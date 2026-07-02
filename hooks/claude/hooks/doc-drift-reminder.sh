#!/usr/bin/env bash
# Stop hook: when the agent is about to finish AND non-doc source files
# changed this turn, block the stop and inject a doc-drift reminder so Claude
# verifies AGENTS.md / CLAUDE.md / README.md before wrapping up.
#
# Requires: jq
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // ""')

# 1. Loop guard — skip if this turn was already continued by a Stop hook.
[ "$(echo "$input" | jq -r '.stop_hook_active')" = "true" ] && exit 0

# 2. Fire only when non-.md files changed (avoid friction on docs-only turns).
if [[ -z "$cwd" ]] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi
changed=$(git -C "$cwd" diff --name-only HEAD 2>/dev/null | grep -vE '\.(md)$' || echo "")
[ -z "$changed" ] && exit 0

# 3. Block the stop with a concrete, file-scoped reason.
reason="Code changes detected. Before finishing, review AGENTS.md, legacy CLAUDE.md (when present), and README.md for drift and update any outdated content — keep the existing section structure intact. Changed files:
${changed}"

jq -n --arg r "$reason" '{decision: "block", reason: $r}'
