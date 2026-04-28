# Multi-steps implementation

Use this reference when `implement-dev` is operating in **multi-steps** mode — a main plan file linking to `-STEP-N` sub-plans, each a complete build-test cycle. Steps are implemented in isolated git worktrees using TDD, then merged to `develop`. Independent steps within a phase can run in parallel via subagents.

## 1. Read the main plan

Read the main plan file end-to-end. Collect:

- `## Steps Overview` — the full list of steps, titles, and dependencies.
- `## Execution Flow` — phases and which steps can run in parallel.
- `## Sub-plans` — wikilinks to each `-STEP-N` file; resolve each wikilink to its absolute path in `${OBSIDIAN_HOME}/00. Plans/`.
- `## Conventions` / `## Tech Stack` / `## Architecture Overview` — context every step must respect.
- `## Requirements Coverage` (if SPEC.md was input) — FR → step mapping.

## 2. Branch setup

Ensure a `develop` branch exists and is up to date:

```bash
git checkout develop 2>/dev/null || git checkout -b develop
git pull --ff-only || true
```

## 3. Step dispatch

Walk the phases from `## Execution Flow` in order:

1. Identify the steps in the current phase (all dependencies satisfied).
2. For each step in the phase, **dispatch a subagent in parallel** (steps within a phase have no mutual dependencies). If subagents are not available or the user prefers sequential execution, run them one at a time in dependency order.
3. Wait for all steps in the current phase to complete and merge into `develop` before starting the next phase.
4. After each phase merges, run post-merge validation on `develop` (see section 6).

## 4. Per-step execution (subagent scope)

Each step runs in an isolated git worktree branched from `develop`.

### 4.1 Set up worktree

```bash
git worktree add ../step-N-{short-title} develop -b step-N/{short-title}
cd ../step-N-{short-title}
```

`{short-title}` is a hyphenated slug derived from the step's title.

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

### 4.5 Write the step completion report

Create the step-level completion report in Obsidian following [report-file.md](report-file.md). The report filename matches the sub-plan: `{base}-STEP-N.md` stored in `${OBSIDIAN_HOME}/02. Implementation Reports/`. The report links back to the sub-plan (and, by extension, the main plan) via wikilink.

Add a wikilink to the report at the top of the sub-plan file so the link is bidirectional.

### 4.6 Commit and merge

The report lives in Obsidian, not the repo, so the commit contains implementation only:

```bash
git add -A
git commit -m "feat: implement step N - {title}"

cd ..
git checkout develop
git merge --no-ff step-N/{short-title} -m "Merge step N: {title}"

# Clean up
git worktree remove ../step-N-{short-title}
git branch -d step-N/{short-title}
```

(Optional) Tick the row for this step in the main plan's `## Steps Overview` once the merge is complete.

## 5. Post-phase validation

After all steps in a phase have merged to `develop`, run the full verification suite on `develop` to catch integration issues:

```bash
git checkout develop
make lint && make test && make build
```

If this fails, the phase's merges introduced a regression — investigate and fix before starting the next phase.

## 6. Completion

When all steps are merged and the final post-phase validation on `develop` passes:

1. Run the full verification suite one final time on `develop`.
2. Write a **final summary report** (optional but recommended) at `${OBSIDIAN_HOME}/02. Implementation Reports/{base}.md` — a top-level report that links to each `-STEP-N` report via wikilink and summarizes overall outcomes, deviations, and coverage. Add a wikilink to this summary report at the top of the main plan.
3. Report to the user: which steps completed, any deviations, overall test coverage. The `develop → main` merge is left to the user to perform manually.
