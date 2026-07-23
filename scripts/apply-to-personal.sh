#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills/claude"
AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/claude"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

OPENCODE_SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills/opencode"
OPENCODE_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/opencode"
OPENCODE_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/opencode"

CLAUDE_HOME="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_HOME}/skills"
AGENTS_DIR="${CLAUDE_HOME}/agents"
HOOKS_DIR="${CLAUDE_HOME}/hooks"
INSTRUCTIONS_FILE="${CLAUDE_HOME}/CLAUDE.md"
SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

OPENCODE_HOME="${HOME}/.config/opencode"
OPENCODE_SKILLS_DIR="${OPENCODE_HOME}/skills"
OPENCODE_AGENTS_DIR="${OPENCODE_HOME}/agents"
OPENCODE_INSTRUCTIONS_FILE="${OPENCODE_HOME}/AGENTS.md"
OPENCODE_PLUGIN_FILE="${OPENCODE_HOME}/personal-harness.js"
if [[ -f "${OPENCODE_HOME}/opencode.jsonc" ]]; then
  OPENCODE_CONFIG_FILE="${OPENCODE_HOME}/opencode.jsonc"
else
  OPENCODE_CONFIG_FILE="${OPENCODE_HOME}/opencode.json"
fi

mkdir -p "${SKILLS_DIR}" "${AGENTS_DIR}" "${HOOKS_DIR}" "${OPENCODE_SKILLS_DIR}" "${OPENCODE_AGENTS_DIR}"

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
settings_status="✗ source not found"
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

# ── OpenCode ──
opencode_skills_count=0
opencode_agents_count=0
opencode_instructions_status="✗ not found"
opencode_plugin_status="✗ source not found"
opencode_config_status="✗ not found"

if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${OPENCODE_INSTRUCTIONS_FILE}"
  opencode_instructions_status="✓ installed"
fi

if [[ -d "${OPENCODE_SKILLS_SOURCE_DIR}" ]]; then
  find "${OPENCODE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${OPENCODE_SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${OPENCODE_SKILLS_DIR}/" \;
  opencode_skills_count=$(find "${OPENCODE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
fi

if [[ -d "${OPENCODE_AGENTS_SOURCE_DIR}" ]]; then
  find "${OPENCODE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${OPENCODE_AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${OPENCODE_AGENTS_DIR}/" \;
  opencode_agents_count=$(find "${OPENCODE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
fi

if [[ -f "${OPENCODE_HOOKS_SOURCE_DIR}/personal-harness.js" ]]; then
  cp -f "${OPENCODE_HOOKS_SOURCE_DIR}/personal-harness.js" "${OPENCODE_PLUGIN_FILE}"
  opencode_plugin_status="✓ installed"
fi

if [[ -f "${OPENCODE_CONFIG_FILE}" ]]; then
  if jq -e 'any(.plugin[]; . == "./personal-harness.js" or (type == "array" and .[0] == "./personal-harness.js"))' "${OPENCODE_CONFIG_FILE}" >/dev/null 2>&1; then
    opencode_config_status="✓ plugin registered"
  else
    opencode_config_status="⚠ plugin not registered in opencode.json"
  fi
fi

echo ""
echo "Personal harness applied:"
echo "  Claude Code skills:       ${skills_count} directories installed to ${SKILLS_DIR}"
echo "  Claude Code instructions: ${claude_md}"
echo "  Claude Code sub-agents:   ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Claude Code hook scripts: ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Claude Code settings:     ${settings_status}"
echo ""
echo "  OpenCode skills:          ${opencode_skills_count} directories installed to ${OPENCODE_SKILLS_DIR}"
echo "  OpenCode instructions:    ${opencode_instructions_status}"
echo "  OpenCode sub-agents:      ${opencode_agents_count} files installed to ${OPENCODE_AGENTS_DIR}"
echo "  OpenCode plugin:          ${opencode_plugin_status}"
echo "  OpenCode config:          ${opencode_config_status}"
