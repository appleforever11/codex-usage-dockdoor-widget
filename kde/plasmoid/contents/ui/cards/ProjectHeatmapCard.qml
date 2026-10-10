import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ProjectHeatmapCard: 2×2 project tiles, accent intensity by
// token share.
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

    readonly property var projects: dataSource && dataSource.analytics ? dataSource.analytics.projects : []
    readonly property double maxTokens: {
        let max = 0;
        for (let i = 0; i < projects.length; ++i)
            max = Math.max(max, projects[i].tokens);
        return Math.max(max, 1);
    }

    implicitHeight: projects.length === 0 ? emptyLabel.implicitHeight : _grid.implicitHeight

    Text {
        id: emptyLabel
        visible: card.projects.length === 0
        text: " Project heatmap appears after local sessions are indexed."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    GridLayout {
        id: _grid
        visible: card.projects.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        columns: 2
        columnSpacing: 6
        rowSpacing: 6

        Repeater {
            model: Math.min(card.projects.length, 4)

            Rectangle {
                id: tile

                required property int index
                readonly property var project: card.projects[index]
                readonly property double share: project
                    ? Math.min(Math.max(project.tokens / card.maxTokens, 0), 1) : 0

                Layout.fillWidth: true
                implicitHeight: _tileColumn.implicitHeight + 14
                radius: 8
                color: Theme.rgba(card.theme.accent, 0.09 + 0.23 * share)

                ColumnLayout {
                    id: _tileColumn
                    anchors.fill: parent
                    anchors.margins: 7
                    spacing: 3

                    Text {
                        text: tile.project ? tile.project.name : ""
                        color: "#e2e2e8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: tile.project ? Theme.compactTokens(tile.project.tokens) : ""
                            color: "#f0f0f4"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            font.weight: Font.Bold
                            Layout.fillWidth: true
                        }
                        Text {
                            text: tile.project ? tile.project.sessionCount + " sessions" : ""
                            color: "#bcbcc8"
                            font.pixelSize: 9
                            font.family: Theme.fontFamily(UIFont.configured)
                        }
                    }
                    Text {
                        text: tile.project ? tile.project.eventCount + " local turns" : ""
                        color: "#9d9dac"
                        font.pixelSize: 9
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                }
            }
        }
    }
}
