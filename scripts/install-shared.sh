#!/usr/bin/env bash
# Shared skill install helpers sourced by apply-to.sh and apply-to-{claude,codex,cursor,grok}.sh.
# Harness-owned skill names only — never wipe ~/.agents/skills or a platform skills dir.
# install_shared_skills is called only from apply-to.sh (once per invocation).

HARNESS_SKILLS=(
  chat-summary
  commit-code
  learn-from-manual-edits
  loki-log-search
  notion-daily-briefing
  plan-dev
  setup-initial-repo
  spec-creator
  test-dev
)

# Third-party skills installed via `npx skills add` as "<source>|<skill>".
EXTERNAL_SKILLS=(
  'makenotion/skills|notion-cli'
)

# Removed from the harness. Deleted from install targets so old copies stop loading.
RETIRED_SKILLS=(
  application-research-sync
  dev-loop
  fix-dev
  implement-dev
  review-code
)

RETIRED_AGENTS=(
  fixer
  implementer
  maintainability-reviewer
  plan-consultant
  planner
  reliability-reviewer
  security-reviewer
  senior-generalist-reviewer
  tester
)

RETIRED_SCRIPTS=(
  detect-commands.sh
  resolve-scope.sh
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
  for name in "${RETIRED_SKILLS[@]}"; do
    rm -rf "${dest}/${name}"
  done
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

# `-g -a universal` installs into ~/.agents/skills (the other agents read it natively).
install_external_skills() {
  local entry
  for entry in "${EXTERNAL_SKILLS[@]}"; do
    npx --yes skills add "${entry%%|*}" --skill "${entry##*|}" -g -a universal -y
  done
}

remove_retired_scripts() {
  local name
  for name in "${RETIRED_SCRIPTS[@]}"; do
    rm -f "${HOME}/.agents/scripts/${name}"
  done
}

# $1 = platform agents dir, $2 = agent file extension (md | toml)
remove_retired_agents() {
  local dir="$1" ext="$2"
  [[ -d "${dir}" ]] || return 0
  local name
  for name in "${RETIRED_AGENTS[@]}"; do
    rm -f "${dir}/${name}.${ext}"
  done
}

remove_platform_harness_skills() {
  local dir="$1"
  [[ -d "${dir}" ]] || return 0
  local name
  for name in "${HARNESS_SKILLS[@]}" "${RETIRED_SKILLS[@]}"; do
    rm -rf "${dir}/${name}"
  done
}

# Retired names have no target left, so their links are removed and not recreated.
link_claude_harness_skills() {
  local claude_skills="${HOME}/.claude/skills"
  local agents_skills="${HOME}/.agents/skills"
  mkdir -p "${claude_skills}"
  local name
  for name in "${HARNESS_SKILLS[@]}" "${EXTERNAL_SKILLS[@]##*|}" "${RETIRED_SKILLS[@]}"; do
    local link="${claude_skills}/${name}"
    local target="${agents_skills}/${name}"
    rm -rf "${link}"
    if [[ -d "${target}" ]]; then
      ln -s "${target}" "${link}"
    fi
  done
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
