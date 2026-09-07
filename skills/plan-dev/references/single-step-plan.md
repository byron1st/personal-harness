# Single-step plan file

One markdown file describing the full implementation of a task — the default `plan-dev` mode, and the unit `implement-dev` executes.

Structure below is enforced. The body between the research links and the TODO checklist is **free-form**: do not force it into a fixed template (Goal / Technical Approach / Affected Files / Risks / …). When a planning agent produced the plan, copy its output **verbatim** — squeezing it into a normalized shape loses fidelity. That is not licence to keep mechanics-level detail; granularity still governs, so push line-level detail into research files or drop it.

## 1. File name

`{timestamp}_{Jira ticket number}_PLAN_{title}.md`

- `{timestamp}` — local time, `YYYYMMDDHHMMSS`.
- `{Jira ticket number}` — from the current branch via `[A-Z]+-[0-9]+`. If absent, ask, unless the user confirms `NO-JIRA`. **Shortcut**: when the SessionStart context says `repo_type: personal` and the branch has no Jira key, propose `NO-JIRA` as the default and skip the question.
- `{title}` — short, hyphenated, no spaces. e.g. `refactor-service-layer-to-resolve-cycle-dependencies`.

Example: `20260622153045_BLC-692_PLAN_refactor-service-layer.md`

## 2. Storage

`docs/agents/dev/` under the project root; create it if missing.

## 3. Frontmatter

```yaml
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
---
```

Required. Add other keys (`Tags`, `Status`) only when useful.

## 4. Research links

When research was created or consulted, list it at the top of the body, right after the H1. The executor starts cold, so each link carries three parts: the Markdown link, a one-line summary of **what current-code understanding** it captures, and the TODOs that should read it as `**TODO N·M**`. Omit the block entirely when there is no research.

```markdown
## 참고 Research
- [auth-flow](../research/auth-flow.md) — 로그인 요청의 현재 실행 경로(handler→service→repo).
  **TODO 2·3** 구현 전 참조.
- [module-dependencies](../research/module-dependencies.md) — service 계층의 현재 의존 방향.
  **TODO 5**의 대상 구조.
```

## 5. Direction anchors

`## Non-goals` and `## Key decisions` are **required unless the plan is trivial** — trivial meaning a single obvious change with no real alternative approach. They are what stops a cold executor from re-deriving a different direction under its own discretion:

- `## Non-goals` — what this change explicitly does *not* touch, so the executor does not rediscover the boundary by guessing.
- `## Key decisions` — the chosen approach, and where it matters the alternatives rejected and why, so a discarded path is not re-picked.

## 6. Acceptance Contract

The completion conditions agreed during the acceptance round. An independent evaluator — a reviewer, or `dev-loop` — judges the finished work against this with no memory of the planning session.

| ID | Observable condition | Evidence |
| --- | --- | --- |
| AC-1 | {an observable state a reviewer can check without asking the author} | {the work-specific proof: behavior, output, artifact} |

- IDs are `AC-N` from 1. An optional fourth column `Do not mark done if` names explicit disqualifiers.
- Work-specific outcomes only; generic gates stay out.
- Every TODO references the AC id(s) it fulfills.

## 7. Authority Boundaries

Bounds the discretion of whoever executes the plan:

- **Discretion** — what the executor decides alone: how-level mechanics.
- **Must-ask** — forbidden without user confirmation: direction changes (goal / approach / `## Key decisions` / `## Non-goals`), scope expansion, destructive or externally visible operations.
- **Stop conditions** — situations that halt work and go back to a human.
- **Loop budget** — maximum remediation rounds for a fix loop. Default `3`; override only here.
- **Per-TODO lines** — only where the plan-wide answer above is genuinely wrong for that item. This is the cheapest thing a plan gives an efficient executor: what it lacks is not detail but a sense of where its own authority ends.

```markdown
## Authority Boundaries
- Discretion: ...
- Must-ask: ...
- Stop conditions: ...
- Loop budget: 3
- TODO 2: 토큰 버킷의 자료구조·리필 주기는 로컬 판단. 저장소를 프로세스 메모리 밖으로 옮기는 선택은 escalate.
```

Do not restate the plan-wide bullets per TODO. A section that lists every TODO has stopped being a boundary and become a second TODO list.

## 8. TODO checklist

The plan ends with `## TODOs`, a checkbox list of **outcomes**, not keystroke-level edits. Name what to achieve and where, with enough direction that the approach is clear, then let the implementer resolve the mechanics.

- Outcome-level (good): `- [ ] Add rate-limiting to the public API layer (token-bucket per API key)`
- Edit-level (avoid): `- [ ] In ratelimit.go create a TokenBucket struct with fields capacity, tokens, refillRate and a Take() method`

Each item carries trailing tags:

- `(AC-N)` — the acceptance criteria it fulfills. This is how an evaluator maps TODOs to the contract without the planning session's memory.
- `(mechanical)` or `(design-bearing)` — `mechanical` when the *how* follows from the codebase or the alternatives are cheap to reverse; `design-bearing` when two approaches both fit the plan and picking wrong is expensive to undo. **Be stingy with `design-bearing`**: it is the sole gate on `implement-dev`'s `plan-consultant` hatch, which has no call cap, so how sparingly it is applied *is* the budget control. If most TODOs carry it, either the plan is under-decided or the tagging is loose.
- `(→ research: {file-stem})` — when the TODO should read a linked research file first. Pairs with the `**TODO N·M**` tags in section 4, so the executor reads research exactly once, for exactly the TODO that needs it.

```markdown
## TODOs
- [ ] Add rate-limiting to the public API layer (token-bucket per API key) (AC-1) (design-bearing) (→ research: rate-limit-capacity)
- [ ] Wire the limiter into the API entrypoints (AC-1, AC-2) (mechanical) (→ research: api-entrypoints)
- [ ] Update the docs page for rate limits (AC-3) (mechanical)
```

If an agent-generated plan already has its own task list, normalize it into this shape at the end of the body. The rest of its content stays where it was.

## 9. Skeleton

```markdown
---
Application: {Application}
JiraTicket: {Jira ticket number}
PlanType: single-step
Timestamp: {timestamp}
Title: {title}
---

# [Feature / Change Name]

<!-- §4 research links, when applicable -->

<!-- Free-form body. Agent-generated plans are copied verbatim. -->

<!-- §5 anchors — required unless the plan is trivial: -->
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
- [ ] Task 1 (AC-1) (mechanical)
- [ ] Task 2 (AC-1, AC-2) (design-bearing) (→ research: relevant-file)
```
