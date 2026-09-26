import Foundation

/// Token fields emitted by Codex in a session `token_count` event.
///
/// These are observed local session values. They describe the work recorded in
/// the local transcript and are intentionally kept separate from account-limit
/// percentages supplied by the live sync companion.
struct CodexTokenUsage: Codable, Equatable, Sendable {
    let inputTokens: Int64
    let cachedInputTokens: Int64
    let cacheWriteInputTokens: Int64
    let outputTokens: Int64
    let reasoningOutputTokens: Int64
    let totalTokens: Int64

    init(
        inputTokens: Int64 = 0,
        cachedInputTokens: Int64 = 0,
        cacheWriteInputTokens: Int64 = 0,
        outputTokens: Int64 = 0,
        reasoningOutputTokens: Int64 = 0,
        totalTokens: Int64? = nil
    ) {
        self.inputTokens = max(0, inputTokens)
        self.cachedInputTokens = max(0, cachedInputTokens)
        self.cacheWriteInputTokens = max(0, cacheWriteInputTokens)
        self.outputTokens = max(0, outputTokens)
        self.reasoningOutputTokens = max(0, reasoningOutputTokens)
        self.totalTokens = max(0, totalTokens ?? inputTokens + outputTokens)
    }

    static let zero = CodexTokenUsage()

    private enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cachedInputTokens = "cached_input_tokens"
        case cacheWriteInputTokens = "cache_write_input_tokens"
        case outputTokens = "output_tokens"
        case reasoningOutputTokens = "reasoning_output_tokens"
        case totalTokens = "total_tokens"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let input = container.decodeFlexibleInt64(forKey: .inputTokens) ?? 0
        let cached = container.decodeFlexibleInt64(forKey: .cachedInputTokens) ?? 0
        let cacheWrite = container.decodeFlexibleInt64(forKey: .cacheWriteInputTokens) ?? 0
        let output = container.decodeFlexibleInt64(forKey: .outputTokens) ?? 0
        let reasoning = container.decodeFlexibleInt64(forKey: .reasoningOutputTokens) ?? 0
        let total = container.decodeFlexibleInt64(forKey: .totalTokens)

