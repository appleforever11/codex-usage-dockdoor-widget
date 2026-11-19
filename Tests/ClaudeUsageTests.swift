import Foundation

@main enum ClaudeUsageTests {
    static func main() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        func decode(_ json: String) -> ClaudeUsageSnapshot { .decode(Data(json.utf8)) }
        let sample = decode("""
        {"version":2,"samples":[
          {"t":1800000000000,"org":"account-b","u":{"fh":0,"sd":21}},
          {"t":1799999900000,"org":"account-a","u":{"fh":99,"sd":99}}
        ]}
        """)
        precondition(sample.fiveHourRemaining == 1)
        precondition(sample.weeklyRemaining == 0.79)
        precondition(!sample.isStale(at: now))
        precondition(sample.isStale(at: now.addingTimeInterval(901)))
        precondition(sample.isStale(at: now.addingTimeInterval(-61)))
        let partial = decode("""
        {"version":2,"samples":[{"t":1800000000000,"u":{"fh":101,"sd":100}}]}
        """)
        precondition(partial.fiveHourRemaining == nil && partial.weeklyRemaining == 0)
        for json in ["{}", "not json", "{\"version\":3,\"samples\":[]}",
                     "{\"version\":2,\"samples\":[]}",
                     "{\"version\":2,\"samples\":[{\"t\":-1,\"u\":{\"fh\":0}}]}"] {
            let unavailable = decode(json)
            precondition(unavailable.fiveHourRemaining == nil && unavailable.weeklyRemaining == nil)
            precondition(unavailable.unavailableReason != nil)
        }
        print("Passed: Claude latest-sample selection, percentage conversion, missing/invalid feeds, partial allowances, and freshness.")
    }
}
