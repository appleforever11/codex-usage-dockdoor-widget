import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import "../lib/Theme.js" as Theme

// Port of CodexV6CardShell: header with icon + title, info affordance,
// themed surface with breathing border, arrangement controls, context menu
// (details / move-to-page), and the wiggle in edit mode.
Rectangle {
    id: shell

    property string cardId: ""
    property var theme: Theme.theme("Astra")
    property bool isEditing: false
    property bool isHero: false
    property bool highContrast: false
    property double cardPadding: 11
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property var clock: null
    readonly property double animTime: clock ? clock.time : 0
    property var detailText: ""
    signal openDetails()

    default property alias content: _content.data

    radius: 14
    implicitHeight: _layout.implicitHeight + cardPadding * 2
    color: Theme.rgba([1, 1, 1], isHero ? 0.0 : 0.035)
    border.width: isEditing ? 1.6 : (highContrast ? 1.3 : 0.8)
    border.color: isEditing
        ? Theme.rgba(theme.accent, 0.6)
        : (highContrast ? Theme.rgba([1, 1, 1], 0.30) : Theme.rgba([1, 1, 1], 0.10))

    // Breathing accent wash at the top-trailing corner of the surface.
    Rectangle {
        id: _wash
        anchors.fill: parent
        radius: shell.radius
        visible: !shell.isHero
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.rgba(Theme.dataColor(shell.theme, 0), 0.12) }
            GradientStop { position: 0.55; color: Theme.rgba(Theme.dataColor(shell.theme, 1), 0.035) }
            GradientStop { position: 1.0; color: Theme.rgba([1, 1, 1], 0) }
        }
        opacity: shell.animationsEnabled ? 0.85 + 0.15 * Math.sin(shell.animTime * 0.75) : 0.85
    }

    // Wiggle while arranging (CodexV6WiggleModifier).
    rotation: isEditing && animationsEnabled ? Math.sin(animTime * 7.0 + wiggleSeed) * 1.25 : 0

    readonly property double wiggleSeed: {
        let hash = 0;
        const text = shell.cardId;
        for (let i = 0; i < text.length; ++i)
            hash = (hash * 17 + text.charCodeAt(i)) % 31;
        return hash;
    }

    ColumnLayout {
        id: _layout
        anchors.fill: parent
        anchors.margins: shell.isHero ? 4 : shell.cardPadding
        spacing: 9

        RowLayout {
            visible: !shell.isHero
            spacing: 6
            Layout.fillWidth: true

            Text {
                text: Theme.iconGlyph((Theme.CARDS[shell.cardId] || {}).icon)
                color: Theme.rgba(shell.theme.accent, 1)
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
            }
            Text {
                text: (Theme.CARDS[shell.cardId] || {}).title || shell.cardId
                color: "#f0f0f4"
                font.pixelSize: shell.isHero ? 13 : 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                visible: !shell.isEditing
                icon.name: "help-about"
                implicitWidth: 18
                implicitHeight: 18
                opacity: mouse.hovered ? 1 : 0.55
                onClicked: shell.openDetails()
                PlasmaComponents.ToolTip {
                    text: shell.detailText !== "" ? shell.detailText : ((Theme.CARDS[shell.cardId] || {}).title || "") + " details"
                }
            }
            Text {
                visible: shell.isEditing
                text: "⠿"
                color: Theme.rgba(shell.theme.accent, 1)
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }

        Item {
            id: _content
            Layout.fillWidth: true
            implicitHeight: childrenRect.height
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        enabled: false
    }
}
