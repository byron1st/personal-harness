# Codex 변형 구현 계획

> 작성일: 2026-08-03 · 상위 문서: [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md) · 선행: [PLAN_CLAUDE.md](PLAN_CLAUDE.md)(적용 완료) · 병행 참고: [PLAN_CURSOR.md](PLAN_CURSOR.md) · 변환 규칙: [SYNC_TO_CODEX.md](../sync-harness/SYNC_TO_CODEX.md) · 범위: **`skills/codex/` · `agents/codex/` · `hooks/codex/` · `scripts/apply-to-work.sh` · `SYNC_TO_CODEX.md` · `AGENTS.md`** · 성격: 구현 계약
>
> Cursor 계획과 달리 Codex는 **그린필드 포팅이 아니다.** `skills/codex/` · `agents/codex/` · `hooks/codex/` · `apply-to-work.sh`가 이미 있고, Claude ↔ Codex 토폴로지의 Work 중심이 이 변형이다. 이 문서가 하는 일은 **Claude 비용 절감 적용분(`PLAN_CLAUDE` W1~W9)을 Codex 방언으로 동기화**하고, 그 위에 **Codex 고유 티어 배치(Sol / Terra / Luna)** 를 얹는 것이다.
>
> **참조 표기**: `§N`은 상위 문서 [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md)의 절, `PLAN_CLAUDE §N` · `PLAN_CURSOR §N`은 각 계획서의 절, `SYNC §…`는 [SYNC_TO_CODEX.md](../sync-harness/SYNC_TO_CODEX.md)의 절이다. 그 외 `§N`이 이 문서 자신을 가리킬 때는 "이 문서 §N"으로 적는다.

## 요약 (결론 먼저)

1. **포팅 자체가 아니라 델타다.** Claude 17스킬 · 9에이전트 대비 Codex는 스킬 15(+ `review-code-claude` 전용 1) · 에이전트 6이다. 빠진 것은 `dev-loop-light` · `dev-loop-noreview` 스킬 2개와 `plan-consultant` · `tester` · `fixer` 에이전트 3개, 그리고 기존 파일에 아직 없는 **티어 핀 · cascade · design-bearing · 런타임 스크립트 소비 · 리뷰어 Reporting contract · TESTING Fix/Accept** 이다. 본문을 처음부터 쓰지 말고 **Claude 적용본을 소스로 `SYNC_TO_CODEX.md` 규칙에 따라 옮긴다.**
2. **Codex 기본 루프는 `dev-loop-light`이다.** Claude·Cursor의 `dev-loop-noreview`와 다르다. Luna 단가 때문에 light→noreview 추가 절감이 작업당 $0.27(−5%)뿐이라, 2축 리뷰를 유지하는 쪽이 맞다(§9.9). `dev-loop-noreview`도 **만들되 기본값은 아니다** — 세 루프가 병존한다.
3. **단일 배치 변경 중 절감이 가장 큰 것은 `implementer` → Terra / high다.** Sol→Terra는 라운드 단위 약 2.0~2.5배 싸면서 MRCR·SWE-Bench Pro는 1~2pp 차다(§9.6b). **cascade(3-fail → Sol 1회 재시도)가 짝**이므로 Terra 핀과 cascade 규칙은 같은 적용분 안에서 함께 들어간다.
4. **표현은 이미 가능하다 — 두 줄만 추가하면 된다.** Codex agent role TOML은 `ConfigToml`을 flatten하므로 `model` · `model_reasoning_effort`를 키로 넣는다(§8.2, Context7 `/openai/codex` 확인). `sandbox_mode`는 이미 read-only / workspace-write로 나뉘어 있다. Claude의 `tools:` · `effort:` 가 여기선 각각 `sandbox_mode` · `model_reasoning_effort`로 대응한다.
5. **핀이 조용히 깨지지 않는다.** Codex의 `[agents] default_subagent_*`는 **fallback**이다 — role이 명시한 값을 덮어쓰지 않는다. 잘못된 effort 조합은 `supported_reasoning_levels` 검증에서 **에러**가 난다. Cursor의 `model-pin-guard.sh`에 해당하는 훅은 **필요 없다.**
6. **`ultra` 금지 · Luna는 장문맥 역할에 금지.** `ultra`는 automatic task delegation을 동반해 dev-loop 위임과 충돌한다(§4 원칙 3). Luna MRCR 41.3%는 `implementer` 입력 형태와 겹치므로 Luna 자리는 tester/fixer/T2 리뷰어/컨트롤러뿐이다.
7. **설치 경로만 한 군데 비어 있다.** `scripts/runtime/*`는 Claude·Cursor 설치 스크립트가 복사하지만 `apply-to-work.sh`에는 런타임 스크립트 블록이 없다. 소비 스킬이 `$HOME/.codex/scripts/…`를 부르게 되면 **그 블록이 없으면 참조가 전부 깨진다.**

---

## §1. 현재 상태 — 파일 단위 사실

전부 이 세션에서 직접 확인한 값이다. 기준 원본은 Claude 비용 절감 적용 완료분(`PLAN_CLAUDE` W1~W9).

### 1.1 갭 인벤토리

