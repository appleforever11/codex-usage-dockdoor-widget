#!/bin/zsh

set -euo pipefail

usage_file="${CODEX_USAGE_FILE:-$HOME/.codex/usage.json}"
codex_bin="${CODEX_BIN:-}"

if [[ -z "$codex_bin" ]]; then
    for bundled_codex in \
        "/Applications/Codex.app/Contents/Resources/codex" \
        "$HOME/Applications/Codex.app/Contents/Resources/codex" \
        "/Applications/ChatGPT.app/Contents/Resources/codex" \
        "$HOME/Applications/ChatGPT.app/Contents/Resources/codex"; do
        if [[ -x "$bundled_codex" ]]; then
            codex_bin="$bundled_codex"
            break
        fi
    done

    if [[ -z "$codex_bin" ]] && command -v codex >/dev/null 2>&1; then
        codex_bin="$(command -v codex)"
    elif [[ -z "$codex_bin" ]]; then
        print -u2 "Codex executable not found. Install or launch the Codex desktop app."
        exit 1
    fi
fi

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/codex-usage-sync.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

rate_limits=""
error_file="$work_dir/app-server.stderr"

# App-server startup can occasionally be slower while Codex is busy. Retry a
# bounded request rather than allowing a transient delay to stale the widget.
for attempt in 1 2 3; do
    response_file="$work_dir/app-server-$attempt.jsonl"
    : >"$error_file"
    {
        printf '%s\n' '{"id":1,"method":"initialize","params":{"clientInfo":{"name":"dockdoor-codex-usage-sync","title":"DockDoor Codex Usage Sync","version":"3.0.1"},"capabilities":{"experimentalApi":true,"requestAttestation":false}}}'
        sleep 0.25
        printf '%s\n' '{"method":"initialized","params":{}}'
        printf '%s\n' '{"id":2,"method":"account/rateLimits/read","params":null}'
        sleep 5
    } | "$codex_bin" app-server --listen stdio:// >"$response_file" 2>"$error_file" || true

    rate_limits="$(/usr/bin/jq -cs 'map(select(.id == 2 and .result != null)) | last | .result // empty' "$response_file" 2>/dev/null || true)"
    [[ -n "$rate_limits" && "$rate_limits" != "null" ]] && break
    sleep "$attempt"
done

if [[ -z "$rate_limits" || "$rate_limits" == "null" ]]; then
    print -u2 "Codex did not return account rate limits."
    sed -n '1,40p' "$error_file" >&2
    exit 1
fi

general_used="$(printf '%s' "$rate_limits" | /usr/bin/jq -r '(.rateLimitsByLimitId.codex // .rateLimits).primary.usedPercent // empty')"
general_reset="$(printf '%s' "$rate_limits" | /usr/bin/jq -r '(.rateLimitsByLimitId.codex // .rateLimits).primary.resetsAt // empty')"
spark_used="$(printf '%s' "$rate_limits" | /usr/bin/jq -r '([.rateLimitsByLimitId[]? | select(.limitName == "GPT-5.3-Codex-Spark")][0].primary.usedPercent) // empty')"
spark_reset="$(printf '%s' "$rate_limits" | /usr/bin/jq -r '([.rateLimitsByLimitId[]? | select(.limitName == "GPT-5.3-Codex-Spark")][0].primary.resetsAt) // empty')"
credits="$(printf '%s' "$rate_limits" | /usr/bin/jq -r '(.rateLimitsByLimitId.codex // .rateLimits).credits.balance // "0"')"

if [[ -z "$general_used" ]]; then
    print -u2 "Codex returned no General usage window."
    exit 1
fi

general_remaining="$(printf '%s' "$general_used" | /usr/bin/jq -R '100 - (tonumber | round)')"
spark_remaining="100"
if [[ -n "$spark_used" ]]; then
    spark_remaining="$(printf '%s' "$spark_used" | /usr/bin/jq -R '100 - (tonumber | round)')"
fi

reset_label() {
    local epoch="$1"
    if [[ -z "$epoch" ]]; then
        printf '%s' "Unknown"
    else
        /bin/date -r "$epoch" '+%b %e' | /usr/bin/sed 's/  */ /g'
    fi
}

general_reset_label="$(reset_label "$general_reset")"
spark_reset_label="$(reset_label "$spark_reset")"
temporary_usage="$work_dir/usage.json"

/usr/bin/jq -n \
    --arg source "Codex app-server live account limits" \
    --arg creditsBalance "\$$credits" \
    --arg generalReset "$general_reset_label" \
    --arg sparkReset "$spark_reset_label" \
    --argjson generalRemaining "$general_remaining" \
    --argjson sparkRemaining "$spark_remaining" \
    '{
        updatedAt: (now | todateiso8601),
        source: $source,
        creditsBalance: $creditsBalance,
        limits: [
            {
                name: "General",
                subtitle: "Weekly usage limit",
                percentRemaining: $generalRemaining,
                resetLabel: $generalReset,
                systemImage: "gauge.with.dots.needle.67percent"
            },
            {
                name: "GPT-5.3-Codex-Spark",
                subtitle: "Weekly usage limit",
                percentRemaining: $sparkRemaining,
                resetLabel: $sparkReset,
                systemImage: "sparkles"
            }
        ]
    }' >"$temporary_usage"

/bin/mkdir -p "${usage_file:h}"
/bin/chmod 600 "$temporary_usage"
/bin/mv -f "$temporary_usage" "$usage_file"

print "Updated $usage_file: General ${general_remaining}% left, Spark ${spark_remaining}% left"
