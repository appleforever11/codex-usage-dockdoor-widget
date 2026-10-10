import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "lib/Theme.js" as Theme
import "components"

// Panel representation with simple, user-selectable styles:
//   gauge    — usage ring with the percentage inside it
//   bar      — "86%  Luna-6" over a horizontal progress bar (fixed length)
//   percent  — the percentage (optionally captioned "Codex")
Item {
    id: compact

    // The containing PlasmoidItem (set by main.qml; optional so the widget
    // can render in offscreen test harnesses).
    property var plasmoidItem: null

    // injected from main.qml
    property var dataSource: null
    property var clock: null
    property var configuration: null
    property var plasmaPalette: null
    property string themeName: "Astra"
    property string panelStyle: "gauge"        // gauge | bar | percent
    property double panelLength: 110           // extent along the panel (bar)
    property bool showCodexLabel: true         // "Codex" under the percent style
    property double sparkleIntensity: 1
    property bool animationsEnabled: true

    // Anything saved by earlier versions ("auto", "compact", "extended")
    // collapses to the gauge.
    readonly property string style: {
        const value = String(panelStyle).toLowerCase();
        return (value === "bar" || value === "percent") ? value : "gauge";
    }

    readonly property var theme: Theme.resolveTheme(configuration, plasmaPalette, themeName)
    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
    readonly property double dim: Math.min(width, height)

    // The panel always shows the account usage percent — no rotating deck.
    // A label that keeps changing value also keeps changing the widget's
    // ideal width, which read as jitter.
    readonly property double fractionRemaining: dataSource && dataSource.usage
        ? Math.max(0, Math.min(1, dataSource.usage.percentRemaining)) : 0
    readonly property string percentText: dataSource && dataSource.usage
        ? Math.round(fractionRemaining * 100) + "%" : "…%"
    readonly property string modelName: dataSource && dataSource.modelSettings
        ? dataSource.modelSettings.shortModelName : "Codex"

    // Percentage turns amber when the data is stale so the tiny panel
    // representation still communicates health without extra chrome.
    readonly property var percentTint: {
        if (!dataSource || !dataSource.usage) return [0.55, 0.57, 0.60];
        return dataSource.usage.isStale ? [1.0, 0.58, 0.0] : [1, 1, 1];
    }

    // Length along the panel axis; thickness comes from the panel itself.
    readonly property double panelExtent: Math.max(56, Math.min(360, panelLength))

    Layout.minimumWidth: isVertical ? 0 : (style === "bar" ? panelExtent : Math.max(dim, 30))
    Layout.minimumHeight: isVertical ? (style === "bar" ? panelExtent : Math.max(dim, 30)) : 0
    Layout.preferredWidth: isVertical ? width : (style === "bar" ? panelExtent : Math.max(dim, 34))
    Layout.preferredHeight: isVertical ? (style === "bar" ? panelExtent : Math.max(dim, 34)) : height

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (compact.plasmoidItem) compact.plasmoidItem.expanded = !compact.plasmoidItem.expanded
    }

    // --- gauge: ring with the percentage inside ---------------------------
    // (UsageRing's built-in label is off — this Text is the single % so it
    // can tint amber when the snapshot is stale.)
    Item {
        visible: compact.style === "gauge"
        anchors.centerIn: parent
        width: Math.max(24, Math.min(compact.dim * 0.82, 46))
        height: width

        UsageRing {
            id: gaugeRing
            anchors.fill: parent
            showsPercent: false
            // Same thickness setting as the dashboard ring, scaled to the
            // panel ring's size (7px on the 68px dashboard ring = default).
            readonly property int configThickness: compact.configuration && compact.configuration.ringThickness
                ? compact.configuration.ringThickness : 7
            lineWidth: Math.max(2, parent.width * configThickness / 68)
            ringStyle: compact.configuration ? String(compact.configuration.ringStyle || "gradient") : "gradient"
            sparklesEnabled: compact.configuration ? compact.configuration.ringSparkles !== false : true
            theme: compact.theme
            percentRemaining: compact.fractionRemaining
            sparkleIntensity: compact.sparkleIntensity
            animationsEnabled: compact.animationsEnabled
            clock: compact.clock
        }
        Text {
            anchors.centerIn: parent
            text: compact.percentText
            color: Theme.rgba(compact.percentTint, 1)
            font.family: Theme.fontFamily(UIFont.configured)
            font.pixelSize: Math.max(7.5, Math.min(parent.width * 0.28, 11))
            font.weight: Font.Bold
            style: Text.Raised
            styleColor: "#c0000000"
        }
    }

    // --- percent: the number, optionally with a small Codex label ---------
    Column {
        visible: compact.style === "percent"
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: compact.percentText
            color: Theme.rgba(compact.percentTint, 1)
            font.family: Theme.fontFamily(UIFont.configured)
            font.pixelSize: Math.max(10, Math.min(compact.dim * 0.38, 15))
            font.weight: Font.Black
            style: Text.Raised
            styleColor: "#c0000000"
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: compact.showCodexLabel
            text: "Codex"
            color: Theme.rgba([1, 1, 1], 0.55)
            font.family: Theme.fontFamily(UIFont.configured)
            font.pixelSize: Math.max(7, Math.min(compact.dim * 0.20, 9))
            font.weight: Font.DemiBold
            font.letterSpacing: 0.8
        }
    }

    // --- bar: "86%  Luna-6" over a progress bar (horizontal panel) ---------
    ColumnLayout {
        visible: compact.style === "bar" && !compact.isVertical
        anchors.fill: parent
        anchors.margins: 7
        spacing: 3

        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Text {
                text: compact.percentText
                color: Theme.rgba(compact.percentTint, 1)
                font.family: Theme.fontFamily(UIFont.configured)
                font.pixelSize: Math.max(9, Math.min(compact.dim * 0.28, 12))
                font.weight: Font.Bold
                style: Text.Raised
                styleColor: "#c0000000"
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignRight
                text: compact.modelName
                color: Theme.rgba([1, 1, 1], 0.60)
                font.family: Theme.fontFamily(UIFont.configured)
                font.pixelSize: Math.max(8, Math.min(compact.dim * 0.22, 10))
                elide: Text.ElideRight
            }
        }
        ThemeProgressBar {
            Layout.fillWidth: true
            barHeight: Math.max(4, Math.min(compact.dim * 0.11, 6))
            theme: compact.theme
            value: compact.fractionRemaining
            sparkleIntensity: compact.sparkleIntensity
            glowIntensity: 1
            animationsEnabled: compact.animationsEnabled
            clock: compact.clock
        }
    }

    // --- bar, vertical panel: percent / vertical fill / name ---------------
    ColumnLayout {
        visible: compact.style === "bar" && compact.isVertical
        anchors.fill: parent
        anchors.margins: 6
        spacing: 3

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: compact.percentText
            color: Theme.rgba(compact.percentTint, 1)
            font.family: Theme.fontFamily(UIFont.configured)
            font.pixelSize: Math.max(8, Math.min(compact.dim * 0.28, 11))
            font.weight: Font.Bold
        }
        Rectangle {
            Layout.fillHeight: true
            Layout.alignment: Qt.AlignHCenter
            width: Math.max(4, Math.min(compact.dim * 0.11, 6))
            radius: width / 2
            color: Theme.rgba(compact.theme.accent, 0.10)
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                height: parent.height * compact.fractionRemaining
                radius: parent.radius
                color: Theme.rgba(compact.theme.accent, 0.92)
            }
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: compact.modelName
            color: Theme.rgba([1, 1, 1], 0.60)
            font.family: Theme.fontFamily(UIFont.configured)
            font.pixelSize: Math.max(8, Math.min(compact.dim * 0.22, 10))
        }
    }
}
