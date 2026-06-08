# Multi-steps implementation

Use this reference when `implement-dev` is operating in **multi-steps** mode — a main plan file linking to `-STEP-N` sub-plans, each a complete build-test cycle. The **main session** orchestrates one step at a time. If the user explicitly requested subagents, delegation, or parallel agent work for this implementation run, the main session dispatches each step to a fresh Codex `worker` agent that runs the actual TDD work on a `feature/step-N` branch off `develop`, then handles the per-step review gate and the merge back to `develop`. Otherwise, the main session performs the same per-step work itself.

Throughout this document each section is labelled with the actor that runs it: **[main session]**, **[worker]**, or **[worker/main session]**.

## 1. Read the main plan [main session]

Read the main plan file end-to-end. Collect:

- `## Steps Overview` — the full list of steps, titles, and dependencies.
- `## Execution Flow` — the order steps must be implemented in (dependencies dictate sequence).
- `## Sub-plans` — wikilinks to each `-STEP-N` file; resolve each wikilink to its absolute path in `${OBSIDIAN_HOME}/00. Plans/`.
- `## Conventions` / `## Tech Stack` / `## Architecture Overview` — context every step must respect; pass these to every worker when delegating, or keep them in view when working in the main session.
- `## Requirements Coverage` (if SPEC.md was input) — FR → step mapping.

## 2. Branch setup [main session]

Ensure a `develop` branch exists and is up to date:

```bash
git checkout develop 2>/dev/null || git checkout -b develop
git pull --ff-only || true
```

## 3. Orchestration loop [main session]

Walk the steps in dependency order from `## Execution Flow`. **Execute one step at a time, sequentially.** For each step:

1. **Run** step N:
   - Delegation explicitly requested: dispatch a Codex `worker` agent (section 4). Wait for it to return.
   - No delegation request: perform the per-step work directly in the main session (section 5).
2. **Present** the step summary — especially the Red Flags, Open Questions, and `## Manual Verification` items — to the user.
3. **Wait** for explicit user approval. If the user requests changes, use a follow-up `worker` only when delegation was explicitly requested; otherwise make the follow-up changes in the main session. Re-request approval and do not merge until approved.
4. **Merge** `feature/step-N` into `develop` (section 6), delete the feature branch, run post-merge validation.
5. Move on to step N+1.

Do not start step N+1 until step N has been approved and merged. When using a `worker`, the main session does not re-read the per-step report file or pull implementation details into its own context — everything it needs is in the worker's returned summary.

## 4. Dispatch the step worker [main session]

Use this section only when the user explicitly requested subagents, delegation, or parallel agent work. Spawn a Codex `worker` agent with a self-contained prompt. Do not fork the parent conversation unless the user explicitly asked for that; the prompt must include every input the worker needs. The worker inherits the parent sandbox and approval policy, so do not assume it has independent permissions.

### 4.1 What to pass in the worker's prompt

- The step number `N` and the step title.
- Absolute paths to:
  - the main plan file,
  - the sub-plan file (`-STEP-N.md`),
  - this skill's `SKILL.md` and `references/report-file.md` (so the worker can follow the global rules and the report format).
- The project root, `${OBSIDIAN_HOME}`.
- The verification commands the main session extracted in Prepare (lint, format, test, build).
- A directive to read `AGENTS.md` / `CLAUDE.md` before coding so it inherits project conventions.
- The branch contract: create `feature/step-N` off `develop`, commit when done, **do not merge** — the main session owns the merge.
- The TDD contract: Red → Green → Refactor per task, edge-case tests after, test public/exported methods only.
- The plan-update contract: tick each `- [ ]` → `- [x]` in the sub-plan file immediately as the task is completed (do not batch).
- The reporting contract: write the per-step completion report to `${OBSIDIAN_HOME}/02. Implementation Reports/{base}-STEP-N.md` per `references/report-file.md`, with a `## Manual Verification` section, and add a bidirectional wikilink from the sub-plan.
- The return contract (section 4.2).
- The error-recovery contract: stop after 3 failed attempts on the same error and return `blocked` with what was tried.

### 4.2 What the worker must return

The worker's single return message is the only thing that enters the main session's context, so it must carry everything the main session needs to drive the review gate. Required fields:

- **Status**: `success` | `blocked` | `failed`.
- **Report path**: absolute path to the completion report in Obsidian (so the user can open it if they want detail).
- **Branch**: feature branch name and the latest commit SHA.
- **Red Flags**: the report's `## Red Flags` list copied verbatim (each id + `file:line` + one line), or `None`. The main session surfaces these at the review gate — they are the AI-specific signals most worth the user's distrust.
- **Open Questions**: the report's `## Open Questions` list copied verbatim (each id + `file:line` + one line), or `None`. The reviewer can answer by id.
- **Manual Verification items**: the bullet list copied verbatim from the report's `## Manual Verification` section. Write `None` if there is nothing to verify manually. The main session presents these directly to the user — it does not re-read the report file.
- **Files changed**: short bullet list of changed paths (no diffs).
- **Deviations**: any deviations from the sub-plan and the reason. Omit the field if none.
- **Notes**: anything else the user should see before approving (e.g., flaky test investigation, follow-ups suggested).

The full report content lives in Obsidian; the worker must **not** dump the entire report into its return message.

### 4.3 Follow-up dispatch when the user requests changes

If the user asks for changes after reviewing the report and delegation was explicitly requested, dispatch a follow-up `worker`. The follow-up prompt mirrors section 4.1 plus:

