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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Codex Usage", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.headline)
                Spacer()
                Button {
                    if !isPreview { CodexAppLauncher.checkForUpdates() }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Check for widget updates")
                .accessibilityLabel("Check for widget updates")
                Button {
                    if !isPreview { Task { await refreshSnapshot(force: true) } }
                } label: {
                    Image(systemName: isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                        .rotationEffect(.degrees(isRefreshing ? 180 : 0))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Refresh Codex data now")
                .accessibilityLabel("Refresh usage")
                .disabled(isRefreshing)
                CodexThemeMenu(selection: $themeName)
                Button(action: dismiss) {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            if CodexWidgetPreferences.showDataStatus {
                DataStatusRow(usage: snapshot.usage, now: now)
            }

            if let warning = snapshot.usage.warning {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(warning)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack(spacing: 12) {
                UsageRingView(percentRemaining: snapshot.usage.percentRemaining, size: 72, lineWidth: 7, theme: theme)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.usage.primaryTitle)
                        .font(.title3.weight(.bold))
                    Text(snapshot.usage.primarySubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    Text(snapshot.usage.resetSummary(now: now))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .background(theme.accent.opacity(0.075), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.accent.opacity(0.18)))

            HStack(spacing: 10) {
                StatPill(title: "Window", value: snapshot.usage.windowUsedLabel)
                StatPill(title: "Today", value: snapshot.usage.todayUsedLabel)
                StatPill(title: "Tasks", value: "\(snapshot.taskCount)")
                StatPill(title: "Chats", value: "\(snapshot.chatCount)")
            }

            VStack(alignment: .leading, spacing: 7) {
                Text("Usage limits")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(snapshot.usage.metrics) { metric in
                    HStack(spacing: 8) {
                        Image(systemName: metric.systemImage)
                            .frame(width: 15)
                            .foregroundStyle(theme.accent)
                        Text(metric.title)
                            .font(.caption.weight(.semibold))
                        Spacer()
                        Text(metric.value)
                            .font(.caption.monospacedDigit().weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
            }

            ModelControlSection(
                settings: snapshot.modelSettings,
                onChange: { model, reasoning in
                    if isPreview {
                        self.snapshot?.modelSettings = CodexModelSettings(model: model, reasoningEffort: reasoning)
                    } else {
                        do {
                            try CodexConfigStore.update(model: model, reasoningEffort: reasoning)
                            Task { await refreshSnapshot() }
                        } catch {
                            settingsError = error.localizedDescription
                        }
                    }
                }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Chats")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if snapshot.panelSessions.isEmpty {
                            Label("Your recent chats will appear here", systemImage: "bubble.left.and.bubble.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 14)
                        }
                        ForEach(snapshot.panelSessions) { session in
                            CodexSessionRow(session: session, allowsOpening: !isPreview)
                        }

                        if let latest = snapshot.latestChat {
                            Divider()
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Latest Chat")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(latest)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 2)
                }
                .frame(minHeight: 70, maxHeight: .infinity)
                .accessibilityLabel("Recent Codex chats")
            }
        }
        .padding(14)
        .frame(width: 350, height: 640, alignment: .topLeading)
    }

    private var loadingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.small)
            Text("Loading Codex Usage")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(width: 350, height: 640)
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
