#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/grok"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/grok"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
RUNTIME_SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

GROK_HOME="${HOME}/.grok"
AGENTS_DIR="${GROK_HOME}/agents"
HOOKS_DIR="${GROK_HOME}/hooks"
RULES_DIR="${GROK_HOME}/rules"
INSTRUCTIONS_FILE="${RULES_DIR}/AGENTS.md"
GROK_CONFIG="${GROK_HOME}/config.toml"

mkdir -p "${AGENTS_DIR}" "${HOOKS_DIR}" "${RULES_DIR}" "${HOME}/.grok/skills"

instructions_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  instructions_md="✓ installed"
fi

install_shared_scripts "${RUNTIME_SCRIPTS_SOURCE_DIR}"
remove_platform_harness_skills "${HOME}/.grok/skills"
skills_count=$(count_shared_skills)
scripts_count=$(count_shared_scripts)

agents_status="✗ source not found"
hooks_status="✗ source not found"
hooks_json_status="✗ source not found"
agents_count=0
hooks_count=0

if [[ -d "${AGENTS_SOURCE_DIR}" ]]; then
  find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" -exec cp -f {} "${AGENTS_DIR}/" \;
  agents_count=$(find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" | wc -l | tr -d ' ')
  agents_status="✓ installed"
fi

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
echo "  Shared runtime scripts:   ${scripts_count} files in ${HOME}/.agents/scripts"
echo "  Grok instructions:      ${instructions_md} to ${INSTRUCTIONS_FILE}"
echo "  Grok agents:            ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Grok hook scripts:      ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Grok hooks harness.json:${hooks_json_status}"
echo "  Grok [skills] paths:    ${skills_paths_status}"
echo ""
echo "Required one-time config (installer cannot set this for you):"
echo "  In ~/.grok/config.toml set [compat.claude] and [compat.cursor] cells to false"
echo "  (skills, rules, agents, mcps, hooks, sessions) so pure Grok paths are used."
echo "  Session habits: plan-dev → grok-4.6 / xhigh; dev-loop → grok-4.6 / medium."
echo ""
