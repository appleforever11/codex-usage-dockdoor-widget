import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6SessionHealthCard.
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
    readonly property int sessionCount: dataSource && dataSource.snapshot && dataSource.snapshot.sessions ? dataSource.snapshot.sessions.length : 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            spacing: 7
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: String(card.sessionCount)
                label: "sessions"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: dataSource && dataSource.counts ? String(dataSource.counts.taskCount) : "0"
                label: "tasks"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: dataSource && dataSource.counts ? String(dataSource.counts.chatCount) : "0"
                label: "chats"
            }
        }

        RowLayout {
            spacing: 5
            Layout.fillWidth: true
            Text {
                text: card.telemetry && card.telemetry.eventCount > 0 ? "✔" : "⏳"
                color: card.telemetry && card.telemetry.eventCount > 0
                    ? Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                    : "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: card.telemetry
                    ? card.telemetry.eventCount + " local token events · "
                      + Theme.modelLabel(card.telemetry.currentModel, "Unknown") + " active model"
                    : ""
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }
    }
}
