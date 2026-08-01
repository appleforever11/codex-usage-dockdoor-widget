#!/bin/zsh

set -euo pipefail

launch_agent="$HOME/Library/LaunchAgents/com.appleforever11.codex-usage-sync.plist"
install_dir="$HOME/Library/Application Support/CodexUsageWidget"

/bin/launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
/bin/rm -f "$launch_agent"
/bin/rm -rf "$install_dir"

print "Uninstalled Codex Usage live sync."
