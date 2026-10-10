//! Usage snapshot resolution, ported from `CodexTrackerStore.usageSnapshot`:
//! the account usage file is authoritative; rate limits embedded in recent
//! session events are a labeled fallback; a local budget estimate is the last
//! resort. Produces display-ready values and rotating dock cards.

use crate::settings::Settings;
use crate::telemetry::Telemetry;
use crate::usagefile::{read_external_state, ExternalUsageState};
use crate::util;
use serde::Serialize;
use serde_json::Value;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct UsageMetric {
    pub title: String,
    pub value: String,
    pub icon: String,
    pub tint: String,
}

#[derive(Debug, Clone, Serialize, Default, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct DockCard {
    pub title: String,
    pub subtitle: String,
    pub short_label: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub percent_remaining: Option<f64>,
    pub kind: String,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct ResolvedLimit {
    pub name: String,
    pub percent_remaining: f64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reset_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reset_label: Option<String>,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct UsageView {
    pub percent_remaining: f64,
    pub primary_title: String,
    pub primary_subtitle: String,
    pub window_used_tokens: i64,
    pub today_used_tokens: i64,
    pub budget_tokens: i64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reset_at: Option<i64>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub reset_label: Option<String>,
    pub source: String,
    pub metrics: Vec<UsageMetric>,
    pub dock_cards: Vec<DockCard>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub last_updated_at: Option<i64>,
    pub is_stale: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub warning: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub credits_balance: Option<String>,
    pub limits: Vec<ResolvedLimit>,
    pub status_label: String,
    pub reset_summary: String,
    pub status_tint: String,
    pub plan_type: Option<String>,
    pub reset_credit_title: Option<String>,
}

impl UsageView {
    #[allow(dead_code)]
    pub fn loading() -> Self {
        Self {
            percent_remaining: 1.0,
            primary_title: "Loading usage".into(),
            primary_subtitle: "Reading local Codex data".into(),
            source: "Loading".into(),
            is_stale: true,
            warning: Some("Waiting for the first local usage snapshot.".into()),
            status_label: "Loading • No update timestamp".into(),
            reset_summary: "No reset time exposed locally yet".into(),
            status_tint: "secondary".into(),
            ..Default::default()
        }
    }

    pub fn unavailable() -> Self {
        Self {
            percent_remaining: 0.0,
            primary_title: "Usage unavailable".into(),
            primary_subtitle: "No authoritative usage data found".into(),
            source: "No account snapshot".into(),
            is_stale: true,
            warning: Some(
                "Launch Codex or install the local usage sync to provide current limits.".into(),
            ),
            status_label: "No account snapshot • No update timestamp".into(),
            reset_summary: "No reset time exposed locally yet".into(),
            status_tint: "secondary".into(),
            ..Default::default()
        }
    }
}

pub struct UsageInputs<'a> {
    pub settings: &'a Settings,
    pub telemetry: &'a Telemetry,
    pub projects: &'a [crate::sessions::ProjectView],
    pub sessions: &'a [crate::sessions::SessionView],
    pub session_files: &'a [crate::sessions::SessionFile],
    pub plan_type: Option<String>,
    pub reset_credit_title: Option<String>,
    pub now: i64,
}

pub fn resolve(inputs: &UsageInputs<'_>) -> UsageView {
    let mut view = if let Some((state, modified)) = read_external_state(inputs.settings) {
        external_usage_snapshot(&state, modified, inputs)
    } else if let Some(live) = live_rate_limit_snapshot(inputs) {
        live
    } else if inputs.session_files.is_empty() {
        UsageView::unavailable()
    } else {
        estimated_usage_snapshot(inputs)
    };
    view.plan_type = inputs.plan_type.clone();
    view.reset_credit_title = inputs.reset_credit_title.clone();
    view.status_label = status_label(&view, inputs.now);
    view.status_tint = status_tint(&view);
    view.reset_summary = util::reset_summary(view.reset_at, inputs.now);
    view
}

