import Foundation
import SwiftUI

struct CodexV6CardShell<Content: View>: View {
    let card: CodexV6CardID
    let isEditing: Bool
    let density: CodexV6CardDensity
    let showsHeader: Bool
    let onOpenDetails: () -> Void
    let onMoveToPage: (CodexV6Page) -> Void
    private let content: Content
    @Environment(\.codexTheme) private var theme
    @State private var isHovering = false

    init(
        card: CodexV6CardID,
        isEditing: Bool,
        density: CodexV6CardDensity = .standard,
        showsHeader: Bool = true,
        onOpenDetails: @escaping () -> Void = {},
        onMoveToPage: @escaping (CodexV6Page) -> Void = { _ in },
        @ViewBuilder content: () -> Content
    ) {
        self.card = card
        self.isEditing = isEditing
        self.density = density
        self.showsHeader = showsHeader
        self.onOpenDetails = onOpenDetails
        self.onMoveToPage = onMoveToPage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: showsHeader ? 9 : 0) {
            if showsHeader {
                HStack(spacing: 6) {
                    Image(systemName: card.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.accent)
                    Text(card.title)
                        .font(card.isHero ? Font.subheadline.weight(.bold) : Font.caption.weight(.bold))
                    Spacer(minLength: 0)
                    if !isEditing {
                        Button(action: onOpenDetails) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(isHovering ? theme.accent : .secondary)
                                .frame(width: 18, height: 18)
                        }
                        .buttonStyle(.plain)
                        .help("Open \(card.title) details")
                        .accessibilityLabel("Open \(card.title) details")
                    }
                    if isEditing {
                        Image(systemName: "line.3.horizontal")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent)
                            .accessibilityHidden(true)
                    }
                }
            }
            content
        }
        .padding(card == .quota ? 4 : density.cardPadding)
        .background {
            if card != .quota {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(card == .modelControls ? 0.10 : 0.035))
            }
        }
        .overlay {
            if card != .quota || isEditing {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isEditing ? theme.accent.opacity(0.6) : .white.opacity(0.10), lineWidth: 0.8)
            }
        }
        .modifier(CodexV6WiggleModifier(isActive: isEditing, seed: wiggleSeed))
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Open \(card.title) details", action: onOpenDetails)
            Menu("Move to page") {
                ForEach(CodexV6Page.allCases) { page in
                    Button(page.title) { onMoveToPage(page) }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(card.title)
        .accessibilityHint("Use the info button to open details")
    }

    private var wiggleSeed: Double {
        Double(card.rawValue.utf8.reduce(0) { ($0 * 17 + Int($1)) % 31 })
    }
}

struct CodexV6WiggleModifier: ViewModifier {
    let isActive: Bool
    let seed: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    func body(content: Content) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0,
                                paused: reduceMotion || !tuning.animationsEnabled || !isActive)) { timeline in
            let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let rotation = isActive && !reduceMotion && tuning.animationsEnabled ? sin(time * 7.0 + seed) * 1.25 : 0
            let xOffset = isActive && !reduceMotion && tuning.animationsEnabled ? sin(time * 7.0 + seed) * 0.35 : 0
            content
                .rotationEffect(.degrees(rotation))
                .offset(x: xOffset)
        }
    }
}

struct CodexV6QuotaCard: View {
    let usage: CodexUsageSnapshot
    let analytics: CodexV6AnalyticsSnapshot
    let now: Date
    let taskCount: Int
    let chatCount: Int
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Circle()
                    .fill(usage.isStale ? theme.dataColor(1) : theme.dataColor(2))
                    .frame(width: 6, height: 6)
                Text(usage.statusLabel(now: now))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 2)

            HStack(spacing: 12) {
                CodexV6ProgressRing(value: usage.percentRemaining, theme: theme, size: 68)
                VStack(alignment: .leading, spacing: 3) {
                    Text(usage.primaryTitle)
                        .font(.title3.weight(.bold))
                    Text(usage.primarySubtitle)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(usage.resetSummary(now: now))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    if let change = analytics.todayVsPreviousDay {
                        CodexV6TrendBadge(change: change, label: "vs yesterday")
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(0.18), lineWidth: 0.8))

            HStack(spacing: 7) {
                CodexV6Metric(value: usage.windowUsedLabel, label: "Window", tint: theme.dataColor(0), treatment: .soft)
                CodexV6Metric(value: usage.todayUsedLabel, label: "Today", tint: theme.dataColor(1), treatment: .soft)
                CodexV6Metric(value: "\(taskCount)", label: "Tasks", tint: theme.dataColor(2), treatment: .soft)
                CodexV6Metric(value: "\(chatCount)", label: "Chats", tint: theme.dataColor(3), treatment: .soft)
            }
            .padding(.vertical, 1)

            if !usage.metrics.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    Text("Usage limits")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 2)
                    ForEach(usage.metrics) { metric in
                        HStack(spacing: 6) {
                            Image(systemName: metric.systemImage)
                                .foregroundStyle(theme.accent)
                                .frame(width: 14)
                            Text(metric.title)
                                .font(.caption2.weight(.medium))
                            Spacer(minLength: 4)
                            Text(metric.value)
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }


        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((usage.percentRemaining * 100).rounded())) percent remaining, \(usage.resetSummary(now: now))")
    }
}

