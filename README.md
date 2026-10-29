# My personal harness

**English** | [한국어](README.ko.md)

A harness of Agent Skills, global instructions, hooks, and install scripts for personal use.

Work usage burns quota in **Cursor → Claude → Codex** order (cheapest-approval-friction pool first). Personal projects use **Grok Build** (SuperGrok subscription quota).

## Usage

The harness does not prescribe a development workflow. Describe what you want built — what "done" means, what is out of scope, what must not change — and let the model plan and implement in its own way. Skills supply only what the model cannot know by itself: tool and environment knowledge, plus a few habits that make "done" checkable. See [Development](#development) for the optional steps.

The previous loop-based harness (plan → implement → test → review state machine with persona sub-agents and model-tier pins) is preserved at the `pre-lean-harness` git tag.

## Layout

```
personal-harness/
├── skills/           # shared Agent Skills (one folder per skill; installed to ~/.agents/skills)
├── hooks/            # per-platform hooks (claude: settings.json + *.sh · codex/cursor/grok: hooks.json + *.sh)
├── instructions/     # source for the global AGENTS.md instructions
├── scripts/          # install scripts (apply-to.sh · apply-to-{claude,codex,cursor,grok}.sh · apply-to-all.sh · setup-ctx7.sh)
└── docs/             # harness docs (sync-harness/: SYNC_TO_* hook conversion rules)
```

Hook behavior is under [Harness > Hooks](#hooks). Hooks require `rg`/`fd`, so install [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd) (see Prerequisites).

Skills are shared (`skills/<name>/` → `~/.agents/skills`). Hooks migrate as **Claude ↔ Codex** (bidirectional) + **Claude → Cursor** (one-way) + **Claude → Grok Build** (one-way, pure path). Grok Build does not use Claude-compat paths. A hook change that starts in Cursor or Grok still lands in the Claude variant first, then is pushed down. There is no sync skill — the agent reads the relevant checklist and applies it directly. Conversion rules live in [SYNC_TO_CODEX.md](docs/sync-harness/SYNC_TO_CODEX.md), [SYNC_TO_CLAUDE.md](docs/sync-harness/SYNC_TO_CLAUDE.md), [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md), and [SYNC_TO_GROK.md](docs/sync-harness/SYNC_TO_GROK.md).

## Prerequisites

These CLI tools must be on PATH for this harness's skills, hooks, and install scripts to work. Some tools are not required on every platform; check the scope column.

| Tool | Scope | Role | Install |
| --- | --- | --- | --- |
| `jq` | all (Claude/Codex shell hook + `apply-to-claude.sh`) | parse hook input, merge `settings.json`, LogQL URL-encode for `loki-log-search` | `brew install jq` |
| `git` | all shell hooks and `commit-code` | classify session context, verify git identity, post-commit docs-drift check | `brew install git` |
| `make` | all `auto-format` hook | run the project's Makefile `fmt`/`format` target | macOS: Xcode Command Line Tools, Linux: `build-essential` |
| `rg` (ripgrep) | all `enforce-rg` hook + AGENTS.md | force `rg` instead of recursive `grep` | `brew install ripgrep` |
| `fd` | all `enforce-fd` hook + AGENTS.md | force `fd` instead of `find` for file/path search | `brew install fd` |
| `ctx7` | AGENTS.md context7 rule + `scripts/setup-ctx7.sh` | fetch official library/framework docs | `npm install -g ctx7` then `ctx7 login` (or set `CONTEXT7_API_KEY`) |
| `codegraph` | AGENTS.md CodeGraph rule + `setup-initial-repo` | code-intelligence index; `setup-initial-repo` runs `codegraph init` on new repos | `npx @colbymchenry/codegraph` |
| `gh` | `commit-code` (personal PR path), `setup-initial-repo` (personal remote create) | create/update GitHub PRs, auto-create personal private repos | `brew install gh` then `gh auth login` |
| `glab` | `commit-code` (work MR path), `notion-daily-briefing` | create/update GitLab MRs; read-only MR/commit search for the yesterday recap | `brew install glab` then `glab auth login` |
| `gcx` | `loki-log-search` | Grafana Loki log lookup via `gcx api` passthrough | install a `gcx` distribution, then configure context with `gcx config current-context` |
| `acli` | `notion-daily-briefing` | Atlassian CLI for read-only Jira ticket search/view/comment list | `brew tap atlassian/homebrew-acli && brew install acli` then `acli jira auth login --web` |
| `ntn` | `notion-daily-briefing`, `notion-cli` | Notion CLI for the Daily Note query/create/markdown update | `curl -fsSL https://ntn.dev \| bash` then `ntn login` |
| Cursor 2.4+ | entire Cursor variant | Agent Skills, `hooks.json` | update the Cursor app |
| `grok` (Grok Build 0.2+) | entire Grok variant | `~/.grok/{skills,hooks,rules}`; SuperGrok subscription recommended | [install Grok Build CLI](https://x.ai/cli) then `grok login` |

Notes:
- `rg`/`fd` are required: as the layout section's `hooks` item already says, hooks enforce their use.
- `gh` and `glab` are only called on personal and work repos respectively, so you can omit the tool for a repo type you never use.
- Project templates (`skills/*/setup-initial-repo/references/{go-makefile.md,golangci-yml.md,swift-makefile.md,ts-nextjs-packagejson.md}`) pull along `go`, `golangci-lint`, `mockery`, `gremlins`, `swag`, `swiftlint`, `swiftformat`, `eslint`, `vitest`, `playwright`, `stryker`, and so on when `setup-initial-repo` references them. Those are build tools of the generated project, not prerequisites of this harness.

### One-time required setup (Cursor · Grok Build)

These are UI/config-file steps the install scripts cannot take for you. Recheck them on a new machine, a reinstall, or a settings reset.

#### Cursor — turn off `~/.claude` / `~/.codex` compat paths

Besides `~/.cursor/` and `~/.agents/skills`, Cursor also **reads skills from `~/.claude/` and `~/.codex/` at user scope**, so with compat on it also loads the Claude per-skill symlinks and every shared skill loads twice. The compat-path read is a **Cursor setting (UI)**, so the install script cannot guarantee it stays off, and if it comes back **there is no error.**

**Do this:** In Cursor settings, **turn off** Claude / Codex compat (or “read from `~/.claude` / `~/.codex`”). The UI label varies by Cursor version; look under Agents / Skills settings for the compat-path option and switch it off.

#### Grok Build — turn off `[compat.claude]` · `[compat.cursor]`

Grok Build can read Claude/Cursor paths via `[compat.*]` by default. This harness uses **pure `~/.grok/{skills,hooks,rules}` plus `~/.agents/skills` only**. With compat on, the `~/.claude/skills` symlinks and the rest mix in and the same names load twice.

Paste the following into `~/.grok/config.toml`, or if the blocks already exist set every value to `false`.

```toml
# ~/.grok/config.toml — pure Grok variant (the install script does not set this)
[compat.claude]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false

[compat.cursor]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false
```

### Environment variables

Environment variables the skills need. They must be registered in each agent's env config (for example Claude Code `settings.json` `env`, or Codex `config.toml` `shell_environment_policy.set`).

- `PERSONAL_GIT_EMAIL`: Git email for personal-repo commits
- `PERSONAL_GIT_NAME`: Git name for personal-repo commits
- `WORK_GIT_EMAIL`: Git email for work-repo commits
- `WORK_GIT_NAME`: Git name for work-repo commits
- `WORK_GITLAB_HOST`: work GitLab host (used to classify repos; `notion-daily-briefing` derives its `glab --hostname` from it)
- `WORK_GITLAB_USERNAME`: work GitLab username (`--assignee` when creating MRs)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: default work GitLab reviewers (`--reviewer` when creating MRs)
- `NOTION_DAILY_NOTES_DS_ID`: Notion Daily Notes data source ID (`notion-daily-briefing`)
- `NOTION_DAILY_NOTE_TEMPLATE_ID`: Notion Daily Note template ID (`notion-daily-briefing`)

## Development

```
plan-dev → implement in the same session → /goal <done-when condition> → test-dev (fresh context) → review → commit-code
```

Every step is optional and scales with the work: a one-sentence change needs none of them, a medium feature usually wants `plan-dev` and one review, and long or unattended work benefits from all of them.

1. **Plan** (`plan-dev`): the model investigates the repo, then settles with you what "done" means (observable state + evidence), what is out of scope, and what must not change. It hands the "done when" items back as one completion condition. The plan stays in the conversation; it is saved under `docs/agents/dev/` only when the work spans sessions or is handed to another session or tool.
2. **Implement**: in the same session, without a separate executor. Global instructions ask for evidence per completion criterion, forbid weakening tests, and ask the model to stop only for decisions that change the goal, scope, or something marked do-not-touch.
3. **Keep it going** (`/goal`, Claude Code): paste the completion condition, for example `/goal AC-1..N each shown passing by command output in the conversation, make test and make lint exit 0, no existing test file modified or deleted — or stop after 15 turns`. A small evaluator checks the condition after every turn and only reads the conversation, so ask for command output, not a claim. Pair it with auto mode for unattended runs.
4. **Harden tests** (`test-dev`): run it in a fresh context (a subagent or a new session) so it reads the diff, not the author's intent. It writes test code only and reports suspected defects instead of fixing production code.
5. **Review**: the host's built-in review (Claude Code: `/code-review`; add `/security-review` for changes touching authn/authz, secrets, concurrency, or partial-failure paths).
6. **Commit** (`commit-code`): name a PR/MR in that invocation if you want one (`request-merge` is a routing alias).

## Harness

### Skills

Each skill lives once under `skills/<name>/` and installs to `~/.agents/skills`. Claude uses per-skill symlinks from `~/.claude/skills`. See each skill's `SKILL.md` for the full contract.

**Development:**

| Skill | Description | Artifacts |
| --- | --- | --- |
| `plan-dev` | Investigates the repo and settles done-when / out-of-scope / do-not-touch with the user; offers the done-when items as a goal condition | Plan in the conversation; a file under `docs/agents/dev` only for multi-session or hand-off work |
| `test-dev` | Fresh-context test hardening over a git scope (default: diff vs `main`). Test code only; suspected defects are reported, never fixed | Test code (no file artifact) |
| `commit-code` | Creates a commit from modified files, then a read-only docs-drift check. Opens a PR/MR (`gh` personal / `glab` work) only when the prompt asks (`request-merge` is a routing alias). Dirty tree + PR request: commit first | Commit · (optional) PR/MR |

**Misc:**

| Skill | Description | Artifacts |
| --- | --- | --- |
| `spec-creator` | Stepwise interview to capture requirements for a new project | Korean SPEC.md |
| `setup-initial-repo` | Bootstrap a new repo from SPEC.md — instruction files, build scripts, .gitignore, git identity, remote origin | Initial repo scaffold |
| `learn-from-manual-edits` | Infers general preferences from the user's manual edits on top of agent-written code and records them as conventions | CLAUDE.md/AGENTS.md convention sections |
| `chat-summary` | Turns a conversation into a self-contained Obsidian note using the vault's existing category/tag vocabulary (YAML frontmatter + body) | Obsidian note (.md) |
| `loki-log-search` | Queries Grafana Loki logs via `gcx api` | None (chat report) |
| `notion-daily-briefing` | Ensures today's Notion Daily Note (from template), summarizes my not-Done Jira tickets via `acli` (read-only), and writes them into its "아침 브리핑" section, plus a blue callout recapping yesterday's Jira comments and GitLab MRs/commits (`glab`, read-only), and copies the previous note's "할 일" section (Friday's on a Monday) into today's | Today's Notion Daily Note |

**External (official, not vendored in `skills/`):** installed by `apply-to.sh` from [`EXTERNAL_SKILLS`](scripts/install-shared.sh) via `npx skills add`.

| Skill | Source | Description |
| --- | --- | --- |
| `notion-cli` | `makenotion/skills` (official Notion) | Uses the Notion CLI (`ntn`) for the Notion API, workers, and file uploads |

### Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

| Hook | When | Role |
| --- | --- | --- |
| `session-context.sh` | Session start | Classifies the repo as work/personal via `WORK_GITLAB_HOST` and the origin remote, then injects session context |
| `git-identity-guard.sh` | Before Bash | Verifies git identity (name/email) matches the repo type at commit time |
| `enforce-rg.sh` | Before Bash | Forces `rg` instead of recursive `grep` for code search |
| `enforce-fd.sh` | Before Bash | Forces `fd` instead of `find` for file/path search |
| `auto-format.sh` | After file edits | Runs the project's Makefile `fmt`/`format` target |

Platform-specific config: Claude Code uses the `hooks` block in `hooks/claude/settings.json`; Codex, Cursor, and Grok each use `hooks.json` (schemas differ — Cursor's is a flat array, see [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md); Grok installs as `~/.grok/hooks/harness.json` and merges `~/.grok/hooks/*.json`). Hooks are guardrails that enforce policy, not workflow.

## Scripts

`scripts/` holds install scripts. `apply-to-*.sh` deploys this repo's source variants into the real agent environment under the user's home; `setup-ctx7.sh` does the reverse, writing an external product back into the repo source. Harness-owned install targets are emptied then refilled, so skills and hooks edited directly under home are overwritten from source on the next run.

Skills, agents, and runtime scripts the harness no longer ships are listed in `RETIRED_SKILLS` · `RETIRED_AGENTS` · `RETIRED_SCRIPTS` in `scripts/install-shared.sh`. The installers delete those names from every install target, so an upgraded machine stops loading them; anything else in those directories is left alone.

### apply-to.sh

Common entry point: takes agent names as arguments and runs only those install scripts, in order. Before the per-agent installers, it deletes harness-owned and retired names under `~/.agents/skills`, copies `skills/<name>/` there once (shared across hosts), and removes retired scripts from `~/.agents/scripts`. It then installs third-party skills listed in `EXTERNAL_SKILLS` (`scripts/install-shared.sh`) with `npx skills add <source> --skill <name> -g -a universal -y` (network required); `apply-to-claude.sh` symlinks them from `~/.claude/skills` like the harness skills.

```bash
scripts/apply-to.sh claude
scripts/apply-to.sh claude cursor
scripts/apply-to.sh claude codex cursor grok
```

Allowed arguments: `claude` · `codex` · `cursor` · `grok` (case-insensitive, duplicates dropped). Legacy names `personal`/`work` are rejected with a pointer to `claude`/`codex`.

### apply-to-claude.sh

Claude Code install script.

- Claude Code: copies `instructions/AGENTS.md` to `~/.claude/CLAUDE.md` and refreshes per-skill symlinks under `~/.claude/skills` → `~/.agents/skills` (retired names lose their link). Removes retired harness agents from `~/.claude/agents`. Empties and refills `~/.claude/hooks` from `hooks/claude/hooks/`.
- Claude Code settings: merges the `hooks` block from `hooks/claude/settings.json` into `~/.claude/settings.json` with `jq`. Other user settings (`permissions`/`model`/`env`, …) are preserved; if the target file is missing it is created whole (`jq` required).
- Prints a per-item install status summary at the end.

### apply-to-codex.sh

Codex install script.

- Copies `instructions/AGENTS.md` to `~/.codex/AGENTS.md`.
- Removes harness and retired skill names from `~/.codex/skills`, and retired harness agents from `~/.codex/agents/`.
- Empties `~/.codex/hooks/`, copies `hooks/codex/hooks/*`, and copies `hooks/codex/hooks.json` to `~/.codex/hooks.json`.
- Prints a per-item install status summary at the end.

### apply-to-cursor.sh

Cursor install script.

- Copies `instructions/AGENTS.md` to `~/.cursor/AGENTS.md`. **Cursor does not read this file** — `session-context.sh` reads it and injects it as `additional_context`. Cursor has no user-global instructions file, and User Rules are UI state the install script cannot write.
- Removes harness and retired skill names from `~/.cursor/skills`, and retired harness agents from `~/.cursor/agents`. Empties and refills `~/.cursor/hooks` from `hooks/cursor/hooks/`.
- Copies `hooks/cursor/hooks.json` to `~/.cursor/hooks.json` as a **replace, not a merge**. Claude's `settings.json` is shared with other settings; Cursor's `hooks.json` is hooks-only.
- Prints an install summary and reminds you of the one-time manual step the script cannot take (turn off `~/.claude` compat paths).

### apply-to-grok.sh

Install script for the Grok Build-only variant (does not use Claude/Cursor compat paths).

- Copies `instructions/AGENTS.md` to **`~/.grok/rules/AGENTS.md`** (native rules load, not SessionStart injection).
- Removes harness and retired skill names from `~/.grok/skills`, and retired harness agents from `~/.grok/agents/`.
- Places hook scripts under `~/.grok/hooks/` and copies `hooks/grok/hooks.json` to **`~/.grok/hooks/harness.json`** (Grok merges `~/.grok/hooks/*.json`).
- On exit, reminds you to **turn off `[compat.claude]` · `[compat.cursor]`**.

### apply-to-all.sh

Wrapper that calls `apply-to.sh claude codex cursor grok` and runs all four agent installs in order. Runnable from anywhere (the script resolves paths from its own location).

### setup-ctx7.sh

Regenerates the Context7-shipped context7 instruction block to the latest version and writes it into the repo source. It updates source in the repo, not the install environment (`~/.claude` and so on); later `apply-to-*.sh` runs deploy the result (`ctx7` CLI required).

- Runs `ctx7 upgrade` first to check for a CLI update (if one is available it only prints a notice; it does not auto-install).
- Runs `ctx7 setup --cli --claude -y -p` in a temp directory to generate the context7 rules. `ctx7` also emits a `find-docs` skill; this harness does not vendor it — the same instructions already live in the context7 block of `instructions/AGENTS.md`, and installing the skill as well would burn skill-list budget twice on all four platforms.
- Rewrites generated `npx ctx7@latest` invocations to the globally installed `ctx7` command.
- Demotes `ctx7`'s `## Steps` heading to `### Context7 Steps`. If it stayed H2 when appended to AGENTS.md it would sit as a top-level section next to `## Key Principles` and would not read as ctx7-only steps.
- Replaces the `<!-- context7 -->` block in `instructions/AGENTS.md` with the Claude rule content (the four platforms share this instructions file, so the platform-neutral Claude rule is used).
