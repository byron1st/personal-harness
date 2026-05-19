# Global Instructions

## Key Principles

### Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:

- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## Common Development Rules

- Always use Context7 for code generation, setup/configuration steps, or library/API documentation.
- Check `Makefile` to find useful commands for verifying the code, generating mocks/database models/swagger documentation, testing the code, building the application, or listing outdated direct dependencies.
- Use `rg` (ripgrep) instead of `grep` for code/codebase searches. Plain pipe-filter usage (e.g. `git status | grep modified`) is fine.
- Use `fd` instead of `find` for file/code searches. Metadata-only queries (e.g. `find . -mtime ...`, `-size`, `-perm`) may still use `find`.
- After adding a new feature or refactoring existing code, ALWAYS check `AGENTS.md`, `CLAUDE.md`, and `README.md` files to figure out outdated contents. DO NOT add/delete the existing "section" structure and ONLY check the contents of existing sections.
