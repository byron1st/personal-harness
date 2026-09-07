---
name: dev-loop
description: "Drive an approved single-step plan through implement/test/[review]/(triage-fix) until READY_TO_COMMIT. Modes: light (default, 2-axis, no mutation), full (4-axis + mutation), noreview (no review). Use when asked to run a saved plan as a loop. Requires Acceptance Contract + Authority Boundaries."
---

# Dev Loop

A thin controller driving one approved **single-step** plan through implement → test → (review) with `fix-dev` remediation cycles, until every termination predicate holds, then stopping at **READY_TO_COMMIT** for the human.

The loop owns **when**: the state machine, which persona each stage starts, the human gates, and spawn-failure questions. It implements nothing itself and never merges the stage skills into one. It starts each stage's **persona**; the skill that persona follows does not start personas of its own.

[references/transitions.md](references/transitions.md) is **normative** for mode effects, the state × status table, TESTING scope, termination predicates, and escalation conditions. Where this file summarizes, that one decides.

## Inputs

- **Plan path** (required) — a `plan-dev` plan. If the invocation omits it, ask.
- **Mode** — `light` (default) | `full` | `noreview`. Frozen at preflight; **never changes mid-run**.
- Multi-steps **main** plans are refused. Run each `-STEP-N` sub-plan through its own loop, in dependency order.

| Signal | Mode |
| --- | --- |
| `full`, `4축`, four-axis, four axes, `dev-loop-full` | `full` |
| `light`, `2축`, two-axis, `dev-loop-light` | `light` |
| `noreview`, no review, 리뷰 없이, `dev-loop-noreview` | `noreview` |
| omitted, `루프 돌려`, `dev-loop 실행`, `run the plan through the loop`, bare `/dev-loop` | `light` |

Two different modes named in one utterance → ask, do not guess. **Never infer `full` from the diff looking security-sensitive** — the loop may *recommend* `full` and stop, but it does not self-upgrade.

| Mode | Review | Mutation |
| --- | --- | --- |
| `light` (default) | `maintainability-reviewer` + `senior-generalist-reviewer` | out of scope |
| `full` | all four axes | in scope |
| `noreview` | none — `review-code` is never invoked | out of scope |

`light`'s two axes were chosen for cost, not for miss cost: **`security` and `reliability` do not run.** A change touching authn/authz, secrets, concurrency, or partial-failure paths belongs in `full`. `noreview` drops the reviewer fleet, not the human — `test-dev`'s suspected defects still stop the loop for Fix/Accept every round, and they are that mode's only source of remediation work.

## Preflight

1. Read the plan end to end. Enforce frontmatter `PlanType: single-step` (a `-STEP-N` sub-plan qualifies) and both `## Acceptance Contract` and `## Authority Boundaries`. On any miss, **refuse the run** and route to `plan-dev`. The loop does not degrade gracefully around a thin plan — its termination predicates are written against the contract.
2. Read the **Loop budget** from `## Authority Boundaries`; default `3`.
3. Snapshot `git status --short` — the pre-existing-change baseline the loop must preserve, and the reference for spotting hook-driven tree changes.
4. **Prepare once**: run `$HOME/.agents/scripts/detect-commands.sh`, and `$HOME/.agents/scripts/resolve-scope.sh` when TESTING or REVIEWING is ahead. Put the JSON in every executor brief so no persona rediscovers commands or scope cold.
5. Resolve Mode and the LOOP file (`docs/agents/dev/{plan stem, _PLAN_ → _LOOP_}.md`, per [references/loop-state.md](references/loop-state.md)):
   - **Existing LOOP** — resume. Trust the file's `Mode:` and the last round's `Next` over memory and over a new utterance. A new utterance naming a *different* mode → **refuse and ask**; do not switch.
   - **No LOOP yet** — resolve Mode from the invocation, create the file with that `Mode:`, start at IMPLEMENTING.

   Never rewrite prior rounds.

## Stage personas

| State | Persona started | Skill it follows |
| --- | --- | --- |
| IMPLEMENTING | `implementer` (one) | `implement-dev` |
| TESTING | `tester` (one) | `test-dev` |
| REVIEWING | the mode's axis set, in parallel | `review-code` (executor section; the loop follows the caller section) |
| FIXING | `fixer` (one per finding, sequential) | `fix-dev` |

