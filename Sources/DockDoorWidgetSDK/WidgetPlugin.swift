import Foundation

/// Base class for widget plugins.
///
/// Subclass this **and** conform to ``DockDoorWidgetProvider``.
/// The host discovers your plugin via `Bundle.principalClass`, which
/// requires an `NSObject` subclass, hence this base class.
///
/// Set your subclass name as `principalClass` in `widget.json`.
///
/// ```swift
/// final class MyPlugin: WidgetPlugin, DockDoorWidgetProvider {
///     var id: String { "com.me.my-widget" }
///     // …
/// }
/// ```
open class WidgetPlugin: NSObject {
    public override required init() { super.init() }
}
