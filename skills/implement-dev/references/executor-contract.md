# Executor contract

The caller brief and return schema for `implement-dev`. Update them here; do not duplicate them elsewhere.

## A. Caller brief

The loop (or standalone Prepare) fills this. It carries only what the executor cannot derive on its own — the skill itself supplies the rules, so do not restate them here.

```text
Use the `implement-dev` skill to execute this plan: {PLAN_PATH}

You operate cold — a fresh session with no memory of the planning run.

Verification commands (already resolved; re-derive only the ones marked `none`):
- lint: {LINT_CMD or none}
- format: {FORMAT_CMD or none}
- test: {TEST_CMD or none}
- build: {BUILD_CMD or none}

Do not start another persona. Do not run `test-dev` or `review-code`. Do not revert edits made by others.

Return only the fixed-heading Markdown in section B of `references/executor-contract.md`.
```

When a value is missing from the brief, the executor may run `$HOME/.agents/scripts/detect-commands.sh` itself.

## B. Executor return message (②)

Fixed `##` headings, Markdown. The caller parses these headings by name, so emit them **exactly** — never invent or rename one, and never drop one. Anything empty becomes `none`.

```markdown
## Stage Status
pass | blocked | failed | needs-design-decision

## Evidence
{one line per AC from the plan's `## Acceptance Contract`: "AC-N: {work-specific proof - command/observation and its result}"}

## Decision Needed
{only when status is blocked: the direction conflict + the choices the user must pick between. Otherwise "none"}

## Design Decision Needed
{only when status is needs-design-decision: TODO id and title; options A | B; why the wrong pick is expensive to reverse. Otherwise "none"}

## TODO Status
- TODO1: done
- TODO2: done
- TODO4: blocked - {one-line decision needed}

## Implementation Report
{absolute path, or "none"}

## Changed Files
{one absolute path per line, or "none"}

## Verification
{commands run}: {pass/fail}

## Red Flags
{bullets, or "none"}

## Open Questions
{bullets, or "none"}
```

`## Stage Status` / `## Evidence` / `## Decision Needed` are the **common stage block** shared across executor-returning skills. `## Evidence` carries AC-specific proof only — generic gate results stay under `## Verification`.

| Status | Means |
| --- | --- |
| `pass` | Every TODO fulfilled, verification green, every AC evidenced |
| `blocked` | At least one TODO hit a direction-level conflict; no code was written past it. Detail-level obstacles are not blockers |
| `failed` | Verification failed irrecoverably after 3 attempts on the same error, or an unexpected hard error |
| `needs-design-decision` | A `(design-bearing)` TODO needs a `plan-consultant` decision the executor did not make. Not `blocked`; does not consume loop budget |

## C. Caller chat summary (③)

After ② arrives, the caller renders 2-4 bullets — what changed, verification status, red-flag and open-question gist, TODO completion at a glance ("7개 중 6개 완료, TODO4 blocked") — plus a clickable Markdown link to the ① report. Not ② verbatim, not ①'s sections verbatim.

`blocked` surfaces `## Decision Needed` first and stops. `needs-design-decision` goes to `plan-consultant` (loop) or the user (standalone).

## D. Boundary

This contract covers implementation only. `test-dev` and `review-code` keep their own. Spawn failure, the same-persona `failed` retry, and starting `plan-consultant` belong to `dev-loop` or the standalone user, not to this skill.
