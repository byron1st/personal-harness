# Research file

A structured record of codebase investigation done during planning: what the **current** code does — execution paths, component relationships, surrounding constraints — so the plan can reference concrete findings instead of carrying raw investigation.

Drafted in memory during plan mode, written to disk immediately after plan mode exits. One planning task may produce several files when the scope needs more than one angle.

Every `file:line` reference must point at a location actually verified during investigation. Never from memory or assumption — a stale anchor sends a cold executor to the wrong place, which is worse than no anchor.

## 1. Type

One per file, recorded in frontmatter, shaping the body's focus:

- **Flow** — the runtime execution path of a feature, entry point to terminal boundary. Choose it when the change modifies behavior along a path: middleware, request processing, data transformation, a bug in a specific flow. Capture the entry point, each layer the data crosses, callers and callees at significant functions, and side effects triggered along the way.
- **Structure** — the static relationships between components. Choose it when the change affects how things connect: implementing an interface, refactoring module boundaries, breaking a dependency cycle, introducing an abstraction. Capture interface definitions, every implementation and where it is registered or injected, dependency direction, and the consumers of what is changing.

## 2. Name and storage

`docs/agents/research/{title}.md`, where `{title}` is short kebab-case that makes the focus obvious to someone scanning the directory — `auth-flow`, `module-dependencies`, `test-gaps`. Create the directory if missing.

## 3. Frontmatter

```yaml
---
Application: {Application}
ResearchType: Flow      # or: Structure
Description: Concise, understandable description for this research. AI agents decide whether to read this file based on this description.
---
```

`Description` carries real weight: later planning and sync runs read `index.md` and decide what to open from this field alone. Write it so a stranger can tell at a glance whether the file bears on their problem.

## 4. Index

Maintain `docs/agents/research/index.md` whenever a research file is created, renamed, deleted, or has its frontmatter changed — in the same persistence step. Agents read this index first and open only what looks relevant, so an index out of sync with the files silently hides research.

It is an index only; never duplicate body content into it.

```markdown
# Research Index

| File | Application | ResearchType | Description |
|------|-------------|--------------|-------------|
| [auth-flow](./auth-flow.md) | sample-server | Flow | Explains the request path for authentication. |
| [module-dependencies](./module-dependencies.md) | sample-server | Structure | Maps service and repository dependencies. |
```

One row per file (excluding `index.md`), with `Application` / `ResearchType` / `Description` exactly matching the file's frontmatter. Sort by `Application`, then `ResearchType`, then title, for stable diffs.

## 5. Body

Korean, apart from section titles. Structure is yours — the type determines the focus, not a template. Use `file:line` references throughout and lean on Mermaid diagrams wherever they clarify the picture.
