# Migrating Claude Code to Cursor

이 문서는 **Claude Code → Cursor** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude → Cursor 단방향**이다. Cursor 변형의 소스는 항상 Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이고, 대상은 Cursor 변형(`skills/cursor/`, `agents/cursor/`, `hooks/cursor/`)이다. Cursor에서 시작한 변경은 먼저 Claude 변형에 반영한 뒤 여기로 다시 내려보낸다 — Cursor → Claude 역방향 문서는 없다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent 정의 파일), 훅(hook 설정·스크립트) — 이고, 아래도 그 순서로 나눈다.

## Install prerequisite (설치 전제)

**Cursor의 `~/.claude/`·`~/.codex/` 호환 경로를 설정에서 꺼야 한다.** Cursor는 `~/.cursor/agents/`·`~/.cursor/skills/`뿐 아니라 `~/.claude/agents/`·`~/.claude/skills/`도 사용자 스코프로 읽는다. 두 플랫폼을 같은 머신에 설치하면 Cursor에게 같은 이름의 에이전트 9개·스킬 17개가 두 벌씩 보인다.

`~/.cursor/`가 우선하므로 정상 상태에서는 문제가 없지만, **호환 경로 끄기는 UI 설정이라 설치 스크립트가 보장할 수 없다.** 새 머신·재설치·설정 초기화 때 되살아나고, 되살아나도 에러가 나지 않는다. Claude 판이 채택되면:

- `tools:`는 Cursor 필드가 아니므로 무시된다 → **리뷰어 4종이 쓰기 권한을 얻는다.**
- `effort:`도 무시된다.
- `model: sonnet`을 Cursor가 어떻게 해석하는지 불명이다.

셋 다 조용히 일어난다. 감지 장치는 `hooks/cursor/hooks/model-pin-guard.sh` 하나뿐이며, T1 에이전트의 해석된 모델이 `grok-4.6` 계열이 아니게 되는 것으로 첫 라운드에 잡는다.

## Platform invariants (do not translate)

플랫폼 간 파싱·매칭 호환성을 위해 아래 항목은 마이그레이션 시 이름·값을 그대로 보존한다. 도구명·실행모델 변환 규칙이 이 목록보다 우선하지 않는다. **[SYNC_TO_CODEX.md](SYNC_TO_CODEX.md)의 Platform invariants 목록과 동일하며, 한쪽만 고치지 않는다.**

- **공통 반환 섹션명**: `## Stage Status`, `## Evidence`, `## Findings`, `## Decision Needed` — Worker/단계 반환 맨 앞의 공통 블록. 그 아래의 스킬별 헤딩(`## TODO Fulfillment`, `## Suspected` 계열 등 현행 이름)도 개명하지 않는다.
- **플랜 섹션명**: `## Acceptance Contract`, `## Authority Boundaries`, `## TODOs`, `## Non-goals`, `## Key decisions`.
- **리뷰 섹션명**: `## Accepted Review Exceptions`, `## Applied Exceptions`.
- **상태 어휘**: `pass | blocked | failed | needs-confirmation | needs-decision | changes-required` (+ test-dev 전용 `pass-with-suspected-defects`). 번역·동의어 치환 금지.
- **ID 규칙**: `AC-N`, `AR-NNN`, `TEST-NNN`(test Worker가 부여), `REVIEW-NNN`(aggregate 시 메인 세션이 부여 — reviewer 부여 금지).
- **스킬·에이전트 이름**: `plan-dev`, `implement-dev`, `fix-dev`, `test-dev`, `review-code`, `commit-code`, `request-merge`, `dev-loop`(+`-light`/`-noreview`); persona `planner`, `plan-consultant`, `implementer`, `tester`, `fixer`, `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`.
- **파일명 규칙**: `{timestamp}_{Jira}_PLAN|IMPL|LOOP_{title}.md`와 `-STEP-N` 접미 규칙.
- **AR 불변식**: AR 엔트리는 사용자의 명시적 Accept 응답이 있을 때만 기록한다. 어떤 플랫폼 변형에서도 이 규칙을 완화하거나 자동화하는 번역을 하지 않는다.
- **루프 상태 기계**: 세 루프 변형의 전이표·종료 술어·휴먼 게이트(TESTING Fix/Accept, READY_TO_COMMIT)는 플랫폼 무관이다. 그대로 옮긴다.

