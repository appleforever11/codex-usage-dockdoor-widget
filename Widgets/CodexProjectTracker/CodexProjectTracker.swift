import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

final class CodexProjectTrackerPlugin: WidgetPlugin, DockDoorWidgetProvider {
    var id: String { "codex-project-tracker" }
    var name: String { "Codex Usage" }
    var iconSymbol: String { "gauge.with.dots.needle.67percent" }
    var widgetDescription: String { "Shows Codex usage countdowns, recent projects, tasks, and chats" }
    var supportedOrientations: [WidgetOrientation] { [.horizontal, .vertical] }

    @MainActor
    func makeBody(size: CGSize, isVertical: Bool) -> AnyView {
        return AnyView(CodexTrackerCompactView(size: size, isVertical: isVertical))
    }

    @MainActor
    func makePanelBody(dismiss: @escaping () -> Void) -> AnyView? {
        return AnyView(CodexTrackerPanelView(dismiss: dismiss))
    }

    func settingsSchema() -> [WidgetSetting] {
        return [
            .textField(
                key: "projectsRoot",
                label: "Codex Sessions Folder",
                placeholder: "~/.codex/sessions",
                defaultValue: CodexTrackerStore.defaultProjectsRoot.path
            ),
            .slider(
                key: "recentLimit",
                label: "Recent Session Count",
                range: 3...10,
                step: 1,
                defaultValue: 5
            ),
            .slider(
                key: "usageBudgetMillions",
                label: "Usage Budget (M tokens)",
                range: 25...500,
                step: 25,
                defaultValue: 200
            ),
            .slider(
                key: "usageWindowHours",
                label: "Usage Window Hours",
                range: 1...24,
                step: 1,
                defaultValue: 5
            ),
            .textField(
                key: "usageStatePath",
                label: "Usage State File",
                placeholder: "~/.codex/usage.json",
                defaultValue: "~/.codex/usage.json"
            ),
            .toggle(
                key: "rainbowUsageRing",
                label: "Rainbow Usage Ring",
                defaultValue: true
            ),
        ]
    }

    func performTapAction() {
        CodexAppLauncher.openCodex()
    }
}

private struct CodexTrackerCompactView: View {
    let size: CGSize
    let isVertical: Bool
    @State private var snapshot = CodexSnapshot.empty
    @State private var now = Date()
    @State private var rainbowUsageRing = CodexWidgetPreferences.rainbowUsageRing

    private var dim: CGFloat { min(size.width, size.height) }
    private var gaugeSize: CGFloat { min(dim * 0.70, 35) }
    private var horizontalGaugeOutset: CGFloat { max(3, min(dim * 0.07, 4)) }
    private var compactTitleSize: CGFloat { max(9, min(dim * 0.22, 12)) }
    private var titleSize: CGFloat { isVertical ? max(10, min(dim * 0.21, 13)) : max(11, min(dim * 0.22, 13)) }
    private var subtitleSize: CGFloat { isVertical ? max(8, min(dim * 0.16, 10)) : max(8.5, min(dim * 0.16, 9.5)) }
    private var isExtended: Bool {
        isVertical ? size.height > size.width * 1.5 : size.width > size.height * 1.5
    }
    private var card: CodexDockCard { snapshot.rotatingDockCard(at: now) }

    var body: some View {
        Group {
            if isExtended {
                extendedLayout
            } else {
                compactLayout
            }
        }
        .task {
            while !Task.isCancelled {
                let refreshed = await CodexTrackerStore.snapshot()
                snapshot = refreshed
                CodexSnapshotCache.latest = refreshed
                rainbowUsageRing = CodexWidgetPreferences.rainbowUsageRing
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 1) {
            UsageRingView(
                percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining,
                size: gaugeSize,
                lineWidth: max(3, dim * 0.055),
                rainbow: rainbowUsageRing
            )
            Text(card.shortLabel)
                .font(.system(size: compactTitleSize, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.primary)
    }

    private var extendedLayout: some View {
        Group {
            if isVertical {
                VStack(spacing: dim * 0.08) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), rainbow: rainbowUsageRing)
                    usageLabels(alignment: .center)
                }
            } else {
                HStack(spacing: max(4, dim * 0.05)) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), rainbow: rainbowUsageRing)
                        .frame(
                            width: gaugeSize + (horizontalGaugeOutset * 2),
                            height: gaugeSize + (horizontalGaugeOutset * 2)
                        )
                    usageLabels(alignment: .leading)
                }
                .padding(.leading, 1)
                .padding(.trailing, max(4, dim * 0.06))
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.primary)
    }

    private func usageLabels(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: alignment, spacing: 1) {
                Text(card.title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(card.subtitle)
                    .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)
        }
    }
}

private struct CodexAppIconView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = CodexAppIconProvider.icon {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: max(7, size * 0.22)))
        .overlay {
            RoundedRectangle(cornerRadius: max(7, size * 0.22))
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
    }
}

private struct UsageRingView: View {
    let percentRemaining: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let rainbow: Bool

    private var clamped: Double { min(max(percentRemaining, 0), 1) }
    private var color: Color {
        switch clamped {
        case 0.45...: return Color(red: 0.13, green: 0.72, blue: 1.00)
        case 0.20..<0.45: return .orange
        default: return .red
        }
    }
    private var ringColors: [Color] {
        if rainbow {
            return [
                Color(red: 1.00, green: 0.18, blue: 0.34),
                Color(red: 1.00, green: 0.55, blue: 0.16),
                Color(red: 1.00, green: 0.90, blue: 0.18),
                Color(red: 0.18, green: 0.86, blue: 0.36),
                Color(red: 0.12, green: 0.70, blue: 1.00),
                Color(red: 0.48, green: 0.34, blue: 1.00),
                Color(red: 0.95, green: 0.28, blue: 0.86),
                Color(red: 1.00, green: 0.18, blue: 0.34),
            ]
        }

        return [color.opacity(0.72), color, .cyan.opacity(0.85)]
    }
    private var glowColor: Color {
        rainbow ? Color(red: 0.95, green: 0.28, blue: 0.86) : color
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(rainbow ? 0.10 : 0.14), lineWidth: lineWidth)
            if rainbow {
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
        .background(.black.opacity(0.16), in: Circle())
        .shadow(color: glowColor.opacity(rainbow ? 0.48 : 0.30), radius: rainbow ? 8 : 5, y: 1)
        .accessibilityLabel("Codex usage remaining")
        .accessibilityValue("\(Int((clamped * 100).rounded())) percent")
    }
}

