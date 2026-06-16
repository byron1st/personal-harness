# Single-step implementation

Use this reference when `implement-dev` is operating in **single-step** mode — one plan file describing the full implementation, executed in one pass.

## 1. Read the plan

Read the plan file end-to-end. In particular:

- `## Goal`, `## Technical Approach` — the intent.
- `## Affected Files` — the scope of changes.
- `## Verification` — commands that must pass at the end.
- `## TODOs` — the atomic work items to execute and check off.
- Any linked research files (top of the plan) — read these if the change touches code paths you haven't already investigated.

## 2. Implement task-by-task with TDD

Walk the `## TODOs` list in order. For each item:

1. **Red** — add or update a failing test that expresses the expected behavior.
2. **Green** — write the minimum production code to make the test pass.
3. **Refactor** — clean up names, duplication, structure; keep tests green.
4. **Expand** — add edge-case tests (boundary values, error paths, empty inputs, concurrency as relevant). Each edge case is its own Red → Green mini-cycle.
5. **Check off the TODO** — immediately flip the matching `- [ ]` to `- [x]` in the plan file. Do not batch.

Testing rules:
- Match the existing test style and structure in the project.
- Test **public/exported** methods and functions. Do not write tests for internal/private helpers.
- Exception to TDD: pure documentation, configuration, or trivially obvious one-line changes. When in doubt, write the test.

Deviations:
- If you must diverge from the plan (missing detail, incorrect assumption, better approach surfaced during work), proceed but record the deviation for the completion report.

## 3. Final verification

After all TODOs are complete, run the full verification suite collected during Prepare:

```bash
# Examples — adapt to the project's tech stack:
# Go:    go vet ./... && go test ./... && go build ./...
# Node:  npm run lint && npm test && npm run build
# Rust:  cargo clippy && cargo test && cargo build
```

All commands must pass. If anything fails, follow Error Recovery in SKILL.md.

Tick the `## Verification` checklist items in the plan file as each command passes.

## 4. Refresh project docs (if affected)

If the implementation changed public APIs, commands, architecture, or setup steps, update `AGENTS.md` / `CLAUDE.md` / `README.md`. Preserve existing section structure; update only content that is now stale.

## 5. Write the completion report

Create the completion report in Obsidian following [report-file.md](report-file.md). The report is saved to `${OBSIDIAN_HOME}/02. Implementation Reports/` with the same base filename as the plan, and linked back to the plan via wikilink.

After writing the report, add a wikilink to it at the top of the plan file (under the plan's frontmatter or heading) so the plan ↔ report link is bidirectional.

## 6. Print the review cockpit

Alongside the saved report, print its **cockpit** sections — `## Summary`, `## Review Map`, `## Red Flags`, `## Open Questions`, `## Change Walkthrough` — verbatim except for the clickable-link conversion described in [report-file.md](report-file.md), followed by the report path, so the user can start reviewing without opening Obsidian. The `## Key Decisions` and everything below it stay in the file for on-demand reading; do not reprint them here.