## Skill migration

`skills/claude/<skill>`를 `skills/cursor/<skill>`로 옮길 때의 규칙이다.

### Reduce frontmatter to name + description

Cursor 스킬 프론트매터가 받는 키는 `name`(부모 폴더명과 일치) · `description` · `paths` · `disable-model-invocation` · `metadata`뿐이다.

- **`allowed-tools`를 삭제한다.** Cursor에는 스킬 단위 권한 프리어프루브가 없다. 런타임 스크립트 호출 시 권한 프롬프트가 뜰 수 있으나 무해한 실패 모드이므로 수용한다.
- `model` · `effort` · `context: fork`는 Claude 스킬에도 없으므로 삭제 대상이 아니다. 새로 추가하지도 않는다.
- **`paths`와 `disable-model-invocation`은 쓰지 않는다.** Claude 판에 대응물이 없어 두 변형이 갈라진다. 도입하려면 먼저 Claude 판에서 결정한다.

### Replace Claude tool names with Cursor tool names

인자 이름이 같으므로 **툴 이름만 치환**하면 된다. 텍스트 프로토콜로 후퇴하지 않는다 — Cursor에는 두 휴먼 게이트를 Claude와 같은 강제력으로 구현할 도구가 있다.

| Claude | Cursor | 비고 |
| --- | --- | --- |
| `Agent(subagent_type: …, prompt: …)` | `Task(subagent_type: …, prompt: …)` | 인자 이름 동일 |
| `AskUserQuestion` | `AskQuestion` | 구조화 질문 도구. 트리아지·Fix/Accept 분류가 여기에 의존한다 |
| `general-purpose` (fallback subagent) | `generalPurpose` | Cursor 빌트인 서브에이전트 타입 |
| `Read` / `Grep` / `Glob` / `Bash` / `Edit` / `Write` | 기능 중심 표현 | "파일을 읽고", "검색해서", "셸에서" |
| `$HOME/.claude/scripts/…` | `$HOME/.cursor/scripts/…` | 설치 대상 경로 |
| `agents/claude/…` | `agents/cursor/…` | 문서 내 경로 참조 |

`${CLAUDE_SKILL_DIR}` 같은 치환 변수는 Cursor에 없다. `scripts/` · `references/` · `assets/`는 **스킬 루트 기준 상대 경로**로 참조한다.

**`AskQuestion`의 문항 수 상한을 Claude 값(4개)으로 옮기지 않는다.** Claude의 `AskUserQuestion` 제약이며 Cursor 문서에 대응 수치가 없다. "작은 묶음으로 나눠 묻는다" 수준으로 완화해 적는다.

### Translate the cascade's model escalation

3-fail cascade는 T1으로 1회 재시도한다. Cursor의 task 요청도 호출 시점 `model` 인자를 받으므로 이 장치는 살아남는다 — **값만 바꾼다.**

- `model: opus` → `model: grok-4.6[effort=high]`
- 상한(1회)·"세 번째 시도 금지"·"메인 세션 폴백 금지"는 그대로.

### Use Cursor plan-mode approval, not host-specific exit tools

Claude Code에는 에이전트가 호출하는 plan-mode exit tool(`ExitPlanMode`)이 있지만 **Cursor에는 대응물이 없다.** 승인은 사용자가 대화를 plan mode 밖으로 옮기는 행위다.

