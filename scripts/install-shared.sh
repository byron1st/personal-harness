#!/usr/bin/env bash
# Shared skill/script install helpers sourced by apply-to-{claude,codex,cursor,grok}.sh.
# Harness-owned skill names only — never wipe ~/.agents/skills or a platform skills dir.

HARNESS_SKILLS=(
  application-research-sync
  chat-summary
  commit-code
  dev-loop
  fix-dev
  implement-dev
  learn-from-manual-edits
  loki-log-search
  plan-dev
  review-code
  setup-initial-repo
  spec-creator
  test-dev
)

CLAUDE_SCRIPT_ALLOWS=(
  'Bash($HOME/.agents/scripts/detect-commands.sh *)'
  'Bash($HOME/.agents/scripts/resolve-scope.sh *)'
)

install_shared_skills() {
  local repo_skills="$1"
  local dest="${HOME}/.agents/skills"
  mkdir -p "${dest}"
  if [[ ! -d "${repo_skills}" ]]; then
    echo "Error: shared skills directory not found at ${repo_skills}" >&2
    return 1
  fi
  local name
  for name in "${HARNESS_SKILLS[@]}"; do
    rm -rf "${dest}/${name}"
    if [[ -d "${repo_skills}/${name}" ]]; then
      cp -R "${repo_skills}/${name}" "${dest}/${name}"
    else
      echo "Error: missing repo skill ${repo_skills}/${name}" >&2
      return 1
    fi
  done
}

install_shared_scripts() {
  local src="$1"
  local dest="${HOME}/.agents/scripts"
  mkdir -p "${dest}"
  if [[ ! -d "${src}" ]]; then
    echo "Error: runtime scripts directory not found at ${src}" >&2
    return 1
  fi
  find "${dest}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${src}" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${dest}/" \;
}

remove_platform_harness_skills() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 0
  local name
  for name in "${HARNESS_SKILLS[@]}"; do
    rm -rf "${dir}/${name}"
  done
}

link_claude_harness_skills() {
  local claude_skills="${HOME}/.claude/skills"
  local agents_skills="${HOME}/.agents/skills"
  mkdir -p "${claude_skills}"
  local name
  for name in "${HARNESS_SKILLS[@]}"; do
    local link="${claude_skills}/${name}"
    local target="${agents_skills}/${name}"
    rm -rf "${link}"
    if [[ -d "${target}" ]]; then
      ln -s "${target}" "${link}"
    fi
  done
}

append_claude_script_allows() {
  local settings="${HOME}/.claude/settings.json"
  if [[ ! -f "${settings}" ]]; then
    echo "Error: ${settings} missing; cannot append script allows" >&2
    return 1
  fi
  local tmp
  tmp=$(mktemp)
  # Append missing entries. Do not replace the allow array (jq * does).
  jq --argjson entries "$(printf '%s\n' "${CLAUDE_SCRIPT_ALLOWS[@]}" | jq -R . | jq -s .)" '
    .permissions = (.permissions // {})
    | .permissions.allow = (
        (.permissions.allow // []) as $a
        | $a + ($entries - $a)
      )
  ' "${settings}" > "${tmp}"
  mv "${tmp}" "${settings}"
}

count_shared_skills() {
  local dest="${HOME}/.agents/skills"
  local n=0 name
  for name in "${HARNESS_SKILLS[@]}"; do
    if [[ -d "${dest}/${name}" ]]; then
      n=$((n + 1))
    fi
  done
  printf '%s' "${n}"
}

count_shared_scripts() {
  local dest="${HOME}/.agents/scripts"
  if [[ ! -d "${dest}" ]]; then
    printf '0'
    return
  fi
  find "${dest}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' '
}
