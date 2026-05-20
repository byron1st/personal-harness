---
name: request-merge
description: Create or update a Merge/Pull Request using the `glab` or `gh` CLI command depending on the repository.
---

# Create or Update Merge/Pull Request

This skill explains how to create or update a Merge Request (GitLab) or Pull Request (GitHub) depending on the repository.

## Determine repository type and gather information

- Check the url of a repository's origin. If the url starts with `$WORK_GITLAB_HOST*`, this is a work repository. If not, this is a personal repsitory.
- Gather all commits from the current branch to the target branch. If the target branch is not mentioned, the `main` branch is the` target branch.

## Make a title

A title always has the format: `{PREFIX}: {title}` where `{PREFIX}` is one of `feat`, `fix`, `refactor`, `test`, `ci`, or `chore`.

If this is a work repository, try to extract a Jira ticket number (`[A-Z]+-[0-9]+`) from the branch name. If you cannot extract any Jira ticket number from the branch name, ask the user to provide it. Then, use the format: `{PREFIX}: [{Jira-ticket-number}] {title}`.

`{title}` should be a concise, one-line title that explains ALL the commits submitted in this branch well. DO NOT just pick one of commit messages for `{title}`. Also, it should start with a lowercase.

## Make a description and Execute

- See [the work guide](references/work.md) for a **work repository**
- See [the personal guide](references/personal.md) for a **personal repository**

## Afterward

If user has requested, run a code review process to ensure the MR/PR is ready for merge.
