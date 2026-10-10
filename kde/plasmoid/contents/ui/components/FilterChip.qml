import QtQuick
import "../lib/Theme.js" as Theme

Rectangle {
    id: chip

    property string label: ""
    property var accent: null
    signal clicked()

    radius: height / 2
    height: 18
    implicitWidth: chipText.implicitWidth + 14
    color: Theme.rgba(accent || [1, 1, 1], chipHover.hovered ? 0.2 : 0.12)
    border.width: 0.6
    border.color: Theme.rgba(accent || [1, 1, 1], 0.3)

    Text {
        id: chipText
        anchors.centerIn: parent
        text: chip.label
        color: "#f0f0f4"
        font.pixelSize: 10
        font.family: Theme.fontFamily(UIFont.configured)
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: chipHover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
}
