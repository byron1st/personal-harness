#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/../skills"
INSTRUCTIONS_DIR="${SCRIPT_DIR}/../instructions"

CLAUDE_DIR="${HOME}/.claude"
OPENCODE_DIR="${HOME}/.config/opencode"
CURSOR_DIR="${HOME}/.cursor"
AGENTS_DIR="${HOME}/.agents"
CODEX_DIR="${HOME}/.codex"

# OpenCode will use skills for Claude Code
CLAUDE_SKILLS_DIR="${CLAUDE_DIR}/skills"
CURSOR_SKILLS_DIR="${CURSOR_DIR}/skills"
AGENTS_SKILLS_DIR="${AGENTS_DIR}/skills"

# Ensure target directory exists
mkdir -p "${CLAUDE_SKILLS_DIR}"
mkdir -p "${OPENCODE_DIR}"
mkdir -p "${CURSOR_SKILLS_DIR}"
mkdir -p "${AGENTS_SKILLS_DIR}"
mkdir -p "${CODEX_DIR}"

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
