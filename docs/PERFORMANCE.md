# Performance Notes

Codex Usage is designed to stay thin inside DockDoor Pro.

## Runtime Shape

- Native SwiftUI rendering.
- Astra's 12-star Canvas schedules up to 18 updates per second while visible and selected or hovered. It pauses when inactive or hidden and respects Reduce Motion. Its energy and memory impact have not been benchmarked.
- Widget-side local file reads only.
- No widget-side network calls or subprocess launches.
- No persistent helper daemon.
- No external package dependencies in the widget. Sparkle 2.9.6 is embedded only in the standalone companion application.
- No persistent background process outside DockDoor Pro's widget host.

The optional live-sync LaunchAgent runs one short Codex app-server request every 60 seconds, writes the result atomically, and exits. It uses Codex's existing signed-in local service rather than making a separate web request.

The update LaunchAgent opens the companion at login and every six hours for a Sparkle check. The companion exits when a background update cycle finishes; a manual check or an installation keeps its window open until dismissed. Sparkle performs network downloads outside DockDoor Pro. End-to-end energy and RAM costs have not been benchmarked.

## Refresh Behavior

- Usage and session snapshots refresh periodically. The one-shot companion updates `~/.codex/usage.json` from `account/rateLimits/read`; the widget decodes that small snapshot first. When it is unavailable, account limits are decoded from small tails of the newest session files and scanning stops as soon as both the General and model-specific streams are found.
- The compact dock card rotates every few seconds.
- The compact card also keeps one complete snapshot in memory so opening the expanded panel does not repeat the session scan before recent chats can appear.
- The panel waits for that complete snapshot and uses a fixed-size cold-start state, preventing partial menus, late chat rows, and layout jumps during the first hover.
- The expanded panel refreshes time labels less frequently because reset labels and account usage do not need second-level polling.

## Why This Matters

The widget is meant to be visible all day. Keeping rendering and scanning simple reduces wakeups and memory churn. The account sync is intentionally periodic and non-resident, preserving accurate limits without turning the widget into a network client or long-running service.
