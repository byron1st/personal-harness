# Single-step plan file

A single-step plan is one markdown file describing the full implementation of a task. Use this format when `plan-dev` is operating in **single-step** mode (the default).

## What is enforced vs. flexible

**Enforced** (these are structural metadata, not content format):

- File name pattern (section 1)
- Storage location (section 2)
- Frontmatter fields (section 3)
- Body language: Korean

**Flexible**:

- Section structure inside the body. The template in section 4 is a *suggested* default — drop sections that do not apply, add ones that do, reorder freely.

## 1. File name

`{YYYYMMDD}_{Jira ticket number}_{Application}_{descriptor}.md`

- `{YYYYMMDD}` — today's date.
- `{Jira ticket number}` — extract from the current branch name using the regex `[A-Z]+-[0-9]+`. If it cannot be extracted, ask the user.
- `{Application}` — the working repository name without the URL. Example: origin `github.com/sample-user/sample-server` → `sample-server`.
- `{descriptor}` — short, concise, hyphen-separated description. No spaces. Example: `refactor-service-layer-to-resolve-cycle-dependencies`.

## 2. Storage location

ALWAYS store the file in `${OBSIDIAN_HOME}/00. Plans/`.

## 3. Required frontmatter

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
---
```

These three keys are required. Add other keys (e.g., `Tags`, `Status`) when useful.

## 4. Suggested body structure

Use this as a starting point. Adapt freely to the task — for a small bug fix you might collapse "Technical Approach" and "Affected Files" into one section; for a refactor with many tradeoffs you might add a "Migration" section. The point is to communicate the plan clearly, not to fill every heading.

If research files were created or consulted, link them somewhere near the top.

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

## Goal
Brief description of what this change accomplishes and why.

## Technical Approach
High-level overview, then detailed implementation notes including key code snippets where useful.

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
```

The `## TODOs` checkbox list pairs well with `implement-dev`, which ticks each box as it completes a task. If you keep that pattern, the items should be concrete enough that another agent can execute them without re-investigating the codebase.
