#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=install-shared.sh
source "${SCRIPT_DIR}/install-shared.sh"

HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/cursor"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

CURSOR_HOME="${HOME}/.cursor"
AGENTS_DIR="${CURSOR_HOME}/agents"
HOOKS_DIR="${CURSOR_HOME}/hooks"
# Cursor has no user-global instructions file and never reads this one.
# hooks/session-context.sh does, and injects it as additional_context.
INSTRUCTIONS_FILE="${CURSOR_HOME}/AGENTS.md"
HOOKS_FILE="${CURSOR_HOME}/hooks.json"

mkdir -p "${HOOKS_DIR}" "${HOME}/.cursor/skills"

instructions_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  instructions_md="✓ installed"
fi

remove_platform_harness_skills "${HOME}/.cursor/skills"
remove_retired_agents "${AGENTS_DIR}" md
skills_count=$(count_shared_skills)

hooks_status="✗ source not found"
hooks_json_status="✗ source not found"
hooks_count=0

# `-p` preserves the executable bit, same as the Claude installer.
if [[ -d "${HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${HOOKS_DIR}/" \;
  hooks_count=$(find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  hooks_status="✓ installed"
fi

# Replaced, not merged: ~/.cursor/hooks.json is hooks-only, unlike Claude's
# settings.json which shares a file with unrelated settings.
if [[ -f "${HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${HOOKS_SOURCE_DIR}/hooks.json" "${HOOKS_FILE}"
  hooks_json_status="✓ installed"
fi

echo "Cursor harness applied:"
echo "  Shared skills:            ${skills_count} directories in ${HOME}/.agents/skills"
echo "  Cursor skills dir:        harness names removed from ${HOME}/.cursor/skills (native ~/.agents/skills)"
echo "  Cursor instructions:      ${instructions_md} to ${INSTRUCTIONS_FILE} (injected by session-context.sh)"
echo "  Retired harness agents:   removed from ${AGENTS_DIR}"
echo "  Cursor hook scripts:      ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Cursor hooks.json:        ${hooks_json_status}"
echo ""
echo "One-time manual step (an installer cannot do this):"
echo "  Turn OFF Cursor's ~/.claude and ~/.codex compatibility paths in Cursor settings."
echo "  Otherwise Cursor also sees the Claude per-skill symlink of every shared skill,"
echo "  and the same name loads twice."
echo ""