| 구분 | Claude (원본) | Codex (현재) | 갭 |
| --- | --- | --- | --- |
| 에이전트 | 9 (`agents/claude/*.md`) | 6 (`agents/codex/*.toml`) | **`plan-consultant` · `tester` · `fixer` 없음** |
| 에이전트 티어 핀 | 전 행 `model` + `effort`, `inherit` 0 | **`model` / `model_reasoning_effort` 0곳** | 전부 세션/부모 상속 |
| 스킬 | 17 (`dev-loop` 3종 포함) | 15 + `review-code-claude`(Codex-only) | **`dev-loop-light` · `dev-loop-noreview` 없음** |
| 런타임 스크립트 | `scripts/runtime/` → `~/.claude/scripts/` | **설치 안 됨** | `apply-to-work.sh`에 블록 없음 |
| 훅 | 5 + `settings.json` | 5 + `hooks.json` | 경로·스키마 이미 Codex용. **model-pin-guard 불필요** |
| implement-dev | cascade · plan-consultant · detect-commands | custom `implementer` + `fork_turns="none"` + worker 폴백만 | **본문 계약 미반영** |
| test-dev / fix-dev | `tester` / `fixer` persona | built-in `worker` | **persona 없음, mutation opt-out·Fix/Accept 미반영** |
| review-code | Reporting contract 에이전트 본문, 축 부분집합, resolve-scope, Aggregate 필터 | 4축 parallel + 텍스트 triage 규약 | **정적 계약 이전·subset·스크립트·필터 이전 미반영** |
| plan-dev | `(mechanical)` / `(design-bearing)` 태그 | AC/AB는 있음, **difficulty 태그 없음** | 태그·consultant 게이트 없음 |
| dev-loop | TESTING Fix/Accept 게이트 | 구형 전이( suspected → FIXING / closed 쪽) | **C3b 미반영** |

### 1.2 이미 올바른 것 — 다시 만들지 않는다

- **Dispatcher-first + delegation failure gate** (`SYNC` "Allow Skill-directed delegation…"). 위임형 스킬 본문에 이미 있다.
- **custom agent spawn 시 `fork_turns="none"`** (`implement-dev` · `plan-dev` · `review-code`).
- **트리아지 텍스트 응답 규약** (`REVIEW-001: fix` / `accept`) — Codex에 구조화 질문 툴이 없어 이미 변환됨(`SYNC` "Convert structured triage…").
- **read-only = `sandbox_mode = "read-only"`** + 본문 hard rule. Claude `tools:` 화이트리스트의 Codex 대응물.
- **`review-code-claude`** — Codex-only 어댑터. counterpart를 Claude에 만들지 않으며 이 계획도 건드리지 않는다(`SYNC` Platform-specific exception).
- **훅 5종** 경로(`$HOME/.codex/hooks/…`)와 `hooks.json` 이벤트 매핑(`SessionStart` · `PreToolUse` Bash · `PostToolUse` apply_patch|Edit|Write).
- **전역 지침** — `instructions/AGENTS.md` → `~/.codex/AGENTS.md` (`apply-to-work.sh`가 이미 복사). Cursor처럼 sessionStart 주입이 필요 없다.

### 1.3 기존 에이전트 6개 (`agents/codex/`)

| 파일 | `sandbox_mode` | `model` / `model_reasoning_effort` |
| --- | --- | --- |
| `planner.toml` | `read-only` | **없음** |
| `implementer.toml` | `workspace-write` | **없음** |
| `security-reviewer.toml` | `read-only` | **없음** |
| `reliability-reviewer.toml` | `read-only` | **없음** |
| `maintainability-reviewer.toml` | `read-only` | **없음** |
| `senior-generalist-reviewer.toml` | `read-only` | **없음** |

본문은 Claude 적용 **이전** 세대다 — 리뷰어 4종에 `## Reporting contract`가 없고, `implementer`에 design-bearing / plan-consultant 밴드와 `Tier:` 근거 줄이 없다.

### 1.4 설치 경로 (`scripts/apply-to-work.sh`)

| 소스 | 대상 |
| --- | --- |
| `skills/codex/*` | `~/.codex/skills/` (디렉터리 통째 삭제 후 복사) |
| `agents/codex/*.toml` | `~/.codex/agents/` |
| `hooks/codex/hooks/*` | `~/.codex/hooks/` (`cp -rp`) |
| `hooks/codex/hooks.json` | `~/.codex/hooks.json` (교체) |
| `instructions/AGENTS.md` | `~/.codex/AGENTS.md` |
| `scripts/runtime/*` | **미설치** ← X1에서 추가 |

스킬은 소스·설치본 모두 형제 디렉터리라 `../dev-loop/references/…` 같은 상대 링크가 양쪽에서 같다 — `PLAN_CLAUDE` W2가 기댄 성질이 여기도 성립한다.

---

## §2. 확인된 Codex 사양 (구현이 이 위에 선다)

이 세션에서 Context7 `/openai/codex`와 상위 문서 §8.2로 확인한 것만 적는다.

**Agent role TOML** (`agents/*.toml`)

- 스키마: `name` · `description` · `nickname_candidates` + **`ConfigToml` flatten**.
- flatten 덕에 **`model`** · **`model_reasoning_effort`** · `sandbox_mode` 등을 role 파일에 직접 쓸 수 있다. 구조 변경 없이 키 추가.
- 설치 경로: 전역 `~/.codex/agents/`, 프로젝트 `.codex/agents/`.

