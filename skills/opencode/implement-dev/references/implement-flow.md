# Implementation flow

`implement-dev` always takes one plan file describing the full implementation and executes it in one pass.

## 1. Read the plan

Read the plan file end-to-end. The plan is a coarse-grained **direction** - it locks what and why, not how. Its structure:

- **Frontmatter** (`Application`, `JiraTicket`, `PlanType`, `Timestamp`, `Title`) - metadata; the Jira ticket and title flow into the report filename.
- **Research file links** at the top of the body (when present) - read these if the change touches code paths you have not already investigated. Detailed findings live in research files, not the plan body; the plan holds the direction distilled from them.
- **Free-form body** - the agent-generated direction, copied verbatim. It typically carries the goal, the chosen approach and why, and the affected area, but its section names are not fixed - do not expect a rigid `## Goal` / `## Technical Approach` / `## Affected Files` template. Recommended anchors (when not trivial) are `## Non-goals` and `## Key decisions`; the plan-internal mechanics are deliberately coarse and deferred to your discretion (TDD-first, against the running code).
- **`## TODOs`** - the outcome-level work items to execute and check off. Each item names *what* to achieve and where, with enough direction that you know the approach; the *how* is yours to resolve.

## 2. Implement task-by-task with TDD

Walk the `## TODOs` list in order. For each item:

1. **Red** - add or update a failing test that expresses the expected behavior.
2. **Green** - write the minimum production code to make the test pass.
3. **Refactor** - clean up names, duplication, structure; keep tests green.
4. **Expand** - add edge-case tests (boundary values, error paths, empty inputs, concurrency as relevant). Each edge case is its own Red -> Green mini-cycle.
5. **Check off the TODO** - immediately flip the matching `- [ ]` to `- [x]` in the plan file. Do not batch.

Testing rules:
- Match the existing test style and structure in the project.
- Test **public/exported** methods and functions. Do not write tests for internal/private helpers.
- Exception to TDD: pure documentation, configuration, or trivially obvious one-line changes. When in doubt, write the test.

Deviations - resolve details, escalate direction:
- **Detail-level** - a helper / type / signature the plan did not spell out, a library quirk, an edge case, a local naming or structure choice: the *how* of a TODO whose *what* is unchanged. Resolve it yourself, TDD-first, and record it in the report's `## Deviations from Plan` (cross-reference a `## Red Flags` entry if it widened scope). This is the discretion the coarse plan deliberately left you.
- **Direction-level** - the change contradicts the plan's `## Goal` / chosen approach / `## Key decisions`, requires touching something the plan put in `## Non-goals`, reverses a decision the plan made, or reveals the plan's premise is unworkable: the *what* is wrong, not just the *how*. **Stop and ask the user before writing code for it.** Changing direction silently voids the review the user gave the plan; do not decide it yourself and log it after the fact.
- **When unsure which side**, treat it as direction-level and ask - but only for genuine direction conflicts. Do not escalate ordinary mechanics, or the gate becomes noise the user rubber-stamps.

## 3. Final verification

After all TODOs are complete, run the full verification suite collected during Prepare:

```bash
# Examples - adapt to the project's tech stack:
# Go:    go vet ./... && go test ./... && go build ./...
# Node:  npm run lint && npm test && npm run build
# Rust:  cargo clippy && cargo test && cargo build
```

All commands must pass. If anything fails, follow Error Recovery in SKILL.md.

Tick the `## Verification` checklist items in the plan file as each command passes.

## 4. Refresh project docs (if affected)

If the implementation changed public APIs, commands, architecture, or setup steps, update `AGENTS.md` and legacy `CLAUDE.md` when present / `README.md`. Preserve existing section structure; update only content that is now stale.

## 5. Write the completion report

Create the completion report under `docs/agents/dev/` following [report-file.md](report-file.md). The report filename mirrors the plan filename by replacing `_PLAN_` with `_IMPL_`, and the report links back to the plan using a Markdown link.

After writing the report, add a Markdown link to it at the top of the plan file (under the plan's frontmatter or heading) so the plan/report link is bidirectional.

## 6. Send the report summary

Alongside the saved report, send only a short implementation-report summary (2-4 bullets or 2-3 sentences) and a clickable report link/path. Include what changed, verification status, and any red flags/open questions at a high level. Do not paste `## Summary`, `## Review Map`, `## Red Flags`, `## Open Questions`, `## Change Walkthrough`, or lower report sections verbatim into the session; the report file carries those details.
