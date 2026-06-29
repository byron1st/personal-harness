---
name: implement-dev
description: Execute a plan-dev implementation plan with TDD, verification, TODO updates, and repository-local implementation reports under docs/agents. Use when the user asks to implement a saved single-step or multi-step plan.
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report under `docs/agents/dev`.

## Global Rules (apply to both modes)

### 1. Keep the plan's TODO list current - update immediately

Each TODO / Task checkbox in the plan file must be flipped from `- [ ]` to `- [x]` **the moment that item is complete**. Do **not** batch updates to the end. This applies to:

- `## TODOs` and `## Verification` checklists in a single-step plan file.
- `## Tasks` and `## Completion Checklist` in a multi-steps **sub-plan** (`-STEP-N.md`) - the currently executing step.
- (Optional but recommended) the `## Steps Overview` table in the multi-steps **main plan** once an entire step is done.

This contract ensures that work can be paused and resumed at any time with no ambiguity about what has shipped.

### 2. TDD - Red-Green-Refactor

All new behavior is built test-first:

1. **Red** - write a failing test that defines the desired behavior. The test must fail (or not compile) to prove it is valid and the behavior does not accidentally exist.
2. **Green** - write the minimum production code to make the test pass. Do not optimize or handle edge cases yet.
3. **Refactor** - improve names, remove duplication, simplify structure while keeping tests green. Not optional; skipping it accumulates mess.

After the happy-path is green, add edge-case tests (boundary values, error paths, empty inputs, concurrency, etc.). Each edge case is its own Red -> Green -> Refactor mini-cycle.

**Exception**: pure documentation, configuration, or trivially obvious one-line changes where a test would add no signal. When in doubt, write the test.

### 3. Multi-steps: Codex delegation is explicit

Codex only spawns subagents when the user explicitly asks for subagents, delegation, or parallel agent work. In **multi-steps** mode:

- If the user explicitly requested delegation for this implementation run, the main session spawns one Codex `worker` agent per step, sequentially. The worker runs the per-step build: branch creation, sub-plan TDD work, build verification, completion report, commit, and returns a concise summary.
- Otherwise, the main session implements each step directly, still one step at a time, using the same branch, TDD, verification, report, commit, and review-gate contracts.

Do not spawn a subagent just because the plan is multi-steps. The Codex delegation path and the main-session fallback are defined in [references/multi-steps-implement.md](references/multi-steps-implement.md).

### 4. Multi-steps: per-step review gate (no auto-merge)

Steps are executed **one at a time, sequentially**. After step N is complete:

1. The completion report (including a `## Manual Verification` checklist) has been written under `docs/agents/dev`.
2. The main session **pauses** and presents the step summary, especially the Red Flags, Open Questions, and Manual Verification items, and waits for the user's explicit approval. Manual checks performed by the user are part of this gate.
3. Only after approval does the main session merge `feature/step-N` into `develop` and start the next step.

Because every step blocks on a user review, **do not run steps in parallel**. Execute steps strictly in dependency order, one after another.

## Prepare

1. **Plan file(s)**: the user provides the plan path. If the prompt omits it, ask.
2. **Mode detection** - inspect the plan file and decide:
   - Frontmatter `PlanType: multi-steps` -> **multi-steps**
   - Body contains Markdown links to `-STEP-N` sub-plan files -> **multi-steps**
   - Otherwise -> **single-step**
   - If ambiguous, ask the user once.
   - State the decided mode to the user in one sentence before proceeding.
3. **Verification commands**: extract lint, format, test, and build commands from `Makefile`, `AGENTS.md`, `CLAUDE.md`, or `README.md`. If none are found, ask the user.
4. **Project conventions**: read `AGENTS.md` / `CLAUDE.md`; their constraints apply to every implementation decision.

## Execute

Follow the reference document for the decided mode:

- single-step -> [references/single-step-implement.md](references/single-step-implement.md)
- multi-steps -> [references/multi-steps-implement.md](references/multi-steps-implement.md)

## Report

Both modes write completion reports under `docs/agents/dev/`. File naming, content format, the review-cockpit layout, and the plan/report Markdown link convention are in [references/report-file.md](references/report-file.md).

After saving the report file, do **not** paste report sections verbatim into the session. As the final output, provide only a short implementation-report summary (2-4 bullets or 2-3 sentences covering what changed, verification status, and any red flags/open questions) plus the report path as a clickable Markdown file link. The full report remains the source of truth for `## Summary`, `## Review Map`, `## Red Flags`, `## Open Questions`, `## Change Walkthrough`, and the detailed sections below them.

- **single-step**: summarize the single completion report and link to it.
- **multi-steps**: summarize the final summary report and link to it. Do not print each per-step report; they were already surfaced at each step's review gate.

## Error Recovery

When verification fails:

1. **Read the error carefully** - understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** - if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** - do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** - if you notice a failure mid-work, fix it before moving on. Do not accumulate failures.
5. **Stop after 3 failed attempts on the same error** - describe what you tried and what you observed, and ask the user for guidance.

## Completion

- All plan TODO/Task checkboxes are up to date.
- The completion report is saved under `docs/agents/dev`, and the plan/report Markdown links are bidirectional.
- `AGENTS.md` / `CLAUDE.md` / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.
- For **multi-steps**: final verification on `develop` passes, and the user sees a summary of completed/skipped/deviated steps. The `develop -> main` merge is left to the user.
