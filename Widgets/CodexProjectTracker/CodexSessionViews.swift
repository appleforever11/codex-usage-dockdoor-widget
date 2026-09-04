import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct CodexSessionRow: View {
    let session: CodexSession
    var allowsOpening = true
    @Environment(\.codexTheme) private var theme
    @State private var isHovering = false
    @State private var resolvedTitle: String?

    private var rowSubtitle: String {
        resolvedTitle ?? session.title ?? session.relativeActivity
    }

    var body: some View {
        Button {
            if allowsOpening { CodexAppLauncher.openSession(session) }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: session.isActive ? "circle.fill" : "circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(session.isActive ? theme.accent : .secondary)
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.projectName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                    Text(rowSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text(session.relativeActivity)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.up.forward.app")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary.opacity(isHovering ? 0.9 : 0.0))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(.white.opacity(isHovering ? 0.10 : 0.0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help("Open in Codex")
        .task(id: session.id) {
            guard session.title == nil else { return }

            let url = session.url
            let title = await Task.detached(priority: .utility) {
                CodexTrackerStore.sessionTitle(from: url)
            }.value

            guard !Task.isCancelled else { return }
            resolvedTitle = title
        }
    }
}

struct DataStatusRow: View {
    let usage: CodexUsageSnapshot
    let now: Date

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(usage.statusTint)
                .frame(width: 7, height: 7)
            Text(usage.statusLabel(now: now))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex data status")
        .accessibilityValue(usage.statusLabel(now: now))
    }
}


struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
