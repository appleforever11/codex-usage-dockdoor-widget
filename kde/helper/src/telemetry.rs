//! Local token telemetry, a faithful port of `CodexTokenTelemetryReader`.
//! Reads the same `turn_context` / `thread_settings_applied` / `token_count`
//! envelopes with cumulative-delta attribution, head+tail file windows, and
//! per-model breakdowns.

use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::{HashMap, HashSet};
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;

const MAX_FILE_BYTES: u64 = 768 * 1024;
const HEAD_BYTES: u64 = 384 * 1024;
const MAX_CHART_SAMPLES: usize = 48;
const MAX_TELEMETRY_SESSIONS: usize = 64;

#[derive(Debug, Clone, Copy, Default, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "camelCase", default)]
pub struct TokenUsage {
    pub input_tokens: i64,
    pub cached_input_tokens: i64,
    pub cache_write_input_tokens: i64,
    pub output_tokens: i64,
    pub reasoning_output_tokens: i64,
    pub total_tokens: i64,
}

impl TokenUsage {
    pub fn new(
        input: i64,
        cached: i64,
        cache_write: i64,
        output: i64,
        reasoning: i64,
        total: Option<i64>,
    ) -> Self {
        let total = total.unwrap_or(input + output);
        Self {
            input_tokens: input.max(0),
            cached_input_tokens: cached.max(0),
            cache_write_input_tokens: cache_write.max(0),
            output_tokens: output.max(0),
            reasoning_output_tokens: reasoning.max(0),
            total_tokens: total.max(0),
        }
    }

    /// Port of `effectiveTotalTokens`: older events omit `total_tokens`.
    pub fn effective_total(&self) -> i64 {
        if self.total_tokens > 0 {
            self.total_tokens
        } else {
            self.input_tokens + self.output_tokens
        }
    }

    pub fn has_usage(&self) -> bool {
        self.effective_total() > 0
            || self.cached_input_tokens > 0
            || self.cache_write_input_tokens > 0
    }

    pub fn add(&self, other: &TokenUsage) -> TokenUsage {
        TokenUsage::new(
            self.input_tokens + other.input_tokens,
            self.cached_input_tokens + other.cached_input_tokens,
            self.cache_write_input_tokens + other.cache_write_input_tokens,
            self.output_tokens + other.output_tokens,
            self.reasoning_output_tokens + other.reasoning_output_tokens,
            Some(self.effective_total() + other.effective_total()),
        )
    }

    /// Positive delta between cumulative snapshots; `None` when unusable.
    pub fn delta(&self, previous: &TokenUsage) -> Option<TokenUsage> {
        let total = self.effective_total() - previous.effective_total();
        let input = self.input_tokens - previous.input_tokens;
        let cached = self.cached_input_tokens - previous.cached_input_tokens;
        let cache_write = self.cache_write_input_tokens - previous.cache_write_input_tokens;
        let output = self.output_tokens - previous.output_tokens;
        let reasoning = self.reasoning_output_tokens - previous.reasoning_output_tokens;
        if total < 0 || input < 0 || cached < 0 || cache_write < 0 || output < 0 || reasoning < 0 {
            return None;
        }
        let result = TokenUsage::new(input, cached, cache_write, output, reasoning, Some(total));
        result.has_usage().then_some(result)
    }
}

/// Flexible int decode port of `decodeFlexibleInt64` (number/string/double).
fn flexible_i64(value: Option<&Value>) -> Option<i64> {
    match value {
        Some(Value::Number(number)) => number
            .as_i64()
            .or_else(|| number.as_f64().map(|f| f.round() as i64)),
        Some(Value::String(text)) => text.trim().parse::<i64>().ok(),
        Some(Value::Null) | None => None,
        _ => None,
    }
}

