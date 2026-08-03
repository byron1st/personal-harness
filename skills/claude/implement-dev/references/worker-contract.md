# Worker delegation contract

`implement-dev`'s **Dispatch mode** (the main session, default) delegates the actual implementation to a single `implementer` subagent (the **Worker**, dispatched via the `Agent` tool with `subagent_type: implementer`). This file is the **single source of truth** for that delegation: the prompt the dispatcher hands the Worker, the structured Markdown the Worker must return (② in [report-file.md](report-file.md)'s terminology - ① is the on-disk report, ② is the Worker's return message, ③ is the dispatcher's chat summary), and the chat summary the dispatcher owes the user.

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

Read the plan's `## Acceptance Contract` and `## Authority Boundaries` when present. Record, in the report's `## TODO Fulfillment`, which AC id(s) each TODO fulfills (`AC:` line), and collect each AC's work-specific evidence for your return's `## Evidence`. If the plan has no `## Acceptance Contract` (legacy plan), do not refuse the run: skip AC evidence and record `Acceptance Contract: none (legacy plan)` in the report's `## Summary` and the return's `## Evidence`.

If you hit a direction-level conflict - the plan's goal / chosen approach / `## Key decisions` / `## Non-goals` turn out wrong or unworkable - you cannot ask the user (you are an isolated subagent). Stop, do not write code for the conflicting TODO, and return `blocked` with the decision needed laid out in `## Decision Needed`. Detail-level obstacles (a helper, an edge case, the *how* of a TODO) are yours to resolve and record in the report; do not escalate them.

Do not re-dispatch another implementation subagent. Do not run `test-dev` or `review-code`. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

Write the completion report under `docs/agents/dev` per `references/report-file.md`, mirror the plan filename by replacing `_PLAN_` with `_IMPL_`, and add the bidirectional Report/Plan links.

When done, return only the fixed-heading Markdown in section C of `references/worker-contract.md` - do not paste report sections verbatim, link the report by absolute path.
```

## C. Worker return message (②)

Fixed `##` headings, Markdown. The dispatcher parses these headings by name, so the Worker must emit them **exactly** and must not invent or rename headings. Anything empty becomes `none` (or its bullets, `none`); never drop a heading.

```markdown
## Stage Status
pass | blocked | failed

## Evidence
{one line per AC from the plan's `## Acceptance Contract`: "AC-N: {work-specific proof - command/observation and its result}". When the plan has no `## Acceptance Contract` (legacy plan): exactly "Acceptance Contract: none (legacy plan)"}

## Decision Needed
{only when status is blocked: the direction conflict + the choices the user must pick between. Otherwise "none"}

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

The first three headings are the **common stage block** shared across Worker-returning skills (`## Stage Status` / `## Evidence` / `## Decision Needed`; other skills add `## Findings`); the headings below it are implement-dev's own. `## Evidence` carries AC-specific proof only - generic gate results stay under `## Verification` (they are separate completion predicates).

`pass` = every TODO fulfilled, verification green, and every AC evidenced under `## Evidence` (legacy plans: the `none (legacy plan)` line recorded instead - an unproven AC blocks `pass`). `blocked` = at least one TODO is blocked on a direction-level decision (no further code should be written past that conflict; detail-level obstacles are not blockers). `failed` = verification failed irrecoverably after `implement-dev`'s Error Recovery, or an unexpected hard error.

## D. Dispatcher chat summary (③)

After the dispatcher receives ②, it renders a short summary for the user in chat - **not** ② verbatim, and **not** ①'s sections verbatim. Keep it to:

- 2-4 bullets: what changed / verification status / red-flag and open-question gist / TODO completion at a glance (e.g. "7개 중 6개 완료, TODO4 blocked").
- A clickable Markdown link to the ① report file by absolute path.
- One line when a cascade retry fired (§E'): that the first Worker returned `failed` and whether the T1 retry recovered. Never omit this line to keep the summary tidy — it is the metric.
- If `## Stage Status` is `blocked`, surface `## Decision Needed` first and prominently so the user sees what to decide, then stop - do not proceed to additional stages.

When `implement-dev` runs in explicitly authorized direct mode, the same shape applies as the final chat output: short bullets + report link, with report sections kept in the file.

## E'. Cascade — one T1 retry on a `failed` return

**This is a different event from §E.** §E is *dispatch itself* never producing a Worker. Cascade is a Worker that ran, hit its own 3-attempts-per-error wall, and returned `## Stage Status: failed`. Do not merge the two: §E asks the user, cascade does not.

When the Worker returns `failed`, the Dispatcher re-dispatches **exactly once** with the `Agent` tool's call-time `model: opus` argument, which outranks the persona's frontmatter. The retry gets the same prompt plus one line naming what the first attempt tried and observed, so it does not rediscover the same wall. If the second return is also `failed`, pass `failed` up unchanged — do not retry a third time, do not fall back to the main session, and do not escalate the model further.

**The retry is capped at one.** Unbounded promotion turns a stuck Worker into an expensive stuck Worker.

**Always report that it happened.** The Dispatcher's chat summary (③) carries one line: that a T1 retry fired, and whether it succeeded. This line is the only signal that the T2 implementer is under-powered for this class of work — without it there is no way to tell a working tier assignment from a wrong one that keeps getting bailed out.

A loop controller never sees the first `failed`: the retry completes inside the Dispatcher, so `dev-loop*` observes only the final status. The loop's own rule — it never retries a `failed` stage — stays true, and no loop file changes.

## E. Delegation failure

If the `Agent` tool or compatible Worker capability is unavailable, or dispatch fails, the Dispatcher must stop before substantive implementation. It reports `Delegation status: unavailable` or `failed`, includes the observed cause, and uses `AskUserQuestion` to ask whether to continue with direct main-session execution or stop. Direct execution starts only after the user explicitly chooses that fallback; the Dispatcher never silently substitutes itself for a failed Worker and never retries by dispatching another Worker.

## F. Boundary

This contract covers only implementation delegation. `test-dev` and `review-code` keep their own prompts and return schemas; they do not duplicate the implementation-stage contract above.
