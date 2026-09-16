import DockDoorWidgetSDK
import Foundation

enum CodexV6Page: String, CaseIterable, Hashable, Identifiable {
    case overview
    case activity
    case models
    case health

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Overview"
        case .activity: return "Activity"
        case .models: return "Models"
        case .health: return "Health"
        }
    }

    var symbol: String {
        switch self {
        case .overview: return "gauge.with.dots.needle.67percent"
        case .activity: return "chart.xyaxis.line"
        case .models: return "square.stack.3d.up.fill"
        case .health: return "heart.text.square.fill"
        }
    }

    var defaultTheme: CodexTheme {
        switch self {
        case .overview: return .astra
        case .activity: return .luna
        case .models: return .terra
        case .health: return .sol
        }
    }

    var defaultCards: [CodexV6CardID] {
        switch self {
        case .overview: return [.quota, .modelControls, .quotaBudget, .sessionPulse, .pace, .burn, .context, .contextRunway]
        case .activity: return [.dailyActivity, .hourlyActivity, .projectHeatmap, .turnTimeline, .streaksGoals, .cost]
        case .models: return [.modelMix, .modelScorecard, .efficiency, .projectMix, .sessionHealth]
        case .health: return [.officialActivity, .reliability, .dataHealth, .workspaceHealth, .recentChats]
        }
    }

    var pageIndex: Int {
        Self.allCases.firstIndex(of: self) ?? 0
    }
}

enum CodexV6AnalyticsWindow: String, CaseIterable, Identifiable {
    case today
    case sevenDays
    case thirtyDays

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .sevenDays: return "7 days"
        case .thirtyDays: return "30 days"
        }
    }

    var dayCount: Int {
        switch self {
        case .today: return 1
        case .sevenDays: return 7
        case .thirtyDays: return 30
        }
    }
}

enum CodexV6CardDensity: String, CaseIterable, Identifiable {
    case compact
    case standard
    case spacious

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }

    var cardSpacing: CGFloat {
        switch self {
        case .compact: return 6
        case .standard: return 9
        case .spacious: return 13
        }
    }

    var cardPadding: CGFloat {
        switch self {
        case .compact: return 8
        case .standard: return 11
        case .spacious: return 14
        }
    }
}

enum CodexV6CardID: String, CaseIterable, Hashable, Identifiable {
    case quota
    case pace
    case burn
    case context
    case quotaBudget
    case sessionPulse
    case contextRunway
    case dailyActivity
    case hourlyActivity
    case projectHeatmap
    case turnTimeline
    case streaksGoals
    case cost
    case modelMix
    case modelScorecard
    case efficiency
    case projectMix
    case sessionHealth
    case officialActivity
    case reliability
    case dataHealth
    case workspaceHealth
    case recentChats
    case modelControls

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quota: return "Quota"
        case .pace: return "Quota pace"
        case .burn: return "Live burn"
        case .context: return "Context health"
        case .quotaBudget: return "Quota budget"
        case .sessionPulse: return "Session pulse"
        case .contextRunway: return "Context runway"
        case .dailyActivity: return "Daily activity"
        case .hourlyActivity: return "Hourly activity"
        case .projectHeatmap: return "Project heatmap"
        case .turnTimeline: return "Turn timeline"
        case .streaksGoals: return "Streaks & goals"
        case .cost: return "Cost estimate"
        case .modelMix: return "Model mix"
        case .modelScorecard: return "Model scorecard"
        case .efficiency: return "Efficiency"
        case .projectMix: return "Project mix"
        case .sessionHealth: return "Session health"
        case .officialActivity: return "Official activity"
        case .reliability: return "Reliability"
        case .dataHealth: return "Data health"
        case .workspaceHealth: return "Workspace health"
        case .recentChats: return "Recent chats"
        case .modelControls: return "New chat defaults"
        }
    }

    var symbol: String {
        switch self {
        case .quota: return "gauge.with.dots.needle.67percent"
        case .pace: return "speedometer"
        case .burn: return "flame.fill"
        case .context: return "rectangle.3.group"
        case .quotaBudget: return "gauge.open.with.lines.needle.33percent"
        case .sessionPulse: return "waveform.path.ecg.rectangle"
        case .contextRunway: return "arrow.down.right.and.arrow.up.left"
        case .dailyActivity: return "calendar"
        case .hourlyActivity: return "square.grid.3x3.fill"
        case .projectHeatmap: return "square.grid.2x2.fill"
        case .turnTimeline: return "list.bullet.rectangle.portrait"
        case .streaksGoals: return "flame.circle.fill"
        case .cost: return "dollarsign.circle.fill"
        case .modelMix: return "cpu.fill"
        case .modelScorecard: return "chart.bar.xaxis"
        case .efficiency: return "gauge.with.dots.needle.50percent"
        case .projectMix: return "folder.fill"
        case .sessionHealth: return "waveform.path.ecg"
        case .officialActivity: return "person.crop.circle.badge.checkmark"
        case .reliability: return "checkmark.seal.fill"
        case .dataHealth: return "checkmark.shield.fill"
        case .workspaceHealth: return "terminal.fill"
        case .recentChats: return "bubble.left.and.bubble.right.fill"
        case .modelControls: return "slider.horizontal.3"
        }
    }

    var isHero: Bool { self == .quota }

    var detailDescription: String {
        switch self {
        case .quota: return "Account allowance, reset timing, and the most important usage totals."
        case .pace, .quotaBudget: return "A local pace estimate comparing current usage with the next quota reset."
        case .burn: return "Recent token burn measured from local Codex session events."
        case .context, .contextRunway: return "Context-window usage derived from locally observed token events."
        case .sessionPulse, .sessionHealth: return "The current local session and its recent activity signals."
        case .dailyActivity, .hourlyActivity, .turnTimeline: return "Token activity grouped by time from the local event cache."
        case .projectHeatmap, .projectMix: return "Token activity grouped by local project and session."
        case .streaksGoals: return "Daily activity goals and streaks based on available local history."
        case .cost: return "An API-equivalent cost estimate using the configured model rates."
        case .modelMix, .modelScorecard: return "Model and reasoning-level usage breakdowns from attributed events."
        case .efficiency: return "Input, cache, output, and per-turn efficiency indicators."
        case .officialActivity: return "Read-only aggregate activity exposed by the local usage state."
        case .reliability, .dataHealth, .workspaceHealth: return "Health and provenance checks for the widget data sources."
        case .recentChats: return "Recent local Codex sessions available to open."
        case .modelControls: return "The model and reasoning defaults used for new chats."
        }
    }
}

