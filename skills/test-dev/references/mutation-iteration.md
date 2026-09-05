# Mutation test LIVED elimination

Use this reference for **Phase 3** of `test-dev`. The goal is to drive **test efficacy** to at least **80%**, then push it **as high as possible** within a bounded post-threshold budget. Reaching 0 LIVED mutants is not the goal and is usually infeasible — equivalent mutants and untestable side effects always remain.

## Test efficacy — definition

Use the mutation-score metric the tool reports as the primary number:

- **KILLED** count goes in the numerator.
- **KILLED + LIVED** goes in the denominator.
- **EQUIVALENT**, **ERROR**, and **TIMEOUT** (when the tool treats timeout as killed) are excluded from both.
- **NO COVERAGE** is treated as LIVED unless the tool reports a separate coverage-only score; either way, surface NO COVERAGE entries as Phase 1/2 gaps and re-run after filling them.

Tool-name correspondence:

- gremlins → "Test efficacy"
- stryker → "Mutation score"
- pitest → "Mutation Coverage"
- mutmut / cargo-mutants / go-mutesting → ratio of killed / (killed + survived)

When the tool's ratio definition differs, prefer the tool's reported number and document the formula used in the final summary.

## 1. Locate the mutation target

The convention is a Makefile target, typically `make test-mutation`. Check, in this order:

1. `Makefile` — look for `test-mutation`, `mutation`, `mutate`, `stryker`, `mutmut`, `gremlins`.
2. `package.json` scripts — `"mutation"`, `"stryker"`.
3. `AGENTS.md` / `CLAUDE.md` / `README.md` — explicit instructions.

If found, note both the command and the underlying tool (the tool determines the report format and how to filter by path).

If **not** found, do not decide alone — `SKILL.md`'s `Prepare` step 3 owns that routing (standalone asks the user; a loop executor returns `blocked`). The options to offer are: skip Phase 3, nominate a command, or install the language-standard tool (Go: `go-mutesting` or `gremlins`; Node/TS: `stryker`; Python: `mutmut`; Rust: `cargo-mutants`; Java/Kotlin: `pitest`) — never install anything without the user's confirmation.

## 2. Run mutation testing on the in-scope files

Mutation runs are slow. Restrict the scope as much as the tool allows:

- **gremlins (Go)** — `gremlins unleash ./path/to/pkg/...`
- **go-mutesting** — `go-mutesting --do-not-remove-tmp-folder ./path/to/pkg`
- **stryker (Node/TS)** — configure `mutate` glob in `stryker.conf.{js,json}` to match in-scope paths, or pass `--mutate "src/foo/**/*.ts"`.
- **mutmut (Python)** — `mutmut run --paths-to-mutate src/foo/`
- **cargo-mutants** — `cargo mutants --in-place --file src/foo.rs`
- **pitest** — `mvn pitest:mutationCoverage -DtargetClasses=com.example.foo.*`

If the project's `make test-mutation` target does not accept a path filter, run the full target the first iteration; for subsequent iterations on individual mutants, prefer running the underlying tool directly with a path filter.

## 3. Read the report

Each tool reports a status per mutant. Across tools, the meaningful states are:

- **KILLED** — at least one test failed when the mutant was applied. Good.
- **LIVED** (or **SURVIVED**, **NOT KILLED**) — all tests passed despite the mutation. **This is the gap.**
- **NO COVERAGE** — no test exercises the mutated code at all. Treat as a Phase 1/Phase 2 gap if the line belongs to in-scope code; add a unit test that exercises the line, then re-run.
- **TIMEOUT** — the mutated code likely caused an infinite loop. Usually counts as killed; verify the original code has bounded execution under the same input.
- **EQUIVALENT** — semantically identical to the original (often must be flagged manually). Record and skip.
- **ERROR** — tool internal error. Investigate and re-run.

For each LIVED entry, capture: file path, line number, mutation operator (e.g. `>=` → `>`, conditional negation, return-value swap, statement deletion), and the original source snippet.

## 4. Distinguish each LIVED mutant

This skill is test-code-only (`SKILL.md` Global Rule 6). Production code is read-only here even when adding distinguishing tests.

For each LIVED mutant, design a test that fails when the mutation is applied:

