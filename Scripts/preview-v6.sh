#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
app_dir="$root_dir/build/CodexV6Demo.app"
contents_dir="$app_dir/Contents"
sdk_dir="$root_dir/build/v6-demo-sdk"

mkdir -p "$contents_dir/MacOS" "$sdk_dir"
cp "$root_dir/Preview/Info.plist" "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.appleforever11.codex-v6-demo' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName CodexV6Demo' "$contents_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable CodexV6Demo' "$contents_dir/Info.plist"

swiftc -target arm64-apple-macosx14.0 -emit-library -emit-module -module-name DockDoorWidgetSDK \
    -emit-module-path "$sdk_dir/DockDoorWidgetSDK.swiftmodule" \
    "$root_dir/Sources/DockDoorWidgetSDK/"*.swift -o "$sdk_dir/libDockDoorWidgetSDK.dylib"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    -I "$sdk_dir" -L "$sdk_dir" -lDockDoorWidgetSDK \
    -Xlinker -rpath -Xlinker "$sdk_dir" \
    "$root_dir/Widgets/CodexProjectTracker/"*.swift \
    "$root_dir/Preview/V6Demo.swift" \
    -o "$contents_dir/MacOS/CodexV6Demo"

open -n "$app_dir"
echo "Launched $app_dir"
