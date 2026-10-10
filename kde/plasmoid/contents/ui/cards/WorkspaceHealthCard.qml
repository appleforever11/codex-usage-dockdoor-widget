import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6WorkspaceHealthCard: read-only git status for project roots.
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

    readonly property var health: dataSource && dataSource.analytics ? dataSource.analytics.workspaceHealth : null
    readonly property bool available: health && health.repositoryCount > 0

    implicitHeight: available ? _column.implicitHeight : emptyLabel.implicitHeight

    Text {
        id: emptyLabel
        visible: !card.available
        text: card.health && card.health.checkedProjectCount > 0
            ? " Git status is unavailable for the indexed projects."
            : " No local project paths are available."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.available
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.health ? String(card.health.repositoryCount) : "—"
                label: "repositories"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                tintColor: card.health && card.health.dirtyRepositoryCount > 0
                    ? Theme.dataColor(card.theme, 1) : Theme.dataColor(card.theme, 2)
                value: card.health ? String(card.health.dirtyRepositoryCount) : "—"
                label: "dirty repos"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                tintColor: card.health && card.health.dirtyFileCount > 0
                    ? Theme.dataColor(card.theme, 1) : Theme.dataColor(card.theme, 2)
                value: card.health ? String(card.health.dirtyFileCount) : "—"
                label: "dirty files"
            }
        }

        RowLayout {
            spacing: 5
            Layout.fillWidth: true
            Text {
                text: "⑂"
                color: Theme.rgba(card.theme.accent, 1)
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: card.health ? (card.health.activeBranch || "Detached or unavailable branch") : "—"
                color: "#d6d6de"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
        }

        Text {
            text: (card.health ? card.health.activeProject || "No active project" : "No active project") + " · read-only local Git status"
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