1. **Locate the public surface** that calls the mutated code path (Phase 1 already enumerated public symbols — reuse that map). If only an internal helper is mutated, find the public caller(s) that would observe the difference.
2. **Find an input value where original ≠ mutated**. Most operators have a textbook witness:
   - `>=` → `>` flips at the boundary value: input where `a == b`.
   - `&&` → `||` flips when one side is false and the other is true.
   - Off-by-one in loop bounds: input where the last iteration matters.
   - Return-value swap (e.g. `return true` → `return false`): any input where the original returns the dropped value.
   - Statement deletion: an input where the deleted statement's side effect is observable downstream.
3. **Write the test against the public surface** asserting the original-correct behavior at that input. Run it once on current code — it **must pass on the unmutated code**.
4. **If the new test fails on the unmutated code** — the original behavior is unexpectedly different from what the contract implies. This is a strong suspected business-logic defect signal: the existing implementation is doing something the documented/intended behavior does not match, and that is exactly why the mutant LIVED. Do **not** edit production code. Record the defect (production file:line, the test path, observed vs expected behavior in one sentence), leave the test red or skip it with annotation, and move on. This entry feeds the central defect list reported at the end of the skill.
5. Run unit tests to confirm the new test, when it passes on unmutated code, is green and the previously-green tests are still green.

If you cannot construct a distinguishing test for a particular mutant after honest effort, see step 6.

## 5. Iterate against the efficacy target

After adding tests for the current batch of LIVED mutants, re-run mutation testing on the affected file(s) only and recompute efficacy. The iteration is split into two phases with different budgets.

### 5.a Pre-threshold iterations (efficacy < 80%)

- **No fixed iteration cap.** Keep iterating as long as each iteration adds at least one new test that kills at least one mutant.
- Compare iteration-over-iteration:
  - Efficacy went up → continue with the new LIVED list.
  - Efficacy unchanged but new tests were added → either the new tests didn't actually distinguish (revisit), or the affected mutants are equivalent (mark and exclude).
  - An iteration adds zero new tests because every remaining LIVED mutant looks equivalent or untestable → stop and surface the residual list.
- Stop pre-threshold iterations the moment efficacy reaches 80% — move to post-threshold.

### 5.b Post-threshold iterations (efficacy ≥ 80%)

- **At most 3 iterations.** This is a hard cap — do not exceed it even if more LIVED mutants remain.
- Each iteration: pick the LIVED mutants most likely to have a feasible distinguishing test (skip ones that look equivalent or require refactoring), add the tests, re-run, recompute efficacy.
- Stop early if any iteration adds zero new tests.
- Record the final efficacy after the cap is reached or convergence happens, whichever comes first.

### Per-mutant attempts cap

Independent of the phase: stop after **3 attempts on the same individual mutant** without progress. Record that specific mutant with what was tried (the inputs you tried, the assertions you tried, why none distinguished the mutant) and move on.

### Pre-threshold floor not reached

If pre-threshold iterations exhaust their progress before efficacy hits 80%, stop and surface the residual LIVED list to the user. Do not contort tests, weaken assertions, or chase the number through artificial scenarios — those make tests brittle without adding real signal.

## 6. Record what could not be killed

Some mutants legitimately cannot be killed by a behavioral test:

- **Equivalent mutants** — the mutation produces a semantically identical program (e.g. mutating a constant inside dead code, or a redundant guard).
- **Untestable side effects** — log message wording, internal counter values not exposed publicly, ordering inside a hash-randomized iteration.
- **Refactor opportunities disguised as mutants** — when the only way to kill a mutant is a structural change (extract function, inject dependency), record this as a recommendation rather than forcing a contorted test.

For each such mutant, record file:line, operator, and reason. Surface the list in the final summary so the user can decide.

## 7. Verify

Run the full lint + unit (+ e2e) commands resolved in `SKILL.md`'s `Prepare` step once Phase 3 ends; all must pass (`SKILL.md` Global Rule 4).

## 8. What to record for the summary

Track:

- Mutation tool used, command run, and the formula used for the efficacy metric.
- Starting efficacy → final efficacy (with the threshold-reached/not-reached state called out explicitly).
- Starting LIVED count and final LIVED count.
- Pre-threshold iterations and post-threshold iterations (e.g. `pre 4 / post 3`).
- Tests added per file (count + paths).
- Remaining LIVED mutants with file:line, operator, and reason (equivalent / untestable / refactor-needed / per-mutant 3-attempt cap hit).
- **Suspected business-logic defects** surfaced when a distinguishing test failed on unmutated code — production file:line, the test path, observed vs expected behavior in one sentence, whether the test was left red or skipped. These feed the central defect list reported at the end of the skill.
- Whether Phase 3 was skipped, with the user's stated reason.
