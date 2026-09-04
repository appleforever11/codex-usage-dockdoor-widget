import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct CodexTrackerCompactView: View {
    let size: CGSize
    let isVertical: Bool
    @State private var snapshot = CodexSnapshot.empty
    @State private var now = Date()
    @AppStorage(CodexTheme.storageKey) private var themeName = CodexTheme.astra.rawValue
    private var theme: CodexTheme { CodexTheme(rawValue: themeName) ?? .astra }
    @State private var primaryCard = CodexWidgetPreferences.primaryCard
    @State private var rotationInterval = CodexWidgetPreferences.rotationInterval
    @State private var pauseRotationOnHover = CodexWidgetPreferences.pauseRotationOnHover
    @State private var isHovering = false
    @State private var pausedAt = Date()

    private var dim: CGFloat { min(size.width, size.height) }
    private var gaugeSize: CGFloat { min(dim * 0.70, 35) }
    private var horizontalGaugeOutset: CGFloat { max(3, min(dim * 0.07, 4)) }
    private var compactTitleSize: CGFloat { max(9, min(dim * 0.22, 12)) }
    private var titleSize: CGFloat { isVertical ? max(10, min(dim * 0.21, 13)) : max(11, min(dim * 0.22, 13)) }
    private var subtitleSize: CGFloat { isVertical ? max(8, min(dim * 0.16, 10)) : max(8.5, min(dim * 0.16, 9.5)) }
    private var isExtended: Bool {
        isVertical ? size.height > size.width * 1.5 : size.width > size.height * 1.5
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
        .onHover { hovering in
            if hovering && !isHovering {
                pausedAt = now
            }
            isHovering = hovering
        }
        .task {
            while !Task.isCancelled {
                let refreshed = await CodexTrackerStore.snapshot()
                snapshot = refreshed
                CodexSnapshotCache.latest = refreshed
                primaryCard = CodexWidgetPreferences.primaryCard
                rotationInterval = CodexWidgetPreferences.rotationInterval
                pauseRotationOnHover = CodexWidgetPreferences.pauseRotationOnHover
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
            Text(card.shortLabel)
                .font(.system(size: compactTitleSize, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundStyle(.primary)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Codex \(card.shortLabel) card")
        .accessibilityValue(card.title)
    }

    private var extendedLayout: some View {
        Group {
            if isVertical {
                VStack(spacing: dim * 0.08) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), theme: theme)
                    usageLabels(alignment: .center)
                }
            } else {
                HStack(spacing: max(4, dim * 0.05)) {
                    UsageRingView(percentRemaining: card.percentRemaining ?? snapshot.usage.percentRemaining, size: gaugeSize, lineWidth: max(3, dim * 0.052), theme: theme)
                        .frame(
                            width: gaugeSize + (horizontalGaugeOutset * 2),
                            height: gaugeSize + (horizontalGaugeOutset * 2)
                        )
                    usageLabels(alignment: .leading)
                }
                .padding(.leading, 1)
                .padding(.trailing, max(4, dim * 0.06))
                .padding(.vertical, 2)
            }
        }
        .foregroundStyle(.primary)
    }

    private func usageLabels(alignment: HorizontalAlignment) -> some View {
        HStack(spacing: 4) {
            VStack(alignment: alignment, spacing: 1) {
                Text(card.title)
                    .font(.system(size: titleSize, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text(card.subtitle)
                    .font(.system(size: subtitleSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.primary.opacity(0.80))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .layoutPriority(1)
        }
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