Two things the brief must carry, because leaving them to description matching gets them wrong: in `light` / `noreview`, that **mutation is out of scope for this run**; and at REVIEWING, **the exact axis set** for this mode.

With multiple Fix-classified findings in one round, start one `fixer` per finding sequentially — each brief carrying its `Finding ID` and `Loop context` — and re-enter TESTING/REVIEWING once, after all of them.

LOOP log lines stay skill names (`implement-dev: pass`); do not rename them to personas.

## State machine

```
PLANNED → IMPLEMENTING → TESTING → [REVIEWING] → READY_TO_COMMIT
   │            │            │          ├─ needs-decision → triage(human) ─ Fix → FIXING
   │            │            │          │                        └─ Accept → AR 기록(human) → re-evaluate
   │            │            │          └─ changes-required → FIXING
   │            │            └─ pass-with-suspected-defects → human gate ─ Fix → FIXING
   │            │                                              └─ Accept → AR 기록(human) → re-evaluate
   │            ├─ needs-design-decision → plan-consultant (read-only) → resume implementer
   │            ├─ blocked (direction conflict) → BLOCKED_DIRECTION → human / plan-dev
   │            └─ failed → same persona once → still failed → ESCALATED → human
   └─ FIXING → TESTING(reduced) → [REVIEWING]     (= one remediation round)
```

REVIEWING exists in `light` and `full` only; in `noreview`, TESTING `pass` goes straight to the termination check. Read `## Stage Status` — plus `## Findings`, `## Evidence`, `## Decision Needed`, `## Design Decision Needed` — and transition per the normative table.

**Spawn failure**: if a persona cannot start, ask the user whether to run that stage in the current session or stop. Never silently continue in place.

**`failed` retry**: start the **same persona** once more with the same brief plus a line naming what the first attempt tried and observed. Still `failed` → ESCALATED. Do not name a host model. `blocked`, `needs-confirmation`, and `needs-design-decision` are never retried this way.

**`needs-design-decision`**: start `plan-consultant` read-only with the fork brief, collect its short decision, resume `implementer` with it. Does not consume loop budget. Not `blocked`.

## Human gates — exactly two

Escalations are aborts, not gates.

1. **Triage.** `review-code`'s Fix/Accept classification and `test-dev`'s suspected-defect decisions, which share the same **Fix / Accept** vocabulary. The loop never classifies, never auto-accepts, and leaves unanswered items unclassified — staying stopped on them. An Accept is recorded as an AR entry per `review-code`'s [Accepted Review Exceptions registry](../review-code/SKILL.md#accepted-review-exceptions-registry); `TEST-NNN` acceptances use `Original severity: TEST (suspected defect)`.
2. **READY_TO_COMMIT.** When every termination predicate holds, stop and report: the Mode that ran, an outcome summary, clickable links to the IMPL report and the LOOP file, open `[NORMAL]` / `[LOW]` findings, and applied ARs. **`light` must name the two axes that ran**, so the user knows what was not reviewed. **`noreview` must point at the IMPL report's `## TODO Fulfillment` and AC evidence** — no reviewer read the change, so catching instruction drift is the human's job. `commit-code` is the user's own action, outside the loop.

Aborts (BLOCKED_DIRECTION / ESCALATED / FAILED): report the state, the reason, and the LOOP file link, then stop.

## Prohibitions

The loop never commits, pushes, or opens a PR/MR; never weakens a test; never auto-fixes `[NORMAL]` / `[LOW]` findings; and never changes plan direction — goal, approach, `## Key decisions`, `## Non-goals` — which requires `plan-dev` re-entry.

## Hooks

Hooks are guardrails, not loop participants. When one (auto-format, say) changes the working tree or fails after an edit, do not revert or fight it — treat the change or failure as an observation feeding the next verification stage.

## Checkpointing

Disk is the source of truth: the LOOP file, the plan's TODO checkboxes, the IMPL report. Append the round's fields to the LOOP file after **every** stage return, before transitioning. A session can die at any point, and resume must work from those three artifacts alone.