struct CodexAnalyticsDay: Equatable, Identifiable, Sendable {
    let dayKey: String
    let tokens: Int64
    let eventCount: Int
    let estimatedCostUSD: Double?

    var id: String { dayKey }
}

enum CodexV6DateFormatting {
    /// Day keys are calendar dates, not instants. Keep their weekday label in
    /// the same UTC calendar used by the `yyyy-MM-dd` representation so a
    /// western time zone cannot shift the label to the previous day.
    static func shortWeekday(forDayKey key: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: key + "T00:00:00Z") else {
            return String(key.suffix(2))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EE"
        return formatter.string(from: date)
    }
}

struct CodexAnalyticsHour: Equatable, Identifiable, Sendable {
    let weekday: Int
    let hour: Int
    let tokens: Int64
    let eventCount: Int

    var id: String { "\(weekday)-\(hour)" }
}

struct CodexAnalyticsModel: Equatable, Identifiable, Sendable {
    let model: String
    let reasoningEffort: String
    let tokens: Int64
    let eventCount: Int
    let estimatedCostUSD: Double?

    var id: String { "\(model)|\(reasoningEffort)" }

    var modelLabel: String {
        switch model.lowercased() {
        case let value where value.contains("astra"): return "Astra"
        case let value where value.contains("terra"): return "Terra"
        case let value where value.contains("luna"): return "Luna"
        case let value where value.contains("sol"): return "Sol"
        case "", "unknown": return "Unknown"
        default: return model
        }
    }

    var reasoningLabel: String {
        switch reasoningEffort.lowercased() {
        case "low", "instant": return "Light"
        case "max": return "Max"
        case "", "unknown": return "Unknown"
        default: return reasoningEffort.prefix(1).uppercased() + reasoningEffort.dropFirst()
        }
    }
}

struct CodexAnalyticsProject: Equatable, Identifiable, Sendable {
    let name: String
    let tokens: Int64
    let eventCount: Int
    let sessionCount: Int

    var id: String { name }
}

struct CodexV6WorkspaceHealth: Equatable, Sendable {
    let checkedProjectCount: Int
    let repositoryCount: Int
    let dirtyRepositoryCount: Int
    let dirtyFileCount: Int
    let activeProject: String?
    let activeBranch: String?

    var isAvailable: Bool { repositoryCount > 0 }
}

struct CodexOfficialActivitySnapshot: Equatable, Sendable {
    let lifetimeTokens: Int64?
    let peakDailyTokens: Int64?
    let currentStreakDays: Int?
    let longestStreakDays: Int?
    let daily: [CodexAnalyticsDay]

    var hasData: Bool {
        lifetimeTokens != nil || peakDailyTokens != nil || !daily.isEmpty
    }
}

struct CodexV6QuotaPace: Equatable, Sendable {
    let usedPercent: Double
    let percentPerHour: Double?
    let projectedExhaustionAt: Date?
    let resetAt: Date?
    let willLastToReset: Bool?
    let sampleCount: Int
}

struct CodexAnalyticsSourceStatus: Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let state: String
    let detail: String
}

struct CodexV6AnalyticsSnapshot: Equatable, Sendable {
    let todayTokens: Int64
    let last7DaysTokens: Int64
    let last30DaysTokens: Int64
    let daily: [CodexAnalyticsDay]
    let hourly: [CodexAnalyticsHour]
    let models: [CodexAnalyticsModel]
    let projects: [CodexAnalyticsProject]
    let contextPercent: Double?
    let peakContextPercent: Double?
    let burnPerMinute: Double?
    let estimatedCostUSD: Double?
    let costCoverage: Double
    let quotaPace: CodexV6QuotaPace?
    let officialActivity: CodexOfficialActivitySnapshot?
    let sourceStatuses: [CodexAnalyticsSourceStatus]
    let cachedEventCount: Int
    let dailyGoalTokens: Int64
    let workspaceHealth: CodexV6WorkspaceHealth
    let updatedAt: Date?

