#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
install_dir="$HOME/Library/Application Support/CodexUsageWidget"
launch_agent="$HOME/Library/LaunchAgents/com.appleforever11.codex-widget-updater.plist"
installed_updater="$install_dir/update-codex-widget.sh"
log_dir="$HOME/Library/Logs/CodexUsageWidget"

/bin/mkdir -p "$install_dir" "$HOME/Library/LaunchAgents" "$log_dir"
/bin/cp "$script_dir/update-codex-widget.sh" "$installed_updater"
/bin/chmod 755 "$installed_updater"

cat >"$launch_agent" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.appleforever11.codex-widget-updater</string>
    <key>ProgramArguments</key>
    <array>
        <string>$installed_updater</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>StartInterval</key>
    <integer>21600</integer>
    <key>ProcessType</key>
    <string>Background</string>
    <key>StandardOutPath</key>
    <string>$log_dir/updater.log</string>
    <key>StandardErrorPath</key>
    <string>$log_dir/updater-error.log</string>
</dict>
</plist>
PLIST

/usr/bin/plutil -lint "$launch_agent"
/bin/launchctl bootout "gui/$UID" "$launch_agent" >/dev/null 2>&1 || true
/bin/launchctl bootstrap "gui/$UID" "$launch_agent"
/bin/launchctl kickstart -k "gui/$UID/com.appleforever11.codex-widget-updater"

print "Installed Codex Usage updater."
print "Schedule: at login and every 6 hours"
print "Logs: $log_dir/updater.log"
