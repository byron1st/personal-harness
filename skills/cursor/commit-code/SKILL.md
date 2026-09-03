---
name: commit-code
description: "Commit current modified files (identity, conventional title, no Co-Authored-By, read-only docs-drift). Opens a PR/MR only when the prompt asks — including 'request-merge', 'PR 열어', 'open a PR'. Dirty tree plus a PR/MR request: commit first, then create/update. Commit-only does not ask about a PR and does not push unless asked. The PR/MR path implies push (`gh` personal / `glab` work)."
---

# Commit Code

Commit current modified files. Open a PR/MR only when the invocation asks for one. Do not ask whether to open a PR/MR after a commit-only run.

## Intent

Resolve once from the invocation. If the utterance both asks for a PR/MR and forbids one, ask; do not guess. Do not infer a PR/MR from the branch being ahead of `main`.

| Signal | Open PR/MR? |
| --- | --- |
| `request-merge`, PR 열어, open a PR, create a PR, MR 열어, open an MR, create an MR, open a pull request, 머지 요청, 커밋하고 PR, commit and open a PR | yes |
| omitted, Commit it, `/commit-code`, 커밋해, 커밋해줘 | no |

Push without a PR/MR is still allowed when the user clearly asked to push. That is not a PR/MR.

## Flow

1. Use the session-scoped repository context provided by the SessionStart hook.
   - If the context says `repo_type: work`, this is a work repository.
   - If the context says `repo_type: personal`, this is a personal repository.
   - Do not reclassify the repository from the origin URL inside this skill.
   - If the session context is missing, unclear, or contradictory, use `AskQuestion` to explicitly ask the user whether this is a work or personal repository before continuing.
2. If the working tree is dirty (staged or unstaged changes, excluding accidental test binaries): run **Commit**.
3. If the working tree is clean and intent is commit-only: report that there is nothing to commit, and stop. Do not ask about a PR/MR.
4. After a successful commit — or when skipping commit because the tree is already clean — if intent is PR/MR: read [references/pr-mr.md](references/pr-mr.md) and follow it. That path implies push. Do not read `references/pr-mr.md`, `references/personal.md`, or `references/work.md` on a commit-only run.
5. If intent is commit-only: after the docs-drift check, push only if the user clearly asked to push. Do not ask about a PR/MR.

## Commit

### Gather modified files and Jira ticket number

- You should check the email and name of a committer:
  - A committer for a work repository should be a user whose email and name are `$WORK_GIT_EMAIL` and `$WORK_GIT_NAME`.
  - A committer for a personal repository should be a user whose email and name are `$PERSONAL_GIT_EMAIL` and `$PERSONAL_GIT_NAME`.`.
- Also, if this is a work repository, try to extract the Jira ticket number from the branch name. The Jira ticket number follows the regex format `[A-Z]+-[0-9]+`.
  - If you cannot extract it, ask the user to provide the Jira ticket number.
- Check all modified files, contents including staged and unstaged changes.

### Make a title

A title always has the format: `{PREFIX}: {title}` where `{PREFIX}` is one of `feat`, `fix`, `refactor`, `test`, `ci`, or `chore`.

If a Jira ticket number is available, use the format: `{PREFIX}: [{Jira-ticket-number}] {title}`.

`{title}` should be a concise, one-line title, which ALWAYS starts with a lowercase letter and does NOT end with a period.

### Stage modified files

Basically, stage all modified files, including staged and unstaged changes. However, below files should be excluded:

- A binary file that is accidentally built for testing.

### Execute

Run `git commit` command to commit the changes.

Use `git commit --help` to find more information about flags.

DO NOT add "Co-Authored-By" in the commit message.

### Documentation drift check

After a successful commit, and before an optional push or PR/MR, perform a **read-only** documentation-drift check against the commit (for example, inspect `HEAD^..HEAD` with `git show` or `git diff`). Do not modify, stage, amend, or create any documentation files as part of this check.

- Compare the committed code, configuration, commands, interfaces, and behavior with relevant repository documentation, including `AGENTS.md`, legacy `CLAUDE.md` when present, `README.md`, and affected documents under `docs/`.
- If no update is needed, tell the user that the documentation-drift check found no required changes.
- If an update appears necessary, tell the user that no files were changed and list each likely document with a concise description of the stale or missing content—for example, setup or execution commands, configuration/environment variables, public API or CLI behavior, architecture/flow descriptions, or developer instructions.
- When the evidence is insufficient to determine whether a document is stale, label it as a manual-review candidate rather than claiming that it needs an update.

