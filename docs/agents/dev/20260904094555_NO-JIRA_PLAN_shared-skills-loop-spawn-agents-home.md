---
Application: personal-harness
JiraTicket: NO-JIRA
PlanType: single-step
Timestamp: 20260904094555
Title: shared-skills-loop-spawn-agents-home
---

# 공용 스킬 + 루프 소환 + ~/.agents/skills

한 세트의 SKILL.md를 네 호스트가 같이 읽고, 소환은 루프가 하며, 설치 위치는 `~/.agents/skills`다. Claude만 스킬 단위 심링크로 붙인다.

## 참고 Research

구현 세션은 해당 TODO 전에 아래 파일을 읽는다.

- [skill-platform-forks](../research/skill-platform-forks.md) — 지금 네 벌 SKILL.md가 갈라지는 기계적 차이(툴 이름, 스크립트 경로, `allowed-tools`, Dispatcher/Worker, cascade 모델명, Grok depth-1). **TODO 1·2·3**
- [skill-install-discovery](../research/skill-install-discovery.md) — `apply-to-*.sh`가 무엇을 비우고 어디에 복사하는지, 각 호스트가 `~/.agents/skills`를 읽는지, `verify-sync.py`가 스킬 트리를 어떻게 검사하는지. **TODO 4·5·6**

## 목표

`personal-harness`의 13개 제품 스킬을 플랫폼 방언이 아닌 **방법론**으로 만들고, `dev-loop`가 단계마다 persona를 띄우게 뒤집고, 설치본은 `~/.agents/skills` 한곳만 관리한다.

## 세 레이어

| 레이어 | 소유 | 하지 않는 것 |
| --- | --- | --- |
| **스킬** (`skills/<name>/`) | How — TDD, 3-phase test, finding 형식, AC 증거, AR, 반환 헤딩 | 누구를 띄울지, `Agent`/`Task`/`spawn_subagent`, `AskUserQuestion`/`AskQuestion` |
| **에이전트** (`agents/<platform>/`) | Who — 페르소나, 모델 핀, 읽기/쓰기 | 다음 단계, 루프 전이 |
| **dev-loop** | When — 상태 기계, 이 단계의 persona, 휴먼 게이트, spawn 실패 질문 | 구현 디테일 |

에이전트와 훅은 이 플랜에서도 플랫폼별로 남긴다. 합치는 대상은 **스킬과 런타임 스크립트 경로**뿐이다.

## 한 라운드 데이터 흐름 (full 모드 예시)

```
메인 세션 (dev-loop)
  PREFLIGHT: 플랜·LOOP·git snapshot. detect-commands.sh / resolve-scope.sh 를 호출자가 한 번 실행해 brief에 넣음.
  IMPLEMENTING: implementer 를 블로킹으로 시작 (brief: 플랜 경로, 검증 명령, "implement-dev 방법론").
      implementer → implement-dev 로드 → TDD 실행 → ## Stage Status 반환
      needs-design-decision → 메인이 plan-consultant 시작 → 결정을 넣어 implementer 재개
      failed → 같은 persona 1회 재시도 (스킬에 호스트 모델명을 적지 않음)
  TESTING: tester 시작 (brief: scope JSON, mutation in/out).
  REVIEWING: 모드의 축 persona들을 병렬 시작. 메인 세션이 review-code 의 caller 절(aggregate·triage·AR)을 수행.
  FIXING: finding마다 fixer 시작.
  휴먼 게이트(Fix/Accept, READY_TO_COMMIT)는 메인에만 남음. 서브에이전트는 사용자에게 묻지 않음.
```

standalone `/implement-dev` (루프 없음): 현재 세션이 방법론을 **직접** 실행한다. spawn하지 않는다.

standalone `/review-code`: 현재 세션이 **caller**다. 축 persona를 시작한 뒤 aggregate/triage를 한다. 스킬 본문은 소환 툴 이름을 대지 않는다.

## 레포·설치 토폴로지

```
repo
  skills/<name>/SKILL.md          ← 유일 소스 (지금 skills/claude/<name>/ 에서 승격)
  agents/{claude,codex,cursor,grok}/
  hooks/{claude,codex,cursor,grok}/
  scripts/runtime/*.sh
  .agents/skills/sync-harness/    ← 이 레포 전용 메타 스킬. ~/.agents/skills 에 설치하지 않음

home
  ~/.agents/skills/<name>/        ← 인스톨러가 harness 소유 이름만 관리
  ~/.agents/scripts/*.sh          ← detect-commands.sh, resolve-scope.sh
  ~/.claude/skills/<name>  →  ~/.agents/skills/<name>   # 스킬 단위 심링크
  ~/.cursor/skills/, ~/.codex/skills/, ~/.grok/skills/  ← harness 이름은 제거 (이중 로드 방지)
```

