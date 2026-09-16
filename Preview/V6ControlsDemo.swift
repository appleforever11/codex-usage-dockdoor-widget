import AppKit
import SwiftUI

private struct V6ControlsDemoRoot: View {
    @State private var settings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "medium")

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("6.0 MODEL THEMES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            Text("Purple glow + optional haptic selection")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.82))
            ModelControlSection(settings: settings) { model, reasoning in
                settings = CodexModelSettings(model: model, reasoningEffort: reasoning)
                return true
            }
        }
        .padding(14)
        .frame(width: 370)
        .background(CodexThemeBackground(theme: .astra))
        .environment(\.codexTheme, .astra)
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
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Codex Usage 6.0 · Model Themes"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
