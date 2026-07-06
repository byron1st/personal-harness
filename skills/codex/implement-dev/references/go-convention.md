# Go Convention

These rules capture the Go style used in this repository in a form that can be reused in other backend projects. Prefer the smallest rule that keeps the code explicit, testable, and easy to debug.

When working in an existing repository, follow its established structure first; use these conventions as defaults for new Go backend/service code or when the local codebase has no clearer pattern.

## Priorities

- Keep code simple before making it flexible. Do not add an abstraction, option, hook, or generic helper until at least two real call sites need it.
- Prefer the standard library when it is enough. Add third-party dependencies only for protocol clients, frameworks, test tooling, generated code, or cases where the dependency clearly removes meaningful risk.
- Make ownership visible in the package layout. A reader should know whether code is HTTP routing, service orchestration, external I/O, configuration, shared type definitions, or low-level utility code from the import path alone.
- Keep behavior explicit. Validate inputs directly, return named sentinel errors for expected failure modes, and map errors at system boundaries.
- Optimize for readable operational debugging. Use structured logs, contextual wrapped errors, and traces around external I/O without exposing secrets or key material.

## Package Layout

General Go project defaults:

- Put executable entry points under `cmd/<binary>/main.go`. Main should parse flags, load config, create dependencies, start the runtime, handle signals, and shut down gracefully. Keep business logic outside `main`.
- Organize code around layered architecture and keep dependencies one-way. Types and helpers that belong to one layer or domain should stay in that package instead of being lifted into a shared package.
- Put layer-neutral shared types, enums, and helpers under `internal/pkg/<topic>` when they are module-private, or `pkg/<topic>` when they are an intentional public import contract. Avoid catch-all `types` or `util` packages.
- Keep generated documentation and generated code in clearly named locations such as `docs`, `mocks`, or generated DB/API packages. Regenerate them through project commands instead of hand-editing them.

Backend server defaults:

- Put HTTP framework setup under a `server` package and route handlers under a `route` or transport package. Keep framework middleware and handler logic out of service packages.
- Put use-case orchestration under `service/<domain>`. Service code may coordinate adapters, persistence, telemetry, validation, and domain decisions, but it should not know HTTP status codes or request binding details.
- Put external systems under `adapter/<system>`. An adapter owns protocol details, request/response structs, status-code handling, SDK calls, and external error wrapping for one external system.
- Avoid dependency cycles by keeping the backend direction clear: `cmd` wires everything, `route` depends on `service`, `service` depends on `adapter`, and layer-neutral shared code lives under `internal/pkg` or `pkg`.

## Constructors And Interfaces

- Define small interfaces at dependency boundaries: service contracts, external clients, persistence clients, callback senders, and aggregating managers. Do not define an interface just because a concrete type exists.
- Keep the interface in the package that owns the behavior when callers naturally depend on that package's contract.
- Use `New<Type>` constructors for externally created components. Constructors should fill safe defaults, accept injected dependencies needed for testing, and validate required configuration.
- When a dependency is optional for tests, accept it as a constructor parameter and create the default only when it is `nil`.
- Use concrete implementation names such as `ClientImpl` or `ServiceImpl` when the public name is already used by the interface. Keep the implementation struct small and focused on stored dependencies.
- Prefer dependency injection over package globals for clients and service collaborators. Package globals are acceptable for constants, sentinel errors, immutable lookup tables, and telemetry tracers.

## Context And Concurrency

- Pass `context.Context` as the first argument for functions that do I/O, call adapters, access storage, start servers, or may block.
- Use a parent context from `main`, cancel it on shutdown, and let servers/workers observe cancellation.
- Check `ctx.Done()` before starting outbound requests or long work when cancellation can avoid useless I/O.
- Use goroutines only around clear concurrency boundaries such as independent servers or asynchronous workers. Return errors through buffered channels or structured coordination, not hidden logs.
- Always use bounded shutdown contexts for graceful shutdown and trace/exporter cleanup.

## Error Handling

- Define expected package errors as exported sentinel variables named `Err...` near the code that owns the failing operation.
- Keep sentinel errors in the package/file that owns the behavior. Re-export only the small subset needed by an upper boundary to translate or preserve contracts.
- Each `Err...` sentinel must have exactly one origin return site so the sentinel alone identifies where the failure occurred. An origin return site is a direct `return ErrX`, `return errors.Join(ErrX, err)`, or `fmt.Errorf("%w: ...", ErrX)`. If the same condition can occur in multiple places, define more specific sentinels instead of returning the same one from several locations.
- Propagating an existing `err` is not a new origin return site. Callers should usually return that `err` unchanged unless they are translating it at a boundary or adding necessary local context.
- Use `errors.Join(ErrSentinel, err)` when preserving both a stable sentinel and the underlying error.
- When returning an `err` that came directly from a standard-library or third-party function call, wrap it with a package-local sentinel at that return point: `return errors.Join(ErrLocalFailure, err)`.
- For errors returned by project code, usually return `err` unchanged unless the caller needs extra local context. Avoid deep wrapping chains that make the real failure harder to inspect.
- Use `fmt.Errorf("%w: field=%s", ErrSentinel, value)` when adding local context to a sentinel. Keep context compact and machine-searchable.
- Use `errors.Is`, `errors.As`, and `require.ErrorIs` in callers and tests. Do not compare error strings when a sentinel is available.
- Return early on errors. Keep the happy path left-aligned and avoid large `else` blocks after a return.
- At transport boundaries, translate known errors to the correct external status or response shape. Let unexpected errors become internal/server errors with enough context logged or wrapped.
- Error messages should be short, stable, and specific. Prefer `missing key id`, `failed to decode response body`, or `unsupported delivery type` over broad messages.

