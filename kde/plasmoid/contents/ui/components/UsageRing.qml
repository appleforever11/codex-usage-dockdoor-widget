import QtQuick
import "../lib/Theme.js" as Theme

// Port of UsageRingView + CodexThemeRingSparkles: track, glow arc, gradient
// arc starting at 12 o'clock, bold percentage, and theme-colored sparkles
// that ride the filled arc only. Qt Quick Canvas has no CSS filter(), so the
// Swift blur layers are reproduced with shadowBlur (arc glow) and radial
// gradients (sparkle halos).
//
// Style variants (ringStyle):
//   gradient — the original: gradient arc + glow + sparkles
//   solid    — one clean accent arc, no glow
//   dual     — gradient arc plus a thin inner companion ring
//   segments — discrete filled/dim segments around the circle
//   ticks    — dial ticks that light up as usage fills
Item {
    id: ring

    property var theme: Theme.theme("Astra")
    property double percentRemaining: 0
    property double lineWidth: 7
    property bool showsPercent: true   // the built-in center label
    property double sparkleIntensity: 1
    property bool animationsEnabled: true
    property string ringStyle: "gradient"
    property bool sparklesEnabled: true
    property var clock: null        // shared AnimationClock; may be null
    readonly property double animTime: clock ? clock.time : 0

    readonly property string style: {
        const value = String(ringStyle).toLowerCase();
        return ["gradient", "solid", "dual", "segments", "ticks"].indexOf(value) >= 0
            ? value : "gradient";
    }
    readonly property bool styleHasSparkles: style === "gradient" || style === "solid" || style === "dual"
    readonly property bool sparklesActive: sparklesEnabled && styleHasSparkles && animationsEnabled

    readonly property double clamped: isFinite(percentRemaining) ? Math.max(0, Math.min(1, percentRemaining)) : 0
    readonly property int sparkleCount: width < 45 ? 5 : Math.max(8, Math.floor(width / 7))

    onPercentRemainingChanged: _arcs.requestPaint()
    onThemeChanged: _arcs.requestPaint()
    onAnimTimeChanged: if (animationsEnabled && clamped > 0) _sparkles.requestPaint()
    onWidthChanged: _arcs.requestPaint()
    onStyleChanged: _arcs.requestPaint()

    Canvas {
        id: _arcs
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const size = Math.min(width, height);
            const center = size / 2;
            const lw = ring.lineWidth;
            const clamped = ring.clamped;
            const start = -Math.PI / 2;
            const span = clamped * Math.PI * 2;
            const theme = ring.theme;

            // AngularGradient approximation across the filled arc from the
            // theme dataSource palette — shared by the arc styles.
            const grad = ctx.createLinearGradient(0, 0, size, size);
            for (let i = 0; i <= 4; ++i) {
                const f = i / 4;
                grad.addColorStop(f, Theme.rgba(Theme.dataColor(theme, f * 3), 1));
            }

            switch (ring.style) {
            case "solid": {
                drawTrack(ctx, center, lw);
                if (clamped > 0) arc(ctx, center, center - lw / 2, start, start + span, lw, Theme.rgba(theme.accent, 1));
                break;
            }
            case "dual": {
                drawTrack(ctx, center, lw);
                const innerLw = Math.max(1.5, lw * 0.45);
                const innerR = center - lw - lw * 0.45;
                if (innerR > innerLw) {
                    ctx.beginPath();
                    ctx.arc(center, center, innerR, 0, Math.PI * 2);
                    ctx.lineWidth = innerLw;
                    ctx.strokeStyle = Theme.rgba(theme.accent, 0.14);
                    ctx.stroke();
                    if (clamped > 0)
                        arc(ctx, center, innerR, start, start + span, innerLw,
                            Theme.rgba(Theme.dataColor(theme, 1), 0.95));
                }
                if (clamped > 0) {
                    ctx.save();
                    ctx.shadowColor = Theme.rgba(theme.accent, 0.40);
                    ctx.shadowBlur = Math.max(2, lw * 0.5);
                    arc(ctx, center, center - lw / 2, start, start + span, lw, grad);
                    ctx.restore();
                }
                break;
            }
            case "segments": {
                const count = Math.max(10, Math.min(30, Math.round(size / 5.5)));
                const segLw = Math.min(lw, center * 0.24);
                const radius = center - segLw / 2;
                const step = Math.PI * 2 / count;
                const gap = step * 0.30;
                for (let i = 0; i < count; ++i) {
                    const segStart = start + i * step + gap / 2;
                    const filled = (i + 0.5) / count <= clamped;
                    arc(ctx, center, radius, segStart, segStart + (step - gap), segLw,
                        filled ? Theme.rgba(Theme.dataColor(theme, i), 1)
                               : Theme.rgba(theme.accent, 0.14));
                }
                break;
            }
            case "ticks": {
                const count = Math.max(18, Math.min(44, Math.round(size / 3.4)));
                const tickLw = Math.max(1, Math.min(lw * 0.55, center * 0.09));
                const outer = center - tickLw * 0.8;
                const inner = Math.max(outer - lw * 1.7, center * 0.42);
                for (let i = 0; i < count; ++i) {
                    const angle = start + (i + 0.5) / count * Math.PI * 2;
                    const lit = (i + 0.5) / count <= clamped;
                    ctx.beginPath();
                    ctx.moveTo(center + Math.cos(angle) * inner, center + Math.sin(angle) * inner);
                    ctx.lineTo(center + Math.cos(angle) * outer, center + Math.sin(angle) * outer);
                    ctx.lineWidth = tickLw;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = lit
                        ? Theme.rgba(Theme.dataColor(theme, i), 1)
                        : Theme.rgba(theme.accent, 0.16);
                    ctx.stroke();
                }
                break;
            }
            default: { // gradient — the original liquid-glass arc
                drawTrack(ctx, center, lw);
                if (clamped > 0) {
                    // Glow: the blurred 1.55× arc behind the crisp stroke.
                    ctx.save();
                    ctx.shadowColor = Theme.rgba(theme.accent, 0.55 * 0.75);
                    ctx.shadowBlur = Math.max(2, lw * 0.55) * 1.6;
                    ctx.beginPath();
                    ctx.arc(center, center, center - lw * 1.1, start, start + span);
                    ctx.lineWidth = lw * 1.55;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = grad;
                    ctx.globalAlpha = 0.55;
                    ctx.stroke();
                    ctx.restore();

                    // Crisp arc.
                    arc(ctx, center, center - lw / 2, start, start + span, lw, grad);
                }
                break;
            }
            }
        }

        function drawTrack(ctx, center, lw) {
            ctx.beginPath();
            ctx.arc(center, center, center - lw / 2, 0, Math.PI * 2);
            ctx.lineWidth = lw;
            ctx.strokeStyle = Theme.rgba(ring.theme.accent, 0.14);
            ctx.stroke();
        }

        function arc(ctx, center, radius, from, to, lw, style) {
            ctx.beginPath();
            ctx.arc(center, center, radius, from, to);
            ctx.lineWidth = lw;
            ctx.lineCap = "round";
            ctx.strokeStyle = style;
            ctx.stroke();
        }
    }

    Canvas {
        id: _sparkles
        anchors.fill: parent
        anchors.margins: -ring.lineWidth
        renderStrategy: Canvas.Cooperative
        visible: ring.clamped > 0 && ring.sparklesActive

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            if (!ring.sparklesActive || ring.clamped <= 0)
                return;
            const time = ring.animTime;
            const lw = ring.lineWidth;
            const count = ring.sparkleCount;
            const center = width / 2;
            const centerY = height / 2;
            const radius = ring.width / 2;
            const intensity = Math.max(0, Math.min(1.5, ring.sparkleIntensity));

            for (let i = 0; i < count; ++i) {
                const seed = i * 2.39996;
                const pulse = ((Math.sin(time * (1.25 + (i % 3) * 0.25) + seed) + 1) / 2) * intensity;
                const drift = 0.16 * Math.sin(time * 0.35 + seed);
                const position = (i + 0.5 + drift) / count;
                const angle = position * ring.clamped * Math.PI * 2 - Math.PI / 2;
                const orbit = radius + Math.sin(seed) * lw * 0.22;
                const px = center + Math.cos(angle) * orbit;
                const py = centerY + Math.sin(angle) * orbit;
                const arm = Math.max(1.1, lw * 0.38) * (0.65 + pulse * 0.65);
                const color = Theme.dataColor(ring.theme, i);

                // Halo: blurred ellipse ≈ radial gradient circle of arm*2.
                const haloRadius = arm * 2;
                const halo = ctx.createRadialGradient(px, py, 0, px, py, haloRadius);
                const haloAlpha = Math.min(1, 0.24 + pulse * 0.40);
                halo.addColorStop(0, Theme.rgba(color, haloAlpha));
                halo.addColorStop(0.6, Theme.rgba(color, haloAlpha * 0.35));
                halo.addColorStop(1, Theme.rgba(color, 0));
                ctx.fillStyle = halo;
                ctx.beginPath();
                ctx.arc(px, py, haloRadius, 0, Math.PI * 2);
                ctx.fill();

                // Four-point star, inner radius 0.30 like codexSparkPath.
                ctx.beginPath();
                ctx.moveTo(px, py - arm);
                ctx.lineTo(px + arm * 0.30, py - arm * 0.30);
                ctx.lineTo(px + arm, py);
                ctx.lineTo(px + arm * 0.30, py + arm * 0.30);
                ctx.lineTo(px, py + arm);
                ctx.lineTo(px - arm * 0.30, py + arm * 0.30);
                ctx.lineTo(px - arm, py);
                ctx.lineTo(px - arm * 0.30, py - arm * 0.30);
                ctx.closePath();
                ctx.fillStyle = Theme.rgba([1, 1, 1], Math.min(1, 0.35 + pulse * 0.65));
                ctx.fill();
            }
        }
    }

    Column {
        anchors.centerIn: parent
        visible: ring.showsPercent
        spacing: -1
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(ring.clamped * 100)
            color: "#f2f2f5"
            font.pixelSize: Math.max(9, ring.width * 0.34)
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Black
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "%"
            color: "#cfcfd8"
            font.pixelSize: Math.max(7, ring.width * 0.15)
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Bold
        }
    }
}
