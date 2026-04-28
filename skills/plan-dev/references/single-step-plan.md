# Single-step plan file

A single-step plan is one markdown file describing the full implementation of a task. Use this format when the `plan-dev` skill is operating in **single-step** mode (the default).

## 1. File name

`{YYYYMMDD}_{Jira ticket number}_{Application}_{descriptor}.md`

- `{YYYYMMDD}` — today's date.
- `{Jira ticket number}` — extract from the current branch name using the regex `[A-Z]+-[0-9]+`. If it cannot be extracted, ask the user.
- `{Application}` — the working repository name without the URL. Example: origin `github.com/sample-user/sample-server` → `sample-server`.
- `{descriptor}` — short, concise, hyphen-separated description. No spaces. Example: `refactor-service-layer-to-resolve-cycle-dependencies`.

## 2. Storage location

ALWAYS store the file in `${OBSIDIAN_HOME}/00. Plans/`.

## 3. Content

- Everything except the frontmatter and section titles is written in Korean.
- If research files were created or consulted, link them at the top.

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
---

# [Feature / Change Name]

Please refer to the research documents for detailed information about the related code and execution flow.
- {Link to RESEARCH file} (DO NOT wrap in backticks)
- {Link to RESEARCH file}
- ...

## Goal
Brief description of what this change accomplishes and why.

## Technical Approach
First, a high-level overview of how the change will be implemented.
Then, a detailed implementation plan including key code snippets where useful.

## Affected Files
- `path/to/file.go` — description of changes
- `path/to/new_file.go` — (new) description

## Risks and Assumptions
- Risk or assumption 1
- Risk or assumption 2

## Tradeoffs
- Tradeoff 1
- Tradeoff 2

## Verification
- [ ] Tests: specific test commands or new tests to write
- [ ] Lint: linting checks to pass
- [ ] Compile: check compilation errors

## TODOs
- [ ] Task 1
- [ ] Task 2
- [ ] Task 3
```