private enum CodexAppIconProvider {
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

@MainActor
private enum CodexSnapshotCache {
    static var latest: CodexSnapshot?
}

@MainActor
private struct CodexTrackerPanelView: View {
    let dismiss: () -> Void
    @State private var snapshot: CodexSnapshot?
    @State private var now = Date()
    @State private var rainbowUsageRing = CodexWidgetPreferences.rainbowUsageRing

    init(dismiss: @escaping () -> Void) {
        self.dismiss = dismiss
        _snapshot = State(initialValue: CodexSnapshotCache.latest)
    }

    var body: some View {
        Group {
            if let snapshot {
                panelContent(snapshot)
            } else {
                loadingContent
            }
        }
        .task {
            if snapshot == nil {
                await refreshSnapshot()
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await refreshSnapshot()
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(30))
            }
        }
    }

    private func panelContent(_ snapshot: CodexSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Codex Usage", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                Spacer()
                Button {
                    toggleFastMode(current: snapshot.modelSettings)
                } label: {
                    Image(systemName: snapshot.modelSettings.isFastMode ? "bolt.fill" : "bolt")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(snapshot.modelSettings.isFastMode ? .yellow : .secondary)
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(snapshot.modelSettings.isFastMode ? 0.12 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help(snapshot.modelSettings.isFastMode ? "Fast mode is on: Spark + Instant" : "Use Spark + Instant for new chats")
                Button {
                    rainbowUsageRing.toggle()
                    CodexWidgetPreferences.setRainbowUsageRing(rainbowUsageRing)
                } label: {
                    Image(systemName: rainbowUsageRing ? "paintpalette.fill" : "paintpalette")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(rainbowUsageRing ? .pink : .secondary)
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(rainbowUsageRing ? 0.12 : 0.06), in: Circle())
                }
                .buttonStyle(.plain)
                .help(rainbowUsageRing ? "Rainbow usage ring is on" : "Turn on rainbow usage ring")
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                UsageRingView(percentRemaining: snapshot.usage.percentRemaining, size: 72, lineWidth: 7, rainbow: rainbowUsageRing)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.usage.primaryTitle)
                        .font(.title3.weight(.bold))
                    Text(snapshot.usage.primarySubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(snapshot.usage.resetSummary(now: now))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tertiary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 10) {
                StatPill(title: "Window", value: snapshot.usage.windowUsedLabel)
                StatPill(title: "Today", value: snapshot.usage.todayUsedLabel)
                StatPill(title: "Tasks", value: "\(snapshot.taskCount)")
                StatPill(title: "Chats", value: "\(snapshot.chatCount)")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Rotating Stats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(snapshot.usage.metrics) { metric in
                    HStack(spacing: 8) {
                        Image(systemName: metric.systemImage)
                            .frame(width: 15)
                            .foregroundStyle(metric.tint)
                        Text(metric.title)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(metric.value)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }

            ModelControlSection(
                settings: snapshot.modelSettings,
                onChange: { model, reasoning in
                    CodexConfigStore.update(model: model, reasoningEffort: reasoning)
                    Task {
                        await refreshSnapshot()
                    }
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Chats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(snapshot.sessions) { session in
                    CodexSessionRow(session: session)
                }
            }

            if let latest = snapshot.latestChat {
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    Text("Latest Chat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(latest)
                        .font(.caption)
                        .lineLimit(2)
                }
            }
        }
        .padding(14)
        .frame(width: 350)
    }

    private var loadingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading Codex Usage")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 350, height: 640)
    }

    private func refreshSnapshot() async {
        let refreshed = await CodexTrackerStore.snapshot()
        CodexSnapshotCache.latest = refreshed
        snapshot = refreshed
        rainbowUsageRing = CodexWidgetPreferences.rainbowUsageRing
    }

    private func toggleFastMode(current: CodexModelSettings) {
        if current.isFastMode {
            let restored = CodexWidgetPreferences.fastModeRestoreSettings
            CodexConfigStore.update(model: restored.model, reasoningEffort: restored.reasoningEffort)
        } else {
            CodexWidgetPreferences.saveFastModeRestoreSettings(current)
            CodexConfigStore.update(model: CodexModelSettings.fast.model, reasoningEffort: CodexModelSettings.fast.reasoningEffort)
        }

        Task {
            await refreshSnapshot()
        }
    }
}

private struct CodexSessionRow: View {
    let session: CodexSession
    @State private var isHovering = false

    var body: some View {
        Button {
            CodexAppLauncher.openSession(session)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: session.isActive ? "circle.fill" : "circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(session.isActive ? Color(red: 0.13, green: 0.72, blue: 1.00) : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(session.title ?? session.relativeActivity)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(session.relativeActivity)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(isHovering ? 0.9 : 0.0))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(.white.opacity(isHovering ? 0.10 : 0.0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Open in Codex")
    }
}

private struct ModelControlSection: View {
    let settings: CodexModelSettings
    let onChange: (String, String) -> Void

    private let models: [CodexPickerOption] = [
        CodexPickerOption(
            label: "Luna",
            value: "gpt-5.6-luna",
            colors: [Color(red: 0.18, green: 0.50, blue: 1.00), Color(red: 0.36, green: 0.22, blue: 0.95)]
        ),
        CodexPickerOption(
            label: "Sol",
            value: "gpt-5.6-sol",
            colors: [Color(red: 1.00, green: 0.60, blue: 0.20), Color(red: 0.95, green: 0.24, blue: 0.44)]
        ),
        CodexPickerOption(
            label: "Spark",
            value: "gpt-5.3-codex-spark",
            colors: [Color(red: 0.20, green: 0.84, blue: 0.48), Color(red: 0.05, green: 0.66, blue: 0.92)]
        ),
    ]

