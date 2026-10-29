# personal-harness

A harness of Agent Skills, global instructions, hooks, and install scripts for personal use. It supports four platforms — Claude Code, Codex, Cursor, and Grok Build. Skills are shared (`skills/<name>/` → `~/.agents/skills`). Hooks migrate using the topology below.

- Claude ↔ Codex (bidirectional)
- Claude → Cursor (one-way; a change that starts in Cursor lands in the Claude variant first)
- Claude → Grok Build (one-way; pure Grok paths only — do not rely on Grok's Claude/Cursor compat scanners)

Per-platform conversion rules are defined in `docs/sync-harness/` (`SYNC_TO_CODEX.md`, `SYNC_TO_CLAUDE.md`, `SYNC_TO_CURSOR.md`, and `SYNC_TO_GROK.md`). There is no sync skill — read the relevant checklist and apply it directly.

## Design

The harness supplies what a current model cannot work out for itself: environment and tool knowledge (Jira, Notion, GitLab, Loki, Context7, git identity), deterministic guardrails (hooks), and a few habits that make "done" checkable. It does not prescribe a development workflow — planning, implementing, and verifying are left to the model.

Before adding a skill or instruction, run the task once without it and confirm the model actually gets it wrong. Process instructions a stronger model no longer needs are removed, not kept as insurance. The previous loop-based harness (a plan → implement → test → review state machine with persona sub-agents) is preserved at the `pre-lean-harness` tag.

## Development

```
plan-dev → implement in the same session → /goal <done-when condition> → test-dev (fresh context) → review → commit-code
```

Every step is optional and scales with the work; a one-sentence change needs none of them.

- **`plan-dev`** settles what "done" means (observable state + evidence), what is out of scope, and what must not change, then hands the "done when" items back as one completion condition.
- **`/goal`** (Claude Code) keeps the session working until a small evaluator judges the condition met. The evaluator only reads the conversation, so the condition must ask for command output (`make test exits 0`), not a claim, and should carry a turn cap. Use it for long or unattended work.
- **`test-dev`** fills test gaps from the diff in a context that did not write the code, and reports suspected defects instead of fixing production code.
- **Review** uses the host's built-in review (Claude Code: `/code-review`, plus `/security-review` for changes touching authn/authz, secrets, concurrency, or partial-failure paths).
- Commits stay human-owned (`commit-code`).

## Harness

### Skills

Each skill under `skills/<name>/` is shared across hosts. See each skill's `SKILL.md` for the full contract. Install lives in `~/.agents/skills`; Claude uses per-skill symlinks from `~/.claude/skills`. Third-party skills are not vendored: `EXTERNAL_SKILLS` in `scripts/install-shared.sh` lists them and `apply-to.sh` installs them into `~/.agents/skills` via `npx skills add` — currently the official Notion `notion-cli` (`makenotion/skills`). `RETIRED_SKILLS`, `RETIRED_AGENTS`, and `RETIRED_SCRIPTS` in the same file list what the harness used to install, so the installer deletes old copies.

**Development:**

| Skill | Description | Artifacts |
| --- | --- | --- |
| `plan-dev` | Investigates the repo and settles done-when / out-of-scope / do-not-touch with the user; offers the done-when items as a goal condition | Plan in the conversation; a file under `docs/agents/dev` only for multi-session or hand-off work |
| `test-dev` | Fresh-context test hardening over a git scope (default: diff vs `main`); test code only; suspected defects are reported, never fixed | Test code (no file artifact) |
| `commit-code` | Creates a commit; runs a read-only documentation-drift check afterward. Opens a PR (`gh`, personal) or MR (`glab`, work) only when the prompt asks (`request-merge` is a routing alias). Dirty tree + PR request: commit first | Commit · (optional) PR/MR |

The remaining skills (`spec-creator`, `setup-initial-repo`, `learn-from-manual-edits`, `chat-summary`, `notion-daily-briefing`, `loki-log-search`) carry project-bootstrap, note-taking, and work-tool knowledge.

### Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

| Hook | When | Role |
| --- | --- | --- |
| `session-context.sh` | Session start | Classifies the repo as work/personal via `WORK_GITLAB_HOST` + origin remote and injects session context |
| `git-identity-guard.sh` | Before Bash | Verifies git identity at commit time |
| `enforce-rg.sh` | Before Bash | Enforces `rg` over recursive `grep` |
| `enforce-fd.sh` | Before Bash | Enforces `fd` over `find` |
| `auto-format.sh` | After file edits | Runs the project Makefile's `fmt`/`format` target |

Platform-specific config files: Claude Code uses the `hooks` block in `settings.json`; Codex, Cursor, and Grok use `hooks.json` (schemas differ — Cursor's is flat, see `SYNC_TO_CURSOR.md`; Grok installs as `~/.grok/hooks/harness.json` and merges all `~/.grok/hooks/*.json`). Hooks are guardrails, not workflow. `jq`·`git`·`make`·`rg`·`fd` are required (see README.md Prerequisites for details).

## Environment Variables

Skills and hooks read these from the host agent's env configuration (Claude Code `settings.json` `env`, Codex `config.toml` `shell_environment_policy.set`):

| Variable | Purpose |
| --- | --- |
| `PERSONAL_GIT_EMAIL` / `PERSONAL_GIT_NAME` | Git identity for personal-repo commits |
| `WORK_GIT_EMAIL` / `WORK_GIT_NAME` | Git identity for work-repo commits |
| `WORK_GITLAB_HOST` | Work GitLab host; drives work/personal repo classification; `notion-daily-briefing` derives its `glab --hostname` from it |
| `WORK_GITLAB_USERNAME` | `--assignee` when creating MRs |
| `WORK_GITLAB_DEFAULT_REVIEWERS` | `--reviewer` when creating MRs |
| `NOTION_DAILY_NOTES_DS_ID` / `NOTION_DAILY_NOTE_TEMPLATE_ID` | Daily Notes data source and Daily Note template used by `notion-daily-briefing` |
