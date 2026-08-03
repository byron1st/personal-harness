# State transitions (normative)

The full transition table, termination predicate, and escalation conditions for `dev-loop-light`. Where SKILL.md summarizes, this file decides.

The state machine is `dev-loop`'s. What differs is what REVIEWING dispatches (two axes) and what TESTING covers (no mutation) — both are *inputs to the stages*, not new states, which is why every row below matches the four-axis loop.

## Transition table

| State | Stage skill | Stage Status | → Next |
| --- | --- | --- | --- |
| PLANNED | (preflight) | checks pass | IMPLEMENTING |
| PLANNED | (preflight) | plan/AC/AB missing or not single-step | REFUSED — route to `plan-dev` |
| IMPLEMENTING | implement-dev | `pass` | TESTING |
| IMPLEMENTING | implement-dev | `blocked` | BLOCKED_DIRECTION — surface `## Decision Needed`, suggest `plan-dev` re-entry |
| IMPLEMENTING | implement-dev | `failed` | ESCALATED |
| TESTING | test-dev | `pass` | REVIEWING |
| TESTING | test-dev | `pass-with-suspected-defects` | HUMAN GATE — per `TEST-NNN` finding: **Fix** → queue for FIXING; **Accept** → record an AR entry, finding closed. Any Fix → FIXING; all Accept → REVIEWING. Unanswered → stay stopped |
| TESTING | test-dev | `blocked` | ESCALATED — surface `## Decision Needed` |
| TESTING | test-dev | `failed` | ESCALATED |
| REVIEWING | review-code (2 axes) | `pass` | termination check → READY_TO_COMMIT |
| REVIEWING | review-code (2 axes) | `needs-decision` | TRIAGE (human, inside review-code). After triage: any Fix → FIXING; all Accept (ARs recorded) → re-evaluate status; any unclassified → stay stopped |
| REVIEWING | review-code (2 axes) | `changes-required` | FIXING |
| FIXING | fix-dev (per finding) | `pass` (all queued fixes) | TESTING(reduced) — opens round N+1 |
| FIXING | fix-dev | `needs-confirmation` | STOP — scope guard fired; route the work to `plan-dev`, wait for the user |
| FIXING | fix-dev | `blocked` | ESCALATED |
| FIXING | fix-dev | `failed` | ESCALATED |

Any unresolved `## Decision Needed` in any return stops the loop regardless of row: direction conflicts → BLOCKED_DIRECTION, everything else → ESCALATED.

## Review axis subset (normative)

Every REVIEWING entry dispatches **exactly two** axes: `maintainability-reviewer` and `senior-generalist-reviewer`. The loop passes that subset to `review-code`, which owns the dispatch. `security-reviewer` and `reliability-reviewer` never run in this variant — not on Round 0, not on re-entry, not on the last round. Widening to four axes is a variant change and belongs to the user, who runs `dev-loop` instead.

## TESTING scope

- **Round 0**: unit + e2e over the resolved scope. **Mutation is out of scope** — say so in the `test-dev` invocation so Phase 3 is skipped and a missing mutation command does not return `blocked`.
- **Reduced (re-entry after fixes)**: unit/e2e over the changed files only.
- **No final mutation round exists in this variant.** The rule is deleted, not conditionally skipped — so a `pass` from REVIEWING goes straight to the termination check.

## Termination predicate (all 9 must hold for READY_TO_COMMIT)

1. Every plan `## TODOs` checkbox is `[x]`.
2. Every AC in `## Acceptance Contract` is linked to verification evidence (return `## Evidence` / report `AC:` lines).
3. implement-dev returned `pass` and the IMPL report is saved.
4. The rediscovered generic gates (lint/unit/e2e/build) are green.
5. test-dev is `pass` with no open suspected defects. Mutation is out of scope for this variant and is never part of this predicate.
6. Zero HIGH/CRITICAL `REVIEW-NNN` findings that are unclassified or Fix-classified, and zero `TEST-NNN` findings that are unclassified or Fix-classified.
7. Every Accept-classified finding is recorded as an AR entry.
8. No unresolved `## Decision Needed` or `needs-confirmation` anywhere.
9. The LOOP file carries the final state and evidence (`## Result` appended).

Predicate ⑥ holding says nothing about the two axes that did not run. It is a statement about what was looked at, not about the change.

## Escalation conditions

- **Budget**: completed remediation rounds would exceed the Loop budget (plan `## Authority Boundaries`, default 3).
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count fails to decrease between rounds.
- **Immediate**: `blocked`, `failed`, `needs-confirmation`, or an unresolved `## Decision Needed` from any stage, per the table above.
- **Authority**: an action classified must-ask / destructive / scope-expanding by the plan's `## Authority Boundaries` — ask the user; never proceed on inference.

Every escalation appends its reason to the LOOP file (`Stop reason`, and `## Result` when the loop ends there) before reporting to the human.
