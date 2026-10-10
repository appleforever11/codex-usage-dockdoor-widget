import QtQuick
import QtQuick.Layouts
import "../lib/Theme.js" as Theme
import "../components"

// New-chat defaults, driven by the account's live model catalog: curated
// family identities (planet buttons), variant chips within a family, the
// model's own reasoning-effort ladder, and the "/fast" speed-tier toggle.
// Selections write ~/.codex/config.toml through the helper.
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

    readonly property var settings: dataSource ? dataSource.modelSettings : null
    property bool busy: false
    property string errorText: ""

    // --- live catalog -------------------------------------------------------
    readonly property var catalog: dataSource && dataSource.availableModels
        ? dataSource.availableModels : []
    readonly property var currentModel: {
        for (let i = 0; i < catalog.length; ++i)
            if (catalog[i].id === (settings ? settings.model : ""))
                return catalog[i];
        return null;
    }
    readonly property string selectedFamily: settings ? Theme.modelFamily(settings.model) : ""

    // Families in catalog order (the app-server lists the default first),
    // each with its variants.
    readonly property var families: {
        const groups = [];
        const byFamily = {};
        for (let i = 0; i < catalog.length; ++i) {
            const model = catalog[i];
            if (!byFamily[model.family]) {
                byFamily[model.family] = [];
                groups.push(model.family);
            }
            byFamily[model.family].push(model);
        }
        return groups.map(family => ({
            family: family,
            label: Theme.familyDisplay(family),
            identity: Theme.familyIdentity(family),
            variants: byFamily[family],
        }));
    }

    // The selected family's entry (falls back to the family containing the
    // current model so the chips reflect reality even after external edits).
    readonly property var familyEntry: {
        for (let i = 0; i < families.length; ++i)
            if (families[i].family === selectedFamily)
                return families[i];
        return null;
    }
    readonly property var variants: familyEntry ? familyEntry.variants : []

    // The effort ladder for the current model (fallback: the full ladder).
    readonly property var efforts: currentModel && currentModel.efforts && currentModel.efforts.length > 0
        ? currentModel.efforts : ["low", "medium", "high", "xhigh", "max", "ultra"]

    // Severity-tinted pill gradients, cool (low) → hot (ultra).
    readonly property var effortColors: ({
        low: [[0.12, 0.62, 1.00], [0.20, 0.82, 0.80]],
        medium: [[0.58, 0.44, 1.00], [0.78, 0.38, 0.96]],
        high: [[0.80, 0.45, 1.00], [0.95, 0.45, 0.80]],
        xhigh: [[0.95, 0.45, 0.85], [0.98, 0.55, 0.60]],
        max: [[1.00, 0.46, 0.24], [0.92, 0.18, 0.56]],
        ultra: [[1.00, 0.66, 0.12], [0.96, 0.20, 0.30]],
    })

    // Variant chip label: the version distinguishing it inside the family
    // ("gpt-6.1-sol" → "6.1"), falling back to the full short label.
    function variantLabel(model) {
        const label = Theme.modelLabel(model.id);
        const familyName = Theme.familyDisplay(Theme.modelFamily(model.id));
        if (label.indexOf(familyName + "-") === 0)
            return label.slice(familyName.length + 1);
        return label;
    }

    implicitHeight: _column.implicitHeight

    function writeDefaults(model, reasoning, fast) {
        busy = true;
        errorText = "";
        dataSource.setModel(model, reasoning, fast, function(ok, error) {
            card.busy = false;
            if (!ok)
                card.errorText = "Couldn't save defaults: " + error;
        });
    }

    function applyModel(model) {
        if (!dataSource || busy)
            return;
        const reasoning = settings ? settings.reasoningEffort : "medium";
        // Keep the current effort when the target model supports it;
        // otherwise land on the model's own default.
        const supported = model.efforts && model.efforts.length > 0
            ? model.efforts : efforts;
        const effort = supported.indexOf(reasoning) >= 0 ? reasoning : model.defaultEffort || supported[0];
        writeDefaults(model.id, effort, settings ? settings.fast : false);
    }

    function applyReasoning(value) {
        if (!dataSource || busy || !settings)
            return;
        writeDefaults(settings.model, value, settings.fast);
    }

    function toggleFast() {
        if (!dataSource || busy || !settings)
            return;
        writeDefaults(settings.model, settings.reasoningEffort, !settings.fast);
    }

    ColumnLayout {
        id: _column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 10

        RowLayout {
            spacing: 4
            Layout.fillWidth: true
            Item { Layout.fillWidth: true }
            Text {
                text: card.settings
                    ? card.settings.shortModelName + " · " + card.settings.reasoningLabel
                      + (card.settings.fast ? " · Fast" : "")
                    : ""
                color: "#bcbcc8"
                font.pixelSize: 11
                font.family: Theme.fontFamily(UIFont.configured)
                font.weight: Font.Bold
            }
        }

        // --- family identities ------------------------------------------------
        Text {
            visible: card.families.length === 0
            Layout.fillWidth: true
            text: "Model catalog unavailable — waiting for the helper's next refresh."
            color: "#9d9dac"
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
        }

        Flow {
            visible: card.families.length > 0
            Layout.fillWidth: true
            spacing: 6

            Repeater {
                model: card.families
                IdentityButton {
                    required property var modelData
                    // Four families share one row; more wrap two-per-row.
                    readonly property real cellWidth: card.families.length <= 4
                        ? (card.width - 6 * (card.families.length - 1)) / card.families.length
                        : (card.width - 6) / 2
                    width: cellWidth
                    identity: modelData.identity
                    isSelected: card.selectedFamily === modelData.family
                    buttonHeight: 48
                    compactMode: true
                    sparkleIntensity: card.sparkleIntensity
                    glowIntensity: card.glowIntensity
                    animationsEnabled: card.animationsEnabled
                    clock: card.clock
                    opacity: card.busy ? 0.7 : 1
                    onActivated: {
                        // Pick the family's newest variant (the catalog lists
                        // the leading one first).
                        const target = modelData.variants[0];
                        if (target)
                            card.applyModel(target);
                    }
                }
            }
        }

        // --- variants within the family ----------------------------------------
        RowLayout {
            visible: card.variants.length > 1
            Layout.fillWidth: true
            spacing: 5

            Repeater {
                model: card.variants
                Rectangle {
                    id: variantChip
                    required property var modelData
                    readonly property bool isSelected: card.settings
                        && card.settings.model === modelData.id
                    Layout.fillWidth: true
                    height: 24
                    radius: 8
                    color: isSelected
                        ? Theme.rgba(card.theme.accent, 0.30)
                        : Theme.rgba([1, 1, 1], 0.05)
                    border.width: isSelected ? 1.1 : 0.8
                    border.color: isSelected
                        ? Theme.rgba(card.theme.accent, 0.75)
                        : Theme.rgba([1, 1, 1], 0.14)

                    Text {
                        anchors.centerIn: parent
                        text: card.variantLabel(variantChip.modelData)
                        color: variantChip.isSelected ? "#f4f4f7" : "#bcbcc8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.applyModel(variantChip.modelData)
                    }
                }
            }
        }

        // --- reasoning ladder ----------------------------------------------------
        Text {
            text: "REASONING"
            color: "#bcbcc8"
            font.pixelSize: 9
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            columnSpacing: 5
            rowSpacing: 5

            Repeater {
                model: card.efforts
                Rectangle {
                    id: pill
                    required property string modelData
                    readonly property bool isSelected: card.settings
                        && card.settings.reasoningEffort === pill.modelData
                    readonly property var colors: {
                        const pair = card.effortColors[pill.modelData];
                        return pair || card.effortColors.medium;
                    }
                    Layout.fillWidth: true
                    height: 26
                    radius: 10
                    gradient: Gradient {
                        GradientStop { position: 0; color: Theme.rgba(pill.colors[0], pill.isSelected ? 0.55 : (pillHover.hovered ? 0.30 : 0.18)) }
                        GradientStop { position: 1; color: Theme.rgba(pill.colors[1], pill.isSelected ? 0.55 : (pillHover.hovered ? 0.30 : 0.18)) }
                    }
                    border.width: pill.isSelected ? 1.3 : 0.8
                    border.color: pill.isSelected
                        ? Theme.rgba([1, 1, 1], 0.85)
                        : Theme.rgba([1, 1, 1], 0.20)

                    Text {
                        anchors.centerIn: parent
                        text: Theme.reasoningLabel(pill.modelData)
                        color: Theme.rgba([1, 1, 1], pill.isSelected ? 1 : 0.88)
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }

                    MouseArea {
                        id: pillHover
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: card.applyReasoning(pill.modelData)
                    }
                }
            }
        }

        // --- fast speed tier -------------------------------------------------------
        RowLayout {
            visible: !card.currentModel || card.currentModel.supportsFast
            Layout.fillWidth: true
            spacing: 8

            Rectangle {
                width: 30
                height: 17
                radius: 9
                color: card.settings && card.settings.fast
                    ? Theme.rgba(card.theme.accent, 0.85)
                    : Theme.rgba([1, 1, 1], 0.14)
                Rectangle {
                    width: 13
                    height: 13
                    radius: 7
                    anchors.verticalCenter: parent.verticalCenter
                    x: card.settings && card.settings.fast ? parent.width - 15 : 2
                    color: "white"
                    Behavior on x { NumberAnimation { duration: 120 } }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.toggleFast()
                }
            }
            ColumnLayout {
                spacing: 1
                Layout.fillWidth: true
                Text {
                    text: "Fast mode"
                    color: "#d6d6de"
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "2× speed, increased usage (codex /fast)"
                    color: "#9d9dac"
                    font.pixelSize: 9
                    font.family: Theme.fontFamily(UIFont.configured)
                }
            }
        }

        Text {
            visible: card.errorText !== ""
            text: card.errorText
            color: "#ff7a70"
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Text {
            text: "Applies to new Codex work; running chats keep their model."
            color: "#9d9dac"
            font.pixelSize: 10
            font.family: Theme.fontFamily(UIFont.configured)
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
}
