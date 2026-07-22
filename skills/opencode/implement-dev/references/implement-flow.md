# Implementation flow

`implement-dev` always takes one plan file describing the full implementation and executes it in one pass. This flow is followed by whoever actually edits the code - either a **Worker** (a subagent launched by the `implement-dev` Dispatcher, recognized by the `You are running as the implementation Worker subagent.` signal) or an **interactive** main session explicitly authorized for direct execution (for example, after a delegation failure). The Dispatcher itself does not edit; it only launches one Worker and parses that Worker's return. Mode-specific routing (asking the user vs. returning `blocked`) is called out inline.

## 1. Read the plan

Read the plan file end-to-end. The plan is a coarse-grained **direction** - it locks what and why, not how. Read it against these **guaranteed anchors** (what `plan-dev` always produces); the plan body may carry other sections too, but treat those as "use if present" rather than assumed:

- **Frontmatter** (`Application`, `JiraTicket`, `PlanType`, `Timestamp`, `Title`) - metadata; the Jira ticket and title flow into the report filename. Required.
- **Research file links** at the top of the body (when present) - the plan's pointer to "current-code exploration already done in the planning session". Each link is **required reading for the TODOs it names**. Read each linked research file before implementing the TODO it applies to; do not assume you "already know it". The plan reviewed this code once; you are starting cold.
- **`## TODOs`** - the outcome-level work items to execute and check off. Each item names *what* to achieve and where, with enough direction that you know the approach; the *how* is yours to resolve. Required.
- **`## Non-goals`** and **`## Key decisions`** - the cold-handoff anchors the plan uses to bound your discretion (what not to touch, what approach was picked over what alternative). `plan-dev` makes these required when the plan is not trivial, recommended when it is. Treat violation of either as a direction-level conflict, not a detail.
- **`## Acceptance Contract`** and **`## Authority Boundaries`** - guaranteed on plans created since `plan-dev`'s acceptance round. The contract's AC rows are what final verification must evidence (step 3); the boundaries bound your discretion the same way `## Non-goals` does - a must-ask item or stop condition is a direction-level conflict, not a detail. **Legacy plans** may lack both: do not refuse the run - skip AC evidence per step 3's legacy fallback, and default authority boundaries to this skill's own rules.

Do **not** expect a hardcoded `## Goal` / `## Technical Approach` / `## Affected Files` / `## Verification` template - the plan body is free-form between the anchors above. Adopt whatever sections it does carry; do not invent missing ones.

**Verification commands** are not read off a plan section: extract lint / format / test / build commands from `Makefile`, `AGENTS.md` (and legacy `CLAUDE.md` when present), or `README.md` during the `Prepare` step. (`implement-dev` already does this in SKILL.md.)

## 2. Implement task-by-task with TDD

Walk the `## TODOs` list in order. For each item:

1. **Read its linked research first** (when the plan tags the TODO with `(→ research: xxx)` or the research links name this TODO). You are cold; the research is what stops you from re-exploring code the planning session already mapped.
2. **Red** - add or update a failing test that expresses the expected behavior.
3. **Green** - write the minimum production code to make the test pass.
4. **Refactor** - clean up names, duplication, structure; keep tests green.
5. **Expand** - add edge-case tests (boundary values, error paths, empty inputs, concurrency as relevant). Each edge case is its own Red -> Green mini-cycle.
6. **Check off the TODO** - immediately flip the matching `- [ ]` to `- [x]` in the plan file. Do not batch.

Testing rules:
- Match the existing test style and structure in the project.
- Test **public/exported** methods and functions. Do not write tests for internal/private helpers.
- Exception to TDD: pure documentation, configuration, or trivially obvious one-line changes. When in doubt, write the test.

