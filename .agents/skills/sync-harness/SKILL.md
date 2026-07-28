---
name: sync-harness
description: Sync this personal-harness repo's platform variants between Claude and Codex. Use when the user asks to regenerate skills, agents, or hooks for another platform variant in this repo.
---

# Sync Harness

This repo keeps two platform variants of every shared skill, sub-agent, and hook: `claude/` and `codex/`. The supported migration topology is `Claude <-> Codex`: Claude Code is the center of Personal and Codex is the center of Work.

`review-code-claude` is the only platform-specific exception. It is a Codex-only adapter that launches Claude Code, so never create, migrate, or expect a `skills/claude/review-code-claude` counterpart.

Your job is to regenerate target variant(s) so they match the chosen source variant.

The transform rules are not in this skill. They live in two checklists under `docs/sync-harness/`:

- `SYNC_TO_CODEX.md` - Claude -> Codex
- `SYNC_TO_CLAUDE.md` - Codex -> Claude

Read the sections relevant to what you are migrating and apply them faithfully. Prefer those documents over this summary because they are the living authority.

## Step 1 - Get the migration direction

The direction is an explicit user decision. If the user's request already names it, use that direction. Otherwise ask the user before touching files. Supported directions:

- `Claude -> Codex` - Personal to Work.
- `Codex -> Claude` - Work to Personal.

## Scope

Sync all shared artifacts by default: every shared skill, all shared persona sub-agents, and the hook set. If the user names specific artifacts, limit the work to those. Paths are relative to the repo root:

| Artifact | `claude/` | `codex/` |
| --- | --- | --- |
| skill `<name>` | `skills/claude/<name>/` | `skills/codex/<name>/` |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` |
| hooks | `hooks/claude/` | `hooks/codex/` |

For `Claude -> Codex`, `claude/` is the source and `codex/` is the target. For `Codex -> Claude`, `codex/` is the source and `claude/` is the target.

## Step 2 - Migrate per artifact

Read the relevant section of each migration document and apply it. The docs are organized by artifact type: `## Skill migration`, `## Sub-agent migration`, and `## Hook migration`.

### Skills

Skills contain `SKILL.md` plus optional `references/` and `scripts/` subtrees.

- `references/` and `scripts/` copy verbatim across platforms when they are host-neutral. Only `SKILL.md` transforms.
- `Claude -> Codex`: shorten descriptions, gate sub-agent use behind explicit user request when Codex requires it, replace Claude-specific tool names with Codex-safe wording, and map Claude persona agent wording to Codex agent concepts.
- `Codex -> Claude`: preserve Codex's user-facing behavior while restoring Claude Code mechanics such as `Agent` tool dispatch, `subagent_type`, richer Claude descriptions when useful, `AskUserQuestion`, and `ExitPlanMode`.
- Host-neutral skills should stay near-identical. Do not manufacture platform differences when the body has no delegation, plan-mode, or platform-specific terms.

### Sub-agents

The shared persona sub-agents are `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`, and `planner`.

- `Claude -> Codex`: Claude Markdown becomes Codex TOML.
- `Codex -> Claude`: Codex TOML becomes Claude Markdown with YAML frontmatter, `tools:` where appropriate, and body instructions restored to Claude Code terms.
- Quote YAML frontmatter descriptions that contain `: ` so frontmatter parses correctly.
- Keep `name` equal to the filename and to the name used by skill bodies.

### Hooks

Hooks migrate between Claude `settings.json` and Codex `hooks.json`.

- `Claude -> Codex`: `settings.json` hooks block becomes `hooks.json`; `$HOME/.claude/...` becomes `$HOME/.codex/...`; file edit matchers use Codex-safe matcher names.
- `Codex -> Claude`: `hooks.json` hooks block goes into `settings.json`; `$HOME/.codex/...` becomes `$HOME/.claude/...`; `apply_patch|Edit|Write` becomes `Edit|Write|MultiEdit`.
- Documentation-drift checking is intentionally not a hook on any platform. Every platform's `commit-code` skill runs a read-only post-commit check and reports likely updates without editing files.

## Step 3 - Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .agents/skills/sync-harness/scripts/verify-sync.py
```

It checks tree parity, the required `review-code-claude` Codex-only exception, frontmatter parsing, skill and agent names, residual platform-specific terms, hook JSON shape, and `bash -n` for hook scripts. It exits non-zero when failures remain.

The script catches mechanical regressions for the Claude/Codex variants. You still need to read the regenerated files and confirm the meaning survived the transform, especially for `Codex -> Claude` because platform-specific tool, permission, hook, and plan-mode restoration requires judgment. If the checker flags something, fix the file and rerun until it is clean.

## Boundaries

- Never write to the source variant of the chosen direction.
- Claude and Codex can be sources for each other.
- Never propagate the Codex-only `review-code-claude` adapter to Claude.
- Do not deploy; `scripts/apply-to-personal.sh` handles Claude Code installation, and `scripts/apply-to-work.sh` handles Codex installation.
- Do not commit unless the user asks.
- If a migration document and this skill disagree, the migration document wins; mention the drift so the user can reconcile it.
