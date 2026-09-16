#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
app_dir="$root_dir/build/CodexV6ControlsDemo.app"
contents_dir="$app_dir/Contents"

mkdir -p "$contents_dir/MacOS"
cp "$root_dir/Preview/Info.plist" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.appleforever11.codex-v6-controls-demo' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName CodexV6ControlsDemo' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable CodexV6ControlsDemo' "$contents_dir/Info.plist"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$root_dir/Widgets/CodexProjectTracker/CodexModelControls.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexHaptics.swift" \
    "$root_dir/Preview/V6ControlsDemo.swift" \
    -o "$contents_dir/MacOS/CodexV6ControlsDemo"

open -n "$app_dir"
echo "Launched $app_dir"
