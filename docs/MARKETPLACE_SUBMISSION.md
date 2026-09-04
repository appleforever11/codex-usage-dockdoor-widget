# Marketplace Submission

Current Astra review: [ejbills/dockdoorpro-widgets#24](https://github.com/ejbills/dockdoorpro-widgets/pull/24).

The read-only `codex-usage` widget was merged in [PR #21](https://github.com/ejbills/dockdoorpro-widgets/pull/21). The Astra proposal builds on that widget; it does not replace the original `codex-project-tracker` or modify the separate chat-scrolling PR.

## Astra Scope

- Recognize Astra names from user-maintained usage snapshots and named rate-limit records in Codex session logs.
- Render actual Astra limits with a dark-purple starfield, a sparkle icon, and a short dock label.
- Keep low-budget orange/red warnings and respect Reduce Motion.
- Animate a fixed 12-star Canvas only while the row is visible, at up to 18 frames per second. No performance benchmark is claimed.
- Preserve identity, both dock orientations, existing data sources, and the host's update mechanism.

## Boundaries

The marketplace folder contains only `widget.json` and Swift source. It does not write Codex configuration, spawn processes, perform network calls, install a LaunchAgent, or embed Sparkle. Astra is not shown as an independent allowance unless the source data labels it that way.

The full v4.1.0 model controls, live-sync helper, Sparkle companion, notarized installer, screenshots, and release notes remain in this standalone repository. Users of the personal build install its DMG once per Mac; marketplace users continue updating through DockDoor Pro.

## Checks

Build with `bash scripts/build-widgets.sh Widgets/CodexUsage`. Verify the new sources match the manifest, the binary contains arm64 and x86_64 slices, and the unsafe-API lint passes. Use `Scripts/test-marketplace-astra.sh <marketplace-checkout>` from the standalone repository for focused decoding and label checks.
