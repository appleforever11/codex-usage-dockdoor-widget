import Foundation
import SwiftUI

struct CodexV6SessionPulseCard: View {
    let snapshot: CodexSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    private var session: CodexSession? {
        snapshot.panelSessions.first(where: \.isActive) ?? snapshot.panelSessions.first
    }

    var body: some View {
        if let session {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 7) {
                    CodexV6Metric(value: snapshot.tokenTelemetry.currentModelLabel, label: "model", tint: theme.dataColor(0))
                    CodexV6Metric(value: snapshot.tokenTelemetry.currentReasoningLabel, label: "reasoning", tint: theme.dataColor(1))
                    CodexV6Metric(value: session.relativeActivity, label: "last seen", tint: theme.dataColor(2))
                }
                HStack(spacing: 6) {
                    Image(systemName: session.isActive ? "circle.fill" : "circle.dotted")
                        .foregroundStyle(session.isActive ? theme.dataColor(2) : .secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.projectName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(session.title ?? "Local Codex session")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill").foregroundStyle(theme.dataColor(2))
                    Text(snapshot.tokenTelemetry.latestDelta.map { "Last turn \(CodexTokenUsage.compactLabel($0.effectiveTotalTokens))" } ?? "Waiting for the next local turn")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Text(snapshot.tokenTelemetry.freshnessLabel(now: now))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        } else {
            CodexV6InsightEmptyState(text: "Session pulse appears after Codex writes a local session.")
        }
    }
}

struct CodexV6ContextRunwayCard: View {
    let telemetry: CodexTokenTelemetry
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    private var remainingTokens: Int64? {
        guard let usage = telemetry.latestContextUsage,
              let window = telemetry.latestContextWindow,
              window > 0
        else { return nil }
        return max(0, window - usage.effectiveTotalTokens)
    }

    private var runwayMinutes: Double? {
        guard let remainingTokens,
              let burn = analytics.burnPerMinute,
              burn > 0
        else { return nil }
        return Double(remainingTokens) / burn
    }

    var body: some View {
        if let remainingTokens {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    CodexV6Metric(value: CodexTokenUsage.compactLabel(remainingTokens), label: "tokens left", tint: theme.dataColor(0))
                    CodexV6Metric(value: runwayLabel, label: "at current burn", tint: theme.dataColor(1))
                    CodexV6Metric(value: telemetry.contextLabel, label: "in use", tint: theme.dataColor(2))
                }
                CodexV6InsightProgress(value: analytics.contextPercent ?? telemetry.contextPercent,
                                       tint: theme.accent,
                                       label: "Context consumed")
                Text(analytics.peakContextPercent.map { "Peak observed \(Int(($0 * 100).rounded()))% · runway is an estimate from local burn." } ?? "Runway is an estimate from local burn.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else {
            CodexV6InsightEmptyState(text: "Context runway appears when a model context window is reported locally.")
        }
    }

    private var runwayLabel: String {
        guard let runwayMinutes else { return "—" }
        if runwayMinutes < 60 {
            return "\(Int(runwayMinutes.rounded()))m"
        }
        return "\(Int((runwayMinutes / 60).rounded()))h"
    }
}

struct CodexV6EfficiencyCard: View {
    let telemetry: CodexTokenTelemetry
    @Environment(\.codexTheme) private var theme

    private var usage: CodexTokenUsage {
        telemetry.todayUsage.hasUsage ? telemetry.todayUsage : telemetry.observedUsage
    }

    private var cacheShare: Double? {
        guard usage.inputTokens > 0 else { return nil }
        return min(max(Double(usage.cachedInputTokens) / Double(usage.inputTokens), 0), 1)
    }

    var body: some View {
        if usage.hasUsage {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    CodexV6Metric(value: cacheShare.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "cache share", tint: theme.dataColor(0))
                    CodexV6Metric(value: tokensPerTurn, label: "tokens / turn", tint: theme.dataColor(1))
                    CodexV6Metric(value: CodexTokenUsage.compactLabel(usage.outputTokens), label: "output", tint: theme.dataColor(2))
                }
                CodexV6InsightProgress(value: cacheShare, tint: theme.accent, label: "Cached input")
                Text("Input \(CodexTokenUsage.compactLabel(usage.inputTokens)) · cached \(CodexTokenUsage.compactLabel(usage.cachedInputTokens)) · reasoning \(CodexTokenUsage.compactLabel(usage.reasoningOutputTokens))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            CodexV6InsightEmptyState(text: "Efficiency appears after local token events are attributed.")
        }
    }

    private var tokensPerTurn: String {
        guard telemetry.eventCount > 0 else { return "—" }
        return CodexTokenUsage.compactLabel(usage.effectiveTotalTokens / Int64(telemetry.eventCount))
    }
}

struct CodexV6QuotaBudgetCard: View {
    let pace: CodexV6QuotaPace?
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    private var hoursToReset: Double? {
        guard let reset = pace?.resetAt ?? usage.resetDate else { return nil }
        return max(0, reset.timeIntervalSince(now) / 3600)
    }

