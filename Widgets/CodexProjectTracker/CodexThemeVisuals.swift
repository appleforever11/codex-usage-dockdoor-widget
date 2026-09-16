import SwiftUI

struct CodexV6VisualTuning: Equatable {
    var sparkleIntensity: Double = 1
    var glowIntensity: Double = 1
    var animationsEnabled: Bool = true
    var highContrast: Bool = false

    static let standard = CodexV6VisualTuning()

    var clampedSparkle: Double { min(max(sparkleIntensity, 0), 1.5) }
    var clampedGlow: Double { min(max(glowIntensity, 0), 1.5) }
}

private struct CodexV6VisualTuningKey: EnvironmentKey {
    static let defaultValue = CodexV6VisualTuning.standard
}

extension EnvironmentValues {
    var codexVisualTuning: CodexV6VisualTuning {
        get { self[CodexV6VisualTuningKey.self] }
        set { self[CodexV6VisualTuningKey.self] = newValue }
    }
}

extension CodexTheme {
    /// Theme-owned data colors keep secondary metrics, bars, and charts inside
    /// the same visual language as the page accent.
    var dataColors: [Color] {
        switch self {
        case .astra:
            return [colors[1], colors[2], Color(red: 0.56, green: 0.28, blue: 0.92), Color(red: 0.93, green: 0.42, blue: 0.90)]
        case .luna:
            return [colors[1], colors[2], Color(red: 0.25, green: 0.56, blue: 0.98), Color(red: 0.35, green: 0.84, blue: 0.92)]
        case .sol:
            return [colors[1], colors[2], Color(red: 1.0, green: 0.38, blue: 0.12), Color(red: 0.96, green: 0.25, blue: 0.16)]
        case .terra:
            return [colors[1], colors[2], Color(red: 0.24, green: 0.91, blue: 0.59), Color(red: 0.82, green: 0.68, blue: 0.28)]
        case .rainbow:
            return colors
        }
    }

    func dataColor(_ index: Int) -> Color {
        let palette = dataColors
        let normalizedIndex = ((index % palette.count) + palette.count) % palette.count
        return palette[normalizedIndex]
    }

