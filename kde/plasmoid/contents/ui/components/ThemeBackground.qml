import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexThemeBackground + CodexThemeAnimatedAtmosphere: theme base at
// adjustable opacity, a shared-purple corner wash, two breathing dataSource-color
// radials that drift, an optional rainbow sweep, and the deterministic
// floating starfield. One canvas renders the whole atmosphere at ~18 fps.
Rectangle {
    id: background

    property var theme: Theme.theme("Astra")
    property double backgroundOpacity: 0.75
    property bool frostedGlass: true
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0

    // Frosted glass: behind-window material becomes a translucent blend on
    // Plasma; when disabled the base renders at full strength.
    color: Theme.rgba(theme.base, frostedGlass ? Math.max(0.2, Math.min(1, backgroundOpacity)) : 1.0)

    onAnimTimeChanged: _atmosphere.requestPaint()
    onThemeChanged: _atmosphere.requestPaint()
    onWidthChanged: _atmosphere.requestPaint()
    onHeightChanged: _atmosphere.requestPaint()

    Canvas {
        id: _atmosphere
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        opacity: background.frostedGlass ? 1 : 0.8

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const t = background.animationsEnabled ? background.animTime : 0;
            const theme = background.theme;
            const intensity = Math.max(0, Math.min(1.5, background.sparkleIntensity));
            const glow = Math.max(0, Math.min(1.5, background.glowIntensity));

            // Corner washes from CodexThemeBackground: accent top-trailing
            // and shared purple bottom-leading.
            drawRadial(ctx, w * 0.86, h * 0.08, Math.max(w, h) * 0.62,
                       Theme.rgba(theme.accent, 0.20), w, h);
            drawRadial(ctx, w * 0.10, h * 0.94, Math.max(w, h) * 0.55,
                       Theme.rgba(Theme.SHARED_PURPLE_GLOW, 0.13), w, h);

            // Breathing dataSource-color radials (CodexThemeAnimatedAtmosphere).
            const c1x = 0.78 + 0.04 * Math.sin(t * 0.22);
            const c1y = 0.16 + 0.03 * Math.cos(t * 0.18);
            drawRadial(ctx, w * c1x, h * c1y, 340,
                       Theme.rgba(Theme.dataColor(theme, 0), 0.12 * 0.75), w, h);
            const c2x = 0.18 + 0.05 * Math.cos(t * 0.15);
            const c2y = 0.82 + 0.04 * Math.sin(t * 0.19);
            drawRadial(ctx, w * c2x, h * c2y, 310,
                       Theme.rgba(Theme.dataColor(theme, 2), 0.08), w, h);

            if (theme.key === "rainbow" && background.animationsEnabled && glow > 0.05) {
                // Rotating angular gradient sweep.
                ctx.save();
                ctx.translate(w / 2, h / 2);
                ctx.rotate(t * 2.4 * Math.PI / 180);
                const sweep = ctx.createLinearGradient(-w, -h, w, h);
                for (let i = 0; i < theme.dataColors.length; ++i)
                    sweep.addColorStop(i / (theme.dataColors.length - 1),
                                       Theme.rgba(theme.dataColors[i], 0.08));
                ctx.fillStyle = sweep;
                ctx.fillRect(-w, -h, w * 2, h * 2);
                ctx.restore();
            }

            // Deterministic floating starfield.
            const count = Math.round((theme.key === "rainbow" ? 42 : 34) * (0.45 + intensity * 0.55));
            for (let i = 0; i < count; ++i) {
                const phase = i * 0.77;
                const xBase = ((i * 47 + 11) % 101) / 100.0;
                const yBase = ((i * 71 + 19) % 97) / 96.0;
                const driftX = Math.sin(t * (0.10 + (i % 4) * 0.035) + phase) * w * 0.018;
                const driftY = Math.cos(t * (0.08 + (i % 5) * 0.025) + phase) * h * 0.012;
                const x = Math.max(2, Math.min(w - 2, xBase * w + driftX));
                const y = Math.max(2, Math.min(h - 2, yBase * h + driftY));
                const twinkle = (0.32 + 0.68 * ((Math.sin(t * (0.72 + (i % 6) * 0.11) + phase) + 1) / 2)) * intensity;
                if (twinkle <= 0.01)
                    continue;
                const radius = (i % 5 === 0 ? 1.05 : 0.55) * (0.75 + 0.35 * twinkle);
                const color = Theme.dataColor(theme, i + Math.trunc(t * 0.18));

                const haloR = radius * 2.4 + 3;
                const halo = ctx.createRadialGradient(x, y, 0, x, y, haloR);
                halo.addColorStop(0, Theme.rgba(color, 0.18 * twinkle));
                halo.addColorStop(1, Theme.rgba(color, 0));
                ctx.fillStyle = halo;
                ctx.beginPath();
                ctx.arc(x, y, haloR, 0, Math.PI * 2);
                ctx.fill();

                if (i % 4 === 0) {
                    const arm = radius * 2.9;
                    ctx.beginPath();
                    ctx.moveTo(x, y - arm);
                    ctx.lineTo(x + arm * 0.30, y - arm * 0.30);
                    ctx.lineTo(x + arm, y);
                    ctx.lineTo(x + arm * 0.30, y + arm * 0.30);
                    ctx.lineTo(x, y + arm);
                    ctx.lineTo(x - arm * 0.30, y + arm * 0.30);
                    ctx.lineTo(x - arm, y);
                    ctx.lineTo(x - arm * 0.30, y - arm * 0.30);
                    ctx.closePath();
                    ctx.fillStyle = Theme.rgba(color, 0.30 * twinkle);
                    ctx.fill();
                } else {
                    ctx.beginPath();
                    ctx.arc(x, y, radius, 0, Math.PI * 2);
                    ctx.fillStyle = Theme.rgba(color, 0.18 * twinkle);
                    ctx.fill();
                }
            }
        }
    }

    function drawRadial(ctx, cx, cy, radius, color, w, h) {
        if (radius <= 0)
            return;
        const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
        grad.addColorStop(0, color);
        grad.addColorStop(1, Theme.rgba([color.r, color.g, color.b], 0));
        ctx.fillStyle = grad;
        ctx.beginPath();
        ctx.arc(cx, cy, radius, 0, Math.PI * 2);
        ctx.fill();
    }
}
