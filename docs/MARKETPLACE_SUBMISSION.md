# Marketplace submission

The existing [PR #24](https://github.com/ejbills/dockdoorpro-widgets/pull/24) now proposes Astra, Luna, Sol, Terra, and Rainbow appearances for the read-only Codex Usage widget, including an Astra-only animated progress ring and a palette chooser. The existing widget identity, usage decoding, missing-data handling, and dock orientations are preserved.

The marketplace folder contains only its manifest and Swift source. It has no Sparkle import or framework, companion, appcast, LaunchAgent, process launcher, network client, or Codex configuration writer. DockDoor Pro remains responsible for marketplace delivery and updates.

The private 5.0.0 edition retains model/reasoning default controls, recent chats, local usage sync, and the signed Sparkle companion. Its universal installer supports MacBook, MacBook Neo, and Mac mini on macOS 14 or later.

Validation includes the universal marketplace build, upstream unsafe-API lint, manifest checks, usage-decoding fixtures, and a rendered native panel. The public CI compiler requires explicit drawing types and an extracted Canvas helper; that compatibility adjustment is confined to the marketplace source.
