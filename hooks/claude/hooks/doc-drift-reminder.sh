#!/usr/bin/env bash
# UserPromptSubmit hook: when the prompt signals task completion AND source
# files were changed without README/AGENTS/CLAUDE.md updates, inject a sync
# reminder so Claude verifies the docs before wrapping up.
#
# Requires: jq
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // ""')
prompt=$(echo "$input" | jq -r '.prompt // ""')

# Trigger signals:
#   (a) Completion phrases (Korean + English) — safety net, kept narrow.
#   (b) request-merge skill invocation — primary signal for this workflow.
#       Detects both explicit slash (`/request-merge`) and natural-language
#       triggers Claude uses to match the skill ("PR 만들어줘", "MR 올려줘",
#       "pull/merge request" 등).
if ! echo "$prompt" | grep -iqE '(끝났어|끝났다|마무리하|마무리할|wrap.?up|all done|ship it|이제 끝|모두 완료|finished up|/request-merge|PR[[:space:]]*(만들|올리|생성|요청|올려)|MR[[:space:]]*(만들|올리|생성|요청|올려)|(pull|merge)[[:space:]]?request)'; then
  exit 0
fi

if [[ -z "$cwd" ]] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
fi

# Pick an upstream baseline to diff against (for committed-but-unpushed work)
upstream=""
if git -C "$cwd" rev-parse --verify --quiet "@{u}" >/dev/null 2>&1; then
  upstream="@{u}"
elif git -C "$cwd" rev-parse --verify --quiet "origin/main" >/dev/null 2>&1; then
  upstream="origin/main"
elif git -C "$cwd" rev-parse --verify --quiet "origin/master" >/dev/null 2>&1; then
  upstream="origin/master"
fi

uncommitted=$(git -C "$cwd" diff --name-only HEAD 2>/dev/null || echo "")
committed=""
if [[ -n "$upstream" ]]; then
  committed=$(git -C "$cwd" diff --name-only "$upstream"...HEAD 2>/dev/null || echo "")
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

  jq -n --arg ctx "$msg" '{
    hookSpecificOutput: {
      hookEventName: "UserPromptSubmit",
      additionalContext: $ctx
    }
  }'
fi
