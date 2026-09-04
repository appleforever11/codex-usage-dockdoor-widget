import SwiftUI
import AppKit

// Shared by the panel and dock: AppStorage propagates palette changes immediately.
enum CodexTheme: String, CaseIterable, Identifiable {
    case astra = "Astra", luna = "Luna", sol = "Sol", terra = "Terra", rainbow = "Rainbow"
    static let storageKey = "widget.codex-project-tracker.modelTheme"
    static let opacityKey = "widget.codex-project-tracker.backgroundOpacity"
    static let glassKey = "widget.codex-project-tracker.frostedGlass"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .astra: return "sparkles"
        case .luna: return "moon.fill"
        case .sol: return "sun.max.fill"
        case .terra: return "globe.americas.fill"
        case .rainbow: return "rainbow"
        }
    }
    var accent: Color { colors[1] }
    var colors: [Color] {
        switch self {
        case .astra: return [Color(red: 0.38, green: 0.16, blue: 0.85), Color(red: 0.76, green: 0.48, blue: 1), Color(red: 0.98, green: 0.72, blue: 1)]
        case .luna: return [Color(red: 0.20, green: 0.36, blue: 0.90), Color(red: 0.40, green: 0.77, blue: 1), Color(red: 0.80, green: 0.91, blue: 1)]
        case .sol: return [Color(red: 0.85, green: 0.25, blue: 0.10), Color(red: 1, green: 0.61, blue: 0.20), Color(red: 1, green: 0.88, blue: 0.49)]
        case .terra: return [Color(red: 0.62, green: 0.36, blue: 0.19), Color(red: 0.30, green: 0.77, blue: 0.52), Color(red: 0.78, green: 0.87, blue: 0.56)]
        case .rainbow: return [.pink, .orange, .yellow, .green, .cyan, .purple, .pink]
        }
    }
    var base: Color {
        switch self {
        case .astra: return Color(red: 0.055, green: 0.025, blue: 0.12)
        case .luna: return Color(red: 0.025, green: 0.055, blue: 0.12)
        case .sol: return Color(red: 0.13, green: 0.055, blue: 0.025)
        case .terra: return Color(red: 0.065, green: 0.08, blue: 0.045)
        case .rainbow: return Color(red: 0.07, green: 0.055, blue: 0.10)
        }
    }
}

private struct CodexThemeKey: EnvironmentKey {
    static let defaultValue = CodexTheme.astra
}
extension EnvironmentValues {
    var codexTheme: CodexTheme {
        get { self[CodexThemeKey.self] }
        set { self[CodexThemeKey.self] = newValue }
    }
}

struct CodexThemeMenu: View {
    @Binding var selection: String
    @AppStorage(CodexTheme.opacityKey) private var opacity = 0.75
    @AppStorage(CodexTheme.glassKey) private var frosted = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isPresented = false
    private var theme: CodexTheme { CodexTheme(rawValue: selection) ?? .astra }
    var body: some View {
        Button { isPresented.toggle() } label: {
            Image(systemName: "paintpalette.fill")
                .foregroundStyle(theme.accent)
                .frame(width: 24, height: 24)
                .background(theme.accent.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isPresented, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Appearance").font(.headline)
                ForEach(CodexTheme.allCases) { option in
                    Button { selection = option.rawValue } label: {
                        HStack {
                            Image(systemName: option.symbol).foregroundStyle(option.accent).frame(width: 18)
                            Text(option.rawValue)
                            Spacer()
                            if selection == option.rawValue { Image(systemName: "checkmark").foregroundStyle(option.accent) }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selection == option.rawValue ? .isSelected : [])
                }
                Divider()
                HStack {
                    Text("Background opacity")
                    Spacer()
                    Text("\(Int((opacity * 100).rounded()))%")
                        .monospacedDigit().foregroundStyle(.secondary)
                }
                Slider(value: $opacity, in: 0.2...1, step: 0.05)
                    .accessibilityLabel("Background opacity")
                    .disabled(reduceTransparency)
                HStack {
                    Text("More transparent")
                    Spacer()
                    Text("Solid")
                }
                .font(.caption2).foregroundStyle(.secondary)
                Toggle("Frosted glass", isOn: $frosted)
                    .disabled(reduceTransparency)
                if reduceTransparency {
                    Text("Reduce Transparency is enabled in macOS.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Text and controls stay fully visible.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(width: 250)
            .tint(theme.accent)
        }
        .help("Choose theme and transparency")
        .accessibilityLabel("Widget appearance")
        .accessibilityValue(theme.rawValue)
    }
}

// Native behind-window material lets the desktop show through a transparent host.
private struct CodexFrostedBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .hudWindow
        view.state = .active
        return view
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct CodexThemeBackground: View {
    let theme: CodexTheme
    @AppStorage(CodexTheme.opacityKey) private var opacity = 0.75
    @AppStorage(CodexTheme.glassKey) private var frosted = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        ZStack {
            if frosted && !reduceTransparency {
                CodexFrostedBackdrop()
            }
            theme.base.opacity(reduceTransparency ? 1 : min(max(opacity, 0.2), 1))
            RadialGradient(colors: [theme.accent.opacity(0.20), .clear], center: .topTrailing,
                           startRadius: 10, endRadius: 360)
            // Static points keep the main surface quiet; only model buttons animate.
            if theme == .astra {
                Canvas { context, size in
                    for index in 0..<32 {
                        let x = CGFloat((index * 73 + 13) % 347) / 347 * size.width
                        let y = CGFloat((index * 97 + 7) % 641) / 641 * size.height
                        let radius: CGFloat = index.isMultiple(of: 5) ? 1 : 0.5
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                                     with: .color(.white.opacity(index.isMultiple(of: 5) ? 0.20 : 0.10)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
