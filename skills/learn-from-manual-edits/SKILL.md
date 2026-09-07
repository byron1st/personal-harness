---
name: learn-from-manual-edits
description: Detect the user's manual edits on top of agent-written code in the working tree, infer the general preference behind each edit, and persist those preferences as conventions in the project's AGENTS.md. Use when the user says they manually changed or fixed code the agent wrote, even alongside a follow-up task.
---

# Learn from Manual Edits

When the user manually edits code the agent wrote, each edit is feedback: it shows how they *would have wanted* the code written in the first place. This skill turns that into persistent memory, so the same correction never has to be made twice.

## 1. Separate the user's edits from your own

The working tree typically holds uncommitted agent edits and uncommitted user edits from the same session, with no git boundary between them. Git alone cannot separate the two — you can, because you know what you wrote.

Enumerate what changed (`git status --porcelain`, `git diff HEAD --stat`), ignoring generated files. A file you never touched this session is entirely the user's. For a file you did edit, reconstruct the version *you* wrote from the session context and diff it against the current content — write your reconstruction to a temp file rather than eyeballing it. Re-read the current content first; never assume a file still matches what you last wrote.

**When attribution is uncertain** — long session, compacted context, no faithful reconstruction — say so and show the user the ambiguous hunks, asking which are theirs. A wrong attribution recorded as a convention is worse than a question. Do not guess.

## 2. Infer the intent and generalize

For each user edit: *what general principle, had I known it, would have made me write this the way it now reads?*

An edit is worth recording only if it generalizes, which means all three of:

- **Beyond this spot** — the same change would apply to other files and future code.
- **How, not what** — it changes the *way* code is written (structure, style, idiom), not what it does (behavior, business logic).
- **Forward-actionable** — it can be phrased as guidance followable next time without seeing this diff.

Worth recording: error-wrapping style, interface-first design, naming, package layout, dependency injection, test structure, comment and doc style, stdlib-vs-third-party preferences.

Not worth recording: one-off bug fixes, business-logic corrections, typo fixes, anything tied to one file's specific domain. Mention these in the report so the user knows you saw them — just do not persist them.

Several small edits sharing one theme merge into a single rule, not three entries.

## 3. Record

Maintain a dedicated section in the project root instruction file — `CLAUDE.md` when it exists, else `AGENTS.md`; if neither exists, create `CLAUDE.md` and append.

```markdown
## Conventions Learned from Manual Edits

<!-- Maintained by the learn-from-manual-edits skill. One bullet per rule. -->

### Style
- Wrap errors with `fmt.Errorf("...: %w", err)` including the failed operation; never return bare `err`. e.g. `return err` → `return fmt.Errorf("load user %s: %w", id, err)` (2026-06-13)

### Architecture
- Define consumer-side interfaces for services; constructors return the concrete type, callers depend on the interface. (2026-06-13)
```

- **One bullet per rule**: an imperative sentence, optionally a compact `before → after`, and the date observed. Grouped under `### Style` / `### Architecture` / `### Naming` / `### Errors` / `### Testing` / `### Other`, creating a heading only when first needed.
- **Read the section before writing.** An equivalent rule already there is refined and re-dated, never duplicated. A new observation that *contradicts* an existing rule replaces it — the newest preference wins.
- **Rules stay project-general.** No file paths or symbol names in the rule itself, though examples may use them. A rule that only makes sense for one file failed step 2.
- Touch nothing else in the file.

## 4. Report, then continue

Briefly: which hunks you attributed to the user (a line per file), the rules you recorded (quote the bullets), and in one line what you deliberately did not record and why.

Then, if the user's message carried a follow-up task, continue with it immediately — applying the just-recorded conventions to everything you write from here on.
