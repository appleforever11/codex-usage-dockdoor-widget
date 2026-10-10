import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ModelMixCard: per model·reasoning token share rows.
Item {
    id: card

    property var dataSource: null
    property var theme: Theme.theme("Astra")
    property var clock: null
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property string activityWindow: "sevenDays"
    property string modelFilter: ""

    readonly property var models: {
        const all = dataSource && dataSource.analytics ? dataSource.analytics.models : [];
        if (!modelFilter)
            return all;
        const id = modelFilter;
        return all.filter(m => (m.model + "|" + m.reasoningEffort) === id);
    }
    readonly property double maxTokens: {
        let max = 0;
        for (let i = 0; i < models.length; ++i)
            max = Math.max(max, models[i].tokens);
        return Math.max(max, 1);
    }

    implicitHeight: models.length === 0 ? emptyLabel.implicitHeight : _column.implicitHeight

    Text {
        id: emptyLabel
        visible: card.models.length === 0
        text: " Model mix appears after token events."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.models.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 6

        Repeater {
            model: Math.min(card.models.length, 4)

            ColumnLayout {
                id: row
                required property int index
                readonly property var model: card.models[row.index]
                spacing: 3

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text {
                        text: Theme.modelLabel(row.model.model, "Unknown") + " · " + Theme.reasoningLabel(row.model.reasoningEffort)
                        color: "#d6d6de"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: Theme.compactTokens(row.model.tokens)
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }
                }
                ThemeProgressBar {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: row.model.tokens / card.maxTokens
                    barHeight: 4
                    sparkleIntensity: card.sparkleIntensity
                    glowIntensity: card.glowIntensity
                    animationsEnabled: card.animationsEnabled
                    clock: card.clock
                }
            }
        }
    }
}
