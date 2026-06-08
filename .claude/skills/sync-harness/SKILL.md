---
name: sync-harness
description: Propagate this personal-harness repo's platform variants downstream along the migration chain — Claude → Codex → Cursor (full chain), or just Codex → Cursor. Use whenever a skill, sub-agent, or hook needs its downstream variant(s) regenerated — e.g. "sync the harness", "propagate to codex and cursor", "migrate the new reviewer agent", "rebuild the cursor variants from codex", "push my changes down the chain". The skill asks you which direction to migrate, then applies MIGRATE_TO_CODEX.md and/or MIGRATE_TO_CURSOR.md and runs their Verify checklists. Migration is one-way downstream only — never Cursor → Codex or Codex → Claude. Project-local skill for the personal-harness repo only.
---

# Sync Harness

This repo keeps three platform variants of every skill, sub-agent, and hook: `claude/`, `codex/`, `cursor/`. They form a **one-way migration chain — Claude → Codex → Cursor.** Claude is the source of truth; Codex is migrated from Claude; Cursor is migrated from Codex. Migration only ever flows downstream — there is no reverse (never Cursor → Codex, never Codex → Claude).

Your job is to regenerate the downstream variant(s) so they match their upstream source, in the direction the user picks.

The transform rules are **not** in this skill. They live in two checklists at the repo root that the user maintains:

- `MIGRATE_TO_CODEX.md` — Claude → Codex
- `MIGRATE_TO_CURSOR.md` — Codex → Cursor

These are the living authority. Read the sections relevant to what you're migrating and apply them faithfully — prefer them over anything summarized here, because they get updated and this skill must not drift from them (the repo even has a doc-drift hook for exactly this reason).

## Step 1 — Get the migration direction (ask explicitly)

The direction is an explicit decision the user makes — don't infer it from git history or anything else. If the user's request already names it, use that ("rebuild the cursor variants from codex" → Codex → Cursor; "sync everything from claude down" → full chain). Otherwise **ask the user with AskUserQuestion before touching any files.** There are exactly two valid directions:

- **Claude → Codex → Cursor** — the full chain. Claude is the source; regenerate the Codex variant (hop 1) and then the Cursor variant (hop 2). This is the normal case, since Claude is the source of truth.
- **Codex → Cursor** — the second hop only. Codex is the source; regenerate just the Cursor variant. Use this when a change was made directly in `codex/` and only Cursor needs to catch up.

The chain is one-way. If the user asks for a reverse sync ("update codex from cursor", "sync cursor back to codex"), explain that migration only flows downstream and offer the closest downstream direction instead.

### What to migrate (scope)

Once the direction is set, sync **all** artifacts by default — every skill, all four reviewer sub-agents, and the hook set — so nothing downstream is left stale. If the user named specific artifacts ("just the review-code skill", "only the hooks"), limit to those. Paths, relative to the repo root:

| Artifact | `claude/` | `codex/` | `cursor/` |
| --- | --- | --- | --- |
| skill `<name>` | `skills/claude/<name>/` | `skills/codex/<name>/` | `skills/cursor/<name>/` |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` | `agents/cursor/<name>.md` |
| hooks | `hooks/claude/` | `hooks/codex/` | `hooks/cursor/` |

For the full chain, `claude/` is the source and `codex/` + `cursor/` are the targets. For Codex → Cursor, `codex/` is the source and `cursor/` is the only target. Treat the hook set as one unit — its config file is shared across all the scripts.

## Why the hops are ordered this way

Cursor variants are derived from the **Codex** variant, not from Claude — the Cursor sub-agent body is the Codex `developer_instructions` reformatted, and the Cursor skill body is the Codex body with execution-model terms swapped. So in the full chain you cannot shortcut Claude → Cursor: regenerate Codex first, then derive Cursor from that freshly-regenerated Codex. In the Codex → Cursor direction there is just the one hop, and the existing Codex variant is taken as the source as-is.

## Step 2 — Migrate, per artifact

Read the relevant section of each MIGRATE doc and apply it. The docs are organized by artifact type (`## Skill migration`, `## Sub-agent migration`, `## Hook migration`) in both files. **For the full chain, apply hop 1 (Claude→Codex) then hop 2 (Codex→Cursor). For the Codex → Cursor direction, apply only the hop-2 rules below and leave `codex/` untouched.**

Here is the structural shape of each transform so you know what you're producing. **The detailed rules — field mappings, what to strip, the gotchas — are in the MIGRATE docs; read them.**