fn freshness(updated_at: Option<i64>, authoritative: bool, now: i64) -> (bool, Option<String>) {
    if !authoritative {
        return (
            true,
            Some("Using recent session telemetry; account snapshot unavailable.".into()),
        );
    }
    let Some(updated) = updated_at else {
        return (true, Some("The usage snapshot has no update timestamp.".into()));
    };
    if now - updated > 15 * 60 {
        return (
            true,
            Some("The usage snapshot is more than 15 minutes old.".into()),
        );
    }
    (false, None)
}

fn usage_tint(percent_remaining: f64) -> &'static str {
    if percent_remaining >= 0.45 {
        "blue"
    } else if percent_remaining >= 0.20 {
        "orange"
    } else {
        "red"
    }
}

fn status_tint(view: &UsageView) -> String {
    if view.source == "Loading" || view.source == "No account snapshot" {
        "secondary".to_string()
    } else if view.is_stale {
        "orange".to_string()
    } else if view.source.to_ascii_lowercase().contains("estimate") {
        "orange".to_string()
    } else {
        "green".to_string()
    }
}

fn status_label(view: &UsageView, now: i64) -> String {
    let update_label = match view.last_updated_at {
        Some(updated) => {
            let age = (now - updated).max(0);
            if age < 10 {
                "Updated just now".to_string()
            } else {
                format!("Updated {}", util::relative_time(updated, now))
            }
        }
        None => "No update timestamp".to_string(),
    };
    format!("{} • {}", view.source, update_label)
}

fn percent_text(value: f64) -> String {
    format!("{}%", (value * 100.0).round() as i64)
}

// ---------------------------------------------------------------------------
// 1. Account usage.json — authoritative
// ---------------------------------------------------------------------------