**모델·effort 해석 우선순위**

```
spawn_agent 호출 인자 (model / reasoning_effort)
  → role 파일 (model / model_reasoning_effort)
  → [agents] default_subagent_model / default_subagent_reasoning_effort
  → 부모 상속
```

- **`default_subagent_*`는 fallback** — role 핀을 덮어쓰지 않는다. Claude의 `CLAUDE_CODE_SUBAGENT_MODEL`(전부 덮어씀)보다 운용상 안전하다.
- effort는 모델별 `supported_reasoning_levels`로 검증된다. **잘못된 조합은 조용히 무시되지 않고 에러.**
- cascade(T1 1회 재시도)는 spawn 호출 인자의 `model` / `reasoning_effort`로 role 핀을 이긴다 — Claude가 호출 인자 `model: opus`로 frontmatter를 이기는 것과 같다. multi-agent v2의 `expose_spawn_agent_model_overrides`가 켜져 있어야 툴 스키마에 필드가 노출된다(문서 확인). **적용 전 환경에서 spawn 시 model override가 가능한지 한 번 확인한다**(이 문서 §8 결정 2).

**effort 스케일**: `none` · `minimal` · `low` · `medium` · `high` · `xhigh` · `max` · **`ultra`**. 이 하네스는 **`ultra`를 쓰지 않는다**(§4 원칙 3).

**built-in agent 이름**: `default` · `worker` · `explorer`. custom `name`이 이들과 충돌하면 custom이 우선되므로 충돌 이름을 쓰지 않는다(`SYNC` Sub-agent migration). 이 계획의 신규 이름(`plan-consultant` · `tester` · `fixer`)은 충돌하지 않는다.

**Skill description 예산**: Codex는 시작 시 `name` · `description` · 경로만 먼저 본다. description은 **한두 문장·대략 300자 이내**, 첫 문장에 trigger(`SYNC` "Keep frontmatter descriptions short…"). Claude 스킬 description이 길면 Codex 쪽에서 축약한다 — 본문·`references/`로 옮긴다.

**권한**: Codex subagent는 기본적으로 현재 sandbox와 approval policy를 상속한다. 독립 권한을 가정하지 않는다. read-only는 `sandbox_mode = "read-only"` + 본문 규칙으로 보장한다.

**루프 불변식**: 훅에 의존하지 않는다. Codex `PreToolUse`는 모든 shell 경로를 intercept하지 못하므로, 커밋·푸시 금지·AR 규칙·예산 상한은 **SKILL 본문**이 강제한다(`SYNC` "Migrate controller skills…").

---

## §3. 목표 상태 — 숫자 (Codex 풀)

전제: §9.4 · §9.9 정가 기준. Codex 기본 예산 $100(=2,500 credits), 계획 상한 $700.

| | 구성 | $/작업 | **$100 작업 수** | **$700 작업 수** |
| --- | --- | --- | --- | --- |
| **적용 전** (추정) | 전부 Sol 계열 · `dev-loop` 4축 · implementer Sol | ~$13.8+ (implementer Sol이면 더 큼) | ≤7.2 | ≤50.7 |
| **적용 후 (§9.9)** | 최종 티어 · **`dev-loop-light`** · implementer Terra/high | **$5.38** | **18.6** | **130.1** |
| 참고: noreview | 위 + 리뷰 0축 | $5.11 | 19.6 | 137.0 |

**기본값이 light인 이유**: light→noreview 추가 절감이 −5%뿐이고, 남는 리뷰어 2종이 Luna라 라운드 단위 $0.54 수준이다(§9.9). Claude(−47%)·Cursor(−32%)와 경제성이 다르다.

**기여 분해** (회계; 일괄 적용):

| 기여 | 효과 |
| --- | --- |
| `dev-loop-light` 기본값 | 작업당 −61% (4축 대비) — **절감의 대부분** |
| `implementer` Sol → Terra/high | 4축 기준 월 +2.0작업(+38%) — **단일 배치 최대** |
| 나머지 T2 → Luna + 세션 Luna | 리뷰어·tester·fixer·컨트롤러 단가 25배 축 |

---

## §4. 티어 배치 — Codex 판

§4 배치표의 Codex 열을 파일로 옮긴 것이다. **모델 슬러그 표기**는 카탈로그 표시명(Sol / Terra / Luna)을 쓰고, TOML `model` 값에는 Codex models catalog가 받는 실제 ID를 넣는다(예: 문서·카탈로그에 보이는 `gpt-5.6-*` 계열). **틀린 ID는 spawn이 실패한다** — Cursor처럼 조용히 폴백하지 않으므로 첫 라운드에서 드러난다(이 문서 §8 결정 1).

### 4.1 최종 에이전트 배치

