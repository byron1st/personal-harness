# Migrating Claude Code to Grok Build

이 문서는 **Claude Code → Grok Build** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude → Grok 단방향**이다. Grok 변형의 소스는 항상 Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이고, 대상은 Grok 변형(`skills/grok/`, `agents/grok/`, `hooks/grok/`)이다. Grok에서 시작한 변경은 먼저 Claude 변형에 반영한 뒤 여기로 다시 내려보낸다 — Grok → Claude 역방향 문서는 없다.

**의도적 비호환.** Grok Build는 `[compat.claude]` / `[compat.cursor]`로 다른 하네스 경로를 읽을 수 있다. 이 변형은 **그 경로를 쓰지 않는다.** 설치 후 compat 셀을 모두 `false`로 둔다 (`scripts/apply-to-grok.sh`가 안내). Claude 설정을 “그대로 가져오는” 운용은 범위 밖이다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent `.md`), 훅(hook JSON·스크립트) — 이고, 아래도 그 순서로 나눈다.

## Install prerequisite

1. **`[compat.claude]` · `[compat.cursor]` 전부 끄기** (`skills` · `rules` · `agents` · `mcps` · `hooks` · `sessions`). 켜 두면 `~/.claude/agents` 등이 섞여 frontmatter가 조용히 어긋난다.
2. 전역 지침은 **`~/.grok/rules/AGENTS.md`** (네이티브 rules 로드). SessionStart stdout 주입은 Grok에서 무시된다.
3. 과금은 **SuperGrok subscription 구독 쿼터**다. API 정가 §9 표로 작업 수를 세지 않는다. effort·라운드·200K 경계는 쿼터 효율 레버다.

## Platform invariants (do not translate)

[SYNC_TO_CURSOR.md](SYNC_TO_CURSOR.md) · [SYNC_TO_CODEX.md](SYNC_TO_CODEX.md)와 동일한 불변식 목록이다. 한쪽만 고치지 않는다.

- **공통 반환 섹션명**: `## Stage Status`, `## Evidence`, `## Findings`, `## Decision Needed` 및 스킬별 하위 헤딩.
- **플랜 섹션명**: `## Acceptance Contract`, `## Authority Boundaries`, `## TODOs`, `## Non-goals`, `## Key decisions`.
- **리뷰 섹션명**: `## Accepted Review Exceptions`, `## Applied Exceptions`.
- **상태 어휘**: `pass | blocked | failed | needs-confirmation | needs-decision | changes-required` (+ `pass-with-suspected-defects`) + Grok 전용 **`needs-design-decision`**(depth-1 consultant 에스컬레이션).
- **ID 규칙**: `AC-N`, `AR-NNN`, `TEST-NNN`, `REVIEW-NNN`.
- **스킬·에이전트 이름**: 기존 목록 + `plan-consultant` · `tester` · `fixer` · `dev-loop`(+`-light`/`-noreview`).
- **파일명 규칙** · **AR 불변식** · **루프 상태 기계**: 플랫폼 무관 — 그대로.

## Skill migration

`skills/claude/<skill>` → `skills/grok/<skill>`.

### Frontmatter

Grok 스킬은 `name` · `description` · (선택) `model` · `effort` · `allowed-tools` · `disable-model-invocation` 등을 받는다.

- Claude의 `allowed-tools`에 있던 Claude 툴 이름은 **삭제하거나** Grok 툴명으로 고친다. 1차 변형은 **name+description만 유지**해도 된다.
- 메인 세션 스킬의 `model`/`effort`는 멀티턴에서 세션 습관이 권위이므로 **보통 비운다** (`plan-dev` high · `dev-loop*` medium은 문서 습관).

### Tool names

| Claude | Grok Build |
| --- | --- |
| `Agent` | `spawn_subagent` |
| `AskUserQuestion` | `ask_user_question` |
| `Bash` | `run_terminal_command` |
| `Read` | `read_file` |
| `Edit` / `Write` | `search_replace` |
| `Grep` | `grep` |
| `Glob` | `list_dir` |
| `$HOME/.claude/scripts/…` | **`$HOME/.grok/scripts/…`** |
| `agents/claude/…` | `agents/grok/…` |

### Depth 1 — design-bearing must leave the Worker

Grok은 **탑레벨만** 서브에이전트를 낳는다. `implementer → plan-consultant`는 불가.

- implementer 본문·`implement-flow`·`implement-dev` Dispatcher: Worker는 `status: needs-design-decision`을 반환하고, **메인이** `plan-consultant`를 `capability_mode: read-only`로 spawn한 뒤 implementer를 재dispatch/`resume_from`.
- Claude/Cursor의 “Worker가 consultant를 부른다” 문장을 Grok에 남기지 않는다.

### No multi-model cascade

카탈로그는 `grok-4.6`만 쓴다. `grok-4.5`는 쓰지 않는다. Claude의 “failed → T1 opus 1회” cascade는 **같은 persona 1회 재시도**로 번역하고, 다른 `model:` 패밀리로 올리지 않는다. `implementer-strict` 파일을 만들지 않는다(현행 결정).

