# Language starter conventions

Starter material for the agent file's **Code Conventions** and **Testing** sections (see [agent-md-template.md](agent-md-template.md) §5 and §6). Read only the block for the project type detected in Step 3.

These are the choices a model will not guess: arbitrary picks between equally good options, and rules that cut against a language's common default. Ordinary good practice for the language is deliberately absent — the implementing agent already knows it.

**This is a menu, not a dump.** Code Conventions caps at 3–5 bullets, so select the ones this project will actually exercise and drop the rest. Tooling and commands are not repeated here; they live in the command-surface reference. Anything the project decides differently wins — write what the project does, not what this file says.

## Go

- Layering is one-way: `cmd/<binary>/main.go` only wires, `route` → `service` → `adapter`. Layer-neutral shared code goes in `internal/pkg/<topic>` (module-private) or `pkg/<topic>` (public contract). No catch-all `types` or `util` package.
- Expected failures are exported `Err...` sentinels in the package that owns the failing operation, with **exactly one origin return site each** — so the sentinel alone identifies where it came from. If a condition arises in two places, define two sentinels.
- Wrap errors from stdlib/third-party calls as `errors.Join(ErrLocal, err)`. Return errors from project code unchanged unless translating at a boundary or adding local context via `fmt.Errorf("%w: field=%s", ErrSentinel, value)`.
- Compare errors with `errors.Is` / `errors.As` / `require.ErrorIs`, never by string.
- `context.Context` is the first parameter of anything that does I/O, calls an adapter, or can block.
- Tests live in the external `<package>_test` package and exercise exported behavior only.
- `testify/require` for preconditions and expected outcomes; `assert` only where continuing after a failed comparison adds information.
- Mocks are generated with `mockery` through the command surface's `gen` target. Never hand-edit a generated mock.

## Swift / macOS

- Layout: `App/` for launch wiring and scenes, `Features/<Name>/` for feature UI, plus `Services/`, `Adapters/`, `Models/` (or `Domain/`), and `Persistence/`. AppKit bridging (`NSViewRepresentable`, delegates, panels, window controllers) stays isolated under `Platform/AppKit/`.
- SwiftUI is the default for new screens. Reach for AppKit only where SwiftUI models the interaction badly — advanced tables, text editing, status items, custom windows, complex menu validation.
- Apple's Human Interface Guidelines are the source of truth for every macOS UI decision. Document any product-specific exception before implementing it.
- Use the Observation framework for new observable models. `ObservableObject` / `@Published` only where the deployment target or existing project code requires it.
- `@MainActor` for UI-bound models and state mutations; slow I/O runs off the main actor and checks cancellation on long operations (file scans, imports, sync).
- Secrets and long-lived credentials go in Keychain — never `UserDefaults`, plist files, or app-support files.
- Swift Testing (`@Test`, `#expect`, `#require`) for new pure tests. XCTest stays for existing suites, UI tests, and app-lifecycle tests.
- Dense productivity UI: native controls, toolbars, sidebars, inspectors. No oversized mobile-style spacing or decorative hero sections.

## TypeScript / Next.js

- Ownership by directory: pages compose the flow, `lib/**` owns external I/O and server logic, `types/**` owns shared types, `components/**` owns UI pieces. No API clients, loggers, or mappers inside components.
- Server Components by default. Add `"use client"` only for React hooks, DOM event handlers, browser-only libraries, or URL-state sync.
- Never pass an external API response into a Client Component — normalize it through `lib/*-mapper.ts` first. Backend DTOs keep the backend's casing; UI types are camelCase; a mapper converts.
- Treat `response.json()` as `unknown` until a type guard narrows it. No `any`, tests included — prefer `unknown` or `Record<string, unknown>` with the narrowest cast.
- Build UI from shadcn/ui-style primitives with Tailwind, merging conditional classes through `cn()` and taking icons from `lucide-react`. Do not write a new component when an existing primitive covers it.
- Centralize environment access in one module (`lib/runtime-config.ts`), including truthy-flag parsing.
- Tests: `__tests__/unit`, `__tests__/integration`, `__tests__/components` under Vitest, with MSW for HTTP integration mocks; Playwright specs under `__tests__/e2e`.
- Dense admin UI: tables, toolbars, drawers, and inline alerts. No hero sections, decorative gradients, or nested cards.
