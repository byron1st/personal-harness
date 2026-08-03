#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills/cursor"
AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/cursor"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/cursor"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

CURSOR_HOME="${HOME}/.cursor"
SKILLS_DIR="${CURSOR_HOME}/skills"
AGENTS_DIR="${CURSOR_HOME}/agents"
HOOKS_DIR="${CURSOR_HOME}/hooks"
SCRIPTS_DIR="${CURSOR_HOME}/scripts"
# Cursor has no user-global instructions file and never reads this one.
# hooks/session-context.sh does, and injects it as additional_context.
INSTRUCTIONS_FILE="${CURSOR_HOME}/AGENTS.md"
HOOKS_FILE="${CURSOR_HOME}/hooks.json"

mkdir -p "${SKILLS_DIR}" "${AGENTS_DIR}" "${HOOKS_DIR}" "${SCRIPTS_DIR}"

instructions_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  instructions_md="✓ installed"
fi

if [[ ! -d "${SKILLS_SOURCE_DIR}" ]]; then
  echo "Error: Cursor skills directory not found at ${SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

echo "Cleaning existing Cursor skills..."
find "${SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${SKILLS_DIR}/" \;
skills_count=$(find "${SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

agents_status="✗ source not found"
hooks_status="✗ source not found"
scripts_status="✗ source not found"
hooks_json_status="✗ source not found"
agents_count=0
hooks_count=0
scripts_count=0

if [[ -d "${AGENTS_SOURCE_DIR}" ]]; then
  find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${AGENTS_DIR}/" \;
  agents_count=$(find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  agents_status="✓ installed"
fi

# `-p` preserves the executable bit, same as the Claude installer.
if [[ -d "${HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${HOOKS_DIR}/" \;
  hooks_count=$(find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  hooks_status="✓ installed"
fi

# Runtime scripts the skills call at execution time, from the shared
# scripts/runtime source the Claude installer also uses.
if [[ -d "${SCRIPTS_SOURCE_DIR}" ]]; then
  find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${SCRIPTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${SCRIPTS_DIR}/" \;
  scripts_count=$(find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  scripts_status="✓ installed"
fi

# Replaced, not merged: ~/.cursor/hooks.json is hooks-only, unlike Claude's
# settings.json which shares a file with unrelated settings.
if [[ -f "${HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${HOOKS_SOURCE_DIR}/hooks.json" "${HOOKS_FILE}"
  hooks_json_status="✓ installed"
fi

echo "Cursor harness applied:"
echo "  Cursor skills:            ${skills_count} directories installed to ${SKILLS_DIR}"
echo "  Cursor instructions:      ${instructions_md} to ${INSTRUCTIONS_FILE} (injected by session-context.sh)"
echo "  Cursor sub-agents:        ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Cursor hook scripts:      ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Cursor run scripts:       ${scripts_count} files installed to ${SCRIPTS_DIR} (${scripts_status})"
echo "  Cursor hooks.json:        ${hooks_json_status}"
echo ""
echo "One-time manual step (an installer cannot do this):"
echo "  Turn OFF Cursor's ~/.claude and ~/.codex compatibility paths in Cursor settings."
echo "  Otherwise Cursor also sees the Claude variant of every agent and skill, where"
echo "  'tools:' and 'effort:' are silently ignored and reviewers gain write access."
echo "  hooks/model-pin-guard.sh catches this on the first T1 dispatch if it comes back."
echo ""
