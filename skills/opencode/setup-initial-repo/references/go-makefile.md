# Go Makefile Convention

Use this as the baseline Makefile shape for new Go projects. The common targets apply to all Go projects; backend projects add `sqlc` model generation and Swagger documentation generation.

## Defaults

- Keep project workflows behind Make targets so agents and developers run the same commands.
- Use `mockery` for interface mocks. Generated mocks should live under `internal/pkg/mocks` by default and should not be edited by hand.
- Use `go fmt ./...` and `go fix ./...` for formatting and modernization.
- Use `go mod tidy` plus `golangci-lint run` for linting.
- Keep `format` and `lint` as separate targets, and group them behind `check`.
- Clean the Go test cache before normal, race, and e2e test runs.
- Use `gremlins` for mutation testing through Make targets, not ad hoc command lines.
- Use `go list -u -m` for outdated direct dependency checks without depending on extra tools.
- For Go backend servers, use `sqlc` for database model/query generation and `swag` for Swagger documentation generation.

## Tools

- Auto-installed by targets when missing: `mockery`, `swag`, `gremlins`.
- Expected to be installed by the developer or CI image: `sqlc`, `golangci-lint`.

## Project Values

- `BINS`: space-separated binary output names. Each binary is built from `./cmd/<name>`.
- `RUN_BIN`: binary to run with `make run`. Defaults to the first value in `BINS`.
- `BUILD_FLAGS`: optional environment or flags prefix used by CI, for example `CGO_ENABLED=0`.
- `MOCK_DIR`: generated mock output directory. Defaults to `internal/pkg/mocks`.
- `SQLC_CONFIG`: sqlc config path for backend projects. Defaults to `./scripts/sqlc.yaml`.
- `SQLC_DB_FILE`: generated sqlc file to normalize after generation. Defaults to `internal/adapter/db/db.go`.
- `SWAG_MAIN`: main Go file used by `swag init`. Defaults to `cmd/server/main.go`.
- `SWAG_OUT`: Swagger output directory. Defaults to `docs`.
- `E2E_PKG`: e2e package path. Defaults to `./tests/e2e/...`.
- `EXCLUDE`: package-name regex excluded from coverage package lists.

## General Go Template

Use this version for non-backend Go projects. Add project-specific build binaries by setting `BINS`.

```makefile
BINS ?= app
RUN_BIN ?= $(firstword $(BINS))
BUILD_FLAGS ?=
MOCK_DIR ?= internal/pkg/mocks
E2E_PKG ?= ./tests/e2e/...
EXCLUDE ?= (mocks|docs|cmd)

.PHONY: outdated
# List outdated direct dependencies
outdated:
	@go list -u -m -f '{{if and (not .Main) (not .Indirect) .Update}}{{.Path}} {{.Version}} -> {{.Update.Version}}{{end}}' all | sed '/^$$/d'

.PHONY: gen mockgen
# Generate project artifacts
gen: mockgen

# Generate mocks for interfaces in the project
mockgen:
	command -v mockery >/dev/null 2>&1 || go install github.com/vektra/mockery/v3@latest
	rm -rf $(MOCK_DIR) && mkdir -p $(MOCK_DIR)
	mockery
	find $(MOCK_DIR) -type f -name '*.go' -exec perl -pi -e 's/interface\{\}/any/g' {} +
	find $(MOCK_DIR) -type f -name '*.go' -exec gofmt -w {} +

.PHONY: format lint check clean-testcache test race test-e2e test-mutation test-mutation-pkg
# Run formatting and linting
check: format lint

# Format and modernize code
format:
	@go fmt ./...
	@go fix ./...

# Run linters to check code quality and style
lint:
	@go mod tidy
	@golangci-lint run

# Clean test cache to ensure tests run with the latest code changes
clean-testcache:
	@go clean -testcache

# Clean test caches and run tests
test: clean-testcache
	@go test ./...

# Clean test caches and run race tests
race: clean-testcache
	@go test -short -race ./...

# Clean test caches and run end-to-end tests
test-e2e: clean-testcache
	@go test $(E2E_PKG)

# Run mutation testing and show survived mutants
test-mutation:
	@command -v gremlins >/dev/null 2>&1 || go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
	@gremlins unleash -S l

# Run mutation testing for a single package, for example: make test-mutation-pkg PKG=./internal/service/foo
test-mutation-pkg:
	@test -n "$(PKG)" || (echo "usage: make test-mutation-pkg PKG=./internal/service/foo" >&2; exit 1)
	@command -v gremlins >/dev/null 2>&1 || go install github.com/go-gremlins/gremlins/cmd/gremlins@latest
	@gremlins unleash "$(PKG)" -S l --workers=3 --timeout-coefficient=20

.PHONY: build run
# Build application binaries from ./cmd/<binary>
build:
	@for bin in $(BINS); do \
		$(BUILD_FLAGS) go build -o $$bin ./cmd/$$bin || exit 1; \
	done

# Run the default application binary
run:
	@$(BUILD_FLAGS) go run ./cmd/$(RUN_BIN)

.PHONY: deps-graph
# Show intra-module package dependency edges
deps-graph:
	@MODULE=$$(go list -m); \
	go list -f '{{$$from := .ImportPath}}{{range .Imports}}{{$$from}} -> {{.}}{{"\n"}}{{end}}' ./internal/... \
	| grep -F -- "-> $${MODULE}/"

PACKAGES := $(shell go list ./... | grep -v -E '$(EXCLUDE)')
COVERPKG := $(shell go list ./... | grep -v -E '$(EXCLUDE)' | paste -sd, -)

.PHONY: coverage
# Run package coverage over non-generated application packages
coverage:
	go test $(PACKAGES) -coverprofile=coverage.out -coverpkg=$(COVERPKG)
	go tool cover -func=coverage.out | grep total | awk '{print $$3}'
```

## Backend Additions

For Go backend servers, extend `gen` with `modelgen` and `docsgen`, then add the targets below.

```makefile
SQLC_CONFIG ?= ./scripts/sqlc.yaml
SQLC_DB_FILE ?= internal/adapter/db/db.go
SWAG_MAIN ?= cmd/server/main.go
SWAG_OUT ?= docs

.PHONY: gen mockgen modelgen docsgen
# Generate mocks, database models, and Swagger documentation
gen: mockgen modelgen docsgen

# Generate database models using sqlc
modelgen:
	sqlc generate -f $(SQLC_CONFIG)
	find $$(dirname $(SQLC_DB_FILE)) -type f -name '$$(basename $(SQLC_DB_FILE))' -exec perl -pi -e 's/interface\{\}/any/g' {} +
	find $$(dirname $(SQLC_DB_FILE)) -type f -name '$$(basename $(SQLC_DB_FILE))' -exec gofmt -w {} +

# Generate Swagger documentation using swag
docsgen:
	command -v swag >/dev/null 2>&1 || go install github.com/swaggo/swag/cmd/swag@latest
	swag init -g $(SWAG_MAIN) -o $(SWAG_OUT)
```

## Required Checks

- Run `make check` after Go source changes.
- Run `make test` after behavior changes.
- Run `make race` before handing off meaningful backend or concurrency-related changes.
- Run `make gen` after changing interfaces, sqlc inputs, or Swagger annotations in backend projects.
- Run `make test-mutation-pkg PKG=./path/to/package` when hardening tests for a focused package, and `make test-mutation` when a broader mutation pass is needed.
