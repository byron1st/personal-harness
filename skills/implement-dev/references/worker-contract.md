# Executor contract

Caller brief, return schema, and chat-summary shape for `implement-dev`. The filename is historical. This file does not start a persona and does not name a host spawn tool.

`implement-dev` references this contract instead of restating it. Do not duplicate these templates elsewhere; update them here.

## A. Who runs this

- **Standalone** — the current session runs the methodology in place and does not start a persona.
- **Loop** — `dev-loop` starts the `implementer` persona as a blocking child. That persona follows `implement-dev` and returns the headings in §C. It does not start another persona.

## B. Caller brief

The loop (or standalone Prepare) fills this, replacing placeholders. It fills the verification-command block from Prepare (`$HOME/.agents/scripts/detect-commands.sh` plus any prose-only commands) so the executor does not rediscover the same commands cold every round. When a value is already in the brief, the executor uses it; when a required value is missing, the executor may run the script itself.

```text
Use the `implement-dev` skill to execute this existing plan-dev plan: {PLAN_PATH}

You operate cold: this is a fresh session with no memory of the planning run. Read the plan end-to-end first, then read each research file the plan links at the relevant TODO before touching code - the plan already did that exploration in the planning session; do not assume you "already know it". Mechanics-level detail (helpers, signatures, edge cases) is yours to decide TDD-first against the running code; the plan does not spell them out and you must not wait for them.

Verification commands (already resolved - use these instead of rediscovering them; re-derive only the ones marked `none`):
- lint: {LINT_CMD or none}
- format: {FORMAT_CMD or none}
- test: {TEST_CMD or none}
- build: {BUILD_CMD or none}

Whenever a `## TODOs` checkbox completes, flip `- [ ]` to `- [x]` in the plan file immediately - do not batch.

Read the plan's `## Acceptance Contract` and `## Authority Boundaries` when present. Record, in the report's `## TODO Fulfillment`, which AC id(s) each TODO fulfills (`AC:` line), and collect each AC's work-specific evidence for your return's `## Evidence`. If the plan has no `## Acceptance Contract` (legacy plan), do not refuse the run: skip AC evidence and record `Acceptance Contract: none (legacy plan)` in the report's `## Summary` and the return's `## Evidence`.

If you hit a direction-level conflict - the plan's goal / chosen approach / `## Key decisions` / `## Non-goals` turn out wrong or unworkable - stop, do not write code for the conflicting TODO, and return `blocked` with the decision needed laid out in `## Decision Needed`. Detail-level obstacles (a helper, an edge case, the *how* of a TODO) are yours to resolve and record in the report; do not escalate them.

On a TODO tagged `(design-bearing)` do not start `plan-consultant`. Return `## Stage Status: needs-design-decision` with the fork brief under `## Design Decision Needed`. TODOs tagged `(mechanical)`, and untagged TODOs from older plans, never consult. A consultant cannot authorize a direction change - if the answer would contradict the plan, return `blocked` instead. Do not mix `needs-design-decision` with `blocked`.

Do not start another persona. Do not run `test-dev` or `review-code`. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

Write the completion report under `docs/agents/dev` per `references/report-file.md`, mirror the plan filename by replacing `_PLAN_` with `_IMPL_`, and add the bidirectional Report/Plan links.

When done, return only the fixed-heading Markdown in section C of `references/worker-contract.md` - do not paste report sections verbatim, link the report by absolute path.
```

## C. Executor return message (②)

Fixed `##` headings, Markdown. The caller parses these headings by name, so the executor must emit them **exactly** and must not invent or rename headings. Anything empty becomes `none` (or its bullets, `none`); never drop a heading.

```markdown
## Stage Status
pass | blocked | failed | needs-design-decision

## Evidence
{one line per AC from the plan's `## Acceptance Contract`: "AC-N: {work-specific proof - command/observation and its result}". When the plan has no `## Acceptance Contract` (legacy plan): exactly "Acceptance Contract: none (legacy plan)"}

## Decision Needed
{only when status is blocked: the direction conflict + the choices the user must pick between. Otherwise "none"}

## Design Decision Needed
{only when status is needs-design-decision: TODO id and title; options A | B; why the wrong pick is expensive to reverse. Otherwise "none"}

## TODO Status
- TODO1: done
- TODO2: done
- TODO4: blocked - {one-line decision needed}

## Implementation Report
{absolute path, or "none"}

## Changed Files
{one absolute path per line, or "none"}

## Verification
{commands run}: {pass/fail}

## Red Flags
{bullets, or "none"}

## Open Questions
{bullets, or "none"}
```

The first headings are the **common stage block** shared across executor-returning skills (`## Stage Status` / `## Evidence` / `## Decision Needed`; other skills add `## Findings`). `## Design Decision Needed` is implement-dev's consultable-fork brief. `## Evidence` carries AC-specific proof only - generic gate results stay under `## Verification`.

`pass` = every TODO fulfilled, verification green, and every AC evidenced under `## Evidence` (legacy plans: the `none (legacy plan)` line recorded instead - an unproven AC blocks `pass`). `blocked` = at least one TODO is blocked on a direction-level decision (no further code should be written past that conflict; detail-level obstacles are not blockers). `failed` = verification failed irrecoverably after `implement-dev`'s Error Recovery, or an unexpected hard error. `needs-design-decision` = a `(design-bearing)` TODO needs a `plan-consultant` decision; the executor did not start that persona. The caller starts `plan-consultant` read-only, then resumes the executor with the decision in the brief. This is not `blocked` and does not consume loop budget.

## D. Caller chat summary (③)

After ② arrives, the caller renders a short summary for the user in chat - **not** ② verbatim, and **not** ①'s sections verbatim. Keep it to:

- 2-4 bullets: what changed / verification status / red-flag and open-question gist / TODO completion at a glance (e.g. "7개 중 6개 완료, TODO4 blocked").
- A clickable Markdown link to the ① report file by absolute path.
- If `## Stage Status` is `blocked`, surface `## Decision Needed` first and prominently so the user sees what to decide, then stop - do not proceed to additional stages.
- If `## Stage Status` is `needs-design-decision`, the loop starts `plan-consultant` and resumes; standalone asks the user. Do not treat it as `blocked`.

Standalone uses the same shape as the final chat output: short bullets + report link, with report sections kept in the file.

## E. Boundary

This contract covers only implementation. `test-dev` and `review-code` keep their own briefs and return schemas; they do not duplicate the implementation-stage contract above. Spawn failure, same-persona `failed` retry, and `plan-consultant` start belong to `dev-loop` (or the standalone user), not to this skill.
