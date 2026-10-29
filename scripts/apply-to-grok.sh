#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/grok"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

GROK_HOME="${HOME}/.grok"
AGENTS_DIR="${GROK_HOME}/agents"
HOOKS_DIR="${GROK_HOME}/hooks"
RULES_DIR="${GROK_HOME}/rules"
INSTRUCTIONS_FILE="${RULES_DIR}/AGENTS.md"
GROK_CONFIG="${GROK_HOME}/config.toml"

mkdir -p "${HOOKS_DIR}" "${RULES_DIR}" "${HOME}/.grok/skills"

instructions_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  instructions_md="✓ installed"
fi

remove_platform_harness_skills "${HOME}/.grok/skills"
remove_retired_agents "${AGENTS_DIR}" md
skills_count=$(count_shared_skills)

hooks_status="✗ source not found"
hooks_json_status="✗ source not found"
hooks_count=0

if [[ -d "${HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 \( -type f -o -type d \) ! -name '*.json' -exec rm -rf {} + 2>/dev/null || true
  # Install hook scripts into ~/.grok/hooks/ (same dir as harness.json)
  find "${HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${HOOKS_DIR}/" \;
  hooks_count=$(find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')
  hooks_status="✓ installed"
fi

# Grok merges all ~/.grok/hooks/*.json — install harness as its own file.
if [[ -f "${HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${HOOKS_SOURCE_DIR}/hooks.json" "${HOOKS_DIR}/harness.json"
  hooks_json_status="✓ installed"
fi

# If grok inspect is available and user-tier scan misses ~/.agents/skills,
# add [skills] paths only when that key is absent. Native scan + paths = double load.
skills_paths_status="skipped (grok inspect not available or native scan present)"
if command -v grok >/dev/null 2>&1; then
  inspect_out="$(grok inspect 2>/dev/null || true)"
  if [[ -n "${inspect_out}" ]]; then
    if printf '%s' "${inspect_out}" | rg -q "${HOME}/.agents/skills"; then
      skills_paths_status="native scan sees ~/.agents/skills — not adding [skills] paths"
    else
      mkdir -p "${GROK_HOME}"
      if [[ -f "${GROK_CONFIG}" ]] && rg -q '^\[skills\]' "${GROK_CONFIG}"; then
        skills_paths_status="~/.grok/config.toml already has [skills] — left unchanged"
      else
        {
          [[ -f "${GROK_CONFIG}" ]] && cat "${GROK_CONFIG}"
          printf '\n[skills]\npaths = ["~/.agents/skills"]\n'
        } > "${GROK_CONFIG}.tmp"
        mv "${GROK_CONFIG}.tmp" "${GROK_CONFIG}"
        skills_paths_status="added [skills] paths = [\"~/.agents/skills\"] (inspect did not list it)"
      fi
    fi
  fi
fi

echo "Grok Build harness applied:"
echo "  Shared skills:            ${skills_count} directories in ${HOME}/.agents/skills"
echo "  Grok skills dir:          harness names removed from ${HOME}/.grok/skills (native ~/.agents/skills)"
echo "  Grok instructions:      ${instructions_md} to ${INSTRUCTIONS_FILE}"
echo "  Retired harness agents: removed from ${AGENTS_DIR}"
echo "  Grok hook scripts:      ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Grok hooks harness.json:${hooks_json_status}"
echo "  Grok [skills] paths:    ${skills_paths_status}"
echo ""
echo "Required one-time config (installer cannot set this for you):"
echo "  In ~/.grok/config.toml set [compat.claude] and [compat.cursor] cells to false"
echo "  (skills, rules, agents, mcps, hooks, sessions) so pure Grok paths are used."
echo ""