    var todayVsPreviousDay: Double? {
        guard daily.count > 1,
              let current = daily.last,
              let previous = daily.dropLast().last,
              previous.tokens > 0
        else { return nil }
        return (Double(current.tokens) - Double(previous.tokens)) / Double(previous.tokens)
    }

    static let empty = CodexV6AnalyticsSnapshot(
        todayTokens: 0,
        last7DaysTokens: 0,
        last30DaysTokens: 0,
        daily: [],
        hourly: [],
        models: [],
        projects: [],
        contextPercent: nil,
        peakContextPercent: nil,
        burnPerMinute: nil,
        estimatedCostUSD: nil,
        costCoverage: 0,
        quotaPace: nil,
        officialActivity: nil,
        sourceStatuses: [],
        cachedEventCount: 0,
        dailyGoalTokens: 0,
        workspaceHealth: CodexV6WorkspaceHealth(
            checkedProjectCount: 0,
            repositoryCount: 0,
            dirtyRepositoryCount: 0,
            dirtyFileCount: 0,
            activeProject: nil,
            activeBranch: nil
        ),
        updatedAt: nil
    )

    static let preview: CodexV6AnalyticsSnapshot = {
        let now = Date()
        let dayValues: [(String, Int64)] = [
            ("2026-09-09", 420_000), ("2026-09-10", 1_180_000),
            ("2026-09-11", 760_000), ("2026-09-12", 2_240_000),
            ("2026-09-13", 1_560_000), ("2026-09-14", 3_080_000),
            ("2026-09-15", 1_940_000)
        ]
        return CodexV6AnalyticsSnapshot(
            todayTokens: 1_940_000,
            last7DaysTokens: 11_184_000,
            last30DaysTokens: 18_420_000,
            daily: dayValues.map {
                CodexAnalyticsDay(dayKey: $0.0, tokens: $0.1, eventCount: 12, estimatedCostUSD: Double($0.1) / 4_000_000)
            },
            hourly: (0..<24).flatMap { hour in
                [
                    CodexAnalyticsHour(weekday: 2, hour: hour, tokens: Int64(max(0, sin(Double(hour) * 0.7) * 280_000 + 320_000)), eventCount: 4),
                    CodexAnalyticsHour(weekday: 3, hour: hour, tokens: Int64(max(0, cos(Double(hour) * 0.5) * 180_000 + 200_000)), eventCount: 3)
                ]
            },
            models: [
                CodexAnalyticsModel(model: "gpt-6-astra", reasoningEffort: "max", tokens: 8_420_000, eventCount: 46, estimatedCostUSD: 8.24),
                CodexAnalyticsModel(model: "gpt-5.6-terra", reasoningEffort: "medium", tokens: 5_180_000, eventCount: 31, estimatedCostUSD: 4.88),
                CodexAnalyticsModel(model: "gpt-5.6-luna", reasoningEffort: "low", tokens: 2_080_000, eventCount: 19, estimatedCostUSD: 1.12)
            ],
            projects: [
                CodexAnalyticsProject(name: "Codex Usage Widget", tokens: 9_860_000, eventCount: 51, sessionCount: 7),
                CodexAnalyticsProject(name: "Personal Dashboard", tokens: 5_240_000, eventCount: 28, sessionCount: 4),
                CodexAnalyticsProject(name: "Release Prep", tokens: 580_000, eventCount: 17, sessionCount: 2)
            ],
            contextPercent: 0.57,
            peakContextPercent: 0.82,
            burnPerMinute: 24_800,
            estimatedCostUSD: 14.24,
            costCoverage: 0.92,
            quotaPace: CodexV6QuotaPace(
                usedPercent: 22,
                percentPerHour: 2.8,
                projectedExhaustionAt: now.addingTimeInterval(28 * 3600),
                resetAt: now.addingTimeInterval(40 * 3600),
                willLastToReset: true,
                sampleCount: 18
            ),
            officialActivity: CodexOfficialActivitySnapshot(
                lifetimeTokens: 482_000_000,
                peakDailyTokens: 9_200_000,
                currentStreakDays: 11,
                longestStreakDays: 28,
                daily: []
            ),
            sourceStatuses: [
                CodexAnalyticsSourceStatus(id: "local-events", title: "Local token events", state: "Ready", detail: "128 events in the 30-day window"),
                CodexAnalyticsSourceStatus(id: "incremental-cache", title: "Incremental cache", state: "Ready", detail: "Bounded local cache · 128 events"),
                CodexAnalyticsSourceStatus(id: "account-quota", title: "Account quota", state: "Ready", detail: "Codex app-server live account limits"),
                CodexAnalyticsSourceStatus(id: "official-activity", title: "Official activity", state: "Ready", detail: "Read-only aggregate activity")
            ],
            cachedEventCount: 128,
            dailyGoalTokens: 2_500_000,
            workspaceHealth: CodexV6WorkspaceHealth(
                checkedProjectCount: 3,
                repositoryCount: 3,
                dirtyRepositoryCount: 1,
                dirtyFileCount: 4,
                activeProject: "Codex Usage Widget",
                activeBranch: "codex/v6-ui-haptics"
            ),
            updatedAt: now.addingTimeInterval(-8)
        )
    }()
}

