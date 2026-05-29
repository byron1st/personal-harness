#!/usr/bin/env bash
# stop hook (paired with beforeSubmitPrompt/doc-drift-flag.sh): if the user
# signaled wrap-up earlier this conversation AND source files changed without
# README/AGENTS/CLAUDE.md updates, inject a sync reminder as the next user
# message (followup_message) so the agent verifies docs before finishing.
#
# Requires: jq, git
set -euo pipefail

input=$(cat)
status=$(echo "$input" | jq -r '.status // ""')
loop_count=$(echo "$input" | jq -r '.loop_count // 0')
conv=$(echo "$input" | jq -r '.conversation_id // ""')
root=$(echo "$input" | jq -r '.workspace_roots[0] // ""')

# Act only on a clean completion, only once (loop_count 0), and only if the
# user signaled wrap-up earlier (flag present for this conversation).
[[ "$status" == "completed" ]] || exit 0
[[ "$loop_count" == "0" ]] || exit 0

flag="${TMPDIR:-/tmp}/cursor-docdrift/${conv}"
[[ -n "$conv" && -f "$flag" ]] || exit 0
# Consume the flag — one reminder per wrap-up signal.
rm -f "$flag"

if [[ -z "$root" ]] || ! git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Pick an upstream baseline to diff against (for committed-but-unpushed work).
upstream=""
if git -C "$root" rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
  upstream="@{u}"
elif git -C "$root" rev-parse --verify --quiet "origin/main" >/dev/null 2>&1; then
  upstream="origin/main"
elif git -C "$root" rev-parse --verify --quiet "origin/master" >/dev/null 2>&1; then
  upstream="origin/master"
fi

uncommitted=$(git -C "$root" diff --name-only HEAD 2>/dev/null || echo "")
committed=""
if [[ -n "$upstream" ]]; then
  committed=$(git -C "$root" diff --name-only "$upstream"...HEAD 2>/dev/null || echo "")
fi
changed=$(printf "%s\n%s" "$uncommitted" "$committed" | grep -v '^$' | sort -u || echo "")

if [[ -z "$changed" ]]; then
  exit 0
fi

docs_changed=$(echo "$changed" | grep -iE '(^|/)(README|AGENTS|CLAUDE)\.md$' || echo "")
src_changed=$(echo "$changed" | grep -vE '(^|/)(README|AGENTS|CLAUDE)\.md$' | grep -vE '^docs/' || echo "")

if [[ -n "$src_changed" && -z "$docs_changed" ]]; then
  msg="Doc-drift check: source files changed but README.md / AGENTS.md / CLAUDE.md were NOT updated. Per global rule, verify whether these need syncing before wrapping up. Changed source files (truncated):
$(echo "$src_changed" | head -10)"

  jq -n --arg m "$msg" '{followup_message: $m}'
fi
exit 0
