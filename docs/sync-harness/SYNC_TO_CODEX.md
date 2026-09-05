# Migrating Claude Code to Codex

이 문서는 **Claude Code → Codex** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**(양방향)다. 이 문서의 소스는 Claude 에이전트·훅(`agents/claude/`, `hooks/claude/`)이고, 대상은 Codex 에이전트·훅(`agents/codex/`, `hooks/codex/`)이다. 제품 스킬은 공유 트리 `skills/<name>/`이며 변환하지 않는다. Codex → Claude Code 단계는 [SYNC_TO_CLAUDE.md](SYNC_TO_CLAUDE.md)를 참고한다.

옮기는 대상은 서브에이전트와 훅이다. 스킬 불변식은 아래 Shared skills 절.

## Platform invariants (do not translate)

플랫폼 간 파싱·매칭 호환성을 위해 아래 항목은 마이그레이션 시 이름·값을 그대로 보존한다. 도구명·실행모델 변환 규칙이 이 목록보다 우선하지 않는다.

- **공통 반환 섹션명**: `## Stage Status`, `## Evidence`, `## Findings`, `## Decision Needed` — Worker/단계 반환 맨 앞의 공통 블록. 그 아래의 스킬별 헤딩(`## TODO Fulfillment`, `## Suspected` 계열 등 현행 이름)도 개명하지 않는다.
- **플랜 섹션명**: `## Acceptance Contract`, `## Authority Boundaries`, `## TODOs`, `## Non-goals`, `## Key decisions`.
- **리뷰 섹션명**: `## Accepted Review Exceptions`, `## Applied Exceptions`.
- **상태 어휘**: `pass | blocked | failed | needs-confirmation | needs-decision | changes-required | needs-design-decision` (+ test-dev 전용 `pass-with-suspected-defects`). 번역·동의어 치환 금지. `needs-design-decision`은 공통 어휘다.
- **ID 규칙**: `AC-N`, `AR-NNN`, `TEST-NNN`(test Worker가 부여), `REVIEW-NNN`(aggregate 시 메인 세션이 부여 — reviewer 부여 금지).
- **스킬·에이전트 이름**: `plan-dev`, `implement-dev`, `fix-dev`, `test-dev`, `review-code`, `commit-code` (optional PR/MR; `request-merge` is a routing alias), `dev-loop` (modes `light`/`full`/`noreview`); persona `planner`, `implementer`, `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`.
- **파일명 규칙**: `{timestamp}_{Jira}_PLAN|IMPL|LOOP_{title}.md`와 `-STEP-N` 접미 규칙.
- **AR 불변식**: AR 엔트리는 사용자의 명시적 Accept 응답이 있을 때만 기록한다. 어떤 플랫폼 변형에서도 이 규칙을 완화하거나 자동화하는 번역을 하지 않는다.

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
- 루프가 persona를 띄운다. 스킬 본문에 spawn 툴 이름이나 `fork_turns`를 넣지 않는다.
- 배포 스크립트가 personal harness를 Codex agent의 source of truth로 관리한다면 `~/.codex/agents/`를 먼저 정리한 뒤 `agents/codex/*.toml`만 복사한다. 기존 사용자 agent를 보존해야 하는 환경이라면 별도 디렉토리나 프로젝트 범위 `.codex/agents/`를 사용한다.

### Map model and effort pins (required)

Claude frontmatter의 `model` / `effort`는 Codex role TOML의 `model` / `model_reasoning_effort`로 옮긴다. role 파일은 `ConfigToml`을 flatten하므로 두 키를 그대로 추가하면 된다. **`inherit`은 쓰지 않는다** — 티어는 파일 속성이어야 한다.

| Claude | Codex TOML | 비고 |
| --- | --- | --- |
| T1 역할 (planner · plan-consultant · security/reliability reviewer) | `model = "gpt-5.6-sol"` | T1 judgment |
| `implementer` · `fixer` | `model = "gpt-5.6-terra"` | Claude에서 `opus`인 두 T2 쓰기 역할 — Luna 금지 |
| 그 외 T2 | `model = "gpt-5.6-luna"` | tester / T2 reviewers |
| `effort: high` / `medium` / … | `model_reasoning_effort = "high"` 등 | 공통 구간 값 그대로 |
| `tools: Read, Grep, Glob, Bash` | `sandbox_mode = "read-only"` + 본문 hard rule | 툴 화이트리스트는 없음 |
| (없음 — write agent) | `sandbox_mode = "workspace-write"` | implementer / tester / fixer |

**배치 요약 (하네스 기준):**

| 역할 | model | effort |
| --- | --- | --- |
| planner · plan-consultant · security-reviewer · reliability-reviewer | `gpt-5.6-sol` | high (리뷰어 T1은 medium) |
| implementer · fixer | `gpt-5.6-terra` | high |
| tester · maintainability-reviewer · senior-generalist-reviewer | `gpt-5.6-luna` | high |

- **`ultra` 금지.** automatic task delegation을 동반해 dev-loop 위임과 충돌한다.
- **매핑 키는 Claude의 `model:` 값이 아니라 역할의 티어다.** Claude는 `implementer`·`fixer`를 `opus` / `medium`으로 두므로(T1 모델 + T2 effort), `model: opus` → Sol로 기계 변환하면 두 역할이 Sol로 올라간다.
- **Luna를 implementer·fixer에 두지 않는다.** MRCR 장문맥 절벽(41.3%)이 plan+research+코드 입력과 겹친다.
- `failed` 재시도는 루프가 같은 persona를 한 번 더 띄운다. 스킬/루프 본문에 호스트 모델명을 적지 않는다.
- Codex의 `[agents] default_subagent_*`는 **fallback**이다 — role이 명시한 값을 덮어쓰지 않는다. Claude의 `CLAUDE_CODE_SUBAGENT_MODEL`과 다르다.
- 각 본문에 `Tier: T1|T2 — {근거 한 줄}`을 남긴다. 모델명이 아니라 근거가 문서화 대상이다.
- 리뷰어 4종의 `## Reporting contract`는 에이전트 본문(`developer_instructions`)에 둔다. dispatch 프롬프트에 축자 재전달하지 않는다.

### Runtime scripts path

- 소스는 공용 `scripts/runtime/*.sh`다. `apply-to-*.sh`가 `~/.agents/scripts/`로 복사한다.
- 소비 스킬 본문의 호출 경로는 `$HOME/.agents/scripts/detect-commands.sh` · `$HOME/.agents/scripts/resolve-scope.sh` 리터럴이다.

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
