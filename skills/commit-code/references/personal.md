## Description template

```markdown
## Summary
Brief description of what this PR accomplishes.

## Key Changes
- List of key changes made related to features (not test)

## Testing
- List of key changes made related to tests
```

## Execute

Push the current branch to origin if it is not already up to date with the remote (the PR path implies push).

Run `gh pr create` command with the following flags:

- (REQUIRED) `--assignee @me`: Self-assign.
- (REQUIRED) `--title {...}`: Add a title created in the previous step.
- (REQUIRED) `--body {...}`: Add a description created in the previous step.

Use `gh pr create --help` to find more information about flags.
