---
name: implement-dev
description: Execute an implementation plan produced by `plan-dev`. Auto-detects mode from the plan file — single-step (one plan file → one implementation pass in the main session) or multi-steps (main plan + `-STEP-N` sub-plans → each step delegated to a fresh sub-agent that builds on a `feature/step-N` branch off `develop` and returns only a concise summary, so the main session's context stays free of per-step implementation noise). After each step the main session pauses for user review and explicit approval before merging back to `develop`. Applies TDD Red-Green-Refactor in both modes, updates the plan's TODO/task checkboxes immediately as each item is completed, records any required manual verification in the step's report, and writes completion reports to Obsidian `02. Implementation Reports`. Use after `plan-dev` produces a plan or when the user asks to implement against an existing plan file.
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report in Obsidian.

## Global Rules (apply to both modes)

### 1. Keep the plan's TODO list current — update immediately

Each TODO / Task checkbox in the plan file must be flipped from `- [ ]` to `- [x]` **the moment that item is complete**. Do **not** batch updates to the end. This applies to:

- `## TODOs` and `## Verification` checklists in a single-step plan file.
- `## Tasks` and `## Completion Checklist` in a multi-steps **sub-plan** (`-STEP-N.md`) — the currently executing step.
- (Optional but recommended) the `## Steps Overview` table in the multi-steps **main plan** once an entire step is done.

This contract ensures that work can be paused and resumed at any time with no ambiguity about what has shipped.

### 2. TDD — Red-Green-Refactor

All new behavior is built test-first:

1. **Red** — write a failing test that defines the desired behavior. The test must fail (or not compile) to prove it is valid and the behavior does not accidentally exist.
2. **Green** — write the minimum production code to make the test pass. Do not optimize or handle edge cases yet.
3. **Refactor** — improve names, remove duplication, simplify structure while keeping tests green. Not optional — skipping it accumulates mess.

After the happy-path is green, add edge-case tests (boundary values, error paths, empty inputs, concurrency, etc.) — each edge case is its own Red → Green → Refactor mini-cycle.

**Exception**: pure documentation, configuration, or trivially obvious one-line changes where a test would add no signal. When in doubt, write the test.

### 3. Multi-steps: each step runs in a sub-agent (clean main context)

In **multi-steps** mode, the main session does **not** implement steps directly. For each step it invokes the `Agent` tool (subagent_type `general-purpose`) with a self-contained prompt; the sub-agent runs the entire per-step build — branch creation, sub-plan TDD work, build verification, completion report, commit — and returns a concise summary back. The main session only orchestrates: dispatch each step, present the returned summary at the review gate, and (after approval) merge `feature/step-N` into `develop`.

This keeps the main session's context free of per-step implementation noise — file edits, test runs, and verification output stay inside the sub-agent and are discarded when it returns. Only the orchestration trail and per-step summary fields accumulate in the main context.

The sub-agent's prompt and return contract are defined in [references/multi-steps-implement.md](references/multi-steps-implement.md) sections 4–5; the sub-agent's own per-step work (TDD per task, verify, report, commit) lives there too.

### 4. Multi-steps: per-step review gate (no auto-merge)

Steps are executed **one at a time, sequentially**. After the sub-agent for step N returns:

1. The completion report (including a `## Manual Verification` checklist) has been written to Obsidian by the sub-agent.
2. The main session **pauses** and presents the sub-agent's returned summary — especially the Manual Verification items — and waits for the user's explicit approval. Manual checks performed by the user are part of this gate.
3. Only after approval does the main session merge `feature/step-N` into `develop` and dispatch the next step's sub-agent.

Because every step blocks on a user review, **do not dispatch steps in parallel** — there is no benefit, and parallelism conflicts with the review gate. Execute steps strictly in dependency order, one after another.

## Prepare

1. **Plan file(s)**: the user provides the plan path. If the prompt omits it, ask.
2. **Mode detection** — inspect the plan file and decide:
   - Frontmatter `PlanType: multi-steps` → **multi-steps**
   - Body contains wikilinks to `-STEP-N` sub-plan files → **multi-steps**
   - Otherwise → **single-step**
   - If ambiguous, ask the user once with `AskUserQuestion`.
   - State the decided mode to the user in one sentence before proceeding.
3. **Verification commands**: extract lint, format, test, and build commands from `Makefile`, `AGENTS.md`, `CLAUDE.md`, or `README.md`. If none are found, ask the user.
4. **Project conventions**: read `AGENTS.md` / `CLAUDE.md` — their constraints apply to every implementation decision.

## Execute

Follow the reference document for the decided mode:

- single-step → [references/single-step-implement.md](references/single-step-implement.md)
- multi-steps → [references/multi-steps-implement.md](references/multi-steps-implement.md)

## Report

Both modes write completion reports to Obsidian at `${OBSIDIAN_HOME}/02. Implementation Reports/`. File naming, content format, and the plan ↔ report wikilink convention are in [references/report-file.md](references/report-file.md).

After saving the report file, also print the report's full content as the session's final output to the user — not a paraphrase or shortened version. The user should see exactly what was written to Obsidian without having to open the file.

- **single-step**: print the single completion report.
- **multi-steps**: print only the final summary report (the `multi-steps-summary` document). Do not print each per-step report — they remain in Obsidian for reference.

## Error Recovery

When verification fails:

1. **Read the error carefully** — understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** — if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** — do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** — if you notice a failure mid-work, fix it before moving on. Don't accumulate failures.
5. **Stop after 3 failed attempts on the same error** — describe what you tried and what you observed, and ask the user for guidance.

## Completion

- All plan TODO/Task checkboxes are up to date.
- The completion report is saved in Obsidian and the plan ↔ report wikilinks are bidirectional.
- `AGENTS.md` / `CLAUDE.md` / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.
- For **multi-steps**: final verification on `develop` passes, and the user sees a summary of completed/skipped/deviated steps. The `develop → main` merge is left to the user.
