---
name: fix-dev
description: Fix an error or bug discovered during a review phase without polluting the main session's context. The main session dispatches a fresh subagent via OpenCode's Task tool and requires an explicit decision before direct fallback. Use when the user asks to correct a defect without a new plan. Does NOT commit; leaves the working tree as-is so the user can commit later.
---

# Fix Dev

A surgical fix-it skill for issues caught during a review gate. The main session organises the issue, dispatches a subagent to diagnose and patch it, and re-enters its own work with only the summary in context. The implementation noise — file reads, grep hits, diff iteration, test output — stays inside the subagent and is discarded when it returns. If dispatch is unavailable or fails, report the failure and ask whether to continue directly; never silently perform the fix in the main session.

## When this skill applies

Trigger this skill when **all** of the following hold:

- An `implement-dev` pass (single-step, or one step of a multi-steps plan) has just finished, or the user is otherwise in a review/verification moment (e.g. after `review-code`).
- The user has spotted a bug, regression, or defect they want corrected without invoking a new planning cycle.
- They have *not* asked for a redesign, new feature work, or a broad refactor.

If the request is for new behavior, a broad refactor, or anything that clearly needs its own plan, **do not** invoke this skill — recommend `plan-dev` instead.

## Scope of this skill

This skill corrects established intent without new design work. Establish that intent from the first applicable source below:

- An existing plan, using its original intent and the relevant step.
- A review finding and the current diff when no plan exists.
- The user's description of existing behavior and its test contract when neither exists.

A fix fits here when:

- It does not require new design decisions; only "make the existing intent actually work".
- A reasonable engineer would not write a new plan/SPEC for it.

New public contracts, new features, or a change in product direction require `plan-dev`.

The executor re-checks this boundary once it has read the code; see "Scope-guard handling" below.

## Main session responsibilities

### 1. Organise the issue before dispatching

The user-facing input is only the defect, expected behavior, and any known pointer or review finding. Do not make workflow metadata a prerequisite. Before dispatch, reuse the current context and make only lightweight read-only lookups needed to give the executor a short brief. The brief must contain:

- **What is wrong** — one or two sentences describing the observed defect: error message, wrong output, broken UI, failing test, etc.
- **Expected behavior** — what the user wanted to happen instead. Quote the user's words when useful.
- **Known location or reproduction** — file path, line, function, failing test, reproduction command, or review finding; use `none` if unavailable.
- **Finding ID** — optional: the review/test finding this fix addresses (`REVIEW-NNN` / `TEST-NNN`); use `none` when not applicable.
- **Loop context** — optional: when dispatched from a `dev-loop` run, the remediation round number and the LOOP file's absolute path; use `none` otherwise.
- **Workspace context** — capture `git status --short` before dispatch, then include the current branch and any pre-existing changes in known target files; gather this automatically.
- **Plan context** — absolute paths to the plan file (and the `-STEP-N.md` sub-plan, if multi-steps), plus the related step; use `none` if no plan exists or it is not known.
- **Implementation Report path** — absolute path to the existing report under `docs/agents/dev/` that this fix amends. For single-step, the single report; for a multi-steps step, the `{timestamp}_{Jira}_IMPL_{title}-STEP-N.md` per-step report; for fixes raised after the final summary already exists, still amend the relevant `-STEP-N` report (the per-step report is closer to the change set than the summary). Use `none` if no report exists or it cannot be identified; the executor will skip the report update.
- **Verification candidates** — known reproduction/targeted lint/test commands and project-required fast gates from `Makefile`, `AGENTS.md` (and legacy `CLAUDE.md` when present), or `README.md`; use `none` if unavailable. The executor chooses a proportional set under step 6 of the Fix work contract.
- **Project conventions** — a directive that the executor must read `AGENTS.md` and legacy `CLAUDE.md` when present before editing so it inherits project-specific rules.

Do not interrupt to ask for missing branch, plan, report, or verification metadata; pass `none` where it is unavailable. Use the question tool only when the reported defect itself or its expected behavior cannot be reasonably inferred.

### 2. Dispatch one subagent by default

Use OpenCode's Task tool with `subagent_type: general`. The subagent has no access to the main session's conversation, so the prompt must be **self-contained** — embed the brief from §1, the work contract (§4), and the return contract (§5) directly. Do not assume the subagent will read this `SKILL.md`; either inline the relevant sections in the prompt or pass the absolute path to this file and tell it to read the subagent contract sections first.