    private let reasoning: [CodexPickerOption] = [
        CodexPickerOption(
            label: "Instant",
            value: "instant",
            colors: [Color(red: 0.12, green: 0.62, blue: 1.00), Color(red: 0.20, green: 0.82, blue: 0.80)]
        ),
        CodexPickerOption(
            label: "Medium",
            value: "medium",
            colors: [Color(red: 0.58, green: 0.44, blue: 1.00), Color(red: 0.78, green: 0.38, blue: 0.96)]
        ),
        CodexPickerOption(
            label: "Max",
            value: "max",
            colors: [Color(red: 1.00, green: 0.46, blue: 0.24), Color(red: 0.92, green: 0.18, blue: 0.56)]
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Codex Defaults")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.86))
                Spacer()
                Text("\(settings.shortModelName) • \(settings.reasoningLabel)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                ForEach(models, id: \.value) { option in
                    CodexChoiceButton(
                        option: option,
                        isSelected: settings.model == option.value
                    ) {
                        onChange(option.value, settings.reasoningEffort)
                    }
                }
            }

            HStack(spacing: 6) {
                ForEach(reasoning, id: \.value) { option in
                    CodexChoiceButton(
                        option: option,
                        isSelected: settings.reasoningEffort == option.value
                    ) {
                        onChange(settings.model, option.value)
                    }
                }
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.070))
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.090), .white.opacity(0.025)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.105), lineWidth: 1)
        }
        .help("Updates ~/.codex/config.toml defaults for new Codex work.")
    }
}

private struct CodexPickerOption {
    let label: String
    let value: String
    let colors: [Color]
}

private struct CodexChoiceButton: View {
    let option: CodexPickerOption
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text(option.label)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(buttonFill)
                .overlay(buttonStroke)
                .shadow(color: selectedGlow, radius: isSelected ? 8 : 0, y: isSelected ? 2 : 0)
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var buttonFill: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? option.colors
                        : option.colors.map { $0.opacity(isHovering ? 0.32 : 0.18) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.08 : (isHovering ? 0.055 : 0.025)))
            }
    }

    private var buttonStroke: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isSelected
                        ? [.white.opacity(0.55), option.colors.last?.opacity(0.65) ?? .white.opacity(0.30)]
                        : [.white.opacity(isHovering ? 0.25 : 0.12), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.25 : 1
            )
    }

    private var selectedGlow: Color {
        (option.colors.last ?? .accentColor).opacity(0.38)
    }
}

private struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct CodexSnapshot {
    var projectCount: Int
    var activeCount: Int
    var chatCount: Int
    var taskCount: Int
    var headline: String
    var latestChat: String?
    var usage: CodexUsageSnapshot
    var modelSettings: CodexModelSettings
    var projects: [CodexProject]
    var sessions: [CodexSession]

    static let empty = CodexSnapshot(
        projectCount: 0,
        activeCount: 0,
        chatCount: 0,
        taskCount: 0,
        headline: "Loading",
        latestChat: nil,
        usage: .empty,
        modelSettings: .default,
        projects: [],
        sessions: []
    )

    func rotatingDockCard(at date: Date) -> CodexDockCard {
        var cards = usage.dockCards
        cards.append(CodexDockCard(
            title: modelSettings.shortModelName,
            subtitle: "\(modelSettings.reasoningLabel) reasoning",
            shortLabel: "Model"
        ))
        cards.append(CodexDockCard(
            title: "\(taskCount) Tasks",
            subtitle: "\(projectCount) projects active",
            shortLabel: "Tasks"
        ))
        cards.append(CodexDockCard(
            title: "\(chatCount) Chats",
            subtitle: headline,
            shortLabel: "Chats"
        ))

        guard !cards.isEmpty else {
            return CodexDockCard(title: "Codex", subtitle: headline, shortLabel: "Codex")
        }

        let index = Int(date.timeIntervalSinceReferenceDate / 4) % cards.count
        return cards[index]
    }
}

private struct CodexModelSettings {
    var model: String
    var reasoningEffort: String

    static let `default` = CodexModelSettings(model: "gpt-5.6-luna", reasoningEffort: "medium")
    static let fast = CodexModelSettings(model: "gpt-5.3-codex-spark", reasoningEffort: "instant")

    var isFastMode: Bool {
        model == Self.fast.model && reasoningEffort == Self.fast.reasoningEffort
    }

    var shortModelName: String {
        if model.localizedCaseInsensitiveContains("spark") { return "Spark" }
        if model.localizedCaseInsensitiveContains("luna") { return "Luna" }
        if model.localizedCaseInsensitiveContains("sol") { return "Sol" }
        if model.count > 14 { return String(model.prefix(14)) }
        return model
    }

    var reasoningLabel: String {
        if reasoningEffort == "max" { return "Max" }
        return reasoningEffort.prefix(1).uppercased() + reasoningEffort.dropFirst()
    }
}

private struct CodexDockCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let shortLabel: String
    let percentRemaining: Double?

    init(title: String, subtitle: String, shortLabel: String, percentRemaining: Double? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.shortLabel = shortLabel
        self.percentRemaining = percentRemaining
    }
}

private struct CodexUsageSnapshot {
    var percentRemaining: Double
    var primaryTitle: String
    var primarySubtitle: String
    var windowUsedTokens: Int64
    var todayUsedTokens: Int64
    var budgetTokens: Int64
    var resetDate: Date?
    var resetLabel: String?
    var source: String
    var metrics: [CodexUsageMetric]
    var accountCards: [CodexDockCard]

    static let empty = CodexUsageSnapshot(
        percentRemaining: 1,
        primaryTitle: "Usage Ready",
        primarySubtitle: "Waiting for Codex activity",
        windowUsedTokens: 0,
        todayUsedTokens: 0,
        budgetTokens: 0,
        resetDate: nil,
        resetLabel: nil,
        source: "loading",
        metrics: [],
        accountCards: []
    )

