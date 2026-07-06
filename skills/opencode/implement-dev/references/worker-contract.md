# Worker delegation contract

`implement-dev`'s **Dispatch mode** (the main session, default) delegates the actual implementation to a single OpenCode subagent invoked via the Task tool with `subagent_type: general` (the **Worker**). This file is the **single source of truth** for that delegation: the prompt the dispatcher hands the Worker, the structured Markdown the Worker must return (② in [report-file.md](report-file.md)'s terminology - ① is the on-disk report, ② is the Worker's return message, ③ is the dispatcher's chat summary), and the chat summary the dispatcher owes the user.

`implement-dev` Dispatch references this contract instead of restating it. Do not duplicate these templates elsewhere; update them here.

## A. Worker signal

The Worker detects it is a Worker (not a Dispatcher) from the dispatch prompt itself: the prompt contains the line `You are running as the implementation Worker subagent.` A session that sees this line runs the Worker flow directly (`implement-dev`'s `implement-flow.md` step 1 onward) and **does not re-dispatch** another subagent - that would double-nest. A session that does not see this line is in Dispatch mode and must launch exactly one Worker.

## B. Dispatch prompt

The dispatcher (the main `implement-dev` session) hands the Worker this prompt, replacing placeholders:

```text
You are running as the implementation Worker subagent.

Use the `implement-dev` skill to execute this existing plan-dev plan: {PLAN_PATH}

You operate cold: this is a fresh subagent session with no memory of the planning run. Read the plan end-to-end first, then read each research file the plan links at the relevant TODO before touching code - the plan already did that exploration in the planning session; do not assume you "already know it". Mechanics-level detail (helpers, signatures, edge cases) is yours to decide TDD-first against the running code; the plan does not spell them out and you must not wait for them.

Whenever a `## TODOs` checkbox completes, flip `- [ ]` to `- [x]` in the plan file immediately - do not batch.

If you hit a direction-level conflict - the plan's goal / chosen approach / `## Key decisions` / `## Non-goals` turn out wrong or unworkable - you cannot ask the user (you are an isolated subagent). Stop, do not write code for the conflicting TODO, and return `blocked` with the decision needed laid out in `## Decision Needed`. Detail-level obstacles (a helper, an edge case, the *how* of a TODO) are yours to resolve and record in the report; do not escalate them.

Do not re-dispatch another implementation subagent. Do not run `test-dev` or `review-code`. Do not revert edits made by others. Follow the repository's AGENTS.md and legacy `CLAUDE.md` when present / README.md / Makefile instructions.

Write the completion report under `docs/agents/dev` per `references/report-file.md`, mirror the plan filename by replacing `_PLAN_` with `_IMPL_`, and add the bidirectional Report/Plan links.

When done, return only the fixed-heading Markdown in section C of `references/worker-contract.md` - do not paste report sections verbatim, link the report by absolute path.
```

## C. Worker return message (②)

Fixed `##` headings, Markdown. The dispatcher parses these headings by name, so the Worker must emit them **exactly** and must not invent or rename headings. Anything empty becomes `none` (or its bullets, `none`); never drop a heading.

```markdown
## Implementation Status
pass | blocked | failed

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

## Decision Needed
{only when status is blocked: the direction conflict + the choices the user must pick between. Otherwise "none"}
```

`pass` = every TODO fulfilled, verification green. `blocked` = at least one TODO is blocked on a direction-level decision (no further code should be written past that conflict; detail-level obstacles are not blockers). `failed` = verification failed irrecoverably after `implement-dev`'s Error Recovery, or an unexpected hard error.

## D. Dispatcher chat summary (③)

After the dispatcher receives ②, it renders a short summary for the user in chat - **not** ② verbatim, and **not** ①'s sections verbatim. Keep it to:

- 2-4 bullets: what changed / verification status / red-flag and open-question gist / TODO completion at a glance (e.g. "7개 중 6개 완료, TODO4 blocked").
- A clickable Markdown link to the ① report file by absolute path.
- If `## Implementation Status` is `blocked`, surface `## Decision Needed` first and prominently so the user sees what to decide, then stop - do not proceed to additional stages.

When `implement-dev` runs interactively (not via dispatch), the same shape applies as the final chat output: short bullets + report link, with report sections kept in the file.

## E. Boundary

This contract covers only implementation delegation. `test-dev` and `review-code` keep their own prompts and return schemas; they do not duplicate the implementation-stage contract above.