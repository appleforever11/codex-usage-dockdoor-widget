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
        print("Passed: Codex usage percentage normalization, including the 1% exhaustion boundary.")
    }

    private static func assertClose(_ actual: Double, _ expected: Double) {
        precondition(abs(actual - expected) < 0.000_001, "Expected \(expected), got \(actual)")
    }
}
