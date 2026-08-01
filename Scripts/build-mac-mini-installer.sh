#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
root_dir="${script_dir:h}"
version="3.1.0"
dist_dir="$root_dir/Dist"
package_name="Codex Usage for DockDoor Pro v$version"
stage_dir="$dist_dir/$package_name"
dmg_path="$dist_dir/$package_name.dmg"
zip_path="$dist_dir/$package_name.zip"

"$script_dir/build-widgets.sh" "$root_dir/Widgets/CodexProjectTracker"

/bin/rm -rf "$stage_dir"
/bin/mkdir -p "$stage_dir/Payload" "$stage_dir/Scripts" "$dist_dir"

/usr/bin/ditto "$root_dir/build/CodexProjectTracker.bundle" "$stage_dir/Payload/CodexProjectTracker.bundle"
/bin/cp "$root_dir/Installer/Install Codex Usage.command" "$stage_dir/"
/bin/cp "$root_dir/Installer/Remove Codex Usage.command" "$stage_dir/"
/bin/cp "$root_dir/Installer/README - Mac mini.txt" "$stage_dir/"
/bin/cp "$root_dir/screenshots/codex-usage-discord-cover.png" "$stage_dir/Codex Usage Preview.png"
/bin/cp "$root_dir/Scripts/install-usage-sync.sh" "$stage_dir/Scripts/"
/bin/cp "$root_dir/Scripts/sync-codex-usage.sh" "$stage_dir/Scripts/"
/bin/cp "$root_dir/Scripts/uninstall-usage-sync.sh" "$stage_dir/Scripts/"
/bin/chmod 755 "$stage_dir"/*.command "$stage_dir/Scripts"/*.sh
/usr/bin/xattr -cr "$stage_dir" 2>/dev/null || true

/bin/rm -f "$dmg_path" "$zip_path"
/usr/bin/hdiutil create -quiet -volname "Codex Usage v$version" -srcfolder "$stage_dir" -format UDZO "$dmg_path"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$stage_dir" "$zip_path"

print "Created:"
print "  $dmg_path"
print "  $zip_path"