    func dataGradient(role: Int = 0) -> LinearGradient {
        LinearGradient(
            colors: [dataColor(role), dataColor(role + 1), dataColor(role + 2)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

let codexThemeAnimationInterval = 1.0 / 18.0

/// A low-contrast animated atmosphere that gives every theme its own living
/// background instead of reserving sparkles for Astra/model selection.
struct CodexThemeAnimatedAtmosphere: View {
    let theme: CodexTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
            let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                RadialGradient(
                    colors: [theme.dataColor(0).opacity(0.12), .clear],
                    center: UnitPoint(x: 0.78 + 0.04 * sin(time * 0.22),
                                      y: 0.16 + 0.03 * cos(time * 0.18)),
                    startRadius: 8,
                    endRadius: 340
                )
                .opacity(0.75)

                RadialGradient(
                    colors: [theme.dataColor(2).opacity(0.08), .clear],
                    center: UnitPoint(x: 0.18 + 0.05 * cos(time * 0.15),
                                      y: 0.82 + 0.04 * sin(time * 0.19)),
                    startRadius: 4,
                    endRadius: 310
                )

                if theme == .rainbow {
                    AngularGradient(gradient: Gradient(colors: theme.dataColors), center: .center)
                        .rotationEffect(.degrees(time * 2.4))
                        .blur(radius: 12)
                        .opacity(0.08)
                }

                CodexThemeSparkleField(
                    theme: theme,
                    time: time,
                    count: Int(Double(theme == .rainbow ? 42 : 34) * (0.45 + tuning.clampedSparkle * 0.55))
                )
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CodexThemeAmbientMotif: View {
    let theme: CodexTheme
    let time: Double

    var body: some View {
        Canvas { context, size in
            let pulse = 0.5 + 0.5 * sin(time * 0.9)
            let center = CGPoint(x: size.width * 0.84, y: size.height * 0.18)
            let radius = min(max(size.width * 0.06, 16), 25)
            switch theme {
            case .astra:
                codexDrawAstraMotif(&context, center: center, radius: radius, pulse: pulse, theme: theme)
            case .luna:
                codexDrawLunaMotif(&context, center: center, radius: radius, pulse: pulse, theme: theme)
            case .sol:
                codexDrawSolMotif(&context, center: center, radius: radius, pulse: pulse, time: time, theme: theme)
            case .terra:
                codexDrawTerraMotif(&context, center: center, radius: radius, pulse: pulse, theme: theme)
            case .rainbow:
                codexDrawRainbowMotif(&context, center: center, radius: radius, pulse: pulse, time: time, theme: theme)
            }
        }
    }
}

private func codexOrbitPath(center: CGPoint, width: CGFloat, height: CGFloat) -> Path {
    Path(ellipseIn: CGRect(x: center.x - width / 2,
                          y: center.y - height / 2,
                          width: width,
                          height: height))
}

private func codexDrawAstraMotif(_ context: inout GraphicsContext,
                                center: CGPoint,
                                radius: CGFloat,
                                pulse: Double,
                                theme: CodexTheme) {
    codexFillGlow(&context, center: center, radius: radius * 3.2, color: theme.dataColor(1), opacity: 0.045)
    let planet = CGRect(x: center.x - radius * 0.72,
                        y: center.y - radius * 0.72,
                        width: radius * 1.44,
                        height: radius * 1.44)
    context.fill(Path(ellipseIn: planet), with: .radialGradient(
        Gradient(colors: [theme.dataColor(2).opacity(0.34 + 0.08 * pulse),
                          theme.dataColor(0).opacity(0.18),
                          theme.base.opacity(0.04)]),
        center: CGPoint(x: planet.midX - radius * 0.22, y: planet.midY - radius * 0.24),
        startRadius: 1,
        endRadius: radius
    ))
    context.stroke(codexOrbitPath(center: center, width: radius * 3.5, height: radius * 1.08),
                   with: .color(theme.dataColor(1).opacity(0.22 + 0.04 * pulse)), lineWidth: 0.9)
    let satellite = CGPoint(x: center.x + radius * 1.45, y: center.y - radius * 0.32)
    context.fill(Path(ellipseIn: CGRect(x: satellite.x - 1.5, y: satellite.y - 1.5, width: 3, height: 3)),
                 with: .color(theme.dataColor(2).opacity(0.58)))
    context.fill(codexSparkPath(center: CGPoint(x: center.x - radius * 1.45, y: center.y - radius * 1.18),
                                radius: radius * 0.22),
                 with: .color(theme.dataColor(2).opacity(0.46 + 0.12 * pulse)))
}

private func codexDrawLunaMotif(_ context: inout GraphicsContext,
                               center: CGPoint,
                               radius: CGFloat,
                               pulse: Double,
                               theme: CodexTheme) {
    codexFillGlow(&context, center: center, radius: radius * 3.0, color: theme.dataColor(2), opacity: 0.05)
    let moonRect = CGRect(x: center.x - radius * 0.84,
                          y: center.y - radius * 0.84,
                          width: radius * 1.68,
                          height: radius * 1.68)
    let shadowRect = CGRect(x: center.x - radius * 0.18,
                            y: center.y - radius * 1.05,
                            width: radius * 1.54,
                            height: radius * 1.54)
    var crescent = Path(ellipseIn: moonRect)
    crescent.addEllipse(in: shadowRect)
    context.fill(crescent,
                 with: .color(theme.dataColor(2).opacity(0.30 + 0.06 * pulse)),
                 style: FillStyle(eoFill: true))
    context.stroke(codexOrbitPath(center: center, width: radius * 3.25, height: radius * 1.10),
                   with: .color(theme.dataColor(1).opacity(0.20 + 0.04 * pulse)), lineWidth: 0.8)
    let star = CGPoint(x: center.x - radius * 1.38, y: center.y + radius * 0.95)
    context.fill(codexSparkPath(center: star, radius: radius * 0.20),
                 with: .color(theme.dataColor(2).opacity(0.44 + 0.10 * pulse)))
}

private func codexDrawSolMotif(_ context: inout GraphicsContext,
                              center: CGPoint,
                              radius: CGFloat,
                              pulse: Double,
                              time: Double,
                              theme: CodexTheme) {
    codexFillGlow(&context, center: center, radius: radius * 3.2, color: theme.dataColor(1), opacity: 0.055)
    for ray in 0..<12 {
        let angle = Double(ray) / 12.0 * 2.0 * .pi + time * 0.035
        let inner = radius * (1.15 + 0.08 * pulse)
        let outer = radius * (1.65 + 0.10 * pulse)
        var path = Path()
        path.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner,
                              y: center.y + CGFloat(sin(angle)) * inner))
        path.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer,
                                 y: center.y + CGFloat(sin(angle)) * outer))
        context.stroke(path, with: .color(theme.dataColor(ray).opacity(0.15)), lineWidth: 0.9)
    }
    let sun = CGRect(x: center.x - radius * 0.78,
                     y: center.y - radius * 0.78,
                     width: radius * 1.56,
                     height: radius * 1.56)
    context.fill(Path(ellipseIn: sun), with: .radialGradient(
        Gradient(colors: [theme.dataColor(2).opacity(0.46 + 0.08 * pulse),
                          theme.dataColor(1).opacity(0.24),
                          theme.dataColor(0).opacity(0.12)]),
        center: CGPoint(x: sun.midX - radius * 0.20, y: sun.midY - radius * 0.25),
        startRadius: 1,
        endRadius: radius
    ))
}

private func codexDrawTerraMotif(_ context: inout GraphicsContext,
                                center: CGPoint,
                                radius: CGFloat,
                                pulse: Double,
                                theme: CodexTheme) {
    codexFillGlow(&context, center: center, radius: radius * 3.1, color: theme.dataColor(2), opacity: 0.045)
    let planet = CGRect(x: center.x - radius * 0.86,
                        y: center.y - radius * 0.86,
                        width: radius * 1.72,
                        height: radius * 1.72)
    context.fill(Path(ellipseIn: planet), with: .radialGradient(
        Gradient(colors: [theme.dataColor(2).opacity(0.42 + 0.07 * pulse),
                          theme.dataColor(1).opacity(0.24),
                          theme.base.opacity(0.10)]),
        center: CGPoint(x: planet.midX - radius * 0.24, y: planet.midY - radius * 0.25),
        startRadius: 1,
        endRadius: radius * 1.15
    ))

    var surface = context
    surface.clip(to: Path(ellipseIn: planet))
    var latitude = Path()
    latitude.move(to: CGPoint(x: center.x - radius, y: center.y - radius * 0.18))
    latitude.addCurve(to: CGPoint(x: center.x + radius, y: center.y + radius * 0.06),
                     control1: CGPoint(x: center.x - radius * 0.30, y: center.y - radius * 0.58),
                     control2: CGPoint(x: center.x + radius * 0.25, y: center.y + radius * 0.45))
    surface.stroke(latitude, with: .color(theme.dataColor(2).opacity(0.36)), lineWidth: 0.8)
    var longitude = Path()
    longitude.move(to: CGPoint(x: center.x - radius * 0.30, y: center.y - radius))
    longitude.addCurve(to: CGPoint(x: center.x - radius * 0.08, y: center.y + radius),
                       control1: CGPoint(x: center.x + radius * 0.58, y: center.y - radius * 0.38),
                       control2: CGPoint(x: center.x + radius * 0.58, y: center.y + radius * 0.36))
    surface.stroke(longitude, with: .color(theme.dataColor(1).opacity(0.34)), lineWidth: 0.8)

    context.stroke(codexOrbitPath(center: center, width: radius * 3.45, height: radius * 1.12),
                   with: .color(theme.dataColor(2).opacity(0.26 + 0.04 * pulse)), lineWidth: 0.9)
    let satellite = CGPoint(x: center.x + radius * 1.47, y: center.y - radius * 0.40)
    context.fill(Path(ellipseIn: CGRect(x: satellite.x - 1.8, y: satellite.y - 1.8, width: 3.6, height: 3.6)),
                 with: .color(theme.dataColor(2).opacity(0.60)))
}

private func codexDrawRainbowMotif(_ context: inout GraphicsContext,
                                  center: CGPoint,
                                  radius: CGFloat,
                                  pulse: Double,
                                  time: Double,
                                  theme: CodexTheme) {
    codexFillGlow(&context, center: center, radius: radius * 3.2, color: theme.dataColor(5), opacity: 0.04)
    let planet = CGRect(x: center.x - radius * 0.72,
                        y: center.y - radius * 0.72,
                        width: radius * 1.44,
                        height: radius * 1.44)
    context.fill(Path(ellipseIn: planet), with: .radialGradient(
        Gradient(colors: [theme.dataColor(5).opacity(0.34 + 0.06 * pulse),
                          theme.dataColor(0).opacity(0.22),
                          theme.base.opacity(0.05)]),
        center: CGPoint(x: planet.midX - radius * 0.18, y: planet.midY - radius * 0.20),
        startRadius: 1,
        endRadius: radius
    ))
    for orbit in 0..<3 {
        let orbitCenter = CGPoint(x: center.x, y: center.y + CGFloat(orbit - 1) * radius * 0.08)
        context.stroke(codexOrbitPath(center: orbitCenter,
                                      width: radius * CGFloat(2.7 + Double(orbit) * 0.35),
                                      height: radius * CGFloat(0.82 + Double(orbit) * 0.12)),
                       with: .color(theme.dataColor(orbit + Int(time * 0.08)).opacity(0.18 + 0.04 * pulse)),
                       lineWidth: 0.8)
    }
    let sparkle = CGPoint(x: center.x - radius * 1.42, y: center.y - radius * 1.04)
    context.fill(codexSparkPath(center: sparkle, radius: radius * 0.22),
                 with: .color(theme.dataColor(Int(time * 0.12)).opacity(0.48 + 0.12 * pulse)))
}

private func codexFillGlow(_ context: inout GraphicsContext,
                           center: CGPoint,
                           radius: CGFloat,
                           color: Color,
                           opacity: Double) {
    var glow = context
    glow.addFilter(.blur(radius: radius * 0.34))
    glow.fill(Path(ellipseIn: CGRect(x: center.x - radius * 0.55,
                                     y: center.y - radius * 0.55,
                                     width: radius * 1.1,
                                     height: radius * 1.1)),
              with: .color(color.opacity(opacity)))
}

/// A compact, theme-owned planet marker for filter metadata. It keeps the
/// planet language intentional and legible instead of placing a large,
/// ambiguous shape behind the label.
struct CodexThemePlanetMarker: View {
    let theme: CodexTheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
            let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let pulse = 0.5 + 0.5 * sin(time * 0.9)
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) * 0.30
                let planet = CGRect(x: center.x - radius,
                                    y: center.y - radius,
                                    width: radius * 2,
                                    height: radius * 2)

