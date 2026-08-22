#!/bin/zsh

set -euo pipefail

: "${DEVELOPER_ID_CERTIFICATE_BASE64:?Set DEVELOPER_ID_CERTIFICATE_BASE64 to a base64-encoded Developer ID .p12}"
: "${DEVELOPER_ID_CERTIFICATE_PASSWORD:?Set DEVELOPER_ID_CERTIFICATE_PASSWORD}"
: "${CODEX_BUILD_KEYCHAIN_PASSWORD:?Set CODEX_BUILD_KEYCHAIN_PASSWORD}"

keychain="$RUNNER_TEMP/codex-signing.keychain-db"
certificate="$RUNNER_TEMP/developer-id.p12"

/usr/bin/security create-keychain -p "$CODEX_BUILD_KEYCHAIN_PASSWORD" "$keychain"
/usr/bin/security set-keychain-settings -lut 21600 "$keychain"
/usr/bin/security unlock-keychain -p "$CODEX_BUILD_KEYCHAIN_PASSWORD" "$keychain"
/usr/bin/security list-keychains -d user -s "$keychain"

printf '%s' "$DEVELOPER_ID_CERTIFICATE_BASE64" | /usr/bin/base64 --decode > "$certificate"
/usr/bin/security import "$certificate" \
    -k "$keychain" \
    -P "$DEVELOPER_ID_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign \
    -T /usr/bin/security \
    -T /usr/bin/xcrun
/usr/bin/security set-key-partition-list \
    -S apple-tool:,apple: \
    -s \
    -k "$CODEX_BUILD_KEYCHAIN_PASSWORD" \
    "$keychain"

/usr/bin/security find-identity -v -p codesigning "$keychain"
