---
name: sync-harness
description: Sync this personal-harness repo's platform variants across Claude and Codex, from Codex to Cursor, and from Claude to OpenCode. Use when the user asks to regenerate skills, agents, or hooks for another platform variant in this repo.
---

# Sync Harness

This repo keeps four platform variants of every skill, sub-agent, and hook: `claude/`, `codex/`, `cursor/`, and `opencode/`. The supported migration topology is `Claude <-> Codex`, `Codex -> Cursor`, and `Claude -> OpenCode`. Claude Code is the center of Personal, Codex is the center of Work, Cursor is a Work subvariant derived only from Codex, and OpenCode is a Personal subvariant derived only from Claude Code.

Your job is to regenerate target variant(s) so they match the chosen source variant.

The transform rules are not in this skill. They live in four checklists at the repo root:

- `MIGRATE_TO_CODEX.md` - Claude -> Codex
- `MIGRATE_TO_CLAUDE.md` - Codex -> Claude
- `MIGRATE_TO_CURSOR.md` - Codex -> Cursor
- `MIGRATE_TO_OPENCODE.md` - Claude -> OpenCode

Read the sections relevant to what you are migrating and apply them faithfully. Prefer those documents over this summary because they are the living authority.

## Step 1 - Get the migration direction

The direction is an explicit user decision. If the user's request already names it, use that direction. Otherwise ask the user before touching files. Supported directions:

- `Claude -> Codex` - Personal to Work.
- `Claude -> Codex -> Cursor` - Personal to Work, then update Cursor from Codex.
- `Claude -> OpenCode` - Personal to Personal subvariant.
- `Claude -> Codex + OpenCode` - Personal updates shared to Work and OpenCode.
- `Claude -> Codex -> Cursor + OpenCode` - Personal updates shared to Work, Cursor, and OpenCode.
- `Codex -> Claude` - Work to Personal.
- `Codex -> Cursor` - Work to Cursor.
- `Codex -> Claude + Cursor` - Work updates shared to Personal and Cursor.
- `Codex -> Claude -> OpenCode` - Work updates shared to Personal, then OpenCode from the refreshed Claude variant.
- `Codex -> Claude + Cursor + OpenCode` - Work updates shared to Personal, Cursor, and OpenCode; derive Cursor from Codex and OpenCode from the refreshed Claude variant.

Cursor and OpenCode are never sources. If the user asks for `Cursor -> Codex` or `Cursor -> Claude`, explain that Cursor is Work's downstream variant and offer `Codex -> Cursor` instead. If the user asks for `OpenCode -> Claude`, `OpenCode -> Codex`, or `OpenCode -> Cursor`, explain that OpenCode is Personal's downstream variant and offer `Claude -> OpenCode` after refreshing Claude from the intended source if needed.

## Scope

Sync all shared artifacts by default: every shared skill, all reviewer sub-agents, and the hook set. If the user names specific artifacts, limit the work to those. Paths are relative to the repo root:

| Artifact | `claude/` | `codex/` | `cursor/` | `opencode/` |
| --- | --- | --- | --- | --- |
| skill `<name>` | `skills/claude/<name>/` | `skills/codex/<name>/` | `skills/cursor/<name>/` | `skills/opencode/<name>/` |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` | `agents/cursor/<name>.md` | `agents/opencode/<name>.md` |
| hooks | `hooks/claude/` | `hooks/codex/` | `hooks/cursor/` | `hooks/opencode/` |

For `Claude -> Codex`, `claude/` is the source and `codex/` is the target. For `Codex -> Claude`, `codex/` is the source and `claude/` is the target. For `Codex -> Cursor`, `codex/` is the source and `cursor/` is the target. For `Claude -> OpenCode`, `claude/` is the source and `opencode/` is the target. Composite directions apply those hops in order without using Cursor or OpenCode as an intermediate source, except that a freshly regenerated Claude target becomes the source for a following `Claude -> OpenCode` hop.

## Why Cursor and OpenCode are target-only

Cursor variants are Work subvariants derived from Codex, not from Claude. When a Claude change needs Cursor, regenerate Codex first, then derive Cursor from the freshly regenerated Codex. When a Codex change needs both Claude and Cursor, derive both targets from the same Codex source.

OpenCode variants are Personal subvariants derived from Claude Code, not from Codex or Cursor. When a Codex change needs OpenCode, regenerate Claude first, then derive OpenCode from the refreshed Claude variant. When a Claude change needs OpenCode, derive OpenCode directly from Claude.

## Work-only skill exceptions

`loki-log-search` is Work-only. It must exist only under `skills/codex/loki-log-search` and `skills/cursor/loki-log-search`, and must not be propagated to Claude Code or OpenCode. When this skill changes, use `Codex -> Cursor` only. Do not force shared tree parity by creating `skills/claude/loki-log-search` or `skills/opencode/loki-log-search`.

## Step 2 - Migrate per artifact

Read the relevant section of each migration document and apply it. The docs are organized by artifact type: `## Skill migration`, `## Sub-agent migration`, and `## Hook migration`.

