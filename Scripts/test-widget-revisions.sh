#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
sdk_dir="$root_dir/build/revision-test-sdk"
mkdir -p "$sdk_dir" "$root_dir/build/tests"
swiftc -emit-library -emit-module -module-name DockDoorWidgetSDK \
    -emit-module-path "$sdk_dir/DockDoorWidgetSDK.swiftmodule" \
    "$root_dir/Sources/DockDoorWidgetSDK/"*.swift -o "$sdk_dir/libDockDoorWidgetSDK.dylib"
swiftc -parse-as-library -I "$sdk_dir" -L "$sdk_dir" -lDockDoorWidgetSDK \
    -Xlinker -rpath -Xlinker "$sdk_dir" \
    "$root_dir/Widgets/CodexProjectTracker/"*.swift "$root_dir/Tests/WidgetRevisionTests.swift" \
    -o "$root_dir/build/tests/widget-revisions"
"$root_dir/build/tests/widget-revisions"