Harness 소유 스킬 이름 13개: `application-research-sync`, `chat-summary`, `commit-code`, `dev-loop`, `fix-dev`, `implement-dev`, `learn-from-manual-edits`, `loki-log-search`, `plan-dev`, `review-code`, `setup-initial-repo`, `spec-creator`, `test-dev`.

## 스킬 본문 계약 (13개 전부)

1. **frontmatter**는 `name` + `description`만. `allowed-tools` 삭제. `description`은 Codex 길이: 한두 문장, 대략 300자, 첫 문장에 trigger. Dispatcher/Worker 절차를 description에 넣지 않는다. 기존 `skills/codex/*/SKILL.md` description을 상한의 기준으로 쓴다.
2. **툴 이름 금지**: `Agent`, `Task`, `spawn_subagent`, `AskUserQuestion`, `AskQuestion`, `ask_user_question`, `ExitPlanMode`, `fork_turns`, `subagent_type`를 스킬 본문·references에 쓰지 않는다. "사용자에게 물어라". 객관식이면 선택지와 미응답=미분류 규칙만 적는다. "persona `X`를 블로킹 자식으로 시작한다"는 **루프/caller** 문장이지 스킬의 spawn 구현이 아니다.
3. **스크립트 경로**는 `$HOME/.agents/scripts/detect-commands.sh` 와 `$HOME/.agents/scripts/resolve-scope.sh`만.
4. **`agents/<platform>/` 경로를 스킬에 넣지 않는다.** 리뷰어 Reporting contract는 "해당 persona 본문의 `## Reporting contract`"로 지칭한다.
5. **Dispatcher/Worker 이중 모드를 삭제**한다 (`implement-dev`, `test-dev`, `fix-dev`). 실행자는 방법론을 따르고 고정 헤딩으로 반환한다. `worker-contract.md` 파일명은 유지하되 내용은 **호출자 brief + 반환 스키마 + 채팅 요약 형태**. worker-signal 문장(`You are running as the … Worker subagent.`)은 루프가 넘기는 brief로 대체한다.
6. **design-bearing**: 실행자는 `plan-consultant`를 띄우지 않는다. `## Stage Status: needs-design-decision`과 갈림길 brief를 반환한다. `needs-design-decision`은 이제 Grok 전용이 아니라 공통 상태 어휘다. `blocked`(방향 충돌)과 섞지 않는다.
7. **failed cascade**: 스킬은 호스트 모델명(`opus`, `gpt-5.6-sol`, `grok-4.6[effort=high]`)으로 재시도하지 않는다. 루프가 같은 persona를 한 번 더 띄운다.
8. **review-code**는 파일 하나, 청중 둘.
   - Executor: 자기 축의 finding 블록. 리뷰어 persona가 읽음.
   - Caller: scope를 한 번 모은다 → 지정된 축 persona를 시작한다 → Location 중복 제거, Confidence 필터, `REVIEW-NNN` 부여, Fix/Accept 트리아지, AR, Stage Status. 루프 또는 standalone 메인이 읽음.
9. **plan-dev / commit-code는 소환 역전 대상이 아니다.** plan-dev는 메인 인터뷰를 유지하고, planner가 필요하면 "읽기 전용 `planner`를 시작한다"고만 적는다. 플랜 승인은 "호스트의 plan-mode 승인 흐름을 기다린다. 호스트 전용 exit 툴을 호출하지 않는다."
10. 스킬 간 상대 링크(`../dev-loop/references/loop-state.md`)는 형제가 `skills/`와 `~/.agents/skills/` 아래에 그대로 있으므로 유지한다.

## 루프 계약

지금 불변식 "never dispatches a stage's Worker directly"를 지우고 아래로 바꾼다.

> 루프는 단계의 **persona**를 띄운다. 스킬은 띄우지 않는다.

단계 표 (모드 효과는 기존 `transitions.md`와 같음):

