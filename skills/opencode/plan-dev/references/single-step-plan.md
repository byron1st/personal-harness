# Single-step plan file

A single-step plan is one markdown file describing the full implementation of a task. Use this format when `plan-dev` is operating in **single-step** mode (the default).

## What is enforced vs. flexible

**Enforced** (structural metadata + tracking hooks, not content shape):

- File name pattern (section 1)
- Storage location (section 2)
- Frontmatter fields (section 3)
- Body language: Korean
- Research file links at the top of the body when research files were created or consulted, in the strengthened format with per-TODO tags (section 4)
- A `## Acceptance Contract` table agreed with the user during planning (section 5)
- A `## Authority Boundaries` section bounding executor discretion and the loop budget (section 6)
- A `## TODOs` checkbox list at the end of the body for progress tracking (section 7); each item carries its `(AC-N)` reference(s), and when a TODO consults research, append the `(→ research: {file-stem})` hint
- `## Non-goals` and `## Key decisions` direction anchors, **required when the plan is non-trivial** (the cold-handoff anchors the Worker needs to not re-derive a different direction)

**Flexible**:

- Everything else inside the body. Do NOT force the plan into a fixed section template (Goal / Technical Approach / Affected Files / Risks / Tradeoffs / Verification / ...). When the plan was produced by a planning agent, copy its output **verbatim** into the body between the research links and the TODO checklist. Squeezing a rich agent-generated plan into a normalized template loses fidelity; preserve it as-is.
- The verbatim rule preserves the agent's structure and reasoning; it is not a license to keep mechanics-level detail. Plan granularity (see SKILL.md) still governs: keep the direction, and push line-level edits / code sketches down into research files or drop them.

Two body elements bound a coarse plan's implementer discretion cheaply - both are information `implement-dev` cannot recover from environment feedback and, because **delegation is the default** (the implementer is a fresh subagent with no memory of this planning session), they are the **cold-handoff anchors that stop the Worker from re-deriving a different direction**:

- `## Non-goals` - what this change explicitly does *not* touch. A Worker that re-derives the scope will re-discover these by guessing; write the exclusion here.
- `## Key decisions` - the chosen approach and, where it matters, the alternatives you rejected and why (so the Worker does not re-pick a discarded path under its own discretion).

These are **required when the plan is non-trivial**. Omit either only when the plan is trivial enough that a Worker cannot plausibly misread the direction from the plan body alone. Trivial = a single obvious change with no real alternative approach.

## 1. File name

`{timestamp}_{Jira ticket number}_PLAN_{title}.md`

- `{timestamp}` - local time in `YYYYMMDDHHMMSS` format.
- `{Jira ticket number}` - extract from the current branch name using the regex `[A-Z]+-[0-9]+`. If it cannot be extracted, ask the user unless they explicitly confirm `NO-JIRA`. **Session-context shortcut**: when the injected session context classifies this repo as personal (`repo_type: personal`) and the branch carries no Jira key, propose `NO-JIRA` as the default — the confirmation question may be skipped.
- `{title}` - short, concise, hyphen-separated description. No spaces. Example: `refactor-service-layer-to-resolve-cycle-dependencies`.

Example: `20260622153045_BLC-692_PLAN_refactor-service-layer.md`.

## 2. Storage location

Always store the file in `docs/agents/dev/` under the project root. Create the directory if it does not exist.

## 3. Required frontmatter

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
---
```

These keys are required. Add other keys (e.g., `Tags`, `Status`) only when useful.

## 4. Research file links (strengthened)

When research files were created or consulted during planning, list them at the top of the body, immediately after the H1 heading. The Worker (`implement-dev`) starts cold - no memory of the planning session - so each link must carry enough context for it to pick the right research files for the right TODOs without re-exploring. Each link is one bullet with three parts:

1. the Markdown link to the file,
2. a one-line summary of **what current-code understanding** that research captures (the *why* exists; it is an anchor, not a duplicate of the body),
3. the TODOs that should consult it, as `**TODO N·M**`.

If no research files exist, omit this block entirely.

```markdown
## 참고 Research
- [auth-flow](../research/auth-flow.md) — 로그인 요청의 현재 실행 경로(handler→service→repo).
  **TODO 2·3** 구현 전 참조.