| 에이전트 | 신규? | `model` | `model_reasoning_effort` | `sandbox_mode` | 근거 |
| --- | --- | --- | --- | --- | --- |
| `planner` | | **Sol** | `high` | `read-only` | T1 — 아키텍처 판단 |
| `plan-consultant` | ✅ | **Sol** | `high` | `read-only` | T1 — escalation hatch |
| `security-reviewer` | | **Sol** | `medium` | `read-only` | T1 — miss 비용 최대 |
| `reliability-reviewer` | | **Sol** | `medium` | `read-only` | T1 — 반사실 시뮬레이션 |
| `implementer` | | **Terra** | `high` | `workspace-write` | 장문맥 역할 — Luna 실격, Sol 대비 2~2.5배 저렴(§9.6b) |
| `tester` | ✅ | **Luna** | `high` | `workspace-write` | 기계 목표 + 프로덕션 코드 금지; 소형 컨텍스트 |
| `fixer` | ✅ | **Luna** | `high` | `workspace-write` | finding이 곧 명세; 소형 컨텍스트 |
| `maintainability-reviewer` | | **Luna** | `high` | `read-only` | 명세된 패턴 매칭 |
| `senior-generalist-reviewer` | | **Luna** | `high` | `read-only` | calibrated catch-all |

**effort 원칙 (Codex 재서술)**:

1. **모델은 아래로, effort는 위로.** Sol→Luna는 입·출력 25배 절감인데 Luna를 `high`로 올리는 비용은 그 절감분에 비해 미미하다. T2 전 행이 `high`인 이유다.
2. **최상단은 사지 마라.** 기본→`max`는 티어 전반 2~4점. 세션 `plan-dev`에만 `xhigh`를 쓰고, 리뷰어 T1은 `medium`.
3. **`ultra` 금지.** 본문·`SYNC_TO_CODEX.md`·`AGENTS.md`에 한 줄로 남긴다.

**세션 모델** (파일 아님 — 습관, `PLAN_CLAUDE` W4와 동일 구조):

| 세션 | 모델 / effort | 왜 |
| --- | --- | --- |
| `plan-dev` | **Sol / xhigh** | 방향·경계·AC는 되돌릴 수 없음 |
| 모든 `dev-loop*` 실행 | **Luna / medium** | 컨트롤러는 전이표 조회 + LOOP append. T1 에이전트는 role 핀으로 Sol |

**cascade 시 spawn 인자**: `model` = Sol, `reasoning_effort` = `high`(또는 role의 T1 기본). 1회 상한. chat summary에 "T1 retry fired / recovered?" 한 줄을 **반드시** 남긴다 — Terra 하향의 유일한 관측 창이다.

### 4.2 Claude → Codex 필드 매핑

| Claude | Codex | 비고 |
| --- | --- | --- |
| `model: opus` | `model = "<Sol id>"` | T1 |
| `model: sonnet` (implementer) | `model = "<Terra id>"` | **Claude T2 ≠ Codex T2 단일 모델** — implementer만 Terra |
| `model: sonnet` (그 외 T2) | `model = "<Luna id>"` | |
| `effort: high` | `model_reasoning_effort = "high"` | 값 어휘는 공통 구간에서 그대로 |
| `effort: medium` | `model_reasoning_effort = "medium"` | |
| `tools: Read, Grep, Glob, Bash` | `sandbox_mode = "read-only"` + 본문 hard rule | 툴 화이트리스트 손실 — Codex는 원래 sandbox 단위 |
| `tools: …, Agent` | (필드 없음) | spawn은 스킬/런타임 능력. implementer 본문에 plan-consultant 호출 규약만 명시 |
| `Agent(subagent_type: X, …)` | spawn custom agent `X` with `fork_turns="none"`; 없으면 `explorer`/`worker` + persona 프롬프트 폴백 | 기존 Codex 패턴 유지 |
| `AskUserQuestion` | 텍스트 응답 규약 (`REVIEW-001: fix` 등) | 이미 있음. Fix/Accept 확장 시 동일 형식 |
| `$HOME/.claude/scripts/…` | `$HOME/.codex/scripts/…` | 설치 대상 경로 |
| `allowed-tools:` | **삭제** | Codex 스킬 프론트매터에 없음 |
| `## Reporting contract` (에이전트 본문) | 그대로 `developer_instructions`에 포함 | 플랫폼 무관 산문 — **이득이 그대로 온다** |

### 4.3 커밋 분할

일괄 적용 · 항목별 커밋. 회귀 시 `git revert` 단위.

| 커밋 | 항목 | 내용 | 되돌리면 잃는 것 |
| --- | --- | --- | --- |
| **X1** | A1 | 기존 6 에이전트에 `model` + `model_reasoning_effort` + `Tier:` 줄. implementer는 **아직 Sol**로 두거나, X6에서 Terra로 바꾸는 한 줄을 분리할 수 있게 커밋 경계를 명확히 한다 | 티어 핀 전부 |
| **X2** | A2 | `tester.toml` · `fixer.toml` 신설 + `test-dev` · `fix-dev`가 해당 persona를 spawn (`fork_turns="none"`, 폴백 `worker`) | tester/fixer 티어링 |
| **X3** | A3 | `dev-loop-light` · `dev-loop-noreview` 신설 + `test-dev` mutation opt-out + `review-code` 축 부분집합 | **절감의 대부분** |
| **X3b** | A3 | TESTING 게이트 Fix/Accept + AR 연결 — `dev-loop` 및 신규 2종 전이표 | test finding Accept 경로 |
| **X4** | A4 | `plan-dev` references에 `(mechanical)` / `(design-bearing)` 태그 | plan-consultant 게이트 |
| **X5** | A5 | cascade — implement-dev · fix-dev Worker `failed` 시 Sol 1회 재시도 + summary 한 줄 | implementer 하향 안전망 |
| **X6** | A6 | `implementer` → **Terra/high** + `plan-consultant.toml` 신설 + implement-flow consultable 밴드 | **단일 배치 최대 절감** + 최대 리스크 |
| **X7** | A7 | 리뷰어 4종 `## Reporting contract` 이전 + stable-first + Aggregate 필터 완화 + T2 리뷰어는 Luna 핀(X1과 중복이면 X1에 포함했는지 확인) | 4축·light 리뷰 품질·비용 |
| **X8** | A8 | `scripts/runtime/*` → `~/.codex/scripts/` 블록을 `apply-to-work.sh`에 추가 + 소비 스킬 경로 `$HOME/.codex/scripts/…` | 반복 추론 제거 |
| **X9** | A9 | `SYNC_TO_CODEX.md` 모델 매핑 절 추가 + `AGENTS.md` Codex 열 + 세션 운용 + `ultra` 금지 | 문서 (동작은 X1~X8) |