### Plan-mode approval

`ExitPlanMode` 등 호스트 전용 exit 툴을 남기지 않는다. 사용자가 plan mode를 벗어나는 것이 승인이다.

### Default loop

**`dev-loop-noreview`** (Claude/Cursor와 같음). Codex의 light 기본을 복사하지 않는다.

## Sub-agent migration

`agents/claude/*.md` → `agents/grok/*.md`. 본문 산문(Reporting contract 등)은 유지.

### Frontmatter

```yaml
---
name: security-reviewer
description: "…(Claude 서술 유지)"
model: grok-4.6       # every role — T1/T2 is effort, see table below
effort: high          # or medium — see agents/AGENTS.md
permission_mode: plan # read-only roles; writers use default
agents_md: true
---
```

| Claude | Grok |
| --- | --- |
| T1 역할(planner · plan-consultant · security/reliability reviewer) | `model: grok-4.6` + `effort: high` |
| T2 쓰기·tester(implementer · fixer · tester) | `model: grok-4.6` + `effort: medium` |
| T2 리뷰어(maintainability · senior-generalist) | `model: grok-4.6` + `effort: medium` |
| `tools: Read, …` (read-only) | `permission_mode: plan` + spawn `capability_mode: read-only` |
| `tools: …, Agent` | 삭제. depth 1이라 Worker는 consultant를 부르지 않음 |
| `inherit` | **금지** |

**Claude의 `model:` 값으로 매핑하지 않는다 — 역할의 티어로 매핑한다.** Claude는 `implementer`·`fixer`를 `opus` / `medium`(T1 모델 + T2 effort)에 두므로, 모델명만 보고 옮기면 두 역할이 T1 effort로 올라간다. `agents/AGENTS.md`의 배치표가 source of truth다.

**4.6 effort 메뉴는 `low` · `medium` · `high` · `xhigh`** (기본 high). `xhigh`는 `plan-dev` 세션에만 쓴다. 에이전트 핀에는 `xhigh`를 넣지 않는다.

**`permission_mode: plan`은 읽기 셸을 막지 않는다** (`git diff`, `rg` 가능). 편집만 막힌다.

### Tier table source of truth

`agents/AGENTS.md`의 **Grok Build** 열. Cursor 열과 모델 배치는 같아도 프론트매터 문법(`model` + `effort` + `permission_mode` vs 접힌 `model` 문자열)이 다르니 섞지 않는다.

## Hook migration

- 스키마: Claude와 같은 **중첩** `hooks.<Event>[].hooks[]` (`type` · `command`).
- 설치: `hooks/grok/hooks.json` → `~/.grok/hooks/harness.json` (Grok은 `~/.grok/hooks/*.json`을 머지).
- 스크립트: `~/.grok/hooks/*.sh`.
- stdin: **camelCase** (`toolName`, `toolInput`, `cwd`, `workspaceRoot`). snake_case 폴백을 두면 Claude 스크립트 이식에 유리.
- matcher 별칭: `Bash`→`run_terminal_command`, `Edit|Write`→`search_replace` — matcher에 둘 다 적거나 스크립트에서 툴명을 검사.
- **SessionStart stdout 무시** — additionalContext 주입 금지. 전역 지침은 rules 파일.
- **SubagentStart 비차단** — Cursor `model-pin-guard`를 이식하지 않는다. 핀 권위 = agent 파일. (선택) `PreToolUse` on `spawn_subagent`는 후순위.

## Install mapping

| 소스 | 대상 |
| --- | --- |
| `skills/grok/*` | `~/.grok/skills/` |
| `agents/grok/*.md` | `~/.grok/agents/` |
| `hooks/grok/hooks/*` | `~/.grok/hooks/` |
| `hooks/grok/hooks.json` | `~/.grok/hooks/harness.json` |
| `instructions/AGENTS.md` | `~/.grok/rules/AGENTS.md` |
| `scripts/runtime/*` | `~/.grok/scripts/` |

설치 스크립트: `scripts/apply-to-grok.sh`.

## Session habits (not files)

| Session | Model / effort |
| --- | --- |
| `plan-dev` | `grok-4.6` / **xhigh** |
| every `dev-loop*` | `grok-4.6` / **medium** |

## Checklist (verifier)

- [ ] compat.claude / compat.cursor off
- [ ] 9 agents under `agents/grok/` with explicit `model` + `effort`, no `inherit` (all `grok-4.6`; T1/T2 is effort)
- [ ] read-only six use `permission_mode: plan`
- [ ] implementer has Dispatcher escalation, not nested consultant
- [ ] 17 skills; scripts path `$HOME/.grok/scripts`
- [ ] no `ExitPlanMode` / Claude Agent tool leftovers
- [ ] hooks harness.json + five scripts; SessionStart does not rely on stdout inject
- [ ] `~/.grok/rules/AGENTS.md` and `~/.grok/scripts/*` install
