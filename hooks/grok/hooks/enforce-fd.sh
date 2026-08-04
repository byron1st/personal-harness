#!/usr/bin/env bash
# PreToolUse: block `find` for file/code search; prefer `fd`.
# Metadata-only find (-mtime, -size, -perm, …) is allowed.
# Grok: camelCase stdin; matcher may pass Bash or run_terminal_command.
# Requires: jq
set -euo pipefail

input=$(cat)
tool=$(echo "$input" | jq -r '.toolName // .tool_name // empty')
case "$tool" in
  Bash|run_terminal_command|Shell) ;;
  *) exit 0 ;;
esac

cmd=$(echo "$input" | jq -r '.toolInput.command // .tool_input.command // empty')

if echo "$cmd" | grep -qE '(^|[^a-zA-Z])find[[:space:]][^|;&]*[[:space:]](-iname|-name|-ipath|-path|-iregex|-regex)([[:space:]]|=|$)'; then
  reason=$(cat <<'MSG'
Use `fd` instead of `find` for file/code search.
  find . -name "*.ts"  →  fd -e ts
MSG
)
  jq -n --arg r "$reason" '{decision:"deny",reason:$r}'
  exit 2
fi
exit 0
