# TypeScript Next.js package.json Convention

Use this as the baseline `package.json` script shape for new TypeScript / Next.js projects. Prefer the package manager declared in `packageManager`; if none exists yet, default new projects to `pnpm`.

## Defaults

- Keep project workflows behind `package.json` scripts so agents and developers run the same commands.
- Use ESLint for both linting and formatting.
- Keep `format` and `lint` as separate scripts, and group them behind `check`.
- Use Vitest for the default test suite and coverage.
- Use Playwright for e2e tests.
- Use Stryker for mutation testing.
- Add `gen` only when the project has real generators; do not add an empty placeholder script.

## Tools

- Expected dev dependencies when the corresponding script exists: `eslint`, `typescript-eslint` or the project ESLint config package, `vitest`, `@vitest/coverage-v8`, `@playwright/test`, `@stryker-mutator/core`, and `@stryker-mutator/vitest-runner`.
- When the generated project declares a package manager other than `pnpm`, adjust usage text and any script composition commands to match it.
- Next.js projects should use the ESLint CLI script form, not `next lint`.

## Script Template

Add these scripts to the initial `package.json` unless the project state proves a script does not apply.

```json
{
  "scripts": {
    "format": "eslint . --fix",
    "lint": "eslint .",
    "check": "eslint . --fix && eslint .",
    "test": "vitest run",
    "test-e2e": "playwright test",
    "test-mutation": "stryker run",
    "test-mutation-pkg": "test -n \"$PKG\" || (echo \"usage: PKG=src/path/**/*.ts pnpm test-mutation-pkg\" >&2; exit 1); stryker run --mutate \"$PKG\"",
    "coverage": "vitest run --coverage",
    "build": "next build",
    "run": "next dev"
  }
}
```

## Optional Generation Scripts

When the project has actual generated artifacts, add `gen` and the concrete generator scripts it calls. Examples include API client generation, typed route generation, GraphQL code generation, or mock generation. Do not add `modelgen` or `docsgen` by analogy with Go unless the TypeScript project really has those generators.

```json
{
  "scripts": {
    "gen": "pnpm mockgen && pnpm docsgen",
    "mockgen": "<project-specific mock generator>",
    "docsgen": "<project-specific documentation generator>"
  }
}
```

## Required Checks

- Run the package-manager equivalent of `check` after TypeScript or React source changes.
- Run the package-manager equivalent of `test` after behavior changes.
- Run the package-manager equivalent of `test-e2e` after browser workflow changes.
- Run the package-manager equivalent of `test-mutation-pkg` when hardening tests for a focused path, and `test-mutation` when a broader mutation pass is needed.