                var glow = context
                glow.addFilter(.blur(radius: 3.8))
                glow.fill(Path(ellipseIn: planet.insetBy(dx: -2.5, dy: -2.5)),
                          with: .color(theme.dataColor(1).opacity(0.18 + 0.08 * pulse)))

                switch theme {
                case .astra:
                    context.fill(Path(ellipseIn: planet), with: .radialGradient(
                        Gradient(colors: [theme.dataColor(2).opacity(0.92),
                                          theme.dataColor(0).opacity(0.65),
                                          theme.base.opacity(0.55)]),
                        center: CGPoint(x: planet.midX - radius * 0.25,
                                        y: planet.midY - radius * 0.28),
                        startRadius: 0.5,
                        endRadius: radius * 1.25
                    ))
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - size.width * 0.45,
                                                           y: center.y - size.height * 0.22,
                                                           width: size.width * 0.90,
                                                           height: size.height * 0.44)),
                                       with: .color(theme.dataColor(2).opacity(0.7)), lineWidth: 0.75)
                    context.fill(codexSparkPath(center: CGPoint(x: center.x - radius * 1.25,
                                                                y: center.y - radius * 1.0),
                                                radius: 1.5),
                                 with: .color(.white.opacity(0.82)))

                case .luna:
                    var crescent = Path(ellipseIn: planet)
                    crescent.addEllipse(in: CGRect(x: center.x - radius * 0.15,
                                                   y: center.y - radius * 1.08,
                                                   width: radius * 1.55,
                                                   height: radius * 1.55))
                    context.fill(crescent,
                                 with: .color(theme.dataColor(2).opacity(0.90)),
                                 style: FillStyle(eoFill: true))
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - size.width * 0.45,
                                                           y: center.y - size.height * 0.20,
                                                           width: size.width * 0.90,
                                                           height: size.height * 0.40)),
                                       with: .color(theme.dataColor(1).opacity(0.62)), lineWidth: 0.7)
                    context.fill(codexSparkPath(center: CGPoint(x: center.x + radius * 1.15,
                                                                y: center.y - radius * 0.95),
                                                radius: 1.2),
                                 with: .color(.white.opacity(0.76)))

                case .sol:
                    for ray in 0..<8 {
                        let angle = Double(ray) / 8.0 * 2.0 * .pi + time * 0.04
                        let inner = radius * 1.22
                        let outer = radius * (1.65 + 0.10 * pulse)
                        var rayPath = Path()
                        rayPath.move(to: CGPoint(x: center.x + CGFloat(cos(angle)) * inner,
                                                 y: center.y + CGFloat(sin(angle)) * inner))
                        rayPath.addLine(to: CGPoint(x: center.x + CGFloat(cos(angle)) * outer,
                                                    y: center.y + CGFloat(sin(angle)) * outer))
                        context.stroke(rayPath,
                                       with: .color(theme.dataColor(ray).opacity(0.72)), lineWidth: 0.7)
                    }
                    context.fill(Path(ellipseIn: planet), with: .radialGradient(
                        Gradient(colors: [theme.dataColor(2).opacity(0.98),
                                          theme.dataColor(1).opacity(0.80),
                                          theme.dataColor(0).opacity(0.62)]),
                        center: CGPoint(x: planet.midX - radius * 0.2,
                                        y: planet.midY - radius * 0.25),
                        startRadius: 0.5,
                        endRadius: radius * 1.2
                    ))

                case .terra:
                    context.fill(Path(ellipseIn: planet), with: .radialGradient(
                        Gradient(colors: [theme.dataColor(2).opacity(0.95),
                                          theme.dataColor(1).opacity(0.70),
                                          theme.base.opacity(0.64)]),
                        center: CGPoint(x: planet.midX - radius * 0.2,
                                        y: planet.midY - radius * 0.25),
                        startRadius: 0.5,
                        endRadius: radius * 1.25
                    ))
                    var globe = context
                    globe.clip(to: Path(ellipseIn: planet))
                    var latitude = Path()
                    latitude.move(to: CGPoint(x: center.x - radius,
                                              y: center.y - radius * 0.05))
                    latitude.addCurve(to: CGPoint(x: center.x + radius,
                                                  y: center.y + radius * 0.05),
                                     control1: CGPoint(x: center.x - radius * 0.35,
                                                       y: center.y - radius * 0.50),
                                     control2: CGPoint(x: center.x + radius * 0.30,
                                                       y: center.y + radius * 0.50))
                    globe.stroke(latitude, with: .color(theme.dataColor(2).opacity(0.70)), lineWidth: 0.6)
                    var longitude = Path()
                    longitude.move(to: CGPoint(x: center.x,
                                               y: center.y - radius))
                    longitude.addCurve(to: CGPoint(x: center.x,
                                                   y: center.y + radius),
                                      control1: CGPoint(x: center.x + radius * 0.50,
                                                        y: center.y - radius * 0.35),
                                      control2: CGPoint(x: center.x + radius * 0.50,
                                                        y: center.y + radius * 0.35))
                    globe.stroke(longitude, with: .color(theme.dataColor(1).opacity(0.65)), lineWidth: 0.6)
                    context.stroke(Path(ellipseIn: CGRect(x: center.x - size.width * 0.45,
                                                           y: center.y - size.height * 0.22,
                                                           width: size.width * 0.90,
                                                           height: size.height * 0.44)),
                                       with: .color(theme.dataColor(2).opacity(0.64)), lineWidth: 0.7)

                case .rainbow:
                    context.fill(Path(ellipseIn: planet), with: .color(theme.dataColor(4).opacity(0.76)))
                    for orbit in 0..<3 {
                        let orbitRect = CGRect(x: center.x - size.width * (0.38 + CGFloat(orbit) * 0.05),
                                               y: center.y - size.height * (0.20 + CGFloat(orbit) * 0.04),
                                               width: size.width * (0.76 + CGFloat(orbit) * 0.10),
                                               height: size.height * (0.40 + CGFloat(orbit) * 0.08))
                        context.stroke(Path(ellipseIn: orbitRect),
                                       with: .color(theme.dataColor(orbit + Int(time * 0.08)).opacity(0.68)),
                                       lineWidth: 0.65)
                    }
                }
            }
        }
        .frame(width: 28, height: 20)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct CodexThemeSparkleField: View {
    let theme: CodexTheme
    let time: Double
    let count: Int
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        Canvas { context, size in
            for index in 0..<count {
                let phase = Double(index) * 0.77
                let xBase = CGFloat((index * 47 + 11) % 101) / 100.0
                let yBase = CGFloat((index * 71 + 19) % 97) / 96.0
                let driftX = CGFloat(sin(time * (0.10 + Double(index % 4) * 0.035) + phase)) * size.width * 0.018
                let driftY = CGFloat(cos(time * (0.08 + Double(index % 5) * 0.025) + phase)) * size.height * 0.012
                let x = min(max(xBase * size.width + driftX, 2), max(size.width - 2, 2))
                let y = min(max(yBase * size.height + driftY, 2), max(size.height - 2, 2))
                let twinkle = (0.32 + 0.68 * ((sin(time * (0.72 + Double(index % 6) * 0.11) + phase) + 1) / 2)) * tuning.clampedSparkle
                let radius = CGFloat(index.isMultiple(of: 5) ? 1.05 : 0.55) * (0.75 + 0.35 * CGFloat(twinkle))
                let color = theme.dataColor(index + Int(time * 0.18))
                let center = CGPoint(x: x, y: y)

                var glow = context
                glow.addFilter(.blur(radius: 4 + radius * 3))
                glow.fill(Path(ellipseIn: CGRect(x: x - radius * 1.8,
                                                  y: y - radius * 1.8,
                                                  width: radius * 3.6,
                                                  height: radius * 3.6)),
                           with: .color(color.opacity(0.18 * twinkle)))

                if index.isMultiple(of: 4) {
                    context.fill(codexSparkPath(center: center, radius: radius * 2.9),
                                 with: .color(color.opacity(0.30 * twinkle)))
                } else {
                    context.fill(Path(ellipseIn: CGRect(x: x - radius,
                                                         y: y - radius,
                                                         width: radius * 2,
                                                         height: radius * 2)),
                                 with: .color(color.opacity(0.18 * twinkle)))
                }
            }
        }
    }
}

