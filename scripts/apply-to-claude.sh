#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/claude"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
RUNTIME_SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

CLAUDE_HOME="${HOME}/.claude"
AGENTS_DIR="${CLAUDE_HOME}/agents"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
INSTRUCTIONS_FILE="${CLAUDE_HOME}/CLAUDE.md"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

mkdir -p "${AGENTS_DIR}" "${HOOKS_DIR}" "${CLAUDE_HOME}/skills"

claude_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  claude_md="✓ installed"
fi

install_shared_scripts "${RUNTIME_SCRIPTS_SOURCE_DIR}"
link_claude_harness_skills
skills_count=$(count_shared_skills)
scripts_count=$(count_shared_scripts)

agents_status="✗ source not found"
hooks_status="✗ source not found"
settings_status="✗ source not found"
allow_status="✗ not appended"
agents_count=0
hooks_count=0

if [[ -d "${AGENTS_SOURCE_DIR}" ]]; then
  find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${AGENTS_DIR}/" \;
  agents_count=$(find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  agents_status="✓ installed"
fi

if [[ -d "${HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${HOOKS_DIR}/" \;
  hooks_count=$(find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  hooks_status="✓ installed"
fi

if [[ -f "${HOOKS_SOURCE_DIR}/settings.json" ]]; then
  if [[ -f "${SETTINGS_FILE}" ]]; then
    tmp_settings=$(mktemp)
    jq -s '.[0] * .[1]' "${SETTINGS_FILE}" "${HOOKS_SOURCE_DIR}/settings.json" > "${tmp_settings}"
    mv "${tmp_settings}" "${SETTINGS_FILE}"
    settings_status="✓ merged"
  else
    cp -f "${HOOKS_SOURCE_DIR}/settings.json" "${SETTINGS_FILE}"
    settings_status="✓ created"
  fi
fi

if append_claude_script_allows; then
  allow_status="✓ appended"
fi

echo "Claude harness applied:"
echo "  Shared skills:            ${skills_count} directories in ${HOME}/.agents/skills"
echo "  Claude skill symlinks:    per-skill links in ${CLAUDE_HOME}/skills → ~/.agents/skills"
echo "  Shared runtime scripts:   ${scripts_count} files in ${HOME}/.agents/scripts"
echo "  Claude Code instructions: ${claude_md}"
echo "  Claude Code sub-agents:   ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Claude Code hook scripts: ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Claude Code settings:     ${settings_status}"
echo "  Claude script allows:     ${allow_status}"
echo ""
