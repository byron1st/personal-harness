---
name: sync-harness
description: Propagate this personal-harness repo's platform variants across the supported migration topology — Claude ↔ Codex, and Codex → Cursor. Use whenever a skill, sub-agent, or hook needs another platform variant regenerated, including Personal→Work, Work→Personal, Work→Cursor, or Work→Personal+Cursor sync. Cursor is downstream only; never sync from Cursor back to Claude or Codex.
---

# Sync Harness

This repo keeps three platform variants of every skill, sub-agent, and hook: `claude/`, `codex/`, `cursor/`. The supported migration topology is **Claude ↔ Codex** and **Codex → Cursor**. Claude Code is the center of Personal, Codex is the center of Work, and Cursor is a Work subvariant derived only from Codex.

Your job is to regenerate target variant(s) so they match the chosen source variant.

The transform rules are **not** in this skill. They live in three checklists at the repo root that the user maintains:

- `MIGRATE_TO_CODEX.md` — Claude → Codex
- `MIGRATE_TO_CLAUDE.md` — Codex → Claude Code
- `MIGRATE_TO_CURSOR.md` — Codex → Cursor

These are the living authority. Read the sections relevant to what you're migrating and apply them faithfully — prefer them over anything summarized here, because they get updated and this skill must not drift from them.

## Step 1 — Get the migration direction (ask explicitly)

The direction is an explicit decision the user makes — don't infer it from git history or anything else. If the user's request already names it, use that direction ("sync work back to personal" → Codex → Claude; "rebuild the cursor variants from codex" → Codex → Cursor; "sync personal changes to work and cursor" → Claude → Codex → Cursor). Otherwise **ask the user with AskUserQuestion before touching any files.** Supported directions:

- **Claude → Codex** — Personal to Work. Claude is the source; regenerate the Codex variant.
- **Claude → Codex → Cursor** — Personal to Work, then update Cursor from the freshly regenerated Codex variant.
- **Codex → Claude** — Work to Personal. Codex is the source; regenerate the Claude Code variant.
- **Codex → Cursor** — Work to Cursor. Codex is the source; regenerate just the Cursor variant.
- **Codex → Claude + Cursor** — Work updates shared to Personal and Cursor. Codex is the source; regenerate Claude and Cursor as independent targets from Codex.

Cursor is never a source. If the user asks for a reverse sync from Cursor ("update codex from cursor", "sync cursor back to claude"), explain that Cursor is Work's downstream variant and offer the closest supported direction from Codex instead.

### What to migrate (scope)

Once the direction is set, sync **all** artifacts by default — every skill, all four reviewer sub-agents, and the hook set — so nothing target-side is left stale. If the user named specific artifacts ("just the review-code skill", "only the hooks"), limit to those. Paths, relative to the repo root:

| Artifact | `claude/` | `codex/` | `cursor/` |
| --- | --- | --- | --- |
| skill `<name>` | `skills/claude/<name>/` | `skills/codex/<name>/` | `skills/cursor/<name>/` |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` | `agents/cursor/<name>.md` |
| hooks | `hooks/claude/` | `hooks/codex/` | `hooks/cursor/` |

For Claude → Codex, `claude/` is the source and `codex/` is the target. For Claude → Codex → Cursor, regenerate `codex/` first, then regenerate `cursor/` from that Codex result. For Codex → Claude, `codex/` is the source and `claude/` is the target. For Codex → Cursor, `codex/` is the source and `cursor/` is the target. For Codex → Claude + Cursor, derive both targets from the same Codex source; do not use one generated target as the source for the other.

## Why Cursor only derives from Codex

Cursor variants are Work subvariants derived from **Codex**, not from Claude — the Cursor sub-agent body is the Codex `developer_instructions` reformatted, and the Cursor skill body is the Codex body with execution-model terms swapped. So when a Claude change needs Cursor, regenerate Codex first, then derive Cursor from that freshly regenerated Codex. When a Codex change needs both Personal and Cursor updates, apply Codex → Claude and Codex → Cursor as two target hops from the same Codex source.

## Step 2 — Migrate, per artifact

Read the relevant section of each MIGRATE doc and apply it. The docs are organized by artifact type (`## Skill migration`, `## Sub-agent migration`, `## Hook migration`). For composite directions, apply each hop in order and keep the chosen source variant read-only.

Here is the structural shape of each transform so you know what you're producing. **The detailed rules — field mappings, what to strip, the gotchas — are in the MIGRATE docs; read them.**

### Skills

`skills/<platform>/<name>/SKILL.md` plus a `references/` and/or `scripts/` subtree.

