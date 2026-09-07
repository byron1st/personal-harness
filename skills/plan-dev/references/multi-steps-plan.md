# Multi-steps plan files

A set of **standalone single-step plans** organized by one **main plan**. Each sub-plan is a complete [single-step plan](single-step-plan.md) — same frontmatter, free-form body, research links, anchors, `## Acceptance Contract`, `## Authority Boundaries`, `## TODOs` with their tags — and is executed **individually** by `implement-dev` in single-step mode.

The main plan adds nothing to any step's implementation. Its only job is the **relationship between sub-plans**: order, dependencies, shared conventions, and how they compose. Point `implement-dev` at a sub-plan, never at the main plan.

Used only when the user explicitly asks for a multi-step breakdown.

## Core principle

Each step is a complete develop → test → build cycle: after step N, the project compiles and all tests pass. This is what lets each sub-plan be planned, implemented, and reviewed on its own, and lets anyone pick up from the last completed step.

Because steps are planned together but implemented in **separate sessions**, granularity has one exception here. Step-internal mechanics stay coarse as always, but the **seam between steps** — the interfaces, types, schemas, and signatures one step exposes to the next — must be stated precisely, because later sub-plans are written against it and no shared session carries it.

**Step contract ≠ Acceptance Contract.** The step contract fixes the *seam* later sub-plans are written against. A sub-plan's `## Acceptance Contract` fixes *completion inside that step*. A stable seam can exist while its step is unfinished, and a finished step can still expose the wrong seam. Keep both.

## 1. File names

- Main: `{timestamp}_{Jira}_PLAN_{title}.md`
- Sub-plans: `{timestamp}_{Jira}_PLAN_{title}-STEP-{N}.md`, `N` from 1.

Components follow [single-step-plan.md](single-step-plan.md) §1. Sub-plans share the main plan's base name; only the suffix differs.

## 2. Storage

All files — main and sub-plans — in `docs/agents/dev/`.

## 3. Links

- Main → each sub-plan: `[Step 1](./20260622153045_PROJ-42_PLAN_introduce-event-bus-STEP-1.md)`
- Each sub-plan → main, in its header area: `Part of main plan: [...](./...)`
- Research links point from `docs/agents/dev/` to `../research/`.

## 4. Main plan

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: multi-steps
Timestamp: {timestamp}
Title: {title}
---
```

The body is free-form; shape it to the initiative. What it has to make answerable:

- **What is being built and why**, in a paragraph.
- **A `## Steps Overview` table** — step number, title, one-line summary, and what it depends on. Add a Mermaid DAG when dependencies are non-trivial enough that a table alone hides them, and note which steps can run in parallel.
- **Conventions that span steps** — error handling, logging, API response shape, auth — when they are not already in `AGENTS.md` / `CLAUDE.md`.
- **`## Requirements Coverage`** mapping each `FR-N` to the step(s) implementing it — only when a SPEC.md with numbered functional requirements is an input.
- **A sub-plan link list.**

A `Related research` list is optional here and stays a plain link list: the executor reads research from the sub-plan it is running, so the per-TODO tagging lives there, not at this level.

## 5. Sub-plan (`-STEP-N.md`)

A sub-plan **is** a single-step plan — follow [single-step-plan.md](single-step-plan.md) in full, including its own `## Acceptance Contract` and `## Authority Boundaries` scoped to this step, since each is evaluated and budgeted on its own. It differs in exactly three ways, all serving the parent:

1. Frontmatter carries `Step: {N}`. `PlanType` stays `single-step`, so it is detected and executed identically to any single-step plan.
2. A back-link to the main plan in the header area.
3. A `## Depends On` line naming prior steps, or "None". When SPEC.md is an input, an optional `## Implements` maps the `FR-N` this step covers.

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
Step: {N}
---

# Step {N}: {Title}

Part of main plan: [{timestamp}_{Jira}_PLAN_{title}.md](./{timestamp}_{Jira}_PLAN_{title}.md)

<!-- research links · ## Depends On · free-form body · anchors -->
<!-- ## Acceptance Contract · ## Authority Boundaries · ## TODOs -->
```

## 6. Decomposition

- **Incrementality first**: foundation, then dependent behavior. Every step leaves the project compiling and green.
- **Right-sized**: a step is one single-step plan's worth of focused work. Past roughly 10 TODOs, consider splitting.
- **Testable scope**: if you cannot define clear tests for a step, its scope is probably wrong.
- **FR-driven** when SPEC.md is the input: each `FR-N` already carries Input, Output, business rules, and edge cases. Group related FRs sharing dependencies; split one that is too big.
- **A scaffold step is the usual first step**: module init, directory structure, lint/format config, CI, and convention infrastructure.

Adapt to the project. A TUI, a backend service, a CLI, a library, and a full-stack app decompose differently — do not force one shape.

Before presenting: if only steps 1..N were completed, does the project still compile and pass? Does every `FR-N` appear in at least one step? Do the main plan's links match the filenames you will write?
