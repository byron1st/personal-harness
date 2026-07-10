# Migrating Codex to Claude Code

이 문서는 **Codex → Claude Code** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, Work 중심인 Codex 변형의 변경을 Personal 중심인 Claude Code 변형으로 공유할 때 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**다. Personal 환경의 중심은 Claude Code이고 Work 환경의 중심은 Codex이므로, Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. 이 문서는 Codex 변형을 소스로 삼아 Claude Code 변형을 갱신하는 공식 경로다.

이 문서의 소스는 Codex 변형(`skills/codex/`, `agents/codex/`, `hooks/codex/`)이고, 대상은 Claude Code 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이다. repo-scoped Codex skill인 `.agents/skills/<skill>`을 소스로 지정받은 경우에도 아래 Skill migration 규칙을 적용하되, 대상은 사용자가 지정한 Claude Code skill 위치(일반적으로 `.claude/skills/<skill>` 또는 `skills/claude/<skill>`)로 둔다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent 정의 파일), 훅(hook 설정·스크립트) — 이고, 아래도 그 순서로 나눈다.

## Skill migration

`skills/codex/<skill>`를 `skills/claude/<skill>`로 옮길 때의 규칙이다.

### Start from the Codex behavior, then restore Claude Code mechanics

- 먼저 Codex 변형이 실제로 바꾼 사용자-facing 의미를 식별한다. 단순히 Claude 원본을 다시 복사하면 Codex에서 추가된 동작·문구·검증 규칙을 잃을 수 있다.
- 트리 구조, 파일명, `references/`·`scripts/` 경로, frontmatter `name`은 기본적으로 유지한다. `references/`와 `scripts/`가 host-neutral하면 그대로 복사한다.
- skill-local `agents/openai.yaml`은 Codex/OpenAI UI 메타데이터이며 Claude Code custom subagent 정의가 아니다. Codex 소스에 이 파일이 있어도 `skills/claude/<skill>/agents/openai.yaml`로 복사하지 말고, Claude 대상 스킬에는 필요한 `SKILL.md`, host-neutral `references/`, `scripts/`만 둔다.
- Claude Code 변형에서는 Codex 실행모델을 설명하는 문장을 Claude Code 실행모델로 바꾼다. 예: Codex `sandbox and approval policy`, `worker`, `explorer`, `/permissions`는 Claude Code의 permission mode, `Agent` tool, `subagent_type`, `ExitPlanMode`, `AskUserQuestion` 등으로 바꾼다.
- host-neutral skill은 거의 그대로 옮긴다. 위임(subagent), plan mode, hook/tool 이름, 권한 모델, Codex 전용 위치(`.agents/skills`, `~/.codex`)가 없으면 차이를 만들지 않는다.

### Expand descriptions only when Claude Code benefits from it

Codex는 시작 시 skill `name`, `description`, 경로만 예산 제한 안에서 먼저 보므로 description을 짧게 유지한다. Claude Code도 skill description을 자동 선택에 사용하지만, 이 harness의 Claude 변형은 더 긴 trigger 예시와 workflow 설명을 담아온 경우가 있다.

- Codex의 짧은 description을 그대로 써도 trigger가 충분하면 늘리지 않는다.
- Claude Code가 자동 skill 선택이나 subagent dispatch에 쓸 단서가 부족하면, 사용자가 말할 법한 트리거·대상 범위·금지 범위를 한 문단 안에서 보강한다.
- 구현 세부 절차를 frontmatter description에 과하게 넣지 않는다. 긴 절차는 본문이나 `references/`에 둔다.
- `name`은 디렉터리명과 일치시키고, YAML frontmatter가 파싱되는지 확인한다. 값에 `: `(콜론+공백)가 있으면 따옴표로 감싼다.

### Restore Claude Code subagent dispatch where the skill expects delegation

Codex는 명시적 요청이 있을 때만 subagent를 spawn한다. Claude Code는 custom subagent description과 작업 문맥을 보고 더 적극적으로 위임할 수 있고, skill 본문도 `Agent` tool dispatch를 직접 전제로 작성할 수 있다.

- Codex 변형에 "use subagents only when explicitly requested" 정책이 들어간 이유를 먼저 확인한다. 그 문장이 Codex 제품 제약 때문에 추가된 것이라면 Claude Code 변형에서는 제거하거나 완화한다.
- Claude Code 원래 workflow가 항상 병렬 reviewer agent를 dispatch하는 구조라면, Codex의 main-session fallback 문장을 제거하고 `Agent` tool 병렬 dispatch 흐름을 복원한다.
- 그래도 사용자가 명시적으로 "main session only", "no subagents" 같은 제한을 둔 경우에는 그 지시가 우선한다는 문장을 남길 수 있다.
- `Codex custom agent` 표현은 Claude Code의 `custom subagent` 또는 `reviewer agent`로 바꾼다. dispatch 절차를 써야 하면 `Agent` tool과 `subagent_type`을 명시한다.
- Codex `worker`는 보통 Claude Code의 범용 subagent dispatch로 바꾸고, Codex `explorer` fallback은 Claude Code에서 사용할 수 있는 읽기 중심 subagent나 custom agent prompt로 바꾼다. 이 repo의 reviewer persona는 세 플랫폼에서 같은 이름(`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`)을 유지한다.

### Convert plan-mode instructions to Claude Code plan mode

Codex plan mode는 UI/CLI의 approval flow를 통해 write-capable 단계로 넘어간다. Claude Code에는 plan mode 종료 시 agent가 호출하는 `ExitPlanMode` 도구가 있다.

