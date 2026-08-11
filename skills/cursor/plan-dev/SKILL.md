---
name: plan-dev
description: Create an implementation plan in Cursor plan mode, present the final plan for the user's approval, and persist plan/research artifacts under docs/agents after approval. Use when the user wants to plan before coding; single-step by default, multi-step only on explicit request.
---

# Plan Dev

Create an implementation plan through iterative refinement entirely inside Cursor plan mode, then persist the result as markdown file(s) under the project root's `docs/agents` directory as the very first action once the approved plan returns control to write-capable execution.

## Why this skill exists

Cursor plan mode keeps the agent exploring rather than implementing while it researches and proposes changes. That gate is valuable because the user reads the plan before any side effect happens. The planning workflow still produces durable artifacts: plan documents and research notes. `plan-dev` keeps planning read-only, then writes those artifacts into the repository-local `docs/agents` tree immediately after plan mode ends.

## Compatibility with plan mode

Steps 1-10 below MUST run with read-only tools only (file reads, search, `AskQuestion`, dispatching the read-only `planner` agent, and other read-only queries). No writes to `docs/agents` or the working tree happen during this phase.

When the final plan is ready, present it and wait for the user's approval through Cursor's own plan flow. **There is no plan-exit tool to call** — approval is the user switching the conversation out of plan mode, so never claim the plan is approved on your own reading of the conversation.

The first tool calls after the user has approved the plan and writes are allowed MUST be the persistence steps in step 12, in this exact order: research files -> plan file(s). Only after those writes are done may any further follow-up work begin.

## Language Rule

Plan and research file content is **always written in Korean**, regardless of the conversation language. Frontmatter keys and section titles can be English. Technical terms (library names, framework names, CLI commands, file paths, code snippets) remain in English. Conversation with the developer follows their language.

## Artifact layout

- Plan files: `docs/agents/dev/{timestamp}_{Jira ticket}_PLAN_{title}.md`
- Implementation reports (created later by `implement-dev`): `docs/agents/dev/{timestamp}_{Jira ticket}_IMPL_{title}.md`
- Research files: `docs/agents/research/{title}.md`
- Research index: `docs/agents/research/index.md`

The naming rules behind those placeholders are enforced by the references: plan files in [single-step-plan.md](references/single-step-plan.md) section 1 (and [multi-steps-plan.md](references/multi-steps-plan.md) section 1 for `-STEP-N` sub-plans), research files in [research-file.md](references/research-file.md) section 3.

## Content format

Inside plan and research files, the **frontmatter** and **language** (Korean) are always enforced. Beyond those two, each reference document owns its own enforced-vs-flexible list - read the mode's reference rather than assuming a section template here. What all modes share: structural metadata (file naming, storage location, Markdown link conventions) is enforced, and body *shape* is not.

## Plan granularity

A plan is a **goal-oriented, coarse-grained overview**, not a mechanical build script. Its job is to lock direction that a human can review quickly and that `implement-dev` can execute without second-guessing the approach, while leaving how-level details to be resolved at implementation time, where TDD and real environment feedback (compiler errors, failing tests, actual code state) settle those decisions better than read-only plan mode can.

Decide altitude by what the information *is*, not by how much of it you happen to have:

- **Coarse - defer to `implement-dev`'s discretion**: line-level edits, exact code sketches, helper signatures, pre-enumerated edge cases, library quirks. These are cheaper and more correct to settle against a running codebase than to guess in plan mode. Over-specifying them also makes the plan long and low-signal, which degrades how reliably an executor follows *any* single instruction and makes the plan too heavy for a human to actually review.
- **Sharp - specify precisely**: the goal, the chosen approach and why, module/area boundaries, non-goals, and - for multi-steps - the contract between steps (the interfaces, types, and schemas one step exposes to the next). This is information the implementer cannot recover from environment feedback; if it is wrong or missing, the result is a direction-level error the executor cannot self-correct, not a detail it can.

Generic verification commands (lint / unit / e2e / build) are never copied into the plan - `implement-dev` rediscovers them from `Makefile` / `AGENTS.md` / `CLAUDE.md` / `README.md` at implementation time, where they cannot drift. The `## Acceptance Contract` records only work-specific outcomes and evidence the repository cannot announce on its own.

Deep investigation during planning is still encouraged - but its detailed findings belong in **research files**, not the plan body. Research holds the depth; the plan holds the direction distilled from it.

## Modes

