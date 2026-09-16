import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct UsageRingView: View {
    let percentRemaining: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let theme: CodexTheme
    var forceReducedMotion = false

    private var clamped: Double { percentRemaining.isFinite ? min(max(percentRemaining, 0), 1) : 0 }
    private var ringColors: [Color] { theme.dataColors }
    private var glowColor: Color { theme.accent }

    var body: some View {
        ZStack {
            Circle()
                .stroke(theme.accent.opacity(0.14), lineWidth: lineWidth)
            if clamped > 0 {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(colors: ringColors, center: .center),
                        style: StrokeStyle(lineWidth: lineWidth * 1.55, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .blur(radius: max(2, lineWidth * 0.55))
                    .opacity(0.55)
            }
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    AngularGradient(
                        colors: ringColors,
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: -1) {
                Text("\(Int((clamped * 100).rounded()))")
                    .font(.system(size: size * 0.34, weight: .black, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: size * 0.15, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .minimumScaleFactor(0.65)
        }
        .frame(width: size, height: size)
        .overlay {
            if clamped > 0 {
                CodexThemeRingSparkles(progress: clamped,
                                       ringSize: size,
                                       lineWidth: lineWidth,
                                       theme: theme,
                                       forceReducedMotion: forceReducedMotion)
            }
        }
        .shadow(color: glowColor.opacity(0.42), radius: 7, y: 1)
        .accessibilityLabel("Codex usage remaining")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

enum CodexAppIconProvider {
    static let icon: NSImage? = {
        let fileManager = FileManager.default
        let resourceCandidates = [
            "/Applications/Codex.app/Contents/Resources/icon.icns",
            "/Applications/Codex.app/Contents/Resources/electron.icns",
            "/Applications/Codex.app/Contents/Resources/app.icns",
            "/Applications/ChatGPT.app/Contents/Resources/icon.icns",
            "/Applications/ChatGPT.app/Contents/Resources/electron.icns",
            "/Applications/ChatGPT.app/Contents/Resources/app.icns",
        ]

        for path in resourceCandidates where fileManager.fileExists(atPath: path) {
            if let image = NSImage(contentsOfFile: path) {
                image.size = NSSize(width: 128, height: 128)
                return image
            }
        }

        for appPath in ["/Applications/Codex.app", "/Applications/ChatGPT.app"] where fileManager.fileExists(atPath: appPath) {
            let image = NSWorkspace.shared.icon(forFile: appPath)
            image.size = NSSize(width: 128, height: 128)
            return image
        }

        return nil
    }()
}
