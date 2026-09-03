# State transitions (normative)

The full transition table, termination predicate, and escalation conditions for `dev-loop`. Where SKILL.md summarizes, this file decides.

Mode is resolved at preflight (`light` | `full` | `noreview`) and frozen in the LOOP file. Apply only the rows whose **Mode** column includes the run's mode (`all` means every mode).

## Mode effects

| Mode | Review | Mutation | TESTING `pass` → | REVIEWING | Final mutation round |
| --- | --- | --- | --- | --- | --- |
| `light` | exactly `maintainability-reviewer` + `senior-generalist-reviewer` | out of scope — say so in the `test-dev` invocation so Phase 3 is skipped and a missing mutation command does not return `blocked` | REVIEWING | yes | no — the rule is deleted, not conditionally skipped |
| `full` | all four axes | in scope | REVIEWING | yes | yes, when owed (see below) |
| `noreview` | none — `review-code` is never invoked; `REVIEW-NNN` ids do not exist | out of scope — same `test-dev` invocation rule as `light` | termination check | no | no |

`security-reviewer` and `reliability-reviewer` never run in `light` — not on Round 0, not on re-entry, not on the last round. Widening to four axes is a mode change and belongs to the user.

## Transition table

| State | Stage skill | Stage Status | Mode | → Next |
| --- | --- | --- | --- | --- |
| PLANNED | (preflight) | checks pass | all | IMPLEMENTING |
| PLANNED | (preflight) | plan/AC/AB missing or not single-step | all | REFUSED — route to `plan-dev` |
| IMPLEMENTING | implement-dev | `pass` | all | TESTING |
| IMPLEMENTING | implement-dev | `blocked` | all | BLOCKED_DIRECTION — surface `## Decision Needed`, suggest `plan-dev` re-entry |
| IMPLEMENTING | implement-dev | `failed` | all | ESCALATED |
| TESTING | test-dev | `pass` | light, full | REVIEWING |
| TESTING | test-dev | `pass` | noreview | termination check → READY_TO_COMMIT |
| TESTING | test-dev | `pass-with-suspected-defects` | all | HUMAN GATE — per `TEST-NNN` finding: **Fix** → queue for FIXING; **Accept** → record an AR entry, finding closed. Unanswered → stay stopped |
| TESTING | test-dev | (gate resolved: any Fix) | all | FIXING |
| TESTING | test-dev | (gate resolved: all Accept) | light, full | REVIEWING |
| TESTING | test-dev | (gate resolved: all Accept) | noreview | termination check → READY_TO_COMMIT |
| TESTING | test-dev | `blocked` | all | ESCALATED — surface `## Decision Needed` |
| TESTING | test-dev | `failed` | all | ESCALATED |
| REVIEWING | review-code (mode's axes) | `pass` | light | termination check → READY_TO_COMMIT |
| REVIEWING | review-code (mode's axes) | `pass` | full | termination check → READY_TO_COMMIT (final mutation round first when owed — see below) |
| REVIEWING | review-code (mode's axes) | `needs-decision` | light, full | TRIAGE (human, inside review-code). After triage: any Fix → FIXING; all Accept (ARs recorded) → re-evaluate status; any unclassified → stay stopped |
| REVIEWING | review-code (mode's axes) | `changes-required` | light, full | FIXING |
| FIXING | fix-dev (per finding) | `pass` (all queued fixes) | all | TESTING(reduced) — opens round N+1 |
| FIXING | fix-dev | `needs-confirmation` | all | STOP — scope guard fired; route the work to `plan-dev`, wait for the user |
| FIXING | fix-dev | `blocked` | all | ESCALATED |
| FIXING | fix-dev | `failed` | all | ESCALATED |

Any unresolved `## Decision Needed` in any return stops the loop regardless of row: direction conflicts → BLOCKED_DIRECTION, everything else → ESCALATED.

`review-code` appears in no `noreview` row. A REVIEWING state, `needs-decision`, and `changes-required` do not exist in that mode.

## TESTING scope

- **Round 0**: unit + e2e over the resolved scope. Mutation is in scope only in `full`. In `light` and `noreview`, mutation is out of scope.
- **Reduced (re-entry after fixes)**: unit/e2e over the changed files only; mutation skipped (`full`) or already out of scope (`light` / `noreview`).
- **Final mutation round** (`full` only): when REVIEWING returns `pass` and a reduced round skipped mutation **the project has tooling for**, run one mutation-only `test-dev` pass before READY_TO_COMMIT. Test-code-only additions do not void review evidence. `pass` → READY_TO_COMMIT; `pass-with-suspected-defects` → the TESTING human gate. No final mutation round is owed when the loop had no remediation rounds and Round 0 already satisfied mutation policy, **or when the project has no mutation tooling at all** (the approved infeasibility skip satisfies predicate ⑤ directly, so a final round would be a no-op).

## Termination predicate (all 9 must hold for READY_TO_COMMIT)

1. Every plan `## TODOs` checkbox is `[x]`.
2. Every AC in `## Acceptance Contract` is linked to verification evidence (return `## Evidence` / report `AC:` lines).
3. implement-dev returned `pass` and the IMPL report is saved.
4. The rediscovered generic gates (lint/unit/e2e/build) are green.
5. The latest test-dev run is `pass`, or `pass-with-suspected-defects` with every Fix-classified finding resolved. In `full`, mutation meets the policy threshold, or its infeasibility is explicitly approved and recorded. In `light` and `noreview`, mutation is out of scope and is never part of this predicate.
6. Zero `TEST-NNN` findings that are unclassified or Fix-classified. In `light` and `full`, also zero HIGH/CRITICAL `REVIEW-NNN` findings that are unclassified or Fix-classified. Predicate ⑥ holding in `light` says nothing about the two axes that did not run.
7. Every Accept-classified finding is recorded as an AR entry — review and test findings alike.
8. No unresolved `## Decision Needed` or `needs-confirmation` anywhere.
9. The LOOP file carries the final state and evidence (`## Result` appended).

Predicates ⑥ and ⑦ survive `noreview` because acceptance survives it: the user can still knowingly ship a defect, and that decision still leaves a record. What is gone is the reviewer that would have found a *different* class of defect — not the machinery for accepting one.

## Escalation conditions

- **Budget**: completed remediation rounds would exceed the Loop budget (plan `## Authority Boundaries`, default 3).
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count fails to decrease between rounds.
- **Immediate**: `blocked`, `failed`, `needs-confirmation`, or an unresolved `## Decision Needed` from any stage, per the table above.
- **Authority**: an action classified must-ask / destructive / scope-expanding by the plan's `## Authority Boundaries` — ask the user; never proceed on inference.

Every escalation appends its reason to the LOOP file (`Stop reason`, and `## Result` when the loop ends there) before reporting to the human.
