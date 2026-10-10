import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "lib/Theme.js" as Theme
import "components"

// Port of CodexV6DashboardView: themed background, header with actions, page
// tabs, stale-dataSource notice, swipeable card pages, arrangement mode, and footer
// navigation with page dots.
Rectangle {
    id: dashboard

    property var dataSource: null
    property var clock: null
    property var configuration: null        // Plasmoid.configuration
    property var plasmaPalette: null        // live Plasma scheme colors ({accent})
    property bool popupVisible: true

    readonly property string currentPage: currentPageId
    property string currentPageId: "overview"
    property bool isEditing: false
    property string activityWindow: "sevenDays"
    property string modelFilter: ""
    property bool isRefreshing: false
    property bool appearanceOpen: false
    property var activeFlickable: null      // the visible page's scroller

    readonly property var pageThemeMap: ({
        overview: configuration ? configuration.pageThemeOverview : "Astra",
        activity: configuration ? configuration.pageThemeActivity : "Luna",
        models: configuration ? configuration.pageThemeModels : "Terra",
        health: configuration ? configuration.pageThemeHealth : "Sol",
    })
    readonly property var theme: Theme.resolveTheme(configuration, plasmaPalette, pageThemeMap[currentPage] || "Astra")
    readonly property double cardSpacing: configuration
        ? ({ compact: 6, standard: 9, spacious: 13 })[configuration.cardDensity] || 9 : 9
    readonly property double cardPadding: configuration
        ? ({ compact: 8, standard: 11, spacious: 14 })[configuration.cardDensity] || 11 : 11

    // Persisted layout: {"overview":[...], ...} in Plasmoid.configuration.cardLayout.
    property var cardLayout: ({})
    Component.onCompleted: {
        cardLayout = Theme.parseLayout(configuration ? configuration.cardLayout : "")
        if (popupVisible)
            forceActiveFocus();
    }

    readonly property var usage: dataSource ? dataSource.usage : null
    readonly property double nowEpoch: dataSource ? dataSource.nowEpoch : 0

    radius: 18
    implicitWidth: 350
    implicitHeight: 640
    color: "transparent"

    onCurrentPageIdChanged: {
        // Edit-mode target pages keep their own theme; nothing else to do.
    }

    // Keyboard focus follows the popup; the panel grabs it back on close.
    onPopupVisibleChanged: {
        if (popupVisible)
            forceActiveFocus();
        else if (activeFocus)
            focus = false;
    }

    // Keyboard shortcuts (the footer documents the page keys):
    //   ←/→ or 1–4   switch pages        R   refresh
    //   ↑/↓          scroll the page     A   appearance popover
    //   Esc          close the popover   E   arrange cards
    focus: true
    Keys.onLeftPressed: event => {
        if (appearanceOpen) { appearanceOpen = false; return; }
        navigatePage(-1);
    }
    Keys.onRightPressed: event => {
        if (appearanceOpen) { appearanceOpen = false; return; }
        navigatePage(1);
    }
    Keys.onUpPressed: event => scrollActivePage(-72)
    Keys.onDownPressed: event => scrollActivePage(72)
    Keys.onPressed: event => {
        if (appearanceOpen) {
            if (event.key === Qt.Key_Escape) {
                appearanceOpen = false;
                event.accepted = true;
            }
            return;
        }
        switch (event.key) {
        case Qt.Key_1: currentPageId = "overview"; event.accepted = true; break;
        case Qt.Key_2: currentPageId = "activity"; event.accepted = true; break;
        case Qt.Key_3: currentPageId = "models"; event.accepted = true; break;
        case Qt.Key_4: currentPageId = "health"; event.accepted = true; break;
        case Qt.Key_R: refresh(); event.accepted = true; break;
        case Qt.Key_A: appearanceOpen = true; event.accepted = true; break;
        case Qt.Key_E: isEditing = !isEditing; event.accepted = true; break;
        }
    }

    function scrollActivePage(delta) {
        if (!activeFlickable)
            return;
        const flick = activeFlickable;
        const target = Math.max(0, Math.min(flick.contentHeight - flick.height,
                                            flick.contentY + delta));
        scrollAnimation.to = target;
        if (scrollAnimation.running)
            scrollAnimation.stop();
        scrollAnimation.to = target;
        scrollAnimation.start();
    }
    SmoothedAnimation {
        id: scrollAnimation
        target: dashboard.activeFlickable
        property: "contentY"
        duration: 140
        velocity: -1
        maximumEasingTime: 140
    }

    function moveCard(cardId, targetPage, beforeCard) {
        const next = Theme.normalizedLayout(cardLayout);
        for (let p = 0; p < Theme.PAGES.length; ++p) {
            const page = Theme.PAGES[p].id;
            next[page] = (next[page] || []).filter(c => c !== cardId);
        }
        const destination = next[targetPage] || [];
        const index = beforeCard ? destination.indexOf(beforeCard) : destination.length;
        destination.splice(index < 0 ? destination.length : index, 0, cardId);
        next[targetPage] = destination;
        cardLayout = next;
        if (configuration)
            configuration.cardLayout = JSON.stringify(next);
        currentPageId = targetPage;
    }

    function moveWithinPage(pageId, cardId, offset) {
        const next = Theme.normalizedLayout(cardLayout);
        const cards = next[pageId] || [];
        const index = cards.indexOf(cardId);
        const target = index + offset;
        if (index < 0 || target < 0 || target >= cards.length)
            return;
        cards.splice(index, 1);
        cards.splice(target, 0, cardId);
        next[pageId] = cards;
        cardLayout = next;
        if (configuration)
            configuration.cardLayout = JSON.stringify(next);
    }

    function navigatePage(offset) {
        if (isEditing)
            return;
        const pages = Theme.PAGES;
        let index = 0;
        for (let i = 0; i < pages.length; ++i)
            if (pages[i].id === currentPageId)
                index = i;
        const next = (index + offset + pages.length) % pages.length;
        currentPageId = pages[next].id;
    }

    function refresh() {
        if (isRefreshing || !dataSource)
            return;
        isRefreshing = true;
        dataSource.refreshNow();
        // Safety valve: release the spinner even if no fresh snapshot lands.
        refreshTimer.restart();
    }
    property Timer refreshTimer: Timer {
        interval: 35000
        onTriggered: dashboard.isRefreshing = false
    }

    Connections {
        target: dashboard.dataSource
        function onFreshSnapshotArrived() { dashboard.isRefreshing = false }
    }

    ThemeBackground {
        id: background
        anchors.fill: parent
        theme: dashboard.theme
        backgroundOpacity: dashboard.configuration ? dashboard.configuration.backgroundOpacity : 0.75
        frostedGlass: dashboard.configuration ? dashboard.configuration.frostedGlass : true
        sparkleIntensity: dashboard.configuration ? dashboard.configuration.sparkleIntensity : 1
        glowIntensity: dashboard.configuration ? dashboard.configuration.glowIntensity : 1
        animationsEnabled: dashboard.configuration
            ? dashboard.configuration.animationsEnabled && dashboard.popupVisible : true
        clock: dashboard.clock
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        anchors.topMargin: 12
        anchors.bottomMargin: 7
        spacing: 0

        // --- Header --------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            Layout.rightMargin: 3
            Layout.bottomMargin: 12
            spacing: 7

            ColumnLayout {
                spacing: 3
                Text {
                    text: "Codex Usage"
                    color: "#f4f4f7"
                    font.pixelSize: 14
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.Bold
                }
                RowLayout {
                    visible: dashboard.configuration && dashboard.configuration.showDataStatus
                    spacing: 4
                    Rectangle {
                        width: 5; height: 5; radius: 2.5
                        Layout.alignment: Qt.AlignVCenter
                        color: Theme.rgba(statusBadge.tint, 1)
                    }
                    Text {
                        id: statusBadge
                        readonly property var tint: {
                            if (!dashboard.usage) return [0.55, 0.57, 0.60];
                            if (dashboard.usage.source === "Loading") return [0.55, 0.57, 0.60];
                            if (dashboard.usage.isStale || dashboard.usage.source === "No account snapshot")
                                return Theme.dataColor(dashboard.theme, 1);
                            return Theme.dataColor(dashboard.theme, 2);
                        }
                        text: {
                            if (!dashboard.usage || dashboard.usage.source === "Loading") return "Loading";
                            if (dashboard.usage.source === "No account snapshot") return "Waiting";
                            return dashboard.usage.isStale ? "Stale" : "Live";
                        }
                        color: Theme.rgba(tint, 1)
                        font.pixelSize: 10
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.DemiBold
                    }
                }
            }

            Item { Layout.fillWidth: true }

            HeaderButton {
                iconGlyph: ""
                spinning: dashboard.isRefreshing
                tint: dashboard.theme.accent
                tooltip: "Refresh usage"
                onClicked: dashboard.refresh()
            }
            HeaderButton {
                iconGlyph: ""
                tint: dashboard.theme.accent
                highlighted: true
                tooltip: "Choose the page theme"
                onClicked: dashboard.appearanceOpen = !dashboard.appearanceOpen
            }
            HeaderButton {
                iconGlyph: dashboard.isEditing ? "" : ""
                tint: dashboard.isEditing ? dashboard.theme.accent : null
                tooltip: dashboard.isEditing ? "Finish arranging cards" : "Arrange cards"
                onClicked: dashboard.isEditing = !dashboard.isEditing
            }
        }

        // --- Page tabs -----------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 7
            spacing: 4

            Repeater {
                model: Theme.PAGES
                Rectangle {
                    id: tab
                    required property var modelData
                    readonly property bool active: dashboard.currentPageId === tab.modelData.id
                    Layout.fillWidth: true
                    height: 26
                    radius: 8
                    color: active
                        ? Theme.rgba(dashboard.theme.accent, 0.18)
                        : Theme.rgba([1, 1, 1], 0.045)

                    Row {
                        anchors.centerIn: parent
                        spacing: 4
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: Theme.iconGlyph(tab.modelData.icon)
                            color: tab.active ? "#f4f4f7" : "#bcbcc8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: tab.modelData.title
                            color: tab.active ? "#f4f4f7" : "#bcbcc8"
                            font.pixelSize: 11
                            font.family: Theme.fontFamily(UIFont.configured)
                            font.weight: tab.active ? Font.Bold : Font.DemiBold
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dashboard.currentPageId = tab.modelData.id
                    }
                }
            }
        }

        // --- Stale-dataSource notice ---------------------------------------------
        Rectangle {
            visible: dashboard.usage
                && (dashboard.usage.source === "No account snapshot" || dashboard.usage.isStale || !dashboard.dataSource.connected)
            Layout.fillWidth: true
            Layout.bottomMargin: 7
            height: _notice.implicitHeight + 14
            radius: 10
            color: Theme.rgba(Theme.dataColor(dashboard.theme, 1), 0.10)
            border.width: 0.7
            border.color: Theme.rgba(Theme.dataColor(dashboard.theme, 1), 0.22)

            RowLayout {
                id: _notice
                anchors.fill: parent
                anchors.margins: 8
                spacing: 7

                Text {
                    text: !dashboard.dataSource.connected ? "" : (dashboard.usage.source === "No account snapshot" ? "" : "")
                    color: Theme.rgba(Theme.dataColor(dashboard.theme, 1), 1)
                    font.pixelSize: 11
                    font.family: Theme.fontFamily(UIFont.configured)
                }
                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    Text {
                        text: !dashboard.dataSource.connected
                            ? "Helper unreachable"
                            : (dashboard.usage.source === "No account snapshot" ? "Account dataSource unavailable" : "Showing stale account dataSource")
                        color: "#e2e2e8"
                        font.pixelSize: 11
                        font.family: Theme.fontFamily(UIFont.configured)
                        font.weight: Font.Bold
                    }
                    Text {
                        text: !dashboard.dataSource.connected
                            ? (dashboard.dataSource.statusMessage || "Showing the last snapshot")
                            : (dashboard.usage.warning || dashboard.usage.statusLabel)
                        color: "#bcbcc8"
                        font.pixelSize: 10
                        font.family: Theme.fontFamily(UIFont.configured)
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // --- Filter bar (activity / models) ---------------------------------
        FilterBar {
            visible: dashboard.currentPageId === "activity" || dashboard.currentPageId === "models"
            Layout.fillWidth: true
            Layout.bottomMargin: dashboard.cardSpacing
            theme: dashboard.theme
            pageId: dashboard.currentPageId
            activityWindow: dashboard.activityWindow
            modelFilter: dashboard.modelFilter
            models: dashboard.dataSource && dashboard.dataSource.analytics ? dashboard.dataSource.analytics.models : []
            planetClock: dashboard.clock
            onActivityWindowSelected: value => dashboard.activityWindow = value
            onModelFilterSelected: value => dashboard.modelFilter = value
        }

        // --- Pages -----------------------------------------------------------
        Item {
            id: pageContainer
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Repeater {
                model: Theme.PAGES

                Item {
                    id: pageHolder
                    required property var modelData
                    readonly property bool active: dashboard.currentPageId === pageHolder.modelData.id
                    anchors.fill: parent
                    opacity: active ? 1 : 0
                    // Only the active page is ever interactive/visible —
                    // stacking every page in edit mode put four pages of
                    // cards on top of each other, so reorder clicks landed
                    // on the wrong page's buttons.
                    visible: opacity > 0
                    onActiveChanged: if (active) dashboard.activeFlickable = scroll

                    Behavior on opacity {
                        enabled: dashboard.configuration ? dashboard.configuration.animationsEnabled : true
                        NumberAnimation { duration: 180; easing.type: Easing.InOutQuad }
                    }

                    // Plain Flickable (not ScrollView): no visible scrollbar,
                    // native wheel scrolling, and full control of bounds.
                    Flickable {
                        id: scroll
                        anchors.fill: parent
                        clip: true
                        contentWidth: width
                        contentHeight: pageColumn.implicitHeight + 4
                        boundsBehavior: Flickable.StopAtBounds
                        maximumFlickVelocity: 2200

                        ColumnLayout {
                            id: pageColumn
                            width: scroll.width
                            spacing: dashboard.cardSpacing

                            Text {
                                visible: dashboard.isEditing
                                text: " Use the buttons on each card to move or reorder it"
                                color: Theme.rgba(dashboard.theme.accent, 1)
                                font.pixelSize: 11
                                font.family: Theme.fontFamily(UIFont.configured)
                                font.weight: Font.DemiBold
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                            }

                            Repeater {
                                model: {
                                    const layout = Theme.normalizedLayout(dashboard.cardLayout);
                                    return layout[pageHolder.modelData.id] || [];
                                }

                                CardShell {
                                    id: shell
                                    required property string modelData

                                    Layout.fillWidth: true
                                    cardId: shell.modelData
                                    theme: dashboard.theme
                                    isEditing: dashboard.isEditing
                                    isHero: shell.modelData === "quota"
                                    highContrast: dashboard.configuration ? dashboard.configuration.highContrast : false
                                    cardPadding: dashboard.cardPadding
                                    glowIntensity: dashboard.configuration ? dashboard.configuration.glowIntensity : 1
                                    animationsEnabled: dashboard.configuration ? dashboard.configuration.animationsEnabled : true
                                    clock: dashboard.clock
                                    detailText: (Theme.CARDS[shell.modelData] || {}).title || ""

                                    // Edit-mode controls: up / down / move-to-page.
                                    RowLayout {
                                        parent: shell
                                        anchors.top: parent.top
                                        anchors.right: parent.right
                                        anchors.margins: 6
                                        spacing: 2
                                        visible: dashboard.isEditing

                                        EditButton {
                                            glyph: "↑"
                                            tint: dashboard.theme.accent
                                            onClicked: dashboard.moveWithinPage(pageHolder.modelData.id, shell.modelData, -1)
                                        }
                                        EditButton {
                                            glyph: "↓"
                                            tint: dashboard.theme.accent
                                            onClicked: dashboard.moveWithinPage(pageHolder.modelData.id, shell.modelData, 1)
                                        }
                                        EditButton {
                                            glyph: "→"
                                            tint: dashboard.theme.accent
                                            onClicked: {
                                                const pages = Theme.PAGES.map(p => p.id);
                                                let index = pages.indexOf(pageHolder.modelData.id);
                                                dashboard.moveCard(shell.modelData, pages[(index + 1) % pages.length]);
                                            }
                                        }
                                    }

                                    CardLoader {
                                        cardId: shell.modelData
                                        dataSource: dashboard.dataSource
                                        theme: dashboard.theme
                                        clock: dashboard.clock
                                        sparkleIntensity: dashboard.configuration ? dashboard.configuration.sparkleIntensity : 1
                                        glowIntensity: dashboard.configuration ? dashboard.configuration.glowIntensity : 1
                                        animationsEnabled: dashboard.configuration
                                            ? dashboard.configuration.animationsEnabled && dashboard.popupVisible : true
                                        activityWindow: dashboard.activityWindow
                                        modelFilter: dashboard.modelFilter
                                        ringStyle: dashboard.configuration ? dashboard.configuration.ringStyle : "gradient"
                                        ringThickness: dashboard.configuration && dashboard.configuration.ringThickness
                                            ? dashboard.configuration.ringThickness : 7
                                        ringSparkles: dashboard.configuration ? dashboard.configuration.ringSparkles !== false : true
                                    }
                                }
                            }

                            Item { Layout.fillHeight: true; Layout.minimumHeight: 4 }
                        }
                    }
                }
            }

            // Horizontal swipe between pages (two-finger trackpad maps to
            // wheel events with fine deltas). Vertical-dominant wheels are
            // left unaccepted so they propagate to the page Flickable below.
            MouseArea {
                anchors.fill: parent
                enabled: !dashboard.isEditing
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)
                        && Math.abs(wheel.angleDelta.x) > 12) {
                        dashboard.navigatePage(wheel.angleDelta.x > 0 ? -1 : 1);
                        wheel.accepted = true;
                    } else {
                        wheel.accepted = false;
                    }
                }
            }
        }

        // --- Footer ----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.leftMargin: 3
            Layout.rightMargin: 3
            spacing: 7

            FooterButton {
                Layout.alignment: Qt.AlignVCenter
                glyph: "‹"
                onClicked: dashboard.navigatePage(-1)
            }
            Row {
                spacing: 5
                Layout.alignment: Qt.AlignVCenter
                Repeater {
                    model: Theme.PAGES
                    Rectangle {
                        required property var modelData
                        readonly property bool active: dashboard.currentPageId === modelData.id
                        width: active ? 7 : 5
                        height: width
                        radius: width / 2
                        color: active
                            ? Theme.rgba(dashboard.theme.accent, 1)
                            : Theme.rgba([1, 1, 1], 0.28)
                    }
                }
            }
            FooterButton {
                Layout.alignment: Qt.AlignVCenter
                glyph: "›"
                onClicked: dashboard.navigatePage(1)
            }

            Item { Layout.fillWidth: true }

            ColumnLayout {
                spacing: 1
                Layout.alignment: Qt.AlignVCenter
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: dashboard.isEditing ? "Move cards with ↑ ↓ →" : "Keys: ←→ pages · R refresh · A style"
                    color: dashboard.isEditing
                        ? Theme.rgba(dashboard.theme.accent, 1)
                        : Theme.rgba([1, 1, 1], 0.62)
                    font.pixelSize: 10
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.Bold
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    visible: !dashboard.isEditing
                    text: {
                        let index = 1;
                        for (let i = 0; i < Theme.PAGES.length; ++i)
                            if (Theme.PAGES[i].id === dashboard.currentPageId)
                                index = i + 1;
                        return "Page " + index + " of " + Theme.PAGES.length;
                    }
                    color: Theme.rgba([1, 1, 1], 0.48)
                    font.pixelSize: 9
                    font.family: Theme.fontFamily(UIFont.configured)
                    font.weight: Font.DemiBold
                }
            }
        }
    }

    // --- Appearance popover -------------------------------------------------
    Rectangle {
        id: appearanceScrim
        visible: dashboard.appearanceOpen
        anchors.fill: parent
        radius: dashboard.radius
        color: Theme.rgba([0, 0, 0], 0.35)

        MouseArea {
            anchors.fill: parent
            onClicked: dashboard.appearanceOpen = false
        }

        AppearancePopover {
            id: appearancePanel
            anchors.centerIn: parent
            theme: dashboard.theme
            configuration: dashboard.configuration
            plasmaPalette: dashboard.plasmaPalette
            currentPageId: dashboard.currentPageId
            clock: dashboard.clock
            sparkleIntensity: dashboard.configuration ? dashboard.configuration.sparkleIntensity : 1
            glowIntensity: dashboard.configuration ? dashboard.configuration.glowIntensity : 1
            animationsEnabled: dashboard.configuration ? dashboard.configuration.animationsEnabled : true
            onClosed: dashboard.appearanceOpen = false
        }

        onVisibleChanged: {
            if (visible)
                appearancePanel.forceActiveFocus();
            else
                dashboard.forceActiveFocus();
        }
    }

    component HeaderButton: Rectangle {
        id: headerButton

        property string iconGlyph: ""
        property var tint: null
        property bool highlighted: false
        property bool spinning: false
        property string tooltip: ""

        signal clicked()

        width: 23
        height: 23
        radius: highlighted ? 12 : 0
        color: highlighted && tint ? Theme.rgba(tint, 0.13) : "transparent"

        Text {
            anchors.centerIn: parent
            text: headerButton.iconGlyph
            color: headerButton.tint
                ? Theme.rgba(headerButton.tint, 1)
                : Theme.rgba([1, 1, 1], 0.72)
            font.pixelSize: 13
            font.family: Theme.fontFamily(UIFont.configured)

            RotationAnimation on rotation {
                running: headerButton.spinning
                from: 0
                to: 360
                duration: 900
                loops: Animation.Infinite
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: headerButton.clicked()
        }

        PlasmaComponents.ToolTip {
            text: headerButton.tooltip
        }
    }

    component FooterButton: Rectangle {
        property string glyph: "‹"
        signal clicked()
        width: 20
        height: 20
        color: hover.hovered ? Theme.rgba([1, 1, 1], 0.08) : "transparent"
        radius: 4
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: Theme.rgba([1, 1, 1], 0.55)
            font.pixelSize: 13
            font.family: Theme.fontFamily(UIFont.configured)
        }
        MouseArea {
            id: hover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }

    component EditButton: Rectangle {
        property string glyph: "↑"
        property var tint: null
        signal clicked()
        width: 18
        height: 18
        radius: 5
        color: Theme.rgba(tint || [1, 1, 1], editHover.hovered ? 0.25 : 0.14)
        Text {
            anchors.centerIn: parent
            text: parent.glyph
            color: "white"
            font.pixelSize: 11
            font.family: Theme.fontFamily(UIFont.configured)
            font.weight: Font.Bold
        }
        MouseArea {
            id: editHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
