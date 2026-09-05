---
name: sync-harness
description: Sync this personal-harness repo's platform variants between Claude and Codex. Use when the user asks to regenerate agents or hooks for another platform variant in this repo.
---

# Sync Harness

Product skills live in one shared tree: `skills/<name>/`. Do not fork them per platform. This skill migrates **agents and hooks** between Claude and Codex. Cursor and Grok Build stay one-way derivatives of Claude for agents and hooks (`Claude → Cursor`, `Claude → Grok`).

Your job is to regenerate target **agent and hook** variant(s) so they match the chosen source variant. Shared skills are not a migration target.

The transform rules are not in this skill. They live in checklists under `docs/sync-harness/`:

- `SYNC_TO_CODEX.md` - Claude -> Codex (agents, hooks)
- `SYNC_TO_CLAUDE.md` - Codex -> Claude (agents, hooks)
- Shared skill invariants live in `SYNC_TO_CODEX.md` § Shared skills — apply them when editing `skills/<name>/`, never by copying a platform fork.

Read the sections relevant to what you are migrating and apply them faithfully. Prefer those documents over this summary because they are the living authority.

## Step 1 - Get the migration direction

The direction is an explicit user decision. If the user's request already names it, use that direction. Otherwise ask the user before touching files. Supported directions:

- `Claude -> Codex`
- `Codex -> Claude`

## Scope

Sync shared **agents and hooks** by default. Skills are the shared tree `skills/<name>/` — do not create `skills/claude/` or `skills/codex/`. If the user names specific artifacts, limit the work to those. Paths are relative to the repo root:

| Artifact | `claude/` | `codex/` |
| --- | --- | --- |
| skill `<name>` | `skills/<name>/` (shared; not migrated) | same |
| sub-agent `<name>` | `agents/claude/<name>.md` | `agents/codex/<name>.toml` |
| hooks | `hooks/claude/` | `hooks/codex/` |

For `Claude -> Codex`, `agents/claude/` and `hooks/claude/` are the source. For `Codex -> Claude`, `agents/codex/` and `hooks/codex/` are the source.

## Step 2 - Migrate per artifact

Read the relevant section of each migration document and apply it. The docs are organized by artifact type: `## Shared skills`, `## Sub-agent migration`, and `## Hook migration`.

### Skills

Do not convert skills between platforms. Edit `skills/<name>/` in place under the shared-skill invariants (no host tool names, `$HOME/.agents/scripts`, short Codex-length descriptions, `needs-design-decision` as common status vocabulary). `references/` stay host-neutral.

### Sub-agents

The shared persona sub-agents are `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`, `planner`, `plan-consultant`, `implementer`, `tester`, and `fixer`.

- `Claude -> Codex`: Claude Markdown becomes Codex TOML.
- `Codex -> Claude`: Codex TOML becomes Claude Markdown with YAML frontmatter, `tools:` where appropriate, and body instructions restored to Claude Code terms.
- Quote YAML frontmatter descriptions that contain `: ` so frontmatter parses correctly.
- Keep `name` equal to the filename.

### Hooks

Hooks migrate between Claude `settings.json` and Codex `hooks.json`.

- `Claude -> Codex`: `settings.json` hooks block becomes `hooks.json`; `$HOME/.claude/...` becomes `$HOME/.codex/...`; file edit matchers use Codex-safe matcher names.
- `Codex -> Claude`: `hooks.json` hooks block goes into `settings.json`; `$HOME/.codex/...` becomes `$HOME/.claude/...`; `apply_patch|Edit|Write` becomes `Edit|Write|MultiEdit`.
- Do not put `permissions` in `hooks/claude/settings.json`. Claude script allows are appended at install time.
- Documentation-drift checking is intentionally not a hook on any platform. Every platform's `commit-code` skill runs a read-only post-commit check and reports likely updates without editing files.

## Step 3 - Verify

After migrating, run the bundled checker from the repo root:

```bash
python3 .agents/skills/sync-harness/scripts/verify-sync.py
```

It checks the shared skill tree, residual host tokens in skills, agent and hook parity, hook JSON shape, and `bash -n` for hook scripts. It exits non-zero when failures remain.

You still need to read the regenerated agent/hook files and confirm the meaning survived the transform. If the checker flags something, fix the file and rerun until it is clean.

## Boundaries

- Never write to the source variant of the chosen direction.
- Claude and Codex can be sources for each other for agents and hooks only.
- Do not create `skills/{claude,codex,cursor,grok}/`.
- Do not deploy; `scripts/apply-to.sh claude|codex|cursor|grok` handles installation.
- Do not commit unless the user asks.
- If a migration document and this skill disagree, the migration document wins; mention the drift so the user can reconcile it.