enum CodexThemeBarOrientation {
    case horizontal
    case column
}

/// A tiny breathing flare placed inside each filled data bar. Keeping this as
/// a reusable primitive makes charts feel related without adding a global
/// timer or making every card implement its own animation.
struct CodexThemeBarSparkle: View {
    let theme: CodexTheme
    let time: Double
    let seed: Double
    let orientation: CodexThemeBarOrientation
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        Canvas { context, size in
            guard size.width > 4, size.height > 2 else { return }
            let pulse = (0.5 + 0.5 * sin(time * (1.05 + seed.truncatingRemainder(dividingBy: 3) * 0.08) + seed)) * tuning.clampedSparkle
            let travel = 0.5 + 0.5 * sin(time * 0.72 + seed * 1.7)
            let point: CGPoint
            switch orientation {
            case .horizontal:
                point = CGPoint(x: size.width * (0.42 + 0.42 * travel), y: size.height / 2)
            case .column:
                point = CGPoint(x: size.width * (0.28 + 0.44 * travel), y: max(2, size.height * 0.14))
            }
            let arm = max(0.9, min(2.2, size.height * 0.42)) * (0.76 + 0.34 * pulse)
            let color = theme.dataColor(Int(abs(seed)))

            var glow = context
            glow.addFilter(.blur(radius: max(2, arm * 2.2)))
            glow.fill(Path(ellipseIn: CGRect(x: point.x - arm * 2.2,
                                              y: point.y - arm * 2.2,
                                              width: arm * 4.4,
                                              height: arm * 4.4)),
                      with: .color(color.opacity(0.22 + 0.18 * pulse)))
            context.fill(codexSparkPath(center: point, radius: arm),
                         with: .color(.white.opacity(0.28 + 0.42 * pulse)))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The quota ring uses the same theme-aware sparkle treatment in the compact
/// widget, the legacy panel, and the v6 dashboard card.
struct CodexThemeRingSparkles: View {
    let progress: Double
    let ringSize: CGFloat
    let lineWidth: CGFloat
    let theme: CodexTheme
    var forceReducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                paused: reduceMotion || forceReducedMotion || !tuning.animationsEnabled)) { timeline in
            Canvas { context, size in
                let clamped = min(max(progress, 0), 1)
                guard clamped > 0 else { return }
                let time = reduceMotion || forceReducedMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let count = ringSize < 45 ? 5 : max(8, Int(ringSize / 7))
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = ringSize / 2

                for index in 0..<count {
                    let seed = Double(index) * 2.39996
                    let pulse = ((sin(time * (1.25 + Double(index % 3) * 0.25) + seed) + 1) / 2) * tuning.clampedSparkle
                    let drift = 0.16 * sin(time * 0.35 + seed)
                    let position = (Double(index) + 0.5 + drift) / Double(count)
                    let angle = position * clamped * .pi * 2 - .pi / 2
                    let orbit = radius + CGFloat(sin(seed)) * lineWidth * 0.22
                    let point = CGPoint(x: center.x + CGFloat(cos(angle)) * orbit,
                                        y: center.y + CGFloat(sin(angle)) * orbit)
                    let arm = max(1.1, lineWidth * 0.38) * (0.65 + pulse * 0.65)
                    let color = theme.dataColor(index)

                    var halo = context
                    halo.addFilter(.blur(radius: max(1.4, lineWidth * 0.5)))
                    halo.fill(Path(ellipseIn: CGRect(x: point.x - arm * 2,
                                                      y: point.y - arm * 2,
                                                      width: arm * 4,
                                                      height: arm * 4)),
                              with: .color(color.opacity(0.24 + pulse * 0.40)))
                    context.fill(codexSparkPath(center: point, radius: arm),
                                 with: .color(.white.opacity(0.35 + pulse * 0.65)))
                }
            }
        }
        .frame(width: ringSize + lineWidth * 3, height: ringSize + lineWidth * 3)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

func codexSparkPath(center: CGPoint, radius: CGFloat) -> Path {
    var path = Path()
    path.move(to: CGPoint(x: center.x, y: center.y - radius))
    path.addLine(to: CGPoint(x: center.x + radius * 0.30, y: center.y - radius * 0.30))
    path.addLine(to: CGPoint(x: center.x + radius, y: center.y))
    path.addLine(to: CGPoint(x: center.x + radius * 0.30, y: center.y + radius * 0.30))
    path.addLine(to: CGPoint(x: center.x, y: center.y + radius))
    path.addLine(to: CGPoint(x: center.x - radius * 0.30, y: center.y + radius * 0.30))
    path.addLine(to: CGPoint(x: center.x - radius, y: center.y))
    path.addLine(to: CGPoint(x: center.x - radius * 0.30, y: center.y - radius * 0.30))
    path.closeSubpath()
    return path
}

struct CodexThemeCardSurface: View {
    let theme: CodexTheme
    let cornerRadius: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                paused: reduceMotion)) { timeline in
            let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(time * 0.75)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.white.opacity((tuning.highContrast ? 0.065 : 0.048) + 0.012 * pulse))
                LinearGradient(colors: [theme.dataColor(0).opacity(0.12),
                                         theme.dataColor(1).opacity(0.035),
                                         .clear],
                               startPoint: .topLeading,
                               endPoint: .bottomTrailing)
                RadialGradient(colors: [theme.dataColor(2).opacity(0.065 + 0.025 * pulse), .clear],
                               center: UnitPoint(x: 0.72 + 0.08 * sin(time * 0.16),
                                                 y: 0.16 + 0.05 * cos(time * 0.13)),
                               startRadius: 4,
                               endRadius: 180)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

