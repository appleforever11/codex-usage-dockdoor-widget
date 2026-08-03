# Marketplace Submission Notes

Use this checklist when preparing a pull request against `ejbills/dockdoorpro-widgets`.

## Target

- Marketplace repo: `https://github.com/ejbills/dockdoorpro-widgets`
- Marketplace widget folder: `Widgets/CodexUsage`
- Marketplace widget id: `codex-usage`
- Widget name: `Codex Usage`
- Standalone release: `3.2.0`
- Marketplace PR: `https://github.com/ejbills/dockdoorpro-widgets/pull/21`
- Canonical Discord discussion: `https://discord.com/channels/1312172160931856464/1532985348374659092`

The standalone v3.2.0 project is intentionally broader than the marketplace submission. The marketplace contribution is a separate widget with a new identifier so it cannot silently replace the existing `codex-project-tracker` installation.

## Pre-PR Checklist

- Build the marketplace checkout with `bash scripts/build-widgets.sh Widgets/CodexProjectTracker Widgets/CodexUsage`.
- Confirm `CodexProjectTracker` is unchanged from marketplace `main`.
- Confirm `CodexUsage` has its own `codex-usage` identifier and supports both dock orientations.
- Verify the marketplace widget reads `~/.codex/usage.json` without writing it.
- Verify DockDoor settings exposes only the `Rainbow Usage Ring` preference for the marketplace widget.
- Confirm the marketplace widget contains no scripts, LaunchAgent, process spawning, network calls, or Codex config writes.
- Test the read-only bundle in the current DockDoor Pro build.
- Keep the full installer, live-sync helper, updater, screenshots, and release notes in the standalone repository only.

## Suggested PR Title

Add separate read-only Codex Usage widget

## Suggested PR Summary

This is a fresh marketplace submission for the separate `codex-usage` identifier. It leaves `codex-project-tracker` unchanged and adds a native SwiftUI usage widget that reads `~/.codex/usage.json` only. It shows General and model-specific percentages, credits, reset labels, reset countdowns, compact dock rotation, and a rainbow ring setting. The marketplace bundle contains only `widget.json` and Swift source: no config writes, process spawning, network calls, LaunchAgent, scripts, or installer. The full v3.2.0 project and optional local synchronization tooling remain in this standalone repository.

## Suggested Discord Patch Notes

**Codex Usage Widget v3.2.0**

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