fn usage_from(value: Option<&Value>) -> Option<TokenUsage> {
    let value = value?;
    Some(TokenUsage::new(
        flexible_i64(value.get("input_tokens")).unwrap_or(0),
        flexible_i64(value.get("cached_input_tokens")).unwrap_or(0),
        flexible_i64(value.get("cache_write_input_tokens")).unwrap_or(0),
        flexible_i64(value.get("output_tokens")).unwrap_or(0),
        flexible_i64(value.get("reasoning_output_tokens")).unwrap_or(0),
        flexible_i64(value.get("total_tokens")),
    ))
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct BurnSample {
    pub id: String,
    pub timestamp: i64,
    pub usage: TokenUsage,
    pub model: String,
    pub reasoning_effort: String,
    pub context_window: Option<i64>,
    pub project_name: String,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ModelBreakdown {
    pub model: String,
    pub reasoning_effort: String,
    pub usage: TokenUsage,
    pub turn_count: i64,
    pub last_updated_at: Option<i64>,
}

#[derive(Debug, Clone, Serialize, Default)]
#[serde(rename_all = "camelCase")]
pub struct Telemetry {
    pub observed_usage: TokenUsage,
    pub today_usage: TokenUsage,
    pub window_usage: TokenUsage,
    pub latest_delta: Option<TokenUsage>,
    pub latest_context_usage: Option<TokenUsage>,
    pub latest_context_window: Option<i64>,
    pub peak_context_tokens: i64,
    pub samples: Vec<BurnSample>,
    pub model_breakdowns: Vec<ModelBreakdown>,
    pub current_model: Option<String>,
    pub current_reasoning_effort: Option<String>,
    pub updated_at: Option<i64>,
    pub session_count: i64,
    pub event_count: i64,
    pub attributed_event_count: i64,
}

impl Telemetry {
    pub fn has_data(&self) -> bool {
        self.observed_usage.has_usage()
            || self.latest_context_usage.map(|u| u.has_usage()) == Some(true)
    }

    #[allow(dead_code)]
    pub fn context_percent(&self) -> Option<f64> {
        let context = self.latest_context_usage?;
        let window = self.latest_context_window?;
        if window <= 0 {
            return None;
        }
        Some((context.effective_total() as f64 / window as f64).clamp(0.0, 1.0))
    }

    pub fn tokens_per_minute(&self, window_secs: f64, now: i64) -> Option<f64> {
        if window_secs <= 0.0 {
            return None;
        }
        let cutoff = now as f64 - window_secs;
        let total: i64 = self
            .samples
            .iter()
            .filter(|s| (s.timestamp as f64) >= cutoff && s.timestamp <= now)
            .map(|s| s.usage.effective_total())
            .sum();
        if total <= 0 {
            return None;
        }
        Some(total as f64 / window_secs * 60.0)
    }

    pub fn burn_label(&self, now: i64) -> String {
        crate::util::rate_label(self.tokens_per_minute(60.0, now))
    }

    #[allow(dead_code)]
    pub fn freshness_label(&self, now: i64) -> String {
        let Some(updated) = self.updated_at else {
            return "Waiting for token events".to_string();
        };
        let age = (now - updated).max(0);
        if age < 15 {
            return "Live · updated just now".to_string();
        }
        if age < 120 {
            return format!("Updated {}s ago", age);
        }
        format!("Stale · {}", crate::util::relative_time(updated, now))
    }
}

pub struct TelemetrySource<'a> {
    pub id: &'a str,
    pub project_name: String,
    pub path: Option<&'a Path>,
    pub contents: Option<&'a str>,
    pub modified: i64,
}

pub fn read_telemetry(sources: &[TelemetrySource<'_>], now: i64, window_hours: f64) -> Telemetry {
    let mut observed = TokenUsage::default();
    let mut today = TokenUsage::default();
    let mut window = TokenUsage::default();
    let window_start = now as f64 - window_hours.max(1.0) * 3600.0;
    let mut all_samples: Vec<BurnSample> = Vec::new();
    let mut breakdowns: HashMap<String, (TokenUsage, i64, Option<i64>)> = HashMap::new();
    let mut latest_context: Option<(i64, TokenUsage, Option<i64>, String, String)> = None;
    let mut latest_delta: Option<(i64, TokenUsage)> = None;
    let mut peak_context: i64 = 0;
    let mut event_count: i64 = 0;
    let mut attributed_event_count: i64 = 0;
    let mut sessions_with_events: HashSet<String> = HashSet::new();

    for source in sources.iter().take(MAX_TELEMETRY_SESSIONS) {
        let segments = log_segments(source);
        let mut model = "unknown".to_string();
        let mut effort = "unknown".to_string();
        let mut context_window: Option<i64> = None;
        let mut previous_cumulative: Option<TokenUsage>;
        let mut seen_keys: HashSet<String> = HashSet::new();

        for (segment_index, lines) in segments.iter().enumerate() {
            // A head+tail split makes the first tail event a new baseline so an
            // unknown middle section is never attributed to the current model.
            previous_cumulative = None;

            for line in lines.iter() {
                let Ok(value) = serde_json::from_str::<Value>(line.as_str()) else {
                    continue;
                };
                let Some(payload) = value.get("payload") else {
                    continue;
                };
                let envelope_type = value.get("type").and_then(|t| t.as_str()).unwrap_or("");

                if envelope_type == "turn_context" {
                    if let Some(new_model) = context_model(payload) {
                        model = new_model;
                    }
                    if let Some(new_effort) = context_effort(payload) {
                        effort = new_effort.to_ascii_lowercase();
                    }
                    continue;
                }

                if envelope_type != "event_msg" {
                    continue;
                }
                let payload_type = payload.get("type").and_then(|t| t.as_str()).unwrap_or("");

                if payload_type == "thread_settings_applied" {
                    if let Some(settings) = payload.get("thread_settings") {
                        if let Some(new_model) = settings.get("model").and_then(|m| m.as_str()) {
                            if !new_model.trim().is_empty() {
                                model = new_model.trim().to_string();
                            }
                        }
                        if let Some(new_effort) =
                            settings.get("reasoning_effort").and_then(|e| e.as_str())
                        {
                            if !new_effort.trim().is_empty() {
                                effort = new_effort.trim().to_ascii_lowercase();
                            }
                        }
                    }
                    continue;
                }

                if payload_type != "token_count" {
                    continue;
                }
                let Some(info) = payload.get("info") else {
                    continue;
                };
                let timestamp =
                    crate::util::parse_timestamp(value.get("timestamp").and_then(|t| t.as_str()))
                        .unwrap_or(source.modified);

                let total_snapshot = usage_from(info.get("total_token_usage"));
                let last_snapshot = usage_from(info.get("last_token_usage"));

                let event_key = match value.get("ordinal").and_then(|o| o.as_i64()) {
                    Some(ordinal) => format!("{}|{}", source.id, ordinal),
                    None => format!(
                        "{}|{}|{}",
                        source.id,
                        timestamp,
                        total_snapshot
                            .as_ref()
                            .map(|u| u.effective_total())
                            .or_else(|| last_snapshot.as_ref().map(|u| u.effective_total()))
                            .unwrap_or(0)
                    ),
                };
                if !seen_keys.insert(event_key.clone()) {
                    continue;
                }
                event_count += 1;
                sessions_with_events.insert(source.id.to_string());

                if let Some(current) = last_snapshot {
                    if let Some(reported) = flexible_i64(info.get("model_context_window")) {
                        context_window = Some(reported);
                    }
                    let should_replace = latest_context
                        .as_ref()
                        .map(|(existing, _, _, _, _)| timestamp >= *existing)
                        .unwrap_or(true);
                    if should_replace {
                        latest_context = Some((
                            timestamp,
                            current,
                            context_window,
                            model.clone(),
                            effort.clone(),
                        ));
                    }
                    peak_context = peak_context.max(current.effective_total());
                }

                let cumulative = match total_snapshot.or(last_snapshot) {
                    Some(value) => value,
                    None => continue,
                };

                let delta = match previous_cumulative {
                    Some(previous) => cumulative.delta(&previous),
                    None if segment_index == 0 && segments.len() == 1 => {
                        cumulative.has_usage().then_some(cumulative)
                    }
                    None => None,
                };
                previous_cumulative = Some(cumulative);

                let Some(delta) = delta else { continue };
                if !delta.has_usage() {
                    continue;
                }
                attributed_event_count += 1;
                observed = observed.add(&delta);
                if crate::util::same_local_day(timestamp, now) {
                    today = today.add(&delta);
                }
                if (timestamp as f64) >= window_start && timestamp <= now {
                    window = window.add(&delta);
                }

                all_samples.push(BurnSample {
                    id: event_key,
                    timestamp,
                    usage: delta,
                    model: model.clone(),
                    reasoning_effort: effort.clone(),
                    context_window,
                    project_name: source.project_name.clone(),
                });

                let key = format!("{model}|{effort}");
                let entry = breakdowns
                    .entry(key)
                    .or_insert((TokenUsage::default(), 0, None));
                entry.0 = entry.0.add(&delta);
                entry.1 += 1;
                entry.2 = Some(
                    entry
                        .2
                        .map_or(timestamp, |existing| existing.max(timestamp)),
                );

                match latest_delta {
                    Some((existing, _)) if timestamp < existing => {}
                    _ => latest_delta = Some((timestamp, delta)),
                }
            }
        }
    }

    all_samples.sort_by_key(|s| s.timestamp);
    let chart_start = all_samples.len().saturating_sub(MAX_CHART_SAMPLES);
    let samples = all_samples[chart_start..].to_vec();

    let mut model_breakdowns: Vec<ModelBreakdown> = breakdowns
        .into_iter()
        .map(|(key, (usage, turns, last_updated))| {
            let mut parts = key.splitn(2, '|');
            ModelBreakdown {
                model: parts.next().unwrap_or("unknown").to_string(),
                reasoning_effort: parts.next().unwrap_or("unknown").to_string(),
                usage,
                turn_count: turns,
                last_updated_at: last_updated,
            }
        })
        .collect();
    model_breakdowns.sort_by(|a, b| {
        b.usage
            .effective_total()
            .cmp(&a.usage.effective_total())
            .then_with(|| a.model.cmp(&b.model))
    });

    Telemetry {
        observed_usage: observed,
        today_usage: today,
        window_usage: window,
        latest_delta: latest_delta.map(|(_, usage)| usage),
        latest_context_usage: latest_context.as_ref().map(|(_, usage, _, _, _)| *usage),
        latest_context_window: latest_context
            .as_ref()
            .and_then(|(_, _, window, _, _)| *window),
        peak_context_tokens: peak_context,
        samples,
        model_breakdowns,
        current_model: latest_context
            .as_ref()
            .map(|(_, _, _, model, _)| model.clone()),
        current_reasoning_effort: latest_context
            .as_ref()
            .map(|(_, _, _, _, effort)| effort.clone()),
        updated_at: latest_context.map(|(timestamp, _, _, _, _)| timestamp),
        session_count: sessions_with_events.len() as i64,
        event_count,
        attributed_event_count,
    }
}

fn context_string(payload: &Value, path: &[&str]) -> Option<String> {
    let mut current = payload;
    for key in path {
        current = current.get(*key)?;
    }
    let value = current.as_str()?.trim().to_string();
    (!value.is_empty()).then_some(value)
}

/// `model ?? collaborationMode.settings.model` — the turn_context envelope
/// exposes the model at the top level and (mirrored) inside the
/// collaboration-mode settings; the two are alternatives, not a nested path.
fn context_model(payload: &Value) -> Option<String> {
    context_string(payload, &["model"])
        .or_else(|| context_string(payload, &["collaboration_mode", "settings", "model"]))
}

/// `model ?? collaborationMode.settings.model` and
/// `effort ?? reasoning_effort ?? collaborationMode.settings.reasoning_effort`.
fn context_effort(payload: &Value) -> Option<&str> {
    payload
        .get("effort")
        .and_then(|v| v.as_str())
        .filter(|v| !v.trim().is_empty())
        .or_else(|| {
            payload
                .get("reasoning_effort")
                .and_then(|v| v.as_str())
                .filter(|v| !v.trim().is_empty())
        })
        .or_else(|| {
            payload
                .get("collaboration_mode")?
                .get("settings")?
                .get("reasoning_effort")?
                .as_str()
        })
}

fn log_segments(source: &TelemetrySource<'_>) -> Vec<Vec<String>> {
    if let Some(contents) = source.contents {
        return vec![contents.lines().map(|l| l.to_string()).collect()];
    }
    let Some(path) = source.path else {
        return Vec::new();
    };
    let Ok(mut file) = std::fs::File::open(path) else {
        return Vec::new();
    };
    let Ok(size) = file.metadata().map(|m| m.len()) else {
        return Vec::new();
    };
    if size <= MAX_FILE_BYTES {
        let mut text = String::new();
        if file.read_to_string(&mut text).is_err() {
            return Vec::new();
        }
        return vec![text.lines().map(|l| l.to_string()).collect()];
    }
    let mut head = String::new();
    let mut head_bytes = vec![0u8; HEAD_BYTES as usize];
    if file.read_exact(&mut head_bytes).is_err() {
        return Vec::new();
    }
    head.push_str(&String::from_utf8_lossy(&head_bytes));
    let tail_size = (MAX_FILE_BYTES - HEAD_BYTES).min(size);
    if file.seek(SeekFrom::End(-(tail_size as i64))).is_err() {
        return vec![head.lines().map(|l| l.to_string()).collect()];
    }
    let mut tail_bytes = vec![0u8; tail_size as usize];
    if file.read_exact(&mut tail_bytes).is_err() {
        return vec![head.lines().map(|l| l.to_string()).collect()];
    }
    let tail = String::from_utf8_lossy(&tail_bytes).to_string();
    vec![
        head.lines().map(|l| l.to_string()).collect(),
        tail.lines().map(|l| l.to_string()).collect(),
    ]
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = concat!(
        r#"{"type":"event_msg","timestamp":"2026-09-25T05:00:00Z","ordinal":1,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"total_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"model_context_window":200000}}}"#,
        "\n",
        r#"{"type":"event_msg","timestamp":"2026-09-25T08:00:00Z","ordinal":2,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":30,"output_tokens":20,"total_tokens":50},"total_token_usage":{"input_tokens":90,"output_tokens":60,"total_tokens":150},"model_context_window":200000}}}"#,
        "\n",
        r#"{"type":"event_msg","timestamp":"2026-09-25T11:00:00Z","ordinal":3,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"total_token_usage":{"input_tokens":150,"output_tokens":100,"total_tokens":250},"model_context_window":200000}}}"#,
    );

    #[test]
    fn rolling_window_and_daily_totals_match_swift() {
        let now = crate::util::parse_timestamp(Some("2026-09-25T12:00:00Z")).unwrap();
        let source = TelemetrySource {
            id: "fixture",
            project_name: "Fixture".to_string(),
            path: None,
            contents: Some(FIXTURE),
            modified: now,
        };
        let telemetry = read_telemetry(&[source], now, 5.0);
        assert_eq!(telemetry.today_usage.effective_total(), 250);
        assert_eq!(telemetry.window_usage.effective_total(), 150);
        assert_eq!(telemetry.latest_context_window, Some(200_000));
        assert_eq!(telemetry.event_count, 3);
        assert_eq!(telemetry.attributed_event_count, 3);
    }

    #[test]
    fn turn_context_models_are_attributed_not_unknown() {
        // Real codex-cli shape: the model sits at the payload top level (and
        // mirrored under collaboration_mode.settings) — these are
        // alternatives, and a nested-path lookup used to miss both, leaving
        // every pre-thread_settings event attributed to "unknown".
        let fixture = concat!(
            r#"{"type":"turn_context","timestamp":"2026-10-03T17:02:40Z","ordinal":7,"payload":{"cwd":"/home/user/proj","model":"gpt-6-luna","effort":"max","collaboration_mode":{"mode":"default","settings":{"model":"gpt-6-luna","reasoning_effort":"max"}}}}"#,
            "\n",
            r#"{"type":"event_msg","timestamp":"2026-10-03T17:02:43Z","ordinal":15,"payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":100,"output_tokens":10,"total_tokens":110},"last_token_usage":{"input_tokens":100,"output_tokens":10,"total_tokens":110},"model_context_window":258400}}}"#,
            "\n",
        );
        let now = crate::util::parse_timestamp(Some("2026-10-03T18:00:00Z")).unwrap();
        let source = TelemetrySource {
            id: "fixture",
            project_name: "Fixture".to_string(),
            path: None,
            contents: Some(fixture),
            modified: now,
        };
        let telemetry = read_telemetry(&[source], now, 5.0);
        assert_eq!(telemetry.model_breakdowns.len(), 1);
        assert_eq!(telemetry.model_breakdowns[0].model, "gpt-6-luna");
        assert_eq!(telemetry.model_breakdowns[0].reasoning_effort, "max");
        assert_eq!(telemetry.current_model.as_deref(), Some("gpt-6-luna"));
        assert!(telemetry.samples.iter().all(|s| s.model == "gpt-6-luna"));
    }

    #[test]
    fn token_deltas_reject_negative_resets() {
        let before = TokenUsage::new(100, 0, 0, 50, 0, Some(150));
        let after = TokenUsage::new(90, 0, 0, 50, 0, Some(140));
        assert!(after.delta(&before).is_none());
        let grown = TokenUsage::new(120, 0, 0, 60, 0, Some(180));
        let delta = grown.delta(&before).expect("usable delta");
        assert_eq!(delta.effective_total(), 30);
    }

    #[test]
    fn flexible_ints_accept_strings() {
        let value: Value =
            serde_json::from_str(r#"{"input_tokens":"150","output_tokens":50}"#).unwrap();
        let usage = usage_from(Some(&value)).unwrap();
        assert_eq!(usage.input_tokens, 150);
        assert_eq!(usage.effective_total(), 200);
    }
}
