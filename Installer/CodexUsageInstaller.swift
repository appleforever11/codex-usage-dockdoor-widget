import AppKit
import Foundation
import SwiftUI

private enum InstallerError: LocalizedError {
    case missingPackage
    case failed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .missingPackage:
            return "The installer package is incomplete. Re-download the DMG and try again."
        case let .failed(code, output):
            let details = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if details.isEmpty {
                return "The installer stopped with exit code \(code)."
            }
            return "The installer stopped with exit code \(code):\n\(details)"
        }
    }
}

private struct ProcessResult {
    let status: Int32
    let output: String
}

final class InstallerViewController: NSViewController {
    var updates: CompanionUpdates?
    var isDesignPreview = false
    private let statusLabel = NSTextField(labelWithString: "Ready to install the latest Codex Usage widget.")
    private let detailLabel = NSTextField(labelWithString: "")
    private let installButton = NSButton(title: "Install Widget", target: nil, action: nil)
    private let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
    private let outputView = NSTextView()
    private let outputScrollView = NSScrollView()
    private var isInstalling = false

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 350))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.appearance = NSAppearance(named: .darkAqua)
        view.widthAnchor.constraint(equalToConstant: 560).isActive = true
        let themeSurface = NSHostingView(rootView: CompanionThemeSurface())
        themeSurface.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(themeSurface)
        NSLayoutConstraint.activate([
            themeSurface.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            themeSurface.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            themeSurface.topAnchor.constraint(equalTo: view.topAnchor),
            themeSurface.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])


        let iconView = NSImageView()
        iconView.image = NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "Codex Usage installer")
        iconView.contentTintColor = .systemPurple
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.setContentHuggingPriority(.required, for: .horizontal)
        iconView.setContentHuggingPriority(.required, for: .vertical)
        iconView.widthAnchor.constraint(equalToConstant: 42).isActive = true
        iconView.heightAnchor.constraint(equalToConstant: 42).isActive = true

        let titleLabel = NSTextField(labelWithString: "Codex Usage for DockDoor Pro")
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let subtitleLabel = NSTextField(labelWithString: version.isEmpty ? "Design preview" : "Version \(version)")
        subtitleLabel.font = .systemFont(ofSize: 14)
        subtitleLabel.textColor = .secondaryLabelColor

        let titleStack = NSStackView(views: [titleLabel, subtitleLabel])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 4

        let themePicker = NSHostingView(rootView: CompanionThemePicker())
        themePicker.translatesAutoresizingMaskIntoConstraints = false
        themePicker.widthAnchor.constraint(equalToConstant: 28).isActive = true
        themePicker.heightAnchor.constraint(equalToConstant: 28).isActive = true
        let headingStack = NSStackView(views: [iconView, titleStack, themePicker])
        headingStack.orientation = .horizontal
        headingStack.alignment = .centerY
        headingStack.spacing = 14

        let explanationLabel = NSTextField(labelWithString: "This installs the widget, keeps a dated backup of any existing copy, enables live usage sync, installs the automatic updater, and restarts DockDoor Pro. No Terminal or .command file is required.")
        explanationLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        explanationLabel.font = .systemFont(ofSize: 13)
        explanationLabel.textColor = .secondaryLabelColor
        explanationLabel.lineBreakMode = .byWordWrapping
        explanationLabel.maximumNumberOfLines = 4
        explanationLabel.translatesAutoresizingMaskIntoConstraints = false

        statusLabel.font = .systemFont(ofSize: 14, weight: .medium)
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 3
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        detailLabel.font = .systemFont(ofSize: 12)
        detailLabel.textColor = .secondaryLabelColor
        detailLabel.lineBreakMode = .byWordWrapping
        detailLabel.maximumNumberOfLines = 3
        detailLabel.translatesAutoresizingMaskIntoConstraints = false

        outputView.isEditable = false
        outputView.isSelectable = true
        outputView.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        outputView.textColor = .secondaryLabelColor
        outputView.drawsBackground = false
        outputView.textContainerInset = NSSize(width: 8, height: 8)
        outputScrollView.documentView = outputView
        outputScrollView.hasVerticalScroller = true
        outputScrollView.borderType = .bezelBorder
        outputScrollView.isHidden = true
        outputScrollView.translatesAutoresizingMaskIntoConstraints = false

        installButton.target = self
        installButton.action = #selector(install)
        installButton.keyEquivalent = "\r"
        installButton.bezelStyle = .rounded

        cancelButton.target = self
        cancelButton.action = #selector(cancel)
        cancelButton.bezelStyle = .rounded

        let updateButton = NSButton(title: "Check for Updates…", target: updates, action: #selector(CompanionUpdates.checkForUpdates))
        updateButton.bezelStyle = .rounded
        updateButton.isEnabled = !isDesignPreview
        installButton.isEnabled = !isDesignPreview
        let buttonStack = NSStackView(views: [updateButton, cancelButton, installButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.alignment = .centerY

        let rootStack = NSStackView(views: [headingStack, explanationLabel, statusLabel, detailLabel, outputScrollView, buttonStack])
        rootStack.orientation = .vertical
        rootStack.alignment = .leading
        rootStack.spacing = 14
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(rootStack)

        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            rootStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            rootStack.topAnchor.constraint(equalTo: view.topAnchor, constant: 26),
            rootStack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24),
            explanationLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            detailLabel.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            outputScrollView.widthAnchor.constraint(equalTo: rootStack.widthAnchor),
            outputScrollView.heightAnchor.constraint(equalToConstant: 92),
            installButton.widthAnchor.constraint(equalToConstant: 132)
        ])
    }

    @objc private func cancel() {
        NSApp.terminate(nil)
    }

    @objc func install() {
        guard !isInstalling else { return }

        isInstalling = true
        updates?.isInstallingWidget = true
        installButton.isEnabled = false
        cancelButton.isEnabled = false
        statusLabel.stringValue = "Installing…"
        detailLabel.stringValue = "DockDoor Pro may briefly disappear while its widget bundle is replaced."

        let installerURL = Bundle.main.resourceURL?.appendingPathComponent("Install Codex Usage.command")
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            do {
                guard let installerURL, FileManager.default.isReadableFile(atPath: installerURL.path) else {
                    throw InstallerError.missingPackage
                }

                let result = try Self.runInstaller(at: installerURL)
                guard result.status == 0 else {
                    throw InstallerError.failed(result.status, result.output)
                }

                DispatchQueue.main.async {
                    self?.finishSuccessfully(output: result.output)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.finishWithError(error)
                }
            }
        }
    }

    private static func runInstaller(at url: URL) throws -> ProcessResult {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [url.path]
        process.currentDirectoryURL = url.deletingLastPathComponent()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()

        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ProcessResult(
            status: process.terminationStatus,
            output: String(data: outputData, encoding: .utf8) ?? ""
        )
    }

    private func finishSuccessfully(output: String) {
        isInstalling = false
        updates?.isInstallingWidget = false
        cancelButton.isEnabled = true
        installButton.isEnabled = true
        installButton.title = "Close"
        installButton.keyEquivalent = "\r"
        installButton.action = #selector(closeInstaller)
        statusLabel.stringValue = "Installation complete."
        detailLabel.stringValue = "Codex Usage is installed. DockDoor Pro has been restarted and the widget is ready to add or refresh in your dock."
        showOutput(output)
    }

    private func finishWithError(_ error: Error) {
        isInstalling = false
        updates?.isInstallingWidget = false
        cancelButton.isEnabled = true
        installButton.isEnabled = true
        statusLabel.stringValue = "Installation could not be completed."
        detailLabel.stringValue = error.localizedDescription
        showOutput(error.localizedDescription)
    }

    private func showOutput(_ output: String) {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        outputView.string = trimmed
        outputScrollView.isHidden = false
    }

    @objc private func closeInstaller() {
        NSApp.terminate(nil)
    }
}

