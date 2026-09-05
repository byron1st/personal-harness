---
name: review-code
description: Review code changes for bugs, security, reliability, maintainability, and missing tests. Use for diff, PR, branch, or file reviews.
---

# Review Code

One file, two audiences. This skill does not name a host spawn tool.

- **Executor** — a review-axis persona. Reads the diff, reports findings for its own axis, follows that persona body's `## Reporting contract`.
- **Caller** — the current session. Standalone `/review-code` or `dev-loop` in REVIEWING. Gathers scope once, starts the named axis personas as blocking children in parallel, then aggregates, filters, triages, records AR, and writes Stage Status.

Personas do not start children. Spawn failure is the caller's: ask the user whether to continue this stage in the current session or stop. Never silently substitute a main-session review.

## Reviewer roles

Four review axes. Start one persona per axis:

- `security-reviewer` — adversarial. Authn/authz, secret handling, injection, crypto misuse, malicious-input resistance, TOCTOU.
- `reliability-reviewer` — failure-mode imaginer. Error handling, resource lifecycle, concurrency, idempotency, timeouts, partial failure, boundary conditions.
- `maintainability-reviewer` — fit critic. Codebase-style consistency, abstractions that don't pay rent, naming, module boundaries, project-rule violations, dead code introduced by the change.
- `senior-generalist-reviewer` — calibrated catch-all for the remaining ISO 25010 axes. Performance efficiency, compatibility, interaction capability, functional suitability, operational safety, flexibility.

Each persona explicitly defers what the others cover, so duplicates should be rare. When they do overlap on the same `Location`, the caller deduplicates during aggregation.

**Axis subset**: the caller may name a subset of these axes, and the default is **all four**. `dev-loop` mode `light` names `maintainability-reviewer` + `senior-generalist-reviewer`; a user may ask for any subset directly. Start exactly the named axes in parallel and run the rest of this skill unchanged — aggregation, triage, the AR registry, and Stage Status do not care how many axes reported. State which axes ran at the top of the final output: a clean verdict from a subset is a statement about what was looked at, not about the change, and the axes that did not run are exactly the ones nobody checked.

The loop names the axis set for the mode. Do not leave axis selection to description matching.

## Scope of the Review

By default, the "proposed change" is the diff between the current branch and `main` (or `origin/main`), including uncommitted and unstaged edits. The user can override:

- "Review this PR" → diff against the PR's base branch.
- "Review this file" → only the file they point at.
- "Review the whole codebase" → treat the entire tree as the change.

If the current branch *is* `main`, only staged and unstaged edits are in scope.

## Caller: gather context (once)

Before starting personas, do these once. The result becomes part of every persona brief so the axes do not redo the same work. The loop may already have run `$HOME/.agents/scripts/resolve-scope.sh`; if so, use that JSON and do not rediscover.

1. Capture the diff:
   - Normal branch: `git diff main...HEAD` (or `git diff origin/main...HEAD`).
   - On `main`: `git diff HEAD` for staged+unstaged and `git status` for untracked files.
2. Read `AGENTS.md` / `CLAUDE.md` at the repo root and any nested copies in directories the diff touches. Extract any rules relevant to the four axes.
3. List the touched files with absolute paths and the language(s) involved. `$HOME/.agents/scripts/resolve-scope.sh {branch|head|uncommitted|all}` returns both — plus the diff range used in step 1 — as one JSON blob. These are shell facts; computing them once here is what stops each persona from re-deriving them.
4. From the same instruction files, load the `## Accepted Review Exceptions` registry (see "Accepted Review Exceptions registry" below) and keep the entries whose `Applies to` scope plausibly overlaps the diff. When none exist or none overlap, pass nothing — do not mention the mechanism to the reviewers.

If the diff is very large (roughly >2000 changed lines), review one file at a time and use one set of personas per file (still all started axes in parallel each round). If the user explicitly authorizes running a missing axis in the current session after a start failure, run that pass per file. Note the file-by-file mode at the end of the final output so the user knows the review was chunked.

## Caller: start the axis personas

Start all required axis personas in parallel as blocking children — all four by default, or exactly the axes the caller named (see "Axis subset" above). If a named persona cannot start, stop the review run, preserve any successful returns, report the failed axes, and ask the user whether to continue those axes in the current session or stop. Do not begin a current-session pass until the user explicitly authorizes it.

