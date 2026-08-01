# Changelog

## 3.0.0 - Major Usage Countdown Release

Codex Usage 3.0.0 is the big release. The widget has grown from a simple project tracker into a full DockDoor Pro command center for Codex usage, chats, tasks, and local defaults.

- Rebuilt the primary dock experience around a fast usage countdown ring.
- Added optional rainbow/glow usage tracking with both DockDoor settings support and an in-panel palette toggle.
- Added account usage parsing from `~/.codex/usage.json`, including credits, weekly limits, percent remaining, and reset labels.
- Added rotating dock cards for usage limits, selected model, tasks, and chats.
- Added Codex Defaults controls for model and reasoning preferences.
- Improved model and reasoning controls with smoother rounded cells, gradient fills, hover states, and selected-state glow.
- Reduced the older green-heavy styling in favor of cleaner cyan/blue activity accents and optional rainbow usage visuals.
- Preserved recent chat selection and Codex task deep links.
- Tuned dock and panel refresh intervals so the widget stays responsive without waking more often than it needs to.
- Tightened external usage snapshot refreshes so `~/.codex/usage.json` changes are picked up faster.
- Kept the widget ultra-thin: it reads local Codex files directly, uses simple SwiftUI views, avoids background daemons, and only refreshes lightweight snapshots.
- Added standalone repo documentation, screenshots, examples, marketplace notes, and release copy.

## 0.2.0 - Clickable Chat Tracker

- Added selectable recent Codex chats in the widget panel.
- Added Codex task deep-link support using `codex://threads/<session-id>`.
- Added task/chat counters and recent session scanning.
- Updated the widget panel for a denser live project-tracker layout.

## 0.1.0 - Initial DockDoor Pro Widget

- Added the first Codex tracker widget for DockDoor Pro.
- Added compact dock and expanded panel views.
- Added local Codex project/session scanning.