    var windowUsedLabel: String { Self.compactTokens(windowUsedTokens) }
    var todayUsedLabel: String { Self.compactTokens(todayUsedTokens) }

    var dockCards: [CodexDockCard] {
        if !accountCards.isEmpty {
            return accountCards
        }

        return [
            CodexDockCard(
                title: "\(Int((percentRemaining * 100).rounded()))% Left",
                subtitle: primarySubtitle,
                shortLabel: "Left",
                percentRemaining: percentRemaining
            ),
            CodexDockCard(
                title: "Used \(windowUsedLabel)",
                subtitle: source,
                shortLabel: "Usage"
            ),
            CodexDockCard(
                title: resetTitle,
                subtitle: resetDate == nil && resetLabel == nil ? "No reset time found" : "Usage limit countdown",
                shortLabel: "Reset"
            ),
        ]
    }

    var resetTitle: String {
        if let resetLabel {
            return "Reset \(resetLabel)"
        }
        if let resetDate {
            return "Reset \(Self.relativeReset(resetDate))"
        }
        return "Reset Soon"
    }

    func resetSummary(now: Date) -> String {
        if let resetLabel {
            return "Resets \(resetLabel)"
        }
        guard let resetDate else { return "No reset time exposed locally yet" }
        let interval = max(0, resetDate.timeIntervalSince(now))
        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        }
        return "Resets in \(minutes)m"
    }

    static func compactTokens(_ tokens: Int64) -> String {
        let value = Double(max(tokens, 0))
        if value >= 1_000_000 {
            return String(format: "%.1fM", value / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.0fK", value / 1_000)
        }
        return "\(Int(value))"
    }

    private static func relativeReset(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

private struct CodexUsageMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

private struct CodexProject: Identifiable {
    let id: String
    let name: String
    let url: URL
    let modified: Date
    let isActive: Bool

    var relativeActivity: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modified, relativeTo: Date())
    }
}

private struct CodexSession: Identifiable {
    let id: String
    let url: URL
    let projectName: String
    let projectURL: URL
    let modified: Date
    let title: String?
    let isActive: Bool

    var relativeActivity: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: modified, relativeTo: Date())
    }

    var codexDeepLink: URL? {
        guard UUID(uuidString: id) != nil else { return nil }
        return URL(string: "codex://threads/\(id)")
    }
}

private enum CodexAppLauncher {
    private static let codexAppURLs = [
        URL(fileURLWithPath: "/Applications/Codex.app"),
        URL(fileURLWithPath: "/Applications/ChatGPT.app"),
    ]

    static func openSession(_ session: CodexSession) {
        if let deepLink = session.codexDeepLink {
            NSWorkspace.shared.open(deepLink)
        } else {
            openCodex()
        }
    }

    static func openCodex() {
        for appURL in codexAppURLs where FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.open(appURL)
            return
        }

        NSWorkspace.shared.open(CodexTrackerStore.defaultProjectsRoot)
    }
}

private enum CodexWidgetPreferences {
    private static let widgetId = "codex-project-tracker"
    private static let rainbowKey = "rainbowUsageRing"
    private static let fastRestoreModelKey = "fastModeRestoreModel"
    private static let fastRestoreReasoningKey = "fastModeRestoreReasoning"

    static var rainbowUsageRing: Bool {
        WidgetDefaults.bool(key: rainbowKey, widgetId: widgetId, default: true)
    }

    static func setRainbowUsageRing(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: "widget.\(widgetId).\(rainbowKey)")
    }

    static var fastModeRestoreSettings: CodexModelSettings {
        let defaults = UserDefaults.standard
        let model = defaults.string(forKey: "widget.\(widgetId).\(fastRestoreModelKey)") ?? CodexModelSettings.default.model
        let storedReasoning = defaults.string(forKey: "widget.\(widgetId).\(fastRestoreReasoningKey)") ?? CodexModelSettings.default.reasoningEffort
        let reasoning = CodexConfigStore.normalizedReasoningEffort(storedReasoning)
        return CodexModelSettings(model: model, reasoningEffort: reasoning)
    }

    static func saveFastModeRestoreSettings(_ settings: CodexModelSettings) {
        let defaults = UserDefaults.standard
        defaults.set(settings.model, forKey: "widget.\(widgetId).\(fastRestoreModelKey)")
        defaults.set(settings.reasoningEffort, forKey: "widget.\(widgetId).\(fastRestoreReasoningKey)")
    }
}

private enum CodexConfigStore {
    private static let configURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/config.toml")

    static func read() -> CodexModelSettings {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return .default
        }

        return CodexModelSettings(
            model: tomlStringValue(for: "model", in: text) ?? CodexModelSettings.default.model,
            reasoningEffort: normalizedReasoningEffort(
                tomlStringValue(for: "model_reasoning_effort", in: text) ?? CodexModelSettings.default.reasoningEffort
            )
        )
    }

    static func update(model: String, reasoningEffort: String) {
        let allowedModels = ["gpt-5.6-luna", "gpt-5.6-sol", "gpt-5.3-codex-spark"]
        let allowedReasoning = ["instant", "medium", "max"]
        guard allowedModels.contains(model), allowedReasoning.contains(reasoningEffort) else { return }

        let current = (try? String(contentsOf: configURL, encoding: .utf8)) ?? ""
        var lines = current.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        upsert(key: "model", value: model, in: &lines)
        upsert(key: "model_reasoning_effort", value: reasoningEffort, in: &lines)

        let output = lines.joined(separator: "\n")
        try? output.write(to: configURL, atomically: true, encoding: .utf8)
    }

    static func normalizedReasoningEffort(_ value: String) -> String {
        switch value.lowercased() {
        case "high", "xhigh", "max": return "max"
        case "instant": return "instant"
        default: return "medium"
        }
    }

    private static func tomlStringValue(for key: String, in text: String) -> String? {
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("\(key) =") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            return parts[1]
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return nil
    }

    private static func upsert(key: String, value: String, in lines: inout [String]) {
        let replacement = "\(key) = \"\(value)\""
        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\(key) =") }) {
            lines[index] = replacement
        } else {
            lines.insert(replacement, at: min(lines.count, 0))
        }
    }
}

