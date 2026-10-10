//! Direct ChatGPT-backend fallback used only when the Codex CLI binary is
//! unavailable but `~/.codex/auth.json` still holds ChatGPT-subscription
//! tokens. The app-server RPC remains the primary path; this mirror talks to
//! the same usage endpoint with the stored access token and refreshes it via
//! the Codex CLI's public OAuth client when expired.

use crate::codexrpc::{AccountLimits, LimitEntry, ResetCredit};
use crate::settings::codex_home;
use serde_json::{json, Value};
use std::path::PathBuf;

const USAGE_URL: &str = "https://chatgpt.com/backend-api/codex/usage";
const TOKEN_URL: &str = "https://auth.openai.com/oauth/token";
const CLIENT_ID: &str = "app_EMoamEEZ73f0CkXaXp7hrann";

struct AuthFile {
    document: Value,
    path: PathBuf,
}

impl AuthFile {
    fn load() -> Option<Self> {
        let path = codex_home().join("auth.json");
        let text = std::fs::read_to_string(&path).ok()?;
        let document: Value = serde_json::from_str(&text).ok()?;
        Some(Self { document, path })
    }

    fn tokens(&self) -> Option<&Value> {
        self.document.get("tokens")
    }

    fn access_token(&self) -> Option<String> {
        self.tokens()
            .and_then(|t| t.get("access_token"))
            .and_then(|v| v.as_str())
            .filter(|s| !s.is_empty())
            .map(|s| s.to_string())
    }

