import QtQuick
import "../lib/Theme.js" as Theme

// Port of CodexV6Metric: bold value + small label on a themed surface.
// treatment "soft" is the plain white 9% tile; "outlined" uses the
// CodexThemeMetricSurface look with a tinted border and inner wash.
Rectangle {
    id: tile

    property var theme: Theme.theme("Astra")
    property string value: "—"
    property string label: ""
    property var tintColor: null       // [r,g,b] semantic tint
    property string treatment: "outlined"
    property bool highContrast: false

    radius: treatment === "soft" ? 9 : Math.min(12, Math.max(9, height * 0.30))
    implicitHeight: 44

    readonly property var _tint: tintColor !== null ? tintColor : theme.accent

    color: treatment === "soft"
        ? Theme.rgba([1, 1, 1], 0.09)
        : Theme.rgba(_tint, highContrast ? 0.10 : 0.055)
    border.width: treatment === "soft" ? 0 : (highContrast ? 1.1 : 0.8)
    border.color: treatment === "soft"
        ? Theme.rgba([1, 1, 1], 0)
        : Theme.rgba(_tint, 0.28)

    Column {
        anchors.centerIn: parent
        spacing: 2
        width: parent.width - 12

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: tile.value
            color: "#f2f2f5"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideMiddle
            minimumPixelSize: 7
            fontSizeMode: Text.HorizontalFit
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            width: parent.width
            text: tile.label
            color: "#bcbcc8"
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
