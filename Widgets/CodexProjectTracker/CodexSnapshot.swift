import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct CodexSnapshot {
    var projectCount: Int
    var activeCount: Int
    var chatCount: Int
    var taskCount: Int
    var headline: String
    var latestChat: String?
    var usage: CodexUsageSnapshot
    var tokenTelemetry: CodexTokenTelemetry
    var analytics: CodexV6AnalyticsSnapshot
    var modelSettings: CodexModelSettings
    var projects: [CodexProject]
    var sessions: [CodexSession]
    var panelSessions: [CodexSession]

    static let empty = CodexSnapshot(
        projectCount: 0,
        activeCount: 0,
        chatCount: 0,
        taskCount: 0,
        headline: "Loading",
        latestChat: nil,
        usage: .empty,
        tokenTelemetry: .empty,
        analytics: .empty,
        modelSettings: .default,
        projects: [],
        sessions: [],
        panelSessions: []
    )

    func rotatingDockCard(
        at date: Date,
        interval: Double = 4,
        preferredKind: String = "Auto"
    ) -> CodexDockCard {
        var cards = usage.dockCards
        cards.append(CodexDockCard(
            title: modelSettings.shortModelName,
            subtitle: "\(modelSettings.reasoningLabel) reasoning",
            shortLabel: "Model",
            kind: CodexCardKind.model.rawValue
        ))
        cards.append(CodexDockCard(
            title: "\(taskCount) Tasks",
            subtitle: "\(projectCount) projects active",
            shortLabel: "Tasks",
            kind: CodexCardKind.tasks.rawValue
        ))
        cards.append(CodexDockCard(
            title: "\(chatCount) Chats",
            subtitle: headline,
            shortLabel: "Chats",
            kind: CodexCardKind.chats.rawValue
        ))
        if tokenTelemetry.hasData {
            cards.append(CodexDockCard(
                title: tokenTelemetry.burnLabel(now: date),
                subtitle: tokenTelemetry.currentModelLabel + " · " + tokenTelemetry.currentReasoningLabel,
                shortLabel: "Burn",
                kind: CodexCardKind.burn.rawValue
            ))
        }
        if let pace = analytics.quotaPace, let rate = pace.percentPerHour {
            let projected = pace.projectedExhaustionAt.map { projectedDate in
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                return "Runs out \(formatter.localizedString(for: projectedDate, relativeTo: date))"
            } ?? "Building baseline"
            cards.append(CodexDockCard(
                title: String(format: "%.1f%% / hr", rate),
                subtitle: "Quota pace · \(projected)",
                shortLabel: "Pace",
                kind: CodexCardKind.pace.rawValue
            ))
        }
        if let cost = analytics.estimatedCostUSD {
            cards.append(CodexDockCard(
                title: String(format: "$%.2f est.", cost),
                subtitle: "30-day API-equivalent cost",
                shortLabel: "Cost",
                kind: CodexCardKind.cost.rawValue
            ))
        }

        guard !cards.isEmpty else {
            return CodexDockCard(title: "Codex", subtitle: headline, shortLabel: "Codex")
        }

        let normalizedKind = preferredKind.lowercased()
        if normalizedKind != "auto",
           let preferred = cards.first(where: { $0.kind == normalizedKind }) {
            return preferred
        }

        let safeInterval = max(interval, 2)
        let index = Int(date.timeIntervalSinceReferenceDate / safeInterval) % cards.count
        return cards[index]
    }
}

enum CodexCardKind: String {
    case usage
    case model
    case tasks
    case chats
    case credits
    case burn
    case pace
    case cost
}


struct CodexDockCard: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let shortLabel: String
    let percentRemaining: Double?
    let kind: String

    init(
        title: String,
        subtitle: String,
        shortLabel: String,
        percentRemaining: Double? = nil,
        kind: String = CodexCardKind.usage.rawValue
    ) {
        self.title = title
        self.subtitle = subtitle
        self.shortLabel = shortLabel
        self.percentRemaining = percentRemaining
        self.kind = kind
    }
}

struct CodexUsageSnapshot {
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
    var lastUpdated: Date?
    var isStale: Bool
    var warning: String?
    /// Formatted, unit-neutral prepaid credit balance from the account snapshot.
    var creditsBalance: String?

