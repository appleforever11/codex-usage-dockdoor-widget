#!/bin/zsh
set -euo pipefail

companion="$HOME/Applications/Install Codex Usage.app"
if [[ ! -d "$companion" ]]; then
    print -u2 'Install the v4.1.0 or later DMG once to enable Sparkle updates.'
    exit 1
fi
if [[ "${1:-}" == "--background" ]]; then
    /usr/bin/open -g "$companion" --args --background
else
    /usr/bin/open 'codexusage://check-for-updates'
fi
