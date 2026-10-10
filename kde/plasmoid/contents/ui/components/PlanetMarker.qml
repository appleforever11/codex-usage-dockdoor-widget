import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexThemePlanetMarker: a compact 28×20 themed planet glyph used in
// filter bars.
Item {
    id: marker

    property var theme: Theme.theme("Astra")
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0

    width: 28
    height: 20

    onAnimTimeChanged: _canvas.requestPaint()
    onThemeChanged: _canvas.requestPaint()

    Canvas {
        id: _canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const t = marker.animTime;
            const theme = marker.theme;
            const cx = width / 2, cy = height / 2;
            const radius = Math.min(width, height) * 0.30;
            const pulse = 0.5 + 0.5 * Math.sin(t * 0.9);

            const halo = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius * 2.2);
            halo.addColorStop(0, Theme.rgba(Theme.dataColor(theme, 1), 0.18 + 0.08 * pulse));
            halo.addColorStop(1, Theme.rgba(Theme.dataColor(theme, 1), 0));
            ctx.fillStyle = halo;
            ctx.fillRect(0, 0, width, height);

            switch (theme.key) {
            case "luna": {
                ctx.fillStyle = Theme.rgba(Theme.dataColor(theme, 2), 0.90);
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = Theme.rgba(theme.base, 0.9);
                ctx.beginPath();
                ctx.arc(cx + radius * 0.5, cy - radius * 0.45, radius, 0, Math.PI * 2);
                ctx.fill();
                break;
            }
            case "sol": {
                for (let ray = 0; ray < 8; ++ray) {
                    const angle = ray / 8 * Math.PI * 2 + t * 0.04;
                    ctx.strokeStyle = Theme.rgba(Theme.dataColor(theme, ray % theme.dataColors.length), 0.72);
                    ctx.lineWidth = 0.7;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * radius * 1.22, cy + Math.sin(angle) * radius * 1.22);
                    ctx.lineTo(cx + Math.cos(angle) * radius * (1.65 + 0.10 * pulse), cy + Math.sin(angle) * radius * (1.65 + 0.10 * pulse));
                    ctx.stroke();
                }
                const sun = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius * 1.2);
                sun.addColorStop(0, Theme.rgba(Theme.dataColor(theme, 2), 0.98));
                sun.addColorStop(0.6, Theme.rgba(Theme.dataColor(theme, 1), 0.80));
                sun.addColorStop(1, Theme.rgba(Theme.dataColor(theme, 0), 0.62));
                ctx.fillStyle = sun;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                break;
            }
            case "terra": {
                const terra = ctx.createRadialGradient(cx - radius * 0.2, cy - radius * 0.25, 0.5, cx, cy, radius * 1.25);
                terra.addColorStop(0, Theme.rgba(Theme.dataColor(theme, 2), 0.95));
                terra.addColorStop(0.6, Theme.rgba(Theme.dataColor(theme, 1), 0.70));
                terra.addColorStop(1, Theme.rgba(theme.base, 0.64));
                ctx.fillStyle = terra;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = Theme.rgba(Theme.dataColor(theme, 2), 0.70);
                ctx.lineWidth = 0.6;
                ctx.beginPath();
                ctx.ellipse(cx - width * 0.45, cy - radius * 0.7, width * 0.90, radius * 1.4);
                ctx.stroke();
                break;
            }
            case "rainbow": {
                ctx.fillStyle = Theme.rgba(Theme.dataColor(theme, 4), 0.76);
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                for (let orbit = 0; orbit < 3; ++orbit) {
                    ctx.strokeStyle = Theme.rgba(Theme.dataColor(theme, orbit + Math.trunc(t * 0.08)), 0.68);
                    ctx.lineWidth = 0.65;
                    ctx.beginPath();
                    ctx.ellipse(cx - width * (0.38 + orbit * 0.05), cy - height * (0.20 + orbit * 0.04) / 2, width * (0.76 + orbit * 0.10), height * (0.40 + orbit * 0.08));
                    ctx.stroke();
                }
                break;
            }
            default: {
                // Astra
                const astra = ctx.createRadialGradient(cx - radius * 0.25, cy - radius * 0.28, 0.5, cx, cy, radius * 1.25);
                astra.addColorStop(0, Theme.rgba(Theme.dataColor(theme, 2), 0.92));
                astra.addColorStop(0.6, Theme.rgba(Theme.dataColor(theme, 0), 0.65));
                astra.addColorStop(1, Theme.rgba(theme.base, 0.55));
                ctx.fillStyle = astra;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.strokeStyle = Theme.rgba(Theme.dataColor(theme, 2), 0.7);
                ctx.lineWidth = 0.75;
                ctx.beginPath();
                ctx.ellipse(cx - width * 0.45, cy - height * 0.22 / 2, width * 0.90, height * 0.44);
                ctx.stroke();
                ctx.fillStyle = "rgba(255,255,255,0.82)";
                starAt(ctx, cx - radius * 1.25, cy - radius * 1.0, 1.5);
                break;
            }
            }
        }

        function starAt(ctx, x, y, radius) {
            ctx.beginPath();
            for (let i = 0; i < 8; ++i) {
                const angle = i * Math.PI / 4 - Math.PI / 2;
                const r = i % 2 === 0 ? radius * 2 : radius * 0.38;
                const px = x + Math.cos(angle) * r;
                const py = y + Math.sin(angle) * r;
                if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.fill();
        }
    }
}
