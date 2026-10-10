import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6StreaksGoalsCard.
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
    readonly property var official: analytics ? analytics.officialActivity : null
    readonly property double goalProgress: analytics && analytics.dailyGoalTokens > 0
        ? Math.min(Math.max(analytics.todayTokens / analytics.dailyGoalTokens, 0), 1) : 0

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
                value: card.official && card.official.currentStreakDays !== null && card.official.currentStreakDays !== undefined
                    ? String(card.official.currentStreakDays) : "—"
                label: "day streak"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.official && card.official.longestStreakDays !== null && card.official.longestStreakDays !== undefined
                    ? String(card.official.longestStreakDays) : "—"
                label: "longest"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.analytics ? Theme.compactTokens(card.analytics.last7DaysTokens / 7) : "—"
                label: "7-day avg"
            }
        }

        LabeledBar {
            Layout.fillWidth: true
            theme: card.theme
            labelText: "Daily goal · " + Theme.compactTokens(card.analytics ? card.analytics.dailyGoalTokens : 0)
            value: card.goalProgress
            valueLabel: Theme.percentText(card.goalProgress)
            tint: card.theme.accent
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        Text {
            text: card.analytics
                ? "Today " + Theme.compactTokens(card.analytics.todayTokens) + " · goal is local and adjustable in widget settings."
                : ""
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
