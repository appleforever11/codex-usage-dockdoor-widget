//! Top-level snapshot assembly: one JSON document serving the whole plasmoid
//! (usage, telemetry, analytics, sessions, model settings, rotating dock
//! cards), written to the state folder and served over localhost HTTP.

use crate::analytics::{self, Analytics};
use crate::modelsettings::{self, ModelSettings};
use crate::sessions::{self, SessionFile, SessionView};
use crate::settings::{state_root, Settings};
use crate::telemetry::{self, Telemetry, TelemetrySource};
use crate::usage::{self, DockCard, UsageView};
use serde::Serialize;
use std::path::Path;

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub version: i32,
    pub generated_at: i64,
    pub generated_at_iso: String,
    pub usage: UsageView,
    pub telemetry: Telemetry,
    pub analytics: Analytics,
    pub model_settings: ModelSettings,
    pub available_models: Vec<modelsettings::ModelInfo>,
    pub counts: Counts,
    pub headline: String,
    pub latest_chat: Option<String>,
    pub projects: Vec<sessions::ProjectView>,
    pub sessions: Vec<SessionView>,
    pub dock_cards: Vec<DockCard>,
    pub helper: HelperInfo,
    pub diagnostics: Diagnostics,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Counts {
    pub project_count: usize,
    pub active_count: usize,
    pub chat_count: usize,
    pub task_count: usize,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct HelperInfo {
    pub version: &'static str,
    pub port: u16,
    pub codex_binary: Option<String>,
    pub refresh_seconds: u64,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Diagnostics {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub account_fetch_error: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub usage_file_error: Option<String>,
    pub telemetry_freshness_label: String,
    pub telemetry_session_count: i64,
    pub telemetry_event_count: i64,
}

pub struct FetchOutcome {
    pub plan_type: Option<String>,
    pub reset_credit_title: Option<String>,
    pub error: Option<String>,
    pub models: Vec<modelsettings::ModelInfo>,
}

impl FetchOutcome {
    /// A fetch that never talked to the app-server (quiet startup path).
    pub fn quiet() -> Self {
        Self {
            plan_type: None,
            reset_credit_title: None,
            error: None,
            models: modelsettings::fallback_catalog(),
        }
    }
}

/// Query the account (app-server RPC, HTTP fallback) and persist usage.json.
pub fn refresh_account_limits(settings: &Settings) -> FetchOutcome {
    let codex_binary = crate::codexrpc::find_codex_binary();
    let result = match &codex_binary {
        Some(binary) => crate::codexrpc::fetch_account_and_models(binary).or_else(|rpc_error| {
            // Fall back to direct backend access when the RPC path fails
            // (busy app-server, startup hiccups); the model catalog then
            // falls back to the curated list.
            crate::httpfetch::fetch_account_limits()
                .map(|limits| (limits, Vec::new()))
                .map_err(|http_error| format!("app-server: {rpc_error}; direct: {http_error}"))
        }),
        None => crate::httpfetch::fetch_account_limits()
            .map(|limits| (limits, Vec::new()))
            .map_err(|http_error| format!("codex binary not found; direct: {http_error}")),
    };

    match result {
        Ok((limits, models)) => {
            let plan_type = limits.plan_type.clone();
            let reset_credit_title = limits.reset_credits.first().map(|c| c.title.clone());
            match crate::usagefile::write_usage_file(&limits, settings) {
                Ok(_) => FetchOutcome {
                    plan_type,
                    reset_credit_title,
                    error: None,
                    models,
                },
                Err(error) => FetchOutcome {
                    plan_type,
                    reset_credit_title,
                    error: Some(format!("failed writing usage file: {error}")),
                    models,
                },
            }
        }
        Err(error) => FetchOutcome {
            plan_type: None,
            reset_credit_title: None,
            error: Some(error),
            models: modelsettings::fallback_catalog(),
        },
    }
}

/// Scan local session data and assemble the complete snapshot document.
pub fn build_snapshot(
    settings: &Settings,
    fetch: &FetchOutcome,
    helper: HelperInfo,
) -> Snapshot {
    let now = chrono::Utc::now().timestamp();
    let sessions_root = settings.sessions_root();
    let files: Vec<SessionFile> = sessions::session_files(&sessions_root);
    let records = sessions::build_records(&files);
    let index_names = sessions::session_index_names(&crate::settings::codex_home());
    let recent_limit = settings.recent_limit as usize;
    let panel_sessions =
        sessions::build_session_views(&records, &index_names, recent_limit.max(1), recent_limit.max(1));
    let projects = sessions::build_projects(&records, recent_limit);
    let latest_chat = sessions::latest_history_prompt(&crate::settings::codex_home());
    let headline = panel_sessions
        .first()
        .map(|s| s.project_name.clone())
        .or_else(|| projects.first().map(|p| p.name.clone()))
        .unwrap_or_else(|| "No sessions".to_string());

    let telemetry_sources: Vec<TelemetrySource<'_>> = records
        .iter()
        .map(|record| TelemetrySource {
            id: &record.id,
            project_name: record
                .metadata
                .cwd
                .rsplit('/')
                .next()
                .unwrap_or(&record.metadata.cwd)
                .to_string(),
            path: Some(Path::new(&record.file.path)),
            contents: None,
            modified: record.file.modified,
        })
        .collect();
    let telemetry = telemetry::read_telemetry(&telemetry_sources, now, settings.usage_window_hours);

    let usage_inputs = usage::UsageInputs {
        settings,
        telemetry: &telemetry,
        projects: &projects,
        sessions: &panel_sessions,
        session_files: &files,
        plan_type: fetch.plan_type.clone(),
        reset_credit_title: fetch.reset_credit_title.clone(),
        now,
    };
    let usage_view = usage::resolve(&usage_inputs);

    let analytics = analytics::build(
        &telemetry,
        &usage_view,
        &panel_sessions,
        &settings.usage_state_path_expanded(),
        settings.daily_goal_tokens(),
        now,
    );

    let model_settings = modelsettings::read();
    let available_models = if fetch.models.is_empty() {
        modelsettings::fallback_catalog()
    } else {
        fetch.models.clone()
    };
    let task_count = sessions::local_task_count(&crate::settings::codex_home(), &panel_sessions);
    let chat_count = files.len();
    let active_count = panel_sessions.iter().filter(|s| s.is_active).count();

    let dock_cards = build_dock_cards(&usage_view, &model_settings, &telemetry, &analytics, task_count, chat_count, projects.len(), &headline, now);

    Snapshot {
        version: 1,
        generated_at: now,
        generated_at_iso: crate::util::iso8601(now),
        usage: usage_view,
        telemetry,
        analytics,
        model_settings,
        available_models,
        counts: Counts {
            project_count: projects.len(),
            active_count,
            chat_count,
            task_count,
        },
        headline,
        latest_chat,
        projects,
        sessions: panel_sessions,
        dock_cards,
        helper,
        diagnostics: Diagnostics {
            account_fetch_error: fetch.error.clone(),
            usage_file_error: None,
            telemetry_freshness_label: String::new(),
            telemetry_session_count: 0,
            telemetry_event_count: 0,
        },
    }
}

/// Port of `CodexSnapshot.rotatingDockCard` deck construction: account cards
/// first, then model/tasks/chats and optional burn/pace/cost cards. The QML
/// side performs the actual rotation by interval or pinned kind.
#[allow(clippy::too_many_arguments)]
fn build_dock_cards(
    usage: &UsageView,
    model_settings: &ModelSettings,
    telemetry: &Telemetry,
    analytics: &Analytics,
    task_count: usize,
    chat_count: usize,
    project_count: usize,
    headline: &str,
    now: i64,
) -> Vec<DockCard> {
    let mut cards = usage.dock_cards.clone();
    if cards.is_empty() {
        cards.push(DockCard {
            title: format!("{}% Left", (usage.percent_remaining * 100.0).round() as i64),
            subtitle: usage.primary_subtitle.clone(),
            short_label: "Left".into(),
            percent_remaining: Some(usage.percent_remaining),
            kind: "usage".into(),
        });
        cards.push(DockCard {
            title: format!("Used {}", crate::util::compact_tokens_plain(usage.window_used_tokens)),
            subtitle: usage.source.clone(),
            short_label: "Usage".into(),
            percent_remaining: None,
            kind: "usage".into(),
        });
        cards.push(DockCard {
            title: usage
                .reset_at
                .map(|reset| format!("Reset {}", crate::util::relative_time(reset, now)))
                .or_else(|| usage.reset_label.clone().map(|label| format!("Reset {label}")))
                .unwrap_or_else(|| "Reset Soon".to_string()),
            subtitle: if usage.reset_at.is_none() && usage.reset_label.is_none() {
                "No reset time found".to_string()
            } else {
                "Usage limit countdown".to_string()
            },
            short_label: "Reset".into(),
            percent_remaining: None,
            kind: "usage".into(),
        });
    }

    cards.push(DockCard {
        title: model_settings.short_model_name.clone(),
        subtitle: format!(
            "{} reasoning{}",
            model_settings.reasoning_label,
            if model_settings.fast { " · Fast" } else { "" }
        ),
        short_label: "Model".into(),
        percent_remaining: None,
        kind: "model".into(),
    });
    cards.push(DockCard {
        title: format!("{task_count} Tasks"),
        subtitle: format!("{project_count} projects active"),
        short_label: "Tasks".into(),
        percent_remaining: None,
        kind: "tasks".into(),
    });
    cards.push(DockCard {
        title: format!("{chat_count} Chats"),
        subtitle: headline.to_string(),
        short_label: "Chats".into(),
        percent_remaining: None,
        kind: "chats".into(),
    });

    if telemetry.has_data() {
        cards.push(DockCard {
            title: telemetry.burn_label(now),
            subtitle: format!(
                "{} · {}",
                crate::util::model_label(telemetry.current_model.as_deref()),
                telemetry
                    .current_reasoning_effort
                    .as_deref()
                    .map(crate::util::reasoning_label)
                    .unwrap_or_else(|| "Unknown reasoning".to_string())
            ),
            short_label: "Burn".into(),
            percent_remaining: None,
            kind: "burn".into(),
        });
    }
    if let Some(pace) = &analytics.quota_pace {
        if let Some(rate) = pace.percent_per_hour {
            let projected = pace
                .projected_exhaustion_at
                .map(|date| format!("Runs out {}", crate::util::relative_time(date, now)))
                .unwrap_or_else(|| "Building baseline".to_string());
            cards.push(DockCard {
                title: format!("{rate:.1}% / hr"),
                subtitle: format!("Quota pace · {projected}"),
                short_label: "Pace".into(),
                percent_remaining: None,
                kind: "pace".into(),
            });
        }
    }
    if let Some(cost) = analytics.estimated_cost_usd {
        cards.push(DockCard {
            title: format!("${cost:.2} est."),
            subtitle: "30-day API-equivalent cost".to_string(),
            short_label: "Cost".into(),
            percent_remaining: None,
            kind: "cost".into(),
        });
    }

    cards
}

pub fn snapshot_state_path() -> std::path::PathBuf {
    state_root().join("snapshot.json")
}

pub fn persist(snapshot: &Snapshot) -> std::io::Result<std::path::PathBuf> {
    let path = snapshot_state_path();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let temp = path.with_extension("json.tmp");
    std::fs::write(&temp, serde_json::to_vec(snapshot).unwrap_or_default())?;
    std::fs::rename(temp, &path)?;
    Ok(path)
}
