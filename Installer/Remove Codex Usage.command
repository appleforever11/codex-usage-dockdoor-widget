#!/bin/zsh

set -euo pipefail
setopt NULL_GLOB

package_dir="${0:A:h}"
widgets_dir="$HOME/Library/Application Support/DockDoorPro/Widgets"
backup_dir="$HOME/Library/Application Support/DockDoorPro/WidgetInstallerBackups/removed-$(/bin/date '+%Y%m%d-%H%M%S')"
installed_bundles=("$widgets_dir"/CodexProjectTracker*.bundle(N))

print "Removing Codex Usage from DockDoor Pro..."
/usr/bin/osascript -e 'tell application "DockDoor Pro" to quit' >/dev/null 2>&1 || true

if (( ${#installed_bundles[@]} > 0 )); then
    /bin/mkdir -p "$backup_dir"
    for installed_bundle in "${installed_bundles[@]}"; do
        /bin/mv "$installed_bundle" "$backup_dir/"
    done
    print "Widget moved to: $backup_dir"
else
    print "No installed Codex Usage widget was found."
fi

if [[ -x "$package_dir/Scripts/uninstall-usage-sync.sh" ]]; then
    "$package_dir/Scripts/uninstall-usage-sync.sh"
fi

/usr/bin/open -a "DockDoor Pro"
print "Removal complete. Your previous widget was preserved as a backup."

if [[ -t 0 ]]; then
    print -n "Press any key to close..."
    read -k 1
    printf '\n'
fi

