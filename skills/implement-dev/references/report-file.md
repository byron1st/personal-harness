# Implementation report file

A completion report is a **thin review overlay** on an AI-written change: it states what was implemented and why, points the reviewer at the diff rather than copying it, surfaces where to be suspicious, and orders the reading so the code can be checked against its intent quickly. The report's spine is per-TODO fulfillment - the reviewer answers "for each plan TODO, where was it implemented, what tests pin it, and where did it diverge from the plan?" - not a foundation-first walk of every touched symbol. Foundation-first reading survives only as an optional `## Deep Reading Order` for genuinely high-risk changes that need that ordering on top. Reports are produced by `implement-dev` and stored under `docs/agents/dev`.

## 1. Storage location

Always store the report in `docs/agents/dev/` under the project root. Create the directory if it does not exist.

## 2. File name

The report's base filename mirrors the corresponding plan file so pairs are trivially discoverable: `{timestamp}_{Jira}_IMPL_{title}.md` - the same timestamp, Jira ticket, and title as the plan, with `PLAN` changed to `IMPL`. When the plan is a `-STEP-N` sub-plan, its stem already carries that suffix, so the report mirrors it as `{timestamp}_{Jira}_IMPL_{title}-STEP-N.md`.

Reuse the **plan's** `{timestamp}_{Jira}_{title}` stem exactly - the plan's actual creation timestamp, not a fresh one at write time - so the plan/report pair stays linkable across runs.

## 3. Link convention - bidirectional

- The report file links to its plan at the top using a Markdown link, e.g. `Plan: [20260622153045_PROJ-42_PLAN_title.md](./20260622153045_PROJ-42_PLAN_title.md)`.
- The plan file must also link to its report: add `Report: [20260622153045_PROJ-42_IMPL_title.md](./20260622153045_PROJ-42_IMPL_title.md)` near the top of the plan (below frontmatter or top heading). This edit happens after the report is written.

## 4. Content format

- Section titles in English; body content in Korean.
- The report is an **overlay, not a copy**. Reference the change through `ReviewBase` (how to see the diff) and `file:line` anchors; never paste diffs or file bodies into the report. This keeps it small, avoids staleness, and anchors every position to one frozen revision.
- Separate the deterministic from the narrative honestly. The implementer just wrote this code, so intent, risk, and red flags are cheap and trustworthy, but nothing here is statically verified. Anything you are unsure of belongs in `## Open Questions`, not asserted as fact.
- The spine of the report is **`## TODO Fulfillment`**: one sub-section per plan TODO, each carrying what was implemented (`path:line` + symbol + why), the test that pins that TODO's behavior (`path:line` + test name + what behavior it pins as the executable spec for this change), the `AC:` line (which Acceptance Contract id(s) the TODO fulfills, with an evidence pointer; `none (legacy plan)` when the plan has no `## Acceptance Contract`), and any deviation specific to that TODO. The risk/lens metadata from the old `## Review Map` has been folded into the per-TODO sub-sections as an optional `Risk / Lens` line - include it only when a single TODO is high-risk and the reviewer would benefit from being told to read it line-by-line.
- The completion chat output (② executor return, or the ③ chat summary) must not paste report sections verbatim. After saving the report, the caller sends a short summary, not the body. Keep `## TODO Fulfillment`, `## Red Flags`, `## Open Questions`, `## Plan Divergence`, and all lower sections in the report file for on-demand reading.

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
ReportType: single-step
Timestamp: {timestamp}
Title: {title}
ReviewBase: {command or commit range that reproduces the reviewed snapshot, e.g. `git diff <base-sha> <head-sha>`}
---

# [Feature / Step Title]

Plan: [{plan filename}](./{plan filename})

## Summary
2-3 sentences: what was implemented **and why** - the intent the reviewer should judge the code against. Lead with the goal, not the mechanics.

## TODO Fulfillment
See the change: `{ReviewBase}`. Every `path:line` anchor in this report is valid against that snapshot.

### TODO 1: {the matching item from the plan's `## TODOs`} - done | partial | blocked
- Risk / Lens: {high / line-by-line} (optional; only when this TODO is high-risk and needs that lens)
- 구현: `path:line` `symbol` - what was changed and why
- 테스트: `path:line` `TestName` - which behavior it pins (this TODO's executable spec)
- AC: {이행한 AC id(s) + 증거 포인터, e.g. `AC-1 — make e2e 통과 로그`; 플랜에 `## Acceptance Contract`가 없으면 `none (legacy plan)`}
- 편차: {how this TODO diverged from the plan; "none" when it did not}

### TODO 2: ...
- ...

## Red Flags
AI-specific signals the reviewer should distrust on sight: new dependencies, possibly-hallucinated or unverified APIs, over-engineering, scope beyond the plan, swallowed errors, hardcoded values or secrets. Each gets a stable id and a `file:line` anchor. Write `None` if there are genuinely none; never omit the section.
- **RF1** `path:line` - {signal}: {what, and why it deserves a look}

## Open Questions
Points the implementer is **not confident** about, surfaced here, never hidden behind plausible-looking code. Each gets a stable id and anchor so the reviewer can answer by id. Write `None` if none; never omit the section.
- **OQ1** `path:line` - {the uncertainty, and why it matters}

## Plan Divergence
Plan-vs-implementation deltas, sorted into three buckets so the reviewer can tell "this was different" from "this was more than the plan asked" from "this got skipped". Never omit the section; write `None` in each bucket where there is nothing.
### Changed - details that differ from the plan
- what: why the plan was adjusted
### Added - implemented but absent from the plan
- what: why it was needed (when an Added item widened scope, cross-reference the matching **RF** by id here, do not duplicate its content)
### Deferred - planned but not implemented (deferred)
- what: why / what follow-up is needed

## Key Decisions
(Optional) Cross-cutting decisions not tied to a single TODO, e.g. choosing one library or pattern over another. Omit when individual TODO rationales already carry the reasoning.
- decision: why this approach over alternatives

## Deep Reading Order
(Optional. Include only for genuinely high-risk changes where the reviewer benefits from a foundation-first walk on top of the per-TODO sub-sections - not as a default.) foundation-first order: types & contracts -> core logic -> wiring -> tests.
1. `path:line` group - why this is read first
2. ...

## Manual Verification
(Optional. Lists checks the user must perform by hand - UI behavior, external side effects, data migrations, visual regressions - before trusting the change. Omit when there is nothing to verify manually.)
- [ ] What to check, where to check it, and the expected outcome
- [ ] ...

## Coverage
(Optional. Coverage summary when tooling is available. Omit when not measured.)
```

`## Red Flags`, `## Open Questions`, and `## Plan Divergence` are **never omitted** - write `None` (or an empty bucket line) when they are empty, because "nothing to flag / nothing deferred" is itself a signal the reviewer needs. Omit `## Key Decisions`, `## Deep Reading Order`, `## Manual Verification`, and `## Coverage` when the corresponding content does not apply.

Red deduplication rule: the **Added** bucket of `## Plan Divergence` is the primary record for "implemented but not in plan". Only when an Added item is risky on its own do you also add a Red Flag and cross-reference it from the Added line by id - never duplicate the same risk in both sections.