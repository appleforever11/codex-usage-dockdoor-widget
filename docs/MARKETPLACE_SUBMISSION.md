# Marketplace Submission Notes

Use this checklist when preparing a pull request against `ejbills/dockdoorpro-widgets`.

## Target

- Marketplace repo: `https://github.com/ejbills/dockdoorpro-widgets`
- Widget folder: `Widgets/CodexProjectTracker`
- Widget id: `codex-project-tracker`
- Widget name: `Codex Usage`
- Current package version: `3.0.0`

## Pre-PR Checklist

- Build with `bash Scripts/build-widgets.sh Widgets/CodexProjectTracker`.
- Confirm `Build/CodexProjectTracker.bundle.zip` is regenerated.
- Test the installed bundle in the current DockDoor Pro build.
- Verify compact dock mode rotates between usage, model, tasks, and chats.
- Verify the panel palette button toggles the rainbow usage ring.
- Verify DockDoor settings exposes `Rainbow Usage Ring`.
- Verify model/reasoning buttons update `~/.codex/config.toml`.
- Verify recent chat rows open Codex tasks when the session id is available.
- Refresh screenshots if the UI changed.

## Suggested PR Title

Add Codex Usage widget with usage countdown, defaults controls, and chat deep links

## Suggested PR Summary

This adds Codex Usage 3.0.0 for DockDoor Pro. It shows Codex account usage countdowns, credits, recent chats, project/task counts, and local Codex default controls directly from the dock. Account limits synchronize from the newest `rate_limits` events already written by Codex, with `~/.codex/usage.json` retained only as a compatibility fallback. The widget includes a rainbow usage ring setting, clickable Codex task rows, and model/reasoning selectors for new Codex work. It is intentionally lightweight: local file reads, native SwiftUI rendering, no helper daemon, and modest refresh intervals for low energy and memory use.

## Suggested Discord Patch Notes

**Codex Usage Widget v3.0.0**

This is the big Codex Usage release for DockDoor Pro. The widget has evolved from a simple tracker into a polished, lightweight Codex command center right in the dock.

- New usage countdown ring built for quick scanning from the dock.
- Optional rainbow/glow usage tracking toggle from the widget panel and DockDoor settings.
- Credits, general limits, model-specific limits, reset dates, tasks, and chats in one compact view.
- Smooth gradient model and reasoning selectors for Codex defaults.
- Recent chats stay selectable and open Codex tasks directly when possible.
- Ultra-thin native SwiftUI implementation with local file reads, no helper daemon, and tuned refresh intervals for low energy and RAM use.
- Responsive dock rotation for usage, model, task, and chat cards without heavy polling.
- Repo-ready package with screenshots, examples, changelog, and marketplace submission notes.

Note: model/reasoning controls update Codex defaults for new work. They do not change already-running chats.
