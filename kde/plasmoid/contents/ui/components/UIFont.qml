pragma Singleton
import QtQuick

// Live, engine-wide font choice. main.qml assigns this from
// Plasmoid.configuration.uiFontFamily ("" = auto-detect Hack Nerd Font).
// Every Text binds Theme.fontFamily(UIFont.configured), so a settings
// change re-flows the whole dashboard immediately — no Plasma restart.
QtObject {
    property string configured: ""
}
