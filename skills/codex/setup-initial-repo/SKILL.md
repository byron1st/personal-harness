---
name: setup-initial-repo
description: Bootstrap a new repository from SPEC.md with an agent instruction file, docs conventions, Makefile, .gitignore, git identity, and optional remote. Use for initial project setup.
---

# Setup Initial Repo

Bootstrap a new project repository from a `SPEC.md` document. This skill produces the minimum scaffolding an AI coding agent and a developer need to start working immediately:

- `CLAUDE.md` or `AGENTS.md` (depending on the agent in use)
- `docs/` with the language-specific conventions file
- `Makefile` whose targets back every command referenced from the agent file
- `.gitignore`
- An initialized git repository with the right user identity (personal or work)
- A remote `origin` (existing URL, or a freshly-created private repo via `gh`)

## Process

The steps below are sequential. Confirm with the user before any irreversible action (overwriting an existing file, creating a remote repo, running the first commit).

### Step 1: Locate SPEC.md

Look for the spec in this order and stop at the first hit:

1. `docs/SPEC.md`
2. `SPEC.md` (project root)

If neither exists, do **not** invent one. Ask the user where the spec lives or suggest running `/spec-creator` first. The rest of the skill assumes a real SPEC.md, so do not proceed without it.

Once located, read the file fully. The Tech Stack section drives language detection and the rest of the scaffolding.

### Step 2: Decide the agent file (CLAUDE.md vs AGENTS.md)

Different coding agents read different filenames. Pick one — never both — to avoid drift.

1. If exactly one of `CLAUDE.md` or `AGENTS.md` already exists in the project root, use that one and warn the user before any modification.
2. If neither exists, ask the user which agent file they want. Frame the choice as: "Which AI coding agent will primarily use this repo? Claude Code → CLAUDE.md, Codex / other agents → AGENTS.md."
3. If both exist, ask the user which to keep as the canonical file and recommend deleting the other to prevent duplicated instructions.

Hold the chosen path as `${AGENT_FILE}` for the rest of the run.

### Step 3: Detect the language and pick the conventions file

Read the Tech Stack section from SPEC.md and detect the primary language. Only the conventions file is language-specific; the Makefile and `.gitignore` templates are common and the agent fills in language-specific details from the conventions and project state.

| Detected language | Conventions reference |
|---|---|
| Go | [references/go.md](references/go.md) |

If the language has no matching conventions file, tell the user and ask whether to proceed without copying conventions (the agent file will skip the language-specific link) or to stop and add support first.

### Step 4: Determine identity (personal vs. work)

Ask the user to choose "Personal" or "Work". The answer drives:

- Which git `user.email` and `user.name` to set
- Whether the skill may auto-create a remote with `gh` (only allowed for personal repos)

Once the context is known, ask for the email and name to use. Show the values you intend to set and require explicit confirmation before applying them. Never reuse identities from another machine or session — always confirm.

### Step 5: Initialize git and apply local config

Check whether the working directory is a git repository:

```bash
git rev-parse --git-dir 2>/dev/null
```

If the command fails, run `git init`. Then apply the identity **locally** (not globally) so other repos on the machine are unaffected:

```bash
git config user.email "<email>"
git config user.name "<name>"
```

Verify with `git config --local --list | grep user`.

### Step 6: Set up the remote origin

Ask: "Does an `origin` repository already exist for this project?"

- **Yes → existing URL:** Ask for the SSH or HTTPS URL, validate the format, and run `git remote add origin <URL>` (or `git remote set-url origin <URL>` if origin already exists).
- **No → ONLY for the Personal repository:** Ask for the repo name (default to the working directory's basename, but let the user override). Confirm visibility (`--private` is the default for this skill) and create with:

  ```bash
  gh repo create <owner>/<name> --private --source=. --remote=origin
  ```

  If `gh` is not authenticated, tell the user to run `gh auth login` and pause.
- **No → for the Work repository:** Do **not** auto-create. Explain that work repos generally need to be created through the company process (organization settings, approvals, naming policies). Ask the user to create the repo on the work git host and come back with the URL.

After wiring origin, do not push yet — wait for the first commit at the end.

### Step 7: Generate `.gitignore`

Start from the common baseline in [references/gitignore.md](references/gitignore.md) and append language-, framework-, and tooling-specific entries based on SPEC.md's Tech Stack and what is actually in the working directory (build dirs, coverage outputs, dependency caches, etc.).

If `.gitignore` already exists, diff it against the result — if the user has custom entries, ask before overwriting; otherwise overwrite cleanly.

### Step 8: Copy the language conventions into `docs/`

1. Create `docs/` if it does not exist.
2. Copy the reference file into `docs/` using the canonical name `docs/{language}-conventions.md` (e.g., `docs/go-conventions.md`).
3. If the file already exists, diff the contents — if there are user-authored sections, ask before overwriting; otherwise overwrite cleanly.

This copy is what the agent file links to, so the agent reads project-local conventions, not the skill's references.

### Step 9: Generate the Makefile

The Makefile is the single source of truth for executable commands. Every command quoted from `${AGENT_FILE}` later must exist as a Makefile target — no bare `go test ./...` in the agent file.

Use the target checklist in [references/makefile.md](references/makefile.md). The reference lists which targets must exist; the agent fills in each recipe based on the project's language, conventions, and state:

- Pick the idiomatic CLI for the language (e.g., `go test -race ./...` vs `pytest -v`).
- Decide variables to lift to the top (binary name, main package path, build dir, etc.) so future edits stay in one place.
- Drop targets that do not apply (e.g., `build`/`run` for library-only projects, `lint-fix` if the linter has no fix mode).
- Add project-specific targets only when they earn their place — never as filler.

### Step 10: Generate `${AGENT_FILE}`

Use the section structure in [references/agent-md-template.md](references/agent-md-template.md). The reference lists which sections to include and the constraints; the agent writes the actual content using SPEC.md, project state, and the language conventions file.

Key requirements (the reference covers them in detail):

- Every Core Commands entry must back to a Makefile target. If one is missing, add it to the Makefile first.
- The Code Conventions section includes only 3–5 highlights; the full list lives in `docs/{language}-conventions.md` and is linked from References.
- Boundaries are NEVER rules with concrete alternatives.
- The file is **English-only** and **under 150 lines**, regardless of conversation or SPEC.md language.

### Step 11: Review, confirm, and commit

Before the first commit, present a summary to the user:

```
✓ Initialized git repo (or detected existing)
✓ Set local user.email = <email>, user.name = <name>
✓ Remote origin: <URL>
✓ Created: ${AGENT_FILE}, .gitignore, Makefile
✓ Created: docs/{language}-conventions.md
✓ Updated: <list any other modifications>
```

Ask whether to make the initial commit:

```bash
git add -A
git commit -m "chore: initial project scaffolding"
```

Do **not** push automatically. Tell the user to push manually with `git push -u origin main` (or whichever default branch they prefer) so they can review the local commit first.

## Writing Rules

- The agent file (`CLAUDE.md` / `AGENTS.md`) is in **English**, regardless of conversation language.
- Every executable command quoted from the agent file must exist as a Makefile target.
- The agent file stays under 150 lines — push deeper detail into `docs/` references.
- Identity setup is **always local** to the repo (`git config` without `--global`).
- The skill **never** runs `git push` automatically.
- The skill **never** auto-creates remote repos for work contexts.
- For overwriting existing files (`.gitignore`, `${AGENT_FILE}`, `Makefile`), always show a diff or ask first.
