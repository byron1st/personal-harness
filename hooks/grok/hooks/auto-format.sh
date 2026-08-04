#!/usr/bin/env bash
# PostToolUse hook for Edit/Write/MultiEdit: if the project's Makefile defines
# a `fmt` (or `format`) target, run it. Silent on success; surfaces failure to
# the agent via exit 2 / logs.
#
# Requires: jq, make
set -euo pipefail

input=$(cat)
cwd=$(echo "$input" | jq -r '.cwd // .workspaceRoot // empty')

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
  echo "[auto-format] make $target failed:" >&2
  echo "$out" | tail -n 20 >&2
  exit 2
fi
