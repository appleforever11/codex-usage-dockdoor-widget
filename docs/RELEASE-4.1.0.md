# Codex Usage 4.1.0: Astra and Sparkle

Astra joins the dock with its approved dark-purple glow and twinkling stars. This release also adds a signed Sparkle update path so your other Macs can update through a familiar app dialog.

## What Changed

- Four model choices: Luna, Sol, Spark, and Astra. Instant, Medium, and Max remain available.
- Astra uses a fixed 12-star SwiftUI Canvas, pauses when inactive/hidden, and respects Reduce Motion.
- An update icon in the widget opens the companion's Sparkle dialog.
- Updates verify an Ed25519 signature and install a Developer ID-signed, Apple-notarized app.
- After updating, the companion applies its bundled widget, preserves the existing dock placement, and restarts DockDoor Pro.
- Widget replacement is staged and signature-checked, with a rollback copy retained.

## Install on Another Mac

Download the DMG, open **Install Codex Usage.app**, and follow the native installer. No Terminal or `.command` launch is required. The companion installs into your user Applications folder.

**Install this DMG once per Mac to enable Sparkle.** Earlier direct-widget updaters cannot install the new companion by themselves. Future updates are available from the widget's update icon or the companion's **Check for Updates** button.

## Marketplace

[PR #24](https://github.com/ejbills/dockdoorpro-widgets/pull/24) proposes read-only Astra usage labels and styling for DockDoor Pro. It does not contain the personal build's model controls, sync helper, or Sparkle framework. That edition continues to update through DockDoor Pro and requires maintainer review before release.

## Scope and Performance

Model controls change local defaults for new Codex work, not a running chat. Availability depends on the signed-in account. The widget has no new external framework dependency: Sparkle runs in the separate companion. Energy and RAM impact have not been benchmarked, so no measured performance claim is made.

## Verification

- Universal Apple Silicon/Intel widget and companion compiled and signature-validated.
- App and DMG notarization accepted; tickets stapled and Gatekeeper assessments accepted.
- Marketplace universal build, unsafe-API lint, and five focused usage-decoding checks passed.
- Astra controls were visually inspected and their selection behavior tested in the native preview.
