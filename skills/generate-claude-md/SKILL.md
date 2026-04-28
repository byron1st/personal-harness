---
name: generate-claude-md
description: Generate a CLAUDE.md file from a SPEC.md document for initial project setup. Use this skill whenever the user wants to create a CLAUDE.md, set up agent instructions for a new project, bootstrap CLAUDE.md from a spec, or says things like "generate CLAUDE.md", "create CLAUDE.md from spec", "set up agent instructions", or "init CLAUDE.md". Also trigger when the user mentions setting up a new project and a SPEC.md file exists in the repository.
---

# Generate CLAUDE.md from SPEC.md

Generate a concise, high-quality CLAUDE.md file by extracting and transforming relevant sections from a SPEC.md document. The output follows the "Self-Contained Essentials" structure — a single file under 150 lines containing everything an AI coding agent needs to start working immediately.

## Process

### Step 1: Locate and Read SPEC.md

Find the SPEC.md file in the project root or ask the user for its location. Read it fully before proceeding.

If no SPEC.md exists, inform the user and suggest they create one first.

### Step 2: Discover Project State

Check whether the project already has build/test infrastructure:

1. Check for `Makefile` — if present, extract available targets (`make -qp | grep -E '^[a-zA-Z]' | grep -v '^make'` or read the file directly)
2. Check for `go.mod` — confirm Go version and module path
3. Check for existing test files, linter config (`.golangci.yml`, etc.)
4. Check for existing `CLAUDE.md` — if present, warn the user and ask whether to overwrite or merge

If no Makefile exists, generate Core Commands based on Go conventions and the tech stack declared in SPEC.md.

### Step 3: Generate CLAUDE.md

Map SPEC.md sections to CLAUDE.md following the rules below.

#### Section Mapping

| SPEC.md Section | CLAUDE.md Section | Transformation |
|---|---|---|
| Project title + first paragraph | `# {Project Name}` + description | Compress to 1-2 lines |
| Tech Stack | Integrated into header description | Summarize key technologies in one line |
| Architecture > Code / Module | `## Architecture Overview` | Package structure + one-line responsibility per module |
| Conventions | `## Code Conventions` | Carry over as prescriptive statements |
| Tech Stack > Testing + Mocking | `## Testing` | Framework, file naming rules, mock tooling |
| Quality Attributes > Security, Testability | `## Testing` or `## Boundaries` | Distribute to the relevant section |
| Constraints | `## Boundaries` | Convert to "NEVER" prohibition rules |
| Dependencies | `## Dependencies & Integrations` | Include only when external services exist |
| Functional Requirements | ❌ Do NOT include | CLAUDE.md does not carry feature specs |
| Quality Attributes | ❌ Mostly excluded | Performance targets etc. belong in the plan phase |
| Open Questions | ❌ Do NOT include | Unresolved items stay in SPEC.md |

#### Core Commands (not in SPEC.md)

Use actual Makefile targets when available. Otherwise infer from the tech stack:

- Go projects: `go build ./...`, `go test ./...`, `golangci-lint run`
- Node projects: `npm run build`, `npm test`, `npm run lint`
- Other stacks: ask the user

#### Git Workflow (not in SPEC.md)

Generate defaults and confirm with the user:

```
- Branch: `feat/{description}` or `fix/{description}`
- Commit: `{prefix}: {description}` (feat, fix, refactor, test, ci, chore)
```

For Jira-integrated environments, use `feat/{JIRA-TICKET}-{description}` and `{prefix}: [{JIRA-TICKET}] {description}`.

### Step 4: Review and Present

1. Check line count — if over 150 lines, trim or extract to separate reference files
2. Show the full content to the user and request review
3. Apply feedback and save to the project root

## Output Template

```markdown
# {Project Name}

{1-2 line description extracted from SPEC.md first paragraph. Include core tech stack.}

## Core Commands

- Build: `{build command}`
- Test all: `{test command}`
- Test single: `{single test command}`
- Lint: `{lint command}`
- Lint fix: `{lint fix command}`
- Run: `{run command, if applicable}`

## Architecture Overview

{Extracted from SPEC.md Architecture > Code / Module section}

## Code Conventions

{Extracted from SPEC.md Conventions section. Each item as a prescriptive statement.}

## Testing

{Test/mock framework from SPEC.md Tech Stack}

## Git Workflow

{Defaults or confirmed by user}

## Boundaries

{Converted from SPEC.md Constraints + common prohibition rules}
```

## Writing Rules

- **CLAUDE.md MUST be written in English.** Even if SPEC.md is in another language, all content (section titles, descriptions, rules) must be in English. Code, commands, and paths remain as-is.
- **150 lines or fewer.** If exceeding, switch to progressive disclosure with separate reference files.
- **Be prescriptive.** "Wrap errors appropriately" ❌ → "Wrap errors with `errors.Join(Err..., err)`" ✅
- **Provide alternatives in prohibition rules.** "NEVER use `var`" ❌ → "NEVER use `var`; prefer `const` or `:=`" ✅
- **Transform, don't copy from SPEC.md.** SPEC.md explains "why"; CLAUDE.md keeps only "do this / don't do that".
- **Describe module responsibilities over file paths.** Paths change; use format like `internal/domain/: business logic, domain models`.
- **NEVER include Functional Requirements.** Feature specs are input for the plan phase, not content for CLAUDE.md which loads every session.
