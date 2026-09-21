import Foundation

enum CodexCreditFormatting {
    /// The account API exposes an internal credit balance, not a currency value.
    /// Keep the display unit-neutral and avoid presenting it as dollars.
    static func display(_ rawValue: String?) -> String? {
        guard let rawValue else { return nil }

        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.caseInsensitiveCompare("unlimited") == .orderedSame {
            return "Unlimited"
        }

        let numeric = trimmed
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")

        guard let decimal = Decimal(string: numeric, locale: Locale(identifier: "en_US_POSIX")) else {
            return numeric
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.groupingSize = 3
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.roundingMode = .halfUp
        return formatter.string(from: decimal as NSDecimalNumber) ?? numeric
    }
}
