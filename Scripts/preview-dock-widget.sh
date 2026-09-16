#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
preview_dir="$root_dir/build/DockWidgetPreview.app/Contents"
sdk_dir="$root_dir/build/dock-preview-sdk"
mkdir -p "$preview_dir/MacOS" "$sdk_dir"
cp "$root_dir/Preview/Info.plist" "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.appleforever11.codex-dock-preview' "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable DockWidgetPreview' "$preview_dir/Info.plist"

swiftc -target arm64-apple-macosx14.0 \
    -emit-library -emit-module -module-name DockDoorWidgetSDK \
    -emit-module-path "$sdk_dir/DockDoorWidgetSDK.swiftmodule" \
    "$root_dir/Sources/DockDoorWidgetSDK/"*.swift \
    -o "$sdk_dir/libDockDoorWidgetSDK.dylib"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    -I "$sdk_dir" -L "$sdk_dir" -lDockDoorWidgetSDK \
    -Xlinker -rpath -Xlinker "$sdk_dir" \
    "$root_dir/Widgets/CodexProjectTracker/"*.swift \
    "$root_dir/Preview/DockWidgetPreview.swift" \
    -o "$preview_dir/MacOS/DockWidgetPreview"

if [[ "${1:-}" == "--capture" && -n "${2:-}" ]]; then
    "$preview_dir/MacOS/DockWidgetPreview" --capture "$2"
else
    open "$root_dir/build/DockWidgetPreview.app"
fi
