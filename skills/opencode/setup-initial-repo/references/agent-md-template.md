# Agent File Section Structure

Required sections, in order, for `AGENTS.md` and legacy `CLAUDE.md` when present. The agent fills in each section's content using SPEC.md, project state, and the language conventions in `docs/`.

This file lists **which sections to include**. It does not provide content — that is the agent's job.

## Required sections

1. **Title and description**
   - `# {Project Name}` followed by a 1–2 line summary: what the project does + the core tech stack.


2. **Key requirements**
  - List key non-functional requirements with a concise, short, one-sentence description.
    - e.g. `- High Performance: Low latency is a primary goal.`
  - ALWAYS add `Minimal Dependencies: Prefer the standard library over external ones.`

3. **Core Commands**
   - List every common operation as a `make ...` invocation. The Makefile is the source of truth — never quote a bare `go test ./...` or `npm test` here.
   - At minimum: `build`, `test`, `test-single`, `lint`, `lint-fix`, `run` (drop the ones the Makefile does not expose).

4. **Architecture Overview**
   - Module-level responsibilities. One bullet per package or top-level directory, format: `path/: one-line responsibility`.
   - Compress from SPEC.md's Architecture section; do not copy verbatim.

5. **Code Conventions**
   - 3–5 prescriptive bullets covering the highest-impact rules.
   - Defer the full list to `docs/{language}-conventions.md` via a one-line link.

6. **Testing**
   - Test framework, file naming rule, mocking approach, the single command to run before commit.

7. **Boundaries**
   - Convert SPEC.md Constraints into "NEVER ..." rules, each paired with a recommended alternative.

8. **References**
   - Link to SPEC.md and to `docs/{language}-conventions.md`.
   - Add other internal docs the agent should consult (only when they actually exist).

## Constraints

- **English only**, regardless of conversation or SPEC.md language.
- **Under 150 lines.** If you cannot fit, push detail into `docs/` references and link.
- **Every Core Commands entry must back to a Makefile target.** If a target is missing, add it to the Makefile first.
- **Drop sections that do not apply** — empty sections are worse than no section.
- **Be prescriptive, not explanatory** — "Wrap with `fmt.Errorf(\"verb-ing X: %w\", err)`" beats "Wrap errors appropriately".
