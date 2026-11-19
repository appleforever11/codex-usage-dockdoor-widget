#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p "$ROOT/build/tests"
swiftc -parse-as-library "$ROOT/Widgets/CodexProjectTracker/ClaudeUsage.swift" "$ROOT/Tests/ClaudeUsageTests.swift" -o "$ROOT/build/tests/claude-usage"
"$ROOT/build/tests/claude-usage"
