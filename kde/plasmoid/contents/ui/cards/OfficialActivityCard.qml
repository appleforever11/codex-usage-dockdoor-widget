import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6OfficialActivityCard: read-only aggregates when exposed.
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

    readonly property var official: dataSource && dataSource.analytics ? dataSource.analytics.officialActivity : null

    implicitHeight: official ? _column.implicitHeight : emptyLabel.implicitHeight

    Text {
        id: emptyLabel
        visible: !card.official
        text: " Official lifetime activity is optional and is not exposed in the current local usage file."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.official !== null && card.official !== undefined
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.official && card.official.lifetimeTokens !== null && card.official.lifetimeTokens !== undefined
                    ? Theme.compactTokens(card.official.lifetimeTokens) : "—"
                label: "lifetime"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.official && card.official.peakDailyTokens !== null && card.official.peakDailyTokens !== undefined
                    ? Theme.compactTokens(card.official.peakDailyTokens) : "—"
                label: "peak day"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.official && card.official.currentStreakDays !== null && card.official.currentStreakDays !== undefined
                    ? String(card.official.currentStreakDays) : "—"
                label: "day streak"
            }
        }

        Text {
            text: "Read-only aggregate activity from the configured usage state."
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
