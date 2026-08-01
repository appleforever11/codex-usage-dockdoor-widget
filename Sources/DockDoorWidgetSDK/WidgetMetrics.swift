import Foundation

/// Shared sizing constants for widget content.
///
/// All built-in DockDoor Pro widgets use these for consistent proportions.
/// Marketplace widgets should use them too so they look native.
///
/// - `contentScale` - main icon/image sizing relative to `dim`
/// - `sfSymbolScale` - SF Symbol sizing relative to `dim`
/// - `spacingScale` - spacing between elements relative to `dim`
///
/// Where `dim = min(size.width, size.height)`.
public enum WidgetMetrics {
    public static let contentScale: CGFloat = 0.85
    public static let sfSymbolScale: CGFloat = 0.55
    public static let spacingScale: CGFloat = 0.08
}