| 상태 | 루프가 시작하는 persona | 그 persona가 따르는 스킬 |
| --- | --- | --- |
| IMPLEMENTING | `implementer` 1명 | `implement-dev` |
| TESTING | `tester` 1명 | `test-dev` |
| REVIEWING | 모드의 축 집합, 병렬 | 각자는 executor 절; 메인은 `review-code` caller 절 |
| FIXING | `fixer` 1명, finding당 순차 | `fix-dev` |

추가 전이:

| 상태 | Stage Status | → Next |
| --- | --- | --- |
| IMPLEMENTING | `needs-design-decision` | 메인이 `plan-consultant`를 읽기 전용으로 시작 → 결정을 brief에 넣어 `implementer` 재개. 루프 예산을 쓰지 않음. `blocked`가 아님. |
| 임의 단계 | spawn 실패 | 사용자에게 이 단계를 현재 세션에서 직접 할지, 멈출지 묻는다. 조용히 in-place 하지 않음. |
| 임의 단계 | `failed` (실행자가 3회 벽에 부딪힘) | 같은 persona 1회 재시도 후 또 `failed`면 ESCALATED. 스킬에 모델명을 적지 않음. |

LOOP 파일 스테이지 줄은 계속 스킬 이름이다 (`implement-dev: pass`). persona 이름으로 바꾸지 않는다.

호출자가 Prepare를 한 번 한다: `detect-commands.sh` / `resolve-scope.sh` 결과를 brief에 넣는다. 실행자가 매번 처음부터 재발견하지 않게 한다. 값이 없으면 실행자가 스스로 돌리되, 루프는 있는 값을 넘긴다.

`light`/`noreview`에서 tester brief에 mutation out of scope를 명시하는 규칙은 유지한다. REVIEWING 축 집합을 루프가 명시하는 규칙도 유지한다. description matching에 축 선택을 맡기지 않는다.

## 에이전트 계약 (4 플랫폼 모두, 파일은 플랫폼에 남김)

- description에서 `Do not invoke directly` / `dispatched by the … skill` / `let test-dev dispatch`를 뺀다. 일의 내용으로 trigger를 쓴다.
- `plan-consultant`: 루프가 `needs-design-decision`일 때 띄운다. implementer가 띄운다는 문장을 모든 플랫폼에서 삭제한다.
- Claude `implementer`: `tools:`에서 `Agent`를 제거한다 (`Skill`은 유지).
- Claude `fixer`: `Skill`을 `tools:`에 추가한다.
- Claude `tester`: `Skill` 유지, spawn 툴 없음.
- 본문의 "Worker가 consultant를 부른다" / Cursor 중첩 한도를 consultant에 쓴다는 문장은 삭제하거나, 루프가 부른다고 고친다.
- 모델 핀·`readonly`·Codex TOML·Grok `permission_mode`는 이 플랜에서 재배치하지 않는다.

## 인스톨러

`scripts/apply-to-*.sh`가 스킬을 플랫폼 홈에 복사하는 경로를 없앤다.

공통 스킬 설치 (한 헬퍼로 빼도 되고, 네 스크립트가 같은 블록을 호출해도 된다):

1. `~/.agents/skills`에서 harness 소유 13개 이름만 지우고, 레포 `skills/<name>/`을 그 이름으로 채운다. 사용자가 `npx skills add`로 넣은 다른 이름은 건드리지 않는다. 디렉터리 전체를 `rm -rf` 하지 않는다.
2. `~/.agents/scripts`를 `scripts/runtime/`으로 채운다 (`cp -rp`).
3. Claude: harness 이름마다 `~/.claude/skills/<name>` → `~/.agents/skills/<name>` 심링크. 기존 실디렉터리/깨진 심링크는 그 이름만 교체. `~/.claude/skills` 디렉터리 자체를 심링크하지 않는다.
4. Cursor/Codex/Grok: `~/.cursor/skills`, `~/.codex/skills`, `~/.grok/skills`에서 harness 13개 이름을 제거한다 (이전 apply의 복본이 네이티브 `~/.agents/skills`와 이중 로드됨). 그 디렉터리 전체를 비우지 않는다.
5. Claude `~/.claude/settings.json`의 `permissions.allow`에 아래 두 항목이 없으면 **배열에 append**한다. `hooks/claude/settings.json`에 `permissions`를 넣지 않는다. `jq -s '.[0] * .[1]'`는 allow 배열을 통째 교체한다.

```
Bash($HOME/.agents/scripts/detect-commands.sh *)
Bash($HOME/.agents/scripts/resolve-scope.sh *)
```