fn external_usage_snapshot(
    state: &ExternalUsageState,
    file_modified: i64,
    inputs: &UsageInputs<'_>,
) -> UsageView {
    let primary = state.limits.first();
    let percent_remaining = if let Some(remaining) = primary
        .and_then(|l| l.percent_remaining.map(|v| v as f64))
        .or_else(|| primary.and_then(|l| l.remaining_percent.map(|v| v as f64)))
        .or_else(|| state.percent_remaining)
        .or_else(|| state.remaining_percent)
    {
        util::percent_fraction(remaining)
    } else if let Some(used) = primary
        .and_then(|l| l.percent_used.map(|v| v as f64))
        .or_else(|| primary.and_then(|l| l.used_percent.map(|v| v as f64)))
        .or_else(|| state.percent_used)
        .or_else(|| state.used_percent)
    {
        1.0 - util::percent_fraction(used)
    } else if let (Some(remaining), Some(limit)) = (
        primary.and_then(|l| l.remaining).or(state.remaining),
        primary.and_then(|l| l.limit).or(state.limit),
    ) {
        if limit > 0 {
            (remaining as f64 / limit as f64).clamp(0.0, 1.0)
        } else {
            1.0
        }
    } else {
        1.0
    };

    let reset_at = primary
        .and_then(|l| l.reset_at.as_deref())
        .or(state.reset_at.as_deref())
        .and_then(|s| util::parse_timestamp(Some(s)));
    let reset_label = primary
        .and_then(|l| l.reset_label.clone())
        .or_else(|| state.reset_label.clone());
    let used = primary.and_then(|l| l.used).or(state.used).unwrap_or(0);
    let limit = primary.and_then(|l| l.limit).or(state.limit).unwrap_or(0);
    let primary_name = primary
        .map(|l| l.name.clone())
        .or_else(|| state.title.clone())
        .unwrap_or_else(|| "Weekly usage".to_string());
    let primary_reset = reset_label
        .as_ref()
        .map(|label| format!("Resets {label}"))
        .unwrap_or_else(|| "Account usage limit".to_string());
    let last_updated = state
        .updated_at
        .as_deref()
        .and_then(|s| util::parse_timestamp(Some(s)))
        .unwrap_or(file_modified);
    let (is_stale, warning) = freshness(Some(last_updated), true, inputs.now);

    let observed_window = inputs.telemetry.window_usage.effective_total();
    let observed_today = inputs.telemetry.today_usage.effective_total();

    let mut metrics = Vec::new();
    if let Some(credits) = util::credit_display(state.credits_balance.as_deref()) {
        metrics.push(UsageMetric {
            title: "Prepaid credits".into(),
            value: credits.clone(),
            icon: "creditcard".into(),
            tint: "blue".into(),
        });
    }
    for entry in &state.limits {
        let percent = normalized_limit_percent(entry).unwrap_or(percent_remaining);
        metrics.push(UsageMetric {
            title: entry.name.clone(),
            value: format!("{} left", percent_text(percent)),
            icon: entry
                .system_image
                .clone()
                .unwrap_or_else(|| "gauge".to_string()),
            tint: usage_tint(percent).to_string(),
        });
    }
    if metrics.is_empty() {
        metrics.push(UsageMetric {
            title: "Remaining".into(),
            value: format!("{} left", percent_text(percent_remaining)),
            icon: "battery".into(),
            tint: usage_tint(percent_remaining).to_string(),
        });
    }

    let mut dock_cards = Vec::new();
    for entry in &state.limits {
        let percent = normalized_limit_percent(entry).unwrap_or(percent_remaining);
        let reset = entry
            .reset_label
            .as_ref()
            .map(|label| format!("Resets {label}"))
            .or_else(|| entry.subtitle.clone())
            .unwrap_or_else(|| "Weekly usage limit".to_string());
        dock_cards.push(DockCard {
            title: format!("{} Left", percent_text(percent)),
            subtitle: format!("{} • {}", util::short_usage_label(&entry.name), reset),
            short_label: util::short_usage_label(&entry.name),
            percent_remaining: Some(percent),
            kind: "usage".into(),
        });
    }
    if let Some(credits) = util::credit_display(state.credits_balance.as_deref()) {
        dock_cards.push(DockCard {
            title: format!("{credits} credits"),
            subtitle: "Prepaid balance".into(),
            short_label: "Credits".into(),
            percent_remaining: None,
            kind: "credits".into(),
        });
    }

    UsageView {
        percent_remaining: percent_remaining.clamp(0.0, 1.0),
        primary_title: format!("{} Left", percent_text(percent_remaining)),
        primary_subtitle: state
            .subtitle
            .clone()
            .unwrap_or_else(|| format!("{primary_name} • {primary_reset}")),
        window_used_tokens: if observed_window > 0 { observed_window } else { used },
        today_used_tokens: if observed_today > 0 {
            observed_today
        } else {
            state.today_used.unwrap_or(used)
        },
        budget_tokens: limit,
        reset_at,
        reset_label,
        source: state.source.clone().unwrap_or_else(|| "Codex account limits".into()),
        metrics,
        dock_cards,
        last_updated_at: Some(last_updated),
        is_stale,
        warning,
        credits_balance: util::credit_display(state.credits_balance.as_deref()),
        limits: state
            .limits
            .iter()
            .map(|entry| ResolvedLimit {
                name: entry.name.clone(),
                percent_remaining: normalized_limit_percent(entry).unwrap_or(percent_remaining),
                reset_at: entry.reset_at.as_deref().and_then(|s| util::parse_timestamp(Some(s))),
                reset_label: entry.reset_label.clone(),
            })
            .collect(),
        ..Default::default()
    }
}

fn normalized_limit_percent(entry: &crate::usagefile::ExternalUsageLimit) -> Option<f64> {
    if let Some(remaining) = entry.percent_remaining.map(|v| v as f64).or(entry.remaining_percent.map(|v| v as f64)) {
        return Some(util::percent_fraction(remaining));
    }
    if let Some(used) = entry.percent_used.map(|v| v as f64).or(entry.used_percent.map(|v| v as f64)) {
        return Some(1.0 - util::percent_fraction(used));
    }
    if let (Some(remaining), Some(limit)) = (entry.remaining, entry.limit) {
        if limit > 0 {
            return Some((remaining as f64 / limit as f64).clamp(0.0, 1.0));
        }
    }
    None
}

