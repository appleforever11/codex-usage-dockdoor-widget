//! Chat transcript rendering: parses a codex session `.jsonl` rollout into a
//! readable Markdown document so "Recent chats" can open a conversation in a
//! terminal or text editor instead of raw JSON.

use serde_json::Value;
use std::path::{Path, PathBuf};

/// Render `~/.codex/sessions/.../<id>.jsonl` into Markdown.
pub fn render_markdown(path: &Path) -> String {
    let Ok(text) = std::fs::read_to_string(path) else {
        return format!("# Codex session\n\nCould not read `{}`.\n", path.display());
    };

    let mut session_id = String::new();
    let mut cwd = String::new();
    let mut started = String::new();
    let mut model = String::new();
    let mut effort = String::new();
    let mut first_user_line = String::new();
    let mut body = String::new();
    let mut last_role = String::new();
    let mut total_tokens: Option<i64> = None;

    for line in text.lines() {
        let Ok(value) = serde_json::from_str::<Value>(line) else {
            continue;
        };
        let envelope_type = value.get("type").and_then(|t| t.as_str()).unwrap_or("");
        let timestamp = value
            .get("timestamp")
            .and_then(|t| t.as_str())
            .map(short_time)
            .unwrap_or_default();
        let payload = value.get("payload");

        match envelope_type {
            "session_meta" => {
                let Some(payload) = payload else { continue };
                session_id = payload
                    .get("id")
                    .or_else(|| payload.get("session_id"))
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                cwd = payload
                    .get("cwd")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
                started = payload
                    .get("timestamp")
                    .and_then(|v| v.as_str())
                    .unwrap_or_default()
                    .to_string();
            }
            "turn_context" => {
                let Some(payload) = payload else { continue };
                if let Some(m) = payload.get("model").and_then(|v| v.as_str()) {
                    model = m.to_string();
                }
                if let Some(e) = payload
                    .get("effort")
                    .and_then(|v| v.as_str())
                    .or_else(|| payload.get("reasoning_effort").and_then(|v| v.as_str()))
                {
                    effort = e.to_string();
                }
            }
            "event_msg" => {
                let Some(payload) = payload else { continue };
                match payload.get("type").and_then(|t| t.as_str()).unwrap_or("") {
                    "user_message" => {
                        let text = payload
                            .get("message")
                            .or_else(|| payload.get("text"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        push_turn(
                            &mut body,
                            &mut last_role,
                            "User",
                            &timestamp,
                            text,
                            &mut first_user_line,
                        );
                    }
                    "agent_message" => {
                        let text = payload
                            .get("message")
                            .or_else(|| payload.get("text"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        let label = model_label(&model);
                        push_turn(
                            &mut body,
                            &mut last_role,
                            &label,
                            &timestamp,
                            text,
                            &mut first_user_line,
                        );
                    }
                    _ => {}
                }
            }
            "response_item" => {
                let Some(payload) = payload else { continue };
                match payload.get("type").and_then(|t| t.as_str()).unwrap_or("") {
                    "message" => {
                        let role = payload.get("role").and_then(|r| r.as_str()).unwrap_or("");
                        let text = payload
                            .get("content")
                            .and_then(|c| c.as_array())
                            .map(|items| {
                                items
                                    .iter()
                                    .filter_map(|item| item.get("text").and_then(|t| t.as_str()))
                                    .collect::<Vec<_>>()
                                    .join("\n")
                            })
                            .unwrap_or_default();
                        if text.trim().is_empty() {
                            continue;
                        }
                        if role == "user" {
                            push_turn(
                                &mut body,
                                &mut last_role,
                                "User",
                                &timestamp,
                                &text,
                                &mut first_user_line,
                            );
                        } else if role == "assistant" {
                            let label = model_label(&model);
                            push_turn(
                                &mut body,
                                &mut last_role,
                                &label,
                                &timestamp,
                                &text,
                                &mut first_user_line,
                            );
                        }
                    }
                    "function_call" | "custom_tool_call" | "local_shell_call" => {
                        let name = payload
                            .get("name")
                            .and_then(|v| v.as_str())
                            .unwrap_or("tool");
                        let input = payload
                            .get("arguments")
                            .or_else(|| payload.get("input"))
                            .or_else(|| payload.get("action"))
                            .and_then(|v| v.as_str())
                            .unwrap_or("");
                        body.push_str(&format!(
                            "\n> 🔧 **{name}** {}\n",
                            single_line(&truncate_chars(input, 160))
                        ));
                        last_role = String::new();
                    }
                    "function_call_output"
                    | "command_execution_output"
                    | "custom_tool_call_output" => {
                        let output = payload
                            .get("output")
                            .map(|v| match v {
                                Value::String(text) => text.clone(),
                                other => other.to_string(),
                            })
                            .or_else(|| {
                                payload
                                    .get("output")
                                    .and_then(|v| v.as_str())
                                    .map(|s| s.to_string())
                            })
                            .unwrap_or_default();
                        body.push_str(&format!(
                            "> ↳ {}\n",
                            single_line(&truncate_chars(&output, 200))
                        ));
                        last_role = String::new();
                    }
                    "reasoning" => {
                        // Internal reasoning is summarized, not dumped.
                        let text = payload
                            .get("summary")
                            .and_then(|v| v.as_array())
                            .map(|items| {
                                items
                                    .iter()
                                    .filter_map(|i| i.get("text").and_then(|t| t.as_str()))
                                    .collect::<Vec<_>>()
                                    .join(" ")
                            })
                            .unwrap_or_default();
                        if !text.trim().is_empty() {
                            body.push_str(&format!(
                                "\n> 💭 _thinking:_ {}\n",
                                single_line(&truncate_chars(&text, 200))
                            ));
                            last_role = String::new();
                        }
                    }
                    _ => {}
                }
            }
            _ => {}
        }
        if let Some(info) = payload.and_then(|p| p.get("info")) {
            if let Some(total) = info
                .get("total_token_usage")
                .and_then(|u| u.get("total_tokens"))
            {
                if let Some(n) = total.as_i64() {
                    total_tokens = Some(n);
                }
            }
        }
    }

    let title = if first_user_line.is_empty() {
        "Codex session".to_string()
    } else {
        first_user_line
    };
    let mut header = format!("# {title}\n\n");
    if !session_id.is_empty() {
        header.push_str(&format!("- **Session:** `{session_id}`\n"));
    }
    if !cwd.is_empty() {
        header.push_str(&format!("- **Project:** `{cwd}`\n"));
    }
    if !started.is_empty() {
        header.push_str(&format!("- **Started:** {started}\n"));
    }
    if !model.is_empty() {
        header.push_str(&format!(
            "- **Model:** {} · {}\n",
            model_label(&model),
            if effort.is_empty() { "—" } else { &effort }
        ));
    }
    if let Some(tokens) = total_tokens {
        header.push_str(&format!(
            "- **Tokens (session):** {}\n",
            crate::util::compact_tokens_plain(tokens)
        ));
    }
    format!("{header}\n---\n{body}")
}

/// Locate the rollout file for a session id under the sessions root.
pub fn session_file_for_id(sessions_root: &Path, session_id: &str) -> Option<PathBuf> {
    for file in crate::sessions::session_files(sessions_root) {
        let name = file.path.file_name()?.to_string_lossy();
        if name.contains(session_id) {
            return Some(file.path);
        }
    }
    None
}

/// Render the transcript into the cache folder and return its path, so a
/// viewer command always opens a stable, nicely named file.
pub fn cached_transcript_path(session_id: &str, markdown: &str) -> std::io::Result<PathBuf> {
    let dir = cache_root().join("transcripts");
    std::fs::create_dir_all(&dir)?;
    let path = dir.join(format!("{session_id}.md"));
    std::fs::write(&path, markdown)?;
    Ok(path)
}

fn cache_root() -> PathBuf {
    if let Ok(xdg) = std::env::var("XDG_CACHE_HOME") {
        if !xdg.is_empty() {
            return PathBuf::from(xdg).join("codex-usage-plasmoid");
        }
    }
    crate::settings::home_dir().join(".cache/codex-usage-plasmoid")
}

/// Default viewer template: `{file}` is replaced with the (shell-quoted)
/// transcript path. Any shell command works, e.g. `kitty -e nvim {file}`.
pub fn open_in_viewer(command: &str, file: &Path) -> std::io::Result<std::process::Child> {
    let template = if command.trim().is_empty() {
        "xdg-open {file}"
    } else {
        command
    };
    let quoted = shell_quote(&file.to_string_lossy());
    let command_line = template.replace("{file}", &quoted);
    std::process::Command::new("sh")
        .arg("-c")
        .arg(command_line)
        .stdin(std::process::Stdio::null())
        .spawn()
}

fn shell_quote(value: &str) -> String {
    if !value.is_empty()
        && value
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || "-_./:=,%@+".contains(c))
    {
        return value.to_string();
    }
    format!("'{}'", value.replace('\'', r"'\''"))
}

fn push_turn(
    body: &mut String,
    last_role: &mut String,
    label: &str,
    timestamp: &str,
    text: &str,
    first_user_line: &mut String,
) {
    if crate::sessions::is_synthetic_message(text) {
        return;
    }
    if label == "User" && first_user_line.is_empty() {
        *first_user_line = truncate_chars(text.trim(), 72);
    }
    let role_key = format!("{label}|{timestamp}");
    if *last_role != role_key {
        let stamp = if timestamp.is_empty() {
            String::new()
        } else {
            format!("  ·  {timestamp}")
        };
        body.push_str(&format!("\n## {label}{stamp}\n\n"));
    }
    body.push_str(text.trim());
    body.push_str("\n\n");
    *last_role = role_key;
}

fn model_label(model: &str) -> String {
    if model.is_empty() {
        return "Codex".to_string();
    }
    crate::util::model_label(Some(model))
}

fn short_time(rfc3339: &str) -> String {
    // "2026-10-03T17:02:43.391Z" → "2026-10-03 17:02 UTC"
    let base = rfc3339
        .split('.')
        .next()
        .unwrap_or(rfc3339)
        .trim_end_matches('Z');
    base.replace('T', " ") + " UTC"
}

fn single_line(text: &str) -> String {
    text.trim().replace(['\n', '\r'], " ⏎ ")
}

fn truncate_chars(text: &str, max: usize) -> String {
    if text.chars().count() > max {
        let prefix: String = text.chars().take(max).collect();
        format!("{prefix}…")
    } else {
        text.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const FIXTURE: &str = concat!(
        r#"{"timestamp":"2026-10-03T17:02:18Z","type":"session_meta","payload":{"session_id":"abc-123","cwd":"/home/user/proj"}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:02:40Z","type":"turn_context","payload":{"model":"gpt-6-luna","effort":"max"}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:02:41Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<environment_context>\n<cwd>/home/user/proj</cwd>\n</environment_context>"}]}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:02:42Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Fix the login bug"}]}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:03:10Z","type":"response_item","payload":{"type":"function_call","name":"shell","arguments":"{\"command\":[\"npm\",\"test\"]}"}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:03:12Z","type":"response_item","payload":{"type":"function_call_output","output":"3 passed"}}"#,
        "\n",
        r#"{"timestamp":"2026-10-03T17:03:40Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"All tests pass now."}]}}"#,
        "\n",
    );

    #[test]
    fn renders_readable_transcript() {
        let path = std::env::temp_dir().join(format!("transcript-{}.jsonl", std::process::id()));
        std::fs::write(&path, FIXTURE).unwrap();
        let markdown = render_markdown(&path);
        let _ = std::fs::remove_file(path);

        assert!(
            markdown.contains("# Fix the login bug"),
            "title from first real user message"
        );
        assert!(markdown.contains("**Project:** `/home/user/proj`"));
        assert!(markdown.contains("**Model:** Luna-6 · max"));
        assert!(markdown.contains("## User  ·  2026-10-03 17:02:42 UTC"));
        assert!(markdown.contains("Fix the login bug"));
        assert!(markdown.contains("🔧 **shell**"));
        assert!(markdown.contains("↳ 3 passed"));
        assert!(markdown.contains("## Luna-6"));
        assert!(markdown.contains("All tests pass now."));
        assert!(
            !markdown.contains("<environment_context>"),
            "synthetic context must be skipped"
        );
    }

    #[test]
    fn shell_quoting_stays_safe() {
        assert_eq!(shell_quote("/tmp/a b.md"), "'/tmp/a b.md'");
        assert_eq!(shell_quote("/tmp/abc.md"), "/tmp/abc.md");
        assert_eq!(shell_quote("it's.md"), "'it'\\''s.md'");
    }
}
