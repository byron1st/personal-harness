---
name: commit-code
description: Make a commit based on current modified files
---

# Commit Code

This skill explains how to make a commit based on current modified files.

## Prepare

### 1. Gather modified files and Jira ticket number

- Use the session-scoped repository context provided by the SessionStart hook.
  - If the context says `repo_type: work`, this is a work repository.
  - If the context says `repo_type: personal`, this is a personal repository.
  - Do not reclassify the repository from the origin URL inside this skill.
  - If the session context is missing, unclear, or contradictory, explicitly ask the user whether this is a work or personal repository before continuing.
- You should check the email and name of a committer:
  - A committer for a work repository should be a user whose email and name are `$WORK_GIT_EMAIL` and `$WORK_GIT_NAME`.
  - A committer for a personal repository should be a user whose email and name are `$PERSONAL_GIT_EMAIL` and `$PERSONAL_GIT_NAME`.`.
- Also, if this is a work repository, try to extract the Jira ticket number from the branch name. The Jira ticket number follows the regex format `[A-Z]+-[0-9]+`.
  - If you cannot extract it, ask the user to provide the Jira ticket number.
- Check all modified files, contents including staged and unstaged changes.

### 2. Make a title

A title always has the format: `{PREFIX}: {title}` where `{PREFIX}` is one of `feat`, `fix`, `refactor`, `test`, `ci`, or `chore`.

If a Jira ticket number is available, use the format: `{PREFIX}: [{Jira-ticket-number}] {title}`.

`{title}` should be a concise, one-line title, which ALWAYS starts with a lowercase letter and does NOT end with a period.

## Stage modified files

Basically, stage all modified files, including staged and unstaged changes. However, below files should be excluded:

- A binary file that is accidentally built for testing.

## Execute

Run `git commit` command to commit the changes.

Use `git commit --help` to find more information about flags.

DO NOT add "Co-Authored-By" in the commit message.

## Afterward

### Documentation drift check

After a successful commit, and before an optional push, perform a **read-only** documentation-drift check against the commit (for example, inspect `HEAD^..HEAD` with `git show` or `git diff`). Do not modify, stage, amend, or create any documentation files as part of this check.

- Compare the committed code, configuration, commands, interfaces, and behavior with relevant repository documentation, including `AGENTS.md`, legacy `CLAUDE.md` when present, `README.md`, and affected documents under `docs/`.
- If no update is needed, tell the user that the documentation-drift check found no required changes.
- If an update appears necessary, tell the user that no files were changed and list each likely document with a concise description of the stale or missing content—for example, setup or execution commands, configuration/environment variables, public API or CLI behavior, architecture/flow descriptions, or developer instructions.
- When the evidence is insufficient to determine whether a document is stale, label it as a manual-review candidate rather than claiming that it needs an update.

If user clearly mentioned to push after the commit, push it to the origin. If not, DO NOT push it to any remote.