enum CodexV6Preferences {
    // The demo app swaps this for an isolated suite before its view is created.
    // The installed widget continues to use standard widget preferences.
    static var defaults = UserDefaults.standard

    static let sparkleIntensityKey = "widget.codex-project-tracker.v6.sparkleIntensity"
    static let glowIntensityKey = "widget.codex-project-tracker.v6.glowIntensity"
    static let animationsEnabledKey = "widget.codex-project-tracker.v6.animationsEnabled"
    static let highContrastKey = "widget.codex-project-tracker.v6.highContrast"
    static let denseLayoutKey = "widget.codex-project-tracker.v6.denseLayout"
    static let cardDensityKey = "widget.codex-project-tracker.v6.cardDensity"
    static let showDataStatusKey = "widget.codex-project-tracker.v6.showDataStatus"

    static func loadVisualTuning() -> CodexV6VisualTuning {
        CodexV6VisualTuning(
            sparkleIntensity: defaults.object(forKey: sparkleIntensityKey) == nil ? 1 : defaults.double(forKey: sparkleIntensityKey),
            glowIntensity: defaults.object(forKey: glowIntensityKey) == nil ? 1 : defaults.double(forKey: glowIntensityKey),
            animationsEnabled: defaults.object(forKey: animationsEnabledKey) == nil ? true : defaults.bool(forKey: animationsEnabledKey),
            highContrast: defaults.bool(forKey: highContrastKey)
        )
    }

    static func saveVisualTuning(_ tuning: CodexV6VisualTuning) {
        defaults.set(tuning.sparkleIntensity, forKey: sparkleIntensityKey)
        defaults.set(tuning.glowIntensity, forKey: glowIntensityKey)
        defaults.set(tuning.animationsEnabled, forKey: animationsEnabledKey)
        defaults.set(tuning.highContrast, forKey: highContrastKey)
    }

    static var denseLayout: Bool {
        get { defaults.bool(forKey: denseLayoutKey) }
        set { defaults.set(newValue, forKey: denseLayoutKey) }
    }

    static func loadCardDensity() -> CodexV6CardDensity {
        if let stored = defaults.string(forKey: cardDensityKey),
           let density = CodexV6CardDensity(rawValue: stored) {
            return density
        }
        return denseLayout ? .compact : .standard
    }

    static func saveCardDensity(_ density: CodexV6CardDensity) {
        defaults.set(density.rawValue, forKey: cardDensityKey)
        defaults.set(density == .compact, forKey: denseLayoutKey)
    }

    static var showDataStatus: Bool {
        get { defaults.object(forKey: showDataStatusKey) == nil ? true : defaults.bool(forKey: showDataStatusKey) }
        set { defaults.set(newValue, forKey: showDataStatusKey) }
    }
}

enum CodexV6PageThemeStore {
    static func load(for page: CodexV6Page) -> CodexTheme {
        let key = "widget.codex-project-tracker.v6.page-theme.\(page.rawValue)"
        return CodexTheme(rawValue: CodexV6Preferences.defaults.string(forKey: key) ?? "") ?? page.defaultTheme
    }

    static func save(_ theme: CodexTheme, for page: CodexV6Page) {
        CodexV6Preferences.defaults.set(theme.rawValue, forKey: "widget.codex-project-tracker.v6.page-theme.\(page.rawValue)")
    }
}

enum CodexV6CardOrderStore {
    // One snapshot owns placement across all pages, so a move cannot be restored
    // to its old page by per-page normalization on the next launch.
    static let layoutKey = "widget.codex-project-tracker.v6.card-layout"

    static func loadLayout() -> [CodexV6Page: [CodexV6CardID]] {
        if let saved = CodexV6Preferences.defaults.dictionary(forKey: layoutKey) as? [String: [String]] {
            let decoded = Dictionary(uniqueKeysWithValues: CodexV6Page.allCases.map { page in
                (page, (saved[page.rawValue] ?? []).compactMap(CodexV6CardID.init(rawValue:)))
            })
            return normalizedLayout(decoded)
        }
        // Preserve existing arrangements when upgrading from page-local ordering.
        return normalizedLayout(Dictionary(uniqueKeysWithValues: CodexV6Page.allCases.map {
            ($0, load(for: $0))
        }))
    }

    static func saveLayout(_ layout: [CodexV6Page: [CodexV6CardID]]) {
        let layout = normalizedLayout(layout)
        let encoded = Dictionary(uniqueKeysWithValues: CodexV6Page.allCases.map {
            ($0.rawValue, (layout[$0] ?? []).map(\.rawValue))
        })
        CodexV6Preferences.defaults.set(encoded, forKey: layoutKey)
    }

    static func normalizedLayout(_ layout: [CodexV6Page: [CodexV6CardID]]) -> [CodexV6Page: [CodexV6CardID]] {
        var seen = Set<CodexV6CardID>()
        var result: [CodexV6Page: [CodexV6CardID]] = [:]
        for page in CodexV6Page.allCases {
            result[page] = (layout[page] ?? []).filter { seen.insert($0).inserted }
        }
        // Add newly introduced or missing cards only if absent from every page.
        for page in CodexV6Page.allCases {
            for card in page.defaultCards where seen.insert(card).inserted {
                result[page, default: []].append(card)
            }
        }
        return result
    }

