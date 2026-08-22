# Signed and Notarized Distribution

The v4.0.0 assets were built before a Developer ID certificate was available and are unsigned. The release pipeline now supports the proper Gatekeeper-friendly path for the next release.

## Requirements

- An Apple Developer Program account with a **Developer ID Application** certificate and its private key exported as a `.p12` file.
- The certificate identity, exactly as shown by `security find-identity -v -p codesigning`.
- Apple Team ID.
- An Apple ID plus an app-specific password for `notarytool`, or an equivalent App Store Connect API-key workflow.
- Xcode command-line tools with `codesign`, `xcrun notarytool`, and `xcrun stapler`.

Apple Development certificates are not valid for notarization. The widget binary must be signed with Developer ID Application before submission.

## Local Build

Import the `.p12` into the login keychain, then run:

```zsh
export CODEX_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export CODEX_REQUIRE_SIGNING=1
Scripts/build-mac-mini-installer.sh

xcrun notarytool store-credentials codex-notary \
  --apple-id 'your-apple-id@example.com' \
  --team-id 'TEAMID' \
  --password 'app-specific-password'

export CODEX_NOTARY_PROFILE=codex-notary
Scripts/notarize-release.sh
Scripts/validate-v4.sh
```

The notarization profile is stored in the macOS keychain. Do not commit certificates, private keys, app-specific passwords, or API keys.

## GitHub Actions Secrets

The release workflow expects these repository secrets:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_APPLICATION` | Full Developer ID Application identity string. |
| `DEVELOPER_ID_CERTIFICATE_BASE64` | Base64-encoded Developer ID `.p12` certificate. |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password protecting the `.p12`. |
| `APPLE_NOTARY_APPLE_ID` | Apple ID used for notarization. |
| `APPLE_NOTARY_TEAM_ID` | Apple Developer Team ID. |
| `APPLE_NOTARY_APP_SPECIFIC_PASSWORD` | App-specific password for `notarytool`. |

The workflow creates a temporary keychain, imports the certificate, builds a signed universal widget, submits both the DMG and ZIP to Apple, staples the DMG ticket, and verifies the signed output before publishing the release assets.

## Verification

After notarization, the release pipeline verifies:

- The widget has a valid Developer ID signature.
- The widget contains both `arm64` and `x86_64` slices.
- The DMG has a valid stapled ticket.
- Apple reports the DMG and ZIP submissions as `Accepted`.
