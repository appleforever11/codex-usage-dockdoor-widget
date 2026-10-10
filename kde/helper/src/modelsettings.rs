//! `~/.codex/config.toml` model-default editing: upsert `model`,
//! `model_reasoning_effort`, and `service_tier` (the "/fast" speed tier) in
//! the root section only, preserving every other line. The selectable catalog
//! comes from the app-server's `model/list` RPC when available, with a
//! curated fallback so the widget still works offline.

use crate::settings::codex_home;
use crate::util;
use serde::Serialize;
use std::path::PathBuf;

pub const LUNA_MODEL: &str = "gpt-6-luna";

/// Every reasoning effort the Codex CLI accepts; individual models may expose
/// a subset (see `ModelInfo::efforts`).
pub const EFFORT_LADDER: [&str; 6] = ["low", "medium", "high", "xhigh", "max", "ultra"];

/// One selectable model from the account's catalog.
#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ModelInfo {
    pub id: String,
    pub display_name: String,
    pub description: String,
    pub family: String,
    pub efforts: Vec<String>,
    pub default_effort: String,
    pub supports_fast: bool,
    pub is_default: bool,
}

impl ModelInfo {
    pub fn new(
        id: &str,
        display_name: &str,
        description: &str,
        efforts: &[&str],
        default_effort: &str,
        supports_fast: bool,
        is_default: bool,
    ) -> Self {
        let efforts: Vec<String> = efforts.iter().map(|e| e.to_string()).collect();
        let default_effort = if default_effort.is_empty() {
            efforts.first().cloned().unwrap_or_else(|| "medium".to_string())
        } else {
            default_effort.to_string()
        };
        Self {
            id: id.to_string(),
            display_name: display_name.to_string(),
            description: description.to_string(),
            family: util::model_family(id).to_string(),
            efforts,
            default_effort,
            supports_fast,
            is_default,
        }
    }
}

/// Static catalog mirroring the app-server's `model/list` answer for a
/// ChatGPT-subscription account — used until the first live list lands (or
/// when the app-server is unreachable).
pub fn fallback_catalog() -> Vec<ModelInfo> {
    vec![
        ModelInfo::new(
            "gpt-6.1-sol",
            "GPT-6.1-Sol",
            "Latest workhorse model for coding and everyday work.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "low",
            true,
            true,
        ),
        ModelInfo::new(
            "gpt-6-astra",
            "GPT-6-Astra",
            "Frontier intelligence for the most demanding work.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "medium",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-6-sol",
            "GPT-6-Sol",
            "Previous generation workhorse model.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "medium",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-6-luna",
            "GPT-6-Luna",
            "Balanced everyday model.",
            &["low", "medium", "high", "xhigh", "max"],
            "medium",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-5.6-sol",
            "GPT-5.6-Sol",
            "Previous generation workhorse model.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "low",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-5.6-terra",
            "GPT-5.6-Terra",
            "Efficient model for lighter work.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "medium",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-5.6-luna",
            "GPT-5.6-Luna",
            "Balanced everyday model.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "medium",
            true,
            false,
        ),
        ModelInfo::new(
            "gpt-daybreak-blue-latest",
            "Daybreak Blue",
            "Experimental preview model.",
            &["low", "medium", "high", "xhigh", "max", "ultra"],
            "low",
            false,
            false,
        ),
    ]
}

/// The account's default model (first entry flagged `isDefault`, else the
/// fallback catalog's default).
pub fn default_model() -> String {
    fallback_catalog()
        .iter()
        .find(|m| m.is_default)
        .map(|m| m.id.clone())
        .unwrap_or_else(|| LUNA_MODEL.to_string())
}

#[derive(Debug, Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct ModelSettings {
    pub model: String,
    pub reasoning_effort: String,
    pub service_tier: String,
    pub short_model_name: String,
    pub reasoning_label: String,
    pub fast: bool,
}

impl Default for ModelSettings {
    fn default() -> Self {
        Self::new(&default_model(), "medium", "")
    }
}

impl ModelSettings {
    pub fn new(model: &str, reasoning_effort: &str, service_tier: &str) -> Self {
        let short_model_name = {
            let label = util::model_label(Some(model));
            label.chars().take(16).collect::<String>()
        };
        Self {
            short_model_name,
            reasoning_label: util::reasoning_label(reasoning_effort),
            fast: is_fast_tier(service_tier),
            model: model.to_string(),
            reasoning_effort: reasoning_effort.to_string(),
            service_tier: service_tier.to_string(),
        }
    }
}

/// `service_tier = "fast"` is what the Codex TUI's `/fast` writes; older
/// builds called the same tier "priority".
pub fn is_fast_tier(tier: &str) -> bool {
    tier == "fast" || tier == "priority"
}

pub fn config_path() -> PathBuf {
    codex_home().join("config.toml")
}

