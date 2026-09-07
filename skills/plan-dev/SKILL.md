---
name: plan-dev
description: Create an implementation plan in plan mode and persist plan/research artifacts under docs/agents after approval. Use when the user wants to plan before coding; single-step by default, multi-step only on explicit request.
---

# Plan Dev

Refine an implementation plan entirely inside plan mode, then persist it under `docs/agents` the moment plan mode ends.

The main session runs the interview. When the work is ambiguous, cross-cutting, or architecture-sensitive, start the read-only `planner` persona — before drafting, for an architecture view plus the high-impact questions to put to the user, and again on the draft for a fit-and-over-planning pass. A persona cannot talk to the user, so every question it raises comes back through this session. Skip both for trivial work.

## Plan-mode protocol

Everything up to approval is **read-only**: reads, searches, questions, the `planner` persona. No writes to the working tree or `docs/agents`.

Present the finished plan and wait for the host's own approval flow — do not call a host-specific plan-exit tool.

The **first writes after approval** are the persistence step, in this order: research files (with their index) → plan file(s). Only then does any other follow-up begin.

## Language

Plan and research **file content is always Korean**, whatever the conversation language. Frontmatter keys and section titles may be English; library names, commands, paths, and code stay English. Conversation follows the user's language.

## Artifacts

| Artifact | Path | Format |
| --- | --- | --- |
| Plan | `docs/agents/dev/{timestamp}_{Jira}_PLAN_{title}.md` | [single-step-plan.md](references/single-step-plan.md) |
| Sub-plan (multi-steps) | same stem + `-STEP-{N}` | [multi-steps-plan.md](references/multi-steps-plan.md) |
| Research | `docs/agents/research/{title}.md` | [research-file.md](references/research-file.md) |
| Research index | `docs/agents/research/index.md` | same |

Implementation reports (`_IMPL_`) and loop state (`_LOOP_`) reuse the plan's stem; they are written later by `implement-dev` and `dev-loop`.

## Granularity — the plan is direction, not a build script

The executor is an `implement-dev` session with **no memory of this planning session**. That cuts both ways, and getting the altitude wrong in either direction is the main way a plan fails.

- **Coarse — leave to the implementer**: line-level edits, code sketches, helper signatures, pre-enumerated edge cases, library quirks. These are cheaper and more correct to settle against running code than to guess at in plan mode. Over-specifying them also makes the plan too long for a human to actually review, and degrades how reliably an executor follows any *single* instruction.
- **Sharp — specify precisely**: the goal, the chosen approach and why, module boundaries, non-goals, and for multi-steps the contract between steps. The implementer cannot recover any of this from environment feedback; if it is wrong or missing, the result is a direction error the executor cannot self-correct.

Generic verification commands (lint / test / build) never go in the plan — `implement-dev` rediscovers them from `Makefile` / `AGENTS.md` / `README.md`, where they cannot drift. The `## Acceptance Contract` records only work-specific outcomes.

Investigate deeply, but put the findings in **research files**. Research holds the depth; the plan holds the direction distilled from it.

## Modes

- **single-step** (default) — one plan file. Features, refactors, bug fixes, small-to-medium work.
- **multi-steps** (explicit opt-in only) — a main plan plus `-STEP-N` sub-plans, each a complete single-step plan run on its own. Triggered by an explicit ask: "여러 단계로 나눠서", "multi-step plan", "단계별로", "증분 개발". Typical for new projects and large initiatives.

If the signal is ambiguous, ask once; otherwise proceed single-step. State the decided mode in one sentence.

## Process

Interview the user toward a plan the way any careful collaborator would. Six things about it are specific to this harness:

1. **When a SPEC.md is the input** (typically from `spec-creator`), mine it before planning: its `## Open Questions` and inline `[ASSUMED]` markers are unresolved decisions someone deliberately deferred to this moment. Surface them grouped by how much they block — cannot plan without an answer / can plan around but the plan may change / proceed on the stated assumption. Its numbered `FR-N` requirements are also the natural decomposition units for a multi-steps breakdown.
2. **Consult `docs/agents/research/index.md` first** when the repo has existing code — it carries each research file's metadata, so you can open only what is relevant instead of reading them all. A missing index means existing research is unavailable for this run; do not rebuild it unless asked. Skip research entirely for an empty or scaffold-only repository.
3. **Settle acceptance before designing how.** For each outcome the plan will deliver, agree with the user on: the **observable completion state** a reviewer can check without asking the author; the **work-specific evidence** for it (generic gates stay out); and the **acceptable risk** — what is deliberately not verified, named now rather than discovered later. This becomes the `## Acceptance Contract`, and approving the plan approves those criteria along with the approach. Scale it to the work — one confirmation question for a trivial task.
4. **Draft everything in memory**, research included. Nothing is written until after approval.
5. **Check the cold hand-off before presenting.** Given only this plan and its linked research, can the executor recover the direction without re-deriving it, and pick the right research for each TODO? Given only the plan and its `## Acceptance Contract`, could an independent evaluator decide pass/fail? While either answer is "no", strengthen the research links, thicken `## Non-goals` / `## Key decisions`, or sharpen the contract — do not present it for approval.
6. **Persist in order** once approval lands: research files and their index first, then the plan file(s). For multi-steps, verify each main-plan link resolves to a sub-plan you actually wrote.

Then report the paths and continue with whatever the user asks next.
