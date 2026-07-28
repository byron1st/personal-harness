#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "review-code-claude: $*" >&2
  exit 1
}

for dependency in git jq claude; do
  command -v "${dependency}" >/dev/null 2>&1 || fail "required command not found: ${dependency}"
done

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" || fail "run this skill inside a Git repository"
cd "${repo_root}"
git rev-parse --verify HEAD >/dev/null 2>&1 || fail "the repository must have at least one commit"

claude_config_dir="${CLAUDE_CONFIG_DIR:-${HOME}/.claude}"
claude_review_skill="${claude_config_dir}/skills/review-code/SKILL.md"
[[ -f "${claude_review_skill}" ]] || fail "Claude review skill not found: ${claude_review_skill}; install the Claude harness first"

reviewers=(
  security-reviewer
  reliability-reviewer
  maintainability-reviewer
  senior-generalist-reviewer
)
for reviewer in "${reviewers[@]}"; do
  reviewer_file="${claude_config_dir}/agents/${reviewer}.md"
  [[ -f "${reviewer_file}" ]] || fail "Claude reviewer agent not found: ${reviewer_file}; install the Claude harness first"
done

review_request="${*:-현재 브랜치와 main의 차이를 리뷰하라.}"
delegated_prompt="$(printf '%s\n\n%s\n' \
  '/review-code '"${review_request}" \
  '이 호출은 비대화형 delegated review다. 사용자에게 질문하지 말고 파일을 수정하거나 Accepted Review Exception을 기록하지 마라. 차단 이슈는 unclassified로 남기고 전체 리뷰 보고서만 반환하라.')"

temp_dir="$(mktemp -d)"
cleanup() {
  if [[ -n "${temp_dir:-}" && -d "${temp_dir}" ]]; then
    rm -r -- "${temp_dir}"
  fi
}
trap cleanup EXIT

capture_worktree() {
  local destination="$1"
  git status --porcelain=v2 --untracked-files=all >"${destination}.status"
  git diff --binary --no-ext-diff --no-textconv HEAD -- >"${destination}.diff"
  : >"${destination}.untracked"
  while IFS= read -r -d '' path; do
    printf '%s\0' "${path}" >>"${destination}.untracked"
    if [[ -L "${path}" ]]; then
      readlink "${path}" | git hash-object --stdin >>"${destination}.untracked"
    else
      git hash-object --no-filters -- "${path}" >>"${destination}.untracked"
    fi
  done < <(git ls-files --others --exclude-standard -z)
}

capture_worktree "${temp_dir}/before"

set +e
claude -p "${delegated_prompt}" \
  --permission-mode dontAsk \
  --allowedTools 'Agent,Read,Grep,Glob,Bash(git diff *),Bash(git status),Bash(git status *),Bash(git rev-parse *),Bash(git merge-base *),Bash(git ls-files *),Bash(git show *),Bash(git log *)' \
  --disallowedTools 'AskUserQuestion,Edit,Write,NotebookEdit,WebFetch,WebSearch' \
  --output-format json \
  --no-session-persistence \
  >"${temp_dir}/result.json"
claude_status=$?
set -e

capture_worktree "${temp_dir}/after"
if ! cmp -s "${temp_dir}/before.status" "${temp_dir}/after.status" ||
  ! cmp -s "${temp_dir}/before.diff" "${temp_dir}/after.diff" ||
  ! cmp -s "${temp_dir}/before.untracked" "${temp_dir}/after.untracked"; then
  fail "Claude changed the working tree; the runner did not revert those changes"
fi

if [[ ${claude_status} -ne 0 ]]; then
  echo "review-code-claude: Claude exited with status ${claude_status}" >&2
  exit "${claude_status}"
fi

jq -e '
  type == "object"
  and (.is_error == false)
  and (.result | type == "string" and test("\\S"))
  and (.result | contains("## Stage Status"))
  and (.result | contains("Overall Correctness:"))
  and (
    (.result | test("### \\[(CRITICAL|HIGH)\\]") | not)
    or (.result | test("REVIEW-[0-9]{3}"))
  )
' "${temp_dir}/result.json" >/dev/null ||
  fail "Claude returned invalid JSON or a report that does not satisfy the review-code output contract"

jq -r '.result' "${temp_dir}/result.json"
