---
name: application-research-sync
description: Sync repository-local docs/agents/research files with code changes. Use after implementation, when research docs may be stale, or when asked to update research against uncommitted changes, a commit range, or the full codebase.
---

# Application Research Sync

Bring `docs/agents/research/` back in line with code that has moved on. Typically run after implementation and before committing, but a commit range or a full-codebase pass makes it useful any time the research may have drifted.

Research files are investigative documents describing an Application's flows and architecture — the format, frontmatter, and index rules are `plan-dev`'s [research-file.md](../plan-dev/references/research-file.md). This skill only updates them.

## 1. Scope

Ask which scope to detect changes against, unless the request already names one:

| Mode | Changes | How |
| --- | --- | --- |
| **Uncommitted** | staged + unstaged | `git diff HEAD` |
| **Since commit** | everything after a commit | `git diff <commit-hash>` |
| **Full codebase** | none — read the tree as it stands | no diff |

For the two diff modes, an empty diff means there is nothing to sync: say so and stop. Full-codebase mode compares each research file against the current source directly, which is what to use when files have drifted gradually with no single change point.

The Application name is the repository directory name: `basename $(git rev-parse --show-toplevel)`.

A plan file under `docs/agents/dev/` is useful context for what the change was trying to achieve — take it from the session, or ask. It is optional in full-codebase mode.

## 2. Pick the files that actually need updating

Read `docs/agents/research/index.md` and keep the rows for this Application. Each row's `Description` says what that file investigates — that is the field to judge against, which is why the index is read before any research file is opened.

If `index.md` is missing but research files exist, build it first from their frontmatter, then continue. If there are no research files at all, report that and stop.

A file needs updating when the change touches the feature, flow, or architecture its description covers, or when the modified files and modules are ones it describes. **When in doubt, include it** — one unnecessary review is cheaper than leaving a document wrong.

## 3. Update

Read each selected file and apply **targeted** edits. Do not rewrite a file to change part of it: preserve the existing tone, structure, and formatting, revise what is now false, and weave new flows into the structure that is already there. Update code snippets to match current code, and verify against the actual source whenever a detail is uncertain.

Update frontmatter only when the content materially changed — and when `Description` changes, update the matching `index.md` row in the same step.

Two things this skill must not do:

- **Leave no trace of the update.** No "changed due to commit X" notes, no changelog. The file should read as though it always described the current state.
- **Keep them investigative.** These are documents written to understand a system, not API references or code comments. Preserve the exploratory, explanatory register.

## 4. Report

- Updated files, with a one-line summary of what changed in each.
- Whether `index.md` was created or updated.
- Files excluded, each with a short reason.
- Anything needing the user's own review.
