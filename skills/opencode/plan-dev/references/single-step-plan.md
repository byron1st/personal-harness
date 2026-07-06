# Single-step plan file

A single-step plan is one markdown file describing the full implementation of a task. Use this format when `plan-dev` is operating in **single-step** mode (the default).

## What is enforced vs. flexible

**Enforced** (structural metadata + tracking hooks, not content shape):

- File name pattern (section 1)
- Storage location (section 2)
- Frontmatter fields (section 3)
- Body language: Korean
- Research file links at the top of the body when research files were created or consulted (section 4)
- A `## TODOs` checkbox list at the end of the body for progress tracking (section 5)

**Flexible**:

- Everything else inside the body. Do NOT force the plan into a fixed section template (Goal / Technical Approach / Affected Files / Risks / Tradeoffs / Verification / ...). When the plan was produced by a planning agent, copy its output **verbatim** into the body between the research links and the TODO checklist. Squeezing a rich agent-generated plan into a normalized template loses fidelity; preserve it as-is.
- The verbatim rule preserves the agent's structure and reasoning; it is not a license to keep mechanics-level detail. Plan granularity (see SKILL.md) still governs: keep the direction, and push line-level edits / code sketches down into research files or drop them.

Two body elements are **recommended** (not required) because a coarse plan gives the implementer wide discretion and these are the cheapest way to bound it - both are information `implement-dev` cannot recover from environment feedback:

- `## Non-goals` - a few lines on what this change explicitly does *not* touch.
- `## Key decisions` - the chosen approach and, where it matters, the alternatives you rejected and why (so the implementer does not re-pick a discarded path under its own discretion).

Keep both short. Omit either when the plan is trivial enough not to need it.

## 1. File name

`{timestamp}_{Jira ticket number}_PLAN_{title}.md`

- `{timestamp}` - local time in `YYYYMMDDHHMMSS` format.
- `{Jira ticket number}` - extract from the current branch name using the regex `[A-Z]+-[0-9]+`. If it cannot be extracted, ask the user unless they explicitly confirm `NO-JIRA`.
- `{title}` - short, concise, hyphen-separated description. No spaces. Example: `refactor-service-layer-to-resolve-cycle-dependencies`.

Example: `20260622153045_BLC-692_PLAN_refactor-service-layer.md`.

## 2. Storage location

Always store the file in `docs/agents/dev/` under the project root. Create the directory if it does not exist.

## 3. Required frontmatter

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
---
```

These keys are required. Add other keys (e.g., `Tags`, `Status`) only when useful.

## 4. Research file links

When research files were created or consulted during planning, list them at the top of the body, immediately after the H1 heading. Use plain Markdown links. If no research files exist, omit this block entirely.

```markdown
Please refer to the research documents for detailed information about the related code and execution flow.
- [Research title](../research/research-title.md)
```

## 5. TODO checklist

Every plan ends with a `## TODOs` section: a checkbox list of tasks. Each item is an **outcome** the implementer owns, not a keystroke-level edit: name what to achieve and where, with enough direction that `implement-dev` knows the approach, then let it resolve the mechanics itself (TDD-first). Aim for outcome-level, not edit-level:

- Outcome-level (good): `- [ ] Add rate-limiting to the public API layer (token-bucket per API key)`
- Edit-level (avoid): `- [ ] In ratelimit.go create a TokenBucket struct with fields capacity, tokens, refillRate and a Take() method`

The second bakes in mechanics the implementer should decide against the running code, and inflates the plan past the point a human will actually review it. This pairs with `implement-dev`, which ticks each box as it completes a task.

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
Timestamp: {timestamp}
Title: {title}
---

# [Feature / Change Name]

<!-- Section 4: research file links, when applicable -->

<!-- Agent-generated plan body, copied verbatim. Keep whatever sections / ordering the agent produced. -->

<!-- Recommended direction anchors (section 5), when not trivial: -->
<!-- ## Non-goals -->
<!-- ## Key decisions -->

## TODOs
- [ ] Task 1
- [ ] Task 2
```
