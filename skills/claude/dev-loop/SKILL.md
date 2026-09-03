---
name: dev-loop
description: "Drive an approved single-step plan-dev plan through implement → test → [review] → (triage/fix) until READY_TO_COMMIT, checkpointing to a LOOP file. Modes: light (default; 2-axis review, no mutation), full (4-axis + mutation; serious or security-/reliability-sensitive work), noreview (no reviewers, no mutation). Use for '루프 돌려', 'dev-loop', 'dev-loop-light', 'dev-loop-noreview', 'run the plan through the loop'. Requires Acceptance Contract and Authority Boundaries; refuses legacy plans. Never commits, pushes, or opens PR/MRs."
---

# Dev Loop

A thin controller that drives one approved **single-step** plan through the existing stage skills — `implement-dev` → `test-dev` → (`review-code` when the mode has review), with `fix-dev` remediation cycles — until every termination predicate holds, then stops at **READY_TO_COMMIT** for the human.

The loop owns exactly two things: **stage-skill invocation** and **state transitions read from each stage's `## Stage Status`**. It implements nothing itself, never dispatches a stage's Worker directly (each skill's own Dispatcher flow does that), and never merges the stage skills into one.

Three modes share this controller. Mode is resolved once at preflight, written into the LOOP file, and **never changes mid-run**.

## Inputs

- **Plan path** (required): a plan produced by `plan-dev`. If the invocation omits it, ask.
- **Mode** (`light` | `full` | `noreview`): parsed from the invocation. Default **`light`**.
- Multi-steps **main** plans are not accepted. Run each `-STEP-N` sub-plan (each is a single-step plan) through its own loop, in the main plan's dependency order.

Mode signals (if the utterance names two different modes, ask; do not guess):

| Signal | Mode |
| --- | --- |
| `full`, `4축`, four-axis, four axes, `dev-loop-full` | `full` |
| `light`, `2축`, two-axis, `dev-loop-light` | `light` |
| `noreview`, no review, 리뷰 없이, `dev-loop-noreview` | `noreview` |
| omitted, `루프 돌려`, `dev-loop 실행`, `run the plan through the loop`, bare `/dev-loop` | `light` |

Do not infer `full` from the diff looking security-sensitive. The loop may **recommend** `full` and stop; it does not self-upgrade.

## Mode

Normative effects (axes, mutation, whether REVIEWING exists) live in [references/transitions.md](references/transitions.md). Summary:

| Mode | Review | Mutation |
| --- | --- | --- |
| `light` (default) | 2 axes: `maintainability-reviewer` + `senior-generalist-reviewer` | out of scope |
| `full` | all four axes | in scope |
| `noreview` | none — `review-code` is never invoked | out of scope |

`light` keeps the two axes chosen for cost, not miss cost. `security` and `reliability` do **not** run in `light`. A change that touches authn/authz, secrets, concurrency, or partial-failure paths belongs in `full`.

`noreview` drops the reviewer fleet, not the human: `test-dev`'s suspected defects still stop the loop for Fix/Accept every round.

## Preflight (before any stage)

1. Read the plan end to end. Enforce: frontmatter `PlanType: single-step` (a `-STEP-N` sub-plan qualifies), and both `## Acceptance Contract` and `## Authority Boundaries` present. On any miss, **refuse the run** and route to `plan-dev` (augment the plan or re-plan) — the loop has no legacy fallback; graceful degradation for legacy plans belongs to the standalone skills, not here.
2. Read the **Loop budget** (maximum remediation rounds) from `## Authority Boundaries`; default `3` when the section does not override it.
3. Snapshot `git status --short`. This is the pre-existing-change baseline the loop must preserve, and the reference for observing hook-driven tree changes.
4. Resolve Mode and the LOOP file — `docs/agents/dev/{plan stem with _PLAN_ → _LOOP_}.md` per [references/loop-state.md](references/loop-state.md):
   - **Existing LOOP with `Mode:`** — resume. Trust the file's Mode and the last round's `Next` over memory and over a new utterance. If the new utterance names a *different* mode, **refuse and ask**; do not switch.
   - **Existing LOOP with no `Mode:`** (legacy file) — **ask** which mode this resume is; do not default.
   - **No LOOP yet** — resolve Mode from the invocation (default `light`), create the file with that `Mode:`, then start at IMPLEMENTING.
   Never rewrite prior rounds.

## State machine

States and transitions (the full state × Stage Status table in [references/transitions.md](references/transitions.md) is normative). REVIEWING exists in `light` and `full` only; in `noreview`, TESTING `pass` goes to the termination check.

```
PLANNED → IMPLEMENTING → TESTING → [REVIEWING] → READY_TO_COMMIT
   │            │            │          ├─ needs-decision → triage(human) ─ Fix → FIXING
   │            │            │          │                        └─ Accept → AR 기록(human) → re-evaluate
   │            │            │          └─ changes-required → FIXING
   │            │            └─ pass-with-suspected-defects → human gate ─ Fix → FIXING
   │            │                                              └─ Accept → AR 기록(human) → re-evaluate
   │            ├─ blocked (direction conflict) → BLOCKED_DIRECTION → human / plan-dev
   │            └─ failed → ESCALATED → human
   └─ FIXING → TESTING(reduced) → [REVIEWING]     (= one remediation round)
```

Each stage runs by invoking the stage skill; the skill's own Dispatcher flow executes in this session and owns its Worker dispatch, its delegation-failure gate, and its human interactions (triage, suspected-defect notification). dev-loop reads the resulting `## Stage Status` — plus `## Findings`, `## Evidence`, and `## Decision Needed` — and transitions per the table. Statuses the loop consumes: `pass | pass-with-suspected-defects | blocked | failed | needs-confirmation | needs-decision | changes-required`.

When invoking `review-code` (`light` / `full`), name the axis set for this mode and let `review-code`'s Dispatcher do the dispatching — never dispatch a reviewer agent from the loop. When invoking `test-dev` in `light` or `noreview`, state explicitly that **mutation is out of scope for this run**.

## Remediation re-entry

Production fixes void prior test evidence, and prior review evidence when the mode has review. A completed FIXING round therefore always re-enters **TESTING with reduced scope** (unit/e2e over the changed files only), then **REVIEWING** in `light`/`full` — never straight back to review — or the termination check in `noreview`.

- **Final mutation round** (`full` only): when REVIEWING returns `pass` and a reduced round skipped mutation **that the project actually has tooling for**, run one mutation-only `test-dev` pass before declaring READY_TO_COMMIT. Test-code-only additions do not void review evidence; findings from this pass go through the TESTING human gate. If the project has no mutation tooling at all, skip this round — the approved infeasibility skip already satisfies termination predicate ⑤, so the round would be a guaranteed no-op. The rule does not exist in `light` or `noreview`.
- **Multiple Fix findings in one round**: one `fix-dev` invocation per finding (its brief carries `Finding ID` and `Loop context`), sequentially. The round's TESTING / REVIEWING re-entry happens once, after all fixes.
- **`noreview` remediation source**: only `test-dev`'s `## Findings`. Fix-classified `TEST-NNN` entries are what create a round.

## Budgets and escalation

- Remediation rounds ≤ Loop budget (from the plan's `## Authority Boundaries`, default 3). Exhausted → ESCALATED.
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count does not decrease between rounds → ESCALATED.
- Any `blocked`, `needs-confirmation`, or unresolved `## Decision Needed` → stop immediately and hand to the human. Direction conflicts → BLOCKED_DIRECTION with a `plan-dev` re-entry suggestion; the loop never changes plan direction (goal / approach / `## Key decisions` / `## Non-goals`).
- Externally visible changes, destructive operations, or scope expansion → must-ask per the plan's `## Authority Boundaries`: stop and ask.
- Each skill's internal 3-attempts-per-error rule stays internal; the loop does not retry a `failed` stage on its own.

## Human gates (exactly two; escalations are aborts, not gates)

1. **Triage — always human.** `review-code`'s Fix/Accept classification (when the mode ran review) and `test-dev`'s suspected-defect decisions, which use the same **Fix / Accept** vocabulary. The loop never classifies, never auto-accepts, and leaves unanswered items unclassified (the loop stays stopped on them). An Accept is recorded as an AR entry per `review-code`'s [Accepted Review Exceptions registry](../review-code/SKILL.md#accepted-review-exceptions-registry) — `TEST-NNN` acceptances use `Original severity: TEST (suspected defect)`.
2. **READY_TO_COMMIT.** When every termination predicate in [references/transitions.md](references/transitions.md) holds, stop and report: **the Mode that ran**, outcome summary, clickable links to the IMPL report and the LOOP file, open `[NORMAL]`/`[LOW]` findings (when review ran), and applied ARs. `light` must name the two axes that ran so the user knows what was *not* reviewed. `noreview` must point the user at the IMPL report's `## TODO Fulfillment` and AC evidence — no reviewer read the change, so instruction drift is the human's job. `commit-code` is the user's own action, outside the loop (open a PR/MR only if they ask in that invocation).

Aborts (BLOCKED_DIRECTION / ESCALATED / FAILED): report the state, the reason, and the LOOP file link, then stop.

## Prohibitions

The loop never: commits, pushes, or creates PR/MRs; writes an AR entry on its own (only the user's explicit Accept in triage does); weakens tests; auto-fixes `[NORMAL]`/`[LOW]` findings; changes Mode mid-run or infers a Mode upgrade from the diff; silently widens `light` to four axes or runs `review-code` in `noreview`; merges stage skills or dispatches their Workers directly; orchestrates control flow through hooks; exceeds or self-overrides the loop budget; changes plan direction — that requires `plan-dev` re-entry.

## Hooks

Hooks are guardrails, not loop participants. When a hook (e.g. auto-format) changes the working tree or fails after an edit, do not revert or fight it — treat the change or failure as an observation that feeds the next verification stage.

## Checkpointing

Disk is the source of truth: the LOOP file, the plan's TODO checkboxes, and the IMPL report. Append the current round's fields to the LOOP file after **every** stage return, before transitioning. A session can die at any point; resume must work from those three artifacts alone.
