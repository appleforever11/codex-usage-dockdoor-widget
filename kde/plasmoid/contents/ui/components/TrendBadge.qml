import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexV6TrendBadge: pill with an arrow for day-over-day change.
Rectangle {
    id: badge

    property var theme: Theme.theme("Astra")
    property double change: 0
    property string labelText: "vs yesterday"

    readonly property int roundedPercent: Math.round(Math.abs(change) * 100)
    readonly property bool isNeutral: roundedPercent === 0
    readonly property var tint: isNeutral ? [0.55, 0.57, 0.60] : (change >= 0 ? Theme.dataColor(theme, 1) : Theme.dataColor(theme, 2))

    radius: height / 2
    height: 17
    implicitWidth: _row.implicitWidth + 12
    color: Theme.rgba(tint, 0.10)
    border.width: 0.6
    border.color: Theme.rgba(tint, 0.16)

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 3
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.isNeutral ? "→" : (badge.change >= 0 ? "" : "↘")
            color: Theme.rgba(badge.tint, 1)
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: badge.roundedPercent + "% " + badge.labelText
            color: Theme.rgba(badge.tint, 1)
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.DemiBold
        }
    }
}
