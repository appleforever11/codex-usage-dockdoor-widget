import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6DailyActivityCard: weekday columns for the selected window.
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

    readonly property int dayCount: activityWindow === "today" ? 1 : (activityWindow === "thirtyDays" ? 30 : 7)
    readonly property var daily: dataSource && dataSource.analytics ? dataSource.analytics.daily : []
    readonly property var visibleDays: daily.slice(Math.max(0, daily.length - dayCount))
    readonly property var chartData: visibleDays.map(day => ({
        id: day.dayKey,
        label: Theme.shortWeekday(day.dayKey),
        value: day.tokens,
        detail: day.eventCount + " turns",
    }))
    readonly property var windowTotal: visibleDays.reduce((sum, day) => sum + day.tokens, 0)
    readonly property string windowTitle: activityWindow === "today" ? "today"
        : (activityWindow === "thirtyDays" ? "30 days" : "7 days")

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        ColumnChart {
            Layout.fillWidth: true
            theme: card.theme
            dataSource: card.chartData
            chartHeight: 58
            showsLabels: card.visibleDays.length <= 10
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        RowLayout {
            spacing: 6
            Text {
                text: Theme.compactTokens(card.windowTotal)
                color: "#f4f4f7"
                font.pixelSize: 15
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
            }
            Text {
                text: "tokens in " + card.windowTitle
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }
    }
}
