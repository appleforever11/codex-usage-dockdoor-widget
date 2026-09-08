#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
mkdir -p "$root_dir/build/tests"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
 "$root_dir/Widgets/CodexProjectTracker/CodexModelControls.swift" \
 "$root_dir/Widgets/CodexProjectTracker/CodexConfigStore.swift" \
 "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
 "$root_dir/Widgets/CodexProjectTracker/CodexTokenTelemetry.swift" \
 "$root_dir/Tests/WidgetRevisionTests.swift" -o "$root_dir/build/tests/widget-revisions"
"$root_dir/build/tests/widget-revisions"
