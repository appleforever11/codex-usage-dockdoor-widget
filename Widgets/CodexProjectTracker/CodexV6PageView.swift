import Foundation
import OSLog
import SwiftUI
import UniformTypeIdentifiers

struct CodexV6PageView: View {
    let page: CodexV6Page
    let snapshot: CodexSnapshot
    let cardOrder: [CodexV6CardID]
    @Binding var isEditing: Bool
    let now: Date
    let isPreview: Bool
    let hapticsEnabled: Bool
    let onModelChange: (String, String) -> Bool
    let cardDensity: CodexV6CardDensity
    @Binding var activityWindow: CodexV6AnalyticsWindow
    @Binding var modelFilter: String?
    let onSelectCard: (CodexV6CardID) -> Void
    let onMoveCard: (CodexV6CardID, CodexV6Page, CodexV6CardID?) -> Void
    let onDragStarted: () -> Void
    @Environment(\.codexTheme) private var theme

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: cardDensity.cardSpacing) {
                if isEditing {
                    Label("Drag cards here or onto a page tab", systemImage: "hand.draw.fill")
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

                if cardOrder.isEmpty {
                    Label("Drop cards here", systemImage: "square.dashed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 100)
                }

                ForEach(cardOrder) { card in
                    CodexV6CardShell(
                        card: card,
                        isEditing: isEditing,
                        density: cardDensity,
                        showsHeader: card != .modelControls && card != .quota,
                        onOpenDetails: { onSelectCard(card) },
                        onMoveToPage: { onMoveCard(card, $0, nil) }
                    ) {
                        cardContent(card)
                    }
                    .contentShape(Rectangle())
                    .codexHoverHaptics(enabled: hapticsEnabled)
                    .onDrag {
                        onDragStarted()
                        return CodexV6CardDrag.provider(for: card)
                    }
                    .onDrop(of: [CodexV6CardDrag.type], delegate: CodexV6CardDropDelegate(
                        onMove: { onMoveCard($0, page, card) }
                    ))
                }
            }
            .padding(.horizontal, 2)
            .padding(.top, 4)
            .padding(.bottom, cardDensity == .compact ? 2 : 4)
        }
        .onDrop(of: [CodexV6CardDrag.type], delegate: CodexV6CardDropDelegate(
            onMove: { onMoveCard($0, page, nil) }
        ))
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
            ModelControlSection(
                settings: snapshot.modelSettings,
                hapticsEnabled: hapticsEnabled,
                showsHeader: true,
                isEmbedded: true,
                onChange: onModelChange
            )
        }
    }
}

// Use the native text representation for macOS drag services, with a strict
// application prefix so unrelated text can never move dashboard cards.
enum CodexV6CardDrag {
    static let logger = Logger(subsystem: "com.appleforever11.codex-usage", category: "CardDrag")
    static let type = UTType.text
    private static let prefix = "codex-usage-card:"


    static func provider(for card: CodexV6CardID) -> NSItemProvider {
        logger.info("Started card drag: \(card.rawValue, privacy: .public)")
        return NSItemProvider(object: (prefix + card.rawValue) as NSString)
    }

    static func receive(_ providers: [NSItemProvider], onMove: @escaping (CodexV6CardID) -> Void) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) else { return false }
        logger.info("Accepted card drop")
        provider.loadObject(ofClass: NSString.self) { object, _ in
            guard let value = object as? String, value.hasPrefix(prefix),
                  let card = CodexV6CardID(rawValue: String(value.dropFirst(prefix.count))) else { return }
            logger.info("Decoded card drop: \(card.rawValue, privacy: .public)")
            DispatchQueue.main.async { onMove(card) }
        }
        return true
    }
}

struct CodexV6CardDropDelegate: DropDelegate {
    var onEnter: () -> Void = {}
    let onMove: (CodexV6CardID) -> Void

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [CodexV6CardDrag.type])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info) else { return }
        CodexV6CardDrag.logger.debug("Entered card drop target")
        onEnter()
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        CodexV6CardDrag.receive(info.itemProviders(for: [CodexV6CardDrag.type]), onMove: onMove)
    }
}

/// Holding a dragged card at either edge turns pages without committing a move.
struct CodexV6EdgeDropZone: View {
    let page: CodexV6Page
    let direction: Int
    let onNavigate: (Int) -> Void
    let onMove: (CodexV6CardID) -> Void
    @State private var isTargeted = false
    @Environment(\.codexTheme) private var theme

    var body: some View {
        Rectangle()
            .fill(isTargeted ? theme.accent.opacity(0.25) : .clear)
            .frame(width: 12)
            .contentShape(Rectangle())
            .onDrop(of: [CodexV6CardDrag.type], isTargeted: $isTargeted) { providers in
                CodexV6CardDrag.receive(providers, onMove: onMove)
            }
            .task(id: "\(page.rawValue)-\(isTargeted)") {
                guard isTargeted else { return }
                do { try await Task.sleep(for: .milliseconds(650)) }
                catch { return }
                guard !Task.isCancelled else { return }
                onNavigate(direction)
            }
            .accessibilityHidden(true)
    }
}
