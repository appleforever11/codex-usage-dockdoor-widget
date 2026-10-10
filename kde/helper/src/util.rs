//! Formatting helpers ported from the DockDoor widget's Swift sources so the
//! plasmoid shows identical labels for the same numbers.

use chrono::{DateTime, Datelike, Local, TimeZone, Utc};

/// Port of `CodexUsagePercent.fraction(fromPercent:)`: whole numbers are
/// percentages, values below one are already-normalized fractions.
pub fn percent_fraction(value: f64) -> f64 {
    let fraction = if value >= 1.0 { value / 100.0 } else { value };
    fraction.clamp(0.0, 1.0)
}

/// Port of `CodexTokenUsage.compactLabel` / `CodexUsageSnapshot.compactTokens`
/// (the 1-decimal variant used across the v6 dashboard).
pub fn compact_tokens(tokens: i64) -> String {
    let value = (tokens.max(0)) as f64;
    if value >= 1_000_000_000.0 {
        format!("{:.1}B", value / 1_000_000_000.0)
    } else if value >= 1_000_000.0 {
        format!("{:.1}M", value / 1_000_000.0)
    } else if value >= 1_000.0 {
        format!("{:.1}K", value / 1_000.0)
    } else {
        format!("{}", value as i64)
    }
}

/// The no-decimal variant used by the usage snapshot totals.
pub fn compact_tokens_plain(tokens: i64) -> String {
    let value = (tokens.max(0)) as f64;
    if value >= 1_000_000.0 {
        format!("{:.1}M", value / 1_000_000.0)
    } else if value >= 1_000.0 {
        format!("{:.0}K", value / 1_000.0)
    } else {
        format!("{}", value as i64)
    }
}

/// Port of `CodexTokenUsage.rateLabel`.
pub fn rate_label(tokens_per_minute: Option<f64>) -> String {
    match tokens_per_minute {
        Some(rate) if rate.is_finite() && rate > 0.0 => {
            format!("{} / min", compact_tokens(rate.round() as i64))
        }
        _ => "—".to_string(),
    }
}

/// Port of `CodexCreditFormatting.display`: keep the prepaid balance
/// unit-neutral and never present it as dollars.
pub fn credit_display(raw: Option<&str>) -> Option<String> {
    let trimmed = raw?.trim();
    if trimmed.is_empty() {
        return None;
    }
    if trimmed.eq_ignore_ascii_case("unlimited") {
        return Some("Unlimited".to_string());
    }
    let numeric = trimmed.replace(['$', ','], "");
    match numeric.parse::<f64>() {
        Ok(value) if value.is_finite() => {
            let rounded = (value * 100.0).round() / 100.0;
            let whole = rounded.trunc() as i64;
            let cents = ((rounded - rounded.trunc()) * 100.0).round() as i64;
            let mut grouped = group_thousands(whole);
            if cents > 0 {
                grouped.push_str(&format!(".{:02}", cents));
            }
            Some(grouped)
        }
        _ => Some(numeric),
    }
}

fn group_thousands(value: i64) -> String {
    let text = value.to_string();
    let mut result = String::new();
    let digits = text.len();
    for (index, ch) in text.chars().enumerate() {
        if index > 0 && (digits - index) % 3 == 0 {
            result.push(',');
        }
        result.push(ch);
    }
    result
}

/// Port of `CodexModelIdentity.label`.
pub fn model_label(model: Option<&str>) -> String {
    model_label_with_unknown(model, "Unknown model")
}

pub fn model_label_with_unknown(model: Option<&str>, unknown: &str) -> String {
    let Some(model) = model else {
        return unknown.to_string();
    };
    if model.is_empty() || model.eq_ignore_ascii_case("unknown") {
        return unknown.to_string();
    }
    let value = model.to_ascii_lowercase();
    if value.contains("spark") {
        return "Spark".to_string();
    }
    for family in ["luna", "sol", "terra", "astra", "daybreak"] {
        if value.contains(family) {
            let name = family_display(family);
            // "gpt-6.1-sol" → "Sol-6.1"; ids without a numeric version
            // ("gpt-daybreak-blue-latest") keep the bare name.
            if let Some(rest) = value.strip_prefix("gpt-") {
                if let Some(version) = rest.split('-').next() {
                    if version.chars().next().is_some_and(|c| c.is_ascii_digit()) {
                        return format!("{name}-{version}");
                    }
                }
            }
            return name;
        }
    }
    model.to_string()
}

/// Reasoning-effort labels matching the Codex CLI status line
/// ("GPT-6.1-Sol Max Fast").
pub fn reasoning_label(effort: &str) -> String {
    match effort.to_ascii_lowercase().as_str() {
        "low" | "instant" => "Low".to_string(),
        "xhigh" => "XHigh".to_string(),
        "ultra" => "Ultra".to_string(),
        "max" => "Max".to_string(),
        "" | "unknown" => "Unknown".to_string(),
        other => {
            let mut chars = other.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => "Unknown".to_string(),
            }
        }
    }
}

