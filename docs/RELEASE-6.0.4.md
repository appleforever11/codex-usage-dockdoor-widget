# Codex Usage 6.0.4

## 🛠️ ChatGPT/Codex macOS app compatibility

The ChatGPT/Codex desktop app update **26.924.20706** moved its bundled Codex executable. The private live-sync helper was still searching the old location, so account snapshots stopped refreshing and the widget could show stale data.

- 🔄 Live sync now discovers the executable at `Contents/Resources/codex-cli/bin/codex` in both ChatGPT and Codex desktop app bundles.
- 📊 Account percentages and prepaid credits continue to come from the authoritative local app-server response.
- 🧮 Window and Today totals now use bounded local session token events when the account snapshot does not provide token counts, instead of displaying misleading zeros.
- 🕰️ The existing stale-data warning remains available when an account snapshot truly is old.
- 🧪 Added five-hour rolling-window and daily-total regression coverage; verified the new app-bundled executable path with a restricted system `PATH`.

This is a **private companion/personal-widget patch**. The marketplace edition remains read-only, has no sync helper or Sparkle dependency, and continues to update through DockDoor Pro.

## Download and update

- [Download the Mac installer](https://github.com/appleforever11/codex-usage-dockdoor-widget/releases/download/v6.0.4/Codex.Usage.for.DockDoor.Pro.v6.0.4.dmg).
- [Download the companion ZIP](https://github.com/appleforever11/codex-usage-dockdoor-widget/releases/download/v6.0.4/CodexUsage-v6.0.4.zip).
- Existing users can use **Check for Updates** in the companion app.

Supports Apple silicon and Intel Macs on macOS 14 or later. Requires DockDoor Pro and local Codex data.
