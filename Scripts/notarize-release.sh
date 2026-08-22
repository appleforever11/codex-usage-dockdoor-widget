#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
root_dir="${script_dir:h}"
version="$(tr -d '[:space:]' < "$root_dir/VERSION")"
dist_dir="$root_dir/Dist"
bundle="$root_dir/build/CodexProjectTracker.bundle"
dmg="$dist_dir/Codex Usage for DockDoor Pro v$version.dmg"
zip="$dist_dir/Codex Usage for DockDoor Pro v$version.zip"

[[ -d "$bundle" ]] || { print -u2 "Missing built widget bundle: $bundle"; exit 1; }
[[ -f "$dmg" ]] || { print -u2 "Missing DMG: $dmg"; exit 1; }
[[ -f "$zip" ]] || { print -u2 "Missing ZIP: $zip"; exit 1; }

identity="${CODEX_SIGNING_IDENTITY:-}"
[[ "$identity" == Developer\ ID\ Application:* ]] || {
    print -u2 "CODEX_SIGNING_IDENTITY must be a Developer ID Application identity."
    exit 1
}

/usr/bin/codesign --verify --deep --strict --verbose=2 "$bundle"

submit() {
    local artifact="$1"
    if [[ -n "${CODEX_NOTARY_PROFILE:-}" ]]; then
        /usr/bin/xcrun notarytool submit "$artifact" \
            --keychain-profile "$CODEX_NOTARY_PROFILE" \
            --wait
    else
        [[ -n "${APPLE_ID:-}" ]] || { print -u2 "Set APPLE_ID or CODEX_NOTARY_PROFILE."; exit 1; }
        [[ -n "${APPLE_TEAM_ID:-}" ]] || { print -u2 "Set APPLE_TEAM_ID or CODEX_NOTARY_PROFILE."; exit 1; }
        [[ -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]] || { print -u2 "Set APPLE_APP_SPECIFIC_PASSWORD or CODEX_NOTARY_PROFILE."; exit 1; }
        /usr/bin/xcrun notarytool submit "$artifact" \
            --apple-id "$APPLE_ID" \
            --team-id "$APPLE_TEAM_ID" \
            --password "$APPLE_APP_SPECIFIC_PASSWORD" \
            --wait
    fi
}

print "Submitting v$version DMG for notarization..."
submit "$dmg"

print "Stapling the notarization ticket to the DMG..."
/usr/bin/xcrun stapler staple "$dmg"
/usr/bin/xcrun stapler validate "$dmg"

print "Submitting v$version ZIP for notarization..."
submit "$zip"

print "Verifying the signed widget and notarized DMG..."
/usr/bin/spctl --assess --type open --context context:primary-signature "$dmg"
print "Notarization complete for Codex Usage v$version."
