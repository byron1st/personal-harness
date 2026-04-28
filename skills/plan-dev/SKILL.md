---
name: plan-dev
description: Collaboratively create an implementation plan and save it to Obsidian. Default mode is single-step (one plan file). Switches to multi-steps (main plan + sub-plans connected via Obsidian wikilinks) only when the user explicitly asks for it — e.g. "여러 단계로 나눠서", "multi-step", "단계별 플랜", "증분 개발". Use this skill whenever the user wants to plan before coding — features, refactors, bug fixes, or new projects (with or without SPEC.md). Also trigger on "let's think through how to do this", "plan this out", "what's the approach for", or when a Jira ticket / Obsidian notes are mentioned as planning inputs.
---

# Plan Dev

Create an implementation plan through iterative refinement and save it as markdown file(s) in Obsidian.

## Language Rule

Plan and research file content is **always written in Korean**, regardless of the conversation language. Technical terms (library names, framework names, CLI commands, file paths, code snippets) remain in English. Conversation with the developer follows their language.

## Modes

- **single-step** (default) — a single plan file in Obsidian. Use this for most tasks: features, refactors, bug fixes, small-to-medium work.
  - Format and file layout: [references/single-step-plan.md](references/single-step-plan.md)
- **multi-steps** (explicit opt-in) — one main plan file + multiple `-STEP-N` sub-plan files in Obsidian, connected by wikilinks (`[[...]]`). Use when the user explicitly asks for a multi-step breakdown (e.g. "여러 단계로 나눠서 플래닝 해줘", "multi-step plan", "단계별로", "PLAN-STEP", "증분 개발"). Typical for new projects or large initiatives that should be delivered as incremental build-test cycles.
  - Format and file layout: [references/multi-steps-plan.md](references/multi-steps-plan.md)

## Arguments / Inputs

The user should explain what to do in the prompt. The prompt can include free-form text, some Obsidian notes, or a SPEC.md document. If the prompt is empty, ask the user what they want to plan.

## Process

### 1. Collect context

- Parse the prompt to identify free-form text, Obsidian notes, or a SPEC.md document.
  - Obsidian notes: search markdown files in `${OBSIDIAN_HOME}`. If no match, ask the user to clarify.
  - A SPEC.md: if the user does not provide its path, ask the user its path.

### 2. Determine mode

- Default to **single-step**.
- Switch to **multi-steps** only when the user explicitly asks (see Modes section for trigger phrases).
- If the signal is ambiguous, ask the user once with `AskUserQuestion` — otherwise proceed with single-step.
- State the decided mode to the user in one sentence before proceeding.

### 3. Align on goal / scope

Before deep research or planning, confirm the direction:

- Summarize the goal in 1–2 sentences based on collected context.
- State which modules or areas you expect to focus on (or, for new projects, the high-level architecture).
- If SPEC.md is used and has `Open Questions` or `⚠️ ASSUMED` markers, surface them grouped by impact:
  - 🔴 Blocking — cannot plan without an answer
  - 🟡 Important — can plan around, but plan may change
  - 🟢 Low-risk — proceed with the stated assumption after a brief confirmation
- Ask the user to confirm or correct before proceeding.

### 4. Research (conditional)

Perform this step **only if the working directory contains existing source code** — i.e., it is a git repository with committed source files beyond documentation (a repo that has only `README.md`, `SPEC.md`, or `docs/` does not qualify). For empty or scaffold-only repositories, skip to step 5.

If research is required:

- Query existing research files first: `obsidian base:query file="Research.base" format=json view="{Application name}"`, where `{Application name}` is the working repository name (not the full URL; e.g., `github.com/sample-user/sample-server` → `sample-server`).
- Based on each result's description, determine which files are relevant. The `path` field is relative to `${OBSIDIAN_HOME}`.
- Evaluate whether existing research covers the planned change. If gaps remain, investigate the codebase:
  - **Trace callers & callees** for each function to be modified — follow the chain to stable boundaries (entry points, external APIs, data stores).
  - **Check interfaces & contracts** — find all implementations and verify whether changes require updating them.
  - **Review existing tests** — read test files to understand expected behavior, edge cases, and testing patterns.
- Save new findings as research files — follow [references/research-file.md](references/research-file.md) for the format and process.

### 5. Clarify assumptions

Present your understanding and assumptions to the user for validation before writing the plan:

- List numbered assumptions (scope, strategy, error behavior, backward compatibility, etc.).
- Mark items where you need the user's input (unknowns, ambiguous requirements, design decisions with multiple valid options).
- If SPEC.md had `⚠️ ASSUMED` items deferred from step 3, revisit them now with concrete context.
- Continue until critical ambiguities are resolved.

### 6. Design

Synthesize research findings and clarified requirements into an implementation approach:

- **single-step**: design one cohesive technical approach covering files to modify/create/delete and verification steps.
- **multi-steps**: break the work into an incremental step DAG where each completed step keeps the project compiling and tests passing. Use Functional Requirements (when SPEC.md is provided) as the natural decomposition units. Identify which steps can run in parallel.

Every technical decision must be consistent with the key requirements from `AGENTS.md` / `CLAUDE.md` and SPEC.md Conventions/Constraints.

### 7. Write the plan file(s)

Follow the reference document for the decided mode:

- single-step → [references/single-step-plan.md](references/single-step-plan.md)
- multi-steps → [references/multi-steps-plan.md](references/multi-steps-plan.md)

All plan files are stored in `${OBSIDIAN_HOME}/00. Plans/`.

### 8. Review

Review your plan for:

- **Completeness**: every intent from the context is addressed. For multi-steps with SPEC.md input, every FR-N appears in at least one step's `Implements` section.
- **Correctness**: technical decisions are consistent with project constraints and conventions.
- **Actionability**: each task/step can be executed without re-investigating the codebase.
- **For multi-steps**: each step keeps the project compiling and tests passing when completed; step dependencies form a sensible DAG.

Highlight risks, edge cases, and remaining assumptions. Present the plan to the user.

### 9. Refine

- Iterate on the plan based on user feedback.
- Adjust scope, approach, files, or step granularity.
- Repeat review → refine until the user approves.

### 10. Wrap up

- Add newly created or updated plan and research files to the Obsidian daily note:
  - First read the daily note: `obsidian daily:read` — to see which files are already listed.
  - Only append files that are not already listed.
  - Append using `obsidian daily:append content=${CONTENT}`, where `${CONTENT}` is `- [[${PATH_TO_FILE}]]` with the path relative to `${OBSIDIAN_HOME}`. The `.md` extension may be omitted.
  - For multi-steps plans, link the main plan file (sub-plans are discoverable via wikilinks inside it).
