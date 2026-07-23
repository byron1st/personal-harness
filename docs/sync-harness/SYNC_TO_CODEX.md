# Migrating Claude Code to Codex

이 문서는 **Claude Code → Codex** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**다. Personal 환경의 중심은 Claude Code이고 Work 환경의 중심은 Codex이므로, Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. 이 문서의 소스는 Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이고, 대상은 Codex 변형(`skills/codex/`, `agents/codex/`, `hooks/codex/`)이다. Codex → Claude Code 단계는 [SYNC_TO_CLAUDE.md](SYNC_TO_CLAUDE.md)를 참고한다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent 정의 파일), 훅(hook 설정·스크립트) — 이고, 아래도 그 순서로 나눈다.

## Platform invariants (do not translate)

플랫폼 간 파싱·매칭 호환성을 위해 아래 항목은 마이그레이션 시 이름·값을 그대로 보존한다. 도구명·실행모델 변환 규칙이 이 목록보다 우선하지 않는다.

- **공통 반환 섹션명**: `## Stage Status`, `## Evidence`, `## Findings`, `## Decision Needed` — Worker/단계 반환 맨 앞의 공통 블록. 그 아래의 스킬별 헤딩(`## TODO Fulfillment`, `## Suspected` 계열 등 현행 이름)도 개명하지 않는다.
- **플랜 섹션명**: `## Acceptance Contract`, `## Authority Boundaries`, `## TODOs`, `## Non-goals`, `## Key decisions`.
- **리뷰 섹션명**: `## Accepted Review Exceptions`, `## Applied Exceptions`.
- **상태 어휘**: `pass | blocked | failed | needs-confirmation | needs-decision | changes-required` (+ test-dev 전용 `pass-with-suspected-defects`). 번역·동의어 치환 금지.
- **ID 규칙**: `AC-N`, `AR-NNN`, `TEST-NNN`(test Worker가 부여), `REVIEW-NNN`(aggregate 시 메인 세션이 부여 — reviewer 부여 금지).
- **스킬·에이전트 이름**: `plan-dev`, `implement-dev`, `fix-dev`, `test-dev`, `review-code`, `commit-code`, `request-merge`, (도입 시) `dev-loop`; persona `planner`, `implementer`, `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`.
- **파일명 규칙**: `{timestamp}_{Jira}_PLAN|IMPL|LOOP_{title}.md`와 `-STEP-N` 접미 규칙.
- **AR 불변식**: AR 엔트리는 사용자의 명시적 Accept 응답이 있을 때만 기록한다. 어떤 플랫폼 변형에서도 이 규칙을 완화하거나 자동화하는 번역을 하지 않는다.

## Skill migration

`skills/claude/<skill>`를 `skills/codex/<skill>`로 옮길 때의 규칙이다.

### Keep frontmatter descriptions short and trigger-focused

Codex는 시작 시 각 Skill의 `name`, `description`, 경로만 먼저 본다. 초기 Skill 목록에는 예산이 있으므로 Skill이 많거나 description이 길면 description이 축약되거나 일부 Skill이 초기 목록에서 빠질 수 있다.

- `description`의 첫 문장에 핵심 trigger를 둔다.
- 구현 방식, 산출물 형식, 세부 절차는 본문이나 `references/`로 옮긴다.
- 긴 bullet list, 다중 문단 description, 플랫폼별 내부 구현 설명을 피한다.
- 권장 기준: 한두 문장, 대략 300자 이내.

### Allow Skill-directed delegation with an explicit failure gate

현재 Codex는 subagent collaboration이 활성화되어 있고, 활성 Skill 또는 `AGENTS.md`가 delegation을 요구하는 경우 사용자가 별도로 subagent 사용을 반복하지 않아도 dispatch를 시도할 수 있다. 다만 capability와 surface/build에 따라 spawn이 실패할 수 있으므로, delegation은 다음 규칙을 따른다.

- subagent-dispatch Skill은 Dispatcher-first로 동작한다. Skill이 요구하면 명시적 사용자 위임 문구를 기다리지 말고 dispatch를 시도한다.
- dispatch가 성공하면 Worker가 해당 작업을 전담한다. 메인 세션은 Worker의 변경 작업을 중복 수행하지 않는다.
- worker capability가 없거나 spawn 호출이 실패하면 substantive 작업을 시작하지 않는다.
- 메인 세션은 `Delegation status: unavailable` 또는 `failed`, 관찰된 원인을 사용자에게 보고한다.
- direct fallback은 사용자가 명시적으로 선택한 뒤에만 시작한다. 사용자가 중단을 선택하면 종료한다.
- 여러 Worker 중 일부만 성공한 경우 성공한 결과를 임의로 main session 작업으로 대체하지 않는다. 부분 실패 상태와 direct fallback 여부를 사용자에게 묻는다.
- Worker는 재-dispatch하지 않는다.

