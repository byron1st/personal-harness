---
name: test-dev
description: Harden tests for a change by reading its git diff with fresh eyes and filling unit/e2e gaps, without touching production code. Use after implementing non-trivial work, or when asked to add tests, harden tests, or improve coverage.
---

# Test Dev

Add the tests the author's mental model skipped. The value comes from not being the author: read the diff, not the author's account of it. Run this in a fresh context — a subagent or a new session that did not write the code — and give it only the scope and, when there is one, the plan's "done when" items.

## Scope

Default: the diff between the current branch and `main` (or `origin/main`), plus uncommitted and untracked changes. On `main`, only the uncommitted changes. The user may narrow it (a commit, a file) or widen it (the whole codebase). State the scope in one sentence.

## What to add

- Unit tests for the public surface of the changed code: the happy path plus the edge cases its body implies.
- An e2e test for each change that crosses a system boundary (HTTP route, DB write, external IO, queue consumer, UI flow), when the project has an e2e suite.
- Mutation testing only when the user asks for it.

The repository's own conventions (AGENTS.md / CLAUDE.md, neighbouring tests) decide layout, mocks, and dependencies.

## The boundary — test code only

Write only tests and test-only fixtures, helpers, and config. Never edit production code, and never weaken, loosen, or delete an existing test.

When a legitimate new test fails because the production code is wrong, leave it failing — or skip it with a comment naming the suspected defect if it blocks the suite — and report it: file:line, the test, expected vs observed in one sentence. Suspected defects are the headline of the report; never drop or summarize them away.

## Finish

Run the project's lint and test commands. Every test that was green before must still be green; if one broke, revert your most recent test change rather than touching production code. Report the tests added, the suspected defects, and what you could not cover.
