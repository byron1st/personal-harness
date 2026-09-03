#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

SKILLS_SOURCE_DIR="${SCRIPT_DIR}/../skills/grok"
AGENTS_SOURCE_DIR="${SCRIPT_DIR}/../agents/grok"
HOOKS_SOURCE_DIR="${SCRIPT_DIR}/../hooks/grok"
INSTRUCTIONS_SOURCE_DIR="${SCRIPT_DIR}/../instructions"
SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/runtime"

GROK_HOME="${HOME}/.grok"
SKILLS_DIR="${GROK_HOME}/skills"
AGENTS_DIR="${GROK_HOME}/agents"
HOOKS_DIR="${GROK_HOME}/hooks"
SCRIPTS_DIR="${GROK_HOME}/scripts"
RULES_DIR="${GROK_HOME}/rules"
INSTRUCTIONS_FILE="${RULES_DIR}/AGENTS.md"

mkdir -p "${SKILLS_DIR}" "${AGENTS_DIR}" "${HOOKS_DIR}" "${SCRIPTS_DIR}" "${RULES_DIR}"

instructions_md="✗ not found"
if [[ -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" ]]; then
  cp -f "${INSTRUCTIONS_SOURCE_DIR}/AGENTS.md" "${INSTRUCTIONS_FILE}"
  instructions_md="✓ installed"
fi

if [[ ! -d "${SKILLS_SOURCE_DIR}" ]]; then
  echo "Error: Grok skills directory not found at ${SKILLS_SOURCE_DIR}" >&2
  exit 1
fi

echo "Cleaning existing Grok skills..."
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
  find "${AGENTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" -exec cp -f {} "${AGENTS_DIR}/" \;
  agents_count=$(find "${AGENTS_DIR}" -maxdepth 1 -mindepth 1 -name "*.md" | wc -l | tr -d ' ')
  agents_status="✓ installed"
fi

if [[ -d "${HOOKS_SOURCE_DIR}/hooks" ]]; then
  find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 \( -type f -o -type d \) ! -name '*.json' -exec rm -rf {} + 2>/dev/null || true
  # Install hook scripts into ~/.grok/hooks/ (same dir as harness.json)
  find "${HOOKS_SOURCE_DIR}/hooks" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${HOOKS_DIR}/" \;
  hooks_count=$(find "${HOOKS_DIR}" -maxdepth 1 -mindepth 1 -type f -name '*.sh' | wc -l | tr -d ' ')
  hooks_status="✓ installed"
fi

if [[ -d "${SCRIPTS_SOURCE_DIR}" ]]; then
  find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -exec rm -rf {} +
  find "${SCRIPTS_SOURCE_DIR}" -maxdepth 1 -mindepth 1 -exec cp -rp {} "${SCRIPTS_DIR}/" \;
  scripts_count=$(find "${SCRIPTS_DIR}" -maxdepth 1 -mindepth 1 -type f | wc -l | tr -d ' ')
  scripts_status="✓ installed"
fi

# Grok merges all ~/.grok/hooks/*.json — install harness as its own file.
if [[ -f "${HOOKS_SOURCE_DIR}/hooks.json" ]]; then
  cp -f "${HOOKS_SOURCE_DIR}/hooks.json" "${HOOKS_DIR}/harness.json"
  hooks_json_status="✓ installed"
fi

echo "Grok Build harness applied:"
echo "  Grok skills:            ${skills_count} directories installed to ${SKILLS_DIR}"
echo "  Grok instructions:      ${instructions_md} to ${INSTRUCTIONS_FILE}"
echo "  Grok agents:            ${agents_count} files installed to ${AGENTS_DIR} (${agents_status})"
echo "  Grok hook scripts:      ${hooks_count} files installed to ${HOOKS_DIR} (${hooks_status})"
echo "  Grok runtime scripts:   ${scripts_count} files installed to ${SCRIPTS_DIR} (${scripts_status})"
echo "  Grok hooks harness.json:${hooks_json_status}"
echo ""
echo "Required one-time config (installer cannot set this for you):"
echo "  In ~/.grok/config.toml set [compat.claude] and [compat.cursor] cells to false"
echo "  (skills, rules, agents, mcps, hooks, sessions) so pure Grok paths are used."
echo "  Session habits: plan-dev → grok-4.6 / xhigh; dev-loop → grok-4.6 / medium."
echo ""
