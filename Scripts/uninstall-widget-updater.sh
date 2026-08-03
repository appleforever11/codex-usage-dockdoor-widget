#!/bin/zsh

set -euo pipefail

launch_agent="$HOME/Library/LaunchAgents/com.appleforever11.codex-widget-updater.plist"
installed_updater="$HOME/Library/Application Support/CodexUsageWidget/update-codex-widget.sh"

/bin/launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
/bin/rm -f "$launch_agent" "$installed_updater"

print "Uninstalled the Codex Usage updater."