- 계획 단계에서는 read-only 행동만 수행한다.
- 최종 계획을 제시하고 **멈춘다.** `ExitPlanMode` 호출을 Cursor용 스킬에 남기지 않는다.
- **에이전트가 대화 내용을 자기 판단으로 읽어 "승인됐다"고 간주하지 않도록** 본문에 명시한다. 호출할 도구가 없다는 것은 승인 신호도 명시적이지 않다는 뜻이므로, Claude 판보다 이 문장이 더 중요하다.
- 승인 후 첫 write는 스킬이 요구하는 persistence 작업이어야 한다.

### Keep the delegation failure gate

Dispatcher-first + 명시적 실패 게이트는 플랫폼 무관 규칙이므로 그대로 옮긴다. dispatch가 실패하면 substantive 작업을 시작하지 않고, `Delegation status: unavailable | failed`와 관찰된 원인을 보고하고, direct fallback은 사용자가 명시적으로 선택한 뒤에만 시작한다.

### Mind the nesting limit

메인 에이전트와 그 직속 서브에이전트는 자식을 낳을 수 있지만, **서브에이전트가 낳은 서브에이전트는 더 낳지 못한다.** 하네스는 main(Dispatcher) → Worker(L1) → `plan-consultant`(L2)로 **한도를 정확히 다 쓴다.**

- Worker 아래에 새 위임 계층을 추가하는 스킬 변경은 Cursor에서 성립하지 않는다. 그런 변경은 Claude 판에서부터 다시 설계한다.

## Sub-agent migration

`agents/claude/*.md`를 `agents/cursor/*.md`로 옮길 때의 규칙이다. **본문은 플랫폼 무관한 산문이므로 그대로 간다.** 리뷰어 4종의 `## Reporting contract`, `implementer`의 3-bucket + 4번째 밴드, `tester`의 test-code-only 규칙 전부 해당한다.

### Fold model + effort into a single model string

Cursor 서브에이전트 프론트매터는 `name` · `description` · `model` · `readonly` · `is_background` **다섯 개가 전부**다. `tools:`도 `effort:`도 없다.

```yaml
---
name: security-reviewer
description: "…(Claude 판 그대로)"
model: grok-4.6[effort=high]
readonly: true
---
```

`model` 문자열의 파라미터 문법: `composer-2.5[]` · `composer-2.5[fast=false]` · `grok-4.6[effort=high]` · `claude-opus-5[effort=high,context=300k]`.

**`[fast=false]`를 Composer 전 행에 반드시 붙인다.** 빠뜨리면 조용히 Fast로 돌아간다 — 지능은 같은데 약 6배 비싸고, **T1인 Grok보다도 비싸서 티어가 역전되며**, first-party 풀을 3.6배 빨리 태운다. Cursor 변형에서 가장 자주·가장 조용히 틀릴 수 있는 한 토큰이다.

**`[context=300k]`는 쓰지 않는다.** Grok은 200K 프롬프트 토큰을 넘기면 요청 **전체**가 2배 요금이 되므로, 컨텍스트를 키우는 파라미터는 정확히 반대 방향이다.

**effort 값을 Claude에서 그대로 옮기지 않는다.** Grok 4.6은 `low/medium/high/xhigh`이고 기본값이 `high`다. T1 리뷰어는 `high`(예약된 `xhigh` 바로 아래). Composer는 effort를 받지 않으므로 그 자리에 `[fast=false]`가 들어간다.

현행 배치는 `AGENTS.md`의 Model Tier 절이 source of truth다. 표를 고치면 `hooks/cursor/hooks/model-pin-guard.sh`의 `case` 문도 함께 고친다 — **두 곳이 갈라지면 가드가 정상 dispatch를 거부한다.**

### Convert `tools:` to `readonly:` and record the loss

Claude의 `tools: Read, Grep, Glob, Bash`는 Cursor에서 `readonly: true` 하나로 축약된다. Cursor 서브에이전트는 **MCP 툴을 포함해 부모의 모든 툴을 상속**하고, 제한 수단은 이 불리언뿐이다.

