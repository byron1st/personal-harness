---
name: learn-from-manual-edits
description: Detect the user's manual edits on top of agent-written code in the working tree, infer the general preference behind each edit, and persist those preferences as conventions in the project's AGENTS.md and legacy CLAUDE.md when present. Use when the user says they manually changed or fixed code the agent wrote, even alongside a follow-up task.
---

# Learn from Manual Edits

When the user manually edits code the agent wrote, each edit is feedback: it shows how the user *would have wanted* the code written in the first place. This skill turns that feedback into persistent memory. The goal is that the same correction never has to be made twice — the next implementation should already follow the preference.

The working tree at invocation time typically contains a mix of **uncommitted agent edits and uncommitted user edits from the same session**. There is no git boundary between them, so git alone cannot separate the two. You can — because you know what you wrote.

## Step 1 — Separate the user's edits from your own

1. Enumerate everything that changed: `git status --porcelain` and `git diff HEAD --stat`. Ignore generated files (lockfiles, build output, `*_gen.go`, etc.).
2. Attribute each changed file:
   - **Files you never touched this session** → the entire change is the user's.
   - **Files you edited this session** → reconstruct the *final version you wrote* from the session context and compare it against the file's current content. Anything that differs is the user's edit.
3. For precise comparison, don't eyeball it. Write your reconstructed version to a temp file and diff it:

   ```bash
   # /tmp/agent_version mirrors the repo layout
   diff -u /tmp/agent_version/internal/service/user.go internal/service/user.go
   ```

4. Always re-read the current file content before comparing — never assume a file still matches what you last wrote.

**When attribution is uncertain** (long session, context was compacted, you can't faithfully reconstruct what you wrote): say so and show the user the ambiguous hunks, asking which ones are theirs. A wrong attribution recorded as a convention is worse than a question. Do not guess.

## Step 2 — Infer the intent and generalize

For each user edit, ask: *what general principle, had I known it, would have made me write this code the way it is now?*

An edit is worth recording only if it generalizes. Use these tests:

- **Beyond this spot** — would the same change apply to other files or future code, not just this one location?
- **How, not what** — does it change the *way* the code is written (structure, style, idiom) rather than *what* it does (behavior, business logic)?
- **Forward-actionable** — can it be phrased as guidance you could follow next time without seeing this diff?

Record things like: error-wrapping style, interface-first design, naming conventions, package layout, dependency-injection patterns, test structure, comment/doc style, preferred stdlib vs third-party choices.

Do **not** record: one-off bug fixes, business-logic corrections, typo fixes, changes tied to a single file's specific domain. Mention these in your report (Step 4) so the user knows you saw them — just don't persist them.

When several small edits share one theme (e.g. three renames that all shorten receiver names), merge them into a single rule rather than three entries.

## Step 3 — Record in AGENTS.md and legacy CLAUDE.md when present

Maintain a dedicated section in the project root instruction file. Prefer `AGENTS.md`; if only legacy `CLAUDE.md` exists, use that instead; if neither exists, create `AGENTS.md` and append the section at the end:

```markdown
## Conventions Learned from Manual Edits

<!-- Maintained by the learn-from-manual-edits skill. One bullet per rule. -->

### Style
- Wrap errors with `fmt.Errorf("...: %w", err)` including the failed operation; never return bare `err`. e.g. `return err` → `return fmt.Errorf("load user %s: %w", id, err)` (2026-06-13)

### Architecture
- Define consumer-side interfaces for services; constructors return the concrete type, callers depend on the interface. (2026-06-13)
```

Rules for maintaining the section:

- **One bullet per rule**: rule in one imperative sentence, optionally a compact `before → after` example, and the date observed. Group bullets under `### Style`, `### Architecture`, `### Naming`, `### Errors`, `### Testing`, `### Other` — create a category heading only when first needed.
- **Read the existing section before writing.** If an equivalent rule already exists, do not duplicate it — refine its wording if the new observation sharpens it, and update the date. If a new observation *contradicts* an existing rule, the newest preference wins: replace the old bullet.
- **Keep rules project-general.** No file paths or symbol names in the rule itself (examples may use them). If a rule only makes sense for one file, it failed the Step 2 filter and doesn't belong here.
- Don't touch anything else in the instructions file.

## Step 4 — Report, then continue

Report briefly:

- Which hunks you attributed to the user (one line per file is enough).
- The rules you recorded (quote the bullets).
- Edits you intentionally did **not** record (one-offs) and why, in one line.

Then, if the user's message included a follow-up task ("…차이점을 확인하고 이어서 X를 구현해"), continue with it immediately — applying the just-recorded conventions to everything you write from this point on.
