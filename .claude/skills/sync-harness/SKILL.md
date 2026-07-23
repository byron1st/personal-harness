---
name: sync-harness
description: Sync this personal-harness repo's platform variants across Claude and Codex, and from Claude to OpenCode. Use when the user asks to regenerate skills, agents, or hooks for another platform variant in this repo.
---

# Sync Harness

This repo keeps three platform variants of every skill, sub-agent, and hook: `claude/`, `codex/`, and `opencode/`. The supported migration topology is `Claude <-> Codex` and `Claude -> OpenCode`. Claude Code is the center of Personal, Codex is the center of Work, and OpenCode is a Personal subvariant derived only from Claude Code.

Your job is to regenerate target variant(s) so they match the chosen source variant.

The transform rules are not in this skill. They live in three checklists under `docs/sync-harness/`:

- `SYNC_TO_CODEX.md` - Claude -> Codex
- `SYNC_TO_CLAUDE.md` - Codex -> Claude
- `SYNC_TO_OPENCODE.md` - Claude -> OpenCode

Read the sections relevant to what you are migrating and apply them faithfully. Prefer those documents over this summary because they are the living authority.

## Step 1 - Get the migration direction

The direction is an explicit user decision. If the user's request already names it, use that direction. Otherwise ask the user before touching files. Supported directions:

- `Claude -> Codex` - Personal to Work.
- `Claude -> OpenCode` - Personal to Personal subvariant.
- `Claude -> Codex + OpenCode` - Personal updates shared to Work and OpenCode.
- `Codex -> Claude` - Work to Personal.
- `Codex -> Claude -> OpenCode` - Work updates shared to Personal, then OpenCode from the refreshed Claude variant.

OpenCode is never a source. If the user asks for `OpenCode -> Claude` or `OpenCode -> Codex`, explain that OpenCode is Personal's downstream variant and offer `Claude -> OpenCode` after refreshing Claude from the intended source if needed.

## Scope

Sync all shared artifacts by default: every shared skill, all shared persona sub-agents, and the hook set. If the user names specific artifacts, limit the work to those. Paths are relative to the repo root:

| Artifact | `claude/` | `codex/` | `opencode/` |
| --- | --- | --- | --- |
| skill `<name>` | `skills/claude/<name>/` | `skills/codex/<name>/` | `skills/opencode/<name>/` |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` | `agents/opencode/<name>.md` |
| hooks | `hooks/claude/` | `hooks/codex/` | `hooks/opencode/` |

For `Claude -> Codex`, `claude/` is the source and `codex/` is the target. For `Codex -> Claude`, `codex/` is the source and `claude/` is the target. For `Claude -> OpenCode`, `claude/` is the source and `opencode/` is the target. Composite directions apply those hops in order without using OpenCode as an intermediate source, except that a freshly regenerated Claude target becomes the source for a following `Claude -> OpenCode` hop.

## Why OpenCode is target-only

OpenCode variants are Personal subvariants derived from Claude Code, not from Codex. When a Codex change needs OpenCode, regenerate Claude first, then derive OpenCode from the refreshed Claude variant. When a Claude change needs OpenCode, derive OpenCode directly from Claude.

## Step 2 - Migrate per artifact

Read the relevant section of each migration document and apply it. The docs are organized by artifact type: `## Skill migration`, `## Sub-agent migration`, and `## Hook migration`.

### Skills

Skills contain `SKILL.md` plus optional `references/` and `scripts/` subtrees.

- `references/` and `scripts/` copy verbatim across platforms when they are host-neutral. Only `SKILL.md` transforms.
- `Claude -> Codex`: shorten descriptions, gate sub-agent use behind explicit user request when Codex requires it, replace Claude-specific tool names with Codex-safe wording, and map Claude persona agent wording to Codex agent concepts.
- `Codex -> Claude`: preserve Codex's user-facing behavior while restoring Claude Code mechanics such as `Agent` tool dispatch, `subagent_type`, richer Claude descriptions when useful, `AskUserQuestion`, and `ExitPlanMode`.
- `Claude -> OpenCode`: apply the wording and execution-model changes in `SYNC_TO_OPENCODE.md`; replace Claude Code tool names with OpenCode-safe wording, map `Agent` tool dispatch to OpenCode's Task tool, and convert plan-mode instructions to OpenCode Plan/Build mode.
- Host-neutral skills should stay near-identical. Do not manufacture platform differences when the body has no delegation, plan-mode, or platform-specific terms.

### Sub-agents

The shared persona sub-agents are `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`, and `planner`.

- `Claude -> Codex`: Claude Markdown becomes Codex TOML.
- `Codex -> Claude`: Codex TOML becomes Claude Markdown with YAML frontmatter, `tools:` where appropriate, and body instructions restored to Claude Code terms.
- `Claude -> OpenCode`: Claude Markdown becomes OpenCode Markdown; use OpenCode frontmatter and `permission:` blocks, not Claude `tools:` allowlists.
- Quote YAML frontmatter descriptions that contain `: ` so frontmatter parses correctly.
- Keep `name` equal to the filename and to the name used by skill bodies.

### Hooks

Hooks migrate between Claude `settings.json` and Codex `hooks.json`.

- `Claude -> Codex`: `settings.json` hooks block becomes `hooks.json`; `$HOME/.claude/...` becomes `$HOME/.codex/...`; file edit matchers use Codex-safe matcher names.
- `Codex -> Claude`: `hooks.json` hooks block goes into `settings.json`; `$HOME/.codex/...` becomes `$HOME/.claude/...`; `apply_patch|Edit|Write` becomes `Edit|Write|MultiEdit`.
- `Claude -> OpenCode`: convert the Claude shell-hook set into the OpenCode JS plugin according to `SYNC_TO_OPENCODE.md`; OpenCode does not use Claude/Codex shell-hook JSON.
- Documentation-drift checking is intentionally not a hook on any platform. Every platform's `commit-code` skill runs a read-only post-commit check and reports likely updates without editing files.

## Step 3 - Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .agents/skills/sync-harness/scripts/verify-sync.py
```

It checks tree parity, frontmatter parsing, skill and agent names, residual platform-specific terms, hook JSON shape, and `bash -n` for hook scripts. It exits non-zero when failures remain.

The script catches mechanical regressions for the Claude/Codex variants. You still need to read the regenerated files and confirm the meaning survived the transform, especially for `Codex -> Claude` and `Claude -> OpenCode` because platform-specific tool, permission, hook, and plan-mode restoration requires judgment. If the checker flags something, fix the file and rerun until it is clean. For OpenCode changes, also manually verify the relevant `SYNC_TO_OPENCODE.md` checklist because OpenCode uses a different plugin and permission model.

## Boundaries

- Never write to the source variant of the chosen direction.
- Claude and Codex can be sources for each other; OpenCode is target-only.
- Never propagate from OpenCode to Claude or Codex.
- Do not deploy; `scripts/apply-to-personal.sh` handles Claude Code and OpenCode installation, and `scripts/apply-to-work.sh` handles Codex installation.
- Do not commit unless the user asks.
- If a migration document and this skill disagree, the migration document wins; mention the drift so the user can reconcile it.
