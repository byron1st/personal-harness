#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

CLAUDE_HOME="${HOME}/.claude"
AGENTS_DIR="${CLAUDE_HOME}/agents"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
INSTRUCTIONS_FILE="${CLAUDE_HOME}/CLAUDE.md"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

mkdir -p "${HOOKS_DIR}" "${CLAUDE_HOME}/skills"

claude_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  claude_md="✓ installed"
fi

link_claude_harness_skills
remove_retired_agents "${AGENTS_DIR}" md
skills_count=$(count_shared_skills)

hooks_status="✗ source not found"
settings_status="✗ source not found"
hooks_count=0

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

echo "Claude harness applied:"
echo "  Shared skills:            ${skills_count} directories in ${HOME}/.agents/skills"
echo "  Claude skill symlinks:    per-skill links in ${CLAUDE_HOME}/skills → ~/.agents/skills"
echo "  Claude Code instructions: ${claude_md}"
echo "  Retired harness agents:   removed from ${AGENTS_DIR}"
echo "  Claude Code hook scripts: ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Claude Code settings:     ${settings_status}"
echo ""