- **읽기 전용 6개 에이전트(리뷰어 4종 · `planner` · `plan-consultant`)에 `readonly: true`를 빠짐없이 넣는다.** 아무것도 안 쓰면 모든 에이전트가 모든 툴을 갖는다 — Claude와 반대 방향의 위험이다.
- **정보 손실을 본문에 주석으로 남긴다**: read-only가 `readonly` 불리언으로만 강제되며 툴 화이트리스트는 존재하지 않는다는 한 줄.
- `readonly`는 **파일시스템 write/edit만 막고 읽기 셸은 통과시킨다.** `git diff`·`rg`는 정상이므로 리뷰어의 조사 능력은 손상되지 않는다.
- 반대로 **명시적 허용은 불필요해진다.** Claude에서 `implementer.md`의 `tools:`에 `Agent`를 추가해야 했던 문제가 Cursor에는 없다.

### Leave `is_background` at its default

전부 `false`(기본값)로 둔다. Dispatcher/Worker 패턴은 Worker의 반환을 기다려야 성립한다. 명시적 선언은 불필요하지만, `implementer`·`tester`처럼 오래 도는 에이전트에는 **나중에 누군가 `true`를 붙이지 않도록 본문에 이유를 한 줄 남긴다.**

### Keep the reporting contract in the agent body

리뷰어 4종의 `## Reporting contract`는 dispatch 프롬프트가 아니라 에이전트 본문에 있다. **Cursor에서 이득이 더 크다** — 서브에이전트가 부모 툴을 전부 상속해 dispatch 프롬프트가 길어지기 쉽기 때문이다. 되돌리지 않는다.

## Hook migration

`hooks/claude/`를 `hooks/cursor/`로 옮길 때의 규칙이다.

### Rewrite hooks.json against the flat schema