    private var safePace: Double? {
        guard let hoursToReset, hoursToReset > 0 else { return nil }
        return max(0, usage.percentRemaining * 100 / hoursToReset)
    }

    var body: some View {
        if let pace, let safePace {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    CodexV6Metric(value: String(format: "%.1f%%", safePace), label: "safe / hour", tint: theme.dataColor(0))
                    CodexV6Metric(value: pace.percentPerHour.map { String(format: "%.1f%%", $0) } ?? "—", label: "actual / hour", tint: theme.dataColor(1))
                    CodexV6Metric(value: resetLabel, label: "until reset", tint: theme.dataColor(2))
                }
                CodexV6InsightProgress(value: safePace > 0 ? (pace.percentPerHour ?? 0) / safePace : nil,
                                       tint: pace.willLastToReset == false ? theme.dataColor(1) : theme.dataColor(0),
                                       label: "Actual pace vs safe budget")
                Text(pace.willLastToReset == false ? "Current burn may exhaust the quota before reset." : "Current burn is within the pace needed to reach reset.")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(pace.willLastToReset == false ? theme.dataColor(1) : .secondary)
            }
        } else {
            CodexV6InsightEmptyState(text: "Quota budget appears after two account snapshots establish a pace.")
        }
    }

    private var resetLabel: String {
        guard let hoursToReset else { return "—" }
        if hoursToReset < 1 {
            return "\(Int((hoursToReset * 60).rounded()))m"
        }
        return "\(Int(hoursToReset.rounded()))h"
    }
}

struct CodexV6ReliabilityCard: View {
    let telemetry: CodexTokenTelemetry
    let analytics: CodexV6AnalyticsSnapshot
    let usage: CodexUsageSnapshot
    let now: Date
    @Environment(\.codexTheme) private var theme

    private var readySourceCount: Int {
        analytics.sourceStatuses.filter { $0.state == "Ready" }.count
    }

