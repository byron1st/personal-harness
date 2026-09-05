---
Application: personal-harness
ResearchType: Structure
Description: 네 플랫폼 SKILL.md가 갈라지는 기계적 차이 — 툴 이름, 스크립트 경로, allowed-tools, Dispatcher/Worker, cascade 모델명, Grok depth-1.
---

# Research: 스킬 플랫폼 포크

> Type: Structure

제품 스킬은 네 트리에 **같은 13개 이름**으로 존재한다. 플랫폼 전용 스킬은 없다.

`application-research-sync`, `chat-summary`, `commit-code`, `dev-loop`, `fix-dev`, `implement-dev`, `learn-from-manual-edits`, `loki-log-search`, `plan-dev`, `review-code`, `setup-initial-repo`, `spec-creator`, `test-dev`

경로: `skills/{claude,cursor,codex,grok}/<name>/SKILL.md`. 어떤 스킬에도 `scripts/` 서브트리와 `agents/openai.yaml`은 없다.

레포 메타 스킬 `sync-harness`는 `skills/` 밖이다: `.agents/skills/sync-harness/` 및 `.claude/skills/sync-harness/`. apply가 `~/.claude/skills`로 복사하지 않는다.

## 소환 극성 (현재)

`dev-loop`는 메인 세션 컨트롤러다. 스테이지 스킬의 Dispatcher 흐름을 호출하고, 단계 Worker를 직접 띄우지 않는다 (`skills/claude/dev-loop/SKILL.md` 10, 72–74행 부근).

스테이지 스킬이 spawn을 소유한다.

| 플랫폼 | Dispatch 툴 | 추가 인자 | 폴백 타입 |
| --- | --- | --- | --- |
| Claude | `Agent` + `subagent_type` | 없음 | `general-purpose` |
| Cursor | `Task` + `subagent_type` | 없음 | `generalPurpose` |
| Codex | custom agent spawn | 모든 custom spawn에 `fork_turns="none"` | write: `worker`; read: `explorer` |
| Grok | `spawn_subagent` + `subagent_type` | 리뷰어 `capability_mode: read-only` | `general-purpose` |

`fork_turns`는 `skills/codex/`에만 있다 (plan-dev, implement-dev, test-dev, fix-dev, review-code, implement-flow, worker-contract).

## allowed-tools (Claude 네 스킬만)

```
skills/claude/implement-dev/SKILL.md:4  Bash($HOME/.claude/scripts/detect-commands.sh *)
skills/claude/fix-dev/SKILL.md:4        Bash($HOME/.claude/scripts/detect-commands.sh *)
skills/claude/test-dev/SKILL.md:4       Bash(...detect-commands.sh *) Bash(...resolve-scope.sh *)
skills/claude/review-code/SKILL.md:4    Bash($HOME/.claude/scripts/resolve-scope.sh *)
```

Cursor/Codex/Grok SKILL.md에는 `allowed-tools`가 없다. `hooks/claude/settings.json`은 `"hooks"`만 있고 permissions가 없다. `jq -s '.[0] * .[1]'`로 settings를 병합하면 배열은 교체된다 — allow 목록을 훅 설정에 넣으면 사용자 allow가 날아간다.

## 런타임 스크립트 경로

소비자: implement-dev · test-dev · fix-dev → `detect-commands.sh`. test-dev · review-code → `resolve-scope.sh`.

소스는 `scripts/runtime/` 한곳. 스킬 본문은 플랫폼 홈을 박는다.

- `$HOME/.claude/scripts/…`
- `$HOME/.cursor/scripts/…`
- `$HOME/.codex/scripts/…`
- `$HOME/.grok/scripts/…`

`implement-dev/references/worker-contract.md` 디스패치 프롬프트에도 동일 경로가 있다.

## 질문 / 플랜 승인

