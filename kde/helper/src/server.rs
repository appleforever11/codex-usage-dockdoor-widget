//! Minimal loopback-only HTTP server exposing the snapshot to the plasmoid's
//! QML XMLHttpRequest (Qt's QML XHR enforces no same-origin policy, and file
//! reads are disabled by default on Qt 6.8+, so localhost HTTP is the bridge).

use crate::settings::{Settings, HELPER_VERSION};
use crate::snapshot::{self, FetchOutcome, Snapshot};
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::{Arc, Condvar, Mutex};

pub struct AppState {
    pub settings: Mutex<Settings>,
    snapshot: Mutex<Option<Arc<Snapshot>>>,
    last_refresh_at: Mutex<i64>,
    refresh_lock: Mutex<()>,
    refresh_signal: Mutex<bool>,
    refresh_cond: Condvar,
    codex_binary: Mutex<Option<String>>,
    models: Mutex<Vec<crate::modelsettings::ModelInfo>>,
}

impl AppState {
    pub fn new(settings: Settings) -> Self {
        let codex_binary = crate::codexrpc::find_codex_binary();
        Self {
            settings: Mutex::new(settings),
            snapshot: Mutex::new(None),
            last_refresh_at: Mutex::new(0),
            refresh_lock: Mutex::new(()),
            refresh_signal: Mutex::new(false),
            refresh_cond: Condvar::new(),
            codex_binary: Mutex::new(codex_binary),
            models: Mutex::new(Vec::new()),
        }
    }

    /// The live model catalog from the last app-server cycle (empty before
    /// the first successful fetch).
    pub fn models(&self) -> Vec<crate::modelsettings::ModelInfo> {
        self.models
            .lock()
            .map(|guard| guard.clone())
            .unwrap_or_default()
    }

    pub fn snapshot(&self) -> Option<Arc<Snapshot>> {
        self.snapshot.lock().ok().and_then(|guard| guard.clone())
    }

    pub fn last_refresh_at(&self) -> i64 {
        self.last_refresh_at.lock().map(|guard| *guard).unwrap_or(0)
    }

    pub fn codex_binary(&self) -> Option<String> {
        self.codex_binary.lock().ok().and_then(|g| g.clone())
    }

    /// Wake the refresh loop early (used by POST /refresh).
    pub fn signal_refresh(&self) {
        if let Ok(mut flag) = self.refresh_signal.lock() {
            *flag = true;
        }
        self.refresh_cond.notify_all();
    }

    /// Block until a refresh is signalled or the timeout elapses.
    pub fn wait_for_refresh_signal(&self, timeout: std::time::Duration) {
        let Ok(flag) = self.refresh_signal.lock() else { return };
        if *flag {
            let _guard = flag;
            if let Ok(mut flag) = self.refresh_signal.lock() {
                *flag = false;
            }
            return;
        }
        let (mut flag, _result) = self
            .refresh_cond
            .wait_timeout_while(flag, timeout, |flag| !*flag)
            .unwrap_or_else(|poison| poison.into_inner());
        *flag = false;
    }

    /// Run one full refresh cycle: account limits → usage.json → snapshot →
    /// state file. Guarded so concurrent /refresh calls cannot stack.
    pub fn refresh_now(&self) -> Arc<Snapshot> {
        let _guard = self.refresh_lock.lock().unwrap_or_else(|poison| poison.into_inner());
        let settings = self
            .settings
            .lock()
            .map(|guard| guard.clone())
            .unwrap_or_default();
        let fetch = snapshot::refresh_account_limits(&settings);
        let helper = crate::snapshot::HelperInfo {
            version: HELPER_VERSION,
            port: settings.port,
            codex_binary: self.codex_binary(),
            refresh_seconds: settings.refresh_seconds,
        };
        let built = snapshot::build_snapshot(&settings, &fetch, helper);
        let _ = snapshot::persist(&built);
        let arc = Arc::new(built);
        if let Ok(mut guard) = self.snapshot.lock() {
            *guard = Some(arc.clone());
        }
        if !fetch.models.is_empty() {
            if let Ok(mut guard) = self.models.lock() {
                *guard = fetch.models.clone();
            }
        }
        if let Ok(mut stamp) = self.last_refresh_at.lock() {
            *stamp = chrono::Utc::now().timestamp();
        }
        arc
    }
}

