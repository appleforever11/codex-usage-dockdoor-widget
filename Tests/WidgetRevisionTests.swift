import Foundation

@main
enum WidgetRevisionTests {
    static func main() {
        let source = """
        # keep this comment
        model="gpt-5.6-sol" # root selection
        model_reasoning_effort = 'medium'
        [profiles.work]
        model = "gpt-5.6-luna"
        model_reasoning_effort = "high"
        [tools]
        enabled = true
        """
        let result = CodexConfigStore.replacingDefaults(in: source, model: "gpt-5.6-terra", reasoningEffort: "max")
        precondition(CodexConfigStore.tomlStringValue(for: "model", in: result) == "gpt-5.6-terra")
        precondition(CodexConfigStore.tomlStringValue(for: "model_reasoning_effort", in: result) == "max")
        precondition(result.components(separatedBy: "[profiles.work]")[1] == source.components(separatedBy: "[profiles.work]")[1])
        precondition(result.contains("# keep this comment"))
        let nestedOnly = "[profiles.work]\nmodel = \"gpt-5.6-sol\"\n"
        precondition(CodexConfigStore.tomlStringValue(for: "model", in: nestedOnly) == nil)
        let inserted = CodexConfigStore.replacingDefaults(in: nestedOnly, model: "gpt-6-astra", reasoningEffort: "medium")
        precondition(inserted.hasSuffix(nestedOnly))
        precondition(CodexConfigStore.tomlStringValue(for: "model", in: inserted) == "gpt-6-astra")
        precondition(CodexModelSettings(model: "gpt-5.6-terra", reasoningEffort: "low").reasoningLabel == "Light")
        precondition(CodexModelSettings(model: "gpt-5.6-terra", reasoningEffort: "medium").shortModelName == "Terra")
        precondition(Set(CodexTheme.allCases.map(\.rawValue)).count == 5)
        precondition(CodexConfigStore.normalizedReasoningEffort("instant") == "low")
        precondition(CodexConfigStore.normalizedReasoningEffort("low") == "low")
        print("Passed: root TOML edits, nested-profile preservation, root insertion, comments, Terra and Light labels, theme identities.")
    }
}