    static func moving(_ card: CodexV6CardID, to page: CodexV6Page,
                       before target: CodexV6CardID? = nil,
                       in layout: [CodexV6Page: [CodexV6CardID]]) -> [CodexV6Page: [CodexV6CardID]] {
        var result = normalizedLayout(layout)
        guard target != card else { return result }
        for source in CodexV6Page.allCases {
            result[source]?.removeAll { $0 == card }
        }
        var destination = result[page] ?? []
        let index = target.flatMap { destination.firstIndex(of: $0) } ?? destination.endIndex
        destination.insert(card, at: index)
        result[page] = destination
        return result
    }

    private static let overviewModelControlsPlacementKey = "widget.codex-project-tracker.v6.card-order-migration.overview-model-controls"

    static func load(for page: CodexV6Page) -> [CodexV6CardID] {
        let key = "widget.codex-project-tracker.v6.card-order.\(page.rawValue)"
        guard let values = CodexV6Preferences.defaults.array(forKey: key) as? [String] else {
            return page.defaultCards
        }
        let decoded = values.compactMap(CodexV6CardID.init(rawValue:))
        let normalizedCards = normalized(decoded, for: page)
        let migratedCards = migrateNewOverviewCard(normalizedCards, page: page)
        if migratedCards != decoded {
            CodexV6Preferences.defaults.set(migratedCards.map(\.rawValue), forKey: key)
        }
        return migratedCards
    }

    static func save(_ cards: [CodexV6CardID], for page: CodexV6Page) {
        CodexV6Preferences.defaults.set(cards.map(\.rawValue), forKey: "widget.codex-project-tracker.v6.card-order.\(page.rawValue)")
    }

    static func normalized(_ cards: [CodexV6CardID], for page: CodexV6Page) -> [CodexV6CardID] {
        var result: [CodexV6CardID] = []
        for card in cards where page.defaultCards.contains(card) && !result.contains(card) {
            result.append(card)
        }
        for card in page.defaultCards where !result.contains(card) {
            result.append(card)
        }
        return result
    }

    private static func migrateNewOverviewCard(_ cards: [CodexV6CardID], page: CodexV6Page) -> [CodexV6CardID] {
        guard page == .overview,
              !CodexV6Preferences.defaults.bool(forKey: overviewModelControlsPlacementKey),
              cards.last == .modelControls
        else { return cards }

        CodexV6Preferences.defaults.set(true, forKey: overviewModelControlsPlacementKey)

        var result = cards
        result.removeAll { $0 == .modelControls }
        let insertionIndex = min((result.firstIndex(of: .quota) ?? -1) + 1, result.count)
        result.insert(.modelControls, at: insertionIndex)
        return result
    }
}

private struct CodexAnalyticsEvent: Codable, Equatable, Sendable {
    let timestamp: Date
    let model: String
    let reasoningEffort: String
    let projectName: String
    let usage: CodexTokenUsage

    var identity: String {
        [
            String(timestamp.timeIntervalSince1970),
            model,
            reasoningEffort,
            projectName,
            String(usage.inputTokens),
            String(usage.cachedInputTokens),
            String(usage.outputTokens),
            String(usage.reasoningOutputTokens),
        ].joined(separator: "|")
    }
}

private final class CodexAnalyticsCacheStore: @unchecked Sendable {
    static let shared = CodexAnalyticsCacheStore()

    private struct Document: Codable {
        let version: Int
        var events: [CodexAnalyticsEvent]
    }

    private let lock = NSLock()
    private var didLoad = false
    private var events: [CodexAnalyticsEvent] = []
    private let version = 1
    private let retention: TimeInterval = 30 * 24 * 60 * 60
    private let maximumEvents = 4_096

    func merge(_ samples: [CodexTokenBurnSample], now: Date) -> [CodexAnalyticsEvent] {
        lock.lock()
        defer { lock.unlock() }

        loadIfNeeded()
        let cutoff = now.addingTimeInterval(-retention)
        var known = Set(events.map(\.identity))
        for sample in samples {
            let event = CodexAnalyticsEvent(
                timestamp: sample.timestamp,
                model: sample.model,
                reasoningEffort: sample.reasoningEffort,
                projectName: sample.projectName ?? "Unknown project",
                usage: sample.usage
            )
            guard event.timestamp >= cutoff, known.insert(event.identity).inserted else { continue }
            events.append(event)
        }
        events = Array(events.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }.suffix(maximumEvents))
        save()
        return events
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: Self.cacheURL()),
              let document = try? JSONDecoder().decode(Document.self, from: data),
              document.version == version
        else { return }
        events = document.events
    }

    private func save() {
        let document = Document(version: version, events: events)
        guard let data = try? JSONEncoder().encode(document) else { return }
        let url = Self.cacheURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func cacheURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("DockDoorPro/CodexProjectTracker", isDirectory: true)
            .appendingPathComponent("analytics-v6.json", isDirectory: false)
    }
}

private final class CodexQuotaPaceHistoryStore: @unchecked Sendable {
    static let shared = CodexQuotaPaceHistoryStore()