### Replace Claude Code agent invocation with Codex agent concepts

Claude Code의 `Agent` tool, `subagent_type`, Markdown 기반 custom agent 파일은 Codex의 agent 모델과 다르다.

- Codex 기본 agent는 `default`, `worker`, `explorer`를 기준으로 생각한다.
- 구현/수정 작업은 보통 `worker`, 읽기 중심 조사나 리뷰는 보통 `explorer`에 맞춘다. (예외: `implement-dev`는 minimal-code 규율을 위해 custom `implementer` agent를 spawn하고, 없으면 built-in `worker`로 폴백한다.)
- custom agent 정의 자체는 "Sub-agent migration"에서 다룬다. Skill 본문에서는 Claude persona agent 이름을 그대로 Codex agent type으로 쓰지 말고, 필요한 persona는 Codex agent prompt 안에 명시한다.
- 별도 컨텍스트가 목적이면 self-contained prompt를 넘기고, parent conversation fork는 필요한 경우에만 사용한다.

### Re-check permissions, sandbox, and tool assumptions

Claude Code subagent는 frontmatter나 settings로 도구 제한, permission mode, hooks를 따로 가질 수 있다. Codex subagent는 기본적으로 현재 sandbox와 approval policy를 상속하며, 부모 turn의 runtime override도 다시 적용된다.

- delegated agent가 독립 권한을 가진다고 가정하지 않는다.
- read-only 작업은 read-only 성격의 agent나 sandbox 설정으로 보장한다.
- 승인이 필요한 작업은 child thread에서 실패하거나 parent workflow로 surfaced 될 수 있음을 문서화한다.
- Claude Code 전용 `allowed-tools`, subagent hook, permission-mode 전제를 Codex용 지시로 남기지 않는다.

### Use Codex plan-mode approval, not host-specific exit tools

Claude Code에는 agent가 호출하는 plan-mode exit tool이 있지만, Codex에서는 UI의 plan approval flow를 통해 사용자가 계획을 승인하고 write-capable 단계로 넘어간다.

- 계획 단계에서는 read-only 행동만 수행한다.
- 최종 계획을 사용자에게 제시하고 Codex의 승인 흐름을 기다린다.
- 승인 후 첫 write는 Skill이 요구하는 persistence나 기록 작업이어야 한다.
- host-specific plan-exit tool 호출을 Codex용 Skill에 남기지 않는다.

### Replace Claude-specific tool names with Codex-safe wording

