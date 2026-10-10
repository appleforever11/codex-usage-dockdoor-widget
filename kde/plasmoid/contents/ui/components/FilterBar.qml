import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme

// Port of CodexV6FilterBar: window filter for the Activity page and model
// filter for the Models page, with the themed planet marker. Clicking a
// filter cycles its options (equivalent to the macOS menu selection).
Rectangle {
    id: filterBar

    property var theme: Theme.theme("Astra")
    property string pageId: "activity"
    property string activityWindow: "sevenDays"
    property string modelFilter: ""
    property var models: []
    property var planetClock: null

    signal activityWindowSelected(string value)
    signal modelFilterSelected(string value)

    radius: height / 2
    implicitHeight: filterRow.implicitHeight + 10
    color: Theme.rgba(theme.accent, 0.07)
    border.width: 0.6
    border.color: Theme.rgba(theme.accent, 0.13)

    readonly property var windowOptions: [
        { value: "today", label: "Today" },
        { value: "sevenDays", label: "7 days" },
        { value: "thirtyDays", label: "30 days" },
    ]

    readonly property string windowLabel: {
        for (let i = 0; i < windowOptions.length; ++i)
            if (windowOptions[i].value === activityWindow)
                return windowOptions[i].label;
        return "7 days";
    }

    readonly property string modelLabel: {
        if (!modelFilter)
            return "All models";
        for (let i = 0; i < models.length; ++i)
            if ((models[i].model + "|" + models[i].reasoningEffort) === modelFilter)
                return Theme.modelLabel(models[i].model, "Unknown") + " · " + Theme.reasoningLabel(models[i].reasoningEffort);
        return "All models";
    }

    function cycleWindow() {
        for (let i = 0; i < windowOptions.length; ++i) {
            if (windowOptions[i].value === activityWindow) {
                activityWindowSelected(windowOptions[(i + 1) % windowOptions.length].value);
                return;
            }
        }
        activityWindowSelected("today");
    }

    function cycleModel() {
        const options = [""].concat(models.map(m => m.model + "|" + m.reasoningEffort));
        const index = options.indexOf(modelFilter);
        modelFilterSelected(options[(index + 1) % options.length]);
    }

    RowLayout {
        id: filterRow
        anchors.fill: parent
        anchors.leftMargin: 7
        anchors.rightMargin: 7
        spacing: 5

        Text {
            text: ""
            color: Theme.rgba(filterBar.theme.accent, 1)
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
        }

        FilterChip {
            visible: filterBar.pageId === "activity"
            label: filterBar.windowLabel
            accent: filterBar.theme.accent
            onClicked: filterBar.cycleWindow()
        }
        FilterChip {
            visible: filterBar.pageId === "models"
            label: filterBar.modelLabel
            accent: filterBar.theme.accent
            onClicked: filterBar.cycleModel()
        }

        Item { Layout.fillWidth: true }

        PlanetMarker {
            theme: filterBar.theme
            clock: filterBar.planetClock
        }
        Text {
            text: filterBar.pageId === "activity" ? "Local activity" : "Attributed events"
            color: "#bcbcc8"
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.DemiBold
        }
    }
}
