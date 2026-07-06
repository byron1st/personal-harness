---
name: implement-dev
description: Execute a plan-dev implementation plan with TDD, verification, TODO updates, and repository-local implementation reports under docs/agents. Use when the user asks to implement a saved plan.
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report under `docs/agents/dev`.

## Execution modes

`implement-dev` runs in one of two delegated modes, detected from the invoking prompt (the **worker signal**). In Codex, subagent dispatch (Worker) requires the user to explicitly request delegation, subagent, or parallel agent work - auto-dispatch is not assumed.

- **Worker (delegation, subagent - opt-in)** - A session invoked with `You are running as the implementation Worker subagent.` in its prompt. It runs the implementation flow directly ([references/implement-flow.md](references/implement-flow.md)), does not re-dispatch, and returns the fixed-heading Markdown from [references/worker-contract.md](references/worker-contract.md). The dispatcher hands the Worker a self-contained prompt and asks Codex to spawn it as a `worker` agent; the Worker starts cold.
- **Dispatcher (opt-in, main session)** - When the user explicitly requests delegation, the main `implement-dev` session acts as the Dispatcher. The Dispatcher does **not** edit production code, tests, or the report itself; it launches exactly **one** Worker using the prompt, return schema, and chat-summary shape in [references/worker-contract.md](references/worker-contract.md), then parses the Worker's fixed-heading return and renders a short chat summary (what changed / verification / red flags / TODO status) plus a clickable link to the on-disk report. The Dispatcher does not re-dispatch another Worker once one is running.

Interactive (the **default** in Codex): when a session runs `implement-dev` directly in the main session without the user requesting delegation (or when subagent dispatch is not available on the host), the implementation flow ([references/implement-flow.md](references/implement-flow.md)) runs in-place. Follow the Worker rules except that a direction-level conflict goes back to the user interactively rather than being returned as `blocked`. A user simply invoking `implement-dev` from the main chat gets interactive direct execution; Worker dispatch requires explicit opt-in.

## Rules

### 1. Keep the plan's TODO list current - update immediately

Each checkbox in the plan file - the `## TODOs` checklist and any `## Verification` checklist - must be flipped from `- [ ]` to `- [x]` **the moment that item is complete**. Do **not** batch updates to the end.

This contract ensures that work can be paused and resumed at any time with no ambiguity about what has shipped.

### 2. TDD - Red-Green-Refactor

All new behavior is built test-first:

1. **Red** - write a failing test that defines the desired behavior. The test must fail (or not compile) to prove it is valid and the behavior does not accidentally exist.
2. **Green** - write the minimum production code to make the test pass. Do not optimize or handle edge cases yet.
3. **Refactor** - improve names, remove duplication, simplify structure while keeping tests green. Not optional; skipping it accumulates mess.

After the happy-path is green, add edge-case tests (boundary values, error paths, empty inputs, concurrency, etc.). Each edge case is its own Red -> Green -> Refactor mini-cycle.

**Exception**: pure documentation, configuration, or trivially obvious one-line changes where a test would add no signal. When in doubt, write the test.

### 3. Deviations: resolve details, escalate direction

The plan is a coarse, human-approved **direction**. Detail-level obstacles it deliberately left open - a helper, an edge case, the *how* of a TODO - are yours to resolve, TDD-first, and record. A **direction-level** conflict - the plan's goal, chosen approach, key decisions, or non-goals turn out wrong or unworkable - **stops work and goes back before code is written for it**, because changing direction silently voids the review the plan received. This is distinct from the stuck-after-3-attempts escalation in Error Recovery: that one fires when you are technically blocked, this one fires when the plan's direction is wrong even though the code would compile. The buckets and the escalation trigger are detailed in [references/implement-flow.md](references/implement-flow.md).

**Escalation routing depends on mode:**

- **Worker mode** - you are an isolated subagent and **cannot ask the user**. On a direction-level conflict, stop, do not write code for the conflicting TODO, set `## Implementation Status` to `blocked`, and surface the conflict plus the choices in `## Decision Needed` (see [references/worker-contract.md](references/worker-contract.md)). Detail-level obstacles stay yours to resolve and record; never escalate them.
- **Interactive (direct main-session) execution** - ask the user before writing code for the conflicting TODO, then resume after they decide.

The Dispatcher itself never makes direction decisions for the Worker; if the Worker returns `blocked`, the Dispatcher surfaces `## Decision Needed` to the user and stops - it does not retry or self-decide.

## Prepare

1. **Plan file**: the user (Dispatcher / interactive) or the dispatch prompt (Worker) provides the plan path. If the prompt omits it, ask the user (interactive) or surface in `## Open Questions` / `## Decision Needed` (Worker).
2. **Verification commands**: extract lint, format, test, and build commands from `Makefile`, `AGENTS.md`, `CLAUDE.md`, or `README.md`. If none are found, ask the user (interactive) or surface in `## Open Questions` / `## Decision Needed` (Worker).
3. **Project conventions**: read `AGENTS.md` / `CLAUDE.md`; their constraints apply to every implementation decision.

## Execute

Follow [references/implement-flow.md](references/implement-flow.md): read the plan and the research it links, implement its `## TODOs` test-first, run final verification, refresh project docs, and write the completion report.

## Report

The implementation produces three artifacts, defined in [references/report-file.md](references/report-file.md) (①) and [references/worker-contract.md](references/worker-contract.md) (②, ③):

- **① Report file** - the on-disk body under `docs/agents/dev/`, spine `## TODO Fulfillment`. File naming, content format, and the bidirectional plan/report Markdown link convention are in [references/report-file.md](references/report-file.md).
- **② Worker return** - the fixed-heading Markdown the Worker hands back to the Dispatcher. Never paste ① sections into ② - link the report by absolute path under `## Implementation Report`.
- **③ Chat summary** - the Dispatcher renders a short summary (2-4 bullets + clickable report link) for the user, never pasting ① or ② verbatim.

In interactive (non-delegated) execution, the same shape applies as the final chat output: short bullets + report link, with report sections kept in the file.

## Error Recovery

When verification fails:

1. **Read the error carefully** - understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** - if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** - do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** - if you notice a failure mid-work, fix it before moving on. Do not accumulate failures.
5. **Stop after 3 failed attempts on the same error** - describe what you tried and what you observed. In interactive mode, ask the user for guidance; in Worker mode, set `## Implementation Status` to `failed` and return.

## Completion

- All plan TODO checkboxes are up to date.
- The completion report (①) is saved under `docs/agents/dev`, and the plan/report Markdown links are bidirectional.
- If running as a Worker, the return message ② uses the fixed headings and links ① by absolute path.
- `AGENTS.md` / `CLAUDE.md` / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.