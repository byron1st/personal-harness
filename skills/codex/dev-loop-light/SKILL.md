---
name: dev-loop-light
description: "Drive an approved single-step plan through implement/test/2-axis review (maintainability+senior-generalist) without mutation until READY_TO_COMMIT. Codex default loop. Requires Acceptance Contract + Authority Boundaries."
---

# Dev Loop (light)

A thin controller that drives one approved **single-step** plan through the existing stage skills — `implement-dev` → `test-dev` → `review-code`, with `fix-dev` remediation cycles — until every termination predicate holds, then stops at **READY_TO_COMMIT** for the human. It is [`dev-loop`](../dev-loop/SKILL.md) with two changes and nothing else: **review runs two axes, not four**, and **mutation testing is out of scope**. The loop owns exactly two things: **stage-skill invocation** and **state transitions read from each stage's `## Stage Status`**. It implements nothing itself, never dispatches a stage's Worker directly (each skill's own Dispatcher flow does that), and never merges the stage skills into one.

Sibling variants: [`dev-loop-noreview`](../dev-loop-noreview/SKILL.md) is the everyday default and runs no review at all; [`dev-loop`](../dev-loop/SKILL.md) runs all four axes plus mutation. Pick before starting; the loop does not switch variants mid-run.

**Know which axes you are giving up.** This variant keeps `maintainability` and `senior-generalist` — the two chosen for cost, not for miss cost. `security` and `reliability` are precisely the axes whose misses are unrecoverable, and they do **not** run here. A change that touches authn/authz, secrets, concurrency, or partial-failure paths belongs in `dev-loop`, not this variant.

## Inputs

- **Plan path** (required): a plan produced by `plan-dev`. If the invocation omits it, ask.
- Multi-steps **main** plans are not accepted. Run each `-STEP-N` sub-plan (each is a single-step plan) through its own loop, in the main plan's dependency order.

## Preflight (before any stage)

1. Read the plan end to end. Enforce: frontmatter `PlanType: single-step` (a `-STEP-N` sub-plan qualifies), and both `## Acceptance Contract` and `## Authority Boundaries` present. On any miss, **refuse the run** and route to `plan-dev` (augment the plan or re-plan) — the loop has no legacy fallback; graceful degradation for legacy plans belongs to the standalone skills, not here.
2. Read the **Loop budget** (maximum remediation rounds) from `## Authority Boundaries`; default `3` when the section does not override it.
3. Snapshot `git status --short`. This is the pre-existing-change baseline the loop must preserve, and the reference for observing hook-driven tree changes.
4. Create the LOOP file — `docs/agents/dev/{plan stem with _PLAN_ → _LOOP_}.md` per [../dev-loop/references/loop-state.md](../dev-loop/references/loop-state.md). The checkpoint format is shared across all three variants. If the file already exists for this plan, **resume** instead: trust the file over memory, continue from the last round's `Next`, and never rewrite prior rounds.

## State machine

States and transitions (the full state × Stage Status table in [references/transitions.md](references/transitions.md) is normative):

```
PLANNED → IMPLEMENTING → TESTING → REVIEWING(2축) → READY_TO_COMMIT
   │            │            │          ├─ needs-decision → triage(human) ─ Fix → FIXING
   │            │            │          │                        └─ Accept → AR 기록(human) → re-evaluate
   │            │            │          └─ changes-required → FIXING
   │            │            └─ pass-with-suspected-defects → human gate ─ Fix → FIXING
   │            │                                              └─ Accept → AR 기록(human) → re-evaluate
   │            ├─ blocked (direction conflict) → BLOCKED_DIRECTION → human / plan-dev
   │            └─ failed → ESCALATED → human
   └─ FIXING → TESTING(reduced) → REVIEWING     (= one remediation round)
```

Each stage runs by invoking the stage skill; the skill's own Dispatcher flow executes in this session and owns its Worker dispatch, its delegation-failure gate, and its human interactions (triage, suspected-defect notification). dev-loop-light reads the resulting `## Stage Status` — plus `## Findings`, `## Evidence`, and `## Decision Needed` — and transitions per the table. Statuses the loop consumes: `pass | pass-with-suspected-defects | blocked | failed | needs-confirmation | needs-decision | changes-required`.

## The two differences from `dev-loop`

1. **REVIEWING runs two axes.** When invoking `review-code`, name the axis subset explicitly: `maintainability-reviewer` and `senior-generalist-reviewer` only. The loop states the subset in the invocation and lets `review-code`'s own Dispatcher flow do the dispatching — it never dispatches a reviewer agent itself, which would break the loop's standing invariant that it never dispatches a stage's Worker directly.
2. **Mutation is out of scope.** When invoking `test-dev`, state explicitly that **mutation is out of scope for this run**, so Phase 3 is skipped and a missing mutation command is not treated as `blocked`. Consequently **there is no final mutation round** — the rule does not exist in this variant.

Everything else — triage, the AR registry, the two human gates, the nine termination predicates, budgets, prohibitions, hooks, checkpointing — is `dev-loop`'s behavior unchanged.

## Remediation re-entry

Production fixes void prior test and review evidence. A completed FIXING round therefore always re-enters **TESTING with reduced scope** (unit/e2e over the changed files only), then **REVIEWING** (the same two axes) — never straight back to review.

- **Multiple Fix findings in one round**: one `fix-dev` invocation per finding (its brief carries `Finding ID` and `Loop context`), sequentially. The round's TESTING/REVIEWING re-entry happens once, after all fixes.

## Budgets and escalation

- Remediation rounds ≤ Loop budget (from the plan's `## Authority Boundaries`, default 3). Exhausted → ESCALATED.
- **No-progress**: the same blocking finding survives two consecutive rounds, or the blocking-finding count does not decrease between rounds → ESCALATED.
- Any `blocked`, `needs-confirmation`, or unresolved `## Decision Needed` → stop immediately and hand to the human. Direction conflicts → BLOCKED_DIRECTION with a `plan-dev` re-entry suggestion; the loop never changes plan direction (goal / approach / `## Key decisions` / `## Non-goals`).
- Externally visible changes, destructive operations, or scope expansion → must-ask per the plan's `## Authority Boundaries`: stop and ask.
- Each skill's internal 3-attempts-per-error rule stays internal; the loop does not retry a `failed` stage on its own.

## Human gates (exactly two; escalations are aborts, not gates)

1. **Triage — always human.** `review-code`'s Fix/Accept classification and `test-dev`'s suspected-defect decisions, which use the same **Fix / Accept** vocabulary. The loop never classifies, never auto-accepts, and leaves unanswered items unclassified (the loop stays stopped on them). An Accept is recorded as an AR entry per `review-code`'s [Accepted Review Exceptions registry](../review-code/SKILL.md#accepted-review-exceptions-registry) — `TEST-NNN` acceptances use `Original severity: TEST (suspected defect)`.
2. **READY_TO_COMMIT.** When every termination predicate in [references/transitions.md](references/transitions.md) holds, stop and report: outcome summary, clickable links to the IMPL report and the LOOP file, open `[NORMAL]`/`[LOW]` findings, and applied ARs. Say which two axes ran, so the user knows what was *not* reviewed. `commit-code` / `request-merge` are the user's own actions, outside the loop.

Aborts (BLOCKED_DIRECTION / ESCALATED / FAILED): report the state, the reason, and the LOOP file link, then stop.

## Prohibitions

The loop never: commits, pushes, or creates PR/MRs; writes an AR entry on its own (only the user's explicit Accept in triage does); weakens tests; auto-fixes `[NORMAL]`/`[LOW]` findings; dispatches reviewer agents itself or otherwise merges stage skills and dispatches their Workers directly; silently widens the review to four axes (that is a variant change, and a variant change is the user's call); orchestrates control flow through hooks; exceeds or self-overrides the loop budget; changes plan direction — that requires `plan-dev` re-entry.

## Hooks

Hooks are guardrails, not loop participants. When a hook (e.g. auto-format) changes the working tree or fails after an edit, do not revert or fight it — treat the change or failure as an observation that feeds the next verification stage.

## Checkpointing

Disk is the source of truth: the LOOP file, the plan's TODO checkboxes, and the IMPL report. Append the current round's fields to the LOOP file after **every** stage return, before transitioning. A session can die at any point; resume must work from those three artifacts alone.
