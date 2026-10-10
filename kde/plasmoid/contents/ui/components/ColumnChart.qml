import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme

// Port of CodexV6InteractiveColumnChart: clickable/hoverable columns with a
// reserved callout slot, gradient fills, and a breathing top line. Data rows
// are {id, label, value, detail}.
Item {
    id: chart

    property var theme: Theme.theme("Astra")
    property var dataSource: []
    property double chartHeight: 52
    property bool showsLabels: true
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0

    property string selectedId: ""

    implicitHeight: chartHeight + (showsLabels ? 14 : 0) + 22 + 6

    onAnimTimeChanged: _canvas.requestPaint()
    onDataSourceChanged: { selectedId = ""; _canvas.requestPaint() }
    onThemeChanged: _canvas.requestPaint()

    function maximumValue() {
        let max = 0;
        for (let i = 0; i < dataSource.length; ++i)
            max = Math.max(max, Number(dataSource[i].value) || 0);
        return Math.max(max, 1);
    }

    function datumFor(id) {
        for (let i = 0; i < dataSource.length; ++i)
            if (dataSource[i].id === id)
                return dataSource[i];
        return null;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 6

        // Reserved callout slot prevents layout jumps while hovering.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 22

            Rectangle {
                anchors.fill: parent
                visible: chart.selectedId !== ""
                radius: height / 2
                color: Theme.rgba(chart.theme.accent, 0.10)
                border.width: 1
                border.color: Theme.rgba(chart.theme.accent, 0.18)

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 7
                    spacing: 5

                    Rectangle { width: 5; height: 5; radius: 2.5; anchors.verticalCenter: parent.verticalCenter; color: Theme.rgba(chart.theme.accent, 1) }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const d = chart.datumFor(chart.selectedId);
                            return d ? d.label : "";
                        }
                        color: "#f0f0f4"
                        font.pixelSize: 10
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            const d = chart.datumFor(chart.selectedId);
                            return d ? Theme.compactTokens(d.value) : "";
                        }
                        color: "white"
                        font.pixelSize: 10
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: text !== ""
                        text: {
                            const d = chart.datumFor(chart.selectedId);
                            return d && d.detail ? d.detail : "";
                        }
                        color: "#bcbcc8"
                        font.pixelSize: 9
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                }
            }
        }

        Item {
            id: _plot
            Layout.fillWidth: true
            Layout.preferredHeight: chart.chartHeight

            Canvas {
                id: _canvas
                anchors.fill: parent
                renderStrategy: Canvas.Cooperative

                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const count = chart.dataSource.length;
                    if (count === 0)
                        return;
                    const slot = width / count;
                    // macOS bars are slim (≈8–12 px) no matter how few
                    // samples the window holds — never slot-wide slabs.
                    const barW = Math.max(4, Math.min(slot * 0.62, 22));
                    const max = chart.maximumValue();
                    const t = chart.animTime;
                    const plotH = height;

                    // Thin baseline every column rises from.
                    ctx.fillStyle = Theme.rgba([1, 1, 1], 0.10);
                    ctx.fillRect(0, plotH - 1, width, 1);

                    for (let i = 0; i < count; ++i) {
                        const datum = chart.dataSource[i];
                        const value = Number(datum.value) || 0;
                        const fraction = Math.max(0, Math.min(1, value / max));
                        const x = i * slot + (slot - barW) / 2;
                        const color = Theme.dataColor(chart.theme, i);
                        const pulse = 0.5 + 0.5 * Math.sin(t * 1.1 + i);

                        if (value <= 0) {
                            // Empty slot: dim baseline stub — NO glow. Glowing
                            // every zero slot is what turned sparse charts
                            // into plot-wide gradient fog.
                            ctx.fillStyle = Theme.rgba(color, 0.22);
                            ctx.fillRect(x, plotH - 3, barW, 2);
                            continue;
                        }

                        const barHeight = Math.max(6, fraction * (plotH - 4));
                        const y = plotH - 1 - barHeight;
                        const selected = chart.selectedId === datum.id;

                        // Compact glow hugging the bar top (radius ≈ one bar
                        // width) — a breathing accent, not a fog source.
                        const haloR = barW * 1.15;
                        const halo = ctx.createRadialGradient(x + barW / 2, y + 1, 0, x + barW / 2, y + 1, haloR);
                        halo.addColorStop(0, Theme.rgba(color, (0.20 + 0.08 * pulse) * Math.max(0, Math.min(1.5, chart.glowIntensity))));
                        halo.addColorStop(1, Theme.rgba(color, 0));
                        ctx.fillStyle = halo;
                        ctx.fillRect(x + barW / 2 - haloR, y + 1 - haloR, haloR * 2, haloR * 2);

                        // Crisp rounded-top bar, brighter toward the top.
                        const grad = ctx.createLinearGradient(0, plotH, 0, y);
                        grad.addColorStop(0, Theme.rgba(color, 0.60));
                        grad.addColorStop(1, Theme.rgba(color, 1.0));
                        ctx.fillStyle = grad;
                        ctx.beginPath();
                        barTopPath(ctx, x, y, barW, barHeight, Math.min(3, barW / 2));
                        ctx.fill();

                        // Bright cap line on the top edge.
                        ctx.fillStyle = Theme.rgba([1, 1, 1], chart.animationsEnabled ? 0.35 + 0.20 * pulse : 0.35);
                        ctx.fillRect(x + 1, y, barW - 2, 1.2);

                        if (selected) {
                            ctx.strokeStyle = Theme.rgba(chart.theme.accent, 0.55);
                            ctx.lineWidth = 1;
                            ctx.beginPath();
                            ctx.roundedRect(x - 2, y - 2, barW + 4, barHeight + 4, 4);
                            ctx.stroke();
                        }
                    }
                }

                // Rounded top corners, square base — the macOS bar silhouette.
                function barTopPath(ctx, x, y, w, h, r) {
                    r = Math.min(r, w / 2, h);
                    ctx.moveTo(x, y + h);
                    ctx.lineTo(x, y + r);
                    ctx.quadraticCurveTo(x, y, x + r, y);
                    ctx.lineTo(x + w - r, y);
                    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
                    ctx.lineTo(x + w, y + h);
                    ctx.closePath();
                }
            }

            MouseArea {
                id: _hover
                anchors.fill: parent
                hoverEnabled: true
                onPositionChanged: function(mouse) {
                    const count = chart.dataSource.length;
                    if (count === 0)
                        return;
                    const slot = width / count;
                    const index = Math.min(count - 1, Math.max(0, Math.floor(mouse.x / slot)));
                    const id = chart.dataSource[index].id;
                    if (chart.selectedId !== id) {
                        chart.selectedId = id;
                        _canvas.requestPaint();
                    }
                }
                onExited: { chart.selectedId = ""; _canvas.requestPaint(); }
                onClicked: function(mouse) {
                    const count = chart.dataSource.length;
                    if (count === 0)
                        return;
                    const slot = width / count;
                    const index = Math.min(count - 1, Math.max(0, Math.floor(mouse.x / slot)));
                    chart.selectedId = chart.selectedId === chart.dataSource[index].id ? "" : chart.dataSource[index].id;
                    _canvas.requestPaint();
                }
            }

            Row {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 0
                visible: chart.showsLabels
                Repeater {
                    model: chart.dataSource.length
                    Item {
                        width: _plot.width / Math.max(chart.dataSource.length, 1)
                        height: 14
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: chart.dataSource[index] ? chart.dataSource[index].label : ""
                            color: chart.selectedId === (chart.dataSource[index] ? chart.dataSource[index].id : "") ? Theme.rgba(chart.theme.accent, 1) : "#a3a3b0"
                            font.pixelSize: 9
                            font.family: Theme.fontFamily(UIFont.configured)
                        }
                    }
                }
            }
        }
    }
}
