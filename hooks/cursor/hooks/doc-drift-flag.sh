#!/usr/bin/env bash
# beforeSubmitPrompt hook (paired with stop/doc-drift-reminder.sh): when the
# user's prompt signals task completion or a merge request, drop a
# per-conversation flag so the stop hook runs the doc-drift check on wrap-up.
# beforeSubmitPrompt cannot inject context, so the actual reminder is emitted
# by the stop hook via followup_message.
#
# Requires: jq
set -euo pipefail

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // ""')
conv=$(echo "$input" | jq -r '.conversation_id // ""')

# Trigger signals (same as the Codex UserPromptSubmit version):
#   (a) Completion phrases (Korean + English) — safety net, kept narrow.
#   (b) request-merge skill invocation — primary signal for this workflow.
if echo "$prompt" | grep -iqE '(끝났어|끝났다|마무리하|마무리할|wrap.?up|all done|ship it|이제 끝|모두 완료|finished up|/request-merge|PR[[:space:]]*(만들|올리|생성|요청|올려)|MR[[:space:]]*(만들|올리|생성|요청|올려)|(pull|merge)[[:space:]]?request)'; then
  if [[ -n "$conv" ]]; then
    flag_dir="${TMPDIR:-/tmp}/cursor-docdrift"
    mkdir -p "$flag_dir"
    : > "$flag_dir/$conv"
  fi
fi

# beforeSubmitPrompt must not block here; output is advisory only.
printf '{"continue":true}\n'
exit 0
