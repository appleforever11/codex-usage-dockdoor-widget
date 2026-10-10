import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6DataHealthCard: per-source readiness list + status line.
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

    readonly property var statuses: dataSource && dataSource.analytics ? dataSource.analytics.sourceStatuses : []
    readonly property var usage: dataSource ? dataSource.usage : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    implicitHeight: _column.implicitHeight

    function stateColor(state) {
        if (state === "Ready") return Theme.dataColor(card.theme, 2);
        if (state === "Optional") return Theme.dataColor(card.theme, 1);
        if (state === "Waiting") return Theme.dataColor(card.theme, 0);
        return Theme.dataColor(card.theme, 3);
    }

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5

        Repeater {
            model: card.statuses

            ColumnLayout {
                id: row
                required property var modelData
                spacing: 1

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 7
                    Rectangle {
                        width: 7; height: 7; radius: 4
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.rgba(card.stateColor(row.modelData.state), 1)
                    }
                    Text {
                        text: row.modelData.title
                        color: "#d6d6de"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: row.modelData.state
                        color: Theme.rgba(card.stateColor(row.modelData.state), 1)
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                }
                Text {
                    text: row.modelData.detail
                    color: "#9d9dac"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily(UIFont.configured)
                    Layout.leftMargin: 14
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.rgba([1, 1, 1], 0.08)
        }

        Text {
            text: card.usage ? card.usage.statusLabel : ""
            color: Theme.rgba(card.theme.accent, 1)
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
