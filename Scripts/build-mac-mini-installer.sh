#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
root_dir="${script_dir:h}"
version="$(tr -d '[:space:]' < "$root_dir/VERSION")"
dist_dir="$root_dir/Dist"
package_name="Codex Usage for DockDoor Pro v$version"
stage_dir="$dist_dir/$package_name"
dmg_path="$dist_dir/$package_name.dmg"
zip_path="$dist_dir/$package_name.zip"
installer_build_dir="$root_dir/build/CodexUsageInstaller"
installer_app="$installer_build_dir/Install Codex Usage.app"
installer_macos="$installer_app/Contents/MacOS"
installer_resources="$installer_app/Contents/Resources"
installer_source="$root_dir/Installer/CodexUsageInstaller.swift"
sparkle_dir="$root_dir/build/sparkle"
public_key="$(tr -d '[:space:]' < "$root_dir/Config/sparkle-public-key.txt")"
zsh "$script_dir/fetch-sparkle.sh"

"$script_dir/build-widgets.sh" "$root_dir/Widgets/CodexProjectTracker"

/bin/rm -rf "$installer_build_dir"
/bin/mkdir -p "$installer_macos" "$installer_resources"

print "Building universal installer app..."
for arch in arm64 x86_64; do
    swiftc \
        -target "${arch}-apple-macosx14.0" \
        -framework AppKit \
        -F "$sparkle_dir" -framework Sparkle \
        -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
        -parse-as-library \
        -o "$installer_macos/CodexUsageInstaller_${arch}" \
        "$installer_source" "$root_dir/Installer/CompanionUpdates.swift" \
        "$root_dir/Installer/CompanionTheme.swift" \
        "$root_dir/Widgets/CodexProjectTracker/CodexTheme.swift" \
        "$root_dir/Widgets/CodexProjectTracker/CodexThemeVisuals.swift" \
        "$root_dir/Widgets/CodexProjectTracker/CodexHaptics.swift"
done
lipo -create \
    "$installer_macos/CodexUsageInstaller_arm64" \
    "$installer_macos/CodexUsageInstaller_x86_64" \
    -output "$installer_macos/CodexUsageInstaller"
/bin/rm "$installer_macos/CodexUsageInstaller_arm64" "$installer_macos/CodexUsageInstaller_x86_64"
/bin/cp "$root_dir/Installer/Install Codex Usage.command" "$installer_resources/"
/bin/cp "$root_dir/VERSION" "$installer_resources/"
/bin/cp "$root_dir/Assets/CodexUsage.icns" "$installer_resources/"
/bin/mkdir -p "$installer_app/Contents/Frameworks"
/usr/bin/ditto "$sparkle_dir/Sparkle.framework" "$installer_app/Contents/Frameworks/Sparkle.framework"
/bin/mkdir -p "$installer_resources/Payload" "$installer_resources/Scripts"
/usr/bin/ditto "$root_dir/build/CodexProjectTracker.bundle" "$installer_resources/Payload/CodexProjectTracker.bundle"
for helper in \
    install-usage-sync.sh \
    sync-codex-usage.sh \
    uninstall-usage-sync.sh \
    install-widget-updater.sh \
    update-codex-widget.sh \
    uninstall-widget-updater.sh; do
    /bin/cp "$root_dir/Scripts/$helper" "$installer_resources/Scripts/$helper"
done
/bin/chmod 755 "$installer_resources/Install Codex Usage.command" "$installer_resources/Scripts"/*.sh

/bin/cat > "$installer_app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>Install Codex Usage</string>
    <key>CFBundleExecutable</key>
    <string>CodexUsageInstaller</string>
    <key>CFBundleIdentifier</key>
    <string>com.appleforever11.codex-usage-installer</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Install Codex Usage</string>
    <key>CFBundleIconFile</key>
    <string>CodexUsage</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${version}</string>
    <key>CFBundleVersion</key>
    <string>${version}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>SUFeedURL</key>
    <string>https://github.com/appleforever11/codex-usage-dockdoor-widget/releases/latest/download/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>${public_key}</string>
    <key>SUEnableAutomaticChecks</key>
    <false/>
    <key>SUVerifyUpdateBeforeExtraction</key>
    <true/>
    <key>CFBundleURLTypes</key>
    <array><dict>
        <key>CFBundleURLName</key><string>Codex Usage Updates</string>
        <key>CFBundleURLSchemes</key><array><string>codexusage</string></array>
    </dict></array>
</dict>
</plist>
PLIST

if [[ -n "${CODEX_SIGNING_IDENTITY:-}" ]]; then
    print "Signing installer app with Developer ID..."
    framework="$installer_app/Contents/Frameworks/Sparkle.framework/Versions/B"
    for nested in "$framework/XPCServices/Downloader.xpc" "$framework/XPCServices/Installer.xpc" "$framework/Autoupdate" "$framework/Updater.app" "$installer_app/Contents/Frameworks/Sparkle.framework"; do
        /usr/bin/codesign --force --options runtime --timestamp --sign "$CODEX_SIGNING_IDENTITY" "$nested"
    done
    /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$CODEX_SIGNING_IDENTITY" \
        "$installer_app"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$installer_app"
elif [[ "${CODEX_REQUIRE_SIGNING:-0}" == "1" ]]; then
    print -u2 "CODEX_REQUIRE_SIGNING=1 but CODEX_SIGNING_IDENTITY is not set"
    exit 1
fi

/bin/rm -rf "$stage_dir"
/bin/mkdir -p "$stage_dir" "$dist_dir"

/usr/bin/ditto "$installer_app" "$stage_dir/Install Codex Usage.app"
/bin/cp "$root_dir/Installer/README - Mac mini.txt" "$stage_dir/"
/bin/cp "$root_dir/VERSION" "$stage_dir/"
/bin/cp "$root_dir/screenshots/codex-astra-theme.png" "$stage_dir/Codex Usage Preview.png"
/usr/bin/xattr -cr "$stage_dir" 2>/dev/null || true

if [[ -n "${CODEX_SIGNING_IDENTITY:-}" ]]; then
    /usr/bin/codesign \
        --force \
        --deep \
        --options runtime \
        --timestamp \
        --sign "$CODEX_SIGNING_IDENTITY" \
        "$stage_dir/Install Codex Usage.app"
    /usr/bin/codesign --verify --deep --strict --verbose=2 "$stage_dir/Install Codex Usage.app"
elif [[ "${CODEX_REQUIRE_SIGNING:-0}" == "1" ]]; then
    print -u2 "The staged installer app is unsigned. Set CODEX_SIGNING_IDENTITY."
    exit 1
fi

/bin/rm -f "$dmg_path" "$zip_path"
/usr/bin/hdiutil create -quiet -volname "Codex Usage v$version" -srcfolder "$stage_dir" -format UDZO "$dmg_path"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$stage_dir" "$zip_path"

print "Created:"
print "  $dmg_path"
print "  $zip_path"
