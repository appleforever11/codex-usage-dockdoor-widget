# KDE Port Handoff — Codex Usage Plasmoid

Everything that was built for the KDE Plasma port after the Swift/DockDoor (macOS)
line. The git history in this repo is still 100 % the macOS widget (through
`a48c6ec` "Release 6.0.4"); **the entire KDE port lives in `kde/` and is not yet
committed** (`git status`: `?? kde/`, plus a modified root `README.md` that
adds a pointer blurb to the port).

Two shipping artifacts:

| Artifact | Version | What it is |
| --- | --- | --- |
| `kde/helper/` → `codex-usage-helper` | 6.3.0 | Rust daemon holding **all** logic (account RPC, telemetry, analytics, config.toml writer, HTTP snapshot server) |
| `kde/plasmoid/` → `io.github.appleforever11.codex-usage` | 6.1.0 | Plasma 6 QML package — pure presentation, zero file/process access |

---

## 1. Architecture

```
+-------------------+     HTTP 127.0.0.1:47631      +------------------------------+
|  Plasma plasmoid  | <---------------------------  |  codex-usage-helper (Rust)   |
|  QML (UI only)    |   /snapshot /refresh /model   |  ├─ codex app-server RPC     |
|                   |   /settings /open /chats      |  ├─ HTTP fallback (auth.json)|
|                   |   /transcript /metrics /health|  ├─ ~/.codex/sessions scan   |
+-------------------+                               |  ├─ analytics caches + pace  |
                                                    |  └─ config.toml model writer |
                                                    +------------------------------+
```

Why a helper at all: **pure-QML plasmoids cannot spawn processes or read files**,
Qt 6.8+ disables `file://` XHR by default, but QML `XMLHttpRequest` has **no
same-origin restriction** — so a loopback-only HTTP daemon is the bridge. This
mirrors the macOS widget's split (SwiftUI UI + live-sync agent), except the
Linux backend is one Rust binary instead of an app bundle.

Hard boundaries:

- Helper binds `127.0.0.1` only; the systemd unit additionally enforces
  `IPAddressAllow=localhost` / `IPAddressDeny=any`.
- The plasmoid renders; the helper computes. No business logic in QML
  (`Theme.js` only ports *formatting/labels* so text matches Swift byte-for-byte).
- One account request per refresh cycle (default 60 s) — the account is a
  borrowed/shared ChatGPT subscription, keep request volume minimal.

### Refresh cycle (daemon loop)

1. `AppState::refresh_now()` (guarded by `refresh_lock`, so stacked `/refresh`
   calls coalesce) runs `snapshot::refresh_account_limits`:
   - spawn `codex app-server --listen stdio://` once, ask **two** RPCs in that
     one session (`account/rateLimits/read` id 2, `model/list` id 3);
   - on RPC failure → direct-backend HTTP fallback via `~/.codex/auth.json`;
   - on total failure → keep last data, surface the error in diagnostics, and
     serve the curated fallback model catalog.
2. Write macOS-compatible `~/.codex/usage.json` (authoritative usage source).
3. `build_snapshot()` scans sessions, telemetry, analytics, model settings,
   assembles one JSON document, persists it atomically to
   `~/.local/state/codex-usage-plasmoid/snapshot.json`.
4. The loop sleeps on a condvar — either `refresh_seconds` elapse or a
   `POST /refresh` wakes it early.
5. QML side: `POST /refresh` answers `202` immediately; `CodexData` fast-polls
   `/snapshot` every 600 ms until `generatedAt` advances (25 s watchdog), so no
   request is held open and spinner UIs have a definite end.

---

## 2. The Rust helper (`kde/helper/src/`)

Dependencies are deliberately tiny: `serde`/`serde_json`, `chrono`, `ureq`
(tls+json). No async runtime — plain threads + channels.

