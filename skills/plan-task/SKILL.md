---
name: plan-task
description: |
  Collaboratively create an implementation plan inside the host agent's built-in plan mode (Claude Code's ExitPlanMode flow, Codex's plan mode, Opencode's Plan/Build mode toggle, etc.), then persist the result to Obsidian as markdown the moment plan mode is exited. Default mode is single-step (one plan file). Switches to multi-steps (main + sub-plans connected via Obsidian wikilinks) when the user explicitly asks for incremental breakdown — e.g. "여러 단계로 나눠서", "단계별로", "단계별 플랜", "multi-step", "증분 개발", "릴리스 가능한 단위로 chunk".

  Trigger this skill whenever the user wants to PLAN an implementation before writing code — features, refactors, bug fixes, or new projects (with or without SPEC.md). Strong signals include "plan 좀", "plan this out", "plan it out properly", "plan out the migration", "let's think through how to do this", "어떻게 고칠지 정리해줘", "어떤 순서로 풀까", "어떤 순서로 풀어야 할지", "what's the approach for", "일단 plan 으로 정리하고", or when a Jira ticket / branch name / Obsidian note is referenced as the source of requirements for a planned change. Prefer this skill over plan-dev whenever the host agent's plan mode is active.

  Do NOT trigger when: (1) the user asks to execute or implement an already-existing plan ("그대로 실행해줘", "implement-dev 으로 plan 실행", "just write the code, no need to plan") — that is implement-dev's job; (2) the user wants to understand current code without intent to change it ("how does this currently work", "nothing to implement yet"); (3) the request belongs to a sibling skill — review-code (PR/code review), commit-code (commit messages), generate-claude-md (CLAUDE.md generation), request-merge (merge request creation), summarize-week (weekly digest from daily notes), application-research-sync (syncing RESEARCH files to Obsidian); (4) the user explicitly waives planning for a trivial fix ("그냥 바로 고쳐줘", "5분 안에 끝낼 작업").
---

# Plan Task

Create an implementation plan through iterative refinement entirely inside the host agent's plan mode, then persist the result as markdown file(s) in Obsidian as the very first action after the host transitions out of plan mode.

## Why this skill exists

Most coding agents (Claude Code, Codex, Opencode) ship with a built-in plan mode that blocks file writes and returns control to the user via an explicit "exit plan" gate. That gate is valuable — the user reads the plan before any side effect happens. But the planning workflow itself produces durable artifacts (plan documents, research notes) the user wants persisted. `plan-task` threads the needle: planning happens inside plan mode using read-only tools; persistence to Obsidian happens immediately after plan mode ends, as the very first action of the build/execute phase.

This skill is the plan-mode-compatible counterpart of `plan-dev`. The technical thinking and review/refine cycle are identical; what differs is *when* the writes happen.

## Compatibility with plan mode

Steps 1–9 below MUST run with read-only tools only (`Read`, `Grep`, `Glob`, `AskUserQuestion`, MCP read queries). No writes to Obsidian or the working tree happen during this phase — that is what plan mode enforces, and the skill is designed around it.

When the user approves the plan, plan mode ends. The exact transition is host-specific, and matters because of *who* initiates it:

- **Claude Code**: agent-initiated. Call `ExitPlanMode` with the final reviewed plan as its `plan` argument; the user approves through that tool's UI, after which the agent automatically continues into implementation.
- **Codex**: use the equivalent plan-mode exit mechanism the host provides.
- **Opencode**: user-initiated, no agent-callable exit tool. The agent presents the final plan in chat; the user manually switches Plan → Build mode by pressing Tab and then prompts the agent to continue. Make this hand-off explicit at the end of the plan presentation — e.g., a closing line like *"플랜 확정. Build 모드로 전환 (Tab) 한 뒤 'continue' 라고 답하면 파일을 저장할게."* / *"Plan ready — switch to Build mode (Tab) and reply 'continue' to persist these files."* This way the user knows exactly what to do, and the agent's next turn (now in Build mode) can carry out persistence with the plan still in conversation context.

The first tool calls in build/execute mode after the user has approved the plan MUST be the persistence steps in step 11, in this exact order: research files → plan file(s) → daily note. Only after those three are done may any further follow-up work begin. For user-initiated transitions like Opencode's, "first tool calls" refers to the agent's first actions in its first build-mode turn — even if the user typed something generic like "go ahead", treat persistence as the implicit first task.