    private struct Point: Codable {
        let timestamp: Date
        let usedFraction: Double
        let resetAt: Date?
    }

    private struct Document: Codable {
        let version: Int
        var points: [Point]
    }

    private let lock = NSLock()
    private var didLoad = false
    private var points: [Point] = []
    private let retention: TimeInterval = 45 * 24 * 60 * 60

    func record(usage: CodexUsageSnapshot, now: Date) -> CodexV6QuotaPace? {
        guard usage.source != "Loading", usage.source != "No account snapshot", usage.lastUpdated != nil else { return nil }

        lock.lock()
        defer { lock.unlock() }
        loadIfNeeded()

        let current = Point(
            timestamp: now,
            usedFraction: min(max(1 - usage.percentRemaining, 0), 1),
            resetAt: usage.resetDate
        )
        let previous = points.last
        if previous == nil || now.timeIntervalSince(previous!.timestamp) >= 60 {
            points.append(current)
        }
        points = points.filter { now.timeIntervalSince($0.timestamp) <= retention }
        points = Array(points.suffix(512))
        save()

        guard let previous, let latest = points.last, latest.timestamp > previous.timestamp else {
            return CodexV6QuotaPace(
                usedPercent: current.usedFraction * 100,
                percentPerHour: nil,
                projectedExhaustionAt: nil,
                resetAt: usage.resetDate,
                willLastToReset: nil,
                sampleCount: points.count
            )
        }

        let hours = latest.timestamp.timeIntervalSince(previous.timestamp) / 3600
        let percentPerHour = hours > 0
            ? max(0, (latest.usedFraction - previous.usedFraction) * 100 / hours)
            : nil
        let projected = percentPerHour.flatMap { rate -> Date? in
            guard rate > 0.001 else { return nil }
            return now.addingTimeInterval(max(0, (100 - latest.usedFraction * 100) / rate) * 3600)
        }
        let willLast: Bool? = if let projected, let reset = usage.resetDate { projected >= reset } else { nil }

        return CodexV6QuotaPace(
            usedPercent: latest.usedFraction * 100,
            percentPerHour: percentPerHour,
            projectedExhaustionAt: projected,
            resetAt: usage.resetDate,
            willLastToReset: willLast,
            sampleCount: points.count
        )
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: Self.cacheURL()),
              let document = try? JSONDecoder().decode(Document.self, from: data),
              document.version == 1
        else { return }
        points = document.points
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(Document(version: 1, points: points)) else { return }
        let url = Self.cacheURL()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static func cacheURL() -> URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("DockDoorPro/CodexProjectTracker", isDirectory: true)
            .appendingPathComponent("quota-pace-v6.json", isDirectory: false)
    }
}

private enum CodexOfficialActivityReader {
    private struct Bucket: Decodable {
        let startDate: String?
        let tokens: Int64?

        enum CodingKeys: String, CodingKey {
            case startDate = "start_date"
            case tokens
        }
    }

    private struct Payload: Decodable {
        let lifetimeTokens: Int64?
        let peakDailyTokens: Int64?
        let currentStreakDays: Int?
        let longestStreakDays: Int?
        let dailyUsageBuckets: [Bucket]?

        enum CodingKeys: String, CodingKey {
            case lifetimeTokens = "lifetime_tokens"
            case peakDailyTokens = "peak_daily_tokens"
            case currentStreakDays = "current_streak_days"
            case longestStreakDays = "longest_streak_days"
            case dailyUsageBuckets = "daily_usage_buckets"
        }
    }

    private struct Envelope: Decodable {
        let officialUsage: Payload?
        let accountUsage: Payload?
        let summary: Payload?
        let lifetimeTokens: Int64?
        let peakDailyTokens: Int64?
        let currentStreakDays: Int?
        let longestStreakDays: Int?
        let dailyUsageBuckets: [Bucket]?

        enum CodingKeys: String, CodingKey {
            case officialUsage
            case accountUsage
            case summary
            case lifetimeTokens = "lifetime_tokens"
            case peakDailyTokens = "peak_daily_tokens"
            case currentStreakDays = "current_streak_days"
            case longestStreakDays = "longest_streak_days"
            case dailyUsageBuckets = "daily_usage_buckets"
        }
    }

    static func read() -> CodexOfficialActivitySnapshot? {
        let path = WidgetDefaults.string(
            key: "usageStatePath",
            widgetId: "codex-project-tracker",
            default: "~/.codex/usage.json"
        )
        let url = URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data)
        else { return nil }

        let payload = envelope.officialUsage ?? envelope.accountUsage ?? envelope.summary
        let lifetime = payload?.lifetimeTokens ?? envelope.lifetimeTokens
        let peak = payload?.peakDailyTokens ?? envelope.peakDailyTokens
        let currentStreak = payload?.currentStreakDays ?? envelope.currentStreakDays
        let longestStreak = payload?.longestStreakDays ?? envelope.longestStreakDays
        let buckets = payload?.dailyUsageBuckets ?? envelope.dailyUsageBuckets ?? []
        let daily = buckets.compactMap { bucket -> CodexAnalyticsDay? in
            guard let key = bucket.startDate, let tokens = bucket.tokens else { return nil }
            return CodexAnalyticsDay(dayKey: key, tokens: max(tokens, 0), eventCount: 0, estimatedCostUSD: nil)
        }

