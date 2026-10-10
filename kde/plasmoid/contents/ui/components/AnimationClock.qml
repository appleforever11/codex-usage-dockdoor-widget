import QtQuick

// Shared low-framerate animation clock (≈18 fps, like codexThemeAnimationInterval).
// One timer drives every canvas so the widget stays visually alive without a
// per-element timer; it pauses when animations are disabled or hidden.
Item {
    id: clock

    property bool animationsEnabled: true
    property bool visibleToUser: true
    property double time: 0        // seconds since start; frozen when paused

    property double _last: 0
    property Timer _timer: Timer {
        interval: 1000 / 18
        running: clock.animationsEnabled && clock.visibleToUser
        repeat: true
        onTriggered: {
            const now = Date.now() / 1000;
            if (clock._last === 0)
                clock._last = now;
            clock.time += now - clock._last;
            clock._last = now;
        }
    }

    onVisibleToUserChanged: if (!visibleToUser) _last = 0
    onAnimationsEnabledChanged: if (!animationsEnabled) _last = 0
}
