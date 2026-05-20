---
name: test-dev
description: Harden the project's test suite after `implement-dev` (or against the entire codebase) by filling unit-test gaps on public APIs, supplementing e2e tests, and iteratively eliminating LIVED mutants from mutation testing. Auto-detects scope from the current session — if `implement-dev` results are present, target the newly implemented code; otherwise target the entire codebase. Use whenever the user asks to "테스트 보강", "harden tests", "improve test coverage", "kill mutants", "mutation test 돌려서 살아남은 거 잡아줘", or invokes the skill manually after `implement-dev` finishes.
---

# Test Dev

Harden the project's test suite in three sequential phases — unit-test gap filling, e2e-test gap filling, and mutation-test LIVED elimination — and report the result inline in the chat. No file artifacts are produced.

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

When a legitimately written test breaks and the failure looks like a real defect in business logic, **do not fix it**. Record the suspected defect (file, line, observed vs expected behavior, the test that surfaced it) into a running list, **leave the failing test in place** unless leaving it red blocks subsequent tests from running, and continue to the next gap. After all phases finish, report the collected defects to the user as part of the final summary.

If keeping the failing test red blocks the rest of the run (e.g. it hangs the suite or corrupts shared state), **skip it** with the framework's standard skip mechanism (`t.Skip`, `it.skip`, `@pytest.mark.skip`) annotated with a comment pointing to the suspected defect, and add the skipped test to the same defect list. Do not weaken the assertions to make it pass.

## Determine Scope

Decide which code is in scope before any analysis:

1. **Session has `implement-dev` results** — check the conversation for an `implement-dev` invocation, an Implementation Report content, or files modified during this session. If yes, the scope is the files added/modified by that run.
   - Prefer the report's `## Implementation Flow` section as the file list when it is available.
   - Otherwise diff against the pre-`implement-dev` state (e.g. `git diff develop...HEAD`, or stash/log inspection) to recover the file list.
2. **No `implement-dev` results in session** → scope is the entire codebase.

State the decided scope to the user in one sentence before proceeding (e.g. "Scope: 4 files modified by this session's implement-dev run." / "Scope: entire codebase — no implement-dev result detected in this session.").

## Prepare

1. **Verification commands**: extract lint, unit, e2e, and mutation commands from `Makefile`, `AGENTS.md`, `CLAUDE.md`, or `README.md`. If any required command is missing, ask the user.
2. **E2E layout**: locate where e2e tests live (see [references/e2e-gap-analysis.md](references/e2e-gap-analysis.md) for common conventions). If the project has no e2e suite at all, note this and skip Phase 2 with a single-line justification in the final summary.
3. **Mutation tooling**: find the project's mutation target (typical: `make test-mutation`). If no tooling is configured, ask the user with `AskUserQuestion` how to proceed (skip Phase 3 / nominate a command / install a standard tool).

## Phase 1 — Unit test gaps

Detail: [references/unit-gap-analysis.md](references/unit-gap-analysis.md)

For each in-scope file:

1. Enumerate public/exported functions and methods.
2. For each, locate any existing tests. A function is "covered" if at least one test exercises its happy path.
3. Inspect the function body for obvious branches the existing tests miss — error returns, nil/empty inputs, boundary values, switch arms, select cases, retry loops.
4. For every gap, add a Red → Green test (write a failing test first, then confirm the existing implementation makes it pass). Each edge case is its own Red → Green mini-cycle.
5. Run the unit-test suite. All must pass.

## Phase 2 — E2E test gaps

Detail: [references/e2e-gap-analysis.md](references/e2e-gap-analysis.md)

For in-scope changes that cross a system boundary (HTTP route, DB write, external IO, queue consumer, UI flow), check whether at least one e2e test exercises the happy path end-to-end:

1. Read the existing e2e tests to understand what is already covered.
2. Identify boundary-crossing changes in the in-scope files.
3. For each genuinely uncovered boundary, add an e2e test exercising the happy path (and one obvious failure path if the boundary has user-visible error semantics).
4. Do not duplicate unit-test coverage at the e2e layer — e2e exists to verify integration, not branches.
5. Run the e2e suite. All must pass.

If the project has no e2e harness, skip this phase and note it in the summary.

## Phase 3 — Mutation test LIVED elimination

Detail: [references/mutation-iteration.md](references/mutation-iteration.md)