        let snapshot = CodexOfficialActivitySnapshot(
            lifetimeTokens: lifetime,
            peakDailyTokens: peak,
            currentStreakDays: currentStreak,
            longestStreakDays: longestStreak,
            daily: daily
        )
        return snapshot.hasData ? snapshot : nil
    }
}

enum CodexV6WorkspaceHealthReader {
    static func read(sessions: [CodexSession]) -> CodexV6WorkspaceHealth {
        var projectURLs: [URL] = []
        var seenPaths = Set<String>()

        for session in sessions {
            let url = session.projectURL.standardizedFileURL
            guard seenPaths.insert(url.path).inserted else { continue }
            projectURLs.append(url)
            if projectURLs.count == 8 { break }
        }

        var repositoryCount = 0
        var dirtyRepositoryCount = 0
        var dirtyFileCount = 0
        var activeBranch: String?

        for url in projectURLs {
            guard let status = gitStatus(at: url) else { continue }
            repositoryCount += 1
            dirtyFileCount += status.dirtyFileCount
            if status.dirtyFileCount > 0 {
                dirtyRepositoryCount += 1
            }
            if activeBranch == nil {
                activeBranch = status.branch
            }
        }

        return CodexV6WorkspaceHealth(
            checkedProjectCount: projectURLs.count,
            repositoryCount: repositoryCount,
            dirtyRepositoryCount: dirtyRepositoryCount,
            dirtyFileCount: dirtyFileCount,
            activeProject: sessions.first(where: \.isActive)?.projectName ?? sessions.first?.projectName,
            activeBranch: activeBranch
        )
    }

    private static func gitStatus(at url: URL) -> (branch: String?, dirtyFileCount: Int)? {
        let output = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = [
            "-C", url.path,
            "status",
            "--porcelain=v1",
            "--branch",
            "--untracked-files=normal",
        ]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            guard process.terminationStatus == 0,
                  let text = String(data: data, encoding: .utf8)
            else { return nil }

            let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
            let branch = lines.first(where: { $0.hasPrefix("## ") })?
                .dropFirst(3)
                .split(separator: "...", maxSplits: 1, omittingEmptySubsequences: true)
                .first
                .map(String.init)
            let dirtyFileCount = lines.filter { !$0.hasPrefix("## ") }.count
            return (branch, dirtyFileCount)
        } catch {
            return nil
        }
    }
}

enum CodexV6AnalyticsBuilder {
    static func build(
        telemetry: CodexTokenTelemetry,
        usage: CodexUsageSnapshot,
        sessions: [CodexSession],
        now: Date = Date()
    ) -> CodexV6AnalyticsSnapshot {
        let cachedEvents = CodexAnalyticsCacheStore.shared.merge(telemetry.samples, now: now)
        let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 60 * 60)
        let sevenDaysAgo = now.addingTimeInterval(-7 * 24 * 60 * 60)
        let todayStart = Calendar.current.startOfDay(for: now)
        let events = cachedEvents.filter { $0.timestamp >= thirtyDaysAgo && $0.timestamp <= now }

        var days: [String: (tokens: Int64, count: Int, cost: Double)] = [:]
        var hours: [String: (weekday: Int, hour: Int, tokens: Int64, count: Int)] = [:]
        var models: [String: (model: String, effort: String, tokens: Int64, count: Int, cost: Double)] = [:]
        var projects: [String: (tokens: Int64, count: Int, sessions: Int)] = [:]
        var totalCost = 0.0

        for event in events {
            let tokens = max(event.usage.effectiveTotalTokens, 0)
            let cost = estimateCost(for: event)
            totalCost += cost
            let dayKey = dayKey(for: event.timestamp)
            let day = days[dayKey] ?? (0, 0, 0)
            days[dayKey] = (day.tokens + tokens, day.count + 1, day.cost + cost)

            if event.timestamp >= sevenDaysAgo {
                let calendar = Calendar.current
                let weekday = calendar.component(.weekday, from: event.timestamp)
                let hour = calendar.component(.hour, from: event.timestamp)
                let key = "\(weekday)-\(hour)"
                let existing = hours[key] ?? (weekday, hour, 0, 0)
                hours[key] = (weekday, hour, existing.tokens + tokens, existing.count + 1)
            }

            let modelKey = "\(event.model)|\(event.reasoningEffort)"
            let model = models[modelKey] ?? (event.model, event.reasoningEffort, 0, 0, 0)
            models[modelKey] = (model.model, model.effort, model.tokens + tokens, model.count + 1, model.cost + cost)

            let project = projects[event.projectName] ?? (0, 0, 0)
            projects[event.projectName] = (project.tokens + tokens, project.count + 1, project.sessions)
        }

        for session in sessions {
            let project = projects[session.projectName] ?? (0, 0, 0)
            projects[session.projectName] = (project.tokens, project.count, project.sessions + 1)
        }