### `main.rs` — CLI surface
```
codex-usage-helper daemon [--port N]        # default; serve snapshots
codex-usage-helper once                     # one refresh, print snapshot, exit
codex-usage-helper set-model --model M --reasoning low|medium|high|xhigh|max|ultra [--fast|--no-fast]
codex-usage-helper refresh-account          # one account fetch into usage.json
codex-usage-helper doctor                   # paths, binary, defaults, counts
```
Daemon startup does the first refresh on a side thread while the HTTP server
is already accepting (so `/snapshot` never blocks on a cold start; a
"quiet refresh" builds a telemetry-only snapshot if polled before the first
account cycle finishes).

### `codexrpc.rs` — live account limits + model catalog
- `find_codex_binary()`: `CODEX_BIN` env override, else PATH scan.
- `fetch_account_and_models()`: 3 attempts (1/2/3 s backoff). One spawn per
  attempt; handshake sends `initialize` (id 1, `clientInfo: codex-usage-plasmoid`,
  `experimentalApi: true`), then `initialized` + both requests together.
- Stdout is drained on a **reader thread**; replies matched by id. **stdin stays
  open until the replies land** — closing early is EOF and the app-server exits
  without answering. 8 s deadline; rate-limit reply is *required*, `model/list`
  is *best-effort* (missing/failed → curated fallback catalog).
- `parse_rate_limit_result()` accepts both the live camelCase shape
  (`rateLimitsByLimitId`, `usedPercent`, `windowDurationMins`, `resetsAt`,
  `planType` living *inside* each limit entry) and the legacy snake_case one.
  Order is deterministic: `codex` (general) first, then sorted by id.
  Reset credits come from `rateLimitResetCredits.credits` ("Full reset available").
- `parse_model_list()` keeps visible models only (`hidden` dropped), carries the
  per-model effort ladder (`supportedReasoningEfforts[].reasoningEffort`,
  falling back to the full ladder), `defaultReasoningEffort`, fast support
  (`additionalSpeedTiers` contains `"fast"` **or** `serviceTiers[].id == "fast"`),
  and `isDefault`. Family is derived from the id.

### `httpfetch.rs` — direct-backend fallback
Only used when the codex binary is missing or the RPC fails. Reads
`~/.codex/auth.json`; if `last_refresh` is >45 min old (or absent), refreshes the
token via `auth.openai.com/oauth/token` using the Codex CLI's public OAuth client
id (`app_EMoamEEZ73f0CkXaXp7hrann`) and writes the rotated tokens back
atomically. Then `GET chatgpt.com/backend-api/codex/usage` with Bearer token,
`OpenAI-Beta: responses=experimental`, and `chatgpt-account-id`. Parses the
`rate_limits` mirror of the app-server shape. Model catalog is **not** available
on this path → fallback catalog.

### `usagefile.rs` — `~/.codex/usage.json`
`write_usage_file()` writes the exact shape the macOS live-sync agent produced
(`updatedAt`, `source: "Codex app-server live account limits"`, `creditsBalance`,
`limits[]` with `percentRemaining`/`resetLabel`/`resetAt`/`systemImage`
sparkles-vs-gauge, `planType`) — atomic tmp+rename, mode 0600. This file is the
**authoritative usage source** for `usage::resolve` (tier 1 below), and either
ecosystem's widget can consume it.

### `telemetry.rs` — token attribution engine (port of `CodexTokenTelemetryReader`)
- `TokenUsage`: input/cached/cache-write/output/reasoning/total;
  `effective_total()` falls back to input+output when total is absent;
  `delta()` returns `None` on any negative component (counter reset ⇒ skip).
- `read_telemetry()` scans up to **64 newest sessions**; files >768 KB are read
  as **head 384 KB + tail** with the delta baseline reset per segment (an
  unknown middle can never be attributed to the wrong model).
