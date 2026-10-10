import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6SessionPulseCard: the active session, model/reasoning, and
// last-turn telemetry.
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

    readonly property var telemetry: dataSource ? dataSource.telemetry : null
    readonly property var session: dataSource && dataSource.snapshot && dataSource.snapshot.sessions
        ? (dataSource.snapshot.sessions.find(s => s.isActive) || dataSource.snapshot.sessions[0] || null)
        : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        ColumnLayout {
            visible: card.session !== null
            spacing: 7

            RowLayout {
                spacing: 7
                Layout.fillWidth: true
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: card.telemetry ? Theme.modelLabel(card.telemetry.currentModel, "Unknown") : "—"
                    label: "model"
                }
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: card.telemetry ? Theme.reasoningLabel(card.telemetry.currentReasoningEffort) : "—"
                    label: "reasoning"
                }
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: card.session ? Theme.relativeTime(card.session.modifiedAt, card.nowEpoch) : "—"
                    label: "last seen"
                }
            }

            RowLayout {
                spacing: 6
                Layout.fillWidth: true
                Rectangle {
                    width: 7; height: 7; radius: 4
                    Layout.alignment: Qt.AlignVCenter
                    color: card.session && card.session.isActive
                        ? Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                        : Theme.rgba([0.55, 0.57, 0.60], 1)
                }
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: card.session ? card.session.projectName : ""
                        color: "#e2e2e8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: card.session && card.session.title ? card.session.title : "Local Codex session"
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            RowLayout {
                spacing: 5
                Layout.fillWidth: true
                Text {
                    text: ""
                    color: Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                    font.pixelSize: 10
                    font.family: Theme.fontFamily(UIFont.configured)
                }
                Text {
                    text: card.telemetry && card.telemetry.latestDelta
                        ? "Last turn " + Theme.compactTokens(card.telemetry.latestDelta.totalTokens)
                        : "Waiting for the next local turn"
                    color: "#bcbcc8"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                Text {
                    text: {
                        const telemetry = card.telemetry;
                        if (!telemetry || telemetry.updatedAt === null || telemetry.updatedAt === undefined)
                            return "";
                        const age = Math.max(card.nowEpoch - telemetry.updatedAt, 0);
                        if (age < 15) return "Live · just now";
                        if (age < 120) return "Updated " + Math.round(age) + "s ago";
                        return "Stale · " + Theme.relativeTime(telemetry.updatedAt, card.nowEpoch);
                    }
                    color: "#9d9dac"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                    elide: Text.ElideRight
                }
            }
        }

        Text {
            visible: card.session === null
            text: " Session pulse appears after Codex writes a local session."
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
