import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// Panel (compact) representation settings: which style the dock widget uses
// and how much room it takes.
KCM.SimpleKCM {
    id: page

    property alias cfg_compactStyle: styleCombo.currentValue
    property alias cfg_panelWidgetLength: lengthSpin.value
    property alias cfg_panelShowCodexLabel: codexLabelCheck.checked
    property alias cfg_modelTheme: themeCombo.currentText

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        QQC2.Label {
            text: i18n("How the widget sits in the panel. The dashboard popup is configured on the Appearance page.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Panel style")
        }

        QQC2.ComboBox {
            id: styleCombo
            Kirigami.FormData.label: i18n("Style:")
            model: [
                { value: "gauge", text: i18n("Gauge — ring with % inside") },
                { value: "bar", text: i18n("Bar — %, progress bar, model") },
                { value: "percent", text: i18n("Percent — number only") },
            ]
            textRole: "text"
            valueRole: "value"
            // Installs saved before the style rework hold "auto"/"compact"/
            // "extended"; land them on the gauge instead of an empty box.
            Component.onCompleted: if (currentIndex < 0) currentIndex = 0
        }

        QQC2.SpinBox {
            id: lengthSpin
            Kirigami.FormData.label: i18n("Widget length (px):")
            from: 60
            to: 320
            stepSize: 10
        }
        QQC2.Label {
            text: i18n("Applies to the Bar panel style — how much room the widget takes along the panel.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            font.pointSize: -1
            font.pixelSize: 11
            opacity: 0.7
        }

        QQC2.CheckBox {
            id: codexLabelCheck
            Kirigami.FormData.label: i18n("Percent style:")
            text: i18n("Show “Codex” under the percentage")
        }

        QQC2.Label {
            text: i18n("Used by the Apple liquid-glass mode; the Plasma and Custom modes ignore it.")
            textFormat: Text.PlainText
            wrapMode: Text.WordWrap
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Dock ring theme")
        }

        QQC2.ComboBox {
            id: themeCombo
            Kirigami.FormData.label: i18n("Planet:")
            model: ["Astra", "Luna", "Sol", "Terra", "Rainbow"]
        }
    }
}
