# Implementation report file

A completion report captures what was implemented, how it diverged from the plan (if at all), and what the reviewer should look at first. Reports are produced by `implement-dev` in both modes and stored in Obsidian.

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
- Order files in `## Implementation Flow` so a reviewer can follow the same path a request takes through the code — start from the entry point (route, handler, CLI command) and work down to services, data layers, models.

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
ReportType: single-step | multi-steps-step | multi-steps-summary
Step: {N}   # only for multi-steps-step
---

# [Feature / Step Title]

Plan: [[00. Plans/{plan or sub-plan base}]]

## Summary
One-paragraph summary of what was implemented.

## Implementation Flow (ordered for review)
- `path/to/file1` — what was created/modified
- `path/to/file2` — what was created/modified

## Key Decisions
- decision: why this approach over alternatives

## Deviations from Plan
- what changed: why the plan was adjusted

## Testing
- `path/to/test1` — what it tests, key scenarios
- `path/to/test2` — ...

## Coverage
(Optional) Coverage summary if tooling is available.
```

Omit `## Key Decisions` and `## Deviations from Plan` when there are none. Omit `## Coverage` when not measured.

## 5. Final summary report (multi-steps only, optional)

When all steps are merged, a top-level summary report may be written at `{YYYYMMDD}_{Jira}_{App}_{descriptor}.md`. Its structure:

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
ReportType: multi-steps-summary
---

# [Project / Initiative Name] — Implementation Summary

Plan: [[00. Plans/{main plan base}]]

## Step Reports
- [[{base}-STEP-1]] — {step 1 title}
- [[{base}-STEP-2]] — {step 2 title}
- ...

## Overall Outcome
Short narrative of what was delivered end-to-end.

## Cross-step Deviations
Aggregated deviations that changed the shape of the plan across multiple steps.

## Coverage / Verification
Summary of final test coverage and verification results on `develop`.
```
