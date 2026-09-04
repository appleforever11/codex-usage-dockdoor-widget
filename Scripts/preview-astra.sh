#!/bin/zsh
set -euo pipefail

root_dir="${0:A:h:h}"
preview_dir="$root_dir/build/AstraPreview.app/Contents"
mkdir -p "$preview_dir/MacOS" "$root_dir/build/astra-preview"
cp "$root_dir/Preview/Info.plist" "$preview_dir/Info.plist"
swiftc -parse-as-library -target arm64-apple-macosx14.0 \
    "$root_dir/Widgets/CodexProjectTracker/CodexModelControls.swift" \
    "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
    "$root_dir/Preview/AstraPreview.swift" \
    -o "$preview_dir/MacOS/AstraPreview"
if [[ "${1:-}" == "--capture" ]]; then
    "$preview_dir/MacOS/AstraPreview" --capture "$root_dir/build/astra-preview"
else
    open "$root_dir/build/AstraPreview.app"
fi
