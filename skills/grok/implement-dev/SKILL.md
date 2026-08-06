---
name: implement-dev
description: "Execute a plan-dev implementation plan with TDD, verification, TODO updates, and repository-local implementation reports under docs/agents. By default runs as the Dispatcher (main session): it launches one Worker subagent that owns the actual code/test/report edits and returns a fixed-heading status the Dispatcher collapses to a short chat summary. If dispatch fails, it requires an explicit decision before direct fallback. Use when the user asks to implement a saved plan."
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report under `docs/agents/dev`.

## Required language convention gate

Complete this gate during Prepare **before writing a Red test, production code, or completing a TODO**. It is a hard prerequisite, not a suggested resource lookup.

1. Determine every language/framework involved in the plan's TODOs and the files expected to change. If that is unclear, inspect the plan and repository before proceeding.
2. Open and read the **entire contents** of every matching convention file in the table below. Seeing its link, title, or table row does not count as reading it.
3. For a multi-language change, read **all** matching files; do not select only a primary language. Read the file again even if it was consulted during an earlier task or session.
4. If a matching convention file is missing or inaccessible, continue without it. Apply the most widely adopted de facto standard known for that language/framework, and record the fallback in the completion report's `## Summary`.

| Language / framework | Read when | Required convention file |
| --- | --- | --- |
| Go | The plan or changed files involve Go code. | [references/go-convention.md](references/go-convention.md) |
| Swift / macOS | The plan or changed files involve Swift, SwiftUI, AppKit, or macOS app code. | [references/swift-convention.md](references/swift-convention.md) |
| TypeScript / Next.js | The plan or changed files involve TypeScript, React, or Next.js code. | [references/ts-nextjs-convention.md](references/ts-nextjs-convention.md) |

Repository `AGENTS.md` / `CLAUDE.md` instructions override bundled defaults, but they do not replace this required read. Record every convention file consulted and any de facto fallback used in the completion report's `## Summary`.

## Execution modes

`implement-dev` runs in one of two delegated modes, detected from the invoking prompt (the **worker signal**):

- **Dispatcher (default, main session)** - The session that is *not* told it is the Worker. The Dispatcher does **not** edit production code, tests, or the report itself; it launches exactly **one** `implementer` subagent (the Worker, `subagent_type: implementer`) using the prompt, return schema, and chat-summary shape in [references/worker-contract.md](references/worker-contract.md), then parses the Worker's fixed-heading return and renders a short chat summary (what changed / verification / red flags / TODO status) plus a clickable link to the on-disk report. The Dispatcher does not re-dispatch another Worker once one is running.
- **Worker (delegation, subagent)** - A session invoked with `You are running as the implementation Worker subagent.` in its prompt. It runs the implementation flow directly ([references/implement-flow.md](references/implement-flow.md)), does not re-dispatch, and returns the fixed-heading Markdown from [references/worker-contract.md](references/worker-contract.md).

**Delegation failure gate:** if the `spawn_subagent` tool or compatible Worker capability is unavailable, or dispatch fails, stop before substantive implementation. Report `Delegation status: unavailable` or `failed`, include the observed cause, and use `ask_user_question` to ask whether to continue with direct main-session execution or stop. Never enter the interactive flow silently. Direct execution is allowed only when the user explicitly chooses it; then the implementation flow ([references/implement-flow.md](references/implement-flow.md)) runs in-place with the Worker rules and the main-session routing for direction-level conflicts.

## Rules

The rules that bind whoever edits the code - TDD Red-Green-Refactor, flipping each plan checkbox the moment its item completes, and the deviation buckets (detail-level / consultable / direction-level) with their per-mode escalation routing - live in [references/implement-flow.md](references/implement-flow.md). Two points belong here instead:

- **Direction-level escalation is not the Error Recovery escalation.** A direction-level conflict - the plan's goal, chosen approach, key decisions, or non-goals turn out wrong or unworkable - **stops work before code is written for it**, because changing direction silently voids the review the plan received. The stuck-after-3-attempts rule below fires when you are technically blocked; this one fires when the plan's direction is wrong even though the code would compile.
- **The Dispatcher never makes direction decisions for the Worker.** If the Worker returns `blocked`, the Dispatcher surfaces `## Decision Needed` to the user and stops - it does not retry or self-decide.

