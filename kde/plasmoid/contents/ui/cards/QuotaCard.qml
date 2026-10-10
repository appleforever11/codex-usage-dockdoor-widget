import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6QuotaCard: freshness row, hero ring block with reset +
// trend, four metric tiles, and the account usage-limits list.
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
    property string ringStyle: "gradient"
    property int ringThickness: 7
    property bool ringSparkles: true

    readonly property var usage: dataSource ? dataSource.usage : null
    readonly property var analytics: dataSource ? dataSource.analytics : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        Row {
            spacing: 5
            Layout.fillWidth: true
            Rectangle {
                width: 6; height: 6; radius: 3
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.rgba(usage && usage.isStale ? Theme.dataColor(theme, 1) : Theme.dataColor(theme, 2), 1)
            }
            Text {
                text: usage ? usage.statusLabel : ""
                color: "#bcbcc8"
                font.pixelSize: 10
                font.family: Theme.fontFamily(UIFont.configured)
                elide: Text.ElideRight
            }
        }

        // Hero block: ring + titles on an accent wash. The content row is
        // pinned left/right/top only — anchoring it on all four sides while
        // the box height derives from the row's implicitHeight is a binding
        // cycle that freezes the box at its empty-data size and drops the
        // reset-credit chip below the bottom edge once usage arrives.
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: heroRow.height + 20
            radius: 14
            color: Theme.rgba(theme.accent, 0.065)
            border.width: 0.8
            border.color: Theme.rgba(theme.accent, 0.18)

            RowLayout {
                id: heroRow
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 10
                spacing: 12

                UsageRing {
                    width: 68
                    height: 68
                    lineWidth: Math.max(3, Math.min(14, card.ringThickness))
                    ringStyle: card.ringStyle
                    sparklesEnabled: card.ringSparkles
                    theme: card.theme
                    percentRemaining: card.usage ? card.usage.percentRemaining : 0
                    sparkleIntensity: card.sparkleIntensity
                    animationsEnabled: card.animationsEnabled
                    clock: card.clock
                }

                ColumnLayout {
                    spacing: 3
                    Layout.fillWidth: true

                    Text {
                        text: card.usage ? card.usage.primaryTitle : ""
                        color: "#f4f4f7"
                        font.pixelSize: 15
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: card.usage ? card.usage.primarySubtitle : ""
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                    Text {
                        text: card.usage ? Theme.resetSummary(card.usage.resetAt, card.nowEpoch) : ""
                        color: Theme.rgba(card.theme.accent, 1)
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                    }
                    TrendBadge {
                        visible: card.analytics && card.analytics.todayVsPreviousDay !== undefined && card.analytics.todayVsPreviousDay !== null
                        theme: card.theme
                        change: card.analytics ? (card.analytics.todayVsPreviousDay || 0) : 0
                    }
                    // Reset credit + plan chip, new in the KDE port.
                    Row {
                        visible: card.usage && card.usage.resetCreditTitle !== undefined && card.usage.resetCreditTitle !== null
                        spacing: 4
                        Rectangle {
                            radius: height / 2
                            height: 15
                            width: creditText.implicitWidth + 12
                            color: Theme.rgba(Theme.dataColor(card.theme, 2), 0.12)
                            border.width: 0.6
                            border.color: Theme.rgba(Theme.dataColor(card.theme, 2), 0.3)
                            Text {
                                id: creditText
                                anchors.centerIn: parent
                                text: " " + (card.usage ? card.usage.resetCreditTitle : "")
                                color: Theme.rgba(Theme.dataColor(card.theme, 2), 1)
                                font.pixelSize: 10
                                font.family: Theme.fontFamily(UIFont.configured)
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }
        }

        // Window / Today / Tasks / Chats metric row.
        RowLayout {
            spacing: 7
            Layout.fillWidth: true

            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                treatment: "soft"
                value: card.usage ? Theme.compactTokensPlain(card.usage.windowUsedTokens) : "—"
                label: "Window"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                treatment: "soft"
                value: card.usage ? Theme.compactTokensPlain(card.usage.todayUsedTokens) : "—"
                label: "Today"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                treatment: "soft"
                value: dataSource && dataSource.counts ? String(dataSource.counts.taskCount) : "0"
                label: "Tasks"
            }
            MetricTile {
                Layout.fillWidth: true
                theme: card.theme
                treatment: "soft"
                value: dataSource && dataSource.counts ? String(dataSource.counts.chatCount) : "0"
                label: "Chats"
            }
        }

        // Usage limits list.
        ColumnLayout {
            visible: card.usage && card.usage.metrics && card.usage.metrics.length > 0
            spacing: 9
            Text {
                text: Theme.iconGlyph("signal") + "  Usage limits"
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.DemiBold
            }
            Repeater {
                model: card.usage && card.usage.metrics ? card.usage.metrics : []
                RowLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.rgba(card.theme.accent, 1)
                        text: String(modelData.title).toLowerCase().indexOf("credit") >= 0
                            ? Theme.iconGlyph("money") : Theme.iconGlyph("gauge")
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                    }
                    Text {
                        text: parent.modelData.title
                        color: "#d6d6de"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                    Text {
                        text: parent.modelData.value
                        color: "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }
                }
            }
        }

        // RowLayout (not Row + width: parent.width): a wrapping Text sized
        // from its parent's width can go negative during layout negotiation
        // and spins the text engine at 100% CPU, freezing the popup.
        RowLayout {
            visible: card.usage && card.usage.creditsBalance !== undefined && card.usage.creditsBalance !== null
            Layout.fillWidth: true
            spacing: 5
            Text {
                text: ""
                color: Theme.rgba(card.theme.accent, 1)
                font.pixelSize: 10
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                Layout.fillWidth: true
                text: "Prepaid credits are reported separately from the weekly General allowance."
                color: "#bcbcc8"
                font.pixelSize: 10
                font.family: Theme.fontFamily(UIFont.configured)
                wrapMode: Text.WordWrap
            }
        }
    }
}
