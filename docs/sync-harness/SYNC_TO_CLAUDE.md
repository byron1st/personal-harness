# Migrating Codex to Claude Code

이 문서는 **Codex → Claude Code** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, Claude Code와 Codex 변형을 양방향으로 공유할 때 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**(양방향)다. 이 문서는 Codex 변형을 소스로 삼아 Claude Code 변형을 갱신하는 공식 경로다. Claude와 Codex의 공유 스킬 집합은 동일해야 하며 플랫폼 전용 스킬 예외는 없다.

이 문서의 소스는 Codex 에이전트·훅(`agents/codex/`, `hooks/codex/`)이고, 대상은 Claude Code 에이전트·훅(`agents/claude/`, `hooks/claude/`)이다. 제품 스킬은 공유 트리 `skills/<name>/`이며 변환하지 않는다.

옮기는 대상은 서브에이전트와 훅이다. 스킬 불변식은 아래 Shared skills 절.

## Shared skills

제품 스킬은 `skills/<name>/` 한 트리만 쓴다. `skills/{claude,codex,cursor,grok}/`를 만들지 않는다. 스킬은 플랫폼 변환 대상이 아니다. 에이전트·훅만 이 문서의 나머지 절을 따른다.

불변식 (스킬 본문·references):

- frontmatter는 `name` + `description`만. `allowed-tools` 금지.
- description은 한두 문장, 대략 300자, 첫 문장에 trigger. Dispatcher/Worker 절차를 description에 넣지 않는다.
- 호스트 툴 이름 금지: `Agent`, `Task`, `spawn_subagent`, `AskUserQuestion`, `AskQuestion`, `ask_user_question`, `ExitPlanMode`, `fork_turns`, `subagent_type`.
- 질문은 "사용자에게 물어라". 객관식이면 선택지와 미응답=미분류만 적는다.
- 런타임 스크립트는 `$HOME/.agents/scripts/detect-commands.sh` 와 `$HOME/.agents/scripts/resolve-scope.sh`만.
- `agents/<platform>/` 경로를 스킬에 넣지 않는다. Reporting contract는 persona 본문의 `## Reporting contract`로 지칭한다.
- 스테이지 스킬은 persona를 띄우지 않는다. `dev-loop`가 단계 persona를 띄운다. standalone implement/test/fix는 현재 세션 in-place.
- `(design-bearing)` TODO는 `## Stage Status: needs-design-decision`을 반환한다. 실행자가 `plan-consultant`를 띄우지 않는다. `needs-design-decision`은 공통 상태 어휘이며 `blocked`와 섞지 않는다.
- `failed` 재시도는 루프가 같은 persona를 한 번 더 띄운다. 스킬에 호스트 모델명을 적지 않는다.

설치: `~/.agents/skills`가 유일 설치본. Claude만 스킬 단위 심링크 `~/.claude/skills/<name> → ~/.agents/skills/<name>`. Cursor/Codex/Grok 플랫폼 스킬 디렉터리에서 harness 이름은 제거한다. `sync-harness`는 `~/.agents/skills`에 설치하지 않는다.
Cursor/Grok Claude-compat 스킬 스캔은 끈 채로 `~/.agents/skills`를 쓴다.

## Sub-agent migration

`agents/codex/*.toml`를 `agents/claude/*.md`로 옮길 때의 규칙이다.

### Convert Codex TOML agents to Claude Code Markdown agents

Codex custom agent는 standalone TOML이고, Claude Code custom subagent는 Markdown 파일의 YAML frontmatter와 본문으로 정의한다.

- Codex agent 소스는 `agents/codex/<name>.toml`, Claude Code 대상은 `agents/claude/<name>.md`다.
- 설치 대상은 개인 전역 agent면 `~/.claude/agents/`, 프로젝트 범위 agent면 `.claude/agents/`다. personal harness에서는 `scripts/apply-to-claude.sh`가 `agents/claude/*`를 `~/.claude/agents/`로 동기화한다.
- filename과 frontmatter `name`은 같은 hyphenated name으로 유지한다. Claude Code가 반드시 파일명과 `name`을 같게 요구하는 것은 아니더라도, skill 본문 dispatch 참조와 맞추기 위해 이 repo에서는 일치시킨다.
- TOML `developer_instructions`는 Markdown body로 옮긴다. 본문이 host-neutral하면 의미를 바꾸지 말고, Codex 전용 권한·sandbox·agent 이름만 제거한다.

