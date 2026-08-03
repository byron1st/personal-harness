#!/usr/bin/env bash
# afterFileEdit hook: if the project's Makefile defines a `fmt` (or `format`)
# target, run it.
#
# Two differences from the Claude variant:
#   1. afterFileEdit has no `cwd`; the repo root comes from `workspace_roots[0]`.
#   2. afterFileEdit has no documented output contract, so exit 2 does not mean
#      "surface this to the agent" the way it does in Claude Code. A failing
#      formatter is therefore logged and swallowed rather than escalated — this
#      hook must never be able to fail an edit that already landed.
#
# Requires: jq, make
set -euo pipefail

LOG_DIR="$HOME/.cursor/logs"
LOG_FILE="$LOG_DIR/auto-format.log"

log() {
  mkdir -p "$LOG_DIR"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
}

input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace_roots[0] // ""')

[[ -n "$cwd" ]] || exit 0

# Walk up from cwd to find a Makefile
dir="$cwd"
while [[ -n "$dir" && "$dir" != "/" ]]; do
  if [[ -f "$dir/Makefile" ]]; then
    break
  fi
  dir=$(dirname "$dir")
done

if [[ ! -f "$dir/Makefile" ]]; then
  exit 0
fi

target=""
if grep -qE '^fmt[[:space:]]*:' "$dir/Makefile"; then
  target="fmt"
elif grep -qE '^format[[:space:]]*:' "$dir/Makefile"; then
  target="format"
fi

if [[ -z "$target" ]]; then
  exit 0
fi

if ! out=$(make -C "$dir" "$target" 2>&1); then
  log "make $target failed in $dir:"
  printf '%s\n' "$out" | tail -n 20 >>"$LOG_FILE"
fi

exit 0
