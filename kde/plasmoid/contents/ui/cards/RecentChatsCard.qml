import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6RecentChatsCard + CodexSessionRow: clickable rows that open
// codex://threads/<uuid> through the helper.
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

    readonly property var sessions: dataSource && dataSource.snapshot && dataSource.snapshot.sessions ? dataSource.snapshot.sessions : []
    readonly property var latestChat: dataSource && dataSource.snapshot ? dataSource.snapshot.latestChat : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 4

        Text {
            visible: card.sessions.length === 0 && card.latestChat
            text: card.latestChat || ""
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            visible: card.sessions.length === 0 && !card.latestChat
            text: " Recent chats appear as Codex writes local session files."
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Repeater {
            model: Math.min(card.sessions.length, 3)

            Rectangle {
                id: row
                required property int index
                readonly property var session: card.sessions[row.index]
                readonly property bool hovered: Boolean(rowHover.hovered)

                Layout.fillWidth: true
                implicitHeight: _rowContent.implicitHeight + 10
                radius: 7
                color: Theme.rgba([1, 1, 1], hovered ? 0.10 : 0.0)

                RowLayout {
                    id: _rowContent
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 8

                    Text {
                        text: row.session.isActive ? "●" : "○"
                        color: row.session.isActive
                            ? Theme.rgba(card.theme.accent, 1)
                            : "#9d9dac"
                        font.pixelSize: 10
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                    ColumnLayout {
                        spacing: 1
                        Layout.fillWidth: true
                        Text {
                            text: row.session.projectName
                            color: "#e2e2e8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Text {
                            text: row.session.title || Theme.relativeTime(row.session.modifiedAt, card.nowEpoch)
                            color: "#bcbcc8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                    }
                    Text {
                        text: Theme.relativeTime(row.session.modifiedAt, card.nowEpoch)
                        color: "#9d9dac"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                    Text {
                        text: ""
                        color: Theme.rgba([1, 1, 1], row.hovered ? 0.9 : 0.0)
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                }

                MouseArea {
                    id: rowHover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (card.dataSource) card.dataSource.openSession(row.session.id)
                }
            }
        }
    }
}
