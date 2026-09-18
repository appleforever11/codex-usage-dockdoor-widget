# 🚀 Codex Usage 6.0.0 — the companion edition gets its living dashboard

This release ships the full Codex Usage 6.0 experience to the companion edition and its `codex-project-tracker` widget. It does not modify or publish the marketplace `codex-usage` variant; that edition keeps DockDoor Pro's separate read-only update path.

## ✨ What is new

- 🧭 **Four-page dashboard:** swipe between Overview, Activity, Models, and Health with a two-finger trackpad drag, page controls, or `⌘←` / `⌘→`.
- 📊 **A deeper usage story:** quota and reset timing, live burn, context health, quota pacing, daily/hourly activity, project heatmaps, turn timelines, streaks, cost estimates, model mix, efficiency, reliability, and workspace health.
- 🎨 **Five living themes:** Astra, Luna, Sol, Terra, and Rainbow now color the full visual system—not only the usage ring. Bars, chart columns, progress tracks, card surfaces, controls, ambient fields, glows, and sparkles follow the active page theme.
- ✨ **Breathing atmosphere:** subtle animated gradients and faint floating stars make each page feel alive while a Reduce Motion path keeps the presentation calm and static when requested.
- 🧲 **Visible haptics:** model and page interactions can provide Mac haptic feedback, and the model controls show whether the feature is enabled.
- 🧩 **Card personalization:** drag cards to reorder them, switch between compact/standard/spacious density, and open focused detail sheets for deeper values and provenance.
- 🫧 **Dock preview refresh:** compact, extended horizontal, and extended vertical layouts share the same living theme language and foreground the active model name for quick scanning.
- 🪞 **Reflective Shelf beta:** the private preview keeps dock content transparent and edge-free so DockDoor Pro's reflective shelf supplies the material while the widget contributes the ring, glow, sparkles, and legible labels.
- 🔒 **Local-first telemetry:** token activity, model/reasoning attribution, session health, and workspace checks remain derived from local events and caches; account limits remain a separately labeled local app-server snapshot.

## 🎉 Preview gallery

The repository README includes the refreshed native previews for:

- 🌌 Astra, 🌙 Luna, ☀️ Sol, 🌍 Terra, and 🌈 Rainbow overview themes.
- 🪞 Transparent Reflective Shelf beta dock treatment.
- ↔️ Compact and extended horizontal dock slots.
- ↕️ Extended vertical dock slot.
- 🧠 Model themes and haptic selection controls.

## 📦 Distribution

The release workflow builds the universal Apple Silicon/Intel widget and companion, validates the payload, notarizes and staples the installer artifacts, signs the Sparkle appcast, and publishes the immutable release assets. Existing Sparkle installations can use the companion's update check after the public feed is available.

The marketplace variant is deliberately outside this release: no marketplace source, asset, manifest, or update path is part of the 6.0.0 publication.
