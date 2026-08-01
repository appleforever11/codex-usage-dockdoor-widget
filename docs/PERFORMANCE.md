# Performance Notes

Codex Usage is designed to stay thin inside DockDoor Pro.

## Runtime Shape

- Native SwiftUI rendering.
- Local file reads only.
- No network calls.
- No helper daemon.
- No external package dependencies.
- No persistent background process outside DockDoor Pro's widget host.

## Refresh Behavior

- Usage and session snapshots refresh periodically. Live account limits are decoded from small tails of the newest session files, and scanning stops as soon as both the General and model-specific streams are found.
- The compact dock card rotates every few seconds.
- The compact card also keeps one complete snapshot in memory so opening the expanded panel does not repeat the session scan before recent chats can appear.
- The expanded panel refreshes time labels less frequently because reset labels and account usage do not need second-level polling.

## Why This Matters

The widget is meant to be visible all day. Keeping the implementation simple reduces wakeups, memory churn, and unnecessary background work while preserving the responsive dock feel.
