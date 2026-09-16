import Foundation

/// Converts the two percentage shapes emitted by Codex into a 0...1 fraction.
/// Whole numbers are percentages (`1` means 1%); values below one are already
/// normalized fractions (`0.01` means 1%).
enum CodexUsagePercent {
    static func fraction(fromPercent value: Double) -> Double {
        let fraction = value >= 1 ? value / 100 : value
        return min(max(fraction, 0), 1)
    }
}
