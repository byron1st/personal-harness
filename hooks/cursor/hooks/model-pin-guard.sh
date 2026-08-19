#!/usr/bin/env bash
# subagentStart hook: check that a dispatched harness agent actually got the
# model its frontmatter pins, and refuse the spawn when a T1 agent did not.
#
# Why this exists. Cursor's model pin is not a guarantee — an admin model
# restriction, a plan limitation, or an unrecognised model ID all make Cursor
# fall back to a "compatible model" silently. subagentStart is the only place
# the resolved model is visible before the work starts, so this hook is the
# harness's one chance to notice. It watches three failure modes at once:
#
#   1. Plan/admin fallback: the pin was refused.
#   2. A wrong model ID in agents/cursor/*.md: an unknown ID also falls back.
#   3. ~/.claude/ compatibility-path revival: if Cursor picks up the Claude
#      variant of an agent, the resolved model stops being a Cursor one
#      entirely (`tools:` and `effort:` are silently ignored there too, which
#      is what makes that failure worth catching loudly).
#
# T1 agents are denied, T2 agents are logged and allowed. subagentStart takes
# only allow/deny — there is no "warn" — and denying every mismatch would stop
# a whole loop on one fallback. So the hard stop is reserved for the axes whose
# misses are unrecoverable, and everything else is left for post-hoc reading.
#
# Matching is on the base model id, not the full pin string: subagent_model
# reports a resolved model (e.g. "grok-4.6"), while the frontmatter pin carries
# parameters ("grok-4.6[effort=high]") that do not come back in this field.
# Comparing the full string would fire on every single dispatch.
#
# Unknown subagent types (Cursor built-ins like generalPurpose / explore /
# shell, or any agent this harness does not own) are always allowed.
#
# Requires: jq
set -euo pipefail

LOG_DIR="$HOME/.cursor/logs"
LOG_FILE="$LOG_DIR/model-pin.log"

log() {
  mkdir -p "$LOG_DIR"
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$1" >>"$LOG_FILE"
}

allow() { printf '{"permission":"allow"}\n'; exit 0; }

input=$(cat)
subagent_type=$(echo "$input" | jq -r '.subagent_type // ""')
subagent_model=$(echo "$input" | jq -r '.subagent_model // ""')

# Expected base model per agent, mirroring the placement table in agents/AGENTS.md.
case "$subagent_type" in
  planner|plan-consultant|security-reviewer|reliability-reviewer)
    expected="grok-4.6"; tier="T1" ;;
  implementer|fixer|tester|maintainability-reviewer|senior-generalist-reviewer)
    expected="grok-4.6"; tier="T2" ;;
  *)
    allow ;;
esac

# An empty subagent_model means Cursor told us nothing; do not block on that.
[[ -n "$subagent_model" ]] || allow

case "$subagent_model" in
  *"$expected"*) allow ;;
esac

log "MISMATCH ${tier} ${subagent_type}: expected ${expected}, got ${subagent_model}"

if [[ "$tier" == "T1" ]]; then
  jq -n \
    --arg agent "$subagent_type" \
    --arg expected "$expected" \
    --arg actual "$subagent_model" \
    --arg logfile "$LOG_FILE" \
    '{permission:"deny",
      user_message:("Model pin not honoured for T1 agent `" + $agent + "`: expected " + $expected + ", got " + $actual + ".\nA T1 axis running on the wrong model is a miss you cannot recover, so the spawn was refused.\nCheck: (1) the model ID in agents/cursor/" + $agent + ".md, (2) whether Cursor is reading ~/.claude/agents/ again, (3) admin/plan model restrictions.\nLog: " + $logfile)}'
  exit 0
fi

allow
