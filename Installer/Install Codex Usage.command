#!/bin/zsh

set -euo pipefail
setopt NULL_GLOB

package_dir="${0:A:h}"
payload_bundle="$package_dir/Payload/CodexProjectTracker.bundle"
sync_installer="$package_dir/Scripts/install-usage-sync.sh"
widgets_dir="$HOME/Library/Application Support/DockDoorPro/Widgets"
backup_root="$HOME/Library/Application Support/DockDoorPro/WidgetInstallerBackups"
timestamp="$(/bin/date '+%Y%m%d-%H%M%S')"
backup_dir="$backup_root/$timestamp"

finish() {
    local exit_code="$1"
    printf '\n'
    if [[ "$exit_code" -eq 0 ]]; then
        print "Installation complete. You can close this window."
    else
        print -u2 "Installation stopped. No existing widget backup was deleted."
    fi
    if [[ -t 0 ]]; then
        print -n "Press any key to close..."
        read -k 1
        printf '\n'
    fi
}

trap 'exit_code=$?; trap - EXIT; finish "$exit_code"; exit "$exit_code"' EXIT

print "Codex Usage for DockDoor Pro v3.0.1"
print "======================================"

if [[ ! -d "/Applications/DockDoor Pro.app" && ! -d "$HOME/Applications/DockDoor Pro.app" ]]; then
    print -u2 "DockDoor Pro is not installed in Applications. Install and activate it first."
    exit 1
fi

if [[ ! -d "$payload_bundle" || ! -x "$sync_installer" ]]; then
    print -u2 "This installer is incomplete. Re-download the full Mac mini package."
    exit 1
fi

print "1. Closing DockDoor Pro..."
/usr/bin/osascript -e 'tell application "DockDoor Pro" to quit' >/dev/null 2>&1 || true
for _ in {1..20}; do
    /usr/bin/pgrep -x "DockDoor Pro" >/dev/null 2>&1 || break
    sleep 0.25
done

/bin/mkdir -p "$widgets_dir" "$backup_dir"
existing_bundles=("$widgets_dir"/CodexProjectTracker*.bundle(N))
target_name="CodexProjectTracker.bundle"

if (( ${#existing_bundles[@]} > 0 )); then
    target_name="${existing_bundles[1]:t}"
    print "2. Backing up the existing widget..."
    for existing_bundle in "${existing_bundles[@]}"; do
        /bin/mv "$existing_bundle" "$backup_dir/"
    done
else
    print "2. No previous Codex widget found; installing fresh."
fi

print "3. Installing the universal Codex Usage widget..."
/usr/bin/ditto "$payload_bundle" "$widgets_dir/$target_name"
/usr/bin/xattr -dr com.apple.quarantine "$widgets_dir/$target_name" 2>/dev/null || true

print "4. Installing live Codex account synchronization..."
"$sync_installer"

print "5. Waiting for the first live account snapshot..."
for _ in {1..15}; do
    if [[ -s "$HOME/.codex/usage.json" ]] && \
       /usr/bin/jq -e '.source == "Codex app-server live account limits"' "$HOME/.codex/usage.json" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if [[ -s "$HOME/.codex/usage.json" ]]; then
    general="$(/usr/bin/jq -r '.limits[] | select(.name == "General") | .percentRemaining' "$HOME/.codex/usage.json" 2>/dev/null || true)"
    spark="$(/usr/bin/jq -r '.limits[] | select(.name | contains("Spark")) | .percentRemaining' "$HOME/.codex/usage.json" 2>/dev/null || true)"
    print "   Live usage: General ${general:-unknown}% left, Spark ${spark:-unknown}% left"
else
    print "   Codex has not produced a snapshot yet. Launch Codex, then wait one minute."
fi

print "6. Starting DockDoor Pro..."
/usr/bin/open -a "DockDoor Pro"

print ""
print "Widget installed at: $widgets_dir/$target_name"
print "Backup saved at:     $backup_dir"
print "Sync log:            $HOME/Library/Logs/CodexUsageWidget/sync.log"
