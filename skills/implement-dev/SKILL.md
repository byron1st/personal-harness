---
name: implement-dev
description: Execute a plan-dev implementation plan — work its TODOs, evidence each Acceptance Contract row, and write the implementation report under docs/agents. Use when the user asks to implement a saved plan.
---

# Implement Dev

Execute one approved plan file in one pass: implement its `## TODOs`, verify, and produce a completion report under `docs/agents/dev`.

This skill is methodology. It does not start a persona.

- **Standalone** (`/implement-dev`) — the current session is the executor and asks the user when a decision is needed.
- **Loop** — `dev-loop` starts the `implementer` persona, which follows this skill. It cannot ask the user; it returns a Stage Status and the loop handles gates, `plan-consultant`, and retries.

## Prepare

1. **Plan file** — the user or the caller brief provides the path. If it is omitted, ask (standalone) or return `blocked` with `## Decision Needed` (loop).
2. **Verification commands** — use the caller brief's resolved commands when present, re-deriving only values marked `none`. Otherwise run `$HOME/.agents/scripts/detect-commands.sh` (reads `Makefile` targets and `package.json` scripts, returns JSON) and fill any `null` from `AGENTS.md` / `CLAUDE.md` / `README.md` prose. A command that still cannot be found is a question for the user (standalone) or `## Decision Needed` (loop).
3. **Project conventions** — read `AGENTS.md` / `CLAUDE.md` (root, plus any nested copy covering the files you will change). Where they are silent, match the surrounding code rather than importing a house style from elsewhere.

## The plan is direction, not a build script

The plan locks *what* and *why*; the *how* is yours to resolve against the running code. Its body is free-form apart from these anchors, which `plan-dev` guarantees:

| Anchor | What it is to you |
| --- | --- |
| Frontmatter | `Timestamp` / `JiraTicket` / `Title` form the report filename |
| Research links | Exploration already done. **Read each one before the TODO it names** — you are cold, and the planning session already mapped this code |
| `## TODOs` | The work items. Each carries `(AC-N)`, a `(mechanical)` / `(design-bearing)` tag, and sometimes `(→ research: …)` |
| `## Non-goals` · `## Key decisions` | What not to touch, and which approach was chosen over what. Violating either is a direction-level conflict |
| `## Acceptance Contract` | The AC rows final verification must evidence |
| `## Authority Boundaries` | Discretion, must-ask items, stop conditions, loop budget. A must-ask item is a direction-level conflict |

Adopt whatever other sections the plan carries; do not invent missing ones.

## Execute

Work the `## TODOs` in order. Read a TODO's linked research before implementing it. **Flip its `- [ ]` to `- [x]` in the plan file the moment it completes** — never batch, because the plan file is what makes the run resumable with no ambiguity about what has shipped.

Each TODO's behavior should end up pinned by a test, named per TODO in the report. Never weaken or delete an existing test to get a passing run.

### Deviations — resolve details, escalate direction

- **Detail-level** — a helper, signature, edge case, or local naming choice the plan did not spell out: the *how* of a TODO whose *what* is unchanged. Resolve it yourself and record it on that TODO's `편차` line. This is the discretion the coarse plan deliberately left you.
- **Direction-level** — the change contradicts the plan's goal, approach, `## Key decisions`, or `## Non-goals`, or the plan's premise turns out unworkable: the *what* is wrong. **Stop before writing code for it** — changing direction silently voids the review the user gave the plan. Loop: mark that TODO `blocked`, set `## Stage Status: blocked`, lay the conflict and choices out in `## Decision Needed`, and leave other TODOs alone. Standalone: ask the user, then resume.
- **Consultable** — both candidate approaches fit the plan, the plan is silent on which, and the wrong one is expensive to reverse (a persisted shape, a public signature, a concurrency model). **Only on a `(design-bearing)` TODO**, and only in the loop: return `## Stage Status: needs-design-decision` with the fork brief under `## Design Decision Needed` so the *caller* starts `plan-consultant` and resumes you with the decision; record it on the TODO's `편차` line. Standalone asks the user instead.
  - The tag is the only gate, and there is no cap on consultant calls — so `(mechanical)` TODOs never consult. A TODO carrying no difficulty tag counts as `(mechanical)`.
  - A consultant cannot authorize a direction change. If the answer would contradict the plan, the item was direction-level all along: escalate instead.

When genuinely unsure which bucket applies, treat it as direction-level — but only for real direction conflicts, or the gate becomes noise the user rubber-stamps.

### Finish

1. Run the verification commands resolved in Prepare. All must pass. Stop after **3 failed attempts on the same error** and return `failed` (loop) or ask the user (standalone); this skill never retries under a different model.
2. **Evidence each AC**: for every row in `## Acceptance Contract`, collect the proof its Evidence column names and record it on the report's `AC:` lines and in the return's `## Evidence`. An unevidenced AC blocks `pass`.
3. Update `AGENTS.md` / `CLAUDE.md` / `README.md` if the change made them stale, preserving their section structure.
4. Write the report per [references/report-file.md](references/report-file.md), then add a link to it at the top of the plan file so plan and report point at each other.

## Report

Three artifacts, and they are not interchangeable:

- **① Report file** — the on-disk body under `docs/agents/dev/`, spine `## TODO Fulfillment`. Format in [references/report-file.md](references/report-file.md).
- **② Executor return** — the fixed-heading Markdown in [references/executor-contract.md](references/executor-contract.md). Links ① by absolute path; never pastes its sections.
- **③ Chat summary** — 2-4 bullets plus a clickable link to ①, rendered by the caller (or by standalone as its final output). Never ① or ② verbatim.

On `blocked`, surface `## Decision Needed` first and stop. On `needs-design-decision`, the loop starts `plan-consultant` and resumes — that is not `blocked`.

## Completion

- Every plan TODO checkbox is current.
- Every AC has recorded evidence.
- ① is saved and the plan/report links are bidirectional.
- ② uses the fixed headings and links ① by absolute path.
