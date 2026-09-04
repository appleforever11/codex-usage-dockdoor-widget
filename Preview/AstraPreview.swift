import AppKit
import SwiftUI

private struct AstraPreview: View {
    @State private var settings = CodexModelSettings(model: CodexModelSettings.astraModel, reasoningEffort: "max")

    var body: some View {
        ModelControlSection(settings: settings) { model, reasoning in
            settings = CodexModelSettings(model: model, reasoningEffort: reasoning)
        }
        .padding(14)
        .frame(width: 350)
        .background(Color(red: 0.11, green: 0.11, blue: 0.13))
        .environment(\.colorScheme, .dark)
    }
}

@main
private final class AstraPreviewApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!

    static func main() {
        let app = NSApplication.shared
        let delegate = AstraPreviewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: AstraPreview())
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 145),
            styleMask: [.titled, .closable], backing: .buffered, defer: false
        )
        window.title = "Astra Button Preview"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let index = CommandLine.arguments.firstIndex(of: "--capture"),
           CommandLine.arguments.count > index + 1 {
            let folder = URL(fileURLWithPath: CommandLine.arguments[index + 1])
            for (offset, name) in [(1.0, "astra-preview.png"), (2.3, "astra-preview-next.png")] {
                DispatchQueue.main.asyncAfter(deadline: .now() + offset) {
                    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?
                        .write(to: folder.appendingPathComponent(name))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { NSApp.terminate(nil) }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
