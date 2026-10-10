//! Session discovery and metadata, ported from `CodexTrackerStore` with the
//! Linux additions: `~/.codex/session_index.jsonl` supplies thread names, and
//! `response_item` user messages back the legacy `event_msg` title fallback.

use serde::Serialize;
use serde_json::Value;
use std::collections::HashMap;
use std::path::{Path, PathBuf};

pub const MAX_INDEXED_SESSIONS: usize = 500;

#[derive(Debug, Clone)]
pub struct SessionFile {
    pub path: PathBuf,
    pub modified: i64,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct SessionMetadata {
    pub id: Option<String>,
    pub cwd: String,
    pub timestamp: Option<i64>,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionRecord {
    pub id: String,
    pub file: SessionFileInfo,
    pub metadata: SessionMetadata,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionFileInfo {
    pub path: String,
    pub modified: i64,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct SessionView {
    pub id: String,
    pub file_path: String,
    pub project_name: String,
    pub project_path: String,
    pub modified_at: i64,
    pub title: Option<String>,
    pub is_active: bool,
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ProjectView {
    pub id: String,
    pub name: String,
    pub path: String,
    pub modified_at: i64,
    pub is_active: bool,
}

/// Enumerate `.jsonl` session transcripts newest-first.
pub fn session_files(root: &Path) -> Vec<SessionFile> {
    let mut files: Vec<SessionFile> = Vec::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(dir) = stack.pop() {
        let Ok(entries) = std::fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let name = path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .unwrap_or_default();
            if name.starts_with('.') {
                continue;
            }
            if path.is_dir() {
                stack.push(path);
                continue;
            }
            if path.extension().and_then(|e| e.to_str()) != Some("jsonl") {
                continue;
            }
            let Ok(meta) = entry.metadata() else { continue };
            if !meta.is_file() {
                continue;
            }
            let modified = meta
                .modified()
                .ok()
                .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
                .map(|d| d.as_secs() as i64)
                .unwrap_or(0);
            files.push(SessionFile { path, modified });
        }
    }
    files.sort_by(|a, b| b.modified.cmp(&a.modified));
    files.truncate(MAX_INDEXED_SESSIONS);
    files
}

/// First 64 KB / 20 lines looking for `session_meta` with a cwd.
pub fn session_metadata(path: &Path) -> Option<SessionMetadata> {
    let mut file = std::fs::File::open(path).ok()?;
    let prefix = read_head(&mut file, 64 * 1024)?;
    for line in prefix.lines().take(20) {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        if value.get("type").and_then(|t| t.as_str()) != Some("session_meta") {
            continue;
        }
        let payload = value.get("payload")?;
        let cwd = payload.get("cwd").and_then(|c| c.as_str()).unwrap_or("");
        if cwd.is_empty() {
            continue;
        }
        return Some(SessionMetadata {
            id: payload
                .get("id")
                .or_else(|| payload.get("session_id"))
                .and_then(|i| i.as_str())
                .map(|s| s.to_string()),
            cwd: cwd.to_string(),
            timestamp: crate::util::parse_timestamp(
                payload
                    .get("timestamp")
                    .and_then(|t| t.as_str())
                    .or_else(|| value.get("timestamp").and_then(|t| t.as_str())),
            ),
        });
    }
    None
}

/// Thread names from `~/.codex/session_index.jsonl` — codex keeps this index
/// current, so it is the fastest and most accurate title source on Linux.
pub fn session_index_names(codex_home: &Path) -> HashMap<String, (String, i64)> {
    let mut names = HashMap::new();
    let Ok(text) = std::fs::read_to_string(codex_home.join("session_index.jsonl")) else {
        return names;
    };
    for line in text.lines().rev().take(MAX_INDEXED_SESSIONS) {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let Some(id) = value.get("id").and_then(|i| i.as_str()) else {
            continue;
        };
        let Some(name) = value.get("thread_name").and_then(|n| n.as_str()) else {
            continue;
        };
        if name.trim().is_empty() {
            continue;
        }
        let updated =
            crate::util::parse_timestamp(value.get("updated_at").and_then(|t| t.as_str()))
                .unwrap_or(0);
        names.insert(id.to_string(), (name.trim().to_string(), updated));
    }
    names
}

/// Codex injects machine context into the thread as user-role messages
/// wrapped in XML-ish tags (`<environment_context>`, `<user_instructions>`,
/// …). They are not conversation and must never become the title.
pub fn is_synthetic_message(text: &str) -> bool {
    const WRAPPERS: [&str; 7] = [
        "<environment_context>",
        "<user_instructions>",
        "<turn_context>",
        "<permissions>",
        "<skill_context>",
        "<collaboration_mode",
        "<ambient_context>",
    ];
    let trimmed = text.trim_start();
    WRAPPERS.iter().any(|wrapper| trimmed.starts_with(wrapper))
}

/// Title fallback port of `CodexTrackerStore.sessionTitle`: the first user
/// message, matching both the classic `event_msg`/`user_message` envelope and
/// the newer `response_item` message items (role `user`).
pub fn session_title(path: &Path) -> Option<String> {
    let mut file = std::fs::File::open(path).ok()?;
    let prefix = read_head(&mut file, 256 * 1024)?;
    for line in prefix.lines().take(80) {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let kind = value.get("type").and_then(|t| t.as_str()).unwrap_or("");
        let payload = value.get("payload");
        let candidate = match kind {
            "event_msg" => {
                let payload = payload?;
                if payload.get("type").and_then(|t| t.as_str()) != Some("user_message") {
                    None
                } else {
                    payload
                        .get("message")
                        .and_then(|m| m.as_str())
                        .or_else(|| payload.get("text").and_then(|t| t.as_str()))
                }
            }
            "response_item" => {
                let payload = payload?;
                if payload.get("type").and_then(|t| t.as_str()) != Some("message")
                    || payload.get("role").and_then(|r| r.as_str()) != Some("user")
                {
                    None
                } else {
                    payload
                        .get("content")
                        .and_then(|content| content.as_array())
                        .and_then(|items| {
                            items.iter().find_map(|item| {
                                item.get("text")
                                    .and_then(|t| t.as_str())
                                    .filter(|t| !t.trim().is_empty())
                            })
                        })
                }
            }
            _ => None,
        };
        if let Some(text) = candidate {
            if is_synthetic_message(text) {
                continue;
            }
            let cleaned = text.trim().replace('\n', " ");
            if !cleaned.is_empty() {
                return Some(truncate(&cleaned, 96));
            }
        }
    }
    None
}

/// Latest prompt from the tail of `~/.codex/history.jsonl`.
pub fn latest_history_prompt(codex_home: &Path) -> Option<String> {
    let path = codex_home.join("history.jsonl");
    let mut file = std::fs::File::open(path).ok()?;
    let text = read_tail(&mut file, 256 * 1024)?;
    for line in text.lines().rev() {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let Some(prompt) = value.get("text").and_then(|t| t.as_str()) else {
            continue;
        };
        let trimmed = prompt.trim();
        if !trimmed.is_empty() {
            return Some(truncate(trimmed, 160));
        }
    }
    None
}

pub fn build_records(files: &[SessionFile]) -> Vec<SessionRecord> {
    files
        .iter()
        .filter_map(|file| {
            let metadata = session_metadata(&file.path)?;
            Some(SessionRecord {
                id: metadata
                    .id
                    .clone()
                    .unwrap_or_else(|| file.path.to_string_lossy().to_string()),
                file: SessionFileInfo {
                    path: file.path.to_string_lossy().to_string(),
                    modified: file.modified,
                },
                metadata,
            })
        })
        .collect()
}

/// Port of `recentProjects`: group sessions by cwd, newest activity wins.
pub fn build_projects(records: &[SessionRecord], recent_limit: usize) -> Vec<ProjectView> {
    let now = chrono::Utc::now().timestamp();
    let mut by_path: HashMap<String, ProjectView> = HashMap::new();
    for record in records {
        let path = PathBuf::from(&record.metadata.cwd);
        let modified = record.metadata.timestamp.unwrap_or(record.file.modified);
        let name = path
            .file_name()
            .map(|n| n.to_string_lossy().to_string())
            .filter(|n| !n.is_empty())
            .unwrap_or_else(|| record.metadata.cwd.clone());
        let entry = ProjectView {
            id: record.metadata.cwd.clone(),
            name,
            path: record.metadata.cwd.clone(),
            modified_at: modified,
            is_active: now - modified < 60 * 60 * 24 * 7,
        };
        match by_path.get_mut(&record.metadata.cwd) {
            Some(existing) if existing.modified_at >= entry.modified_at => {}
            Some(existing) => *existing = entry,
            None => {
                by_path.insert(record.metadata.cwd.clone(), entry);
            }
        }
    }
    let mut projects: Vec<ProjectView> = by_path.into_values().collect();
    projects.sort_by(|a, b| b.modified_at.cmp(&a.modified_at));
    projects.truncate(recent_limit);
    projects
}

/// Panel sessions with titles; the first `preload_title_count` rows read their
/// transcript directly, later rows resolve lazily from the session index.
pub fn build_session_views(
    records: &[SessionRecord],
    index_names: &HashMap<String, (String, i64)>,
    recent_limit: usize,
    preload_title_count: usize,
) -> Vec<SessionView> {
    let now = chrono::Utc::now().timestamp();
    records
        .iter()
        .take(MAX_INDEXED_SESSIONS)
        .enumerate()
        .map(|(index, record)| {
            let path = PathBuf::from(&record.metadata.cwd);
            let project_name = path
                .file_name()
                .map(|n| n.to_string_lossy().to_string())
                .filter(|n| !n.is_empty())
                .unwrap_or_else(|| record.metadata.cwd.clone());
            let modified = record.metadata.timestamp.unwrap_or(record.file.modified);
            let id = record.id.clone();
            let title = if index < preload_title_count {
                session_title(Path::new(&record.file.path))
            } else {
                None
            }
            .or_else(|| index_names.get(&id).map(|(name, _)| truncate(name, 96)));
            SessionView {
                id,
                file_path: record.file.path.clone(),
                project_name,
                project_path: record.metadata.cwd.clone(),
                modified_at: modified,
                title,
                is_active: now - modified < 60 * 60 * 24 * 7,
            }
        })
        .take(recent_limit.max(1))
        .collect()
}

/// Linux port of `localTaskCount`: automations folders plus delegation
/// heuristics over recent sessions.
pub fn local_task_count(codex_home: &Path, sessions: &[SessionView]) -> usize {
    let mut file_count = 0;
    let roots = [
        codex_home.join("automations"),
        crate::settings::home_dir().join(".local/share/codex/automations"),
    ];
    for root in roots {
        let Ok(entries) = std::fs::read_dir(&root) else {
            continue;
        };
        file_count += entries
            .flatten()
            .filter(|entry| {
                entry
                    .file_name()
                    .to_string_lossy()
                    .to_ascii_lowercase()
                    .contains("task")
            })
            .count();
    }
    let delegated = sessions
        .iter()
        .filter(|session| {
            let title = session
                .title
                .clone()
                .unwrap_or_default()
                .to_ascii_lowercase();
            title.contains("delegation")
                || session.project_name.to_ascii_lowercase().contains("codex")
        })
        .count();
    file_count.max(delegated)
}

fn read_head(file: &mut std::fs::File, limit: u64) -> Option<String> {
    use std::io::Read;
    let size = file.metadata().ok()?.len().min(limit);
    let mut buffer = vec![0u8; size as usize];
    file.read_exact(&mut buffer).ok()?;
    String::from_utf8(buffer).ok()
}

fn read_tail(file: &mut std::fs::File, limit: u64) -> Option<String> {
    use std::io::{Read, Seek, SeekFrom};
    let size = file.metadata().ok()?.len();
    let read_size = size.min(limit);
    file.seek(SeekFrom::Start(size - read_size)).ok()?;
    let mut buffer = vec![0u8; read_size as usize];
    file.read_exact(&mut buffer).ok()?;
    String::from_utf8(buffer).ok()
}

fn truncate(text: &str, max: usize) -> String {
    if text.chars().count() > max {
        let prefix: String = text.chars().take(max).collect();
        format!("{prefix}...")
    } else {
        text.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn write_temp(name: &str, contents: &str) -> std::path::PathBuf {
        let path = std::env::temp_dir().join(format!(
            "codex-usage-test-{name}-{}.jsonl",
            std::process::id()
        ));
        std::fs::write(&path, contents).unwrap();
        path
    }

    #[test]
    fn synthetic_environment_context_is_not_a_title() {
        let fixture = concat!(
            r#"{"type":"session_meta","payload":{"cwd":"/home/user/proj","id":"s1"}}"#,
            "\n",
            r#"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\n  <cwd>/home/user/proj</cwd>\n  <shell>zsh</shell>\n</environment_context>"}]}}"#,
            "\n",
            r#"{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the login bug please"}]}}"#,
            "\n",
        );
        let path = write_temp("title-synthetic", fixture);
        assert_eq!(
            session_title(&path).as_deref(),
            Some("Fix the login bug please")
        );
        let _ = std::fs::remove_file(path);
    }

    #[test]
    fn synthetic_prefixes_are_detected() {
        assert!(is_synthetic_message(
            "  <environment_context>\n<cwd>/x</cwd>"
        ));
        assert!(is_synthetic_message("<user_instructions>"));
        assert!(!is_synthetic_message("Use <b> tags sparingly"));
        assert!(!is_synthetic_message("plain question"));
    }
}