**Goal**: drive **test efficacy** to **at least 80%**, then push **as high as possible** within a bounded budget. Reaching 0 LIVED mutants is generally infeasible — equivalent mutants and untestable side effects always remain — so the target is a score threshold, not zero.

**Test efficacy** = the mutation-score metric reported by the tool (`KILLED / (KILLED + LIVED)`, with EQUIVALENT/ERROR/TIMEOUT excluded; NO COVERAGE counted as LIVED unless the tool reports it separately as a coverage gap).

1. Run mutation testing against the in-scope files (use the project's target — typical: `make test-mutation`). If the target supports a path/package filter, restrict to in-scope paths to keep the run tractable.
2. Read the report. Compute or read the test efficacy. List every `LIVED` mutant with file, line, and operator.
3. **Pre-threshold iterations** (efficacy < 80%): iterate with no fixed cap. For each LIVED mutant:
   - Locate the public surface that exercises the mutated code path.
   - Add an assertion or new test case that fails when the mutant is applied.
   - Re-run mutation testing on the affected file/package.
   Continue until efficacy ≥ 80% or no further progress is possible (an iteration adds zero new tests).
4. **Post-threshold iterations** (efficacy ≥ 80%): perform **at most 3 additional iterations** of LIVED hardening to push efficacy higher. Stop early if any iteration adds zero new tests.
5. Stop after 3 attempts on the same individual mutant without progress and surface it to the user with a description of why a distinguishing test seems infeasible (equivalent mutant, untestable side effect, etc.).
6. If efficacy stays below 80% after pre-threshold iterations exhaust their progress, stop and surface the residual LIVED list to the user — do not contort tests to chase the number.

## Final Verification

Run the full lint + unit + e2e suites once more.

- All previously-green tests must remain green. If a pre-existing test broke during the run, it points to a problem the skill caused — investigate by reverting the most recent test change rather than touching production code.
- Newly added tests that surfaced suspected business-logic defects may legitimately remain red (or skipped per Global Rule 6). They do not block completion — they are reported to the user.

If a pre-existing test is red and reverting recent test changes does not restore it, stop and surface the failure to the user with what was tried.

## Output (chat only)

Print a brief summary in the chat — no file artifacts:

- **Scope**: the decided scope and the file list.
- **Phase 1 (Unit)**: number of tests added, key file paths, final pass/fail.
- **Phase 2 (E2E)**: number of tests added, key file paths, final pass/fail (or "skipped — no e2e harness").
- **Phase 3 (Mutation)**: starting efficacy → final efficacy, starting LIVED count → final LIVED count, pre-threshold iterations + post-threshold iterations performed (e.g. `pre 4 / post 3`), or "skipped (reason)". Note explicitly whether the 80% threshold was reached.
- **Remaining attention items**: any LIVED mutants left unresolved with the reason (equivalent mutant, infeasible distinguishing test, refactor needed, etc.).
- **Suspected business-logic defects**: the running list collected per Global Rule 6. For each entry: file:line, the test path that surfaced it (Phase 1/2/3), observed vs expected behavior in one sentence, and whether the test was left red or skipped. This list is the most important attention item — flag it prominently in the summary.

Keep the summary tight. Do not write a separate report file. Do not modify Obsidian Implementation Reports.

## Error Recovery

This skill is test-code-only (Global Rule 6). Production code is **never** edited here, even to "fix" a failing newly-added test. The recovery flow is:

1. **Read the error carefully** — understand whether the failure points to a wrong test, a wrong assumption about behavior, or a suspected defect in production.
2. **If the test itself is wrong** (assertion misstates expected behavior, fixture is incorrect, mock is set up wrong) — adjust the test. This is the only freely-allowed correction.
3. **If the test correctly expresses the intended behavior but production code disagrees** — this is a suspected business-logic defect. Do **not** edit production code. Add it to the running defect list (see Global Rule 6), leave the test red (or skip with annotation if it blocks the suite), and continue.
4. **If a previously-green test broke** because of changes made by this skill — the most recent test-code change is the suspect. Revert the test change and re-evaluate. Do not touch production code to make a previously-green test pass under a new test infrastructure.
5. **Never weaken tests to make them pass** — see Global Rule 3.
6. **Stop after 3 failed attempts on the same error** — record what was tried, what was observed, and add it to the defect list. Continue to the next gap; the user gets the full picture in the final summary.