6. 에이전트·훅 설치는 지금과 같다 (플랫폼 홈 wipe+copy / Claude settings 훅 병합 / Cursor hooks.json replace / Grok harness.json).
7. 런타임 스크립트를 `~/.claude/scripts` 등에 더 복사할지는 구현 재량이다. **스킬 본문은 그 경로를 부르면 안 된다.** 복사하지 않는 쪽이 두 진실이 안 생긴다.
8. Grok: apply 후 `grok inspect`로 harness 스킬이 `~/.agents/skills`에서 한 번씩만 보이는지 확인한다. 유저 티어 스캔이 안 되면 `~/.grok/config.toml`에 `[skills] paths = ["~/.agents/skills"]`를 안내하거나 인스톨러가 없을 때만 추가한다. 네이티브 스캔이 되면 paths를 넣어 이중 로드하지 않는다. `[compat.claude]`/`[compat.cursor]` `skills = false`는 유지.
9. Cursor stdout 경고(호환 경로 끄기)는 유지한다. 켜지면 Claude 심링크와 `~/.agents/skills`를 둘 다 읽는다.

## sync-harness

스킬은 더 이상 Claude↔Codex 마이그레이션 대상이 아니다.

- `.agents/skills/sync-harness/SKILL.md` (및 `.claude/skills` 복본): 스킬 변환 절을 "공유 트리 `skills/<name>/`, 포크 금지"로 교체. 방향 Step 1은 에이전트·훅만.
- `docs/sync-harness/SYNC_TO_{CODEX,CLAUDE,CURSOR,GROK}.md`: Skill migration에서 툴 치환표를 지우고, 공유 스킬 불변식(툴 이름 금지, 스크립트 경로, 짧은 description, `needs-design-decision` 공통)을 한곳에 둔다. 에이전트·훅 변환은 유지.
- `verify-sync.py`: `skills/claude` vs `skills/codex` 트리 패리티를 제거. `skills/<name>/` 13개가 있고 `SKILL.md` `name`이 디렉터리와 같은지 검사. residual sweep을 **공유 스킬 트리**에 적용: `AskUserQuestion`, `AskQuestion`, `ExitPlanMode`, `fork_turns`, `$HOME/.claude/scripts`, `$HOME/.cursor/scripts`, `$HOME/.codex/scripts`, `$HOME/.grok/scripts`, `allowed-tools`가 있으면 fail. 에이전트·훅 패리티는 유지.

## 문서

`AGENTS.md`, `README.md`, `README.ko.md`, `agents/AGENTS.md`에서 `skills/<platform>/` 설치 서술, 런타임 스크립트 네 경로, `plan-consultant` "implementer가 소환 / Grok만 Dispatcher" 행을 고친다. `instructions/AGENTS.md`는 스킬 레이아웃을 안 말하므로 필수는 아니다.

`needs-design-decision`을 Platform invariants 상태 어휘에 넣고 "Grok 전용"을 뺀다.

## Non-goals

- 에이전트 파일을 `~/.agents/` 아래로 합치지 않는다. 모델 핀·`tools:`/`readonly:`/`sandbox_mode`는 플랫폼 어댑터로 남긴다.
- 훅 스키마를 합치지 않는다.
- `sync-harness`를 `~/.agents/skills`에 설치하지 않는다.
- Cursor/Grok Claude-compat를 켜서 스킬을 공유하지 않는다. compat는 끈 채로 `~/.agents/skills`를 쓴다.
- `dev-loop-light` / `dev-loop-noreview` 스킬 폴더를 부활시키지 않는다. 모드는 기존처럼 `dev-loop` 하나다.
- T1 모델 cascade(`opus` / `gpt-5.6-sol` 재시도)를 되살리지 않는다.
- standalone implement/test/fix가 persona를 띄우게 되돌리지 않는다.
- 스킬 안에 호스트 툴 이름을 "문서용 예시"로 남기지 않는다.
- `docs/cost-effective/` 역사 문서를 이 플랜에서 고치지 않는다.

## Key decisions