struct CodexV6PaceCard: View {
    let pace: CodexV6QuotaPace?
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let pace {
                HStack(spacing: 10) {
                    CodexV6Metric(value: pace.percentPerHour.map { String(format: "%.1f%%", $0) } ?? "—",
                                  label: "used / hour", tint: theme.dataColor(0))
                    CodexV6Metric(value: projectedLabel(pace), label: "exhaustion", tint: theme.dataColor(1))
                    CodexV6Metric(value: pace.sampleCount > 1 ? "\(pace.sampleCount)" : "1", label: "samples", tint: theme.dataColor(2))
                }
                Text(pace.willLastToReset == nil ? "Building a personal pace baseline" :
                        (pace.willLastToReset == true ? "At this pace, quota lasts to reset" : "At this pace, quota may run out first"))
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(pace.willLastToReset == false ? theme.dataColor(1) : .secondary)
            } else {
                Label("Collecting quota pace history", systemImage: "clock.arrow.2.circlepath")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("The widget records bounded local points as the account snapshot refreshes.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text("Current usage: \(Int(((1 - usage.percentRemaining) * 100).rounded()))% used")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
    }

    private func projectedLabel(_ pace: CodexV6QuotaPace) -> String {
        guard let date = pace.projectedExhaustionAt else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: now)
    }
}

struct CodexV6BurnCard: View {
    let telemetry: CodexTokenTelemetry
    let analytics: CodexV6AnalyticsSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                CodexV6Metric(value: CodexTokenUsage.rateLabel(analytics.burnPerMinute), label: "burn rate", tint: theme.dataColor(1))
                CodexV6Metric(value: CodexTokenUsage.compactLabel(analytics.todayTokens), label: "today", tint: theme.dataColor(0))
                CodexV6Metric(value: CodexTokenUsage.compactLabel(analytics.last7DaysTokens), label: "7 days", tint: theme.dataColor(2))
            }
            // The interactive chart reserves a hover-callout slot above its
            // plot. Keep that slot in the layout so the freshness row cannot
            // overlap the bottom of the bars.
            CodexV6MiniBarChart(values: telemetry.samples.suffix(24).map { Double($0.usage.effectiveTotalTokens) }, theme: theme)
            HStack(spacing: 5) {
                Image(systemName: "bolt.fill").foregroundStyle(theme.dataColor(2))
                Text(telemetry.hasData ? telemetry.freshnessLabel(now: now) : "Waiting for local token events")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let latest = telemetry.latestDelta {
                    Text("last \(CodexTokenUsage.compactLabel(latest.effectiveTotalTokens))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
            }
            if let change = analytics.todayVsPreviousDay {
                CodexV6TrendBadge(change: change, label: "today vs yesterday")
            }
        }
    }
}

struct CodexV6ContextCard: View {
    let telemetry: CodexTokenTelemetry
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CodexV6LabeledBar(label: "Current context", value: analytics.contextPercent ?? telemetry.contextPercent,
                              valueLabel: percentLabel(analytics.contextPercent ?? telemetry.contextPercent), tint: theme.dataColor(0))
            CodexV6LabeledBar(label: "Peak observed", value: analytics.peakContextPercent,
                              valueLabel: percentLabel(analytics.peakContextPercent), tint: theme.dataColor(1))
            Text("Context is derived from local session token events and never uploaded by this widget.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func percentLabel(_ value: Double?) -> String {
        guard let value else { return "—" }
        return "\(Int((value * 100).rounded()))%"
    }
}

