# TypeScript + Next.js Convention

This document extracts the reusable coding conventions from this repository for other Next.js/TypeScript projects. Project-specific domains, route names, authentication providers, and API endpoints may change, but the structure and decision rules should remain consistent.

## Common Principles

- Write only the code needed to solve the problem. Do not introduce abstractions for one-off logic, and do not create classes or generic utilities when a small helper function is enough.
- Keep changes limited to files directly tied to the requested behavior. Do not casually clean up neighboring code, names, or structure.
- Do not trust external inputs, URL parameters, FormData, or API responses. Parse and narrow them at the server boundary before passing internal UI types forward.
- Pages compose the flow, `lib/**` owns external I/O and server logic, `types/**` owns shared types, and `components/**` owns UI pieces.
- Keep work on the server when it can be handled on the server. Use Client Components only for browser APIs, React hooks, event handlers, URL state synchronization, or real user interaction.
- Use `pnpm` as the default package manager for installing dependencies and running project scripts.
- Use the project package scripts as the source of truth for verification. The default verification sequence for this style is `pnpm lint`, `pnpm test`, and when needed `pnpm test:e2e`, `pnpm run test:mutation`, and `pnpm build`.
- Check current official documentation before documenting or applying library/API usage or configuration. Do not rely on memory for Next.js, React, or TypeScript features that vary across versions.

## Next.js Convention

### App Router Structure

- Use App Router file-system routing. Put screen routes in `app/**/page.tsx`, route-level loading UI in `loading.tsx`, route-level error UI in `error.tsx`, and HTTP endpoints in `route.ts`.
- Split route groups by routing purpose, such as protected and public areas. Example: `app/(protected)/**`, `app/(auth)/**`.
- Keep `app/**/page.tsx` focused on page-level orchestration: session checks, search param parsing, server data loading, server action definitions, and rendering the top-level feature component.
- Move UI into `components/features/<feature>/**` when a page grows. Use role-oriented filenames such as `*-content.tsx`, `*-list.tsx`, `*-list-client.tsx`, and `*-toolbar.tsx`.
- Put shared layouts in `components/layout/**`, reusable UI primitives in `components/ui/**`, and auth/session providers in `components/providers/**`.
- Put server-only external calls and server logic in `lib/**`. Do not implement API clients, runtime config, loggers, or mappers inside UI components.

### Server Components

- Use Server Components by default. Add `"use client"` only when the file needs `useState`, `useEffect`, `useActionState`, `useRouter`, `usePathname`, `useSearchParams`, DOM event handlers, or browser-only libraries.
- Check sessions on the server for protected pages and send unauthenticated users to `redirect()`. Do not make client-side auth gating the default for protected screens.
- Fetch user-specific or request-specific data on the server and use `unstable_noStore` or fetch `cache: "no-store"` when needed. Make cache policy explicit based on data sensitivity and freshness requirements.
- Do not pass external API responses directly into Client Components. Normalize them into internal UI types through `lib/*-mapper.ts`.
- Do not call the same application's Route Handlers from Server Components. Server Components should call `lib/**` functions or server-only clients directly.

### Client Components

- Keep Client Components small and interaction-scoped. Only client-render the pieces that need browser state, such as table row selection, drawer open/close, filter input, form mode switching, or URL query updates.
- For URL state, use `useRouter`, `usePathname`, `useSearchParams`, and `URLSearchParams` to preserve existing query values while adding or removing only the required keys.
- When mouse interactions are available, provide keyboard access too. Include basic accessibility handling such as `tabIndex`, `onKeyDown`, `Enter`, `Space`, and `aria-current`.
- Use `next/link` for internal navigation. If a link needs to look like a button, use the `Button asChild` pattern.
- Client Components should not fetch server data directly by default. When needed, create an explicit BFF boundary through a Route Handler.

### Route Handlers

