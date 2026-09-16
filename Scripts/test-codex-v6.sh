#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
test_dir="$root_dir/build/tests"
sdk_dir="$root_dir/build/v6-test-sdk"
mkdir -p "$test_dir" "$sdk_dir"

swiftc -target arm64-apple-macosx14.0 -emit-library -emit-module -module-name DockDoorWidgetSDK \
    -emit-module-path "$sdk_dir/DockDoorWidgetSDK.swiftmodule" \
    "$root_dir/Sources/DockDoorWidgetSDK/"*.swift -o "$sdk_dir/libDockDoorWidgetSDK.dylib"

swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    -I "$sdk_dir" -L "$sdk_dir" -lDockDoorWidgetSDK \
    -Xlinker -rpath -Xlinker "$sdk_dir" \
    "$root_dir/Widgets/CodexProjectTracker/CodexHaptics.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexThemeVisuals.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexModelControls.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexSnapshot.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexTokenTelemetry.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexV6Analytics.swift" \
    "$root_dir/Tests/CodexV6Tests.swift" \
    -o "$test_dir/codex-v6"

"$test_dir/codex-v6"
