# Swift Convention

These rules capture a reusable Swift style for macOS application projects. Prefer the smallest rule that keeps the app native, testable, responsive, and easy to debug.

When working in an existing repository, follow its established structure first; use these conventions as defaults for new Swift/macOS app code or when the local codebase has no clearer pattern.

## Priorities

- Keep code simple before making it flexible. Do not add a protocol, generic abstraction, environment key, coordinator, or service layer until a real boundary or at least two call sites need it.
- Prefer the Swift standard library, SwiftUI, AppKit, Foundation, and OS frameworks when they are enough. Add third-party dependencies only for clear protocol clients, persistence libraries, test tooling, or cases where the dependency removes meaningful risk.
- Keep UI, application state, domain logic, persistence, external I/O, and platform glue visibly separate. A reader should know which layer owns a behavior from the file path and type name.
- Keep macOS behavior explicit. Model windows, menus, file access, sandbox permissions, shortcuts, and settings as product behavior, not incidental view code.
- Optimize for responsive desktop use. Keep UI work on the main actor, move slow I/O off the main actor, support cancellation, and avoid blocking modal flows unless the platform interaction requires them.

## Project Layout

- Put the app entry point in `App/<ProductName>App.swift` or the repository's existing app target root. Keep launch wiring, scene setup, commands, and app-level dependency construction there; keep feature behavior elsewhere.
- Organize feature UI under `Features/<FeatureName>/` with small SwiftUI views, view state, and feature-local helpers. Use names such as `<FeatureName>View`, `<FeatureName>DetailView`, `<FeatureName>ViewModel`, and `<FeatureName>Commands` when those roles exist.
- Put reusable UI primitives under `UI/` or `Components/`, app services under `Services/`, external integrations under `Adapters/`, model/domain types under `Models/` or `Domain/`, and persistence code under `Persistence/`.
- Put AppKit bridging code under `Platform/AppKit/` or `UI/AppKit/`. Isolate `NSViewRepresentable`, `NSViewControllerRepresentable`, delegates, panels, pasteboard, menu, and window-controller code from ordinary SwiftUI views.
- Put generated code, assets, entitlements, localization, and preview fixtures in clearly named locations. Regenerate or update generated assets through project commands instead of hand-editing them.
- For Swift Package Manager modules, keep public app-independent logic in library targets and app UI in the app target. Use `Tests/<TargetName>Tests` for package tests and Xcode test targets for app or UI tests.

## macOS App Architecture

- Use SwiftUI as the default UI layer for new macOS screens when it can express the interaction cleanly. Use AppKit directly for mature macOS behaviors that SwiftUI does not model well, such as advanced tables, text editing, custom windows, status items, drag sessions, pasteboard workflows, or complex menu validation.
- Keep `Scene` declarations focused on window composition, commands, settings, document groups, and environment injection. Do not put feature business logic in the `App` type or scene builder.
- Model document-based apps with explicit document types and file contracts. Keep import/export, migration, and autosave behavior close to the document or persistence boundary, not scattered through views.
- Model menu commands and keyboard shortcuts as first-class app behavior. Put command handlers near the state or service they mutate, and keep shortcut definitions discoverable in `Commands`-focused files.
- Keep long-running app services independent of windows when the behavior survives window closure. Keep window-specific state scoped to the scene or view tree.
- Treat preview-only data, mock services, and debug menu actions as explicit non-production paths. Do not let preview fixtures leak into app runtime defaults.

## SwiftUI And AppKit Boundaries

