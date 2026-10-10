import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6ContextRunwayCard: tokens left in the context window and the
// burn-based runway estimate.
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
    readonly property var analytics: dataSource ? dataSource.analytics : null
    readonly property var remainingTokens: {
        if (!card.telemetry || !card.telemetry.latestContextUsage || !(card.telemetry.latestContextWindow > 0))
            return null;
        return Math.max(0, card.telemetry.latestContextWindow - card.telemetry.latestContextUsage.totalTokens);
    }
    readonly property var runwayMinutes: {
        if (card.remainingTokens === null || !card.analytics || !(card.analytics.burnPerMinute > 0))
            return null;
        return card.remainingTokens / card.analytics.burnPerMinute;
    }
    readonly property var contextPercent: card.analytics && card.analytics.contextPercent !== null
        ? card.analytics.contextPercent : null

    readonly property bool available: remainingTokens !== null

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        ColumnLayout {
            visible: card.available
            spacing: 7

            RowLayout {
                spacing: 8
                Layout.fillWidth: true
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: Theme.compactTokens(card.remainingTokens)
                    label: "tokens left"
                }
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: card.runwayMinutes === null ? "—"
                        : (card.runwayMinutes < 60
                            ? Math.round(card.runwayMinutes) + "m"
                            : Math.round(card.runwayMinutes / 60) + "h")
                    label: "at current burn"
                }
                MetricTile {
                    Layout.fillWidth: true
                    theme: card.theme
                    value: card.contextPercent === null ? "—" : Theme.percentText(card.contextPercent)
                    label: "in use"
                }
            }

            LabeledBar {
                Layout.fillWidth: true
                theme: card.theme
                labelText: "Context consumed"
                value: card.contextPercent === null ? 0 : card.contextPercent
                valueLabel: card.contextPercent === null ? "—" : Theme.percentText(card.contextPercent)
                tint: card.theme.accent
                sparkleIntensity: card.sparkleIntensity
                glowIntensity: card.glowIntensity
                animationsEnabled: card.animationsEnabled
                clock: card.clock
            }

            Text {
                text: card.analytics && card.analytics.peakContextPercent !== null && card.analytics.peakContextPercent !== undefined
                    ? "Peak observed " + Math.round(card.analytics.peakContextPercent * 100) + "% · runway is an estimate from local burn."
                    : "Runway is an estimate from local burn."
                color: "#9d9dac"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }

        Text {
            visible: !card.available
            text: " Context runway appears when a model context window is reported locally."
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
