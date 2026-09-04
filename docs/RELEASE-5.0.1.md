# Private installer 5.0.1 — launch handoff repair

The reported Mac mini symptom is a brief Dock bounce followed by the installer disappearing, on macOS 26.6.2. The local test Mac runs macOS 27.0, so a remote-machine confirmation is still required.

The 5.0.0 relocation code allowed Launch Services to reuse an existing instance sharing the bundle identifier, then unconditionally terminated the source launcher. The updated handoff explicitly creates a distinct process and includes an installed-copy marker to prevent repeat relocation if an app is translocated. An older running companion produces an actionable alert, and activation of a background companion restores its window.

The widget's features and marketplace PR are unchanged. This is a private installer patch. The code change addresses a concrete startup risk; without a crash report from the Mac mini, it does not establish the exact cause of that machine's failure.

Verification: universal build and package validation passed. Apple accepted and stapled the app and DMG; Gatekeeper accepted both. A normal launch from the mounted 5.0.1 DMG, without bypass flags, started the installed companion with the handoff marker. Its 5.0.1 window remained open and completed installation on the local macOS 27.0 Mac. The Mac mini on macOS 26.6.2 still needs user confirmation.
