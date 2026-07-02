#!/usr/bin/env bash
# stop hook: when the agent finishes AND non-doc source files changed this
# turn, inject a doc-drift reminder as a follow-up message so Cursor verifies
# AGENTS.md / CLAUDE.md / README.md before wrapping up.
#
# Cursor has no stop_hook_active field; loop_count 0 == first stop of the turn,
# so we use it to fire the reminder exactly once and avoid an infinite loop.
#
# Requires: jq, git
set -euo pipefail

input=$(cat)
status=$(echo "$input" | jq -r '.status // ""')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')
root=$(echo "$input" | jq -r '.workspace_roots[0] // ""')

# 1. Loop guard — only on a clean completion, only at the first stop.
[[ "$status" == "completed" ]] || exit 0
[[ "$loop_count" == "0" ]] || exit 0

# 2. Fire only when non-.md files changed (avoid friction on docs-only turns).
if [[ -z "$root" ]] || ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi
changed=$(git -C "$root" diff --name-only HEAD 2>/dev/null | grep -vE '\.(md)$' || echo "")
[ -z "$changed" ] && exit 0

# 3. Inject the reminder as the next user message.
reason="Code changes detected. Before finishing, review AGENTS.md, legacy CLAUDE.md (when present), and README.md for drift and update any outdated content — keep the existing section structure intact. Changed files:
${changed}"

jq -n --arg m "$reason" '{followup_message: $m}'
exit 0