- Put App Router HTTP endpoints in `app/api/**/route.ts` and write them as `export async function GET|POST|PUT|DELETE(request: Request): Promise<Response>`.
- Use `NextResponse.json()` for JSON responses. When an upstream response must pass through its stream, body, headers, and status, use `new Response(upstreamResponse.body, { status, statusText, headers })`.
- When forwarding request or response headers, split allowlist and hop-by-hop header stripping rules into constants. Prevent caller `Authorization`, cookies, host headers, and similar sensitive headers from leaking upstream.
- Add `export const dynamic = "force-dynamic"` for routes that must always be dynamic because of environment variables or request bodies.
- Keep error responses consistent with a small helper such as `jsonError(message, status)` returning a stable `{ message }` shape.

### Server Actions and Forms

- Keep a server action inside the page file when it is used by only that page. Extract it only when multiple pages share it.
- Put `"use server"` at the top of the server action body. Recheck the session before mutation and call `redirect()` on authentication failure.
- Parse FormData through small explicit helpers such as `getString`, `requireString`, and `parsePositiveInteger`. Do not scatter trim, required-field checks, and numeric validation throughout the action body.
- After a successful mutation, revalidate only the affected paths with `revalidatePath()`.
- Pass state between a client form and server action using a clear action state type such as `{ status, message, result }`, and use `useActionState`.

### Search Params and URL State

- Treat App Router page `searchParams` as potentially asynchronous. Narrow `string | string[] | undefined` values into single strings through a helper such as `getSingleSearchParam()`.
- Parse enum-like search param values with parser functions that allow only known values. Normalize invalid values to a default or `undefined`.
- Store list/detail deep links in the URL with a pattern like `?id=<rowId>`. The server can pass `id` to the external API to load the selected row's page, and the client can open the selected drawer.
- Build pagination, sort, and filter links with `URLSearchParams`. Explicitly set the values that must be preserved.

### UI and Styling

- Prefer shadcn/ui-style primitives. If new UI can be represented with existing primitives such as `Button`, `Table`, `Badge`, `Sheet`, `Card`, `Input`, `Alert`, or `Skeleton`, do not create a new component.
- Use Tailwind utility classes as the default styling approach, and merge conditional classes with `cn()`.
- Manage repeated primitive variants with `class-variance-authority` and `cva`. For one-off screen styling, local class strings are enough.
- Use `lucide-react` for icons, and pair icons with text in buttons and navigation when the meaning should be explicit.
- Design for dense admin UI. Avoid oversized heroes, decorative gradients, and unnecessary nested cards; prefer tables, toolbars, drawers, and inline alerts for repeated operational work.
- Loading UI should match the actual screen skeleton. Error boundaries should be Client Components and provide a `reset()` button.

### Auth, Runtime Config, Logging

- Declare protected pages in the `proxy.ts` matcher. Public routes or curl/API routes should be deliberately excluded and backed by explicit route-level authentication or token handling.
- Centralize environment access in a small module such as `lib/runtime-config.ts`. For truthy flags, explicitly allow values like `"1"`, `"true"`, `"yes"`, and `"on"`.
- Mock mode or external-request-disable mode must skip real external I/O. Mock data should preserve the same internal type shape as real responses.
- Server logs should include request-context fields such as request id, method, path, and user id. In catch blocks, serialize the error and rethrow a short domain-appropriate message.

### Testing

Use this repository's testing stack as the default for new Next.js/TypeScript apps: Vitest for unit, integration, and component tests; React Testing Library, user-event, jest-dom, and jsdom for component tests; MSW for HTTP integration mocks; Playwright for E2E tests; and Stryker Mutator with the Vitest runner and TypeScript checker for mutation testing.

#### Test Scripts

- Define `pnpm test` as `vitest run`, `pnpm test:watch` as `vitest`, and `pnpm test:coverage` as `vitest run --coverage`.
- Define `pnpm test:e2e` as `playwright test` and `pnpm test:e2e:ui` as `playwright test --ui`.
- Define `pnpm run test:mutation` as `stryker run`.
- Keep `pnpm lint` responsible for both ESLint and TypeScript checks, then run tests separately.

#### Vitest, Testing Library, and jsdom