- **single-step** (default) - a single plan file. Use this for most tasks: features, refactors, bug fixes, small-to-medium work.
  - Frontmatter, naming, required anchors (research links + TODOs): [references/single-step-plan.md](references/single-step-plan.md)
- **multi-steps** (explicit opt-in) - one main plan file + multiple `-STEP-N` sub-plan files, connected via Markdown links. Use when the user explicitly asks for a multi-step breakdown (e.g. "여러 단계로 나눠서 플래닝 해줘", "multi-step plan", "단계별로", "PLAN-STEP", "증분 개발"). Typical for new projects or large initiatives that should be delivered as incremental build-test cycles.
  - Frontmatter, naming, link rules, suggested structure: [references/multi-steps-plan.md](references/multi-steps-plan.md)

## Arguments / Inputs

The user explains what to plan in the prompt. The prompt may include free-form text, repository markdown references, or a SPEC.md document. If the prompt is empty, ask the user what they want to plan.

## Process

### 1. Collect context (read-only)

Parse the prompt to identify free-form text, repository markdown references, or a SPEC.md document.

- Repository markdown references: search markdown files under the working tree. If no match, ask the user to clarify.
- SPEC.md: if the user does not provide its path, ask.

### 2. Determine mode

Default to **single-step**. Switch to **multi-steps** only when the user explicitly asks (see Modes section for trigger phrases). If the signal is ambiguous, ask once with `AskQuestion`; otherwise proceed with single-step. State the decided mode to the user in one sentence before proceeding.

### 3. Align on goal / scope

Before deep research or planning, confirm direction:

- Summarize the goal in 1-2 sentences from the collected context.
- State the modules or areas you expect to focus on (or, for new projects, the high-level architecture).
- If SPEC.md has `Open Questions` or `ASSUMED` markers, surface them grouped by impact:
  - Blocking - cannot plan without an answer
  - Important - can plan around, but plan may change
  - Low-risk - proceed with the stated assumption after a brief confirmation
- Ask the user to confirm or correct before proceeding.

### 4. Research (conditional, read-only)

Perform this step only if the working directory contains existing source code, i.e. a git repository with committed source files beyond documentation. For empty / scaffold-only repositories, skip to step 5.

If research is required:

- Inspect `docs/agents/research/index.md` first. It lists each research file's frontmatter metadata plus a Markdown link to the file. Use this index to decide which research files are relevant to the planned change. If the index is missing, treat existing research as unavailable for this planning run; do not open every research file to reconstruct metadata unless the user explicitly asks you to rebuild the index.
- Read relevant research files inline as read-only inputs.
- Evaluate whether existing research covers the planned change. If gaps remain, investigate the codebase with read tools per [references/research-file.md](references/research-file.md) section 1, which owns the investigation procedure.
- Draft any new research findings as research file content **in memory**. Do not write yet. The actual write happens in step 12; [references/research-file.md](references/research-file.md) also carries naming, frontmatter, and index rules.

**Planner touchpoint ① (conditional)**: when the work is ambiguous, cross-cutting, or architecture-sensitive, dispatch the read-only `planner` agent with the collected context. It returns (a) a compact architecture view to fold into the draft, and (b) a list of high-impact questions for the user, each with options and a recommended default. Relay those questions in steps 5-6 - a subagent cannot talk to the user, so the interview always stays in the main session. Skip for trivial work.

### 5. Clarify assumptions

Present your understanding and assumptions for validation before drafting the plan:

- List numbered assumptions (scope, strategy, error behavior, backward compatibility, etc.).
- Mark items where you need the user's input (unknowns, ambiguous requirements, design decisions with multiple valid options).
- If SPEC.md had `ASSUMED` items deferred from step 3, revisit them now with concrete context.
- Continue until critical ambiguities are resolved.

### 6. Acceptance round

Agree on what "done" observably means before designing how. With `AskQuestion`, settle for each outcome the plan will deliver (these become the `## TODOs`):

- **Observable completion state** - what a reviewer can check without asking the author.
- **Evidence** - the work-specific proof (a behavior, an output, an artifact). Generic lint/unit/e2e/build gates stay out - they are rediscovered at implementation time (see Plan granularity).
- **Acceptable risk** - what is deliberately not verified, named now instead of discovered later.

