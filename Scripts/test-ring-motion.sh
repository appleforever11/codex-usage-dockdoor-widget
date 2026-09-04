#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
mkdir -p "$root_dir/build/tests" "$root_dir/build/theme-preview"
swiftc -parse-as-library -target arm64-apple-macosx14.0 -I "$root_dir/build/preview-sdk" \
 "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
 "$root_dir/Widgets/CodexProjectTracker/CodexUsageRing.swift" \
 "$root_dir/Widgets/CodexProjectTracker/AstraRingSparkles.swift" \
 "$root_dir/Preview/RingPreview.swift" -o "$root_dir/build/tests/RingPreview"
"$root_dir/build/tests/RingPreview" "$root_dir/build/theme-preview"
swift "$root_dir/Tests/RingMotionCheck.swift" "$root_dir/build/theme-preview"
