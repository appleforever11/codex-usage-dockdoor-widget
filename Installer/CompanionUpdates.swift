import AppKit
import Sparkle

final class CompanionUpdates: NSObject, SPUUpdaterDelegate {
    static var installedAppURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications/Install Codex Usage.app")
    }

    var backgroundOnly = false
    var isInstallingWidget = false
    private(set) var controller: SPUStandardUpdaterController!

    override init() {
        super.init()
        controller = SPUStandardUpdaterController(
            startingUpdater: false, updaterDelegate: self, userDriverDelegate: nil
        )
    }

    func start() throws {
        try controller.updater.start()
    }

    @objc func checkForUpdates() {
        guard !isInstallingWidget else { return }
        backgroundOnly = false
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        controller.checkForUpdates(nil)
    }

    func checkInBackground() {
        guard !isInstallingWidget else { return }
        controller.updater.checkForUpdatesInBackground()
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error { NSLog("Codex Usage update check: %@", error.localizedDescription) }
        if backgroundOnly && !isInstallingWidget {
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    static var hasNewerWidgetPayload: Bool {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DockDoorPro/Widgets")
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        guard let entries = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil),
              let widget = entries.first(where: {
                  $0.pathExtension == "bundle" && $0.lastPathComponent.hasPrefix("CodexProjectTracker")
              }),
              let installedVersion = Bundle(url: widget)?.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        else { return false }
        return SUStandardVersionComparator.default.compareVersion(currentVersion, toVersion: installedVersion) == .orderedDescending
    }

    // Sparkle needs a writable app location; keep the signed companion outside the DMG.
    static func relocateIfNeeded(completion: @escaping (Error?) -> Void) throws -> Bool {
        let source = Bundle.main.bundleURL.standardizedFileURL
        let target = installedAppURL.standardizedFileURL
        if source == target || CommandLine.arguments.contains("--no-relocate")
            || CommandLine.arguments.contains("--installed-copy") { return false }
        let fm = FileManager.default
        try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: target.path) {
            guard let existing = Bundle(url: target), existing.bundleIdentifier == Bundle.main.bundleIdentifier else {
                throw NSError(domain: "CodexUsageInstaller", code: 1, userInfo: [NSLocalizedDescriptionKey: "Another app occupies the installation location."])
            }
            let existingVersion = existing.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            let incomingVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: existing.bundleIdentifier ?? "")
                .contains { $0.bundleURL?.standardizedFileURL == target }
            let existingIsCurrent = SUStandardVersionComparator.default.compareVersion(existingVersion, toVersion: incomingVersion) != .orderedAscending
            if running && !existingIsCurrent {
                throw NSError(domain: "CodexUsageInstaller", code: 2, userInfo: [NSLocalizedDescriptionKey:
                    "An older Codex Usage installer is still running. Close that installer, then open this one again."])
            }
            if existingIsCurrent {
                launch(target, completion: completion)
                return true
            }
        }
        let staging = target.deletingLastPathComponent().appendingPathComponent(".CodexUsage-\(UUID().uuidString).app")
        try fm.copyItem(at: source, to: staging)
        var backup: URL?
        do {
            if fm.fileExists(atPath: target.path) {
                let backupRoot = fm.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/CodexUsageWidget/AppBackups")
                try fm.createDirectory(at: backupRoot, withIntermediateDirectories: true)
                let backupURL = backupRoot.appendingPathComponent("\(UUID().uuidString).app")
                try fm.moveItem(at: target, to: backupURL)
                backup = backupURL
            }
            try fm.moveItem(at: staging, to: target)
        } catch {
            if let backup { try? fm.moveItem(at: backup, to: target) }
            try? fm.removeItem(at: staging)
            throw error
        }
        launch(target, completion: completion)
        return true
    }

    private static func launch(_ url: URL, completion: @escaping (Error?) -> Void) {
        let configuration = NSWorkspace.OpenConfiguration()
        // Without this, Launch Services can return the source process for the same
        // bundle identifier. The source then exits and no installer window remains.
        configuration.createsNewApplicationInstance = true
        configuration.activates = !CommandLine.arguments.contains("--background")
        configuration.arguments = CommandLine.arguments.dropFirst().filter { $0 != "--installed-copy" } + ["--installed-copy"]
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            DispatchQueue.main.async { completion(error) }
        }
    }
}
