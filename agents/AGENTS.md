# Agent Placement

Per-agent `model` / `effort` pins for all four platforms, with the rationale for each. This file loads automatically when working with files under `agents/`; the tier *definitions* it builds on live in the root `AGENTS.md` `## Model Tier` section.

Claude keeps `model` and `effort` as two fields. **Codex** uses TOML `model` + `model_reasoning_effort` (+ `sandbox_mode` for read-only). **Cursor** has neither `effort` nor `tools`: effort folds into the model string, and read-only is a single `readonly` boolean. **Grok Build** uses `model` + `effort` + `permission_mode` (plan = read-only edits blocked, read shell allowed); spawn may also pass `capability_mode: read-only`.

| Agent | Claude | Codex | Cursor | Grok Build `model` / `effort` | Why this tier |
| --- | --- | --- | --- | --- | --- |
| `planner` | `opus` / `high` | `gpt-5.6-sol` / `high` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Architecture calls are irreversible and unverifiable |
| `plan-consultant` | `opus` / `high` | `gpt-5.6-sol` / `high` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Exists for calls the executor cannot verify; the loop starts it on `needs-design-decision` |
| `security-reviewer` | `opus` / `medium` | `gpt-5.6-sol` / `medium` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Missed authz bypass is unrecoverable |
| `reliability-reviewer` | `opus` / `medium` | `gpt-5.6-sol` / `medium` | `grok-4.6[effort=high]` | `grok-4.6` / `high` (plan) | Counterfactual simulation is the first thing weaker models lose |
| `implementer` | **`opus` / `medium`** | **`gpt-5.6-terra` / `high`** | `grok-4.6[effort=medium]` | `grok-4.6` / **`medium`** (default) | Long-context agentic role; T1 model at T2 effort |
| `tester` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` | Mutation score ≥80%; barred from production code; quality gate alongside `light`'s two T2 reviewers |
| `fixer` | **`opus` / `medium`** | **`gpt-5.6-terra` / `high`** | **`grok-4.6[effort=medium]`** | `grok-4.6` / `medium` | Finding is the spec; re-test verifies — but matched to `implementer` on every platform |
| `maintainability-reviewer` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` (plan) | Specified pattern matching |
| `senior-generalist-reviewer` | `sonnet` / `medium` | `gpt-5.6-luna` / `high` | `grok-4.6[effort=medium]` | `grok-4.6` / `medium` (plan) | Calibrated catch-all, lowest miss cost |

**effort follows two rules.** Do not buy the top of the scale — the jump from a model's default effort to `max` is worth a couple of points across the board, so `xhigh` is reserved for decisions that cannot be revisited. And when a model comes down a tier, effort does not follow it down: Codex T2 rows use `high` on Luna/Terra for exactly that reason (cheap model, high effort).

**Claude's two write-heavy T2 roles run the T1 model at T2 effort.** `implementer` and `fixer` are `opus` / `medium`, not `sonnet`: measured on this harness, Sonnet needed enough extra turns per task to hand back the 1.67x price gap and then some, and each of those turns re-read the plan and the repo slice. The tier is still T2 — the *effort* is what encodes that, and everything else in the T2 block stays on `sonnet` (`tester`, `maintainability-reviewer`, `senior-generalist-reviewer`), where the output is bounded and re-verified.

**Codex-specific:** never set `model_reasoning_effort = "ultra"` — it adds automatic task delegation that collides with this harness's own dispatch. Never put Luna on `implementer` or `fixer` (long-context cliff). The shared default loop mode is **`light`**: Luna makes the last two review axes nearly free, so `light` already captures ~95% of `noreview`'s savings.

**Cursor's effort values are not the Claude ones.** Grok 4.6 has `low/medium/high/xhigh` (default `high`). T1 reviewers sit at `high` — one step below the reserved `xhigh` slot, same shape as Claude/Codex T1 reviewers sitting below plan-dev. Cursor T2 matches Grok Build: every role on `grok-4.6`, T2 at `[effort=medium]`. Composer 2.5 and `grok-4.5` are unused.

`implementer` and `fixer` are the rows where Cursor, like Claude, keeps the T1 *model*. The agentic gap between the two models lands exactly on those jobs, and a role that loads a plan (or a defect brief and its report), the conventions, and the code together is the wrong place for a 200K window — so the effort comes down instead.

**`fixer` tracks `implementer` on every platform, not the T2 bulk.** Writing a fix reads the same shape of input as writing the change — brief, report, surrounding code — and the cheaper model spent its price advantage on extra turns. So Codex puts it on Terra, Cursor on Grok 4.6, and Claude on Opus. On Cursor and Grok Build, `tester` also sits on 4.6 medium because the default loop mode is `light` (tester sits next to the two T2 reviewers) and Composer dropped instructions too often; `maintainability-reviewer` and `senior-generalist-reviewer` sit on 4.6 medium too — `grok-4.5` has no meaningful price advantage.

**The Cursor table rows and `hooks/cursor/hooks/model-pin-guard.sh` are one fact in two files.** Change a Cursor row and change the guard's `case` statement with it, or the guard starts rejecting healthy dispatches.

**Grok Build-specific:** catalog in use is **`grok-4.6` only** (SuperGrok subscription quota). `grok-4.5` is unused. Effort menu is `low|medium|high|xhigh`. Subagent nesting depth is **1** — the implementer must not start `plan-consultant`; the loop returns on `needs-design-decision` and starts the consultant. No multi-model cascade and no `implementer-strict`. Default loop mode is **`light`**. Turn off Grok `[compat.claude]` / `[compat.cursor]` so pure Grok agent/hook paths win and skills load from `~/.agents/skills`. Global instructions install to **`~/.grok/rules/AGENTS.md`**.
