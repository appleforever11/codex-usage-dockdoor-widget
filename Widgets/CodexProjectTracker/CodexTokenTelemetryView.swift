import SwiftUI

struct CodexTokenTelemetrySection: View {
    let telemetry: CodexTokenTelemetry
    let now: Date
    @Environment(\.codexTheme) private var theme
    @State private var isExpanded = false
    @State private var isBreakdownExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2.weight(.bold))
                        .frame(width: 9)
                        .foregroundStyle(theme.accent)
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Token activity")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(telemetry.hasData ? telemetry.shortSummary(now: now) : "Waiting for a Codex token event")
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.primary.opacity(0.86))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Text(telemetry.freshnessLabel(now: now))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(telemetry.isStale(now: now) ? .orange : .secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Token activity")
            .accessibilityValue(telemetry.hasData ? "\(telemetry.shortSummary(now: now)), \(isExpanded ? "expanded" : "collapsed")" : "Waiting for a token event, \(isExpanded ? "expanded" : "collapsed")")

            if isExpanded {
                if telemetry.hasData {
                    expandedContent
                } else {
                    Label("Waiting for a Codex token event", systemImage: "hourglass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            }
        }
        .padding(10)
        .background(theme.accent.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.accent.opacity(0.14), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Codex token activity")
        .accessibilityValue(telemetry.hasData ? telemetry.shortSummary(now: now) : "Waiting for a token event")
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                CodexTokenTelemetryStat(
                    title: "Burn / min",
                    value: telemetry.burnLabel(now: now),
                    tint: theme.accent
                )
                CodexTokenTelemetryStat(
                    title: "Today",
                    value: CodexTokenUsage.compactLabel(telemetry.todayUsage.effectiveTotalTokens),
                    tint: theme.dataColor(1)
                )
                CodexTokenTelemetryStat(
                    title: "Context",
                    value: telemetry.contextLabel,
                    tint: theme.dataColor(2)
                )
            }

            CodexTokenBurnChart(samples: telemetry.samples, tint: theme.accent)
                .frame(height: 42)

            HStack(spacing: 5) {
                Image(systemName: "bolt.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(theme.accent)
                Text(telemetry.shortSummary(now: now))
                    .font(.caption2.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.primary.opacity(0.86))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let latestDelta = telemetry.latestDelta {
                    Text("last \(CodexTokenUsage.compactLabel(latestDelta.effectiveTotalTokens))")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            DisclosureGroup(isExpanded: $isBreakdownExpanded) {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(telemetry.modelBreakdowns.prefix(6)) { breakdown in
                        HStack(spacing: 7) {
                            Circle()
                                .fill(modelTint(for: breakdown.model))
                                .frame(width: 7, height: 7)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(breakdown.modelLabel)
                                    .font(.caption2.weight(.semibold))
                                Text("\(breakdown.reasoningLabel) · \(breakdown.turnCount) events")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Text(CodexTokenUsage.compactLabel(breakdown.usage.effectiveTotalTokens))
                                .font(.caption2.monospacedDigit().weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 5)
            } label: {
                HStack {
                    Text("By model and reasoning")
                        .font(.caption2.weight(.semibold))
                    Spacer()
                    Text("\(telemetry.modelBreakdowns.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .tint(theme.accent)

            Text("Observed local session usage · no network")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }

    private func modelTint(for model: String) -> Color {
        switch model.lowercased() {
        case let value where value.contains("astra"): return CodexTheme.astra.accent
        case let value where value.contains("terra"): return CodexTheme.terra.accent
        case let value where value.contains("luna"): return CodexTheme.luna.accent
        case let value where value.contains("sol"): return CodexTheme.sol.accent
        default: return .secondary
        }
    }
}

private struct CodexTokenTelemetryStat: View {
    let title: String
    let value: String
    let tint: Color
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(CodexThemeMetricSurface(theme: theme, tint: tint))
    }
}

private struct CodexTokenBurnChart: View {
    let samples: [CodexTokenBurnSample]
    let tint: Color
    @Environment(\.codexTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                    paused: reduceMotion)) { timeline in
                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let visible = Array(samples.suffix(36))
                    let values = visible.map { max(0, Double($0.usage.effectiveTotalTokens)) }
                    let maximum = max(values.max() ?? 0, 1)
                    let slot = size.width / CGFloat(max(visible.count, 1))

                    context.stroke(
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: size.height - 1))
                            path.addLine(to: CGPoint(x: size.width, y: size.height - 1))
                        },
                        with: .color(theme.dataColor(0).opacity(0.20)),
                        style: StrokeStyle(lineWidth: 1, dash: [2, 3])
                    )

                    for (index, value) in values.enumerated() {
                        let height = max(3, CGFloat(value / maximum) * (size.height - 5))
                        let rect = CGRect(
                            x: CGFloat(index) * slot + max(1, slot * 0.16),
                            y: size.height - height,
                            width: max(2, slot * 0.68),
                            height: height
                        )
                        let color = theme.dataColor(index)
                        let pulse = 0.5 + 0.5 * sin(time * 1.05 + Double(index) * 0.65)
                        var glow = context
                        glow.addFilter(.blur(radius: 3))
                        glow.fill(Path(roundedRect: rect.insetBy(dx: -1, dy: -1), cornerRadius: min(3, rect.width / 2)),
                                  with: .color(color.opacity(0.16 + 0.10 * pulse)))
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: min(3, rect.width / 2)),
                            with: .linearGradient(
                                Gradient(colors: [color.opacity(0.42), color.opacity(0.95)]),
                                startPoint: CGPoint(x: rect.midX, y: rect.maxY),
                                endPoint: CGPoint(x: rect.midX, y: rect.minY)
                            )
                        )
                        let sparkle = CGPoint(x: rect.midX, y: rect.minY + 1)
                        context.fill(codexSparkPath(center: sparkle, radius: max(0.8, min(1.8, rect.width * 0.18))),
                                     with: .color(.white.opacity(0.25 + 0.42 * pulse)))
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .accessibilityLabel("Recent token burn chart")
        .accessibilityValue(samples.isEmpty ? "No token events" : "Showing the latest \(samples.count) token events")
    }
}

private extension CodexTokenTelemetry {
    func isStale(now: Date) -> Bool {
        guard let updatedAt else { return true }
        return now.timeIntervalSince(updatedAt) > 120
    }
}
