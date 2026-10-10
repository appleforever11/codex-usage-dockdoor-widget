import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme

// Port of CodexV6LabeledBar: label + value above a themed progress bar.
ColumnLayout {
    id: labeledBar

    property var theme: Theme.theme("Astra")
    property string labelText: ""
    property double value: 0
    property string valueLabel: "—"
    property var tint: null
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null

    spacing: 4

    RowLayout {
        Layout.fillWidth: true
        Text {
            text: labeledBar.labelText
            color: "#d6d6de"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.DemiBold
            Layout.fillWidth: true
        }
        Text {
            text: labeledBar.valueLabel
            color: Theme.rgba(labeledBar.tint ? labeledBar.tint : labeledBar.theme.accent, 1)
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Bold
        }
    }

    ThemeProgressBar {
        Layout.fillWidth: true
        theme: labeledBar.theme
        value: labeledBar.value
        barHeight: 6
        tintColor: labeledBar.tint
        sparkleIntensity: labeledBar.sparkleIntensity
        glowIntensity: labeledBar.glowIntensity
        animationsEnabled: labeledBar.animationsEnabled
        clock: labeledBar.clock
    }
}