private enum CodexTrackerStore {
    static let defaultProjectsRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/sessions")

    private static let codexHome = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex")

    static func snapshot() async -> CodexSnapshot {
        await Task.detached(priority: .utility) {
            buildSnapshot()
        }.value
    }

    private static func buildSnapshot() -> CodexSnapshot {
        let sessionsRoot = configuredProjectsRoot()
        let sessionFiles = sessionFiles(in: sessionsRoot)
        let records = sessionFiles.prefix(500).compactMap { file -> CodexSessionRecord? in
            guard let metadata = sessionMetadata(from: file.url) else { return nil }
            return CodexSessionRecord(file: file, metadata: metadata)
        }
        let sessions = recentSessions(from: records)
        let projects = recentProjects(from: records)
        let latestChat = latestHistoryPrompt()
        let activeCount = sessions.filter(\.isActive).count
        let headline = sessions.first?.projectName ?? projects.first?.name ?? "No sessions"
        let usage = usageSnapshot(projects: projects, sessions: sessions, sessionFiles: sessionFiles)
        let taskCount = localTaskCount(sessions: sessions)
        let modelSettings = CodexConfigStore.read()

        return CodexSnapshot(
            projectCount: projects.count,
            activeCount: activeCount,
            chatCount: sessionFiles.count,
            taskCount: taskCount,
            headline: headline,
            latestChat: latestChat,
            usage: usage,
            modelSettings: modelSettings,
            projects: projects,
            sessions: sessions
        )
    }

    private static func configuredProjectsRoot() -> URL {
        let path = WidgetDefaults.string(
            key: "projectsRoot",
            widgetId: "codex-project-tracker",
            default: defaultProjectsRoot.path
        )

        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }

    private static func recentLimit() -> Int {
        max(3, min(10, Int(WidgetDefaults.double(
            key: "recentLimit",
            widgetId: "codex-project-tracker",
            default: 5
        ))))
    }

    private static func usageBudgetTokens() -> Int64 {
        let millions = WidgetDefaults.double(
            key: "usageBudgetMillions",
            widgetId: "codex-project-tracker",
            default: 200
        )
        return Int64(max(1, millions) * 1_000_000)
    }

    private static func usageWindowHours() -> Double {
        max(1, min(24, WidgetDefaults.double(
            key: "usageWindowHours",
            widgetId: "codex-project-tracker",
            default: 5
        )))
    }

    private static func recentProjects(from sessions: [CodexSessionRecord]) -> [CodexProject] {
        var projectsByPath: [String: CodexProject] = [:]

        for session in sessions {
            let projectURL = URL(fileURLWithPath: session.metadata.cwd).standardizedFileURL
            let path = projectURL.path
            let modified = session.metadata.timestamp ?? session.file.modified
            let existing = projectsByPath[path]

            if existing == nil || modified > existing!.modified {
                projectsByPath[path] = CodexProject(
                    id: path,
                    name: projectURL.lastPathComponent.isEmpty ? path : projectURL.lastPathComponent,
                    url: projectURL,
                    modified: modified,
                    isActive: Date().timeIntervalSince(modified) < 60 * 60 * 24 * 7
                )
            }
        }

        return projectsByPath.values
            .sorted { $0.modified > $1.modified }
            .prefix(recentLimit())
            .map { $0 }
    }

    private static func recentSessions(from sessionRecords: [CodexSessionRecord]) -> [CodexSession] {
        var sessions: [CodexSession] = []

        for record in sessionRecords {
            let projectURL = URL(fileURLWithPath: record.metadata.cwd).standardizedFileURL
            let modified = record.metadata.timestamp ?? record.file.modified
            let projectName = projectURL.lastPathComponent.isEmpty ? projectURL.path : projectURL.lastPathComponent

            sessions.append(CodexSession(
                id: record.metadata.id ?? record.file.url.path,
                url: record.file.url,
                projectName: projectName,
                projectURL: projectURL,
                modified: modified,
                title: sessionTitle(from: record.file.url),
                isActive: Date().timeIntervalSince(modified) < 60 * 60 * 24 * 7
            ))

            if sessions.count >= recentLimit() {
                break
            }
        }

        return sessions
    }

    private static func sessionFiles(in root: URL) -> [CodexSessionFile] {
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return enumerator.compactMap { item -> CodexSessionFile? in
            guard let url = item as? URL, url.pathExtension == "jsonl" else { return nil }
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return CodexSessionFile(url: url, modified: values?.contentModificationDate ?? .distantPast)
        }
        .sorted { $0.modified > $1.modified }
    }

