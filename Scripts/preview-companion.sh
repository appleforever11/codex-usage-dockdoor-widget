#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
preview_dir="$root_dir/build/CompanionThemePreview.app/Contents"
mkdir -p "$preview_dir/MacOS"
cp "$root_dir/Preview/Info.plist" "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier com.appleforever11.codex-companion-preview' "$preview_dir/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleExecutable CompanionThemePreview' "$preview_dir/Info.plist"
swiftc -parse-as-library -D WIDGET_DESIGN_PREVIEW -target arm64-apple-macosx14.0 \
    -F "$root_dir/build/sparkle" -framework Sparkle -Xlinker -rpath -Xlinker "$root_dir/build/sparkle" \
    "$root_dir/Installer/"*.swift "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
    "$root_dir/Preview/CompanionPreview.swift" -o "$preview_dir/MacOS/CompanionThemePreview"
if [[ "${1:-}" == "--capture" ]]; then
    "$preview_dir/MacOS/CompanionThemePreview" --capture "$root_dir/build/theme-preview/companion-astra.png"
else
    open "$root_dir/build/CompanionThemePreview.app"
fi
