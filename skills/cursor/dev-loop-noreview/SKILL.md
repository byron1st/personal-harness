---
name: dev-loop-noreview
description: "The default loop for everyday work — drives an approved single-step plan-dev plan through implement → test → (fix) until READY_TO_COMMIT, with no reviewer agents at all. Use for the ordinary majority of tasks ('루프 돌려', 'dev-loop 실행', 'run the plan through the loop') when four-axis review would be overkill; escalate to `dev-loop-light` when the change wants review, or `dev-loop` when it is genuinely serious or large. Reviewers are gone, human judgement is not: test-dev's suspected defects still stop the loop for a Fix/Accept decision every round, and mutation testing is out of scope. Requires a plan with Acceptance Contract and Authority Boundaries; refuses legacy plans and routes them to plan-dev. Never commits, pushes, or opens PR/MRs."
---

# Dev Loop (no review)

A thin controller that drives one approved **single-step** plan through `implement-dev` → `test-dev`, with `fix-dev` remediation cycles, until every termination predicate holds, then stops at **READY_TO_COMMIT** for the human. **No reviewer agents run in this variant, and neither does mutation testing.** The loop owns exactly two things: **stage-skill invocation** and **state transitions read from each stage's `## Stage Status`**. It implements nothing itself, never dispatches a stage's Worker directly (each skill's own Dispatcher flow does that), and never merges the stage skills into one.

This is the Cursor default. Sibling variants: [`dev-loop-light`](../dev-loop-light/SKILL.md) adds two review axes, [`dev-loop`](../dev-loop/SKILL.md) adds four plus mutation. Pick before starting; the loop does not switch variants mid-run.

**What dropping review does not drop.** The reviewer fleet is gone; the human is not. `test-dev`'s suspected business-logic defects still stop the loop for classification every round, and an Accept still writes an `## Accepted Review Exceptions` entry. Expect a triage question whenever `test-dev` finds something.

## Inputs

- **Plan path** (required): a plan produced by `plan-dev`. If the invocation omits it, ask.
- Multi-steps **main** plans are not accepted. Run each `-STEP-N` sub-plan (each is a single-step plan) through its own loop, in the main plan's dependency order.

## Preflight (before any stage)

1. Read the plan end to end. Enforce: frontmatter `PlanType: single-step` (a `-STEP-N` sub-plan qualifies), and both `## Acceptance Contract` and `## Authority Boundaries` present. On any miss, **refuse the run** and route to `plan-dev` (augment the plan or re-plan) — the loop has no legacy fallback; graceful degradation for legacy plans belongs to the standalone skills, not here.
2. Read the **Loop budget** (maximum remediation rounds) from `## Authority Boundaries`; default `3` when the section does not override it.
3. Snapshot `git status --short`. This is the pre-existing-change baseline the loop must preserve, and the reference for observing hook-driven tree changes.
4. Create the LOOP file — `docs/agents/dev/{plan stem with _PLAN_ → _LOOP_}.md` per [../dev-loop/references/loop-state.md](../dev-loop/references/loop-state.md). The checkpoint format is shared across all three variants; this variant simply writes `none` into `Applied AR` more often and never logs a `review-code` stage line. If the file already exists for this plan, **resume** instead: trust the file over memory, continue from the last round's `Next`, and never rewrite prior rounds.

## State machine

States and transitions (the full state × Stage Status table in [references/transitions.md](references/transitions.md) is normative):

```
PLANNED → IMPLEMENTING → TESTING → READY_TO_COMMIT
   │            │            │
   │            │            └─ pass-with-suspected-defects → human gate ─ Fix → FIXING
   │            │                                              └─ Accept → AR 기록(human) → re-evaluate
   │            ├─ blocked (direction conflict) → BLOCKED_DIRECTION → human / plan-dev
   │            └─ failed → ESCALATED → human
   └─ FIXING → TESTING(reduced) → 종료 판정                     (= one remediation round)
```

Each stage runs by invoking the stage skill; the skill's own Dispatcher flow executes in this session and owns its Worker dispatch, its delegation-failure gate, and its human interactions. dev-loop-noreview reads the resulting `## Stage Status` — plus `## Findings`, `## Evidence`, and `## Decision Needed` — and transitions per the table. Statuses the loop consumes: `pass | pass-with-suspected-defects | blocked | failed | needs-confirmation`.

There is **no REVIEWING state**. `review-code` is never invoked, `REVIEW-NNN` ids never exist here, and no reviewer agent is dispatched at any point.

## Mutation is out of scope

This variant never runs mutation testing. When invoking `test-dev`, state explicitly in the invocation that **mutation is out of scope for this run**, so Phase 3 is skipped and a missing mutation command is not treated as `blocked`. Consequently there is no reduced-vs-final TESTING distinction and **no final mutation round** — the rule does not exist in this variant.

## Remediation re-entry

Production fixes void prior test evidence. A completed FIXING round therefore always re-enters **TESTING with reduced scope** (unit/e2e over the changed files only), then goes straight to the termination check — there is no review to re-enter.

- **Multiple Fix findings in one round**: one `fix-dev` invocation per finding (its brief carries `Finding ID` and `Loop context`), sequentially. The round's TESTING re-entry happens once, after all fixes.
- **The only source of remediation is `test-dev`'s `## Findings`.** Fix-classified `TEST-NNN` entries are what create a round; nothing else can.

## Budgets and escalation

- Remediation rounds ≤ Loop budget (from the plan's `## Authority Boundaries`, default 3). Exhausted → ESCALATED.
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count does not decrease between rounds → ESCALATED.
- Any `blocked`, `needs-confirmation`, or unresolved `## Decision Needed` → stop immediately and hand to the human. Direction conflicts → BLOCKED_DIRECTION with a `plan-dev` re-entry suggestion; the loop never changes plan direction (goal / approach / `## Key decisions` / `## Non-goals`).
- Externally visible changes, destructive operations, or scope expansion → must-ask per the plan's `## Authority Boundaries`: stop and ask.
- Each skill's internal 3-attempts-per-error rule stays internal; the loop does not retry a `failed` stage on its own.

## Human gates (exactly two; escalations are aborts, not gates)

1. **Triage — always human.** `test-dev`'s suspected-defect classification: **Fix** or **Accept**, the same vocabulary `review-code` uses. The loop never classifies, never auto-accepts, and leaves unanswered findings unclassified (the loop stays stopped on them). An Accept is recorded as an AR entry per `review-code`'s [Accepted Review Exceptions registry](../review-code/SKILL.md#accepted-review-exceptions-registry), with `Original severity: TEST (suspected defect)`. Dropping the reviewers moved this gate from second place to only place — it is the loop's sole quality decision point.
2. **READY_TO_COMMIT.** When every termination predicate in [references/transitions.md](references/transitions.md) holds, stop and report: outcome summary, clickable links to the IMPL report and the LOOP file, and any recorded ARs. `commit-code` / `request-merge` are the user's own actions, outside the loop.

Aborts (BLOCKED_DIRECTION / ESCALATED / FAILED): report the state, the reason, and the LOOP file link, then stop.

**Because no reviewer reads this change, the IMPL report is the only record of what the implementer actually did.** At READY_TO_COMMIT, point the user at the report's `## TODO Fulfillment` and AC evidence explicitly — instruction drift is the failure mode a four-axis review would have caught and this variant will not.

## Prohibitions

The loop never: commits, pushes, or creates PR/MRs; writes an AR entry on its own (only the user's explicit Accept in the TESTING gate does); weakens tests; runs `review-code` or dispatches a reviewer agent; merges stage skills or dispatches their Workers directly; orchestrates control flow through hooks; exceeds or self-overrides the loop budget; changes plan direction — that requires `plan-dev` re-entry.

## Hooks

Hooks are guardrails, not loop participants. When a hook (e.g. auto-format) changes the working tree or fails after an edit, do not revert or fight it — treat the change or failure as an observation that feeds the next verification stage.

## Checkpointing

Disk is the source of truth: the LOOP file, the plan's TODO checkboxes, and the IMPL report. Append the current round's fields to the LOOP file after **every** stage return, before transitioning. A session can die at any point; resume must work from those three artifacts alone.
