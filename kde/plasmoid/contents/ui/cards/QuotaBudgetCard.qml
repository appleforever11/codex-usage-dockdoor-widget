import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6QuotaBudgetCard: safe vs actual pace against the next reset.
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

    readonly property double hoursToReset: {
        const reset = (card.pace && card.pace.resetAt) || (card.usage ? card.usage.resetAt : null);
        if (!reset)
            return 0;
        return Math.max(0, (reset - card.nowEpoch) / 3600);
    }
    readonly property double safePace: card.hoursToReset > 0 && card.usage
        ? Math.max(0, card.usage.percentRemaining * 100 / card.hoursToReset) : 0
    readonly property bool available: card.pace !== null && card.safePace > 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            visible: card.available
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.safePace.toFixed(1) + "%"
                label: "safe / hour"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.pace && card.pace.percentPerHour !== null && card.pace.percentPerHour !== undefined
                    ? card.pace.percentPerHour.toFixed(1) + "%" : "—"
                label: "actual / hour"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.hoursToReset < 1
                    ? Math.round(card.hoursToReset * 60) + "m"
                    : Math.round(card.hoursToReset) + "h"
                label: "until reset"
            }
        }

        LabeledBar {
            visible: card.available
            Layout.fillWidth: true
            theme: card.theme
            labelText: "Actual pace vs safe budget"
            value: card.safePace > 0 && card.pace && card.pace.percentPerHour
                ? card.pace.percentPerHour / card.safePace : 0
            valueLabel: card.safePace > 0 && card.pace && card.pace.percentPerHour
                ? Theme.percentText(Math.min(1, card.pace.percentPerHour / card.safePace)) : "—"
            tint: card.pace && card.pace.willLastToReset === false
                ? Theme.dataColor(card.theme, 1) : Theme.dataColor(card.theme, 0)
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        Text {
            visible: card.available
            text: card.pace && card.pace.willLastToReset === false
                ? "Current burn may exhaust the quota before reset."
                : "Current burn is within the pace needed to reach reset."
            color: card.pace && card.pace.willLastToReset === false
                ? Theme.rgba(Theme.dataColor(card.theme, 1), 1) : "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            visible: !card.available
            text: " Quota budget appears after two account snapshots establish a pace."
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
