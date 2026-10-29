# Migrating Claude Code to Grok Build

이 문서는 **Claude Code → Grok Build** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude → Grok 단방향**(훅)이다. Grok 변형의 소스는 항상 Claude 훅(`hooks/claude/`)이고, 대상은 `hooks/grok/`이다. 제품 스킬은 공유 트리 `skills/<name>/`이며 변환하지 않는다. Grok에서 시작한 훅 변경은 먼저 Claude 변형에 반영한 뒤 여기로 다시 내려보낸다.

**의도적 비호환.** Grok Build는 `[compat.claude]` / `[compat.cursor]`로 다른 하네스 경로를 읽을 수 있다. 이 변형은 **그 경로를 쓰지 않는다.** 설치 후 compat 셀을 모두 `false`로 둔다 (`scripts/apply-to-grok.sh`가 안내). Claude 설정을 “그대로 가져오는” 운용은 범위 밖이다.

옮기는 대상은 훅(hook JSON·스크립트)이다. 스킬은 공유 트리를 그대로 쓴다.

## Install prerequisite

1. **`[compat.claude]` · `[compat.cursor]` 전부 끄기** (`skills` · `rules` · `agents` · `mcps` · `hooks` · `sessions`). 켜 두면 `~/.claude/skills` 심링크 등이 섞여 같은 이름이 두 번 로드된다.
2. 전역 지침은 **`~/.grok/rules/AGENTS.md`** (네이티브 rules 로드). SessionStart stdout 주입은 Grok에서 무시된다.
3. 과금은 **SuperGrok subscription 구독 쿼터**다. API 정가 §9 표로 작업 수를 세지 않는다. effort·라운드·200K 경계는 쿼터 효율 레버다.

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

- 스키마: Claude와 같은 **중첩** `hooks.<Event>[].hooks[]` (`type` · `command`).
- 설치: `hooks/grok/hooks.json` → `~/.grok/hooks/harness.json` (Grok은 `~/.grok/hooks/*.json`을 머지).
- 스크립트: `~/.grok/hooks/*.sh`.
- stdin: **camelCase** (`toolName`, `toolInput`, `cwd`, `workspaceRoot`). snake_case 폴백을 두면 Claude 스크립트 이식에 유리.
- matcher 별칭: `Bash`→`run_terminal_command`, `Edit|Write`→`search_replace` — matcher에 둘 다 적거나 스크립트에서 툴명을 검사.
- **SessionStart stdout 무시** — additionalContext 주입 금지. 전역 지침은 rules 파일.

## Install mapping

| 소스 | 대상 |
| --- | --- |
| `skills/<name>/` | `~/.agents/skills/<name>/` (harness names only) |
| (harness names) | removed from `~/.grok/skills/` |
| `hooks/grok/hooks/*` | `~/.grok/hooks/` |
| `hooks/grok/hooks.json` | `~/.grok/hooks/harness.json` |
| `instructions/AGENTS.md` | `~/.grok/rules/AGENTS.md` |

설치 스크립트: `scripts/apply-to-grok.sh`.

## Checklist (verifier)

- [ ] compat.claude / compat.cursor off
- [ ] shared `skills/<name>/` only
- [ ] no `ExitPlanMode` / Claude Agent tool leftovers in skills
- [ ] hooks harness.json + five scripts; SessionStart does not rely on stdout inject
- [ ] `~/.grok/rules/AGENTS.md` install
