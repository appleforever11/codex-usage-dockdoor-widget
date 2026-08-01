CODEX USAGE FOR DOCKDOOR PRO v3.1.0
====================================

QUICK INSTALL

1. Install, launch, and activate DockDoor Pro on the Mac mini.
2. Install and sign in to the Codex or ChatGPT desktop app.
3. Double-click "Install Codex Usage.command".
4. If macOS asks, choose Open.
5. Hover over Codex Usage in the DockDoor Pro dock after the installer finishes.

The installer does not need an administrator password. It will:

- Back up an existing Codex widget instead of deleting it.
- Install the universal Apple Silicon and Intel widget bundle.
- Preserve the existing Codex widget identifier and dock placement.
- Install a lightweight 60-second live account-usage synchronizer.
- Restart DockDoor Pro and verify the first usage snapshot.

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

Usage snapshot:
~/.codex/usage.json

Widget backups:
~/Library/Application Support/DockDoorPro/WidgetInstallerBackups/

To remove the widget without permanently deleting its bundle, double-click
"Remove Codex Usage.command". The removed widget is moved into a backup folder.
