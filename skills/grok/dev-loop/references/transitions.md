# State transitions (normative)

The full transition table, termination predicate, and escalation conditions for `dev-loop`. Where SKILL.md summarizes, this file decides.

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
| REVIEWING | review-code | `pass` | termination check → READY_TO_COMMIT (final mutation round first when owed — see below) |
| REVIEWING | review-code | `needs-decision` | TRIAGE (human, inside review-code). After triage: any Fix → FIXING; all Accept (ARs recorded) → re-evaluate status; any unclassified → stay stopped |
| REVIEWING | review-code | `changes-required` | FIXING |
| FIXING | fix-dev (per finding) | `pass` (all queued fixes) | TESTING(reduced) — opens round N+1 |
| FIXING | fix-dev | `needs-confirmation` | STOP — scope guard fired; route the work to `plan-dev`, wait for the user |
| FIXING | fix-dev | `blocked` | ESCALATED |
| FIXING | fix-dev | `failed` | ESCALATED |

Any unresolved `## Decision Needed` in any return stops the loop regardless of row: direction conflicts → BLOCKED_DIRECTION, everything else → ESCALATED.

## Reduced vs. final TESTING

- **Reduced (re-entry after fixes)**: unit/e2e over the changed files only; mutation skipped.
- **Final mutation round**: when REVIEWING returns `pass` and a reduced round skipped mutation **the project has tooling for**, run one mutation-only `test-dev` pass before READY_TO_COMMIT. Test-code-only additions do not void review evidence. `pass` → READY_TO_COMMIT; `pass-with-suspected-defects` → the TESTING human gate.
- No final mutation round is owed when the loop had no remediation rounds and Round 0 already satisfied mutation policy, **or when the project has no mutation tooling at all** (the approved infeasibility skip satisfies predicate ⑤ directly, so a final round would be a no-op).

## Termination predicate (all 9 must hold for READY_TO_COMMIT)

1. Every plan `## TODOs` checkbox is `[x]`.
2. Every AC in `## Acceptance Contract` is linked to verification evidence (return `## Evidence` / report `AC:` lines).
3. implement-dev returned `pass` and the IMPL report is saved.
4. The rediscovered generic gates (lint/unit/e2e/build) are green.
5. test-dev is `pass` with no open suspected defects; mutation meets the policy threshold, or its infeasibility is explicitly approved and recorded.
6. Zero HIGH/CRITICAL `REVIEW-NNN` findings that are unclassified or Fix-classified, and zero `TEST-NNN` findings that are unclassified or Fix-classified.
7. Every Accept-classified finding is recorded as an AR entry — review and test findings alike.
8. No unresolved `## Decision Needed` or `needs-confirmation` anywhere.
9. The LOOP file carries the final state and evidence (`## Result` appended).

## Escalation conditions

- **Budget**: completed remediation rounds would exceed the Loop budget (plan `## Authority Boundaries`, default 3).
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count fails to decrease between rounds.
- **Immediate**: `blocked`, `failed`, `needs-confirmation`, or an unresolved `## Decision Needed` from any stage, per the table above.
- **Authority**: an action classified must-ask / destructive / scope-expanding by the plan's `## Authority Boundaries` — ask the user; never proceed on inference.

Every escalation appends its reason to the LOOP file (`Stop reason`, and `## Result` when the loop ends there) before reporting to the human.