| 플랫폼 | 구조화 질문 | 플랜 승인 |
| --- | --- | --- |
| Claude | `AskUserQuestion` | `ExitPlanMode` (`plan-dev` 본문 다수) |
| Cursor | `AskQuestion` | exit 툴 없음. 사용자가 plan mode를 나감 |
| Codex | "ask the user" / `REVIEW-001: fix` 텍스트 | UI 승인. 호스트 exit 툴 호출 금지 |
| Grok | `ask_user_question` | "plan-mode approval을 기다린다. ExitPlanMode를 만들지 마라" |

트리아지 묶음: Claude·Grok `review-code`는 호출당 최대 4문항. Cursor는 "작은 묶음". Codex는 구조화 툴 없음.

## 에이전트 경로 참조

`review-code`가 Reporting contract 위치를 플랫폼 트리로 가리킨다.

- Claude: `agents/claude/*-reviewer.md`
- Cursor: `agents/cursor/*-reviewer.md`
- Codex: `agents/codex/*-reviewer.toml`
- Grok: `agents/grok/*-reviewer.md`

## design-bearing / depth-1

Claude/Cursor `implement-flow.md`: `(design-bearing)` TODO에서 Worker가 `plan-consultant`를 띄운다.

Codex: 같은 뜻 + `fork_turns="none"`.

Grok만 반대다.

- `skills/grok/implement-dev/SKILL.md` 86–106: Worker는 consultant를 띄우지 않고 `needs-design-decision`을 반환. Dispatcher가 `capability_mode: read-only`로 띄운 뒤 implementer를 재개.
- `skills/grok/implement-dev/references/implement-flow.md` 40행: 동일.
- `skills/grok/implement-dev/references/worker-contract.md` 49행: Stage Status에 `needs-design-decision`. 80행: Dispatcher가 consultant를 띄움.
- **내부 모순**: 같은 Grok worker-contract 디스패치 프롬프트는 여전히 "you may dispatch plan-consultant"라고 한다.

`SYNC_TO_GROK.md` 24행은 `needs-design-decision`을 Grok 전용 상태 어휘로 적는다. 공용화 후에는 공통 어휘가 된다.

## failed cascade 모델명

| 플랫폼 | 위치 | 재시도 모델 |
| --- | --- | --- |
| Claude | implement-dev worker-contract §E'; fix-dev | `model: opus` |
| Cursor | 동상 | `model: grok-4.6[effort=high]` |
| Codex | 동상 | `gpt-5.6-sol` + high effort |
| Grok | implement-dev는 모델 패밀리 변경 없음. 같은 implementer 1회 | fix-dev는 그래도 `model: grok-4.6`을 적음 |

## description

Codex description이 짧다 (예: implement-dev "Execute a plan-dev implementation plan with TDD… Use when the user asks to implement a saved plan."). Claude/Cursor/Grok implement-dev description은 Dispatcher/Worker 절차를 포함한다. Codex `dev-loop` description도 이미 짧은 편이다.

## 에이전트 description 결합

`Do not invoke directly`는 claude/cursor/grok의 리뷰어 4종 · tester · fixer description에 있다. planner·implementer에는 없다. Codex TOML description에는 이 문구가 없다.

Claude `tools:`:

- implementer: `Read, Edit, Write, Bash, Grep, Glob, Skill, Agent`
- tester: `Read, Edit, Write, Bash, Grep, Glob, Skill` (Agent 없음)
- fixer: `Read, Edit, Write, Bash, Grep, Glob` (**Skill 없음, Agent 없음**)
- 읽기 전용 6종: `Read, Grep, Glob, Bash`

Cursor는 `tools:`가 없고 부모 툴을 상속한다. Grok은 `permission_mode`. Codex는 `sandbox_mode`.

Claude `plan-consultant` description: implementer가 `(design-bearing)`에서 소환. Grok `plan-consultant`: 메인 세션만 (depth 1).

## 전이표

`skills/claude/dev-loop/references/transitions.md` IMPLEMENTING 행은 `pass` / `blocked` / `failed`만 있다. `needs-design-decision` 행이 없다. 루프가 consultant를 소유하려면 이 표를 고쳐야 한다. LOOP 스테이지 줄 형식은 `{skill}: {Stage Status}` (`loop-state.md`).
