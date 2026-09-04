import AppKit
import DockDoorWidgetSDK
import Foundation
import SwiftUI

struct CodexSessionFile {
    let url: URL
    let modified: Date
}

struct CodexSessionRecord {
    let file: CodexSessionFile
    let metadata: CodexSessionMetadata
}

struct CodexSQLiteUsage {
    let tokens: Int64
    let threadCount: Int
}

struct CodexSessionMetadata {
    let id: String?
    let cwd: String
    let timestamp: Date?
}

struct CodexSessionEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let id: String?
        let timestamp: String?
        let cwd: String?
    }
}

struct CodexEventEnvelope: Decodable {
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let message: String?
        let text: String?
    }
}

struct CodexHistoryEntry: Decodable {
    let text: String
}

struct CodexExternalUsageState: Decodable {
    let updatedAt: String?
    let title: String?
    let subtitle: String?
    let source: String?
    let creditsBalance: String?
    let used: Int64?
    let remaining: Int64?
    let limit: Int64?
    let todayUsed: Int64?
    let resetAt: String?
    let resetLabel: String?
    let percentRemaining: Double?
    let remainingPercent: Double?
    let percentUsed: Double?
    let usedPercent: Double?
    let limits: [CodexExternalUsageLimit]?
}

struct CodexExternalUsageLimit: Decodable {
    let name: String
    let subtitle: String?
    let systemImage: String?
    let used: Int64?
    let remaining: Int64?
    let limit: Int64?
    let resetAt: String?
    let resetLabel: String?
    let percentRemaining: Double?
    let remainingPercent: Double?
    let percentUsed: Double?
    let usedPercent: Double?
}

struct CodexRateLimitEnvelope: Decodable {
    let timestamp: String?
    let type: String
    let payload: Payload

    struct Payload: Decodable {
        let type: String?
        let rateLimits: CodexRateLimits?

        enum CodingKeys: String, CodingKey {
            case type
            case rateLimits = "rate_limits"
        }
    }
}

struct CodexRateLimits: Decodable {
    let limitID: String?
    let limitName: String?
    let primary: Window?
    let credits: Credits?

    struct Window: Decodable {
        let usedPercent: Double
        let windowMinutes: Int?
        let resetsAt: TimeInterval?

        enum CodingKeys: String, CodingKey {
            case usedPercent = "used_percent"
            case windowMinutes = "window_minutes"
            case resetsAt = "resets_at"
        }
    }

    struct Credits: Decodable {
        let balance: String?
        let unlimited: Bool?
    }

    enum CodingKeys: String, CodingKey {
        case limitID = "limit_id"
        case limitName = "limit_name"
        case primary
        case credits
    }
}

struct CodexLiveRateLimitSample {
    let id: String
    let name: String?
    let usedPercent: Double
    let windowMinutes: Int?
    let resetsAt: TimeInterval?
    let creditsBalance: String?
    let unlimitedCredits: Bool
    let timestamp: Date

    var isGeneral: Bool {
        id == "codex" || name == nil
    }

    var displayName: String {
        name ?? "General"
    }
}

struct CodexResolvedRateLimit {
    let name: String
    let percentRemaining: Double
    let resetDate: Date?
    let resetLabel: String?
}
