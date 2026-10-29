# Migrating Claude Code to Codex

이 문서는 **Claude Code → Codex** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**(양방향)다. 이 문서의 소스는 Claude 훅(`hooks/claude/`)이고, 대상은 Codex 훅(`hooks/codex/`)이다. 제품 스킬은 공유 트리 `skills/<name>/`이며 변환하지 않는다. Codex → Claude Code 단계는 [SYNC_TO_CLAUDE.md](SYNC_TO_CLAUDE.md)를 참고한다.

옮기는 대상은 훅이다. 스킬 불변식은 아래 Shared skills 절.

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