    init(
        percentRemaining: Double,
        primaryTitle: String,
        primarySubtitle: String,
        windowUsedTokens: Int64,
        todayUsedTokens: Int64,
        budgetTokens: Int64,
        resetDate: Date?,
        resetLabel: String?,
        source: String,
        metrics: [CodexUsageMetric],
        accountCards: [CodexDockCard],
        lastUpdated: Date? = nil,
        isStale: Bool = false,
        warning: String? = nil,
        creditsBalance: String? = nil
    ) {
        self.percentRemaining = percentRemaining
        self.primaryTitle = primaryTitle
        self.primarySubtitle = primarySubtitle
        self.windowUsedTokens = windowUsedTokens
        self.todayUsedTokens = todayUsedTokens
        self.budgetTokens = budgetTokens
        self.resetDate = resetDate
        self.resetLabel = resetLabel
        self.source = source
        self.metrics = metrics
        self.accountCards = accountCards
        self.lastUpdated = lastUpdated
        self.isStale = isStale
        self.warning = warning
        self.creditsBalance = creditsBalance
    }

    static let empty = CodexUsageSnapshot(
        percentRemaining: 1,
        primaryTitle: "Loading usage",
        primarySubtitle: "Reading local Codex data",
        windowUsedTokens: 0,
        todayUsedTokens: 0,
        budgetTokens: 0,
        resetDate: nil,
        resetLabel: nil,
        source: "Loading",
        metrics: [],
        accountCards: [],
        isStale: true,
        warning: "Waiting for the first local usage snapshot."
    )

    static let unavailable = CodexUsageSnapshot(
        percentRemaining: 0,
        primaryTitle: "Usage unavailable",
        primarySubtitle: "No authoritative usage data found",
        windowUsedTokens: 0,
        todayUsedTokens: 0,
        budgetTokens: 0,
        resetDate: nil,
        resetLabel: nil,
        source: "No account snapshot",
        metrics: [],
        accountCards: [],
        isStale: true,
        warning: "Launch Codex or install the local usage sync to provide current limits."
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
                percentRemaining: percentRemaining,
                kind: CodexCardKind.usage.rawValue
            ),
            CodexDockCard(
                title: "Used \(windowUsedLabel)",
                subtitle: source,
                shortLabel: "Usage",
                kind: CodexCardKind.usage.rawValue
            ),
            CodexDockCard(
                title: resetTitle,
                subtitle: resetDate == nil && resetLabel == nil ? "No reset time found" : "Usage limit countdown",
                shortLabel: "Reset",
                kind: CodexCardKind.usage.rawValue
            ),
        ]
    }

    var statusTint: Color {
        if source == "Loading" { return .secondary }
        if isStale { return .orange }
        if source.localizedCaseInsensitiveContains("estimate") { return .orange }
        return .green
    }

    func statusLabel(now: Date) -> String {
        let updateLabel: String
        if let lastUpdated {
            let age = max(0, now.timeIntervalSince(lastUpdated))
            if age < 10 {
                updateLabel = "Updated just now"
            } else {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .abbreviated
                updateLabel = "Updated \(formatter.localizedString(for: lastUpdated, relativeTo: now))"
            }
        } else {
            updateLabel = "No update timestamp"
        }

        return "\(source) • \(updateLabel)"
    }

    var resetTitle: String {
        if let resetDate {
            return "Reset \(Self.relativeReset(resetDate))"
        }
        if let resetLabel {
            return "Reset \(resetLabel)"
        }
        return "Reset Soon"
    }

    func resetSummary(now: Date) -> String {
        if let resetDate {
            let interval = max(0, resetDate.timeIntervalSince(now))
            let days = Int(interval / 86_400)
            let hours = Int((interval.truncatingRemainder(dividingBy: 86_400)) / 3600)
            let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
            if days > 0 {
                return "Resets in \(days)d \(hours)h"
            }
            if hours > 0 {
                return "Resets in \(hours)h \(minutes)m"
            }
            return "Resets in \(minutes)m"
        }
        if let resetLabel {
            return "Resets \(resetLabel)"
        }
        return "No reset time exposed locally yet"
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

struct CodexUsageMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let systemImage: String
    let tint: Color
}

struct CodexProject: Identifiable {
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

struct CodexSession: Identifiable {
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
