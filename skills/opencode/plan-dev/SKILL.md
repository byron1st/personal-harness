---
name: plan-dev
description: Create an implementation plan in OpenCode Plan mode, present the final plan in chat for the user to review before switching to Build mode, and persist plan/research artifacts under docs/agents after the user switches to Build mode. Use when the user wants to plan before coding; single-step by default, multi-step only on explicit request.
---

# Plan Dev

Create an implementation plan through iterative refinement entirely inside OpenCode Plan mode, then persist the result as markdown file(s) under the project root's `docs/agents` directory as the very first action after the user switches from Plan mode to Build mode (Tab) and returns control to write-capable execution.

## Why this skill exists

OpenCode Plan mode blocks file writes while the agent researches and proposes changes. That gate is valuable because the user reads the plan before any side effect happens. The planning workflow still produces durable artifacts: plan documents and research notes. `plan-dev` keeps planning read-only, then writes those artifacts into the repository-local `docs/agents` tree immediately after plan mode ends.

## Compatibility with plan mode

Steps 1-9 below MUST run with read-only tools only (`Read`, `Grep`, `Glob`, the question tool, and other read-only queries). No writes to `docs/agents` or the working tree happen during this phase.

When the final plan is ready, present the reviewed plan in chat. The user switches from Plan mode to Build mode by pressing Tab, then replies with a continuation cue (e.g., "continue"); the agent then runs persistence in the first Build-mode turn.

The first tool calls after the user has approved the plan and Claude Code is allowed to write MUST be the persistence steps in step 11, in this exact order: research files -> plan file(s). Only after those writes are done may any further follow-up work begin.

## Language Rule

Plan and research file content is **always written in Korean**, regardless of the conversation language. Frontmatter keys and section titles can be English. Technical terms (library names, framework names, CLI commands, file paths, code snippets) remain in English. Conversation with the developer follows their language.

## Artifact layout

- Plan files: `docs/agents/dev/{timestamp}_{Jira ticket}_PLAN_{title}.md`
- Implementation reports (created later by `implement-dev`): `docs/agents/dev/{timestamp}_{Jira ticket}_IMPL_{title}.md`
- Research files: `docs/agents/research/{title}.md`
- Research index: `docs/agents/research/index.md`

`timestamp` is local time in `YYYYMMDDHHMMSS` format. `{title}` is a short kebab-case descriptor. `{Jira ticket}` is extracted from the current branch name using `[A-Z]+-[0-9]+`; if it cannot be extracted, ask the user unless they explicitly confirm `NO-JIRA`.

## Content format

Inside plan and research files, the **frontmatter** and **language** (Korean) are always enforced. Each reference document specifies any additional enforced elements.

Body shape differs by mode:

- **single-step** - only the research file links (when applicable) and a final `## TODOs` checklist are enforced. The rest of the body is free-form: when the plan was produced by a planning agent, copy its output **verbatim** between those two anchors instead of normalizing it into a fixed template. See [references/single-step-plan.md](references/single-step-plan.md).
- **multi-steps** - choose whatever section structure best fits the work. Each reference document includes a suggested default structure as a starting point. Drop sections that do not apply, add ones that do, reorder freely.

File naming, storage location, and (for multi-steps) Markdown link conventions in the references *are* enforced. Those are structural metadata, not content format.

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

Default to **single-step**. Switch to **multi-steps** only when the user explicitly asks (see Modes section for trigger phrases). If the signal is ambiguous, ask once with the question tool; otherwise proceed with single-step. State the decided mode to the user in one sentence before proceeding.

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
- Evaluate whether existing research covers the planned change. If gaps remain, investigate the codebase using read tools:
  - **Trace callers & callees** for each function to be modified; follow the chain to stable boundaries (entry points, external APIs, data stores).
  - **Check interfaces & contracts**; find all implementations and verify whether changes require updating them.
  - **Review existing tests**; read test files to understand expected behavior, edge cases, and testing patterns.
- Draft any new research findings as research file content **in memory**. Do not write yet. The actual write happens in step 11. Use [references/research-file.md](references/research-file.md) for naming and frontmatter.

### 5. Clarify assumptions

Present your understanding and assumptions for validation before drafting the plan:

- List numbered assumptions (scope, strategy, error behavior, backward compatibility, etc.).
- Mark items where you need the user's input (unknowns, ambiguous requirements, design decisions with multiple valid options).
- If SPEC.md had `ASSUMED` items deferred from step 3, revisit them now with concrete context.
- Continue until critical ambiguities are resolved.

### 6. Design

Synthesize research and clarified requirements into an implementation approach:

- **single-step**: one cohesive technical approach covering files to modify/create/delete and verification.
- **multi-steps**: an incremental step DAG where each completed step keeps the project compiling and tests passing. When SPEC.md provides numbered Functional Requirements, they are natural decomposition units. Identify which steps can run in parallel.

Every technical decision must be consistent with the key requirements in `AGENTS.md` and legacy `CLAUDE.md` when present and SPEC.md Conventions/Constraints (when present).

### 7. Draft the plan in memory

Compose plan file content in memory according to the chosen mode's reference:

- single-step -> [references/single-step-plan.md](references/single-step-plan.md). Frontmatter, research file links (when applicable), and the final `## TODOs` checklist are enforced. The body in between is free-form; when the plan came from a planning agent, copy its output verbatim instead of reshaping it.
- multi-steps -> [references/multi-steps-plan.md](references/multi-steps-plan.md). Frontmatter and language must follow the reference. Section structure is your call. Draft the main plan and every sub-plan in memory; verify link targets match the sub-plan filenames you intend to use.

### 8. Review

Review the draft for:

- **Completeness** - every intent from the context is addressed. For multi-steps with SPEC.md input, every FR-N is covered by at least one step.
- **Correctness** - technical decisions are consistent with project constraints and conventions.
- **Actionability** - each task / step can be executed without re-investigating the codebase.
- **Multi-steps integrity** - each step keeps the project compiling and tests passing when completed; step dependencies form a sensible DAG.

Highlight risks, edge cases, and remaining assumptions. Present the plan to the user. This is the content the user will read in chat before pressing Tab to switch to Build mode, after final refinement.

### 9. Refine

Iterate on the plan based on user feedback. Adjust scope, approach, files, or step granularity. Repeat review -> refine until the user approves.

### 10. Hand off to plan mode exit

Once the reviewed plan is ready, present the final reviewed plan in chat and end with the hand-off line: *"Plan ready — switch to Build mode (Tab) and reply 'continue' to persist these files."* The user switches from Plan mode to Build mode by pressing Tab and replies with a continuation cue (e.g., "continue"); the agent then runs persistence in the first Build-mode turn.

Persistence steps are skill mechanics, not part of the plan content the user reviews. Keep the plan focused on the technical work.

### 11. Persist (first actions in build/execute mode)

These are the very first tool calls after Claude Code transitions out of plan mode, before any other follow-up:

1. **Write research files** (if any were drafted in step 4). Ensure `docs/agents/research/` exists, then save each file per [references/research-file.md](references/research-file.md). After writing or updating research files, ensure `docs/agents/research/index.md` exists, creating it when no index.md was present beforehand, then update it so it contains the current metadata and links for every research file.
2. **Write plan file(s)**. Ensure `docs/agents/dev/` exists, then save the plan file(s) per the chosen mode's reference. For multi-steps, write the main plan and every sub-plan, then verify each Markdown link in the main plan resolves to an existing sub-plan filename.

After persistence, report the file paths to the user and proceed with whatever follow-up they request (typically: invoke `implement-dev` or another execution skill).
