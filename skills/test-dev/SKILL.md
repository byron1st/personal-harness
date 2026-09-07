---
name: test-dev
description: Strengthen tests by filling unit/e2e gaps and reducing LIVED mutation survivors against a git-defined scope. Use after implementation or when asked to improve coverage, harden tests, or kill mutants.
---

# Test Dev

Harden the test suite over a **git-defined scope** in three phases — unit gaps, e2e gaps, mutation LIVED elimination — and report inline. No file artifact is written.

This skill is methodology. It does not start a persona.

- **Standalone** (`/test-dev`) — the current session resolves scope, runs the phases, and asks the user when a decision is needed.
- **Loop** — `dev-loop` starts the `tester` persona, which receives scope and commands in its brief, cannot ask the user, and returns the headings in [references/executor-contract.md](references/executor-contract.md).

Read the scope with **fresh eyes**: the input is a diff, never the author's narrative of what they meant. An agent that did not write the code spots the untested branch the author's mental model skips over — which is the entire reason this stage is separate from `implement-dev`.

## The boundary — test code only

This skill is **strictly read-only with respect to production behavior**. Writable: unit and e2e test files, their dedicated fixtures/factories/page objects, test-only helpers and mocks no production code imports, and test-only configuration (`jest.e2e.config.ts`, `stryker.conf.json`, test-only `make` targets).

Not writable, even when a newly added test fails because of it: application source, production configuration, migrations, schema, infrastructure-as-code, and `AGENTS.md` / `CLAUDE.md` / `README.md`.

**When a legitimate test fails because production code is wrong, do not fix it.** Record it as a finding — file:line, the test path, observed vs expected in one sentence — with a sequential `TEST-NNN` id, leave the test red, and continue to the next gap. If leaving it red blocks the rest of the suite (it hangs, or corrupts shared state), skip it with the framework's standard mechanism annotated with a comment pointing at the suspected defect, and record it the same way. Never weaken an assertion to make it pass.

Two more rules survive from the same instinct: add tests against the **public/exported surface** (internal helpers get exercised through it), and **never relax an existing test** — when a mutant lives, the answer is a new assertion that distinguishes the mutation, not a looser old one.

Repository `AGENTS.md` / `CLAUDE.md` constraints — coverage policy, mock policy, allowed dependencies, layout — override anything in this skill.

## Determine scope

The **caller** resolves scope in git terms before the executor runs; a loop executor never re-derives it from conversation. Default: the diff between the current branch and `main` (or `origin/main`), including uncommitted and unstaged edits. On `main`, only staged and unstaged edits.

Overrides: "the latest commit" → `HEAD`; "uncommitted changes" → `git diff HEAD` plus untracked; "this file" → that file; "the whole codebase" → the entire tree.

`$HOME/.agents/scripts/resolve-scope.sh {branch|head|uncommitted|all}` returns the diff range, absolute changed-file paths, and languages as JSON. State the decided scope in one sentence.

An `implement-dev` report may be passed as an **intent hint only** — scope is always the git diff. Keeping the brief lean is what preserves the fresh-eyes advantage.

## Prepare

1. **Verification commands** — from the caller brief, else `$HOME/.agents/scripts/detect-commands.sh`, filling any `null` from `AGENTS.md` / `CLAUDE.md` / `README.md` prose. A missing required command is `blocked` with `## Decision Needed` (loop) or a question (standalone).
2. **E2E layout** — locate where e2e tests live; the `Makefile`, `package.json` scripts, and `AGENTS.md` name the command. No e2e suite at all → skip Phase 2 with a one-line justification.
3. **Mutation tooling** — find the mutation target (typically `make test-mutation`). None configured → standalone asks (skip / nominate a command / install a standard tool); loop returns `blocked` with those options.

**Caller opt-out**: when the invocation places mutation out of scope for this run — `dev-loop` modes `light` and `noreview` always do — skip step 3 and Phase 3 entirely, and **do not treat a missing mutation command as `blocked`**. Record `out of scope (caller)` under `## Mutation`. This covers mutation only.

## Phase 1 — Unit test gaps

Target: every public function in the in-scope files has at least one happy-path test, plus tests for the obvious edge cases its body implies.

## Phase 2 — E2E test gaps

Target: every in-scope change that crosses a system boundary (HTTP route, DB write, external IO, queue consumer, UI flow) has at least one e2e test covering it end-to-end. E2E verifies integration — do not duplicate unit-level branch coverage here.

If the project has no e2e harness, skip this phase and note it in the summary.

## Phase 3 — Mutation test LIVED elimination

Skip entirely when the caller placed mutation out of scope (see Prepare 3).

**Goal**: drive **test efficacy** to **at least 80%**, then as high as possible within the budget below. Reaching 0 LIVED mutants is infeasible — equivalent mutants and untestable side effects always remain — so the target is a threshold, not zero. If efficacy stalls below 80%, surface the residual LIVED list rather than contorting tests to chase the number.

- **Efficacy** is the tool's own reported score (gremlins "test efficacy", stryker "mutation score", pitest "mutation coverage"), i.e. `KILLED / (KILLED + LIVED)`. Exclude EQUIVALENT and ERROR. **NO COVERAGE counts as LIVED and is really a Phase 1/2 gap** — fill it there and re-run rather than treating it as a mutant.
- **Restrict the run to in-scope paths**; a full-tree mutation run is slow enough to matter. `gremlins unleash ./pkg/...` · `stryker --mutate "src/foo/**/*.ts"` · `mutmut run --paths-to-mutate src/foo/` · `cargo mutants --file src/foo.rs` · `pitest -DtargetClasses=com.example.foo.*`. If the project's target takes no path filter, run it whole the first time and call the underlying tool directly afterwards.
- **A distinguishing test must pass on unmutated code.** If it fails there, the implementation disagrees with its own contract — a suspected defect, not a test to fix. Record it as `TEST-NNN` and move on.
- **Budgets**: uncapped iterations below 80%, at most 3 above it, at most 3 attempts on any single mutant. Stop early when an iteration adds no new killing test. Record what could not be killed (file:line, operator, reason) for the summary.

## Finish

Run the full lint + unit (+ e2e) suites once more. Every previously-green test must still be green — if one broke, the most recent test-code change is the suspect, so revert that rather than touching production code. If reverting does not restore it, return `failed` (loop) or surface it (standalone).

Newly added tests that surfaced suspected defects may legitimately stay red or skipped. They do not block completion; they are the headline of the report.

**The return is the deliverable** — no file artifact exists to fall back on. So one rule outranks brevity in both the executor return and the chat summary: the `## Findings` list is carried **verbatim**, never summarised or dropped, and `pass-with-suspected-defects` never auto-proceeds to a next stage.
