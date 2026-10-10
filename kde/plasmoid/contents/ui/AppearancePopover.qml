import QtQuick
import QtQuick.Layouts
import "lib/Theme.js" as Theme
import "components"

// Port of CodexV6AppearancePopover, extended for the KDE port's three style
// modes: Apple liquid glass (per-page planet themes), Plasma (accent from the
// system color scheme), and a custom accent color. Scrollable with a plain
// Flickable — wheel scrolling with no visible scrollbar, matching the card
// pages — and sized to its content so nothing is cramped off-screen.
Rectangle {
    id: popover

    property var theme: Theme.theme("Astra")
    property var configuration: null
    property var plasmaPalette: null
    property string currentPageId: "overview"
    property var clock: null
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    signal closed()

    readonly property string themeMode: configuration ? String(configuration.themeMode || "apple") : "apple"

    function themeKeyForPage() {
        return ({
            overview: "pageThemeOverview",
            activity: "pageThemeActivity",
            models: "pageThemeModels",
            health: "pageThemeHealth",
        })[currentPageId] || "pageThemeOverview";
    }

    function currentPageTheme() {
        if (!configuration)
            return "Astra";
        return configuration[themeKeyForPage()] || Theme.PAGE_DEFAULT_THEME[currentPageId] || "Astra";
    }

    function selectTheme(name) {
        if (configuration)
            configuration[themeKeyForPage()] = name;
    }

    function selectMode(mode) {
        if (configuration)
            configuration.themeMode = mode;
    }

    radius: 16
    color: Theme.rgba(theme.base, 0.97)
    border.width: 1
    border.color: Theme.rgba(theme.accent, 0.25)
    // Fit the content; cap at the dashboard height (the body scrolls then).
    width: 316
    height: Math.min(parent ? parent.height - 20 : 540, _chrome.implicitHeight + 28)

    Keys.onEscapePressed: closed()

    Rectangle {
        anchors.fill: parent
        radius: popover.radius
        color: "transparent"
        border.width: 0.8
        border.color: Theme.rgba([1, 1, 1], 0.10)
    }

    ColumnLayout {
        id: _chrome
        anchors.fill: parent
        anchors.margins: 14
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                spacing: 3
                Text {
                    text: "Appearance"
                    color: "#f4f4f7"
                    font.pixelSize: 15
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.Bold
                }
                Text {
                    text: themeMode === "apple" ? "Customize this page"
                        : (themeMode === "plasma" ? "Following your Plasma colors" : "Your accent, everywhere")
                    color: "#bcbcc8"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                }
            }
            Item { Layout.fillWidth: true }
            Rectangle {
                radius: height / 2
                height: 20
                width: currentLabel.implicitWidth + 16
                color: Theme.rgba(theme.accent, 0.12)
                Text {
                    id: currentLabel
                    anchors.centerIn: parent
                    text: themeMode === "apple" ? Theme.theme(popover.currentPageTheme()).displayName : theme.displayName
                    color: Theme.rgba(popover.theme.accent, 1)
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.DemiBold
                }
            }
        }

        // Plain Flickable: wheel/touch scrolling with no scrollbar, exactly
        // like the dashboard's card pages. implicitHeight follows the
        // content so the popover sizes to fit when there is room.
        Flickable {
            id: body
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitHeight: contentHeight
            contentWidth: width
            contentHeight: settingsColumn.implicitHeight + 4
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            maximumFlickVelocity: 2200

            ColumnLayout {
                id: settingsColumn
                width: body.width
                spacing: 12

                SectionLabel { text: "STYLE" }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { value: "apple", label: "Liquid Glass", glyph: "\uF185" },
                            { value: "plasma", label: "Plasma", glyph: "\uF013" },
                            { value: "custom", label: "Custom", glyph: "\uF1FC" },
                        ]
                        Rectangle {
                            id: modeChip
                            required property var modelData
                            readonly property bool active: popover.themeMode === modelData.value
                            Layout.fillWidth: true
                            height: 40
                            radius: 9
                            color: active
                                ? Theme.rgba(popover.theme.accent, 0.26)
                                : Theme.rgba([1, 1, 1], 0.05)
                            border.width: active ? 1 : 0.8
                            border.color: active
                                ? Theme.rgba(popover.theme.accent, 0.7)
                                : Theme.rgba([1, 1, 1], 0.12)

                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 1
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modeChip.modelData.glyph
                                    color: modeChip.active ? "#f4f4f7" : "#bcbcc8"
                                    font.pixelSize: 12
                                    font.family: Theme.fontFamily(UIFont.configured)
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: modeChip.modelData.label
                                    color: modeChip.active ? "#f4f4f7" : "#bcbcc8"
                                    font.pixelSize: 10
                                    font.family: Theme.fontFamily(UIFont.configured)
                                    font.weight: Font.DemiBold
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: popover.selectMode(modeChip.modelData.value)
                            }
                        }
                    }
                }

                // Accent swatches for the custom mode.
                Flow {
                    Layout.fillWidth: true
                    visible: popover.themeMode === "custom"
                    spacing: 8

                    Repeater {
                        model: Theme.ACCENT_PRESETS
                        Rectangle {
                            id: swatch
                            required property var modelData
                            readonly property bool active: popover.configuration
                                && String(popover.configuration.customAccentColor || "").toUpperCase()
                                    === modelData.value.toUpperCase()
                            width: 24
                            height: 24
                            radius: 12
                            color: modelData.value
                            border.width: active ? 2 : 1
                            border.color: active ? "white" : Theme.rgba([1, 1, 1], 0.25)

                            Rectangle {
                                visible: swatch.active
                                anchors.centerIn: parent
                                width: 8
                                height: 8
                                radius: 4
                                color: "white"
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (popover.configuration) popover.configuration.customAccentColor = swatch.modelData.value
                            }
                        }
                    }
                }

                Text {
                    visible: popover.themeMode === "plasma"
                    Layout.fillWidth: true
                    text: "Accent, data colors, and background tint follow the Plasma system color scheme. Change your accent in System Settings → Colors."
                    color: "#9d9dac"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily(UIFont.configured)
                    wrapMode: Text.WordWrap
                }

                // Per-page planet themes only apply to the liquid-glass mode.
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: popover.themeMode === "apple"
                    spacing: 12

                    SectionLabel { text: "PAGE THEME" }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 2
                        columnSpacing: 8
                        rowSpacing: 8

                        Repeater {
                            model: ["Luna", "Sol", "Terra", "Astra"]
                            IdentityButton {
                                required property string modelData
                                Layout.fillWidth: true
                                identity: Theme.theme(modelData)
                                isSelected: popover.currentPageTheme() === modelData
                                buttonHeight: 54
                                sparkleIntensity: popover.sparkleIntensity
                                glowIntensity: popover.glowIntensity
                                animationsEnabled: popover.animationsEnabled
                                clock: popover.clock
                                onActivated: popover.selectTheme(modelData)
                            }
                        }
                    }

                    IdentityButton {
                        Layout.fillWidth: true
                        identity: Theme.theme("Rainbow")
                        isSelected: popover.currentPageTheme() === "Rainbow"
                        buttonHeight: 34
                        compactMode: true
                        sparkleIntensity: popover.sparkleIntensity
                        glowIntensity: popover.glowIntensity
                        animationsEnabled: popover.animationsEnabled
                        clock: popover.clock
                        onActivated: popover.selectTheme("Rainbow")
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: Theme.rgba([1, 1, 1], 0.08) }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    IntensitySlider {
                        Layout.fillWidth: true
                        labelText: "Glow"
                        symbol: ""
                        value: popover.configuration ? popover.configuration.glowIntensity : 1
                        onValueAdjusted: v => { if (popover.configuration) popover.configuration.glowIntensity = v }
                    }
                    IntensitySlider {
                        Layout.fillWidth: true
                        labelText: "Sparkles"
                        symbol: ""
                        value: popover.configuration ? popover.configuration.sparkleIntensity : 1
                        onValueAdjusted: v => { if (popover.configuration) popover.configuration.sparkleIntensity = v }
                    }
                }

                ToggleRow {
                    Layout.fillWidth: true
                    labelText: "Animate glow and sparkles"
                    checked: popover.configuration ? popover.configuration.animationsEnabled : true
                    onToggled: v => { if (popover.configuration) popover.configuration.animationsEnabled = v }
                }
                ToggleRow {
                    Layout.fillWidth: true
                    labelText: "High contrast edges"
                    checked: popover.configuration ? popover.configuration.highContrast : false
                    onToggled: v => { if (popover.configuration) popover.configuration.highContrast = v }
                }
                ToggleRow {
                    Layout.fillWidth: true
                    labelText: "Show live dataSource status"
                    checked: popover.configuration ? popover.configuration.showDataStatus : true
                    onToggled: v => { if (popover.configuration) popover.configuration.showDataStatus = v }
                }

                SectionLabel { text: "PERCENTAGE RING" }

                // Ring style: applies to the overview hero wheel and the
                // panel gauge alike.
                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    Repeater {
                        model: [
                            { value: "gradient", label: "Gradient" },
                            { value: "solid", label: "Solid" },
                            { value: "dual", label: "Dual" },
                            { value: "segments", label: "Segments" },
                            { value: "ticks", label: "Ticks" },
                        ]
                        Rectangle {
                            id: ringChip
                            required property var modelData
                            readonly property bool active: popover.configuration
                                ? String(popover.configuration.ringStyle || "gradient") === modelData.value : modelData.value === "gradient"
                            width: (body.width - 12) / 3
                            height: 26
                            radius: 8
                            color: active
                                ? Theme.rgba(popover.theme.accent, 0.28)
                                : Theme.rgba([1, 1, 1], 0.05)
                            border.width: active ? 1 : 0.8
                            border.color: active
                                ? Theme.rgba(popover.theme.accent, 0.7)
                                : Theme.rgba([1, 1, 1], 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: ringChip.modelData.label
                                color: ringChip.active ? "white" : "#bcbcc8"
                                font.pixelSize: 11
                                font.family: Theme.fontFamily(UIFont.configured)
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (popover.configuration) popover.configuration.ringStyle = ringChip.modelData.value
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: "Thickness"
                        color: "#d6d6de"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                    Slider {
                        id: ringThicknessSlider
                        Layout.fillWidth: true
                        from: 3
                        to: 12
                        stepSize: 1
                        value: popover.configuration && popover.configuration.ringThickness
                            ? popover.configuration.ringThickness : 7
                        onSliderMoved: v => { if (popover.configuration) popover.configuration.ringThickness = Math.round(v) }
                    }
                    Text {
                        text: Math.round(ringThicknessSlider.value) + " px"
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                }

                ToggleRow {
                    visible: !popover.configuration
                        || ["gradient", "solid", "dual"].indexOf(String(popover.configuration.ringStyle || "gradient")) >= 0
                    labelText: "Sparkles around the arc"
                    checked: popover.configuration ? popover.configuration.ringSparkles !== false : true
                    onToggled: v => { if (popover.configuration) popover.configuration.ringSparkles = v }
                }

                SectionLabel { text: "CARD SPACING" }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["compact", "standard", "spacious"]
                        Rectangle {
                            id: densityChip
                            required property string modelData
                            Layout.fillWidth: true
                            height: 28
                            radius: 8
                            readonly property bool active: popover.configuration
                                ? popover.configuration.cardDensity === modelData : modelData === "standard"
                            color: active
                                ? Theme.rgba(popover.theme.accent, 0.28)
                                : Theme.rgba([1, 1, 1], 0.05)
                            border.width: active ? 1 : 0.8
                            border.color: active
                                ? Theme.rgba(popover.theme.accent, 0.7)
                                : Theme.rgba([1, 1, 1], 0.12)

                            Text {
                                anchors.centerIn: parent
                                text: densityChip.modelData.charAt(0).toUpperCase() + densityChip.modelData.slice(1)
                                color: densityChip.active ? "white" : "#bcbcc8"
                                font.pixelSize: 11
                                font.family: Theme.fontFamily(UIFont.configured)
                                font.weight: Font.DemiBold
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (popover.configuration) popover.configuration.cardDensity = densityChip.modelData
                            }
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: "Background opacity and frosted glass follow the global appearance settings."
                    color: "#9d9dac"
                    font.pixelSize: 10
                    font.family: Theme.fontFamily(UIFont.configured)
                    wrapMode: Text.WordWrap
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 30
            radius: 8
            color: Theme.rgba(popover.theme.accent, 0.18)
            border.width: 1
            border.color: Theme.rgba(popover.theme.accent, 0.5)

            Text {
                anchors.centerIn: parent
                text: "Done"
                color: "white"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: popover.closed()
            }
        }
    }

    component SectionLabel: Text {
        color: "#bcbcc8"
        font.pixelSize: 10
        font.family: Theme.fontFamily(UIFont.configured)
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2
    }

    component IntensitySlider: ColumnLayout {
        id: sliderControl

        property string labelText: ""
        property string symbol: ""
        property double value: 1
        signal valueAdjusted(real newValue)

        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: sliderControl.symbol + " " + sliderControl.labelText
                color: "#d6d6de"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(sliderControl.value * 100) + "%"
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }

        Slider {
            id: slider
            Layout.fillWidth: true
            from: 0
            to: 1.5
            stepSize: 0.05
            value: sliderControl.value
            onSliderMoved: sliderControl.valueAdjusted(value)
        }
    }

    component ToggleRow: RowLayout {
        id: toggleRow

        property string labelText: ""
        property bool checked: false
        signal toggled(bool value)

        spacing: 8

        Rectangle {
            width: 30
            height: 17
            radius: 9
            color: toggleRow.checked
                ? Theme.rgba(popover.theme.accent, 0.85)
                : Theme.rgba([1, 1, 1], 0.14)
            Rectangle {
                width: 13
                height: 13
                radius: 7
                anchors.verticalCenter: parent.verticalCenter
                x: toggleRow.checked ? parent.width - 15 : 2
                color: "white"
                Behavior on x { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: toggleRow.toggled(!toggleRow.checked)
            }
        }
        Text {
            text: toggleRow.labelText
            color: "#d6d6de"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            Layout.fillWidth: true
        }
    }

    component Slider: Item {
        id: sliderBase

        property real from: 0
        property real to: 1
        property real stepSize: 0.05
        property real value: from
        signal sliderMoved()

        height: 18
        implicitWidth: 100

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 4
            radius: 2
            color: Theme.rgba([1, 1, 1], 0.14)
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: handle.x + handle.width / 2
            height: 4
            radius: 2
            color: Theme.rgba(popover.theme.accent, 0.85)
        }
        Rectangle {
            id: handle
            width: 14
            height: 14
            radius: 7
            anchors.verticalCenter: parent.verticalCenter
            x: positionForValue(sliderBase.value)
            color: "white"
            border.width: 1
            border.color: Theme.rgba(popover.theme.accent, 0.7)

            function positionForValue(v) {
                const fraction = (v - sliderBase.from) / (sliderBase.to - sliderBase.from);
                return Math.max(0, Math.min(parent.width - width, fraction * (parent.width - width)));
            }
            function valueForPosition(x) {
                const fraction = x / Math.max(1, parent.width - width);
                const raw = sliderBase.from + fraction * (sliderBase.to - sliderBase.from);
                const stepped = Math.round(raw / sliderBase.stepSize) * sliderBase.stepSize;
                return Math.max(sliderBase.from, Math.min(sliderBase.to, stepped));
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            function updateValue(mouseX) {
                const x = Math.max(0, Math.min(parent.width - handle.width, mouseX - handle.width / 2));
                sliderBase.value = handle.valueForPosition(x);
                sliderBase.sliderMoved();
            }
            onPressed: mouse => updateValue(mouse.x)
            onPositionChanged: mouse => { if (pressed) updateValue(mouse.x) }
            cursorShape: Qt.PointingHandCursor
        }
    }
}
