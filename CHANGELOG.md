# Changelog

## 6.0.3 — 2026-09-22

- Added Luna-6 (`gpt-6-luna`) and Sol-6 (`gpt-6-sol`) to new-chat controls and removed GPT-5.6 Luna/Sol from the writable model list.
- Centralized model IDs and generation-aware labels across dock cards, session telemetry, and analytics; older sessions keep their recorded generation.
- Updated appearance and accessibility labels while preserving personal saved palettes and hover/selection haptics.
- Preserved the 6.0.2 prepaid-credit fix and the existing Mac installer/Sparkle signing path.
- Based the separate marketplace follow-up on ejbills' merged #27, retaining its host-compatible move menus, persistent layouts, shared file discovery, and light-mode readability.


## 6.0.2 - Prepaid credit display fix (2026-09-21)

- 🔧 Fixed the prepaid-credit display so the raw account quantity is no longer presented as a misleading dollar amount or a long floating-point string.
- 🧾 Grouped and rounded the balance for readability, with clear **Prepaid credits** and **Prepaid balance** labels.
- 🧭 Added an in-widget explanation that prepaid credits are separate from the weekly General allowance, so an exhausted usage window is not confused with the credit balance.
- 🔄 Applied the same formatting to live session fallback data, the synced `~/.codex/usage.json` path, dock cards, and the expanded dashboard.
- 🧪 Added focused formatter coverage and rebuilt the universal Apple silicon/Intel widget.
- 🔒 Private companion and personal widget patch only; the marketplace `codex-usage` variant remains unchanged.

## 5.0.5 - Model attribution fix (2026-09-13)

- Fixed local token telemetry for current Codex session logs by reading the active model and reasoning level from `turn_context` records.
- Preserved compatibility with older `thread_settings_applied` telemetry and added regression coverage for both formats.

## 5.0.4 - Local token activity (2026-09-07)

- Added local session token parsing for input, cached input, output, reasoning output, and total-token deltas.
- Added near-real-time burn rates, context-window percentage, freshness state, and a compact burn dock card.
- Added per-model and reasoning-level breakdowns for Astra, Terra, Luna, Sol, and unknown metadata buckets.
- Made the Token activity panel collapsible, keeping the live burn summary visible while the chart and details stay out of the way until expanded.
- Kept telemetry private and bounded: the widget reads small head/tail slices of local JSONL files and sends no token data over the network.

## 5.0.2 - Local transparency controls (2026-09-04)

- Added a 20–100% background-opacity slider and Frosted glass toggle to the palette popover.
- Text, controls, and ring sparkles remain fully visible while the panel background changes.
- Defaults to 75% opacity with native frosted material; respects macOS Reduce Transparency.
- Local widget update only; existing installers and marketplace submission are unchanged.


## 5.0.1 - Installer launch handoff (2026-09-04)

- Launch the installed companion in a distinct process so Launch Services cannot reuse the DMG launcher and then quit it.
- Mark the installed-copy handoff to avoid repeated relocation if macOS translocates the application.
- Show an actionable error when an older companion is still running, and reopen the installer window when a background instance is activated.
- The widget and marketplace edition are otherwise unchanged.


## 5.0.0 - Model Themes and Astra Sparkles (2026-09-04)

- Added Astra, Luna, Sol, Terra, and Rainbow themes for the ring and expanded widget, selectable through the palette button.
- Added Astra-only live sparkle animation on the filled progress arc, with a static Reduce Motion path.
- Added Terra model controls, removed Spark selection and its shortcut, and mapped Light reasoning to Codex's supported low value.
- Added matching companion app palettes. Sparkle remains exclusive to the private companion; the marketplace edition uses DockDoor Pro updates.
- Refactored the widget into focused files, repaired extended-layout hover pausing and chat-list sizing, and improved refresh and configuration-write handling.
- One signed universal installer supports MacBook, MacBook Neo, and Mac mini on macOS 14 or later.


## 4.1.0 - Astra and Signed Sparkle Updates (2026-09-04)

This focused feature release adds Astra as a first-class next-chat model while preserving the tracker's local-first performance and existing DockDoor Pro layout.

