## Description template

- Content except the section titles should be written in Korean.

```markdown
## Summary
Brief description of what this MR accomplishes.

## Related Issue
- Jira: [TICKET-ID](jira-url)

## Key Changes
- List of key changes made related to features (not test)

## Testing
- List of key changes made related to tests
```

## Execute

First, try to create an MR. If failed because the MR already exists, update the MR.

### Create an MR

Run `glab mr create` command with the following flags:

- (REQUIRED) `--assignee "$WORK_GITLAB_USERNAME"`
- (REQUIRED) `--reviewer "$WORK_GITLAB_DEFAULT_REVIEWERS"`
    - If additional reviewers are mentioned, add them after default reviewers separated by commas.
- (REQUIRED) `--push`
- (REQUIRED) `--remove-source-branch`
- (REQUIRED) `--title {...}`: Add a title created in the previous step.
- (REQUIRED) `--description {...}`: Add a description created in the previous step.
- (REQUIRED) `--yes`
- (OPTIONAL) `--squash-before-merge`: If the additional prompt requires squashing commits, add this flag.

Use `glab mr create --help` to find more information about flags.

### Update an MR

Run `glab mr update` command with the following flags:

- (REQUIRED) `--title {...}`: Add a title created in the previous step.
- (REQUIRED) `--description {...}`: Add a description created in the previous step.
- (REQUIRED) `--yes`

If the additional prompt requires changing the MR's reviewers or other options like squash-before-merge, add them to the command.

For modifying reviewers, add prefix with '!' or '-' to remove from existing reviewers, '+' to add. Otherwise, replace existing reviewers with given users. Multiple usernames can be comma-separated or specified by repeating the flag.

Use `glab mr update --help` to find more information about flags.