// ---------------------------------------------------------------------------
// 2. Rate limits embedded in recent session `token_count` events
// ---------------------------------------------------------------------------

#[derive(Debug, Clone)]
struct LiveSample {
    id: String,
    name: Option<String>,
    used_percent: f64,
    window_minutes: Option<i64>,
    resets_at: Option<i64>,
    credits_balance: Option<String>,
    unlimited_credits: bool,
    timestamp: i64,
}

impl LiveSample {
    fn is_general(&self) -> bool {
        self.id == "codex" || self.name.is_none()
    }

    fn display_name(&self) -> String {
        self.name.clone().unwrap_or_else(|| "General".to_string())
    }
}

fn live_rate_limit_snapshot(inputs: &UsageInputs<'_>) -> Option<UsageView> {
    let mut latest_by_id: std::collections::HashMap<String, LiveSample> = Default::default();

    for file in inputs.session_files.iter().take(24) {
        let Some(text) = tail_text(&file.path, 96 * 1024) else {
            continue;
        };
        for line in text.lines().rev() {
            let Ok(value) = serde_json::from_str::<Value>(line) else { continue };
            if value.get("type").and_then(|t| t.as_str()) != Some("event_msg") {
                continue;
            }
            let Some(payload) = value.get("payload") else { continue };
            if payload.get("type").and_then(|t| t.as_str()) != Some("token_count") {
                continue;
            }
            let Some(limits) = payload.get("rate_limits").or_else(|| payload.get("rateLimits")) else {
                continue;
            };
            let Some(primary) = limits.get("primary") else { continue };
            let used_percent = primary
                .get("used_percent")
                .or_else(|| primary.get("usedPercent"))
                .and_then(|v| v.as_f64())?;
            let window_minutes = primary
                .get("window_minutes")
                .or_else(|| primary.get("windowDurationMins"))
                .and_then(|v| v.as_i64());
            let resets_at = primary
                .get("resets_at")
                .or_else(|| primary.get("resetsAt"))
                .and_then(|v| v.as_i64());
            let id = limits
                .get("limit_id")
                .or_else(|| limits.get("limitId"))
                .and_then(|v| v.as_str())
                .or_else(|| limits.get("limit_name").and_then(|v| v.as_str()))
                .unwrap_or("codex")
                .to_string();
            let timestamp = util::parse_timestamp(value.get("timestamp").and_then(|t| t.as_str()))
                .unwrap_or(file.modified);
            if let Some(existing) = latest_by_id.get(&id) {
                if existing.timestamp >= timestamp {
                    continue;
                }
            }
            let credits = limits.get("credits");
            latest_by_id.insert(
                id.clone(),
                LiveSample {
                    id,
                    name: limits
                        .get("limit_name")
                        .or_else(|| limits.get("limitName"))
                        .and_then(|v| v.as_str())
                        .map(|s| s.to_string()),
                    used_percent,
                    window_minutes,
                    resets_at,
                    credits_balance: credits
                        .and_then(|c| c.get("balance"))
                        .and_then(|b| b.as_str())
                        .map(|s| s.to_string()),
                    unlimited_credits: credits
                        .and_then(|c| c.get("unlimited"))
                        .and_then(|u| u.as_bool())
                        .unwrap_or(false),
                    timestamp,
                },
            );
        }
        let has_general = latest_by_id.values().any(LiveSample::is_general);
        let has_named = latest_by_id.values().any(|s| !s.is_general());
        if has_general && has_named {
            break;
        }
    }

    if latest_by_id.is_empty() {
        return None;
    }

    let mut samples: Vec<LiveSample> = latest_by_id.into_values().collect();
    samples.sort_by(|a, b| {
        b.is_general()
            .cmp(&a.is_general())
            .then_with(|| a.display_name().to_lowercase().cmp(&b.display_name().to_lowercase()))
    });
    let primary_sample = samples.first()?;
    let now = inputs.now;

    let mut limits = Vec::new();
    let mut metrics = Vec::new();
    let mut dock_cards = Vec::new();
    for sample in &samples {
        let (percent_remaining, reset_at) =
            resolved_rate_limit(sample.used_percent, sample.window_minutes, sample.resets_at, now);
        let display = sample.display_name();
        limits.push(ResolvedLimit {
            name: display.clone(),
            percent_remaining,
            reset_at,
            reset_label: reset_at.map(util::short_reset_label),
        });
        metrics.push(UsageMetric {
            title: display.clone(),
            value: format!("{} left", percent_text(percent_remaining)),
            icon: if display.to_ascii_lowercase().contains("spark") {
                "sparkles".into()
            } else {
                "gauge".into()
            },
            tint: usage_tint(percent_remaining).into(),
        });
        dock_cards.push(DockCard {
            title: format!("{} Left", percent_text(percent_remaining)),
            subtitle: format!(
                "{} • {}",
                util::short_usage_label(&display),
                reset_at
                    .map(|epoch| format!("Resets {}", util::short_reset_label(epoch)))
                    .unwrap_or_else(|| "Weekly usage".into())
            ),
            short_label: util::short_usage_label(&display),
            percent_remaining: Some(percent_remaining),
            kind: "usage".into(),
        });
    }
    let primary_limit = limits.first()?.clone();

    let credits_sample = samples
        .iter()
        .find(|s| s.unlimited_credits || s.credits_balance.is_some())
        .unwrap_or(primary_sample);
    let credits_value = if credits_sample.unlimited_credits {
        Some("Unlimited".to_string())
    } else {
        credits_sample
            .credits_balance
            .as_deref()
            .and_then(|s| util::credit_display(Some(s)))
    };
    if let Some(credits) = credits_value.clone() {
        metrics.insert(
            0,
            UsageMetric {
                title: "Prepaid credits".into(),
                value: credits.clone(),
                icon: "creditcard".into(),
                tint: "blue".into(),
            },
        );
        dock_cards.push(DockCard {
            title: format!("{credits} credits"),
            subtitle: "Prepaid balance".into(),
            short_label: "Credits".into(),
            percent_remaining: None,
            kind: "credits".into(),
        });
    }

    let last_updated = samples.iter().map(|s| s.timestamp).max();
    let (is_stale, warning) = freshness(last_updated, false, now);

    Some(UsageView {
        percent_remaining: primary_limit.percent_remaining,
        primary_title: format!("{} Left", percent_text(primary_limit.percent_remaining)),
        primary_subtitle: format!(
            "{} • {}",
            primary_limit.name,
            primary_limit
                .reset_label
                .as_ref()
                .map(|label| format!("Resets {label}"))
                .unwrap_or_else(|| "Weekly usage".to_string())
        ),
        window_used_tokens: inputs.telemetry.window_usage.effective_total(),
        today_used_tokens: inputs.telemetry.today_usage.effective_total(),
        budget_tokens: 0,
        reset_at: primary_limit.reset_at,
        reset_label: primary_limit.reset_label.clone(),
        source: "Session telemetry fallback".into(),
        metrics,
        dock_cards,
        last_updated_at: last_updated,
        is_stale,
        warning,
        credits_balance: credits_value,
        limits,
        ..Default::default()
    })
}