**X6은 단독 revert 가능해야 한다.** 신호 표(이 문서 §9)가 이 커밋을 직접 가리킨다. 실질 변경은 `implementer.toml`의 `model` 한 줄(+ consultant는 남겨도 무해).

### 4.4 같은 적용분 안에서 지킬 의존

| 의존 | 이유 |
| --- | --- |
| **X1 → 세션 규칙을 Luna로** | 핀 없이 세션만 Luna면 T1 리뷰어·planner가 조용히 Luna가 된다 |
| **X5 ↔ X6 짝** | Terra 하향의 실패 꼬리를 cascade가 자른다. **X5만 되돌리면 안 된다** |
| **X4 → X6 consult 게이트** | `(design-bearing)` 없이 consultant를 열면 호출 상한이 없다(§10-11) |
| **X3 + X3b 함께** | 신규 루프 전이표가 처음부터 Fix/Accept여야 세 루프 게이트가 갈라지지 않는다 |
| **X8 + 소비 스킬 경로** | 설치 블록 없이 `$HOME/.codex/scripts/`를 부르면 깨진다 |
| **모든 커밋 → `apply-to-work.sh` 실행** | 저장소 수정만으로는 설치본이 안 바뀐다 |

---

## §5. 작업 단위 상세

### A1 — 기존 6 에이전트 티어 핀 · **X1**

각 `agents/codex/<name>.toml` 상단에 (예시 형태):

```toml
name = "security-reviewer"
description = "…"  # 한두 문장 유지
sandbox_mode = "read-only"
model = "<Sol id>"
model_reasoning_effort = "medium"
developer_instructions = """
# Security Reviewer

Tier: T1 judgment — a missed authz bypass is unrecoverable once shipped.

…
"""
```

- `implementer`는 X1에서 **Sol / high**로 두거나, 최종 Terra를 X6 한 줄로 남기기 위해 X1에서는 핀만 명시하고 값을 X6에서 Terra로 바꾼다. **권장: X1 = Sol/high, X6 = Terra/high** — revert 단위가 `PLAN_CLAUDE` C1/C6와 같다.
- 본문 선두는 Claude 적용본의 산문을 가져오되, Claude 툴 이름(`Read`/`Grep`/…)은 기능 서술로 바꾼다(`SYNC` "Replace Claude-specific tool names").
- `description`은 Codex 선택 힌트용으로 **짧게** 유지. 긴 persona는 `developer_instructions`에.

### A2 — `tester` · `fixer` 신설 · **X2**

- 소스: `agents/claude/tester.md` · `fixer.md` 본문 → TOML `developer_instructions`.
- 핀: Luna / high, `sandbox_mode = "workspace-write"`.
- `skills/codex/test-dev/SKILL.md` · `worker-contract.md`: spawn 대상을 built-in `worker`에서 custom **`tester`** 로 (`fork_turns="none"`; 없으면 `worker` + 계약 프롬프트 폴백).
- `skills/codex/fix-dev/SKILL.md`: 동일하게 **`fixer`**.
- 폴백 시에도 티어 핀은 사라질 수 있다 — summary에 fallback을 명시하고, 가능하면 role 설치를 전제로 한다.

### A3 — 루프 3종 + 기존 스킬 계약 · **X3 / X3b**

**신규 스킬** (Claude 소스를 `SYNC` "Migrate controller skills"로 옮김):

| 스킬 | Codex 기본값? | 구성 |
| --- | --- | --- |
| `dev-loop` | 아니오 — 무겁고 심각할 때만 | 4축 + mutation |
| **`dev-loop-light`** | **예 — Work/Codex 기본** | mutation 제외 + maintainability · senior-generalist |
| `dev-loop-noreview` | 아니오 (만들되 비기본) | mutation 제외 + 리뷰 없음 |

- description만 300자 이내 trigger 중심 압축. 상태 기계·종료 술어·ID·섹션명은 **번역하지 않는다** (Platform invariants).
- `test-dev`: 호출자가 mutation out of scope를 선언하면 Phase 3 스킵, 명령 부재를 `blocked`로 보지 않음 — Claude 문단을 Codex 툴 어휘로 이식.
- `review-code`: 호출자가 축 부분집합을 이름 내면 그 축만 spawn. light가 `maintainability-reviewer` · `senior-generalist-reviewer`만 넘긴다.

**X3b — TESTING Fix/Accept** (`PLAN_CLAUDE` C3b와 동일 정책):

