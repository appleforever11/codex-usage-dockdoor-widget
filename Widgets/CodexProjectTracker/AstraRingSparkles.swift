import SwiftUI
import Darwin

/// Small, deterministic stars follow the filled arc rather than the empty track.
struct AstraRingSparkles: View {
    let progress: Double
    let ringSize: CGFloat
    let lineWidth: CGFloat
    var forceReducedMotion = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false

    var body: some View {
        TimelineView(animationSchedule) { timeline in
            AstraRingSparklesCanvas(
                progress: progress,
                ringSize: ringSize,
                lineWidth: lineWidth,
                date: timeline.date,
                isStatic: reduceMotion || forceReducedMotion
            )
        }
        .frame(width: ringSize + lineWidth * 3, height: ringSize + lineWidth * 3)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var animationSchedule: AnimationTimelineSchedule {
        AnimationTimelineSchedule(
            minimumInterval: 1.0 / 18.0,
            paused: reduceMotion || forceReducedMotion || !isVisible
        )
    }
}

private struct AstraRingSparklesCanvas: View {
    let progress: Double
    let ringSize: CGFloat
    let lineWidth: CGFloat
    let date: Date
    let isStatic: Bool

    var body: some View {
        Canvas { context, size in
            drawSparkles(in: &context, size: size)
        }
    }

    private func drawSparkles(in context: inout GraphicsContext, size: CGSize) {
        let time = isStatic ? 0 : date.timeIntervalSinceReferenceDate
        let count = ringSize < 45 ? 5 : 12
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = ringSize / 2

        for index in 0..<count {
            let seed = Double(index) * 2.39996
            let pulseRate = 1.3 + Double(index % 3) * 0.25
            let pulse = (Darwin.sin(time * pulseRate + seed) + 1) / 2
            let drift = 0.18 * Darwin.sin(time * 0.35 + seed)
            let position = (Double(index) + 0.5 + drift) / Double(count)
            let angle = position * progress * .pi * 2 - .pi / 2
            let orbit = radius + CGFloat(Darwin.sin(seed)) * lineWidth * 0.22
            let point = CGPoint(
                x: center.x + CGFloat(Darwin.cos(angle)) * orbit,
                y: center.y + CGFloat(Darwin.sin(angle)) * orbit
            )
            let arm = max(1.1, lineWidth * 0.38) * (0.65 + pulse * 0.65)
            drawHalo(in: &context, at: point, arm: arm, pulse: pulse)
            context.fill(starPath(at: point, arm: arm), with: .color(.white.opacity(0.35 + pulse * 0.65)))
        }
    }

    private func drawHalo(in context: inout GraphicsContext, at point: CGPoint, arm: CGFloat, pulse: Double) {
        var halo = context
        halo.addFilter(.blur(radius: max(1.4, lineWidth * 0.5)))
        let diameter = arm * 4
        let rect = CGRect(
            x: point.x - arm * 2,
            y: point.y - arm * 2,
            width: diameter,
            height: diameter
        )
        let glow = Color(red: 0.84, green: 0.57, blue: 1).opacity(0.25 + pulse * 0.4)
        halo.fill(Path(ellipseIn: rect), with: .color(glow))
    }

    private func starPath(at point: CGPoint, arm: CGFloat) -> Path {
        let inner = arm * 0.22
        var star = Path()
        star.move(to: CGPoint(x: point.x, y: point.y - arm))
        star.addLine(to: CGPoint(x: point.x + inner, y: point.y - inner))
        star.addLine(to: CGPoint(x: point.x + arm, y: point.y))
        star.addLine(to: CGPoint(x: point.x + inner, y: point.y + inner))
        star.addLine(to: CGPoint(x: point.x, y: point.y + arm))
        star.addLine(to: CGPoint(x: point.x - inner, y: point.y + inner))
        star.addLine(to: CGPoint(x: point.x - arm, y: point.y))
        star.addLine(to: CGPoint(x: point.x - inner, y: point.y - inner))
        star.closeSubpath()
        return star
    }
}
