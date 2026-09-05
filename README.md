# My personal harness

**English** | [한국어](README.ko.md)

A harness of Agent Skills, global instructions, and install scripts for personal use.

Work usage burns quota in **Cursor → Claude → Codex** order (cheapest-approval-friction pool first; rationale in [docs/cost-effective/ANALYSIS_AND_PROPOSAL.md](docs/cost-effective/ANALYSIS_AND_PROPOSAL.md) §9.8). Personal projects use **Grok Build** (SuperGrok subscription quota).

## Usage

The everyday flow is **plan → human review and approval → run the loop**.

```
plan-dev → (plan review and approval) → dev-loop → commit-code
```

1. **`plan-dev`**: Interviews to draft a plan and lock `Acceptance Contract` and `Authority Boundaries`. Artifacts land under `docs/agents/` as PLAN and RESEARCH.
2. **Review**: A human reads the saved plan and approves it. If the direction is wrong, do not put it in a loop — recapture it with `plan-dev`.
3. **Run the loop**: Pass the approved plan path to `dev-loop`. Mode is `light` (default), `full`, or `noreview`. Frozen at preflight; do not switch mid-run.

| Mode | Review | mutation | Use for |
| --- | --- | --- | --- |
| `light` (default) | maintainability + senior-generalist | no | Everyday work that wants a review without four axes |
| `full` | all four axes | yes | Serious or large work, or security-/reliability-sensitive paths |
| `noreview` | none | no | Cheapest path; no reviewer reads the change |