### Skills
`skills/<platform>/<name>/SKILL.md` plus a `references/` and/or `scripts/` subtree.
- **`references/` and `scripts/` copy verbatim** across platforms — they're host-neutral. Only `SKILL.md` (frontmatter + body) transforms. Keep the trees identical.
- Hop 1 (Claude→Codex): shorten the `description` to a trigger-focused sentence or two; gate sub-agent use behind explicit user request; replace Claude tool names (`Agent`/`subagent_type`, `Read`/`Grep`/`AskUserQuestion`, `ExitPlanMode`) with Codex wording; map persona agents to Codex agent concepts.
- Hop 2 (Codex→Cursor): mostly word-swaps — "Codex"→"Cursor", "Codex custom agent"→"Cursor custom subagent (Task tool)", "Codex `explorer`"→"Cursor built-in `Explore`", strip "sandbox and approval" execution-model terms — while **keeping the Codex behavior** (delegation still gated on explicit request; don't make it always-on just because Cursor can auto-delegate).
- **Host-neutral skills are near-identical copies.** If a skill's body has no delegation, no plan-mode, and no platform terms, its Codex and Cursor variants are essentially `cp` of the source. In this repo `commit-code` is byte-identical across all three; `request-merge`, `application-research-sync`, `summarize-week`, `test-dev` are close. Don't manufacture differences — over-editing a host-neutral skill is a bug.

### Sub-agents
The four reviewer personas (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`).
- Claude `*.md` (YAML frontmatter + body) → Codex `*.toml` (`name`, `description`, `sandbox_mode`, `developer_instructions = """..."""`) → Cursor `*.md` (YAML frontmatter + body).
- The Cursor body equals the Codex `developer_instructions`. The Cursor frontmatter keys are only `name`, `description`, `model`, `readonly`, `is_background` — read-only is expressed as `readonly: true`, not a `tools:` list.
- **YAML colon trap (high-frequency failure):** in the Cursor `.md`, any `description` value containing `: ` (colon-space) must be quoted, or the frontmatter fails to parse. The Codex TOML hides this because TOML values are already quoted.
- `name` must equal the filename and the name the skill body dispatches by. Keep all three platforms on the same hyphenated name.

### Hooks
- Claude `settings.json` (`hooks` block) → Codex `hooks.json` → Cursor `hooks.json`. Scripts live under `hooks/<platform>/hooks/`.
- Hop 1 is mostly mechanical: `settings.json` hooks block → `hooks.json`; path `$HOME/.claude/...` → `$HOME/.codex/...`; matcher `Edit|Write|MultiEdit` → `apply_patch|Edit|Write`. The scripts themselves are largely unchanged Claude→Codex.
- Hop 2 is a real event-model remap, not a word-swap: `PreToolUse`(Bash)→`beforeShellExecution`, `PostToolUse`→`afterFileEdit`, `UserPromptSubmit`→`beforeSubmitPrompt`+`stop`. Cursor `hooks.json` needs `"version": 1` and **relative** commands (`./hooks/...`). Script I/O changes: input field `.tool_input.command`→`.command`, blocking via `{"permission":"deny",...}`/exit 2 instead of `exit 2`+stderr, and a trailing `{"permission":"allow"}`/exit 0 on the pass path.
- **doc-drift splits into two scripts on Cursor.** Because `beforeSubmitPrompt` can't inject context, the single Codex `doc-drift-reminder.sh` becomes `doc-drift-flag.sh` (flags on `beforeSubmitPrompt`) + `doc-drift-reminder.sh` (injects via `stop`/`followup_message`). So `hooks/cursor/hooks/` has one more script than `hooks/codex/hooks/`. Expect that asymmetry; don't "fix" it.

## Step 3 — Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .claude/skills/sync-harness/scripts/verify-sync.py
```

It mechanizes the Verify checklists from the MIGRATE docs: tree parity across the three variants, sub-agent frontmatter actually parsing as YAML (the colon trap), `readonly: true` present, skill/agent `name` matching its directory or filename, the residual sweep for leftover `Codex` / `worker` / `explorer` / `sandbox and approval` / Claude-tool references in the Cursor variants (with the intentional allowlist), `hooks.json` being valid JSON with `version: 1` and relative commands, and `bash -n` on every hook script. It exits non-zero and prints what failed. (It checks the whole tree structure, so it's equally valid after a Codex → Cursor run — the Cursor-side checks are the ones that matter there.)

The script catches the mechanical regressions. You still own the judgment calls: read your regenerated files and confirm the meaning survived the transform — a shortened description still triggers, a gated delegation still has its main-session fallback, a remapped hook still blocks what it should. When the checker flags something, fix the file and re-run until it's clean.

## Boundaries

- **Never write to the source variant of the chosen direction.** For Claude → Codex → Cursor, `claude/` is read-only. For Codex → Cursor, `codex/` is read-only. Only ever write the downstream target(s).
- **Migration is one-way.** Never propagate upstream — no Cursor → Codex, no Codex → Claude.
- **Don't deploy.** Installing into `~/.claude`, `~/.codex`, `~/.cursor` is `scripts/apply-to-global.sh`'s job, not this skill's. Leave your changes in the working tree for the user to review.
- **Don't commit** unless the user asks. Migration produces a reviewable diff; let them look before it lands.
- If a MIGRATE doc and this skill's summary ever disagree, the MIGRATE doc wins — and mention the drift so the user can reconcile.
