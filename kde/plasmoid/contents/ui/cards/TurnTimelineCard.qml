import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6TurnTimelineCard: the five most recent attributed turns.
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

    readonly property var samples: {
        const all = dataSource && dataSource.telemetry && dataSource.telemetry.samples ? dataSource.telemetry.samples : [];
        return all.slice(Math.max(0, all.length - 5)).reverse();
    }

    implicitHeight: samples.length === 0 ? emptyLabel.implicitHeight : _column.implicitHeight

    Text {
        id: emptyLabel
        visible: card.samples.length === 0
        text: " Turn timeline appears after local token events are recorded."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.samples.length > 0
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 5

        Repeater {
            model: card.samples.length

            RowLayout {
                id: row
                required property int index
                readonly property var sample: card.samples[index]
                spacing: 7

                Rectangle {
                    width: 6; height: 6; radius: 3
                    Layout.alignment: Qt.AlignTop
                    Layout.topMargin: 5
                    color: Theme.rgba(card.theme.accent, 1)
                }
                ColumnLayout {
                    spacing: 1
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 5
                        Layout.fillWidth: true
                        Text {
                            text: Theme.modelLabel(row.sample.model, "Unknown")
                            color: "#d6d6de"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "· " + Theme.reasoningLabel(row.sample.reasoningEffort)
                            color: "#bcbcc8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                        }
                        Item { Layout.fillWidth: true }
                        Text {
                            text: Theme.compactTokens(row.sample.usage.totalTokens)
                            color: Theme.rgba(card.theme.accent, 1)
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            font.weight: Font.Bold
                        }
                    }
                    Text {
                        text: (row.sample.projectName || "Unknown project") + " · " + shortTime(row.sample.timestamp)
                        color: "#9d9dac"
                        font.pixelSize: 9
                        font.family: Theme.fontFamily(UIFont.configured)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }

    function shortTime(epoch) {
        const date = new Date(epoch * 1000);
        const h = date.getHours();
        const m = date.getMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }
}
