import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6BurnCard: burn/today/7-day metrics, the 24-sample burn
// chart, freshness row, and the day-over-day trend badge.
Item {
    id: card

    property var dataSource: null
    property var theme: Theme.theme("Astra")
    property var clock: null
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property string activityWindow: "sevenDays"
    property string modelFilter: ""

    readonly property var telemetry: dataSource ? dataSource.telemetry : null
    readonly property var analytics: dataSource ? dataSource.analytics : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    readonly property var chartData: {
        const samples = card.telemetry && card.telemetry.samples ? card.telemetry.samples : [];
        const visible = samples.slice(Math.max(0, samples.length - 24));
        return visible.map((sample, index) => ({
            id: "burn-" + index,
            label: "#" + (index + 1),
            value: Math.max(0, sample.usage.totalTokens),
            detail: "recent turn",
        }));
    }

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: Theme.rateLabel(card.analytics ? card.analytics.burnPerMinute : null)
                label: "burn rate"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.analytics ? Theme.compactTokens(card.analytics.todayTokens) : "—"
                label: "today"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.analytics ? Theme.compactTokens(card.analytics.last7DaysTokens) : "—"
                label: "7 days"
            }
        }

        ColumnChart {
            Layout.fillWidth: true
            theme: card.theme
            dataSource: card.chartData
            chartHeight: 38
            showsLabels: false
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        RowLayout {
            spacing: 5
            Layout.fillWidth: true
            Text {
                text: ""
                color: Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                font.pixelSize: 10
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: card.telemetry && card.telemetry.observedUsage && card.telemetry.observedUsage.totalTokens > 0
                    ? freshnessLabel()
                    : "Waiting for local token events"
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            Text {
                visible: card.telemetry && card.telemetry.latestDelta
                text: card.telemetry && card.telemetry.latestDelta
                    ? "last " + Theme.compactTokens(card.telemetry.latestDelta.totalTokens) : ""
                color: "#9d9dac"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }

        TrendBadge {
            visible: card.analytics && card.analytics.todayVsPreviousDay !== undefined && card.analytics.todayVsPreviousDay !== null
            theme: card.theme
            change: card.analytics ? (card.analytics.todayVsPreviousDay || 0) : 0
            labelText: "today vs yesterday"
        }
    }

    function freshnessLabel() {
        const telemetry = card.telemetry;
        if (!telemetry || telemetry.updatedAt === null || telemetry.updatedAt === undefined)
            return "Waiting for token events";
        const age = Math.max(card.nowEpoch - telemetry.updatedAt, 0);
        if (age < 15)
            return "Live · updated just now";
        if (age < 120)
            return "Updated " + Math.round(age) + "s ago";
        return "Stale · " + Theme.relativeTime(telemetry.updatedAt, card.nowEpoch);
    }
}
