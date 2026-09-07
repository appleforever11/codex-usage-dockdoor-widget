#!/bin/zsh
set -euo pipefail
root_dir="${0:A:h:h}"
case "${1:-}" in ''|--capture) ;; *) echo 'Usage: preview-companion.sh [--capture]' >&2; exit 2 ;; esac
preview_dir="$root_dir/build/CompanionThemePreview.app/Contents"
source "$root_dir/Scripts/app_instance.sh"
require_app_stopped "$preview_dir/MacOS/CompanionThemePreview"
mkdir -p "$preview_dir/MacOS" "$preview_dir/Resources"
cp "$root_dir/Assets/CodexUsage.icns" "$preview_dir/Resources/"
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
