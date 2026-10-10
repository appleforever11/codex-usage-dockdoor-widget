# Codex Usage — KDE Plasma Port

A KDE Plasma 6 plasmoid port of the [DockDoor Pro Codex Usage widget](../README.md),
with all logic moved into a Rust helper daemon. Built for the ChatGPT-subscription
Codex CLI (`~/.codex`) on Linux — including borrowed/shared subscriptions — where
the account limits come from the local Codex app-server instead of the macOS ChatGPT app.

```
+-------------------+     HTTP 127.0.0.1:47631      +---------------------------+
|  Plasma plasmoid  | <---------------------------  |  codex-usage-helper (Rust) |
|  QML (this UI)    |   /snapshot /refresh /model   |  - codex app-server RPC   |
|                   |   /settings /open /health     |  - session telemetry      |
+-------------------+                               |  - analytics + usage.json |
                                                    +---------------------------+
```

Pure-QML plasmoids cannot spawn processes or read files, so the helper is the
bridge: it performs the `account/rateLimits/read` JSON-RPC against
`codex app-server --listen stdio://` (the same call the macOS live-sync agent
used), writes a macOS-compatible `~/.codex/usage.json`, scans
`~/.codex/sessions` for token telemetry, and serves one combined snapshot
document to the plasmoid over loopback HTTP.

## What's ported

- **Compact dock widget**: themed usage ring with sparkles, rotating card deck
  (General/credits/model/tasks/chats/burn/cost), LIVE/STALE/SYNC status,
  hover pause, compact + extended layouts, wheel-pinned rotation.
- **Dashboard**: four swipeable pages (Overview · Activity · Models · Health)
  with per-page themes (Astra, Luna, Sol, Terra, Rainbow), 24 cards, filter
  bars, page dots, arrangement mode (move/reorder), and footer navigation.
- **Style modes**: Apple liquid glass (default, per-page planet themes),
  Plasma style (accent, data colors, and tint follow the system color
  scheme), or a custom accent color — switchable in the Appearance popover
  and the settings dialog.
- **Percentage ring styles**: gradient (glow + sparkles), solid, dual
  (inner companion ring), segments, and dial ticks — plus thickness (3–12px)
  and a sparkles toggle, shared by the overview hero wheel and the panel
  gauge; both live in the Appearance popover and the settings dialog.
- **Keyboard**: ←/→ or 1–4 switch pages, ↑/↓ scroll, R refreshes, A opens
  the Appearance popover, E toggles card arrangement, Esc closes the popover.
- **Visual language**: breathing atmospheres, deterministic starfields,
  gradient progress bars with traveling highlights, interactive column charts,
  identity artwork buttons, planet markers — all the SwiftUI canvas math
  ported to QML Canvas.
- **Model defaults**: the account's live model catalog (app-server
  `model/list`) drives curated family buttons + variant chips, each model's
  own reasoning ladder (low · medium · high · xhigh · max · ultra), and the
  `/fast` speed-tier toggle — all writing `~/.codex/config.toml`
  (root-section upsert, nested profiles preserved). A curated fallback
  catalog covers offline starts.
- **KDE extras**: reset-credit chip ("Full reset available"), plan type, and
  `codex://threads/<id>` deep links via `xdg-open`.

## Install

```bash
bash kde/Scripts/install-kde.sh     # builds helper, installs systemd unit + plasmoid
```

Then add **Codex Usage** to your panel, or preview with
`plasmawindowed io.github.appleforever11.codex-usage`. If you upgraded an
existing install, restart Plasma:
`systemctl --user restart plasma-plasmashell.service`.

Remove everything with `bash kde/Scripts/uninstall-kde.sh`.

## Requirements

- Plasma 6 (tested 6.7.5 / Qt 6.11) and `kpackage` (`kpackagetool6`)
- Rust toolchain (build-time only)
- Codex CLI signed in (`~/.codex/auth.json`) — the helper discovers the
  `codex` binary on `PATH` (override with `CODEX_BIN=` or install a copy at a
  standard location). Without it, the helper falls back to direct backend
  requests using the stored tokens.

## Files

| Path | Purpose |
| --- | --- |
| `kde/helper/` | Rust daemon — app-server RPC, HTTP fallback, session telemetry, analytics, config.toml writer, snapshot server |
| `kde/plasmoid/` | Plasma package (metadata.json, QML UI, config pages) |
| `kde/systemd/` | `codex-usage-helper.service` user unit |
| `kde/Scripts/install-kde.sh` | build + install everything |
| `kde/Scripts/check-qml.py` | compile every QML file with the real QML engine (CI-style gate) |

## Helper API (loopback only)

All routes send `Access-Control-Allow-Origin: *` and answer `OPTIONS` preflights,
so browser-side dashboards and other local tools can consume the live data too.

| Route | Method | Purpose |
| --- | --- | --- |
| `/snapshot` | GET | full snapshot document (usage, telemetry, analytics, sessions, dock cards, `availableModels`) |
| `/refresh` | POST | signal a full account refresh; answers `202` immediately — poll `/snapshot` for the new `generatedAt` |
| `/model` | GET/POST | read / write new-chat defaults: `{"model","reasoning","fast":true}` (or `"serviceTier":"fast"\|"default"`); reasoning validates against the model's own ladder |
| `/settings` | GET/POST | helper settings mirrored from the plasmoid's config |
| `/open` | POST | open a chat: `{"sessionId","mode":"transcript"}` renders Markdown and opens it in the configured viewer (default `xdg-open {file}`); `mode:"link"` deep-links `codex://threads/<uuid>` |
| `/chats` | GET | recent sessions with titles/project/activity |
| `/transcript?id=<uuid>` | GET | a session rendered as readable Markdown (`{ok, markdown, filePath}`) |
| `/metrics` | GET | Prometheus text exposition (quota, tokens, burn, cost, counts, model) |
| `/health` | GET | liveness, version, codex binary, last refresh time |

Quick examples:

```bash
curl -s localhost:47631/metrics                 # scrape into Prometheus/Grafana
curl -s localhost:47631/chats | jq '.chats[0]'
curl -s "localhost:47631/transcript?id=<uuid>" | jq -r .markdown | less
curl -s -X POST localhost:47631/open -d '{"sessionId":"<uuid>"}'   # opens in your editor
```

The chat viewer command is configurable (plasmoid settings → General, or
`POST /settings {"chatViewerCommand": "kitty -e nvim {file}"}`); `{file}` is
replaced with the shell-quoted Markdown transcript under
`~/.cache/codex-usage-plasmoid/transcripts/`.

CLI: `codex-usage-helper daemon|once|set-model --model M --reasoning low|medium|high|xhigh|max|ultra [--fast|--no-fast]|doctor|refresh-account`.

## Data & privacy

Account percentages come from the signed-in Codex account via the local
app-server and are written to `~/.codex/usage.json` (identical shape to the
macOS agent's). Token telemetry is derived only from local session files and
stays on this machine. The helper binds to `127.0.0.1` only and the systemd
unit denies non-loopback network access. Refresh cadence defaults to one
account request per minute, matching the macOS widget's live-sync agent.

## Testing

```bash
cd kde/helper && cargo test                 # 23 unit tests (Swift test parity)
python3 kde/Scripts/check-qml.py kde/plasmoid   # whole-package QML compile gate
python3 kde/Scripts/render-preview.py           # offscreen render vs the live helper
```
