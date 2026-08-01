# Changelog

## 3.0.1 - Live Account Sync Fix

- Added an optional one-shot sync agent that reads the signed-in account's current limits from Codex's local `account/rateLimits/read` app-server RPC.
- Refreshes `~/.codex/usage.json` every 60 seconds so the dock and panel track the current General and Spark percentages instead of stale legacy session telemetry.
- Writes snapshots atomically and preserves the last valid result when Codex is temporarily unavailable.
- Added bounded retries for occasional slow app-server startup.
- Kept the widget itself lightweight and local-only; the sync process runs briefly on demand and exits instead of remaining resident.
- Added install and uninstall scripts, launchd configuration, and diagnostic logs for the live-sync companion.

## 3.0.0 - Major Usage Countdown Release

Codex Usage 3.0.0 is the big release. The widget has grown from a simple project tracker into a full DockDoor Pro command center for Codex usage, chats, tasks, and local defaults.

- Rebuilt the primary dock experience around a fast usage countdown ring.
- Added optional rainbow/glow usage tracking with both DockDoor settings support and an in-panel palette toggle.
- Added account usage parsing from `~/.codex/usage.json`, including credits, weekly limits, percent remaining, and reset labels.
- Fixed real-time account synchronization by treating an explicit `~/.codex/usage.json` account snapshot as authoritative, preventing older session telemetry or reset windows from overriding the current subscription state.
- Retained the newest General and model-specific session `rate_limits` events as a fallback when the explicit account snapshot is unavailable or invalid.
- Added automatic weekly-window rollover handling so an expired local event displays a fresh 100% window until Codex emits its next authoritative update.
- Fixed staged panel loading by caching the compact widget's complete snapshot and presenting usage, controls, and recent chats together on the first expanded-panel frame.
- Added a fixed-size cold-start loading state so the panel never exposes empty sections or changes height while session data is still being assembled.
- Balanced compact-card ring and text spacing so the usage circle stays inside the card without crowding the label at either edge.
- Added rotating dock cards for usage limits, selected model, tasks, and chats.
- Added Codex Defaults controls for model and reasoning preferences.
- Improved model and reasoning controls with smoother rounded cells, gradient fills, hover states, and selected-state glow.
- Reduced the older green-heavy styling in favor of cleaner cyan/blue activity accents and optional rainbow usage visuals.
- Preserved recent chat selection and Codex task deep links.
- Tuned dock and panel refresh intervals so the widget stays responsive without waking more often than it needs to.
- Tightened external usage snapshot refreshes so `~/.codex/usage.json` changes are picked up faster.
- Kept the widget ultra-thin: it reads local Codex files directly, uses simple SwiftUI views, avoids background daemons, and only refreshes lightweight snapshots.
- Added standalone repo documentation, screenshots, examples, marketplace notes, and release copy.
- Published the final square promotional artwork as the starter attachment for the canonical Discord v3.0.0 repost.

## 0.2.0 - Clickable Chat Tracker

- Added selectable recent Codex chats in the widget panel.
- Added Codex task deep-link support using `codex://threads/<session-id>`.
- Added task/chat counters and recent session scanning.
- Updated the widget panel for a denser live project-tracker layout.

## 0.1.0 - Initial DockDoor Pro Widget

- Added the first Codex tracker widget for DockDoor Pro.
- Added compact dock and expanded panel views.
- Added local Codex project/session scanning.
