import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

@MainActor
enum CodexSnapshotCache {
    static var latest: CodexSnapshot?
}

@MainActor
struct CodexTrackerPanelView: View {
    let dismiss: () -> Void
    private let isPreview: Bool
    @State private var snapshot: CodexSnapshot?
    @State private var now = Date()
    @AppStorage(CodexTheme.storageKey) private var themeName = CodexTheme.astra.rawValue
    private var theme: CodexTheme { CodexTheme(rawValue: themeName) ?? .astra }
    @State private var isRefreshing = false
    @State private var settingsError: String?

    init(dismiss: @escaping () -> Void, previewSnapshot: CodexSnapshot? = nil) {
        self.dismiss = dismiss
        self.isPreview = previewSnapshot != nil
        _snapshot = State(initialValue: previewSnapshot ?? CodexSnapshotCache.latest)
    }

    var body: some View {
        Group {
            if let snapshot {
                panelContent(snapshot)
            } else {
                loadingContent
            }
        }
        .alert("Couldn’t save defaults", isPresented: Binding(
            get: { settingsError != nil }, set: { if !$0 { settingsError = nil } }
        )) { Button("OK") { settingsError = nil } } message: { Text(settingsError ?? "") }
        .background(CodexThemeBackground(theme: theme))
        .environment(\.codexTheme, theme)
        .environment(\.colorScheme, .dark)
        .tint(theme.accent)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .task {
            guard !isPreview else { return }
            if snapshot == nil {
                await refreshSnapshot()
            }

            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard !Task.isCancelled else { break }
                await refreshSnapshot(force: false)
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(15))
            }
        }
    }

    private func panelContent(_ snapshot: CodexSnapshot) -> some View {
        CodexV6DashboardView(
            snapshot: snapshot,
            now: now,
            isPreview: isPreview,
            isRefreshing: isRefreshing,
            onRefresh: {
                if !isPreview {
                    Task { await refreshSnapshot(force: true) }
                }
            },
            onCheckUpdates: {
                if !isPreview { CodexAppLauncher.checkForUpdates() }
            },
            onModelChange: { model, reasoning in
                if isPreview {
                    self.snapshot?.modelSettings = CodexModelSettings(model: model, reasoningEffort: reasoning)
                    return true
                }

                do {
                    try CodexConfigStore.update(model: model, reasoningEffort: reasoning)
                    Task { await refreshSnapshot() }
                    return true
                } catch {
                    settingsError = error.localizedDescription
                    return false
                }
            },
            dismiss: dismiss
        )
        .frame(width: 350, height: 640, alignment: .topLeading)
    }

    private var loadingContent: some View {
        CodexV6LoadingState(theme: theme)
    }

    private func refreshSnapshot(force: Bool = false) async {
        if force {
            guard !isRefreshing else { return }
            isRefreshing = true
        }
        let refreshed = await CodexTrackerStore.snapshot(forceRefresh: force)
        CodexSnapshotCache.latest = refreshed
        snapshot = refreshed
        if force {
            isRefreshing = false
        }
    }

}
