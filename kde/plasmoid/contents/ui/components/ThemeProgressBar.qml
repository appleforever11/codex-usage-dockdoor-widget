import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexThemeProgressBar: capsule track, gradient fill with a
// traveling white highlight and a tiny breathing flare inside the fill.
Item {
    id: bar

    property var theme: Theme.theme("Astra")
    property double value: 0          // 0…1; negative disables the bar
    property double barHeight: 5
    property int role: 0
    property var tintColor: null      // overrides the theme color when set
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0

    implicitHeight: barHeight

    onAnimTimeChanged: if (animationsEnabled) _flare.requestPaint()

    Rectangle {
        id: _track
        anchors.fill: parent
        radius: height / 2
        color: Theme.rgba(Theme.dataColor(theme, role), 0.10)
    }

    Item {
        id: _fillClip
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: parent.width * Math.max(0, Math.min(1, isFinite(value) ? value : 0))
        clip: true
        visible: width > 0.5

        Rectangle {
            id: _fill
            anchors.fill: parent
            radius: height / 2

            readonly property double fraction: Math.max(0, Math.min(1, isFinite(value) ? value : 0))

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0
                    color: Theme.rgba(bar.tintColor ? bar.tintColor : Theme.dataColor(bar.theme, bar.role), 1)
                }
                GradientStop {
                    position: 0.5
                    color: Theme.rgba(Theme.dataColor(bar.theme, bar.role + 1), 1)
                }
                GradientStop {
                    position: 1
                    color: Theme.rgba(Theme.dataColor(bar.theme, bar.role + 2), 1)
                }
            }

            // Traveling highlight: white 22% patch sweeping inside the fill.
            Rectangle {
                id: _highlight
                readonly property double travel: 0.5 + 0.5 * Math.sin(bar.animTime * 1.35 + bar.role)
                readonly property double parentWidth: _fillClip.width
                width: Math.min(30, Math.max(10, parentWidth * 0.42))
                height: parent.height
                radius: height / 2
                color: Theme.rgba([1, 1, 1], bar.animationsEnabled ? 0.22 : 0.12)
                visible: bar.animationsEnabled && _fillClip.width > 2
                x: Math.max(0, parentWidth - width) * travel
            }
        }

        // Breathing flare near the leading edge (CodexThemeBarSparkle).
        Canvas {
            id: _flare
            anchors.fill: parent
            renderStrategy: Canvas.Cooperative
            visible: bar.animationsEnabled && _fillClip.width > 5 && bar.sparkleIntensity > 0.05

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = bar.animTime;
                const pulse = (0.5 + 0.5 * Math.sin(t * (1.05 + (bar.role % 3) * 0.08) + bar.role)) * bar.sparkleIntensity;
                const travel = 0.5 + 0.5 * Math.sin(t * 0.72 + bar.role * 1.7);
                const px = width * (0.42 + 0.42 * travel);
                const py = height / 2;
                const arm = Math.max(0.9, Math.min(2.2, height * 0.42)) * (0.76 + 0.34 * pulse);
                const color = Theme.dataColor(bar.theme, Math.abs(bar.role));

                const halo = ctx.createRadialGradient(px, py, 0, px, py, arm * 2.4);
                halo.addColorStop(0, Theme.rgba(color, 0.22 + 0.18 * pulse));
                halo.addColorStop(1, Theme.rgba(color, 0));
                ctx.fillStyle = halo;
                ctx.beginPath();
                ctx.arc(px, py, arm * 2.4, 0, Math.PI * 2);
                ctx.fill();

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
                ctx.fillStyle = Theme.rgba([1, 1, 1], 0.28 + 0.42 * pulse);
                ctx.fill();
            }
        }
    }
}
