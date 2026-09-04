import SwiftUI

struct ModelControlSection: View {
    let settings: CodexModelSettings
    let onChange: (String, String) -> Void

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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("New chat defaults")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary.opacity(0.86))
                Spacer()
                Text("\(settings.shortModelName) · \(settings.reasoningLabel)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: models.count),
                spacing: 6
            ) {
                ForEach(models, id: \.value) { option in
                    CodexChoiceButton(
                        option: option,
                        isSelected: settings.model == option.value
                    ) {
                        onChange(option.value, settings.reasoningEffort)
                    }
                }
            }

            Text("REASONING")
                .font(.system(size: 8, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            HStack(spacing: 6) {
                ForEach(reasoning, id: \.value) { option in
                    CodexChoiceButton(
                        option: option,
                        isSelected: settings.reasoningEffort == option.value
                    ) {
                        onChange(settings.model, option.value)
                    }
                }
            }
        }
        .padding(10)
        .background {
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
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.105), lineWidth: 1)
        }
        .help("Choose the model and reasoning for new chats.")
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
    let action: () -> Void
    @Environment(\.codexTheme) private var theme
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if isModel {
                    Image(systemName: isAstra ? "sparkles" : (option.label == "Luna" ? "moon.fill" : (option.label == "Terra" ? "globe.americas.fill" : "sun.max.fill")))
                        .font(.caption2.weight(.bold))
                        .symbolRenderingMode(.hierarchical)
                }
                Text(option.label)
                    .font(.caption.weight(.heavy))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(.white.opacity(isSelected ? 0.98 : 0.88))
            .frame(maxWidth: .infinity)
                .frame(height: isModel ? 48 : 28)
                .background {
                    if isAstra {
                        AstraButtonBackground(isSelected: isSelected, isHovering: isHovering)
                    } else if option.label == "Terra" {
                        TerraButtonBackground(isActive: isSelected || isHovering)
                    } else if isModel {
                        CelestialButtonBackground(isSun: option.label == "Sol", isActive: isSelected || isHovering)
                    } else {
                        buttonFill
                    }
                }
                .overlay(buttonStroke)
                .shadow(
                    color: selectedGlow,
                    radius: isSelected ? (isAstra ? 12 : 8) : 0,
                    y: isSelected ? 2 : 0
                )
                .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var isModel: Bool { option.value.hasPrefix("gpt-") }

    private var isAstra: Bool {
        option.value == CodexModelSettings.astraModel
    }

    private var buttonFill: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .fill(
                LinearGradient(
                    colors: isSelected
                        ? theme.colors.map { $0.opacity(0.48) }
                        : option.colors.map { $0.opacity(isHovering ? 0.32 : 0.18) },
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(isSelected ? 0.08 : (isHovering ? 0.055 : 0.025)))
            }
    }

    private var buttonStroke: some View {
        RoundedRectangle(cornerRadius: 11, style: .continuous)
            .stroke(
                LinearGradient(
                    colors: isAstra && isSelected
                        ? [.white.opacity(0.72), Color(red: 0.74, green: 0.42, blue: 1.00).opacity(0.86)]
                        : isSelected
                        ? [.white.opacity(0.55), option.colors.last?.opacity(0.65) ?? .white.opacity(0.30)]
                        : [.white.opacity(isHovering ? 0.25 : 0.12), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 1.25 : 1
            )
    }

    private var selectedGlow: Color {
        (isAstra ? Color(red: 0.54, green: 0.20, blue: 0.90) : (option.colors.last ?? .accentColor))
            .opacity(isAstra ? 0.52 : 0.38)
    }
}

private struct TerraButtonBackground: View {
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0,
                                paused: reduceMotion || !isVisible || !isActive)) { timeline in
            Canvas { context, size in
                let shape = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 11)
                context.clip(to: shape)
                context.fill(shape, with: .linearGradient(Gradient(colors: [
                    Color(red: 0.13, green: 0.075, blue: 0.045),
                    Color(red: 0.28, green: 0.16, blue: 0.09),
                    Color(red: 0.055, green: 0.22, blue: 0.15)
                ]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
                let center = CGPoint(x: size.width * 0.85, y: size.height * 0.24)
                let time = reduceMotion || !isActive ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.25 + 0.08 * sin(time * 0.9)
                for ring in 0..<4 {
                    let radius = CGFloat(14 + ring * 7)
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(Color(red: 0.70, green: 0.43, blue: 0.24).opacity(0.24)), lineWidth: 0.7)
                }
                let planet = CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22)
                var glow = context
                glow.addFilter(.blur(radius: 5))
                glow.fill(Path(ellipseIn: planet.insetBy(dx: -3, dy: -3)), with: .color(.green.opacity(pulse)))
                context.fill(Path(ellipseIn: planet), with: .linearGradient(Gradient(colors: [
                    Color(red: 0.34, green: 0.73, blue: 0.49),
                    Color(red: 0.075, green: 0.32, blue: 0.21),
                    Color(red: 0.07, green: 0.13, blue: 0.10)
                ]), startPoint: CGPoint(x: planet.minX, y: planet.minY), endPoint: CGPoint(x: planet.maxX, y: planet.maxY)))
                var surface = context
                surface.clip(to: Path(ellipseIn: planet))
                for stripe in 0..<3 {
                    var contour = Path()
                    let y = center.y - 7 + CGFloat(stripe * 6)
                    contour.move(to: CGPoint(x: center.x - 12, y: y))
                    contour.addCurve(to: CGPoint(x: center.x + 12, y: y + 3),
                                     control1: CGPoint(x: center.x - 3, y: y - 7),
                                     control2: CGPoint(x: center.x + 2, y: y + 9))
                    surface.stroke(contour, with: .color(Color(red: 0.83, green: 0.64, blue: 0.37).opacity(0.65)), lineWidth: 1.2)
                }
                context.stroke(Path(ellipseIn: planet), with: .color(.mint.opacity(0.5)), lineWidth: 0.7)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CelestialButtonBackground: View {
    let isSun: Bool
    let isActive: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0,
                                paused: reduceMotion || !isVisible || !isActive)) { timeline in
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size)
                let shape = Path(roundedRect: bounds, cornerRadius: 11)
                context.clip(to: shape)
                let colors: [Color] = isSun
                    ? [Color(red: 0.20, green: 0.055, blue: 0.015), Color(red: 0.43, green: 0.16, blue: 0.025)]
                    : [Color(red: 0.025, green: 0.07, blue: 0.20), Color(red: 0.075, green: 0.19, blue: 0.40)]
                context.fill(shape, with: .linearGradient(Gradient(colors: colors), startPoint: .zero,
                                                         endPoint: CGPoint(x: size.width, y: size.height)))
                let time = reduceMotion || !isActive ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let center = CGPoint(x: size.width * 0.87, y: size.height * 0.23)
                let tint: Color = isSun ? .orange : .cyan
                for ring in 0..<4 {
                    let radius = CGFloat(13 + ring * 9)
                    let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                    context.stroke(Path(ellipseIn: rect), with: .color(tint.opacity(0.10 + Double(3 - ring) * 0.035)), lineWidth: isSun ? 3 : 0.7)
                }
                if isSun {
                    for ray in 0..<16 {
                        let angle = Double(ray) * .pi / 8 + time * 0.035
                        var path = Path()
                        path.move(to: CGPoint(x: center.x + cos(angle) * 12, y: center.y + sin(angle) * 12))
                        path.addLine(to: CGPoint(x: center.x + cos(angle) * 20, y: center.y + sin(angle) * 20))
                        context.stroke(path, with: .color(.orange.opacity(0.45)), lineWidth: 1)
                    }
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)),
                                 with: .radialGradient(Gradient(colors: [.yellow, .orange]), center: center, startRadius: 0, endRadius: 11))
                } else {
                    let moon = CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20)
                    context.fill(Path(ellipseIn: moon), with: .color(Color(red: 0.72, green: 0.88, blue: 1)))
                    context.fill(Path(ellipseIn: moon.offsetBy(dx: 6, dy: -4)), with: .color(colors[1]))
                    for star in 0..<9 {
                        let x = CGFloat((star * 31 + 7) % 100) / 100 * size.width
                        let y = CGFloat((star * 17 + 11) % 47)
                        let alpha = 0.35 + 0.2 * sin(time + Double(star))
                        context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.2, height: 1.2)), with: .color(.white.opacity(alpha)))
                    }
                }
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct AstraButtonBackground: View {
    let isSelected: Bool
    let isHovering: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    private struct Star {
        let x: CGFloat
        let y: CGFloat
        let radius: CGFloat
        let phase: Double
        let speed: Double
        let isFourPoint: Bool
    }

    // Reuse the same constellation across redraws.
    private static let stars: [Star] = [
        Star(x: 0.08, y: 0.24, radius: 1.0, phase: 0.2, speed: 1.6, isFourPoint: true),
        Star(x: 0.19, y: 0.72, radius: 0.8, phase: 1.8, speed: 1.2, isFourPoint: false),
        Star(x: 0.31, y: 0.34, radius: 0.7, phase: 2.7, speed: 1.9, isFourPoint: false),
        Star(x: 0.43, y: 0.78, radius: 1.0, phase: 3.5, speed: 1.4, isFourPoint: true),
        Star(x: 0.54, y: 0.18, radius: 0.8, phase: 4.2, speed: 1.7, isFourPoint: false),
        Star(x: 0.65, y: 0.55, radius: 1.1, phase: 5.1, speed: 1.3, isFourPoint: true),
        Star(x: 0.77, y: 0.28, radius: 0.7, phase: 5.8, speed: 2.0, isFourPoint: false),
        Star(x: 0.90, y: 0.74, radius: 0.9, phase: 6.5, speed: 1.5, isFourPoint: true),
        Star(x: 0.13, y: 0.52, radius: 0.6, phase: 7.1, speed: 1.8, isFourPoint: false),
        Star(x: 0.36, y: 0.12, radius: 0.6, phase: 7.8, speed: 1.1, isFourPoint: false),
        Star(x: 0.60, y: 0.84, radius: 0.7, phase: 8.6, speed: 1.6, isFourPoint: false),
        Star(x: 0.84, y: 0.46, radius: 0.8, phase: 9.3, speed: 1.9, isFourPoint: false),
    ]

    var body: some View {
        TimelineView(
            .animation(minimumInterval: 1.0 / 18.0, paused: reduceMotion || !isVisible || !(isSelected || isHovering))
        ) { timeline in
            Canvas { context, size in
                let bounds = CGRect(origin: .zero, size: size)
                let shape = Path(roundedRect: bounds, cornerRadius: 11)

                context.fill(
                    shape,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color(red: 0.045, green: 0.010, blue: 0.11),
                            Color(red: 0.12, green: 0.020, blue: 0.25),
                            Color(red: 0.25, green: 0.055, blue: 0.44),
                        ]),
                        startPoint: CGPoint(x: 0, y: 0),
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                context.clip(to: shape)

                let time = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                for star in Self.stars {
                    let twinkle = 0.5 + (0.5 * sin(time * star.speed + star.phase))
                    let alpha = (isSelected ? 0.42 : 0.22) + (twinkle * (isSelected ? 0.52 : 0.28))
                    let center = CGPoint(x: size.width * star.x, y: size.height * star.y)
                    let glowRadius = star.radius * (isSelected ? 3.4 : 2.4)
                    let glowRect = CGRect(
                        x: center.x - glowRadius,
                        y: center.y - glowRadius,
                        width: glowRadius * 2,
                        height: glowRadius * 2
                    )

                    var glowContext = context
                    glowContext.addFilter(.blur(radius: max(1, star.radius * 1.8)))
                    glowContext.fill(
                        Path(ellipseIn: glowRect),
                        with: .color(Color(red: 0.72, green: 0.42, blue: 1.00).opacity(alpha * 0.72))
                    )

                    let starPath = star.isFourPoint
                        ? fourPointPath(center: center, radius: star.radius * (1.0 + (twinkle * 0.35)))
                        : Path(ellipseIn: CGRect(
                            x: center.x - star.radius,
                            y: center.y - star.radius,
                            width: star.radius * 2,
                            height: star.radius * 2
                        ))
                    context.fill(starPath, with: .color(.white.opacity(alpha)))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func fourPointPath(center: CGPoint, radius: CGFloat) -> Path {
        let diagonal = radius * 0.42
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius * 2.2))
        path.addLine(to: CGPoint(x: center.x + diagonal, y: center.y - diagonal))
        path.addLine(to: CGPoint(x: center.x + radius * 2.2, y: center.y))
        path.addLine(to: CGPoint(x: center.x + diagonal, y: center.y + diagonal))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 2.2))
        path.addLine(to: CGPoint(x: center.x - diagonal, y: center.y + diagonal))
        path.addLine(to: CGPoint(x: center.x - radius * 2.2, y: center.y))
        path.addLine(to: CGPoint(x: center.x - diagonal, y: center.y - diagonal))
        path.closeSubpath()
        return path
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