- [module-dependencies](../research/module-dependencies.md) — service 계층의 현재 의존 방향.
  **TODO 5**의 대상 구조.
```

## 5. Acceptance Contract

Every plan carries a `## Acceptance Contract` section: the completion conditions agreed with the user during `plan-dev`'s acceptance round. It is the contract an independent evaluator (a reviewer, or a loop controller such as `dev-loop`) judges the finished work against, with no memory of the planning session.

| ID | Observable condition | Evidence |
| --- | --- | --- |
| AC-1 | {an observable state a reviewer can check without asking the author} | {the work-specific proof: behavior, output, artifact} |

- IDs are `AC-N`, numbered from 1.
- An optional fourth column `Do not mark done if` names explicit disqualifiers for a row.
- Record only work-specific outcomes and evidence the repository cannot announce on its own. Generic lint/unit/e2e/build gates are rediscovered by `implement-dev` at implementation time and are never copied here.
- Every `## TODOs` item references the AC id(s) it fulfills as `(AC-N)` (section 7).

## 6. Authority Boundaries

Every plan carries a `## Authority Boundaries` section bounding the discretion of whoever executes the plan (implementer or loop controller):

- **Discretion** - what the executor decides alone: how-level mechanics, per Plan granularity.
- **Must-ask** - changes forbidden without user confirmation: direction changes (goal / approach / `## Key decisions` / `## Non-goals`), scope expansion, destructive or externally visible operations.
- **Stop conditions** - situations that halt work immediately and go back to a human.
- **Loop budget** - the maximum remediation rounds a fix loop may run over this plan. Default `3`; override only in this section.

## 7. TODO checklist

Every plan ends with a `## TODOs` section: a checkbox list of tasks. Each item is an **outcome** the implementer owns, not a keystroke-level edit: name what to achieve and where, with enough direction that `implement-dev` knows the approach, then let it resolve the mechanics itself (TDD-first). Aim for outcome-level, not edit-level:

- Outcome-level (good): `- [ ] Add rate-limiting to the public API layer (token-bucket per API key)`
- Edit-level (avoid): `- [ ] In ratelimit.go create a TokenBucket struct with fields capacity, tokens, refillRate and a Take() method`

The second bakes in mechanics the implementer should decide against the running code, and inflates the plan past the point a human will actually review it. This pairs with `implement-dev`, which ticks each box as it completes a task.

**AC reference**: every item names the acceptance criteria it fulfills as a trailing `(AC-N)` (or `(AC-N, AC-M)`). This is how an evaluator maps completed TODOs to the `## Acceptance Contract` (section 5) without the planning session's memory.

**Research hint**: when a TODO should consult a linked research file before being implemented, append `(→ research: {file-stem})` to the end of the item. This pairs with section 4's `**TODO N·M**` tagging - bidirectional, so the Worker reads research exactly once and exactly for the TODO that needs it, with no guesswork. Keep the hint terse; do not paraphrase the research in the TODO line.

```markdown
## TODOs
- [ ] Add rate-limiting to the public API layer (token-bucket per API key) (AC-1) (→ research: rate-limit-capacity)
- [ ] Wire the limiter into the API entrypoints (AC-1, AC-2) (→ research: api-entrypoints)
- [ ] Update the docs page for rate limits (AC-3)
```

If the agent-generated plan already contains its own task list, normalize it into this section's checkbox format and place it at the end. The rest of its content stays where it was.

## 8. File skeleton

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
---

# [Feature / Change Name]

<!-- Section 4: research file links (strengthened), when applicable -->

<!-- Agent-generated plan body, copied verbatim. Keep whatever sections / ordering the agent produced. -->

<!-- Direction anchors - required when non-trivial, omitted only when the plan is truly trivial: -->
<!-- ## Non-goals -->
<!-- ## Key decisions -->

## Acceptance Contract
| ID | Observable condition | Evidence |
| --- | --- | --- |
| AC-1 | ... | ... |

## Authority Boundaries
- Discretion: ...
- Must-ask: ...
- Stop conditions: ...
- Loop budget: 3

## TODOs
- [ ] Task 1 (AC-1)
- [ ] Task 2 (AC-1, AC-2)  (→ research: relevant-file)
```
