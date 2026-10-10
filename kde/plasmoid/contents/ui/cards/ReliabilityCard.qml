import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ReliabilityCard: attribution and source readiness.
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
    readonly property var usage: dataSource ? dataSource.usage : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0
    readonly property int readySources: {
        if (!analytics || !analytics.sourceStatuses)
            return 0;
        let count = 0;
        for (let i = 0; i < analytics.sourceStatuses.length; ++i)
            if (analytics.sourceStatuses[i].state === "Ready")
                ++count;
        return count;
    }
    readonly property var attributionPercent: telemetry && telemetry.eventCount > 0
        ? telemetry.attributedEventCount / telemetry.eventCount : null

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.attributionPercent === null ? "—" : Theme.percentText(card.attributionPercent)
                label: "attributed"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.analytics
                    ? card.readySources + "/" + card.analytics.sourceStatuses.length : "—"
                label: "sources ready"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.analytics ? String(card.analytics.cachedEventCount) : "0"
                label: "cached events"
            }
        }

        RowLayout {
            spacing: 5
            Layout.fillWidth: true
            Text {
                text: card.usage && card.usage.isStale ? "⚠" : "✔"
                color: card.usage && card.usage.isStale
                    ? Theme.rgba(Theme.dataColor(card.theme, 1), 1)
                    : Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: card.usage && card.usage.warning
                    ? card.usage.warning
                    : "Local telemetry and account dataSource are current."
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Text {
            text: card.usage && card.usage.lastUpdatedAt
                ? "Last account update: " + Theme.relativeTime(card.usage.lastUpdatedAt, card.nowEpoch)
                : "Last account update: unknown"
            color: "#9d9dac"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
        }
    }
}