- Keep `vitest.config.ts` as the shared Vitest entry point using `defineConfig` from `vitest/config`.
- Configure the `@/` alias in Vitest so tests import application modules the same way production code does.
- Include `__tests__/**/*.test.{ts,tsx}` and exclude `__tests__/e2e/**/*.test.{ts,tsx}` from Vitest, because Playwright owns the E2E suite.
- Use `environment: "node"` as the Vitest default. Add `// @vitest-environment jsdom` at the top of component test files that need DOM APIs.
- Register `@testing-library/jest-dom/vitest` in `vitest.setup.ts`.
- Put pure tests under `__tests__/unit/`, HTTP/service integration tests under `__tests__/integration/`, and React component tests under `__tests__/components/`.
- Test pure parsers, mappers, formatters, and config helpers with unit tests. Cover valid cases plus missing fields, wrong types, null/undefined, and invalid numbers.
- Test Client Components with React Testing Library and user-event from the user's point of view: visible text, roles, link hrefs, drawer state, and keyboard/click behavior.

#### Mocking Strategy

- Use application-level mock mode through a single env flag, `KEYWAY_ADMIN_DISABLE_EXTERNAL_REQUESTS`, and centralize its parsing in runtime config.
- Keep seeded mock data in `lib/mock-data.ts` and make it match the same internal UI types returned by real service calls.
- In integration tests that exercise HTTP clients, use MSW with `setupServer()` from `msw/node`, `http.*` handlers, and `HttpResponse`.
- Start MSW in `beforeAll`, reset handlers in `afterEach`, and close it in `afterAll`.
- Use `vi.stubEnv` for env-dependent behavior and `vi.unstubAllEnvs` during cleanup. Re-stub required base env vars after cleanup when a module under test needs them.
- If a module reads env vars at module top level, stub the env first, call `vi.resetModules()`, then dynamically import the module.
- Use `vi.mock` for framework hooks or local dependencies, and `vi.hoisted` when the mock state must be available before module imports.
- Use `vi.stubGlobal("fetch", fetchMock)` for low-level Route Handler passthrough tests where exact `fetch` init, raw body, or header forwarding must be asserted directly.
- Test Route Handlers and external service integrations by verifying forwarded method, URL, body, header allowlists, status passthrough, and fallback error branches.

#### Playwright E2E

- Keep Playwright config in `playwright.config.ts` and place E2E specs under `__tests__/e2e`.
- Run the E2E suite against Chromium using the `Desktop Chrome` device profile unless a project explicitly needs additional browsers.
- Start the app through Playwright `webServer` with `pnpm exec next dev --hostname 127.0.0.1 --port 3110`.
- Default `baseURL` to `http://127.0.0.1:3110`, while allowing `NEXTAUTH_URL` to override it.
- Force test-safe env defaults in Playwright config: `NEXTAUTH_URL`, `NEXTAUTH_SECRET`, `ALLOWED_EMAIL_DOMAIN`, OAuth client placeholders, upstream service URLs, and `KEYWAY_ADMIN_DISABLE_EXTERNAL_REQUESTS=true`.
- Reuse an existing local server outside CI and start a fresh controlled server in CI.
- Use `fullyParallel: true`; set CI retries to `2`, CI workers to `1`, CI reporter to `html`, local reporter to `list`, and trace collection to `on-first-retry`.
- For apps using NextAuth, create an E2E auth fixture that encodes a session token with `next-auth/jwt` and injects the correct session cookie into the Playwright context.
- Write E2E assertions against accessible roles, labels, exact link or cell names where ambiguity is possible, and visible user-facing state.
- Keep E2E independent from live external services by relying on mock mode and seeded mock data.

#### Stryker Mutation Testing

- Keep mutation config in `stryker.config.json`.
- Use `@stryker-mutator/vitest-runner` with `testRunner: "vitest"` and point it at `vitest.config.ts`.
- Use `@stryker-mutator/typescript-checker` with `tsconfig.json`.
- Set `vitest.related` to `false` so mutation testing uses the configured Vitest surface instead of only related tests.
- Use `reporters: ["progress", "clear-text"]`; keep clear-text output readable with colors enabled, emojis disabled, test logging disabled, mutant reporting enabled, score table enabled, and full survivors skipped.
- Keep `thresholds.break` as `null` when the goal is exploratory hardening rather than a hard CI gate.
- Keep `ignoreStatic: true` and `cleanTempDir: "always"`.
- Mutate an explicit high-signal target list instead of the whole app by default. Prioritize shared `lib/**` modules and interaction-heavy components.
- When a mutation survivor exposes an untested fallback branch, add the smallest unit, integration, or component test that proves the behavior. Do not change production logic just to satisfy mutation testing.

