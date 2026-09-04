import AppKit
import SwiftUI

private struct RingPreview: View {
    private let themes: [CodexTheme] = [.astra, .luna, .sol, .terra]
    var body: some View {
        VStack(spacing: 0) {
            row(reduced: false)
            row(reduced: true)
        }
        .frame(width: 520, height: 340)
        .background(Color(red: 0.055, green: 0.025, blue: 0.12))
        .environment(\.colorScheme, .dark)
    }
    private func row(reduced: Bool) -> some View {
        HStack(spacing: 0) {
            ForEach(themes) { theme in
                VStack(spacing: 12) {
                    Text(theme.rawValue + (reduced ? " · Still" : ""))
                        .font(.caption.weight(.semibold))
                    UsageRingView(percentRemaining: 0.78, size: reduced ? 35 : 72,
                                  lineWidth: reduced ? 3 : 7, theme: theme, forceReducedMotion: reduced)
                }
                .frame(width: 130, height: 170)
            }
        }
    }
}

@main
final class RingPreviewApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    static func main() {
        let app = NSApplication.shared
        let delegate = RingPreviewApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingView(rootView: RingPreview())
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Astra Ring • Animation Check"
        window.contentView = host
        window.center()
        window.makeKeyAndOrderFront(nil)
        if CommandLine.arguments.count > 1 {
            let folder = URL(fileURLWithPath: CommandLine.arguments[1])
            for index in 1...2 {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) {
                    guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    try? bitmap.representation(using: .png, properties: [:])?.write(to: folder.appendingPathComponent("ring-frame-\(index).png"))
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { NSApp.terminate(nil) }
        }
    }
}