    private static func sessionMetadata(from url: URL) -> CodexSessionMetadata? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 64 * 1024),
              let prefix = String(data: data, encoding: .utf8)
        else { return nil }

        let decoder = JSONDecoder()

        for line in prefix.split(separator: "\n").prefix(20) {
            guard let lineData = String(line).data(using: .utf8),
                  let envelope = try? decoder.decode(CodexSessionEnvelope.self, from: lineData),
                  envelope.type == "session_meta",
                  let cwd = envelope.payload.cwd,
                  !cwd.isEmpty
            else { continue }

            return CodexSessionMetadata(
                id: envelope.payload.id,
                cwd: cwd,
                timestamp: parseCodexDate(envelope.payload.timestamp ?? envelope.timestamp)
            )
        }

        return nil
    }

    private static func sessionTitle(from url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        guard let data = try? handle.read(upToCount: 256 * 1024),
              let prefix = String(data: data, encoding: .utf8)
        else { return nil }

        let decoder = JSONDecoder()

        for line in prefix.split(separator: "\n").prefix(80) {
            guard let lineData = String(line).data(using: .utf8),
                  let envelope = try? decoder.decode(CodexEventEnvelope.self, from: lineData),
                  envelope.type == "event_msg",
                  envelope.payload.type == "user_message"
            else { continue }

            let title = (envelope.payload.message ?? envelope.payload.text ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")

            if !title.isEmpty {
                return title.count > 96 ? String(title.prefix(96)) + "..." : title
            }
        }

        return nil
    }

    private static func latestHistoryPrompt() -> String? {
        let historyURL = codexHome.appendingPathComponent("history.jsonl")
        guard let handle = try? FileHandle(forReadingFrom: historyURL) else { return nil }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readSize: UInt64 = min(fileSize, 256 * 1024)
        try? handle.seek(toOffset: fileSize - readSize)

        guard let data = try? handle.read(upToCount: Int(readSize)),
              let text = String(data: data, encoding: .utf8)
        else { return nil }

        let decoder = JSONDecoder()

        for line in text.split(separator: "\n").reversed() {
            guard let data = String(line).data(using: .utf8),
                  let entry = try? decoder.decode(CodexHistoryEntry.self, from: data)
            else { continue }

            let prompt = entry.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !prompt.isEmpty {
                return prompt.count > 160 ? String(prompt.prefix(160)) + "..." : prompt
            }
        }

        return nil
    }

    private static func usageSnapshot(
        projects: [CodexProject],
        sessions: [CodexSession],
        sessionFiles: [CodexSessionFile]
    ) -> CodexUsageSnapshot {
        // The account snapshot represents the active subscription and wins over
        // session telemetry, which may belong to an older plan or reset window.
        if let external = externalUsageSnapshot() {
            return external
        }

        if let live = liveRateLimitSnapshot(from: sessionFiles) {
            return live
        }

        let budget = usageBudgetTokens()
        let windowHours = usageWindowHours()
        let now = Date()
        let windowStart = now.addingTimeInterval(-windowHours * 3600)
        let todayStart = Calendar.current.startOfDay(for: now)
        let window = sqliteUsage(since: windowStart)
        let today = sqliteUsage(since: todayStart)
        let used = max(window.tokens, 0)
        let remaining = max(0, budget - used)
        let percentRemaining = budget > 0 ? Double(remaining) / Double(budget) : 1
        let resetDate = windowStart.addingTimeInterval(windowHours * 3600 * 2)
        let activeProject = projects.first?.name ?? sessions.first?.projectName ?? "No active project"

        return CodexUsageSnapshot(
            percentRemaining: percentRemaining,
            primaryTitle: "\(Int((percentRemaining * 100).rounded()))% Remaining",
            primarySubtitle: "\(CodexUsageSnapshot.compactTokens(used)) used in \(Int(windowHours))h window",
            windowUsedTokens: used,
            todayUsedTokens: today.tokens,
            budgetTokens: budget,
            resetDate: resetDate,
            resetLabel: nil,
            source: "Local Codex activity",
            metrics: [
                CodexUsageMetric(
                    title: "Window budget",
                    value: "\(CodexUsageSnapshot.compactTokens(remaining)) left",
                    systemImage: "gauge.with.dots.needle.67percent",
                    tint: usageTint(percentRemaining)
                ),
                CodexUsageMetric(
                    title: "Today used",
                    value: CodexUsageSnapshot.compactTokens(today.tokens),
                    systemImage: "calendar",
                    tint: .blue
                ),
                CodexUsageMetric(
                    title: "Window threads",
                    value: "\(window.threadCount)",
                    systemImage: "bubble.left.and.text.bubble.right.fill",
                    tint: .purple
                ),
                CodexUsageMetric(
                    title: "Active project",
                    value: activeProject,
                    systemImage: "folder.fill",
                    tint: .orange
                ),
            ],
            accountCards: []
        )
    }

    private static func localTaskCount(sessions: [CodexSession]) -> Int {
        let taskRoots = [
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support/com.openai.chat"),
            codexHome.appendingPathComponent("automations"),
        ]

        let fileCount = taskRoots.reduce(0) { total, root in
            guard let children = try? FileManager.default.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return total }

            return total + children.filter { $0.lastPathComponent.localizedCaseInsensitiveContains("task") }.count
        }

        let delegatedThreads = sessions.filter {
            ($0.title ?? "").localizedCaseInsensitiveContains("delegation") ||
            $0.projectName.localizedCaseInsensitiveContains("codex")
        }.count

        return max(fileCount, delegatedThreads)
    }

    private static func sqliteUsage(since _: Date) -> CodexSQLiteUsage {
        CodexSQLiteUsage(tokens: 0, threadCount: 0)
    }

    private static func liveRateLimitSnapshot(from sessionFiles: [CodexSessionFile]) -> CodexUsageSnapshot? {
        let decoder = JSONDecoder()
        var latestByID: [String: CodexLiveRateLimitSample] = [:]

        for file in sessionFiles.prefix(24) {
            guard let text = tailText(from: file.url, maximumBytes: 96 * 1024) else { continue }

            for line in text.split(separator: "\n").reversed() {
                guard let data = String(line).data(using: .utf8),
                      let envelope = try? decoder.decode(CodexRateLimitEnvelope.self, from: data),
                      envelope.type == "event_msg",
                      envelope.payload.type == "token_count",
                      let limits = envelope.payload.rateLimits,
                      let primary = limits.primary
                else { continue }

                let id = limits.limitID ?? limits.limitName ?? "codex"
                let timestamp = parseCodexDate(envelope.timestamp) ?? file.modified
                if let existing = latestByID[id], existing.timestamp >= timestamp {
                    continue
                }

                latestByID[id] = CodexLiveRateLimitSample(
                    id: id,
                    name: limits.limitName,
                    usedPercent: primary.usedPercent,
                    windowMinutes: primary.windowMinutes,
                    resetsAt: primary.resetsAt,
                    creditsBalance: limits.credits?.balance,
                    unlimitedCredits: limits.credits?.unlimited ?? false,
                    timestamp: timestamp
                )
            }

            let hasGeneral = latestByID.values.contains(where: \.isGeneral)
            let hasNamedLimit = latestByID.values.contains { !$0.isGeneral }
            if hasGeneral && hasNamedLimit {
                break
            }
        }

        guard !latestByID.isEmpty else { return nil }

        let now = Date()
        let samples = latestByID.values.sorted { lhs, rhs in
            if lhs.isGeneral != rhs.isGeneral { return lhs.isGeneral }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        guard let primarySample = samples.first else { return nil }

        let liveLimits = samples.map { sample -> CodexResolvedRateLimit in
            let resolved = resolvedRateLimit(sample, now: now)
            return CodexResolvedRateLimit(
                name: sample.displayName,
                percentRemaining: resolved.percentRemaining,
                resetDate: resolved.resetDate,
                resetLabel: resolved.resetDate.map(shortResetLabel)
            )
        }
        guard let primaryLimit = liveLimits.first else { return nil }

        let creditsSample = samples.first { $0.unlimitedCredits || $0.creditsBalance != nil } ?? primarySample
        let creditsValue: String? = if creditsSample.unlimitedCredits {
            "Unlimited"
        } else if let balance = creditsSample.creditsBalance {
            balance.hasPrefix("$") ? balance : "$\(balance)"
        } else {
            nil
        }

        var metrics = liveLimits.map { limit in
            CodexUsageMetric(
                title: limit.name,
                value: "\(Int((limit.percentRemaining * 100).rounded()))% left",
                systemImage: limit.name.localizedCaseInsensitiveContains("spark") ? "sparkles" : "gauge.with.dots.needle.67percent",
                tint: usageTint(limit.percentRemaining)
            )
        }
        if let creditsValue {
            metrics.insert(CodexUsageMetric(
                title: "Credits",
                value: creditsValue,
                systemImage: "creditcard.fill",
                tint: .blue
            ), at: 0)
        }

        var cards = liveLimits.map { limit in
            CodexDockCard(
                title: "\(Int((limit.percentRemaining * 100).rounded()))% Left",
                subtitle: "\(shortUsageLabel(for: limit.name)) • \(limit.resetLabel.map { "Resets \($0)" } ?? "Weekly usage")",
                shortLabel: shortUsageLabel(for: limit.name),
                percentRemaining: limit.percentRemaining
            )
        }
        if let creditsValue {
            cards.append(CodexDockCard(
                title: "\(creditsValue) Credits",
                subtitle: "Current balance",
                shortLabel: "Credits"
            ))
        }

        return CodexUsageSnapshot(
            percentRemaining: primaryLimit.percentRemaining,
            primaryTitle: "\(Int((primaryLimit.percentRemaining * 100).rounded()))% Left",
            primarySubtitle: "\(primaryLimit.name) • \(primaryLimit.resetLabel.map { "Resets \($0)" } ?? "Weekly usage")",
            windowUsedTokens: 0,
            todayUsedTokens: 0,
            budgetTokens: 0,
            resetDate: primaryLimit.resetDate,
            resetLabel: primaryLimit.resetLabel,
            source: "Live Codex rate limits",
            metrics: metrics,
            accountCards: cards
        )
    }

    private static func tailText(from url: URL, maximumBytes: UInt64) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        let readSize = min(fileSize, maximumBytes)
        try? handle.seek(toOffset: fileSize - readSize)

        guard let data = try? handle.read(upToCount: Int(readSize)) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func resolvedRateLimit(
        _ sample: CodexLiveRateLimitSample,
        now: Date
    ) -> (percentRemaining: Double, resetDate: Date?) {
        var resetDate = sample.resetsAt.map { Date(timeIntervalSince1970: $0) }
        var remaining = min(max(1 - sample.usedPercent / 100, 0), 1)

        if let originalReset = resetDate, originalReset <= now {
            remaining = 1
            if let windowMinutes = sample.windowMinutes, windowMinutes > 0 {
                let interval = TimeInterval(windowMinutes * 60)
                let elapsedWindows = floor(now.timeIntervalSince(originalReset) / interval) + 1
                resetDate = originalReset.addingTimeInterval(elapsedWindows * interval)
            }
        }

        return (remaining, resetDate)
    }

    private static func shortResetLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    private static func externalUsageSnapshot() -> CodexUsageSnapshot? {
        let configuredPath = WidgetDefaults.string(
            key: "usageStatePath",
            widgetId: "codex-project-tracker",
            default: "~/.codex/usage.json"
        )
        let url = URL(fileURLWithPath: NSString(string: configuredPath).expandingTildeInPath)
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(CodexExternalUsageState.self, from: data)
        else { return nil }

        let primaryLimit = state.limits?.first
        let percentRemaining: Double
        if let remaining = primaryLimit?.percentRemaining ?? primaryLimit?.remainingPercent ?? state.percentRemaining ?? state.remainingPercent {
            percentRemaining = remaining > 1 ? remaining / 100 : remaining
        } else if let used = primaryLimit?.percentUsed ?? primaryLimit?.usedPercent ?? state.percentUsed ?? state.usedPercent {
            percentRemaining = 1 - (used > 1 ? used / 100 : used)
        } else if let remaining = primaryLimit?.remaining ?? state.remaining, let limit = primaryLimit?.limit ?? state.limit, limit > 0 {
            percentRemaining = Double(remaining) / Double(limit)
        } else {
            percentRemaining = 1
        }

        let resetDate = parseCodexDate(primaryLimit?.resetAt ?? state.resetAt)
        let resetLabel = primaryLimit?.resetLabel ?? state.resetLabel
        let used = primaryLimit?.used ?? state.used ?? 0
        let limit = primaryLimit?.limit ?? state.limit ?? 0
        let primaryName = primaryLimit?.name ?? state.title ?? "Weekly usage"
        let primaryReset = resetLabel.map { "Resets \($0)" } ?? "Account usage limit"
        let accountMetrics = externalMetrics(from: state, primaryPercent: percentRemaining)
        let accountCards = externalDockCards(from: state, primaryPercent: percentRemaining)

        return CodexUsageSnapshot(
            percentRemaining: min(max(percentRemaining, 0), 1),
            primaryTitle: "\(Int((percentRemaining * 100).rounded()))% Left",
            primarySubtitle: state.subtitle ?? "\(primaryName) • \(primaryReset)",
            windowUsedTokens: used,
            todayUsedTokens: state.todayUsed ?? used,
            budgetTokens: limit,
            resetDate: resetDate,
            resetLabel: resetLabel,
            source: state.source ?? "Codex account limits",
            metrics: accountMetrics,
            accountCards: accountCards
        )
    }

    private static func externalMetrics(from state: CodexExternalUsageState, primaryPercent: Double) -> [CodexUsageMetric] {
        var metrics = (state.limits ?? []).map { limit in
            let percent = normalizedPercent(for: limit) ?? primaryPercent
            return CodexUsageMetric(
                title: limit.name,
                value: "\(Int((percent * 100).rounded()))% left",
                systemImage: limit.systemImage ?? "gauge.with.dots.needle.67percent",
                tint: usageTint(percent)
            )
        }

        if let credits = state.creditsBalance {
            metrics.insert(CodexUsageMetric(
                title: "Credits",
                value: credits,
                systemImage: "creditcard.fill",
                tint: .blue
            ), at: 0)
        }

        if metrics.isEmpty {
            metrics = [
                CodexUsageMetric(title: "Remaining", value: "\(Int((primaryPercent * 100).rounded()))% left", systemImage: "battery.75percent", tint: usageTint(primaryPercent)),
            ]
        }

        return metrics
    }

    private static func externalDockCards(from state: CodexExternalUsageState, primaryPercent: Double) -> [CodexDockCard] {
        var cards = (state.limits ?? []).map { limit in
            let percent = normalizedPercent(for: limit) ?? primaryPercent
            let reset = limit.resetLabel.map { "Resets \($0)" } ?? limit.subtitle ?? "Weekly usage limit"
            return CodexDockCard(
                title: "\(Int((percent * 100).rounded()))% Left",
                subtitle: "\(shortUsageLabel(for: limit.name)) • \(reset)",
                shortLabel: shortUsageLabel(for: limit.name),
                percentRemaining: percent
            )
        }

        if let credits = state.creditsBalance {
            cards.append(CodexDockCard(
                title: "\(credits) Credits",
                subtitle: "Current balance",
                shortLabel: "Credits"
            ))
        }

        return cards
    }

    private static func normalizedPercent(for limit: CodexExternalUsageLimit) -> Double? {
        if let remaining = limit.percentRemaining ?? limit.remainingPercent {
            return min(max(remaining > 1 ? remaining / 100 : remaining, 0), 1)
        }
        if let used = limit.percentUsed ?? limit.usedPercent {
            return min(max(1 - (used > 1 ? used / 100 : used), 0), 1)
        }
        if let remaining = limit.remaining, let cap = limit.limit, cap > 0 {
            return min(max(Double(remaining) / Double(cap), 0), 1)
        }
        return nil
    }

    private static func shortUsageLabel(for name: String) -> String {
        if name.localizedCaseInsensitiveContains("spark") {
            return "Spark"
        }
        if name.localizedCaseInsensitiveContains("general") {
            return "General"
        }
        return "Limit"
    }

    private static func usageTint(_ percentRemaining: Double) -> Color {
        switch percentRemaining {
        case 0.45...: return Color(red: 0.13, green: 0.72, blue: 1.00)
        case 0.20..<0.45: return .orange
        default: return .red
        }
    }

    private static func parseCodexDate(_ value: String?) -> Date? {
        guard let value else { return nil }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        return ISO8601DateFormatter().date(from: value)
    }
}

