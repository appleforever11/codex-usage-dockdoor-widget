import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6PaceCard.
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

    readonly property var pace: dataSource && dataSource.analytics ? dataSource.analytics.quotaPace : null
    readonly property var usage: dataSource ? dataSource.usage : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            visible: card.pace !== null
            spacing: 10
            Layout.fillWidth: true

            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.pace && card.pace.percentPerHour !== null && card.pace.percentPerHour !== undefined
                    ? card.pace.percentPerHour.toFixed(1) + "%" : "—"
                label: "used / hour"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.pace && card.pace.projectedExhaustionAt
                    ? Theme.relativeTime(card.pace.projectedExhaustionAt, card.nowEpoch) : "—"
                label: "exhaustion"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.pace ? String(Math.max(1, card.pace.sampleCount)) : "1"
                label: "samples"
            }
        }

        Text {
            visible: card.pace !== null
            text: {
                if (!card.pace || card.pace.willLastToReset === null || card.pace.willLastToReset === undefined)
                    return "Building a personal pace baseline";
                return card.pace.willLastToReset === true
                    ? "At this pace, quota lasts to reset"
                    : "At this pace, quota may run out first";
            }
            color: card.pace && card.pace.willLastToReset === false
                ? Theme.rgba(Theme.dataColor(card.theme, 1), 1) : "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        ColumnLayout {
            visible: card.pace === null
            spacing: 3
            Text {
                text: " Collecting quota pace history"
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: "The helper records bounded local points as the account snapshot refreshes."
                color: "#9d9dac"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Text {
            text: card.usage
                ? "Current usage: " + Math.round((1 - card.usage.percentRemaining) * 100) + "% used"
                : ""
            color: "#9d9dac"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
        }
    }
}