### Skills

Skills contain `SKILL.md` plus optional `references/` and `scripts/` subtrees.

- `references/` and `scripts/` copy verbatim across platforms when they are host-neutral. Only `SKILL.md` transforms.
- `Claude -> Codex`: shorten descriptions, gate sub-agent use behind explicit user request when Codex requires it, replace Claude-specific tool names with Codex-safe wording, and map Claude persona agent wording to Codex agent concepts.
- `Codex -> Claude`: preserve Codex's user-facing behavior while restoring Claude Code mechanics such as `Agent` tool dispatch, `subagent_type`, richer Claude descriptions when useful, `AskUserQuestion`, and `ExitPlanMode`.
- `Codex -> Cursor`: apply the wording and execution-model changes in `MIGRATE_TO_CURSOR.md` while preserving Codex behavior. Delegation remains gated on explicit user request when that is the Work policy.
- `Claude -> OpenCode`: apply the wording and execution-model changes in `MIGRATE_TO_OPENCODE.md`; replace Claude Code tool names with OpenCode-safe wording, map `Agent` tool dispatch to OpenCode's Task tool, and convert plan-mode instructions to OpenCode Plan/Build mode.
- Host-neutral skills should stay near-identical. Do not manufacture platform differences when the body has no delegation, plan-mode, or platform-specific terms.

### Sub-agents

The reviewer personas are `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, and `senior-generalist-reviewer`.

- `Claude -> Codex`: Claude Markdown becomes Codex TOML.
- `Codex -> Claude`: Codex TOML becomes Claude Markdown with YAML frontmatter, `tools:` where appropriate, and body instructions restored to Claude Code terms.
- `Codex -> Cursor`: Codex TOML becomes Cursor Markdown; Cursor reviewers use `readonly: true`.
- `Claude -> OpenCode`: Claude Markdown becomes OpenCode Markdown; use OpenCode frontmatter and `permission:` blocks, not Claude `tools:` allowlists.
- Quote YAML frontmatter descriptions that contain `: ` so frontmatter parses correctly.
- Keep `name` equal to the filename and to the name used by skill bodies.

### Hooks

Hooks migrate between Claude `settings.json`, Codex `hooks.json`, and Cursor `hooks.json`.

- `Claude -> Codex`: `settings.json` hooks block becomes `hooks.json`; `$HOME/.claude/...` becomes `$HOME/.codex/...`; file edit matchers use Codex-safe matcher names.
- `Codex -> Claude`: `hooks.json` hooks block goes into `settings.json`; `$HOME/.codex/...` becomes `$HOME/.claude/...`; `apply_patch|Edit|Write` becomes `Edit|Write|MultiEdit`.
- `Codex -> Cursor`: remap the event model according to `MIGRATE_TO_CURSOR.md`; do not treat it as a simple word swap.
- `Claude -> OpenCode`: convert the Claude shell-hook set into the OpenCode JS plugin according to `MIGRATE_TO_OPENCODE.md`; OpenCode does not use Claude/Codex/Cursor shell-hook JSON.
- Cursor `hooks.json` needs `"version": 1` and relative `./hooks/...` commands.
- doc-drift is a single stop hook on every platform (Codex/Claude `Stop`, Cursor `stop`, OpenCode `session.idle`); `hooks/cursor/hooks/` no longer carries an extra `doc-drift-flag.sh`, so the Cursor script count matches Codex.

## Step 3 - Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .agents/skills/sync-harness/scripts/verify-sync.py
```

It checks tree parity, frontmatter parsing, skill and agent names, residual platform-specific terms, hook JSON shape, and `bash -n` for hook scripts. It exits non-zero when failures remain.

The script catches mechanical regressions for the Claude/Codex/Cursor variants. You still need to read the regenerated files and confirm the meaning survived the transform, especially for `Codex -> Claude` and `Claude -> OpenCode` because platform-specific tool, permission, hook, and plan-mode restoration requires judgment. If the checker flags something, fix the file and rerun until it is clean. For OpenCode changes, also manually verify the relevant `MIGRATE_TO_OPENCODE.md` checklist because OpenCode uses a different plugin and permission model.

## Boundaries

- Never write to the source variant of the chosen direction.
- Claude and Codex can be sources for each other; Cursor and OpenCode are target-only.
- Never propagate from Cursor to Codex or Claude, and never propagate from OpenCode to Claude, Codex, or Cursor.
- Do not deploy; `scripts/apply-to-personal.sh` handles Claude Code and OpenCode installation, and `scripts/apply-to-work.sh` handles Codex and Cursor installation.
- Do not commit unless the user asks.
- If a migration document and this skill disagree, the migration document wins; mention the drift so the user can reconcile it.
