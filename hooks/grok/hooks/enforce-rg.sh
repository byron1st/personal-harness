#!/usr/bin/env bash
# PreToolUse: block recursive grep; prefer rg.
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

if echo "$cmd" | grep -qE '(^|[^a-zA-Z])grep[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--include|--exclude|--exclude-dir)'; then
  reason=$(cat <<'MSG'
Use `rg` (ripgrep) instead of recursive `grep` for code search.
  grep -r "pattern" .  →  rg "pattern"
MSG
)
  jq -n --arg r "$reason" '{decision:"deny",reason:$r}'
  exit 2
fi
exit 0