struct CodexThemeCardGlow: View {
    let theme: CodexTheme
    let cornerRadius: CGFloat
    let isEditing: Bool
    var isHighlighted = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    var body: some View {
        TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
            let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(time * 0.9)
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(theme.accent.opacity(((isEditing || isHighlighted) ? 0.30 : 0.16) + 0.05 * pulse),
                                  lineWidth: isEditing || tuning.highContrast ? 1.2 : 0.9)
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(theme.dataGradient(role: 1), lineWidth: 1.4)
                    .blur(radius: 4.5)
                    .opacity((0.10 + 0.08 * pulse) * tuning.clampedGlow)
            }
        }
        .allowsHitTesting(false)
    }
}

struct CodexThemeMetricSurface: View {
    let theme: CodexTheme
    let tint: Color
    let showsOutline: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    init(theme: CodexTheme, tint: Color, showsOutline: Bool = false) {
        self.theme = theme
        self.tint = tint
        self.showsOutline = showsOutline
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                    paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
                let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let pulse = 0.5 + 0.5 * sin(time * 1.0)
                let glowWidth = min(max(geometry.size.width * 0.62, 18), 72)
                let glowHeight = min(max(geometry.size.height * 1.05, 18), 40)
                let cornerRadius = min(12, max(9, geometry.size.height * 0.30))
                ZStack {
                    if showsOutline {
                        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        shape
                            .fill(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.075 + 0.018 * pulse),
                                        theme.base.opacity(0.055),
                                        theme.dataColor(2).opacity(0.045 + 0.018 * pulse)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        shape
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        tint.opacity(0.28 + 0.07 * pulse),
                                        theme.dataColor(2).opacity(0.17 + 0.04 * pulse),
                                        tint.opacity(0.23 + 0.05 * pulse)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                lineWidth: tuning.highContrast ? 1.1 : 0.8
                            )
                        shape
                            .strokeBorder(tint.opacity(0.10 + 0.04 * pulse), lineWidth: 3)
                            .blur(radius: 4)
                            .opacity(tuning.clampedGlow)
                    }

                    // A small blurred ellipse keeps the theme alive inside
                    // the clean outline without exposing jagged tile edges.
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [
                                    tint.opacity((tuning.highContrast ? 0.10 : 0.055) + 0.025 * pulse),
                                    theme.dataColor(2).opacity(0.018 + 0.012 * pulse)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: glowWidth, height: glowHeight)
                        .blur(radius: 7 + 2 * pulse)
                        .offset(x: CGFloat(sin(time * 0.65) * min(geometry.size.width * 0.05, 4)))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .opacity(tuning.clampedGlow)
                }
            }
        }
    }
}

