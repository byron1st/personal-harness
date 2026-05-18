---
name: fix-dev
description: Fix an error or bug discovered during a review phase — either right after a `single-step` plan implementation finishes, or between steps of a `multi-steps` plan — without polluting the main session's context. The main session organises the issue into a self-contained brief and dispatches a fresh sub-agent (`Agent` tool, subagent_type `general-purpose`) which performs root-cause analysis, applies the smallest correct fix on the current branch, runs the related lint/format/test/build commands, appends a `## Fix` section to the corresponding Implementation Report in Obsidian, and returns only a concise summary. Use this skill whenever the user surfaces a defect after `implement-dev` or `review-code` — phrases like "이거 고쳐줘", "리뷰에서 발견됐는데 수정해줘", "버그 좀 잡아줘", "fix this issue", or just pointing at a wrong output and asking for a quick correction. Does NOT commit unless the user explicitly asks for a commit in the same turn.
---

# Fix Dev

A surgical fix-it skill for issues caught during a review gate. The main session decides "this is small enough to delegate", organises the issue, dispatches a sub-agent to diagnose and patch it, and re-enters its own work with only the summary in context. The implementation noise — file reads, grep hits, diff iteration, test output — stays inside the sub-agent and is discarded when it returns.

## When this skill applies

Trigger this skill when **all** of the following hold:

- An `implement-dev` pass (single-step, or one step of a multi-steps plan) has just finished, or the user is otherwise in a review/verification moment (e.g. after `review-code`).
- The user has spotted a bug, regression, or defect they want corrected without invoking a new planning cycle.
- They have *not* asked for a redesign, new feature work, or a broad refactor.

If the request is for new behavior, a broad refactor, or anything that clearly needs its own plan, **do not** invoke this skill — recommend `plan-dev` instead.

## Scope of this skill

This skill stays inside the boundary of an existing plan. A fix fits here when:

- It does not require new design decisions; only "make the existing intent actually work".
- A reasonable engineer would not write a new plan/SPEC for it.

The sub-agent re-checks this boundary once it has read the code; see "Scope-guard handling" below.

## Main session responsibilities

### 1. Organise the issue before dispatching

The main session is the only place that has the surrounding context — which plan, which step, what was just reviewed, what the user reported. Distil this into a short brief so the sub-agent does not have to guess. The brief must include:

- **What is wrong** — one or two sentences describing the observed defect: error message, wrong output, broken UI, failing test, etc.
- **Where it appears** — concrete pointers: file paths (absolute), line numbers, function or component names, reproduction command, failing test name. Whatever the main session already knows.
- **Expected behavior** — what the user wanted to happen instead. Quote the user's words when useful.
- **Plan context** — absolute paths to the plan file (and the `-STEP-N.md` sub-plan, if multi-steps), plus which step the fix relates to. This lets the sub-agent see the original intent without the main session paraphrasing it.
- **Implementation Report path** — absolute path to the existing report in `${OBSIDIAN_HOME}/02. Implementation Reports/` that this fix amends. For single-step, the single report; for a multi-steps step, the `{base}-STEP-N.md` per-step report; for fixes raised after the final summary already exists, still amend the relevant `-STEP-N` report (the per-step report is closer to the change set than the summary). If no report exists yet (e.g. the fix is unrelated to a recent `implement-dev` run), pass `none` — the sub-agent will skip the report update.
- **Current branch** — the branch name the main session is on. The sub-agent must stay on this branch (do not create a new branch, do not switch).
- **Commit policy** — `commit-on-success` only if the user explicitly asked for a commit in this turn. Otherwise `no-commit`. When in doubt, choose `no-commit`.
- **Verification commands** — the lint/format/test/build commands extracted from `Makefile`, `AGENTS.md`, `CLAUDE.md`, or `README.md`. If they were already gathered in the current session (e.g. by an earlier `implement-dev` call), pass them through; otherwise extract them once before dispatching.
- **Project conventions** — a directive that the sub-agent must read `AGENTS.md` / `CLAUDE.md` before editing so it inherits project-specific rules.

