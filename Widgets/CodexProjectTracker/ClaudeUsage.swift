import Foundation

struct ClaudeUsageSnapshot: Equatable, Sendable {
    var fiveHourRemaining: Double?
    var weeklyRemaining: Double?
    var updatedAt: Date?
    var unavailableReason: String?

    static let unavailable = ClaudeUsageSnapshot(unavailableReason: "Open Claude Desktop to provide usage")
    static let feedURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Claude/plan-usage-history.json")

    func isStale(at now: Date) -> Bool {
        guard let updatedAt else { return true }
        return now.timeIntervalSince(updatedAt) > 900 || updatedAt.timeIntervalSince(now) > 60
    }

    static func read() -> Self {
        // A local desktop sample only: no credentials, account requests, or account IDs.
        guard let handle = try? FileHandle(forReadingFrom: feedURL) else { return .unavailable }
        defer { try? handle.close() }
        guard let data = try? handle.read(upToCount: 1_048_577), data.count <= 1_048_576 else {
            return Self(unavailableReason: "Claude usage feed is too large")
        }
        return decode(data)
    }

    static func decode(_ data: Data) -> Self {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              root["version"] as? Int == 2,
              let samples = root["samples"] as? [[String: Any]] else {
            return Self(unavailableReason: "Claude usage format unavailable")
        }
        let validSamples = samples.filter { sample in
            guard let timestamp = sample["t"] as? Double else { return false }
            return timestamp.isFinite && timestamp > 0
        }
        guard let latest = validSamples.max(by: { ($0["t"] as? Double ?? 0) < ($1["t"] as? Double ?? 0) }),
              let timestamp = latest["t"] as? Double,
              let usage = latest["u"] as? [String: Any] else { return .unavailable }
        func remaining(_ key: String) -> Double? {
            guard let used = usage[key] as? Double, used.isFinite, (0...100).contains(used) else { return nil }
            return (100 - used) / 100
        }
        let fiveHour = remaining("fh"), weekly = remaining("sd")
        return Self(fiveHourRemaining: fiveHour, weeklyRemaining: weekly,
                    updatedAt: Date(timeIntervalSince1970: timestamp / 1000),
                    unavailableReason: fiveHour == nil && weekly == nil ? "Claude allowances unavailable" : nil)
    }
}
