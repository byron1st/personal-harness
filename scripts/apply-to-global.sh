#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source paths inside this repository
SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

CLAUDE_SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR}/claude"
CLAUDE_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/claude"
CLAUDE_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"

CODEX_SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR}/codex"
CODEX_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/codex"
CODEX_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/codex"

# Install targets under each agent home
CLAUDE_HOME="${HOME}/.claude"
CLAUDE_SKILLS_DIR="${CLAUDE_HOME}/skills"
CLAUDE_AGENTS_DIR="${CLAUDE_HOME}/agents"
CLAUDE_HOOKS_DIR="${CLAUDE_HOME}/hooks"
CLAUDE_INSTRUCTIONS_FILE="${CLAUDE_HOME}/CLAUDE.md"
CLAUDE_SETTINGS_FILE="${CLAUDE_HOME}/settings.json"

CODEX_HOME="${HOME}/.codex"
CODEX_SKILLS_DIR="${CODEX_HOME}/skills"
CODEX_AGENTS_DIR="${CODEX_HOME}/agents"
CODEX_HOOKS_DIR="${CODEX_HOME}/hooks"
CODEX_INSTRUCTIONS_FILE="${CODEX_HOME}/AGENTS.md"
CODEX_HOOKS_FILE="${CODEX_HOME}/hooks.json"

# Ensure target directory exists
mkdir -p "${CLAUDE_SKILLS_DIR}"
mkdir -p "${CODEX_SKILLS_DIR}"
mkdir -p "${CLAUDE_AGENTS_DIR}"
mkdir -p "${CLAUDE_HOOKS_DIR}"
mkdir -p "${CODEX_AGENTS_DIR}"
mkdir -p "${CODEX_HOOKS_DIR}"

# Copy global instructions to CLAUDE.md
claude_md="✗ not found"
codex_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${CLAUDE_INSTRUCTIONS_FILE}"
  claude_md="✓ installed"

  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${CODEX_INSTRUCTIONS_FILE}"
  codex_md="✓ installed"
fi

# Verify source directory exists
if [[ ! -d "$SKILLS_SOURCE_DIR" ]]; then
  echo "Error: skills directory not found at ${SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

# Clean existing skills
echo "Cleaning existing skills..."
find "${CLAUDE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${CODEX_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +

# Copy skills
if [[ -d "${CLAUDE_SKILLS_SOURCE_DIR}" ]]; then
  find "${CLAUDE_SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CLAUDE_SKILLS_DIR}/" \;
else
  find "${SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CLAUDE_SKILLS_DIR}/" \;
fi
claude_skills_count=$(find "${CLAUDE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
if [[ -d "${CODEX_SKILLS_SOURCE_DIR}" ]]; then
  find "${CODEX_SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CODEX_SKILLS_DIR}/" \;
else
  find "${SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CODEX_SKILLS_DIR}/" \;
fi
codex_skills_count=$(find "${CODEX_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

# Sync platform-specific agents and hooks
claude_agents_status="✗ source not found"
claude_hooks_status="✗ source not found"
claude_settings_status="✗ source not found"
codex_agents_status="✗ source not found"
codex_hooks_status="✗ source not found"
codex_hooks_json_status="✗ source not found"
claude_agents_count=0
claude_hooks_count=0
codex_agents_count=0
codex_hooks_count=0

if [[ -d "${CLAUDE_AGENTS_SOURCE_DIR}" ]]; then
  find "${CLAUDE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CLAUDE_AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CLAUDE_AGENTS_DIR}/" \;
  claude_agents_count=$(find "${CLAUDE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  claude_agents_status="✓ installed"
fi

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

if [[ -d "${CLAUDE_HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${CLAUDE_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CLAUDE_HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${CLAUDE_HOOKS_DIR}/" \;
  claude_hooks_count=$(find "${CLAUDE_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  claude_hooks_status="✓ installed"
fi

if [[ -f "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" ]]; then
  if [[ -f "${CLAUDE_SETTINGS_FILE}" ]]; then
    tmp_settings=$(mktemp)
    jq -s '.[0] * .[1]' "${CLAUDE_SETTINGS_FILE}" "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" > "${tmp_settings}"
    mv "${tmp_settings}" "${CLAUDE_SETTINGS_FILE}"
    claude_settings_status="✓ merged"
  else
    cp -f "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" "${CLAUDE_SETTINGS_FILE}"
    claude_settings_status="✓ created"
  fi
fi

# Report
echo ""
echo "Agent skills applied:"
echo "  Claude Code:  ${claude_skills_count} directories installed to ${CLAUDE_SKILLS_DIR}"
echo "  Codex:        ${codex_skills_count} directories installed to ${CODEX_SKILLS_DIR}"
echo "Global instructions applied:"
echo "  Claude Code: ${claude_md}"
echo "  Codex: ${codex_md}"
echo "Claude-specific extras:"
echo "  Sub-agents:     ${claude_agents_count} files installed to ${CLAUDE_AGENTS_DIR} (${claude_agents_status})"
echo "  Hook scripts:   ${claude_hooks_count} files installed to ${CLAUDE_HOOKS_DIR} (${claude_hooks_status})"
echo "  settings.json:  ${claude_settings_status}"
echo "Codex-specific extras:"
echo "  Custom agents:  ${codex_agents_count} files installed to ${CODEX_AGENTS_DIR} (${codex_agents_status})"
echo "  Hook scripts:   ${codex_hooks_count} files installed to ${CODEX_HOOKS_DIR} (${codex_hooks_status})"
echo "  hooks.json:     ${codex_hooks_json_status}"