### Field mapping

| Codex TOML | Claude Code Markdown | 메모 |
| --- | --- | --- |
| `name = "..."` | `name:` | 파일명·skill dispatch 이름과 일치 |
| `description = "..."` | `description:` | Claude Code automatic delegation에 쓰일 수 있으므로 trigger와 persona를 충분히 설명 |
| `sandbox_mode = "read-only"` | `tools: Read, Grep, Glob, Bash` + 본문 hard rule | Claude Code에 `readonly: true` 키를 만들지 않는다 |
| `developer_instructions = """..."""` | `---` 아래 본문 | Markdown heading 포함 가능 |
| `model`, `model_reasoning_effort` | `model:` 또는 생략 | 부모/default 모델을 쓰면 생략 |

Claude Code frontmatter에는 `tools` 같은 도구 allowlist를 둘 수 있다. Codex의 `sandbox_mode`를 문자 그대로 옮기지 말고, 실제로 허용할 Claude Code 도구 집합을 고른다.

### Restore richer Claude Code subagent descriptions when useful

- Codex `description`은 보통 짧다. Claude Code subagent description은 agent 선택과 자동 위임에 직접 영향을 줄 수 있으므로, reviewer persona처럼 선택 기준이 중요한 agent는 역할·범위·금지 범위를 더 자세히 적는다.
- 단, description이 너무 길어져 본문과 중복되면 줄인다. 핵심은 "언제 이 subagent를 써야 하는가"다.
- YAML 콜론 함정을 확인한다. TOML에서는 안전했던 `description = "security findings: authn/authz"` 같은 값은 YAML에서 `description: "security findings: authn/authz"`처럼 따옴표가 필요할 수 있다.

### Convert read-only and tool policy carefully

- Codex read-only agent를 Claude Code로 옮길 때는 `tools: Read, Grep, Glob, Bash`처럼 읽기 중심 도구만 허용하고, 본문에도 "Read-only. No edits. No commits. No working tree changes."를 남긴다.
- reviewer agent가 shell을 써야 하면 `Bash`는 허용하되, 본문에서 검증·검색 목적임을 명확히 한다. Hook이나 global instruction이 `rg`/`fd` 사용을 강제한다면 그 전제를 유지한다.
- Codex의 `mcp_servers`, `skills.config`, sandbox/network 설정은 Claude Code agent frontmatter로 자동 변환하지 않는다. Claude Code에서 실제로 필요한 MCP/tool 설정만 명시한다.

### Verify

- 서브에이전트 트리 패리티: `agents/codex/*.toml`와 `agents/claude/*.md`가 필요한 범위에서 1:1로 대응하는가.
- 각 `agents/claude/*.md` frontmatter가 실제 YAML 파서로 파싱되는가.
- 각 `name`이 파일명·skill 본문 `subagent_type` 참조와 일치하는가.
- read-only persona에 편집 도구(`Edit`, `Write`, `MultiEdit`)가 들어가지 않았는가.
- 본문에 Codex 전용 표현(`sandbox_mode`, `worker`, `explorer`, `Codex custom agent`, `~/.codex`)이 의도 없이 남지 않았는가.

## Hook migration

`hooks/codex/`를 `hooks/claude/`로 옮길 때의 규칙이다.

### Convert Codex hooks.json to Claude Code settings.json

Codex hook 설정은 `hooks.json` 또는 `config.toml` inline `[hooks]` 테이블로 둘 수 있다. Claude Code는 `settings.json`의 `hooks` 블록으로 배포한다. 이 repo에서는 `hooks/claude/settings.json`이 Claude Code hook 설정의 source of truth다.

- Codex 소스는 `hooks/codex/hooks.json`과 `hooks/codex/hooks/*.sh`, Claude Code 대상은 `hooks/claude/settings.json`과 `hooks/claude/hooks/*.sh`다.
- command path의 `$HOME/.codex/hooks/...`를 `$HOME/.claude/hooks/...`로 바꾼다.
- Codex의 `hooks.json` 전체를 Claude Code `settings.json`으로 그대로 복사하지 말고, `hooks` 블록을 `settings.json` 최상위 안에 둔다. 기존 Claude settings의 다른 키(`permissions`, `env`, `model` 등)는 설치 스크립트가 merge할 수 있어야 한다.
- personal harness에서는 `scripts/apply-to-claude.sh`가 `hooks/claude/hooks/*`를 `~/.claude/hooks/`로 동기화하고, `hooks/claude/settings.json`을 `~/.claude/settings.json`에 merge한다.

