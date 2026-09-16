import Foundation

@main
enum CodexV6Tests {
    static func main() {
        let normalized = CodexV6CardOrderStore.normalized([.burn, .burn, .cost, .quota], for: .overview)
        precondition(normalized == [.burn, .quota, .quotaBudget, .sessionPulse, .pace, .context, .contextRunway])
        precondition(CodexV6Page.allCases.flatMap(\.defaultCards).count == 24)
        precondition(Set(CodexV6Page.allCases.flatMap(\.defaultCards)).count == 24)
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

        let preview = CodexV6AnalyticsSnapshot.preview
        precondition(preview.todayTokens > 0)
        precondition(preview.models.count == 3)
        precondition(preview.dailyGoalTokens > 0)
        precondition(preview.workspaceHealth.dirtyFileCount == 4)
        precondition(preview.sourceStatuses.contains { $0.id == "account-quota" && $0.state == "Ready" })
        precondition(preview.todayVsPreviousDay != nil)
        print("Passed: v6 page defaults, duplicate-safe card normalization, analytics fixture, and source health.")
    }
}
