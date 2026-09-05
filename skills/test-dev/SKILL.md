---
name: test-dev
description: Strengthen tests by filling unit/e2e gaps and reducing LIVED mutation survivors against a git-defined scope. Use after implementation or when asked to improve coverage, harden tests, or kill mutants.
---

# Test Dev

Harden the project's test suite against a **git-defined scope** in three sequential phases — unit-test gap filling, e2e-test gap filling, and mutation-test LIVED elimination — and report the result inline in the chat. No file artifacts are produced.

This skill is methodology. It does not start a persona. Standalone (`/test-dev`, no loop): the current session runs this flow in place. Under `dev-loop`: the loop starts the `tester` persona, and that persona follows this skill.

`test-dev` reads changed code with the same **fresh, unanchored perspective** as `review-code`: the scope is a diff (or the whole tree), never the author's session narrative. This is deliberate — an agent that did not write the code spots the untested branch the author's mental model skips over.

## Who runs this

- **Standalone** — the current session is the executor. Resolve scope, run the three phases, ask the user when a decision is needed. Do not start a persona.
- **Loop** — the `tester` persona is the executor. It receives the resolved scope and verification commands in the caller brief, does not re-derive scope from conversation, cannot ask the user, and returns the fixed headings in [references/worker-contract.md](references/worker-contract.md).

## Global Rules

### 1. Test public/exported surface only

Add tests against public/exported functions, methods, HTTP/CLI entry points, and other public boundaries. Internal/private helpers are exercised indirectly through the public surface. This matches `implement-dev`'s rule and keeps tests resilient to refactors.

### 2. Match the existing test style

Before adding any new test, read the project's existing tests. Follow the same naming convention, file layout, helper utilities, fixtures, mocking style, and table-driven patterns. Do not import new test frameworks or assertion libraries unless none exist.

### 3. Never weaken a test to make it pass

If a mutant LIVES, the fix is to add an assertion or new test case that distinguishes the mutated behavior from the original — never relax an existing test, remove an assertion, or skip a test. The same rule applies for unit/e2e gap filling.

### 4. Verify after each phase

After each phase ends, run the project's lint + unit (+ e2e where appropriate) suites and confirm they pass before moving to the next phase. If anything fails, follow Error Recovery (same procedure as `implement-dev`).

### 5. Honor project conventions

Read `AGENTS.md` / `CLAUDE.md` at repository root (and any nested copies relevant to changed files). Their constraints and testing rules — coverage policy, mock policy, allowed dependencies, layout conventions — override the defaults in this skill.

### 6. Test-code only — never touch business logic

This skill is **strictly read-only** with respect to production/business logic. Across all three phases, only files that exist to test the system may be added, modified, or deleted — production source files, configuration that drives runtime behavior, and project documentation must not be edited by this skill.

What counts as test code (writable here):
- Unit test files (`*_test.go`, `*.test.ts(x)`, `*.spec.ts(x)`, `test_*.py`, `*_test.py`, `*Test.java`, `*Spec.kt`, `tests/` folders, etc.).
- E2E / integration test files and their dedicated fixtures, factories, page objects.
- Test-only helpers / mocks / stubs / harness scaffolding that no production code imports.
- Test-only configuration (e.g. `jest.e2e.config.ts`, `stryker.conf.json`, `playwright.config.ts`, `make` targets used purely by tests).

What is **not** writable here, even if a newly added test fails because of it:
- Application source code (handlers, services, repositories, components, hooks, domain models, etc.).
- Production configuration consumed at runtime.
- Database migrations, schema files, infrastructure-as-code.
- `AGENTS.md` / `CLAUDE.md` / `README.md` content.

When a legitimately written test breaks and the failure looks like a real defect in business logic, **do not fix it**. Record the suspected defect (file, line, observed vs expected behavior, the test that surfaced it) into a running list - returned as `## Findings`, each entry with an executor-assigned `TEST-NNN` id - **leave the failing test in place** unless leaving it red blocks subsequent tests from running, and continue to the next gap. After all phases finish, report the collected defects to the user as part of the final summary.

