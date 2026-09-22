import AppKit
import Foundation
import SwiftUI

struct CodexV6DashboardView: View {
    let snapshot: CodexSnapshot
    let now: Date
    let isPreview: Bool
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onCheckUpdates: () -> Void
    let onModelChange: (String, String) -> Bool
    let dismiss: () -> Void

    @State private var page: CodexV6Page = .overview
    @State private var isEditing = false
    @State private var dragOrigin: CodexV6Page?
    @State private var cardOrders: [CodexV6Page: [CodexV6CardID]]
    @State private var pageThemes: [CodexV6Page: CodexTheme]
    @State private var hapticsEnabled: Bool
    @State private var visualTuning: CodexV6VisualTuning
    @State private var cardDensity: CodexV6CardDensity
    @State private var showDataStatus: Bool
    @State private var activityWindow: CodexV6AnalyticsWindow = .sevenDays
    @State private var modelFilter: String?
    @State private var selectedCard: CodexV6CardID?
    @State private var isAppearancePresented = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        snapshot: CodexSnapshot,
        now: Date,
        isPreview: Bool,
        isRefreshing: Bool = false,
        onRefresh: @escaping () -> Void,
        onCheckUpdates: @escaping () -> Void,
        onModelChange: @escaping (String, String) -> Bool,
        dismiss: @escaping () -> Void
    ) {
        self.snapshot = snapshot
        self.now = now
        self.isPreview = isPreview
        self.isRefreshing = isRefreshing
        self.onRefresh = onRefresh
        self.onCheckUpdates = onCheckUpdates
        self.onModelChange = onModelChange
        self.dismiss = dismiss
        _cardOrders = State(initialValue: CodexV6CardOrderStore.loadLayout())
        _pageThemes = State(initialValue: Dictionary(uniqueKeysWithValues: CodexV6Page.allCases.map {
            ($0, CodexV6PageThemeStore.load(for: $0))
        }))
        let storedHaptics = CodexV6Preferences.defaults.object(forKey: CodexHaptics.enabledKey) == nil
            ? true
            : CodexV6Preferences.defaults.bool(forKey: CodexHaptics.enabledKey)
        _hapticsEnabled = State(initialValue: storedHaptics)
        _visualTuning = State(initialValue: CodexV6Preferences.loadVisualTuning())
        _cardDensity = State(initialValue: CodexV6Preferences.loadCardDensity())
        _showDataStatus = State(initialValue: CodexV6Preferences.showDataStatus)
    }

    private var activeTheme: CodexTheme {
        pageThemes[page] ?? page.defaultTheme
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            pagePicker

            CodexV6DataNotice(usage: snapshot.usage, now: now)

            ZStack {
                activePage

                CodexTrackpadSwipeBridge { offset in
                    navigatePage(by: offset)
                }
                .frame(width: 1, height: 1)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
            .overlay(alignment: .leading) { edgeDropZone(direction: -1) }
            .overlay(alignment: .trailing) { edgeDropZone(direction: 1) }
            // Native card drags own mouse movement. Trackpad page swipes are
            // handled by CodexTrackpadSwipeBridge without competing gestures.

            pageFooter
        }
        .padding(.horizontal, 10)
        .padding(.top, 12)
        .padding(.bottom, 7)
        .background(CodexThemeBackground(theme: activeTheme))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .environment(\.codexTheme, activeTheme)
        .environment(\.codexVisualTuning, visualTuning)
        .tint(activeTheme.accent)
        .animation(reduceMotion || !visualTuning.animationsEnabled ? nil : .easeInOut(duration: 0.20), value: page)
        .onMoveCommand { direction in
            guard !isEditing else { return }
            switch direction {
            case .left: navigatePage(by: -1)
            case .right: navigatePage(by: 1)
            default: break
            }
        }
        .sheet(item: $selectedCard) { card in
            CodexV6CardDetailSheet(
                card: card,
                snapshot: snapshot,
                now: now,
                isPreview: isPreview
            )
            .environment(\.codexTheme, activeTheme)
            .environment(\.codexVisualTuning, visualTuning)
        }
        .onChange(of: visualTuning) { _, newValue in
            CodexV6Preferences.saveVisualTuning(newValue)
        }
        .onChange(of: cardDensity) { _, newValue in
            CodexV6Preferences.saveCardDensity(newValue)
        }
        .onChange(of: showDataStatus) { _, newValue in
            CodexV6Preferences.showDataStatus = newValue
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Usage")
                    .font(.headline.weight(.bold))
                    .lineLimit(1)
                if showDataStatus {
                    CodexV6DataStatusBadge(usage: snapshot.usage, now: now)
                }
            }
            Spacer(minLength: 2)

            Button(action: onCheckUpdates) {
                Image(systemName: "arrow.down.circle")
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Check for widget updates")
            .accessibilityLabel("Check for widget updates")

            Button(action: onRefresh) {
                Group {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .frame(width: 23, height: 23)
            }
            .buttonStyle(.plain)
            .foregroundStyle(activeTheme.accent)
            .help("Refresh usage")
            .accessibilityLabel("Refresh usage")
            .accessibilityValue(isRefreshing ? "Refreshing" : "Ready")
            .disabled(isRefreshing)
            .keyboardShortcut("r", modifiers: [.command])

            Button {
                isAppearancePresented.toggle()
            } label: {
                Image(systemName: "paintpalette.fill")
                    .foregroundStyle(activeTheme.accent)
                    .frame(width: 23, height: 23)
                    .background(activeTheme.accent.opacity(0.13), in: Circle())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isAppearancePresented, arrowEdge: .bottom) {
                CodexV6AppearancePopover(
                    theme: activeThemeBinding,
                    visualTuning: $visualTuning,
                    cardDensity: $cardDensity,
                    showDataStatus: $showDataStatus,
                    hapticsEnabled: hapticsEnabled
                )
            }
            .help("Choose the \(page.title) page theme")
            .accessibilityLabel("Choose \(page.title) page theme")
            .accessibilityValue(activeTheme.displayName)

            Button {
                hapticsEnabled.toggle()
                if hapticsEnabled {
                    CodexHaptics.performHoverIfEnabled(true)
                } else {
                    CodexHaptics.cancelPendingFeedback()
                }
                CodexV6Preferences.defaults.set(hapticsEnabled, forKey: CodexHaptics.enabledKey)
            } label: {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: hapticsEnabled ? "waveform" : "waveform.slash")
                        .foregroundStyle(hapticsEnabled ? activeTheme.accent : .secondary)
                        .frame(width: 23, height: 23)
                    Circle()
                        .fill(hapticsEnabled ? activeTheme.dataColor(2) : Color.secondary)
                        .frame(width: 5, height: 5)
                        .offset(x: 1, y: 1)
                }
            }
            .buttonStyle(.plain)
            .help("Hover and selection haptics: \(hapticsEnabled ? "On" : "Off")")
            .accessibilityLabel("Hover and selection haptics")
            .accessibilityValue(hapticsEnabled ? "On" : "Off")
            .accessibilityAddTraits(hapticsEnabled ? .isSelected : [])
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                    isEditing.toggle()
                }
            } label: {
                Image(systemName: isEditing ? "checkmark" : "arrow.up.and.down.text.horizontal")
                    .foregroundStyle(isEditing ? activeTheme.accent : .secondary)
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(.plain)
            .help(isEditing ? "Finish arranging cards" : "Arrange cards")
            .accessibilityLabel(isEditing ? "Finish arranging cards" : "Arrange cards")
            .keyboardShortcut("e", modifiers: [.command])

            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 23, height: 23)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Codex Usage")
        }
        .padding(.horizontal, 3)
        .padding(.bottom, 12)
    }

    private var pagePicker: some View {
        HStack(spacing: 4) {
            ForEach(CodexV6Page.allCases) { option in
                Button {
                    guard page != option else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
                        page = option
                    }
                    CodexHaptics.performPageNavigationIfEnabled(hapticsEnabled)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: option.symbol)
                            .font(.caption2.weight(.bold))
                        Text(option.title)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .foregroundStyle(page == option ? .primary : .secondary)
                    .background(
                        (page == option ? activeTheme.accent : Color.white)
                            .opacity(page == option ? 0.18 : 0.045),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .codexHoverHaptics(enabled: hapticsEnabled)
                .onDrop(of: [CodexV6CardDrag.type], delegate: CodexV6CardDropDelegate(
                    onEnter: {
                        if page != option {
                            page = option
                            CodexHaptics.performPageNavigationIfEnabled(hapticsEnabled)
                        }
                    },
                    onMove: { moveCard($0, to: option, before: cardOrders[option]?.first) }
                ))
                .help("Show \(option.title), or drop a card here to move it")
                .accessibilityLabel("\(option.title) page")
                .accessibilityValue(page == option ? "Selected" : "Not selected")
                .accessibilityAddTraits(page == option ? .isSelected : [])
            }
        }
        .padding(.bottom, 7)
    }

    private var pageFooter: some View {
        HStack(spacing: 8) {
            Button {
                navigatePage(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Previous page")
            .keyboardShortcut(.leftArrow, modifiers: [.command])

            HStack(spacing: 5) {
                ForEach(CodexV6Page.allCases) { option in
                    Circle()
                        .fill(option == page ? activeTheme.accent : Color.white.opacity(0.28))
                        .frame(width: option == page ? 7 : 5, height: option == page ? 7 : 5)
                        .accessibilityHidden(true)
                }
            }
            .frame(minWidth: 36)


            Button {
                navigatePage(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Next page")
            .keyboardShortcut(.rightArrow, modifiers: [.command])

            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 1) {
                Text(isEditing ? "Drop cards onto page tabs" : "Swipe or ⌘← ⌘→")
            .font(.caption2.weight(.medium))
                    .foregroundStyle(isEditing ? activeTheme.accent : Color.secondary.opacity(0.70))
                    .lineLimit(1)
                if !isEditing {
                    Text("Page \(page.pageIndex + 1) of \(CodexV6Page.allCases.count)")
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.horizontal, 3)
        .padding(.top, 5)
    }

    private func adjacentPage(offset: Int) -> CodexV6Page {
        let pages = CodexV6Page.allCases
        guard let index = pages.firstIndex(of: page) else { return page }
        let next = (index + offset + pages.count) % pages.count
        return pages[next]
    }

    private func navigatePage(by offset: Int) {
        guard !isEditing else { return }
        let nextPage = adjacentPage(offset: offset)
        guard nextPage != page else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.20)) {
            page = nextPage
        }
        CodexHaptics.performPageNavigationIfEnabled(hapticsEnabled)
    }

    private var activePage: some View {
        // Keep each page mounted while dragging. Removing the source page
        // during a tab hover cancels the native macOS drag session.
        ZStack {
            ForEach(CodexV6Page.allCases) { option in
                pageView(for: option)
                    .opacity(page == option ? 1 : 0)
                    .zIndex(page == option ? 1 : 0)
                    .allowsHitTesting(page == option || dragOrigin == option)
                    .accessibilityHidden(page != option)
            }
        }
    }

    private func pageView(for page: CodexV6Page) -> some View {
        CodexV6PageView(
            page: page,
            snapshot: snapshot,
            cardOrder: cardOrders[page] ?? page.defaultCards,
            isEditing: $isEditing,
            now: now,
            isPreview: isPreview,
            hapticsEnabled: hapticsEnabled,
            onModelChange: onModelChange,
            cardDensity: cardDensity,
            activityWindow: $activityWindow,
            modelFilter: $modelFilter,
            onSelectCard: { selectedCard = $0 },
            onMoveCard: { moveCard($0, to: $1, before: $2) },
            onDragStarted: { dragOrigin = page }
        )
        .environment(\.codexTheme, pageThemes[page] ?? page.defaultTheme)
        .environment(\.codexVisualTuning, tuning(for: page))
    }

    private func tuning(for option: CodexV6Page) -> CodexV6VisualTuning {
        var result = visualTuning
        if option != page { result.animationsEnabled = false }
        return result
    }

    private func edgeDropZone(direction: Int) -> some View {
        CodexV6EdgeDropZone(
            page: page,
            direction: direction,
            onNavigate: { offset in
                page = adjacentPage(offset: offset)
                CodexHaptics.performPageNavigationIfEnabled(hapticsEnabled)
            },
            onMove: { moveCard($0, to: page, before: cardOrders[page]?.first) }
        )
    }

    private func moveCard(_ card: CodexV6CardID, to destination: CodexV6Page, before target: CodexV6CardID?) {
        dragOrigin = nil
        let updated = CodexV6CardOrderStore.moving(card, to: destination, before: target, in: cardOrders)
        guard updated != cardOrders else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
            cardOrders = updated
            page = destination
        }
        CodexV6CardOrderStore.saveLayout(updated)
        CodexHaptics.performModelSelectionIfEnabled(hapticsEnabled)
    }

    private var activeThemeBinding: Binding<CodexTheme> {
        Binding(
            get: { activeTheme },
            set: { newTheme in
                pageThemes[page] = newTheme
                CodexV6PageThemeStore.save(newTheme, for: page)
            }
        )
    }

    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { hapticsEnabled },
            set: {
                hapticsEnabled = $0
                CodexV6Preferences.defaults.set($0, forKey: CodexHaptics.enabledKey)
            }
        )
    }
}
