---
name: commit-code
description: "Commit current changes. Open a PR/MR only when asked (including 'request-merge'). Dirty tree + PR request: commit first, then create/update."
---

# Commit Code

Commit the current modified files. Open a PR/MR **only** when the invocation asks for one — never ask about a PR/MR after a commit-only run, and never infer one from the branch being ahead of `main`.

| Signal | Open PR/MR? |
| --- | --- |
| `request-merge`, PR 열어, open a PR, create a PR, MR 열어, open an MR, create an MR, open a pull request, 머지 요청, 커밋하고 PR, commit and open a PR | yes |
| omitted, Commit it, `/commit-code`, 커밋해, 커밋해줘 | no |

An utterance both asking for and forbidding a PR/MR → ask. Pushing without a PR/MR is still fine when the user clearly asked to push; that is not a PR/MR.

## Repository type

Take it from the SessionStart hook's context: `repo_type: work` or `repo_type: personal`. **Do not reclassify from the origin URL inside this skill.** If the session context is missing, unclear, or contradictory, ask the user before continuing.

## Flow

1. **Dirty tree** (staged or unstaged changes) → commit, below. **Clean tree + commit-only** → report there is nothing to commit and stop.
2. After committing — or when skipping the commit because the tree was already clean — a PR/MR intent reads [references/pr-mr.md](references/pr-mr.md) and follows it. That path implies push. On a commit-only run, do not open `pr-mr.md`, `personal.md`, or `work.md` at all.
3. Commit-only: after the docs-drift check, push **only** if the user clearly asked to push.

## Commit

**Verify the committer identity first** — work repositories commit as `$WORK_GIT_EMAIL` / `$WORK_GIT_NAME`, personal ones as `$PERSONAL_GIT_EMAIL` / `$PERSONAL_GIT_NAME`.

**Work repositories only**: extract the Jira ticket from the branch name via `[A-Z]+-[0-9]+`. If it cannot be extracted, ask for it.

Stage all modified files, staged and unstaged, **except** binaries accidentally built for testing.

Title format: `{PREFIX}: {title}`, where `{PREFIX}` is one of `feat`, `fix`, `refactor`, `test`, `ci`, `chore`. With a Jira ticket: `{PREFIX}: [{TICKET}] {title}`. The title is one concise line, **always starting lowercase**, with no trailing period.

**Never add `Co-Authored-By`.**

## Documentation drift check

After a successful commit and before any push or PR/MR, run a **read-only** check of the commit (e.g. `git show HEAD^..HEAD`) against the repository's documentation — `AGENTS.md`, legacy `CLAUDE.md` when present, `README.md`, and affected documents under `docs/`. Compare the committed code, configuration, commands, interfaces, and behavior with what those documents claim.

**Change nothing.** Do not modify, stage, amend, or create documentation as part of this check.

Then report one of three outcomes:

- No update needed — say so.
- An update appears necessary — state that no files were changed, then list each likely document with a concise description of what is now stale or missing (setup or execution commands, configuration and environment variables, public API or CLI behavior, architecture and flow descriptions, developer instructions).
- Evidence insufficient to judge — label the document a manual-review candidate rather than claiming it needs an update.