If keeping the failing test red blocks the rest of the run (e.g. it hangs the suite or corrupts shared state), **skip it** with the framework's standard skip mechanism (`t.Skip`, `it.skip`, `@pytest.mark.skip`) annotated with a comment pointing to the suspected defect, and add the skipped test to the same defect list. Do not weaken the assertions to make it pass.

## Determine Scope

The **caller** (standalone session, or `dev-loop` at preflight) resolves the scope in git terms **before the executor runs** — the same grammar as `review-code`. A loop executor never re-derives scope from conversation; it receives the resolved scope in its brief.

By default, the scope is the diff between the current branch and `main` (or `origin/main`), including uncommitted and unstaged edits. The user can override:

- "test the latest commit" → `git show HEAD` / `git diff HEAD~1...HEAD`.
- "test uncommitted changes" → `git diff HEAD` plus untracked files.
- "test this file" → only the file they point at.
- "test the whole codebase" → treat the entire tree as in scope.

If the current branch *is* `main`, only staged and unstaged edits are in scope.

Capture the scope once (mirroring `review-code`'s gather step): the diff, the touched files with absolute paths, and the language(s) involved. `$HOME/.agents/scripts/resolve-scope.sh {branch|head|uncommitted|all}` computes the last three as JSON in one call — the diff range, the absolute paths, and the languages are shell facts, not inferences. Read the diff itself with `git diff` over the range it returns. State the decided scope to the user in one sentence (e.g. "Scope: 4 files changed vs `main`." / "Scope: entire codebase.").

If an `implement-dev` report exists for the change, the caller may pass its path as an **optional intent hint** — never as the scope definition. Scope is always the git diff. Keeping the executor's brief lean (diff + conventions, not the author's narrative) preserves the fresh-eyes advantage that makes gap analysis worth isolating.

## Prepare

1. **Verification commands**: if the caller brief already lists resolved commands, use those. Otherwise run `$HOME/.agents/scripts/detect-commands.sh` for the declared lint, unit, e2e, and mutation commands, then fill any `null` from `AGENTS.md`, `CLAUDE.md`, or `README.md` prose. The caller resolves any missing required command before starting a loop executor; a loop executor that still finds one missing returns `blocked` with `## Decision Needed` (standalone asks the user).
2. **E2E layout**: locate where e2e tests live (see [references/e2e-gap-analysis.md](references/e2e-gap-analysis.md) for common conventions). If the project has no e2e suite at all, note this and skip Phase 2 with a single-line justification in the final summary.
3. **Mutation tooling**: find the project's mutation target (typical: `make test-mutation`). If no tooling is configured, standalone asks the user with options (skip Phase 3 / nominate a command / install a standard tool); a loop executor returns `blocked` with those options.

**Caller opt-out**: when the invocation explicitly places mutation out of scope for this run — `dev-loop` modes `light` and `noreview` always do — skip step 3 and Phase 3 entirely, treat `mutation: out of scope` in the brief, and **do not treat a missing mutation command as `blocked`**. Record the skip as `out of scope (caller)` in the `## Mutation` section of the return. This opt-out covers mutation only; a missing lint/unit/e2e command is still resolved before the run or returned as `blocked`.

## Phase 1 — Unit test gaps

Read [references/unit-gap-analysis.md](references/unit-gap-analysis.md) before starting this phase — it carries the procedure (enumerate the public surface → map symbols to existing tests → inspect bodies for missed branches → fill each gap Red → Green).

Target: every public function in the in-scope files has at least one happy-path test, plus tests for the obvious edge cases its body implies.

## Phase 2 — E2E test gaps

