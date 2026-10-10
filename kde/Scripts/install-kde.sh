#!/usr/bin/env bash
# Installs the Codex Usage plasmoid (QML) and its Rust helper daemon:
#   1. cargo build --release          (kde/helper)
#   2. ~/.local/libexec/codex-usage-helper
#   3. systemd user service (enabled + started)
#   4. Plasma/Applet package via kpackagetool6 (installed/upgraded)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
helper_src="$repo_root/kde/helper"
plasmoid_src="$repo_root/kde/plasmoid"
helper_dest="$HOME/.local/libexec/codex-usage-helper"
unit_src="$repo_root/kde/systemd/codex-usage-helper.service"
unit_dest="$HOME/.config/systemd/user/codex-usage-helper.service"
plasmoid_id="io.github.appleforever11.codex-usage"

say() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

command -v cargo >/dev/null 2>&1 || die "cargo not found — install rustup or the rust toolchain"
command -v kpackagetool6 >/dev/null 2>&1 || die "kpackagetool6 not found — install kpackage"

say "Building the Rust helper (release)…"
(cd "$helper_src" && cargo build --release)

say "Installing helper to $helper_dest"
mkdir -p "$(dirname "$helper_dest")"
install -m 0755 "$helper_src/target/release/codex-usage-helper" "$helper_dest"

say "Installing systemd user service"
mkdir -p "$(dirname "$unit_dest")"
install -m 0644 "$unit_src" "$unit_dest"
systemctl --user daemon-reload
systemctl --user enable --now codex-usage-helper.service
sleep 0.5

say "Helper health check"
if curl -fsS "http://127.0.0.1:47631/health" >/dev/null 2>&1; then
    echo "  helper is serving on 127.0.0.1:47631"
else
    echo "  warning: helper did not answer /health yet — check: journalctl --user -u codex-usage-helper -e"
fi

say "Installing the plasmoid package"
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$plasmoid_id"; then
    kpackagetool6 --type Plasma/Applet --upgrade "$plasmoid_src"
else
    kpackagetool6 --type Plasma/Applet --install "$plasmoid_src"
fi

cat <<'TIP'

Done. Add "Codex Usage" to your panel (Right-click panel → Add Widgets…),
or preview it immediately with:

    plasmawindowed io.github.appleforever11.codex-usage

If the panel already contained an older copy, restart Plasma to reload it:

    systemctl --user restart plasma-plasmashell.service   # or: kquitapplication6 plasmashell && kstart plasmashell

Logs: journalctl --user -u codex-usage-helper -f
TIP