Deviations - resolve details, escalate direction:
- **Detail-level** - a helper / type / signature the plan did not spell out, a library quirk, an edge case, a local naming or structure choice: the *how* of a TODO whose *what* is unchanged. Resolve it yourself, TDD-first, and record it under the matching TODO's `편차` line in `## TODO Fulfillment` (and, where it widened scope, also in `## Plan Divergence`'s **Added** bucket, cross-referencing a `## Red Flags` entry by id). This is the discretion the coarse plan deliberately left you.
- **Direction-level** - the change contradicts the plan's goal / chosen approach / `## Key decisions`, requires touching something the plan put in `## Non-goals`, reverses a decision the plan made, or reveals the plan's premise is unworkable: the *what* is wrong, not just the *how*. **Stop before writing code for it.** Changing direction silently voids the review the user gave the plan.
  - **Worker mode**: you cannot ask the user. Mark the affected TODO `blocked` in `## TODO Status`, write nothing further for it, set `## Stage Status: blocked`, and lay out the conflict and the choices in `## Decision Needed` ([worker-contract.md](worker-contract.md)). Do not include other still-green TODOs as blocked.
  - **Interactive mode**: ask the user before writing code for the conflicting TODO, then resume after they decide.
- **When unsure which side**, treat it as direction-level and escalate - but only for genuine direction conflicts. Do not escalate ordinary mechanics, or the gate becomes noise the user rubber-stamps.

## 3. Final verification

After all non-blocked TODOs are complete, run the full verification suite you extracted during `Prepare`:

```bash
# Examples - adapt to the project's tech stack:
# Go:    go vet ./... && go test ./... && go build ./...
# Node:  npm run lint && npm test && npm run build
# Rust:  cargo clippy && cargo test && cargo build
```

All commands must pass. If anything fails, follow Error Recovery in SKILL.md.

If the plan happens to include a `## Verification` **checklist** (free-form, not guaranteed), tick its items in the plan file as each command passes. If the plan does not have one (the common case - verification commands were extracted from `Makefile`, `AGENTS.md` and legacy `CLAUDE.md` when present, or `README.md`, not authored into the plan), just run the extracted commands and record the result under `## Verification` in the Worker return (②) and in the report.

**Acceptance Contract check**: for each AC row in the plan's `## Acceptance Contract`, collect the work-specific evidence its Evidence column names (run the command, observe the behavior, locate the artifact) and record it - in the report's `## TODO Fulfillment` `AC:` lines and the return's `## Evidence`. An AC without evidence blocks `pass`: resolve it, or return the applicable non-pass status. When the plan has no `## Acceptance Contract` (legacy plan), do not refuse: skip this check, keep only the generic gates above, and record `Acceptance Contract: none (legacy plan)` in the report's `## Summary` and the return's `## Evidence`.

## 4. Refresh project docs (if affected)

If the implementation changed public APIs, commands, architecture, or setup steps, update `AGENTS.md`, legacy `CLAUDE.md` when present, and `README.md`. Preserve existing section structure; update only content that is now stale.

## 5. Write the completion report (①)

Create the completion report (①) under `docs/agents/dev/` following [report-file.md](report-file.md). The spine is `## TODO Fulfillment`: one sub-section per plan TODO, with `path:line` + symbol (implementation), `path:line` + test name (the behavior it pins), the `AC:` line (fulfilled AC id(s) + evidence pointer), and per-TODO deviation. The filename mirrors the plan filename by replacing `_PLAN_` with `_IMPL_`, and the report links back to the plan using a Markdown link.

After writing the report, add a Markdown link to it at the top of the plan file (under the plan's frontmatter or heading) so the plan/report link is bidirectional.

## 6. Send the return message

How this step manifests depends on mode:

- **Worker mode** - return only the fixed-heading Markdown ② from [worker-contract.md](worker-contract.md). Link the ① report by absolute path under `## Implementation Report`; do not paste its sections.
- **Interactive (Dispatcher direct) mode** - render the ③ chat summary: 2-4 bullets (what changed / verification status / red-flag and open-question gist / TODO completion at a glance) plus a clickable ① report link. Do not paste `## TODO Fulfillment`, `## Red Flags`, `## Open Questions`, `## Plan Divergence`, or lower ① sections verbatim; the report file carries those.

If `## Stage Status` (Worker) / verification (interactive) is `blocked` on a direction-level decision, surface the decision needed first and stop - do not proceed to additional stages, and do not retry the same conflict.
