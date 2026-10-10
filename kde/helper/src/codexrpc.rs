//! Live account limits from the local Codex app-server, mirroring the macOS
//! sync agent: spawn `codex app-server --listen stdio://`, complete the
//! JSON-RPC handshake, call `account/rateLimits/read`, and keep the last valid
//! data when a transient startup delay produces no response.

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::io::{BufRead, BufReader, Write};
use std::process::{Child, Command, Stdio};
use std::time::Duration;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct LimitEntry {
    pub id: String,
    pub name: Option<String>,
    pub used_percent: f64,
    pub window_minutes: Option<i64>,
    pub window_minutes_source: Option<String>,
    pub resets_at: Option<i64>,
    pub credits_balance: Option<String>,
    pub credits_unlimited: bool,
}

impl LimitEntry {
    pub fn display_name(&self) -> String {
        self.name.clone().unwrap_or_else(|| "General".to_string())
    }

    pub fn is_general(&self) -> bool {
        self.id == "codex" || self.name.is_none()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ResetCredit {
    pub title: String,
    #[serde(default)]
    pub description: Option<String>,
    pub expires_at: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AccountLimits {
    pub account_id: Option<String>,
    pub plan_type: Option<String>,
    pub ordinary_usage_allowed: Option<bool>,
    pub limits: Vec<LimitEntry>,
    pub reset_credits: Vec<ResetCredit>,
    pub fetched_at: i64,
}

pub fn find_codex_binary() -> Option<String> {
    if let Ok(env_override) = std::env::var("CODEX_BIN") {
        if !env_override.is_empty() {
            return Some(env_override);
        }
    }
    let path = std::env::var("PATH").unwrap_or_default();
    path.split(':')
        .map(|dir| std::path::Path::new(dir).join("codex"))
        .find(|candidate| candidate.is_file())
        .map(|p| p.to_string_lossy().to_string())
}

/// Account limits plus the selectable model catalog, both from one app-server
/// session (one spawn, two RPCs — no extra requests over the old path).
pub fn fetch_account_and_models(
    codex_binary: &str,
) -> Result<(AccountLimits, Vec<crate::modelsettings::ModelInfo>), String> {
    let mut last_error = String::from("no attempts made");
    for attempt in 1..=3u32 {
        match fetch_once(codex_binary) {
            Ok(result) => return Ok(result),
            Err(error) => {
                last_error = error;
                std::thread::sleep(Duration::from_secs(attempt as u64));
            }
        }
    }
    Err(last_error)
}

fn fetch_once(
    codex_binary: &str,
) -> Result<(AccountLimits, Vec<crate::modelsettings::ModelInfo>), String> {
    let mut child = spawn_app_server(codex_binary)?;
    let result = handshake(&mut child);
    let _ = child.kill();
    let _ = child.wait();
    result
}

fn spawn_app_server(codex_binary: &str) -> Result<Child, String> {
    Command::new(codex_binary)
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| format!("failed to spawn {codex_binary} app-server: {error}"))
}

fn handshake(
    child: &mut Child,
) -> Result<(AccountLimits, Vec<crate::modelsettings::ModelInfo>), String> {
    let mut stdin = child
        .stdin
        .take()
        .ok_or_else(|| "app-server stdin unavailable".to_string())?;
    let stdout = child
        .stdout
        .take()
        .ok_or_else(|| "app-server stdout unavailable".to_string())?;

    let initialize = json!({
        "id": 1,
        "method": "initialize",
        "params": {
            "clientInfo": {
                "name": "codex-usage-plasmoid",
                "title": "Codex Usage Plasmoid",
                "version": super::settings::HELPER_VERSION,
            },
            "capabilities": {
                "experimentalApi": true,
                "requestAttestation": false,
            },
        },
    });
    let initialized = json!({"method": "initialized", "params": {}});
    let rate_limits = json!({"id": 2, "method": "account/rateLimits/read", "params": null});
    let model_list = json!({"id": 3, "method": "model/list", "params": {}});

    stdin
        .write_all(format!("{initialize}\n").as_bytes())
        .and_then(|_| stdin.flush())
        .map_err(|e| format!("initialize write failed: {e}"))?;
    std::thread::sleep(Duration::from_millis(250));
    stdin
        .write_all(format!("{initialized}\n{rate_limits}\n{model_list}\n").as_bytes())
        .and_then(|_| stdin.flush())
        .map_err(|e| format!("request write failed: {e}"))?;

    // Read replies on a worker thread so the deadline is enforced even while
    // blocking on read_line. stdin stays open until the reply arrives: closing
    // it early is an EOF that makes the app-server exit before replying.
    let (tx, rx) = std::sync::mpsc::channel::<String>();
    std::thread::spawn(move || {
        let mut reader = BufReader::new(stdout);
        let mut line = String::new();
        loop {
            line.clear();
            match reader.read_line(&mut line) {
                Ok(0) | Err(_) => break,
                Ok(_) => {
                    if tx.send(line.clone()).is_err() {
                        break;
                    }
                }
            }
        }
    });

    // A busy app-server can take a few seconds before the reply lands; the
    // macOS agent waited five seconds per attempt with three retries.
    let deadline = std::time::Instant::now() + Duration::from_secs(8);
    let mut limits: Option<AccountLimits> = None;
    let mut models: Option<Vec<crate::modelsettings::ModelInfo>> = None;
    loop {
        // The rate-limit reply is required; the model list is best-effort and
        // falls back to the curated catalog when the app-server skips it.
        if limits.is_some() && models.is_some() {
            drop(stdin);
            return Ok((limits.unwrap(), models.unwrap()));
        }
        match rx.recv_timeout(deadline.saturating_duration_since(std::time::Instant::now())) {
            Ok(line) => {
                let Ok(value) = serde_json::from_str::<Value>(line.trim()) else {
                    continue;
                };
                match value.get("id").and_then(|id| id.as_i64()) {
                    Some(2) => {
                        let result = value.get("result").ok_or_else(|| {
                            format!(
                                "rateLimits error: {}",
                                value.get("error").cloned().unwrap_or(Value::Null)
                            )
                        })?;
                        limits = Some(parse_rate_limit_result(result)?);
                    }
                    Some(3) => {
                        if let Some(result) = value.get("result") {
                            models = Some(parse_model_list(result));
                        }
                    }
                    _ => continue,
                }
            }
            Err(std::sync::mpsc::RecvTimeoutError::Timeout) => {
                if let Some(limits) = limits {
                    drop(stdin);
                    return Ok((limits, Vec::new()));
                }
                return Err("timed out waiting for account/rateLimits/read".to_string());
            }
            Err(std::sync::mpsc::RecvTimeoutError::Disconnected) => {
                if let Some(limits) = limits {
                    drop(stdin);
                    return Ok((limits, Vec::new()));
                }
                return Err("app-server closed before replying".to_string());
            }
        }
    }
}

/// Parse the `model/list` result: keep visible models, carry the per-model
/// effort ladder, and flag the "/fast" speed tier.
pub fn parse_model_list(result: &Value) -> Vec<crate::modelsettings::ModelInfo> {
    let Some(data) = result.get("data").and_then(|d| d.as_array()) else {
        return Vec::new();
    };
    let mut models = Vec::new();
    for entry in data {
        if entry.get("hidden").and_then(|h| h.as_bool()).unwrap_or(false) {
            continue;
        }
        let Some(id) = entry
            .get("id")
            .or_else(|| entry.get("model"))
            .and_then(|v| v.as_str())
        else {
            continue;
        };
        let display_name = entry
            .get("displayName")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
            .unwrap_or_else(|| id.to_string());
        let description = entry
            .get("description")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let mut efforts: Vec<String> = entry
            .get("supportedReasoningEfforts")
            .and_then(|v| v.as_array())
            .map(|list| {
                list.iter()
                    .filter_map(|e| e.get("reasoningEffort").and_then(|v| v.as_str()))
                    .map(|s| s.to_string())
                    .collect()
            })
            .unwrap_or_default();
        if efforts.is_empty() {
            efforts = crate::modelsettings::EFFORT_LADDER
                .iter()
                .map(|e| e.to_string())
                .collect();
        }
        let default_effort = entry
            .get("defaultReasoningEffort")
            .and_then(|v| v.as_str())
            .unwrap_or("")
            .to_string();
        let supports_fast = entry
            .get("additionalSpeedTiers")
            .and_then(|v| v.as_array())
            .map(|tiers| tiers.iter().any(|t| t.as_str() == Some("fast")))
            .unwrap_or(false)
            || entry
                .get("serviceTiers")
                .and_then(|v| v.as_array())
                .map(|tiers| {
                    tiers
                        .iter()
                        .any(|t| t.get("id").and_then(|v| v.as_str()) == Some("fast"))
                })
                .unwrap_or(false);
        let is_default = entry
            .get("isDefault")
            .and_then(|v| v.as_bool())
            .unwrap_or(false);
        models.push(crate::modelsettings::ModelInfo {
            id: id.to_string(),
            display_name,
            description,
            family: crate::util::model_family(id).to_string(),
            efforts,
            default_effort,
            supports_fast,
            is_default,
        });
    }
    models
}

#[derive(Debug, Deserialize)]
struct RawWindow {
    #[serde(default, alias = "usedPercent")]
    used_percent: Option<f64>,
    #[serde(default, alias = "windowMinutes")]
    window_minutes: Option<i64>,
    #[serde(default, alias = "windowDurationMins")]
    window_duration_mins: Option<i64>,
    #[serde(default, alias = "resetsAt")]
    resets_at: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct RawCredits {
    #[serde(default)]
    balance: Option<String>,
    #[serde(default)]
    unlimited: Option<bool>,
}

#[derive(Debug, Deserialize)]
struct RawLimit {
    #[serde(default, alias = "limitId")]
    limit_id: Option<String>,
    #[serde(default, alias = "limitName")]
    limit_name: Option<String>,
    #[serde(default, alias = "planType")]
    plan_type: Option<String>,
    #[serde(default)]
    primary: Option<RawWindow>,
    #[serde(default)]
    credits: Option<RawCredits>,
}

#[derive(Debug, Deserialize)]
struct RawResetCredit {
    #[serde(default)]
    title: Option<String>,
    #[serde(default)]
    description: Option<String>,
    #[serde(default, alias = "expires_at")]
    expires_at: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct RawResult {
    #[serde(default, alias = "accountId")]
    account_id: Option<String>,
    #[serde(default, alias = "planType")]
    plan_type: Option<String>,
    #[serde(default, alias = "ordinaryUsageAllowed")]
    ordinary_usage_allowed: Option<bool>,
    #[serde(default, alias = "rateLimits")]
    rate_limits: Option<RawLimit>,
    #[serde(default, alias = "rateLimitsByLimitId")]
    rate_limits_by_limit_id: Option<std::collections::BTreeMap<String, RawLimit>>,
    #[serde(default, alias = "rateLimitResetCredits")]
    rate_limit_reset_credits: Option<RawResetCredits>,
}

#[derive(Debug, Deserialize)]
struct RawResetCredits {
    #[serde(default)]
    credits: Vec<RawResetCredit>,
}

fn parse_rate_limit_result(result: &Value) -> Result<AccountLimits, String> {
    // Accept both the live camelCase payload and the snake_case shape older
    // app-server versions emitted.
    let raw: RawResult = serde_json::from_value(result.clone())
        .map_err(|e| format!("rateLimits shape not recognized: {e}"))?;

    let mut ordered: Vec<RawLimit> = Vec::new();
    if let Some(by_id) = &raw.rate_limits_by_limit_id {
        // Deterministic order: the general "codex" limit first, then the rest
        // sorted by id so named limits keep stable positions.
        let mut ids: Vec<&String> = by_id.keys().collect();
        ids.sort_by_key(|id| (id.as_str() != "codex", id.to_string()));
        for id in ids {
            if let Some(limit) = by_id.get(id) {
                ordered.push(clone_limit(limit));
            }
        }
    }
    if ordered.is_empty() {
        if let Some(limit) = &raw.rate_limits {
            ordered.push(clone_limit(limit));
        }
    }
    if ordered.is_empty() {
        return Err("rateLimits contained no limit entries".to_string());
    }

    let plan_type = raw
        .plan_type
        .clone()
        .or_else(|| ordered.first().and_then(|limit| limit.plan_type.clone()));

    let mut limits = Vec::new();
    for entry in ordered {
        let Some(primary) = &entry.primary else {
            continue;
        };
        let window_minutes = primary.window_minutes.or(primary.window_duration_mins);
        limits.push(LimitEntry {
            id: entry
                .limit_id
                .clone()
                .unwrap_or_else(|| "codex".to_string()),
            name: entry.limit_name.clone(),
            used_percent: primary.used_percent.unwrap_or(0.0),
            window_minutes,
            window_minutes_source: None,
            resets_at: primary.resets_at,
            credits_balance: entry.credits.as_ref().and_then(|c| c.balance.clone()),
            credits_unlimited: entry
                .credits
                .as_ref()
                .and_then(|c| c.unlimited)
                .unwrap_or(false),
        });
    }
    if limits.is_empty() {
        return Err("rateLimits entries had no primary window".to_string());
    }

    let reset_credits = raw
        .rate_limit_reset_credits
        .map(|wrapper| {
            wrapper
                .credits
                .into_iter()
                .map(|credit| ResetCredit {
                    title: credit
                        .title
                        .unwrap_or_else(|| "Rate limit reset".to_string()),
                    description: credit.description,
                    expires_at: credit.expires_at,
                })
                .collect()
        })
        .unwrap_or_default();

    Ok(AccountLimits {
        account_id: raw.account_id,
        plan_type,
        ordinary_usage_allowed: raw.ordinary_usage_allowed,
        limits,
        reset_credits,
        fetched_at: chrono::Utc::now().timestamp(),
    })
}

fn clone_limit(limit: &RawLimit) -> RawLimit {
    RawLimit {
        limit_id: limit.limit_id.clone(),
        limit_name: limit.limit_name.clone(),
        plan_type: limit.plan_type.clone(),
        primary: limit.primary.as_ref().map(|w| RawWindow {
            used_percent: w.used_percent,
            window_minutes: w.window_minutes,
            window_duration_mins: w.window_duration_mins,
            resets_at: w.resets_at,
        }),
        credits: limit.credits.as_ref().map(|c| RawCredits {
            balance: c.balance.clone(),
            unlimited: c.unlimited,
        }),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_live_probe_shape() {
        let payload = json!({
            "accountId": "c7956ac2-6edc-439a-a998-6986f87ef1ae",
            "ordinaryUsageAllowed": true,
            "rateLimits": {
                "limitId": "codex",
                "limitName": null,
                "primary": {"usedPercent": 8, "windowDurationMins": 10080, "resetsAt": 1791580235},
                "secondary": null,
                "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
                "planType": "prolite"
            },
            "rateLimitsByLimitId": {
                "codex": {
                    "limitId": "codex",
                    "limitName": null,
                    "primary": {"usedPercent": 8, "windowDurationMins": 10080, "resetsAt": 1791580235},
                    "credits": {"hasCredits": false, "unlimited": false, "balance": "0"},
                    "planType": "prolite"
                }
            },
            "rateLimitResetCredits": {
                "availableCount": 1,
                "credits": [{"id": "x", "resetType": "codexRateLimits", "status": "available",
                             "title": "Full reset", "expiresAt": 1793300941,
                             "description": "one free rate limit reset"}]
            }
        });
        let limits = parse_rate_limit_result(&payload).expect("parse");
        assert_eq!(limits.limits.len(), 1);
        assert_eq!(limits.limits[0].used_percent, 8.0);
        assert_eq!(limits.limits[0].window_minutes, Some(10080));
        assert_eq!(limits.limits[0].resets_at, Some(1791580235));
        assert!(limits.limits[0].is_general());
        assert_eq!(limits.plan_type.as_deref(), Some("prolite"));
        assert_eq!(limits.reset_credits.len(), 1);
        assert_eq!(limits.reset_credits[0].title, "Full reset");
    }

    #[test]
    fn parses_model_list() {
        let payload = json!({
            "data": [
                {
                    "id": "gpt-6.1-sol",
                    "displayName": "GPT-6.1-Sol",
                    "description": "Latest workhorse model for coding and everyday work.",
                    "supportedReasoningEfforts": [
                        {"reasoningEffort": "low", "description": "Fast responses with lighter reasoning"},
                        {"reasoningEffort": "medium", "description": "Balanced"},
                        {"reasoningEffort": "high", "description": "Deep"},
                        {"reasoningEffort": "xhigh", "description": "Extra high"},
                        {"reasoningEffort": "max", "description": "Maximum"},
                        {"reasoningEffort": "ultra", "description": "Delegation"}
                    ],
                    "defaultReasoningEffort": "low",
                    "additionalSpeedTiers": ["fast"],
                    "serviceTiers": [{"id": "priority", "name": "Fast", "description": "2x speed, increased usage"}],
                    "hidden": false,
                    "isDefault": true
                },
                {
                    "id": "gpt-daybreak-blue-latest",
                    "displayName": "Daybreak Blue",
                    "supportedReasoningEfforts": [{"reasoningEffort": "low"}, {"reasoningEffort": "max"}],
                    "additionalSpeedTiers": [],
                    "hidden": true,
                    "isDefault": false
                }
            ]
        });
        let models = parse_model_list(&payload);
        assert_eq!(models.len(), 1, "hidden models are dropped");
        let model = &models[0];
        assert_eq!(model.id, "gpt-6.1-sol");
        assert_eq!(model.family, "sol");
        assert_eq!(model.efforts, vec!["low", "medium", "high", "xhigh", "max", "ultra"]);
        assert_eq!(model.default_effort, "low");
        assert!(model.supports_fast);
        assert!(model.is_default);
    }

    #[test]
    fn parses_snake_case_shape() {
        let payload = json!({
            "rate_limits": {
                "limit_id": "gpt-6-astra",
                "limit_name": "GPT-6-Astra",
                "primary": {"used_percent": 21, "window_minutes": 300},
                "credits": {"balance": "12.5", "unlimited": false}
            }
        });
        let limits = parse_rate_limit_result(&payload).expect("parse");
        assert_eq!(limits.limits.len(), 1);
        assert!(!limits.limits[0].is_general());
        assert_eq!(limits.limits[0].display_name(), "GPT-6-Astra");
        assert_eq!(limits.limits[0].credits_balance.as_deref(), Some("12.5"));
    }
}
