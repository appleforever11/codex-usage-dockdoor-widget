CODEX USAGE FOR DOCKDOOR PRO v4.1.0
====================================

QUICK INSTALL

1. Install, launch, and activate DockDoor Pro on the Mac mini.
2. Install and sign in to the Codex or ChatGPT desktop app.
3. Double-click "Install Codex Usage.app".
4. The companion copies itself to your user Applications folder. Click "Install
   Widget" for a fresh installation; an older widget updates automatically.
5. Hover over Codex Usage in the DockDoor Pro dock after the installer finishes.

The app-based installer does not open Terminal, does not require an administrator
password, and is signed and notarized for Gatekeeper-friendly installation. It will:

- Back up an existing Codex widget instead of deleting it.
- Install the universal Apple Silicon and Intel widget bundle.
- Preserve the existing Codex widget identifier and dock placement.
- Install a lightweight 60-second live account-usage synchronizer.
- Install a Sparkle companion that checks at login and every six hours.
- Restart DockDoor Pro and verify the first usage snapshot.

FUTURE UPDATES

Click the update icon in the widget header or "Check for Updates" in the companion
app. Approve Sparkle's update prompt. The companion updates itself, applies its
bundled widget, and restarts DockDoor Pro. No Terminal command is needed.

Users on older releases must install this DMG once on each Mac to add Sparkle.
The separate marketplace edition updates through DockDoor Pro, not this companion.

REQUIREMENTS

- macOS 14 or later
- DockDoor Pro installed and activated
- Codex.app, ChatGPT.app, or the codex command-line tool
- A signed-in Codex account for live usage percentages

TROUBLESHOOTING

If the custom dock or widget does not appear after transferring to another Mac,
open DockDoor Pro and verify that it is activated on that Mac first.

Live-sync logs:
~/Library/Logs/CodexUsageWidget/

Updater log:
~/Library/Logs/CodexUsageWidget/updater.log

Companion app:
~/Applications/Install Codex Usage.app

Usage snapshot:
~/.codex/usage.json

Widget backups:
~/Library/Application Support/DockDoorPro/WidgetInstallerBackups/