- Event envelopes honored:
  - `turn_context`: model = `payload.model ?? payload.collaboration_mode.settings.model`
    (**alternatives**, not a nested path — a nested lookup silently attributed
    everything to "unknown" once; that was the "Unknown · Max" row bug, fixed
    2026-10-03); effort = `effort ?? reasoning_effort ?? collaboration_mode.settings.reasoning_effort`.
  - `event_msg`/`thread_settings_applied`: `thread_settings.model` / `.reasoning_effort`.
  - `event_msg`/`token_count`: `info.last_token_usage` (current context),
    `info.total_token_usage` (cumulative; deltas are attributed),
    `info.model_context_window`.
- Dedupe key: session id + `ordinal`, else timestamp + token mix.
- Outputs: observed/today (same local day)/rolling-window totals, last 48 chart
  `BurnSample`s, per-`model|effort` breakdowns, latest context usage + window,
  peak context, session/event counts.

### `sessions.rs` — discovery, titles, projects
- `session_files()`: recursive `.jsonl` scan under the sessions root, newest
  first, cap 500 (`MAX_INDEXED_SESSIONS`).
- Titles, best source first: `~/.codex/session_index.jsonl` `thread_name`
  (`session_index_names`); fallback = first real user message
  (`session_title`) matching both `event_msg/user_message` and the newer
  `response_item` message items. **Synthetic machine context is never a title**
  (`is_synthetic_message`: `<environment_context>`, `<user_instructions>`,
  `<turn_context>`, `<permissions>`, `<skill_context>`, `<collaboration_mode`,
  `<ambient_context>`).
- `build_projects()`: group by cwd, newest wins, active = touched <7 days.
- `local_task_count()`: automations folders + delegation title heuristic.
- `latest_history_prompt()`: tail of `~/.codex/history.jsonl`.

### `analytics.rs` — port of `CodexV6AnalyticsBuilder`
- `merge_samples()` maintains `~/.local/state/codex-usage-plasmoid/analytics-v6.json`:
  bounded 30-day / 4096-event cache. Events are keyed on **timestamp + project +
  token mix (deliberately NOT model)** so a re-parse with fixed attribution
  overwrites whatever the cache recorded first.
- `record_quota_pace()`: `quota-pace-v6.json`, 45-day / 512-point history,
  ≥60 s spacing; derives %/hour, projected exhaustion epoch, `will_last_to_reset`.
- `estimate_cost()`: rough API-equivalent $/Mtok by family — luna 1/6,
  terra 2.5/15, everything else 5/30; cached input excluded.
- `read_official_activity()`: optional aggregates from usage.json
  (`officialUsage`/`accountUsage`/`summary`, `dailyUsageBuckets`).
- `read_workspace_health()`: `git status --porcelain=v1 --branch` over up to 8
  recent project paths (branch, dirty counts).
- `build()` aggregates daily buckets, hourly weekday×hour (7 d), model and
  project breakdowns, today/7 d/30 d totals, context %, burn, cost, four
  `source_statuses`, and `today_vs_previous_day`.

### `usage.rs` — usage resolution, three tiers (port of `usageSnapshot`)
1. **Account `usage.json`** (authoritative) — percent resolved from many key
   shapes (`percentRemaining`/`remainingPercent`/`percentUsed`/`usedPercent`/
   `remaining`+`limit`); window/today token counts always prefer live telemetry
   over the file's numbers; per-limit metrics + dock cards; prepaid credits
   display.
2. **Rate limits embedded in recent session `token_count` events** — tail 96 KB
   of up to 24 session files, `rate_limits.primary`; `resolved_rate_limit()`
   refills to 100 % and rolls the reset epoch forward whole windows when it has
   already passed.
3. **Local budget estimate** — settings budget (default 200 M tokens / 5 h
   window) against telemetry, clearly labeled "Local activity estimate".
Plus the shared status label/tint logic (green/orange/secondary) and
`freshness()` (authoritative sources go stale after 15 min).

### `modelsettings.rs` — `~/.codex/config.toml` writer
- Effort ladder: `low medium high xhigh max ultra`; labels Low/Medium/High/
  XHigh/Max/Ultra. Legacy `instant` normalizes to `low`; unknown → `medium`.
