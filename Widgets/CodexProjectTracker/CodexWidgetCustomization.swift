import AppKit
import Charts
import DockDoorWidgetSDK
import SwiftUI

enum CodexDockLayout: String, CaseIterable, Identifiable {
    case ring = "Ring only", percentage = "Ring + percentage", model = "Ring + model"
    var id: String { rawValue }
}

enum CodexRingMetric: String, CaseIterable, Identifiable {
    case allowance = "Account allowance", window = "Local usage window", tasks = "Task progress"
    var id: String { rawValue }

    func progress(_ usage: CodexUsageSnapshot) -> Double? {
        switch self {
        case .allowance: return usage.source == "Loading" || usage.source == "No account snapshot" ? nil : usage.percentRemaining
        case .window:
            guard usage.source != "Loading" && usage.source != "No account snapshot" else { return nil }
            let configuredBudget = WidgetDefaults.double(key: "usageBudgetMillions", widgetId: "codex-project-tracker", default: 200) * 1_000_000
            let budget = usage.budgetTokens > 0 ? Double(usage.budgetTokens) : configuredBudget
            guard budget.isFinite && budget > 0 else { return nil }
            return max(0, min(1, 1 - Double(usage.windowUsedTokens) / budget))
        case .tasks: return nil // Local snapshots expose task counts, not completion state.
        }
    }
}

extension CodexUsageSnapshot {
    func connectionTitle(now: Date) -> String {
        if source == "Loading" { return "Loading" }
        let issue = (warning ?? "").lowercased()
        if issue.contains("sign in") || issue.contains("signed out") || issue.contains("unauthorized") { return "Signed out" }
        if source == "No account snapshot" { return "Unavailable" }
        if isStale || lastUpdated.map({ now.timeIntervalSince($0) > 900 }) == true { return "Stale" }
        if warning != nil { return "Connection issue" }
        return "Live"
    }
}

enum CodexBuildIdentity {
    static var label: String {
        let bundle = Bundle(for: CodexProjectTrackerPlugin.self)
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Preview"
        let channel = bundle.object(forInfoDictionaryKey: "CodexBuildChannel") as? String ?? "Private"
        return "\(channel) · \(version)"
    }
}

struct CodexWidgetCustomization: View {
    @AppStorage(CodexTheme.opacityKey) private var opacity = 0.75
    @AppStorage("widget.codex-project-tracker.tintStrength") private var tint = 1.0
    @AppStorage("widget.codex-project-tracker.blurStrength") private var blur = 1.0
    @AppStorage(CodexTheme.glassKey) private var frosted = true
    @AppStorage("widget.codex-project-tracker.dockLayout") private var layout = CodexDockLayout.model.rawValue
    @AppStorage("widget.codex-project-tracker.ringMetric") private var metric = CodexRingMetric.allowance.rawValue
    @AppStorage("widget.codex-project-tracker.usageAlerts") private var alerts = false
    @AppStorage("widget.codex-project-tracker.lowAllowance") private var threshold = 0.20
    @AppStorage("widget.codex-project-tracker.hiddenCards") private var hidden = ""
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLASS").font(.caption.weight(.semibold))
            control("Background opacity", value: $opacity, range: 0.2...1)
            control("Tint strength", value: $tint, range: 0...1.5)
            control("Blur strength", value: $blur, range: 0...1)
            Toggle("Frosted glass", isOn: $frosted).disabled(reduceTransparency)
            if reduceTransparency { Text("macOS Reduce Transparency uses a solid background.").font(.caption).foregroundStyle(.secondary) }
            Divider()
            Text("DOCK").font(.caption.weight(.semibold))
            Picker("Layout", selection: $layout) {
                ForEach(CodexDockLayout.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Picker("Ring tracks", selection: $metric) {
                ForEach(CodexRingMetric.allCases) { Text($0.rawValue).tag($0.rawValue) }
            }
            Text(metric == CodexRingMetric.tasks.rawValue
                 ? "Task completion is unavailable from local snapshots. The ring shows —."
                 : metric == CodexRingMetric.window.rawValue
                 ? "Remaining local token budget; this is an estimate, separate from account limits."
                 : "Uses the primary allowance reported by your account.")
                .font(.caption).foregroundStyle(.secondary)
            Toggle("Low allowance and reset alerts", isOn: $alerts)
            if alerts {
                control("Alert below", value: $threshold, range: 0.05...0.5)
                Text("Alerts appear in the widget and dock while live account data is available.").font(.caption).foregroundStyle(.secondary)
            }
            Divider()
            DisclosureGroup("Visible cards") {
                ForEach(CodexV6CardID.allCases) { card in
                    Toggle(card.title, isOn: Binding(
                        get: { !hidden.split(separator: ",").contains(Substring(card.rawValue)) },
                        set: { visible in
                            var values = Set(hidden.split(separator: ",").map(String.init))
                            if visible { values.remove(card.rawValue) } else { values.insert(card.rawValue) }
                            hidden = values.sorted().joined(separator: ",")
                        }
                    ))
                }
            }
            Text("Drag cards in Arrange mode to reorder or move them between pages.")
                .font(.caption).foregroundStyle(.secondary)
            Text(CodexBuildIdentity.label).font(.caption.monospaced()).foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .toggleStyle(.checkbox)
    }

    private func control(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { Text(title); Spacer(); Text("\(Int((value.wrappedValue * 100).rounded()))%").monospacedDigit() }
            Slider(value: value, in: range, step: 0.05)
                .accessibilityLabel(title)
                .disabled(reduceTransparency && title != "Alert below")
        }
    }
}

struct CodexAllowanceAlert: View {
    let usage: CodexUsageSnapshot
    let now: Date
    @AppStorage("widget.codex-project-tracker.usageAlerts") private var enabled = false
    @AppStorage("widget.codex-project-tracker.lowAllowance") private var threshold = 0.20
    @AppStorage("widget.codex-project-tracker.previousReset") private var previousReset = 0.0
    @AppStorage("widget.codex-project-tracker.resetAlertAt") private var resetAlertAt = 0.0

    var body: some View {
        Group {
            if enabled && usage.connectionTitle(now: now) == "Live" {
                if usage.percentRemaining <= threshold {
                    Label("Allowance below \(Int(threshold * 100))% · \(usage.resetSummary(now: now))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if now.timeIntervalSince1970 - resetAlertAt < 3600 {
                    Label("Allowance reset · current limits refreshed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 5)
        .onChange(of: usage.resetDate, initial: true) { _, date in
            guard usage.connectionTitle(now: now) == "Live", let date else { return }
            if previousReset > 0, date.timeIntervalSince1970 > previousReset,
               now.timeIntervalSince1970 >= previousReset {
                resetAlertAt = now.timeIntervalSince1970
            }
            previousReset = date.timeIntervalSince1970
        }
    }
}

struct CodexUsageMiniTrend: View {
    let days: [CodexAnalyticsDay]
    @Environment(\.codexTheme) private var theme
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Recent local token activity").font(.caption2.weight(.semibold))
            if days.isEmpty {
                Text("Waiting for local token history").font(.caption2).foregroundStyle(.secondary)
            } else {
                Chart(Array(days.sorted { $0.dayKey < $1.dayKey }.suffix(7))) { day in
                    BarMark(x: .value("Recorded day", day.dayKey), y: .value("Tokens", day.tokens))
                        .foregroundStyle(theme.accent)
                }
                .chartXAxis(.hidden).chartYAxis(.hidden)
                .frame(height: 32)
                .accessibilityLabel("Last seven recorded days of local token activity")
            }
        }
    }
}
