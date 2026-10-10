import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ProjectMixCard.
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

    implicitHeight: projects.length === 0 ? emptyLabel.implicitHeight : _column.implicitHeight

    Text {
        id: emptyLabel
        visible: card.projects.length === 0
        text: " Project mix appears after token events."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.projects.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Repeater {
            model: Math.min(card.projects.length, 4)

            ColumnLayout {
                id: row
                required property int index
                readonly property var project: card.projects[row.index]
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: row.project.name
                        color: "#d6d6de"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Theme.compactTokens(row.project.tokens)
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }
                }
                ThemeProgressBar {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: row.project.tokens / card.maxTokens
                    barHeight: 4
                    tintColor: card.theme.accent
                    sparkleIntensity: card.sparkleIntensity
                    glowIntensity: card.glowIntensity
                    animationsEnabled: card.animationsEnabled
                    clock: card.clock
                }
            }
        }
    }
}