pub fn read() -> ModelSettings {
    let Ok(text) = std::fs::read_to_string(config_path()) else {
        return ModelSettings::default();
    };
    ModelSettings::new(
        &toml_string_value("model", &text).unwrap_or_else(default_model),
        &util::normalized_reasoning_effort(
            &toml_string_value("model_reasoning_effort", &text)
                .unwrap_or_else(|| "medium".to_string()),
        ),
        &toml_string_value("service_tier", &text).unwrap_or_default(),
    )
}

/// Validate against the live catalog (plus the fallback) and write the root
/// defaults. `fast`: `None` leaves `service_tier` untouched, `Some(true)`
/// writes the fast tier, `Some(false)` removes it.
pub fn update(
    model: &str,
    reasoning_effort: &str,
    fast: Option<bool>,
    catalog: &[ModelInfo],
) -> Result<ModelSettings, String> {
    update_at(&config_path(), model, reasoning_effort, fast, catalog)
}

pub fn update_at(
    path: &std::path::Path,
    model: &str,
    reasoning_effort: &str,
    fast: Option<bool>,
    catalog: &[ModelInfo],
) -> Result<ModelSettings, String> {
    let mut known: Vec<&ModelInfo> = catalog.iter().collect();
    let fallback = fallback_catalog();
    for entry in &fallback {
        if !known.iter().any(|m| m.id == entry.id) {
            known.push(entry);
        }
    }
    // The model already set in config.toml is always accepted — a codex
    // newer than the app-server's catalog may have written it.
    let current_text = std::fs::read_to_string(path).unwrap_or_default();
    let current_model = toml_string_value("model", &current_text).unwrap_or_default();
    let entry = known.iter().find(|m| m.id == model);
    if entry.is_none() && model != current_model {
        return Err(format!("unsupported model: {model}"));
    }

    let reasoning = util::normalized_reasoning_effort(reasoning_effort);
    let allowed: Vec<&str> = match entry {
        Some(entry) => entry.efforts.iter().map(|e| e.as_str()).collect(),
        None => EFFORT_LADDER.iter().map(|e| *e).collect(),
    };
    if !allowed.contains(&reasoning.as_str()) {
        return Err(format!(
            "model {model} does not support reasoning effort {reasoning} (supports: {})",
            allowed.join(", ")
        ));
    }

    let tier = match fast {
        None => toml_string_value("service_tier", &current_text).unwrap_or_default(),
        Some(true) => "fast".to_string(),
        Some(false) => String::new(),
    };
    let updated = replacing_defaults(&current_text, model, &reasoning, fast);
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent).map_err(|e| e.to_string())?;
    }
    let temp = path.with_extension("toml.tmp");
    std::fs::write(&temp, updated).map_err(|e| e.to_string())?;
    std::fs::rename(&temp, path).map_err(|e| e.to_string())?;
    Ok(ModelSettings::new(model, &reasoning, &tier))
}

pub fn replacing_defaults(
    current: &str,
    model: &str,
    reasoning_effort: &str,
    fast: Option<bool>,
) -> String {
    let mut lines: Vec<String> = current.split('\n').map(|l| l.to_string()).collect();
    upsert("model", model, &mut lines);
    upsert("model_reasoning_effort", reasoning_effort, &mut lines);
    match fast {
        Some(true) => upsert("service_tier", "fast", &mut lines),
        Some(false) => remove_key("service_tier", &mut lines),
        None => {}
    }
    lines.join("\n")
}

fn assignment_key(line: &str) -> Option<String> {
    let trimmed = line.trim();
    if trimmed.starts_with('#') {
        return None;
    }
    let equals = trimmed.find('=')?;
    Some(trimmed[..equals].trim().to_string())
}

fn toml_string_value(key: &str, text: &str) -> Option<String> {
    for line in text.split('\n') {
        let trimmed = line.trim();
        if trimmed.starts_with('[') {
            break;
        }
        if assignment_key(line).as_deref() != Some(key) {
            continue;
        }
        let equals = line.find('=')?;
        let value = line[equals + 1..].trim();
        let quote = value.chars().next()?;
        if quote != '"' && quote != '\'' {
            continue;
        }
        return value[1..]
            .split(quote)
            .next()
            .map(|s| s.to_string());
    }
    None
}

fn upsert(key: &str, value: &str, lines: &mut Vec<String>) {
    let replacement = format!("{key} = \"{value}\"");
    let root_end = lines
        .iter()
        .position(|line| line.trim().starts_with('['))
        .unwrap_or(lines.len());
    if let Some(index) = lines[..root_end]
        .iter()
        .position(|line| assignment_key(line).as_deref() == Some(key))
    {
        lines[index] = replacement;
    } else {
        lines.insert(root_end, replacement);
    }
}

