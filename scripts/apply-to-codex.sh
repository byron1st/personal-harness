#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills"
CODEX_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/codex"
CODEX_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/codex"
RUNTIME_SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

CODEX_HOME="${HOME}/.codex"
CODEX_AGENTS_DIR="${CODEX_HOME}/agents"
CODEX_HOOKS_DIR="${CODEX_HOME}/hooks"
CODEX_INSTRUCTIONS_FILE="${CODEX_HOME}/AGENTS.md"
CODEX_HOOKS_FILE="${CODEX_HOME}/hooks.json"

mkdir -p "${CODEX_AGENTS_DIR}" "${CODEX_HOOKS_DIR}" "${HOME}/.codex/skills"

codex_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${CODEX_INSTRUCTIONS_FILE}"
  codex_md="✓ installed"
fi

echo "Installing shared skills to ~/.agents/skills..."
install_shared_skills "${SKILLS_SOURCE_DIR}"
install_shared_scripts "${RUNTIME_SCRIPTS_SOURCE_DIR}"
remove_platform_harness_skills "${HOME}/.codex/skills"
skills_count=$(count_shared_skills)
scripts_count=$(count_shared_scripts)

codex_agents_status="✗ source not found"
codex_hooks_status="✗ source not found"
codex_hooks_json_status="✗ source not found"
codex_agents_count=0
codex_hooks_count=0

if [[ -d "${CODEX_AGENTS_SOURCE_DIR}" ]]; then
  find "${CODEX_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CODEX_AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -name "*.toml" -exec cp -f {} "${CODEX_AGENTS_DIR}/" \;
  codex_agents_count=$(find "${CODEX_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -name "*.toml" | wc -l | tr -d ' ')
  codex_agents_status="✓ installed"
fi

if [[ -d "${CODEX_HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${CODEX_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CODEX_HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${CODEX_HOOKS_DIR}/" \;
  codex_hooks_count=$(find "${CODEX_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  codex_hooks_status="✓ installed"
fi

if [[ -f "${CODEX_HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${CODEX_HOOKS_SOURCE_DIR}/hooks.json" "${CODEX_HOOKS_FILE}"
  codex_hooks_json_status="✓ installed"
fi

echo "Codex harness applied:"
echo "  Shared skills:       ${skills_count} directories in ${HOME}/.agents/skills"
echo "  Codex skills dir:    harness names removed from ${HOME}/.codex/skills (native ~/.agents/skills)"
echo "  Shared runtime scripts: ${scripts_count} files in ${HOME}/.agents/scripts"
echo "  Codex instructions: ${codex_md}"
echo "  Codex custom agents: ${codex_agents_count} files installed to ${CODEX_AGENTS_DIR} (${codex_agents_status})"
echo "  Codex hook scripts:  ${codex_hooks_count} files installed to ${CODEX_HOOKS_DIR} (${codex_hooks_status})"
echo "  Codex hooks.json:    ${codex_hooks_json_status}"
echo ""