        let daily = days.map { CodexAnalyticsDay(dayKey: $0.key, tokens: $0.value.tokens, eventCount: $0.value.count, estimatedCostUSD: $0.value.cost) }
            .sorted { $0.dayKey < $1.dayKey }
        let hourly = hours.values.map { CodexAnalyticsHour(weekday: $0.weekday, hour: $0.hour, tokens: $0.tokens, eventCount: $0.count) }
            .sorted { $0.id < $1.id }
        let modelBreakdowns = models.values.map {
            CodexAnalyticsModel(model: $0.model, reasoningEffort: $0.effort, tokens: $0.tokens, eventCount: $0.count, estimatedCostUSD: $0.cost)
        }
        .sorted { $0.tokens > $1.tokens }
        let projectBreakdowns = projects.map {
            CodexAnalyticsProject(name: $0.key, tokens: $0.value.tokens, eventCount: $0.value.count, sessionCount: $0.value.sessions)
        }
        .sorted { $0.tokens != $1.tokens ? $0.tokens > $1.tokens : $0.name < $1.name }

        let todayTokens = events.filter { $0.timestamp >= todayStart }.reduce(Int64(0)) { $0 + max($1.usage.effectiveTotalTokens, 0) }
        let last7Tokens = events.filter { $0.timestamp >= sevenDaysAgo }.reduce(Int64(0)) { $0 + max($1.usage.effectiveTotalTokens, 0) }
        let contextWindow = telemetry.latestContextWindow
        let contextPercent: Double? = if let context = telemetry.latestContextUsage, let window = contextWindow, window > 0 {
            min(max(Double(context.effectiveTotalTokens) / Double(window), 0), 1)
        } else { nil }
        let peakContextPercent: Double? = if let window = contextWindow, window > 0 {
            min(max(Double(telemetry.peakContextTokens) / Double(window), 0), 1)
        } else { nil }

        let official = CodexOfficialActivityReader.read()
        let quotaPace = CodexQuotaPaceHistoryStore.shared.record(usage: usage, now: now)
        let workspaceHealth = CodexV6WorkspaceHealthReader.read(sessions: sessions)
        let accountHealthy = usage.source != "Loading" && usage.source != "No account snapshot"
        let statuses = [
            CodexAnalyticsSourceStatus(
                id: "local-events",
                title: "Local token events",
                state: events.isEmpty ? "Waiting" : "Ready",
                detail: events.isEmpty ? "No recent token events found" : "\(events.count) events in the 30-day window"
            ),
            CodexAnalyticsSourceStatus(
                id: "incremental-cache",
                title: "Incremental cache",
                state: cachedEvents.isEmpty ? "Waiting" : "Ready",
                detail: cachedEvents.isEmpty ? "Cache will populate after the first refresh" : "Bounded local cache · \(cachedEvents.count) events"
            ),
            CodexAnalyticsSourceStatus(
                id: "account-quota",
                title: "Account quota",
                state: accountHealthy ? "Ready" : "Unavailable",
                detail: usage.source
            ),
            CodexAnalyticsSourceStatus(
                id: "official-activity",
                title: "Official activity",
                state: official == nil ? "Optional" : "Ready",
                detail: official == nil ? "Not exposed by the current local usage file" : "Read-only aggregate activity"
            ),
        ]

        return CodexV6AnalyticsSnapshot(
            todayTokens: todayTokens,
            last7DaysTokens: last7Tokens,
            last30DaysTokens: events.reduce(Int64(0)) { $0 + max($1.usage.effectiveTotalTokens, 0) },
            daily: daily,
            hourly: hourly,
            models: modelBreakdowns,
            projects: projectBreakdowns,
            contextPercent: contextPercent,
            peakContextPercent: peakContextPercent,
            burnPerMinute: telemetry.tokensPerMinute(window: 60, now: now),
            estimatedCostUSD: events.isEmpty ? nil : totalCost,
            costCoverage: events.isEmpty ? 0 : 1,
            quotaPace: quotaPace,
            officialActivity: official,
            sourceStatuses: statuses,
            cachedEventCount: cachedEvents.count,
            dailyGoalTokens: configuredDailyGoalTokens(),
            workspaceHealth: workspaceHealth,
            updatedAt: maxDate(telemetry.updatedAt, usage.lastUpdated)
        )
    }

    private static func configuredDailyGoalTokens() -> Int64 {
        let millions = WidgetDefaults.double(
            key: "dailyGoalMillions",
            widgetId: "codex-project-tracker",
            default: 2
        )
        return Int64(max(0.5, min(millions, 100)) * 1_000_000)
    }

    private static func estimateCost(for event: CodexAnalyticsEvent) -> Double {
        let model = event.model.lowercased()
        let inputRate: Double
        let outputRate: Double
        if model.contains("luna") {
            inputRate = 1e-6
            outputRate = 6e-6
        } else if model.contains("terra") {
            inputRate = 2.5e-6
            outputRate = 1.5e-5
        } else {
            inputRate = 5e-6
            outputRate = 3e-5
        }
        let input = max(event.usage.inputTokens - event.usage.cachedInputTokens, 0)
        return Double(input) * inputRate + Double(max(event.usage.outputTokens, 0)) * outputRate
    }

    private static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (lhs?, rhs?): return max(lhs, rhs)
        case let (lhs?, nil): return lhs
        case let (nil, rhs?): return rhs
        case (nil, nil): return nil
        }
    }
}