pub fn serve(state: Arc<AppState>) -> std::io::Result<()> {
    let settings = state
        .settings
        .lock()
        .map(|guard| guard.clone())
        .unwrap_or_default();
    let listener = TcpListener::bind(("127.0.0.1", settings.port))?;
    eprintln!(
        "codex-usage-helper {} listening on http://127.0.0.1:{}",
        HELPER_VERSION, settings.port
    );
    for stream in listener.incoming() {
        let Ok(stream) = stream else { continue };
        let state = state.clone();
        std::thread::spawn(move || {
            let _ = handle_connection(stream, state);
        });
    }
    Ok(())
}

fn handle_connection(mut stream: TcpStream, state: Arc<AppState>) -> std::io::Result<()> {
    stream.set_read_timeout(Some(std::time::Duration::from_secs(10)))?;
    let mut reader = BufReader::new(stream.try_clone()?);

    let mut request_line = String::new();
    reader.read_line(&mut request_line)?;
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("").to_string();
    let path = parts.next().unwrap_or("/").to_string();

    let mut content_length = 0usize;
    loop {
        let mut header = String::new();
        reader.read_line(&mut header)?;
        let header = header.trim_end();
        if header.is_empty() {
            break;
        }
        if let Some((name, value)) = header.split_once(':') {
            if name.trim().eq_ignore_ascii_case("content-length") {
                content_length = value.trim().parse().unwrap_or(0);
            }
        }
    }
    let mut body = vec![0u8; content_length.min(64 * 1024)];
    if content_length > 0 {
        reader.read_exact(&mut body)?;
    }

    let route = path.split('?').next().unwrap_or("/");
    let query = path.split_once('?').map(|(_, q)| q.to_string()).unwrap_or_default();
    // Preflight for browser/API clients: every route answers OPTIONS.
    if method == "OPTIONS" {
        let response = "HTTP/1.1 204 No Content\r\nAccess-Control-Allow-Origin: *\r\nAccess-Control-Allow-Methods: GET, POST, OPTIONS\r\nAccess-Control-Allow-Headers: Content-Type\r\nAccess-Control-Max-Age: 86400\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
        stream.write_all(response.as_bytes())?;
        stream.flush()?;
        return Ok(());
    }
    let (status, content_type, body) = route_request(&state, &method, route, &query, &body);
    let reason = match status {
        200 => "OK",
        202 => "Accepted",
        204 => "No Content",
        400 => "Bad Request",
        404 => "Not Found",
        405 => "Method Not Allowed",
        _ => "Internal Server Error",
    };
    let response = format!(
        "HTTP/1.1 {status} {reason}\r\nContent-Type: {content_type}\r\nCache-Control: no-store\r\nAccess-Control-Allow-Origin: *\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{}",
        body.as_bytes().len(),
        body
    );
    stream.write_all(response.as_bytes())?;
    stream.flush()?;
    Ok(())
}

