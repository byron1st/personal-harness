# Implementation report file

A completion report is a **thin review overlay** on an AI-written change: it states what was implemented and why, points the reviewer at the diff rather than copying it, surfaces where to be suspicious, and orders the reading so the code can be checked against its intent quickly. The goal is that a reviewer, armed with this overlay plus the diff, catches more and faster than with a flat diff alone. Reports are produced by `implement-dev` in both modes and stored in Obsidian.

## 1. Storage location

ALWAYS store the report in `${OBSIDIAN_HOME}/02. Implementation Reports/`.

## 2. File name

The report's base filename **matches the corresponding plan file** so pairs are trivially discoverable:

- **single-step**: `{YYYYMMDD}_{Jira}_{App}_{descriptor}.md` — same base as the plan.
- **multi-steps, per-step**: `{YYYYMMDD}_{Jira}_{App}_{descriptor}-STEP-N.md` — same base as the sub-plan.
- **multi-steps, final summary** (optional): `{YYYYMMDD}_{Jira}_{App}_{descriptor}.md` — same base as the main plan.

The plan's `{YYYYMMDD}_{Jira}_{App}_{descriptor}` stem is determined when the plan was created; reuse it exactly.

## 3. Wikilink convention — bidirectional

- The report file links to its plan at the top: `Plan: [[00. Plans/{plan base}]]` (omit `.md`, no backticks.).
- The plan file must also link to its report: add `Report: [[02. Implementation Reports/{report base}]]` near the top of the plan (below frontmatter or top heading). This edit happens after the report is written.
- For multi-steps:
  - Each per-step report links to its sub-plan; each sub-plan links to its report.
  - The optional final summary report links to the main plan, to each per-step report, and the main plan links to the summary report.

## 4. Content format

- Section titles in English; body content in Korean.
- The report is an **overlay, not a copy**. Reference the change through `ReviewBase` (how to see the diff) and `file:line` anchors; never paste diffs or file bodies into the report. This keeps it small, avoids staleness, and anchors every position to one frozen revision.
- Separate the deterministic from the narrative honestly. The implementer just wrote this code, so intent, risk, and red flags are cheap and trustworthy — but nothing here is statically verified, so anything you are unsure of belongs in `## Open Questions`, not asserted as fact.
- Order `## Change Walkthrough` **foundation-first** (types & contracts → core logic → wiring → tests) so the reviewer never meets a symbol before its definition. Tag every group with a risk level and a recommended review lens, and concentrate explanation where risk is high — do not spread attention uniformly.
- The first four sections (`## Summary`, `## Review Map`, `## Red Flags`, `## Open Questions`) are the **review cockpit**: the high-signal block the skill prints to the session. Everything below them is detail the reviewer reads on demand from the file.

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
ReportType: single-step | multi-steps-step | multi-steps-summary
Step: {N}   # only for multi-steps-step
ReviewBase: {command or commit range that reproduces the reviewed snapshot, e.g. `git diff develop...feature/step-3` or `git diff <base-sha> <head-sha>`}
---

# [Feature / Step Title]

Plan: [[00. Plans/{plan or sub-plan base}]]

## Summary
2–3 sentences: what was implemented **and why** — the intent the reviewer should judge the code against. Lead with the goal, not the mechanics.

## Review Map
- **See the change**: `{ReviewBase}`. Every `file:line` anchor in this report is valid against that snapshot.
- **Reading order** — foundation-first; read top to bottom and you never meet a symbol before its definition:

  | # | Group | Risk | Lens | Intent (one line) |
  |---|-------|------|------|-------------------|
  | 1 | {types & contracts} | low | skim | {why this group exists} |
  | 2 | {core logic} | high | line-by-line | {…} |
  | 3 | {wiring / glue} | medium | top-down | {…} |
  | 4 | {tests} | low | test-as-spec | {…} |

  Risk ∈ low · medium · high. Lens ∈ line-by-line · top-down · bottom-up+flow · test-as-spec · skim.

## Red Flags
AI-specific signals the reviewer should distrust on sight — new dependencies, possibly-hallucinated or unverified APIs, over-engineering, scope beyond the plan, swallowed errors, hardcoded values or secrets. Each gets a stable id and a `file:line` anchor. Write `None` if there are genuinely none — never omit the section.
- **RF1** `path:line` — {signal}: {what, and why it deserves a look}

## Open Questions
Points the implementer is **not confident** about — surfaced here, never hidden behind plausible-looking code. Each gets a stable id and anchor so the reviewer can answer by id. Write `None` if none.
- **OQ1** `path:line` — {the uncertainty, and why it matters}

## Change Walkthrough (foundation-first)
The detailed walk, in the same order as the Review Map. One subsection per group; within a group, list symbols in dependency order (definition before use). For each symbol state what changed **and why** — the reasoning that is invisible from the code alone.

### 1. {Group name}  [risk · lens]
{Group intent — why this group exists, one or two lines.}
- `path:line` `symbolName` — what changed + why
- `path:line` `symbolName` — …

### 2. {Group name}  [risk · lens]
…

## Key Decisions
(Optional) Cross-cutting decisions not tied to a single group — e.g. choosing one library or pattern over another. Omit when the group intent already carries the reasoning.
- decision: why this approach over alternatives

## Deviations from Plan
- what changed: why the plan was adjusted. If a deviation widened scope, cross-reference the matching **RF**.

## Testing
- `path/to/test1` — what it tests; **which behavior it pins** (read these as the executable spec for this change).
- `path/to/test2` — ...

## Manual Verification
(Required for multi-steps-step reports. Lists checks the user must perform before approving the merge to `develop`. Write `None` if there is nothing to verify manually.)
- [ ] What to check, where to check it, and the expected outcome
- [ ] ...

## Coverage
(Optional) Coverage summary if tooling is available.
```

`## Red Flags` and `## Open Questions` are **never omitted** — write `None` when empty, because "nothing to flag" is itself a signal the reviewer needs. Omit `## Key Decisions` and `## Deviations from Plan` when there are none, and `## Coverage` when not measured. `## Manual Verification` is **required** for `multi-steps-step` reports (write `None` if empty) and **optional** for `single-step` reports.

## 5. Final summary report (multi-steps only, optional)

When all steps are merged, a top-level summary report may be written at `{YYYYMMDD}_{Jira}_{App}_{descriptor}.md`. Its structure:

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
ReportType: multi-steps-summary
ReviewBase: {cumulative diff on develop, e.g. `git diff main...develop`}
---

# [Project / Initiative Name] — Implementation Summary

Plan: [[00. Plans/{main plan base}]]

## Step Reports
- [[{base}-STEP-1]] — {step 1 title}
- [[{base}-STEP-2]] — {step 2 title}
- ...

## Overall Outcome
Short narrative of what was delivered end-to-end.

## Outstanding Red Flags & Open Questions
Aggregated from the per-step reports — only those still unresolved after all merges. Reference each by step and id (e.g. `STEP-2 RF1`, `STEP-3 OQ2`). Write `None` if every flag and question was resolved at its step's review gate.
- {STEP-N RFx / OQx} `path:line` — {the still-open concern}

## Cross-step Deviations
Aggregated deviations that changed the shape of the plan across multiple steps.

## Coverage / Verification
Summary of final test coverage and verification results on `develop`.
```
