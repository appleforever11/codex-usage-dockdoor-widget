import Foundation

/// Declarative setting definition.
///
/// Instead of providing a SwiftUI settings view, marketplace widgets
/// declare their settings as data. The host app renders these using
/// its native settings UI, ensuring a consistent look.
///
/// Use ``WidgetDefaults`` to read the current value at runtime.
///
/// ```swift
/// func settingsSchema() -> [WidgetSetting] {
///     [
///         .toggle(key: "showGraph", label: "Show Graph", defaultValue: true),
///         .picker(key: "interval", label: "Update Interval",
///                 options: ["1s", "5s", "30s"], defaultValue: "5s"),
///     ]
/// }
/// ```
public enum WidgetSetting: Sendable {
    case toggle(key: String, label: String, defaultValue: Bool)
    case picker(key: String, label: String, options: [String], defaultValue: String)
    case slider(key: String, label: String, range: ClosedRange<Double>, step: Double = 1, defaultValue: Double)
    case textField(key: String, label: String, placeholder: String, defaultValue: String)
}