fn route_request(
    state: &Arc<AppState>,
    method: &str,
    route: &str,
    query: &str,
    body: &[u8],
) -> (u16, String, String) {
    let json_response = |status: u16, payload: serde_json::Value| {
        (
            status,
            "application/json; charset=utf-8".to_string(),
            serde_json::to_string(&payload).unwrap_or_else(|_| "{}".to_string()),
        )
    };
    match (method, route) {
        ("GET", "/health") => {
            let snapshot_age = state.last_refresh_at().max(0);
            json_response(
                200,
                serde_json::json!({
                    "ok": true,
                    "version": HELPER_VERSION,
                    "port": state.settings.lock().map(|s| s.port).unwrap_or_default(),
                    "lastRefreshAt": state.last_refresh_at(),
                    "lastRefreshAgeSeconds": chrono::Utc::now().timestamp() - snapshot_age,
                    "codexBinary": state.codex_binary(),
                    "hasSnapshot": state.snapshot().is_some(),
                }),
            )
        }
        ("GET", "/snapshot") => {
            let snapshot = state
                .snapshot()
                .unwrap_or_else(|| Arc::new(run_quiet_refresh(state)));
            json_response(200, serde_json::to_value(&*snapshot).unwrap_or_default())
        }
        ("POST", "/refresh") => {
            // Signal the daemon loop and answer immediately; the fresh
            // document lands on /snapshot within the cycle. (A synchronous
            // full answer used to hold the request open for tens of seconds.)
            state.signal_refresh();
            json_response(
                202,
                serde_json::json!({"ok": true, "status": "refreshing", "poll": "/snapshot"}),
            )
        }
        ("GET", "/metrics") => {
            let snapshot = state
                .snapshot()
                .unwrap_or_else(|| Arc::new(run_quiet_refresh(state)));
            (
                200,
                "text/plain; version=0.0.4; charset=utf-8".to_string(),
                build_prometheus_metrics(&snapshot),
            )
        }
        ("GET", "/chats") => {
            let snapshot = state.snapshot();
            let chats: Vec<serde_json::Value> = snapshot
                .as_ref()
                .map(|snapshot| {
                    snapshot
                        .sessions
                        .iter()
                        .map(|session| {
                            serde_json::json!({
                                "id": session.id,
                                "title": session.title,
                                "projectName": session.project_name,
                                "projectPath": session.project_path,
                                "modifiedAt": session.modified_at,
                                "isActive": session.is_active,
                                "filePath": session.file_path,
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();
            json_response(200, serde_json::json!({"ok": true, "chats": chats}))
        }
        ("GET", "/transcript") => {
            let Some(session_id) = query_param(query, "id") else {
                return json_response(400, serde_json::json!({"ok": false, "error": "id query parameter required"}));
            };
            match resolve_session_markdown(state, &session_id) {
                Ok((markdown, path)) => json_response(
                    200,
                    serde_json::json!({"ok": true, "id": session_id, "filePath": path, "markdown": markdown}),
                ),
                Err(error) => json_response(404, serde_json::json!({"ok": false, "error": error})),
            }
        }
        ("GET", "/settings") => json_response(
            200,
            state
                .settings
                .lock()
                .map(|guard| serde_json::to_value(&*guard).unwrap_or_default())
                .unwrap_or_default(),
        ),
        ("POST", "/settings") => {
            let Ok(update) = serde_json::from_slice::<serde_json::Value>(body) else {
                return json_response(400, serde_json::json!({"ok": false, "error": "invalid JSON body"}));
            };
            let merged = state
                .settings
                .lock()
                .map(|guard| guard.merged(&update))
                .unwrap_or_default();
            if let Ok(mut guard) = state.settings.lock() {
                *guard = merged.clone();
            }
            let saved = merged.save().is_ok();
            state.signal_refresh();
            json_response(
                200,
                serde_json::json!({"ok": saved, "settings": serde_json::to_value(&merged).unwrap_or_default()}),
            )
        }
        ("GET", "/model") => json_response(
            200,
            serde_json::to_value(crate::modelsettings::read()).unwrap_or_default(),
        ),
        ("POST", "/model") => {
            let Ok(request) = serde_json::from_slice::<serde_json::Value>(body) else {
                return json_response(400, serde_json::json!({"ok": false, "error": "invalid JSON body"}));
            };
            let model = request.get("model").and_then(|v| v.as_str()).unwrap_or("");
            let reasoning = request
                .get("reasoning")
                .or_else(|| request.get("reasoningEffort"))
                .and_then(|v| v.as_str())
                .unwrap_or("");
            // Fast mode arrives either as a bool or as the config tier value
            // ("fast" on, anything else off). Absent means "leave as-is".
            let fast = if let Some(value) = request.get("fast").and_then(|v| v.as_bool()) {
                Some(value)
            } else {
                request
                    .get("serviceTier")
                    .or_else(|| request.get("service_tier"))
                    .and_then(|v| v.as_str())
                    .map(crate::modelsettings::is_fast_tier)
            };
            let mut catalog = state.models();
            if catalog.is_empty() {
                catalog = crate::modelsettings::fallback_catalog();
            }
            match crate::modelsettings::update(model, reasoning, fast, &catalog) {
                Ok(settings) => {
                    let _ = state.refresh_now();
                    json_response(200, serde_json::json!({"ok": true, "modelSettings": settings}))
                }
                Err(error) => json_response(400, serde_json::json!({"ok": false, "error": error})),
            }
        }
        ("POST", "/open") => {
            let Ok(request) = serde_json::from_slice::<serde_json::Value>(body) else {
                return json_response(400, serde_json::json!({"ok": false, "error": "invalid JSON body"}));
            };
            let Some(session_id) = request.get("sessionId").and_then(|v| v.as_str()) else {
                return json_response(400, serde_json::json!({"ok": false, "error": "sessionId required"}));
            };
            // Only UUID-shaped ids are safe to resolve on disk.
            let is_uuid = session_id.len() == 36
                && session_id.bytes().filter(|b| *b == b'-').count() == 4;
            if !is_uuid {
                return json_response(400, serde_json::json!({"ok": false, "error": "session id is not a thread UUID"}));
            }
            let mode = request.get("mode").and_then(|v| v.as_str()).unwrap_or("transcript");
            if mode == "link" {
                let opened = std::process::Command::new("xdg-open")
                    .arg(format!("codex://threads/{session_id}"))
                    .spawn()
                    .map(|child| child.id())
                    .is_ok();
                return json_response(200, serde_json::json!({"ok": opened, "mode": "link"}));
            }
            // Default: render the conversation to Markdown and open it in
            // the configured terminal/editor viewer.
            let viewer = state
                .settings
                .lock()
                .map(|guard| guard.chat_viewer_command.clone())
                .unwrap_or_default();
            match resolve_session_markdown(state, session_id) {
                Ok((markdown, _)) => {
                    match crate::transcript::cached_transcript_path(session_id, &markdown)
                        .and_then(|path| {
                            crate::transcript::open_in_viewer(&viewer, &path).map(|child| (path, child))
                        })
                    {
                        Ok((path, _child)) => json_response(
                            200,
                            serde_json::json!({"ok": true, "mode": "transcript", "file": path.to_string_lossy()}),
                        ),
                        Err(error) => json_response(
                            500,
                            serde_json::json!({"ok": false, "error": format!("open failed: {error}")}),
                        ),
                    }
                }
                Err(error) => json_response(404, serde_json::json!({"ok": false, "error": error})),
            }
        }
        ("GET", _) | ("POST", _) => json_response(404, serde_json::json!({"ok": false, "error": "unknown route"})),
        _ => json_response(405, serde_json::json!({"ok": false, "error": "method not allowed"})),
    }
}

/// Refresh without holding the request: used by GET /snapshot and /metrics
/// when no snapshot exists yet (first seconds after daemon start).
fn run_quiet_refresh(state: &Arc<AppState>) -> crate::snapshot::Snapshot {
    let settings = state
        .settings
        .lock()
        .map(|guard| guard.clone())
        .unwrap_or_default();
    let fetch = crate::snapshot::FetchOutcome::quiet();
    let helper = crate::snapshot::HelperInfo {
        version: HELPER_VERSION,
        port: settings.port,
        codex_binary: state.codex_binary(),
        refresh_seconds: settings.refresh_seconds,
    };
    let built = crate::snapshot::build_snapshot(&settings, &fetch, helper);
    let _ = crate::snapshot::persist(&built);
    let arc = Arc::new(built);
    if let Ok(mut guard) = state.snapshot.lock() {
        *guard = Some(arc.clone());
    }
    arc.as_ref().clone()
}

fn query_param(query: &str, key: &str) -> Option<String> {
    for pair in query.split('&') {
        let (name, value) = pair.split_once('=')?;
        if name == key {
            return Some(url_decode(value));
        }
    }
    None
}

fn url_decode(value: &str) -> String {
    let bytes = value.as_bytes();
    let mut out = Vec::with_capacity(bytes.len());
    let mut index = 0;
    while index < bytes.len() {
        match bytes[index] {
            b'%' if index + 2 < bytes.len() => {
                let hex = std::str::from_utf8(&bytes[index + 1..index + 3]).unwrap_or("");
                let byte = u8::from_str_radix(hex, 16).unwrap_or(b'%');
                out.push(byte);
                index += 3;
            }
            b'+' => {
                out.push(b' ');
                index += 1;
            }
            byte => {
                out.push(byte);
                index += 1;
            }
        }
    }
    String::from_utf8_lossy(&out).to_string()
}

/// Resolve a session id to (markdown, source_path).
fn resolve_session_markdown(state: &Arc<AppState>, session_id: &str) -> Result<(String, String), String> {
    let path = markdown_source_path(state, session_id).ok_or_else(|| "session file not found".to_string())?;
    let markdown = crate::transcript::render_markdown(std::path::Path::new(&path));
    Ok((markdown, path))
}

fn markdown_source_path(state: &Arc<AppState>, session_id: &str) -> Option<String> {
    if let Some(snapshot) = state.snapshot() {
        if let Some(session) = snapshot.sessions.iter().find(|s| s.id == session_id) {
            return Some(session.file_path.clone());
        }
    }
    let sessions_root = state
        .settings
        .lock()
        .map(|guard| guard.sessions_root())
        .unwrap_or_default();
    crate::transcript::session_file_for_id(&sessions_root, session_id)
        .map(|path| path.to_string_lossy().to_string())
}

fn build_prometheus_metrics(snapshot: &crate::snapshot::Snapshot) -> String {
    let mut lines = Vec::new();
    let now = chrono::Utc::now().timestamp();

    lines.push("# HELP codex_usage_generated_at Unix time the snapshot was built.".into());
    lines.push("# TYPE codex_usage_generated_at gauge".into());
    lines.push(format!("codex_usage_generated_at {}", snapshot.generated_at));

    lines.push("# HELP codex_usage_percent_remaining Quota fraction remaining (0-1).".into());
    lines.push("# TYPE codex_usage_percent_remaining gauge".into());
    lines.push(format!(
        "codex_usage_percent_remaining {}",
        snapshot.usage.percent_remaining
    ));

    lines.push("# HELP codex_usage_tokens Tokens observed.".into());
    lines.push("# TYPE codex_usage_tokens gauge".into());
    lines.push(format!(
        "codex_usage_tokens{{window=\"window\"}} {}",
        snapshot.usage.window_used_tokens
    ));
    lines.push(format!(
        "codex_usage_tokens{{window=\"today\"}} {}",
        snapshot.usage.today_used_tokens
    ));
    lines.push(format!(
        "codex_usage_tokens{{window=\"7d\"}} {}",
        snapshot.analytics.last7_days_tokens
    ));
    lines.push(format!(
        "codex_usage_tokens{{window=\"30d\"}} {}",
        snapshot.analytics.last30_days_tokens
    ));

    lines.push("# HELP codex_usage_burn_tokens_per_minute Tokens per minute over the last hour.".into());
    lines.push("# TYPE codex_usage_burn_tokens_per_minute gauge".into());
    lines.push(format!(
        "codex_usage_burn_tokens_per_minute {}",
        snapshot.telemetry.tokens_per_minute(60.0, now).unwrap_or(0.0)
    ));

    if let Some(context) = snapshot.analytics.context_percent {
        lines.push("# HELP codex_usage_context_percent Latest context window fill (0-1).".into());
        lines.push("# TYPE codex_usage_context_percent gauge".into());
        lines.push(format!("codex_usage_context_percent {context}"));
    }

    if let Some(cost) = snapshot.analytics.estimated_cost_usd {
        lines.push("# HELP codex_usage_estimated_cost_usd 30-day API-equivalent cost estimate.".into());
        lines.push("# TYPE codex_usage_estimated_cost_usd gauge".into());
        lines.push(format!("codex_usage_estimated_cost_usd {cost}"));
    }

    if let Some(pace) = &snapshot.analytics.quota_pace {
        lines.push("# HELP codex_usage_quota_used_percent Account quota used (percent).".into());
        lines.push("# TYPE codex_usage_quota_used_percent gauge".into());
        lines.push(format!("codex_usage_quota_used_percent {}", pace.used_percent));
    }

    lines.push("# HELP codex_usage_counts Inventory counts.".into());
    lines.push("# TYPE codex_usage_counts gauge".into());
    lines.push(format!("codex_usage_counts{{kind=\"chats\"}} {}", snapshot.counts.chat_count));
    lines.push(format!("codex_usage_counts{{kind=\"projects\"}} {}", snapshot.counts.project_count));
    lines.push(format!("codex_usage_counts{{kind=\"tasks\"}} {}", snapshot.counts.task_count));

    lines.push("# HELP codex_usage_model_info Current new-chat model default.".into());
    lines.push("# TYPE codex_usage_model_info gauge".into());
    lines.push(format!(
        "codex_usage_model_info{{model=\"{}\", reasoning=\"{}\", fast=\"{}\"}} 1",
        snapshot.model_settings.model,
        snapshot.model_settings.reasoning_effort,
        snapshot.model_settings.fast
    ));

    let mut text = lines.join("\n");
    text.push('\n');
    text
}

/// One-shot refresh used by `codex-usage-helper once` and the systemd timer.
pub fn run_once(settings: &Settings) -> (Snapshot, FetchOutcome) {
    let fetch = snapshot::refresh_account_limits(settings);
    let helper = crate::snapshot::HelperInfo {
        version: HELPER_VERSION,
        port: settings.port,
        codex_binary: crate::codexrpc::find_codex_binary(),
        refresh_seconds: settings.refresh_seconds,
    };
    let built = snapshot::build_snapshot(settings, &fetch, helper);
    let _ = snapshot::persist(&built);
    (built, fetch)
}
