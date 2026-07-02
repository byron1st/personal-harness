#!/usr/bin/env bash
# sessionStart hook: classify the repository as personal or work and inject
# that as session-scoped context.
#
# Env vars used: WORK_GITLAB_HOST, WORK_GIT_EMAIL, WORK_GIT_NAME,
#                PERSONAL_GIT_EMAIL, PERSONAL_GIT_NAME
# Requires: jq, git
set -euo pipefail

input=$(cat)
root=$(echo "$input" | jq -r '.workspace_roots[0] // .cwd // ""')

[[ -n "$root" ]] || exit 0

remote=""
branch=""
actual_email=""
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
  remote=$(git -C "$root" remote get-url origin 2>/dev/null || echo "")
  branch=$(git -C "$root" branch --show-current 2>/dev/null || echo "")
  actual_email=$(git -C "$root" config user.email 2>/dev/null || echo "")
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

context=$(cat <<EOF
Session repository classification:
- repo_type: ${repo_type}
- cwd: ${root}
- origin: ${remote:-<none>}
- branch: ${branch:-<none>}
- classification_rule: ${classification_rule}
- expected_commit_identity: ${expected_name:-<unset>} <${expected_email:-<unset>}>
- current_git_email: ${actual_email:-<unset>}

Use repo_type as session-scoped context. If you have not already done so, mention once to the user near the start of the session that this repository was detected as ${repo_type}. When committing or using commit-code, follow the ${repo_type} path: verify git user.name and user.email against the expected ${repo_type} identity, extract a Jira key from the branch only for work repositories, and do not push unless the user explicitly asks.
EOF
)

jq -n --arg ctx "$context" '{continue:true,additional_context:$ctx}'