- `pass-with-suspected-defects` → 항목별 **Fix / Accept** (텍스트: `TEST-001: fix` | `TEST-001: accept`).
- Accept → AR 엔트리 (`Original severity: TEST (suspected defect)`). 사용자 명시 응답만. 미분류 잔존 시 정지.
- `dev-loop` · light · noreview 전이표와 종료 술어 ⑦을 맞춘다. **noreview에서도 AR 레지스트리는 산다.**

### A4 — plan-dev difficulty 태그 · **X4**

- `skills/codex/plan-dev/references/single-step-plan.md` · `multi-steps-plan.md`에 Claude와 같은 `(mechanical)` / `(design-bearing)` 규칙.
- `design-bearing`을 인색하게 — consultant 호출 상한이 없으므로(§10-11) 태그가 예산 제어다.

### A5 — cascade · **X5**

- `implement-dev` · `fix-dev`의 worker-contract(또는 동등 절)에 Claude §E' 이식:
  - Worker `## Stage Status: failed` → Dispatcher가 **Sol로 정확히 1회** 재-spawn (동일 프롬프트 + 이전 시도 관찰 한 줄).
  - 두 번째도 `failed`면 그대로 상향. 메인 세션 대체 금지. 루프는 최종 status만 본다.
  - chat summary에 retry 한 줄 필수.
- Codex 표현: spawn 인자의 `model` / `reasoning_effort` (role의 Terra/Luna를 이김). **툴에 override 필드가 안 보이면** 이 문서 §8 결정 2.

### A6 — implementer Terra + plan-consultant · **X6**

1. `implementer.toml`: `model = "<Terra id>"`, `model_reasoning_effort = "high"`. `Tier:` 줄 갱신.
2. `plan-consultant.toml` 신규: Sol / high, `sandbox_mode = "read-only"`. Claude 본문 이식(짧은 결정만, 코드 금지, direction 변경 승인 금지).
3. `implement-flow.md` · `worker-contract.md` · `implementer` 본문: detail / **consultable(design-bearing → plan-consultant, `fork_turns="none"`)** / direction 3밴드.
4. implementer가 consultant를 spawn할 수 있는가: Codex는 부모 툴 상속·sandbox 상속. workspace-write implementer가 read-only consultant를 role로 띄우면 자식 sandbox는 role 값. **nesting 한도는 Cursor(2계층)보다 Codex 쪽이 문서상 여유 있으나, 하네스는 main → implementer → consultant 2단만 쓴다.**

### A7 — 리뷰 경로 품질·비용 · **X7**

Claude C8과 동일 묶음, Codex 어휘:

- (a) bug bar · priority · confidence · per-finding block · specificity를 **리뷰어 4종 `developer_instructions`의 `## Reporting contract`** 로 이동. `review-code` dispatch 프롬프트는 참조만. AR suppression은 엔트리 있을 때만 전달(현행 유지).
- (b) stable-first 정렬: 불변 계약 → 준불변(AGENTS 발췌·파일 목록) → 변동(diff).
- (c) 리뷰어는 confidence 붙여 전부 보고, **필터는 Aggregate**.
- (d) maintainability · senior-generalist는 이미 Luna(X1). security · reliability는 Sol 유지.

light 경로에서 (a)(c)(d)가 실제로 값을 낸다 — Codex 기본값이 light이므로 Claude noreview 때보다 **이 커밋의 실사용 비중이 높다.**

### A8 — 런타임 스크립트 설치 · **X8**

- 소스는 이미 `scripts/runtime/detect-commands.sh` · `resolve-scope.sh` (플랫폼 중립, PLAN_CURSOR V4에서 `scripts/claude/` → `runtime/` 개명 완료).
- `apply-to-work.sh`에 블록 추가:

```bash
RUNTIME_SCRIPTS_SOURCE="${SCRIPT_DIR}/../scripts/runtime"
CODEX_SCRIPTS_DIR="${CODEX_HOME}/scripts"
# mkdir -p, 비우기, cp -rp, 요약 한 줄
```

- 소비 스킬 본문: `$HOME/.codex/scripts/detect-commands.sh` · `resolve-scope.sh` 리터럴 호출.
  - `implement-dev` dispatch 프롬프트에 검증 커맨드 블록 주입(절감 1순위).
  - `test-dev` · `review-code` · `fix-dev`도 동일 스크립트 사용.
- Codex에는 `allowed-tools`가 없으므로 권한 프롬프트가 날 수 있다 — **무해한 실패 모드**(PLAN_CURSOR §8 결정 2와 동일 성격).

### A9 — 문서 · 동기화 규칙 · **X9**

| 파일 | 변경 |
| --- | --- |
| `docs/sync-harness/SYNC_TO_CODEX.md` | **Sub-agent migration**에 모델 매핑표 추가: Claude `model`/`effort` → Codex `model`/`model_reasoning_effort`, Sol/Terra/Luna 배치 요약, `ultra` 금지, cascade는 spawn override, Luna 장문맥 금지. Skill 쪽에 description 300자·런타임 스크립트 경로(`$HOME/.codex/scripts/`) 변환 한 줄 |
| `AGENTS.md` §Model Tier | 티어 정의표에 **Codex 열**(Sol / Terra·Luna). 에이전트 배치표에 Codex `model` + `model_reasoning_effort` + `sandbox_mode`. 세션 운용에 Sol xhigh / Luna medium 행. 운용 스위치: Codex `default_subagent_*`는 fallback이라 Claude env 덮어쓰기와 다름을 명시 |
| `AGENTS.md` §Runtime Scripts | 설치 대상에 `~/.codex/scripts/` 추가 (`apply-to-work.sh`) |
| `AGENTS.md` 루프 기본값 | Codex 기본 = **`dev-loop-light`** (Claude·Cursor = noreview) — 이미 서술돼 있으면 에이전트/티어 표와 모순 없는지만 확인 |
| `README.md` | Work 설치(`apply-to-work.sh`) 후 런타임 스크립트·에이전트 9개 확인 한 줄 |

