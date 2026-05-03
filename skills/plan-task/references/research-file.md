# How to create a RESEARCH file

A RESEARCH file is a structured record of codebase investigation performed before creating an implementation plan. It captures what was discovered about the current state of the code — execution paths, component relationships, surrounding constraints — so the plan document can reference concrete findings rather than embedding raw investigation details.

Within `plan-task`, research is **drafted in memory during plan mode** and **written to disk after plan mode exits** (step 11 of `SKILL.md`). Investigation itself uses only read tools, which is compatible with plan mode.

Not every task needs the same depth or angle. A single task may produce multiple RESEARCH files of different types when the scope requires understanding the codebase from more than one angle.

## What is enforced vs. flexible

**Enforced**:

- File name pattern (section 3)
- Storage location (section 3)
- Frontmatter fields including `ResearchType` (section 4)
- Body language: Korean

**Flexible**:

- Section structure inside the body. The type (Flow vs. Structure) determines the *focus*, not a rigid template. Use whatever sections best capture what you found, and lean heavily on Mermaid diagrams when they clarify the picture.

## 1. Investigate the codebase (read-only)

Before drafting anything, actually investigate. The goal is concrete understanding — not a summary of what you already assume.

Start from what the planned change touches and work outward:

- **Find the entry point**: route, handler, CLI command, or event listener where the relevant flow begins. Use the project's structure (often in `AGENTS.md` or `CLAUDE.md`) to orient yourself.
- **Trace callers & callees**: for each function in the change area, find all callers and callees. Follow the chain to stable boundaries — entry points, external APIs, data stores.
- **Check interfaces & contracts**: identify interfaces or contracts the modified code must satisfy. Find all implementations and verify whether the planned change requires updating them.
- **Map side effects**: events published/consumed, async jobs triggered, external API calls, cache invalidations along the path.
- **Review existing tests**: read test files for the affected code. Understand what behavior is asserted, what edge cases are covered, and what testing patterns the project uses.

Every `file:line` reference in the research file must point to a location you actually verified during investigation. Do not include references from memory or assumption.

## 2. Choose the research type

The type goes into frontmatter and shapes the body's focus. Pick one per file. A single planning task may produce one Flow file and one Structure file when both angles matter.

### Flow

Traces the runtime execution path of a feature or operation, from entry point to terminal boundary (data store, external API, response).

**Choose this when** the change modifies behavior along an execution path — adding middleware, changing request processing, altering data transformations, or fixing a bug in a specific flow.

**What to capture** (suggested, adapt to fit):
- Entry point (route, handler, CLI command) with `file:line` references
- Each layer the request/data passes through (middleware → service → repository → data store)
- Callers and callees at each significant function
- Side effects triggered along the path (events emitted, async jobs enqueued, external API calls)

### Structure

Maps the static relationships between components — interfaces, implementations, dependency directions, and module boundaries.

**Choose this when** the change affects how components connect — implementing a new interface, refactoring module boundaries, resolving dependency cycles, or introducing a new abstraction.

**What to capture** (suggested, adapt to fit):
- Interface and contract definitions with `file:line` references
- All implementations and where they are registered or injected
- Dependency direction between modules
- Consumers that depend on the component being changed

## 3. Name and store the file

File name: `{Application}-{ResearchType}-{descriptor}.md`

- `{Application}` — working repository name without the URL. Example: `github.com/sample-user/sample-server` → `sample-server`.
- `{ResearchType}` — `Flow` or `Structure`.
- `{descriptor}` — make the focus immediately clear to a reader scanning the project root. Examples: `auth-flow`, `module-dependencies`, `test-gaps`.

Examples: `sample-server-Flow-auth.md`, `sample-server-Structure-module-deps.md`.

Storage location: `${OBSIDIAN_HOME}/01. Research/`.

The actual file write happens in step 11 of `SKILL.md`, after plan mode is exited.

## 4. Required frontmatter

```yaml
---
Application: {Application}
ResearchType: Flow      # or: Structure
Description: Concise, understandable description for this research. AI agents decide whether to read this file based on this description.
---
```

The `Description` matters: future planning runs query `obsidian base:query file="Research.base" ...` and decide what to read based on this field. Write it so a stranger can tell at a glance whether this file is relevant to their problem.

## 5. Body

- Body content (everything except frontmatter and section titles) is in Korean.
- Section structure is your call — the type determines the focus, not a rigid template. Add or remove sections as appropriate.
- Use `file:line` references throughout, and lean on Mermaid diagrams whenever they clarify the picture.

```markdown
---
Application: {Application}
ResearchType: [Flow | Structure]
Description: ...
---

# Research: [Subject]

> Type: [Flow | Structure]

(Sections vary by type and scope. Use whatever shape best captures what you
found, with `file:line` references and Mermaid diagrams where they help.)
```
