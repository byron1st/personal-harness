# Loop state file (LOOP)

The checkpoint file `dev-loop` appends to after every stage return. It is a **checkpoint, not a second report**: minimum fields only. Never copy raw conversation, full diffs, or test output into it — the IMPL report, the plan, and git already carry those. Body language follows the repo convention (Korean prose, English labels).

## 1. File name and location

`docs/agents/dev/{timestamp}_{Jira}_LOOP_{title}.md` — the plan's stem with `_PLAN_` replaced by `_LOOP_`. A `-STEP-N` sub-plan keeps its suffix: `{timestamp}_{Jira}_LOOP_{title}-STEP-N.md`. Reuse the plan's actual timestamp so plan / IMPL / LOOP stay trivially linkable; never mint a fresh one.

## 2. Frontmatter

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
Timestamp: {plan timestamp — shared stem, not a fresh one}
Title: {title}
Plan: {plan filename}
Report: {IMPL filename, or "none" until implement-dev writes it}
Mode: light | full | noreview
Started: {YYYY-MM-DD HH:MM}
---
```

`Mode:` is the run's frozen mode, written at creation. Update `Report:` exactly once, when the IMPL report appears. Everything else in frontmatter is immutable after creation.

## 3. Round log (append-only)

One `## Round N` section per round. **Round 0** is the initial IMPLEMENTING → TESTING → REVIEWING pass (`light` / `full`) or IMPLEMENTING → TESTING (`noreview`); each remediation cycle is the next round number. Prior round sections are **never edited**; the current round's section gains one line per stage return, appended immediately after that stage returns (checkpoint before transition). `noreview` never logs a `review-code` stage line.

```markdown
## Round 0 — started {YYYY-MM-DD HH:MM}
- implement-dev: pass
- AC evidence: AC-1 ✓, AC-2 ✓
- test-dev: pass (mutation: skipped — no tooling, approved in Decision)
- review-code: needs-decision
- Findings: REVIEW-001 HIGH → Fix (user), REVIEW-002 HIGH → Accept (user, AR-004)
- Applied AR: none
- Fixes: none
- Next: FIXING (REVIEW-001)
- Stop reason: none
```

Fields (append only lines that have content, except the required ones which write `none`):

| Field | Required | Content |
| --- | --- | --- |
| stage lines | one per executed stage | `{skill}: {Stage Status}` + at most one short clause of context |
| `AC evidence` | yes | per-AC `✓`/`✗` as of this round's latest evidence |
| `Findings` | yes | open finding ids (`REVIEW-NNN` / `TEST-NNN`) + classification (`Fix` / `Accept` / `unclassified`), or `none`. Both gates use the same vocabulary; an `Accept` carries the AR id it produced |
| `Applied AR` | yes | AR ids waived in this round's review, or `none` |
| `Fixes` | yes | `finding id → fix-dev Stage Status`, or `none` |
| `Next` | yes | the next state, or `DONE` |
| `Stop reason` | yes | why the loop stopped here (gate, abort, budget), or `none` |

## 4. Final entry

When the loop ends — READY_TO_COMMIT or an abort — append a `## Result` section: final state, the Mode that ran, the 9-item termination-predicate summary (`①…⑨` each `✓`/`✗`), Markdown links to the plan and IMPL report, and for aborts the escalation reason. This is the section a resumed session or the human reads first.

## 5. Resume

On invocation with an existing LOOP file: **trust the file over memory**. Continue from the last round's `Next` in the file's `Mode:`. Never rewrite history — corrections happen by appending. If the working tree contradicts what the rounds imply (e.g. expected changes missing), stop and surface the mismatch instead of guessing.

- File has `Mode:` and the new utterance names a different mode → refuse and ask; do not switch.
- File has no `Mode:` (legacy) → ask which mode this resume is; do not default to `light`.
