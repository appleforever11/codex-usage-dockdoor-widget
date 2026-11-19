#!/bin/bash
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
checkout="${1:?Pass the DockDoor Pro marketplace checkout}"
output="${2:?Pass an output directory}"
version="$(tr -d '[:space:]' < "$root/VERSION")"
mkdir -p "$output"
output="$(cd "$output" && pwd)"
cd "$checkout"
bash scripts/build-widgets.sh Widgets/CodexUsage
bundle="build/CodexUsage.bundle"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string $version" "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string $version" "$bundle/Contents/Info.plist"
if [[ -n "${CODEX_SIGNING_IDENTITY:-}" ]]; then
    codesign --force --options runtime --timestamp --sign "$CODEX_SIGNING_IDENTITY" "$bundle"
    codesign --verify --deep --strict "$bundle"
fi
ditto -c -k --keepParent "$bundle" "$output/Codex Usage Marketplace $version.zip"
