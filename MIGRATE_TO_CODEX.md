# Migrating Claude Code to Codex

이 문서는 **Claude Code → Codex** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**, 그리고 **Codex → Cursor**다. Personal 환경의 중심은 Claude Code이고 Work 환경의 중심은 Codex이므로, Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. Cursor는 Work의 하위 변형이므로 Codex에서만 파생되며 Cursor를 소스로 쓰는 역방향은 지원하지 않는다. 이 문서의 소스는 Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이고, 대상은 Codex 변형(`skills/codex/`, `agents/codex/`, `hooks/codex/`)이다. Codex → Claude Code 단계는 [MIGRATE_TO_CLAUDE.md](MIGRATE_TO_CLAUDE.md), Codex → Cursor 단계는 [MIGRATE_TO_CURSOR.md](MIGRATE_TO_CURSOR.md)를 참고한다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent 정의 파일), 훅(hook 설정·스크립트) — 이고, 아래도 그 순서로 나눈다.

## Skill migration

`skills/claude/<skill>`를 `skills/codex/<skill>`로 옮길 때의 규칙이다.

### Preserve Work-only skill exceptions

- `loki-log-search`는 Work-only 스킬이다. `skills/codex/loki-log-search`와 `skills/cursor/loki-log-search`에만 존재해야 하며, Claude Code/OpenCode 같은 personal 변형으로 만들지 않는다.
- Claude → Codex 동기화 중 Claude 소스에 `loki-log-search`가 없더라도 Codex 대상에서 삭제하지 않는다. 이 스킬을 갱신할 때는 Codex를 소스로 삼아 [MIGRATE_TO_CURSOR.md](MIGRATE_TO_CURSOR.md)에 따라 Cursor로만 전파한다.

### Keep frontmatter descriptions short and trigger-focused

Codex는 시작 시 각 Skill의 `name`, `description`, 경로만 먼저 본다. 초기 Skill 목록에는 예산이 있으므로 Skill이 많거나 description이 길면 description이 축약되거나 일부 Skill이 초기 목록에서 빠질 수 있다.

- `description`의 첫 문장에 핵심 trigger를 둔다.
- 구현 방식, 산출물 형식, 세부 절차는 본문이나 `references/`로 옮긴다.
- 긴 bullet list, 다중 문단 description, 플랫폼별 내부 구현 설명을 피한다.
- 권장 기준: 한두 문장, 대략 300자 이내.

### Gate subagent usage behind explicit user intent

Claude Code는 subagent description과 문맥을 보고 자동 위임할 수 있지만, Codex는 사용자가 명시적으로 subagent, delegation, parallel agent work를 요청했을 때만 subagent를 spawn한다.

- Skill이 subagent를 전제로 하면, 먼저 명시적 위임 요청이 있었는지 확인한다.
- 명시적 요청이 없으면 메인 세션에서 같은 작업을 수행하는 fallback을 둔다.
- 자동 위임을 전제로 한 문장, 예를 들어 "always dispatch" 같은 지시는 Codex용 Skill에서 제거한다.
- 사용자가 위임 여부를 선택해야 하는 workflow라면 작업 시작 전에 한 번만 묻는다.

### Replace Claude Code agent invocation with Codex agent concepts

Claude Code의 `Agent` tool, `subagent_type`, Markdown 기반 custom agent 파일은 Codex의 agent 모델과 다르다.

- Codex 기본 agent는 `default`, `worker`, `explorer`를 기준으로 생각한다.
- 구현/수정 작업은 보통 `worker`, 읽기 중심 조사나 리뷰는 보통 `explorer`에 맞춘다.
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

### Handle Codex skill UI metadata

`skills/codex/<skill>/agents/openai.yaml`은 Codex/OpenAI UI 메타데이터이며 repo-level custom agent 정의(`agents/codex/*.toml`)가 아니다.

- Claude 소스에 대응 파일이 없어도 Codex 대상 스킬이 이미 `agents/openai.yaml`을 사용한다면 삭제하지 않는다.
- 새 Codex 스킬에서 UI metadata가 필요하다고 판단한 경우에만 `agents/openai.yaml`을 생성한다. 기존 모든 스킬에 일괄 추가하지 않는다.
- 생성/갱신 시 `SKILL.md`를 기준으로 `display_name`, `short_description`, `default_prompt`를 맞추고, `default_prompt`는 `$skill-name` 형식을 포함한다.
- 이 파일은 Codex 대상 전용이다. Claude/Cursor로 다시 마이그레이션할 때는 대상 스킬에 복사하지 않는다.

## Sub-agent migration

`agents/claude/*.md`(custom agent)를 `agents/codex/*.toml`로 옮길 때의 규칙이다.

### Convert custom agents to Codex TOML agents

Claude Code custom agent는 Markdown 파일의 YAML frontmatter와 본문으로 정의되지만, Codex custom agent는 standalone TOML 파일로 정의한다. Claude Code용 custom agent를 Codex에서도 쓰려면 파일 형식을 변환하고 배포 경로를 분리한다.

- Codex agent 소스는 플랫폼별 디렉토리에 둔다. 예: `agents/codex/*.toml`.
- 설치 대상은 개인 전역 agent면 `~/.codex/agents/`, 프로젝트 범위 agent면 `.codex/agents/`다.
- 각 TOML 파일에는 최소한 `name`, `description`, `developer_instructions`를 둔다.
- Claude Markdown의 짧은 역할 요약은 `description`으로 옮긴다. Codex가 agent를 고를 때 읽기 쉬워야 하므로 한두 문장으로 유지한다.
- Claude Markdown 본문은 `developer_instructions = """..."""`로 옮긴다. 단, Claude 전용 tool 이름, permission mode, hook, 자동 dispatch 전제는 제거하거나 Codex 표현으로 바꾼다.
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
- `Stop` hook은 plain text stdout이 유효하지 않다. 종료 시 continuation을 유도하려면 `{decision:"block",reason}` JSON(또는 exit code `2` + stderr에 continuation reason)을 출력한다. `.stop_hook_active`가 true면 무한 루프 방지로 반드시 통과시킨다.
- Codex hook은 guardrail이지 완전한 보안 경계가 아니다. 공식 문서상 `PreToolUse`는 모든 shell 경로를 아직 intercept하지 못하므로, 중요한 정책은 전역 instructions와 별도 검증 명령에도 남긴다.
- 배포 스크립트가 personal harness를 Codex hooks의 source of truth로 관리한다면 `~/.codex/hooks/`를 먼저 정리한 뒤 `hooks/codex/hooks/*`만 복사하고, `hooks/codex/hooks.json`은 `~/.codex/hooks.json`으로 덮어쓴다.
- 설치 후 Codex CLI/App에서 새 command hooks를 trust해야 할 수 있다. Codex가 경고하면 `/hooks`에서 검토한다.
