import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct CodexV6PageView: View {
    let page: CodexV6Page
    let snapshot: CodexSnapshot
    @Binding var cardOrder: [CodexV6CardID]
    @Binding var isEditing: Bool
    let now: Date
    let isPreview: Bool
    let hapticsEnabled: Bool
    let onModelChange: (String, String) -> Bool
    let cardDensity: CodexV6CardDensity
    @Binding var activityWindow: CodexV6AnalyticsWindow
    @Binding var modelFilter: String?
    let onSelectCard: (CodexV6CardID) -> Void
    @State private var draggedCard: CodexV6CardID?
    @Environment(\.codexTheme) private var theme

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: cardDensity.cardSpacing) {
                if isEditing {
                    Label("Drag a card to move it", systemImage: "hand.draw.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(theme.accent)
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }

                if page == .activity || page == .models {
                    CodexV6FilterBar(
                        page: page,
                        activityWindow: $activityWindow,
                        modelFilter: $modelFilter,
                        models: snapshot.analytics.models
                    )
                }

                ForEach(cardOrder) { card in
                    CodexV6CardShell(
                        card: card,
                        isEditing: isEditing,
                        density: cardDensity,
                        onOpenDetails: { onSelectCard(card) }
                    ) {
                        cardContent(card)
                    }
                    .onDrag {
                        draggedCard = card
                        return NSItemProvider(object: card.rawValue as NSString)
                    }
                    .onDrop(
                        of: [UTType.plainText],
                        delegate: CodexV6CardDropDelegate(
                            item: card,
                            items: $cardOrder,
                            draggedItem: $draggedCard
                        )
                    )
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, cardDensity == .compact ? 2 : 4)
        }
        .scrollContentBackground(.hidden)
        .animation(.easeInOut(duration: 0.18), value: cardOrder)
        .accessibilityLabel("\(page.title) cards")
    }

    @ViewBuilder
    private func cardContent(_ card: CodexV6CardID) -> some View {
        switch card {
        case .quota:
            CodexV6QuotaCard(usage: snapshot.usage,
                             analytics: snapshot.analytics,
                             now: now,
                             taskCount: snapshot.taskCount,
                             chatCount: snapshot.chatCount)
        case .pace:
            CodexV6PaceCard(pace: snapshot.analytics.quotaPace, usage: snapshot.usage, now: now)
        case .burn:
            CodexV6BurnCard(telemetry: snapshot.tokenTelemetry, analytics: snapshot.analytics, now: now)
        case .context:
            CodexV6ContextCard(telemetry: snapshot.tokenTelemetry, analytics: snapshot.analytics)
        case .quotaBudget:
            CodexV6QuotaBudgetCard(pace: snapshot.analytics.quotaPace, usage: snapshot.usage, now: now)
        case .sessionPulse:
            CodexV6SessionPulseCard(snapshot: snapshot, now: now)
        case .contextRunway:
            CodexV6ContextRunwayCard(telemetry: snapshot.tokenTelemetry, analytics: snapshot.analytics)
        case .dailyActivity:
            CodexV6DailyActivityCard(analytics: snapshot.analytics, window: activityWindow)
        case .hourlyActivity:
            CodexV6HourlyActivityCard(analytics: snapshot.analytics, window: activityWindow)
        case .projectHeatmap:
            CodexV6ProjectHeatmapCard(analytics: snapshot.analytics)
        case .turnTimeline:
            CodexV6TurnTimelineCard(telemetry: snapshot.tokenTelemetry)
        case .streaksGoals:
            CodexV6StreaksGoalsCard(analytics: snapshot.analytics)
        case .cost:
            CodexV6CostCard(analytics: snapshot.analytics)
        case .modelMix:
            CodexV6ModelMixCard(analytics: snapshot.analytics, modelFilter: modelFilter)
        case .modelScorecard:
            CodexV6ModelScorecardCard(analytics: snapshot.analytics, modelFilter: modelFilter)
        case .efficiency:
            CodexV6EfficiencyCard(telemetry: snapshot.tokenTelemetry)
        case .projectMix:
            CodexV6ProjectMixCard(analytics: snapshot.analytics)
        case .sessionHealth:
            CodexV6SessionHealthCard(
                telemetry: snapshot.tokenTelemetry,
                sessions: snapshot.panelSessions,
                taskCount: snapshot.taskCount,
                chatCount: snapshot.chatCount
            )
        case .officialActivity:
            CodexV6OfficialActivityCard(analytics: snapshot.analytics)
        case .reliability:
            CodexV6ReliabilityCard(telemetry: snapshot.tokenTelemetry, analytics: snapshot.analytics, usage: snapshot.usage, now: now)
        case .dataHealth:
            CodexV6DataHealthCard(analytics: snapshot.analytics, usage: snapshot.usage, now: now)
        case .workspaceHealth:
            CodexV6WorkspaceHealthCard(health: snapshot.analytics.workspaceHealth)
        case .recentChats:
            CodexV6RecentChatsCard(sessions: snapshot.panelSessions, latestChat: snapshot.latestChat, isPreview: isPreview)
        case .modelControls:
            ModelControlSection(settings: snapshot.modelSettings, hapticsEnabled: hapticsEnabled, onChange: onModelChange)
        }
    }
}

struct CodexV6CardDropDelegate: DropDelegate {
    let item: CodexV6CardID
    @Binding var items: [CodexV6CardID]
    @Binding var draggedItem: CodexV6CardID?

    func dropEntered(info: DropInfo) {
        guard let draggedItem,
              draggedItem != item,
              let fromIndex = items.firstIndex(of: draggedItem),
              let toIndex = items.firstIndex(of: item)
        else { return }

        withAnimation(.easeInOut(duration: 0.16)) {
            items.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedItem = nil
        return true
    }
}
