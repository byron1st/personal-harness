# Single-step plan file

A single-step plan is one markdown file describing the full implementation of a task. Use this format when `plan-dev` is operating in **single-step** mode (the default).

## What is enforced vs. flexible

**Enforced** (structural metadata + tracking hooks, not content shape):

- File name pattern (section 1)
- Storage location (section 2)
- Frontmatter fields (section 3)
- Body language: Korean
- Research file links at the top of the body — when research files were created or consulted (section 4)
- A `## TODOs` checkbox list at the end of the body — for progress tracking (section 5)

**Flexible**:

- Everything else inside the body. Do NOT force the plan into a fixed section template (Goal / Technical Approach / Affected Files / Risks / Tradeoffs / Verification / …). When the plan was produced by a planning agent, copy its output **verbatim** into the body between the research links and the TODO checklist. Squeezing a rich agent-generated plan into a normalized template loses fidelity — preserve it as-is.

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

## 4. Research file links

When research files were created or consulted during planning, list them at the top of the body, immediately after the H1 heading. Use plain markdown links or Obsidian wikilinks — DO NOT wrap them in backticks. If no research files exist, omit this block entirely.

```markdown
Please refer to the research documents for detailed information about the related code and execution flow.
- {Link to RESEARCH file}
- {Link to RESEARCH file}
```

## 5. TODO checklist

Every plan ends with a `## TODOs` section: a checkbox list of concrete, executable tasks. Each item should be specific enough that another agent can execute it without re-investigating the codebase. This pairs with `implement-dev`, which ticks each box as it completes a task.

```markdown
## TODOs
- [ ] Task 1
- [ ] Task 2
```

If the agent-generated plan already contains its own task list, normalize it into this section's checkbox format and place it at the end. The rest of its content stays where it was.

## 6. File skeleton

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
---

# [Feature / Change Name]

<!-- Section 4: research file links — when applicable -->

<!-- Agent-generated plan body, copied verbatim. Keep whatever sections / ordering the agent produced. -->

## TODOs
- [ ] Task 1
- [ ] Task 2
```