**Order the brief stable-first.** Prefix caching matches on a prefix, so anything that varies invalidates everything after it. Compose each persona brief in this order — never the reverse:

1. **Invariant** — nothing. The bug bar, priority definitions, confidence scale, per-finding block, specificity rules, and lane reminder are **not passed at all**: they live in each reviewer's own body (the persona file's `## Reporting contract` section), where they are part of a cached system prompt instead of being re-sent four times every round. Reference that section; do not restate it here or inline it into the brief. Do not point at `agents/<platform>/` paths.
2. **Semi-stable** — the relevant `AGENTS.md` / `CLAUDE.md` content, and the list of touched files with absolute paths. The reviewer may read/search further files if it needs to verify a finding against code outside the diff.
3. **Conditional** — the relevant `## Accepted Review Exceptions` entries, only when step 4 of gather found any, with this suppression rule verbatim: *"A finding is waived only when ALL four conditions hold: (1) its file·symbol·behavior scope exactly matches the entry's `Applies to`; (2) the entry's premises and compensating controls are still valid in this diff; (3) the impact has not expanded beyond the accepted behavior; (4) no `Re-open when` condition is met. A waived finding is downgraded, never deleted: keep its block but replace the priority tag with `[WAIVED:AR-NNN]`. Any doubt about any condition = not waived; return the finding normally."* This one stays in the brief because it is only sent when entries exist.
4. **Volatile** — the diff (verbatim, scoped per "Scope of the Review"). Last, always.

The personas do not see each other's output. They each return a list of per-finding blocks plus a one-sentence axis verdict (e.g., *"보안 축은 깨끗합니다"* / *"신뢰성 측면에서 차단성 이슈 1건과 비차단성 2건이 있습니다"*).

## Executor: axis findings

A review-axis persona reads the brief, inspects the diff for its own axis, and returns per-finding blocks plus a one-sentence axis verdict. It follows its own body's `## Reporting contract`. It does not assign `REVIEW-NNN` ids (the caller does, after aggregation). It does not start another persona. It does not ask the user.

## Caller: aggregate

Once every started return arrives:

1. **Deduplicate by `Location`.** If two reviewers flagged the same file and overlapping line range with the same root issue, keep the framing that is most specific (usually the specialist whose axis the issue most closely sits in). If both framings add value, keep the better-worded one and append a one-line note that another persona corroborated. Do not stack two entries for the same defect. When two framings differ in `Confidence`, keep the higher one — corroboration is evidence.
2. **Filter.** This is where suppression happens now that the reviewers no longer self-censor. Judge each finding on `Confidence` × priority:
   - `Confidence: high` — keep, at its stated priority.
   - `Confidence: medium` — keep. Verify it yourself when it is `[CRITICAL]` / `[HIGH]`: read the cited code, and either confirm the priority or demote it with a one-line note saying why.
   - `Confidence: low` — keep `[CRITICAL]` / `[HIGH]` ones and mark them clearly as unverified; demote `[NORMAL]` / `[LOW]` ones into a single `## Low-confidence notes` list of one-liners, not full blocks.
   - Drop only what is genuinely out of scope (a pre-existing issue the diff did not touch, a duplicate of an `## Applied Exceptions` waiver, an explicit taste preference). **Uncertainty is never a reason to drop** — that is what the demotion path is for.
3. **Collect Applied Exceptions.** Pull findings tagged `[WAIVED:AR-NNN]` out of the finding list and collapse each to one line under `## Applied Exceptions` (AR id + what was waived). Waived findings are excluded from the Stage Status / verdict computation but always displayed — a waiver downgrades, it never hides.
4. **Sort by priority** (`[CRITICAL]` → `[HIGH]` → `[NORMAL]` → `[LOW]`). Within the same priority, group by file path.
5. **Assign finding ids.** Give each blocking finding (`[CRITICAL]` / `[HIGH]`) that survived the filter a sequential `REVIEW-NNN` id (REVIEW-001, REVIEW-002, …) and prefix it to the block title: `### [HIGH] REVIEW-001 — {title}`. The caller assigns ids, never the reviewers — four parallel reviewers would collide.
6. **Triage** when any blocking finding exists — see "Triage blocking findings" below.
7. **Compose the Stage Status and overall verdict** — see "Stage Status and overall verdict" under Output format.

