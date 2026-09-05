# Executor contract

Caller brief, return schema, and chat-summary shape for `test-dev`. The filename is historical. This file does not start a persona and does not name a host spawn tool.

`test-dev` references this contract instead of restating it. Do not duplicate these templates elsewhere; update them here.

## A. Who runs this

- **Standalone** — the current session runs the methodology in place and does not start a persona.
- **Loop** — `dev-loop` starts the `tester` persona as a blocking child. That persona follows `test-dev` and returns the headings in §C. It does not start another persona.

## B. Caller brief

The loop (or standalone Prepare) fills this, replacing placeholders. Scope is defined by the diff — the implementation report, if passed, is only an intent hint:

```text
Use the `test-dev` skill to strengthen tests for the scope below. Work with fresh eyes: you did not write this code, so derive coverage gaps from the code itself, not from any narrative of what was intended.

Scope ({SCOPE_KIND} — e.g. "diff vs main", "uncommitted", "file", "whole codebase"):
{SCOPE_DIFF_OR_FILE_LIST}

Touched files (absolute paths):
{CHANGED_FILES}

Verification commands:
- lint: {LINT_CMD}
- unit: {UNIT_CMD}
- e2e: {E2E_CMD or none}
- mutation: {MUTATION_CMD, "none", or "out of scope" when the caller excluded mutation from this run}

Optional intent hint (do NOT treat as scope; scope is the diff above):
{IMPLEMENTATION_REPORT_PATH or none}

Run the three phases in order — unit gaps, then e2e gaps, then mutation LIVED elimination — per the skill. Add only test code; never edit production/business logic (Global Rule 6). Do not run review-code. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

If the mutation line above reads `out of scope`, skip Phase 3 entirely and write `out of scope (caller)` under `## Mutation` — a missing mutation command is NOT a blocker in that case.

You operate cold and cannot ask the user. If a required verification command is missing, if mutation tooling is missing and mutation was NOT placed out of scope, or if a direction-level decision is needed, stop that phase and return `blocked` with the choice laid out in `## Decision Needed`. Suspected business-logic defects are NOT blockers — record them per Global Rule 6 and continue.

When done, return only the fixed-heading Markdown in section C of `references/worker-contract.md` - do not summarise the `## Findings` list (suspected business-logic defects with `TEST-NNN` ids), return it verbatim.
```

When a value is already in the brief, the executor uses it. When a required value is missing, the executor may run `$HOME/.agents/scripts/detect-commands.sh` or `$HOME/.agents/scripts/resolve-scope.sh` itself.

## C. Executor return message (②)

Fixed `##` headings, Markdown. The caller parses these headings by name, so the executor must emit them **exactly** and must not invent or rename headings. Anything empty becomes `none` (or its bullets, `none`); never drop a heading.

```markdown
## Stage Status
pass | pass-with-suspected-defects | blocked | failed

## Findings
{suspected business-logic defects, one bullet per finding with an executor-assigned sequential `TEST-NNN` id (TEST-001, TEST-002, …): file:line, test path (Phase 1/2/3), observed vs expected, red/skipped status. "none" when empty}

## Decision Needed
{only when status is blocked: the obstacle + the choices the user must pick between. Otherwise "none"}

## Scope
{files or packages tested}

## Test Changes
{one absolute path per line, or "none"}

## Unit
{tests added and final result}

## E2E
{tests added and final result, or skipped reason}

## Mutation
{starting efficacy -> final efficacy, LIVED before -> after, whether 80% reached, or skipped reason}

## Remaining Attention Items
{bullets, or "none"}
```

The first three headings are the **common stage block** shared across executor-returning skills (`## Stage Status` / `## Findings` / `## Decision Needed`; other skills add `## Evidence`); the headings below it are test-dev's own. The executor assigns the `TEST-NNN` ids itself - it is the single writer, so there is no collision risk.

`pass` = gaps filled, all suites green, `## Findings` empty. `pass-with-suspected-defects` = suites green but `## Findings` is non-empty. `blocked` = a required verification command or tooling is missing, or a direction-level decision is needed (no further phase work past it) — **mutation tooling missing while mutation is `out of scope` is not a blocker**. `failed` = a pre-existing test broke and reverting recent test changes did not restore it, or an irrecoverable hard error.

## D. Caller chat summary (③)

After ② arrives, the caller renders a short summary for the user in chat - **not** ② verbatim. Keep it to:

- Scope one-liner.
- Per-phase one-liners: unit (added/result), e2e (added/result or skipped), mutation (start→final efficacy, threshold reached?).
- The `## Findings` list (suspected business-logic defects, `TEST-NNN`) surfaced **prominently and verbatim** - this is the headline attention item, never summarised away.
- If `## Stage Status` is `pass-with-suspected-defects`, do **not** auto-proceed to review-code or any next stage: notify the user and present each finding as a `fix-dev` candidate - fixing or proceeding anyway is the user's call.
- If `## Stage Status` is `blocked`, surface `## Decision Needed` first and prominently, then stop - do not proceed to additional stages.

Translate to Korean if the executor returned English; keep paths, command names, and code identifiers in their original form.

## E. Boundary

This contract covers only test-hardening. `implement-dev` and `review-code` keep their own briefs and return schemas. Spawn failure and same-persona `failed` retry belong to `dev-loop` (or the standalone user), not to this skill.
