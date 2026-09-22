# Marketplace submission

The GPT-6 update starts from the merged [PR #27](https://github.com/ejbills/dockdoorpro-widgets/pull/27), including ejbills' follow-up. It displays Luna-6 and Sol-6 in recorded model cards, analytics, dock labels, and the host-owned palette chooser. Older records retain their actual generation. Model artwork is resolved from model identity independently of the display label.

The marketplace folder contains only its manifest and Swift source. It has no Sparkle import or framework, companion, appcast, LaunchAgent, process launcher, network client, or Codex configuration writer. DockDoor Pro remains responsible for marketplace delivery and updates.

The personal 6.0.3 edition retains model/reasoning default controls, recent chats, local usage sync, haptics, and the signed Sparkle companion. Its universal installer supports Apple silicon and Intel Macs on macOS 14 or later.

Preserve the maintainer's persistent card placement, move menus, shared session-file discovery, primary-color values, seven-day Activity/Models defaults, and removal of drag/drop, sheets, and hover haptics. The marketplace update changes only three production files inside `Widgets/CodexUsage`; its quota parser and analytics reader remain unchanged.

Validation covers both Mac architectures, model-generation labels, model artwork, metadata, unsafe-API lint, and native light/dark model-card previews. The renamed Luna/Sol host palette options use the new names directly, without migration code, as required by the marketplace contribution guide; an older saved palette can be reselected in DockDoor settings.