/// Canonicalize a reasoning effort onto the accepted ladder. Unknown values
/// collapse to medium; legacy "instant" maps to low.
pub fn normalized_reasoning_effort(value: &str) -> String {
    match value.to_ascii_lowercase().as_str() {
        "instant" => "low".to_string(),
        "" => "medium".to_string(),
        other => {
            if crate::modelsettings::EFFORT_LADDER.contains(&other) {
                other.to_string()
            } else {
                "medium".to_string()
            }
        }
    }
}

/// Codename family of a model id: "luna", "sol", "terra", "astra", "spark",
/// "daybreak", or "other" for anything unrecognized.
pub fn model_family(id: &str) -> &'static str {
    let value = id.to_ascii_lowercase();
    for family in ["luna", "sol", "terra", "astra", "spark", "daybreak"] {
        if value.contains(family) {
            return family;
        }
    }
    "other"
}

/// Display name for a model family.
pub fn family_display(family: &str) -> String {
    match family {
        "luna" => "Luna".to_string(),
        "sol" => "Sol".to_string(),
        "terra" => "Terra".to_string(),
        "astra" => "Astra".to_string(),
        "spark" => "Spark".to_string(),
        "daybreak" => "Daybreak".to_string(),
        other => {
            let mut chars = other.chars();
            match chars.next() {
                Some(first) => first.to_uppercase().collect::<String>() + chars.as_str(),
                None => "Other".to_string(),
            }
        }
    }
}

/// Port of `CodexTrackerStore.shortUsageLabel`.
pub fn short_usage_label(name: &str) -> String {
    let lower = name.to_ascii_lowercase();
    if lower.contains("spark") {
        "Spark".to_string()
    } else if lower.contains("general") {
        "General".to_string()
    } else {
        "Limit".to_string()
    }
}

/// "Resets in 3d 4h" / "Resets in 5h 12m" / "Resets in 12m" — port of
/// `CodexUsageSnapshot.resetSummary`.
pub fn reset_summary(reset_epoch: Option<i64>, now_epoch: i64) -> String {
    let Some(reset) = reset_epoch else {
        return "No reset time exposed locally yet".to_string();
    };
    let interval = (reset - now_epoch).max(0);
    let days = interval / 86_400;
    let hours = (interval % 86_400) / 3_600;
    let minutes = (interval % 3_600) / 60;
    if days > 0 {
        format!("Resets in {days}d {hours}h")
    } else if hours > 0 {
        format!("Resets in {hours}h {minutes}m")
    } else {
        format!("Resets in {minutes}m")
    }
}

/// "MMM d" reset label (e.g. "Oct 5") in the local timezone.
pub fn short_reset_label(reset_epoch: i64) -> String {
    let dt = Local
        .timestamp_opt(reset_epoch, 0)
        .single()
        .unwrap_or_else(Local::now);
    format!("{} {}", dt.format("%b"), dt.day())
}

pub fn iso8601(epoch: i64) -> String {
    Utc.timestamp_opt(epoch, 0)
        .single()
        .unwrap_or_else(Utc::now)
        .format("%Y-%m-%dT%H:%M:%SZ")
        .to_string()
}

/// Parses the timestamp shapes Codex writes: RFC3339 with or without
/// fractional seconds. Returns unix seconds.
pub fn parse_timestamp(value: Option<&str>) -> Option<i64> {
    let value = value?.trim();
    if value.is_empty() {
        return None;
    }
    DateTime::parse_from_rfc3339(value)
        .ok()
        .map(|dt| dt.timestamp())
}

/// Abbreviated relative time like "2h ago" / "in 3d" — port of
/// `RelativeDateTimeFormatter(.abbreviated)` for the ranges the widget shows.
pub fn relative_time(target_epoch: i64, now_epoch: i64) -> String {
    let delta = target_epoch - now_epoch;
    let future = delta > 0;
    let seconds = delta.unsigned_abs();
    let (amount, unit) = if seconds < 10 {
        return if future {
            "in moments".to_string()
        } else {
            "just now".to_string()
        };
    } else if seconds < 60 {
        (seconds, "s")
    } else if seconds < 3_600 {
        (seconds / 60, "m")
    } else if seconds < 86_400 {
        (seconds / 3_600, "h")
    } else if seconds < 86_400 * 30 {
        (seconds / 86_400, "d")
    } else if seconds < 86_400 * 365 {
        (seconds / (86_400 * 30), "mo")
    } else {
        (seconds / (86_400 * 365), "y")
    };
    if future {
        format!("in {amount}{unit}")
    } else {
        format!("{amount}{unit} ago")
    }
}

/// Local-calendar day key "yyyy-MM-dd" (matches `dayKey(for:)` in analytics).
pub fn day_key(epoch: i64) -> String {
    Local
        .timestamp_opt(epoch, 0)
        .single()
        .unwrap_or_else(Local::now)
        .format("%Y-%m-%d")
        .to_string()
}

/// UTC weekday label for a day key, matching `CodexV6DateFormatting`.
#[allow(dead_code)]
pub fn short_weekday_for_day_key(key: &str) -> String {
    match NaiveDateWrapper::parse(key) {
        Some(day) => day.weekday_abbrev(),
        None => key.chars().rev().take(2).collect::<String>(),
    }
}

