import Foundation
import SwiftUI

struct CodexV6ChartDatum: Identifiable, Hashable {
    let id: String
    let label: String
    let value: Int64
    let detail: String

    init(id: String, label: String, value: Int64, detail: String = "") {
        self.id = id
        self.label = label
        self.value = value
        self.detail = detail
    }
}

struct CodexV6InteractiveColumnChart: View {
    let data: [CodexV6ChartDatum]
    let theme: CodexTheme
    let height: CGFloat
    let showsLabels: Bool

    @State private var selectedID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Keep the hover readout from reflowing the plot into the metric row. The
    // reserved slot also prevents the chart from jumping when the pointer
    // moves between bars.
    private let calloutSlotHeight: CGFloat = 22

    init(data: [CodexV6ChartDatum], theme: CodexTheme, height: CGFloat = 52, showsLabels: Bool = true) {
        self.data = data
        self.theme = theme
        self.height = height
        self.showsLabels = showsLabels
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Group {
                if let selected {
                    CodexV6ChartCallout(datum: selected, theme: theme)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else {
                    Color.clear
                }
            }
            .frame(height: calloutSlotHeight, alignment: .center)

            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 3) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, datum in
                        Button {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.14)) {
                                selectedID = selectedID == datum.id ? nil : datum.id
                            }
                        } label: {
                            VStack(spacing: 3) {
                                CodexThemeColumnBar(
                                    value: fraction(for: datum.value),
                                    theme: theme,
                                    role: index,
                                    maxHeight: max(12, geometry.size.height - (showsLabels ? 14 : 0))
                                )
                                if showsLabels {
                                    chartLabel(datum, isSelected: selectedID == datum.id)
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                            .padding(.horizontal, 1)
                            .overlay {
                                if selectedID == datum.id {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .stroke(theme.accent.opacity(0.55), lineWidth: 1)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in
                            guard hovering else {
                                if selectedID == datum.id { selectedID = nil }
                                return
                            }
                            selectedID = datum.id
                        }
                        .help(tooltip(for: datum))
                        .accessibilityLabel(datum.label)
                        .accessibilityValue(accessibilityValue(for: datum))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: height)
            .padding(.top, 1)
        }
        .onChange(of: data) { _, newData in
            if let selectedID, !newData.contains(where: { $0.id == selectedID }) {
                self.selectedID = nil
            }
        }
    }

    private var selected: CodexV6ChartDatum? {
        guard let selectedID else { return nil }
        return data.first(where: { $0.id == selectedID })
    }

    private var maximum: Int64 {
        max(data.map(\.value).max() ?? 0, 1)
    }

    private func fraction(for value: Int64) -> Double {
        min(max(Double(value) / Double(maximum), 0), 1)
    }

    private func tooltip(for datum: CodexV6ChartDatum) -> String {
        let value = CodexTokenUsage.compactLabel(datum.value)
        return datum.detail.isEmpty ? "\(datum.label): \(value)" : "\(datum.label): \(value) · \(datum.detail)"
    }

    private func accessibilityValue(for datum: CodexV6ChartDatum) -> String {
        let value = CodexTokenUsage.compactLabel(datum.value)
        guard !datum.detail.isEmpty else { return value }
        return "\(value), \(datum.detail)"
    }

    private func chartLabel(_ datum: CodexV6ChartDatum, isSelected: Bool) -> some View {
        Text(datum.label)
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundStyle(isSelected ? theme.accent : Color.secondary.opacity(0.72))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
    }
}

private struct CodexV6ChartCallout: View {
    let datum: CodexV6ChartDatum
    let theme: CodexTheme

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(theme.accent)
                .frame(width: 5, height: 5)
            Text(datum.label)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .lineLimit(1)
            Spacer(minLength: 3)
            Text(CodexTokenUsage.compactLabel(datum.value))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            if !datum.detail.isEmpty {
                Text(datum.detail)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(theme.accent.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(theme.accent.opacity(0.18), lineWidth: 0.6))
        .accessibilityElement(children: .combine)
    }
}
