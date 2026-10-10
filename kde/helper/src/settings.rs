//! Helper settings persisted at `~/.config/codex-usage-plasmoid/settings.json`.
//! The plasmoid pushes its data-affecting configuration here via POST /settings
//! so the daemon rebuilds snapshots with the same values the UI displays.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

pub const DEFAULT_PORT: u16 = 47631;
pub const HELPER_VERSION: &str = env!("CARGO_PKG_VERSION");

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Settings {
    pub port: u16,
    pub refresh_seconds: u64,
    pub sessions_folder: String,
    pub usage_state_path: String,
    pub recent_limit: u32,
    pub usage_budget_millions: f64,
    pub usage_window_hours: f64,
    pub daily_goal_millions: f64,
    /// Shell template used to open a chat transcript, `{file}` = the path.
    pub chat_viewer_command: String,
}

impl Default for Settings {
    fn default() -> Self {
        Self {
            port: DEFAULT_PORT,
            refresh_seconds: 60,
            sessions_folder: "~/.codex/sessions".to_string(),
            usage_state_path: "~/.codex/usage.json".to_string(),
            recent_limit: 5,
            usage_budget_millions: 200.0,
            usage_window_hours: 5.0,
            daily_goal_millions: 2.0,
            chat_viewer_command: "xdg-open {file}".to_string(),
        }
    }
}

impl Settings {
    pub fn config_path() -> PathBuf {
        config_root().join("settings.json")
    }

    pub fn load() -> Self {
        let Ok(text) = std::fs::read_to_string(Self::config_path()) else {
            return Self::default();
        };
        serde_json::from_str(&text).unwrap_or_default()
    }

    pub fn save(&self) -> std::io::Result<()> {
        let path = Self::config_path();
        std::fs::create_dir_all(path.parent().unwrap_or(&path))?;
        let temp = path.with_extension("json.tmp");
        std::fs::write(&temp, serde_json::to_vec_pretty(self).unwrap_or_default())?;
        std::fs::rename(temp, path)
    }

    /// Merge a partial update coming from the plasmoid, keeping every field
    /// the request omitted. Values are clamped to the same ranges the
    /// DockDoor settings schema enforced.
    pub fn merged(&self, update: &serde_json::Value) -> Self {
        let mut next = self.clone();
        let _ = update
            .get("port")
            .and_then(|v| v.as_u64())
            .map(|v| next.port = v.clamp(1024, 65535) as u16);
        let _ = update
            .get("refreshSeconds")
            .and_then(|v| v.as_u64())
            .map(|v| next.refresh_seconds = v.clamp(15, 3_600));
        let _ = update
            .get("sessionsFolder")
            .and_then(|v| v.as_str())
            .map(|v| next.sessions_folder = expand_tilde(v));
        let _ = update
            .get("usageStatePath")
            .and_then(|v| v.as_str())
            .map(|v| next.usage_state_path = expand_tilde(v));
        let _ = update
            .get("recentLimit")
            .and_then(|v| v.as_f64())
            .map(|v| next.recent_limit = v.clamp(3.0, 10.0) as u32);
        let _ = update
            .get("usageBudgetMillions")
            .and_then(|v| v.as_f64())
            .map(|v| next.usage_budget_millions = v.clamp(25.0, 500.0));
        let _ = update
            .get("usageWindowHours")
            .and_then(|v| v.as_f64())
            .map(|v| next.usage_window_hours = v.clamp(1.0, 24.0));
        let _ = update
            .get("dailyGoalMillions")
            .and_then(|v| v.as_f64())
            .map(|v| next.daily_goal_millions = v.clamp(0.5, 100.0));
        let _ = update
            .get("chatViewerCommand")
            .and_then(|v| v.as_str())
            .map(|v| next.chat_viewer_command = v.trim().to_string());
        next
    }

    pub fn sessions_root(&self) -> PathBuf {
        PathBuf::from(expand_tilde(&self.sessions_folder))
    }

    pub fn usage_budget_tokens(&self) -> i64 {
        (self.usage_budget_millions.max(1.0) * 1_000_000.0) as i64
    }

    pub fn daily_goal_tokens(&self) -> i64 {
        (self.daily_goal_millions.clamp(0.5, 100.0) * 1_000_000.0) as i64
    }
}

pub fn config_root() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("codex-usage-plasmoid");
        }
    }
    home_dir().join(".config").join("codex-usage-plasmoid")
}

pub fn state_root() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_STATE_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("codex-usage-plasmoid");
        }
    }
    home_dir().join(".local/state/codex-usage-plasmoid")
}

pub fn home_dir() -> PathBuf {
    std::env::var("HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| PathBuf::from("/"))
}

pub fn codex_home() -> PathBuf {
    std::env::var("CODEX_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| home_dir().join(".codex"))
}

pub fn expand_tilde(value: &str) -> String {
    if value == "~" {
        return home_dir().to_string_lossy().to_string();
    }
    if let Some(rest) = value.strip_prefix("~/") {
        return home_dir().join(rest).to_string_lossy().to_string();
    }
    value.to_string()
}