## Prepare

1. **Plan file**: the user (Dispatcher) or the dispatch prompt (Worker) provides the plan path. If the prompt omits it, ask.
2. **Verification commands**: run `$HOME/.grok/scripts/detect-commands.sh` for the declared ones — it reads `Makefile` targets and `package.json` scripts and returns JSON, deterministically and without inference. Fill in whatever it returns `null` for by reading `AGENTS.md`, `CLAUDE.md`, or `README.md` prose. If a command still cannot be found, ask the user (interactive) or surface in `## Open Questions` / `## Decision Needed` (Worker). **The Dispatcher does this once and passes the result in the dispatch prompt** — otherwise every Worker rediscovers the same commands cold, every round.
3. **Project conventions**: read `AGENTS.md` / `CLAUDE.md`; their constraints apply to every implementation decision. Treat bundled conventions as defaults only where the repository's own instructions and existing code are silent.
4. **Language conventions**: complete the [required language convention gate](#required-language-convention-gate). Do not advance from Prepare until every matching convention file has been read.

## Execute

Follow [references/implement-flow.md](references/implement-flow.md): read the plan and the research it links, implement its `## TODOs` test-first, run final verification, refresh project docs, and write the completion report.

## Report

The implementation produces three artifacts, defined in [references/report-file.md](references/report-file.md) (①) and [references/worker-contract.md](references/worker-contract.md) (②, ③):

- **① Report file** - the on-disk body under `docs/agents/dev/`, spine `## TODO Fulfillment`. File naming, content format, and the bidirectional plan/report Markdown link convention are in [references/report-file.md](references/report-file.md).
- **② Worker return** - the fixed-heading Markdown the Worker hands back to the Dispatcher. Never paste ① sections into ② - link the report by absolute path under `## Implementation Report`.
- **③ Chat summary** - the Dispatcher renders a short summary (2-4 bullets + clickable report link) for the user, never pasting ① or ② verbatim.

In explicitly authorized direct execution, the same shape applies as the final chat output: short bullets + report link, with report sections kept in the file.

## Error Recovery

When verification fails:

1. **Read the error carefully** - understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** - if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** - do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** - if you notice a failure mid-work, fix it before moving on. Do not accumulate failures.
5. **Stop after 3 failed attempts on the same error** - describe what you tried and what you observed. In interactive mode, ask the user for guidance; in Worker mode, set `## Stage Status` to `failed` and return.

A Worker `failed` return does not end the stage on its own: the Dispatcher re-dispatches **once** with the same `implementer` persona (Grok has no higher model tier; no cascade to a different model)

## Completion

- All plan TODO checkboxes are up to date.
- Every AC in the plan's `## Acceptance Contract` has its work-specific evidence collected and recorded (report `AC:` lines + return `## Evidence`) - an unproven AC blocks `pass`. Legacy plans without an `## Acceptance Contract` are not refused; they take the fallback in [references/implement-flow.md](references/implement-flow.md) step 3.
- The completion report (①) is saved under `docs/agents/dev`, and the plan/report Markdown links are bidirectional.
- If running as a Worker, the return message ② uses the fixed headings and links ① by absolute path.
- The completion report's `## Summary` records every language-specific convention file consulted and any de facto fallback used, or states that no table mapping applied.
- `AGENTS.md` / `CLAUDE.md` / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.


## Grok Build: design-bearing escalation (depth 1)

Grok Build only allows the **top-level session** to spawn subagents. The implementer Worker **must not** call `spawn_subagent` for `plan-consultant`.

When the Worker returns:

```
## Stage Status
status: needs-design-decision
```

the **Dispatcher (this main session)** must:

1. Spawn `plan-consultant` with `capability_mode: read-only` (and the decision brief from the Worker).
2. Collect the short decision.
3. Re-dispatch `implementer` (new spawn or `resume_from` if available) with the decision embedded in the prompt.
4. Continue until a terminal status other than `needs-design-decision`.

Do not treat `needs-design-decision` as `blocked` (user direction conflict) or as a free pass for the main session to implement.

There is **no T1 model cascade** on Grok Build (single model `grok-4.5`). On Worker `failed`, follow the skill's existing retry/escalation text without escalating `model:` to another family; the implementer stays `effort: medium`.