    private var attributionPercent: Double? {
        guard telemetry.eventCount > 0 else { return nil }
        return Double(telemetry.attributedEventCount) / Double(telemetry.eventCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                CodexV6Metric(value: attributionPercent.map { "\(Int(($0 * 100).rounded()))%" } ?? "—", label: "attributed", tint: theme.dataColor(0))
                CodexV6Metric(value: "\(readySourceCount)/\(analytics.sourceStatuses.count)", label: "sources ready", tint: theme.dataColor(2))
                CodexV6Metric(value: "\(analytics.cachedEventCount)", label: "cached events", tint: theme.dataColor(1))
            }
            HStack(spacing: 5) {
                Image(systemName: usage.isStale ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                    .foregroundStyle(usage.isStale ? theme.dataColor(1) : theme.dataColor(2))
                Text(usage.warning ?? "Local telemetry and account data are current.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Text("Last account update: \(usage.lastUpdated.map { relativeDate($0, now: now) } ?? "unknown")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

struct CodexV6ProjectHeatmapCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    var body: some View {
        if analytics.projects.isEmpty {
            CodexV6InsightEmptyState(text: "Project heatmap appears after local sessions are indexed.")
        } else {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(analytics.projects.prefix(4)) { project in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(project.name)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(CodexTokenUsage.compactLabel(project.tokens))
                                .font(.caption.monospacedDigit().weight(.bold))
                            Spacer(minLength: 0)
                            Text("\(project.sessionCount) sessions")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                        }
                        Text("\(project.eventCount) local turns")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(7)
                    .background(theme.accent.opacity(tileOpacity(for: project)), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private func tileOpacity(for project: CodexAnalyticsProject) -> Double {
        let maximum = max(analytics.projects.map(\.tokens).max() ?? 0, 1)
        return 0.09 + 0.23 * min(max(Double(project.tokens) / Double(maximum), 0), 1)
    }
}

struct CodexV6TurnTimelineCard: View {
    let telemetry: CodexTokenTelemetry
    @Environment(\.codexTheme) private var theme

    private var samples: [CodexTokenBurnSample] {
        Array(telemetry.samples.suffix(5).reversed())
    }

    var body: some View {
        if samples.isEmpty {
            CodexV6InsightEmptyState(text: "Turn timeline appears after local token events are recorded.")
        } else {
            VStack(alignment: .leading, spacing: 5) {
                ForEach(samples) { sample in
                    HStack(alignment: .top, spacing: 7) {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 6, height: 6)
                            .padding(.top, 4)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 5) {
                                Text(modelLabel(sample.model))
                                    .font(.caption2.weight(.semibold))
                                Text("· \(effortLabel(sample.reasoningEffort))")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 2)
                                Text(CodexTokenUsage.compactLabel(sample.usage.effectiveTotalTokens))
                                    .font(.caption2.monospacedDigit().weight(.bold))
                                    .foregroundStyle(theme.accent)
                            }
                            Text("\(sample.projectName ?? "Unknown project") · \(sample.timestamp, style: .time)")
                                .font(.system(size: 8))
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }
}

struct CodexV6ModelScorecardCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    let modelFilter: String?
    @Environment(\.codexTheme) private var theme

    init(analytics: CodexV6AnalyticsSnapshot, modelFilter: String? = nil) {
        self.analytics = analytics
        self.modelFilter = modelFilter
    }

    var body: some View {
        if filteredModels.isEmpty {
            CodexV6InsightEmptyState(text: "Model scorecard appears after model-attributed token events.")
        } else {
            VStack(alignment: .leading, spacing: 7) {
                ForEach(filteredModels.prefix(4)) { model in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("\(model.modelLabel) · \(model.reasoningLabel)")
                                .font(.caption2.weight(.semibold))
                                .lineLimit(1)
                            Spacer(minLength: 4)
                            Text(CodexTokenUsage.compactLabel(model.tokens))
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(theme.dataColor(0))
                        }
                        HStack(spacing: 6) {
                            Text("\(CodexTokenUsage.compactLabel(tokensPerTurn(model))) / turn")
                            Text(costPerTurn(model))
                            Text("\(model.eventCount) turns")
                            Spacer(minLength: 0)
                        }
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                        CodexV6InsightProgress(value: fraction(model.tokens), tint: theme.dataColor(0), label: "")
                    }
                }
            }
        }
    }

    private func tokensPerTurn(_ model: CodexAnalyticsModel) -> Int64 {
        guard model.eventCount > 0 else { return model.tokens }
        return model.tokens / Int64(model.eventCount)
    }

    private func costPerTurn(_ model: CodexAnalyticsModel) -> String {
        guard let cost = model.estimatedCostUSD, model.eventCount > 0 else { return "cost —" }
        return String(format: "$%.2f / turn", cost / Double(model.eventCount))
    }

    private func fraction(_ value: Int64) -> Double {
        let maximum = max(filteredModels.map(\.tokens).max() ?? 0, 1)
        return Double(value) / Double(maximum)
    }

    private var filteredModels: [CodexAnalyticsModel] {
        guard let modelFilter else { return analytics.models }
        return analytics.models.filter { $0.id == modelFilter }
    }

}

struct CodexV6StreaksGoalsCard: View {
    let analytics: CodexV6AnalyticsSnapshot
    @Environment(\.codexTheme) private var theme

    private var goalProgress: Double? {
        guard analytics.dailyGoalTokens > 0 else { return nil }
        return min(max(Double(analytics.todayTokens) / Double(analytics.dailyGoalTokens), 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                CodexV6Metric(value: analytics.officialActivity?.currentStreakDays.map(String.init) ?? "—", label: "day streak", tint: theme.dataColor(1))
                CodexV6Metric(value: analytics.officialActivity?.longestStreakDays.map(String.init) ?? "—", label: "longest", tint: theme.dataColor(2))
                CodexV6Metric(value: CodexTokenUsage.compactLabel(analytics.last7DaysTokens / 7), label: "7-day avg", tint: theme.dataColor(0))
            }
            CodexV6InsightProgress(value: goalProgress, tint: theme.accent, label: "Daily goal · \(CodexTokenUsage.compactLabel(analytics.dailyGoalTokens))")
            Text("Today \(CodexTokenUsage.compactLabel(analytics.todayTokens)) · goal is local and adjustable in widget settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct CodexV6WorkspaceHealthCard: View {
    let health: CodexV6WorkspaceHealth
    @Environment(\.codexTheme) private var theme

    var body: some View {
        if health.isAvailable {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    CodexV6Metric(value: "\(health.repositoryCount)", label: "repositories", tint: theme.accent)
                    CodexV6Metric(value: "\(health.dirtyRepositoryCount)", label: "dirty repos", tint: health.dirtyRepositoryCount > 0 ? theme.dataColor(1) : theme.dataColor(2))
                    CodexV6Metric(value: "\(health.dirtyFileCount)", label: "dirty files", tint: health.dirtyFileCount > 0 ? theme.dataColor(1) : theme.dataColor(2))
                }
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundStyle(theme.accent)
                    Text(health.activeBranch ?? "Detached or unavailable branch")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                Text("\(health.activeProject ?? "No active project") · read-only local Git status")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        } else {
            CodexV6InsightEmptyState(text: health.checkedProjectCount == 0 ? "No local project paths are available." : "Git status is unavailable for the indexed projects.")
        }
    }
}

private struct CodexV6InsightProgress: View {
    let value: Double?
    let tint: Color
    let label: String
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption2.weight(.semibold))
            }
            CodexThemeProgressBar(value: value, theme: theme, height: 5, role: 0, tint: tint)
        }
    }
}

private struct CodexV6InsightEmptyState: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "hourglass")
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private func modelLabel(_ value: String) -> String {
    let lowercased = value.lowercased()
    if lowercased.contains("astra") { return "Astra" }
    if lowercased.contains("luna") { return "Luna" }
    if lowercased.contains("sol") { return "Sol" }
    if lowercased.contains("terra") { return "Terra" }
    return value.isEmpty ? "Unknown" : value
}

private func effortLabel(_ value: String) -> String {
    if value == "low" || value == "instant" { return "Light" }
    if value == "max" { return "Max" }
    return value.isEmpty ? "Unknown" : value.prefix(1).uppercased() + value.dropFirst()
}

private func relativeDate(_ date: Date, now: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: now)
}