Claude Code Skill에는 `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `AskUserQuestion` 같은 도구명이 직접 들어가 있을 수 있다. Codex 환경에서는 도구 이름과 사용 방식이 다를 수 있으므로, Skill 본문은 Codex에서 실행 가능한 표현으로 바꾼다.

- 파일 읽기, 검색, 셸 실행, 사용자 질문처럼 기능 중심으로 쓴다.
- 명확히 Codex에서 제공되는 도구를 지칭해야 할 때만 Codex 도구명을 쓴다.
- `AskUserQuestion` 같은 Claude 전용 이름은 "ask the user"나 Codex의 현재 사용자 입력 메커니즘으로 바꾼다.
- 검색 지시는 `rg` 같은 실제 명령이나 "read/search tools"처럼 Codex에서 수행 가능한 방식으로 적는다.
- 전역 지시 파일은 Codex가 자동으로 읽는 `AGENTS.md`를 우선하되, cross-agent repo에서 `CLAUDE.md`가 병존할 수 있으면 필요한 경우 둘 다 확인하도록 둔다.

### Convert structured triage questions to a text response protocol

Claude Code의 review-code 트리아지는 `AskUserQuestion`으로 blocking finding을 항목별 Fix/Accept 분류한다. Codex에는 구조화 질문 도구가 없으므로 텍스트 응답 규약으로 변환한다.

- 요약 테이블(`| ID | Severity | Finding | Recommendation |`)을 그대로 출력한 뒤, 사용자에게 "각 ID에 `REVIEW-001: fix` 또는 `REVIEW-001: accept` 형식으로 응답해 달라"고 요청한다.
- 모호한 응답(형식 불일치, 존재하지 않는 ID, fix/accept 외 단어)은 임의로 해석하지 말고 해당 ID를 재확인한다.
- 응답이 없는 ID는 **미분류로 유지**한다 — 자동 수용 금지, Fix로의 자동 분류도 금지(분류는 사용자의 명시 응답만으로 확정되고, 미분류 잔존 시 Stage Status는 `needs-decision`).
- Accept 분류 항목의 AR 기록 위치·형식·불변식은 Platform invariants 목록을 따른다.

### Migrate controller skills (dev-loop) without agent or hook dependencies

`dev-loop`는 다른 스킬의 Dispatcher 흐름을 호출하고 상태를 전이시키는 **primary 세션 컨트롤러 스킬**이다. 자체적으로 Worker를 spawn하지 않으므로 별도 custom agent도, `agents/openai.yaml`도 필요 없다.

- 본문은 host-neutral하다(스테이지 스킬 위임이라 Claude 전용 도구명이 없음). 거의 그대로 옮기되, `description`만 300자 이내 trigger 중심으로 압축한다.
- 트리아지 등 사용자 상호작용은 dev-loop가 직접 하지 않고 호출되는 `review-code`가 소유하므로, 트리아지 텍스트 응답 규약(위 "Convert structured triage questions..." 참조)은 `review-code`에만 적용되고 dev-loop 본문에는 추가 변환이 없다.
- **루프 불변식은 스킬 본문 규칙으로만 보장된다.** 커밋·푸시·PR 금지, AR은 사용자 명시 Accept 시에만 기록, 테스트 약화 금지, 예산 초과 금지 등은 SKILL 본문이 강제한다 — 훅에 의존하지 않는다. Codex의 `PreToolUse`는 공식 문서상 모든 shell 경로를 intercept하지 못하므로, 훅으로 루프 불변식을 강제한다고 가정하지 말고 본문 규칙을 그대로 보존한다.
- 상태 어휘·섹션명·ID·스킬 이름은 Platform invariants 목록대로 번역하지 않는다.

### Handle Codex skill UI metadata

`skills/codex/<skill>/agents/openai.yaml`은 Codex/OpenAI UI 메타데이터이며 repo-level custom agent 정의(`agents/codex/*.toml`)가 아니다.

- Claude 소스에 대응 파일이 없어도 Codex 대상 스킬이 이미 `agents/openai.yaml`을 사용한다면 삭제하지 않는다.
- 새 Codex 스킬에서 UI metadata가 필요하다고 판단한 경우에만 `agents/openai.yaml`을 생성한다. 기존 모든 스킬에 일괄 추가하지 않는다.
- 생성/갱신 시 `SKILL.md`를 기준으로 `display_name`, `short_description`, `default_prompt`를 맞추고, `default_prompt`는 `$skill-name` 형식을 포함한다.
- 이 파일은 Codex 대상 전용이다. Claude로 다시 마이그레이션할 때는 대상 스킬에 복사하지 않는다.

## Sub-agent migration

`agents/claude/*.md`(custom agent)를 `agents/codex/*.toml`로 옮길 때의 규칙이다.

### Convert custom agents to Codex TOML agents

Claude Code custom agent는 Markdown 파일의 YAML frontmatter와 본문으로 정의되지만, Codex custom agent는 standalone TOML 파일로 정의한다. Claude Code용 custom agent를 Codex에서도 쓰려면 파일 형식을 변환하고 배포 경로를 분리한다.

- Codex agent 소스는 플랫폼별 디렉토리에 둔다. 예: `agents/codex/*.toml`.
- 설치 대상은 개인 전역 agent면 `~/.codex/agents/`, 프로젝트 범위 agent면 `.codex/agents/`다.
- 각 TOML 파일에는 최소한 `name`, `description`, `developer_instructions`를 둔다.
- Claude Markdown의 짧은 역할 요약은 `description`으로 옮긴다. Codex가 agent를 고를 때 읽기 쉬워야 하므로 한두 문장으로 유지한다.
- Claude Markdown 본문은 `developer_instructions = """..."""`로 옮긴다. 단, Claude 전용 tool 이름, permission mode, hook, 자동 dispatch 전제는 Codex의 Skill-directed delegation 규칙과 runtime failure gate로 번역한다.
- Claude frontmatter의 `tools:`는 그대로 옮기지 않는다. Codex에서 read-only agent가 필요하면 `sandbox_mode = "read-only"` 같은 Codex config key를 사용하고, instructions에도 "no edits, no commits"를 남긴다.
- agent 이름은 Codex에서 spawn할 때 쓰는 source of truth다. 파일명과 `name`을 맞추는 단순한 규칙을 쓴다.
- Codex 기본 agent 이름(`default`, `worker`, `explorer`)과 충돌하는 custom `name`은 피한다. 충돌하면 custom agent가 우선되어 예상과 다른 동작이 날 수 있다.
- Skill 본문에서 custom agent를 사용할 때는 Claude Code의 `Agent` / `subagent_type` 표현 대신 Codex agent `name`을 명시한다.
- 배포 스크립트가 personal harness를 Codex agent의 source of truth로 관리한다면 `~/.codex/agents/`를 먼저 정리한 뒤 `agents/codex/*.toml`만 복사한다. 기존 사용자 agent를 보존해야 하는 환경이라면 별도 디렉토리나 프로젝트 범위 `.codex/agents/`를 사용한다.

## Hook migration

`hooks/claude/`를 `hooks/codex/`로 옮길 때의 규칙이다.

### Convert hooks to Codex hooks.json

Claude Code hook 설정은 `settings.json`의 `hooks` 블록으로 배포할 수 있지만, Codex는 `hooks.json` 또는 `config.toml`의 inline `[hooks]` 테이블을 읽는다. 같은 layer에 둘 다 두면 Codex가 merge하고 startup warning을 낼 수 있으므로 한 표현을 고른다. Personal harness에서는 `hooks.json`을 기본 형식으로 사용한다.

- Codex hook 소스는 플랫폼별 디렉토리에 둔다. 예: `hooks/codex/hooks.json`, `hooks/codex/hooks/*.sh`.
- 개인 전역 배포 대상은 `~/.codex/hooks.json`과 `~/.codex/hooks/`다. 프로젝트 범위 hook이면 `<repo>/.codex/hooks.json`과 `<repo>/.codex/hooks/`를 사용한다.
- Claude Code의 command path가 `$HOME/.claude/hooks/...`이면 Codex용으로 `$HOME/.codex/hooks/...`로 바꾼다.
- `SessionStart` 훅은 `matcher: "startup|resume|clear|compact"`와 `hookSpecificOutput.additionalContext`를 유지한다. `session-context.sh`는 `WORK_GITLAB_HOST`와 origin remote로 work/personal repo를 판별해 세션 컨텍스트에 넣는다.
- `PreToolUse`의 `Bash` matcher와 `Stop` hook은 대체로 그대로 옮길 수 있다. Codex도 hook input JSON에서 `cwd`, `stop_hook_active`, `tool_input.command`를 제공하며, `{decision:"block",reason}` 출력 스키마가 Claude Code와 동일하다.
- 파일 편집 hook은 Codex의 실제 tool 이름을 반영해 `apply_patch|Edit|Write` matcher를 사용한다. Codex 문서상 `apply_patch`가 canonical name이고 `Edit` / `Write`는 matcher alias다.
- `PreToolUse`에서 차단하려면 exit code `2`와 `stderr` 메시지를 사용하거나, JSON의 `permissionDecision: "deny"` / legacy `decision: "block"`을 사용한다.
- `PostToolUse`는 이미 실행된 side effect를 되돌리지 않는다. 실패나 추가 지시를 Codex에 feedback으로 전달하는 용도로 사용한다.
- `UserPromptSubmit`에서 context를 추가하려면 `hookSpecificOutput.additionalContext` JSON을 출력한다. Plain text도 developer context로 추가될 수 있지만, 구조화 JSON을 선호한다.
- `Stop` hook is plain text stdout이 유효하지 않다. 종료 시 continuation을 유도하려면 `{decision:"block",reason}` JSON(또는 exit code `2` + stderr에 continuation reason)을 출력한다. `.stop_hook_active`가 true면 무한 루프 방지로 반드시 통과시킨다.
- 문서 드리프트 검사는 훅으로 옮기지 않는다. 모든 플랫폼의 `commit-code` skill이 커밋 후 변경 범위를 읽기 전용으로 검사하고, 필요한 문서와 업데이트 개요만 사용자에게 보고한다.
- Codex hook은 guardrail이지 완전한 보안 경계가 아니다. 공식 문서상 `PreToolUse`는 모든 shell 경로를 아직 intercept하지 못하므로, 중요한 정책은 전역 instructions와 별도 검증 명령에도 남긴다.
- 배포 스크립트가 personal harness를 Codex hooks의 source of truth로 관리한다면 `~/.codex/hooks/`를 먼저 정리한 뒤 `hooks/codex/hooks/*`만 복사하고, `hooks/codex/hooks.json`은 `~/.codex/hooks.json`으로 덮어쓴다.
- 설치 후 Codex CLI/App에서 새 command hooks를 trust해야 할 수 있다. Codex가 경고하면 `/hooks`에서 검토한다.