## TypeScript Convention

### Compiler and Module Defaults

- Use `strict: true`, `noEmit: true`, `isolatedModules: true`, `moduleResolution: "bundler"`, and `jsx: "react-jsx"` as defaults.
- Use the `@/*` import alias. Prefer the alias when a relative path needs to climb out of the current folder.
- Use `import type` aggressively. Do not create unnecessary runtime dependencies by mixing runtime imports and type-only imports.
- Provide a lint script that checks ESLint, TypeScript, and Prettier together. Example: `eslint . && pnpm exec tsc --noEmit`.

### Type Design

- Represent small sets of string values with union types. Example: `"asc" | "desc"`, `"pending" | "approved" | "rejected"`.
- Use `interface` by default for object shapes. Use `type` for generic responses, unions, mapped types, and utility type compositions.
- When deriving a union from an options array, use `as const` and `(typeof values)[number]`.
- Use `Record<Union, Value>` for mappings keyed by union values so omissions are caught at compile time.
- Keep types used only inside one page or component near that file. Move them to `types/**` only when multiple features or lib modules share them.
- Separate backend DTOs from UI domain types. If the backend uses snake_case, keep snake_case in DTOs, use camelCase in UI types, and convert through a mapper.

### External Data and Narrowing

- Treat `response.json()` results as `unknown` and use them as domain types only after they pass through a type guard or parser.
- Split type guards into small helpers such as `isObject`, `isString`, `isFiniteNumber`, and `isStringArray`. For complex schema guards, separate required-field checks from optional/null checks.
- Parse functions should throw stable error messages on failure. Tests should be able to assert invalid inputs against those messages.
- Do not use `any`. Even in tests that construct invalid shapes, prefer `unknown` or `Record<string, unknown>` and use the narrowest cast only where necessary.
- Normalize mixed external `null` and `undefined` values inside mappers. UI should only handle display rules such as `value || "-"`.

### Function Style

- Build small pure helpers first and compose them inside pages or components. Do not over-generalize helpers that are used once.
- Add explicit return types to exported async functions, Route Handlers, server actions, and external I/O functions.
- Omit return types for local helpers when inference is clear. Add them when inference becomes long or the function is part of an API surface.
- Prefer early returns. If nested `if` blocks get deep, split the logic with guard clauses or small helpers.
- Use non-null assertions only when the immediately preceding validation makes the value safe. Prefer parser/helper functions that return narrowed types.
- Create custom Error classes only when an error needs status codes or domain-specific fields. For simple fallback messages, use `error instanceof Error ? error.message : fallback`.

### React TypeScript

- Do not use `React.FC`. Type component props directly on the function parameter or define `interface <ComponentName>Props`.
- Use `React.ReactNode` for children.
- When extending existing component props, use `React.ComponentProps<typeof Button>` or `React.ComponentProps<"button">`.
- Type icon component props with only what is actually needed, such as `ComponentType<{ className?: string }>`.
- Use specific React event handler types. Example: `KeyboardEvent<HTMLTableRowElement>`.
- Make nullable state explicit in the type. Example: `useState<Item | null>(null)`.
- Prefer stable ids for list keys. If a composite key is required, use a meaningful combination such as `${partA}-${partB}`.

### Payload Construction

- Include optional API payload fields only when values are present, usually with object spread. Do not send empty strings as meaningful values.
- Use `URLSearchParams` for query strings, and convert numbers explicitly with `.toString()`.
- Name domain-specific transformations, such as date string normalization, with small functions like `normalizeDate()`.
- Build API request headers through functions. JSON requests should explicitly set `Accept`, `Authorization`, and `Content-Type`; passthrough requests should use an allowlist.

### Comments and Documentation

- Add comments only for complex branches or external contracts that are not obvious from the code.
- Do not restructure Markdown sections unless necessary, and keep each paragraph or bullet as a single logical line.
- When documentation describes code behavior, write only what is backed by actual routes, scripts, env vars, or tests.
