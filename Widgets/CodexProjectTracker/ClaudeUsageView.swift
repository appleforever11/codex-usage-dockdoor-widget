import SwiftUI

struct ClaudeUsageSection: View {
    let now: Date
    @State private var usage = ClaudeUsageSnapshot.unavailable
    @Environment(\.codexTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 5) {
                Label("Claude", systemImage: "sun.max.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.accent)
                Spacer()
                Text(usage.updatedAt == nil ? "UNAVAILABLE" : usage.isStale(at: now) ? "STALE" : "DESKTOP SAMPLE")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            if let reason = usage.unavailableReason {
                Text(reason).font(.caption2).foregroundStyle(.secondary)
            } else {
                HStack(spacing: 12) {
                    allowance("Five-hour", value: usage.fiveHourRemaining)
                    Divider().overlay(theme.accent.opacity(0.18))
                    allowance("Weekly", value: usage.weeklyRemaining)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            if let updated = usage.updatedAt {
                Text("Claude Desktop · updated \(updated, style: .relative) ago")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
            Text("Reset times unavailable from desktop feed")
                .font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accent.opacity(0.065), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.accent.opacity(0.18), lineWidth: 0.8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Claude plan allowances, separate from Codex")
        .task {
            while !Task.isCancelled {
                usage = await Task.detached(priority: .utility) { ClaudeUsageSnapshot.read() }.value
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func allowance(_ title: String, value: Double?) -> some View {
        HStack(spacing: 7) {
            if let value {
                CodexV6ProgressRing(value: value, theme: theme, size: 42)
                    .accessibilityLabel("Claude \(title.lowercased()) allowance remaining")
                    .accessibilityValue("\(Int((value * 100).rounded())) percent")
            } else {
                Image(systemName: "questionmark.circle").font(.title2).foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.caption2.weight(.semibold))
                Text(value.map { "\(Int(($0 * 100).rounded()))% left" } ?? "Unavailable")
                    .font(.caption2.monospacedDigit().weight(.bold))
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
