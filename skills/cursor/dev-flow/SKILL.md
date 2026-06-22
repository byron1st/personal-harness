---
name: dev-flow
description: Run an existing plan-dev plan end-to-end through delegated Cursor subagents for implement-dev, test-dev, and review-code. Use for explicit orchestration, delegation, or subagent requests.
---

# Dev Flow

Orchestrate an already-written `plan-dev` plan through three serial delegated stages: `implement-dev`, `test-dev`, then `review-code`. Keep this skill thin: delegate the real implementation, test hardening, and review work to those existing skills instead of restating their workflows here.

## Input

Require one input: the path to an existing `plan-dev` plan file. If the user omits the plan path, ask once for the path and stop until they provide it.

## Main-Session Role

Act only as the orchestrator:

1. Resolve the plan path to an absolute path, confirm it exists, and identify the repository root.
2. Spawn one implementation stage subagent via the Task tool and instruct it to use `implement-dev` on the plan path.
3. Wait for the implementation stage subagent to finish and parse its structured summary.
4. Spawn one test-hardening stage subagent via the Task tool and instruct it to use `test-dev`, scoped to the implementation output.
5. Wait for the test stage subagent to finish and parse its structured summary.
6. Spawn one review stage subagent via the Task tool and instruct it to use `review-code` with delegated reviewer subagents against the final diff.
7. Wait for the review stage subagent to finish and parse its structured summary.
8. Render the final flow summary in the chat using the delegation contract's output schema.
9. Return a concise final answer with the final status.

Do not edit production code, tests, or implementation reports directly from the main session.

## Delegation Contract

Use the exact stage prompt templates and final chat output schema in [references/delegation-contract.md](references/delegation-contract.md). Each subagent must be explicitly told which skill to use and must return the required machine-readable headings.

If a subagent returns an incomplete structure, request the missing headings from that same subagent once. If the structure is still missing or ambiguous, mark that stage `failed`, show a partial flow summary in chat, and stop according to the failure policy.

## Stage Order

Run stages serially:

- Start `test-dev` only after `implement-dev` returns `pass`.
- Start `review-code` only after `test-dev` returns `pass` or `pass-with-suspected-defects`.
- Do not run implementation, test hardening, and review in parallel.

## Failure Policy

- If the plan path is missing, ask for it and do nothing else.
- If the plan file does not exist, report `failed` and do not spawn subagents.
- If implementation returns `blocked` or `failed`, stop before `test-dev` and show a partial flow summary in chat.
- If test hardening returns `blocked` or `failed`, stop before `review-code` and show a blocked or failed flow summary in chat.
- If test hardening returns `pass-with-suspected-defects`, continue to review but mark the final status `blocked`.
- If review returns `blocked`, `failed`, `incorrect`, `Overall Correctness: Incorrect`, or any `[CRITICAL]` or `[HIGH]` finding, mark the final status `blocked` unless the review stage itself failed, in which case mark it `failed`.
- If all stages pass and review overall correctness is `Correct`, mark the final status `ready-for-user-review`.

## Output Rules

Show the final flow summary directly in chat using the schema in the delegation contract. Keep summaries short and navigable; do not paste full subagent transcripts unless a short excerpt is required to explain a blocked or failed status. Do not write an orchestration report file.

Use `fix-dev` as the recommended next skill when the final status is `blocked` because of suspected business-logic defects or blocking review findings.
