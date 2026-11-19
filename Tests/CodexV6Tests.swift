import Foundation

@main
enum CodexV6Tests {
    static func main() {
        // An optional Git health scan must not stall the usage dashboard.
        let slowRepo = FileManager.default.temporaryDirectory.appendingPathComponent("tracker-slow-git-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: slowRepo, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: slowRepo) }
        func git(_ args: [String]) {
            let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", slowRepo.path] + args
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            try! process.run(); process.waitUntilExit(); precondition(process.terminationStatus == 0)
        }
        git(["init"])
        let hook = slowRepo.appendingPathComponent("slow-monitor")
        try! "#!/bin/sh\nsleep 5\nprintf 'token\\0'\n".write(to: hook, atomically: true, encoding: .utf8)
        try! FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hook.path)
        git(["config", "core.fsmonitor", hook.path])
        let began = Date()
        let health = CodexV6WorkspaceHealthReader.read(sessions: [CodexSession(id: "slow", url: hook, projectName: "Fixture", projectURL: slowRepo, modified: began, title: nil, isActive: true)])
        precondition(Date().timeIntervalSince(began) < 2, "Slow Git must time out without blocking the dashboard")
        precondition(health.repositoryCount == 0, "A timed-out repository is not a clean repository")
        let normalized = CodexV6CardOrderStore.normalized([.burn, .burn, .cost, .quota], for: .overview)
        precondition(normalized == [.burn, .quota, .modelControls, .quotaBudget, .sessionPulse, .pace, .context, .contextRunway])
        precondition(CodexV6Page.allCases.flatMap(\.defaultCards).count == 24)
        precondition(Set(CodexV6Page.allCases.flatMap(\.defaultCards)).count == 24)
        precondition(CodexV6Page.overview.defaultCards.contains(.modelControls))
        precondition(!CodexV6Page.health.defaultCards.contains(.modelControls))
        precondition(CodexV6Page.overview.defaultTheme == .astra)
        precondition(CodexV6Page.activity.defaultTheme == .luna)
        precondition(CodexV6Page.models.defaultTheme == .terra)
        precondition(CodexV6Page.health.defaultTheme == .sol)
        precondition(CodexV6DateFormatting.shortWeekday(forDayKey: "2026-09-09") == "Wed")
        precondition(CodexV6AnalyticsWindow.today.dayCount == 1)
        precondition(CodexV6AnalyticsWindow.thirtyDays.dayCount == 30)
        precondition(CodexV6CardDensity.compact.cardSpacing < CodexV6CardDensity.spacious.cardSpacing)
        precondition(CodexV6CardID.quota.isHero)
        precondition(CodexV6CardID.burn.detailDescription.contains("local"))

        let suiteName = "com.appleforever11.codex-v6-layout-tests.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        let previousDefaults = CodexV6Preferences.defaults
        CodexV6Preferences.defaults = testDefaults
        defer {
            testDefaults.removePersistentDomain(forName: suiteName)
            CodexV6Preferences.defaults = previousDefaults
        }
        // Upgrade preserves legacy ordering, then moving a card persists its
        // new ownership instead of putting a copy back on the original page.
        CodexV6CardOrderStore.save([.burn, .quota], for: .overview)
        let original = CodexV6CardOrderStore.loadLayout()
        precondition(original[.overview]?.first == .burn)
        var moved = CodexV6CardOrderStore.moving(.burn, to: .activity, before: .dailyActivity, in: original)
        precondition(moved[.activity]?.first == .burn)
        precondition(moved[.overview]?.contains(.burn) == false)
        CodexV6CardOrderStore.saveLayout(moved)
        precondition(CodexV6CardOrderStore.loadLayout() == moved)
        // Reorder within a destination and return across pages without copies.
        moved = CodexV6CardOrderStore.moving(.burn, to: .activity, in: moved)
        precondition(moved[.activity]?.last == .burn)
        moved = CodexV6CardOrderStore.moving(.burn, to: .overview, before: .quota, in: moved)
        precondition(moved == original)
        precondition(CodexV6CardOrderStore.moving(.quota, to: .overview, before: .quota, in: moved) == moved)
        // An intentionally emptied page stays empty after saving/relaunching.
        for card in moved[.overview] ?? [] {
            moved = CodexV6CardOrderStore.moving(card, to: .health, in: moved)
        }
        CodexV6CardOrderStore.saveLayout(moved)
        precondition(CodexV6CardOrderStore.loadLayout()[.overview] == [])
        let allCards = CodexV6Page.allCases.flatMap { moved[$0] ?? [] }
        precondition(allCards.count == 24 && Set(allCards).count == 24)
        // Corrupt duplicates are removed; omitted/new cards are restored once.
        moved[.models, default: []].append(.quota)
        moved[.activity]?.removeAll { $0 == .dailyActivity }
        let repaired = CodexV6CardOrderStore.normalizedLayout(moved)
        let repairedCards = CodexV6Page.allCases.flatMap { repaired[$0] ?? [] }
        precondition(repairedCards.count == 24 && Set(repairedCards).count == 24)
        precondition(repaired[.activity]?.contains(.dailyActivity) == true)

        let telemetryNow = ISO8601DateFormatter().date(from: "2026-09-25T12:00:00Z")!
        let telemetryFixture = [
            #"{"type":"event_msg","timestamp":"2026-09-25T05:00:00Z","ordinal":1,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"total_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"model_context_window":200000}}}"#,
            #"{"type":"event_msg","timestamp":"2026-09-25T08:00:00Z","ordinal":2,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":30,"output_tokens":20,"total_tokens":50},"total_token_usage":{"input_tokens":90,"output_tokens":60,"total_tokens":150},"model_context_window":200000}}}"#,
            #"{"type":"event_msg","timestamp":"2026-09-25T11:00:00Z","ordinal":3,"payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":60,"output_tokens":40,"total_tokens":100},"total_token_usage":{"input_tokens":150,"output_tokens":100,"total_tokens":250},"model_context_window":200000}}}"#,
        ].joined(separator: "\n")
        let telemetry = CodexTokenTelemetryReader.read(
            sources: [CodexTokenLogSource(id: "fixture", projectName: "Fixture", contents: telemetryFixture)],
            now: telemetryNow,
            windowHours: 5
        )
        precondition(telemetry.todayUsage.effectiveTotalTokens == 250)
        precondition(telemetry.windowUsage.effectiveTotalTokens == 150)

        let preview = CodexV6AnalyticsSnapshot.preview
        precondition(preview.todayTokens > 0)
        precondition(preview.models.count == 3)
        precondition(preview.dailyGoalTokens > 0)
        precondition(preview.workspaceHealth.dirtyFileCount == 4)
        precondition(preview.sourceStatuses.contains { $0.id == "account-quota" && $0.state == "Ready" })
        precondition(preview.todayVsPreviousDay != nil)
        print("Passed: v6 layout and analytics checks, plus rolling-window and daily session-token totals.")
    }
}
