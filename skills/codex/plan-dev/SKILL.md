---
name: plan-dev
description: Create an implementation plan in Codex plan mode and persist it to Obsidian after approval. Use when the user wants to plan before coding; single-step by default, multi-step only on explicit request.
---

# Plan Dev

Create an implementation plan through iterative refinement entirely inside Codex plan mode, then persist the result as markdown file(s) in Obsidian as the very first action after Codex transitions out of plan mode.

## Why this skill exists

Codex plan mode blocks file writes while the agent researches and proposes changes. That gate is valuable — the user reads the plan before any side effect happens. But the planning workflow itself produces durable artifacts (plan documents, research notes) the user wants persisted. `plan-dev` threads the needle: planning happens inside plan mode using read-only tools; persistence to Obsidian happens immediately after plan mode ends, as the very first action of the build/execute phase.

This skill is the plan-mode-compatible counterpart of `plan-dev`. The technical thinking and review/refine cycle are identical; what differs is *when* the writes happen.

## Compatibility with plan mode

Steps 1–9 below MUST run with read-only tools only (file reads, `rg`/file searches, user questions, MCP read queries when available). No writes to Obsidian or the working tree happen during this phase — that is what plan mode enforces, and the skill is designed around it.

When the user approves the plan, Codex exits plan mode through the UI's approval flow. There is no agent-callable plan-exit tool in Codex.

The first tool calls after the user has approved the plan and Codex is allowed to write MUST be the persistence steps in step 11, in this exact order: research files → plan file(s) → daily note. Only after those three are done may any further follow-up work begin.

## Language Rule

Plan and research file content is **always written in Korean**, regardless of the conversation language. Frontmatter keys and section titles can be English. Technical terms (library names, framework names, CLI commands, file paths, code snippets) remain in English. Conversation with the developer follows their language.

## Content format

Inside plan and research files, the **frontmatter** and **language** (Korean) are always enforced. Each reference document specifies any additional enforced elements.

Body shape differs by mode:

- **single-step** — only the research file links (when applicable) and a final `## TODOs` checklist are enforced. The rest of the body is free-form: when the plan was produced by a planning agent, copy its output **verbatim** between those two anchors instead of normalizing it into a fixed template. See [references/single-step-plan.md](references/single-step-plan.md).
- **multi-steps** — choose whatever section structure best fits the work. Each reference document includes a *suggested* default structure as a starting point — drop sections that do not apply, add ones that do, reorder freely. The suggestion exists so you do not start from a blank page; it is not a contract.

File naming, storage location, and (for multi-steps) wikilink conventions in the references *are* enforced — those are structural metadata, not content format.

## Modes

- **single-step** (default) — a single plan file in Obsidian. Use this for most tasks: features, refactors, bug fixes, small-to-medium work.
  - Frontmatter, naming, required anchors (research links + TODOs): [references/single-step-plan.md](references/single-step-plan.md)
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

Default to **single-step**. Switch to **multi-steps** only when the user explicitly asks (see Modes section for trigger phrases). If the signal is ambiguous, ask once — otherwise proceed with single-step. State the decided mode to the user in one sentence before proceeding.

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

- single-step → [references/single-step-plan.md](references/single-step-plan.md). Frontmatter, research file links (when applicable), and the final `## TODOs` checklist are enforced. The body in between is free-form — when the plan came from a planning agent, copy its output verbatim instead of reshaping it.
- multi-steps → [references/multi-steps-plan.md](references/multi-steps-plan.md). Frontmatter and language must follow the reference. Section structure is your call — the reference's suggested structure is a starting point, not a contract. Draft the main plan and every sub-plan in memory; verify wikilink targets match the sub-plan filenames you intend to use.

### 8. Review

Review the draft for:

- **Completeness** — every intent from the context is addressed. For multi-steps with SPEC.md input, every FR-N is covered by at least one step.
- **Correctness** — technical decisions are consistent with project constraints and conventions.
- **Actionability** — each task / step can be executed without re-investigating the codebase.
- **Multi-steps integrity** — each step keeps the project compiling and tests passing when completed; step dependencies form a sensible DAG.

Highlight risks, edge cases, and remaining assumptions. Present the plan to the user. This is the content the user reviews before approving Codex to leave plan mode and proceed with writes.

### 9. Refine

Iterate on the plan based on user feedback. Adjust scope, approach, files, or step granularity. Repeat review → refine until the user approves.

### 10. Hand off to plan mode exit

Once approved, plan mode ends through Codex's plan approval flow.

Do not call a host-specific plan-exit tool. Present the final reviewed plan, wait for the user's approval in Codex, and then run persistence as the first write-capable action.

Persistence steps are skill mechanics, not part of the plan content the user reviews — keep the plan focused on the technical work.

### 11. Persist (first actions in build/execute mode)

These are the very first tool calls after Codex transitions out of plan mode — before any other follow-up:

1. **Write research files** (if any were drafted in step 4). Save to `${OBSIDIAN_HOME}/01. Research/` per [references/research-file.md](references/research-file.md).
2. **Write plan file(s)**. Save to `${OBSIDIAN_HOME}/00. Plans/` per the chosen mode's reference. For multi-steps, write the main plan and every sub-plan, then verify each wikilink in the main plan resolves to an existing sub-plan filename.
3. **Update the Obsidian daily note**:
   - Read the daily note: `obsidian daily:read` — to see which files are already listed.
   - Append only files not already listed: `obsidian daily:append content=${CONTENT}` where `${CONTENT}` is `- [[${PATH_TO_FILE}]]` with the path relative to `${OBSIDIAN_HOME}` (the `.md` extension may be omitted).
   - For multi-steps, link only the main plan file — sub-plans are reachable via wikilinks inside it.

After persistence, report the file paths to the user and proceed with whatever follow-up they request (typically: invoke `implement-dev` or another execution skill).
