import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6EfficiencyCard: cache share, tokens/turn, output totals.
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
    readonly property var usage: {
        if (!telemetry)
            return null;
        const today = telemetry.todayUsage;
        if (today && today.totalTokens > 0)
            return today;
        return telemetry.observedUsage;
    }
    readonly property bool hasUsage: usage && (usage.totalTokens > 0 || usage.cachedInputTokens > 0 || usage.cacheWriteInputTokens > 0)
    readonly property var cacheShare: usage && usage.inputTokens > 0
        ? Math.min(Math.max(usage.cachedInputTokens / usage.inputTokens, 0), 1) : null
    readonly property var tokensPerTurn: telemetry && telemetry.eventCount > 0 && usage
        ? usage.totalTokens / telemetry.eventCount : null

    implicitHeight: hasUsage ? _column.implicitHeight : emptyLabel.implicitHeight

    Text {
        id: emptyLabel
        visible: !card.hasUsage
        text: " Efficiency appears after local token events are attributed."
        color: "#bcbcc8"
        font.pixelSize: 11
        font.family: Theme.fontFamily(UIFont.configured)
        wrapMode: Text.WordWrap
        width: parent.width
    }

    ColumnLayout {
        id: _column
        visible: card.hasUsage
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        RowLayout {
            spacing: 8
            Layout.fillWidth: true
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.cacheShare === null ? "—" : Theme.percentText(card.cacheShare)
                label: "cache share"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.tokensPerTurn === null ? "—" : Theme.compactTokens(card.tokensPerTurn)
                label: "tokens / turn"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                value: card.usage ? Theme.compactTokens(card.usage.outputTokens) : "—"
                label: "output"
            }
        }

        LabeledBar {
            Layout.fillWidth: true
            theme: card.theme
            labelText: "Cached input"
            value: card.cacheShare === null ? 0 : card.cacheShare
            valueLabel: card.cacheShare === null ? "—" : Theme.percentText(card.cacheShare)
            tint: card.theme.accent
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        Text {
            text: card.usage
                ? "Input " + Theme.compactTokens(card.usage.inputTokens)
                  + " · cached " + Theme.compactTokens(card.usage.cachedInputTokens)
                  + " · reasoning " + Theme.compactTokens(card.usage.reasoningOutputTokens)
                : ""
            color: "#bcbcc8"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            elide: Text.ElideRight
            Layout.fillWidth: true
        }
    }
}
