---
name: spec-creator
description: Create a Korean SPEC.md for a new software project through staged requirements discovery. Use when the user wants to start a new project, define requirements, or draft a SPEC.md from scratch.
---

# Spec Creator

Help the developer produce a SPEC.md for a new project, as a senior architect pair-programming on the spec rather than writing a formal document. The result serves two downstream readers:

1. **`plan-dev`** — detailed enough to build a concrete implementation plan from, including the `## Open Questions` and `[ASSUMED]` markers it will surface before planning.
2. **`setup-initial-repo`** — its Tech Stack, Architecture, and Conventions drive the generated agent file and command surface.

Four stages. Always tell the developer which one you are in.

```
Stage 1: Seed       → understand the initial idea
Stage 2: Deep Dive  → ask targeted questions to fill gaps
Stage 3: Draft      → generate the SPEC.md
Stage 4: Refine     → review and iterate
```

## Stage 1 — Seed

The developer describes what they want to build, from a sentence to several paragraphs. Read it carefully, summarize your understanding back in 3-5 sentences, and state explicitly which SPEC sections you can already fill and which need more.

## Stage 2 — Deep Dive

**One question at a time** — never several in one message. Two rules shape how you ask:

- **Ask with options when the question has 2-4 concrete answers** (tech stack, architecture pattern, database), each with a brief trade-off note relevant to *this* project. Ask in plain text for open-ended things — purpose, business rules, free-form description.
- **Skip what you can infer.** "Go REST API" already answered the language question; confirm the inference instead of asking it.

Work down this order, skipping what the developer has already addressed and following a natural follow-up before jumping to an unrelated topic:

1. Core purpose & scope — what problem, which users
2. Context architecture — external systems, upstream/downstream
3. Runtime architecture — how it runs (server, worker, CLI, cron), ports, protocols, async patterns
4. Tech stack — language, framework, database, messaging, CI
5. Functional requirements — features, business rules, API contracts
6. Code/module architecture — package structure, layering
7. Conventions — error handling, logging, auth, API response format
8. Quality attributes — performance, availability, observability
9. Constraints — infrastructure limits, compliance, team policy
10. Dependencies — external services, third-party libraries, other teams' APIs

Move to Stage 3 when every area has at least a basic answer (including "not applicable"), when the developer says that is enough, or after about 20 questions — summarizing the remaining gaps as you go.

## Stage 3 — Draft

Write the draft directly to `./SPEC.md`. If it already exists, ask whether to overwrite or use a different path first.

**Do not paste the document into chat.** Report which sections you filled, which rely on assumptions (marked `[ASSUMED]` inline), and which items went to `Open Questions` — then invite the developer to open the file.

### Template

```markdown
# {Project Name}

{프로젝트가 무엇이고 왜 존재하는지 2-3줄}

## Tech Stack

- Language: {language and version}
- Framework: {framework}
- Database: {database}
- Messaging: {messaging system, if any}
- Testing: {test framework}
- Mocking: {mock framework}
- CI: {CI system}

## Architecture

### Context

{시스템이 외부 세계와 어떻게 상호작용하는지 — 사용자, 외부 시스템, 써드파티 API 등.
가능하면 간단한 ASCII 다이어그램 포함.}

### Runtime

{실행 시점에 프로세스/컨테이너가 어떻게 구성되고 통신하는지.
배포 단위, 포트, 프로토콜, 비동기 워커, DB 커넥션 등.}

### Code / Module

{패키지 구조와 각 모듈의 책임}

## Conventions

- Error handling: {규칙}
- Logging: {로깅 라이브러리 및 패턴}
- API error response: {응답 형식}
- Auth: {인증/인가 패턴}
- {기타 팀/프로젝트 고유 컨벤션}

## Functional Requirements

### FR-1: {기능 이름}

{이 기능이 무엇을 하는지, 왜 필요한지}

- Input: {입력 데이터/API 요청}
- Output: {출력 데이터/API 응답}
- Business rules:
  - {규칙 1}
  - {규칙 2}
- Edge cases:
  - {케이스 1}

{FR-2, FR-3, ... 동일 구조 반복}

## Quality Attributes

- Performance: {측정 가능한 성능 목표}
- Scalability: {확장성 목표}
- Availability: {가용성 목표}
- Observability: {메트릭, 트레이싱, 로깅 요구사항}
- Security: {보안 요구사항}
- Testability: {테스트 전략, 커버리지 목표}

## Constraints

- {위반 불가능한 제약 조건들 — 인프라, 정책, 기술 제한 등}

## Dependencies

{외부 서비스, 다른 팀의 API, 써드파티 라이브러리 등}

## Open Questions

- {아직 결정되지 않은 사항들}
```

### Writing the draft

- **Concrete, not generic** — "PostgreSQL 15 with pgx driver", not "relational database".
- **Examples over descriptions** — show the JSON for an error response format.
- **Mark unknowns honestly** — `[ASSUMED] ...` inline, or an entry in Open Questions. `plan-dev` reads both, so an honest marker becomes a question asked at the right moment instead of a wrong assumption baked into a plan.
- **Each FR implementable as one feature** — that is also what makes it a decomposition unit for a multi-steps plan.
- **Conventions prescriptive** — "Use `fmt.Errorf(\"context: %w\", err)`", not "wrap errors appropriately".
- **Architecture visual** — ASCII diagrams for Context and Runtime where they help.
- **Never fabricate a requirement.** If the developer has not mentioned a feature, do not invent one; that is what Open Questions is for.

## Stage 4 — Refine

Review with the developer section by section. Apply feedback to the affected sections only, and show only what changed — not the whole document. Repeat until they approve, then confirm the path and suggest `setup-initial-repo` as the next step.

## Language

The SPEC.md is **always Korean**, whatever the conversation language. Technical terms — library and framework names, CLI commands — stay English. Conversation follows the developer's language.
