#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<'EOF' >&2
Usage: scripts/apply-to.sh <agent> [agent...]

Apply the harness to one or more agents (sequentially).

Agents:
  claude   Claude Code  (~/.claude)
  codex    Codex        (~/.codex)
  cursor   Cursor       (~/.cursor)
  grok     Grok Build   (~/.grok)

Examples:
  scripts/apply-to.sh claude
  scripts/apply-to.sh claude cursor
  scripts/apply-to.sh claude codex cursor grok
EOF
  exit 1
}

if [[ $# -eq 0 ]]; then
  usage
fi

# Deduplicate while preserving first-seen order.
declare -a agents=()
for raw in "$@"; do
  agent=$(printf '%s' "${raw}" | tr '[:upper:]' '[:lower:]')
  case "${agent}" in
    claude|codex|cursor|grok) ;;
    personal)
      echo "Error: 'personal' was renamed to 'claude'. Use: scripts/apply-to.sh claude" >&2
      exit 1
      ;;
    work)
      echo "Error: 'work' was renamed to 'codex'. Use: scripts/apply-to.sh codex" >&2
      exit 1
      ;;
    *)
      echo "Error: unknown agent '${raw}'" >&2
      usage
      ;;
  esac
  already=0
  for seen in "${agents[@]+"${agents[@]}"}"; do
    if [[ "${seen}" == "${agent}" ]]; then
      already=1
      break
    fi
  done
  if [[ ${already} -eq 0 ]]; then
    agents+=("${agent}")
  fi
done

failed=0
for agent in "${agents[@]}"; do
  script="${SCRIPT_DIR}/apply-to-${agent}.sh"
  if [[ ! -x "${script}" && ! -f "${script}" ]]; then
    echo "Error: installer not found: ${script}" >&2
    failed=1
    continue
  fi
  echo "=== apply-to-${agent} ==="
  if ! bash "${script}"; then
    echo "Error: apply-to-${agent}.sh failed" >&2
    failed=1
  fi
done

if [[ ${failed} -ne 0 ]]; then
  exit 1
fi
