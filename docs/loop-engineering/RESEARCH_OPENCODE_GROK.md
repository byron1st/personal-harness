# NEXT_HARNESS — Meta-Prompting & Loop Engineering (OpenCode)

> 아카이브 안내: OpenCode 실행 변형은 2026-07-23에 지원 대상에서 제거되었다. 이 문서는 당시의 조사·설계 근거를 보존하며 현재 구현 지침으로 사용하지 않는다.

조사·해석·설계 방향 메모. OpenCode 변형(`skills/opencode/`, `agents/opencode/`, `hooks/opencode/`)을 기준으로 한다. 구현 스펙이 아니라 다음 하네스 개선의 근거 문서다.

- 작성 기준일: 2026-07-21
- 저장소: personal-harness (personal)
- 범위: 메타 프롬프팅, 루프 엔지니어링, 현재 코어 개발 체인과의 매핑, 개선 방향

---

## 1. 목표

개인 하네스에 다음 두 개념을 적용한다.

1. **메타 프롬프팅** — `plan-dev`를 사용자 Q&A로 **구현용 실행 프롬프트(PLAN + RESEARCH)** 를 컴파일하는 단계로 다듬는다. 산출물은 루프 입력이므로 **제약(Constraints)** 과 **완료 조건(DoD / verify)** 에 집중한다.
2. **루프 엔지니어링** — `implement-dev → (fix-dev) → test-dev → review-code → (fix-dev)` 체인을 상태·센서·재진입·탈출 조건이 있는 **how-loop** 로 승격한다.

`review-code`에서 CRITICAL/HIGH가 나와도 항상 결함은 아니다. **의도·제약으로 수용**할 수 있어야 하고, 수용 항목은 `AGENTS.md`(및 legacy `CLAUDE.md`)에 남겨 이후 리뷰에서 재검출되지 않게 한다.

---

## 2. 메타 프롬프팅 — 조사 요약

### 2.1 학술·기법 축

| 계열 | 핵심 | 대표 |
| --- | --- | --- |
| Structure-oriented Meta Prompting | 내용 few-shot이 아니라 과제 **형식·문법·분해 구조**를 프롬프트로 고정 | Zhang et al., *Meta Prompting for AI Systems* (arXiv:2311.11482, v9 2025-12) |
| Recursive Meta Prompting (RMP) | LLM이 자기 프롬프트를 생성·정제하는 자기개선 루프 | 동일 논문 |
| Automatic Prompt Engineer (APE) | 후보 instruction 생성 → 평가 → 선택 | Zhou et al., 2022 |
| OPRO / DSPy / GEPA | 프롬프트를 손으로 쓰지 말고 프로그램+메트릭으로 컴파일 | DSPy 3.x, GEPA (2025) |

공통 메시지:

- 좋은 메타 프롬프트는 토큰 효율과 내용 예시 의존도 감소를 동시에 노린다.
- 산출물은 “더 똑똑한 한 줄”이 아니라 **구조화된 실행 계약**(입력/출력, 제약, 완료 조건, 평가 기준).

참고:

- [Prompt Engineering Guide — Meta Prompting](https://www.promptingguide.ai/techniques/meta-prompting)
- [Prompt Engineering Guide — APE](https://www.promptingguide.ai/techniques/ape)
- [DSPy](https://dspy.ai/)

### 2.2 실무 축 (2025–2026 coding agent)

코딩 에이전트 현장에서 메타 프롬프팅은 거의 항상 아래로 수렴한다.

1. 대화로 의도 정제 (human ↔ planner)
2. 실행 가능한 스펙/프롬프트 산출 (constraints + acceptance + non-goals)
3. cold worker가 그 문서만 보고 구현 (세션 기억 없음)

Anthropic 권장과도 정렬된다.

- Explore → Plan → Code 분리 ([Claude Code best practices](https://www.anthropic.com/engineering/claude-code-best-practices))
- 검증 가능한 완료 조건 (“looks done” 금지; test/build/screenshot 등 pass/fail)
- Long-running harness: feature list·progress·clean git state ([Effective harnesses for long-running agents](https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents))

**실무 정의 (이 문서 기준):**

> 메타 프롬프팅 = cold executor가 방향을 재결정하지 않도록, 제약·완료조건·비목표를 단단히 박은 **실행 프롬프트 아티팩트**를 만드는 일.

---

## 3. 루프 엔지니어링 — 조사 요약

“Loop Engineering”은 단일 표준 용어라기보다, 루프를 설계 대상으로 삼는 흐름의 상위 묶음이다.

### 3.1 Anthropic — Building Effective Agents

- Workflow vs Agent 구분; production은 대개 혼합.
- **Evaluator–Optimizer**: generator ↔ evaluator 피드백 반복. 평가 기준이 명확하고 피드백이 품질을 올릴 때 적합.
- Agents ≈ tool + environment feedback **in a loop**.
- 원칙: 단순성, 계획 투명성, tool/ACI 문서화.

출처: [Building effective agents](https://www.anthropic.com/engineering/building-effective-agents)

### 3.2 Thoughtworks — Humans on the loop / Harness engineering

- **Why loop**: idea ↔ working software (인간)
- **How loop**: specs/code/tests 중간 산출물 반복 (에이전트)
- 인간은 in-the-loop(줄 검수)보다 **on-the-loop**(하네스 설계·튜닝)
- Harness = **Guides (feedforward)** + **Sensors (feedback)**
  - Computational: lint, test, type, arch unit
  - Inferential: review agent, LLM-as-judge
- 반복 실패 시 산출물만 고치지 말고 **하네스를 고친다** (steering loop / flywheel)

출처:

- [Humans and Agents in Software Engineering Loops](https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html)
- [Harness engineering for coding agent users](https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html)

### 3.3 Ralph loop (Huntley)

```bash
while :; do cat PROMPT.md | claude-code ; done
```

원칙: 루프당 한 일, 매 루프 동일 스펙/플랜 스택, backpressure(test/build), 실패 시 프롬프트 튜닝, progress를 디스크에 남겨 컨텍스트 브릿지.

출처: [Ralph Wiggum as a "software engineer"](https://ghuntley.com/ralph/)

### 3.4 Long-running agent harness (Anthropic)

| 실패 모드 | 대응 |
| --- | --- |
| 한 번에 너무 많이 함 | feature list + one unit/session |
| 조기 완료 선언 | passes=false 목록 + 엄격한 완료 규칙 |
| dirty handoff | git commit + progress file |
| 테스트 없이 done | e2e/browser 등 강제 검증 |

### 3.5 관련 인접 개념

- **Context engineering**: 에이전트에 넣는 전체 맥락(시스템 프롬프트, 도구 설명, 메모리, 제약) 설계. 하네스 엔지니어링의 수단.
- **LangChain 관점**: 신뢰성의 핵심은 매 스텝 LLM에 **올바른 컨텍스트**가 들어가는지. 추상화가 그걸 가리면 해가 된다.

**실무 정의 (이 문서 기준):**

> 루프 엔지니어링 = 에이전트 실행을 상태 머신으로 설계하고, 각 단계의 **입력 계약 · 검증 센서 · 재진입/탈출 조건 · 산출물 핸드오프**를 명시하는 일.

---

## 4. OpenCode 하네스 현황

### 4.1 코어 체인 (README)

```
plan-dev → implement-dev → (fix-dev)* → test-dev → review-code → (fix-dev)* → commit-code → request-merge
```

### 4.2 구성요소 맵

| 구성요소 | OpenCode 위치 | 역할 |
| --- | --- | --- |
| `plan-dev` | `skills/opencode/plan-dev/` | Q&A + 방향 잠금 + PLAN/RESEARCH persist |
| `planner` | `agents/opencode/planner.md` | 아키텍처 렌즈, read-only |
| `implement-dev` + `implementer` | skill + agent | TDD 실행 Worker (cold handoff) |
| `fix-dev` | skill | 리뷰/검증 결함 단일 이슈 수정 |
| `test-dev` | skill | unit → e2e → mutation 센서 강화 |
| `review-code` + 4 reviewers | skill + agents | 병렬 inferential sensor |
| hooks | `hooks/opencode/personal-harness.js` | rg/fd 강제, git identity, session context 등 환경 가드 |

### 4.3 이미 강한 점

- cold-handoff: `Non-goals`, `Key decisions`, research ↔ TODO 양방향 태깅
- Dispatcher / Worker 분리 + fixed-heading return
- direction vs detail 에스컬레이션
- review 4축 병렬 (security / reliability / maintainability / senior-generalist)
- test-dev mutation efficacy 목표(≥80%)
- fix-dev의 Implementation Report `## Fix` 누적, 메인 세션 컨텍스트 오염 방지

### 4.4 아직 루프가 아닌 점

- 체인이 **수동 호출 시퀀스** (자동 전이·중단 조건 없음)
- PLAN의 완료 조건이 **기계 판정 gate**로 약함
- outer loop controller(오케스트레이터 스킬) 부재
- review CRITICAL/HIGH → 무조건 fix 가정이 실무(의도적 수용)와 불일치

---

## 5. 해석 A — 메타 프롬프팅 as `plan-dev`

### 5.1 기능적 동일성

`docs/agents/dev/*_PLAN_*.md` + `docs/agents/research/*` 는 학술 메타 프롬프팅의 “구조화 프롬프트”와 **기능적으로 동일**하다. cold Worker 전제에서 PLAN은 문서가 아니라 **실행 프롬프트 아티팩트**다.

| 메타 프롬프팅 요소 | 현재 plan-dev |
| --- | --- |
| 구조 템플릿 | frontmatter + research links + TODOs + Non-goals/Key decisions |
| 내용보다 형식 | 계획 granularity 낮춤, research에 깊이 |
| 사용자 Q&A로 의도 정제 | steps 3, 5, 8, 9 |
| cold executor 가정 | cold hand-off gate (step 8) |
| 산출 분리 | research(사실) vs plan(방향) |

### 5.2 루프 입력으로 쓰기 위해 강화할 초점

개선 중심은 “더 긴 계획”이 아니라 **루프 게이트 품질**이다.

1. **Constraints (hard)** — 위반 시 Worker가 `blocked` 할 수 있는 절대 제약 목록을 1급 블록으로.
2. **Completion criteria / Verify** — TODO 또는 plan 말미에 기계 가능 조건:
   - `Verify:` Makefile/명령
   - `Done when:` 관측 가능 조건
   - `Do not mark done if:` 부정 조건
3. **Loop exit / DoD** — implement 루프를 멈추고 test/review로 넘길 조건.
4. **Scope budget** — 한 루프(또는 한 STEP) 분량 상한; multi-step와 정렬.
5. **Handoff packet gate** — research 없이 방향 재추론 필요 시 fail; non-trivial에 Non-goals/Key decisions 필수; TODO별 verify/research 힌트.

### 5.3 재프레이밍

```
사용자 의도
  → (Q&A) 가정/경계/트레이드오프 잠금
  → RESEARCH = 현재 코드 사실 (context pack)
  → PLAN = 실행 프롬프트
        - Goal
        - Constraints (hard)
        - Key decisions (chosen + rejected)
        - Non-goals
        - TODOs (outcome + research pointer + verify)
        - Loop exit / DoD
  → implement-dev Worker 입력
```

성공 지표 (문서 미학이 아님):

- Worker `blocked`(direction) 비율 ↓
- fix-dev 재진입 횟수 ↓
- review CRITICAL/HIGH 중 실결함 비율 및 수용 후 재발 ↓
- “계획과 다른 방향 구현” 사고 ↓

---

## 6. 해석 B — 루프 엔지니어링 as 구현 체인

### 6.1 단계별 역할

| 단계 | 루프 역할 | Feedforward | Feedback sensor |
| --- | --- | --- | --- |
| `implement-dev` | generator (inner coding loop) | PLAN/RESEARCH, conventions, TDD | unit/lint/build |
| `fix-dev` | local optimizer | defect brief + report path | repro + regression test |
| `test-dev` | computational sensor 강화 | git scope | unit/e2e/mutation |
| `review-code` | inferential sensor (4축) | diff + AGENTS | finding priority |
| hooks | ambient harness | session context, rg/fd, identity | block bad commands |

Anthropic 패턴 대응: implement = coding agent, test+hooks = computational evaluator, review = parallel inferential evaluator, fix = optimizer branch, plan = initializer / prompt compiler.

### 6.2 권장 상태 머신

```
PLANNED → IMPLEMENTING → TESTING → REVIEWING → READY_TO_COMMIT
                │              │           │
                │              │           ├─ fix 선택 항목 → FIXING → (TESTING subset) → REVIEWING
                │              │           └─ accept 항목 → AGENTS.md 기록 후 재평가
                ├─ direction conflict → BLOCKED_DIRECTION → human / plan-dev
                └─ irrecoverable → FAILED → human
```

전이 조건 (초안):

- IMPLEMENTING → TESTING: Implementation Status=`pass`, plan TODOs 모두 `[x]`, PLAN DoD verify 통과
- TESTING → REVIEWING: suite 차단 실패 없음; suspected defects는 review 입력으로 승격 가능
- REVIEWING → 사용자 분류(CRITICAL/HIGH만): 아래 §7
- REVIEWING → READY: blocking finding 없음 **또는** 남은 blocking이 모두 accept 처리됨
- 어디서든 direction conflict → BLOCKED (자동 재계획 금지 또는 명시적 plan-dev 재진입)
- max iterations (예: fix 3, review–fix 2) 후 human escalate

### 6.3 핸드오프 아티팩트

이미 있음: PLAN checkboxes, IMPL report + `## Fix`, Worker fixed headings, review findings.

루프화 시 추가 후보:

- IMPL report 내 `## Loop State` 또는 `*_LOOP_*.md`
  - current stage, iteration counts, last sensor results, open decisions, accepted findings refs

원칙: 오케스트레이터도 **요약을 컨텍스트에 쌓지 말고 디스크 상태를 source of truth**로 유지 (현 Dispatcher/Worker 설계와 정렬).

### 6.4 최소 토폴로지

```
              plan-dev (meta prompt compiler)
                      │
                      ▼
              implement-dev (Worker)
                 │ pass          │ blocked
                 ▼               ▼
              test-dev      human / plan-dev
                 │
                 ▼
              review-code
                 │
        CRITICAL/HIGH?
           │ no              │ yes
           ▼                 ▼
        READY          사용자 분류
                      ├─ fix → fix-dev → re-test → review
                      └─ accept → AGENTS.md → READY 또는 잔여 fix만 처리
```

기본은 **결정적 workflow + 국소 agent loop**. multi-agent mesh는 비목표.

---

## 7. review-code 특별 규칙 — 의도적 수용 (Accepted Findings)

### 7.1 문제

HIGH/CRITICAL이어도 **의도된 사항**인 경우가 있다. 예: 보안 위험을 알지만 외부 제약으로 당장 제거 불가. 이를 무조건 fix 큐에 넣으면 루프가 멈추거나 잘못된 “수정”을 만든다.

### 7.2 규칙

1. **Blocking finding ≠ 자동 수정.** `Incorrect`는 “사람 판단 필요”이지 “무조건 fix”가 아니다.
2. CRITICAL/HIGH가 하나라도 있으면 **사용자에게 항목별 분류**를 묻는다 (question tool).
   - `fix` — 이번 루프에서 수정
   - `accept` — 의도/제약으로 수용하고 문서화
   - (선택) `defer` — 정책으로 도입 여부 결정; 기본안에서는 fix/accept 이원으로도 충분
3. `fix`만 `fix-dev` brief 큐로 보낸다. **auto-fix 금지.**
4. `accept` 항목은 프로젝트 **`AGENTS.md`** 에 기록한다. legacy **`CLAUDE.md`** 가 있으면 동일 규칙을 맞춘다.
5. 이후 `review-code` gather 단계에서 이 기록을 읽어 dispatch prompt에 넣고, reviewer bug bar에 **명시적 Accepted 항목은 finding으로 내지 말 것**을 추가한다. Location+축 겹치면 drop.

### 7.3 기록 포맷 (초안)

`AGENTS.md` 권장 섹션:

```markdown
## Accepted Review Findings

- [security] `path/to/file:symbol` — {의도/제약 한 줄}. Accepted: YYYY-MM-DD. Scope: {이 패턴 또는 이 위치만}.
```

필드 최소셋: 축(priority axis), location, 한 줄 근거, 날짜, scope(과잉 억제 방지).

### 7.4 루프 탈출과의 관계

- accept만 남고 fix 큐가 비면 → `Correct (with accepted risks)` 로 READY.
- fix 큐가 있으면 → FIXING → 검증 → review 재진입.
- PLAN Constraints에 알려진 수용 리스크를 미리 넣을 수 있으나, **타임 신규 발견의 source of truth는 **review 게이트 + AGENTS.md 기록**이다.

### 7.5 plan-dev / 메타 프롬프팅 연결

- 이미 AGENTS.md에 Accepted가 있으면 plan 단계 research/constraints에 반영 가능 (중복 논쟁 방지).
- 다만 “리뷰에서 새로 수용”은 review 스킬의 책임으로 남긴다.

---

## 8. 결합 모델 (목표 아키텍처)

```
[Human Why-loop]
   의도, 취향, 제품 판단
        │
        ▼
[Meta-prompting = plan-dev]
   Q&A로 제약/완료조건 컴파일
   RESEARCH + PLAN (실행 프롬프트)
        │
        ▼
[Loop engineering = how-loop]
   implement ⇄ (test/review sensors) ⇄ fix
   review CRITICAL/HIGH → 사용자 분류 → fix | accept→AGENTS
   디스크 아티팩트가 상태의 source of truth
        │
        ▼
[Human on-the-loop]
   반복 실패 → 스킬/컨벤션/훅(하네스) 개선
   learn-from-manual-edits ≈ steering 보조
```

| 개념 | 하네스에서의 역할 |
| --- | --- |
| 메타 프롬프팅 | 루프가 방황하지 않게 하는 **feedforward** (PLAN 품질) |
| 루프 엔지니어링 | 잘못된 산출을 사람 전에 걸러내는 **feedback + 재시도 규율** |
| 하네스 엔지니어링 | 둘을 스킬/에이전트/훅으로 고정하는 상위 실천 (이 repo의 존재 이유) |

---

## 9. 갭과 우선순위

| 우선 | 갭 | 왜 중요한가 |
| --- | --- | --- |
| P0 | PLAN에 **Constraints + machine-checkable DoD** 부족 | 루프 입력 계약이 약하면 implement/review가 방향 재해석 |
| P0 | review CRITICAL/HIGH의 **사용자 분류 + accept→AGENTS** 부재 | 의도적 리스크와 실결함 구분 불가; 잘못된 자동 fix |
| P0 | 체인에 **자동 전이/중단 조건** 없음 | 루프가 아닌 체크리스트 |
| P1 | stage 간 **표준 상태 객체** 없음 | orchestrator 추가 시 파싱 비용·불일치 |
| P1 | `fix` 선택 finding → fix-dev brief **기계적 변환** | evaluator-optimizer 연결이 사람 손 |
| P2 | multi-step plan과 루프 iteration 단위 정렬 | “한 루프 = 한 STEP” 문서화 시 안정성↑ |
| P2 | `learn-from-manual-edits`와 루프 실패 로그 연결 | on-the-loop flywheel |

---

## 10. 구현 시 손댈 OpenCode 표면 (가이드)

구현 착수 시 건드릴 후보. 이 문서만으로 구현을 시작하지 말고, 별도 plan-dev로 쪼갠다.

### 10.1 메타 프롬프팅 (`plan-dev`)

- `skills/opencode/plan-dev/SKILL.md` — Constraints/DoD/cold-handoff gate 강화
- `references/single-step-plan.md`, `multi-steps-plan.md` — 템플릿 앵커 추가
- `agents/opencode/planner.md` — 제약·완료조건·수용 리스크를 질문 렌즈에 포함

### 10.2 루프 부품

- `implement-dev` — PLAN DoD verify를 final verification 필수 집합에 결합; return에 Next Stage 힌트
- `fix-dev` — review finding brief 입력 형식 공식화
- `test-dev` — suspected defects를 다음 stage 입력으로 넘기는 계약
- `review-code` — CRITICAL/HIGH 사용자 분류; Accepted Review Findings 읽기/쓰기; accept 억제를 dispatch bug bar에 포함
- (신규 후보) `run-dev-loop` 또는 동등 outer skill — 상태 머신 + max-iter + 사람 게이트

### 10.3 에이전트·훅

- 4 reviewers — Accepted 목록 defer 규칙
- `hooks/opencode/personal-harness.js` — 당장은 stage gate 필수 아님; 환경 센서 유지. 필요 시 이후 stage gate 스크립트 확장

### 10.4 플랫폼 동기화

Personal 중심은 Claude → OpenCode 파생. OpenCode에서 확정한 뒤 `SYNC_TO_*` / `sync-harness`로 Claude·Codex에 반영하는 순서를 권장 (또는 Claude를 먼저 고치고 OpenCode로 내릴지 정책에 따름). 이 문서는 OpenCode 기준 설계 메모다.

---

## 11. 결론

1. **메타 프롬프팅**의 2026 실무 정의는 문구 미학이 아니라 **cold executor용 구조화 실행 계약 생성**이다. 현재 `plan-dev`의 PLAN/RESEARCH가 그 자리이며, 다음 개선은 **제약·완료조건** 집중이다.
2. **루프 엔지니어링**은 while-true가 아니라 **상태·센서·재진입·탈출이 있는 how-loop 설계**다. implement→fix→test→review 부품은 이미 있고, **오케스트레이션·게이트·review 수용 분기**가 부족하다.
3. **review-code**는 CRITICAL/HIGH에서 멈추고 사용자에게 **fix vs accept**를 물으며, accept는 **AGENTS.md(및 CLAUDE.md)에 남겨 다음 리뷰를 억제**한다. 자동 fix는 하지 않는다.
4. 다음 하네스의 두 줄 방향:
   - `plan-dev` → 루프 입력 프롬프트 컴파일러
   - 구현 체인 → 게이트 있는 상태 머신 (review 의도 수용 포함)

---

## 12. 참고 링크

- Zhang et al., Meta Prompting — https://arxiv.org/abs/2311.11482
- Prompting Guide, Meta Prompting — https://www.promptingguide.ai/techniques/meta-prompting
- Prompting Guide, APE — https://www.promptingguide.ai/techniques/ape
- Prompting Guide, Context Engineering — https://www.promptingguide.ai/agents/context-engineering
- Anthropic, Building effective agents — https://www.anthropic.com/engineering/building-effective-agents
- Anthropic, Effective harnesses for long-running agents — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- Anthropic, Claude Code best practices — https://www.anthropic.com/engineering/claude-code-best-practices
- LangChain, How to think about agent frameworks — https://blog.langchain.com/how-to-think-about-agent-frameworks/
- Martin Fowler / Kief Morris, Humans and Agents in SE Loops — https://martinfowler.com/articles/exploring-gen-ai/humans-and-agents.html
- Birgitta Böckeler, Harness engineering — https://martinfowler.com/articles/exploring-gen-ai/harness-engineering.html
- Geoffrey Huntley, Ralph — https://ghuntley.com/ralph/
- DSPy — https://dspy.ai/