1. **범위는 한 플랜에 전부**: 본문 중립화 + 소환 역전 + 레포 트리 붕괴 + `~/.agents/skills` 설치 + Claude 스킬 단위 심링크.
2. **소환은 루프만.** 페르소나는 자식을 안 띄운다. consultant도 루프다.
3. **standalone 스킬은 현재 세션 in-place.** 예외는 review-code의 caller가 축 persona를 시작하는 것(멀티 페르소나 단계)뿐이고, 그것도 스킬이 툴 이름을 대지 않는다.
4. **레포 경로는 `skills/<name>/`.** `skills/shared/`나 `skills/common/`을 만들지 않는다. `skills/claude/`에서 승격하고 `skills/{claude,codex,cursor,grok}/`를 삭제한다.
5. **인스톨러는 harness 소유 이름만 만진다.** `~/.agents/skills`와 플랫폼 스킬 디렉터리 전체를 wipe하지 않는다.
6. **Claude 심링크는 스킬 단위.** `~/.claude/skills` 디렉터리 심링크는 쓰지 않는다.
7. **`allowed-tools`는 스킬에서 삭제**하고 Claude settings `permissions.allow`에 append한다. 훅 settings에 permissions를 넣지 않는다.
8. **failed는 같은 persona 1회 재시도**, 스킬/루프 본문에 호스트 모델명 없음.
9. **LOOP 로그는 스킬 이름 유지.**
10. **git mv vs copy**는 구현 재량. 최종 트리와 히스토리 보존이 목적이다.

## 검증 (구현 세션)

테스트 스위트는 없다. 아래가 이 작업의 검증이다.

- `python3 .agents/skills/sync-harness/scripts/verify-sync.py` PASS. 공유 스킬에 호스트 토큰 없음.
- 레포에 `skills/claude` 등이 없고 `skills/implement-dev/SKILL.md` 등이 있다.
- `rg -n 'AskUserQuestion|AskQuestion|ExitPlanMode|fork_turns|allowed-tools|\$HOME/\.(claude|cursor|codex|grok)/scripts' skills/` 가 비어 있다 (`agents/`·`hooks/`는 해당 없음).
- dry-run 또는 실제 `scripts/apply-to.sh claude cursor` 후: `~/.agents/skills/implement-dev/SKILL.md` 존재, `readlink ~/.claude/skills/implement-dev`가 그 타깃, `~/.cursor/skills/implement-dev` 없음.
- `grok inspect`(가능하면): harness 스킬 source가 `~/.agents/skills`이고 중복 없음.

## 리스크

- Cursor가 `~/.agents/skills`와 호환 `~/.claude/skills`를 같이 읽으면 심링크 때문에 같은 스킬이 두 번 보일 수 있다. compat off가 전제다.
- Grok 유저 티어 `~/.agents/skills` 스캔이 문서와 다를 수 있다. inspect로 확인하고 paths는 중복 없을 때만 쓴다.
- Claude 디렉터리 통째 심링크는 slash `Unknown skill` 버그가 있었다. 스킬 단위만 쓴다.
- 본문 중립화 없이 설치만 바꾸면 Cursor가 Claude 툴 이름을 실행한다. TODO 1을 설치(TODO 4)보다 먼저 끝낸다. 같은 커밋이어도 작업 순서는 본문 → 에이전트/루프 → 인스톨러.

## Acceptance Contract

| ID | Observable condition | Evidence |
| --- | --- | --- |
| AC-1 | 제품 스킬 소스가 레포 `skills/<name>/` 하나뿐이고 `skills/{claude,codex,cursor,grok}/`가 없다 | `ls skills/`가 13개 스킬 디렉터리(+필요시 다른 비플랫폼 항목)이고 네 플랫폼 하위 디렉터리가 없음 |
| AC-2 | 공유 스킬·그 references에 호스트 툴 이름, 플랫폼 스크립트 경로, `allowed-tools`가 없다 | `verify-sync.py` PASS + 위 `rg`가 `skills/`에서 0건 |
| AC-3 | `dev-loop`가 단계 persona를 명시하고, 스테이지 스킬이 spawn 툴/Dispatcher-Worker 이중 모드로 persona를 띄우지 않는다 | `dev-loop/SKILL.md` 단계 표; `implement-dev`/`test-dev`/`fix-dev`/`review-code`에 Dispatcher spawn 절 없음; `needs-design-decision`이 루프 전이표에 있음 |
| AC-4 | 네 플랫폼 에이전트 description이 스킬 Dispatcher에 묶이지 않고, Claude implementer는 자식을 띄울 툴이 없으며 fixer는 Skill을 가진다 | `rg 'Do not invoke directly' agents/` 0건; Claude implementer `tools:`에 `Agent` 없음, fixer에 `Skill` 있음 |
| AC-5 | apply가 harness 스킬을 `~/.agents/skills`에 두고 Claude만 스킬 단위 심링크를 걸며, Cursor/Codex/Grok 스킬 디렉터리에 harness 이름 복본이 없다 | apply 후 `readlink`·부재 확인 (검증 절) |
| AC-6 | 런타임 스크립트 호출이 `$HOME/.agents/scripts/…`이고 Claude는 그 경로를 settings allow에 중복 없이 가진다 | 스킬 본문 경로; `~/.claude/settings.json` allow에 두 Bash 엔트리; `hooks/claude/settings.json`에 permissions 없음 |
| AC-7 | sync-harness가 스킬을 플랫폼 변환하지 않고, 문서는 `~/.agents/skills` 토폴로지를 말한다 | SKILL.md·SYNC_TO_*·AGENTS.md·README에 `skills/<platform>/`를 제품 스킬 소스로 쓰지 않음 |