struct CodexThemeProgressBar: View {
    let value: Double?
    let theme: CodexTheme
    let height: CGFloat
    let role: Int
    let tint: Color?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    init(value: Double?, theme: CodexTheme, height: CGFloat = 5, role: Int = 0, tint: Color? = nil) {
        self.value = value
        self.theme = theme
        self.height = height
        self.role = role
        self.tint = tint
    }

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                    paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
                let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let fraction = min(max(value ?? 0, 0), 1)
                let fillWidth = geometry.size.width * CGFloat(fraction)
                let primary = tint ?? theme.dataColor(role)
                let highlightWidth = min(30, max(10, fillWidth * 0.42))
                let highlightProgress = 0.5 + 0.5 * sin(time * 1.35 + Double(role))
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.dataColor(role).opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [primary, theme.dataColor(role + 1), theme.dataColor(role + 2)],
                                             startPoint: .leading,
                                             endPoint: .trailing))
                        .frame(width: fillWidth)
                        .overlay(alignment: .leading) {
                            if !reduceMotion && tuning.animationsEnabled && fillWidth > 2 {
                                Capsule()
                                    .fill(.white.opacity(0.22))
                                    .frame(width: highlightWidth, height: height)
                                    .offset(x: max(0, fillWidth - highlightWidth) * CGFloat(highlightProgress))
                                    .blur(radius: 2)
                            }
                        }
                        .overlay {
                            if fillWidth > 5 && tuning.clampedSparkle > 0.05 {
                                CodexThemeBarSparkle(theme: theme, time: time, seed: Double(role), orientation: .horizontal)
                            }
                        }
                        .clipShape(Capsule())
                        .shadow(color: primary.opacity((0.30 + 0.12 * highlightProgress) * tuning.clampedGlow), radius: 3 + tuning.clampedGlow)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: height)
    }
}

