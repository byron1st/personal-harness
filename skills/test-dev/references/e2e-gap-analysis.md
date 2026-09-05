# E2E test gap analysis

Use this reference for **Phase 2** of `test-dev`. The goal is to make sure every in-scope change that crosses a system boundary has at least one e2e test covering it end-to-end. E2E tests verify integration; they are not a place to retest internal branches.

## 1. Locate the e2e harness

Common conventions, by language/framework:

- **Go** — `*_e2e_test.go`, `Test*Integration`, `tests/e2e/`, build tag `//go:build e2e`. The Makefile usually has `make test-e2e` or `make integration`.
- **Node / TypeScript backend** — `tests/integration/`, `e2e/`, files like `*.e2e.spec.ts`. Often run with `jest --config jest.e2e.config.js` or `vitest --config vitest.e2e.config.ts`.
- **Next.js / React frontend** — `cypress/`, `playwright/`, `tests/e2e/`. Targets like `npm run e2e`, `npx playwright test`, `npx cypress run`.
- **React Native** — Detox under `e2e/`, `make detox` / `detox test`.
- **Python** — `tests/integration/`, `pytest -m integration`, FastAPI `TestClient`-driven tests sometimes count as e2e if they exercise the full route.

Read `Makefile`, `package.json` scripts, and `AGENTS.md`/`CLAUDE.md` to confirm the project's actual command. If none exists, the project has no e2e harness — skip Phase 2 and note the reason in the final summary.

## 2. Identify boundary-crossing changes

From the in-scope file list, isolate the changes that cross a system boundary. A boundary is anywhere code interacts with something it does not own:

- **HTTP / RPC** — new or modified routes, handlers, middlewares affecting request/response shape, auth boundaries.
- **Persistence** — new or modified DB queries, transactions, migrations affecting runtime behavior.
- **External services** — new outbound calls (third-party APIs, S3, Redis, message brokers).
- **Queue consumers / scheduled jobs** — new event handlers, cron jobs.
- **CLI entry points** — new commands or flags affecting program exit code / stdout / side effects.
- **UI flows** — new pages/screens or user-facing interactions.

A pure refactor that touches only internal helpers is **not** a boundary change and does not require new e2e tests.

## 3. Map boundary changes to existing e2e tests

Read the existing e2e tests and decide, per boundary change, whether it is already covered:

- The same route is hit with the same method and asserts on the new behavior.
- The same DB write is exercised and the resulting state is observed.
- The same UI flow is walked and asserts on the new screen / element.

If yes → no gap. Move on.

If no → gap.

## 4. Fill each gap with one happy-path test

This skill is test-code-only (`SKILL.md` Global Rule 6). Production source, runtime configuration, migrations, and infrastructure code are read-only at this layer too — even when an e2e test fails because of them.

For each gap:

1. Write **one** happy-path e2e test exercising the boundary end-to-end.
   - HTTP: real server (or test server in-process), real router, real DB if the project uses a test DB; the test sends an HTTP request and asserts on the response status, body, and any persisted side effect.
   - UI: the framework's standard mode (Playwright/Cypress visiting the page, Detox launching the app), interacting as a user, asserting on visible state.
2. Add a single failure-path test only when the boundary has user-visible error semantics that are not adequately covered by unit tests (e.g. "POST /orders returns 409 when order already exists" — worth e2e if conflict handling spans router + DB; not worth e2e if it's a pure handler-level branch).
3. Reuse existing fixtures, test database setup, page-object helpers, and authentication helpers. Do not introduce a new harness.

If a newly added e2e test fails:

- **The test itself is wrong** (wrong selector, wrong fixture, wrong assertion against the contract) → fix the test.
- **The test correctly exercises the intended user journey but the system disagrees** → suspected business-logic / integration defect. Do **not** edit application code, runtime config, or migrations to make it pass. Record the defect (boundary touched, observed vs expected behavior, the test path), leave the test red — or skip it if it blocks subsequent tests, annotated with the suspected defect. This entry feeds the central defect list reported at the end of the skill.

Avoid:
- Re-asserting branch coverage that belongs in unit tests.
- Adding e2e tests purely to bump coverage numbers.
- Cross-test ordering dependencies — each e2e test must be independently runnable.

## 5. Style-matching checklist

- File location matches the project's e2e convention from step 1.
- Naming: imperative scenario style if the project uses it (`it('creates an order when payment succeeds')`); structured table-driven if Go integration tests do.
- Reuse existing setup/teardown helpers, fixtures, factories, and seed data.
- Use the same authentication helper / token issuer the existing tests use.
- Use the same DB cleanup strategy (transactional rollback, per-test schema, truncation).

## 6. Verify

Run the e2e command resolved in `SKILL.md`'s `Prepare` step end-to-end; all must pass before moving to Phase 3 (`SKILL.md` Global Rule 4).

## 7. What to record for the summary

Track:

- Boundary changes identified.
- Boundaries already covered (count).
- E2E tests added (count + paths).
- Boundaries deliberately not covered with reason (e.g. "fully covered by unit tests of handler", "no user-visible behavior change").
- **Suspected business-logic / integration defects** surfaced by added e2e tests — boundary touched, observed vs expected behavior in one sentence, the test path, whether left red or skipped. These feed the central defect list reported at the end of the skill.
- Whether Phase 2 was skipped entirely because no e2e harness exists.
