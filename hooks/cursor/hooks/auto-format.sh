#!/usr/bin/env bash
# afterFileEdit hook: if the project's Makefile defines a `fmt` (or `format`)
# target, run it after an edit. afterFileEdit is observational — its output is
# ignored and failures cannot be surfaced to the agent, so this is best-effort
# (failures are only logged to stderr).
#
# Requires: jq, make
set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | jq -r '.file_path // ""')
root=$(echo "$input" | jq -r '.workspace_roots[0] // ""')

# Resolve a starting directory: the edited file's dir (relative paths resolve
# against the workspace root), falling back to the workspace root.
if [[ -n "$file_path" ]]; then
  [[ "$file_path" != /* && -n "$root" ]] && file_path="$root/$file_path"
  start=$(dirname "$file_path")
else
  start="$root"
fi
[[ -n "$start" ]] || exit 0

# Walk up from the starting dir to find a Makefile.
dir="$start"
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
fi
exit 0
