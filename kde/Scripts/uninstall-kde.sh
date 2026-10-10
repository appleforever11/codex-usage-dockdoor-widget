#!/usr/bin/env bash
# Removes the Codex Usage plasmoid and its helper daemon.
set -euo pipefail

plasmoid_id="io.github.appleforever11.codex-usage"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }

say "Stopping the helper service"
systemctl --user disable --now codex-usage-helper.service 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/codex-usage-helper.service"
systemctl --user daemon-reload

say "Removing helper binary"
rm -f "$HOME/.local/libexec/codex-usage-helper"

say "Removing plasmoid package"
kpackagetool6 --type Plasma/Applet --remove "$plasmoid_id" 2>/dev/null || echo "  (not installed)"

echo "Optional: remove helper data (settings, snapshot cache, analytics):"
echo "  rm -rf ~/.config/codex-usage-plasmoid ~/.local/state/codex-usage-plasmoid"
