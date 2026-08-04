#!/usr/bin/env bash
# SessionStart hook (Grok Build): classify the repository as personal or work.
# SessionStart stdout is ignored on Grok — global instructions live in
# ~/.grok/rules/AGENTS.md (installed by apply-to-grok.sh), not via this hook.
#
# Env vars used: WORK_GITLAB_HOST, WORK_GIT_EMAIL, WORK_GIT_NAME,
#                PERSONAL_GIT_EMAIL, PERSONAL_GIT_NAME
# Requires: jq, git
set -euo pipefail

input=$(cat)
# Grok SessionStart uses camelCase; accept snake_case fallbacks for safety.
cwd=$(echo "$input" | jq -r '.cwd // .workspaceRoot // .workspace_root // empty')

[[ -n "$cwd" ]] || exit 0

remote=""
branch=""
actual_email=""
if git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")
  branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "")
  actual_email=$(git -C "$cwd" config user.email 2>/dev/null || echo "")
fi

repo_type="personal"
classification_rule="origin remote did not match WORK_GITLAB_HOST"
if [[ -n "${WORK_GITLAB_HOST:-}" && "$remote" == *"$WORK_GITLAB_HOST"* ]]; then
  repo_type="work"
  classification_rule="origin remote matched WORK_GITLAB_HOST"
elif [[ -z "$remote" ]]; then
  classification_rule="no origin remote; defaulted to personal"
elif [[ -z "${WORK_GITLAB_HOST:-}" ]]; then
  classification_rule="WORK_GITLAB_HOST unset; defaulted to personal"
fi

if [[ "$repo_type" == "work" ]]; then
  expected_email="${WORK_GIT_EMAIL:-}"
  expected_name="${WORK_GIT_NAME:-}"
else
  expected_email="${PERSONAL_GIT_EMAIL:-}"
  expected_name="${PERSONAL_GIT_NAME:-}"
fi

# Log only — Grok SessionStart does not inject additionalContext from stdout.
echo "[session-context] repo_type=${repo_type} cwd=${cwd} origin=${remote:-none} branch=${branch:-none} rule=${classification_rule} expected=${expected_name:-unset} <${expected_email:-unset}> current_email=${actual_email:-unset}" >&2
exit 0
