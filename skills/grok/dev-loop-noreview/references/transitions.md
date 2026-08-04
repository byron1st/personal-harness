# State transitions (normative)

The full transition table, termination predicate, and escalation conditions for `dev-loop-noreview`. Where SKILL.md summarizes, this file decides.

This is **not** `dev-loop`'s table with rows deleted. Removing review changes what a round is: the only remediation source becomes `test-dev`'s `## Findings`, TESTING becomes the last stage before the termination check, and the reduced/final TESTING distinction disappears with mutation.

## Transition table

| State | Stage skill | Stage Status | → Next |
| --- | --- | --- | --- |
| PLANNED | (preflight) | checks pass | IMPLEMENTING |
| PLANNED | (preflight) | plan/AC/AB missing or not single-step | REFUSED — route to `plan-dev` |
| IMPLEMENTING | implement-dev | `pass` | TESTING |
| IMPLEMENTING | implement-dev | `blocked` | BLOCKED_DIRECTION — surface `## Decision Needed`, suggest `plan-dev` re-entry |
| IMPLEMENTING | implement-dev | `failed` | ESCALATED |
| TESTING | test-dev | `pass` | termination check → READY_TO_COMMIT |
| TESTING | test-dev | `pass-with-suspected-defects` | HUMAN GATE — per `TEST-NNN` finding: **Fix** → queue for FIXING; **Accept** → record an AR entry, finding closed. Any Fix → FIXING; all Accept → termination check. Unanswered → stay stopped |
| TESTING | test-dev | `blocked` | ESCALATED — surface `## Decision Needed` |
| TESTING | test-dev | `failed` | ESCALATED |
| FIXING | fix-dev (per finding) | `pass` (all queued fixes) | TESTING(reduced) — opens round N+1 |
| FIXING | fix-dev | `needs-confirmation` | STOP — scope guard fired; route the work to `plan-dev`, wait for the user |
| FIXING | fix-dev | `blocked` | ESCALATED |
| FIXING | fix-dev | `failed` | ESCALATED |

Any unresolved `## Decision Needed` in any return stops the loop regardless of row: direction conflicts → BLOCKED_DIRECTION, everything else → ESCALATED.

`review-code` appears nowhere in this table. A REVIEWING state, `REVIEW-NNN` ids, `needs-decision`, and `changes-required` do not exist in this variant.

## TESTING scope

- **Round 0**: unit + e2e over the resolved scope. **Mutation is out of scope** — say so in the `test-dev` invocation so Phase 3 is skipped and a missing mutation command does not return `blocked`.
- **Reduced (re-entry after fixes)**: unit/e2e over the changed files only.
- **No final mutation round exists in this variant.** The rule is deleted, not conditionally skipped.

## Termination predicate (all 9 must hold for READY_TO_COMMIT)

1. Every plan `## TODOs` checkbox is `[x]`.
2. Every AC in `## Acceptance Contract` is linked to verification evidence (return `## Evidence` / report `AC:` lines).
3. implement-dev returned `pass` and the IMPL report is saved.
4. The rediscovered generic gates (lint/unit/e2e/build) are green.
5. The latest test-dev run is `pass`, or `pass-with-suspected-defects` with every Fix-classified finding resolved. Mutation is out of scope for this variant and is never part of this predicate.
6. Zero `TEST-NNN` findings that are unclassified or Fix-classified. (This replaces `dev-loop`'s REVIEW-NNN predicate — the mechanism is the same, the id space is different.)
7. Every Accept-classified finding is recorded as an AR entry.
8. No unresolved `## Decision Needed` or `needs-confirmation` anywhere.
9. The LOOP file carries the final state and evidence (`## Result` appended).

Predicates ⑥ and ⑦ survive the removal of review because acceptance survives it: the user can still knowingly ship a defect, and that decision still leaves a record. What is gone is the reviewer that would have found a *different* class of defect — not the machinery for accepting one.

## Escalation conditions

- **Budget**: completed remediation rounds would exceed the Loop budget (plan `## Authority Boundaries`, default 3).
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count fails to decrease between rounds.
- **Immediate**: `blocked`, `failed`, `needs-confirmation`, or an unresolved `## Decision Needed` from any stage, per the table above.
- **Authority**: an action classified must-ask / destructive / scope-expanding by the plan's `## Authority Boundaries` — ask the user; never proceed on inference.

Every escalation appends its reason to the LOOP file (`Stop reason`, and `## Result` when the loop ends there) before reporting to the human.
