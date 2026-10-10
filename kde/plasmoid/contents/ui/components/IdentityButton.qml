import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexIdentityButton + CodexIdentityArtwork: themed planet artwork
// behind a heavy label, selected/hover borders, and a checkmark chip. The
// per-identity canvas scenes mirror the Swift drawing code.
Rectangle {
    id: button

    property var identity: Theme.theme("Astra")
    property bool isSelected: false
    property double buttonHeight: 50
    property bool compactMode: false
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0
    signal activated()

    radius: 11
    implicitHeight: buttonHeight
    // No Item clip here: QML `clip` cuts to the square bounding rect, which
    // let the canvas artwork bleed past the rounded corners. The canvas
    // instead clips its own drawing to the rounded path (see onPaint).

    onAnimTimeChanged: _art.requestPaint()
    onIdentityChanged: _art.requestPaint()
    onIsSelectedChanged: _art.requestPaint()
    onWidthChanged: _art.requestPaint()
    onHeightChanged: _art.requestPaint()

    Canvas {
        id: _art
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width, h = height;
            const identity = button.identity;
            const t = button.animationsEnabled ? button.animTime : 0;
            const intensity = Math.max(0, Math.min(1.5, button.sparkleIntensity));
            const glow = Math.max(0, Math.min(1.5, button.glowIntensity));
            const emphasized = button.isSelected || hover.hovered;
            const pulse = 0.78 + 0.16 * Math.sin(t * 1.1);
            const cx = w * 0.79, cy = h * 0.30;
            const radius = Math.min(h * 0.25, 16);

            // Everything below stays inside the button's rounded outline.
            const r = Math.min(button.radius, w / 2, h / 2);
            ctx.beginPath();
            ctx.moveTo(r, 0);
            ctx.lineTo(w - r, 0);
            ctx.arc(w - r, r, r, -Math.PI / 2, 0);
            ctx.lineTo(w, h - r);
            ctx.arc(w - r, h - r, r, 0, Math.PI / 2);
            ctx.lineTo(r, h);
            ctx.arc(r, h - r, r, Math.PI / 2, Math.PI);
            ctx.lineTo(0, r);
            ctx.arc(r, r, r, Math.PI, Math.PI * 1.5);
            ctx.closePath();
            ctx.clip();

            // Base diagonal gradient.
            const baseGrad = ctx.createLinearGradient(0, 0, w, h);
            baseGrad.addColorStop(0, Theme.rgba(identity.artworkBase, 1));
            baseGrad.addColorStop(0.5, Theme.rgba(identity.colors[0], 0.58));
            baseGrad.addColorStop(1, Theme.rgba(identity.artworkBase, 1));
            ctx.fillStyle = baseGrad;
            ctx.fillRect(0, 0, w, h);

            // Ambient glow around the scene center.
            drawGlow(ctx, cx, cy, h * 0.95, Theme.rgba(identity.accent, (emphasized ? 0.55 : 0.35) * Math.min(glow, 1)));

            switch (identity.key) {
            case "astra": {
                drawGlow(ctx, w * 0.34, h * 0.68, w * 0.65, Theme.rgba([0.60, 0.33, 0.85], 0.7 * Math.min(glow, 1)));
                drawStars(ctx, w, h, t, Math.round(28 * Math.min(intensity, 1)), [0.95, 0.73, 1.0]);
                // Flare star with bloom.
                drawStar(ctx, cx, cy, radius * 0.48, Theme.rgba([1, 0.75, 0.80], pulse));
                drawStar(ctx, cx, cy, radius * 0.48, Theme.rgba([1, 1, 1], pulse));
                ctx.strokeStyle = Theme.rgba([0.60, 0.33, 0.85], 0.35);
                ctx.lineWidth = 0.6;
                ctx.beginPath();
                ctx.ellipse(cx - radius * 1.8, cy - radius * 0.65, radius * 3.6, radius * 1.3);
                ctx.stroke();
                break;
            }
            case "luna": {
                drawStars(ctx, w, h, t, Math.round(13 * Math.min(intensity, 1)), [0.4, 0.79, 1.0]);
                drawOrbits(ctx, cx, cy, radius, Theme.rgba([0, 0.78, 1.0], 1));
                const moonGrad = ctx.createLinearGradient(cx - radius, cy - radius, cx + radius, cy + radius);
                moonGrad.addColorStop(0, Theme.rgba([1, 1, 1], 1));
                moonGrad.addColorStop(1, Theme.rgba([0.48, 0.79, 1.0], 1));
                ctx.fillStyle = moonGrad;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.fillStyle = Theme.rgba([0.025, 0.07, 0.18], 1);
                ctx.beginPath();
                ctx.arc(cx + radius * 0.65, cy - radius * 0.30, radius, 0, Math.PI * 2);
                ctx.fill();
                break;
            }
            case "sol": {
                drawOrbits(ctx, cx, cy, radius * 1.15, Theme.rgba([1, 0.55, 0.2, 1]));
                for (let ray = 0; ray < 16; ++ray) {
                    const angle = ray * Math.PI / 8 + t * 0.035;
                    ctx.strokeStyle = Theme.rgba([1, 0.93, 0.36], 0.6);
                    ctx.lineWidth = ray % 2 === 0 ? 1.4 : 0.7;
                    ctx.beginPath();
                    ctx.moveTo(cx + Math.cos(angle) * radius * 1.2, cy + Math.sin(angle) * radius * 1.2);
                    ctx.lineTo(cx + Math.cos(angle) * radius * 1.75, cy + Math.sin(angle) * radius * 1.75);
                    ctx.stroke();
                }
                const sun = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius * 1.2);
                sun.addColorStop(0, "white");
                sun.addColorStop(0.5, Theme.rgba([1, 0.93, 0.36], 1));
                sun.addColorStop(1, Theme.rgba([1, 0.55, 0.2], 1));
                ctx.fillStyle = sun;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                break;
            }
            case "terra": {
                drawOrbits(ctx, cx, cy, radius, Theme.rgba([0.71, 0.53, 0.26], 1));
                const terraGrad = ctx.createLinearGradient(cx - radius, cy - radius, cx + radius, cy + radius);
                terraGrad.addColorStop(0, Theme.rgba([0.34, 0.94, 0.78], 1));
                terraGrad.addColorStop(0.5, Theme.rgba([0.03, 0.28, 0.19], 1));
                terraGrad.addColorStop(1, "black");
                ctx.fillStyle = terraGrad;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                ctx.save();
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.clip();
                ctx.strokeStyle = Theme.rgba([0.82, 0.91, 0.51], 0.78);
                ctx.lineWidth = 1.5;
                for (let band = 0; band < 5; ++band) {
                    const y = cy - radius + band * radius * 0.5;
                    ctx.beginPath();
                    ctx.moveTo(cx - radius, y);
                    ctx.quadraticCurveTo(cx - radius * 0.3, y - radius * 0.5, cx, y);
                    ctx.quadraticCurveTo(cx + radius * 0.3, y + radius * 0.7, cx + radius, y + radius * 0.4);
                    ctx.stroke();
                }
                ctx.restore();
                ctx.strokeStyle = Theme.rgba([0.34, 0.94, 0.78], 0.8);
                ctx.lineWidth = 0.8;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.stroke();
                break;
            }
            case "rainbow": {
                for (let index = 0; index < identity.colors.length; ++index) {
                    const y = index * 5 + 3;
                    ctx.strokeStyle = Theme.rgba(identity.colors[index], 0.55);
                    ctx.lineWidth = 6;
                    ctx.beginPath();
                    ctx.moveTo(-10, y + 10);
                    ctx.bezierCurveTo(w * 0.35, -14 + 4 * Math.sin(t * 0.5), w * 0.60, h + 14, w + 10, y);
                    ctx.stroke();
                }
                drawStars(ctx, w, h, t, Math.round(10 * Math.min(intensity, 1)), [1, 1, 1]);
                break;
            }
            default: {
                // Derived identities (Plasma style, custom accent, new model
                // families): a soft orb in the identity's own gradient.
                drawStars(ctx, w, h, t, Math.round(16 * Math.min(intensity, 1)), identity.colors[2] || [1, 1, 1]);
                drawOrbits(ctx, cx, cy, radius * 1.05, identity.accent);
                const orb = ctx.createRadialGradient(cx - radius * 0.3, cy - radius * 0.3, 0, cx, cy, radius * 1.15);
                orb.addColorStop(0, Theme.rgba(identity.colors[2] || [1, 1, 1], 1));
                orb.addColorStop(0.55, Theme.rgba(identity.accent, 1));
                orb.addColorStop(1, Theme.rgba(identity.artworkBase || [0, 0, 0], 1));
                ctx.fillStyle = orb;
                ctx.beginPath();
                ctx.arc(cx, cy, radius, 0, Math.PI * 2);
                ctx.fill();
                drawStar(ctx, cx, cy, radius * 0.30, Theme.rgba([1, 1, 1], pulse), 0.35);
                break;
            }
            }

            // Bottom scrim keeps the label readable over bright artwork.
            const scrim = ctx.createLinearGradient(0, 0, 0, h);
            scrim.addColorStop(0, "rgba(0,0,0,0)");
            scrim.addColorStop(1, "rgba(0,0,0,0.40)");
            ctx.fillStyle = scrim;
            ctx.fillRect(0, 0, w, h);
        }

        function drawGlow(ctx, cx, cy, radius, color) {
            const grad = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius);
            grad.addColorStop(0, color);
            grad.addColorStop(1, "rgba(0,0,0,0)");
            ctx.fillStyle = grad;
            ctx.beginPath();
            ctx.arc(cx, cy, radius, 0, Math.PI * 2);
            ctx.fill();
        }

        function drawOrbits(ctx, cx, cy, radius, tint) {
            for (let index = 0; index < 4; ++index) {
                const r = radius * (1.7 + index * 0.65);
                ctx.strokeStyle = Theme.rgba(tint, Math.max(0, 0.26 - index * 0.045));
                ctx.lineWidth = 0.7;
                ctx.beginPath();
                ctx.arc(cx, cy, r, 0, Math.PI * 2);
                ctx.stroke();
            }
        }

        function drawStars(ctx, w, h, t, count, tint) {
            for (let index = 0; index < count; ++index) {
                const x = ((index * 37 + 11) % 101) / 101 * w;
                const y = ((index * 23 + 9) % 83) / 83 * h;
                const twinkle = 0.55 + 0.45 * Math.sin(t * (1.0 + (index % 3) * 0.3) + index);
                const radius = index % 5 === 0 ? 1.8 : 0.65;
                if (index % 5 === 0) {
                    drawStar(ctx, x, y, radius, Theme.rgba(tint, twinkle), 0.38);
                }
                ctx.fillStyle = Theme.rgba([1, 1, 1], 0.30 + 0.65 * twinkle);
                ctx.beginPath();
                ctx.arc(x, y, radius, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        function drawStar(ctx, x, y, radius, color, innerRatio) {
            const inner = innerRatio === undefined ? 0.30 : innerRatio;
            ctx.fillStyle = color;
            ctx.beginPath();
            for (let i = 0; i < 8; ++i) {
                const angle = i * Math.PI / 4 - Math.PI / 2;
                const r = i % 2 === 0 ? radius * 2 : radius * inner;
                const px = x + Math.cos(angle) * r;
                const py = y + Math.sin(angle) * r;
                if (i === 0)
                    ctx.moveTo(px, py);
                else
                    ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.fill();
        }
    }

    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: button.compactMode ? 7 : 10
        anchors.bottomMargin: button.compactMode ? 8 : 9
        spacing: button.compactMode ? 3 : 5

        Text {
            // displayName is the button's identity ("Luna-6", "Sol-6",
            // "Terra", "Astra") — never a lookup key against THEMES.
            text: button.identity.displayName || "Astra"
            color: "white"
            font.pixelSize: button.compactMode ? 11 : 12
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Black
            style: Text.Raised
            styleColor: "#a0000000"
        }
    }

    // Selection border with gradient stroke (white → accent).
    Rectangle {
        anchors.fill: parent
        radius: button.radius
        color: "transparent"
        border.width: button.isSelected ? 1.5 : (hover.hovered ? 1.0 : 0.8)
        border.color: button.isSelected
            ? Theme.rgba(button.identity.accent, 0.9)
            : Theme.rgba([1, 1, 1], hover.hovered ? 0.45 : 0.20)
    }

    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
        width: 13
        height: 13
        radius: 6.5
        visible: button.isSelected
        color: Theme.rgba(button.identity.accent, 0.5)
        Text {
            anchors.centerIn: parent
            text: ""
            color: "white"
            font.pixelSize: 9
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Black
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.activated()
    }
}