- A note that `feature/step-N` already exists with commits — switch to it, do not re-create it.
- The specific change requests from the user (verbatim).
- A directive to update the existing report in place (do not create a new file), tick any Manual Verification items the user has already confirmed, and re-commit on the same branch.

Loop sections 3.2–3.3 (present → review) until the user approves.

## 5. Per-step work [worker/main session]

The worker or main session performs the following sequence and produces the summary defined in section 4.2.

### 5.1 Create the step branch

```bash
git checkout develop
git pull --ff-only || true
git checkout -b feature/step-N    # or: git checkout feature/step-N for a follow-up dispatch
```

### 5.2 Read the sub-plan

Resolve the sub-plan wikilink to `${OBSIDIAN_HOME}/00. Plans/{base}-STEP-N.md` and read:

- `## Goal`, `## Implements`, `## Depends On`
- `## Tasks` — the atomic work items (checkbox list)
- `## Affected Files`
- `## Tests` — what to test and scenarios
- `## Build Verification` — commands that must pass
- `## Completion Checklist`

### 5.3 Implement with TDD

For each task in `## Tasks`:

1. **Red** — write a failing test that expresses the expected behavior. The test must fail (or not compile).
2. **Green** — write the minimum production code to make the test pass.
3. **Refactor** — improve names, remove duplication, simplify. Keep tests green. Not optional.
4. **Expand** — add edge-case tests derived from the sub-plan's `## Tests` scenarios (boundaries, error paths, etc.). Each edge case is its own Red → Green mini-cycle.
5. **Check off the task** — immediately flip the task's `- [ ]` to `- [x]` in the sub-plan file. Do not batch.

Testing rules:
- Match the existing test style and structure.
- Test **public/exported** methods. No tests for internal helpers.
- Exception to TDD: pure scaffolding (directory creation, empty config) where a test adds no signal.

### 5.4 Verify

Run the sub-plan's `## Build Verification` commands:

```bash
# Adapt to the project's tech stack:
make lint && make test && make build
# or: npm run lint && npm test && npm run build
# or: go vet ./... && go test ./... && go build ./...
```

All must pass. If anything fails, follow Error Recovery in SKILL.md.

Tick each item in `## Completion Checklist` as it is satisfied.

### 5.5 Write the step completion report (with Manual Verification)

Create the step-level completion report in Obsidian following [report-file.md](report-file.md). The report filename matches the sub-plan: `{base}-STEP-N.md` stored in `${OBSIDIAN_HOME}/02. Implementation Reports/`. The report links back to the sub-plan (and, by extension, the main plan) via wikilink.

**Manual Verification section — required.** The report must include a `## Manual Verification` section that lists everything the user must check by hand before approving the merge: UI behavior, third-party integrations, external side effects, content/copy review, visual regressions, data migrations, configuration changes on shared environments, etc. Each item is a checkbox `- [ ]` with concrete steps to verify it. If there is genuinely nothing to verify manually, write a single line `None` — do not omit the section.

**Review cockpit — required.** Fill the report's `## Summary`, `## Review Map`, `## Red Flags`, and `## Open Questions` sections per [report-file.md](report-file.md); write `None` in Red Flags / Open Questions only when genuinely empty. The Red Flags and Open Questions are surfaced in the step summary (section 4.2) and drive the review gate, so they must reflect this step's real risks and uncertainties.

Add a wikilink to the report at the top of the sub-plan file so the link is bidirectional.

### 5.6 Commit and summarize

Commit the step implementation on `feature/step-N` (the report lives in Obsidian, not the repo). **Do not merge** — that is the main session's responsibility.

```bash
git add -A
git commit -m "feat: implement step N - {title}"
```

If running in a worker, return the summary defined in section 4.2 as the worker's single final message. If running in the main session, prepare the same fields as the step summary for the review gate.

## 6. Review gate and merge [main session]

**Do not merge to `develop` automatically.** After the step work completes:

1. Present the step summary to the user — especially the Red Flags, Open Questions, and `## Manual Verification` checklist.
2. Wait for the user to perform any manual verification and to give **explicit approval** to proceed.
3. If the user requests changes, run section 4.3 only when delegation was explicitly requested; otherwise make the follow-up changes in the main session. Do not merge until approval is given.

Only after the user approves:

```bash
git checkout develop
git merge --no-ff feature/step-N -m "Merge step N: {title}"

# Clean up
git branch -d feature/step-N
```

Then run post-merge validation on `develop` to catch integration issues:

```bash
make lint && make test && make build
```

If this fails, the merge introduced a regression. Investigate; for non-trivial fixes, use a fresh worker on a `hotfix/step-N` branch only when delegation was explicitly requested. Otherwise fix in the main session.

(Optional) Tick the row for this step in the main plan's `## Steps Overview` once the merge is complete.

## 7. Completion [main session]

When all steps are merged and the final validation on `develop` passes:

1. Run the full verification suite one final time on `develop`.
2. Write a **final summary report** (optional but recommended) at `${OBSIDIAN_HOME}/02. Implementation Reports/{base}.md` — a top-level report that links to each `-STEP-N` report via wikilink and summarizes overall outcomes, deviations, and coverage. Add a wikilink to this summary report at the top of the main plan. The main session writes this directly using the per-step summaries it already collected; no worker is needed for this small synthesis task.
3. Report to the user: which steps completed, any deviations, overall test coverage. The `develop → main` merge is left to the user to perform manually.