- Fast mode is `service_tier = "fast"` (what the TUI `/fast` writes); older
  name `"priority"` is also recognized as fast. `Some(false)` **removes** the
  key, `None` leaves it untouched.
- `read()` parses only the **root section** (stops at the first `[section]`).
- `update_at()` (the testable variant; tests use a temp path — **never call
  `update()` in tests, it writes the real `~/.codex/config.toml`**):
  - accepted models = live catalog + fallback catalog + **the model currently
    set in config.toml** (a newer codex may have written something the catalog
    doesn't know — it is always accepted so the widget keeps displaying it,
    but once you switch away you can't re-pick it until the catalog lists it);
  - the effort must be in **that model's own ladder** (e.g. Luna-6 has no
    `ultra` — the request is rejected with the supported list);
  - upsert/remove happens in the root section only; every other line and
    nested profile section is preserved byte-for-byte; atomic tmp+rename.
- `fallback_catalog()`: 8 curated models (gpt-6.1-sol default, gpt-6-astra,
  gpt-6-sol, gpt-6-luna, gpt-5.6-sol/terra/luna, gpt-daybreak-blue-latest)
  covering offline starts.

### `transcript.rs` — readable chat transcripts
- `render_markdown()` turns a session `.jsonl` into a clean Markdown doc:
  header (session id, project cwd, started, model+effort, session tokens),
  `## User` / `## <ModelLabel>` turns (synthetic messages skipped), tool calls
  as `> 🔧 **name** …` quotes, outputs as `> ↳ …`, reasoning summarized as
  `> 💭 _thinking:_ …`, all truncated to sane widths.
- `cached_transcript_path()` writes to
  `~/.cache/codex-usage-plasmoid/transcripts/<id>.md`.
- `open_in_viewer()` runs the configurable shell template (default
  `xdg-open {file}`; e.g. `kitty -e nvim {file}`) with `{file}` shell-quoted.

### `settings.rs` — helper settings
`~/.config/codex-usage-plasmoid/settings.json`: port 47631, refresh 60 s
(clamped 15–3600), sessions folder, usage-state path, recent limit 5, budget
200 M, window 5 h, daily goal 2 M, chat viewer command. `merged()` applies the
same clamps the DockDoor schema had. `CODEX_HOME` env overrides `~/.codex`.

### `server.rs` — HTTP surface (loopback only)

| Route | Method | Behavior |
| --- | --- | --- |
| `/snapshot` | GET | full document (usage, telemetry, analytics, sessions, dockCards, `availableModels`, diagnostics); quiet-refreshes if none exists yet |
| `/refresh` | POST | `202` + wakes the daemon loop; client polls for a new `generatedAt` |
| `/model` | GET/POST | read / write defaults: `{"model","reasoning"}` + `fast` bool **or** `"serviceTier":"fast"\|"default"`; absent tier key = leave as-is; validates against the live catalog; triggers an immediate snapshot rebuild |
| `/settings` | GET/POST | helper settings; POST merges, saves, signals refresh |
| `/open` | POST | `{"sessionId","mode"}` — `transcript` (default) renders Markdown + runs the viewer template; `link` → `xdg-open codex://threads/<uuid>`; non-UUID ids rejected |
| `/chats` | GET | recent sessions (id/title/project/activity/filePath) |
| `/transcript?id=` | GET | `{ok, markdown, filePath}` for any session |
| `/metrics` | GET | Prometheus text: quota %, tokens (window/today/7 d/30 d), burn/min, context %, 30-day cost, counts, current model/effort/fast |
| `/health` | GET | version, port, codex binary, last refresh age, hasSnapshot |

Every route sends `Access-Control-Allow-Origin: *` and answers `OPTIONS`
preflights, so browser dashboards / other local tools can consume the data too.