    fn account_id(&self) -> Option<String> {
        self.tokens()
            .and_then(|t| t.get("account_id"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
    }

    /// Refresh only when the stored token is older than the typical access
    /// lifetime so we never race Codex's own token rotation needlessly.
    fn should_refresh(&self) -> bool {
        let last_refresh = self
            .document
            .get("last_refresh")
            .and_then(|v| v.as_str())
            .and_then(|s| crate::util::parse_timestamp(Some(s)));
        match last_refresh {
            Some(ts) => chrono::Utc::now().timestamp() - ts > 45 * 60,
            None => true,
        }
    }

    fn apply_refresh(&mut self, response: &Value) {
        let Some(tokens) = self.document.get_mut("tokens") else {
            return;
        };
        for key in ["access_token", "refresh_token", "id_token", "account_id"] {
            if let Some(value) = response.get(key) {
                if !value.is_null() {
                    tokens[key] = value.clone();
                }
            }
        }
        if let Some(object) = self.document.as_object_mut() {
            object.insert(
                "last_refresh".to_string(),
                json!(chrono::Utc::now()
                    .format("%Y-%m-%dT%H:%M:%S%.3fZ")
                    .to_string()),
            );
        }
        if let Ok(data) = serde_json::to_vec_pretty(&self.document) {
            let temp = self.path.with_extension("json.tmp");
            if std::fs::write(&temp, data).is_ok() {
                let _ = std::fs::rename(temp, &self.path);
            }
        }
    }
}

pub fn fetch_account_limits() -> Result<AccountLimits, String> {
    let mut auth = AuthFile::load().ok_or("no ~/.codex/auth.json to fall back on")?;
    let account_id_hint = auth.account_id();

    if auth.should_refresh() {
        if let Some(refresh_token) = auth
            .tokens()
            .and_then(|t| t.get("refresh_token"))
            .and_then(|v| v.as_str())
            .map(|s| s.to_string())
        {
            if let Ok(response) = ureq::post(TOKEN_URL)
                .set("Content-Type", "application/json")
                .send_json(json!({
                    "client_id": CLIENT_ID,
                    "grant_type": "refresh_token",
                    "refresh_token": refresh_token,
                }))
            {
                if let Ok(value) = response.into_json::<Value>() {
                    auth.apply_refresh(&value);
                }
            }
        }
    }

    let access_token = auth.access_token().ok_or("auth.json has no access token")?;
    let mut request = ureq::get(USAGE_URL)
        .set("Authorization", &format!("Bearer {access_token}"))
        .set("OpenAI-Beta", "responses=experimental")
        .set("User-Agent", "codex_usage_plasmoid");
    if let Some(account) = &account_id_hint {
        request = request.set("chatgpt-account-id", account);
    }
    let response = request
        .call()
        .map_err(|e| format!("usage endpoint request failed: {e}"))?;
    let value: Value = response
        .into_json()
        .map_err(|e| format!("usage response was not JSON: {e}"))?;
    parse_usage_payload(&value, account_id_hint)
}

fn limit_entry_from(id: &str, name: Option<&str>, entry: &Value) -> LimitEntry {
    let primary = entry.get("primary").unwrap_or(entry);
    LimitEntry {
        id: id.to_string(),
        name: name.map(|s| s.to_string()),
        used_percent: primary
            .get("used_percent")
            .or_else(|| primary.get("usedPercent"))
            .and_then(|v| v.as_f64())
            .unwrap_or(0.0),
        window_minutes: primary
            .get("window_minutes")
            .or_else(|| primary.get("windowDurationMins"))
            .and_then(|v| v.as_i64()),
        window_minutes_source: None,
        resets_at: primary
            .get("resets_at")
            .or_else(|| primary.get("resetsAt"))
            .and_then(|v| v.as_i64()),
        credits_balance: entry
            .pointer("/credits/balance")
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        credits_unlimited: entry
            .pointer("/credits/unlimited")
            .and_then(|v| v.as_bool())
            .unwrap_or(false),
    }
}

fn parse_usage_payload(value: &Value, account_id: Option<String>) -> Result<AccountLimits, String> {
    // The endpoint exposes rate_limits mirrors of the app-server shape.
    let container = value
        .get("rate_limits")
        .or_else(|| value.get("rateLimits"))
        .unwrap_or(value);
    let mut limits = Vec::new();

    if let Some(by_id) = container
        .get("rateLimitsByLimitId")
        .and_then(|v| v.as_object())
    {
        for (id, entry) in by_id {
            let name = entry
                .get("limit_name")
                .or_else(|| entry.get("limitName"))
                .and_then(|v| v.as_str());
            limits.push(limit_entry_from(id, name, entry));
        }
    } else if container.get("primary").is_some() || container.get("used_percent").is_some() {
        let id = container
            .get("limit_id")
            .or_else(|| container.get("limitId"))
            .and_then(|v| v.as_str())
            .unwrap_or("codex");
        let name = container
            .get("limit_name")
            .or_else(|| container.get("limitName"))
            .and_then(|v| v.as_str());
        limits.push(limit_entry_from(id, name, container));
    }
    if limits.is_empty() {
        return Err("usage payload contained no limits".to_string());
    }
    limits.sort_by_key(|entry| (entry.id != "codex", entry.id.clone()));

    Ok(AccountLimits {
        account_id,
        plan_type: value
            .get("plan_type")
            .or_else(|| value.get("planType"))
            .or_else(|| {
                container
                    .get("plan_type")
                    .or_else(|| container.get("planType"))
            })
            .and_then(|v| v.as_str())
            .map(|s| s.to_string()),
        ordinary_usage_allowed: None,
        limits,
        reset_credits: Vec::<ResetCredit>::new(),
        fetched_at: chrono::Utc::now().timestamp(),
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_usage_endpoint_mirror() {
        let payload = json!({
            "rate_limits": {
                "limit_id": "codex",
                "primary": {"used_percent": 30, "window_minutes": 10080, "resets_at": 1791580235},
                "credits": {"balance": "0", "unlimited": false}
            }
        });
        let limits = parse_usage_payload(&payload, Some("acct".into())).expect("parse");
        assert_eq!(limits.limits.len(), 1);
        assert_eq!(limits.limits[0].used_percent, 30.0);
        assert_eq!(limits.account_id.as_deref(), Some("acct"));
    }
}