final class InstallerAppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var updates: CompanionUpdates?
    private var pendingCheck = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            if try CompanionUpdates.relocateIfNeeded(completion: { error in
                if let error { NSAlert(error: error).runModal() }
                NSApp.terminate(nil)
            }) { return }
        } catch {
            NSAlert(error: error).runModal()
            NSApp.terminate(nil)
            return
        }
        let updates = CompanionUpdates()
        updates.backgroundOnly = CommandLine.arguments.contains("--background")
        self.updates = updates
        do { try updates.start() } catch {
            NSAlert(error: error).runModal()
        }
        let controller = InstallerViewController()
        controller.updates = updates
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Install Codex Usage"
        window.isReleasedWhenClosed = false
        window.contentViewController = controller
        window.center()
        self.window = window
        let shouldInstall = CompanionUpdates.hasNewerWidgetPayload && !CommandLine.arguments.contains("--no-relocate")
        if !updates.backgroundOnly || shouldInstall {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        DispatchQueue.main.async {
            if shouldInstall {
                updates.backgroundOnly = false
                controller.install()
            } else if self.pendingCheck || CommandLine.arguments.contains("--check-for-updates") {
                updates.checkForUpdates()
            } else if updates.backgroundOnly {
                updates.checkInBackground()
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard urls.contains(where: { $0.scheme == "codexusage" && $0.host == "check-for-updates" }) else { return }
        pendingCheck = true
        updates?.checkForUpdates()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

#if !WIDGET_DESIGN_PREVIEW
@main
enum InstallerMain {
    static func main() {
        let application = NSApplication.shared
        let delegate = InstallerAppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}

#endif