- Keep SwiftUI views declarative and small. A view should compose state, render controls, and route user intent; it should not perform file I/O, decode network payloads, or own complex domain decisions.
- Split views when `body` starts mixing layout, state transitions, async work, and platform bridging. Prefer private subviews or small view structs over large computed `some View` blocks.
- Use AppKit wrappers only at the boundary that needs AppKit. Hide delegates, coordinators, selectors, and `NS*` details behind a small SwiftUI-facing API.
- Keep `Coordinator` types private to representable wrappers unless another platform bridge truly shares them. Do not use coordinators as general business-logic containers.
- Use `@MainActor` for UI-bound observable models, command handlers that mutate UI state, and services whose public contract is main-thread-only.
- Avoid force-refresh patterns such as changing arbitrary `.id()` values to rebuild UI. Prefer state changes that express the actual model change.

## State And Dependency Flow

- Keep state ownership clear. Local view-only state belongs in `@State`; shared feature state belongs in an observable model; app-wide state belongs in an app model or environment object created at the app boundary.
- Prefer the Observation framework for new code when the deployment target and existing project allow it. Use `ObservableObject` and `@Published` when the project already uses Combine-based observation or must support older platform targets.
- Pass dependencies through initializers for domain types, services, and testable view models. Use SwiftUI environment values for UI-wide dependencies that naturally behave like environment, such as open-window actions, managed contexts, selection models, and app services.
- Do not hide essential dependencies in singletons. Singletons are acceptable only for Apple framework shared instances and intentionally global immutable capabilities.
- Keep view models focused on presentation state and user intents. Move reusable domain decisions, persistence, networking, and parsing into services or pure helpers.
- Make preview dependencies explicit and deterministic. Previews should not call live network services, mutate real user data, or require developer-machine state.

## Concurrency

- Prefer structured concurrency with `async`/`await`, `TaskGroup`, and async sequences over callback nesting or detached work.
- Use `Task {}` from UI only to bridge a user event into async work. Keep the actual async operation in a named method or service so it can be tested.
- Use `Task.detached` only for deliberate isolation from the current actor and priority. Document why inherited actor context is wrong.
- Check cancellation during long operations, especially file scans, imports, exports, indexing, sync, and network loops. Return early when cancellation makes the result useless.
- Keep UI state mutations on the main actor. Hop back to the main actor at the boundary instead of sprinkling dispatch calls through lower-level code.
- Avoid blocking calls such as synchronous file reads, sleeps, process waits, or expensive decoding on the main actor. If a platform API is synchronous, isolate it behind a service and keep the UI responsive.
- Use `Sendable` types for values crossing concurrency boundaries. Do not pass mutable reference types between actors unless the ownership and isolation are explicit.

## Error Handling

- Define small domain error enums near the behavior that owns them. Conform to `Error` and add `LocalizedError` only when the message is shown to users or passed through a presentation boundary.
- Throw for expected recoverable failures that callers can handle. Use optional returns for ordinary absence and assertions only for programmer mistakes.
- Preserve underlying errors at system boundaries by wrapping them in domain context. Do not turn all failures into broad strings such as `failed` or `unknown error`.
- Catch errors at UI, command, task, and adapter boundaries where the app can decide how to present, retry, log, or ignore them. Do not catch and suppress errors deep in helpers.
- Keep user-facing error text short and actionable. Keep developer diagnostics, file paths, status codes, and underlying errors in logs or debug details when safe.
- Prefer early returns and small `do` scopes. Do not wrap a whole view model method in one broad `do-catch` when only one operation can throw.

## Validation And External Data

- Validate at the boundary that owns the input: text fields validate user input, file importers validate file type and schema, adapters validate remote responses, and persistence layers validate migration assumptions.
- Normalize strings before decisions when whitespace is not meaningful. Keep display formatting separate from persisted or transmitted values.
- Represent closed value sets with enums. Use raw-value enums only when raw strings cross a file, URL, pasteboard, defaults, or network boundary.
- Decode external JSON, plist, CSV, and file formats into DTOs first when the format differs from app domain models. Convert DTOs into domain values through explicit mappers.
- Keep date, number, measurement, and locale formatting at the UI boundary. Persist stable machine-readable values, not localized display strings.
- Avoid force unwraps for external data. Use `guard`, `if let`, `try #require` in tests, or explicit throwing initializers where failure is meaningful.

