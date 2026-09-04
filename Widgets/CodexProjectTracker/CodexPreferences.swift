import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

enum CodexAppLauncher {
    static func checkForUpdates() {
        let companion = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Install Codex Usage.app")
        if FileManager.default.fileExists(atPath: companion.path) {
            NSWorkspace.shared.open(URL(string: "codexusage://check-for-updates")!)
        } else {
            NSWorkspace.shared.open(URL(string: "https://github.com/appleforever11/codex-usage-dockdoor-widget/releases/latest")!)
        }
    }

    private static let codexAppURLs = [
        URL(fileURLWithPath: "/Applications/Codex.app"),
        URL(fileURLWithPath: "/Applications/ChatGPT.app"),
    ]

    static func openSession(_ session: CodexSession) {
        if let deepLink = session.codexDeepLink {
            NSWorkspace.shared.open(deepLink)
        } else {
            openCodex()
        }
    }

    static func openCodex() {
        for appURL in codexAppURLs where FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.open(appURL)
            return
        }

        NSWorkspace.shared.open(CodexTrackerStore.defaultProjectsRoot)
    }
}

enum CodexWidgetPreferences {
    private static let widgetId = "codex-project-tracker"
    private static let primaryCardKey = "primaryCard"
    private static let rotationIntervalKey = "rotationInterval"
    private static let pauseRotationKey = "pauseRotationOnHover"
    private static let showDataStatusKey = "showDataStatus"

    static var primaryCard: String {
        WidgetDefaults.string(key: primaryCardKey, widgetId: widgetId, default: "Auto")
    }

    static var rotationInterval: Double {
        min(max(WidgetDefaults.double(key: rotationIntervalKey, widgetId: widgetId, default: 4), 2), 12)
    }

    static var pauseRotationOnHover: Bool {
        WidgetDefaults.bool(key: pauseRotationKey, widgetId: widgetId, default: true)
    }

    static var showDataStatus: Bool {
        WidgetDefaults.bool(key: showDataStatusKey, widgetId: widgetId, default: true)
    }

}
