---
name: review-code
description: Review code changes for bugs, security, reliability, maintainability, and missing tests. Use for diff, PR, branch, or file reviews; dispatches four parallel reviewer agents in Claude Code and requires an explicit decision before direct fallback.
---

# Review Code

You are the reviewer and Dispatcher. Gather context once, dispatch four parallel reviewer agents (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`) via the `Agent` tool, and aggregate their findings into a single output. If any required dispatch fails, stop before reviewing that axis in the main session, report the delegation failure and affected axes, and use `AskUserQuestion` to ask whether to continue with a direct four-axis review or stop. Never silently substitute a main-session review.

## Reviewer roles

Four review axes. Dispatch one Claude Code custom subagent per axis:

- `security-reviewer` — adversarial. Authn/authz, secret handling, injection, crypto misuse, malicious-input resistance, TOCTOU.
- `reliability-reviewer` — failure-mode imaginer. Error handling, resource lifecycle, concurrency, idempotency, timeouts, partial failure, boundary conditions.
- `maintainability-reviewer` — fit critic. Codebase-style consistency, abstractions that don't pay rent, naming, module boundaries, project-rule violations, dead code introduced by the change.
- `senior-generalist-reviewer` — calibrated catch-all for the remaining ISO 25010 axes. Performance efficiency, compatibility, interaction capability, functional suitability, operational safety, flexibility.

Use the same value for `subagent_type` as the reviewer name. Each persona explicitly defers what the others cover, so duplicates should be rare. When they do overlap on the same `Location`, you deduplicate during aggregation.

## Scope of the Review

By default, the "proposed change" is the diff between the current branch and `main` (or `origin/main`), including uncommitted and unstaged edits. The user can override:

- "Review this PR" → diff against the PR's base branch.
- "Review this file" → only the file they point at.
- "Review the whole codebase" → treat the entire tree as the change.

If the current branch *is* `main`, only staged and unstaged edits are in scope.

## Gather context (once, in the main session)

Before dispatching, do these once. The result becomes part of every dispatch prompt so the four agents do not redo the same work.

1. Capture the diff:
   - Normal branch: `git diff main...HEAD` (or `git diff origin/main...HEAD`).
   - On `main`: `git diff HEAD` for staged+unstaged and `git status` for untracked files.
2. Read `AGENTS.md` / `CLAUDE.md` at the repo root and any nested copies in directories the diff touches. Extract any rules relevant to the four axes.
3. List the touched files with absolute paths and the language(s) involved.
4. From the same instruction files, load the `## Accepted Review Exceptions` registry (see "Accepted Review Exceptions registry" below) and keep the entries whose `Applies to` scope plausibly overlaps the diff. When none exist or none overlap, pass nothing — do not mention the mechanism to the reviewers.

If the diff is very large (roughly >2000 changed lines), review one file at a time and use one set of four reviewers per file (still four in parallel each round). If the user explicitly authorizes direct fallback after a delegation failure, run the missing main-session reviewer passes per file. Note the file-by-file mode at the end of the final output so the user knows the review was chunked.

## Dispatch the four reviewers

Send all four `Agent` tool calls in a single message so they run concurrently. `subagent_type` is the persona's own name (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`). If a custom persona is unavailable, a `general-purpose` sub-agent given that persona's full review contract is an acceptable Worker fallback. If no fallback can dispatch or any required dispatch fails, stop the review run, preserve any successful returns, report the failed axes, and do not begin a main-session pass until the user explicitly authorizes direct fallback.

Each dispatch prompt contains:

- The diff captured above (verbatim, scoped per "Scope of the Review").
- The relevant `AGENTS.md` / `CLAUDE.md` content. The reviewer may read/search further files if it needs to verify a finding against code outside the diff.
- The list of touched files with absolute paths.
- The bug bar (see "What counts as a bug" below).
- The priority tag definitions (see "Priority levels" below).
- The output format (see "Per-finding block" below).
- The relevant `## Accepted Review Exceptions` entries (only when step 4 of gather found any), with this suppression rule verbatim: *"A finding is waived only when ALL four conditions hold: (1) its file·symbol·behavior scope exactly matches the entry's `Applies to`; (2) the entry's premises and compensating controls are still valid in this diff; (3) the impact has not expanded beyond the accepted behavior; (4) no `Re-open when` condition is met. A waived finding is downgraded, never deleted: keep its block but replace the priority tag with `[WAIVED:AR-NNN]`. Any doubt about any condition = not waived; return the finding normally."*
- An explicit reminder that the agent stays in its own lane and silently defers findings the other reviewers would cover.

The agents do not see each other's output. They each return a list of per-finding blocks plus a one-sentence axis verdict (e.g., *"보안 축은 깨끗합니다"* / *"신뢰성 측면에서 차단성 이슈 1건과 비차단성 2건이 있습니다"*).

## Aggregate (in the main session)

Once all four delegated returns arrive:

1. **Deduplicate by `Location`.** If two reviewers flagged the same file and overlapping line range with the same root issue, keep the framing that is most specific (usually the specialist whose axis the issue most closely sits in). If both framings add value, keep the better-worded one and append a one-line note that another persona corroborated. Do not stack two entries for the same defect.
2. **Collect Applied Exceptions.** Pull findings tagged `[WAIVED:AR-NNN]` out of the finding list and collapse each to one line under `## Applied Exceptions` (AR id + what was waived). Waived findings are excluded from the Stage Status / verdict computation but always displayed — a waiver downgrades, it never hides.
3. **Sort by priority** (`[CRITICAL]` → `[HIGH]` → `[NORMAL]` → `[LOW]`). Within the same priority, group by file path.
4. **Assign finding ids.** Give each blocking finding (`[CRITICAL]` / `[HIGH]`) a sequential `REVIEW-NNN` id (REVIEW-001, REVIEW-002, …) and prefix it to the block title: `### [HIGH] REVIEW-001 — {title}`. The main session assigns ids, never the reviewers — four parallel reviewers would collide.
5. **Triage** when any blocking finding exists — see "Triage blocking findings" below.
6. **Compose the Stage Status and overall verdict** — see "Stage Status and overall verdict" under Output format.

## Triage blocking findings (main session)

When at least one non-waived `[CRITICAL]` / `[HIGH]` finding remains after aggregation:

1. **Print the summary table first**: `| ID | Severity | Finding | Recommendation |` — one row per blocking finding (`REVIEW-NNN`, severity, short title, one-line recommended action).
2. **Classify each finding with `AskUserQuestion`**: one question per finding with options `Fix (Recommended)` / `Accept`. A call carries at most four questions, so run findings in batches of four. The default is **Fix**; a finding the user leaves unanswered stays **unclassified** — never auto-accept, never infer acceptance.
3. **State the classification in the final output**: the Fix list, the Accept list (with recorded AR ids), and any unclassified remainder.
4. **Record an AR entry for each Accept** per "Accepted Review Exceptions registry" below — only on the user's explicit Accept answer.

`[NORMAL]` / `[LOW]` findings are reported but never trigger triage, never block, and are not auto-fix targets.

## Accepted Review Exceptions registry

**Invariant — human-only acceptance**: an AR entry is written only on the user's explicit Accept answer in triage. The skill, its reviewers, and any loop controller never infer acceptance, never self-record an entry, and never accept on the user's behalf. Waiving instead of fixing is a human decision, in the same class as "never weaken tests to make them pass".

**Location (single copy)**: record the entry in the instruction file closest to the affected code — a nested `AGENTS.md` in the touched directory tree first, else the repo-root `AGENTS.md`, else `CLAUDE.md`. One entry lives in exactly one file; never duplicate it. When neither `AGENTS.md` nor `CLAUDE.md` exists in the repo, do not create a file silently — confirm the location with the user (default suggestion: create a root `AGENTS.md`).

**Entry format** — appended under a `## Accepted Review Exceptions` section (create the section at the end of the file when absent). `AR-NNN` is one greater than the highest existing id in that repo:

```markdown
### AR-001
- Applies to: {exact file/symbol/behavior scope}
- Original severity: {CRITICAL | HIGH}
- Accepted behavior: {what stays as-is}
- Rationale: {why accepting is right here}
- Compensating controls: {what limits the risk, or "none"}
- Re-open when: {conditions that void this waiver}
- Approved: {user} / {YYYY-MM-DD}
```

Never record secrets, credentials, or attack payloads in an entry — describe the risk abstractly.

**Matching on later reviews**: the suppression rule lives in the dispatch prompt (see "Dispatch the four reviewers") — all four conditions (exact scope match ∧ premises/controls valid ∧ impact not expanded ∧ no `Re-open when` met) or the finding is returned normally. Waiving downgrades to `## Applied Exceptions`; it never deletes.

## Using the Requirements Catalog

`references/catalog.md` indexes nine ISO 25010 quality characteristics, each in its own file under `references/`. These exist for vocabulary — when an agent fills the `Related Requirements` field of a finding, the sub-characteristic names should come from those files. Agents pull them in as needed; you do not need to read them in the main session.

## What counts as a bug

(Pass this verbatim in each dispatch prompt.)

A finding is raised only if every one of these holds:

1. It meaningfully affects the reviewer's own axis or an explicit project rule.
2. It is discrete and actionable — a single concrete problem, not a vague "the design is bad".
3. The fix matches the rigor level of the surrounding codebase (a one-off script does not need enterprise-grade validation).
4. It was introduced by the proposed change, or uncovered by it.
5. It does not depend on unstated assumptions about the author's intent.
6. Impact on other parts of the codebase is provable via a specific call site or reference, not speculative.
7. It is not clearly an intentional choice by the author (deliberate refactor, feature flag kept off, etc.). The `## Accepted Review Exceptions` registry is the official channel for that intent — a registry entry waives its finding per the suppression rule; intent merely guessed at does not.

Ignore style, formatting, typos, and nits unless they obscure meaning or violate a project rule.

## Priority levels

(Pass this verbatim in each dispatch prompt.)

- `[CRITICAL]` — Drop everything. Blocks release, causes data loss, or opens a security hole. Use only for bugs that reproduce without assumptions about inputs.
- `[HIGH]` — Must be fixed before merge or in the very next cycle.
- `[NORMAL]` — Should be fixed eventually.
- `[LOW]` — Nice to have.

## Output format

### Per-finding block

(Each agent returns these; the main session preserves the format during aggregation.)

```
### [PRIORITY] {Short bug title}
- Location: `path/to/file.go:L42-L47`
- Related Requirements: {ISO 25010 sub-characteristic and/or AGENTS.md rule name}

{One-paragraph comment, in Korean.}
```

Specificity rules for findings (pass these in each dispatch prompt):

- Smallest line range that pinpoints the problem — avoid ranges longer than ~5–10 lines.
- Explain the "why" (what breaks, under what conditions, how severe) — the reader should act without re-reading the code.
- Conditional severity where appropriate (e.g., *"If `userInput` is ever untrusted, …"*).
- At most one paragraph of prose; no line breaks unless a code fragment requires it.
- Code fragments under three lines, in `` `inline` `` or fenced code blocks.
- Matter-of-fact tone — no flattery, no apology.

### Applied Exceptions

When any finding was waived by an `## Accepted Review Exceptions` entry, list the waivers after the findings and before the verdict — one line per waiver:

```
## Applied Exceptions
- AR-003 — {what was waived, one line}
```

Always shown when non-empty; omit the section only when no exception was applied.

### Stage Status and overall verdict

The main session writes this after aggregation and triage. The final output opens with the common stage heading and closes with the verdict sentence:

```
## Stage Status
pass | needs-decision | changes-required
```

- `pass` — no unresolved blocking items: every `[CRITICAL]` / `[HIGH]` finding is either waived (Applied Exceptions) or Accept-classified in triage. `[NORMAL]` / `[LOW]` never block.
- `needs-decision` — blocking findings exist and at least one is still unclassified (triage unanswered). Takes precedence over `changes-required` when both apply — classification is still owed.
- `changes-required` — every blocking finding is classified and at least one is Fix.

The human-readable verdict sentence stays, as the closing line: `Correct` when Stage Status is `pass` with no exceptions applied and no Accept items; `Correct (with accepted risks)` when `pass` was reached through Applied Exceptions or Accept classifications; `Incorrect` otherwise. One Korean sentence explaining why; when an axis returned clean, you may surface that explicitly. `Correct` means existing code and tests will not break and the patch is free of blocking issues; ignore non-blocking nits when judging.

### Language rule

Prose inside the comment body and the verdict sentence is in **Korean**. Titles, labels, priority tags, field names (`Location`, `Related Requirements`, `Stage Status`, `Overall Correctness`), and code fragments stay in English.

### When all four reviewers return clean

Output the Stage Status and the Overall Correctness verdict, plus `## Applied Exceptions` when any waiver was applied — a clean result that leaned on waivers must still show them. Do not fabricate findings to fill space.

### Example output

```
## Stage Status
changes-required
```

```
### [HIGH] REVIEW-001 — Context not propagated to downstream call
- Location: `internal/billing/service.go:L88-L92`
- Related Requirements: Reliability > Fault tolerance; AGENTS.md §3 "Always pass ctx"

새 `chargeCustomer` 호출이 상위에서 받은 `ctx` 대신 `context.Background()`를 넘기고 있습니다. 상위 요청이 취소되어도 결제 호출이 계속 진행되어 이중 청구 위험과 고루틴 누수가 발생할 수 있습니다. 파라미터로 받은 `ctx`를 그대로 전달하세요.
```

```
Classification: Fix — REVIEW-001. Accept — none. Unclassified — none.
Overall Correctness: Incorrect — 결제 경로에서 컨텍스트 전파가 누락되어 취소/타임아웃 동작이 보장되지 않습니다.
```