### `util.rs` — Swift-parity formatting
`percent_fraction` (whole numbers are %, <1 is already a fraction),
`compact_tokens`/`compact_tokens_plain`, `rate_label`, `credit_display`
(thousands grouping, never a `$`), `model_label` (family+version: `gpt-6.1-sol`
→ "Sol-6.1", `gpt-daybreak-blue-latest` → "Daybreak"), `reasoning_label`,
`normalized_reasoning_effort`, `model_family`, `reset_summary`, relative time,
day keys, RFC3339 parsing. Each has a unit test asserting the Swift values.

---

## 3. The plasmoid (`kde/plasmoid/contents/`)

### Entry & data bridge
- `ui/main.qml` — `PlasmoidItem` wiring. Gathers the live Plasma accent into
  `plasmaPalette` (from `Kirigami.Theme.highlightColor`) and injects it into both
  representations. Mirrors data-affecting config into the helper via
  `pushHelperSettings()` on load and on every config `valuesChanged`. Applies
  the UI font choice to the `UIFont` singleton. Pauses the shared
  `AnimationClock` when the popup is closed (no idle CPU on atmosphere painting).
- `ui/CodexData.qml` — the only network-speaking object. 1 s heartbeat clock
  for countdowns; poll timer (default 5 s, min 2 s); refresh flow with 600 ms
  fast-poll + 25 s watchdog; `setModel` / `openSession` / `pushSettings`
  helpers; **localStorage snapshot cache** so the widget renders offline/late-boot
  instead of blank; `rotatingCard(kind, interval, pinnedEpoch)` for the dock deck.

### Theming — `ui/lib/Theme.js`
- Five planet themes (Astra/Luna/Sol/Terra/Rainbow) with the exact SwiftUI
  `[r,g,b]` palettes; `THEME_ORDER`, tolerant `theme()` lookup (display name,
  key, or stored string).
- `deriveTheme()` builds a full theme from one accent via HSL math (glass base
  tint, gradient stops, 4-color data palette, artwork base) — this powers the
  two new modes:
  - **plasma**: accent = live system highlight color (follows the color scheme);
  - **custom**: one accent everywhere (10 preset swatches or any hex via the
    settings dialog's ColorDialog).
- `resolveTheme(configuration, plasmaPalette, pageThemeName)` is the single
  entry point every view calls; apple mode keeps per-page planet themes.
- `fontFamily(preferred)` — explicit choice wins; auto prefers Hack Nerd Font
  with fallbacks (icons need a Nerd Font!).
- `ICON_GLYPHS` — Nerd Font PUA codepoints, each verified **by name** against
  glyphnames.json *and* present in the installed font's cmap (existence alone
  lies: U+F1D3 exists but is the Git logo).
- Card metadata `CARDS` (24), `PAGE_DEFAULT_CARDS`, `PAGES`, and
  `normalizedLayout()` (dedupes, restores missing defaults, repairs order) —
  the port of `CodexV6CardOrderStore`.