If OpenCode's Task tool or compatible subagent capability is unavailable, or dispatch fails, stop before editing. Report `Delegation status: unavailable` or `failed`, include the observed cause, and use the question tool to ask whether to continue with a direct main-session fix or stop. Direct execution is allowed only after the user explicitly chooses that fallback.

The main session never reads the touched files back into its own context after the subagent returns. That defeats the purpose of delegation.

### 3. Present the result

When the subagent returns, present the summary to the user roughly verbatim — root cause, files changed, verification outcomes, and any notes. Translate to Korean if the subagent returned in English; keep file paths, command names, and code identifiers in their original form. Do not embellish with details the subagent did not provide. When the main session performed an explicitly authorized fallback, present the same fields directly.

### 4. Scope-guard handling

If the executor returns status `needs-confirmation` (it judged the fix out of scope after reading the code), **do not dispatch a follow-up or use direct fallback**. Show the user the explanation and rough implementation sketch, then route the work through `plan-dev`. Do not continue it within `fix-dev`; wait for the user to start or approve the planning step.

## Fix work contract

The subagent's prompt must specify the following sequence. If the user explicitly authorizes direct fallback after a delegation failure, the main session follows the same sequence directly. Follow every applicable step unless a stated `blocked` or `needs-confirmation` exit applies.

1. **Read inputs and protect the worktree** — capture `git status --short` before touching files. For every file you will edit that is already changed in that snapshot, inspect its staged and unstaged diff first. Never reset, checkout, discard, or overwrite a pre-existing change. Open the plan file(s) only when the brief provides them, then open the files pointed at by the brief. Read `AGENTS.md` and legacy `CLAUDE.md` when present at the repo root (and any nested copies relevant to the changed files) for project conventions.

2. **Reproduce or locate** — use the reproduction command, failing test, or error message from the brief to confirm the defect actually exists in the current code. If the defect cannot be located from the information provided, return `blocked` with a precise statement of what is missing — do not start editing on speculation.

3. **Scope check** — once the root cause is understood, judge it against the applicable source in "Scope of this skill". If it does **not** fit, return `needs-confirmation` with: a one-paragraph explanation of why the fix exceeds the boundary, and a rough sketch of what a proper `plan-dev` implementation would touch (files, contracts, tests). Do **not** edit code in this case.

4. **Add regression coverage** — use an existing failing test first. When the defect is testable and no existing test captures it, add the smallest regression test that demonstrates the defect before changing production code. For documentation, configuration, or genuinely trivial changes where a test is not appropriate, record why it was omitted. Never modify a test solely to hide the failure.

5. **Fix** — apply the **smallest correct change** that resolves the root cause. Do not refactor neighbouring code, do not rename "while I'm here", do not touch unrelated files. If a test reveals the production code is wrong, fix the production code — never weaken a test to make it pass. Match the existing code style.

6. **Verify proportionally** — select verification in this order: (a) the reproduction command or affected test, (b) lint/test that directly covers the changed area, (c) project-required fast gates, then (d) a full build or E2E only when the change risk or project convention requires it. Run a formatter only as a non-mutating check or when project rules require it. Every selected command must pass. If one fails, first classify it as change-caused, a pre-existing baseline failure, or an environment failure. Fix only a change-caused root cause (never weaken a test); stop after **3 failed attempts on the same error** and return `failed` with what was tried and observed. Do not expand scope to repair a baseline or environment failure.

7. **Branch** — stay on the branch given in the brief. Do not create branches, switch branches, or merge.

8. **Append a `## Fix` entry to the Implementation Report** — open the report at the path given in the brief and append (do not overwrite anything) a Fix entry per "Fix section format" below. If the report does not yet contain a `## Fix` heading, create it at the very end of the file. If multiple Fix entries already exist, append the new one beneath them in chronological order. If the brief's `Implementation Report path` is `none`, skip this step entirely (do not create a new report file). Section titles in English, body content in Korean — this matches the existing Implementation Report convention.

9. **Check the worktree delta** — compare the final worktree state with the initial snapshot. Confirm that every pre-existing change remains intact and only expected fix, test, and report files changed. If your work changed an unexpected file and cannot safely restore it without risking a pre-existing change, return `failed` with the precise file and reason.

## Fix section format

