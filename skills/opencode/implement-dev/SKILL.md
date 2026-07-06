---
name: implement-dev
description: Execute a plan-dev implementation plan with TDD, verification, TODO updates, and repository-local implementation reports under docs/agents. Use when the user asks to implement a saved plan.
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report under `docs/agents/dev`.

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

The plan is a coarse, human-approved **direction**. Detail-level obstacles it deliberately left open - a helper, an edge case, the *how* of a TODO - are yours to resolve, TDD-first, and record. A **direction-level** conflict - the plan's goal, chosen approach, key decisions, or non-goals turn out wrong or unworkable - **stops work and goes back to the user** before code is written for it, because changing direction silently voids the review the plan received. This is distinct from the stuck-after-3-attempts escalation in Error Recovery: that one fires when you are technically blocked, this one fires when the plan's direction is wrong even though the code would compile. The buckets and the escalation trigger are detailed in [references/implement-flow.md](references/implement-flow.md).

## Prepare

1. **Plan file**: the user provides the plan path. If the prompt omits it, ask.
2. **Verification commands**: extract lint, format, test, and build commands from `Makefile`, `AGENTS.md` (and legacy `CLAUDE.md` when present), or `README.md`. If none are found, ask the user.
3. **Project conventions**: read `AGENTS.md` and legacy `CLAUDE.md` when present; their constraints apply to every implementation decision.

## Execute

Follow [references/implement-flow.md](references/implement-flow.md): read the plan, implement its `## TODOs` test-first, run final verification, refresh project docs, and write the completion report.

## Report

Write the completion report under `docs/agents/dev/`. File naming, content format, the review-cockpit layout, and the plan/report Markdown link convention are in [references/report-file.md](references/report-file.md).

After saving the report file, do **not** paste report sections verbatim into the session. As the final output, provide only a short implementation-report summary (2-4 bullets or 2-3 sentences covering what changed, verification status, and any red flags/open questions) plus the report path as a clickable Markdown file link. The full report remains the source of truth for `## Summary`, `## Review Map`, `## Red Flags`, `## Open Questions`, `## Change Walkthrough`, and the detailed sections below them.

## Error Recovery

When verification fails:

1. **Read the error carefully** - understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** - if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** - do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** - if you notice a failure mid-work, fix it before moving on. Do not accumulate failures.
5. **Stop after 3 failed attempts on the same error** - describe what you tried and what you observed, and ask the user for guidance.

## Completion

- All plan TODO checkboxes are up to date.
- The completion report is saved under `docs/agents/dev`, and the plan/report Markdown links are bidirectional.
- `AGENTS.md` and legacy `CLAUDE.md` when present / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.
