import AppKit
import SwiftUI

private func dockPreviewSnapshot() -> CodexSnapshot {
    var snapshot = CodexSnapshot.empty
    snapshot.projectCount = 5
    snapshot.activeCount = 3
    snapshot.chatCount = 403
    snapshot.taskCount = 3
    snapshot.headline = "5 projects active"
    snapshot.modelSettings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "max")
    snapshot.usage = CodexUsageSnapshot(
        percentRemaining: 0.91,
        primaryTitle: "91% Left",
        primarySubtitle: "General · 5-hour window",
        windowUsedTokens: 1_200_000,
        todayUsedTokens: 3_700_000,
        budgetTokens: 0,
        resetDate: Date().addingTimeInterval(6 * 86_400 + 4 * 3_600),
        resetLabel: nil,
        source: "Codex app-server",
        metrics: [],
        accountCards: [
            CodexDockCard(
                title: "91% Left",
                subtitle: "General · 5-hour window",
                shortLabel: "Usage",
                percentRemaining: 0.91,
                kind: CodexCardKind.usage.rawValue
            )
        ],
        lastUpdated: Date(),
        isStale: false
    )
    return snapshot
}

private struct DockPreviewGallery: View {
    private let snapshot = dockPreviewSnapshot()
    private let horizontalSize = CGSize(width: 216, height: 58)
    private let verticalSize = CGSize(width: 64, height: 174)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.06, blue: 0.08), Color(red: 0.16, green: 0.18, blue: 0.22)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DOCK PREVIEW · CODEX USAGE 6.0")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.4)
                        .foregroundStyle(.white.opacity(0.72))
                    Text("The extended slot now carries the same living theme language as the v6 dashboard.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.48))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("EXTENDED HORIZONTAL SLOTS")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.46))
                    HStack(spacing: 10) {
                        ForEach(CodexTheme.allCases) { theme in
                            CodexTrackerCompactView(size: horizontalSize, isVertical: false, previewSnapshot: snapshot, previewTheme: theme)
                                .environment(\.colorScheme, .dark)
                                .environment(\.codexVisualTuning, .standard)
                                .frame(width: horizontalSize.width, height: horizontalSize.height)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("COMPACT + EXTENDED VERTICAL")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.46))
                    HStack(alignment: .top, spacing: 16) {
                        CodexTrackerCompactView(size: CGSize(width: 66, height: 66), isVertical: false, previewSnapshot: snapshot, previewTheme: .astra)
                            .environment(\.colorScheme, .dark)
                            .frame(width: 66, height: 66)
                        CodexTrackerCompactView(size: verticalSize, isVertical: true, previewSnapshot: snapshot, previewTheme: .astra)
                            .environment(\.colorScheme, .dark)
                            .frame(width: verticalSize.width, height: verticalSize.height)
                    }
                }
            }
            .padding(26)
        }
        .frame(width: 1180, height: 350)
        .preferredColorScheme(.dark)
    }
}

@main
private final class DockWidgetPreviewApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = DockWidgetPreviewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: DockPreviewGallery())
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 350),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Codex Usage 6.0 · Dock Widget Preview"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let index = CommandLine.arguments.firstIndex(of: "--capture"),
           CommandLine.arguments.count > index + 1 {
            let output = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                    NSApp.terminate(nil)
                    return
                }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                try? FileManager.default.createDirectory(at: output.deletingLastPathComponent(),
                                                         withIntermediateDirectories: true)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: output)
                NSApp.terminate(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