Append using exactly this shape. Heading and field labels in English; the prose values in Korean. Multiple fixes accumulate under one `## Fix` heading — each call adds a new `### Fix N — {YYYY-MM-DD HH:MM}` subsection. `N` is one greater than the highest existing Fix subsection in the file (start from `Fix 1`).

```markdown
## Fix

### Fix {N} — {YYYY-MM-DD HH:MM} — {짧은 제목}
- **Finding**: {이 수정이 해결한 finding ID (`REVIEW-NNN` / `TEST-NNN`). brief의 Finding ID가 `none`이면 줄 자체를 생략.}
- **Root cause**: 무엇이 왜 잘못되어 있었는지 한 문장으로.
- **Change**: 어떤 변경을 가했고 왜 그것이 가장 작은 올바른 수정인지 한 문장으로.
- **Regression test**: 추가하거나 사용한 회귀 테스트와 결과, 또는 테스트를 생략한 사유.
- **Files changed**:
  - `path/to/file1:line`
  - `path/to/file2:line`
- **Verification**: 실행한 명령과 결과, 생략한 광범위 검증과 이유 (예: `make lint` ✅, `make test` ✅, `make build`는 변경 범위상 생략).
- **Notes**: 사용자가 알아야 할 후속/주변 사항. 없으면 줄 자체를 생략.
```

Timestamps use the local timezone of the project (the value `date "+%Y-%m-%d %H:%M"` would produce). Do **not** rewrite earlier Fix entries; each call only appends.

## Return contract

Return a **single concise message** that leads with the common stage block, then the fields below. The full diff lives on disk; do not paste it into the return. Do not include raw test output or grep dumps — summarise. When running in the main session, use the same shape in the final response.

```markdown
## Stage Status
pass | needs-confirmation | blocked | failed
```

- **Root cause**: one paragraph describing what was actually wrong (not what was changed). Omit if status is `blocked` and the cause could not be located.
- **Finding**: the finding ID this fix resolves (`REVIEW-NNN` / `TEST-NNN`). Omit when the brief's Finding ID was `none`.
- **Fix summary**: one paragraph describing the change applied and why it is the smallest correct fix. Omit if status ≠ `pass`.
- **Regression test**: the existing or newly added regression test and outcome, or the reason it was not appropriate. Omit if status ≠ `pass`.
- **Files changed**: bullet list of paths (no diffs). Omit if status ≠ `pass`.
- **Verification**: selected commands and their pass/fail outcome, any skipped broad checks and why, and whether a failure was change-caused, pre-existing, or environmental. Omit when no verification was performed (scope-guard or blocked returns).
- **Worktree check**: whether pre-existing changes were preserved and only expected files changed. Omit if status ≠ `pass`.
- **Report update**: absolute path of the Implementation Report that was amended and the heading of the new entry (e.g. `Fix 2 — 2026-05-18 14:30 — …`). Use `skipped (no report)` when the brief passed `Implementation Report path: none`. Omit if status ≠ `pass`.
- **Notes**: anything else the user should see — adjacent bugs the subagent suspects but deliberately did not touch, follow-ups worth filing, unrelated cleanups intentionally skipped, etc. Omit if there is nothing.

The subagent must **not** dump file contents, full diffs, or full test output into the return.

## Anti-patterns

- **Do not re-read the changed files in the main session "just to be sure"** — that defeats the entire purpose of delegating to a subagent.
- **Do not make workflow metadata a user prerequisite** — gather available branch, worktree, plan, report, and verification context yourself, and use `none` when it is absent.
- **Do not discard or overwrite pre-existing worktree changes** — inspect a changed target file before editing and preserve every existing change.
- **Do not weaken a test to hide the defect** — use existing coverage or add the smallest appropriate regression test, and record why one is not appropriate.
- **Do not commit** — this skill never commits. Leave the working tree as-is so the user can commit later.
- **Do not bypass the scope guard** — if the needed fix grows beyond the boundary in "Scope of this skill", return `needs-confirmation` and route it through `plan-dev`.
- **Do not create a new branch** — the main session's branch is the right one. Branch creation belongs to `implement-dev`, not here.
- **Do not create a new report file** — this skill only **appends** a `## Fix` entry to the existing Implementation Report. If no report exists (`Implementation Report path: none`), skip the update; do not invent a new file.
- **Do not rewrite earlier `## Fix` entries** — each call appends a new dated subsection. History is part of the report.
- **Do not chain fixes** — one defect per invocation. If the user reports a new issue after this one is resolved, that is a fresh `fix-dev` call.
