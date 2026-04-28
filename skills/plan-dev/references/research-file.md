# How to create a RESEARCH file

A RESEARCH file is a structured record of codebase investigation performed before creating an implementation plan. It captures what was discovered about the current state of the code — execution paths, component relationships, or surrounding constraints — so that the PLAN document can reference concrete findings rather than embedding raw investigation details.

Not every task requires the same depth or angle of investigation. A RESEARCH file focuses on one of two types, chosen based on what the planned change demands. A single task may produce multiple RESEARCH files of different types when the scope requires understanding the codebase from more than one angle.

## 1. Investigate the codebase

Before writing anything, you need to actually investigate. The goal is to build a concrete understanding of the code — not summarize what you already know.

Start from what the planned change touches and work outward:

- **Find the entry point**: Identify the route, handler, CLI command, or event listener where the relevant flow begins. Use the project's code structure (often described in `AGENTS.md` or `CLAUDE.md`) to orient yourself.
- **Trace callers & callees**: For each function in the change area, find all callers (who depends on it) and callees (what it depends on). Follow the chain until you reach stable boundaries — entry points, external APIs, data stores.
- **Check interfaces & contracts**: Identify interfaces or contracts the modified code must satisfy. Find all implementations and verify whether the planned change requires updating them.
- **Map side effects**: Note events published/consumed, async jobs triggered, external API calls, or cache invalidations along the path.
- **Review existing tests**: Read test files for the affected code. Understand what behavior is already asserted, what edge cases are covered, and what testing patterns the project uses.

Every `file:line` reference in the research file must point to a location you actually verified during investigation. Do not include references from memory or assumption.

## 2. Choose the research type

### Flow

Traces the runtime execution path of a feature or operation, from entry point to terminal boundary (data store, external API, response).

**Choose this when** the change modifies behavior along an execution path — adding middleware, changing request processing, altering data transformations, or fixing a bug in a specific flow.

**What to capture:**
- Entry point (route, handler, CLI command) with `file:line` references
- Each layer the request/data passes through (middleware → service → repository → data store)
- Callers and callees at each significant function
- Side effects triggered along the path (events emitted, async jobs enqueued, external API calls)

### Structure

Maps the static relationships between components — interfaces, implementations, dependency directions, and module boundaries.

**Choose this when** the change affects how components connect — implementing a new interface, refactoring module boundaries, resolving dependency cycles, or introducing a new abstraction.

**What to capture:**
- Interface and contract definitions with `file:line` references
- All implementations and where they are registered or injected
- Dependency direction between modules
- Consumers that depend on the component being changed

## 3. Name the file

Use `{Application}-{Research Type}-{descriptor}`.

The `{descriptor}` should make the file's focus immediately clear to a reader scanning the project root (e.g., `RESEARCH-auth-flow.md`, `RESEARCH-module-dependencies.md`, `RESEARCH-test-gaps.md`).
The `{Application}` will be the name of the working repository, which does not include the full url. For example, the name of a repository, of which the origin is `github.com/sample-user/sample-server`, will be `sample-server`.

This file should be stored in `${OBSIDIAN_HOME}/01. Research` directory.

## 4. Write the content

- Content except the frontmatter and section titles should be written in Korean.

```markdown
---
Application: {Application}
ResearchType: [Flow | Structure]
Description: (Write a concise, understandable description for this research. AI agent will determine to read or not based on this description.)
---

# Research: [Subject]

> Type: [Flow | Structure]

(Sections and depth vary by type. Use `file:line` references throughout.
Add or remove sections as appropriate — the type determines the focus, not a rigid template.)
```

- ALWAYS make the most of diagrams, which are formatted by Mermaid syntax.