## Persistence And File Access

- Choose persistence based on data shape and lifecycle. Use `UserDefaults` for small preferences, Keychain for secrets, app files for user-owned documents, SwiftData or Core Data for object graphs, and SQLite-backed libraries for query-heavy local stores.
- Keep persistence models separate from UI state when the store has migrations, relationships, sync, or external import/export contracts. Convert into view models or domain values at a clear boundary.
- Put migrations next to the persistence layer and test them with representative fixtures. Do not perform silent destructive resets unless the product explicitly allows data loss.
- For sandboxed macOS apps, treat user-selected file access as scoped. Store security-scoped bookmarks only when the app must regain access later, and resolve them through a small file-access service.
- Keep import/export code explicit about file types, encodings, atomic writes, and overwrite behavior. Use temporary files and atomic moves for writes that should not leave corrupt output.
- Do not store large binary blobs in defaults or lightweight app state. Use app support directories, user-selected locations, or a database/file store that matches the access pattern.

## Security And Privacy

- Do not log access tokens, refresh tokens, passwords, private keys, security-scoped bookmark data, personally sensitive document content, or full user file paths unless explicitly needed for a debug-only diagnostic.
- Store credentials and long-lived secrets in Keychain, not defaults, plist files, or plain app support files.
- Keep entitlements minimal and documented. Add sandbox, network, file, Apple Events, and automation entitlements only when a feature actually needs them.
- Treat pasteboard, drag-and-drop, open panels, URL schemes, Apple Events, and command-line arguments as untrusted input.
- Keep privacy prompts understandable by tying permission requests to a direct user action. Do not request broad access at launch unless the app cannot function without it.
- Redact sensitive values in analytics, crash breadcrumbs, and diagnostics. Prefer counts, booleans, status categories, and stable non-secret identifiers.

## Networking And Adapters

- Put `URLSession`, request construction, response status handling, decoding, retries, and authentication headers in adapter or client types, not in views.
- Build requests with explicit methods, URLs, headers, and bodies. Keep authorization and content-type logic centralized.
- Decode responses into DTOs and map them into domain or UI types. Do not pass raw network DTOs directly into SwiftUI views when the API contract differs from the app model.
- Use async `URLSession` APIs for new code. Keep callback-based APIs behind small adapters when required by older dependencies.
- Model remote failures with stable domain errors so UI code can distinguish authentication, authorization, offline, timeout, server, decoding, and validation failures.
- Make offline and retry behavior explicit. Do not retry non-idempotent operations unless the server contract supports it.

## Function And Type Style

- Use clear type names that describe roles: `SettingsStore`, `DocumentImporter`, `SyncClient`, `FileAccessService`, `ProjectListView`, `ProjectDetailViewModel`.
- Avoid broad names such as `Manager`, `Helper`, `Util`, and `DataHandler` unless the existing project already uses them consistently.
- Define protocols at real boundaries: external services, persistence stores, clocks, file systems, notification centers, and app services that need test doubles. Do not define a protocol just because a concrete type exists.
- Keep protocols small and caller-oriented. Put the protocol near the caller when only that caller needs the abstraction; put it near the implementation only when it is part of a shared module contract.
- Prefer value types for domain models and immutable DTOs. Use reference types for identity, shared mutable state, delegates, actors, and framework integration points.
- Add explicit access control. Default to `internal`, use `private` for file-local helpers and stored properties, and expose `public` only for package or module contracts.
- Use extensions to organize protocol conformances and focused computed properties. Do not split one type across many files unless the type has distinct platform, persistence, or protocol roles.
- Add comments for non-obvious platform behavior, security decisions, data migrations, and external contracts. Do not comment obvious property assignments or view layout.

## Formatting And Linting

