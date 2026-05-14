# Multi-steps implementation

Use this reference when `implement-dev` is operating in **multi-steps** mode — a main plan file linking to `-STEP-N` sub-plans, each a complete build-test cycle. Steps are implemented **sequentially**, one at a time, on a `feature/step-N` branch off `develop` using TDD. After each step, the user reviews the completion report (including any manual verification items) and explicitly approves before the agent merges to `develop` and moves on to the next step.

## 1. Read the main plan

Read the main plan file end-to-end. Collect:

- `## Steps Overview` — the full list of steps, titles, and dependencies.
- `## Execution Flow` — the order steps must be implemented in (dependencies dictate sequence).
- `## Sub-plans` — wikilinks to each `-STEP-N` file; resolve each wikilink to its absolute path in `${OBSIDIAN_HOME}/00. Plans/`.
- `## Conventions` / `## Tech Stack` / `## Architecture Overview` — context every step must respect.
- `## Requirements Coverage` (if SPEC.md was input) — FR → step mapping.

## 2. Branch setup

Ensure a `develop` branch exists and is up to date:

```bash
git checkout develop 2>/dev/null || git checkout -b develop
git pull --ff-only || true
```

## 3. Step execution order

Walk the steps in dependency order from `## Execution Flow`. **Execute one step at a time, sequentially.** For each step:

1. Implement the step on a `feature/step-N` branch off `develop` (sections 4.1–4.5).
2. Pause and present the step's completion report — including the `## Manual Verification` checklist — to the user.
3. Wait for explicit user approval. Address any requested changes on the same `feature/step-N` branch and re-request approval; do not merge until approved.
4. Only after approval, merge to `develop`, delete the feature branch, and run post-merge validation (section 4.6).
5. Move on to step N+1.

Do not start step N+1 until step N has been approved and merged.

## 4. Per-step execution

Each step is implemented on its own `feature/step-N` branch off `develop`.

### 4.1 Create the step branch

```bash
git checkout develop
git pull --ff-only || true
git checkout -b feature/step-N
```

### 4.2 Read the sub-plan

Resolve the sub-plan wikilink to `${OBSIDIAN_HOME}/00. Plans/{base}-STEP-N.md` and read:

- `## Goal`, `## Implements`, `## Depends On`
- `## Tasks` — the atomic work items (checkbox list)
- `## Affected Files`
- `## Tests` — what to test and scenarios
- `## Build Verification` — commands that must pass
- `## Completion Checklist`

### 4.3 Implement with TDD

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

### 4.4 Verify

Run the sub-plan's `## Build Verification` commands:

```bash
# Adapt to the project's tech stack:
make lint && make test && make build
# or: npm run lint && npm test && npm run build
# or: go vet ./... && go test ./... && go build ./...
```

All must pass. If anything fails, follow Error Recovery in SKILL.md.

Tick each item in `## Completion Checklist` as it is satisfied.

### 4.5 Write the step completion report (with Manual Verification)

Create the step-level completion report in Obsidian following [report-file.md](report-file.md). The report filename matches the sub-plan: `{base}-STEP-N.md` stored in `${OBSIDIAN_HOME}/02. Implementation Reports/`. The report links back to the sub-plan (and, by extension, the main plan) via wikilink.

**Manual Verification section — required.** The report must include a `## Manual Verification` section that lists everything the user must check by hand before approving the merge: UI behavior, third-party integrations, external side effects, content/copy review, visual regressions, data migrations, configuration changes on shared environments, etc. Each item is a checkbox `- [ ]` with concrete steps to verify it. If there is genuinely nothing to verify manually, write a single line `None` — do not omit the section.

Add a wikilink to the report at the top of the sub-plan file so the link is bidirectional.

Commit the step implementation on `feature/step-N` (the report lives in Obsidian, not the repo):

```bash
git add -A
git commit -m "feat: implement step N - {title}"
```

### 4.6 Pause for user review, then merge on approval

**Do not merge to `develop` automatically.** After the step is committed on `feature/step-N`:

1. Present the step's completion report — especially the `## Manual Verification` checklist — to the user.
2. Wait for the user to perform any manual verification and to give **explicit approval** to proceed.
3. If the user requests changes, address them on the same `feature/step-N` branch, update the report (and tick off any Manual Verification items the user has confirmed), and re-request approval. Do not merge until approval is given.

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

If this fails, the merge introduced a regression — investigate and fix before starting the next step.

(Optional) Tick the row for this step in the main plan's `## Steps Overview` once the merge is complete.

## 5. Completion

When all steps are merged and the final validation on `develop` passes:

1. Run the full verification suite one final time on `develop`.
2. Write a **final summary report** (optional but recommended) at `${OBSIDIAN_HOME}/02. Implementation Reports/{base}.md` — a top-level report that links to each `-STEP-N` report via wikilink and summarizes overall outcomes, deviations, and coverage. Add a wikilink to this summary report at the top of the main plan.
3. Report to the user: which steps completed, any deviations, overall test coverage. The `develop → main` merge is left to the user to perform manually.
