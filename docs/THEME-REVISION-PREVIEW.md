# Model theme revision — approved for 5.0.0 packaging

The user approved this revision for 5.0.0 packaging and local installation. The existing marketplace PR has been updated. Private installers remain local artifacts; no new private-edition public release was uploaded.

## Design

- Astra is the default appearance: deep purple, a violet usage ring, restrained glow, and static background stars.
- Luna, Sol, Terra, and Rainbow are available from the existing palette button. The theme controls the panel, ring, usage accents, and reasoning selection fill. Choosing a theme does not change the selected model.
- The companion app uses the same palette components and has its own persisted appearance selection.
- Model controls include Luna, Sol, Terra, and Astra. Spark's model button and toolbar shortcut are removed; historical Spark usage remains readable.
- Light replaces the Instant display label; release preflight maps it to the supported `low` reasoning value.

## Engineering changes

- Separated plugin registration, panel, compact view, ring, session views, snapshot models, decoding, preferences, configuration editing, themes, and storage.
- Fixed pause-on-hover for extended dock layouts.
- Moved cache-signature filesystem scanning off the caller's executor.
- Reduced panel clock updates from once per second to once per 15 seconds.
- Prevented overlapping manual refresh requests.
- Added visible model-setting write errors. Settings edits are restricted to root TOML assignments and preserve nested profiles.
- Recent chats now consume remaining panel space, remain scrollable, and have an empty state.
- Theme backgrounds are static; model animations remain visibility/activity gated and respect Reduce Motion. The background respects Reduce Transparency.

## Verification

- Universal widget build: arm64 and x86_64 passed.
- Companion: arm64 preview and x86_64 executable compiled.
- Native captures generated for all five widget themes and the Astra companion.
- Live preview: palette menu exposes all five options; changing Terra appearance leaves Astra model selected; Terra and Light selection works; recent chats scroll to the final row.
- Companion palette opens and a changed theme is reflected in its accessibility state.
- Regression fixtures pass for root configuration updates, nested-profile preservation, missing root key insertion, comment retention, model labels, and theme identities.
- SwiftUI preview uses sample data and avoids model writes, installation, and update calls.

## Remaining release gates

Design approval, signing/notarization, local installation, loaded-binary verification, private updater check, and the marketplace PR replacement are complete. Maintainer review and marketplace rollout remain external steps. Other-Mac installers are prepared but not installed remotely. Performance has not been benchmarked.

## Astra ring sparkles

Only the Astra progress ring adds twinkling white/violet stars along its filled arc. Five stars serve compact rings and twelve serve larger rings, at up to 18 updates per second while visible. Reduce Motion freezes the effect; an empty arc has no sparkles. The overlay does not affect ring geometry or hit testing. A native two-frame comparison verified changing Astra pixels, unchanged other-model rings, and an unchanged forced reduced-motion path. The system Reduce Motion preference was not modified during testing.
