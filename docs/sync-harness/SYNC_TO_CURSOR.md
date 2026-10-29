# Migrating Claude Code to Cursor

이 문서는 **Claude Code → Cursor** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude → Cursor 단방향**(훅)이다. Cursor 변형의 소스는 항상 Claude 훅(`hooks/claude/`)이고, 대상은 `hooks/cursor/`이다. 제품 스킬은 공유 트리 `skills/<name>/`이며 변환하지 않는다. Cursor에서 시작한 훅 변경은 먼저 Claude 변형에 반영한 뒤 여기로 다시 내려보낸다.

옮기는 대상은 훅이다. 스킬 불변식은 아래 Shared skills 절.

## Install prerequisite (설치 전제)

**Cursor의 `~/.claude/`·`~/.codex/` 호환 경로를 설정에서 꺼야 한다.** Cursor는 네이티브로 `~/.agents/skills`를 읽고, 호환이 켜지면 Claude 스킬 단위 심링크까지 더 읽는다. 같은 이름이 두 번 로드된다.

**호환 경로 끄기는 UI 설정이라 설치 스크립트가 보장할 수 없다.** 새 머신·재설치·설정 초기화 때 되살아나고, 되살아나도 에러가 나지 않는다.

## Shared skills

제품 스킬은 `skills/<name>/` 한 트리만 쓴다. `skills/{claude,codex,cursor,grok}/`를 만들지 않는다. 스킬은 플랫폼 변환 대상이 아니다. 훅만 이 문서의 나머지 절을 따른다.

불변식 (스킬 본문·references):

- frontmatter는 `name` + `description`만. `allowed-tools` 금지.
- description은 한두 문장, 대략 300자, 첫 문장에 trigger. Dispatcher/Worker 절차를 description에 넣지 않는다.
- 호스트 툴 이름 금지: `Agent`, `Task`, `spawn_subagent`, `AskUserQuestion`, `AskQuestion`, `ask_user_question`, `ExitPlanMode`, `fork_turns`, `subagent_type`.
- 질문은 "사용자에게 물어라". 객관식이면 선택지와 미응답=미분류만 적는다.

설치: `~/.agents/skills`가 유일 설치본. Claude만 스킬 단위 심링크 `~/.claude/skills/<name> → ~/.agents/skills/<name>`. Cursor/Codex/Grok 플랫폼 스킬 디렉터리에서 harness 이름은 제거한다.
Cursor/Grok Claude-compat 스킬 스캔은 끈 채로 `~/.agents/skills`를 쓴다.

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

이벤트 이름은 lowerCamelCase다: `sessionStart` · `preToolUse` · `afterFileEdit`. Claude의 `SessionStart` · `PreToolUse` · `PostToolUse`와 대소문자부터 다르다.

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

### Hooks remain guardrails

Codex 판과 같은 원칙이다. 테스트 약화 금지 같은 작업 규칙은 **전역 지침으로만 보장한다.** 훅으로 강제한다고 가정하지 않는다.

## Out of scope

| 항목 | 판단 |
| --- | --- |
| `.cursor/rules/*.mdc` 생성 | 하지 않는다. 전역이 아니고 남의 저장소를 오염시킨다 |
| `disable-model-invocation` 도입 | 이번 범위 밖. Claude 판과 차이를 만드는 결정이라 별도로 다룬다 |
| `paths` 프론트매터로 스킬 스코핑 | 하지 않는다. Claude 판에 대응물이 없어 두 변형이 갈라진다 |
| Cursor CLI(`cursor-agent`) 대응 | 범위 밖. 이 문서는 IDE Agent 채팅을 전제한다 |