- **`references/` and `scripts/` copy verbatim** across platforms when they are host-neutral. Only `SKILL.md` (frontmatter + body) transforms.
- Claude → Codex: shorten the `description` to a trigger-focused sentence or two; gate sub-agent use behind explicit user request when Codex requires it; replace Claude tool names (`Agent`/`subagent_type`, `Read`/`Grep`/`AskUserQuestion`, `ExitPlanMode`) with Codex wording; map persona agents to Codex agent concepts.
- Codex → Claude: preserve Codex's user-facing behavior while restoring Claude Code mechanics such as `Agent` tool dispatch, `subagent_type`, richer Claude descriptions when useful, `AskUserQuestion`, `ExitPlanMode`, and Claude Code permission/tool assumptions.
- Codex → Cursor: mostly word-swaps and execution-model remapping — "Codex"→"Cursor", "Codex custom agent"→"Cursor custom subagent (Task tool)", "Codex `explorer`"→"Cursor built-in `Explore`", strip "sandbox and approval" execution-model terms — while **keeping the Codex behavior**.
- **Host-neutral skills are near-identical copies.** If a skill's body has no delegation, no plan-mode, and no platform terms, don't manufacture differences.

### Sub-agents

The four reviewer personas (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`).

- Claude → Codex: Claude `*.md` (YAML frontmatter + body) → Codex `*.toml` (`name`, `description`, `sandbox_mode`, `developer_instructions = """..."""`).
- Codex → Claude: Codex `*.toml` → Claude `*.md` (YAML frontmatter + body), restoring Claude Code `tools:` allowlists and richer delegation descriptions where useful.
- Codex → Cursor: Codex `*.toml` → Cursor `*.md` (YAML frontmatter + body). The Cursor body equals the Codex `developer_instructions`; read-only is expressed as `readonly: true`, not a `tools:` list.
- **YAML colon trap:** in Claude or Cursor Markdown frontmatter, any `description` value containing `: ` (colon-space) must be quoted, or the frontmatter can fail to parse.
- `name` must equal the filename and the name the skill body dispatches by. Keep all three platforms on the same hyphenated name.

### Hooks

Hooks move among Claude `settings.json` (`hooks` block), Codex `hooks.json`, and Cursor `hooks.json`. Scripts live under `hooks/<platform>/hooks/`.

- Claude → Codex: `settings.json` hooks block → `hooks.json`; path `$HOME/.claude/...` → `$HOME/.codex/...`; matcher `Edit|Write|MultiEdit` → `apply_patch|Edit|Write`.
- Codex → Claude: `hooks.json` hooks block → `settings.json`; path `$HOME/.codex/...` → `$HOME/.claude/...`; matcher `apply_patch|Edit|Write` → `Edit|Write|MultiEdit`.
- Codex → Cursor: event-model remap, not a word-swap: `PreToolUse`(Bash)→`beforeShellExecution`, `PostToolUse`→`afterFileEdit`, `UserPromptSubmit`→`beforeSubmitPrompt`+`stop`. Cursor `hooks.json` needs `"version": 1` and relative commands (`./hooks/...`).
- **doc-drift splits into two scripts on Cursor.** Because `beforeSubmitPrompt` can't inject context, the single Codex `doc-drift-reminder.sh` becomes `doc-drift-flag.sh` (flags on `beforeSubmitPrompt`) + `doc-drift-reminder.sh` (injects via `stop`/`followup_message`). So `hooks/cursor/hooks/` has one more script than `hooks/codex/hooks/`. Expect that asymmetry; don't "fix" it.

## Step 3 — Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .claude/skills/sync-harness/scripts/verify-sync.py
```

It mechanizes the Verify checklists from the MIGRATE docs where possible: tree parity across the three variants, sub-agent frontmatter actually parsing as YAML, `readonly: true` present for Cursor reviewers, skill/agent `name` matching its directory or filename, the residual sweep for leftover Codex execution-model terms in Cursor variants, `hooks.json` shape, and `bash -n` on every hook script. It exits non-zero and prints what failed.

The script catches mechanical regressions. You still own the judgment calls: read your regenerated files and confirm the meaning survived the transform. Codex → Claude especially requires manual review because restoring Claude Code tool names, plan-mode mechanics, and subagent dispatch policy is not fully mechanical. When the checker flags something, fix the file and re-run until it's clean.

## Boundaries

- **Never write to the source variant of the chosen direction.** For Claude-sourced directions, `claude/` is read-only. For Codex-sourced directions, `codex/` is read-only.
- **Claude and Codex are mutually shareable sources.** Personal centers on Claude Code; Work centers on Codex.
- **Cursor is target-only.** Never propagate Cursor → Codex or Cursor → Claude.
- **Don't deploy.** Installing into `~/.claude` is `scripts/apply-to-personal.sh`'s job, and installing into `~/.codex` / `~/.cursor` is `scripts/apply-to-work.sh`'s job. Leave your changes in the working tree for the user to review.
- **Don't commit** unless the user asks. Migration produces a reviewable diff; let them look before it lands.
- If a MIGRATE doc and this skill's summary ever disagree, the MIGRATE doc wins — and mention the drift so the user can reconcile.