        self.init(
            inputTokens: input,
            cachedInputTokens: cached,
            cacheWriteInputTokens: cacheWrite,
            outputTokens: output,
            reasoningOutputTokens: reasoning,
            totalTokens: total
        )
    }

    /// Some older Codex events omit `total_tokens`; retain a useful fallback.
    var effectiveTotalTokens: Int64 {
        totalTokens > 0 ? totalTokens : inputTokens + outputTokens
    }

    var hasUsage: Bool {
        effectiveTotalTokens > 0 || cachedInputTokens > 0 || cacheWriteInputTokens > 0
    }

    func adding(_ other: CodexTokenUsage) -> CodexTokenUsage {
        CodexTokenUsage(
            inputTokens: inputTokens + other.inputTokens,
            cachedInputTokens: cachedInputTokens + other.cachedInputTokens,
            cacheWriteInputTokens: cacheWriteInputTokens + other.cacheWriteInputTokens,
            outputTokens: outputTokens + other.outputTokens,
            reasoningOutputTokens: reasoningOutputTokens + other.reasoningOutputTokens,
            totalTokens: effectiveTotalTokens + other.effectiveTotalTokens
        )
    }

    /// Returns the positive delta between two cumulative session snapshots.
    /// A nil result means that the current event has no usable increase.
    func delta(from previous: CodexTokenUsage) -> CodexTokenUsage? {
        let total = effectiveTotalTokens - previous.effectiveTotalTokens
        let input = inputTokens - previous.inputTokens
        let cached = cachedInputTokens - previous.cachedInputTokens
        let cacheWrite = cacheWriteInputTokens - previous.cacheWriteInputTokens
        let output = outputTokens - previous.outputTokens
        let reasoning = reasoningOutputTokens - previous.reasoningOutputTokens

        guard total >= 0, input >= 0, cached >= 0, cacheWrite >= 0, output >= 0, reasoning >= 0 else {
            return nil
        }

        let result = CodexTokenUsage(
            inputTokens: input,
            cachedInputTokens: cached,
            cacheWriteInputTokens: cacheWrite,
            outputTokens: output,
            reasoningOutputTokens: reasoning,
            totalTokens: total
        )
        return result.hasUsage ? result : nil
    }

    static func compactLabel(_ value: Int64) -> String {
        let number = Double(max(value, 0))
        if number >= 1_000_000_000 {
            return String(format: "%.1fB", number / 1_000_000_000)
        }
        if number >= 1_000_000 {
            return String(format: "%.1fM", number / 1_000_000)
        }
        if number >= 1_000 {
            return String(format: "%.1fK", number / 1_000)
        }
        return String(Int(number))
    }

    static func rateLabel(_ tokensPerMinute: Double?) -> String {
        guard let tokensPerMinute, tokensPerMinute.isFinite, tokensPerMinute > 0 else {
            return "—"
        }
        return compactLabel(Int64(tokensPerMinute.rounded())) + " / min"
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt64(forKey key: Key) -> Int64? {
        if let value = try? decodeIfPresent(Int64.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite {
            return Int64(value.rounded())
        }
        if let value = try? decodeIfPresent(String.self, forKey: key),
           let number = Int64(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return number
        }
        return nil
    }
}

struct CodexTokenLogEnvelope: Decodable {
    let timestamp: String?
    let ordinal: Int64?
    let type: String?
    let payload: Payload?

    struct Payload: Decodable {
        let type: String?
        let info: Info?
        let threadSettings: ThreadSettings?
        let model: String?
        let effort: String?
        let reasoningEffort: String?
        let collaborationMode: CollaborationMode?

        enum CodingKeys: String, CodingKey {
            case type
            case info
            case threadSettings = "thread_settings"
            case model
            case effort
            case reasoningEffort = "reasoning_effort"
            case collaborationMode = "collaboration_mode"
        }

        struct CollaborationMode: Decodable {
            let settings: Settings?

            struct Settings: Decodable {
                let model: String?
                let reasoningEffort: String?

                enum CodingKeys: String, CodingKey {
                    case model
                    case reasoningEffort = "reasoning_effort"
                }
            }
        }

        var contextModel: String? {
            model ?? collaborationMode?.settings?.model
        }

        var contextEffort: String? {
            effort ?? reasoningEffort ?? collaborationMode?.settings?.reasoningEffort
        }
    }

    struct Info: Decodable {
        let lastTokenUsage: CodexTokenUsage?
        let totalTokenUsage: CodexTokenUsage?
        let modelContextWindow: Int64?

        enum CodingKeys: String, CodingKey {
            case lastTokenUsage = "last_token_usage"
            case totalTokenUsage = "total_token_usage"
            case modelContextWindow = "model_context_window"
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            lastTokenUsage = try container.decodeIfPresent(CodexTokenUsage.self, forKey: .lastTokenUsage)
            totalTokenUsage = try container.decodeIfPresent(CodexTokenUsage.self, forKey: .totalTokenUsage)
            modelContextWindow = container.decodeFlexibleInt64(forKey: .modelContextWindow)
        }
    }

    struct ThreadSettings: Decodable {
        let model: String?
        let reasoningEffort: String?

        enum CodingKeys: String, CodingKey {
            case model
            case reasoningEffort = "reasoning_effort"
        }
    }
}

/// A source abstraction keeps parsing testable without requiring a real home
/// directory. Production callers provide `url`; fixtures provide `contents`.
struct CodexTokenLogSource {
    let id: String
    let projectName: String
    let url: URL?
    let contents: String?
    let modified: Date

    init(id: String, projectName: String, contents: String, modified: Date = .distantPast) {
        self.id = id
        self.projectName = projectName
        self.url = nil
        self.contents = contents
        self.modified = modified
    }

    init(id: String, projectName: String, url: URL, modified: Date) {
        self.id = id
        self.projectName = projectName
        self.url = url
        self.contents = nil
        self.modified = modified
    }
}

struct CodexTokenBurnSample: Identifiable, Equatable, Sendable {
    let id: String
    let timestamp: Date
    let usage: CodexTokenUsage
    let model: String
    let reasoningEffort: String
    let contextWindow: Int64?
    let projectName: String?

    init(
        id: String,
        timestamp: Date,
        usage: CodexTokenUsage,
        model: String,
        reasoningEffort: String,
        contextWindow: Int64?,
        projectName: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.usage = usage
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.contextWindow = contextWindow
        self.projectName = projectName
    }
}

struct CodexTokenModelBreakdown: Identifiable, Equatable, Sendable {
    let model: String
    let reasoningEffort: String
    let usage: CodexTokenUsage
    let turnCount: Int
    let lastUpdated: Date?

    var id: String { "\(model)|\(reasoningEffort)" }

    var modelLabel: String {
        CodexModelIdentity.label(model)
    }

    var reasoningLabel: String {
        switch reasoningEffort.lowercased() {
        case "low", "instant": return "Light"
        case "max": return "Max"
        case "", "unknown": return "Unknown reasoning"
        default: return reasoningEffort.prefix(1).uppercased() + reasoningEffort.dropFirst()
        }
    }
}

struct CodexTokenTelemetry: Equatable, Sendable {
    let observedUsage: CodexTokenUsage
    let todayUsage: CodexTokenUsage
    let windowUsage: CodexTokenUsage
    let latestDelta: CodexTokenUsage?
    let latestContextUsage: CodexTokenUsage?
    let latestContextWindow: Int64?
    let peakContextTokens: Int64
    let samples: [CodexTokenBurnSample]
    let modelBreakdowns: [CodexTokenModelBreakdown]
    let currentModel: String?
    let currentReasoningEffort: String?
    let updatedAt: Date?
    let sessionCount: Int
    let eventCount: Int
    let attributedEventCount: Int

    static let empty = CodexTokenTelemetry(
        observedUsage: .zero,
        todayUsage: .zero,
        windowUsage: .zero,
        latestDelta: nil,
        latestContextUsage: nil,
        latestContextWindow: nil,
        peakContextTokens: 0,
        samples: [],
        modelBreakdowns: [],
        currentModel: nil,
        currentReasoningEffort: nil,
        updatedAt: nil,
        sessionCount: 0,
        eventCount: 0,
        attributedEventCount: 0
    )

    var hasData: Bool { observedUsage.hasUsage || latestContextUsage?.hasUsage == true }

    var contextPercent: Double? {
        guard let context = latestContextUsage,
              let window = latestContextWindow,
              window > 0 else { return nil }
        return min(max(Double(context.effectiveTotalTokens) / Double(window), 0), 1)
    }

    func tokensPerMinute(window: TimeInterval, now: Date) -> Double? {
        guard window > 0 else { return nil }
        let cutoff = now.addingTimeInterval(-window)
        let total = samples
            .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            .reduce(Int64(0)) { $0 + $1.usage.effectiveTotalTokens }
        guard total > 0 else { return nil }
        return Double(total) / window * 60
    }

    func outputTokensPerMinute(window: TimeInterval, now: Date) -> Double? {
        guard window > 0 else { return nil }
        let cutoff = now.addingTimeInterval(-window)
        let total = samples
            .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
            .reduce(Int64(0)) { $0 + $1.usage.outputTokens }
        guard total > 0 else { return nil }
        return Double(total) / window * 60
    }

    func freshnessLabel(now: Date) -> String {
        guard let updatedAt else { return "Waiting for token events" }
        let age = max(0, now.timeIntervalSince(updatedAt))
        if age < 15 { return "Live · updated just now" }
        if age < 120 { return "Updated \(Int(age.rounded()))s ago" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Stale · \(formatter.localizedString(for: updatedAt, relativeTo: now))"
    }

    var contextLabel: String {
        guard let contextPercent else { return "—" }
        return "\(Int((contextPercent * 100).rounded()))%"
    }

    var currentModelLabel: String {
        CodexModelIdentity.label(currentModel)
    }

    var currentReasoningLabel: String {
        switch currentReasoningEffort?.lowercased() {
        case "low", "instant": return "Light"
        case "max": return "Max"
        case let value? where !value.isEmpty: return value.prefix(1).uppercased() + value.dropFirst()
        default: return "Unknown reasoning"
        }
    }

    func burnLabel(now: Date) -> String {
        CodexTokenUsage.rateLabel(tokensPerMinute(window: 60, now: now))
    }

    func shortSummary(now: Date) -> String {
        let model = currentModelLabel
        let effort = currentReasoningLabel
        let burn = burnLabel(now: now)
        return "\(model) · \(effort) · \(burn)"
    }
}

enum CodexTokenTelemetryReader {
    private static let maxFileBytes: UInt64 = 768 * 1024
    private static let headBytes: UInt64 = 384 * 1024
    private static let maxChartSamples = 48
    private static let maxTelemetrySessions = 64

    static func read(
        sources: [CodexTokenLogSource],
        now: Date = Date(),
        windowHours: Double = 5
    ) -> CodexTokenTelemetry {
        var observed = CodexTokenUsage.zero
        var today = CodexTokenUsage.zero
        var window = CodexTokenUsage.zero
        let windowStart = now.addingTimeInterval(-max(1, windowHours) * 3600)
        var allSamples: [CodexTokenBurnSample] = []
        var breakdowns: [String: (usage: CodexTokenUsage, turns: Int, lastUpdated: Date?)] = [:]
        var latestContext: (date: Date, usage: CodexTokenUsage, window: Int64?, model: String, effort: String)?
        var latestDelta: (date: Date, usage: CodexTokenUsage)?
        var peakContext: Int64 = 0
        var eventCount = 0
        var attributedEventCount = 0
        var sessionsWithEvents = Set<String>()

        for source in sources.prefix(maxTelemetrySessions) {
            let segments = logSegments(for: source)
            var model = "unknown"
            var effort = "unknown"
            var contextWindow: Int64?
            var previousCumulative: CodexTokenUsage?
            var seenKeys = Set<String>()

            for (segmentIndex, lines) in segments.enumerated() {
                // A large file is represented by a head and a tail. The first
                // tail event is a new baseline; counting its jump would assign
                // an unknown middle section to the current model.
                previousCumulative = nil

                for line in lines {
                    guard let data = line.data(using: .utf8),
                          let envelope = try? JSONDecoder().decode(CodexTokenLogEnvelope.self, from: data),
                          let payload = envelope.payload
                    else { continue }

                    // Current Codex sessions record the active model and
                    // reasoning level on `turn_context`, rather than emitting
                    // the older `thread_settings_applied` event.
                    if envelope.type == "turn_context" {
                        if let value = payload.contextModel?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                            model = value
                        }
                        if let value = payload.contextEffort?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                            effort = value.lowercased()
                        }
                        continue
                    }

                    guard envelope.type == "event_msg", let payloadType = payload.type else { continue }

                    if payloadType == "thread_settings_applied" {
                        if let value = payload.threadSettings?.model?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                            model = value
                        }
                        if let value = payload.threadSettings?.reasoningEffort?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
                            effort = value.lowercased()
                        }
                        continue
                    }

                    guard payloadType == "token_count", let info = payload.info else { continue }
                    let timestamp = parseDate(envelope.timestamp) ?? source.modified
                    let eventKey = "\(source.id)|\(envelope.ordinal.map(String.init) ?? "\(timestamp.timeIntervalSince1970)|\(info.totalTokenUsage?.effectiveTotalTokens ?? info.lastTokenUsage?.effectiveTotalTokens ?? 0)")"
                    guard seenKeys.insert(eventKey).inserted else { continue }
                    eventCount += 1
                    sessionsWithEvents.insert(source.id)

                    if let current = info.lastTokenUsage {
                        if let value = info.modelContextWindow {
                            contextWindow = value
                        }
                        if latestContext == nil || timestamp >= latestContext!.date {
                            latestContext = (timestamp, current, contextWindow, model, effort)
                        }
                        peakContext = max(peakContext, current.effectiveTotalTokens)
                    }

                    guard let cumulative = info.totalTokenUsage ?? info.lastTokenUsage else { continue }

                    let delta: CodexTokenUsage?
                    if let previousCumulative {
                        delta = cumulative.delta(from: previousCumulative)
                    } else if segmentIndex == 0 && segments.count == 1 {
                        // A complete small file starts at the beginning of the
                        // session, so its first cumulative snapshot is usable.
                        delta = cumulative.hasUsage ? cumulative : nil
                    } else {
                        delta = nil
                    }
                    previousCumulative = cumulative

                    guard let delta, delta.hasUsage else { continue }
                    attributedEventCount += 1
                    observed = observed.adding(delta)
                    if Calendar.current.isDate(timestamp, inSameDayAs: now) {
                        today = today.adding(delta)
                    }
                    if timestamp >= windowStart && timestamp <= now {
                        window = window.adding(delta)
                    }

                    let sample = CodexTokenBurnSample(
                        id: eventKey,
                        timestamp: timestamp,
                        usage: delta,
                        model: model,
                        reasoningEffort: effort,
                        contextWindow: contextWindow,
                        projectName: source.projectName
                    )
                    allSamples.append(sample)

                    let key = "\(model)|\(effort)"
                    let existing = breakdowns[key] ?? (usage: .zero, turns: 0, lastUpdated: nil)
                    breakdowns[key] = (
                        usage: existing.usage.adding(delta),
                        turns: existing.turns + 1,
                        lastUpdated: maxDate(existing.lastUpdated, timestamp)
                    )

                    if latestDelta == nil || timestamp >= latestDelta!.date {
                        latestDelta = (timestamp, delta)
                    }
                }
            }
        }

        let sortedSamples = allSamples.sorted { $0.timestamp < $1.timestamp }
        let modelBreakdowns = breakdowns.map { key, value in
            let components = key.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            return CodexTokenModelBreakdown(
                model: components.first ?? "unknown",
                reasoningEffort: components.count > 1 ? components[1] : "unknown",
                usage: value.usage,
                turnCount: value.turns,
                lastUpdated: value.lastUpdated
            )
        }
        .sorted {
            if $0.usage.effectiveTotalTokens != $1.usage.effectiveTotalTokens {
                return $0.usage.effectiveTotalTokens > $1.usage.effectiveTotalTokens
            }
            return $0.id < $1.id
        }

        let currentModel = latestContext?.model
        let currentEffort = latestContext?.effort
        let recentSamples = Array(sortedSamples.suffix(maxChartSamples))

        return CodexTokenTelemetry(
            observedUsage: observed,
            todayUsage: today,
            windowUsage: window,
            latestDelta: latestDelta?.usage,
            latestContextUsage: latestContext?.usage,
            latestContextWindow: latestContext?.window,
            peakContextTokens: peakContext,
            samples: recentSamples,
            modelBreakdowns: modelBreakdowns,
            currentModel: currentModel,
            currentReasoningEffort: currentEffort,
            updatedAt: latestContext?.date,
            sessionCount: sessionsWithEvents.count,
            eventCount: eventCount,
            attributedEventCount: attributedEventCount
        )
    }

    private static func logSegments(for source: CodexTokenLogSource) -> [[Substring]] {
        let text: String
        if let contents = source.contents {
            text = contents
        } else if let url = source.url,
                  let segments = readSegments(from: url) {
            return segments.map { $0.split(separator: "\n") }
        } else {
            return []
        }
        return [text.split(separator: "\n")]
    }

    private static func readSegments(from url: URL) -> [String]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }

        let fileSize = (try? handle.seekToEnd()) ?? 0
        if fileSize <= maxFileBytes {
            try? handle.seek(toOffset: 0)
            guard let data = try? handle.read(upToCount: Int(fileSize)),
                  let text = String(data: data, encoding: .utf8) else { return nil }
            return [text]
        }

        try? handle.seek(toOffset: 0)
        guard let headData = try? handle.read(upToCount: Int(headBytes)) else { return nil }
        let tailSize = min(fileSize, maxFileBytes - headBytes)
        try? handle.seek(toOffset: fileSize - tailSize)
        guard let tailData = try? handle.read(upToCount: Int(tailSize)),
              let head = String(data: headData, encoding: .utf8),
              let tail = String(data: tailData, encoding: .utf8) else { return nil }
        return [head, tail]
    }

    private static func parseDate(_ value: String?) -> Date? {
        guard let value else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: value) ?? ISO8601DateFormatter().date(from: value)
    }

    private static func maxDate(_ lhs: Date?, _ rhs: Date) -> Date {
        guard let lhs else { return rhs }
        return max(lhs, rhs)
    }
}
