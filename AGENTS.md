# personal-harness

A harness of Agent Skills, global instructions, and install scripts for personal use. It supports four platforms — Claude Code, Codex, Cursor, and Grok Build — and migrates platform variants using the topology below.

- Claude ↔ Codex (bidirectional)
- Claude → Cursor (one-way; a change that starts in Cursor lands in the Claude variant first)
- Claude → Grok Build (one-way; pure Grok paths only — do not rely on Grok's Claude/Cursor compat scanners)

Per-stage conversion rules are defined in `docs/sync-harness/` (`SYNC_TO_CODEX.md`, `SYNC_TO_CLAUDE.md`, `SYNC_TO_CURSOR.md`, and `SYNC_TO_GROK.md`).

## Folder Structure

```
personal-harness/
├── skills/           # Per-platform Agent Skills (claude/ · codex/ · cursor/ · grok/; one folder per skill)
├── agents/           # Persona sub-agent definitions (claude/*.md · codex/*.toml · cursor/*.md · grok/*.md)
├── hooks/            # Per-platform hooks (claude: settings.json + *.sh · codex/cursor/grok: hooks.json + *.sh)
├── instructions/     # Distribution source of the global AGENTS.md instructions
├── scripts/          # Install/sync scripts (apply-to.sh · apply-to-{claude,codex,cursor,grok}.sh · apply-to-all.sh · setup-ctx7.sh) + runtime/: platform-neutral runtime scripts installed to ~/.claude/scripts/, ~/.cursor/scripts/, ~/.codex/scripts/, and ~/.grok/scripts/
├── docs/             # Harness docs (sync-harness/: SYNC_TO_* conversion rules · loop-engineering/: loop-engineering plan & research docs · cost-effective/: model-tiering cost analysis)
└── .agents/skills/   # Meta-skills for the harness itself (sync-harness; mirrored in .claude/skills/)
```

## Development

The default flow can run in two modes. Both share the same skill set and artifact formats, so you can switch between them mid-flow.

### Loop Engineering

```
plan-dev → dev-loop*( implement-dev → test-dev → [review-code] → (fix-dev → test-dev → [review-code])* ) → commit-code → request-merge
```

A loop drives one approved single-step plan (its `Acceptance Contract` / `Authority Boundaries` are required at preflight) through the cycle until every termination predicate holds, then stops at READY_TO_COMMIT. State is checkpointed append-only to a LOOP file under `docs/agents/dev` (one shared format across all platform variants); triage (Fix/Accept), AR approval, and commits stay human-owned.

**Three variants coexist — pick before starting, the loop does not switch mid-run:**

| Skill | Review | Mutation | Use for |
| --- | --- | --- | --- |
| `dev-loop-noreview` | none | no | **Claude / Cursor / Grok Build default.** Ordinary everyday work |
| `dev-loop-light` | `maintainability` + `senior-generalist` | no | **Codex default.** Wants a review, but not all four axes |
| `dev-loop` | all four axes | yes | Genuinely serious or large work, or anything touching security-/reliability-sensitive paths |

`dev-loop-light` deliberately omits the two axes whose misses are unrecoverable. A change touching authn/authz, secrets, concurrency, or partial-failure paths belongs in `dev-loop`.

**No variant is gate-free.** All three keep the same two human gates: the TESTING suspected-defect gate (**Fix / Accept**, with an Accept recorded as an AR entry) and READY_TO_COMMIT. Dropping review drops the reviewers, not the human's judgement.

**`dev-loop-noreview` has no reviewer reading the change**, so the IMPL report is the only record of what the implementer did. Read its `## TODO Fulfillment` and AC evidence yourself at READY_TO_COMMIT — instruction drift is exactly what the four-axis review used to catch.

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
| `implement-dev` | Executes the approved plan with TDD and collects per-AC evidence; returns `blocked` on direction conflicts; consults `plan-consultant` on `(design-bearing)` TODOs | Dispatcher → `implementer` Worker | Code + IMPL report |
| `fix-dev` | Fixes one reviewed defect at a time (root cause → fix → verify); never commits | Dispatcher → `fixer` Worker | `## Fix` entries appended to the IMPL report |
| `test-dev` | Fills unit/e2e gaps and removes LIVED mutants over a git scope (default: diff vs `main`); never modifies production code; the caller may put mutation out of scope | Dispatcher → `tester` Worker | Test code (no file artifact) |
| `review-code` | Dispatches reviewer personas in parallel (4 by default, or a caller-named subset) and aggregates findings; reviewers report everything with a `Confidence` tag and **this skill filters**; HIGH/CRITICAL go through user Fix/Accept triage, accepted items recorded as AR and waived in later reviews | Dispatcher → reviewers | Findings, `Accepted Review Exceptions` |
| `dev-loop` | Thin controller repeating implement→test→review(4축)→fix until termination predicates hold; stops at READY_TO_COMMIT. **Heavy — serious or large work only** | Main session (invokes each stage skill's Dispatcher flow) | LOOP file (append-only) |
| `dev-loop-light` | Same controller with review narrowed to 2 axes and no mutation (**Codex default**) | Main session | LOOP file (append-only) |
| `dev-loop-noreview` | Same controller with no review and no mutation; the TESTING Fix/Accept gate remains (**Claude / Cursor / Grok Build default**) | Main session | LOOP file (append-only) |
| `commit-code` | Creates a commit; runs a read-only documentation-drift check afterward | Main session | Commit |
| `request-merge` | Creates/updates a PR (`gh`, personal) or MR (`glab`, work) | Main session | PR/MR |

**Misc:**

| Skill | Description |
| --- | --- |
| `spec-creator` | Organizes requirements for a new project into a Korean SPEC.md |
| `setup-initial-repo` | Bootstraps a new repository from a SPEC.md (instruction files, build scripts, .gitignore, git identity, remote origin) |
| `application-research-sync` | Analyzes code changes and batch-updates Research files under `docs/agents/research` |
| `learn-from-manual-edits` | Infers preferences from the user's manual edits on agent-written code and records them as conventions |
| `chat-summary` | Turns the conversation into a self-contained Obsidian note (YAML frontmatter + body) reusing the vault's category/tag vocabulary |
| `find-docs` | Fetches official library/framework documentation via Context7 (`ctx7`). Third-party skill auto-installed by Context7, not authored by this harness |
| `loki-log-search` | Queries Grafana Loki logs via `gcx api` |

### Custom Agents

Persona sub-agent definitions under `agents/<platform>/`. Formats differ by platform (Claude / Cursor / Grok: `.md`, Codex: `.toml`). Skills dispatch them; direct user invocation is not the norm.

Every agent pins its own `model` and `effort` — see [Model Tier](#model-tier). `inherit` appears nowhere in this harness by design.

| Agent | Persona · Scope | Dispatched by | Access |
| --- | --- | --- | --- |
| `planner` | Software architect — direction, boundaries, interfaces, risks; returns user-facing question lists; reviews plan drafts | `plan-dev` (conditional) | Read-only |
| `plan-consultant` | Escalation hatch — decides a fork where two approaches both fit the plan but the wrong one is expensive to reverse; returns a short decision, never code | Claude/Codex/Cursor: `implementer` on `(design-bearing)` TODOs; **Grok: Dispatcher** (depth 1, `needs-design-decision`) | Read-only |
| `implementer` | Minimal-code implementation Worker; does not relitigate scope | `implement-dev` | Write |
| `tester` | Test-hardening Worker — unit/e2e gaps, LIVED mutants; test code only, records suspected defects as `TEST-NNN` findings | `test-dev` | Write |
| `fixer` | Single-defect executor — smallest correct fix + regression coverage; `needs-confirmation` when the fix needs its own plan | `fix-dev` | Write |
| `security-reviewer` | Security axis — authn/authz, secrets, injection, crypto misuse, TOCTOU | `review-code` (parallel) | Read-only |
| `reliability-reviewer` | Reliability axis — error handling, lifecycle, concurrency, timeouts, partial failure | `review-code` (parallel) | Read-only |
| `maintainability-reviewer` | Maintainability axis — style consistency, abstractions, naming, module boundaries, dead code | `review-code` (parallel) | Read-only |
| `senior-generalist-reviewer` | Remaining ISO 25010 axes — performance, compatibility, interaction capability / UX, functional suitability, operational safety, flexibility | `review-code` (parallel) | Read-only |

The four reviewers share an identical `## Reporting contract` section in their bodies (bug bar, priority + confidence scales, per-finding block, specificity rules). It lives there rather than in `review-code`'s dispatch prompt so it is cached once per reviewer instead of re-sent four times per round — do not move it back.

### Hooks

Hook definitions and scripts under `hooks/<platform>/`. Common shell hooks (`hooks/<platform>/hooks/*.sh`):

| Hook | When | Role |
| --- | --- | --- |
| `session-context.sh` | Session start | Classifies the repo as work/personal via `WORK_GITLAB_HOST` + origin remote and injects session context |
| `git-identity-guard.sh` | Before Bash | Verifies git identity at commit time |
| `enforce-rg.sh` | Before Bash | Enforces `rg` over recursive `grep` |
| `enforce-fd.sh` | Before Bash | Enforces `fd` over `find` |
| `auto-format.sh` | After file edits | Runs the project Makefile's `fmt`/`format` target |
| `model-pin-guard.sh` | Before a subagent spawns | **Cursor only.** Rejects a T1 agent whose resolved model is not the one its frontmatter pins; logs the same for T2 |

Platform-specific config files: Claude Code uses the `hooks` block in `settings.json`; Codex, Cursor, and Grok use `hooks.json` (schemas differ — Cursor's is flat, see `SYNC_TO_CURSOR.md`; Grok installs as `~/.grok/hooks/harness.json` and merges all `~/.grok/hooks/*.json`). Hooks are guardrails; they take no part in `dev-loop` stage transitions or completion decisions. `model-pin-guard.sh` is the first hook here that can block, and it stays inside that invariant: it refuses a spawn on the wrong model, it does not decide a stage transition. `jq`·`git`·`make`·`rg`·`fd` are required (see README.md Prerequisites for details).

### Runtime Scripts

`scripts/runtime/*.sh` is installed to `~/.claude/scripts/` by `apply-to-claude.sh`, to `~/.cursor/scripts/` by `apply-to-cursor.sh`, to `~/.codex/scripts/` by `apply-to-codex.sh`, and to `~/.grok/scripts/` by `apply-to-grok.sh` (distinct from the repo's top-level `scripts/`, which is installer-only and never copied). The source is platform-neutral — it reads `Makefile`, `package.json`, and git, nothing else — so all four installers copy the same files rather than maintaining platform forks. Skills call these instead of re-deriving the same facts with an LLM on every cold Worker:

| Script | Consumers | Returns |
| --- | --- | --- |
| `detect-commands.sh` | `implement-dev` · `test-dev` · `fix-dev` | lint/format/test/build/mutation/e2e commands from `Makefile` targets and `package.json` scripts, as JSON. `null` for anything only named in prose — the caller reads that itself |
| `resolve-scope.sh` | `test-dev` · `review-code` | diff range, changed-file absolute paths, and languages involved, as JSON |

Consumers call them by literal `$HOME/.claude/scripts/…` (Claude), `$HOME/.cursor/scripts/…` (Cursor), `$HOME/.codex/scripts/…` (Codex), or `$HOME/.grok/scripts/…` (Grok) path. `${CLAUDE_SKILL_DIR}` is unavailable here because the scripts live outside any skill folder; `$HOME` stays literal and the shell expands it at run time. Claude skills pre-approve the same literal in `allowed-tools`; Cursor, Codex, and Grok have no skill-level pre-approval, so the first call may prompt. A mismatch costs one permission prompt, nothing more.

## Model Tier

Every agent's model and effort is pinned in its own frontmatter. `inherit` is not used anywhere: it is not a tier, it is whatever the session happened to hold, and it would silently demote `security-reviewer` and `reliability-reviewer` to T2 the moment a loop runs in a Sonnet session.

The tier of a role is a property of the work, not of the model generation. Each agent body carries a one-line `Tier:` rationale so the reasoning survives when the model names change.

| Tier | Definition | Claude | Codex | Cursor | Grok Build |
| --- | --- | --- | --- | --- | --- |
| **T1 judgment** | Irreversible decisions that cannot be machine-verified | `opus` | `gpt-5.6-sol` | `grok-4.6` | `grok-4.6` |
| **T2 execution** | Specified work whose result is machine-checkable | `sonnet`, except the two write-heavy roles (`opus` / `medium`) | **Terra** (long-context) or **Luna** (small context) | `grok-4.6` (effort distinguishes T1 vs T2) | `grok-4.6` (effort distinguishes T1 vs T2) |
| **T3 mechanical** | Transformation and aggregation with no real judgement | *(unused — see below)* | *(unused)* | *(unused)* | *(unused)* |

**T3 is empty on purpose.** Haiku's 200K context, 4096-token minimum cache prefix, and lack of model-level effort make it a poor fit for this harness, whose T2 work is mostly repo-slice reasoning — the thing the smallest tier is worst at. Luna's long-context cliff (MRCR 41.3%) puts Codex's lowest tier out for the same reason. **Cursor and Grok Build use `grok-4.6` only.** `grok-4.5` is unused — it has no meaningful price advantage over 4.6. Composer 2.5 is unused. Tiers are effort, not model. Genuinely mechanical work goes to the shell (Runtime Scripts above), not to a smaller model.

### Agent placement

Claude keeps `model` and `effort` as two fields. **Codex** uses TOML `model` + `model_reasoning_effort` (+ `sandbox_mode` for read-only). **Cursor** has neither `effort` nor `tools`: effort folds into the model string, and read-only is a single `readonly` boolean. **Grok Build** uses `model` + `effort` + `permission_mode` (plan = read-only edits blocked, read shell allowed); spawn may also pass `capability_mode: read-only`.

| Agent | Claude | Codex | Cursor | Grok Build `model` / `effort` | Why this tier |
| --- | --- | --- | --- | --- | --- |
| `planner` | `opus` / `high` | `gpt-5.6-sol` / `high` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Architecture calls are irreversible and unverifiable |
| `plan-consultant` | `opus` / `high` | `gpt-5.6-sol` / `high` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Exists for calls the executor cannot verify; **on Grok the main session spawns it** (depth 1) |
| `security-reviewer` | `opus` / `medium` | `gpt-5.6-sol` / `medium` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Missed authz bypass is unrecoverable |
| `reliability-reviewer` | `opus` / `medium` | `gpt-5.6-sol` / `medium` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Counterfactual simulation is the first thing weaker models lose |
| `implementer` | **`opus` / `medium`** | **`gpt-5.6-terra` / `high`** | `grok-4.6[effort=medium]` | `grok-4.6` / **`medium`** (default) | Long-context agentic role; T1 model at T2 effort |
| `tester` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` | Mutation score ≥80%; barred from production code; on Cursor and Grok this is the noreview quality gate |
| `fixer` | **`opus` / `medium`** | **`gpt-5.6-terra` / `high`** | **`grok-4.6[effort=medium]`** | `grok-4.6` / `medium` | Finding is the spec; re-test verifies — but matched to `implementer` on every platform |
| `maintainability-reviewer` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` (plan) | Specified pattern matching |
| `senior-generalist-reviewer` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` (plan) | Calibrated catch-all, lowest miss cost |

**effort follows two rules.** Do not buy the top of the scale — the jump from a model's default effort to `max` is worth a couple of points across the board, so `xhigh` is reserved for decisions that cannot be revisited. And when a model comes down a tier, effort does not follow it down: Codex T2 rows use `high` on Luna/Terra for exactly that reason (cheap model, high effort).

**Claude's two write-heavy T2 roles run the T1 model at T2 effort.** `implementer` and `fixer` are `opus` / `medium`, not `sonnet`: measured on this harness, Sonnet needed enough extra turns per task to hand back the 1.67x price gap and then some, and each of those turns re-read the plan and the repo slice. The tier is still T2 — the *effort* is what encodes that, and everything else in the T2 block stays on `sonnet` (`tester`, `maintainability-reviewer`, `senior-generalist-reviewer`), where the output is bounded and re-verified.

**Codex-specific:** never set `model_reasoning_effort = "ultra"` — it adds automatic task delegation that collides with this harness's own dispatch. Never put Luna on `implementer` or `fixer` (long-context cliff). Codex's default loop is **`dev-loop-light`** (not `dev-loop-noreview`): Luna makes the last two review axes nearly free, so light already captures ~95% of noreview's savings.

**Cursor's effort values are not the Claude ones.** Grok 4.6 has `low/medium/high/xhigh` (default `high`). T1 reviewers sit at `high` — one step below the reserved `xhigh` slot, same shape as Claude/Codex T1 reviewers sitting below plan-dev. Cursor T2 matches Grok Build: every role on `grok-4.6`, T2 at `[effort=medium]`. Composer 2.5 and `grok-4.5` are unused.

`implementer` and `fixer` are the rows where Cursor, like Claude, keeps the T1 *model*. The agentic gap between the two models lands exactly on those jobs, and a role that loads a plan (or a defect brief and its report), the conventions, and the code together is the wrong place for a 200K window — so the effort comes down instead.

**`fixer` tracks `implementer` on every platform, not the T2 bulk.** Writing a fix reads the same shape of input as writing the change — brief, report, surrounding code — and the cheaper model spent its price advantage on extra turns. So Codex puts it on Terra, Cursor on Grok 4.6, and Claude on Opus. On Cursor and Grok Build, `tester` also sits on 4.6 medium because both default to noreview (tester is the only machine quality gate) and Composer dropped instructions too often; `maintainability-reviewer` and `senior-generalist-reviewer` sit on 4.6 medium too — `grok-4.5` has no meaningful price advantage.

**The Cursor table rows and `hooks/cursor/hooks/model-pin-guard.sh` are one fact in two files.** Change a Cursor row and change the guard's `case` statement with it, or the guard starts rejecting healthy dispatches.

**Grok Build-specific:** catalog in use is **`grok-4.6` only** (SuperGrok subscription quota). `grok-4.5` is unused. Effort menu is `low|medium|high|xhigh`. Subagent nesting depth is **1** — the implementer must not spawn `plan-consultant`; the Dispatcher returns on `needs-design-decision` and spawns the consultant. No multi-model cascade and no `implementer-strict`. Default loop is **`dev-loop-noreview`**. Turn off Grok `[compat.claude]` / `[compat.cursor]` so pure `~/.grok/{agents,skills,hooks,scripts,rules}` paths win. Global instructions install to **`~/.grok/rules/AGENTS.md`**.

### Session operating rules

A skill's `model:` frontmatter applies **only to the current turn** and reverts to the session model at the next prompt. `plan-dev` is a multi-turn interview and every loop breaks turns at its human gates, so neither can be pinned that way. The invocation boundary is therefore the **session** boundary:

| Session | Claude | Codex | Cursor | Grok Build | Why |
| --- | --- | --- | --- | --- | --- |
| `plan-dev` | **Opus** | **Sol / xhigh** | **Grok 4.6** (effort xhigh) | **Grok 4.6 / xhigh** | Direction, boundaries, and ACs are irreversible |
| **every `dev-loop*` run** | **Sonnet** | **Luna / medium** | **Grok 4.6 / medium** | **Grok 4.6 / medium** | Controller reads a transition table and appends to a LOOP file; T1 agents stay pinned |

This applies to `dev-loop` too, four axes and all — every reviewer's model is pinned on the agent file, so the session model no longer decides any agent's tier.

**This part is a habit, not a file.** It takes effect when you start the session, and nothing in the repo enforces it.

### Operating switch — leave it unset

`CLAUDE_CODE_SUBAGENT_MODEL` overrides **both** frontmatter and per-invocation arguments, so setting it neutralises every tier pin in this table at once. There is deliberately no `env` block for it in `hooks/claude/settings.json`; unset is the correct state. Use it only as a deliberate, temporary A/B lever, and unset it afterwards. (Since v2.1.196 the value `inherit` is treated as unset, so resolution falls through normally.)

**Codex's `[agents] default_subagent_model` / `default_subagent_reasoning_effort` are fallbacks only** — they apply when neither the spawn call nor the role file sets a value, so they do not destroy role pins. Safer than Claude's env override.

**Cursor has no such switch — and that is worse, not better.** What takes its place is an *unintended* override: an admin model restriction, a plan limitation, or a model ID Cursor does not recognise all make it fall back to a "compatible model" without erroring. Nobody turns that on, so nobody remembers to turn it off. `hooks/cursor/hooks/model-pin-guard.sh` exists for exactly this: it reads the resolved model at `subagentStart`, refuses the spawn for T1 agents, and logs it for T2. The same guard is what catches a wrong model ID in `agents/cursor/*.md` and Cursor quietly reading `~/.claude/agents/` again.

**Grok Build has no env-wide subagent model override like Claude's.** Agent frontmatter `model` + `effort` is the pin; `[subagents.models]` is optional and this harness does not use it as a second source of truth. `SubagentStart` is non-blocking, so there is no Cursor-style pin guard in the default hook set.

## Environment Variables

Skills and hooks read these from the host agent's env configuration (Claude Code `settings.json` `env`, Codex `config.toml` `shell_environment_policy.set`):

| Variable | Purpose |
| --- | --- |
| `PERSONAL_GIT_EMAIL` / `PERSONAL_GIT_NAME` | Git identity for personal-repo commits |
| `WORK_GIT_EMAIL` / `WORK_GIT_NAME` | Git identity for work-repo commits |
| `WORK_GITLAB_HOST` | Work GitLab host; drives work/personal repo classification |
| `WORK_GITLAB_USERNAME` | `--assignee` when creating MRs |
| `WORK_GITLAB_DEFAULT_REVIEWERS` | `--reviewer` when creating MRs |
