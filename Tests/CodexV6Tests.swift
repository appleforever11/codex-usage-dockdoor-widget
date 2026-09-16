import Foundation

@main
enum CodexV6Tests {
    static func main() {
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

        let preview = CodexV6AnalyticsSnapshot.preview
        precondition(preview.todayTokens > 0)
        precondition(preview.models.count == 3)
        precondition(preview.dailyGoalTokens > 0)
        precondition(preview.workspaceHealth.dirtyFileCount == 4)
        precondition(preview.sourceStatuses.contains { $0.id == "account-quota" && $0.state == "Ready" })
        precondition(preview.todayVsPreviousDay != nil)
        print("Passed: v6 page defaults, cross-page moves, layout persistence and migration, duplicate-safe card normalization, analytics fixture, and source health.")
    }
}