struct CodexThemeColumnBar: View {
    let value: Double
    let theme: CodexTheme
    let role: Int
    let maxHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.codexVisualTuning) private var tuning

    init(value: Double, theme: CodexTheme, role: Int = 0, maxHeight: CGFloat = 42) {
        self.value = value
        self.theme = theme
        self.role = role
        self.maxHeight = maxHeight
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            TimelineView(.animation(minimumInterval: codexThemeAnimationInterval,
                                    paused: reduceMotion || !tuning.animationsEnabled)) { timeline in
                let time = reduceMotion || !tuning.animationsEnabled ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let fraction = min(max(value, 0), 1)
                let pulse = 0.5 + 0.5 * sin(time * 1.1 + Double(role))
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(theme.dataGradient(role: role))
                    .frame(height: max(3, maxHeight * CGFloat(fraction)))
                    .shadow(color: theme.dataColor(role).opacity((0.23 + 0.12 * pulse) * tuning.clampedGlow), radius: 3 + tuning.clampedGlow)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(.white.opacity(0.12 + 0.08 * pulse))
                            .frame(height: 1)
                    }
                    .overlay {
                        if fraction > 0.18 && tuning.clampedSparkle > 0.05 {
                            CodexThemeBarSparkle(theme: theme, time: time, seed: Double(role), orientation: .column)
                        }
                    }
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
    }
}
