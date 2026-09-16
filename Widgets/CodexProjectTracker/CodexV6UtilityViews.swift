import Foundation
import SwiftUI

struct CodexV6DataStatusBadge: View {
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    private var title: String {
        if usage.source == "Loading" { return "Loading" }
        if usage.source == "No account snapshot" { return "Waiting" }
        return usage.isStale ? "Stale" : "Live"
    }

    private var tint: Color {
        if usage.source == "Loading" { return .secondary }
        if usage.isStale || usage.source == "No account snapshot" { return theme.dataColor(1) }
        return theme.dataColor(2)
    }

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 5, height: 5)
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(tint.opacity(0.11), in: Capsule())
        .overlay(Capsule().stroke(tint.opacity(0.18), lineWidth: 0.6))
        .help(usage.statusLabel(now: now))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Data status")
        .accessibilityValue("\(title). \(usage.statusLabel(now: now))")
    }
}

struct CodexV6DataNotice: View {
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    private var isVisible: Bool {
        usage.source == "No account snapshot" || usage.isStale
    }

    var body: some View {
        if isVisible {
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: usage.source == "No account snapshot" ? "wifi.exclamationmark" : "clock.badge.exclamationmark")
                    .foregroundStyle(theme.dataColor(1))
                VStack(alignment: .leading, spacing: 2) {
                    Text(usage.source == "No account snapshot" ? "Account data unavailable" : "Showing stale account data")
                        .font(.caption2.weight(.bold))
                    Text(usage.warning ?? usage.statusLabel(now: now))
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .background(theme.dataColor(1).opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(theme.dataColor(1).opacity(0.22), lineWidth: 0.7))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(usage.source == "No account snapshot" ? "Account data unavailable" : "Showing stale account data")
            .accessibilityValue(usage.warning ?? usage.statusLabel(now: now))
        }
    }
}

struct CodexV6TrendBadge: View {
    let change: Double
    let label: String
    @Environment(\.codexTheme) private var theme

    private var roundedPercent: Int { Int((abs(change) * 100).rounded()) }
    private var isNeutral: Bool { roundedPercent == 0 }
    private var tint: Color { isNeutral ? .secondary : theme.dataColor(change >= 0 ? 1 : 2) }
    private var symbol: String {
        if isNeutral { return "arrow.right" }
        return change >= 0 ? "arrow.up.right" : "arrow.down.right"
    }

    var body: some View {
        Label("\(roundedPercent)% \(label)", systemImage: symbol)
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint.opacity(0.10), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.16), lineWidth: 0.6))
            .help("Today is \(change >= 0 ? "up" : "down") \(roundedPercent)% compared with the previous day")
            .accessibilityLabel("Trend")
            .accessibilityValue("\(roundedPercent) percent \(change >= 0 ? "higher" : "lower") \(label)")
    }
}

struct CodexV6FilterBar: View {
    let page: CodexV6Page
    @Binding var activityWindow: CodexV6AnalyticsWindow
    @Binding var modelFilter: String?
    let models: [CodexAnalyticsModel]
    @Environment(\.codexTheme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.caption2.weight(.bold))
                .foregroundStyle(theme.accent)

