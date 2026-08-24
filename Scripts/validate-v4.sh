#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
root_dir="${script_dir:h}"
version="$(tr -d '[:space:]' < "$root_dir/VERSION")"
bundle="$root_dir/build/CodexProjectTracker.bundle"
installer_app="$root_dir/Dist/Codex Usage for DockDoor Pro v$version/Install Codex Usage.app"
plist="$bundle/Contents/Info.plist"
source_file="$root_dir/Widgets/CodexProjectTracker/CodexProjectTracker.swift"
widget_json="$root_dir/Widgets/CodexProjectTracker/widget.json"
usage_fixture="$root_dir/examples/usage.json"

[[ "$version" == "4.0.0" ]] || { print -u2 "Expected VERSION 4.0.0, found $version"; exit 1; }
[[ -f "$bundle/Contents/MacOS/CodexProjectTracker" ]] || { print -u2 "Built widget bundle is missing."; exit 1; }
[[ -f "$installer_app/Contents/MacOS/CodexUsageInstaller" ]] || { print -u2 "Installer app is missing."; exit 1; }
/usr/bin/plutil -lint "$plist" >/dev/null
/usr/bin/plutil -lint "$installer_app/Contents/Info.plist" >/dev/null

bundle_version="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")"
[[ "$bundle_version" == "$version" ]] || { print -u2 "Bundle version $bundle_version does not match VERSION $version."; exit 1; }

architectures="$(/usr/bin/lipo -archs "$bundle/Contents/MacOS/CodexProjectTracker")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]] || {
    print -u2 "Expected universal arm64/x86_64 binary, found: $architectures"
    exit 1
}

/usr/bin/python3 - "$widget_json" "$usage_fixture" <<'PY'
import json
import sys

widget = json.load(open(sys.argv[1], encoding="utf-8"))
fixture = json.load(open(sys.argv[2], encoding="utf-8"))

assert widget["id"] == "codex-project-tracker"
assert "CodexProjectTracker.swift" in widget["sources"]
assert isinstance(fixture["updatedAt"], str)
limits = fixture["limits"]
assert len(limits) >= 2
assert all(isinstance(limit.get("percentRemaining"), (int, float)) for limit in limits)
assert all(isinstance(limit.get("resetAt"), str) for limit in limits)
PY

/usr/bin/grep -q 'CodexSnapshotBuildCache' "$source_file"
/usr/bin/grep -q 'usageFreshness' "$source_file"
/usr/bin/grep -q 'primaryCard' "$source_file"
/usr/bin/grep -q 'resetAt' "$root_dir/Scripts/sync-codex-usage.sh"

if [[ "${CODEX_REQUIRE_SIGNING:-0}" == "1" ]]; then
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$installer_app"
    authority="$(/usr/bin/codesign -dv --verbose=4 "$bundle" 2>&1 | /usr/bin/sed -n 's/^Authority=//p' | /usr/bin/head -n 1)"
    [[ "$authority" == Developer\ ID\ Application:* ]] || {
        print -u2 "Expected Developer ID Application signing, found: ${authority:-unsigned}"
        exit 1
    }
    installer_authority="$(/usr/bin/codesign -dv --verbose=4 "$installer_app" 2>&1 | /usr/bin/sed -n 's/^Authority=//p' | /usr/bin/head -n 1)"
    [[ "$installer_authority" == Developer\ ID\ Application:* ]] || {
        print -u2 "Expected Developer ID Application signing for installer app, found: ${installer_authority:-unsigned}"
        exit 1
    }
fi

zsh -n "$root_dir/Scripts/sync-codex-usage.sh"
print "Codex Usage v$version validation passed ($architectures)."