## Triage blocking findings (caller)

When at least one non-waived `[CRITICAL]` / `[HIGH]` finding remains after aggregation:

1. **Print the summary table first**: `| ID | Severity | Finding | Recommendation |` — one row per blocking finding (`REVIEW-NNN`, severity, short title, one-line recommended action).
2. **Ask the user to classify each finding**: one question per finding with options `Fix (Recommended)` / `Accept`. Ask at most four findings at a time. The default is **Fix**; a finding the user leaves unanswered stays **unclassified** — never auto-accept, never infer acceptance.
3. **State the classification in the final output**: the Fix list, the Accept list (with recorded AR ids), and any unclassified remainder.
4. **Record an AR entry for each Accept** per "Accepted Review Exceptions registry" below — only on the user's explicit Accept answer.

`[NORMAL]` / `[LOW]` findings are reported but never trigger triage, never block, and are not auto-fix targets.

## Accepted Review Exceptions registry

**Invariant — human-only acceptance**: an AR entry is written only on the user's explicit Accept answer in triage. The skill, its reviewers, and any loop controller never infer acceptance, never self-record an entry, and never accept on the user's behalf. Waiving instead of fixing is a human decision, in the same class as "never weaken tests to make them pass".

**"Triage" here means both gates.** This registry is shared: `review-code`'s own triage of `REVIEW-NNN` findings, and the loops' TESTING gate where the user classifies `test-dev`'s suspected defects (`TEST-NNN`) as Fix or Accept. The mechanism is identical in both — only the id space and the severity value differ. All three loop modes use it.

**Location (single copy)**: record the entry in the instruction file closest to the affected code — a nested `AGENTS.md` in the touched directory tree first, else the repo-root `AGENTS.md`, else `CLAUDE.md`. One entry lives in exactly one file; never duplicate it. When neither `AGENTS.md` nor `CLAUDE.md` exists in the repo, do not create a file silently — confirm the location with the user (default suggestion: create a root `AGENTS.md`).

**Entry format** — appended under a `## Accepted Review Exceptions` section (create the section at the end of the file when absent). `AR-NNN` is one greater than the highest existing id in that repo:

```markdown
### AR-001
- Applies to: {exact file/symbol/behavior scope}
- Original severity: {CRITICAL | HIGH | TEST (suspected defect)}
- Accepted behavior: {what stays as-is}
- Rationale: {why accepting is right here}
- Compensating controls: {what limits the risk, or "none"}
- Re-open when: {conditions that void this waiver}
- Approved: {user} / {YYYY-MM-DD}
```

`TEST (suspected defect)` is the severity for an accepted `TEST-NNN` finding: `test-dev` assigns no priority tag, so there is no `CRITICAL` / `HIGH` to carry over. Its `Applies to` names the failing test and the behavior it pins, and `Accepted behavior` records that the test stays red or skipped.

Never record secrets, credentials, or attack payloads in an entry — describe the risk abstractly.

**Matching on later reviews**: the suppression rule lives in the persona brief (see "Caller: start the axis personas") — all four conditions (exact scope match ∧ premises/controls valid ∧ impact not expanded ∧ no `Re-open when` met) or the finding is returned normally. Waiving downgrades to `## Applied Exceptions`; it never deletes.

## Using the Requirements Catalog

`references/catalog.md` indexes nine ISO 25010 quality characteristics, each in its own file under `references/`. These exist for vocabulary — when an agent fills the `Related Requirements` field of a finding, the sub-characteristic names should come from those files. Agents pull them in as needed; you do not need to read them in the caller session.

## The bug bar lives in the reviewers

The bug bar, the priority definitions, the confidence scale, the per-finding block, and the specificity rules are **not defined here and not passed in the persona brief**. They are in each reviewer's `## Reporting contract` section, identical across all four.

