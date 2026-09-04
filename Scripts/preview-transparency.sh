#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
preview_dir="$root_dir/build/TransparencyPreview.app/Contents"
mkdir -p "$preview_dir/MacOS" "$root_dir/build/transparency-preview" "$root_dir/build/preview-sdk"
cp "$root_dir/Preview/Info.plist" "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.appleforever11.codex-transparency-preview' "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable TransparencyPreview' "$preview_dir/Info.plist"
swiftc -target arm64-apple-macosx14.0 -emit-library -emit-module -module-name DockDoorWidgetSDK \
    -emit-module-path "$root_dir/build/preview-sdk/DockDoorWidgetSDK.swiftmodule" \
    "$root_dir/Sources/DockDoorWidgetSDK/"*.swift -o "$root_dir/build/preview-sdk/libDockDoorWidgetSDK.dylib"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    -I "$root_dir/build/preview-sdk" -L "$root_dir/build/preview-sdk" -lDockDoorWidgetSDK \
    -Xlinker -rpath -Xlinker "$root_dir/build/preview-sdk" \
    "$root_dir/Widgets/CodexProjectTracker/"*.swift "$root_dir/Preview/WidgetPreview.swift" \
    -o "$preview_dir/MacOS/TransparencyPreview"
if [[ "${1:-}" == "--capture" ]]; then
    "$preview_dir/MacOS/TransparencyPreview" --capture "$root_dir/build/transparency-preview"
else
    open "$root_dir/build/TransparencyPreview.app"
fi
