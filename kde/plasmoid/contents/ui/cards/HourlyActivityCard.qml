import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// Port of CodexV6HourlyActivityCard: tokens grouped into 2-hour buckets.
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

    readonly property var hourly: dataSource && dataSource.analytics ? dataSource.analytics.hourly : []

    readonly property var chartData: {
        const grouped = {};
        for (let i = 0; i < hourly.length; ++i) {
            const bucket = Math.floor(hourly[i].hour / 2);
            if (!grouped[bucket]) grouped[bucket] = { tokens: 0, turns: 0 };
            grouped[bucket].tokens += hourly[i].tokens;
            grouped[bucket].turns += hourly[i].eventCount;
        }
        const out = [];
        for (let bucket = 0; bucket < 12; ++bucket) {
            out.push({
                id: "hour-" + bucket,
                label: (bucket * 2 < 10 ? "0" : "") + (bucket * 2),
                value: grouped[bucket] ? grouped[bucket].tokens : 0,
                detail: grouped[bucket] ? grouped[bucket].turns + " turns" : "",
            });
        }
        return out;
    }

    implicitHeight: _column.implicitHeight

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 7

        ColumnChart {
            Layout.fillWidth: true
            theme: card.theme
            dataSource: card.chartData
            chartHeight: 48
            showsLabels: false
            sparkleIntensity: card.sparkleIntensity
            glowIntensity: card.glowIntensity
            animationsEnabled: card.animationsEnabled
            clock: card.clock
        }

        RowLayout {
            spacing: 6
            Layout.fillWidth: true
            Text {
                text: ""
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
            Text {
                text: "Recent activity by hour"
                color: "#e2e2e8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.DemiBold
                Layout.fillWidth: true
            }
            Text {
                text: card.hourly.length === 0 ? "No events" : (card.activityWindow === "today" ? "Today window" : card.activityWindow === "thirtyDays" ? "30 days window" : "7 days window")
                color: "#9d9dac"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
            }
        }
    }
}