Distill the agreement into a draft `## Acceptance Contract` table (AC-1, AC-2, …; format in the mode's reference) and confirm it with the user. Approving the plan later approves the approach **and** these criteria together - this contract is what an independent evaluator judges the implementation against without this session's memory.

Scale the round to the work: for trivial tasks a single confirmation question is enough - do not inflate it. If planner touchpoint ① returned acceptance-related questions, relay them here.

### 7. Design

Synthesize research and clarified requirements into an implementation approach:

- **single-step**: one cohesive technical approach covering files to modify/create/delete and verification.
- **multi-steps**: an incremental step DAG where each completed step keeps the project compiling and tests passing. When SPEC.md provides numbered Functional Requirements, they are natural decomposition units. Identify which steps can run in parallel.

Every technical decision must be consistent with the key requirements in `AGENTS.md` / `CLAUDE.md` and SPEC.md Conventions/Constraints (when present).

### 8. Draft the plan in memory

Compose plan file content in memory according to the chosen mode's reference:

- single-step -> [references/single-step-plan.md](references/single-step-plan.md), which lists what it enforces and what it leaves free. Fold the `## Acceptance Contract` agreed in step 6 into the draft.
- multi-steps -> [references/multi-steps-plan.md](references/multi-steps-plan.md). Draft the main plan **and every sub-plan** in memory; each sub-plan is a full single-step plan and inherits that reference's enforcement, because each is itself a cold-handoff implementation unit. Verify link targets match the sub-plan filenames you intend to write.

### 9. Review

Review the draft for:

- **Completeness** - every intent from the context is addressed. For multi-steps with SPEC.md input, every FR-N is covered by at least one step.
- **Correctness** - technical decisions are consistent with project constraints and conventions.
- **Actionability** - `implement-dev` can start each task / step without having to re-decide the approach. It may still work out how-level details against the codebase; what it must not have to do is re-derive the direction. Do not inflate tasks with mechanics to hit this bar (see Plan granularity).
- **Multi-steps integrity** - each step keeps the project compiling and tests passing when completed; step dependencies form a sensible DAG.
- **Cold hand-off gate (approval-blocking)** - the default execution path is a Worker subagent with zero memory of this planning session. Before approving, ask: *Can an `implement-dev` Worker, given only this plan plus the linked research files, (1) recover the direction without re-deriving it, (2) pick exactly the research files it needs for each TODO from the strengthened links, and (3) not misread the approach? And can an **independent evaluator**, given only this plan and its `## Acceptance Contract`, (4) decide pass/fail for the finished work without asking anyone?* If not, strengthen the research links (add the missing one-line summary or `**TODO N·M**` tag), thicken `## Key decisions` / `## Non-goals` to remove the ambiguity, or sharpen the Acceptance Contract until its conditions are observable and evidence-backed. Do not present the plan for approval while the answer is "no" for any TODO or any AC.

**Planner touchpoint ② (conditional)**: for the same non-trivial work that warranted touchpoint ①, send the draft plan (including its Acceptance Contract) to the `planner` agent for a Planning Lens pass - goal/boundary/contract fit, whether the AC suffices for independent evaluation, and over-planning flags. Fold the findings into the draft before presenting it. Skip for trivial work.

Highlight risks, edge cases, and remaining assumptions. Present the plan to the user. This is the content put up for approval after final refinement.

### 10. Refine

Iterate on the plan based on user feedback. Adjust scope, approach, files, or step granularity. Repeat review -> refine until the user approves.

### 11. Hand off for approval

Once the reviewed plan is ready, put the final reviewed plan in front of the user and stop. The user approves it in Cursor's plan flow and the conversation moves into write-capable execution; you do not call anything to make that happen, and you do not start step 12 until it has.

Persistence steps are skill mechanics, not part of the plan content the user reviews. Keep the plan focused on the technical work.

### 12. Persist (first actions in build/execute mode)

These are the very first tool calls after the session transitions out of plan mode, before any other follow-up:

1. **Write research files** (if any were drafted in step 4). Ensure `docs/agents/research/` exists, then save each file per [references/research-file.md](references/research-file.md), applying its `index.md` maintenance rules (section 5) in the same step - create the index when the project has none yet.
2. **Write plan file(s)**. Ensure `docs/agents/dev/` exists, then save the plan file(s) per the chosen mode's reference. For multi-steps, write the main plan and every sub-plan, then verify each Markdown link in the main plan resolves to an existing sub-plan filename.

After persistence, report the file paths to the user and proceed with whatever follow-up they request (typically: invoke `implement-dev` or another execution skill).
