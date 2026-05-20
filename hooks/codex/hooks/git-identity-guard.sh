#!/usr/bin/env bash
# PreToolUse hook for Bash: verify git user.email matches the repo type
# (personal vs work) before `git commit` or `git push`.
#
# Env vars used: WORK_GITLAB_HOST, WORK_GIT_EMAIL, WORK_GIT_NAME,
#                PERSONAL_GIT_EMAIL, PERSONAL_GIT_NAME
# Requires: jq
set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
cwd=$(echo "$input" | jq -r '.cwd // ""')

if ! echo "$cmd" | grep -qE '(^|[^a-zA-Z])git[[:space:]]+(commit|push)'; then
  exit 0
fi

if [[ -z "$cwd" ]] || ! git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  exit 0
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
  exit 0
fi

actual_email=$(git -C "$cwd" config user.email 2>/dev/null || echo "")

if [[ "$actual_email" != "$expected_email" ]]; then
  cat >&2 <<EOF
Git identity mismatch — blocking commit/push.
  Repo type:   $identity_type
  Remote URL:  ${remote:-<none>}
  Expected:    $expected_email
  Actual:      ${actual_email:-<unset>}

Fix with:
  git -C "$cwd" config user.email "$expected_email"
  git -C "$cwd" config user.name  "$expected_name"
EOF
  exit 2
fi
