# personal-harness

A harness of Agent Skills, global instructions, and install scripts for personal use. It supports three platforms — Claude Code, Codex, and OpenCode — and migrates platform variants using the topology below.

- Claude ↔ Codex (bidirectional; Personal center is Claude Code, Work center is Codex)
- Claude → OpenCode (Personal sub-variant; reverse direction not supported)

Per-stage conversion rules are defined in the root files `MIGRATE_TO_CODEX.md`, `MIGRATE_TO_CLAUDE.md`, and `MIGRATE_TO_OPENCODE.md`.

## Folder Structure

- `skills/` — Per-platform Agent Skills. Subdirectories (`claude/`, `codex/`, `opencode/`) separate platform variants. Each skill lives in its own folder.
- `agents/` — Custom sub-agent definitions. Split by platform format: `agents/claude/` (`.md`), `agents/codex/` (`.toml`), `agents/opencode/` (`.md`). Holds persona agents that skills or the user delegate to, such as review, planning, and implementation.
- `hooks/` — Per-platform hook definitions and execution scripts. `hooks/claude/` (`settings.json` snippet + `hooks/*.sh`), `hooks/codex/` (`hooks.json` + `hooks/*.sh`), `hooks/opencode/` (`personal-harness.js` JS plugin). Requires `rg`/`fd` to be installed.
- `instructions/` — The `AGENTS.md` distribution source that defines global commands and development principles for Claude Code, Codex, and OpenCode.
- `scripts/` — Distribution scripts that install and sync skills and global instructions across editors/agents (`apply-to-personal.sh`, `apply-to-work.sh`, `setup-ctx7.sh`).
- `.agents/skills/` — Meta-skills for the harness itself (e.g., `sync-harness` for platform-variant synchronization).
- `references/` — Supplementary materials referenced by skills.

## Core Development Process

The default development flow is assembled from the chain below. Each skill can be used standalone, but typically the output of the previous skill (plan / implementation result / review comments) becomes the input for the next.

```
plan-dev → implement-dev → (fix-dev loop on issues) → test-dev → review-code → (fix-dev loop on issues) → commit-code → request-merge
```

- `plan-dev`: Uses the host agent's built-in Plan mode to draft an implementation plan and persists it under `docs/agents/dev` and `docs/agents/research`. Splits into multi-step (main + sub-plans) when needed.
- `implement-dev`: Executes the plan with TDD (Red-Green-Refactor), writes code, and stores a completion report under `docs/agents/dev`. In the default Dispatcher mode, the main session delegates implementation to a single `implementer` Worker and parses its fixed-heading status to deliver a short summary. In Worker mode, the delegated subagent runs the implementation directly.
- `fix-dev`: Handles defects found during review — root-cause analysis, fix, and verification — and appends a `## Fix` section to the Implementation Report. Does not commit; leaves the working tree as-is.
- `test-dev`: Strengthens the test suite over a git-defined scope (default: diff against `main`). Fills unit/e2e gaps and removes LIVED mutation survivors in sequence; does not modify production/business logic.
- `review-code`: Reviews code changes (diff, PR, branch, etc.) through ISO 25010 quality attributes. On supported platforms, dispatches four persona agents (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`) in parallel and synthesizes findings.
- `commit-code`: Creates a commit based on currently modified files.
- `request-merge`: Creates or updates a Pull Request / Merge Request using the `gh` or `glab` CLI.

## Skills

Each skill under `skills/<platform>/` is managed in its own folder. Skills outside the Core Development Process:

- `spec-creator`: Organizes requirements for a new project into a Korean SPEC.md.
- `setup-initial-repo`: Bootstraps a new repository from a SPEC.md (AGENTS.md/CLAUDE.md, Makefile/package.json, .gitignore, git identity, remote origin).
- `application-research-sync`: Analyzes code changes and batch-updates Research files under `docs/agents/research`.
- `learn-from-manual-edits`: Detects the user's manual edits on top of agent-written code, infers preferences, and records them as conventions in AGENTS.md/CLAUDE.md.
- `find-docs`: Fetches official library/framework documentation via Context7 (`ctx7`).
- `loki-log-search`: Queries Grafana Loki logs via `gcx api`.

## Agents

Persona sub-agent definitions under `agents/<platform>/`. Formats differ by platform (Claude/OpenCode: `.md`, Codex: `.toml`). Persona agents delegated to by skills:

- `planner`: Planning persona that reviews implementation direction, boundaries, interfaces, sequencing, and risks.
- `implementer`: Implementation persona that handles actual code/test/report edits in `implement-dev` Worker mode.
- `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`: The four review personas dispatched in parallel by `review-code`.

## Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

- `session-context.sh`: On SessionStart, classifies the repo as work/personal using `WORK_GITLAB_HOST` and the origin remote, and injects session context.
- `git-identity-guard.sh`: Verifies git identity at commit time.
- `enforce-rg.sh`, `enforce-fd.sh`: Enforces `rg`/`fd` for code and file searches.
- `auto-format.sh`: Runs the project Makefile's `fmt`/`format` target.
- `doc-drift-reminder.sh`: Detects documentation sync drift from changed files and alerts.

Platform-specific config files: Claude Code uses the `hooks` block in `settings.json`, Codex uses `hooks.json`, and OpenCode uses the `personal-harness.js` JS plugin. `jq`·`git`·`make`·`rg`·`fd`·`node` are required (see README.md Prerequisites for details).
