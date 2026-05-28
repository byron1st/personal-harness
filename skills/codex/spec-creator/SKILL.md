---
name: spec-creator
description: Create a Korean SPEC.md for a new software project through staged requirements discovery. Use when the user wants to start a new project, define requirements, or draft a SPEC.md from scratch.
---

# Spec Creator

Help the developer create a thorough `SPEC.md` document for a new software project. The `SPEC.md` has two jobs:

1. Provide enough detail for an AI coding agent to create an implementation plan
2. Provide the source material for initial repository setup and an agent instruction file such as `AGENTS.md`

## Process Overview

The process has 4 stages. Always tell the developer which stage you are in.

```
Stage 1: Seed       -> Understand the initial idea
Stage 2: Deep Dive  -> Ask targeted questions to fill gaps
Stage 3: Draft      -> Generate the SPEC.md
Stage 4: Refine     -> Review and iterate in ./SPEC.md
```

## Stage 1: Seed

The developer provides an initial description of what they want to build. This can range from one sentence to several paragraphs.

Your job:

- Read the input carefully.
- Identify what is already clear and what is missing.
- Summarize your understanding in 3-5 sentences.
- Explicitly list which SPEC sections can already be filled and which need more information.
- Then transition to Stage 2.

## Stage 2: Deep Dive

Ask questions to fill in the `SPEC.md` sections.

### Question Rules

1. Ask one question at a time. Never ask multiple questions in a single message.
2. Start with the most impactful question. Prioritize questions that unlock downstream decisions.
3. Provide options when possible. Instead of open-ended "What database?", offer "PostgreSQL, MySQL, or MongoDB? (or something else)" with brief trade-off notes relevant to the project.
4. Use structured user input for multiple-choice questions when the current Codex mode provides it. When no structured input tool is available, ask in plain text with numbered options. For open-ended questions such as purpose, business rules, or free-form descriptions, ask in plain text.
5. Build on previous answers. Each question should incorporate earlier context.
6. Skip what you can infer. If the developer said "Go REST API", do not ask "What language?" Confirm the inference instead.
7. Group related decisions. When one answer naturally leads to a follow-up, ask that follow-up next.

### Question Priority Order

Follow this order, but skip sections the developer has already addressed:

1. Core purpose and scope: What problem does this solve? Who are the users?
2. Context architecture: What external systems interact with this? What is upstream or downstream?
3. Runtime architecture: How does this run? HTTP server, worker, CLI, cron, ports, protocols, async patterns, etc.
4. Tech stack: Language, framework, database, messaging, CI
5. Functional requirements: Key features, business rules, API contracts
6. Code/module architecture: Package structure, layering strategy
7. Conventions: Error handling, logging, auth pattern, API response format
8. Quality attributes: Performance targets, availability, observability
9. Constraints: Infrastructure limits, compliance, team policies
10. Dependencies: External services, third-party libraries, other teams' APIs

### When to Stop Asking

Move to Stage 3 when:

- All 10 areas above have at least a basic answer, even if some are "not applicable".
- The developer says "that's enough", "let's draft it", or similar.
- You have asked more than 20 questions. In that case, summarize remaining gaps and move on.

## Stage 3: Draft

Generate the complete `SPEC.md` using the template below.

1. Write the draft directly to `./SPEC.md` in the current working directory. If `./SPEC.md` already exists, ask the developer whether to overwrite it or choose a different path before writing.
2. Do not paste the entire document into the chat. Instead, report a short summary: which sections you filled, which used assumptions marked `[ASSUMED]` inline, and which remaining items went into `Open Questions`.
3. Invite the developer to open the file and review.

### SPEC.md Template

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

{시스템이 외부 세계와 어떻게 상호작용하는지 - 사용자, 외부 시스템, 써드파티 API 등. 가능하면 간단한 ASCII 다이어그램 포함.}

### Runtime

{실행 시점에 프로세스/컨테이너가 어떻게 구성되고 통신하는지. 배포 단위, 포트, 프로토콜, 비동기 워커, DB 커넥션 등.}

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

- {위반 불가능한 제약 조건들 - 인프라, 정책, 기술 제한 등}

## Dependencies

{외부 서비스, 다른 팀의 API, 써드파티 라이브러리 등}

## Open Questions

- {아직 결정되지 않은 사항들}
```

### Draft Writing Guidelines

- Be concrete, not generic. Write "PostgreSQL 15 with pgx driver" instead of "relational database".
- Prefer examples over descriptions. For error response format, show a JSON example.
- Mark unknowns honestly. Use `[ASSUMED] ...` inline or put items in `Open Questions`.
- Keep Functional Requirements actionable. Each FR should be implementable as a single feature or task.
- Make Architecture sections visual. Use ASCII diagrams for Context and Runtime where possible.
- Make Conventions prescriptive. Write `fmt.Errorf("context: %w", err)` instead of "wrap errors appropriately".

## Stage 4: Refine

After the draft is written to `./SPEC.md`:

1. Ask the developer to review section by section.
2. For any feedback, apply changes to the file and modify only the affected sections, not the whole file.
3. After each edit, show only the changed section or a concise diff-style summary, not the full document.
4. Repeat until the developer approves.

The file lives at `./SPEC.md` throughout. There is no separate save or download step. When the developer signals completion, confirm the final path and suggest next steps, such as running the `setup-initial-repo` skill to bootstrap the project from this SPEC.

## Behavioral Rules

- Language: The `SPEC.md` document is always written in Korean, regardless of the conversation language. Technical terms such as library names, framework names, CLI commands, and file paths remain in English. Conversation with the developer follows their language.
- Tone: Professional but conversational. Act like a senior architect pair-programming on the spec, not like a formal document generator.
- Do not over-ask. If something is clearly implied, confirm the inference ("I'll assume X based on what you said - correct me if wrong") instead of asking.
- Do not fabricate requirements. If the developer has not mentioned a feature, do not invent one. Use `Open Questions` for unknowns.
- Respect the developer's expertise. Skip basic explanations for experienced developers and adjust depth based on their responses.