### Event and matcher mapping

Codex hook 이벤트명은 Claude Code와 매우 가깝지만, 파일 편집 도구 이름과 경로는 다르다.

| Codex | Claude Code | 메모 |
| --- | --- | --- |
| `SessionStart` matcher `startup|resume|clear|compact` | `SessionStart` matcher `startup|resume|clear|compact` | work/personal session context 주입은 양쪽 모두 `hookSpecificOutput.additionalContext` 사용 |
| `PreToolUse` matcher `Bash` | `PreToolUse` matcher `Bash` | 대체로 유지 |
| `PostToolUse` matcher `apply_patch\|Edit\|Write` | `PostToolUse` matcher `Edit\|Write\|MultiEdit` | Codex canonical `apply_patch`를 Claude edit tool 이름으로 변환 |
| `$HOME/.codex/hooks/...` | `$HOME/.claude/hooks/...` | 설치 대상 변경 |

Codex에서 MCP tool matcher를 쓰고 있었다면 Claude Code에서 같은 tool 이름과 이벤트 입력이 실제로 존재하는지 확인한다. 이름만 비슷하다는 이유로 무조건 복사하지 않는다.

### Script I/O and blocking

- Codex와 Claude Code 모두 hook script는 stdin JSON을 받고 exit code와 stdout/stderr로 결과를 전달한다. 그래도 입력 필드가 완전히 같다고 가정하지 말고 실제 샘플 stdin으로 스모크 테스트한다.
- Bash command 검사류는 `.tool_input.command`와 `.cwd` 사용 여부를 확인한다. Claude Code hook input에서 해당 필드가 들어오는 이벤트인지 확인하고, 없을 수 있는 이벤트에서는 안전하게 fallback한다.
- 문서 드리프트 검사는 훅으로 옮기지 않는다. 모든 플랫폼의 `commit-code` skill이 커밋 후 변경 범위를 읽기 전용으로 검사하고, 필요한 문서와 업데이트 개요만 사용자에게 보고한다.
- 차단은 exit code `2` + stderr 또는 JSON decision을 사용할 수 있다. 새로 작성한다면 구조화 JSON을 선호하되, 기존 스크립트가 exit code `2` + stderr 방식으로 잘 동작하면 불필요하게 바꾸지 않는다.
- `PostToolUse`는 이미 실행된 side effect를 되돌리지 않는다. 포매터나 알림 용도로 쓰고, 실패가 agent에 어떻게 보이는지 확인한다.

### Verify

- `hooks/claude/settings.json`이 유효 JSON이고 최상위에 `hooks` 블록이 있는가.
- hook command가 `$HOME/.claude/hooks/...`를 가리키며 `$HOME/.codex`가 남아있지 않은가.
- `SessionStart`가 `$HOME/.claude/hooks/session-context.sh`를 실행하고, `session-context.sh`가 `hookSpecificOutput.additionalContext`를 출력하는가.
- 파일 편집 matcher에 `apply_patch`가 남아있지 않고 `Edit|Write|MultiEdit`를 쓰는가.
- `hooks/claude/hooks/*.sh`가 `bash -n`을 통과하고 실행 권한이 필요한 배포 방식이면 `chmod +x` 되어 있는가.
- 샘플 stdin 스모크 테스트로 차단/통과/추가 컨텍스트 경로가 의도대로 동작하는가.

## Out of scope

- 이 문서는 Claude Code가 Personal 중심이고 Codex가 Work 중심이라는 ownership을 바꾸지 않는다. 양쪽 변형은 상호 공유 가능하지만, 어느 쪽을 소스로 삼을지는 사용자가 선택한 현재 작업 방향이 정한다.
- 이 문서는 설치/배포를 수행하지 않는다. Claude Code 설치는 `scripts/apply-to-claude.sh`가 담당한다.
- Codex 변형의 현재 동작이 Claude Code에 맞지 않으면 그대로 복사하지 말고, 사용자-facing 의미만 보존한 채 Claude Code 실행모델로 재작성한다.
