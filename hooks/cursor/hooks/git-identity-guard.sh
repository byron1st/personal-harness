#!/usr/bin/env bash
# beforeShellExecution hook: verify git user.email matches the repo type
# (personal vs work) before `git commit` or `git push`. Denies via JSON
# permission so the fix instructions reach the agent (agent_message).
#
# Env vars used: WORK_GITLAB_HOST, WORK_GIT_EMAIL, WORK_GIT_NAME,
#                PERSONAL_GIT_EMAIL, PERSONAL_GIT_NAME
# Requires: jq
set -euo pipefail

allow() { printf '{"permission":"allow"}\n'; exit 0; }

input=$(cat)
cmd=$(echo "$input" | jq -r '.command // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')

if ! echo "$cmd" | grep -qE '(^|[^a-zA-Z])git[[:space:]]+(commit|push)'; then
  allow
fi

if [[ -z "$cwd" ]] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  allow
fi

remote=$(git -C "$cwd" remote get-url origin 2>/dev/null || echo "")

if [[ -n "${WORK_GITLAB_HOST:-}" && "$remote" == *"$WORK_GITLAB_HOST"* ]]; then
  expected_email="${WORK_GIT_EMAIL:-}"
  expected_name="${WORK_GIT_NAME:-}"
  identity_type="work"
else
  expected_email="${PERSONAL_GIT_EMAIL:-}"
  expected_name="${PERSONAL_GIT_NAME:-}"
  identity_type="personal"
fi

if [[ -z "$expected_email" ]]; then
  allow
fi

actual_email=$(git -C "$cwd" config user.email 2>/dev/null || echo "")

if [[ "$actual_email" == "$expected_email" ]]; then
  allow
fi

agent_msg=$(cat <<EOF
Git identity mismatch — blocking commit/push.
  Repo type:   $identity_type
  Remote URL:  ${remote:-<none>}
  Expected:    $expected_email
  Actual:      ${actual_email:-<unset>}

Fix with:
  git -C "$cwd" config user.email "$expected_email"
  git -C "$cwd" config user.name  "$expected_name"
EOF
)
jq -n --arg am "$agent_msg" \
  '{permission:"deny", user_message:"Git identity mismatch — blocking commit/push.", agent_message:$am}'
exit 0
