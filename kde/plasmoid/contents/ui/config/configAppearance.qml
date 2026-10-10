import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import QtQuick.Dialogs as Dialogs
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Dashboard appearance: the three style modes (Apple liquid glass / Plasma /
// custom accent), per-page planet themes for the liquid-glass mode, and the
// visual tuning (density, background, effects, font).
KCM.SimpleKCM {
    id: page

    property alias cfg_themeMode: modeStore.value
    property alias cfg_customAccentColor: accentField.text
    property alias cfg_pageThemeOverview: overviewThemeCombo.currentText
    property alias cfg_pageThemeActivity: activityThemeCombo.currentText
    property alias cfg_pageThemeModels: modelsThemeCombo.currentText
    property alias cfg_pageThemeHealth: healthThemeCombo.currentText
    property alias cfg_uiFontFamily: fontCombo.editText
    property alias cfg_showDataStatus: statusCheck.checked
    property alias cfg_cardDensity: densityCombo.currentValue
    property alias cfg_sparkleIntensity: sparkleSlider.value
    property alias cfg_glowIntensity: glowSlider.value
    property alias cfg_animationsEnabled: animCheck.checked
    property alias cfg_highContrast: contrastCheck.checked
    property alias cfg_backgroundOpacity: opacitySlider.value
    property alias cfg_frostedGlass: frostedCheck.checked
    property alias cfg_ringStyle: ringStyleCombo.currentValue
    property alias cfg_ringThickness: ringThicknessSpin.value
    property alias cfg_ringSparkles: ringSparklesCheck.checked

    // KCM loads cfg_* into these; the mode buttons read/write the store.
    QtObject {
        id: modeStore
        property string value: "apple"
    }

    // Hidden mirror of the accent color the swatches/dialog write to; the
    // visible swatch row reads it back so the selection stays highlighted.
    QQC2.TextField {
        id: accentField
        visible: false
        text: "#9C6CE8"
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.Label {
            text: i18n("Liquid Glass keeps the per-page planet themes of the original widget. Plasma follows your system color scheme and accent. Custom colors everything from one accent of your choice.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Style mode")
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Mode:")

            Repeater {
                model: [
                    { value: "apple", text: i18n("Liquid Glass"), icon: "preferences-desktop-glass" },
                    { value: "plasma", text: i18n("Plasma Style"), icon: "preferences-desktop-color" },
                    { value: "custom", text: i18n("Custom Accent"), icon: "color-picker" },
                ]
                QQC2.Button {
                    required property var modelData
                    checkable: true
                    icon.name: modelData.icon
                    text: modelData.text
                    checked: modeStore.value === modelData.value
                    opacity: checked ? 1 : 0.75
                    onClicked: modeStore.value = modelData.value
                }
            }
        }

        RowLayout {
            visible: modeStore.value === "custom"
            Kirigami.FormData.label: i18n("Accent color:")

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: [
                        "#4095E8", "#3FC2C7", "#4DC7A0", "#57B860", "#D8B84A",
                        "#E6953F", "#E46055", "#E86A9C", "#9C6CE8", "#6B7BE8",
                    ]
                    Rectangle {
                        required property string modelData
                        readonly property bool selected: accentField.text.toUpperCase() === modelData.toUpperCase()
                        width: 26
                        height: 26
                        radius: 13
                        color: modelData
                        border.width: selected ? 3 : 1
                        border.color: selected ? Kirigami.Theme.highlightColor : Kirigami.Theme.disabledTextColor

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: accentField.text = parent.modelData
                        }
                    }
                }
            }

            QQC2.Button {
                icon.name: "color-picker"
                text: i18n("Pick…")
                onClicked: colorDialog.open()
            }
        }

        Dialogs.ColorDialog {
            id: colorDialog
            title: i18n("Custom accent color")
            onAccepted: accentField.text = colorDialog.selectedColor.toString().toUpperCase()
        }

        // --- liquid-glass per-page themes ------------------------------------
        QQC2.Label {
            visible: modeStore.value === "apple"
            text: i18n("Each dashboard page can carry its own planet identity.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Page themes")
        }

        QQC2.ComboBox {
            id: overviewThemeCombo
            visible: modeStore.value === "apple"
            Kirigami.FormData.label: i18n("Overview:")
            model: ["Astra", "Luna", "Sol", "Terra", "Rainbow"]
        }
        QQC2.ComboBox {
            id: activityThemeCombo
            visible: modeStore.value === "apple"
            Kirigami.FormData.label: i18n("Activity:")
            model: ["Luna", "Astra", "Sol", "Terra", "Rainbow"]
        }
        QQC2.ComboBox {
            id: modelsThemeCombo
            visible: modeStore.value === "apple"
            Kirigami.FormData.label: i18n("Models:")
            model: ["Terra", "Astra", "Luna", "Sol", "Rainbow"]
        }
        QQC2.ComboBox {
            id: healthThemeCombo
            visible: modeStore.value === "apple"
            Kirigami.FormData.label: i18n("Health:")
            model: ["Sol", "Astra", "Luna", "Terra", "Rainbow"]
        }

        // --- dashboard surfaces ----------------------------------------------
        QQC2.Label {
            text: i18n("Card layout, backgrounds, and motion.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dashboard")
        }

        QQC2.ComboBox {
            id: fontCombo
            editable: true
            Kirigami.FormData.label: i18n("Interface font:")
            model: ["Auto"].concat(Qt.fontFamilies().sort())
            // Empty storage means Auto; show it as such in the box.
            Component.onCompleted: if (editText.length === 0) editText = "Auto"
        }
        QQC2.Label {
            text: i18n("Auto prefers Hack Nerd Font (falling back to any installed Nerd/Hack variant) so the icon glyphs render. Pick or type any installed family to override.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pointSize: -1
            font.pixelSize: 11
            opacity: 0.7
        }

        QQC2.CheckBox {
            id: statusCheck
            Kirigami.FormData.label: i18n("Status:")
            text: i18n("Show data freshness badge")
        }

        QQC2.ComboBox {
            id: densityCombo
            Kirigami.FormData.label: i18n("Card spacing:")
            model: [
                { value: "compact", text: i18n("Compact") },
                { value: "standard", text: i18n("Standard") },
                { value: "spacious", text: i18n("Spacious") },
            ]
            textRole: "text"
            valueRole: "value"
        }

        QQC2.Slider {
            id: opacitySlider
            Kirigami.FormData.label: i18n("Background opacity:")
            from: 0.2
            to: 1.0
            stepSize: 0.05
        }

        QQC2.CheckBox {
            id: frostedCheck
            Kirigami.FormData.label: i18n("Background:")
            text: i18n("Frosted glass tint")
        }

        QQC2.Slider {
            id: sparkleSlider
            Kirigami.FormData.label: i18n("Sparkle intensity:")
            from: 0
            to: 1.5
            stepSize: 0.05
        }

        QQC2.Slider {
            id: glowSlider
            Kirigami.FormData.label: i18n("Glow intensity:")
            from: 0
            to: 1.5
            stepSize: 0.05
        }

        QQC2.CheckBox {
            id: animCheck
            Kirigami.FormData.label: i18n("Motion:")
            text: i18n("Animate glow and sparkles")
        }

        QQC2.CheckBox {
            id: contrastCheck
            text: i18n("High contrast edges")
        }

        // --- percentage ring --------------------------------------------------
        QQC2.Label {
            text: i18n("The overview wheel and the panel gauge share these.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Percentage ring")
        }

        QQC2.ComboBox {
            id: ringStyleCombo
            Kirigami.FormData.label: i18n("Ring style:")
            model: [
                { value: "gradient", text: i18n("Gradient — glow and sparkles") },
                { value: "solid", text: i18n("Solid — clean accent arc") },
                { value: "dual", text: i18n("Dual — arc with inner ring") },
                { value: "segments", text: i18n("Segments — discrete blocks") },
                { value: "ticks", text: i18n("Ticks — dial marks") },
            ]
            textRole: "text"
            valueRole: "value"
        }

        QQC2.SpinBox {
            id: ringThicknessSpin
            Kirigami.FormData.label: i18n("Ring thickness (px):")
            from: 3
            to: 12
        }

        QQC2.CheckBox {
            id: ringSparklesCheck
            Kirigami.FormData.label: i18n("Ring sparkles:")
            text: i18n("Sparkles ride the filled arc")
        }
    }
}
