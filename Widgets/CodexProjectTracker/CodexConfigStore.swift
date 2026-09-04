import Foundation

enum CodexConfigStore {
    private static let configURL = URL(fileURLWithPath: NSHomeDirectory())
        .appendingPathComponent(".codex/config.toml")

    static func read() -> CodexModelSettings {
        guard let text = try? String(contentsOf: configURL, encoding: .utf8) else {
            return .default
        }

        return CodexModelSettings(
            model: tomlStringValue(for: "model", in: text) ?? CodexModelSettings.default.model,
            reasoningEffort: normalizedReasoningEffort(
                tomlStringValue(for: "model_reasoning_effort", in: text) ?? CodexModelSettings.default.reasoningEffort
            )
        )
    }

    static func update(model: String, reasoningEffort: String) throws {
        let allowedModels = ["gpt-5.6-luna", "gpt-5.6-sol", "gpt-5.6-terra", CodexModelSettings.astraModel]
        let allowedReasoning = ["low", "medium", "max"]
        guard allowedModels.contains(model), allowedReasoning.contains(reasoningEffort) else { throw CocoaError(.validationMissingMandatoryProperty) }

        let current = FileManager.default.fileExists(atPath: configURL.path)
            ? try String(contentsOf: configURL, encoding: .utf8) : ""
        let output = replacingDefaults(in: current, model: model, reasoningEffort: reasoningEffort)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try output.write(to: configURL, atomically: true, encoding: .utf8)
    }

    static func replacingDefaults(in current: String, model: String, reasoningEffort: String) -> String {
        var lines = current.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        upsert(key: "model", value: model, in: &lines)
        upsert(key: "model_reasoning_effort", value: reasoningEffort, in: &lines)

        return lines.joined(separator: "\n")
    }

    static func normalizedReasoningEffort(_ value: String) -> String {
        switch value.lowercased() {
        case "high", "xhigh", "max": return "max"
        case "low", "instant": return "low"
        default: return "medium"
        }
    }

    static func tomlStringValue(for key: String, in text: String) -> String? {
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("[") { break }
            guard assignmentKey(line) == key, let equals = line.firstIndex(of: "=") else { continue }
            let value = line[line.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard let quote = value.first, quote == "\"" || quote == "'" else { continue }
            return value.dropFirst().split(separator: quote, maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init)
        }
        return nil
    }

    private static func assignmentKey(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.hasPrefix("#"), let equals = trimmed.firstIndex(of: "=") else { return nil }
        return trimmed[..<equals].trimmingCharacters(in: .whitespaces)
    }

    private static func upsert(key: String, value: String, in lines: inout [String]) {
        let replacement = "\(key) = \"\(value)\""
        let rootEnd = lines.firstIndex { $0.trimmingCharacters(in: .whitespaces).hasPrefix("[") } ?? lines.count
        if let index = lines[..<rootEnd].firstIndex(where: { assignmentKey($0) == key }) {
            lines[index] = replacement
        } else {
            lines.insert(replacement, at: rootEnd)
        }
    }
}
