import AppKit
import SwiftUI

private func previewSnapshot() -> CodexSnapshot {
    var snapshot = CodexSnapshot.empty
    snapshot.modelSettings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "medium")
    snapshot.projectCount = 3
    snapshot.chatCount = 24
    snapshot.taskCount = 6
    snapshot.analytics = .preview
    snapshot.usage = CodexUsageSnapshot(percentRemaining: 0.78, primaryTitle: "78% remaining",
        primarySubtitle: "Account usage · 5-hour window", windowUsedTokens: 1_250_000,
        todayUsedTokens: 3_700_000, budgetTokens: 0, resetDate: Date().addingTimeInterval(7500),
        resetLabel: nil, source: "Preview data", metrics: [
            CodexUsageMetric(title: "Weekly allowance", value: "64% left", systemImage: "calendar", tint: .purple),
            CodexUsageMetric(title: "5-hour allowance", value: "78% left", systemImage: "clock", tint: .purple)
        ], accountCards: [], lastUpdated: Date())
    let previewNow = Date()
    let sampleUsages: [CodexTokenUsage] = [
        CodexTokenUsage(inputTokens: 21_400, cachedInputTokens: 7_200, outputTokens: 1_100, reasoningOutputTokens: 380, totalTokens: 22_500),
        CodexTokenUsage(inputTokens: 24_800, cachedInputTokens: 8_900, outputTokens: 1_420, reasoningOutputTokens: 510, totalTokens: 26_220),
        CodexTokenUsage(inputTokens: 19_600, cachedInputTokens: 6_800, outputTokens: 980, reasoningOutputTokens: 260, totalTokens: 20_580),
        CodexTokenUsage(inputTokens: 14_200, cachedInputTokens: 4_600, outputTokens: 820, reasoningOutputTokens: 210, totalTokens: 15_020),
    ]
    snapshot.tokenTelemetry = CodexTokenTelemetry(
        observedUsage: CodexTokenUsage(inputTokens: 80_000, cachedInputTokens: 27_500, outputTokens: 4_320, reasoningOutputTokens: 1_360, totalTokens: 84_320),
        todayUsage: CodexTokenUsage(inputTokens: 246_000, cachedInputTokens: 94_000, outputTokens: 12_400, reasoningOutputTokens: 4_100, totalTokens: 258_400),
        latestDelta: sampleUsages.last,
        latestContextUsage: CodexTokenUsage(inputTokens: 131_000, cachedInputTokens: 52_000, outputTokens: 7_100, reasoningOutputTokens: 2_200, totalTokens: 148_100),
        latestContextWindow: 258_400,
        peakContextTokens: 152_800,
        samples: sampleUsages.enumerated().map { index, usage in
            CodexTokenBurnSample(
                id: "preview-\(index)",
                timestamp: previewNow.addingTimeInterval(Double(-50 + index * 14)),
                usage: usage,
                model: index == 0 ? "gpt-5.6-terra" : "gpt-6-astra",
                reasoningEffort: index == 0 ? "medium" : "max",
                contextWindow: 258_400
            )
        },
        modelBreakdowns: [
            CodexTokenModelBreakdown(
                model: "gpt-6-astra", reasoningEffort: "max",
                usage: CodexTokenUsage(inputTokens: 62_000, cachedInputTokens: 22_000, outputTokens: 3_200, reasoningOutputTokens: 1_100, totalTokens: 65_200),
                turnCount: 8, lastUpdated: previewNow.addingTimeInterval(-5)
            ),
            CodexTokenModelBreakdown(
                model: "gpt-5.6-terra", reasoningEffort: "medium",
                usage: CodexTokenUsage(inputTokens: 18_000, cachedInputTokens: 5_500, outputTokens: 1_120, reasoningOutputTokens: 260, totalTokens: 19_120),
                turnCount: 3, lastUpdated: previewNow.addingTimeInterval(-50)
            ),
        ],
        currentModel: "gpt-6-astra",
        currentReasoningEffort: "max",
        updatedAt: previewNow.addingTimeInterval(-5),
        sessionCount: 4,
        eventCount: 14,
        attributedEventCount: 13
    )
    snapshot.panelSessions = [
        ("Codex workspace", "Review usage and reset timing"),
        ("Native app", "Refine the sidebar and search"),
        ("Release checklist", "Review the latest changes"),
        ("Usage dashboard", "Improve status and accessibility"),
        ("Model controls", "Verify Light, Medium, and Max")
    ].enumerated().map { index, item in
        CodexSession(id: "preview-\(index)", url: URL(fileURLWithPath: "/preview"),
                     projectName: item.0, projectURL: URL(fileURLWithPath: "/preview"),
                     modified: Date().addingTimeInterval(Double(-index * 300)), title: item.1, isActive: index == 0)
    }
    return snapshot
}

private struct WidgetPreview: View {
    var body: some View {
        VStack(spacing: 10) {
            Text("DESIGN PREVIEW · SAMPLE DATA")
                .font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.secondary)
            CodexTrackerPanelView(dismiss: {}, previewSnapshot: previewSnapshot())
        }
        .padding(20)

        .environment(\.colorScheme, .dark)
    }
}

@main
private final class WidgetPreviewApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    static func main() {
        let app = NSApplication.shared
        let delegate = WidgetPreviewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: WidgetPreview())
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 390, height: 705),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.title = "Codex Usage • Transparency Preview"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let index = CommandLine.arguments.firstIndex(of: "--capture"), CommandLine.arguments.count > index + 1 {
            let folder = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            for (index, theme) in CodexTheme.allCases.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
                    UserDefaults.standard.set(theme.rawValue, forKey: CodexTheme.storageKey)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5 + 1.0) {
                    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("theme-\(theme.rawValue.lowercased()).png"))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                UserDefaults.standard.set(CodexTheme.astra.rawValue, forKey: CodexTheme.storageKey)
                NSApp.terminate(nil)
            }
        }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