If any required field is missing and cannot be reasonably inferred from the conversation so far, ask the user once via `AskUserQuestion` rather than guessing or proceeding with a half-formed brief.

### 2. Dispatch the sub-agent

Use the `Agent` tool with `subagent_type: general-purpose`. The sub-agent has no access to the main session's conversation, so the prompt must be **self-contained** — embed the brief from §1, the work contract (§4), and the return contract (§5) directly. Do not assume the sub-agent will read this `SKILL.md`; either inline the relevant sections in the prompt or pass the absolute path to this file and tell it to read the sub-agent contract sections first.

The main session never reads the touched files back into its own context after the sub-agent returns. That defeats the purpose of delegation.

### 3. Present the result

When the sub-agent returns, present the summary to the user roughly verbatim — root cause, files changed, verification outcomes, and any notes. Translate to Korean if the sub-agent returned in English; keep file paths, command names, and code identifiers in their original form. Do not embellish with details the sub-agent did not provide.

### 4. Scope-guard handling

If the sub-agent returns status `needs-confirmation` (it judged the fix out of scope after reading the code), **do not dispatch a follow-up automatically**. Show the user the sub-agent's explanation of why the fix exceeds the boundary, and ask via `AskUserQuestion` whether to:

- proceed anyway — re-dispatch with `force: true` added to the brief, OR
- stop here and route the work through `plan-dev` instead.

Wait for the user's explicit answer before either path.

## Sub-agent work contract

The sub-agent's prompt must specify the following sequence. Steps 3 and 4 are the only ones that branch on outcome; everything else runs unconditionally.

1. **Read inputs** — open the plan file(s) and the files pointed at by the brief. Read `AGENTS.md` / `CLAUDE.md` at the repo root (and any nested copies relevant to the changed files) for project conventions.

2. **Reproduce or locate** — use the reproduction command, failing test, or error message from the brief to confirm the defect actually exists in the current code. If the defect cannot be located from the information provided, return `blocked` with a precise statement of what is missing — do not start editing on speculation.

3. **Scope check** — once the root cause is understood, judge whether the fix stays inside the boundary (see "Scope of this skill"). If it does **not** fit and the brief does not contain `force: true`, return `needs-confirmation` with: a one-paragraph explanation of why the fix exceeds the boundary, and a rough sketch of what a proper fix would touch (files, contracts, tests). Do **not** edit code in this case.

4. **Fix** — apply the **smallest correct change** that resolves the root cause. Do not refactor neighbouring code, do not rename "while I'm here", do not touch unrelated files. If a test reveals the production code is wrong, fix the production code — never weaken a test to make it pass. Match the existing code style.

5. **Verify** — run **all** the lint/format/test/build commands from the brief. All must pass. If any command fails, follow the error-recovery rule: read the error carefully, fix the root cause first (not the test), and stop after **3 failed attempts on the same error** — return `failed` with what was tried and observed.

6. **Branch** — stay on the branch given in the brief. Do not create branches, switch branches, or merge.

7. **Commit (only if policy is `commit-on-success`)** — stage the changed files, excluding `PLAN.md` / `plan-*.md`, `RESEARCH.md` / `research-*.md`, and any accidentally built binaries. Use `git commit` with a message following the `commit-code` skill's conventions (i.e. `fix: {title}` for personal repos, or `fix: [{JIRA-123}] {title}` for work repos where a Jira ticket number can be extracted from the branch name). Do **not** add a `Co-Authored-By` trailer. Do **not** push. If commit policy is `no-commit`, leave the working tree as-is so the user can commit later.

