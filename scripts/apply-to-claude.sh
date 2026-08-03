#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills/claude"
AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/claude"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

CLAUDE_HOME="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_HOME}/skills"
AGENTS_DIR="${CLAUDE_HOME}/agents"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
SCRIPTS_DIR="${CLAUDE_HOME}/scripts"
INSTRUCTIONS_FILE="${CLAUDE_HOME}/CLAUDE.md"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

mkdir -p "${SKILLS_DIR}" "${AGENTS_DIR}" "${HOOKS_DIR}" "${SCRIPTS_DIR}"

claude_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  claude_md="✓ installed"
fi

if [[ ! -d "${SKILLS_SOURCE_DIR}" ]]; then
  echo "Error: Claude skills directory not found at ${SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

echo "Cleaning existing Claude skills..."
find "${SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${SKILLS_DIR}/" \;
skills_count=$(find "${SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

agents_status="✗ source not found"
hooks_status="✗ source not found"
scripts_status="✗ source not found"
settings_status="✗ source not found"
agents_count=0
hooks_count=0
scripts_count=0

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

# Runtime scripts the skills call at execution time. `-p` preserves the
# executable bit, same reason the hooks block above uses it.
if [[ -d "${SCRIPTS_SOURCE_DIR}" ]]; then
  find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${SCRIPTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${SCRIPTS_DIR}/" \;
  scripts_count=$(find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  scripts_status="✓ installed"
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
echo "  Claude Code skills:       ${skills_count} directories installed to ${SKILLS_DIR}"
echo "  Claude Code instructions: ${claude_md}"
echo "  Claude Code sub-agents:   ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Claude Code hook scripts: ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Claude Code run scripts:  ${scripts_count} files installed to ${SCRIPTS_DIR} (${scripts_status})"
echo "  Claude Code settings:     ${settings_status}"
echo ""
