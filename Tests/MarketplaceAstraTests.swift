
@main
enum MarketplaceAstraTests {
    static func main() {
        let samples: [(String, String, Double)] = [
            (#"{"payload":{"rate_limits":{"limit_name":"GPT-6-Astra","primary":{"used_percent":21,"window_minutes":300}}}}"#, "Astra 5h", 0.79),
            (#"{"payload":{"rate_limits":{"limit_id":"gpt-6-astra","secondary":{"used_percent":100,"window_minutes":10080}}}}"#, "Astra Weekly", 0),
            (#"{"payload":{"rate_limits":{"primary":{"used_percent":0,"window_minutes":300}}}}"#, "5h", 1),
            (#"{"payload":{"rate_limits":{"limit_name":"General","primary":{"used_percent":50,"window_minutes":300}}}}"#, "5h", 0.5),
        ]
        for (json, name, remaining) in samples {
            guard let limit = CodexSessionsStore.decodeSnapshot(from: Data(json.utf8))?.limits.first else {
                fatalError("Missing decoded limit")
            }
            precondition(limit.name == name, "Unexpected name: \(limit.name)")
            precondition(abs(limit.percentRemaining - remaining) < 0.0001)
            precondition(limit.isAstra == name.hasPrefix("Astra"))
            if limit.isAstra {
                precondition(limit.shortName == "Astra")
                precondition(limit.systemImage == "sparkles")
            }
        }
        precondition(CodexSessionsStore.decodeSnapshot(from: Data("{}".utf8)) == nil)
        print("Marketplace Astra: 4 named/unnamed usage fixtures and missing-data check passed")
    }
}
