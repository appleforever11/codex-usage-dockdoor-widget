//! `~/.codex/usage.json` writer/reader. The written shape matches the macOS
//! live-sync agent byte-for-byte where it matters (updatedAt, source,
//! creditsBalance, limits[]) so either ecosystem's widget can consume it.

use crate::codexrpc::AccountLimits;
use crate::settings::{codex_home, expand_tilde, Settings};
use crate::util;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct ExternalUsageState {
    pub updated_at: Option<String>,
    pub title: Option<String>,
    pub subtitle: Option<String>,
    pub source: Option<String>,
    pub credits_balance: Option<String>,
    pub used: Option<i64>,
    pub remaining: Option<i64>,
    pub limit: Option<i64>,
    pub today_used: Option<i64>,
    pub reset_at: Option<String>,
    pub reset_label: Option<String>,
    pub percent_remaining: Option<f64>,
    pub remaining_percent: Option<f64>,
    pub percent_used: Option<f64>,
    pub used_percent: Option<f64>,
    pub limits: Vec<ExternalUsageLimit>,
    // Optional aggregate activity surfaced by newer agents; the widget treats
    // it as read-only extra data.
    pub lifetime_tokens: Option<i64>,
    pub peak_daily_tokens: Option<i64>,
    pub current_streak_days: Option<i64>,
    pub longest_streak_days: Option<i64>,
    pub daily_usage_buckets: Vec<DailyUsageBucket>,
    pub plan_type: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct ExternalUsageLimit {
    pub name: String,
    pub subtitle: Option<String>,
    pub system_image: Option<String>,
    pub used: Option<i64>,
    pub remaining: Option<i64>,
    pub limit: Option<i64>,
    pub reset_at: Option<String>,
    pub reset_label: Option<String>,
    pub percent_remaining: Option<i64>,
    pub remaining_percent: Option<i64>,
    pub percent_used: Option<i64>,
    pub used_percent: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
#[serde(rename_all = "camelCase", default)]
pub struct DailyUsageBucket {
    pub start_date: Option<String>,
    pub tokens: Option<i64>,
}

/// Write the authoritative account snapshot atomically (mode 600, like the
/// macOS agent) and return the path used.
pub fn write_usage_file(limits: &AccountLimits, settings: &Settings) -> std::io::Result<PathBuf> {
    let path = settings.usage_state_path_expanded();
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }

    let now = chrono::Utc::now().timestamp();
    let mut external_limits: Vec<ExternalUsageLimit> = Vec::new();

    for entry in &limits.limits {
        let name = if entry.is_general() {
            "General".to_string()
        } else {
            entry.display_name()
        };
        let remaining = 100 - entry.used_percent.round() as i64;
        let is_spark = name.to_ascii_lowercase().contains("spark");
        external_limits.push(ExternalUsageLimit {
            subtitle: Some("Weekly usage limit".to_string()),
            percent_remaining: Some(remaining.max(0)),
            reset_label: entry.resets_at.map(util::short_reset_label),
            reset_at: entry.resets_at.map(util::iso8601),
            system_image: Some(
                if is_spark {
                    "sparkles"
                } else {
                    "gauge.with.dots.needle.67percent"
                }
                .to_string(),
            ),
            name,
            ..Default::default()
        });
    }

    let credits = limits
        .limits
        .first()
        .and_then(|entry| {
            if entry.credits_unlimited {
                Some("Unlimited".to_string())
            } else {
                entry.credits_balance.clone()
            }
        })
        .unwrap_or_else(|| "0".to_string());

    let state = ExternalUsageState {
        updated_at: Some(util::iso8601(now)),
        source: Some("Codex app-server live account limits".to_string()),
        credits_balance: Some(credits),
        limits: external_limits,
        plan_type: limits.plan_type.clone(),
        ..Default::default()
    };

    let temp = path.with_extension("json.tmp");
    std::fs::write(&temp, serde_json::to_vec_pretty(&state).unwrap_or_default())?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        let _ = std::fs::set_permissions(&temp, std::fs::Permissions::from_mode(0o600));
    }
    std::fs::rename(temp, &path)?;
    Ok(path)
}

pub fn read_external_state(settings: &Settings) -> Option<(ExternalUsageState, i64)> {
    let path = settings.usage_state_path_expanded();
    let text = std::fs::read_to_string(&path).ok()?;
    let state: ExternalUsageState = serde_json::from_str(&text).ok()?;
    let modified = std::fs::metadata(&path)
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|time| time.duration_since(std::time::UNIX_EPOCH).ok())
        .map(|duration| duration.as_secs() as i64)
        .unwrap_or(0);
    Some((state, modified))
}

impl Settings {
    pub fn usage_state_path_expanded(&self) -> PathBuf {
        PathBuf::from(expand_tilde(&self.usage_state_path))
    }
}

/// Default sessions folder under the (possibly overridden) Codex home.
pub fn default_sessions_folder() -> String {
    codex_home().join("sessions").to_string_lossy().to_string()
}
