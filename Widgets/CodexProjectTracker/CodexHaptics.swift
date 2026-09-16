import AppKit

enum CodexHaptics {
    static let enabledKey = "widget.codex-project-tracker.hapticsEnabled"

    static func performModelSelectionIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    static func performPageNavigationIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}
