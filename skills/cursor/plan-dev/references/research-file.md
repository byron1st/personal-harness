# How to create a RESEARCH file

A RESEARCH file is a structured record of codebase investigation performed before creating an implementation plan. It captures what was discovered about the current state of the code: execution paths, component relationships, and surrounding constraints, so the plan document can reference concrete findings rather than embedding raw investigation details.

Within `plan-dev`, research is **drafted in memory during plan mode** and **written to disk after plan mode exits** (step 11 of `SKILL.md`). Investigation itself uses only read tools, which is compatible with plan mode.

Not every task needs the same depth or angle. A single task may produce multiple RESEARCH files of different types when the scope requires understanding the codebase from more than one angle.

## What is enforced vs. flexible

**Enforced**:

- File name pattern (section 3)
- Storage location (section 3)
- Frontmatter fields including `ResearchType` (section 4)
- Research index entry in `docs/agents/research/index.md` (section 5)
- Body language: Korean

**Flexible**:

- Section structure inside the body. The type (Flow vs. Structure) determines the focus, not a rigid template. Use whatever sections best capture what you found, and lean heavily on Mermaid diagrams when they clarify the picture.

## 1. Investigate the codebase (read-only)

Before drafting anything, actually investigate. The goal is concrete understanding, not a summary of what you already assume.

Start from what the planned change touches and work outward:

- **Find the entry point**: route, handler, CLI command, or event listener where the relevant flow begins. Use the project's structure (often in `AGENTS.md` or `CLAUDE.md`) to orient yourself.
- **Trace callers & callees**: for each function in the change area, find all callers and callees. Follow the chain to stable boundaries: entry points, external APIs, data stores.
- **Check interfaces & contracts**: identify interfaces or contracts the modified code must satisfy. Find all implementations and verify whether the planned change requires updating them.
- **Map side effects**: events published/consumed, async jobs triggered, external API calls, cache invalidations along the path.
- **Review existing tests**: read test files for the affected code. Understand what behavior is asserted, what edge cases are covered, and what testing patterns the project uses.

Every `file:line` reference in the research file must point to a location you actually verified during investigation. Do not include references from memory or assumption.

## 2. Choose the research type

The type goes into frontmatter and shapes the body's focus. Pick one per file. A single planning task may produce one Flow file and one Structure file when both angles matter.

### Flow

Traces the runtime execution path of a feature or operation, from entry point to terminal boundary (data store, external API, response).

**Choose this when** the change modifies behavior along an execution path: adding middleware, changing request processing, altering data transformations, or fixing a bug in a specific flow.

**What to capture** (suggested, adapt to fit):
- Entry point (route, handler, CLI command) with `file:line` references
- Each layer the request/data passes through (middleware -> service -> repository -> data store)
- Callers and callees at each significant function
- Side effects triggered along the path (events emitted, async jobs enqueued, external API calls)

### Structure

Maps the static relationships between components: interfaces, implementations, dependency directions, and module boundaries.

**Choose this when** the change affects how components connect: implementing a new interface, refactoring module boundaries, resolving dependency cycles, or introducing a new abstraction.

**What to capture** (suggested, adapt to fit):
- Interface and contract definitions with `file:line` references
- All implementations and where they are registered or injected
- Dependency direction between modules
- Consumers that depend on the component being changed

## 3. Name and store the file

File name: `{title}.md`

- `{title}` - short, descriptive, kebab-case title that makes the focus immediately clear to a reader scanning `docs/agents/research/`. Examples: `auth-flow`, `module-dependencies`, `test-gaps`.

Storage location: `docs/agents/research/` under the project root. Create the directory if it does not exist.

The actual file write happens in step 11 of `SKILL.md`, after plan mode is exited.

## 4. Required frontmatter

```yaml
---
Application: {Application}
ResearchType: Flow      # or: Structure
Description: Concise, understandable description for this research. AI agents decide whether to read this file based on this description.
---
```

The `Description` matters: future planning and research-sync runs inspect `docs/agents/research/index.md` and decide what to read based on this field. Write it so a stranger can tell at a glance whether this file is relevant to their problem.

## 5. Research index

Maintain `docs/agents/research/index.md` whenever a research file is created, renamed, deleted, or its frontmatter changes. Agents must read this index first, then open only the research files whose metadata looks relevant.

`index.md` is an index only. Do not duplicate research body content there.

Required shape:

```markdown
# Research Index

| File | Application | ResearchType | Description |
|------|-------------|--------------|-------------|
| [auth-flow](./auth-flow.md) | sample-server | Flow | Explains the request path for authentication. |
| [module-dependencies](./module-dependencies.md) | sample-server | Structure | Maps service and repository dependencies. |
```

Rules:
- Include one row per research file in `docs/agents/research/`, excluding `index.md`.
- Keep `Application`, `ResearchType`, and `Description` exactly aligned with the research file frontmatter.
- Sort rows by `Application`, then `ResearchType`, then file title for stable diffs.
- When updating a research file's frontmatter, update the matching index row in the same persistence step.

## 6. Body

- Body content (everything except frontmatter and section titles) is in Korean.
- Section structure is your call. The type determines the focus, not a rigid template.
- Use `file:line` references throughout, and lean on Mermaid diagrams whenever they help.

```markdown
---
Application: {Application}
ResearchType: [Flow | Structure]
Description: ...
---

# Research: [Subject]

> Type: [Flow | Structure]

(Sections vary by type and scope. Use whatever shape best captures what you found, with `file:line` references and Mermaid diagrams where they help.)
```
