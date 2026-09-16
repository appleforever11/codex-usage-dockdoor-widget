import AppKit
import SwiftUI

private struct V6ControlsDemoRoot: View {
    @State private var settings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "max")
    @State private var theme = CodexTheme.astra
    @State private var tuning = CodexV6VisualTuning()
    @State private var density = CodexV6CardDensity.compact
    @State private var showStatus = true

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("New chat defaults")
                    .font(.system(size: 16, weight: .bold))
                Text("Shared model and theme artwork")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ModelControlSection(settings: settings, isEmbedded: true) { model, reasoning in
                    settings = CodexModelSettings(model: model, reasoningEffort: reasoning)
                    return true
                }
                .padding(12)
                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(16)
            .frame(width: 350)
            .background { CodexThemeBackground(theme: theme).clipShape(RoundedRectangle(cornerRadius: 18)) }

            CodexV6AppearancePopover(theme: $theme, visualTuning: $tuning,
                                     cardDensity: $density, showDataStatus: $showStatus,
                                     hapticsEnabled: true)
                .background { CodexThemeBackground(theme: theme).clipShape(RoundedRectangle(cornerRadius: 18)) }
        }
        .padding(20)
        .environment(\.codexTheme, theme)
        .environment(\.codexVisualTuning, tuning)
        .environment(\.colorScheme, .dark)
    }
}

@main
private final class V6ControlsDemoApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = V6ControlsDemoApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: V6ControlsDemoRoot())
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 708, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Usage 6.0 · Appearance & Models"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
