# personal-harness

A harness of Agent Skills, global instructions, and install scripts for personal use. It supports two platforms — Claude Code and Codex — and migrates platform variants using the topology below.

- Claude ↔ Codex (bidirectional; Personal center is Claude Code, Work center is Codex)

Per-stage conversion rules are defined in `docs/sync-harness/` (`SYNC_TO_CODEX.md` and `SYNC_TO_CLAUDE.md`).

## Folder Structure

```
personal-harness/
├── skills/           # Per-platform Agent Skills (claude/ · codex/; one folder per skill)
├── agents/           # Persona sub-agent definitions (claude/*.md · codex/*.toml)
├── hooks/            # Per-platform hooks (claude: settings.json + *.sh · codex: hooks.json + *.sh)
├── instructions/     # Distribution source of the global AGENTS.md instructions
├── scripts/          # Install/sync scripts (apply-to-personal.sh · apply-to-work.sh · apply-to-all.sh · setup-ctx7.sh)
├── docs/             # Harness docs (sync-harness/: SYNC_TO_* conversion rules · loop-engineering/: loop-engineering plan & research docs)
└── .agents/skills/   # Meta-skills for the harness itself (sync-harness; mirrored in .claude/skills/)
```

## Development

The default flow can run in two modes. Both share the same skill set and artifact formats, so you can switch between them mid-flow.

### Loop Engineering

```
plan-dev → dev-loop( implement-dev → test-dev → review-code → (fix-dev → test-dev → review-code)* ) → commit-code → request-merge
```

`dev-loop` drives one approved single-step plan (its `Acceptance Contract` / `Authority Boundaries` are required at preflight) through the cycle until every termination predicate holds, then stops at READY_TO_COMMIT. State is checkpointed append-only to a LOOP file under `docs/agents/dev`; triage (Fix/Accept), AR approval, and commits stay human-owned.

### Manual Development

```
plan-dev → implement-dev → (fix-dev loop on issues) → test-dev → review-code → (fix-dev loop on issues) → commit-code → request-merge
```

Each skill can be used standalone; typically the output of the previous skill (plan / implementation report / review findings) becomes the input for the next.

## Harness

### Skills

Each skill under `skills/<platform>/` is managed in its own folder. See each skill's `SKILL.md` for the full contract.

**Core Development Process:**

| Skill | Description | Execution | Artifacts |
| --- | --- | --- | --- |
| `plan-dev` | Drafts an implementation plan via Plan-mode interview; locks `Acceptance Contract` / `Authority Boundaries`; splits into multi-step when needed | Main session (conditionally delegates to `planner`) | PLAN·RESEARCH under `docs/agents/` |
| `implement-dev` | Executes the approved plan with TDD and collects per-AC evidence; returns `blocked` on direction conflicts | Dispatcher → `implementer` Worker | Code + IMPL report |
| `fix-dev` | Fixes one reviewed defect at a time (root cause → fix → verify); never commits | Dispatcher → Worker | `## Fix` entries appended to the IMPL report |
| `test-dev` | Fills unit/e2e gaps and removes LIVED mutants over a git scope (default: diff vs `main`); never modifies production code | Dispatcher → Worker | Test code (no file artifact) |
| `review-code` | Dispatches 4 reviewer personas in parallel and aggregates findings; HIGH/CRITICAL go through user Fix/Accept triage, accepted items recorded as AR and waived in later reviews | Dispatcher → 4 reviewers | Findings, `Accepted Review Exceptions` |
| `dev-loop` | Thin controller repeating implement→test→review with fix cycles until termination predicates hold; stops at READY_TO_COMMIT | Main session (invokes each stage skill's Dispatcher flow) | LOOP file (append-only) |
| `commit-code` | Creates a commit; runs a read-only documentation-drift check afterward | Main session | Commit |
| `request-merge` | Creates/updates a PR (`gh`, personal) or MR (`glab`, work) | Main session | PR/MR |

**Misc:**

| Skill | Description |
| --- | --- |
| `spec-creator` | Organizes requirements for a new project into a Korean SPEC.md |
| `setup-initial-repo` | Bootstraps a new repository from a SPEC.md (instruction files, build scripts, .gitignore, git identity, remote origin) |
| `application-research-sync` | Analyzes code changes and batch-updates Research files under `docs/agents/research` |
| `learn-from-manual-edits` | Infers preferences from the user's manual edits on agent-written code and records them as conventions |
| `find-docs` | Fetches official library/framework documentation via Context7 (`ctx7`). Third-party skill auto-installed by Context7, not authored by this harness |
| `loki-log-search` | Queries Grafana Loki logs via `gcx api` |

### Custom Agents

Persona sub-agent definitions under `agents/<platform>/`. Formats differ by platform (Claude: `.md`, Codex: `.toml`). Skills dispatch them; direct user invocation is not the norm.

| Agent | Persona · Scope | Dispatched by | Access |
| --- | --- | --- | --- |
| `planner` | Software architect — direction, boundaries, interfaces, risks; returns user-facing question lists; reviews plan drafts | `plan-dev` (conditional) | Read-only |
| `implementer` | Minimal-code implementation Worker; does not relitigate scope | `implement-dev` | Write |
| `security-reviewer` | Security axis — authn/authz, secrets, injection, crypto misuse, TOCTOU | `review-code` (parallel) | Read-only |
| `reliability-reviewer` | Reliability axis — error handling, lifecycle, concurrency, timeouts, partial failure | `review-code` (parallel) | Read-only |
| `maintainability-reviewer` | Maintainability axis — style consistency, abstractions, naming, module boundaries, dead code | `review-code` (parallel) | Read-only |
| `senior-generalist-reviewer` | Remaining ISO 25010 axes — performance, compatibility, UX, operational safety | `review-code` (parallel) | Read-only |

### Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

| Hook | When | Role |
| --- | --- | --- |
| `session-context.sh` | Session start | Classifies the repo as work/personal via `WORK_GITLAB_HOST` + origin remote and injects session context |
| `git-identity-guard.sh` | Before Bash | Verifies git identity at commit time |
| `enforce-rg.sh` | Before Bash | Enforces `rg` over recursive `grep` |
| `enforce-fd.sh` | Before Bash | Enforces `fd` over `find` |
| `auto-format.sh` | After file edits | Runs the project Makefile's `fmt`/`format` target |

Platform-specific config files: Claude Code uses the `hooks` block in `settings.json`, and Codex uses `hooks.json`. Hooks are guardrails; they take no part in `dev-loop` stage transitions or completion decisions. `jq`·`git`·`make`·`rg`·`fd` are required (see README.md Prerequisites for details).

## Environment Variables

Skills and hooks read these from the host agent's env configuration (Claude Code `settings.json` `env`, Codex `config.toml` `shell_environment_policy.set`):

| Variable | Purpose |
| --- | --- |
| `PERSONAL_GIT_EMAIL` / `PERSONAL_GIT_NAME` | Git identity for personal-repo commits |
| `WORK_GIT_EMAIL` / `WORK_GIT_NAME` | Git identity for work-repo commits |
| `WORK_GITLAB_HOST` | Work GitLab host; drives work/personal repo classification |
| `WORK_GITLAB_USERNAME` | `--assignee` when creating MRs |
| `WORK_GITLAB_DEFAULT_REVIEWERS` | `--reviewer` when creating MRs |
