# Makefile Target Checklist

The Makefile is the single source of truth for executable commands in the repo. Every command quoted from the agent file (`CLAUDE.md` / `AGENTS.md`) must back to a target listed here.

This file lists **which targets must exist**. The agent fills in each target's recipe using the project's language and tooling.

## Required targets

- `build` — compile the project. Skip for library-only projects.
- `test` — run the full test suite. Enable race / coverage flags when the language supports them.
- `test-single` — run a single test by name. Parameterize so the agent file can document a stable invocation (e.g., `make test-single PKG=... TEST=...`).
- `lint` — run the linter.
- `lint-fix` — run the linter with auto-fix where supported. If the linter has no fix mode, leave the target out and remove the matching line from the agent file.
- `run` — build then run the default binary or entry point. Skip for library-only projects.
- `tidy` — clean up dependency manifests (e.g., `go mod tidy`, `npm prune`, `poetry lock --no-update`).
- `clean` — remove build artifacts produced by `build`.
- `help` — list every target with its description, harvested from `## ...` comments next to each target line.

## Conventions

- Mark every target as `.PHONY` unless it actually produces a file whose name matches the target.
- End each target line with a `## description` comment so `help` can print it.
- Group variables (binary name, build directory, main package path) at the top of the file so the agent only edits one place when project metadata changes.
- Keep recipes idempotent — re-running a target should never break a clean state.
- For library-only projects: drop `build` and `run` from the Makefile, and remove the matching lines from the agent file's Core Commands.

## What the agent fills in per project

For each target, the agent decides:

- The exact CLI command for the language (e.g., `go test -race ./...` vs `pytest -v` vs `npm test`).
- Whether the target needs parameters and what their defaults are.
- Which auxiliary targets to add beyond the required list (e.g., `docker-build`, `migrate-up`) — only when they make sense for the project, never as filler.