#[allow(dead_code)]
struct NaiveDateWrapper {
    year: i32,
    month: u32,
    day: u32,
}

impl NaiveDateWrapper {
    #[allow(dead_code)]
    fn parse(key: &str) -> Option<Self> {
        let mut parts = key.split('-');
        let year = parts.next()?.parse().ok()?;
        let month = parts.next()?.parse().ok()?;
        let day = parts.next()?.parse().ok()?;
        Some(Self { year, month, day })
    }

    #[allow(dead_code)]
    fn weekday_abbrev(&self) -> String {
        use chrono::Weekday;
        let Some(date) = chrono::NaiveDate::from_ymd_opt(self.year, self.month, self.day) else {
            return self.day.to_string();
        };
        match date.weekday() {
            Weekday::Mon => "Mon",
            Weekday::Tue => "Tue",
            Weekday::Wed => "Wed",
            Weekday::Thu => "Thu",
            Weekday::Fri => "Fri",
            Weekday::Sat => "Sat",
            Weekday::Sun => "Sun",
        }
        .to_string()
    }
}

/// Whether two epochs fall on the same local calendar day.
pub fn same_local_day(a: i64, b: i64) -> bool {
    day_key(a) == day_key(b)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn percent_normalization_matches_swift() {
        assert_eq!(percent_fraction(0.0), 0.0);
        assert!((percent_fraction(1.0) - 0.01).abs() < 1e-7);
        assert!((percent_fraction(50.0) - 0.50).abs() < 1e-7);
        assert!((percent_fraction(100.0) - 1.0).abs() < 1e-7);
        assert!((percent_fraction(0.01) - 0.01).abs() < 1e-7);
        assert!((percent_fraction(0.5) - 0.5).abs() < 1e-7);
        assert_eq!(percent_fraction(-1.0), 0.0);
        assert_eq!(percent_fraction(250.0), 1.0);
    }

    #[test]
    fn credit_formatting_matches_swift() {
        assert_eq!(
            credit_display(Some("1246.8885130000")).as_deref(),
            Some("1,246.89")
        );
        assert_eq!(
            credit_display(Some("$1250.0000000000")).as_deref(),
            Some("1,250")
        );
        assert_eq!(
            credit_display(Some("Unlimited")).as_deref(),
            Some("Unlimited")
        );
        assert_eq!(credit_display(None), None);
        assert_eq!(credit_display(Some("0")).as_deref(), Some("0"));
    }

    #[test]
    fn model_labels_match_swift() {
        assert_eq!(model_label(Some("gpt-6-luna")).as_str(), "Luna-6");
        assert_eq!(model_label(Some("gpt-6.1-sol")).as_str(), "Sol-6.1");
        assert_eq!(model_label(Some("gpt-6-astra")).as_str(), "Astra-6");
        assert_eq!(model_label(Some("gpt-5.6-terra")).as_str(), "Terra-5.6");
        assert_eq!(model_label(Some("GPT-5.3-Codex-Spark")).as_str(), "Spark");
        assert_eq!(model_label(Some("gpt-daybreak-blue-latest")).as_str(), "Daybreak");
        assert_eq!(model_label(None).as_str(), "Unknown model");
    }

    #[test]
    fn reasoning_labels_match_swift() {
        assert_eq!(reasoning_label("low"), "Low");
        assert_eq!(reasoning_label("instant"), "Low");
        assert_eq!(reasoning_label("medium"), "Medium");
        assert_eq!(reasoning_label("high"), "High");
        assert_eq!(reasoning_label("xhigh"), "XHigh");
        assert_eq!(reasoning_label("ultra"), "Ultra");
        assert_eq!(reasoning_label("max"), "Max");
        assert_eq!(normalized_reasoning_effort("high"), "high");
        assert_eq!(normalized_reasoning_effort("xhigh"), "xhigh");
        assert_eq!(normalized_reasoning_effort("ultra"), "ultra");
        assert_eq!(normalized_reasoning_effort("instant"), "low");
        assert_eq!(normalized_reasoning_effort("bogus"), "medium");
    }

    #[test]
    fn families_resolve() {
        assert_eq!(model_family("gpt-6.1-sol"), "sol");
        assert_eq!(model_family("GPT-Daybreak-Blue-latest"), "daybreak");
        assert_eq!(model_family("grok-9"), "other");
        assert_eq!(family_display("daybreak"), "Daybreak");
    }

    #[test]
    fn compact_labels() {
        assert_eq!(compact_tokens(1_234_567), "1.2M");
        assert_eq!(compact_tokens(950), "950");
        assert_eq!(compact_tokens(2_048), "2.0K");
        assert_eq!(compact_tokens_plain(2_000_000), "2.0M");
        assert_eq!(compact_tokens_plain(999), "999");
    }

    #[test]
    fn weekday_labels_use_utc_calendar() {
        assert_eq!(short_weekday_for_day_key("2026-09-09"), "Wed");
        assert_eq!(short_weekday_for_day_key("2026-10-03"), "Sat");
    }
}