- "Codex plan mode"는 "Claude Code plan mode"로 바꾸고, 계획 단계는 read-only라는 원칙은 유지한다.
- "Codex approval flow를 기다린다"는 문장은 최종 계획을 제시한 뒤 `ExitPlanMode`로 사용자 승인을 받는 흐름으로 바꾼다.
- 승인 후 첫 write가 Obsidian plan/report 저장 같은 persistence여야 한다는 스킬 정책은 유지한다.
- Codex 전용 `/plan`, `/permissions`, sandbox override 표현은 Claude Code의 plan mode, permission mode, `ExitPlanMode` 표현으로 바꾼다.

### Replace Codex-safe generic wording with Claude Code tool names only when useful

Codex 변형은 호스트 독립성을 위해 "read files", "search", "ask the user"처럼 기능 중심 표현을 쓰는 경우가 많다. Claude Code 변형은 필요할 때 `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `MultiEdit`, `AskUserQuestion`, `ExitPlanMode`, `Agent` 같은 도구명을 직접 써도 된다.

- 도구명이 workflow 이해에 직접 도움이 되면 Claude Code 도구명으로 되돌린다. 예: "ask the user" → `AskUserQuestion`, "dispatch custom agents" → `Agent` tool with `subagent_type`, "exit plan mode" → `ExitPlanMode`.
- 단순한 작업 지시는 기능 중심 표현으로 남겨도 된다. 예: `rg`로 검색하라는 repo 규칙은 Codex/Claude 모두에서 유효하므로 그대로 둔다.
- Codex의 `apply_patch` 표현은 Claude Code 편집 도구명으로 바꾼다. hook matcher나 도구 allowlist에서는 `Edit|Write|MultiEdit`를 기준으로 생각한다.
- 전역 지시 파일은 Claude Code가 읽는 `CLAUDE.md`를 우선하되, cross-agent repo에서는 `AGENTS.md`도 함께 확인하도록 둔다.

### Re-check permissions and tool assumptions

Codex는 sandbox mode와 approval policy를 중심으로 권한을 설명한다. Claude Code는 settings, permission mode, tool allowlist, subagent frontmatter의 `tools` 등으로 권한과 도구 접근을 표현한다.

- Codex `sandbox_mode = "read-only"`나 read-only agent 의미는 Claude Code에서 `tools:` allowlist와 본문 hard rule로 옮긴다. 이 repo의 reviewer agent는 `tools: Read, Grep, Glob, Bash`와 "Read-only. No edits. No commits." 규칙을 함께 둔다.
- Codex subagent가 parent sandbox를 상속한다는 설명은 Claude Code subagent frontmatter와 settings가 적용된다는 설명으로 바꾼다. 단, delegated agent가 별도 독립 권한을 가진다고 과장하지 않는다.
- Claude Code의 `allowed-tools`, permission mode, hooks 전제가 필요한 경우에만 복원한다. 모든 skill에 tool allowlist를 새로 추가하지 않는다.
- MCP나 external tool 사용은 플랫폼마다 다를 수 있으므로, Codex MCP 명칭이나 현재 세션 전용 tool 이름을 Claude Code skill에 그대로 남기지 않는다.

### Verify

- 트리 패리티: 대상 skill에 `SKILL.md`가 있고, host-neutral `references/`·`scripts/` 트리가 Codex 소스와 동일한가.
- skill-local `agents/openai.yaml`이 Claude 대상에 복사되지 않았는가. Claude custom subagent는 repo-level `agents/claude/*.md`로만 관리한다.
- frontmatter `name`이 디렉터리명과 일치하고 YAML이 파싱되는가.
- 잔존 스윕(`rg`): `Codex`, `worker`, `explorer`, `sandbox and approval`, `apply_patch`, `.agents/skills`, `~/.codex`, `ExitPlanMode` 누락, `AskUserQuestion` 누락이 문맥상 의도된 것인지 확인한다. `Codex`가 제품명 예시로 필요한 경우만 허용한다.
- 위임형 skill은 Claude Code에서 `Agent` tool / `subagent_type` 흐름이 자연스럽고, Codex 전용 "explicit user request only" fallback이 불필요하게 남아있지 않은가.
- plan-mode skill은 최종 계획 후 `ExitPlanMode`로 승인받는 흐름을 갖는가.

## Sub-agent migration

`agents/codex/*.toml`를 `agents/claude/*.md`로 옮길 때의 규칙이다.

### Convert Codex TOML agents to Claude Code Markdown agents

Codex custom agent는 standalone TOML이고, Claude Code custom subagent는 Markdown 파일의 YAML frontmatter와 본문으로 정의한다.

- Codex agent 소스는 `agents/codex/<name>.toml`, Claude Code 대상은 `agents/claude/<name>.md`다.
- 설치 대상은 개인 전역 agent면 `~/.claude/agents/`, 프로젝트 범위 agent면 `.claude/agents/`다. personal harness에서는 `scripts/apply-to-personal.sh`가 `agents/claude/*`를 `~/.claude/agents/`로 동기화한다.
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
- personal harness에서는 `scripts/apply-to-personal.sh`가 `hooks/claude/hooks/*`를 `~/.claude/hooks/`로 동기화하고, `hooks/claude/settings.json`을 `~/.claude/settings.json`에 merge한다.

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
- 이 문서는 설치/배포를 수행하지 않는다. Claude Code 설치는 `scripts/apply-to-personal.sh`가 담당한다.
- Codex 변형의 현재 동작이 Claude Code에 맞지 않으면 그대로 복사하지 말고, 사용자-facing 의미만 보존한 채 Claude Code 실행모델로 재작성한다.