Two reasons. **Cost**: it is static text that used to be re-sent four times every round, and a system prompt is cached where a dispatch prompt's tail is not. **Recall**: the old bar was seven AND-ed conditions plus *"ignore style, formatting, typos, and nits"* — the shape current models follow literally, dropping findings they actually detected. The reviewers now report everything they can name concretely, tagged with `Confidence`, and **this skill filters during aggregation**. Filtering downstream is recoverable; a reviewer's silence is not.

Keep it that way. Re-adding a suppression instruction to the persona brief undoes both benefits at once.

## Output format

### Per-finding block

The block shape and the specificity rules are defined in the reviewers' `## Reporting contract` and are **not** passed in the persona brief. The caller preserves the format during aggregation, adding only the `REVIEW-NNN` id to the title:

```
### [HIGH] REVIEW-001 — {Short bug title}
- Location: `path/to/file.go:L42-L47`
- Confidence: high | medium | low
- Related Requirements: {ISO 25010 sub-characteristic and/or AGENTS.md rule name}

{One-paragraph comment, in Korean.}
```

Keep `Confidence` in the displayed block. It is what tells the user whether a `[HIGH]` was traced or inferred, and it is the basis for the aggregation filter above.

### Low-confidence notes

When step 2 demoted any `Confidence: low` non-blocking findings, list them after the findings as one-liners:

```
## Low-confidence notes
- `path/to/file.ts:L20` — {one line, what was suspected and what could not be verified}
```

These never block, never get ids, and never enter triage. They exist so a reviewer's uncertain observation reaches the user instead of being discarded — the whole point of moving the filter downstream.

### Applied Exceptions

When any finding was waived by an `## Accepted Review Exceptions` entry, list the waivers after the findings and before the verdict — one line per waiver:

```
## Applied Exceptions
- AR-003 — {what was waived, one line}
```

Always shown when non-empty; omit the section only when no exception was applied.

### Stage Status and overall verdict

The caller writes this after aggregation and triage. The final output opens with the common stage heading and closes with the verdict sentence:

```
## Stage Status
pass | needs-decision | changes-required
```

- `pass` — no unresolved blocking items: every `[CRITICAL]` / `[HIGH]` finding is either waived (Applied Exceptions) or Accept-classified in triage. `[NORMAL]` / `[LOW]` never block.
- `needs-decision` — blocking findings exist and at least one is still unclassified (triage unanswered). Takes precedence over `changes-required` when both apply — classification is still owed.
- `changes-required` — every blocking finding is classified and at least one is Fix.

The human-readable verdict sentence stays, as the closing line: `Correct` when Stage Status is `pass` with no exceptions applied and no Accept items; `Correct (with accepted risks)` when `pass` was reached through Applied Exceptions or Accept classifications; `Incorrect` otherwise. One Korean sentence explaining why; when an axis returned clean, you may surface that explicitly. `Correct` means existing code and tests will not break and the patch is free of blocking issues; ignore non-blocking nits when judging.

### Language rule

Prose inside the comment body and the verdict sentence is in **Korean**. Titles, labels, priority tags, field names (`Location`, `Confidence`, `Related Requirements`, `Stage Status`, `Overall Correctness`), and code fragments stay in English.

### When every started reviewer returns clean

Output the Stage Status and the Overall Correctness verdict, plus `## Applied Exceptions` when any waiver was applied — a clean result that leaned on waivers must still show them. Do not fabricate findings to fill space. When the run used an axis subset, name the axes that ran alongside the verdict so a clean result is not read as broader than it is.

### Example output

```
## Stage Status
changes-required
```

```
### [HIGH] REVIEW-001 — Context not propagated to downstream call
- Location: `internal/billing/service.go:L88-L92`
- Confidence: high
- Related Requirements: Reliability > Fault tolerance; AGENTS.md §3 "Always pass ctx"

새 `chargeCustomer` 호출이 상위에서 받은 `ctx` 대신 `context.Background()`를 넘기고 있습니다. 상위 요청이 취소되어도 결제 호출이 계속 진행되어 이중 청구 위험과 고루틴 누수가 발생할 수 있습니다. 파라미터로 받은 `ctx`를 그대로 전달하세요.
```

```
Classification: Fix — REVIEW-001. Accept — none. Unclassified — none.
Overall Correctness: Incorrect — 결제 경로에서 컨텍스트 전파가 누락되어 취소/타임아웃 동작이 보장되지 않습니다.
```