            if page == .activity {
                Menu {
                    ForEach(CodexV6AnalyticsWindow.allCases) { option in
                        Button {
                            activityWindow = option
                        } label: {
                            HStack {
                                Text(option.title)
                                if activityWindow == option { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Label(activityWindow.title, systemImage: "calendar")
                }
                .menuStyle(.borderlessButton)
                .help("Choose the activity window")
            } else if page == .models {
                Menu {
                    Button {
                        modelFilter = nil
                    } label: {
                        HStack {
                            Text("All models")
                            if modelFilter == nil { Image(systemName: "checkmark") }
                        }
                    }
                    Divider()
                    ForEach(models) { model in
                        Button {
                            modelFilter = model.id
                        } label: {
                            HStack {
                                Text("\(model.modelLabel) · \(model.reasoningLabel)")
                                if modelFilter == model.id { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    Label(modelFilterTitle, systemImage: "cpu")
                }
                .menuStyle(.borderlessButton)
                .help("Filter model and reasoning breakdowns")
            }

            Spacer(minLength: 0)

            HStack(spacing: 4) {
                CodexThemePlanetMarker(theme: theme)
                Text(page == .activity ? "Local activity" : "Attributed events")
            }
        }
        .font(.system(size: 9, weight: .semibold, design: .rounded))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(theme.accent.opacity(0.07), in: Capsule())
        .overlay(Capsule().stroke(theme.accent.opacity(0.13), lineWidth: 0.6))
        .tint(theme.accent)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(page == .activity ? "Activity filters" : "Model filters")
    }

    private var modelFilterTitle: String {
        guard let modelFilter,
              let model = models.first(where: { $0.id == modelFilter })
        else { return "All models" }
        return "\(model.modelLabel) · \(model.reasoningLabel)"
    }
}

struct CodexV6AppearancePopover: View {
    @Binding var theme: CodexTheme
    @Binding var visualTuning: CodexV6VisualTuning
    @Binding var cardDensity: CodexV6CardDensity
    @Binding var showDataStatus: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text("Appearance")
                    .font(.headline.weight(.bold))
                Spacer(minLength: 5)
                Text(theme.rawValue)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.accent)
            }

            Text("Page theme")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(CodexTheme.allCases) { option in
                    Button {
                        theme = option
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: option.symbol)
                                .font(.caption.weight(.bold))
                            Text(option.rawValue)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(option.accent)
                        .background(option.base.opacity(theme == option ? 0.72 : 0.34), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(option.accent.opacity(theme == option ? 0.90 : 0.22), lineWidth: theme == option ? 1.2 : 0.7))
                    }
                    .buttonStyle(.plain)
                    .help("Use the \(option.rawValue) theme for this page")
                    .accessibilityAddTraits(theme == option ? .isSelected : [])
                }
            }

            Divider().opacity(0.45)

            HStack {
                Label("Glow", systemImage: "sun.max.fill")
                Spacer()
                Text("\(Int((visualTuning.glowIntensity * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: tuningBinding(\.glowIntensity), in: 0...1.5)
                .accessibilityLabel("Glow intensity")

            HStack {
                Label("Sparkles", systemImage: "sparkles")
                Spacer()
                Text("\(Int((visualTuning.sparkleIntensity * 100).rounded()))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: tuningBinding(\.sparkleIntensity), in: 0...1.5)
                .accessibilityLabel("Sparkle intensity")

            Toggle("Animate glow and sparkles", isOn: tuningBinding(\.animationsEnabled))
                .disabled(reduceMotion)
            Toggle("High contrast edges", isOn: tuningBinding(\.highContrast))
            Picker("Card density", selection: $cardDensity) {
                ForEach(CodexV6CardDensity.allCases) { density in
                    Text(density.title).tag(density)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Card density")
            Toggle("Show live data status", isOn: $showDataStatus)

            if reduceMotion {
                Label("macOS Reduce Motion is enabled", systemImage: "figure.walk.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Animation controls respect macOS accessibility settings.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(15)
        .frame(width: 285)
        .tint(theme.accent)
    }

    private func tuningBinding<Value>(_ keyPath: WritableKeyPath<CodexV6VisualTuning, Value>) -> Binding<Value> {
        Binding(
            get: { visualTuning[keyPath: keyPath] },
            set: { newValue in
                var updated = visualTuning
                updated[keyPath: keyPath] = newValue
                visualTuning = updated
            }
        )
    }
}

struct CodexV6SwipeProgress: View {
    let progress: CGFloat
    let theme: CodexTheme

    var body: some View {
        GeometryReader { geometry in
            let clamped = min(max(progress, 0), 1)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.12))
                Capsule()
                    .fill(theme.dataGradient(role: 1))
                    .frame(width: geometry.size.width * clamped)
            }
        }
        .frame(width: 42, height: 2)
        .opacity(progress > 0.02 ? 1 : 0)
        .animation(.easeOut(duration: 0.12), value: progress)
        .accessibilityHidden(true)
    }
}

struct CodexV6LoadingState: View {
    let theme: CodexTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Loading Codex Usage")
                        .font(.headline.weight(.bold))
                    Text("Reading local activity and account limits")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            ForEach(0..<4, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(theme.accent.opacity(0.18))
                        .frame(width: index == 0 ? 92 : 70, height: 9)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(0.08))
                        .frame(height: 7)
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(.white.opacity(0.055))
                        .frame(width: 180, height: 7)
                }
                .padding(12)
                .background(CodexThemeCardSurface(theme: theme, cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(theme.accent.opacity(0.12), lineWidth: 0.7))
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 350, height: 640, alignment: .topLeading)
        .background(CodexThemeBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