struct CodexV6DailyActivityCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    let window: CodexV6AnalyticsWindow
    @Environment(\.codexTheme) private var theme

    init(analytics: CodexV6AnalyticsSnapshot, window: CodexV6AnalyticsWindow = .sevenDays) {
        self.analytics = analytics
        self.window = window
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CodexV6InteractiveColumnChart(
                data: dailyData,
                theme: theme,
                height: 58,
                showsLabels: true
            )
            HStack {
                Text(CodexTokenUsage.compactLabel(windowTotal))
                    .font(.title3.weight(.bold).monospacedDigit())
                Text("tokens in \(window.title.lowercased())")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func relative(_ value: Int64) -> Double {
        let maximum = max(analytics.daily.map(\.tokens).max() ?? 0, 1)
        return min(max(Double(value) / Double(maximum), 0), 1)
    }

    private var dailyData: [CodexV6ChartDatum] {
        dailyValues.map { day in
            CodexV6ChartDatum(
                id: day.id,
                label: shortDay(day.dayKey),
                value: day.tokens,
                detail: "\(day.eventCount) turns"
            )
        }
    }

    private var dailyValues: [CodexAnalyticsDay] {
        Array(analytics.daily.suffix(window.dayCount))
    }

    private var windowTotal: Int64 {
        dailyValues.reduce(Int64(0)) { $0 + $1.tokens }
    }

    private func shortDay(_ key: String) -> String {
        CodexV6DateFormatting.shortWeekday(forDayKey: key)
    }
}

struct CodexV6HourlyActivityCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    let window: CodexV6AnalyticsWindow
    @Environment(\.codexTheme) private var theme

    init(analytics: CodexV6AnalyticsSnapshot, window: CodexV6AnalyticsWindow = .sevenDays) {
        self.analytics = analytics
        self.window = window
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            CodexV6InteractiveColumnChart(
                data: hourlyData,
                theme: theme,
                height: 48,
                showsLabels: false
            )
            HStack {
                Image(systemName: "clock")
                    .foregroundStyle(theme.accent)
                Text("Recent activity by hour")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(hourlyData.isEmpty ? "No events" : "\(window.title) window")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var hourlyData: [CodexV6ChartDatum] {
        guard !analytics.hourly.isEmpty else {
            return (0..<12).map { bucket in
                CodexV6ChartDatum(id: "hour-\(bucket)", label: String(format: "%02d", bucket * 2), value: 0)
            }
        }
        let grouped = Dictionary(grouping: analytics.hourly, by: { $0.hour / 2 })
        return (0..<12).map { bucket in
            let entries = grouped[bucket, default: []]
            return CodexV6ChartDatum(
                id: "hour-\(bucket)",
                label: String(format: "%02d", bucket * 2),
                value: entries.reduce(Int64(0)) { $0 + $1.tokens },
                detail: "\(entries.reduce(0) { $0 + $1.eventCount }) turns"
            )
        }
    }
}

struct CodexV6CostCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.title2)
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 3) {
                Text(analytics.estimatedCostUSD.map { String(format: "$%.2f", $0) } ?? "—")
                    .font(.title2.weight(.bold).monospacedDigit())
                Text("estimated API-equivalent cost · 30 days")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
                Text("Coverage \(Int((analytics.costCoverage * 100).rounded()))% · model rates are estimates")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct CodexV6ModelMixCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    let modelFilter: String?
    @Environment(\.codexTheme) private var theme

    init(analytics: CodexV6AnalyticsSnapshot, modelFilter: String? = nil) {
        self.analytics = analytics
        self.modelFilter = modelFilter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if filteredModels.isEmpty {
                CodexV6EmptyState(text: "Model mix appears after token events.")
            } else {
                ForEach(filteredModels.prefix(4)) { model in
                    CodexV6BreakdownRow(label: "\(model.modelLabel) · \(model.reasoningLabel)",
                                        value: CodexTokenUsage.compactLabel(model.tokens),
                                        fraction: fraction(model.tokens), tint: theme.dataColor(0))
                }
            }
        }
    }

    private var filteredModels: [CodexAnalyticsModel] {
        guard let modelFilter else { return analytics.models }
        return analytics.models.filter { $0.id == modelFilter }
    }

    private func fraction(_ value: Int64) -> Double {
        let maximum = max(filteredModels.map(\.tokens).max() ?? 0, 1)
        return Double(value) / Double(maximum)
    }

}

struct CodexV6ProjectMixCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if analytics.projects.isEmpty {
                CodexV6EmptyState(text: "Project mix appears after token events.")
            } else {
                ForEach(analytics.projects.prefix(4)) { project in
                    CodexV6BreakdownRow(label: project.name,
                                        value: CodexTokenUsage.compactLabel(project.tokens),
                                        fraction: fraction(project.tokens), tint: theme.accent)
                }
            }
        }
    }

    private func fraction(_ value: Int64) -> Double {
        let maximum = max(analytics.projects.map(\.tokens).max() ?? 0, 1)
        return Double(value) / Double(maximum)
    }
}

struct CodexV6SessionHealthCard: View {
    let telemetry: CodexTokenTelemetry
    let sessions: [CodexSession]
    let taskCount: Int
    let chatCount: Int
    @Environment(\.codexTheme) private var theme

