//! Analytics port of `CodexV6AnalyticsBuilder`: a bounded 30-day event cache,
//! quota-pace history, cost estimates, daily/hourly buckets, model/project
//! breakdowns, and read-only workspace git health.

use crate::settings::state_root;
use crate::telemetry::{BurnSample, Telemetry, TokenUsage};
use crate::usage::UsageView;
use crate::util;
use chrono::{TimeZone, Timelike};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::HashMap;
use std::path::Path;

const RETENTION_SECS: i64 = 30 * 24 * 60 * 60;
const MAX_EVENTS: usize = 4_096;
const PACE_RETENTION_SECS: i64 = 45 * 24 * 60 * 60;
const MAX_PACE_POINTS: usize = 512;

#[derive(Debug, Clone, Serialize, Deserialize)]
struct CachedEvent {
    timestamp: i64,
    model: String,
    reasoning_effort: String,
    project_name: String,
    usage: TokenUsage,
}

impl CachedEvent {
    /// Data identity of an event: timestamp + project + token mix. The model
    /// attribution is deliberately NOT part of it — a parser fix can
    /// legitimately re-attribute a session's events, and the fresh parse
    /// must replace whatever the cache recorded earlier.
    fn identity(&self) -> String {
        [
            self.timestamp.to_string(),
            self.project_name.clone(),
            self.usage.input_tokens.to_string(),
            self.usage.cached_input_tokens.to_string(),
            self.usage.output_tokens.to_string(),
            self.usage.reasoning_output_tokens.to_string(),
        ]
        .join("|")
    }
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AnalyticsDay {
    pub day_key: String,
    pub tokens: i64,
    pub event_count: i64,
    pub estimated_cost_usd: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AnalyticsHour {
    pub weekday: u32,
    pub hour: u32,
    pub tokens: i64,
    pub event_count: i64,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AnalyticsModel {
    pub model: String,
    pub reasoning_effort: String,
    pub tokens: i64,
    pub event_count: i64,
    pub estimated_cost_usd: Option<f64>,
}

impl AnalyticsModel {
    #[allow(dead_code)]
    pub fn id(&self) -> String {
        format!("{}|{}", self.model, self.reasoning_effort)
    }
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct AnalyticsProject {
    pub name: String,
    pub tokens: i64,
    pub event_count: i64,
    pub session_count: i64,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct QuotaPace {
    pub used_percent: f64,
    pub percent_per_hour: Option<f64>,
    pub projected_exhaustion_at: Option<i64>,
    pub reset_at: Option<i64>,
    pub will_last_to_reset: Option<bool>,
    pub sample_count: usize,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct SourceStatus {
    pub id: String,
    pub title: String,
    pub state: String,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct WorkspaceHealth {
    pub checked_project_count: usize,
    pub repository_count: usize,
    pub dirty_repository_count: usize,
    pub dirty_file_count: usize,
    pub active_project: Option<String>,
    pub active_branch: Option<String>,
}

impl WorkspaceHealth {
    #[allow(dead_code)]
    pub fn is_available(&self) -> bool {
        self.repository_count > 0
    }
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct OfficialActivity {
    pub lifetime_tokens: Option<i64>,
    pub peak_daily_tokens: Option<i64>,
    pub current_streak_days: Option<i64>,
    pub longest_streak_days: Option<i64>,
    pub daily: Vec<AnalyticsDay>,
}

impl OfficialActivity {
    pub fn has_data(&self) -> bool {
        self.lifetime_tokens.is_some() || self.peak_daily_tokens.is_some() || !self.daily.is_empty()
    }
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Analytics {
    pub today_tokens: i64,
    pub last7_days_tokens: i64,
    pub last30_days_tokens: i64,
    pub daily: Vec<AnalyticsDay>,
    pub hourly: Vec<AnalyticsHour>,
    pub models: Vec<AnalyticsModel>,
    pub projects: Vec<AnalyticsProject>,
    pub context_percent: Option<f64>,
    pub peak_context_percent: Option<f64>,
    pub burn_per_minute: Option<f64>,
    pub estimated_cost_usd: Option<f64>,
    pub cost_coverage: f64,
    pub quota_pace: Option<QuotaPace>,
    pub official_activity: Option<OfficialActivity>,
    pub source_statuses: Vec<SourceStatus>,
    pub cached_event_count: usize,
    pub daily_goal_tokens: i64,
    pub workspace_health: WorkspaceHealth,
    pub updated_at: Option<i64>,

    pub today_vs_previous_day: Option<f64>,
}

#[derive(Debug, Clone, Deserialize, Serialize, Default)]
struct PacePoint {
    timestamp: i64,
    used_fraction: f64,
    #[serde(default)]
    reset_at: Option<i64>,
}

#[derive(Debug, Deserialize, Serialize)]
struct AnalyticsDocument {
    version: i32,
    events: Vec<CachedEvent>,
}

#[derive(Debug, Deserialize, Serialize)]
struct PaceDocument {
    version: i32,
    points: Vec<PacePoint>,
}

fn cache_path(name: &str) -> std::path::PathBuf {
    state_root().join(name)
}

fn merge_samples(samples: &[BurnSample], now: i64) -> Vec<CachedEvent> {
    let path = cache_path("analytics-v6.json");
    let cached: Vec<CachedEvent> = std::fs::read(&path)
        .ok()
        .and_then(|data| serde_json::from_slice::<AnalyticsDocument>(&data).ok())
        .filter(|doc| doc.version == 1)
        .map(|doc| doc.events)
        .unwrap_or_default();

    let cutoff = now - RETENTION_SECS;
    // Keyed merge: fresh samples overwrite cached entries with the same data
    // identity, so re-parses (e.g. a fixed model attribution) win over
    // whatever the cache recorded first.
    let mut merged: HashMap<String, CachedEvent> = HashMap::new();
    for event in cached {
        if event.timestamp >= cutoff {
            merged.insert(event.identity(), event);
        }
    }
    for sample in samples {
        let event = CachedEvent {
            timestamp: sample.timestamp,
            model: sample.model.clone(),
            reasoning_effort: sample.reasoning_effort.clone(),
            project_name: sample.project_name.clone(),
            usage: sample.usage,
        };
        if event.timestamp >= cutoff {
            merged.insert(event.identity(), event);
        }
    }
    let mut events: Vec<CachedEvent> = merged.into_values().collect();
    events.sort_by_key(|event| event.timestamp);
    if events.len() > MAX_EVENTS {
        let start = events.len() - MAX_EVENTS;
        events.drain(0..start);
    }
    let document = AnalyticsDocument {
        version: 1,
        events: events.clone(),
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(data) = serde_json::to_vec(&document) {
        let _ = std::fs::write(&path, data);
    }
    events
}

fn record_quota_pace(usage: &UsageView, now: i64) -> QuotaPace {
    let path = cache_path("quota-pace-v6.json");
    let mut points: Vec<PacePoint> = std::fs::read(&path)
        .ok()
        .and_then(|data| serde_json::from_slice::<PaceDocument>(&data).ok())
        .filter(|doc| doc.version == 1)
        .map(|doc| doc.points)
        .unwrap_or_default();

    let usable = usage.source != "Loading"
        && usage.source != "No account snapshot"
        && usage.last_updated_at.is_some();

    let current = PacePoint {
        timestamp: now,
        used_fraction: (1.0 - usage.percent_remaining).clamp(0.0, 1.0),
        reset_at: usage.reset_at,
    };
    if !usable {
        return QuotaPace {
            used_percent: current.used_fraction * 100.0,
            reset_at: usage.reset_at,
            sample_count: points.len(),
            ..Default::default()
        };
    }

    let previous = points.last().cloned();
    if previous.is_none() || now - previous.as_ref().unwrap().timestamp >= 60 {
        points.push(current.clone());
    }
    points.retain(|point| now - point.timestamp <= PACE_RETENTION_SECS);
    if points.len() > MAX_PACE_POINTS {
        let start = points.len() - MAX_PACE_POINTS;
        points.drain(0..start);
    }
    let document = PaceDocument {
        version: 1,
        points: points.clone(),
    };
    if let Some(parent) = path.parent() {
        let _ = std::fs::create_dir_all(parent);
    }
    if let Ok(data) = serde_json::to_vec(&document) {
        let _ = std::fs::write(&path, data);
    }

    let Some(previous) = previous else {
        return QuotaPace {
            used_percent: current.used_fraction * 100.0,
            reset_at: usage.reset_at,
            sample_count: points.len(),
            ..Default::default()
        };
    };
    let Some(latest) = points.last() else {
        return QuotaPace::default();
    };
    if latest.timestamp <= previous.timestamp {
        return QuotaPace {
            used_percent: current.used_fraction * 100.0,
            reset_at: usage.reset_at,
            sample_count: points.len(),
            ..Default::default()
        };
    }

    let hours = (latest.timestamp - previous.timestamp) as f64 / 3600.0;
    let percent_per_hour = if hours > 0.0 {
        Some(((latest.used_fraction - previous.used_fraction) * 100.0 / hours).max(0.0))
    } else {
        None
    };
    let projected = percent_per_hour.and_then(|rate| {
        if rate > 0.001 {
            let remaining_percent = 100.0 - latest.used_fraction * 100.0;
            Some(now + ((remaining_percent / rate).max(0.0) * 3600.0) as i64)
        } else {
            None
        }
    });
    let will_last = projected
        .zip(usage.reset_at)
        .map(|(projected, reset)| projected >= reset);

    QuotaPace {
        used_percent: latest.used_fraction * 100.0,
        percent_per_hour,
        projected_exhaustion_at: projected,
        reset_at: usage.reset_at,
        will_last_to_reset: will_last,
        sample_count: points.len(),
    }
}

fn estimate_cost(model: &str, usage: &TokenUsage) -> f64 {
    let model = model.to_ascii_lowercase();
    let (input_rate, output_rate) = if model.contains("luna") {
        (1e-6, 6e-6)
    } else if model.contains("terra") {
        (2.5e-6, 1.5e-5)
    } else {
        (5e-6, 3e-5)
    };
    let input = (usage.input_tokens - usage.cached_input_tokens).max(0);
    input as f64 * input_rate + usage.output_tokens.max(0) as f64 * output_rate
}

fn read_official_activity(usage_state_path: &Path) -> Option<OfficialActivity> {
    let text = std::fs::read_to_string(usage_state_path).ok()?;
    let value: Value = serde_json::from_str(&text).ok()?;
    let payload = value
        .get("officialUsage")
        .or_else(|| value.get("accountUsage"))
        .or_else(|| value.get("summary"))
        .unwrap_or(&value);
    let pick = |key: &str| -> Option<i64> {
        payload
            .get(key)
            .and_then(|v| v.as_i64())
            .or_else(|| value.get(key).and_then(|v| v.as_i64()))
    };
    let daily = payload
        .get("dailyUsageBuckets")
        .or_else(|| value.get("dailyUsageBuckets"))
        .and_then(|v| v.as_array())
        .map(|buckets| {
            buckets
                .iter()
                .filter_map(|bucket| {
                    Some(AnalyticsDay {
                        day_key: bucket.get("startDate")?.as_str()?.to_string(),
                        tokens: bucket.get("tokens")?.as_i64()?.max(0),
                        event_count: 0,
                        estimated_cost_usd: None,
                    })
                })
                .collect::<Vec<_>>()
        })
        .unwrap_or_default();

    let official = OfficialActivity {
        lifetime_tokens: pick("lifetimeTokens"),
        peak_daily_tokens: pick("peakDailyTokens"),
        current_streak_days: pick("currentStreakDays"),
        longest_streak_days: pick("longestStreakDays"),
        daily,
    };
    official.has_data().then_some(official)
}

fn read_workspace_health(sessions: &[crate::sessions::SessionView]) -> WorkspaceHealth {
    let mut seen = std::collections::HashSet::new();
    let mut urls: Vec<String> = Vec::new();
    for session in sessions {
        if seen.insert(session.project_path.clone()) {
            urls.push(session.project_path.clone());
            if urls.len() == 8 {
                break;
            }
        }
    }

    let mut health = WorkspaceHealth {
        checked_project_count: urls.len(),
        active_project: sessions
            .iter()
            .find(|s| s.is_active)
            .or_else(|| sessions.first())
            .map(|s| s.project_name.clone()),
        ..Default::default()
    };
    for url in urls {
        let Some((branch, dirty_file_count)) = git_status(Path::new(&url)) else {
            continue;
        };
        health.repository_count += 1;
        health.dirty_file_count += dirty_file_count;
        if dirty_file_count > 0 {
            health.dirty_repository_count += 1;
        }
        if health.active_branch.is_none() {
            health.active_branch = branch;
        }
    }
    health
}

fn git_status(path: &Path) -> Option<(Option<String>, usize)> {
    let output = std::process::Command::new("git")
        .args([
            "-C",
            path.to_str()?,
            "status",
            "--porcelain=v1",
            "--branch",
            "--untracked-files=normal",
        ])
        .stderr(std::process::Stdio::null())
        .output()
        .ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout);
    let mut branch = None;
    let mut dirty = 0usize;
    for line in text.lines().filter(|l| !l.is_empty()) {
        if let Some(rest) = line.strip_prefix("## ") {
            branch = rest.split("...").next().map(|s| s.trim().to_string());
        } else {
            dirty += 1;
        }
    }
    Some((branch, dirty))
}

#[allow(clippy::too_many_arguments)]
pub fn build(
    telemetry: &Telemetry,
    usage: &UsageView,
    sessions: &[crate::sessions::SessionView],
    usage_state_path: &Path,
    daily_goal_tokens: i64,
    now: i64,
) -> Analytics {
    let cached_events = merge_samples(&telemetry.samples, now);
    let thirty_days_ago = now - 30 * 24 * 60 * 60;
    let seven_days_ago = now - 7 * 24 * 60 * 60;
    let today_start = today_start_epoch(now);
    let events: Vec<&CachedEvent> = cached_events
        .iter()
        .filter(|event| event.timestamp >= thirty_days_ago && event.timestamp <= now)
        .collect();

    let mut days: HashMap<String, (i64, i64, f64)> = HashMap::new();
    let mut hours: HashMap<(u32, u32), (i64, i64)> = HashMap::new();
    let mut models: HashMap<String, AnalyticsModel> = HashMap::new();
    let mut projects: HashMap<String, AnalyticsProject> = HashMap::new();
    let mut total_cost = 0.0f64;

    for event in &events {
        let tokens = event.usage.effective_total().max(0);
        let cost = estimate_cost(&event.model, &event.usage);
        total_cost += cost;
        let day_key = util::day_key(event.timestamp);
        let day = days.entry(day_key).or_insert((0, 0, 0.0));
        day.0 += tokens;
        day.1 += 1;
        day.2 += cost;

        if event.timestamp >= seven_days_ago {
            let local = chrono::Local.timestamp_opt(event.timestamp, 0).single();
            if let Some(local) = local {
                use chrono::Datelike;
                let weekday = local.weekday().number_from_sunday();
                let hour = local.hour();
                let entry = hours.entry((weekday, hour)).or_insert((0, 0));
                entry.0 += tokens;
                entry.1 += 1;
            }
        }

        let model_key = format!("{}|{}", event.model, event.reasoning_effort);
        let entry = models
            .entry(model_key.clone())
            .or_insert_with(|| AnalyticsModel {
                model: event.model.clone(),
                reasoning_effort: event.reasoning_effort.clone(),
                ..Default::default()
            });
        entry.tokens += tokens;
        entry.event_count += 1;
        entry.estimated_cost_usd = Some(entry.estimated_cost_usd.unwrap_or(0.0) + cost);

        let project = projects
            .entry(event.project_name.clone())
            .or_insert_with(|| AnalyticsProject {
                name: event.project_name.clone(),
                ..Default::default()
            });
        project.tokens += tokens;
        project.event_count += 1;
    }
    for session in sessions {
        let project = projects
            .entry(session.project_name.clone())
            .or_insert_with(|| AnalyticsProject {
                name: session.project_name.clone(),
                ..Default::default()
            });
        project.session_count += 1;
    }

    let mut daily: Vec<AnalyticsDay> = days
        .into_iter()
        .map(|(day_key, (tokens, count, cost))| AnalyticsDay {
            day_key,
            tokens,
            event_count: count,
            estimated_cost_usd: Some(cost),
        })
        .collect();
    daily.sort_by(|a, b| a.day_key.cmp(&b.day_key));

    let mut hourly: Vec<AnalyticsHour> = hours
        .into_iter()
        .map(|((weekday, hour), (tokens, count))| AnalyticsHour {
            weekday,
            hour,
            tokens,
            event_count: count,
        })
        .collect();
    hourly.sort_by(|a, b| (a.weekday, a.hour).cmp(&(b.weekday, b.hour)));

    let mut model_list: Vec<AnalyticsModel> = models.into_values().collect();
    model_list.sort_by(|a, b| b.tokens.cmp(&a.tokens));

    let mut project_list: Vec<AnalyticsProject> = projects.into_values().collect();
    project_list.sort_by(|a, b| b.tokens.cmp(&a.tokens).then_with(|| a.name.cmp(&b.name)));

    let today_tokens = events
        .iter()
        .filter(|event| event.timestamp >= today_start)
        .map(|event| event.usage.effective_total().max(0))
        .sum::<i64>();
    let last7_tokens = events
        .iter()
        .filter(|event| event.timestamp >= seven_days_ago)
        .map(|event| event.usage.effective_total().max(0))
        .sum::<i64>();

    let context_percent = match (
        telemetry.latest_context_usage,
        telemetry.latest_context_window,
    ) {
        (Some(context), Some(window)) if window > 0 => {
            Some((context.effective_total() as f64 / window as f64).clamp(0.0, 1.0))
        }
        _ => None,
    };
    let peak_context_percent = telemetry
        .latest_context_window
        .filter(|window| *window > 0)
        .map(|window| (telemetry.peak_context_tokens as f64 / window as f64).clamp(0.0, 1.0));

    let official = read_official_activity(usage_state_path);
    let quota_pace = record_quota_pace(usage, now);
    let workspace_health = read_workspace_health(sessions);
    let account_healthy = usage.source != "Loading" && usage.source != "No account snapshot";
    let statuses = vec![
        SourceStatus {
            id: "local-events".into(),
            title: "Local token events".into(),
            state: if events.is_empty() {
                "Waiting".into()
            } else {
                "Ready".into()
            },
            detail: if events.is_empty() {
                "No recent token events found".into()
            } else {
                format!("{} events in the 30-day window", events.len())
            },
        },
        SourceStatus {
            id: "incremental-cache".into(),
            title: "Incremental cache".into(),
            state: if cached_events.is_empty() {
                "Waiting".into()
            } else {
                "Ready".into()
            },
            detail: if cached_events.is_empty() {
                "Cache will populate after the first refresh".into()
            } else {
                format!("Bounded local cache · {} events", cached_events.len())
            },
        },
        SourceStatus {
            id: "account-quota".into(),
            title: "Account quota".into(),
            state: if account_healthy {
                "Ready".into()
            } else {
                "Unavailable".into()
            },
            detail: usage.source.clone(),
        },
        SourceStatus {
            id: "official-activity".into(),
            title: "Official activity".into(),
            state: if official.is_none() {
                "Optional".into()
            } else {
                "Ready".into()
            },
            detail: if official.is_none() {
                "Not exposed by the current local usage file".into()
            } else {
                "Read-only aggregate activity".into()
            },
        },
    ];

    let today_vs_previous_day = if daily.len() > 1 {
        let previous = &daily[daily.len() - 2];
        if previous.tokens > 0 {
            Some(
                (daily.last().unwrap().tokens as f64 - previous.tokens as f64)
                    / previous.tokens as f64,
            )
        } else {
            None
        }
    } else {
        None
    };

    Analytics {
        today_tokens,
        last7_days_tokens: last7_tokens,
        last30_days_tokens: events
            .iter()
            .map(|e| e.usage.effective_total().max(0))
            .sum(),
        daily,
        hourly,
        models: model_list,
        projects: project_list,
        context_percent,
        peak_context_percent,
        burn_per_minute: telemetry.tokens_per_minute(60.0, now),
        estimated_cost_usd: (!events.is_empty()).then_some(total_cost),
        cost_coverage: if events.is_empty() { 0.0 } else { 1.0 },
        quota_pace: Some(quota_pace),
        official_activity: official,
        source_statuses: statuses,
        cached_event_count: cached_events.len(),
        daily_goal_tokens,
        workspace_health,
        updated_at: [telemetry.updated_at, usage.last_updated_at]
            .into_iter()
            .flatten()
            .max(),
        today_vs_previous_day,
    }
}

fn today_start_epoch(now: i64) -> i64 {
    chrono::Local
        .timestamp_opt(now, 0)
        .single()
        .map(|local| {
            use chrono::Timelike;
            local
                .with_hour(0)
                .and_then(|d| d.with_minute(0))
                .and_then(|d| d.with_second(0))
                .and_then(|d| d.with_nanosecond(0))
                .map(|d| d.timestamp())
                .unwrap_or(now)
        })
        .unwrap_or(now)
}
