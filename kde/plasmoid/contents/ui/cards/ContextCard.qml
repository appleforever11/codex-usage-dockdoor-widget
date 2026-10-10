import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ContextCard: current + peak context bars with a privacy note.
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
    readonly property var currentPercent: {
        if (card.analytics && card.analytics.contextPercent !== null && card.analytics.contextPercent !== undefined)
            return card.analytics.contextPercent;
        if (card.telemetry && card.telemetry.latestContextUsage && card.telemetry.latestContextWindow > 0)
            return Math.min(Math.max(card.telemetry.latestContextUsage.totalTokens / card.telemetry.latestContextWindow, 0), 1);
        return null;
    }
    readonly property var peakPercent: card.analytics ? card.analytics.peakContextPercent : null

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 8

        LabeledBar {
            Layout.fillWidth: true
            theme: card.theme
            labelText: "Current context"
            value: card.currentPercent === null ? 0 : card.currentPercent
            valueLabel: card.currentPercent === null ? "—" : Theme.percentText(card.currentPercent)
            tint: Theme.dataColor(card.theme, 0)
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }
        LabeledBar {
            Layout.fillWidth: true
            theme: card.theme
            labelText: "Peak observed"
            value: card.peakPercent === null || card.peakPercent === undefined ? 0 : card.peakPercent
            valueLabel: (card.peakPercent === null || card.peakPercent === undefined) ? "—" : Theme.percentText(card.peakPercent)
            tint: Theme.dataColor(card.theme, 1)
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }
        Text {
            text: "Context is derived from local session token events and never uploaded by this widget."
            color: "#9d9dac"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
