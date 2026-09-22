import Foundation

/// Model IDs and labels shared by controls, dock cards, and recorded analytics.
enum CodexModelIdentity {
    static let lunaModel = "gpt-6-luna"
    static let solModel = "gpt-6-sol"
    static let terraModel = "gpt-5.6-terra"
    static let astraModel = "gpt-6-astra"
    static let selectableModels = [lunaModel, solModel, terraModel, astraModel]

    static func label(_ model: String?, unknown: String = "Unknown model") -> String {
        guard let model, !model.isEmpty, model.lowercased() != "unknown" else { return unknown }
        let value = model.lowercased()
        if value.contains("astra") { return "Astra" }
        if value.contains("spark") { return "Spark" }
        if value.contains("terra") { return "Terra" }
        for family in ["luna", "sol"] where value.contains(family) {
            let name = family.capitalized
            // Historical records keep their actual generation; reading them never
            // changes a default or presents GPT-5.6 activity as GPT-6 activity.
            if value.hasPrefix("gpt-"), let version = value.dropFirst(4).split(separator: "-").first,
               version.first?.isNumber == true {
                return "\(name)-\(version)"
            }
            return name
        }
        return model
    }
}

struct CodexModelSettings {
    var model: String
    var reasoningEffort: String

    static let astraModel = CodexModelIdentity.astraModel
    static let `default` = CodexModelSettings(model: CodexModelIdentity.lunaModel, reasoningEffort: "medium")

    var shortModelName: String {
        String(CodexModelIdentity.label(model).prefix(14))
    }

    var reasoningLabel: String {
        if reasoningEffort == "low" || reasoningEffort == "instant" { return "Light" }
        if reasoningEffort == "max" { return "Max" }
        return reasoningEffort.prefix(1).uppercased() + reasoningEffort.dropFirst()
    }
}
