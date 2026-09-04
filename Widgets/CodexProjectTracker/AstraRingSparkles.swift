import SwiftUI

/// Small, deterministic stars follow the filled arc rather than the empty track.
struct AstraRingSparkles: View {
    let progress: Double
    let ringSize: CGFloat
    let lineWidth: CGFloat
    var forceReducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0,
                                paused: reduceMotion || forceReducedMotion || !isVisible)) { timeline in
            Canvas { context, size in
                let time = reduceMotion || forceReducedMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
                let count = ringSize < 45 ? 5 : 12
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = ringSize / 2
                for index in 0..<count {
                    let seed = Double(index) * 2.39996
                    let pulse = (sin(time * (1.3 + Double(index % 3) * 0.25) + seed) + 1) / 2
                    let position = (Double(index) + 0.5 + 0.18 * sin(time * 0.35 + seed)) / Double(count)
                    let angle = position * progress * .pi * 2 - .pi / 2
                    let orbit = radius + sin(seed) * lineWidth * 0.22
                    let point = CGPoint(x: center.x + cos(angle) * orbit,
                                        y: center.y + sin(angle) * orbit)
                    let arm = max(1.1, lineWidth * 0.38) * (0.65 + pulse * 0.65)
                    var halo = context
                    halo.addFilter(.blur(radius: max(1.4, lineWidth * 0.5)))
                    halo.fill(Path(ellipseIn: CGRect(x: point.x - arm * 2, y: point.y - arm * 2,
                                                    width: arm * 4, height: arm * 4)),
                              with: .color(Color(red: 0.84, green: 0.57, blue: 1).opacity(0.25 + pulse * 0.4)))
                    var star = Path()
                    let inner = arm * 0.22
                    star.move(to: CGPoint(x: point.x, y: point.y - arm))
                    star.addLine(to: CGPoint(x: point.x + inner, y: point.y - inner))
                    star.addLine(to: CGPoint(x: point.x + arm, y: point.y))
                    star.addLine(to: CGPoint(x: point.x + inner, y: point.y + inner))
                    star.addLine(to: CGPoint(x: point.x, y: point.y + arm))
                    star.addLine(to: CGPoint(x: point.x - inner, y: point.y + inner))
                    star.addLine(to: CGPoint(x: point.x - arm, y: point.y))
                    star.addLine(to: CGPoint(x: point.x - inner, y: point.y - inner))
                    star.closeSubpath()
                    context.fill(star, with: .color(.white.opacity(0.35 + pulse * 0.65)))
                }
            }
        }
        .frame(width: ringSize + lineWidth * 3, height: ringSize + lineWidth * 3)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