`SYNC_TO_CLAUDE.md`의 역매핑 표(`model` / `model_reasoning_effort` → Claude `model`/`effort`)는 **이미 한 줄 있다** — Codex 슬러그→Claude 별칭 예시를 보강할지는 선택. 필수 범위는 `SYNC_TO_CODEX.md` 쪽.

---

## §6. 하지 않는 것

| 항목 | 판단 |
| --- | --- |
| **`review-code-claude` 변경·삭제** | Codex-only 예외. 이 계획 범위 밖 |
| **`model-pin-guard` / subagentStart 훅** | Codex는 잘못된 effort·미지의 model에서 실패하고 default는 fallback. Cursor 전용 문제 |
| **`ultra` effort** | §4 원칙 3. 금지 |
| **implementer를 Luna로** | MRCR 41.3% 장문맥 절벽. Terra가 정답(§9.6b) |
| **기본값을 `dev-loop-noreview`로** | Codex 경제성상 light가 이미 95% 절감. noreview는 옵션으로만 |
| **Haiku/T3 대응물** | T3 공칸 유지. 기계 일은 셸(X8) |
| **diff-class trivial 축 자동 축소** | PLAN_CLAUDE §6과 같이 보류. light가 이미 2축 |
| **조건부 Implementation Brief** | consultant 부족 증거 나오기 전 보류 |
| **hooks.json을 Cursor 평평 스키마로 "수정"** | Codex 스키마(중첩 `hooks[].hooks[]`)가 맞다. PLAN_CURSOR V3-a 주석은 Cursor 계획 범위의 경고였지 Codex 버그가 아님 |
| **Claude/Cursor 변형 재작성** | 범위 밖. 소스로만 읽는다 |
| **토큰 프로파일 실측** | §10-12. 이 문서 수치는 §9 추정 |

---

## §7. Claude / Cursor 계획과의 관계

| | PLAN_CLAUDE | PLAN_CURSOR | **이 문서** |
| --- | --- | --- | --- |
| 성격 | 1차 적용 (소스 오브 트루스 생성) | 그린필드 포팅 | **기존 변형 델타 동기화 + Codex 티어** |
| 기본 루프 | `dev-loop-noreview` | `dev-loop-noreview` | **`dev-loop-light`** |
| implementer | sonnet / high | grok-4.5[effort=medium] | **Terra / high** |
| T2 bulk | sonnet | composer-2.5[fast=false] | **Luna / high** |
| T1 | opus | grok-4.5[effort=high] | **Sol** |
| 핀 실패 모드 | env 덮어쓰기 | 조용한 폴백 → pin-guard | **에러 또는 fallback(role 우선)** |
| 전역 지침 | `~/.claude/CLAUDE.md` | sessionStart 주입 | **`~/.codex/AGENTS.md` 이미 있음** |
| 변환 문서 | (원본) | `SYNC_TO_CURSOR.md` 신설 | **`SYNC_TO_CODEX.md` 보강** |
| 설치 스크립트 | `apply-to-personal.sh` | `apply-to-cursor.sh` | **`apply-to-work.sh`** |

토폴로지: Personal 중심 Claude → Work 중심 Codex는 **양방향**. 이 계획이 Codex를 Claude 적용분에 맞춘 뒤, 이후 Codex에서만 생긴 변경은 `SYNC_TO_CLAUDE.md`로 되돌린다. **모델 핀 값 자체는 플랫폼 방언이라 숫자/슬러그를 그대로 복사하지 않는다** — 티어 근거(`Tier:` 한 줄)만 공유한다.

---

## §8. 결정 기록

열린 질문은 남기지 않는다. 상위 문서 §10과 Claude/Cursor 계획에서 이미 확정된 것을 Codex에 투영하고, Codex 고유 항목만 여기서 고정한다.