## Language Rule

Plan and research file content is **always written in Korean**, regardless of the conversation language. Frontmatter keys and section titles can be English. Technical terms (library names, framework names, CLI commands, file paths, code snippets) remain in English. Conversation with the developer follows their language.

## Content format

Inside plan and research files, only two things are enforced:

1. The **frontmatter** specified in the relevant reference document.
2. The **language** (Korean for body content).

Beyond those, choose whatever section structure best fits the work. Each reference document includes a *suggested* default structure as a starting point — drop sections that do not apply, add ones that do, reorder freely. The suggestion exists so you do not start from a blank page; it is not a contract.

File naming, storage location, and (for multi-steps) wikilink conventions in the references *are* enforced — those are structural metadata, not content format.

## Modes

- **single-step** (default) — a single plan file in Obsidian. Use this for most tasks: features, refactors, bug fixes, small-to-medium work.
  - Frontmatter, naming, suggested structure: [references/single-step-plan.md](references/single-step-plan.md)
- **multi-steps** (explicit opt-in) — one main plan file + multiple `-STEP-N` sub-plan files, connected via Obsidian wikilinks (`[[...]]`). Use when the user explicitly asks for a multi-step breakdown (e.g. "여러 단계로 나눠서 플래닝 해줘", "multi-step plan", "단계별로", "PLAN-STEP", "증분 개발"). Typical for new projects or large initiatives that should be delivered as incremental build-test cycles.
  - Frontmatter, naming, wikilink rules, suggested structure: [references/multi-steps-plan.md](references/multi-steps-plan.md)

## Arguments / Inputs

The user explains what to plan in the prompt. The prompt may include free-form text, Obsidian note references, or a SPEC.md document. If the prompt is empty, ask the user what they want to plan.

## Process

### 1. Collect context (read-only)

Parse the prompt to identify free-form text, Obsidian notes, or a SPEC.md document.

- Obsidian notes: search markdown files in `${OBSIDIAN_HOME}` using read MCP queries. If no match, ask the user to clarify.
- SPEC.md: if the user does not provide its path, ask.

### 2. Determine mode

Default to **single-step**. Switch to **multi-steps** only when the user explicitly asks (see Modes section for trigger phrases). If the signal is ambiguous, ask once with `AskUserQuestion` — otherwise proceed with single-step. State the decided mode to the user in one sentence before proceeding.

### 3. Align on goal / scope

Before deep research or planning, confirm direction:

- Summarize the goal in 1–2 sentences from the collected context.
- State the modules or areas you expect to focus on (or, for new projects, the high-level architecture).
- If SPEC.md has `Open Questions` or `⚠️ ASSUMED` markers, surface them grouped by impact:
  - 🔴 Blocking — cannot plan without an answer
  - 🟡 Important — can plan around, but plan may change
  - 🟢 Low-risk — proceed with the stated assumption after a brief confirmation
- Ask the user to confirm or correct before proceeding.

### 4. Research (conditional, read-only)

Perform this step only if the working directory contains existing source code — i.e., a git repository with committed source files beyond documentation (a repo with only `README.md`, `SPEC.md`, or `docs/` does not qualify). For empty / scaffold-only repositories, skip to step 5.

If research is required:

- Query existing research files first (read MCP query): `obsidian base:query file="Research.base" format=json view="{Application name}"`, where `{Application name}` is the working repository name without the URL (e.g., `github.com/sample-user/sample-server` → `sample-server`).
- Based on each result's description, decide which files to read. The `path` field is relative to `${OBSIDIAN_HOME}`. Read relevant files inline — they are read-only inputs.
- Evaluate whether existing research covers the planned change. If gaps remain, investigate the codebase using read tools:
  - **Trace callers & callees** for each function to be modified — follow the chain to stable boundaries (entry points, external APIs, data stores).
  - **Check interfaces & contracts** — find all implementations and verify whether changes require updating them.
  - **Review existing tests** — read test files to understand expected behavior, edge cases, and testing patterns.
