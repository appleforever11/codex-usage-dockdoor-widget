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

        let telemetryFixture = """
        {"timestamp":"2026-09-07T16:00:00Z","ordinal":1,"type":"turn_context","payload":{"model":"gpt-6-astra","effort":"low"}}
        {"timestamp":"2026-09-07T16:00:10Z","ordinal":2,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":90,"cached_input_tokens":20,"output_tokens":10,"reasoning_output_tokens":2,"total_tokens":100},"total_token_usage":{"input_tokens":90,"cached_input_tokens":20,"output_tokens":10,"reasoning_output_tokens":2,"total_tokens":100},"model_context_window":1000}}}
        {"timestamp":"2026-09-07T16:00:40Z","ordinal":3,"type":"event_msg","payload":{"type":"thread_settings_applied","thread_settings":{"model":"gpt-5.6-terra","reasoning_effort":"max"}}}
        {"timestamp":"2026-09-07T16:00:50Z","ordinal":4,"type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"input_tokens":120,"cached_input_tokens":30,"output_tokens":20,"reasoning_output_tokens":6,"total_tokens":140},"total_token_usage":{"input_tokens":220,"cached_input_tokens":60,"output_tokens":40,"reasoning_output_tokens":8,"total_tokens":260},"model_context_window":1000}}}
        """
        let telemetryNow = ISO8601DateFormatter().date(from: "2026-09-07T16:01:00Z")!
        let telemetry = CodexTokenTelemetryReader.read(
            sources: [CodexTokenLogSource(id: "fixture", projectName: "Widget", contents: telemetryFixture)],
            now: telemetryNow
        )
        precondition(telemetry.observedUsage.effectiveTotalTokens == 260)
        precondition(telemetry.todayUsage.effectiveTotalTokens == 260)
        precondition(telemetry.attributedEventCount == 2)
        precondition(telemetry.currentModel == "gpt-5.6-terra")
        precondition(telemetry.currentReasoningEffort == "max")
        precondition(telemetry.contextPercent == 0.14)
        precondition(telemetry.modelBreakdowns.count == 2)
        precondition(telemetry.modelBreakdowns.contains { $0.modelLabel == "Astra" && $0.usage.effectiveTotalTokens == 100 })
        precondition(telemetry.modelBreakdowns.contains { $0.modelLabel == "Terra" && $0.usage.effectiveTotalTokens == 160 })
        precondition(telemetry.tokensPerMinute(window: 60, now: telemetryNow) == 260)
        print("Passed: root TOML edits, nested-profile preservation, root insertion, comments, Terra and Light labels, theme identities, token deltas, model/effort attribution, and context burn.")
    }
}