**스키마가 Claude와 다르다.** 중첩 `hooks[].hooks[].type`이 아니라 평평한 배열이다.

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [{ "command": "$HOME/.cursor/hooks/session-context.sh" }],
    "preToolUse":   [{ "command": "…", "matcher": "…" }]
  }
}
```

> **`hooks/codex/hooks.json`을 본뜨지 말 것.** 그 파일은 Claude의 중첩 스키마를 경로만 바꿔 복사한 형태다. Codex 판의 정확성은 이 문서의 범위가 아니지만, 참고 대상으로 삼으면 안 된다.

이벤트 이름은 lowerCamelCase다: `sessionStart` · `preToolUse` · `afterFileEdit` · `subagentStart`. Claude의 `SessionStart` · `PreToolUse` · `PostToolUse`와 대소문자부터 다르다.

### Port the three blocking hooks with a tool_name guard

`enforce-rg.sh` · `enforce-fd.sh` · `git-identity-guard.sh`는 **jq 경로까지 무수정**이다. Cursor의 `preToolUse`도 `tool_name` · `tool_input.command` · `cwd`를 준다. 두 가지만 바꾼다:

1. **맨 앞에 tool 가드 한 줄.** `matcher`는 `preToolUse`에서는 tool 이름을, 다른 이벤트에서는 명령 문자열을 대상으로 하므로, 스크립트 안에서 검사하면 이 모호함이 사라진다.
   ```bash
   [[ "$(echo "$input" | jq -r '.tool_name // ""')" == "Shell" ]] || exit 0
   ```
2. **`exit 2` → `{"permission":"deny","agent_message":…}` stdout.** 둘 다 차단하지만, 에이전트에게 메시지가 전달되는 것이 문서화된 쪽은 JSON이다. 기존 heredoc 메시지를 `agent_message`에 담고 `user_message`에 한 줄 요약을 넣는다.

### Fix the two hooks that lose `cwd`

| 스크립트 | 이벤트 | 변경 |
| --- | --- | --- |
| `session-context.sh` | `sessionStart` | `.cwd` → `.workspace_roots[0]` (sessionStart에는 `cwd`가 없다), 출력 `{hookSpecificOutput:{…additionalContext}}` → **`{additional_context: …}`** |
| `auto-format.sh` | `afterFileEdit` | `.cwd` → `.workspace_roots[0]`. **`exit 2`를 쓰지 않는다** — `afterFileEdit`은 출력 계약이 없어 `exit 2`의 의미가 Claude와 다르다. 실패는 로그에 남기고 조용히 통과시킨다 |

### Inject global instructions through sessionStart

**Cursor에는 사용자 전역 지침 파일이 없다.** `~/.claude/CLAUDE.md`·`~/.codex/AGENTS.md`에 해당하는 경로가 문서에 없고, User Rules는 설정 UI 상태라 설치 스크립트가 쓸 수 없다.

→ `apply-to-cursor.sh`가 `instructions/AGENTS.md`를 `~/.cursor/AGENTS.md`로 복사하고, **`session-context.sh`가 그 파일을 읽어 저장소 분류 컨텍스트 뒤에 이어 붙여 하나의 `additional_context`로 낸다.** Cursor가 그 경로를 읽지는 않지만 훅이 읽어서 넣어주므로 상관없다.

프로젝트별 `.cursor/rules/*.mdc` 생성은 **하지 않는다** — 전역이 아니고 남의 저장소를 오염시킨다.

### Keep model-pin-guard.sh in sync with the tier table

`model-pin-guard.sh`는 **Claude 변형에 대응물이 없는 Cursor 전용 훅**이다. Cursor의 모델 핀은 보장이 아니라서(관리자 제한·플랜 제약·알 수 없는 모델 ID 셋 중 하나면 조용히 폴백) `subagentStart`가 해석된 모델을 볼 수 있는 유일한 지점이다.

- **T1은 거부, T2는 로그 후 허용.** `subagentStart`의 출력은 `allow`/`deny` 둘뿐이라 "경고"가 없다. 전부 거부하면 폴백 한 번에 루프가 멈춘다.
- **비교는 base 모델 ID로 한다.** `subagent_model`은 해석된 모델(`grok-4.6`)을 주고 `[effort=…]` 파라미터는 돌아오지 않는다. 전체 문자열을 비교하면 매 dispatch마다 발화한다.
- **모르는 `subagent_type`은 항상 허용한다.** Cursor 빌트인(`generalPurpose`·`explore`·`shell`)과 하네스 소유가 아닌 에이전트를 막지 않기 위해서다.
- 에이전트 배치를 바꾸면 이 스크립트의 `case` 문과 `AGENTS.md` Model Tier 표를 **함께** 고친다.

**이 훅은 단계 전이를 결정하지 않는다.** *"Hooks are guardrails; they take no part in `dev-loop` stage transitions or completion decisions"* 불변식과 충돌하지 않으며, 잘못된 모델로의 실행을 거부할 뿐이다.

### Hooks remain guardrails

Codex 판과 같은 원칙이다. 루프 불변식(커밋·푸시·PR 금지, AR은 명시적 Accept 시에만, 테스트 약화 금지, 예산 초과 금지)은 **SKILL 본문 규칙으로만 보장한다.** 훅으로 강제한다고 가정하지 않는다.

## Out of scope

| 항목 | 판단 |
| --- | --- |
| `.cursor/rules/*.mdc` 생성 | 하지 않는다. 전역이 아니고 남의 저장소를 오염시킨다 |
| `disable-model-invocation` 도입 | 이번 범위 밖. Claude 판과 차이를 만드는 결정이라 별도로 다룬다 |
| `paths` 프론트매터로 스킬 스코핑 | 하지 않는다. Claude 판에 대응물이 없어 두 변형이 갈라진다 |
| Cursor CLI(`cursor-agent`) 대응 | 범위 밖. 이 문서는 IDE Agent 채팅을 전제한다 |
| `context=300k` 파라미터 | 하지 않는다. 200K 임계를 넘기면 요청 전체가 2배다 |
| `is_background: true` | 하지 않는다. Dispatcher/Worker가 반환을 기다려야 한다 |
