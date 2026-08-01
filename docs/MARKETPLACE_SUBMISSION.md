# Marketplace Submission Notes

Use this checklist when preparing a pull request against `ejbills/dockdoorpro-widgets`.

## Target

- Marketplace repo: `https://github.com/ejbills/dockdoorpro-widgets`
- Widget folder: `Widgets/CodexProjectTracker`
- Widget id: `codex-project-tracker`
- Widget name: `Codex Usage`
- Current package version: `3.1.0`
- Marketplace PR: `https://github.com/ejbills/dockdoorpro-widgets/pull/20`
- Canonical Discord discussion: `https://discord.com/channels/1312172160931856464/1532985348374659092`

## Pre-PR Checklist

- Build with `bash Scripts/build-widgets.sh Widgets/CodexProjectTracker`.
- Confirm `Build/CodexProjectTracker.bundle.zip` is regenerated.
- Test the installed bundle in the current DockDoor Pro build.
- Verify compact dock mode rotates between usage, model, tasks, and chats.
- Verify the panel palette button toggles the rainbow usage ring.
- Verify DockDoor settings exposes `Rainbow Usage Ring`.
- Verify model/reasoning buttons update `~/.codex/config.toml`.
- Verify recent chat rows open Codex tasks when the session id is available.
- Install `Scripts/install-usage-sync.sh` and verify `~/.codex/usage.json` follows the current Codex account limits.
- Verify the sync LaunchAgent exits cleanly and refreshes again after 60 seconds.
- Refresh screenshots if the UI changed.

## Suggested PR Title

Update Codex Usage with live account synchronization

## Suggested PR Summary

This updates Codex Usage to 3.1.0 for DockDoor Pro. It adds a lightning-button fast mode that switches new Codex chats to Spark with Instant reasoning and restores the previous defaults when disabled. The widget also shows account usage countdowns, credits, recent chats, project/task counts, and local Codex defaults directly from the dock. An optional one-shot LaunchAgent reads the signed-in account's limits from Codex's local `account/rateLimits/read` RPC every 60 seconds and atomically updates `~/.codex/usage.json`, preventing stale legacy session telemetry from overriding the current subscription window. The newest session `rate_limits` events remain the automatic fallback. The widget remains intentionally lightweight: native SwiftUI, widget-side local file reads, no persistent helper daemon, and modest refresh intervals.

## Suggested Discord Patch Notes

**Codex Usage Widget v3.1.0**

This is the big Codex Usage release for DockDoor Pro. The widget has evolved from a simple tracker into a polished, lightweight Codex command center right in the dock.

- New usage countdown ring built for quick scanning from the dock.
- Optional rainbow/glow usage tracking toggle from the widget panel and DockDoor settings.
- Credits, general limits, model-specific limits, reset dates, tasks, and chats in one compact view.
- Smooth gradient model and reasoning selectors for Codex defaults.
- Recent chats stay selectable and open Codex tasks directly when possible.
- Live account synchronization through Codex's official local app-server, fixing stale General and Spark percentages.
- Atomic one-minute snapshots with bounded retries and preservation of the last valid reading.
- Ultra-thin native SwiftUI implementation with local file reads, no persistent helper daemon, and tuned refresh intervals for low energy and RAM use.
- Responsive dock rotation for usage, model, task, and chat cards without heavy polling.
- Repo-ready package with screenshots, examples, changelog, and marketplace submission notes.

Note: model/reasoning controls update Codex defaults for new work. They do not change already-running chats.
