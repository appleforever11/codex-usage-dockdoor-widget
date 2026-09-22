import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct CodexTrackerCompactView: View {
    let size: CGSize
    let isVertical: Bool
    private let isPreview: Bool
    private let previewTheme: CodexTheme?
    @State private var snapshot = CodexSnapshot.empty
    @State private var now = Date()
    @AppStorage(CodexTheme.storageKey) private var themeName = CodexTheme.astra.rawValue
    private var theme: CodexTheme { previewTheme ?? CodexTheme.named(themeName) ?? .astra }
    @State private var primaryCard = CodexWidgetPreferences.primaryCard
    @State private var rotationInterval = CodexWidgetPreferences.rotationInterval
    @State private var pauseRotationOnHover = CodexWidgetPreferences.pauseRotationOnHover
    @State private var showDataStatus = CodexWidgetPreferences.showDataStatus
    @State private var isHovering = false
    @State private var pausedAt = Date()

    private var dim: CGFloat { min(size.width, size.height) }
    private var gaugeSize: CGFloat {
        min(dim * (isExtended ? 0.76 : 0.70), isExtended ? 42 : 38)
    }
    private var horizontalGaugeOutset: CGFloat { max(3, min(dim * 0.08, 5)) }
    private var compactTitleSize: CGFloat { max(9, min(dim * 0.22, 12)) }
    private var titleSize: CGFloat { isVertical ? max(10, min(dim * 0.22, 14)) : max(11, min(dim * 0.24, 14)) }
    private var subtitleSize: CGFloat { isVertical ? max(8, min(dim * 0.16, 10)) : max(8.5, min(dim * 0.16, 9.5)) }
    private var isExtended: Bool {
        isVertical ? size.height > size.width * 1.5 : size.width > size.height * 1.5
    }
    private var contentPadding: CGFloat {
        isExtended ? max(4, min(dim * 0.10, 7)) : max(2, min(dim * 0.07, 4))
    }
    private var dockModelName: String {
        // Gallery previews represent the theme being previewed; live widgets
        // represent the model currently selected in Codex.
        previewTheme?.displayName ?? snapshot.modelSettings.shortModelName
    }
    private var dockReasoningLabel: String {
        snapshot.modelSettings.reasoningLabel
    }
    private var dockSecondaryLabel: String {
        if card.kind == CodexCardKind.model.rawValue {
            return dockReasoningLabel
        }
        return "\(dockReasoningLabel) · \(card.shortLabel)"
    }

    init(size: CGSize, isVertical: Bool, previewSnapshot: CodexSnapshot? = nil, previewTheme: CodexTheme? = nil) {
        self.size = size
        self.isVertical = isVertical
        self.isPreview = previewSnapshot != nil
        self.previewTheme = previewTheme
        _snapshot = State(initialValue: previewSnapshot ?? CodexSnapshot.empty)
    }

    private var card: CodexDockCard {
        let rotationDate = isHovering && pauseRotationOnHover ? pausedAt : now
        return snapshot.rotatingDockCard(
            at: rotationDate,
            interval: rotationInterval,
            preferredKind: primaryCard
        )
    }

    var body: some View {
        Group {
            if isExtended {
                extendedLayout
            } else {
                compactLayout
            }
        }
        // DockDoor owns the shelf surface. Keeping this view transparent lets the
        // reflective shelf show through instead of stacking a second tinted card.
        .foregroundStyle(.white.opacity(0.94))
        .padding(contentPadding)
        .shadow(color: .black.opacity(0.74), radius: 2.2, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex Usage 6.0 " + card.shortLabel + " card")
        .accessibilityValue(card.title + ". " + card.subtitle)
        .onHover { hovering in
            if hovering && !isHovering {
                pausedAt = now
            }
            isHovering = hovering
        }
        .task {
            guard !isPreview else { return }
            while !Task.isCancelled {
                let refreshed = await CodexTrackerStore.snapshot()
                snapshot = refreshed
                CodexSnapshotCache.latest = refreshed
                primaryCard = CodexWidgetPreferences.primaryCard
                rotationInterval = CodexWidgetPreferences.rotationInterval
                pauseRotationOnHover = CodexWidgetPreferences.pauseRotationOnHover
                showDataStatus = CodexWidgetPreferences.showDataStatus
                try? await Task.sleep(for: .seconds(5))
            }
        }
        .task {
            while !Task.isCancelled {
                now = Date()
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    private var compactLayout: some View {
        VStack(spacing: 1) {
            UsageRingView(
                percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining,
                size: gaugeSize,
                lineWidth: max(3, dim * 0.055),
                theme: theme
            )
            Text(dockModelName)
                .font(.system(size: compactTitleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .shadow(color: .black.opacity(0.82), radius: 1.6, y: 1)
        }
    }

    private var extendedLayout: some View {
        Group {
            if isVertical {
                VStack(spacing: max(4, dim * 0.08)) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), theme: theme)
                        .frame(
                            width: gaugeSize + (horizontalGaugeOutset * 2),
                            height: gaugeSize + (horizontalGaugeOutset * 2)
                        )
                    usageLabels(alignment: .center)
                }
            } else {
                HStack(spacing: max(5, dim * 0.075)) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), theme: theme)
                        .frame(
                            width: gaugeSize + (horizontalGaugeOutset * 2),
                            height: gaugeSize + (horizontalGaugeOutset * 2)
                        )
                    usageLabels(alignment: .leading)
                }
                .padding(.leading, 1)
                .padding(.trailing, max(3, dim * 0.04))
                .padding(.vertical, 1)
            }
        }
    }

    private func usageLabels(alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            HStack(spacing: 3) {
                if showDataStatus {
                    Circle()
                        .fill(snapshot.usage.statusTint)
                        .frame(width: 4, height: 4)
                }
                Text(showDataStatus ? compactStatusLabel : "CODEX")
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .font(.system(size: max(8, min(dim * 0.15, 10)), weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.88))
            .shadow(color: .black.opacity(0.82), radius: 1.6, y: 1)

            Text(dockModelName)
                .font(.system(size: titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.98))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .shadow(color: .black.opacity(0.84), radius: 1.8, y: 1)
            Text(dockSecondaryLabel)
                .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .shadow(color: .black.opacity(0.84), radius: 1.6, y: 1)
        }
        .layoutPriority(1)
    }

    private var compactStatusLabel: String {
        if snapshot.usage.source == "Loading" { return "SYNC" }
        return snapshot.usage.isStale ? "STALE" : "LIVE"
    }

}

struct CodexAppIconView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let image = CodexAppIconProvider.icon {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .background(.black.opacity(0.16), in: RoundedRectangle(cornerRadius: max(7, size * 0.22)))
        .overlay {
            RoundedRectangle(cornerRadius: max(7, size * 0.22))
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.22), radius: 3, y: 1)
    }
}
