#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
marketplace="${1:?Pass the marketplace checkout path}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT
# Generate an instrumented test translation unit; production visibility stays unchanged.
sed 's/private /fileprivate /g' "$marketplace/Widgets/CodexUsage/CodexUsage.swift" > "$scratch/Test.swift"
cat "$root_dir/Tests/MarketplaceAstraTests.swift" >> "$scratch/Test.swift"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    -module-name DockDoorWidgetSDK \
    "$marketplace/Sources/DockDoorWidgetSDK/"*.swift \
    "$marketplace/Widgets/CodexUsage/AstraUsageBackground.swift" \
    "$marketplace/Widgets/CodexUsage/CodexTheme.swift" \
    "$marketplace/Widgets/CodexUsage/AstraRingSparkles.swift" \
    "$scratch/Test.swift" -o "$scratch/test"
"$scratch/test"
