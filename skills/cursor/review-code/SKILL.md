---
name: review-code
description: Review code changes for bugs, security, reliability, maintainability, and missing tests. Use for diff, PR, branch, or file reviews; use Cursor subagents only when explicitly requested.
---

# Review Code

You are the reviewer. If the user explicitly asks for subagents, delegation, or parallel reviewer agents, act as the orchestrator: gather context once, dispatch four parallel Cursor reviewer subagents via the Task tool (`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`) and aggregate their findings into a single output. Otherwise, perform the same four-axis review in the main session.

## Reviewer roles

Four review axes. When delegation is explicitly requested, dispatch one Cursor custom subagent per axis:

- `security-reviewer` — adversarial. Authn/authz, secret handling, injection, crypto misuse, malicious-input resistance, TOCTOU.
- `reliability-reviewer` — failure-mode imaginer. Error handling, resource lifecycle, concurrency, idempotency, timeouts, partial failure, boundary conditions.
- `maintainability-reviewer` — fit critic. Codebase-style consistency, abstractions that don't pay rent, naming, module boundaries, project-rule violations, dead code introduced by the change.
- `senior-generalist-reviewer` — calibrated catch-all for the remaining ISO 25010 axes. Performance efficiency, compatibility, interaction capability, functional suitability, operational safety, flexibility.

Cursor subagent names are `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, and `senior-generalist-reviewer`. If a custom subagent is unavailable in the current Cursor session, fall back to Cursor's built-in `Explore` subagent with the corresponding persona instructions embedded in the prompt and mention the fallback in the final summary.

Each persona explicitly defers what the others cover, so duplicates should be rare. When they do overlap on the same `Location`, you deduplicate during aggregation.

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

If the diff is very large (roughly >2000 changed lines), review one file at a time. When delegation was explicitly requested, use one set of four reviewers per file (still four in parallel each round). Otherwise, run the four main-session reviewer passes per file. Note the file-by-file mode at the end of the final output so the user knows the review was chunked.

## Run the four reviewers

If the user explicitly requested subagents or parallel review, spawn all four Cursor custom reviewer subagents in parallel (multiple Task tool calls in a single turn) so they run concurrently. If not, run the four reviewer passes in the main session without spawning agents.

Each delegated prompt, or each main-session reviewer pass, contains:

- The diff captured above (verbatim, scoped per "Scope of the Review").
- The relevant `AGENTS.md` / `CLAUDE.md` content. The reviewer may read/search further files if it needs to verify a finding against code outside the diff.
- The list of touched files with absolute paths.
- The bug bar (see "What counts as a bug" below).
- The priority tag definitions (see "Priority levels" below).
- The output format (see "Per-finding block" below).
- An explicit reminder that the agent stays in its own lane and silently defers findings the other reviewers would cover.

When using delegated reviewers, the agents do not see each other's output. They each return a list of per-finding blocks plus a one-sentence axis verdict (e.g., *"보안 축은 깨끗합니다"* / *"신뢰성 측면에서 차단성 이슈 1건과 비차단성 2건이 있습니다"*).

## Aggregate (in the main session)

Once all four delegated returns arrive, or once the main-session reviewer passes are complete:

1. **Deduplicate by `Location`.** If two reviewers flagged the same file and overlapping line range with the same root issue, keep the framing that is most specific (usually the specialist whose axis the issue most closely sits in). If both framings add value, keep the better-worded one and append a one-line note that another persona corroborated. Do not stack two entries for the same defect.
2. **Sort by priority** (`[CRITICAL]` → `[HIGH]` → `[NORMAL]` → `[LOW]`). Within the same priority, group by file path.
3. **Compose the overall verdict**: `Correct` if no blocking findings (`[CRITICAL]` or `[HIGH]`); `Incorrect` otherwise. One Korean sentence explaining why. When an axis returned clean, you may surface that explicitly in the verdict sentence (e.g., *"보안·유지보수성 축은 깨끗하나 신뢰성에서 컨텍스트 전파 누락이 발견되었습니다."*).

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
7. It is not clearly an intentional choice by the author (deliberate refactor, feature flag kept off, etc.).

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

### Overall verdict

The main session writes this after aggregation. One of `Correct` or `Incorrect`, plus one Korean sentence explaining why. `Correct` means existing code and tests will not break and the patch is free of blocking issues; ignore non-blocking nits when judging.

### Language rule

Prose inside the comment body and the verdict sentence is in **Korean**. Titles, labels, priority tags, field names (`Location`, `Related Requirements`, `Overall Correctness`), and code fragments stay in English.

### When all four reviewers return clean

Output only the Overall Correctness verdict. Do not fabricate findings to fill space.

### Example output

```
### [HIGH] Context not propagated to downstream call
- Location: `internal/billing/service.go:L88-L92`
- Related Requirements: Reliability > Fault tolerance; AGENTS.md §3 "Always pass ctx"

새 `chargeCustomer` 호출이 상위에서 받은 `ctx` 대신 `context.Background()`를 넘기고 있습니다. 상위 요청이 취소되어도 결제 호출이 계속 진행되어 이중 청구 위험과 고루틴 누수가 발생할 수 있습니다. 파라미터로 받은 `ctx`를 그대로 전달하세요.
```

```
Overall Correctness: Incorrect — 결제 경로에서 컨텍스트 전파가 누락되어 취소/타임아웃 동작이 보장되지 않습니다.
```