See [Development](#development) for the full cycle, gates, and resume rules.

### Session model / effort (chosen when you start the session)

A skill frontmatter `model:` applies **only to that turn**. `plan-dev` and the loops break turns at human gates, so set the session to the model and effort below **when you start it**. Subagent models (implementer, reviewers, and so on) are pinned on the role files and the session model does not override them — see [Model Tier](#model-tier).

| Invocation | Claude | Codex | Cursor | Grok Build |
| --- | --- | --- | --- | --- |
| `plan-dev` | **Opus** | **Sol / xhigh** | **Grok 4.6** (effort xhigh) | **Grok 4.6 / xhigh** |
| `dev-loop` | **Sonnet** | **Luna / medium** | **Grok 4.6 / medium** | **Grok 4.6 / medium** |

- Even a cheap loop session still runs T1 roles (planner, plan-consultant, security/reliability reviewers) at T1 via file pins.
- `noreview` has no reviewer reading the change, so at READY_TO_COMMIT read the IMPL report's `## TODO Fulfillment` and AC evidence yourself.
- This session rule is not enforced by a file — it is a habit of how you open a session.

## Layout

```
personal-harness/
├── skills/           # shared Agent Skills (one folder per skill; installed to ~/.agents/skills)
├── agents/           # persona subagent definitions (claude/*.md · codex/*.toml · cursor/*.md · grok/*.md)
├── hooks/            # per-platform hooks (claude: settings.json + *.sh · codex/cursor/grok: hooks.json + *.sh)
├── instructions/     # source for the global AGENTS.md instructions
├── scripts/          # install and sync scripts (apply-to.sh · apply-to-{claude,codex,cursor,grok}.sh · apply-to-all.sh · setup-ctx7.sh) + runtime/: platform-neutral runtime scripts installed to ~/.agents/scripts/
├── docs/             # harness docs (sync-harness/: SYNC_TO_* conversion rules · loop-engineering/: loop-engineering plans and research · cost-effective/: model-tiering cost analysis)
└── .agents/skills/   # meta-skill for the harness itself (sync-harness; identical copy under .claude/skills/)
```

Hook behavior is under [Harness > Hooks](#hooks). Hooks require `rg`/`fd`, so install [ripgrep](https://github.com/BurntSushi/ripgrep) and [fd](https://github.com/sharkdp/fd) (see Prerequisites).

Product skills are shared (`skills/<name>/` → `~/.agents/skills`). Agents and hooks still migrate as **Claude ↔ Codex** (bidirectional) + **Claude → Cursor** (one-way) + **Claude → Grok Build** (one-way, pure path). Grok Build does not use Claude-compat paths. Cursor's agent/hook source is always the Claude variant; a change that starts in Cursor or Grok still lands in the Claude variant first, then is pushed down. Conversion rules live in [SYNC_TO_CODEX.md](docs/sync-harness/SYNC_TO_CODEX.md), [SYNC_TO_CLAUDE.md](docs/sync-harness/SYNC_TO_CLAUDE.md), [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md), and [SYNC_TO_GROK.md](docs/sync-harness/SYNC_TO_GROK.md).

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
| `gh` | `commit-code` (personal PR path), `setup-initial-repo` (personal remote create) | create/update GitHub PRs, auto-create personal private repos | `brew install gh` then `gh auth login` |
| `glab` | `commit-code` (work MR path) | create/update GitLab MRs | `brew install glab` then `glab auth login` |
| `gcx` | `loki-log-search` | Grafana Loki log lookup via `gcx api` passthrough | install a `gcx` distribution, then configure context with `gcx config current-context` |
| Cursor 2.4+ | entire Cursor variant | subagent `model`/`readonly` frontmatter, Agent Skills, `hooks.json` (including `subagentStart`) | update the Cursor app |
| `grok` (Grok Build 0.2+) | entire Grok variant | `~/.grok/{agents,skills,hooks,scripts,rules}`; SuperGrok subscription recommended | [install Grok Build CLI](https://x.ai/cli) then `grok login` |

Notes:
- `rg`/`fd` are required: as the layout section's `hooks` item already says, hooks enforce their use.
- `gh` and `glab` are only called on personal and work repos respectively, so you can omit the tool for a repo type you never use.
- Project templates (`skills/*/setup-initial-repo/references/{go-makefile.md,swift-makefile.md,ts-nextjs-packagejson.md}`) pull along `go`, `golangci-lint`, `mockery`, `gremlins`, `swag`, `swiftlint`, `swiftformat`, `eslint`, `vitest`, `playwright`, `stryker`, and so on when `setup-initial-repo` references them. Those are build tools of the generated project, not prerequisites of this harness.

### One-time required setup (Cursor · Grok Build)

These are UI/config-file steps the install scripts cannot take for you. Recheck them on a new machine, a reinstall, or a settings reset.

#### Cursor — turn off `~/.claude` / `~/.codex` compat paths

Besides `~/.cursor/`, Cursor also **reads agents and skills from `~/.claude/` and `~/.codex/` at user scope.** `~/.cursor/` wins, but the compat-path read is a **Cursor setting (UI)**, so the install script cannot guarantee it stays off. If it comes back, **there is no error.** A Claude variant that gets adopted silently ignores `tools:` and `effort:`, so all four reviewers gain write access and model pins can drift. If it does come back, `model-pin-guard.sh` catches it on the first T1 dispatch.

**Do this:** In Cursor settings, **turn off** Claude / Codex compat (or “read from `~/.claude` / `~/.codex`”). The UI label varies by Cursor version; look under Agents / Skills settings for the compat-path option and switch it off.

#### Grok Build — turn off `[compat.claude]` · `[compat.cursor]`

Grok Build can read Claude/Cursor paths via `[compat.*]` by default. This harness uses **pure `~/.grok/{agents,skills,hooks,scripts,rules}` only**. With compat on, `~/.claude/agents` and the rest mix in and frontmatter silently drifts.

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
- `WORK_GITLAB_HOST`: work GitLab host (used to classify repos)
- `WORK_GITLAB_USERNAME`: work GitLab username (`--assignee` when creating MRs)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: default work GitLab reviewers (`--reviewer` when creating MRs)

## Development

The default development flow can run in two modes: **Loop Engineering**, which hands the implementation cycle to the `dev-loop` orchestrator, and **Manual Development**, which calls each skill stage by stage. Both share the same skill set ([Harness > Skills](#skills)) and the same artifact formats (plans / reports / review findings), so you can switch mid-flow.

### Loop Engineering

```
plan-dev → dev-loop( implement-dev → test-dev → [review-code] → (fix-dev → test-dev → [review-code])* ) → commit-code
```

**One skill, three modes.** Pass `light` (default), `full`, or `noreview`. Frozen at preflight; do not switch mid-run.

| Mode | Review | mutation | Use for |
| --- | --- | --- | --- |
| `light` (default) | `maintainability` + `senior-generalist` (2 axes) | no | Everyday work that wants a review without four axes |
| `full` | all four axes | yes | Genuinely serious or large feature work, or anything touching security-/reliability-sensitive paths |
| `noreview` | none | no | Cheapest path; no reviewer reads the change |

The two axes `light` drops (`security` and `reliability`) are the ones whose misses are unrecoverable. A change that touches authn/authz, secrets, concurrency, or partial-failure paths belongs in `full`, not `light`.

**No mode is gate-free.** All three keep the same two human gates: TESTING's suspected-defect **Fix/Accept** triage, and READY_TO_COMMIT. Dropping review drops the four reviewers, not the human's judgement.

1. **Plan**: Call `plan-dev` and interview a plan. In the completion-conditions round, lock per-TODO completion conditions and evidence (`Acceptance Contract`) together with authority boundaries and loop budget (`Authority Boundaries`). Approving the plan writes PLAN/RESEARCH files under `docs/agents/`. **The `plan-dev` session model differs by platform** — Claude Opus · Codex Sol/xhigh · Cursor Grok 4.6 xhigh · Grok Build Grok 4.6 xhigh ([Model Tier](#model-tier)).
2. **Run the loop**: Call `dev-loop` with the approved plan path and a mode from the table above (default `light`). It then repeats autonomously until the termination predicates hold (TODOs done ∧ AC evidence met ∧ verification green ∧ blocking findings 0). Multi-step plans are invoked per sub-plan (`-STEP-N`). **The loop-run session is also per-platform** — Claude Sonnet · Codex Luna/medium · Cursor Grok 4.6 medium · Grok Build Grok 4.6 medium. T1 agents stay T1 via role pins.
3. **Mid-run intervention in two cases only**: (a) If a finding appears at review (modes that have it) or the TESTING gate, answer the per-item Fix/Accept question — Accepted items are recorded in `AGENTS.md`'s `Accepted Review Exceptions`, shown as Waived (`Applied Exceptions`) from the next review, and do not count as blocking findings. (b) If it escalates on blocked, budget exhaustion, or no-progress, give instructions — if the problem is direction, re-enter `plan-dev`.
4. **Confirm and commit**: The loop stops at READY_TO_COMMIT. Check the Implementation Report and LOOP state file, then call `commit-code` yourself (name a PR/MR in that invocation if you want one — `request-merge` is a routing alias). Commit, push, and PR/MR creation are outside the loop's authority. **Under `noreview` no reviewer has read the change**, so read the IMPL report's `## TODO Fulfillment` and AC evidence yourself — the instruction drift four-axis review used to catch is now the human's job.
5. **Interrupt and resume**: If the loop dies mid-run, state remains in `docs/agents/dev/*_LOOP_*.md` (LOOP format is shared; `Mode:` is frozen in frontmatter). Calling `dev-loop` on the same plan continues from the last round in that mode.

### Manual Development

Call each skill stage by stage without `dev-loop`. Each skill can be used standalone; typically the previous skill's artifact (plan / implementation result / review comments) becomes the next skill's input.

```
plan-dev → implement-dev → (fix-dev loop on issues) → test-dev → review-code → (fix-dev loop on issues) → commit-code
```

1. Draft and approve a plan with `plan-dev`.
2. Pass the approved plan path to `implement-dev`.
3. Strengthen tests for the change scope with `test-dev`.
4. Review with `review-code`; fix each defect with `fix-dev` and re-verify the needed scope.
5. Commit with `commit-code`. Name a PR/MR in that invocation if you want one (`request-merge` is a routing alias).

HIGH/CRITICAL review triage (Fix/Accept) and recording `Accepted Review Exceptions` work the same on a standalone `review-code` call. Which stages to skip or repeat is the user's call.

## Harness

### Skills

Each skill lives once under `skills/<name>/` and installs to `~/.agents/skills`. Claude uses per-skill symlinks from `~/.claude/skills`. See each skill's `SKILL.md` for the full contract.

**Core Development Process:**

| Skill | Description | Execution | Artifacts |
| --- | --- | --- | --- |
| `plan-dev` | Drafts and approves an implementation plan via built-in Plan-mode interview. Locks `Acceptance Contract` / `Authority Boundaries` in the completion-conditions round; splits into multi-step (main + sub-plans) when needed | Main session (conditionally delegates to `planner`) | PLAN · RESEARCH (`docs/agents/`) |
| `implement-dev` | Implements the approved plan with TDD (Red-Green-Refactor) and collects per-AC evidence. Returns `blocked` on direction conflicts. Returns `needs-design-decision` on `(design-bearing)` TODOs | Loop starts `implementer`; standalone runs in-place | Code + IMPL report (`## TODO Fulfillment` axis) |
| `fix-dev` | Root-causes, fixes, and verifies one reviewed/verified defect at a time. Does not commit | Loop starts `fixer`; standalone runs in-place | Appends `## Fix` entries to the IMPL report |
| `test-dev` | Fills unit/e2e gaps and removes mutation LIVED survivors over a git scope (default: diff vs `main`). Production code is unchanged. The caller may put mutation out of scope | Loop starts `tester`; standalone runs in-place | Test code (no file artifact) |
| `review-code` | Caller starts reviewer personas in parallel (4 axes by default; the caller may name a subset) and aggregates findings. Reviewers report everything with a `Confidence` tag; **this skill's aggregation step filters**. HIGH/CRITICAL go through user Fix/Accept triage; Accept is recorded as AR and waived in later reviews | Loop or standalone is the caller | Findings report, `Accepted Review Exceptions` |
| `dev-loop` | Autonomously repeats implement → test → [review] → fix on an approved plan (AC · AB required) until termination predicates hold; stops at READY_TO_COMMIT. Modes: `light` (default, 2 axes, no mutation), `full` (4 axes + mutation), `noreview` (no review, no mutation). Starts each stage's persona. Triage, AR approval, and commits stay human-owned | Main session | LOOP file (append-only) |
| `commit-code` | Creates a commit from modified files, then a read-only docs-drift check. Opens a PR/MR (`gh` personal / `glab` work) only when the prompt asks (`request-merge` is a routing alias). Dirty tree + PR request: commit first | Main session | Commit · (optional) PR/MR |

**Misc:**

| Skill | Description | Artifacts |
| --- | --- | --- |
| `spec-creator` | Stepwise interview to capture requirements for a new project | Korean SPEC.md |
| `setup-initial-repo` | Bootstrap a new repo from SPEC.md — instruction files, build scripts, .gitignore, git identity, remote origin | Initial repo scaffold |
| `application-research-sync` | Analyzes code changes and batch-updates Research files (index first, only bodies that need it) | `docs/agents/research/*` |
| `learn-from-manual-edits` | Infers general preferences from the user's manual edits on top of agent-written code and records them as conventions | CLAUDE.md/AGENTS.md convention sections |
| `chat-summary` | Turns a conversation into a self-contained Obsidian note using the vault's existing category/tag vocabulary (YAML frontmatter + body) | Obsidian note (.md) |
| `loki-log-search` | Queries Grafana Loki logs via `gcx api` | None (chat report) |

### Custom Agents

Persona subagent definitions under `agents/<platform>/`. Format is Markdown (YAML frontmatter) for Claude, Cursor, and Grok, and TOML for Codex. Direct user invocation is not the norm; `dev-loop` starts them.

Each agent pins its model in its own frontmatter (or Codex TOML) — Claude uses `model` · `effort`, Codex uses `model` · `model_reasoning_effort` (plus read-only `sandbox_mode`), Cursor folds effort into a single `model` string. Placement and rationale: [Model Tier](#model-tier). `inherit` appears nowhere in this harness.

| Agent | Persona · scope | Dispatched by | Access |
| --- | --- | --- | --- |
| `planner` | Software architect — direction, boundaries, interfaces, risks; returns user-facing question lists; reviews plan drafts | `plan-dev` (conditional on ambiguous, cross-cutting, or architecture-sensitive work) | Read-only |
| `plan-consultant` | Escalation hatch — decides a fork where two approaches both fit the plan but the wrong one is expensive to undo. Returns a short decision, never code | `dev-loop` on `needs-design-decision` | Read-only |
| `implementer` | Minimal-code implementation Worker; does not relitigate scope | `dev-loop` (IMPLEMENTING) | Write |
| `tester` | Test-hardening Worker — unit/e2e gaps, LIVED mutants. Test code only; suspected defects are reported as `TEST-NNN` findings | `dev-loop` (TESTING) | Write |
| `fixer` | Single-defect executor — smallest correct fix + regression tests. Returns `needs-confirmation` when the fix needs its own plan | `dev-loop` (FIXING) | Write |
| `security-reviewer` | Security axis — authn/authz, secrets, injection, crypto misuse, TOCTOU | `review-code` (parallel) | Read-only |
| `reliability-reviewer` | Reliability axis — error handling, resource lifecycle, concurrency, timeouts, partial failure | `review-code` (parallel) | Read-only |
| `maintainability-reviewer` | Maintainability axis — style consistency, abstraction fit, naming, module boundaries, dead code | `review-code` (parallel) | Read-only |
| `senior-generalist-reviewer` | Remaining ISO 25010 axes — performance, compatibility, interaction capability / UX, functional suitability, operational safety, flexibility | `review-code` (parallel) | Read-only |

The four reviewers share an identical `## Reporting contract` section in their bodies (bug bar, priority and confidence scales, per-finding block, specificity rules). It lives there rather than in `review-code`'s dispatch prompt so it is cached: static text that used to be sent 4× per round is cached once in each reviewer's system prompt. Do not move it back.

### Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

| Hook | When | Role |
| --- | --- | --- |
| `session-context.sh` | Session start | Classifies the repo as work/personal via `WORK_GITLAB_HOST` and the origin remote, then injects session context |
| `git-identity-guard.sh` | Before Bash | Verifies git identity (name/email) matches the repo type at commit time |
| `enforce-rg.sh` | Before Bash | Forces `rg` instead of recursive `grep` for code search |
| `enforce-fd.sh` | Before Bash | Forces `fd` instead of `find` for file/path search |
| `auto-format.sh` | After file edits | Runs the project's Makefile `fmt`/`format` target |
| `model-pin-guard.sh` | Just before a subagent spawn | **Cursor only.** If the resolved model is not the frontmatter pin, refuse T1 and log T2 |

Platform-specific config: Claude Code uses the `hooks` block in `hooks/claude/settings.json`; Codex, Cursor, and Grok each use `hooks.json` (schemas differ — Cursor's is a flat array, see [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md); Grok installs as `~/.grok/hooks/harness.json` and merges `~/.grok/hooks/*.json`). Hooks are guardrails that enforce policy; they take no part in `dev-loop` stage transitions, retries, or completion decisions. `model-pin-guard.sh` is the first hook here that can block, and it stays inside that invariant: it refuses a spawn on the wrong model, it does not decide a stage transition.

### Runtime Scripts

`scripts/runtime/*.sh` is installed to `~/.agents/scripts/` by every `apply-to-*.sh` (distinct from the repo's top-level `scripts/`, which is installer-only and never copied to home). The source is platform-neutral — it reads `Makefile`, `package.json`, and git, nothing else. Skills used to re-derive these facts with an LLM on every cold executor; that work now lives in the shell.

| Script | Consumers | Returns |
| --- | --- | --- |
| `detect-commands.sh` | `implement-dev` · `test-dev` · `fix-dev` | lint/format/test/build/mutation/e2e commands from `Makefile` targets and `package.json` scripts, as JSON. `null` for anything only named in prose — the caller reads that itself |
| `resolve-scope.sh` | `test-dev` · `review-code` | diff range, changed-file absolute paths, and languages involved, as one JSON blob |

Consumers call them by literal `$HOME/.agents/scripts/…`. `${CLAUDE_SKILL_DIR}` is unavailable here because the scripts live outside any skill folder; `$HOME` stays literal and the shell expands it at run time. Claude's installer appends the two Bash allows to `~/.claude/settings.json` `permissions.allow` without replacing the array. `hooks/claude/settings.json` has no `permissions` key.

## Model Tier

Every agent pins its model and effort in its own frontmatter (or Codex TOML). `inherit` is not used: it is not a tier, it is whatever the session happened to hold, and it would silently demote `security-reviewer` and `reliability-reviewer` to T2 the moment a loop runs in a Sonnet session, without a single line of those files changing.

The tier of a role is a property of the **work**, not of the model generation. Each agent body therefore carries a one-line `Tier:` rationale so the reasoning survives when the model names change.

| Tier | Definition | Claude | Codex | Cursor | Grok Build |
| --- | --- | --- | --- | --- | --- |
| **T1 judgment** | Irreversible decisions that cannot be machine-verified | `opus` | `gpt-5.6-sol` | `grok-4.6` | `grok-4.6` |
| **T2 execution** | Specified work whose result is machine-checkable | `sonnet`, except the two write-heavy roles (`opus` / `medium`) | **Terra** (long context) or **Luna** (small context) | `grok-4.6` (effort distinguishes T1 vs T2) | `grok-4.6` (effort distinguishes T1 vs T2) |
| **T3 mechanical** | Transformation and aggregation with no real judgement | *(unused — see below)* | *(unused)* | *(unused)* | *(unused)* |

**T3 is empty on purpose.** Haiku's 200K context, 4096-token minimum cache prefix, and lack of model-level effort make it a poor fit for this harness, whose T2 work is mostly repo-slice reasoning — the thing the smallest tier is worst at. Luna's long-context cliff (MRCR 41.3%) puts Codex's lowest tier out for the same reason. **Cursor and Grok Build use `grok-4.6` only.** `grok-4.5` is unused — it has no meaningful price advantage over 4.6. Composer 2.5 is unused. Tiers are effort, not model. Genuinely mechanical work goes to the shell (Runtime Scripts above). Billing is SuperGrok **subscription quota**.

### Agent placement

Claude uses the two fields `model` and `effort`. **Codex** uses TOML `model` + `model_reasoning_effort` (plus read-only `sandbox_mode`). **Cursor has neither `effort` nor `tools`** — effort is folded into the model string, and read-only is a single `readonly` boolean. **Grok Build** uses `model` + `effort` + `permission_mode` (plan = no edits, read-only shell allowed).

| Agent | Claude | Codex | Cursor | Grok Build | Rationale |
| --- | --- | --- | --- | --- | --- |
| `planner` | `opus` / `high` | Sol / high | `grok-4.6[effort=high]` | `grok-4.6` / high (plan) | Architecture judgement |
| `plan-consultant` | `opus` / `high` | Sol / high | `grok-4.6[effort=high]` | `grok-4.6` / high (plan) | **Grok: the main session spawns** (depth 1) |
| `security-reviewer` | `opus` / `medium` | Sol / medium | `grok-4.6[effort=high]` | `grok-4.6` / high (plan) | Highest miss cost |
| `reliability-reviewer` | `opus` / `medium` | Sol / medium | `grok-4.6[effort=high]` | `grok-4.6` / high (plan) | Counterfactual simulation |
| `implementer` | **`opus` / `medium`** | **Terra / high** | `grok-4.6[effort=medium]` | `grok-4.6` / **medium** | Long context; T1 model + T2 effort |
| `tester` | `sonnet` / `medium` | Luna / high | `grok-4.6[effort=medium]` | `grok-4.6` / medium | Machine-checkable goal; quality gate alongside `light`'s two T2 reviewers |
| `fixer` | **`opus` / `medium`** | **Terra / high** | **`grok-4.6[effort=medium]`** | `grok-4.6` / medium | A finding is a spec; same tier as `implementer` on every platform |
| `maintainability-reviewer` | `sonnet` / `medium` | Luna / high | `grok-4.6[effort=medium]` | `grok-4.6` / medium (plan) | Pattern matching |
| `senior-generalist-reviewer` | `sonnet` / `medium` | Luna / high | `grok-4.6[effort=medium]` | `grok-4.6` / medium (plan) | Catch-all |

**Two effort rules.** Do not buy the top of the ladder — even raising default effort to `max` is only a few points across tiers, so `xhigh` is reserved for irreversible decisions. And when you drop the model, do not drop effort with it: that is why Codex T2 rows put `high` on Luna/Terra (cheap model, high effort).

**`fixer` follows `implementer` on every platform, not T2 bulk.** Writing a fix has the same input shape as writing a change (brief · report · surrounding code), and cheaper models gave the price advantage back in extra turns. So Codex uses Terra, Cursor uses Grok 4.6, Claude uses Opus. Cursor and Grok Build `tester` is also 4.6 medium — default loop mode is `light`, so tester sits next to the two T2 reviewers, and Composer often ignored instructions. `maintainability-reviewer` and `senior-generalist-reviewer` are 4.6 medium too — `grok-4.5` has no price advantage.

**Claude's two write roles run a T1 model at T2 effort.** `implementer` and `fixer` are `opus` / `medium`, not `sonnet` — re-running this harness, Sonnet spent extra turns on the same work and gave back (or more than) the 1.67× price gap, rereading the plan and repo slice on every one of those turns. The tier is still T2; effort is what expresses that. The rest of T2 (`tester` · `maintainability-reviewer` · `senior-generalist-reviewer`) stays on `sonnet` because output is bounded and re-verified.

**Codex-only.** Do not use `model_reasoning_effort = "ultra"` — automatic task delegation collides with this harness's dispatch. Do not put Luna on `implementer` or `fixer` (long-context cliff). The shared default loop mode is **`light`** — Luna makes the last two review axes almost free, so `light` already captures ~95% of `noreview`'s savings.

**Grok Build-only.** The catalog in use is `grok-4.6` only (SuperGrok subscription quota). `grok-4.5` is unused. 4.6 effort is `low|medium|high|xhigh`. Subagent depth is 1, so design-bearing work has the loop start `plan-consultant` on `needs-design-decision`. Default loop mode is **`light`**. Turn off `[compat.claude]` and `[compat.cursor]`.

**Cursor's effort values are not Claude's.** Grok 4.6 is `low/medium/high/xhigh` (default `high`). T1 reviewers use `high` — one step below reserved `xhigh`, the same shape as Claude/Codex T1 reviewers. Cursor T2 matches Grok Build: every role `grok-4.6`, T2 is `[effort=medium]`. Composer 2.5 and `grok-4.5` are unused.

`implementer` and `fixer` keep a T1 **model** on Cursor. The agentic gap between the two models lands exactly on this work, and a 200K window does not fit a role that loads plan + research + conventions + code together — so effort was dropped instead of the model.

**The Cursor table rows and `hooks/cursor/hooks/model-pin-guard.sh` are one fact in two files.** Change a Cursor row and change the guard's `case` statement with it. If they diverge, the guard starts rejecting healthy dispatches. Codex has no equivalent guard — the role file is the pin's source of authority.

### Session operating rules

A skill frontmatter `model:` applies **only to that turn** and reverts to the session model at the next prompt. `plan-dev` is a multi-turn interview and every loop breaks turns at its human gates, so neither can be pinned that way. The invocation boundary is therefore the **session** boundary:

| Session | Claude | Codex | Cursor | Grok Build | Why |
| --- | --- | --- | --- | --- | --- |
| `plan-dev` | **Opus** | **Sol / xhigh** | **Grok 4.6** xhigh | **Grok 4.6 / xhigh** | Direction, boundaries, and ACs are irreversible |
| **every `dev-loop` run** | **Sonnet** | **Luna / medium** | **Grok 4.6 / medium** | **Grok 4.6 / medium** | Controller = transition table + LOOP append. T1 stays on role pins |

This applies to `full` too — every reviewer's model is pinned on the agent file, so the session model no longer decides any agent's tier.

**This part is a habit, not a file.** It takes effect when you start the session, and nothing in the repo enforces it.

### Operating switch — leave it unset

`CLAUDE_CODE_SUBAGENT_MODEL` overrides **both** frontmatter and per-invocation arguments, so setting it neutralises every tier pin in this table at once. There is deliberately no `env` block for it in `hooks/claude/settings.json`; unset is the correct state. Use it only as a deliberate, temporary A/B lever, and unset it afterwards. (Since v2.1.196 the value `inherit` is treated as unset, so resolution falls through normally.)

**Codex's `[agents] default_subagent_model` / `default_subagent_reasoning_effort` are fallbacks only** — they apply when neither the spawn call nor the role file sets a value, so they do not destroy role pins. Safer than Claude's env override.

**Cursor has no such switch — and that is worse, not better.** What takes its place is an *unintended* override: an admin model restriction, a plan limitation, or a model ID Cursor does not recognise all make it fall back to a "compatible model" without erroring. Nobody turns that on, so nobody remembers to turn it off. `hooks/cursor/hooks/model-pin-guard.sh` exists for exactly this: it reads the resolved model at `subagentStart`, refuses the spawn for T1 agents, and logs it for T2. The same guard is what catches a wrong model ID in `agents/cursor/*.md` and Cursor quietly reading `~/.claude/agents/` again.

## Scripts

`scripts/` holds install and sync scripts. `apply-to-*.sh` deploys this repo's source variants into the real agent environment under the user's home; `setup-ctx7.sh` does the reverse, writing an external product back into the repo source. Install target directories are emptied then refilled, so skills, agents, and hooks edited directly under home are overwritten from source on the next run.

### apply-to.sh

Common entry point: takes agent names as arguments and runs only those install scripts, in order.

```bash
scripts/apply-to.sh claude
scripts/apply-to.sh claude cursor
scripts/apply-to.sh claude codex cursor grok
```

Allowed arguments: `claude` · `codex` · `cursor` · `grok` (case-insensitive, duplicates dropped). Legacy names `personal`/`work` are rejected with a pointer to `claude`/`codex`.

### apply-to-claude.sh

Claude Code install script.

- Claude Code: copies `instructions/AGENTS.md` to `~/.claude/CLAUDE.md`, installs shared skills to `~/.agents/skills`, runtime scripts to `~/.agents/scripts`, and per-skill symlinks under `~/.claude/skills`. Empties and refills `~/.claude/agents` and `~/.claude/hooks` from `agents/claude/` · `hooks/claude/hooks/`.
- Claude Code settings: merges the `hooks` block from `hooks/claude/settings.json` into `~/.claude/settings.json` with `jq`. Then appends the two `~/.agents/scripts` Bash allows to `permissions.allow` without replacing the array. Other user settings (`permissions`/`model`/`env`, …) are preserved; if the target file is missing it is created whole (`jq` required). `hooks/claude/settings.json` has no `permissions` key.
- Prints a per-item install count and status summary at the end.

### apply-to-codex.sh

Codex install script.

- Copies `instructions/AGENTS.md` to `~/.codex/AGENTS.md`.
- Installs shared skills to `~/.agents/skills` and runtime scripts to `~/.agents/scripts`. Removes harness skill names from `~/.codex/skills`.
- Empties `~/.codex/agents/` and copies `agents/codex/*.toml`.
- Empties `~/.codex/hooks/`, copies `hooks/codex/hooks/*`, and copies `hooks/codex/hooks.json` to `~/.codex/hooks.json`.
- Prints a per-item install count and status summary at the end.

### apply-to-cursor.sh

Cursor install script.

- Copies `instructions/AGENTS.md` to `~/.cursor/AGENTS.md`. **Cursor does not read this file** — `session-context.sh` reads it and injects it as `additional_context`. Cursor has no user-global instructions file, and User Rules are UI state the install script cannot write.
- Installs shared skills to `~/.agents/skills` and runtime scripts to `~/.agents/scripts`. Removes harness skill names from `~/.cursor/skills`. Empties and refills `~/.cursor/agents` and `~/.cursor/hooks` from `agents/cursor/` · `hooks/cursor/hooks/`.
- Copies `hooks/cursor/hooks.json` to `~/.cursor/hooks.json` as a **replace, not a merge**. Claude's `settings.json` is shared with other settings; Cursor's `hooks.json` is hooks-only.
- Prints an install summary and reminds you of the one-time manual step the script cannot take (turn off `~/.claude` compat paths).

### apply-to-grok.sh

Install script for the Grok Build-only variant (does not use Claude/Cursor compat paths).

- Copies `instructions/AGENTS.md` to **`~/.grok/rules/AGENTS.md`** (native rules load, not SessionStart injection).
- Installs shared skills to `~/.agents/skills` and runtime scripts to `~/.agents/scripts`. Removes harness skill names from `~/.grok/skills`.
- Empties `~/.grok/agents/` and copies `agents/grok/*.md`.
- Places hook scripts under `~/.grok/hooks/` and copies `hooks/grok/hooks.json` to **`~/.grok/hooks/harness.json`** (Grok merges `~/.grok/hooks/*.json`).
- On exit, reminds you to **turn off `[compat.claude]` · `[compat.cursor]`** and of the session habit (plan-dev high / dev-loop medium).

### apply-to-all.sh

Wrapper that calls `apply-to.sh claude codex cursor grok` and runs all four agent installs in order. Runnable from anywhere (the script resolves paths from its own location).

### setup-ctx7.sh

Regenerates the Context7-shipped context7 instruction block to the latest version and writes it into the repo source. It updates source in the repo, not the install environment (`~/.claude` and so on); later `apply-to-*.sh` runs deploy the result (`ctx7` CLI required).

- Runs `ctx7 upgrade` first to check for a CLI update (if one is available it only prints a notice; it does not auto-install).
- Runs `ctx7 setup --cli --claude -y -p` in a temp directory to generate the context7 rules. `ctx7` also emits a `find-docs` skill; this harness does not vendor it — the same instructions already live in the context7 block of `instructions/AGENTS.md`, and installing the skill as well would burn skill-list budget twice on all four platforms.
- Rewrites generated `npx ctx7@latest` invocations to the globally installed `ctx7` command.
- Demotes `ctx7`'s `## Steps` heading to `### Context7 Steps`. If it stayed H2 when appended to AGENTS.md it would sit as a top-level section next to `## Key Principles` and would not read as ctx7-only steps.
- Replaces the `<!-- context7 -->` block in `instructions/AGENTS.md` with the Claude rule content (the four platforms share this instructions file, so the platform-neutral Claude rule is used).
