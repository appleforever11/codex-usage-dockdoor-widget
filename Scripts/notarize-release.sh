#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
root_dir="${script_dir:h}"
version="$(tr -d '[:space:]' < "$root_dir/VERSION")"
dist_dir="$root_dir/Dist"
bundle="$root_dir/build/CodexProjectTracker.bundle"
dmg="$dist_dir/Codex Usage for DockDoor Pro v$version.dmg"
zip="$dist_dir/Codex Usage for DockDoor Pro v$version.zip"
installer_app="$dist_dir/Codex Usage for DockDoor Pro v$version/Install Codex Usage.app"
app_zip="$dist_dir/CodexUsage-v$version.zip"

[[ -d "$bundle" ]] || { print -u2 "Missing built widget bundle: $bundle"; exit 1; }
[[ -f "$dmg" ]] || { print -u2 "Missing DMG: $dmg"; exit 1; }
[[ -f "$zip" ]] || { print -u2 "Missing ZIP: $zip"; exit 1; }
[[ -d "$installer_app" ]] || { print -u2 "Missing installer app: $installer_app"; exit 1; }

identity="${CODEX_SIGNING_IDENTITY:-}"
[[ "$identity" == Developer\ ID\ Application:* ]] || {
    print -u2 "CODEX_SIGNING_IDENTITY must be a Developer ID Application identity."
    exit 1
}

/usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$installer_app"

submit() {
    local artifact="$1"
    local result
    result="$(/usr/bin/mktemp)"
    if [[ -n "${CODEX_NOTARY_PROFILE:-}" ]]; then
        /usr/bin/xcrun notarytool submit "$artifact" \
            --keychain-profile "$CODEX_NOTARY_PROFILE" \
            --wait --output-format json > "$result"
    else
        [[ -n "${APPLE_ID:-}" ]] || { print -u2 "Set APPLE_ID or CODEX_NOTARY_PROFILE."; exit 1; }
        [[ -n "${APPLE_TEAM_ID:-}" ]] || { print -u2 "Set APPLE_TEAM_ID or CODEX_NOTARY_PROFILE."; exit 1; }
        [[ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]] || { print -u2 "Set APPLE_APP_SPECIFIC_PASSWORD or CODEX_NOTARY_PROFILE."; exit 1; }
        /usr/bin/xcrun notarytool submit "$artifact" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_SPECIFIC_PASSWORD" \
            --wait --output-format json > "$result"
    fi
    /usr/bin/jq '{id, status, message}' "$result"
    /usr/bin/jq -e '.status == "Accepted"' "$result" >/dev/null || {
        /bin/rm -f "$result"
        print -u2 "Notarization was not accepted. Release publication stopped."
        exit 1
    }
    /bin/rm -f "$result"
}

print "Notarizing and stapling the Sparkle application payload..."
/bin/rm -f "$app_zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$installer_app" "$app_zip"
submit "$app_zip"
/usr/bin/xcrun stapler staple "$installer_app"
/usr/bin/xcrun stapler validate "$installer_app"

# All archives must contain the same stapled application before signing the feed.
/bin/rm -f "$app_zip" "$zip" "$dmg"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$installer_app" "$app_zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "${installer_app:h}" "$zip"
/usr/bin/hdiutil create -quiet -volname "Codex Usage v$version" -srcfolder "${installer_app:h}" -format UDZO "$dmg"
/usr/bin/codesign --timestamp --sign "$identity" "$dmg"

print "Submitting v$version DMG for notarization..."
submit "$dmg"

print "Stapling the notarization ticket to the DMG..."
/usr/bin/xcrun stapler staple "$dmg"
/usr/bin/xcrun stapler validate "$dmg"

print "Verifying the signed widget, installer app, and stapled DMG..."
/usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$installer_app"
/usr/bin/xcrun stapler validate "$dmg"
/usr/sbin/spctl --assess --type execute --verbose=2 "$installer_app"
/usr/sbin/spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg"
print "Notarization complete for Codex Usage v$version."