fn remove_key(key: &str, lines: &mut Vec<String>) {
    let root_end = lines
        .iter()
        .position(|line| line.trim().starts_with('['))
        .unwrap_or(lines.len());
    let mut index = 0;
    while index < lines.len() && index < root_end {
        if assignment_key(&lines[index]).as_deref() == Some(key) {
            lines.remove(index);
        } else {
            index += 1;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn upserts_root_keys_preserving_sections() {
        let input = "service_tier = \"default\"\n[tui]\nscreen_reader_detection_done = true\n";
        let output = replacing_defaults(input, "gpt-6-astra", "max", None);
        let updated = read_from(&output);
        assert_eq!(updated.model, "gpt-6-astra");
        assert_eq!(updated.reasoning_effort, "max");
        assert!(output.contains("service_tier = \"default\""));
        assert!(output.contains("[tui]"));
        assert!(output.contains("screen_reader_detection_done = true"));
    }

    fn read_from(text: &str) -> ModelSettings {
        ModelSettings::new(
            &toml_string_value("model", text).unwrap(),
            &util::normalized_reasoning_effort(
                &toml_string_value("model_reasoning_effort", text).unwrap(),
            ),
            &toml_string_value("service_tier", text).unwrap_or_default(),
        )
    }

    #[test]
    fn replaces_existing_values_in_place() {
        let input = "model = \"gpt-6-sol\"\nmodel_reasoning_effort = \"high\"\n";
        let output = replacing_defaults(input, "gpt-6.1-sol", "ultra", Some(true));
        assert!(output.contains("model = \"gpt-6.1-sol\""));
        assert!(output.contains("model_reasoning_effort = \"ultra\""));
        assert!(output.contains("service_tier = \"fast\""));
        assert!(!output.contains("gpt-6-sol\""));
    }

    #[test]
    fn fast_toggle_writes_and_removes_tier() {
        let input = "model = \"gpt-6.1-sol\"\nmodel_reasoning_effort = \"max\"\nservice_tier = \"fast\"\n";
        let output = replacing_defaults(input, "gpt-6.1-sol", "max", Some(false));
        assert!(!output.contains("service_tier"));
        let on = replacing_defaults(&output, "gpt-6.1-sol", "max", Some(true));
        assert!(on.contains("service_tier = \"fast\""));
    }

    #[test]
    fn real_world_config_parses() {
        let input = "model = \"gpt-6.1-sol\"\nmodel_reasoning_effort = \"max\"\nservice_tier = \"fast\"\n[tui]\nscreen_reader_detection_done = true\n";
        assert_eq!(
            toml_string_value("model", input).as_deref(),
            Some("gpt-6.1-sol")
        );
        assert_eq!(
            toml_string_value("model_reasoning_effort", input).as_deref(),
            Some("max")
        );
        assert_eq!(
            toml_string_value("service_tier", input).as_deref(),
            Some("fast")
        );
        // Values inside sections are not picked up as root defaults.
        let sectioned = "[tui]\nmodel = \"gpt-6-sol\"\n";
        assert_eq!(toml_string_value("model", sectioned).as_deref(), None);
    }

    #[test]
    fn labels_match_widget() {
        let settings = ModelSettings::new("gpt-6.1-sol", "max", "fast");
        assert_eq!(settings.short_model_name, "Sol-6.1");
        assert_eq!(settings.reasoning_label, "Max");
        assert!(settings.fast);
        let off = ModelSettings::new("gpt-6-luna", "xhigh", "");
        assert_eq!(off.reasoning_label, "XHigh");
        assert!(!off.fast);
    }

    #[test]
    fn update_validates_against_catalog() {
        // Isolated config path so the test never touches ~/.codex.
        let dir = std::env::temp_dir().join(format!("codex-modelsettings-test-{}", std::process::id()));
        let _ = std::fs::remove_dir_all(&dir);
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join("config.toml");
        std::fs::write(&path, "model = \"gpt-6.1-sol\"\nmodel_reasoning_effort = \"max\"\nservice_tier = \"fast\"\n").unwrap();

        let catalog = fallback_catalog();
        assert!(update_at(&path, "gpt-6.1-sol", "ultra", None, &catalog).is_ok());
        // Luna-6 has no ultra effort.
        assert!(update_at(&path, "gpt-6-luna", "ultra", None, &catalog).is_err());
        // Unknown model rejected even though the catalog exists.
        assert!(update_at(&path, "gpt-9-foo", "low", None, &catalog).is_err());
        // ...but the currently configured model is always accepted (its
        // efforts validate against the full ladder).
        std::fs::write(&path, "model = \"gpt-9-foo\"\n").unwrap();
        assert!(update_at(&path, "gpt-9-foo", "ultra", Some(true), &catalog).is_ok());
        // Dynamic catalog entries extend the fallback set.
        let mut extended = catalog.clone();
        extended.push(ModelInfo::new(
            "gpt-7-terra",
            "GPT-7-Terra",
            "future",
            &["low", "medium"],
            "medium",
            false,
            false,
        ));
        assert!(update_at(&path, "gpt-7-terra", "medium", Some(true), &extended).is_ok());
        let written = std::fs::read_to_string(&path).unwrap();
        assert!(written.contains("model = \"gpt-7-terra\""));
        assert!(written.contains("service_tier = \"fast\""));
        let _ = std::fs::remove_dir_all(&dir);
    }
}