Read [references/e2e-gap-analysis.md](references/e2e-gap-analysis.md) before starting this phase — it carries the procedure (locate the harness → identify boundary-crossing changes → map them to existing e2e tests → fill each gap with one happy-path test).

Target: every in-scope change that crosses a system boundary (HTTP route, DB write, external IO, queue consumer, UI flow) has at least one e2e test covering it end-to-end. E2E exists to verify integration — do not duplicate unit-level branch coverage here.

If the project has no e2e harness, skip this phase and note it in the summary.

## Phase 3 — Mutation test LIVED elimination

Read [references/mutation-iteration.md](references/mutation-iteration.md) before starting this phase — it carries the efficacy formula, the per-tool run commands and report states, the distinguishing-test technique, and the iteration budgets (pre-threshold uncapped, post-threshold ≤ 3, per-mutant 3 attempts).

Skip this phase entirely when the caller placed mutation out of scope (see Prepare 3) — a missing mutation command is not a `blocked` condition in that case.

**Goal**: drive **test efficacy** (the mutation-score metric the tool reports) to **at least 80%**, then push **as high as possible** within that budget. Reaching 0 LIVED mutants is generally infeasible — equivalent mutants and untestable side effects always remain — so the target is a score threshold, not zero. If efficacy stalls below 80%, surface the residual LIVED list rather than contorting tests to chase the number.

## Final Verification

Run the full lint + unit + e2e suites once more.

- All previously-green tests must remain green. If a pre-existing test broke during the run, it points to a problem the skill caused — investigate by reverting the most recent test change rather than touching production code.
- Newly added tests that surfaced suspected business-logic defects may legitimately remain red (or skipped per Global Rule 6). They do not block completion — they are reported to the user.

If a pre-existing test is red and reverting recent test changes does not restore it, stop and surface the failure with what was tried — loop executor returns `## Stage Status: failed`; standalone surfaces it to the user.

## Output

The result is delivered as two artifacts — the **executor return (②)** and the **caller chat summary (③)** — whose headings and shapes are defined in [references/worker-contract.md](references/worker-contract.md) §C and §D.

**No file artifact is written, so the return is the deliverable.** That makes one rule outrank brevity in both artifacts: the `## Findings` list (suspected business-logic defects with `TEST-NNN` ids) is carried **verbatim**, never summarised or dropped, and a `pass-with-suspected-defects` return does not auto-proceed to any next stage.

Standalone uses ③ as the final chat output. Do not write a separate report file. Do not modify `docs/agents/dev` implementation reports.

## Error Recovery

This skill is test-code-only (Global Rule 6). Production code is **never** edited here, even to "fix" a failing newly-added test. The recovery flow is:

1. **Read the error carefully** — understand whether the failure points to a wrong test, a wrong assumption about behavior, or a suspected defect in production.
2. **If the test itself is wrong** (assertion misstates expected behavior, fixture is incorrect, mock is set up wrong) — adjust the test. This is the only freely-allowed correction.
3. **If the test correctly expresses the intended behavior but production code disagrees** — this is a suspected business-logic defect. Do **not** edit production code. Add it to the running defect list (see Global Rule 6), leave the test red (or skip with annotation if it blocks the suite), and continue.
4. **If a previously-green test broke** because of changes made by this skill — the most recent test-code change is the suspect. Revert the test change and re-evaluate. Do not touch production code to make a previously-green test pass under a new test infrastructure.
5. **Never weaken tests to make them pass** — see Global Rule 3.
6. **Stop after 3 failed attempts on the same error** — record what was tried, what was observed, and add it to the defect list. Continue to the next gap; the user gets the full picture in the final summary. If the error is irrecoverable or a previously-green test cannot be restored, the loop executor sets `## Stage Status` to `failed` and returns; standalone asks the user for guidance. Suspected business-logic defects are never a `failed` condition — they go to the defect list and are reported.

This skill does not retry `failed` under a different model. The loop may start the same persona once more; that retry is the loop's, not this skill's.