- Use SwiftFormat as the de-facto standard formatter for Swift code. Add or preserve a repository-level `.swiftformat` configuration, run `swiftformat .` for formatting, and do not introduce a competing formatter unless the project already standardizes on one.
- Use SwiftLint as the de-facto standard linter for Swift style and convention checks. Add or preserve a repository-level `.swiftlint.yml`, run `swiftlint` for linting, and prefer the Swift Package plugin or Xcode Run Script integration only when the project already uses that workflow.
- Keep formatter and linter rules checked into the repository. Do not rely on developer-local Xcode settings for style decisions that should be reproducible in CI.
- Treat formatter output as mechanical. Do not mix large format-only churn with behavior changes unless the user explicitly asks for a formatting pass.
- Keep lint exceptions narrow and documented with the reason at the closest practical scope. Prefer fixing the code over disabling rules.

## UI Style

- Strictly follow Apple's [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/) for every macOS UI decision. Treat the HIG as the source of truth for layout, controls, navigation, terminology, keyboard behavior, accessibility, and platform integration; document any product-specific exception before implementing it.
- Use native macOS controls and platform conventions. Prefer toolbars, sidebars, tables, inspectors, sheets, settings windows, context menus, menu commands, and keyboard shortcuts where the HIG and macOS users expect them.
- Keep dense productivity UI scannable. Avoid oversized mobile-style spacing, decorative hero sections, and custom controls that reduce keyboard or accessibility behavior.
- Provide keyboard equivalents for common commands and make command availability match selection and focus state.
- Keep accessibility labels, values, focus behavior, and Dynamic Type behavior correct for custom controls and AppKit wrappers.
- Keep view layout deterministic. Give lists, tables, split views, inspectors, and editor panes stable sizing rules so state changes do not cause avoidable layout jumps.
- Use previews for view states that matter: empty, loading, error, populated, long text, disabled, and permission-denied states. Keep previews fast and offline.

## Testing

- Test pure domain logic, parsers, mappers, persistence boundaries, adapters, and view models before UI flows. UI tests should cover the workflows that unit tests cannot prove.
- Prefer Swift Testing for new pure Swift tests when the project supports it. Use `@Test`, `#expect`, and `#require` for readable assertions, including async tests.
- Keep XCTest for existing XCTest suites, Xcode UI tests, app lifecycle tests, or APIs that still require XCTest integration. Do not mix frameworks in one file unless migration or interoperability requires it.
- Name tests after behavior, not implementation. Use descriptive test names or method names that state the input and expected outcome.
- Use deterministic fixtures for files, defaults, persistence stores, clocks, and network responses. Tests should not depend on the real user home directory, current locale surprises, live services, or developer-machine preferences.
- Use temporary directories for file-system tests and clean them through the test framework. Never write test output into real app support, documents, or desktop folders.
- Test security-sensitive behavior, including redaction, keychain boundaries through test doubles, bookmark handling, sandbox-denied paths, and absence of secret values in logs.
- For async tests, await the operation under test directly. Avoid arbitrary sleeps; use controllable clocks, expectations, or test hooks that observe the real completion condition.

## Verification

- Check the repository's `Makefile`, package scripts, Xcode schemes, or documented commands before choosing verification commands.
- For Swift code, run SwiftFormat and SwiftLint using the repository's configured commands. If no wrapper exists, use `swiftformat .` and `swiftlint`.
- For Swift Package Manager code, run formatting or linting when configured, then `swift test` and `swift build`.
- For Xcode macOS app targets, run the relevant `xcodebuild test` and `xcodebuild build` commands for the scheme and destination documented by the project.
- Run UI tests only when the change affects user workflows, window/menu behavior, AppKit bridging, accessibility, or app launch behavior, or when the project requires them for all changes.
- Regenerate assets, generated code, localization, Core Data models, SwiftData schema resources, or project files only when the source contract changed.
- Prefer focused tests while developing, then run the broader package or scheme verification before handing off.
