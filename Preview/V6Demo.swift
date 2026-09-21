import AppKit
import Foundation
import SwiftUI

private func v6DemoSnapshot() -> CodexSnapshot {
    var snapshot = CodexSnapshot.empty
    let now = Date()
    snapshot.modelSettings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "max")
    snapshot.projectCount = 3
    snapshot.chatCount = 24
    snapshot.taskCount = 6
    snapshot.analytics = .preview
    snapshot.usage = CodexUsageSnapshot(
        percentRemaining: 0.78,
        primaryTitle: "78% remaining",
        primarySubtitle: "Account usage · 5-hour window",
        windowUsedTokens: 1_250_000,
        todayUsedTokens: 3_700_000,
        budgetTokens: 0,
        resetDate: now.addingTimeInterval(7_500),
        resetLabel: nil,
        source: "Codex app-server live account limits",
        metrics: [
            CodexUsageMetric(title: "Weekly allowance", value: "64% left", systemImage: "calendar", tint: .purple),
            CodexUsageMetric(title: "5-hour allowance", value: "78% left", systemImage: "clock", tint: .purple),
            CodexUsageMetric(title: "Prepaid credits", value: "1,246.89", systemImage: "creditcard.fill", tint: .blue)
        ],
        accountCards: [],
        lastUpdated: now.addingTimeInterval(-8),
        creditsBalance: "1,246.89"
    )

    let usages = [
        CodexTokenUsage(inputTokens: 21_400, cachedInputTokens: 7_200, outputTokens: 1_100, reasoningOutputTokens: 380, totalTokens: 22_500),
        CodexTokenUsage(inputTokens: 24_800, cachedInputTokens: 8_900, outputTokens: 1_420, reasoningOutputTokens: 510, totalTokens: 26_220),
        CodexTokenUsage(inputTokens: 19_600, cachedInputTokens: 6_800, outputTokens: 980, reasoningOutputTokens: 260, totalTokens: 20_580),
        CodexTokenUsage(inputTokens: 31_600, cachedInputTokens: 11_800, outputTokens: 2_080, reasoningOutputTokens: 620, totalTokens: 33_680)
    ]
    snapshot.tokenTelemetry = CodexTokenTelemetry(
        observedUsage: CodexTokenUsage(inputTokens: 80_000, cachedInputTokens: 27_500, outputTokens: 4_320, reasoningOutputTokens: 1_360, totalTokens: 84_320),
        todayUsage: CodexTokenUsage(inputTokens: 246_000, cachedInputTokens: 94_000, outputTokens: 12_400, reasoningOutputTokens: 4_100, totalTokens: 258_400),
        latestDelta: usages.last,
        latestContextUsage: CodexTokenUsage(inputTokens: 131_000, cachedInputTokens: 52_000, outputTokens: 7_100, reasoningOutputTokens: 2_200, totalTokens: 148_100),
        latestContextWindow: 258_400,
        peakContextTokens: 211_700,
        samples: usages.enumerated().map { index, usage in
            CodexTokenBurnSample(
                id: "v6-preview-\(index)",
                timestamp: now.addingTimeInterval(Double(-50 + index * 14)),
                usage: usage,
                model: index.isMultiple(of: 2) ? "gpt-6-astra" : "gpt-5.6-terra",
                reasoningEffort: index.isMultiple(of: 2) ? "max" : "medium",
                contextWindow: 258_400,
                projectName: index.isMultiple(of: 2) ? "Codex Usage Widget" : "Personal Dashboard"
            )
        },
        modelBreakdowns: [],
        currentModel: "gpt-6-astra",
        currentReasoningEffort: "max",
        updatedAt: now.addingTimeInterval(-8),
        sessionCount: 4,
        eventCount: 128,
        attributedEventCount: 126
    )
    snapshot.panelSessions = [
        ("Codex workspace", "Review usage and reset timing"),
        ("Native app", "Refine the sidebar and search"),
        ("Release checklist", "Review the latest changes"),
        ("Usage dashboard", "Improve status and accessibility")
    ].enumerated().map { index, item in
        CodexSession(
            id: "v6-preview-\(index)",
            url: URL(fileURLWithPath: "/preview"),
            projectName: item.0,
            projectURL: URL(fileURLWithPath: "/preview"),
            modified: now.addingTimeInterval(Double(-index * 300)),
            title: item.1,
            isActive: index == 0
        )
    }
    return snapshot
}

private struct V6DemoRoot: View {
    var body: some View {
        CodexTrackerPanelView(dismiss: { NSApp.terminate(nil) }, previewSnapshot: v6DemoSnapshot())
            .padding(14)

    }
}

@main
private final class V6DemoApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = V6DemoApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        CodexV6Preferences.defaults = UserDefaults(suiteName: "com.appleforever11.codex-v6-demo") ?? .standard
        if ProcessInfo.processInfo.arguments.contains("--reduce-motion") {
            CodexV6Preferences.defaults.setVolatileDomain(
                [CodexV6Preferences.animationsEnabledKey: false], forName: UserDefaults.argumentDomain
            )
        }
        let host = NSHostingView(rootView: V6DemoRoot())
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 705),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.title = "Codex Usage 6.0 · Interactive Demo"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