- Added Astra (`gpt-6-astra`) to the Codex Defaults model picker.
- Added a dark-purple glowing starfield treatment with deterministic twinkle animation for the Astra button.
- Paused Astra animation when the control is neither selected nor hovered to avoid unnecessary wakeups.
- Respect macOS Reduce Motion and stop the starfield timeline when the control disappears.
- Reflowed the model controls into a four-column grid so Astra joins Luna, Sol, and Spark without cramped labels or edge collisions.
- Added a sparkle glyph and stronger selected-state edge treatment so Astra remains recognizable in a translucent DockDoor panel.
- Added Astra name resolution to the compact model card and accepted Astra in the local defaults writer.
- Kept the existing Max reasoning option and Fast mode behavior unchanged; Astra applies to new Codex work only.
- Use a fixed 12-star SwiftUI Canvas at a maximum schedule of 18 updates per second. Energy and memory impact have not been benchmarked.
- Added a widget-header update button and Sparkle 2.9.6 in the standalone companion app, not in DockDoor Pro's process.
- Added signed Ed25519 update archives, a release appcast, notarized application payloads, and a notarized DMG.
- The companion installs itself in the user's Applications folder; after a Sparkle update it applies the bundled widget and restarts DockDoor Pro.
- Stage and verify the widget before replacement, preserve its existing filename, and restore the backup on installation failure.
- Replaced the legacy direct-download updater with short Sparkle checks at login and every six hours. Existing users need one v4.1.0 DMG installation per Mac.
- The separate marketplace proposal adds read-only Astra usage styling only. It contains no Sparkle framework, configuration writes, or helper installer.

## 4.0.0 - Fresh Usage and Responsive Dock Release (2026-08-22)

Codex Usage 4.0.0 is a major reliability and interaction release. It makes the widget much clearer about where its usage numbers come from, keeps the dock responsive during refreshes, and gives users more control over what the compact card shows.

- Added timestamp-aware account snapshots with ISO reset timestamps and a visible freshness indicator.
- Added stale-data warnings when the account snapshot is missing an update time or is more than 15 minutes old.
- Removed the misleading local 100% default when no Codex session or authoritative account snapshot exists.
- Labeled session telemetry and local token-window values as fallbacks or estimates instead of presenting them as account usage.
- Added a cache invalidation signature for usage files, Codex config, history, and session files so updates appear without redundant full rescans.
- Removed a duplicate snapshot build from the refresh path and moved the cache to Swift actor isolation for modern Swift toolchain compatibility.
- Added an in-panel refresh button for an immediate authoritative-data check.
- Added selectable primary dock cards for Usage, Model, Tasks, Chats, and Credits.
- Added configurable card rotation speed, hover pause, and optional freshness display through DockDoor settings.
- Added reset countdown formatting with day, hour, and minute precision when Codex provides a reset timestamp.
- Kept the compact card and expanded panel on stable dimensions so loading and refreshes do not move the dock layout.
- Preserved the v3.2 Max reasoning controls, Fast mode, rainbow ring, direct Codex chat links, updater, and Mac mini installer.
- Kept the runtime local-first and lightweight: no widget-side network calls, no persistent helper daemon, and no new external dependencies.

## 3.2.0 - Max Reasoning and Mac Mini Update Pipeline

- Replaced the High reasoning cell with Max and write Codex's native `max` reasoning value.
- Normalize legacy `high` and `xhigh` defaults to Max so upgrades retain an active reasoning selection.
- Added a Mac updater that checks the latest stable GitHub release at login and every six hours.
- Added semantic version comparison to prevent release downgrades.
- Require GitHub's published SHA-256 asset digest before installing an update.
- Validate bundle metadata and universal Apple Silicon/Intel architectures before replacing the installed widget.
- Preserve the existing marketplace bundle name and dock placement, with timestamped rollback backups.
- Added an automated GitHub tag pipeline that builds and publishes the widget bundle, DMG, ZIP, live-sync scripts, and updater scripts.
- Integrated updater installation and removal into the self-contained Mac package.

## 3.1.0 - Fast Mode Toggle

- Added a one-click lightning toggle directly to the left of the rainbow-ring control.
- Fast mode changes the defaults for new Codex chats to Spark with Instant reasoning.
- Turning fast mode off restores the model and reasoning defaults that were active before it was enabled.
- The lightning button derives its active state from the real Codex configuration, so manual model or reasoning changes remain accurately reflected.
- Added a yellow active treatment and concise hover help without increasing the panel header height.

## 3.0.1 - Live Account Sync Fix

- Added an optional one-shot sync agent that reads the signed-in account's current limits from Codex's local `account/rateLimits/read` app-server RPC.
- Refreshes `~/.codex/usage.json` every 60 seconds so the dock and panel track the current General and Spark percentages instead of stale legacy session telemetry.
- Writes snapshots atomically and preserves the last valid result when Codex is temporarily unavailable.
- Added bounded retries for occasional slow app-server startup.
- Kept the widget itself lightweight and local-only; the sync process runs briefly on demand and exits instead of remaining resident.
- Added install and uninstall scripts, launchd configuration, and diagnostic logs for the live-sync companion.
- Added a self-contained Mac installer DMG and ZIP with one-click widget installation, automatic backup, dock-placement preservation, live-sync setup, verification, and recoverable removal.

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
