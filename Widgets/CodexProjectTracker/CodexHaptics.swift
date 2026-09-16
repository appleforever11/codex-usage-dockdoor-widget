import AppKit
import OSLog
import SwiftUI

enum CodexHaptics {
    private static let logger = Logger(subsystem: "com.appleforever11.codex-usage", category: "Haptics")
    static let enabledKey = "widget.codex-project-tracker.hapticsEnabled"
    private static var lastHoverTime = -Double.infinity
    private static var pendingPulse: DispatchWorkItem?

    static func performModelSelectionIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        cancelPendingFeedback()
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
    }

    static func performPageNavigationIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }

    static func performHoverIfEnabled(_ enabled: Bool) {
        guard enabled else { return }
        let now = ProcessInfo.processInfo.systemUptime
        // Nested card/button hover regions must not pile up feedback.
        guard now - lastHoverTime >= 0.12 else { return }
        logger.debug("Requested hover double pulse")
        lastHoverTime = now
        cancelPendingFeedback()
        // AppKit exposes patterns, not amplitude. Use two distinct generic
        // pulses for a pronounced response, once per pointer entry.
        NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        let pulse = DispatchWorkItem {
            NSHapticFeedbackManager.defaultPerformer.perform(.generic, performanceTime: .now)
        }
        pendingPulse = pulse
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.065, execute: pulse)
    }

    static func cancelPendingFeedback() {
        pendingPulse?.cancel()
        pendingPulse = nil
    }
}

private struct CodexHoverHaptics: ViewModifier {
    let enabled: Bool
    @State private var wasInside = false

    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside && !wasInside { CodexHaptics.performHoverIfEnabled(enabled) }
            wasInside = inside
        }
    }
}

extension View {
    func codexHoverHaptics(enabled: Bool) -> some View {
        modifier(CodexHoverHaptics(enabled: enabled))
    }
}