### Dashboard — `ui/Dashboard.qml`
Four pages (Overview · Activity · Models · Health), each a plain `Flickable`
(no ScrollView/ScrollBar anywhere — that's a hard requirement). Header with
LIVE/STALE/WAITING badge, refresh (spins until `freshSnapshotArrived`),
appearance, and arrange buttons. Filter bar on Activity/Models (window chips,
model filter). Stale/helper-unreachable notice. Footer with page dots.
**Keyboard**: ←/→ or 1–4 pages, ↑/↓ smooth-scroll the active page, R refresh,
A appearance, E edit, Esc closes the popover. Horizontal-dominant wheel swipes
pages; vertical wheel scrolls. Card arrangement (E) persists to
`Plasmoid.configuration.cardLayout` as JSON; only the active page is visible
(edit mode once stacked all four pages and clicks landed on the wrong page).

### Compact/panel widget — `ui/CompactWidget.qml`
Three styles, always the **account usage percent** (a rotating panel label
jitters the panel width): `gauge` (themed ring + percent inside), `bar`
("86%  Luna-6" over a gradient bar; has a vertical-panel variant), `percent`
(big number, optional "Codex" caption). Legacy stored values (`auto`, `compact`,
`extended`…) normalize to gauge — the old "extended/full" style was removed on
purpose. Percent tints amber when the snapshot is stale.

### Appearance popover — `ui/AppearancePopover.qml`
Plain Flickable sized `min(parent.height − 20, chrome.implicitHeight + 28)`:
fits content when there's room, scrolls only when capped. STYLE mode chips
(Liquid Glass / Plasma / Custom), accent swatches (custom), per-page planet
grid (apple only), glow/sparkle sliders (0–150 %), animate / high-contrast /
status toggles, card density. Custom-drawn Slider/ToggleRow components keep it
on-theme.

### Model controls card — `ui/cards/ModelControlsCard.qml`
Fully dynamic from `dataSource.availableModels`: families in catalog order
(default first) rendered as `IdentityButton`s — curated planet artwork for
luna/sol/terra/astra, `Theme.familyIdentity` derived orbs otherwise — variant
chips within the family (e.g. "6.1"), the **model's own** effort ladder as
severity-tinted gradient pills in a 3-column grid, and the Fast-mode toggle
(hidden when the model has no fast tier). Picking keeps your current effort if
the target supports it, else lands on the model default. Writes go through
`POST /model`; card shows busy state and surfaces validation errors inline.

### Card system
`CardShell` (themed chrome, edit-mode controls) hosts a `CardLoader`, which
instantiates `cards/<Id>Card.qml` by id and binds the eight standard props
(dataSource, theme, clock, sparkle/glow/animations, activityWindow,
modelFilter). `Qt.resolvedUrl` pins the path to the loader's own location —
a plain relative string resolves against the *instantiating* context in
plasmashell and was the root cause of the blank-widget incident.

The 24 cards: quota (hero), modelControls, quotaBudget, sessionPulse, pace,
burn, context, contextRunway · dailyActivity, hourlyActivity, projectHeatmap,
turnTimeline, streaksGoals, cost · modelMix, modelScorecard, efficiency,
projectMix, sessionHealth · officialActivity, reliability, dataHealth,
workspaceHealth, recentChats (click → helper renders the transcript into your
configured viewer, or `mode:"link"` deep-links `codex://threads/<id>`).

### Shared components (`ui/components/`)
`AnimationClock` (single shared time source for all breathing/sparkle
animations), `UsageRing`, `ThemeProgressBar`, `ThemeBackground`, `ColumnChart`
(interactive), `PlanetMarker`, `IdentityButton` (canvas planet artwork — clip
via a rounded-rect path + `ctx.clip()` **first**, because Item `clip:` is
square and the artwork bled past the corners), `MetricTile`, `LabeledBar`,
`TrendBadge`, `FilterBar`/`FilterChip`, `CardShell`/`CardLoader`, and the
`UIFont` **pragma-Singleton** (registered via `components/qmldir`) that makes
font changes reflow every Text live without a Plasma restart.

### Config dialog (`config/`)
Three tabs (General / Appearance / Panel) over `contents/config/main.xml` keys:
helper port/poll/refresh, sessions folder, usage-state path, recent count,
budget/window/goal, chat viewer command · themeMode, customAccentColor
(swatches + QtQuick.Dialogs ColorDialog), per-page themes (combos model the
stored **KEYS** "Astra/Luna/Sol/Terra/Rainbow"), uiFontFamily ("Auto" + all
installed families), density, opacity, frosted glass, sparkle/glow/animations/
high-contrast, showDataStatus · compactStyle, panelWidgetLength,
panelShowCodexLabel, modelTheme.

---

## 4. What's actually NEW versus the Swift port

Ported parity: all 24 dashboard cards, planet themes, ring/sparkle/bar visual
language, rotating dock deck, per-page themes, usage three-tier resolution,
telemetry attribution, analytics caches, quota pace, cost estimate, model
labels/formatting, macOS-compatible usage.json.

New or substantially extended on KDE:

1. **Rust helper replaces the app bundle** — one static-ish binary, systemd
   user service, no Sparkle/notarization pipeline.
2. **Live model catalog** from app-server `model/list` (the macOS widget used a
   hardcoded list): families/variants/effort-ladders/fast-support all reflect
   the account, with a curated fallback offline.
3. **`/fast` speed-tier control** writing `service_tier` (previously not
   exposed), plus always-accept-current-model validation semantics.
4. **Readable transcripts + configurable viewer** — Recent chats open as
   rendered Markdown in `xdg-open`/any shell template, or deep-link
   `codex://threads/<id>`.
5. **Public loopback API**: `/chats`, `/transcript`, `/metrics` (Prometheus),
   `/health` with CORS — the data is now consumable by browsers/Grafana/other
   tools, not just the widget.
6. **Three style modes**: original Apple liquid glass, **Plasma style**
   (accent/data colors/tint follow the system scheme live), and **custom
   accent** with presets/arbitrary hex.
7. **Keyboard navigation** for the whole dashboard; wheel page-swipe.
8. **Card arrangement persistence** in plasmoid config with repair-on-load.
9. **Live UI font selection** via the UIFont singleton (no restart).
10. **Offline resilience**: QML localStorage snapshot cache; helper keeps last
    good account data across failed fetches; HTTP fallback path when the CLI is
    missing.
11. **Panel styles simplified** to gauge/bar/percent (extended removed);
    stale-amber percent on the panel.
12. **Test/gate tooling**: 27 cargo tests (Swift-parity asserts), whole-package
    QML compile gate, offscreen render gates (see §6).

---

## 5. Deployment

`bash kde/Scripts/install-kde.sh`:
1. `cargo build --release` in `kde/helper`;
2. installs to `~/.local/libexec/codex-usage-helper`;
3. installs `kde/systemd/codex-usage-helper.service` to
   `~/.config/systemd/user/`, `daemon-reload`, `enable --now`;
4. `kpackagetool6 --install/--upgrade` the plasmoid package;
5. health-checks `http://127.0.0.1:47631/health`.

Operational notes:
- After upgrading an **existing** install, `enable --now` will NOT restart an
  already-running unit — `systemctl --user restart codex-usage-helper.service`,
  and restart plasmashell to reload QML:
  `systemctl --user restart plasma-plasmashell.service`.
- Logs: `journalctl --user -u codex-usage-helper -f`.
- Preview without a panel: `plasmawindowed io.github.appleforever11.codex-usage`.
- On this machine the widget is a desktop applet
  (`[Containments][1][Applets][136]`, 448×656), not in a panel.
- Uninstall: `bash kde/Scripts/uninstall-kde.sh`.

Runtime file map:
`~/.codex/usage.json` (written, authoritative usage) · `~/.codex/config.toml`
(root keys upserted) · `~/.codex/auth.json` (refreshed tokens, fallback path
only) · `~/.config/codex-usage-plasmoid/settings.json` (helper settings) ·
`~/.local/state/codex-usage-plasmoid/{snapshot.json, analytics-v6.json,
quota-pace-v6.json}` · `~/.cache/codex-usage-plasmoid/transcripts/`.

---

## 6. Verification & testing

```bash
cd kde/helper && cargo test                       # 27 unit tests
python3 kde/Scripts/check-qml.py kde/plasmoid      # compile every QML file with the real engine
python3 kde/Scripts/render-preview.py [out.png]    # offscreen render against the LIVE helper
python3 kde/Scripts/render-control.py              # compact-widget render gate
python3 kde/Scripts/bisect-render.py               # bisect card-level render regressions
```

- `render-preview.py` stages the package to /tmp, loads the real Dashboard with
  a live `CodexData`, grabs a window shot after 2.5 s and requires **>8 distinct
  sampled colors** (a blank/broken popup fails); software Qt backend + hard
  timeout guards so it can never hang CI.
- Full manual loop used after any change: check-qml → render-preview →
  install-kde.sh → restart unit + plasmashell → `journalctl -u ... | grep
  appleforever` (target: 0 hits) → `plasmawindowed` + screenshot.

### Postmortems worth remembering (2026-10-03 blank-widget incident)
- plasmashell ran a **stale kpackagetool install**: the old CardLoader resolved
  `../cards/<id>.qml` against the instantiating context → every card failed
  with "No such file or directory" → blank popup. Fix: `Qt.resolvedUrl` +
  reinstall. Symptom to watch for: cards individually missing while the shell
  renders.
- A wrapping `Text` inside a plain `Row` (`width: parent.width - 16`) caused a
  100 %-CPU layout spin that froze any render once paths worked (QuotaCard
  credits row). Rule: width-constrained text goes in a `RowLayout` with
  `fillWidth`, never a bare Row.
- Also fixed then: `Layout.alignment` warnings, WorkspaceHealthCard null
  guards, `Boolean()` coercion in RecentChatsCard.

---

## 7. Gotchas & invariants (read before touching anything)

1. **Never call `modelsettings::update()` in tests** — it writes the real
   `~/.codex/config.toml`. Use `update_at(temp_path, …)`.
2. Keep the app-server's **stdin open** until both replies arrive or the
   process exits on EOF without answering.
3. QML XHR: no same-origin policy, but no file/process access either — the
   loopback HTTP bridge is the only channel; all CORS is handled server-side.
4. `CardLoader` must resolve card URLs via `Qt.resolvedUrl` (see incident above).
5. Item `clip: true` clips a square. Canvas artwork that must respect rounded
  corners builds a rounded-rect path and calls `ctx.clip()` **first** in
   `onPaint` (IdentityButton); a `default:` artwork case must exist so derived
   identities (spark/daybreak/other) still render an orb.
6. AppearancePopover and page bodies are plain `Flickable`s — **no
   ScrollView/ScrollBar**, by explicit requirement.
7. Nerd Font glyph codepoints must be verified **by name** (glyphnames.json)
   and for cmap existence; existence alone is misleading.
8. `turn_context` model lookup is `payload.model ?? collaboration_mode.
   settings.model` — alternatives, not a nested path.
9. Analytics cache identity deliberately excludes model so re-parses overwrite
   stale attribution; don't "fix" that.
10. A model already present in config.toml is always accepted by `/model` even
    when no catalog lists it; after switching away it can't be re-picked until
    the catalog includes it.
11. The panel representation shows only the account percent — no rotating deck
    (width jitter); legacy `compactStyle` values normalize to gauge.
12. Account request discipline: one account fetch per refresh cycle, 60 s
    default — the subscription is borrowed; don't add parallel fetch paths.
13. `Plasmoid.configuration.cardLayout` is a JSON string; always run it through
    `Theme.parseLayout/normalizedLayout` on load.
14. The config dialog's per-page theme combos model the stored KEYS
    ("Astra/Luna/…"), not display names.
15. Helper version lives in `Cargo.toml` (`HELPER_VERSION` via env!); plasmoid
    version in `metadata.json` — bump both together.
16. `kde/README-KDE.md` still says "23 unit tests" — the suite is now 27; the
    root README's KDE blurb and this handoff are the current map.

## 8. Open items when this handoff was written

- `kde/` is **untracked** and the root `README.md` blurb is unstaged — the port
  has never been committed. First task for whoever picks this up: review +
  commit (the helper's `target/` dir should be ignored, not committed).
- `Snapshot.diagnostics` telemetry-freshness/event-count fields are stubbed
  (empty/0); the UI doesn't consume them yet.
- `/metrics` has no helper-process metrics (uptime, refresh failures) yet.
- Fallback catalog needs manual bumps when the account's real catalog gains
  models (live `model/list` already covers the widget UI regardless).
