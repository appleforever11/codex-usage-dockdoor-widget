import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

final class CodexProjectTrackerPlugin: WidgetPlugin, DockDoorWidgetProvider {
    var id: String { "codex-project-tracker" }
    var name: String { "Codex Usage" }
    var iconSymbol: String { "gauge.with.dots.needle.67percent" }
    var widgetDescription: String { "Shows Codex limits, local token burn, model activity, projects, tasks, and chats" }
    var supportedOrientations: [WidgetOrientation] { [.horizontal, .vertical] }

    @MainActor
    func makeBody(size: CGSize, isVertical: Bool) -> AnyView {
        return AnyView(CodexTrackerCompactView(size: size, isVertical: isVertical))
    }

    @MainActor
    func makePanelBody(dismiss: @escaping () -> Void) -> AnyView? {
        return AnyView(CodexTrackerPanelView(dismiss: dismiss))
    }

    func settingsSchema() -> [WidgetSetting] {
        return [
            .textField(
                key: "projectsRoot",
                label: "Codex Sessions Folder",
                placeholder: "~/.codex/sessions",
                defaultValue: CodexTrackerStore.defaultProjectsRoot.path
            ),
            .slider(
                key: "recentLimit",
                label: "Recent Session Count",
                range: 3...10,
                step: 1,
                defaultValue: 5
            ),
            .slider(
                key: "usageBudgetMillions",
                label: "Usage Budget (M tokens)",
                range: 25...500,
                step: 25,
                defaultValue: 200
            ),
            .slider(
                key: "usageWindowHours",
                label: "Usage Window Hours",
                range: 1...24,
                step: 1,
                defaultValue: 5
            ),
            .slider(
                key: "dailyGoalMillions",
                label: "Daily Token Goal (M)",
                range: 0.5...20,
                step: 0.5,
                defaultValue: 2
            ),
            .textField(
                key: "usageStatePath",
                label: "Usage State File",
                placeholder: "~/.codex/usage.json",
                defaultValue: "~/.codex/usage.json"
            ),
            .picker(
                key: "modelTheme",
                label: "Widget Theme",
                options: CodexTheme.allCases.map(\.rawValue),
                defaultValue: "Astra"
            ),
            .picker(
                key: "primaryCard",
                label: "Primary Dock Card",
                options: ["Auto", "Usage", "Model", "Burn", "Pace", "Cost", "Tasks", "Chats", "Credits"],
                defaultValue: "Auto"
            ),
            .slider(
                key: "rotationInterval",
                label: "Card Rotation Seconds",
                range: 2...12,
                step: 1,
                defaultValue: 4
            ),
            .toggle(
                key: "pauseRotationOnHover",
                label: "Pause Rotation on Hover",
                defaultValue: true
            ),
            .toggle(
                key: "showDataStatus",
                label: "Show Data Freshness",
                defaultValue: true
            ),
            .toggle(
                key: "showTokenTelemetry",
                label: "Show Local Token Activity",
                defaultValue: true
            ),
            .toggle(
                key: "hapticsEnabled",
                label: "Model Selection Haptics",
                defaultValue: true
            ),
        ]
    }

    func performTapAction() {
        CodexAppLauncher.openCodex()
    }
}
