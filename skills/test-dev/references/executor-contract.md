# Executor contract

The caller brief and return schema for `test-dev`. Update them here; do not duplicate them elsewhere.

## A. Caller brief

The loop (or standalone Prepare) fills this. Scope is defined by the diff — an implementation report, if passed, is only an intent hint.

```text
Use the `test-dev` skill to strengthen tests for the scope below. Work with fresh eyes: you did not write this code, so derive coverage gaps from the code itself, not from any narrative of what was intended.

Scope ({SCOPE_KIND} — "diff vs main", "uncommitted", "file", "whole codebase"):
{SCOPE_DIFF_OR_FILE_LIST}

Touched files (absolute paths):
{CHANGED_FILES}

Verification commands:
- lint: {LINT_CMD}
- unit: {UNIT_CMD}
- e2e: {E2E_CMD or none}
- mutation: {MUTATION_CMD, "none", or "out of scope" when the caller excluded mutation from this run}

Optional intent hint (NOT the scope):
{IMPLEMENTATION_REPORT_PATH or none}

Do not start another persona. Do not run review-code. Do not revert edits made by others.

Return only the fixed-heading Markdown in section B of `references/executor-contract.md`, with `## Findings` verbatim.
```

When a value is missing from the brief, the executor may run `$HOME/.agents/scripts/detect-commands.sh` or `$HOME/.agents/scripts/resolve-scope.sh` itself.

## B. Executor return message (②)

Fixed `##` headings, Markdown. The caller parses these headings by name, so emit them **exactly** — never invent or rename one, and never drop one. Anything empty becomes `none`.

```markdown
## Stage Status
pass | pass-with-suspected-defects | blocked | failed

## Findings
{suspected business-logic defects, one bullet per finding with a sequential `TEST-NNN` id: file:line, test path (Phase 1/2/3), observed vs expected, red/skipped status. "none" when empty}

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

`## Stage Status` / `## Findings` / `## Decision Needed` are the **common stage block** shared across executor-returning skills. The executor assigns `TEST-NNN` ids itself — it is the single writer, so there is no collision risk.

| Status | Means |
| --- | --- |
| `pass` | Gaps filled, all suites green, `## Findings` empty |
| `pass-with-suspected-defects` | Suites green but `## Findings` is non-empty |
| `blocked` | A required verification command or tooling is missing, or a direction-level decision is needed. **Missing mutation tooling while mutation is `out of scope` is not a blocker** |
| `failed` | A pre-existing test broke and reverting recent test changes did not restore it, or an irrecoverable hard error |

## C. Caller chat summary (③)

Scope one-liner, then per-phase one-liners: unit (added/result), e2e (added/result or skipped), mutation (start→final efficacy, threshold reached?).

Then `## Findings` **prominently and verbatim** — this is the headline, never summarised away. On `pass-with-suspected-defects`, do **not** auto-proceed: present each finding as a `fix-dev` candidate and let the user decide. On `blocked`, surface `## Decision Needed` first and stop.

Translate to Korean if the executor returned English; keep paths, command names, and code identifiers as-is.

## D. Boundary

This contract covers test-hardening only. `implement-dev` and `review-code` keep their own. Spawn failure and the same-persona `failed` retry belong to `dev-loop` or the standalone user, not to this skill.
