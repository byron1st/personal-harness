---
name: commit-code
description: Make a commit based on current modified files
---

# Commit Code

This skill explains how to make a commit based on current modified files.

## Prepare

### 1. Gather modified files and Jira ticket number

- If the url of the repository's origin starts with `$WORK_GITLAB_HOST*`, this is a work repository.
- If not, this is a personal repository.
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

- `PLAN.md` or `plan-...` related files: Markdown files to describe the plan for an AI agent to perform a task.
- `RESEARCH.md` or `research-...` related files: Markdown files to describe the research result for the plan.
- A binary file that is accidentally built for testing.

## Execute

Run `git commit` command to commit the changes.

Use `git commit --help` to find more information about flags.

DO NOT add "Co-Authored-By" in the commit message.

## Afterward

If user clearly mentioned to push after the commit, push it to the origin. If not, DO NOT push it to any remote.