| # | 항목 | 결정 | 영향 |
| --- | --- | --- | --- |
| 1 | 모델 ID 문자열 | ✅ **카탈로그 표시명 Sol/Terra/Luna를 계획의 기준 언어로 쓰고, TOML에는 설치 시점 Codex catalog ID를 기입.** 틀린 ID는 spawn 실패로 드러남 | X1·X6. Cursor와 달리 가드 훅 불필요 |
| 2 | cascade용 spawn model override | ✅ **spawn 인자 `model`/`reasoning_effort`로 1회 Sol 재시도.** 툴 스키마에 필드가 없으면 multi-agent v2 override 노출을 켜거나, 동등한 Sol-pinned 일시 role로 재-spawn | X5. 적용 전 한 번 스모크 |
| 3 | 기본 루프 | ✅ **`dev-loop-light`** (상위 §9.9). noreview는 제공만 | X3 |
| 4 | implementer 모델 | ✅ **Terra / high** (상위 §10-3, §9.6b). cascade 이후(함께) | X5→X6 |
| 5 | tester/fixer | ✅ **custom agent 신설**, built-in worker는 폴백만 | X2 |
| 6 | test suspected defect | ✅ **Fix / Accept + AR** (PLAN_CLAUDE §7 결정 3) | X3b |
| 7 | 런타임 스크립트 | ✅ **공용 `scripts/runtime/` → `~/.codex/scripts/`** (`apply-to-work.sh`) | X8 |
| 8 | `ultra` | ✅ **금지** | 배치표·SYNC·AGENTS |
| 9 | Reporting contract 위치 | ✅ **에이전트 본문** (Claude C8과 동일) | X7 — light 기본값이라 이득이 큼 |
| 10 | description 길이 | ✅ **SYNC 규칙 300자 이내 유지.** Claude description이 길면 Codex에서 축약 | A3·전 스킬 점검 |

**2번의 성격**: Context7 기준 override 필드는 feature 플래그 뒤에 있다. **플래그 없이 호출 인자로 model을 못 넘기면** cascade가 구현 불가능해지므로, X5 착수 전 스모크(더미 spawn 한 번)로 확인한다. 불가면 이 표를 고치고 X5 구현체를 바꾼다 — 추측으로 role 파일을 런타임에 쓰지 않는다.

---

## §9. 검증과 롤백

**적용 후 첫 `dev-loop-light` 1회에서 확인할 것**:

1. **에이전트 9개가 `~/.codex/agents/`에 있고**, 로그·UI에서 implementer가 Terra, 리뷰어 2축이 Luna, (호출 시) planner/consultant/security/reliability가 Sol인지.
2. **`$HOME/.codex/scripts/detect-commands.sh` · `resolve-scope.sh`가 존재하고** implement-dev dispatch가 검증 커맨드를 Worker 프롬프트에 넣는지.
3. **TESTING에서 `TEST-NNN: fix|accept` 텍스트 규약이 도는지**, Accept 시 AR이 기록되는지.
4. **cascade 스모크**: 의도적으로 막히는 픽스처가 없다면, 규칙이 본문에 있고 summary 줄 포맷이 예약돼 있는지로 대체. 실제 발화는 이후 Terra 부족 신호로 관측.
5. **`review-code-claude`가 설치본에 그대로 남아 있는지** (실수로 삭제되지 않았는지).

**주 지표**: 플랜당 remediation 라운드 수 — `docs/agents/dev/*_LOOP_*.md`. Claude 적용 후 기록이 비교 기준. 가능하면 **같은 플랜을 Codex light로 한 번** 돌려 Cursor 계획 §9와 대칭 비교.

**롤백 표**:

| 신호 | 되돌릴 커밋 | 비고 |
| --- | --- | --- |
| remediation 라운드 중앙값 +1 이상 지속 | **X6** (`implementer` model → Sol) | 한 줄. consultant는 유지 가능 |
| cascade 재시도가 실행의 상당 비율 | **X6** | Terra가 이 작업 유형에 부족 |
| instruction drift (AC/TODO 누락) 증가 | **X6** | light는 리뷰 2축만 보므로 IMPL `## TODO Fulfillment`를 사람이 본다 |
| mutation efficacy 하락 · 테스트 약화 | **X2** tester 핀(Luna→Sol) 또는 tester 규칙 | model 한 줄 우선 |
| 보안·신뢰성 결함이 사람 리뷰에서 연속 | **기본값을 `dev-loop`로 상향** (스킬 삭제 아님) | light의 축 선택이 틀린 작업 유형 |
| TESTING 분류 질문이 과도 | **X3b** → Fix/closed 회귀 | 비권장. AR 손실 |
| spawn model override 불가 | **X5 구현 교체** (이 문서 §8 결정 2) | X6 전에 해결 |

**X5는 X6이 살아있는 동안 단독 revert 금지.** cascade가 Terra 하향의 유일한 자동 안전망이다.

---

## §10. 적용 체크리스트 (실행 순서)

저장소 작업은 커밋 단위로, 설치는 마지막에 한 번.

1. [ ] X1 에이전트 6 핀 (+ Tier 줄, 본문 동기화 시작)
2. [ ] X2 tester · fixer + test-dev/fix-dev spawn
3. [ ] X3 light · noreview + mutation opt-out + axis subset
4. [ ] X3b TESTING Fix/Accept 전이표 (dev-loop 3종)
5. [ ] X4 design-bearing 태그
6. [ ] X5 cascade (spawn override 스모크 통과 후)
7. [ ] X6 Terra + plan-consultant + consultable 밴드
8. [ ] X7 Reporting contract · stable-first · Aggregate 필터
9. [ ] X8 `apply-to-work.sh` 런타임 스크립트 + 소비 경로
10. [ ] X9 SYNC_TO_CODEX · AGENTS.md · README
11. [ ] `./scripts/apply-to-work.sh` 실행 → `~/.codex/{skills,agents,hooks,scripts,AGENTS.md,hooks.json}` 확인
12. [ ] 세션 습관: plan-dev = Sol/xhigh, dev-loop* = Luna/medium
13. [ ] 샘플 플랜 1건 `dev-loop-light` 통과

끝.
