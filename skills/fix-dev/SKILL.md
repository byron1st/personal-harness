---
name: fix-dev
description: Fix a bug found during review or verification after implementation. Use when the user asks to correct a defect without a new plan. Does not commit; leaves the working tree as-is.
---

# Fix Dev

Diagnose and patch **one** defect caught at a review or verification gate, then return a summary. Implementation noise — file reads, grep hits, diff iteration, test output — stays with the executor.

This skill is methodology. It does not start a persona. Standalone (`/fix-dev`): the current session assembles the brief and does the work in place. Under `dev-loop`: the loop assembles the brief and starts one `fixer` persona per finding, sequentially.

## Scope — the boundary that defines this skill

`fix-dev` corrects **established intent**. It does no new design work. Establish that intent from the first source that applies: an existing plan and its relevant step; a review finding plus the current diff; or the user's description of the existing behavior and its test contract.

A fix belongs here when it needs no new design decision — only "make the existing intent actually work" — and when a reasonable engineer would not write a plan for it. New public contracts, new features, and changes in product direction belong to `plan-dev`.

**The guard fires after reading the code, not before.** Once the root cause is understood, judge it against that boundary again. If it no longer fits, return `needs-confirmation` with a paragraph on why it exceeds the boundary and a rough sketch of what a proper `plan-dev` implementation would touch (files, contracts, tests) — and **edit nothing**. The caller shows the user and routes the work to `plan-dev`; it does not start a follow-up persona, and this skill does not continue the work itself.

## Rules

- **Protect the worktree.** Capture `git status --short` before touching anything. For every file you will edit that is already dirty, read its staged and unstaged diff first. Never reset, checkout, discard, or overwrite a pre-existing change. Before returning, compare against that snapshot and confirm only the expected fix, test, and report files moved.
- **Locate before editing.** Confirm the defect actually exists in the current code, using the reproduction command, failing test, or error message. If it cannot be located from what the brief gives you, return `blocked` naming precisely what is missing — do not edit on speculation.
- **Smallest correct change, at the root cause.** No refactoring neighbours, no renaming "while I'm here", no unrelated files. Match the existing style.
- **Cover the regression.** Prefer an existing failing test; otherwise add the smallest test that demonstrates the defect. For documentation, configuration, or genuinely trivial changes, record why a test was not appropriate. Never modify a test to hide the failure, and never weaken one to make it pass — if a test reveals the production code is wrong, fix the production code.
- **Verify proportionally**, then stop: the reproduction command or affected test, plus lint/test covering the changed area and any project-required fast gate. A full build or E2E only when the risk or project convention demands it. When something fails, first classify it as change-caused, a pre-existing baseline failure, or environmental — fix only the change-caused root cause, and never expand scope to repair the other two. Stop after **3 failed attempts on the same error** and return `failed`.
- **Stay on the branch** the brief names. No branching, no switching, no merging.
- **Never commit.** Leave the working tree as-is for the user.
- **One defect per invocation.** A new issue reported afterwards is a fresh `fix-dev` call, not a continuation.

`needs-confirmation` and `blocked` are never retried. This skill does not retry `failed` under a different model; the loop may start the same persona once more, and that retry is the loop's.

## Caller brief

The user supplies only the defect, the expected behavior, and any pointer they happen to have. **Workflow metadata is never a user prerequisite** — gather it yourself with lightweight read-only lookups and pass `none` where it is unavailable. Ask the user only when the defect itself or its expected behavior cannot reasonably be inferred.

The persona has no access to the caller's conversation, so the brief must be self-contained:

- **What is wrong** — the observed defect in a sentence or two: error message, wrong output, broken UI, failing test.
- **Expected behavior** — what should have happened; quote the user where useful.
- **Location or reproduction** — file path, line, function, failing test, reproduction command, or review finding. `none` if unavailable.
- **Finding ID** — `REVIEW-NNN` / `TEST-NNN` when this fix answers one, else `none`.
- **Loop context** — remediation round number and the LOOP file's absolute path when started from `dev-loop`, else `none`.
- **Workspace context** — current branch and any pre-existing changes in the target files, from `git status --short`.
- **Plan context** — absolute path to the plan (and `-STEP-N` sub-plan), else `none`.
- **Implementation Report path** — the report under `docs/agents/dev/` this fix amends. For a multi-steps step, the per-step `-STEP-N` report, which sits closer to the change set than any summary. `none` if there is none, and the executor then skips the report update rather than creating a file.
- **Verification candidates** — known reproduction/targeted commands, else from `$HOME/.agents/scripts/detect-commands.sh` plus anything only named in `AGENTS.md` / `CLAUDE.md` / `README.md` prose. `none` if unavailable.
- **Project conventions** — a directive to read `AGENTS.md` / `CLAUDE.md` before editing.

After a loop executor returns, the caller does **not** re-read the changed files "just to be sure" — that defeats isolating the fix in a persona. Present the executor's summary roughly verbatim: root cause, files changed, verification outcomes, notes. Translate to Korean if it returned English, keeping paths, commands, and identifiers as-is. Do not embellish with details it did not provide.

## Report entry

Append to the Implementation Report at the brief's path — **append only**, never overwrite, never create a new report file, never rewrite an earlier entry. Create the `## Fix` heading at the end of the file if absent; multiple fixes accumulate beneath it in chronological order. `N` is one greater than the highest existing Fix subsection. Section titles and field labels in English, prose values in Korean, matching the report convention. Timestamps are local time — what `date "+%Y-%m-%d %H:%M"` would produce.

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

## Return contract

A **single concise message** leading with the common stage block. The diff lives on disk — do not paste it, raw test output, or grep dumps into the return. Standalone uses the same shape as its final response.

```markdown
## Stage Status
pass | needs-confirmation | blocked | failed
```

- **Root cause** — one paragraph on what was actually wrong, not what changed. Omit when `blocked` and the cause could not be located.
- **Finding** — the `REVIEW-NNN` / `TEST-NNN` this resolves. Omit when the brief passed `none`.
- **Fix summary** — the change applied and why it is the smallest correct one. *(pass only)*
- **Regression test** — the test used or added and its outcome, or why one was not appropriate. *(pass only)*
- **Files changed** — paths, no diffs. *(pass only)*
- **Verification** — commands and outcomes, broad checks skipped and why, and whether any failure was change-caused, pre-existing, or environmental. Omit when no verification ran.
- **Worktree check** — that pre-existing changes survived and only expected files moved. *(pass only)*
- **Report update** — absolute path of the amended report and the new entry's heading, or `skipped (no report)`. *(pass only)*
- **Notes** — adjacent bugs deliberately left alone, follow-ups worth filing, cleanups intentionally skipped. Omit when there is nothing.
