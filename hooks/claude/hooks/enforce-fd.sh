#!/usr/bin/env bash
# PreToolUse hook for Bash: block `find` invocations doing file/code search
# (i.e. using -name/-iname/-path/-ipath/-regex/-iregex). Suggests `fd` with
# translation hints. Metadata-only `find` (e.g. -mtime, -size, -perm) is
# allowed because fd does not cover those.
#
# Requires: jq
set -euo pipefail

input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command // ""')

# Match `find` (as a standalone word) followed — within the same command
# segment (no |, ;, &) — by one of the search-pattern flags.
if echo "$cmd" | grep -qE '(^|[^a-zA-Z])find[[:space:]][^|;&]*[[:space:]](-iname|-name|-ipath|-path|-iregex|-regex)([[:space:]]|=|$)'; then
  cat >&2 <<'EOF'
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
  exit 2
fi
