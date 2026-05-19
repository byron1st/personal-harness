#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/../skills"
INSTRUCTIONS_DIR="${SCRIPT_DIR}/../instructions"
CLAUDE_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/claude"
CLAUDE_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/claude"

CLAUDE_DIR="${HOME}/.claude"
OPENCODE_DIR="${HOME}/.config/opencode"
CURSOR_DIR="${HOME}/.cursor"
AGENTS_DIR="${HOME}/.agents"
CODEX_DIR="${HOME}/.codex"

# OpenCode will use skills for Claude Code
CLAUDE_SKILLS_DIR="${CLAUDE_DIR}/skills"
CURSOR_SKILLS_DIR="${CURSOR_DIR}/skills"
AGENTS_SKILLS_DIR="${AGENTS_DIR}/skills"

# Claude-specific extras
CLAUDE_AGENTS_DIR="${CLAUDE_DIR}/agents"
CLAUDE_HOOKS_DIR="${CLAUDE_DIR}/hooks"

# Ensure target directory exists
mkdir -p "${CLAUDE_SKILLS_DIR}"
mkdir -p "${OPENCODE_DIR}"
mkdir -p "${CURSOR_SKILLS_DIR}"
mkdir -p "${AGENTS_SKILLS_DIR}"
mkdir -p "${CODEX_DIR}"
mkdir -p "${CLAUDE_AGENTS_DIR}"
mkdir -p "${CLAUDE_HOOKS_DIR}"

# Copy global instructions to CLAUDE.md
claude_md="✗ not found"
opencode_md="✗ not found"
codex_md="✗ not found"
if [[ -f "${INSTRUCTIONS_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_DIR}/AGENTS.md" "${CLAUDE_DIR}/CLAUDE.md"
  claude_md="✓ installed"

  cp -f "${INSTRUCTIONS_DIR}/AGENTS.md" "${OPENCODE_DIR}/AGENTS.md"
  opencode_md="✓ installed"

  cp -f "${INSTRUCTIONS_DIR}/AGENTS.md" "${CODEX_DIR}/AGENTS.md"
  codex_md="✓ installed"
fi

# Verify source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: skills directory not found at ${SOURCE_DIR}" >&2
  exit 1
fi

# Clean existing skills
echo "Cleaning existing skills..."
find "${CLAUDE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${CURSOR_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${AGENTS_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +

# Copy skills
find "${SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CLAUDE_SKILLS_DIR}/" \;
claude_skills_count=$(find "${CLAUDE_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
find "${SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CURSOR_SKILLS_DIR}/" \;
cursor_skills_count=$(find "${CURSOR_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')
find "${SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${AGENTS_SKILLS_DIR}/" \;
agents_skills_count=$(find "${AGENTS_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

# Sync Claude-specific agents and hooks
claude_agents_status="✗ source not found"
claude_hooks_status="✗ source not found"
claude_settings_status="✗ source not found"
claude_agents_count=0
claude_hooks_count=0

if [[ -d "${CLAUDE_AGENTS_SOURCE_DIR}" ]]; then
  find "${CLAUDE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CLAUDE_AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CLAUDE_AGENTS_DIR}/" \;
  claude_agents_count=$(find "${CLAUDE_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  claude_agents_status="✓ installed"
fi

if [[ -d "${CLAUDE_HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${CLAUDE_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CLAUDE_HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${CLAUDE_HOOKS_DIR}/" \;
  claude_hooks_count=$(find "${CLAUDE_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  claude_hooks_status="✓ installed"
fi

if [[ -f "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" ]]; then
  target_settings="${CLAUDE_DIR}/settings.json"
  if [[ -f "${target_settings}" ]]; then
    tmp_settings=$(mktemp)
    jq -s '.[0] * .[1]' "${target_settings}" "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" > "${tmp_settings}"
    mv "${tmp_settings}" "${target_settings}"
    claude_settings_status="✓ merged"
  else
    cp -f "${CLAUDE_HOOKS_SOURCE_DIR}/settings.json" "${target_settings}"
    claude_settings_status="✓ created"
  fi
fi

# Report
echo ""
echo "Agent skills applied:"
echo "  Claude Code:  ${claude_skills_count} directories installed to ${CLAUDE_SKILLS_DIR}"
echo "  Cursor:  ${cursor_skills_count} directories installed to ${CURSOR_SKILLS_DIR}"
echo "  Agents:  ${agents_skills_count} directories installed to ${AGENTS_SKILLS_DIR}"
echo "Global instructions applied:"
echo "  Claude Code: ${claude_md}"
echo "  Opencode: ${opencode_md}"
echo "  Codex: ${codex_md}"
echo "Claude-specific extras:"
echo "  Sub-agents:     ${claude_agents_count} files installed to ${CLAUDE_AGENTS_DIR} (${claude_agents_status})"
echo "  Hook scripts:   ${claude_hooks_count} files installed to ${CLAUDE_HOOKS_DIR} (${claude_hooks_status})"
echo "  settings.json:  ${claude_settings_status}"
