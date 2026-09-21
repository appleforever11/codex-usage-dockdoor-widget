import Foundation

@main
enum CodexUsagePercentTests {
    static func main() {
        assertClose(CodexUsagePercent.fraction(fromPercent: 0), 0)
        assertClose(CodexUsagePercent.fraction(fromPercent: 1), 0.01)
        assertClose(CodexUsagePercent.fraction(fromPercent: 50), 0.50)
        assertClose(CodexUsagePercent.fraction(fromPercent: 100), 1)
        assertClose(CodexUsagePercent.fraction(fromPercent: 0.01), 0.01)
        assertClose(CodexUsagePercent.fraction(fromPercent: 0.5), 0.5)
        assertClose(CodexUsagePercent.fraction(fromPercent: -1), 0)
        assertClose(CodexUsagePercent.fraction(fromPercent: 250), 1)
        precondition(CodexCreditFormatting.display("1246.8885130000") == "1,246.89")
        precondition(CodexCreditFormatting.display("$1250.0000000000") == "1,250")
        precondition(CodexCreditFormatting.display("Unlimited") == "Unlimited")
        precondition(CodexCreditFormatting.display(nil) == nil)
        print("Passed: usage percentage normalization and unit-neutral prepaid credit formatting.")
    }

    private static func assertClose(_ actual: Double, _ expected: Double) {
        precondition(abs(actual - expected) < 0.000_001, "Expected \(expected), got \(actual)")
    }
}