- Draft any new research findings as research file content **in memory**. Do not write yet — the actual write happens in step 11. Use [references/research-file.md](references/research-file.md) for naming and frontmatter.

### 5. Clarify assumptions

Present your understanding and assumptions for validation before drafting the plan:

- List numbered assumptions (scope, strategy, error behavior, backward compatibility, etc.).
- Mark items where you need the user's input (unknowns, ambiguous requirements, design decisions with multiple valid options).
- If SPEC.md had `⚠️ ASSUMED` items deferred from step 3, revisit them now with concrete context.
- Continue until critical ambiguities are resolved.

### 6. Design

Synthesize research and clarified requirements into an implementation approach:

- **single-step**: one cohesive technical approach covering files to modify/create/delete and verification.
- **multi-steps**: an incremental step DAG where each completed step keeps the project compiling and tests passing. When SPEC.md provides numbered Functional Requirements, they are natural decomposition units. Identify which steps can run in parallel.

Every technical decision must be consistent with the key requirements in `AGENTS.md` / `CLAUDE.md` and SPEC.md Conventions/Constraints (when present).

### 7. Draft the plan in memory

Compose plan file content in memory according to the chosen mode's reference:

- single-step → [references/single-step-plan.md](references/single-step-plan.md)
- multi-steps → [references/multi-steps-plan.md](references/multi-steps-plan.md)

Frontmatter and language must follow the reference. Section structure is your call — the reference's suggested structure is a starting point, not a contract. For multi-steps, draft the main plan and every sub-plan in memory; verify wikilink targets match the sub-plan filenames you intend to use.

### 8. Review

Review the draft for:

- **Completeness** — every intent from the context is addressed. For multi-steps with SPEC.md input, every FR-N is covered by at least one step.
- **Correctness** — technical decisions are consistent with project constraints and conventions.
- **Actionability** — each task / step can be executed without re-investigating the codebase.
- **Multi-steps integrity** — each step keeps the project compiling and tests passing when completed; step dependencies form a sensible DAG.

Highlight risks, edge cases, and remaining assumptions. Present the plan to the user. In Claude Code, this is also the content the agent will pass to `ExitPlanMode`. In Opencode, this is what the user will read in chat before pressing Tab to switch to Build mode.

### 9. Refine

Iterate on the plan based on user feedback. Adjust scope, approach, files, or step granularity. Repeat review → refine until the user approves.

### 10. Hand off to plan mode exit

Once approved, plan mode ends via a host-specific transition. Pick the right hand-off:

- **Claude Code**: pass the final reviewed plan to `ExitPlanMode` as its `plan` argument. The user approves through that tool's UI and the agent continues automatically.
- **Codex**: use the equivalent plan-mode exit mechanism the host provides.
- **Opencode**: there is no agent-callable exit tool. End the plan presentation with an explicit hand-off line telling the user to switch to Build mode (Tab) and reply with a continuation cue (e.g., "continue") so the next turn — now in Build mode — runs persistence as its first action.

Persistence steps are skill mechanics, not part of the plan content the user reviews — keep the plan focused on the technical work.

### 11. Persist (first actions in build/execute mode)

These are the very first tool calls after the host transitions out of plan mode — before any other follow-up. For Opencode in particular, these run in the first Build-mode turn, with the approved plan still in conversation context:

1. **Write research files** (if any were drafted in step 4). Save to `${OBSIDIAN_HOME}/01. Research/` per [references/research-file.md](references/research-file.md).
2. **Write plan file(s)**. Save to `${OBSIDIAN_HOME}/00. Plans/` per the chosen mode's reference. For multi-steps, write the main plan and every sub-plan, then verify each wikilink in the main plan resolves to an existing sub-plan filename.
3. **Update the Obsidian daily note**:
   - Read the daily note: `obsidian daily:read` — to see which files are already listed.
   - Append only files not already listed: `obsidian daily:append content=${CONTENT}` where `${CONTENT}` is `- [[${PATH_TO_FILE}]]` with the path relative to `${OBSIDIAN_HOME}` (the `.md` extension may be omitted).
   - For multi-steps, link only the main plan file — sub-plans are reachable via wikilinks inside it.

After persistence, report the file paths to the user and proceed with whatever follow-up they request (typically: invoke `implement-dev` or another execution skill).
