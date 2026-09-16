import Foundation
import SwiftUI

struct CodexV6CardDetailSheet: View {
    let card: CodexV6CardID
    let snapshot: CodexSnapshot
    let now: Date
    let isPreview: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: card.symbol)
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(card.title)
                        .font(.headline.weight(.bold))
                    Text("Focused detail")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 6)
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(theme.accent)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.bottom, 12)

            Divider().opacity(0.45)

            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(card.detailDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    detailContent
                }
                .padding(.top, 13)
                .padding(.bottom, 8)
            }
        }
        .padding(18)
        .frame(minWidth: 360, idealWidth: 430, maxWidth: 520, minHeight: 360, idealHeight: 540, maxHeight: 720)
        .background(CodexThemeBackground(theme: theme))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(card.title) details")
    }

    @ViewBuilder
    private var detailContent: some View {
        switch card {
        case .quota:
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 8) {
                    CodexV6DetailMetric(value: "\(Int((snapshot.usage.percentRemaining * 100).rounded()))%", label: "remaining", tint: theme.accent)
                    CodexV6DetailMetric(value: snapshot.usage.windowUsedLabel, label: "window used", tint: theme.dataColor(0))
                    CodexV6DetailMetric(value: snapshot.usage.todayUsedLabel, label: "today used", tint: theme.dataColor(1))
                }
                CodexV6DetailRow(label: "Reset", value: snapshot.usage.resetSummary(now: now), tint: theme.accent)
                ForEach(snapshot.usage.metrics) { metric in
                    CodexV6DetailRow(label: metric.title, value: metric.value, tint: theme.dataColor(2))
                }
                CodexV6DetailSource(text: snapshot.usage.statusLabel(now: now), tint: snapshot.usage.statusTint)
            }

        case .dailyActivity, .officialActivity:
            let days = card == .officialActivity ? snapshot.analytics.officialActivity?.daily ?? [] : snapshot.analytics.daily
            if days.isEmpty {
                CodexV6DetailEmpty(text: "No daily activity is available yet.")
            } else {
                ForEach(days) { day in
                    CodexV6DetailRow(
                        label: day.dayKey,
                        value: "\(CodexTokenUsage.compactLabel(day.tokens)) · \(day.eventCount) turns",
                        tint: theme.dataColor(0)
                    )
                }
            }

        case .hourlyActivity:
            let grouped = Dictionary(grouping: snapshot.analytics.hourly, by: { $0.hour / 2 })
            ForEach(0..<12, id: \.self) { bucket in
                let entries = grouped[bucket, default: []]
                CodexV6DetailRow(
                    label: String(format: "%02d:00–%02d:00", bucket * 2, (bucket * 2 + 2) % 24),
                    value: "\(CodexTokenUsage.compactLabel(entries.reduce(Int64(0)) { $0 + $1.tokens })) · \(entries.reduce(0) { $0 + $1.eventCount }) turns",
                    tint: theme.dataColor(bucket)
                )
            }

        case .modelMix, .modelScorecard:
            if snapshot.analytics.models.isEmpty {
                CodexV6DetailEmpty(text: "Model-attributed events will appear here after local sessions are indexed.")
            } else {
                ForEach(snapshot.analytics.models) { model in
                    CodexV6DetailRow(
                        label: "\(model.modelLabel) · \(model.reasoningLabel)",
                        value: "\(CodexTokenUsage.compactLabel(model.tokens)) · \(model.eventCount) turns",
                        tint: theme.dataColor(0)
                    )
                }
            }

        case .projectMix, .projectHeatmap:
            if snapshot.analytics.projects.isEmpty {
                CodexV6DetailEmpty(text: "Project attribution will appear after local sessions are indexed.")
            } else {
                ForEach(snapshot.analytics.projects) { project in
                    CodexV6DetailRow(
                        label: project.name,
                        value: "\(CodexTokenUsage.compactLabel(project.tokens)) · \(project.sessionCount) sessions",
                        tint: theme.dataColor(1)
                    )
                }
            }

        case .dataHealth, .reliability:
            ForEach(snapshot.analytics.sourceStatuses) { status in
                VStack(alignment: .leading, spacing: 3) {
                    CodexV6DetailRow(label: status.title, value: status.state, tint: statusTint(status.state))
                    Text(status.detail)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 10)
                }
            }

        case .workspaceHealth:
            let health = snapshot.analytics.workspaceHealth
            HStack(spacing: 8) {
                CodexV6DetailMetric(value: "\(health.repositoryCount)", label: "repositories", tint: theme.accent)
                CodexV6DetailMetric(value: "\(health.dirtyRepositoryCount)", label: "dirty repos", tint: theme.dataColor(1))
                CodexV6DetailMetric(value: "\(health.dirtyFileCount)", label: "dirty files", tint: theme.dataColor(2))
            }
            CodexV6DetailSource(text: "\(health.activeProject ?? "No active project") · \(health.activeBranch ?? "No branch")", tint: theme.accent)

        case .recentChats:
            if snapshot.panelSessions.isEmpty {
                CodexV6DetailEmpty(text: "Recent sessions appear as Codex writes local session files.")
            } else {
                ForEach(snapshot.panelSessions) { session in
                    CodexSessionRow(session: session, allowsOpening: !isPreview)
                }
            }

        case .cost:
            HStack(spacing: 8) {
                CodexV6DetailMetric(value: snapshot.analytics.estimatedCostUSD.map { String(format: "$%.2f", $0) } ?? "—", label: "30-day estimate", tint: theme.accent)
                CodexV6DetailMetric(value: "\(Int((snapshot.analytics.costCoverage * 100).rounded()))%", label: "coverage", tint: theme.dataColor(1))
            }
            CodexV6DetailSource(text: "Model rates are estimates and local-only.", tint: theme.dataColor(2))

        case .modelControls:
            CodexV6DetailRow(label: "Model", value: snapshot.modelSettings.shortModelName, tint: theme.accent)
            CodexV6DetailRow(label: "Reasoning", value: snapshot.modelSettings.reasoningLabel, tint: theme.dataColor(1))
            CodexV6DetailSource(text: "Use the Overview page controls to change defaults.", tint: theme.dataColor(2))

        default:
            CodexV6DetailMetric(value: detailValue, label: "Current signal", tint: theme.accent)
            CodexV6DetailSource(text: detailSource, tint: theme.dataColor(2))
        }
    }

    private var detailValue: String {
        switch card {
        case .burn: return CodexTokenUsage.rateLabel(snapshot.analytics.burnPerMinute)
        case .context, .contextRunway: return snapshot.tokenTelemetry.contextLabel
        case .efficiency: return CodexTokenUsage.compactLabel(snapshot.tokenTelemetry.todayUsage.effectiveTotalTokens)
        case .sessionHealth, .sessionPulse: return "\(snapshot.panelSessions.count) sessions"
        case .pace, .quotaBudget: return snapshot.analytics.quotaPace?.percentPerHour.map { String(format: "%.1f%% / hour", $0) } ?? "—"
        case .streaksGoals: return CodexTokenUsage.compactLabel(snapshot.analytics.todayTokens)
        default: return "Available"
        }
    }

    private var detailSource: String {
        switch card {
        case .burn, .context, .contextRunway, .efficiency: return snapshot.tokenTelemetry.freshnessLabel(now: now)
        case .sessionHealth, .sessionPulse: return "Local session telemetry"
        case .pace, .quotaBudget: return "Quota pace history"
        case .streaksGoals: return "Local daily goal and activity history"
        default: return "Data is derived from the current local snapshot."
        }
    }

    private func statusTint(_ state: String) -> Color {
        switch state {
        case "Ready": return theme.dataColor(2)
        case "Optional": return theme.dataColor(1)
        default: return theme.dataColor(0)
        }
    }
}

private struct CodexV6DetailMetric: View {
    let value: String
    let label: String
    let tint: Color
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(CodexThemeMetricSurface(theme: theme, tint: tint))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct CodexV6DetailRow: View {
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 6)
            Text(value)
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help("\(label): \(value)")
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}

private struct CodexV6DetailSource: View {
    let text: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: "info.circle")
            .font(.caption2)
            .foregroundStyle(tint)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CodexV6DetailEmpty: View {
    let text: String

    var body: some View {
        Label(text, systemImage: "hourglass")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