Do not mark done if: 스킬 본문은 공용인데 인스톨러가 여전히 `skills/claude`를 `~/.claude/skills`에 복사한다; 또는 루프가 persona를 띄우는데 스킬 Dispatcher 절이 남아 이중 소환한다.

## Authority Boundaries

- Discretion: git mv vs copy로 트리 승격, apply 헬퍼를 한 파일로 뺄지, 플랫폼 `~/.*/scripts` 잔여 복사 여부, Grok inspect 결과에 따른 `[skills] paths` 추가 여부, worker-contract 섹션 헤딩 재배치, 13개 스킬을 한 TODO 안에서 어떤 순서로 중립화할지.
- Must-ask: 레이어 책임 변경, 루프 외 소환 부활, standalone implementer 재도입, `skills/common/` 같은 두 번째 소스 루트, 에이전트 파일을 공용 트리로 합치기, T1 모델 cascade 부활, `~/.claude/skills` 디렉터리 통째 심링크, harness 외 사용자 스킬을 wipe.
- Stop conditions: apply가 harness 이름이 아닌 `~/.agents/skills` 항목을 지운다; jq merge가 사용자 `permissions.allow`를 덮어쓴다; Cursor compat가 켜진 채 심링크와 네이티브 경로가 같은 스킬을 두 벌 로드하는 것을 "그냥 둔다"고 결정하려 할 때 — 멈추고 보고.
- Loop budget: 3

## TODOs

- [x] 레포 제품 스킬을 `skills/<name>/` 단일 트리로 승격하고, 13개 SKILL.md·references를 공용 계약(짧은 description, 툴 이름 없음, `~/.agents/scripts`, Dispatcher 소환 삭제, `needs-design-decision` 반환)으로 재작성한다. `skills/{claude,codex,cursor,grok}/`는 제거한다. (AC-1, AC-2, AC-3) (mechanical) (→ research: skill-platform-forks)
- [x] `dev-loop`와 `transitions.md`를 루프-소환 컨트롤러로 바꾼다: 단계×persona 표, brief에 검증/scope 전달, `needs-design-decision` 처리, spawn 실패 질문, 같은 persona 1회 `failed` 재시도. LOOP 로그는 스킬 이름을 유지한다. (AC-3) (mechanical) (→ research: skill-platform-forks)
- [x] 네 플랫폼 에이전트 9종 description·소환 문장을 루프 소환에 맞추고, Claude `tools:`에서 implementer의 `Agent`를 빼며 fixer에 `Skill`을 넣는다. (AC-4) (mechanical)
- [x] `apply-to-*.sh`를 `~/.agents/skills` + `~/.agents/scripts` + Claude 스킬 단위 심링크 + 플랫폼 스킬 디렉터리에서 harness 이름 제거 + Claude allow append로 바꾼다. (AC-5, AC-6) (mechanical) (→ research: skill-install-discovery)
- [x] `sync-harness` 스킬·`verify-sync.py`·`docs/sync-harness/SYNC_TO_*.md`에서 스킬 플랫폼 변환을 제거하고 공유 트리 residual sweep을 넣는다. (AC-2, AC-7) (mechanical) (→ research: skill-install-discovery)
- [x] `AGENTS.md`, `README.md`, `README.ko.md`, `agents/AGENTS.md`의 스킬 레이아웃·설치 경로·`plan-consultant` 소환자·런타임 스크립트 경로를 새 토폴로지에 맞춘다. (AC-7) (mechanical)
