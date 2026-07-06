# Swift Makefile Convention

Use this as the baseline Makefile shape for new Swift projects whose primary target is macOS. Prefer Swift Package Manager commands when `Package.swift` is the project entry point; adapt `build`, `test`, and `coverage` to `xcodebuild` only when the project is clearly an Xcode app or workspace, and keep `run` only when the project has a stable launch command.

## Defaults

- Keep project workflows behind Make targets so agents and developers run the same commands.
- Use SwiftFormat for formatting and SwiftLint for linting.
- Keep `format` and `lint` as separate targets, and group them behind `check`.
- Do not add mutation testing targets for Swift projects.
- Do not add `modelgen` or `docsgen` by default for macOS Swift projects.
- Add `gen` only when the project has a real generator such as a mock generator; do not add an empty placeholder target.

## Tools

- Expected to be installed by the developer or CI image: `swiftformat`, `swiftlint`, Swift toolchain, and Xcode Command Line Tools.

## Project Values

- `APP`: Swift package executable target used by `make run`.
- `FORMAT_PATHS`: paths passed to SwiftFormat. Defaults to the project root.
- `E2E_FILTER`: XCTest filter used by `make test-e2e`. Defaults to `E2E`.

## Swift Package Template

Use this version when the project has `Package.swift` and no project-specific Xcode scheme requirement.

```makefile
APP ?= app
FORMAT_PATHS ?= .
E2E_FILTER ?= E2E

.PHONY: format lint check
# Run formatting and linting
check: format lint

# Format Swift source
format:
	@swiftformat $(FORMAT_PATHS)

# Run SwiftLint
lint:
	@swiftlint lint

.PHONY: test test-e2e coverage
# Run unit tests
test:
	@swift test

# Run end-to-end tests by XCTest filter
test-e2e:
	@swift test --filter "$(E2E_FILTER)"

# Run tests with Swift package code coverage enabled
coverage:
	@swift test --enable-code-coverage

.PHONY: build run
# Build the package
build:
	@swift build

# Run the default executable target
run:
	@swift run $(APP)
```

## Xcode macOS Adjustment

When the project is an Xcode macOS app, replace the SPM `build`, `test`, and `coverage` recipes with `xcodebuild` and set project-specific values at the top of the Makefile.

```makefile
SCHEME ?= App
DESTINATION ?= platform=macOS
E2E_TEST_PLAN ?= E2E

build:
	@xcodebuild -scheme "$(SCHEME)" -destination "$(DESTINATION)" build

test:
	@xcodebuild -scheme "$(SCHEME)" -destination "$(DESTINATION)" test

test-e2e:
	@xcodebuild -scheme "$(SCHEME)" -destination "$(DESTINATION)" -testPlan "$(E2E_TEST_PLAN)" test

coverage:
	@xcodebuild -scheme "$(SCHEME)" -destination "$(DESTINATION)" -enableCodeCoverage YES test
```

## Required Checks

- Run `make check` after Swift source changes.
- Run `make test` after behavior changes.
- Run `make test-e2e` only when the project has e2e tests or a configured test plan.
- Run `make coverage` when coverage output is needed.
