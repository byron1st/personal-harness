#!/usr/bin/env bash
# preToolUse hook: block `find` invocations doing file/code search (i.e. using
# -name/-iname/-path/-ipath/-regex/-iregex). Suggests `fd` with translation
# hints. Metadata-only `find` (e.g. -mtime, -size, -perm) is allowed because
# fd does not cover those.
#
# See enforce-rg.sh for why the tool is checked here rather than with a
# `matcher`, and why this denies with JSON rather than exit 2.
#
# Requires: jq
set -euo pipefail

input=$(cat)
[[ "$(echo "$input" | jq -r '.tool_name // ""')" == "Shell" ]] || exit 0

cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Match `find` (as a standalone word) followed — within the same command
# segment (no |, ;, &) — by one of the search-pattern flags.
if echo "$cmd" | grep -qE '(^|[^a-zA-Z])find[[:space:]][^|;&]*[[:space:]](-iname|-name|-ipath|-path|-iregex|-regex)([[:space:]]|=|$)'; then
  message=$(cat <<'EOF'
Use `fd` instead of `find` for file/code search.

Why: fd is faster, respects .gitignore by default, and is the project convention.

Translation hints:
  find . -name "*.ts"                  →  fd -e ts
  find . -iname "readme*"              →  fd -i readme
  find . -path "*/src/*" -name "*.go"  →  fd -e go . src
  find . -type f -name "*.go"          →  fd -e go -t f
  find . -type d -name "node_modules"  →  fd -t d node_modules
  find . -name "*.tmp" -delete         →  fd -e tmp -x rm
  find . -name "*.tmp" -exec rm {} \;  →  fd -e tmp -x rm
EOF
)
  jq -n --arg msg "$message" \
    '{permission:"deny",agent_message:$msg,user_message:"Blocked find-based search; use fd."}'
  exit 0
fi
