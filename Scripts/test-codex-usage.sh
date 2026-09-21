#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
mkdir -p "$root_dir/build/tests"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$root_dir/Widgets/CodexProjectTracker/CodexUsagePercent.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexCreditFormatting.swift" \
    "$root_dir/Tests/CodexUsagePercentTests.swift" \
    -o "$root_dir/build/tests/codex-usage-percent"
"$root_dir/build/tests/codex-usage-percent"
