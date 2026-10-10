import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6CostCard: API-equivalent cost estimate for 30 days.
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

    readonly property var analytics: dataSource ? dataSource.analytics : null

    implicitHeight: _row.implicitHeight

    RowLayout {
        id: _row
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Text {
            text: "$"
            color: Theme.rgba(card.theme.accent, 1)
            font.pixelSize: 20
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Bold
        }
        ColumnLayout {
            spacing: 3
            Layout.fillWidth: true
            Text {
                text: card.analytics && card.analytics.estimatedCostUsd !== null && card.analytics.estimatedCostUsd !== undefined
                    ? "$" + card.analytics.estimatedCostUsd.toFixed(2) : "—"
                color: "#f4f4f7"
                font.pixelSize: 18
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
            }
            Text {
                text: "estimated API-equivalent cost · 30 days"
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: card.analytics
                    ? "Coverage " + Math.round(card.analytics.costCoverage * 100) + "% · model rates are estimates"
                    : ""
                color: "#9d9dac"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }
    }
}
