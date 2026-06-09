#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"

CODEX_SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR}/codex"
CODEX_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/codex"
CODEX_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/codex"

CURSOR_SKILLS_SOURCE_DIR="${SKILLS_SOURCE_DIR}/cursor"
CURSOR_AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/cursor"
CURSOR_HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/cursor"

CODEX_HOME="${HOME}/.codex"
CODEX_SKILLS_DIR="${CODEX_HOME}/skills"
CODEX_AGENTS_DIR="${CODEX_HOME}/agents"
CODEX_HOOKS_DIR="${CODEX_HOME}/hooks"
CODEX_INSTRUCTIONS_FILE="${CODEX_HOME}/AGENTS.md"
CODEX_HOOKS_FILE="${CODEX_HOME}/hooks.json"

CURSOR_HOME="${HOME}/.cursor"
CURSOR_SKILLS_DIR="${CURSOR_HOME}/skills"
CURSOR_AGENTS_DIR="${CURSOR_HOME}/agents"
CURSOR_HOOKS_DIR="${CURSOR_HOME}/hooks"
CURSOR_HOOKS_FILE="${CURSOR_HOME}/hooks.json"

mkdir -p "${CODEX_SKILLS_DIR}" "${CODEX_AGENTS_DIR}" "${CODEX_HOOKS_DIR}"
mkdir -p "${CURSOR_SKILLS_DIR}" "${CURSOR_AGENTS_DIR}" "${CURSOR_HOOKS_DIR}"

codex_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${CODEX_INSTRUCTIONS_FILE}"
  codex_md="✓ installed"
fi

if [[ ! -d "${CODEX_SKILLS_SOURCE_DIR}" ]]; then
  echo "Error: Codex skills directory not found at ${CODEX_SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

if [[ ! -d "${CURSOR_SKILLS_SOURCE_DIR}" ]]; then
  echo "Error: Cursor skills directory not found at ${CURSOR_SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

echo "Cleaning existing work skills..."
find "${CODEX_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
find "${CURSOR_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +

find "${CODEX_SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CODEX_SKILLS_DIR}/" \;
codex_skills_count=$(find "${CODEX_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

find "${CURSOR_SKILLS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -r {} "${CURSOR_SKILLS_DIR}/" \;
cursor_skills_count=$(find "${CURSOR_SKILLS_DIR}" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ')

codex_agents_status="✗ source not found"
codex_hooks_status="✗ source not found"
codex_hooks_json_status="✗ source not found"
codex_agents_count=0
codex_hooks_count=0
cursor_agents_status="✗ source not found"
cursor_hooks_status="✗ source not found"
cursor_hooks_json_status="✗ source not found"
cursor_agents_count=0
cursor_hooks_count=0

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

if [[ -d "${CURSOR_AGENTS_SOURCE_DIR}" ]]; then
  find "${CURSOR_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CURSOR_AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" -exec cp -f {} "${CURSOR_AGENTS_DIR}/" \;
  cursor_agents_count=$(find "${CURSOR_AGENTS_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" | wc -l | tr -d ' ')
  cursor_agents_status="✓ installed"
fi

if [[ -d "${CURSOR_HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${CURSOR_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${CURSOR_HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${CURSOR_HOOKS_DIR}/" \;
  cursor_hooks_count=$(find "${CURSOR_HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  cursor_hooks_status="✓ installed"
fi

if [[ -f "${CURSOR_HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${CURSOR_HOOKS_SOURCE_DIR}/hooks.json" "${CURSOR_HOOKS_FILE}"
  cursor_hooks_json_status="✓ installed"
fi

echo ""
echo "Work harness applied:"
echo "  Codex skills:       ${codex_skills_count} directories installed to ${CODEX_SKILLS_DIR}"
echo "  Codex instructions: ${codex_md}"
echo "  Codex custom agents: ${codex_agents_count} files installed to ${CODEX_AGENTS_DIR} (${codex_agents_status})"
echo "  Codex hook scripts:  ${codex_hooks_count} files installed to ${CODEX_HOOKS_DIR} (${codex_hooks_status})"
echo "  Codex hooks.json:    ${codex_hooks_json_status}"
echo "  Cursor skills:       ${cursor_skills_count} directories installed to ${CURSOR_SKILLS_DIR}"
echo "  Cursor custom agents: ${cursor_agents_count} files installed to ${CURSOR_AGENTS_DIR} (${cursor_agents_status})"
echo "  Cursor hook scripts:  ${cursor_hooks_count} files installed to ${CURSOR_HOOKS_DIR} (${cursor_hooks_status})"
echo "  Cursor hooks.json:    ${cursor_hooks_json_status}"
