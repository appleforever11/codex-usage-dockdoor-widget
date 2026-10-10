import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami
import "components"

// Codex Usage — KDE Plasma port of the DockDoor Pro widget.
// QML renders the themed dashboard; all logic (account limits via the Codex
// app-server, session telemetry, analytics, config.toml defaults) lives in
// the Rust helper this plasmoid talks to over localhost HTTP.
PlasmoidItem {
    id: root

    readonly property bool animationsEnabled: Plasmoid.configuration.animationsEnabled

    // Pause the shared animation clock when the popup is closed so the panel
    // burns no CPU on atmosphere painting (the compact ring keeps animating).
    readonly property bool popupActive: root.expanded || root.compactRepresentationItem === null

    // Live Plasma scheme colors for the "Plasma style" theme mode. Kirigami
    // follows the system color scheme, so this tracks the user's accent.
    readonly property var plasmaPalette: ({
        accent: [Kirigami.Theme.highlightColor.r,
                 Kirigami.Theme.highlightColor.g,
                 Kirigami.Theme.highlightColor.b],
    })

    compactRepresentation: CompactWidget {
        id: compactWidget
        plasmoidItem: root
        dataSource: codexData
        clock: animationClock
        configuration: Plasmoid.configuration
        plasmaPalette: root.plasmaPalette
        themeName: Plasmoid.configuration.modelTheme
        panelStyle: Plasmoid.configuration.compactStyle
        panelLength: Plasmoid.configuration.panelWidgetLength
        showCodexLabel: Plasmoid.configuration.panelShowCodexLabel
        sparkleIntensity: Plasmoid.configuration.sparkleIntensity
        animationsEnabled: root.animationsEnabled
    }

    fullRepresentation: Dashboard {
        id: dashboardView
        dataSource: codexData
        clock: animationClock
        configuration: Plasmoid.configuration
        plasmaPalette: root.plasmaPalette
        popupVisible: root.expanded

        Layout.preferredWidth: 366
        Layout.preferredHeight: 660
        Layout.minimumWidth: 320
        Layout.minimumHeight: 420
    }

    toolTipMainText: "Codex Usage"
    toolTipSubText: {
        const usage = codexData.usage;
        if (!usage)
            return "Waiting for the helper…";
        return usage.primaryTitle + " · " + usage.resetSummary;
    }
    Plasmoid.status: codexData.connected
        ? PlasmaCore.Types.ActiveStatus
        : PlasmaCore.Types.PassiveStatus

    CodexData {
        id: codexData
        helperPort: Plasmoid.configuration.helperPort
        pollIntervalMs: Plasmoid.configuration.pollIntervalMs
    }

    AnimationClock {
        id: animationClock
        animationsEnabled: root.animationsEnabled
        visibleToUser: true
    }

    // Mirror the dataSource-affecting settings into the helper whenever they change,
    // then pick up the rebuilt snapshot.
    function pushHelperSettings() {
        codexData.pushSettings({
            helperPort: Plasmoid.configuration.helperPort,
            helperRefreshSeconds: Plasmoid.configuration.helperRefreshSeconds,
            sessionsFolder: Plasmoid.configuration.sessionsFolder,
            usageStatePath: Plasmoid.configuration.usageStatePath,
            recentSessionCount: Plasmoid.configuration.recentSessionCount,
            usageBudgetMillions: Plasmoid.configuration.usageBudgetMillions,
            usageWindowHours: Plasmoid.configuration.usageWindowHours,
            dailyGoalMillions: Plasmoid.configuration.dailyGoalMillions,
            chatViewerCommand: Plasmoid.configuration.chatViewerCommand,
        });
    }

    // Push the chosen UI font into the singleton every Text binds to, so a
    // settings change re-flows the whole dashboard without a restart.
    function applyUiFont() {
        const value = String(Plasmoid.configuration.uiFontFamily || "").trim();
        UIFont.configured = (value.length > 0 && value !== "Auto") ? value : "";
    }

    Component.onCompleted: {
        applyUiFont();
        pushHelperSettings();
    }

    // Re-push when any mirrored key changes (config dialog Apply/Discard).
    Connections {
        target: Plasmoid.configuration
        function onValuesChanged() {
            codexData.helperPort = Plasmoid.configuration.helperPort;
            codexData.pollIntervalMs = Plasmoid.configuration.pollIntervalMs;
            root.applyUiFont();
            root.pushHelperSettings();
        }
    }
}
