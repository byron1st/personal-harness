# Open a PR/MR

Load this file only when commit-code intent is yes. If a commit was made in this run, include it when gathering commits.

Opening a PR/MR implies push. Work `glab mr create` already uses `--push`. For personal: push the current branch to origin if it is not already up to date, then run `gh pr create`.

## Gather commits

Gather all commits from the current branch to the target branch. If the target branch is not mentioned, `main` is the target branch.

## Make a title

A title always has the format: `{PREFIX}: {title}` where `{PREFIX}` is one of `feat`, `fix`, `refactor`, `test`, `ci`, or `chore`.

If this is a work repository, try to extract a Jira ticket number (`[A-Z]+-[0-9]+`) from the branch name. If you cannot extract any Jira ticket number from the branch name, ask the user to provide it. Then, use the format: `{PREFIX}: [{Jira-ticket-number}] {title}`.

`{title}` should be a concise, one-line title that explains ALL the commits submitted in this branch well. DO NOT just pick one of commit messages for `{title}`. Also, it should start with a lowercase.

Do not reuse this run's commit title as the PR/MR title when the branch contains other commits.

## Description and execute

- See [the work guide](work.md) for a **work repository**
- See [the personal guide](personal.md) for a **personal repository**

Load only the matching guide. Do not load both.

## Afterward

If user has requested, run a code review process to ensure the MR/PR is ready for merge.
