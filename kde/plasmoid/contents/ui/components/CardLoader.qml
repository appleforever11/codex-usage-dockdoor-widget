import QtQuick

// Instantiates a card QML file by id and wires live bindings into it. Card
// ids are camelCase ("quota", "modelControls"); files are Capitalized with a
// "Card" suffix (QuotaCard.qml). Qt.resolvedUrl pins the path to this file's
// own location — a plain relative string would resolve against the
// instantiating context instead (plasmashell resolved it one level too high).
Loader {
    id: loader

    // Fill the host item's width; cards bind their own implicitHeight, so the
    // surrounding shell picks the height up from the loaded item. Without
    // this the card renders at its minimum content width, hugging one edge.
    anchors.left: parent.left
    anchors.right: parent.right

    property string cardId: ""
    property var dataSource: null
    property var theme: null
    property var clock: null
    property double sparkleIntensity: 1
    property double glowIntensity: 1
    property bool animationsEnabled: true
    property string activityWindow: "sevenDays"
    property string modelFilter: ""
    property string ringStyle: "gradient"
    property int ringThickness: 7
    property bool ringSparkles: true

    readonly property string cardSource: cardId === "" ? ""
        : Qt.resolvedUrl("../cards/" + cardId.charAt(0).toUpperCase() + cardId.slice(1) + "Card.qml")

    source: cardSource

    onLoaded: {
        if (!item)
            return;
        const required = ["dataSource", "theme", "clock", "sparkleIntensity", "glowIntensity", "animationsEnabled", "activityWindow", "modelFilter", "ringStyle", "ringThickness", "ringSparkles"];
        for (let i = 0; i < required.length; ++i) {
            const name = required[i];
            if (name in item) {
                item[name] = Qt.binding(() => loader[name]);
            }
        }
    }
}
