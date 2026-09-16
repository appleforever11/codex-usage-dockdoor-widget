import SwiftUI

struct ModelControlSection: View {
    let settings: CodexModelSettings
    let onChange: (String, String) -> Bool
    let hapticsEnabledOverride: Bool?
    let showsHeader: Bool
    let isEmbedded: Bool
    @AppStorage(CodexHaptics.enabledKey) private var storedHapticsEnabled = true
    @Environment(\.codexTheme) private var theme

    init(
        settings: CodexModelSettings,
        hapticsEnabled: Bool? = nil,
        showsHeader: Bool = true,
        isEmbedded: Bool = false,
        onChange: @escaping (String, String) -> Bool
    ) {
        self.settings = settings
        self.hapticsEnabledOverride = hapticsEnabled
        self.showsHeader = showsHeader
        self.isEmbedded = isEmbedded
        self.onChange = onChange
    }

    private var hapticsEnabled: Bool {
        hapticsEnabledOverride ?? storedHapticsEnabled
    }

    private let models: [CodexPickerOption] = [
        CodexPickerOption(
            label: "Luna",
            value: "gpt-5.6-luna",
            colors: [Color(red: 0.18, green: 0.50, blue: 1.00), Color(red: 0.36, green: 0.22, blue: 0.95)]
        ),
        CodexPickerOption(
            label: "Sol",
            value: "gpt-5.6-sol",
            colors: [Color(red: 1.00, green: 0.60, blue: 0.20), Color(red: 0.95, green: 0.24, blue: 0.44)]
        ),
        CodexPickerOption(
            label: "Terra",
            value: "gpt-5.6-terra",
            colors: [Color(red: 0.48, green: 0.27, blue: 0.14), Color(red: 0.12, green: 0.62, blue: 0.40)]
        ),
        CodexPickerOption(
            label: "Astra",
            value: CodexModelSettings.astraModel,
            colors: [Color(red: 0.10, green: 0.02, blue: 0.24), Color(red: 0.40, green: 0.10, blue: 0.70)]
        ),
    ]

    private let reasoning: [CodexPickerOption] = [
        CodexPickerOption(
            label: "Light",
            value: "low",
            colors: [Color(red: 0.12, green: 0.62, blue: 1.00), Color(red: 0.20, green: 0.82, blue: 0.80)]
        ),
        CodexPickerOption(
            label: "Medium",
            value: "medium",
            colors: [Color(red: 0.58, green: 0.44, blue: 1.00), Color(red: 0.78, green: 0.38, blue: 0.96)]
        ),
        CodexPickerOption(
            label: "Max",
            value: "max",
            colors: [Color(red: 1.00, green: 0.46, blue: 0.24), Color(red: 0.92, green: 0.18, blue: 0.56)]
        ),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsHeader {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("New chat defaults")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary.opacity(0.86))
                    Spacer()
                    Text("\(settings.shortModelName) · \(settings.reasoningLabel)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 16, alignment: .center)
                .padding(.bottom, isEmbedded ? 2 : 0)
            }

            if isEmbedded {
                HStack(spacing: 6) {
                    ForEach(models, id: \.value) { option in
                        modelButton(for: option)
                    }
                }
            } else {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2),
                    spacing: 8
                ) {
                    ForEach(models, id: \.value) { option in
                        modelButton(for: option)
                    }
                }
            }

            VStack(alignment: .leading, spacing: isEmbedded ? 5 : 4) {
                Text("REASONING")
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, isEmbedded ? 2 : 0)

                HStack(spacing: isEmbedded ? 5 : 8) {
                    ForEach(reasoning, id: \.value) { option in
                        CodexChoiceButton(
                            option: option,
                            isSelected: settings.reasoningEffort == option.value,
                            hapticsEnabled: hapticsEnabled,
                            isEmbedded: isEmbedded
                        ) {
                            onChange(settings.model, option.value)
                        }
                    }
                }
            }

            if !isEmbedded {
                HStack(spacing: 3) {
                    Image(systemName: hapticsEnabled ? "waveform" : "waveform.slash")
                        .foregroundStyle(hapticsEnabled ? theme.sharedPurpleGlow : .secondary)
                    Text(hapticsEnabled ? "Hover and select for Mac haptic feedback" : "Hover and selection haptics are off")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Hover and selection haptics")
                .accessibilityValue(hapticsEnabled ? "On" : "Off")
            }
        }
        .padding(isEmbedded ? 0 : 10)
        .background {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.white.opacity(0.070))
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(0.090), .white.opacity(0.025)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
        }
        .overlay {
            if !isEmbedded {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.105), lineWidth: 1)
            }
        }
        .help("Choose the model and reasoning for new chats.")
    }

    @ViewBuilder
    private func modelButton(for option: CodexPickerOption) -> some View {
        CodexIdentityButton(
            identity: CodexTheme(rawValue: option.label) ?? .astra,
            isSelected: settings.model == option.value,
            hapticsEnabled: hapticsEnabled,
            height: isEmbedded ? 52 : 62,
            compact: isEmbedded
        ) {
            if onChange(option.value, settings.reasoningEffort) {
                CodexHaptics.performModelSelectionIfEnabled(hapticsEnabled)
            }
        }
    }
}

private struct CodexPickerOption {
    let label: String
    let value: String
    let colors: [Color]
}

private struct CodexChoiceButton: View {
    let option: CodexPickerOption
    let isSelected: Bool
    let hapticsEnabled: Bool
    let isEmbedded: Bool
    let action: () -> Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button {
            if action() { CodexHaptics.performModelSelectionIfEnabled(hapticsEnabled) }
        } label: {
            Text(option.label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(isSelected ? 1 : 0.88))
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(height: isEmbedded ? 28 : 32)
                .background {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(colors: option.colors.map { $0.opacity(isSelected ? 0.55 : (isHovering ? 0.30 : 0.18)) },
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(LinearGradient(colors: isSelected ? [.white.opacity(0.85), option.colors.last ?? .purple]
                                                     : [.white.opacity(0.20), .white.opacity(0.08)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing),
                                      lineWidth: isSelected ? 1.3 : 0.8)
                }
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .codexHoverHaptics(enabled: hapticsEnabled)
        .onHover { hovering in
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) { isHovering = hovering }
        }
        .accessibilityLabel(option.label)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct CodexModelSettings {
    var model: String
    var reasoningEffort: String

    static let astraModel = "gpt-6-astra"
    static let `default` = CodexModelSettings(model: "gpt-5.6-luna", reasoningEffort: "medium")
    var shortModelName: String {
        if model.localizedCaseInsensitiveContains("astra") { return "Astra" }
        if model.localizedCaseInsensitiveContains("spark") { return "Spark" }
        if model.localizedCaseInsensitiveContains("terra") { return "Terra" }
        if model.localizedCaseInsensitiveContains("luna") { return "Luna" }
        if model.localizedCaseInsensitiveContains("sol") { return "Sol" }
        if model.count > 14 { return String(model.prefix(14)) }
        return model
    }

    var reasoningLabel: String {
        if reasoningEffort == "low" || reasoningEffort == "instant" { return "Light" }
        if reasoningEffort == "max" { return "Max" }
        return reasoningEffort.prefix(1).uppercased() + reasoningEffort.dropFirst()
    }
}