    var body: some View {
        HStack(spacing: 7) {
            CodexV6Metric(value: "\(sessions.count)", label: "sessions", tint: theme.accent)
            CodexV6Metric(value: "\(taskCount)", label: "tasks", tint: theme.dataColor(1))
            CodexV6Metric(value: "\(chatCount)", label: "chats", tint: theme.dataColor(2))
        }
        HStack(spacing: 5) {
            Image(systemName: telemetry.eventCount > 0 ? "checkmark.circle.fill" : "hourglass")
                .foregroundStyle(telemetry.eventCount > 0 ? theme.dataColor(2) : .secondary)
            Text("\(telemetry.eventCount) local token events · \(telemetry.currentModelLabel) active model")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CodexV6RecentChatsCard: View {
    let sessions: [CodexSession]
    let latestChat: String?
    let isPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if sessions.isEmpty {
                CodexV6EmptyState(text: "Recent chats appear as Codex writes local session files.")
            } else {
                ForEach(sessions.prefix(3)) { session in
                    CodexSessionRow(session: session, allowsOpening: !isPreview)
                }
            }
            if let latestChat, sessions.isEmpty {
                Text(latestChat)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }
}

struct CodexV6OfficialActivityCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let official = analytics.officialActivity {
                HStack(spacing: 8) {
                    CodexV6Metric(value: official.lifetimeTokens.map(CodexTokenUsage.compactLabel) ?? "—", label: "lifetime", tint: theme.accent)
                    CodexV6Metric(value: official.peakDailyTokens.map(CodexTokenUsage.compactLabel) ?? "—", label: "peak day", tint: theme.dataColor(1))
                    CodexV6Metric(value: official.currentStreakDays.map(String.init) ?? "—", label: "day streak", tint: theme.dataColor(2))
                }
                Text("Read-only aggregate activity from the configured usage state.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                CodexV6EmptyState(text: "Official lifetime activity is optional and is not exposed in the current local usage file.")
            }
        }
    }
}

struct CodexV6DataHealthCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(analytics.sourceStatuses) { status in
                HStack(spacing: 7) {
                    Circle()
                        .fill(statusColor(status.state))
                        .frame(width: 7, height: 7)
                    Text(status.title)
                        .font(.caption2.weight(.semibold))
                    Spacer(minLength: 4)
                    Text(status.state)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(statusColor(status.state))
                }
                Text(status.detail)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 14)
                    .lineLimit(1)
            }
            Divider().opacity(0.4)
            Text(usage.statusLabel(now: now))
                .font(.caption2)
                .foregroundStyle(theme.accent)
                .lineLimit(1)
        }
    }

    private func statusColor(_ state: String) -> Color {
        switch state {
        case "Ready": return theme.dataColor(2)
        case "Optional": return theme.dataColor(1)
        case "Waiting": return theme.dataColor(0)
        default: return theme.dataColor(3)
        }
    }
}

struct CodexV6Metric: View {
    let value: String
    let label: String
    let tint: Color
    let treatment: CodexV6MetricTreatment
    @Environment(\.codexTheme) private var theme

    init(value: String, label: String, tint: Color, treatment: CodexV6MetricTreatment = .outlined) {
        self.value = value
        self.label = label
        self.tint = tint
        self.treatment = treatment
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background {
            if treatment == .soft {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(.white.opacity(0.09))
            } else {
                CodexThemeMetricSurface(theme: theme, tint: tint, showsOutline: true)
            }
        }
        .help("\(label): \(value)")
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

enum CodexV6MetricTreatment: Equatable {
    case soft
    case outlined
}

private struct CodexV6ProgressRing: View {
    let value: Double
    let theme: CodexTheme
    let size: CGFloat

    var body: some View {
        UsageRingView(percentRemaining: value, size: size, lineWidth: 7, theme: theme)
    }
}

private struct CodexV6LabeledBar: View {
    let label: String
    let value: Double?
    let valueLabel: String
    let tint: Color
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).font(.caption2.weight(.semibold))
                Spacer()
                Text(valueLabel).font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(tint)
            }
            CodexThemeProgressBar(value: value, theme: theme, height: 6, role: 0, tint: tint)
        }
        .help("\(label): \(valueLabel)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(valueLabel)
    }
}

private struct CodexV6BreakdownRow: View {
    let label: String
    let value: String
    let fraction: Double
    let tint: Color
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(label).font(.caption2.weight(.semibold)).lineLimit(1)
                Spacer(minLength: 5)
                Text(value).font(.caption2.monospacedDigit().weight(.bold)).foregroundStyle(.secondary)
            }
            CodexThemeProgressBar(value: fraction, theme: theme, height: 4, role: 0, tint: tint)
        }
        .help("\(label): \(value)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct CodexV6MiniBarChart: View {
    let values: [Double]
    let theme: CodexTheme

    var body: some View {
        CodexV6InteractiveColumnChart(
            data: values.enumerated().map { index, value in
                CodexV6ChartDatum(id: "burn-\(index)", label: "#\(index + 1)", value: Int64(max(0, value)), detail: "recent turn")
            },
            theme: theme,
            height: 38,
            showsLabels: false
        )
    }
}

private struct CodexV6EmptyState: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "hourglass")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
