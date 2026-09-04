import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

actor CodexSnapshotBuildCache {
    private var signature: String?
    private var snapshot: CodexSnapshot?

    func cachedSnapshot(for signature: String) -> CodexSnapshot? {
        self.signature == signature ? snapshot : nil
    }

    func store(_ snapshot: CodexSnapshot, for signature: String) {
        self.signature = signature
        self.snapshot = snapshot
    }
}

enum CodexTrackerStore {
    private static let maxIndexedSessions = 500

    static let defaultProjectsRoot = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/sessions")

    private static let codexHome = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex")

    private static let snapshotCache = CodexSnapshotBuildCache()

    static func snapshot(forceRefresh: Bool = false) async -> CodexSnapshot {
        let signature = await Task.detached(priority: .utility) { inputSignature() }.value
        if !forceRefresh {
            if let cached = await snapshotCache.cachedSnapshot(for: signature) {
                return cached
            }
        }

        let refreshed = await Task.detached(priority: .utility) {
            buildSnapshot()
        }.value

        await snapshotCache.store(refreshed, for: signature)
        return refreshed
    }

    private static func inputSignature() -> String {
        let sessionsRoot = configuredProjectsRoot()
        let files = sessionFiles(in: sessionsRoot)
        let sessionStamp = files.prefix(maxIndexedSessions)
            .map { "\($0.url.path):\($0.modified.timeIntervalSince1970)" }
            .joined(separator: "|")
        let historyStamp = modificationStamp(codexHome.appendingPathComponent("history.jsonl"))
        let usageStamp = modificationStamp(configuredUsageURL())
        let configStamp = modificationStamp(
            URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".codex/config.toml")
        )
        let settingsStamp = [
            "\(recentLimit())",
            "\(usageBudgetTokens())",
            "\(usageWindowHours())",
            sessionsRoot.path,
            primaryCardSetting(),
        ].joined(separator: ":")

        let freshnessBucket = Int(Date().timeIntervalSince1970 / 60)
        return "\(sessionStamp)|history=\(historyStamp)|usage=\(usageStamp)|config=\(configStamp)|settings=\(settingsStamp)|freshness=\(freshnessBucket)"
    }

    private static func modificationStamp(_ url: URL) -> String {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        let modified = values?.contentModificationDate?.timeIntervalSince1970 ?? 0
        let size = values?.fileSize ?? 0
        return "\(modified):\(size)"
    }

    private static func buildSnapshot() -> CodexSnapshot {
        let sessionsRoot = configuredProjectsRoot()
        let sessionFiles = sessionFiles(in: sessionsRoot)
        let records = sessionFiles.prefix(maxIndexedSessions).compactMap { file -> CodexSessionRecord? in
            guard let metadata = sessionMetadata(from: file.url) else { return nil }
            return CodexSessionRecord(file: file, metadata: metadata)
        }
        let panelSessions = sessionModels(from: records, preloadTitleCount: recentLimit())
        let sessions = Array(panelSessions.prefix(recentLimit()))
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
            sessions: sessions,
            panelSessions: panelSessions
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

    private static func primaryCardSetting() -> String {
        WidgetDefaults.string(
            key: "primaryCard",
            widgetId: "codex-project-tracker",
            default: "Auto"
        )
    }

    private static func configuredUsageURL() -> URL {
        let path = WidgetDefaults.string(
            key: "usageStatePath",
            widgetId: "codex-project-tracker",
            default: "~/.codex/usage.json"
        )
        return URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
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

    // Keep the full bounded history available to the panel while deferring
    // larger transcript reads until a row is actually visible.
    private static func sessionModels(
        from sessionRecords: [CodexSessionRecord],
        preloadTitleCount: Int
    ) -> [CodexSession] {
        sessionRecords.enumerated().map { index, record in
            let projectURL = URL(fileURLWithPath: record.metadata.cwd).standardizedFileURL
            let modified = record.metadata.timestamp ?? record.file.modified
            let projectName = projectURL.lastPathComponent.isEmpty ? projectURL.path : projectURL.lastPathComponent

            return CodexSession(
                id: record.metadata.id ?? record.file.url.path,
                url: record.file.url,
                projectName: projectName,
                projectURL: projectURL,
                modified: modified,
                title: index < preloadTitleCount ? sessionTitle(from: record.file.url) : nil,
                isActive: Date().timeIntervalSince(modified) < 60 * 60 * 24 * 7
            )
        }
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

    static func sessionTitle(from url: URL) -> String? {
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

        guard !sessionFiles.isEmpty else {
            return .unavailable
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
            source: "Local activity estimate",
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
            accountCards: [],
            lastUpdated: sessionFiles.first?.modified,
            isStale: true,
            warning: "Using a local activity estimate; account snapshot unavailable."
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
                shortLabel: "Credits",
                kind: CodexCardKind.credits.rawValue
            ))
        }

        let lastUpdated = samples.map(\.timestamp).max()
        let freshness = usageFreshness(updatedAt: lastUpdated, authoritative: false)

        return CodexUsageSnapshot(
            percentRemaining: primaryLimit.percentRemaining,
            primaryTitle: "\(Int((primaryLimit.percentRemaining * 100).rounded()))% Left",
            primarySubtitle: "\(primaryLimit.name) • \(primaryLimit.resetLabel.map { "Resets \($0)" } ?? "Weekly usage")",
            windowUsedTokens: 0,
            todayUsedTokens: 0,
            budgetTokens: 0,
            resetDate: primaryLimit.resetDate,
            resetLabel: primaryLimit.resetLabel,
            source: "Session telemetry fallback",
            metrics: metrics,
            accountCards: cards,
            lastUpdated: lastUpdated,
            isStale: freshness.isStale,
            warning: freshness.warning
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
        let url = configuredUsageURL()
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
        let lastUpdated = parseCodexDate(state.updatedAt) ?? modificationDate(for: url)
        let freshness = usageFreshness(updatedAt: lastUpdated, authoritative: true)

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
            accountCards: accountCards,
            lastUpdated: lastUpdated,
            isStale: freshness.isStale,
            warning: freshness.warning
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
                percentRemaining: percent,
                kind: CodexCardKind.usage.rawValue
            )
        }

        if let credits = state.creditsBalance {
            cards.append(CodexDockCard(
                title: "\(credits) Credits",
                subtitle: "Current balance",
                shortLabel: "Credits",
                kind: CodexCardKind.credits.rawValue
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

    private static func modificationDate(for url: URL) -> Date? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return values.contentModificationDate
    }

    private static func usageFreshness(
        updatedAt: Date?,
        authoritative: Bool
    ) -> (isStale: Bool, warning: String?) {
        guard authoritative else {
            return (true, "Using recent session telemetry; account snapshot unavailable.")
        }
        guard let updatedAt else {
            return (true, "The usage snapshot has no update timestamp.")
        }
        if Date().timeIntervalSince(updatedAt) > 15 * 60 {
            return (true, "The usage snapshot is more than 15 minutes old.")
        }
        return (false, nil)
    }
}

