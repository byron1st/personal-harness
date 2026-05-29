#!/usr/bin/env bash
# beforeShellExecution hook: block recursive `grep` invocations for code
# search. Suggests `rg` (ripgrep) with translation hints via agent_message.
# Pipe-filter usage of grep (e.g. `git status | grep modified`) is allowed.
#
# Requires: jq
set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.command // ""')

# Match `grep` (not as a substring of egrep/fgrep/pgrep) followed by a
# recursive-style flag: `-r`, `-R`, any combo containing r/R, or
# --include / --exclude / --exclude-dir.
if echo "$cmd" | grep -qE '(^|[^a-zA-Z])grep[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--include|--exclude|--exclude-dir)'; then
  msg=$(cat <<'EOF'
Use `rg` (ripgrep) instead of recursive `grep` for code search.

Why: rg is faster, respects .gitignore by default, and is the project convention.

Translation hints:
  grep -r "pattern" .                     →  rg "pattern"
  grep -rn "pattern" src/                 →  rg "pattern" src/
  grep -ri "pattern" .                    →  rg -i "pattern"
  grep -r --include="*.ts" "p" .          →  rg -t ts "p"
  grep -r --exclude-dir=node_modules ...  →  rg "p"   (rg skips ignored dirs by default)
EOF
)
  jq -n --arg am "$msg" '{permission:"deny", user_message:"Use rg instead of recursive grep.", agent_message:$am}'
  exit 0
fi

printf '{"permission":"allow"}\n'
exit 0
