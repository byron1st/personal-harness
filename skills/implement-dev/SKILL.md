---
name: implement-dev
description: Execute a plan-dev implementation plan with TDD, verification, TODO updates, and repository-local implementation reports under docs/agents. Use when the user asks to implement a saved plan.
---

# Implement Dev

Execute an implementation plan by writing code test-first, validating via automated checks, keeping the plan's TODOs current, and producing a completion report under `docs/agents/dev`.

This skill is methodology. It does not start a persona. Standalone (`/implement-dev`, no loop): the current session runs this flow in place. Under `dev-loop`: the loop starts the `implementer` persona, and that persona follows this skill.

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

## Who runs this

- **Standalone** — the current session is the executor. Ask the user when a decision is needed. Do not start a persona.
- **Loop** — the `implementer` persona is the executor. It cannot ask the user. It returns a Stage Status; the loop handles gates, `plan-consultant`, and retries.

The executor follows the methodology and returns the fixed headings in [references/worker-contract.md](references/worker-contract.md).

## Rules

The rules that bind whoever edits the code - TDD Red-Green-Refactor, flipping each plan checkbox the moment its item completes, and the deviation buckets (detail-level / consultable / direction-level) with their per-mode escalation routing - live in [references/implement-flow.md](references/implement-flow.md). Two points belong here instead:

- **Direction-level escalation is not the Error Recovery escalation.** A direction-level conflict - the plan's goal, chosen approach, key decisions, or non-goals turn out wrong or unworkable - **stops work before code is written for it**, because changing direction silently voids the review the plan received. The stuck-after-3-attempts rule below fires when you are technically blocked; this one fires when the plan's direction is wrong even though the code would compile. Direction conflicts return `blocked`. They are not `needs-design-decision`.
- **The executor never makes direction decisions silently.** If the conflict is direction-level, standalone asks the user; a loop executor returns `blocked` with `## Decision Needed` and stops. Neither retries nor self-decides.

## Prepare

1. **Plan file**: the user or the caller brief provides the plan path. If it is omitted, ask (standalone) or return `blocked` with `## Decision Needed` (loop executor).
2. **Verification commands**: if the caller brief already lists resolved commands, use those and re-derive only values marked `none`. Otherwise run `$HOME/.agents/scripts/detect-commands.sh` — it reads `Makefile` targets and `package.json` scripts and returns JSON, deterministically and without inference. Fill in whatever it returns `null` for by reading `AGENTS.md`, `CLAUDE.md`, or `README.md` prose. If a command still cannot be found, ask the user (standalone) or surface in `## Open Questions` / `## Decision Needed` (loop executor). The loop runs this script once at preflight and passes the result in the brief so the executor does not rediscover the same commands cold every round.
3. **Project conventions**: read `AGENTS.md` / `CLAUDE.md`; their constraints apply to every implementation decision. Treat bundled conventions as defaults only where the repository's own instructions and existing code are silent.
4. **Language conventions**: complete the [required language convention gate](#required-language-convention-gate). Do not advance from Prepare until every matching convention file has been read.

## Execute

Follow [references/implement-flow.md](references/implement-flow.md): read the plan and the research it links, implement its `## TODOs` test-first, run final verification, refresh project docs, and write the completion report.

## Report

The implementation produces three artifacts, defined in [references/report-file.md](references/report-file.md) (①) and [references/worker-contract.md](references/worker-contract.md) (②, ③):

- **① Report file** - the on-disk body under `docs/agents/dev/`, spine `## TODO Fulfillment`. File naming, content format, and the bidirectional plan/report Markdown link convention are in [references/report-file.md](references/report-file.md).
- **② Executor return** - the fixed-heading Markdown the executor hands back. Never paste ① sections into ② - link the report by absolute path under `## Implementation Report`.
- **③ Chat summary** - the caller (standalone session, or the loop collapsing the return) renders a short summary (2-4 bullets + clickable report link) for the user, never pasting ① or ② verbatim.

Standalone uses ③ as the final chat output: short bullets + report link, with report sections kept in the file.

## Error Recovery

When verification fails:

1. **Read the error carefully** - understand the root cause before changing anything. No guess-and-retry.
2. **Fix production code first** - if a test fails, the bug is likely in the implementation, not the test. Only adjust the test if the expectation itself is wrong.
3. **Never weaken tests to pass** - do not remove assertions, loosen checks, or skip tests.
4. **Fix immediately** - if you notice a failure mid-work, fix it before moving on. Do not accumulate failures.
5. **Stop after 3 failed attempts on the same error** - describe what you tried and what you observed. Standalone: ask the user for guidance. Loop executor: set `## Stage Status` to `failed` and return.

This skill does not retry `failed` under a different model. The loop may start the same persona once more; that retry is the loop's, not this skill's.

## Completion

- All plan TODO checkboxes are up to date.
- Every AC in the plan's `## Acceptance Contract` has its work-specific evidence collected and recorded (report `AC:` lines + return `## Evidence`) - an unproven AC blocks `pass`. Legacy plans without an `## Acceptance Contract` are not refused; they take the fallback in [references/implement-flow.md](references/implement-flow.md) step 3.
- The completion report (①) is saved under `docs/agents/dev`, and the plan/report Markdown links are bidirectional.
- The executor return ② uses the fixed headings and links ① by absolute path.
- The completion report's `## Summary` records every language-specific convention file consulted and any de facto fallback used, or states that no table mapping applied.
- `AGENTS.md` / `CLAUDE.md` / `README.md` have been reviewed for staleness caused by the change; update content while preserving the existing section structure.