private struct CodexSessionFile {
    let url: URL
    let modified: Date
}

private struct CodexSessionRecord {
    let file: CodexSessionFile
    let metadata: CodexSessionMetadata
}

private struct CodexSQLiteUsage {
    let tokens: Int64
    let threadCount: Int
}

private struct CodexSessionMetadata {
    let id: String?
    let cwd: String
    let timestamp: Date?
}

private struct CodexSessionEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let id: String?
        let timestamp: String?
        let cwd: String?
    }
}

private struct CodexEventEnvelope: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let message: String?
        let text: String?
    }
}

private struct CodexHistoryEntry: Decodable {
    let text: String
}

private struct CodexExternalUsageState: Decodable {
    let title: String?
    let subtitle: String?
    let source: String?
    let creditsBalance: String?
    let used: Int64?
    let remaining: Int64?
    let limit: Int64?
    let todayUsed: Int64?
    let resetAt: String?
    let resetLabel: String?
    let percentRemaining: Double?
    let remainingPercent: Double?
    let percentUsed: Double?
    let usedPercent: Double?
    let limits: [CodexExternalUsageLimit]?
}

private struct CodexExternalUsageLimit: Decodable {
    let name: String
    let subtitle: String?
    let systemImage: String?
    let used: Int64?
    let remaining: Int64?
    let limit: Int64?
    let resetAt: String?
    let resetLabel: String?
    let percentRemaining: Double?
    let remainingPercent: Double?
    let percentUsed: Double?
    let usedPercent: Double?
}

private struct CodexRateLimitEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let rateLimits: CodexRateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case rateLimits = "rate_limits"
        }
    }
}

private struct CodexRateLimits: Decodable {
    let limitID: String?
    let limitName: String?
    let primary: Window?
    let credits: Credits?

    struct Window: Decodable {
        let usedPercent: Double
        let windowMinutes: Int?
        let resetsAt: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }
    }

    struct Credits: Decodable {
        let balance: String?
        let unlimited: Bool?
    }

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case limitName = "limit_name"
        case primary
        case credits
    }
}

private struct CodexLiveRateLimitSample {
    let id: String
    let name: String?
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: TimeInterval?
    let creditsBalance: String?
    let unlimitedCredits: Bool
    let timestamp: Date

    var isGeneral: Bool {
        id == "codex" || name == nil
    }

    var displayName: String {
        name ?? "General"
    }
}

private struct CodexResolvedRateLimit {
    let name: String
    let percentRemaining: Double
    let resetDate: Date?
    let resetLabel: String?
}
