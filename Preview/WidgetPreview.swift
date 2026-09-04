import AppKit
import SwiftUI

private func previewSnapshot() -> CodexSnapshot {
    var snapshot = CodexSnapshot.empty
    snapshot.modelSettings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "medium")
    snapshot.projectCount = 3
    snapshot.chatCount = 24
    snapshot.taskCount = 6
    snapshot.usage = CodexUsageSnapshot(percentRemaining: 0.78, primaryTitle: "78% remaining",
        primarySubtitle: "Account usage · 5-hour window", windowUsedTokens: 1_250_000,
        todayUsedTokens: 3_700_000, budgetTokens: 0, resetDate: Date().addingTimeInterval(7500),
        resetLabel: nil, source: "Preview data", metrics: [
            CodexUsageMetric(title: "Weekly allowance", value: "64% left", systemImage: "calendar", tint: .purple),
            CodexUsageMetric(title: "5-hour allowance", value: "78% left", systemImage: "clock", tint: .purple)
        ], accountCards: [], lastUpdated: Date())
    snapshot.panelSessions = [
        ("Widget design", "Explore the new model themes"),
        ("Native app", "Refine the sidebar and search"),
        ("Release preparation", "Review the latest changes"),
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
