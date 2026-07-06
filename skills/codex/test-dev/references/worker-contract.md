# Test-hardening Worker delegation contract

`test-dev` uses this contract only when the user explicitly asks for delegation. In that opt-in path, the main session acts as the Dispatcher and hands the actual test hardening to a single Codex `worker` agent (the **Worker**). This file is the **single source of truth** for that delegation: the prompt the dispatcher hands the Worker, the fixed-heading return the Worker must emit (②), and the chat summary the dispatcher owes the user (③).

`test-dev` references this contract instead of restating it. Do not duplicate these templates elsewhere; update them here. This contract does not change the Codex variant's default interactive behavior when delegation was not requested.

## A. Worker signal

The Worker detects it is a Worker (not the main session) from the dispatch prompt itself: the prompt contains the line `You are running as the test-hardening Worker subagent.` A session that sees this line runs the three-phase flow directly and **does not re-dispatch** another Worker - that would double-nest. A session that does not see this line stays in the main-session flow; it dispatches exactly one Worker only when the user explicitly requested delegation, subagent work, or parallel agent work.

## B. Dispatch prompt

The dispatcher (the main `test-dev` session) packages the brief below into a self-contained prompt and hands it to one Codex `worker` agent. Scope is defined by the diff — the implementation report, if passed, is only an intent hint:

```text
You are running as the test-hardening Worker subagent.

Use the `test-dev` skill to strengthen tests for the scope below. Work with fresh eyes: you did not write this code, so derive coverage gaps from the code itself, not from any narrative of what was intended.

Scope ({SCOPE_KIND} — e.g. "diff vs main", "uncommitted", "file", "whole codebase"):
{SCOPE_DIFF_OR_FILE_LIST}

Touched files (absolute paths):
{CHANGED_FILES}

Verification commands:
- lint: {LINT_CMD}
- unit: {UNIT_CMD}
- e2e: {E2E_CMD or none}
- mutation: {MUTATION_CMD or none}

Optional intent hint (do NOT treat as scope; scope is the diff above):
{IMPLEMENTATION_REPORT_PATH or none}

Run the three phases in order — unit gaps, then e2e gaps, then mutation LIVED elimination — per the skill. Add only test code; never edit production/business logic (Global Rule 6). Do not run review-code. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

You operate cold and cannot ask the user. If a required verification/mutation command is missing, or a direction-level decision is needed, stop that phase and return `blocked` with the choice laid out in `## Decision Needed`. Suspected business-logic defects are NOT blockers — record them per Global Rule 6 and continue.

When done, return only the fixed-heading Markdown in section C of `references/worker-contract.md` - do not summarise the `## Suspected Business Logic Defects` list, return it verbatim.
```

## C. Worker return message (②)

Fixed `##` headings, Markdown. The dispatcher parses these headings by name, so the Worker must emit them **exactly** and must not invent or rename headings. Anything empty becomes `none` (or its bullets, `none`); never drop a heading.

```markdown
## Test Status
pass | pass-with-suspected-defects | blocked | failed

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

## Suspected Business Logic Defects
{bullets with file:line, test path (Phase 1/2/3), observed vs expected, red/skipped status, or "none"}

## Remaining Attention Items
{bullets, or "none"}

## Decision Needed
{only when status is blocked: the obstacle + the choices the user must pick between. Otherwise "none"}
```

`pass` = gaps filled, all suites green, defect list empty. `pass-with-suspected-defects` = suites green but the `## Suspected Business Logic Defects` list is non-empty. `blocked` = a required verification/mutation command or tooling is missing, or a direction-level decision is needed (no further phase work past it). `failed` = a pre-existing test broke and reverting recent test changes did not restore it, or an irrecoverable hard error.

## D. Dispatcher chat summary (③)

After the dispatcher receives ②, it renders a short summary for the user in chat - **not** ② verbatim. Keep it to:

- Scope one-liner.
- Per-phase one-liners: unit (added/result), e2e (added/result or skipped), mutation (start→final efficacy, threshold reached?).
- The `## Suspected Business Logic Defects` list surfaced **prominently and verbatim** - this is the headline attention item, never summarised away.
- If `## Test Status` is `blocked`, surface `## Decision Needed` first and prominently, then stop - do not proceed to additional stages.

Translate to Korean if the Worker returned English; keep paths, command names, and code identifiers in their original form.

## E. Boundary

This contract covers only test-hardening delegation. `implement-dev` and `review-code` keep their own prompts and return schemas; they do not duplicate the test-hardening contract above.