fn resolved_rate_limit(used_percent: f64, window_minutes: Option<i64>, resets_at: Option<i64>, now: i64) -> (f64, Option<i64>) {
    let mut reset_at = resets_at;
    let mut remaining = (1.0 - used_percent / 100.0).clamp(0.0, 1.0);
    if let Some(original) = reset_at {
        if original <= now {
            remaining = 1.0;
            if let Some(window) = window_minutes.filter(|w| *w > 0) {
                let interval = window * 60;
                let elapsed_windows = (now - original) / interval + 1;
                reset_at = Some(original + elapsed_windows * interval);
            }
        }
    }
    (remaining, reset_at)
}

fn tail_text(path: &Path, max_bytes: u64) -> Option<String> {
    use std::io::{Read, Seek, SeekFrom};
    let mut file = std::fs::File::open(path).ok()?;
    let size = file.metadata().ok()?.len();
    let read_size = size.min(max_bytes);
    file.seek(SeekFrom::Start(size - read_size)).ok()?;
    let mut buffer = vec![0u8; read_size as usize];
    file.read_exact(&mut buffer).ok()?;
    String::from_utf8(buffer).ok()
}

// ---------------------------------------------------------------------------
// 3. Local budget estimate
// ---------------------------------------------------------------------------

fn estimated_usage_snapshot(inputs: &UsageInputs<'_>) -> UsageView {
    let budget = inputs.settings.usage_budget_tokens();
    let window_hours = inputs.settings.usage_window_hours;
    let now = inputs.now;
    let window_start = now as f64 - window_hours * 3600.0;
    let _ = window_start;
    let used = inputs.telemetry.window_usage.effective_total().max(0);
    let today_used = inputs.telemetry.today_usage.effective_total().max(0);
    let remaining = (budget - used).max(0);
    let percent_remaining = if budget > 0 {
        remaining as f64 / budget as f64
    } else {
        1.0
    };
    let reset_date = now + (window_hours * 3600.0) as i64;
    let active_project = inputs
        .projects
        .first()
        .map(|p| p.name.clone())
        .or_else(|| inputs.sessions.first().map(|s| s.project_name.clone()))
        .unwrap_or_else(|| "No active project".to_string());
    let last_updated = inputs.session_files.first().map(|f| f.modified);
    let (is_stale, warning) = freshness(last_updated, false, now);

    UsageView {
        percent_remaining: percent_remaining.clamp(0.0, 1.0),
        primary_title: format!("{} Remaining", percent_text(percent_remaining)),
        primary_subtitle: format!("{} used in {}h window", util::compact_tokens_plain(used), window_hours as i64),
        window_used_tokens: used,
        today_used_tokens: today_used,
        budget_tokens: budget,
        reset_at: Some(reset_date),
        reset_label: None,
        source: "Local activity estimate".into(),
        metrics: vec![
            UsageMetric {
                title: "Window budget".into(),
                value: format!("{} left", util::compact_tokens_plain(remaining)),
                icon: "gauge".into(),
                tint: usage_tint(percent_remaining).into(),
            },
            UsageMetric {
                title: "Today used".into(),
                value: util::compact_tokens_plain(today_used),
                icon: "calendar".into(),
                tint: "blue".into(),
            },
            UsageMetric {
                title: "Active project".into(),
                value: active_project,
                icon: "folder".into(),
                tint: "orange".into(),
            },
        ],
        dock_cards: Vec::new(),
        last_updated_at: last_updated,
        is_stale,
        warning: Some(warning.unwrap_or_else(|| {
            "Using a local activity estimate; account snapshot unavailable.".into()
        })),
        ..Default::default()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rate_limit_remaining_and_rollover() {
        let now = 1_000_000;
        let (remaining, reset) = resolved_rate_limit(21.0, Some(300), Some(now + 3_600), now);
        assert!((remaining - 0.79).abs() < 1e-9);
        assert_eq!(reset, Some(now + 3_600));

        // A reset already passed rolls forward whole windows and refills.
        let (remaining, reset) = resolved_rate_limit(100.0, Some(300), Some(now - 100), now);
        assert!((remaining - 1.0).abs() < 1e-9);
        assert_eq!(reset, Some(now - 100 + 1 * 18_000));
    }

    #[test]
    fn marketplace_shapes_resolve_remaining() {
        let cases = [(21.0, 0.79), (100.0, 0.0), (0.0, 1.0), (50.0, 0.5)];
        for (used, expected) in cases {
            let (remaining, _) = resolved_rate_limit(used, None, None, 0);
            assert!((remaining - expected).abs() < 1e-9);
        }
    }
}