8. **Append a `## Fix` entry to the Implementation Report** — open the report at the path given in the brief and append (do not overwrite anything) a Fix entry per "Fix section format" below. If the report does not yet contain a `## Fix` heading, create it at the very end of the file. If multiple Fix entries already exist, append the new one beneath them in chronological order. If the brief's `Implementation Report path` is `none`, skip this step entirely (do not create a new report file). Section titles in English, body content in Korean — this matches the existing Implementation Report convention.

## Fix section format

Append using exactly this shape. Heading and field labels in English; the prose values in Korean. Multiple fixes accumulate under one `## Fix` heading — each call adds a new `### Fix N — {YYYY-MM-DD HH:MM}` subsection. `N` is one greater than the highest existing Fix subsection in the file (start from `Fix 1`).

```markdown
## Fix

### Fix {N} — {YYYY-MM-DD HH:MM} — {짧은 제목}
- **Root cause**: 무엇이 왜 잘못되어 있었는지 한 문장으로.
- **Change**: 어떤 변경을 가했고 왜 그것이 가장 작은 올바른 수정인지 한 문장으로.
- **Files changed**:
  - `path/to/file1`
  - `path/to/file2`
- **Verification**: 실행한 명령과 결과 (예: `make lint` ✅, `make test` ✅, `make build` ✅).
- **Commit**: `{SHA}` 또는 `not committed (per policy)` / `not committed (no changes)`.
- **Notes**: 사용자가 알아야 할 후속/주변 사항. 없으면 줄 자체를 생략.
```

Timestamps use the local timezone of the project (the value `date "+%Y-%m-%d %H:%M"` would produce). Do **not** rewrite earlier Fix entries; each call only appends.

## Sub-agent return contract

Return a **single concise message** containing the fields below. The full diff lives on disk; do not paste it into the return. Do not include raw test output or grep dumps — summarise.

- **Status**: `success` | `needs-confirmation` | `blocked` | `failed`.
- **Root cause**: one paragraph describing what was actually wrong (not what was changed). Omit if status is `blocked` and the cause could not be located.
- **Fix summary**: one paragraph describing the change applied and why it is the smallest correct fix. Omit if status ≠ `success`.
- **Files changed**: bullet list of paths (no diffs). Omit if status ≠ `success`.
- **Verification**: which lint/format/test/build commands ran and their pass/fail outcome. Omit when no verification was performed (scope-guard or blocked returns).
- **Commit**: commit SHA if a commit was made, otherwise one of `not committed (per policy)`, `not committed (no changes)`. Omit if status ≠ `success`.
- **Report update**: absolute path of the Implementation Report that was amended and the heading of the new entry (e.g. `Fix 2 — 2026-05-18 14:30 — …`). Use `skipped (no report)` when the brief passed `Implementation Report path: none`. Omit if status ≠ `success`.
- **Notes**: anything else the user should see — adjacent bugs the sub-agent suspects but deliberately did not touch, follow-ups worth filing, unrelated cleanups intentionally skipped, etc. Omit if there is nothing.

The sub-agent must **not** dump file contents, full diffs, or full test output into the return.

## Anti-patterns

- **Do not re-read the changed files in the main session "just to be sure"** — that defeats the entire purpose of delegating to a sub-agent.
- **Do not commit silently** — only commit when the user explicitly asked in the message that triggered this skill. Silence means `no-commit`.
- **Do not expand scope inside the sub-agent** — if the needed fix grows beyond the boundary in "Scope of this skill", return `needs-confirmation` and let the main session ask the user.
- **Do not create a new branch** — the main session's branch is the right one. Branch creation belongs to `implement-dev`, not here.
- **Do not create a new report file** — this skill only **appends** a `## Fix` entry to the existing Implementation Report. If no report exists (`Implementation Report path: none`), skip the update; do not invent a new file.
- **Do not rewrite earlier `## Fix` entries** — each call appends a new dated subsection. History is part of the report.
- **Do not chain fixes** — one defect per invocation. If the user reports a new issue after this one is resolved, that is a fresh `fix-dev` call.