## Validation And Normalization

- Validate at the boundary that owns the input: HTTP handlers validate request shape and query parameters, config loading validates runtime configuration, services validate domain preconditions, adapters validate external response invariants.
- Normalize strings before decisions when whitespace is not meaningful. Use `strings.TrimSpace` for user/config inputs that should treat blank as empty.
- Model closed value sets as typed string enums with constants, a `String()` method, and an `IsValid...` helper when raw strings cross package or API boundaries.
- Prefer explicit switch statements for enum validation and conversion. Include a default case that returns a sentinel error for unsupported values.
- Apply default config values immediately after parsing and before required-field validation.
- Keep JSON/YAML tags aligned with the external contract. Use `json:"-"` or `yaml:"-"` for secret-backed or runtime-only values.

## Data And Security

- Treat byte slices, key material, credentials, tokens, certificates, and private keys as mutable or sensitive. Clone byte slices on input/output when a type owns the data.
- Do not log raw secrets, tokens, private keys, key material, database URLs, or authorization headers. Use redaction, hashes, metadata, or explicit exposure policies.
- Keep sensitive fields out of serialized config and response structs unless the external contract explicitly requires them.
- Separate metadata from raw material in types. Return metadata by default and attach raw bytes only where the use case actually needs them.
- Close response bodies with `defer func() { _ = resp.Body.Close() }()` after a successful HTTP response creation.
- Make nil-safe methods on wrapper types when nil receivers are plausible and simplify callers.

## HTTP And Adapter Style

- Handlers should authorize, parse/bind/validate, call a service, map known errors to HTTP errors, and return response DTOs. Do not put external SDK or persistence logic in handlers.
- Services should return domain results and errors, not HTTP framework types.
- Adapters should own external URLs, headers, SDK request structs, status-code interpretation, response decoding, and protocol-specific validation.
- Use small private request/response structs inside adapter packages when the structs exist only for one external API.
- Build outbound requests with `http.NewRequestWithContext` and set headers explicitly.
- Decode error responses enough to preserve useful remote messages, but keep a stable local sentinel for callers.

## Logging And Telemetry

- Use structured logs with typed fields rather than formatted strings for operational data.
- Record span errors at the layer that observes and returns the error. Add relevant span attributes such as operation type, counts, status, key identifiers, or HTTP status codes when they are safe.
- Keep health checks, swagger, pprof, and other noisy endpoints out of request logs/traces when possible.
- Do not let observability code change business outcomes. A callback-log failure or tracing failure should not alter the domain result unless the feature explicitly requires it.

## Function And Type Style

- Keep exported functions focused on one use case. Extract private helpers when a function starts mixing validation, conversion, persistence, and external I/O in a way that hides the main flow.
- Prefer small helper functions over anonymous inline complexity when the helper name explains the intent.
- Use preallocated slices when the final or upper-bound size is known: `make([]T, 0, len(items))`.
- Use maps for lookup tables and switches for behavior decisions. Avoid clever reflection or generic code for ordinary DTO conversion.
- Use short receiver names that match the type role: `s` for service, `c` for client, `r` for router, `h` for handler, `cfg` for config.
- Prefer Go initialisms in identifiers such as `ID`, `URL`, `HTTP`, `TLS`, `KMS`, and `API`, unless an existing public contract already uses a different spelling.
- Keep comments on exported identifiers concise and factual. Add comments for non-obvious security decisions, external protocol quirks, generated-contract behavior, or intentionally surprising behavior.

## Testing

- Write tests in the external `<package>_test` package by default. Test exported behavior and public contracts rather than private implementation details.
- Place tests in the `_test.go` file that matches the target logic or topic. Do not collect unrelated package behavior in a generic test file.
- Use Go's standard `testing` package with `testify/require` for preconditions and expected outcomes. Use `assert` only when continuing after a failed comparison adds value.
- Use table tests for validation matrices, enum helpers, config cases, and repeated input/output checks. Name each case clearly and run it with `t.Run`.
- Use `require.ErrorIs` for sentinel errors and `require.Contains` only for contextual message fragments that are intentionally part of the contract.
- Mock external clients at adapter/service boundaries. Assert the exact request body, headers, URLs, and side effects when they are part of the contract.
- Generate mocks with `mockery` through the repository's generation target, such as `make mockgen` or `make gen`. Do not hand-write or manually edit generated mock files.
- Keep test helpers local to the test file unless several packages need the same setup. Helpers should call `t.Helper()` when they report failures.
- Use `t.TempDir`, fixtures, and small local test servers instead of relying on developer-machine state.
- Add tests for security-sensitive behavior, especially redaction, absence of key material, token parsing, and callback payload shape.
- For DB-backed tests, keep setup explicit and close resources. Prefer package-scoped runs while iterating, then run the repository's full check/test/race targets before finishing.

## Verification

- Check the repository's `Makefile` or documented scripts before choosing verification commands.
- For Go code changes, run formatting, linting, unit tests, and race tests when the repository provides them.
- Regenerate mocks, DB models, Swagger/OpenAPI, or other generated assets only when source contracts changed.
- Use repository mutation targets when hardening tests: `make test-mutation` for the full suite and `make test-mutation-pkg PKG=./path/to/package` for focused runs. Keep `gremlins` options in the Makefile instead of using ad hoc commands.
- Prefer targeted package tests while developing, then run the broader suite before handing off.
