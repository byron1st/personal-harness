# UPGRADE_HARNESS_PLAN.md — 메타프롬프팅 & 루프 엔지니어링 적용 실행 계획

이 문서는 personal-harness에 메타프롬프팅과 루프 엔지니어링을 적용하는 **실행 계약이자 진행 추적 문서**다. 조사 근거는 [NEXT_HARNESS_CLAUDE.md](NEXT_HARNESS_CLAUDE.md), [NEXT_HARNESS_CODEX.md](NEXT_HARNESS_CODEX.md), [NEXT_HARNESS_OPENCODE_GROK.md](NEXT_HARNESS_OPENCODE_GROK.md) 3개 문서이며, 이 계획은 세 문서의 통합·조정 결과다. 이 문서만 읽고 작업을 이어갈 수 있도록 작성되었다 — 이전 대화의 기억은 필요 없다.

- 작성일: 2026-07-21 (사용자 승인 동일)
- 브랜치: `feature/next-harness`
- 개발 기준: Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)에서 구현 후 sync-harness로 Codex/OpenCode 전파 (Claude-first, OpenCode는 target-only)

## Resume Protocol (중단 후 재개 방법)

1. 아래 **Progress Dashboard**에서 `in-progress` 또는 첫 `todo` Phase를 찾는다. **Progress Log**의 마지막 엔트리에서 직전 세션의 중단 지점과 편차를 확인한다.
2. §1 **확정된 결정 사항**은 재논의하지 않는다. 대안을 다시 검토하고 싶은 충동이 들면, 그 대안은 이미 §1의 "기각" 열에서 사유와 함께 기각된 것인지 먼저 확인한다.
3. 해당 Phase 섹션(§3)을 읽고, 태스크가 가리키는 대상 파일을 읽은 뒤 작업한다. 미체크 태스크 중 ID 순서가 빠른 것부터 진행한다.
4. **마킹 규칙**: 태스크 체크박스는 완료 즉시 `- [ ]` → `- [x]`로 flip한다(batch 금지 — implement-dev와 동일 규칙). Phase의 첫 태스크에 착수하면 Dashboard 상태를 `in-progress`로, 모든 태스크 완료 + 완료 기준 충족 시 `done`으로 갱신한다.
5. 세션을 마치기 전(또는 예산 소진이 예상되면 즉시) **Progress Log**에 엔트리를 append한다: 날짜, 완료한 태스크 ID, 결정·편차, 다음 세션의 시작점 한 줄. 기존 엔트리는 수정하지 않는다.
6. 각 Phase 완료 시점은 커밋 단위로 적합하다. 커밋은 사용자 확인 후 commit-code로 진행한다.

## Progress Dashboard

| Phase | 내용 | 상태 | 비고 |
| --- | --- | --- | --- |
| P0 | 사전 정합성 정리 | done | |
| P1 | plan-dev 메타프롬프팅 강화 | todo | |
| P2 | 공통 단계 결과 계약 정렬 | todo | |
| P3 | review-code 트리아지 + Accepted Review Exceptions | todo | |
| T1 | 1차 변형 전파 (P0~P3 범위) | todo | |
| P4 | dev-loop 컨트롤러 스킬 신설 (MVP) | todo | |
| P5 | 계측과 튜닝 | todo | |
| T2 | 2차 변형 전파 + 문서 마감 | todo | |
| P7 | 후속 확장 (multi-step 외곽 루프 / flywheel / 무인 모드) | on-hold | 착수 자체가 별도 사용자 결정 |

상태 값: `todo`(미착수) / `in-progress`(진행 중) / `done`(완료 기준 충족) / `on-hold`(보류) / `skipped`(사유와 함께 건너뜀).

---

## 1. 확정된 결정 사항 (재논의 금지)

세 조사 문서가 같은 것을 다른 이름·방식으로 제안한 지점들의 통합 결정. 2026-07-21 사용자 승인.

| 항목 | 확정안 | 기각된 대안과 사유 |
| --- | --- | --- |
| 컨트롤러 스킬 이름 | `dev-loop` (3플랫폼 동일) | `loop-dev`, `run-dev-loop` — 플랫폼 간 이름 불일치 방지 |
| 플랜 완료 조건 섹션 | `## Acceptance Contract` — `\| ID \| Observable condition \| Evidence \|` 테이블(AC-1, AC-2…), 선택 열 `Do not mark done if` | `## Completion Criteria`, `Loop exit / DoD` — CODEX 안이 가장 구체적 |
| 플랜 권한·중단 섹션 | `## Authority Boundaries` — 구현자 재량 / 사용자 확인 없이 변경 금지 / 중단 조건 / 루프 예산(remediation rounds 기본 3) | `## Budget & Escalation`, `Constraints (hard)` — Authority Boundaries의 하위 항목으로 흡수 |
| 일반 검증 명령의 위치 | 플랜에 **복제하지 않음** — lint/unit/e2e/build는 구현 시점에 Makefile/AGENTS.md/CLAUDE.md/README.md에서 재발견(기존 Prepare 유지). AC에는 저장소가 자동으로 알려줄 수 없는 작업 특화 결과·증거만 기록 | CLAUDE 문서의 "검증 명령을 플랜에 고정" — 명령 drift 위험으로 폐기 |
| 공통 반환 헤딩 | `## Stage Status` / `## Evidence` / `## Findings` / `## Decision Needed` — 모든 Worker 반환의 맨 앞 공통 블록, 기존 스킬별 헤딩은 그 아래 유지 | 스킬별 상이한 상태 헤딩 유지 — 컨트롤러 파싱 단일화를 위해 통일 |
| 상태 어휘 | `pass \| blocked \| failed \| needs-confirmation \| needs-decision \| changes-required` — 각 스킬은 자기에게 적용되는 부분집합만 사용, 필드명·의미는 동일 | — |
| review-code 상태 | `pass \| needs-decision \| changes-required` 3상태. 사람이 읽는 verdict 문장은 유지, `Correct (with accepted risks)` 표현 추가 | `Correct/Incorrect` 이분법 — triage 개념을 담지 못함 |
| 수용 예외 섹션명 | `## Accepted Review Exceptions` (AR-001, AR-002…) | `Accepted Risks (Review Waivers)`, `Accepted Review Findings` — 3플랫폼 리뷰어가 같은 섹션명을 찾아야 함 |
| AR 기록 위치 | **단일 사본**: 대상 레포의 `AGENTS.md` 우선, 없으면 `CLAUDE.md`. 영향 코드에 가장 가까운(가장 좁은 범위의) 지침 파일 우선 | CODEX 문서의 이중 기록(AGENTS.md와 CLAUDE.md 양쪽) — drift 위험, 3플랫폼 review-code가 어차피 양쪽을 읽으므로 단일 사본으로 충분 |
| AR 엔트리 형식 | Applies to / Original severity / Accepted behavior / Rationale / Compensating controls / Re-open when / Approved (CODEX §9.4 형식). 비밀값·자격증명·공격 payload 기록 금지 | 축약 형식(한 줄) — 재검토 조건과 보완 통제 없이는 waiver rot 방지 불가 |
| AR 매칭·강등 | 억제 4조건(파일·심볼·동작 범위 정확 일치 ∧ 전제·보완 통제 유효 ∧ 영향 미확대 ∧ Re-open when 미충족) 모두 충족 시에만 억제. 억제는 **은폐가 아니라 강등** — verdict 계산에서만 제외하고 `## Applied Exceptions`에 AR ID로 상시 표시 | 조용한 삭제 — comprehension debt, 재검토 조건 발동 감지 불가 |
| finding ID | `REVIEW-NNN`은 aggregate 시 **메인 세션이 부여**(reviewer는 기존 형식 유지), 그 외 `AC-N`, `AR-NNN`, `TEST-NNN` | reviewer 자체 부여 — 4축 병렬 실행이라 중복 위험 |
| fix 후 재진입 순서 | `fix-dev → test-dev(축소 스코프) → review-code` — 프로덕션 수정은 이전 테스트·리뷰 증거를 무효화 | `fix → review`만 재실행 — 증거 무효화 누락 |
| 재진입 test-dev 스코프 | 변경 파일 대상 unit/e2e만, mutation은 기본 생략하고 최종 라운드에만 실행 | 매 라운드 full 3-phase — 과비용 |
| 루프 상태 파일 | `docs/agents/dev/{timestamp}_{Jira}_LOOP_{title}.md` — PLAN/IMPL과 stem 공유, append-only, 체크포인트 최소 필드만(원시 대화·diff·테스트 원문 복제 금지) | IMPL 리포트 내 섹션 — 리포트 비대화 |
| planner 활용 | 두 접점: ① Research 단계(step 4) 조건부 dispatch — 아키텍처 뷰 + **사용자에게 물을 질문 목록 반환**(서브에이전트는 AskUserQuestion 불가, 인터뷰는 메인 세션 소유), ② Review 단계(step 8) 플랜+AC 검토(플랜의 maker-checker). trivial 작업은 양쪽 모두 생략. dev-loop 본문에는 planner 없음 — BLOCKED_DIRECTION으로 plan-dev 재진입 시에만 재관여 | planner가 인터뷰 진행 — 서브에이전트는 사용자와 직접 대화 불가하므로 구조적으로 불가능 |
| 개발·전파 순서 | Claude-first 구현 → sync-harness로 전파, 전파는 2회(T1: P0~P3 후, T2: P4~P5 후) | OpenCode-first(OPENCODE 문서 제안) — sync-harness 토폴로지상 OpenCode는 target-only라 소스 불가 |
| NORMAL/LOW finding | 보고하되 완료 판정 비차단, 자동 수정 대상 아님 | — (3문서 합의) |

**불변식 (모든 플랫폼 공통, 모든 Phase에서 유지):** ① AR 작성은 사용자의 명시적 Accept 응답이 있을 때만 — 스킬·에이전트·루프가 추론으로 수용하거나 스스로 기록하는 것 금지(수정 대신 면제하는 reward hacking 차단, "never weaken tests"와 동급 규칙), ② 테스트 약화 금지 유지, ③ 커밋·푸시·PR/MR 생성은 루프 권한 밖, ④ 플랜의 방향(goal/approach/Key decisions/Non-goals) 변경은 루프 안에서 불가 — plan-dev 재진입, ⑤ 훅은 가드레일로만, 루프 오케스트레이션 불참, ⑥ 상태의 source of truth는 디스크(LOOP 파일·플랜 체크박스·IMPL 리포트), ⑦ 플랜 본문 granularity(coarse, outcome-level)는 불변 — 강화 대상은 경계(AC·Authority Boundaries)뿐, ⑧ 기존 스킬을 하나의 거대 스킬로 병합하지 않고 새 persona 에이전트를 만들지 않는다, ⑨ **단독 사용 보장** — P1~P3의 스킬 계약 변경은 dev-loop 없는 단독 호출에서도 그대로 동작해야 하며, 새 섹션·필드가 없는 입력(legacy 플랜, 지침 파일 없는 레포, finding ID 없는 brief)에는 실행 거부가 아니라 정의된 우아한 강등(graceful degradation) 경로를 둔다.

---

## 2. 목표 아키텍처

```
plan-dev (메타프롬프팅 컴파일러)
  인터뷰(메인 세션) + planner 접점 ①② → PLAN(방향 + Acceptance Contract + Authority Boundaries) + RESEARCH(컨텍스트 팩)
        │ 승인 (ExitPlanMode / plan approval / plan_exit)
        ▼
dev-loop (얇은 컨트롤러 스킬 — 기존 스킬 호출과 상태 전이만 담당)
  PLANNED → IMPLEMENTING → TESTING → REVIEWING → READY_TO_COMMIT
     │            │            │          ├─ needs-decision → 사용자 triage
     │            │            │          │     ├─ Fix → FIXING → TESTING(축소) → REVIEWING
     │            │            │          │     └─ Accept → AR 기록(인간 승인) → 재평가
     │            │            │          └─ changes-required → FIXING
     │            ├─ direction conflict → BLOCKED_DIRECTION → 인간/plan-dev
     │            └─ 3회 실패/예산 소진/no-progress → FAILED/ESCALATED → 인간
        ▼
READY_TO_COMMIT에서 정지 → 인간이 IMPL 리포트·LOOP 파일 확인 → commit-code / request-merge (루프 밖)
```

**종료 술어** (모두 충족 시 READY_TO_COMMIT): ① 플랜 TODO 전부 `[x]`, ② 모든 AC에 검증 증거 연결, ③ implement-dev `pass` + IMPL 리포트 저장, ④ 재발견된 일반 게이트(lint/unit/e2e/build) green, ⑤ test-dev `pass`(의심 결함 없음; mutation은 정책 임계값 충족 또는 실행 불가 사유 명시 승인), ⑥ 미분류(needs-decision)·fix-분류 HIGH/CRITICAL 0건, ⑦ accept 항목 전부 AR로 기록됨, ⑧ 미해결 `Decision Needed`/`needs-confirmation` 없음, ⑨ LOOP 파일에 최종 상태·증거 기록됨.

**중단·에스컬레이션**: 각 스킬의 기존 동일 오류 3회 제한 유지, 전체 remediation rounds ≤ 플랜 Authority Boundaries 값(기본 3), 동일 차단 finding 2라운드 연속 잔존 또는 차단 finding 수 미감소 = no-progress 중단, 어떤 단계든 `blocked`/`needs-confirmation`/`Decision Needed` = 즉시 정지 후 인간, 외부 변경·파괴적 작업·범위 확대 필요 = Authority Boundaries에 따라 승인 요청.

---

## 3. Phase별 태스크

### P0 — 사전 정합성 정리

루프가 올라가기 전에 기존 계약 충돌(NEXT_HARNESS_CODEX.md §6.1 진단)을 제거한다.

- [x] **P0-1** [agents/claude/implementer.md](agents/claude/implementer.md): "The one check"(단일 검증, per-function suite 금지)와 implement-dev의 TDD Red-Green-Refactor 규칙 간 우선순위 절 추가 — "dispatch prompt가 스킬(예: implement-dev)을 지정하면 그 스킬의 테스트·검증 규칙이 The one check보다 우선한다".
- [x] **P0-2** [skills/claude/plan-dev/references/single-step-plan.md](skills/claude/plan-dev/references/single-step-plan.md): Jira 규칙에 세션 컨텍스트 연결 — personal repo로 분류된 세션에서 branch에 Jira 키가 없으면 `NO-JIRA`를 기본 제안(확인 질문 1회 생략 가능).
- [x] **P0-3** 세 변형의 review-code/test-dev/fix-dev 상태 어휘 현황 목록화(조사만, 수정은 P2·P3) — 결과를 Progress Log에 기록.

완료 기준: implementer Worker로 소규모 작업 1건을 돌렸을 때 테스트 정책 해석 충돌이 없다.

### P1 — plan-dev 메타프롬프팅 강화

- [ ] **P1-1** [skills/claude/plan-dev/SKILL.md](skills/claude/plan-dev/SKILL.md): Process 5단계 뒤 **완료 조건 라운드** 신설 — `AskUserQuestion`으로 TODO별 관찰 가능한 완료 상태·증거·수용 가능 리스크를 합의하고 Acceptance Contract 초안을 사용자와 확정. 계획 승인 시 접근법과 합격 기준을 함께 승인하게 한다.
- [ ] **P1-2** 동일 파일: step 8 Cold hand-off gate 확장 — 기존 "구현자가 방향을 복원할 수 있는가"에 **"독립 평가자가 이 플랜(+AC)만으로 합격/실패를 판정할 수 있는가"** 를 승인 차단 조건으로 추가.
- [ ] **P1-3** 동일 파일: Plan granularity 절에 "일반 lint/test/build 명령은 플랜에 복제하지 않는다 — AC에는 저장소가 자동으로 알려줄 수 없는 작업 특화 결과와 증거만 기록"을 명시.
- [ ] **P1-4** 동일 파일: planner 두 접점 명시 — step 4에서 모호·횡단·아키텍처 민감 작업일 때 planner를 dispatch해 (a) 아키텍처 뷰, (b) 사용자에게 물을 고영향 질문 목록(선택지+권장 기본값 형식)을 받고 그 질문을 step 5·완료 조건 라운드에서 메인 세션이 릴레이; step 8에서 초안 플랜+AC를 planner에 보내 Planning Lens 검토(goal/boundary/contract fit, AC의 평가 충분성, over-planning 플래그). trivial 작업은 양쪽 생략.
- [ ] **P1-5** [references/single-step-plan.md](skills/claude/plan-dev/references/single-step-plan.md): enforced 섹션 2개 추가 — `## Acceptance Contract`(AC 테이블 + 선택 열 `Do not mark done if`, 각 TODO에 `(AC-N)` 참조)와 `## Authority Boundaries`(재량/금지/중단 조건/루프 예산 기본 3). 파일 스켈레톤 갱신.
- [ ] **P1-6** [references/multi-steps-plan.md](skills/claude/plan-dev/references/multi-steps-plan.md): sub-plan 상속 규칙에 두 섹션 추가(각 sub-plan이 자기 AC 보유), step contract와 AC의 관계 1문단(스텝 간 seam은 계약, 스텝 내 완료는 AC).
- [ ] **P1-7** [agents/claude/planner.md](agents/claude/planner.md): Planning Lens의 Verification 항목 확장(수용 기준의 관찰 가능성·증거·권한 경계), 기존 AR이 있으면 계획 제약에 반영, "서브에이전트로 실행될 때 질문은 사용자에게 직접 묻는 대신 **반환 형식(질문 목록)** 으로 전달"을 명문화.

완료 기준: 신규 플랜 1건에서 AC 테이블·Authority Boundaries·AC 참조 TODO가 생성되고, 본문 분량이 기존 대비 유의미하게 늘지 않는다(경계만 추가).

### P2 — 공통 단계 결과 계약 정렬

기존 스킬별 풍부한 헤딩은 유지하고 반환 맨 앞에 공통 블록을 얹는다.

- [ ] **P2-1** [skills/claude/implement-dev/references/worker-contract.md](skills/claude/implement-dev/references/worker-contract.md): ② 반환의 `## Implementation Status` → `## Stage Status` 개칭, `## Evidence` 신설(실행 명령/결과 + 이행 AC ID), dispatch prompt에 "플랜의 AC를 읽고 TODO Fulfillment에 AC 매핑 기록" 지시 추가.
- [ ] **P2-2** [skills/claude/implement-dev/SKILL.md](skills/claude/implement-dev/SKILL.md) + [references/implement-flow.md](skills/claude/implement-dev/references/implement-flow.md): 최종 검증에 "AC별 Evidence 수집·기록, AC 미충족 시 pass 불가" 추가. 단 `## Acceptance Contract`가 없는 플랜(P1 이전 legacy 플랜)은 실행 거부하지 않는다 — AC 증거 단계를 건너뛰고 기존 최종 검증(재발견된 일반 게이트)만 수행하며 보고서 `## Summary`와 반환 `## Evidence`에 `Acceptance Contract: none (legacy plan)`을 기록. 플랜 anchors 목록에 Acceptance Contract/Authority Boundaries 추가(P1 이후 생성 플랜에 한해 guaranteed, 부재 시 위 legacy fallback).
- [ ] **P2-3** [references/report-file.md](skills/claude/implement-dev/references/report-file.md): `## TODO Fulfillment` 서브섹션에 `AC:` 줄 추가(이행한 AC ID + 증거 포인터).
- [ ] **P2-4** [skills/claude/test-dev/SKILL.md](skills/claude/test-dev/SKILL.md) + [references/worker-contract.md](skills/claude/test-dev/references/worker-contract.md): `## Test Status` → `## Stage Status`, 어휘에 `pass-with-suspected-defects` 추가(review로 자동 진행하지 않고 사용자 통지 후 fix-dev 후보 분류), 의심 결함 목록을 `## Findings`(`TEST-NNN`)로 구조화.
- [ ] **P2-5** [skills/claude/fix-dev/SKILL.md](skills/claude/fix-dev/SKILL.md): Return contract `Status: success` → `Stage Status: pass` 통일, 입력 brief에 선택 필드 `Finding ID`(REVIEW-NNN/TEST-NNN)와 `Loop context`(라운드 번호, LOOP 파일 경로) 추가, `## Fix` 엔트리에 finding ID 기록.

완료 기준: 네 스킬 반환의 첫 헤딩이 모두 `## Stage Status`이고 어휘가 §1 표의 부분집합이다. 루프 밖 단독 사용 동작은 변하지 않는다.

### P3 — review-code 트리아지 + Accepted Review Exceptions

대상 파일: [skills/claude/review-code/SKILL.md](skills/claude/review-code/SKILL.md). reviewer 에이전트 4종은 수정하지 않는다(억제 규칙은 dispatch prompt로 전달 — diff·마이그레이션 최소화).

- [ ] **P3-1** 상태 모델: `## Stage Status: pass | needs-decision | changes-required` 도입(pass = 미해결 차단 항목 없음; needs-decision = HIGH/CRITICAL 발견됐으나 미분류; changes-required = fix 분류 항목 잔존). verdict 문장 유지 + `Correct (with accepted risks)` 표현.
- [ ] **P3-2** gather 단계: AGENTS.md(없으면 CLAUDE.md)에서 `## Accepted Review Exceptions` 로드 → dispatch prompt에 포함, 억제 4조건 지시, 매칭 finding은 삭제가 아니라 **Waived 강등**(verdict 계산 제외 + `## Applied Exceptions`에 AR ID 표시).
- [ ] **P3-3** aggregate 단계: dedupe 후 차단 finding에 `REVIEW-NNN` ID 부여(메인 세션), HIGH/CRITICAL 존재 시 triage — 요약 테이블(`ID/Severity/Finding/Recommendation`) 출력 후 `AskUserQuestion`으로 항목별 Fix/Accept(질문당 옵션 4개 제한 → 4건씩 배치, 기본값 Fix, 무응답 항목은 미분류 유지). Fix/Accept 목록을 결과에 명시.
- [ ] **P3-4** AR 기록 절차: Accept 시 메인 세션이 AR 엔트리 기록 — 위치·형식·매칭 규칙은 §1 확정안, "AR 작성은 사용자의 명시적 Accept 응답이 있을 때만"을 불변식으로 명문. `AGENTS.md`와 `CLAUDE.md`가 둘 다 없는 레포에서는 파일을 자동 생성하지 않고 기록 위치를 사용자에게 확인한다(기본 제안: 루트 `AGENTS.md` 신규 생성).
- [ ] **P3-5** 문서 연결: bug bar 7번(intentional choice)에 "AR 레지스트리가 그 의도의 공식 채널" 1문장, "When all four reviewers return clean" 절에 Applied Exceptions 표시 규칙 반영.

완료 기준: HIGH finding이 있는 diff에서 triage가 발동하고, Accept 항목이 AGENTS.md에 기록되며, 같은 diff 재리뷰에서 해당 항목이 Waived(Applied Exceptions)로 강등되고 Stage Status가 pass가 된다.

### T1 — 1차 변형 전파 (P0~P3 범위)

- [ ] **T1-1** [MIGRATE_TO_CODEX.md](MIGRATE_TO_CODEX.md) 갱신: triage 질문 변환 규칙(Codex는 구조화 질문 도구 없음 → 테이블 출력 + "각 ID에 `REVIEW-001: fix` 형식으로 응답" 규약, 모호 응답 재확인, 무응답=미분류 유지), **플랫폼 불변 목록**(섹션명·상태 어휘·ID 규칙·스킬/에이전트 이름·파일명 규칙·AR 불변식 — "do not translate") 추가.
- [ ] **T1-2** [MIGRATE_TO_OPENCODE.md](MIGRATE_TO_OPENCODE.md) 갱신: triage → question tool 매핑, 플랫폼 불변 목록 추가.
- [ ] **T1-3** [MIGRATE_TO_CLAUDE.md](MIGRATE_TO_CLAUDE.md) 갱신: Codex발 역이식 시 Stage Status 어휘·섹션명은 변환하지 않고 보존.
- [ ] **T1-4** sync-harness 실행: `Claude -> Codex + OpenCode` (P0~P3에서 변경된 skills/agents 범위). Codex는 `AskUserQuestion`→"ask the user", `ExitPlanMode`→plan approval flow, description 300자 압축 등 기존 규칙 적용. OpenCode는 Task tool/`general`/question tool/`plan_exit`/"legacy CLAUDE.md" 표현 적용. implementer.toml과 implementer.md(OpenCode)에 P0-1 반영.
- [ ] **T1-5** `python3 .agents/skills/sync-harness/scripts/verify-sync.py` 통과 — 새 계약 키워드가 잔존 용어 스윕에 오탐되면 스크립트 허용 목록 갱신.

완료 기준: verify-sync 무오류, Codex/OpenCode 변형에서 새 섹션명·상태 어휘가 §1 불변 목록과 일치.

### P4 — dev-loop 컨트롤러 스킬 신설 (MVP: single-step 플랜 전용)

- [ ] **P4-1** `skills/claude/dev-loop/SKILL.md` 신설: **Preflight**(플랜 경로 수신 → `## Acceptance Contract`/`## Authority Boundaries` 존재 확인, 없으면 실행 거부 + plan-dev 라우팅 제안; `PlanType: single-step`만 허용 — multi-steps의 sub-plan은 single-step이므로 허용; `git status` 스냅샷; LOOP 파일 생성), **상태 머신**(§2 — 각 상태에서 해당 스킬을 호출하고 `## Stage Status`로 전이 결정; 각 단계는 기존 스킬의 Dispatcher 흐름 그대로, dev-loop는 Worker를 직접 dispatch하지 않음), **재진입 규칙**(fix 성공 → test-dev 축소 스코프 → review-code), **예산·중단**(§2), **인간 게이트 2종**(triage 상시 / READY_TO_COMMIT 정지 후 IMPL·LOOP 링크와 요약 보고), **금지 목록**(커밋·푸시·PR, AR 자체 작성, 테스트 약화, NORMAL/LOW 자동 수정, 스킬 병합, 훅 오케스트레이션, 예산 무시), auto-format 훅 등이 작업 트리를 바꾸면 그 변경·실패를 다음 검증의 입력으로 관찰.
- [ ] **P4-2** `skills/claude/dev-loop/references/loop-state.md` 신설: LOOP 파일 형식 — frontmatter(plan/IMPL 경로, 시작 시각) + append-only 라운드 로그(라운드 번호, 단계별 Stage Status, AC별 증거 상태, 열린 finding ID와 분류, 적용된 AR ID, 시도한 수정과 결과, 다음 단계, 중단 사유). 원시 대화·전체 diff·테스트 원문 복제 금지 — 체크포인트이지 제2 보고서가 아님.
- [ ] **P4-3** `skills/claude/dev-loop/references/transitions.md` 신설: 상태×Stage Status 전이표 전체 + 종료 술어 9항 + 에스컬레이션 조건.
- [ ] **P4-4** [README.md](README.md)·[AGENTS.md](AGENTS.md) 갱신: Core Development Process를 루프 표기로 갱신, dev-loop 스킬 설명 추가, README 말미의 "(예정) dev-loop 도입 후 사용 흐름" 섹션을 실제 동작 기준으로 확정(예정 표기 제거).

완료 기준: 소형 실작업 1건에서 plan-dev 산출 플랜을 입력으로 dev-loop가 구현→테스트→리뷰→(triage/fix)→READY_TO_COMMIT까지 진행하고, 진행된 라운드의 모든 상태가 LOOP 파일만으로 복원 가능하다.

### P5 — 계측과 튜닝

- [ ] **P5-1** 작은 실작업 2~3건 드라이런, 지표 기록(Progress Log 또는 별도 메모): 성공률, 평균 remediation rounds, direction-blocked 비율, fix-dev 재진입 횟수, 잘못된 자동 수정 건수, 사용자 개입 지점, 토큰·시간 비용.
- [ ] **P5-2** 측정 결과 기반 조정 — 프롬프트·게이트·예산을 **한 번에 하나씩** 변경하고 재측정. 이 Phase 전에는 어떤 P7 확장도 시작하지 않는다.

완료 기준: 드라이런에서 잘못된 자동 수정 0건, 에스컬레이션이 §2의 정의된 조건에서만 발생.

### T2 — 2차 변형 전파 + 문서 마감

- [ ] **T2-1** sync-harness 실행: `Claude -> Codex + OpenCode` (dev-loop + P5 조정분). Codex dev-loop는 description 300자 압축, `agents/openai.yaml`은 기본 미생성. OpenCode dev-loop는 frontmatter 규칙(1024자, 콜론 따옴표) 준수, dev-loop 자체는 primary 세션 스킬이므로 agent 파일·permission 블록 불필요.
- [ ] **T2-2** MIGRATE 문서 갱신: dev-loop 변환 규칙, 무인 모드(P7-3)는 Claude 전용이며 OpenCode는 plugin에 Stop 대응 이벤트가 없어 제외임을 MIGRATE_TO_OPENCODE.md Out of scope에 명시. Codex의 PreToolUse가 모든 shell 경로를 intercept하지 못하므로 루프 불변식은 스킬 본문 규칙으로만 보장됨을 명시.
- [ ] **T2-3** `verify-sync.py` 통과 + `scripts/apply-to-personal.sh`/`apply-to-work.sh` 실행으로 신규 스킬(dev-loop) 설치 확인(디렉토리 단위 복사라 자동 포함 예상 — 실행으로 검증).
- [ ] **T2-4** NEXT_HARNESS_CLAUDE.md / NEXT_HARNESS_CODEX.md / NEXT_HARNESS_OPENCODE_GROK.md 3개 조사 문서의 아카이브·삭제 여부를 사용자에게 확인(이 문서가 통합 결론을 대체).

완료 기준: 3변형 트리 패리티 + 설치 검증 완료.

### P7 — 후속 확장 (on-hold, 착수는 별도 사용자 결정)

- [ ] **P7-1** multi-step 외곽 루프: main plan의 step DAG를 순회하며 step마다 dev-loop 실행("한 루프 = 한 STEP"). 전제: P5에서 single-step 루프 안정화.
- [ ] **P7-2** learn-from-manual-edits 연결: LOOP 파일의 실패 로그·사용자 개입 기록을 입력으로 컨벤션 추출(on-the-loop flywheel).
- [ ] **P7-3** Claude 전용 무인 모드: `/goal` 래핑 또는 Ralph식 Stop hook. 무인 모드에서 triage 게이트 도달 시 전부 Fix 취급 또는 정지 — **자동 Accept 절대 금지**. Codex 이식은 가능(Stop hook 스키마 동일)하나 Work 환경 특성상 보류, OpenCode는 불가.

---

## 4. 변형별 차이 요약 (전파 작업 시 참조)

| 측면 | Claude (소스) | Codex | OpenCode |
| --- | --- | --- | --- |
| 사용자 질문(triage 포함) | `AskUserQuestion`(질문당 옵션 4개 → 배치) | 구조화 도구 없음 — 테이블 + 텍스트 응답 규약 | question tool |
| 플랜 승인 | `ExitPlanMode` | UI plan approval flow | Plan agent `plan_exit` → Build |
| 서브에이전트 dispatch | `Agent` tool + `subagent_type` | custom TOML agent spawn, `explorer`+persona 폴백 | Task tool + `subagent_type`(`general`) |
| 에이전트 정의 | `.md` + `tools:` | `.toml` + `sandbox_mode`/`developer_instructions` | `.md` + `permission:` + `mode: subagent` |
| 스킬 description | 여유 | 300자 내 trigger 중심 | 1024자 내 |
| 지시 파일 | `CLAUDE.md` 우선(+AGENTS.md) | `AGENTS.md` 우선(+CLAUDE.md 병존) | `AGENTS.md` + legacy `CLAUDE.md` |
| 훅 | settings.json + sh | hooks.json + sh(PreToolUse가 전체 shell 경로 미보장) | JS plugin — Stop 이벤트 없음(무인 모드 불가) |
| 훅 변경 필요 | 없음 | 없음 | 없음 |

## 5. 리스크와 완화

| 리스크 | 완화 |
| --- | --- |
| Codex triage 텍스트 응답 파싱 오류 | 응답 형식 규약 명문화 + 모호 시 재질문 + 무응답=미분류 유지(자동 수용 금지) |
| AR 과잉 억제(blanket suppression) | 매칭 4조건 + Waived 강등 상시 표시 + Re-open when 필수 + Applied Exceptions 가시화 |
| LOOP 파일 비대화 | append-only 최소 필드 + 금지 목록(원시 대화·diff·테스트 원문) 명문화 |
| 상태 어휘 rename 기간의 변형 간 drift | 전파를 T1(P3 직후)·T2(P5 직후) 2회로 묶어 drift 기간 최소화 |
| 루프 비용 폭주 | remediation rounds 기본 3(플랜에서만 오버라이드), 재진입 test-dev 축소 스코프, mutation은 최종 라운드만, NORMAL/LOW 비대상 |
| 플랜/AC 없는 dev-loop 호출 | Preflight 거부 + plan-dev 라우팅 |
| 하네스 자체에 테스트 스위트 부재 | verify-sync.py + P5 실작업 드라이런을 공식 검증 수단으로 규정 |

---

## Progress Log (append-only — 세션마다 아래에 추가, 기존 엔트리 수정 금지)

### 2026-07-21 — 계획 수립
- 수행: 3개 조사 문서 통합, 결정 사항 확정(사용자 승인: dev-loop 명칭, AR 단일 사본, 2회 전파), planner 두 접점 설계 반영, 본 문서 생성.
- 편차/결정: CLAUDE 문서의 "검증 명령 플랜 고정" 제안 폐기(§1 참조), OPENCODE 문서의 OpenCode-first 전파 순서 기각.
- 다음 시작점: **P0-1** (agents/claude/implementer.md 우선순위 절 추가).

### 2026-07-21 — 계획 보완 (단독 사용 분석)
- 수행: implement-dev/fix-dev/review-code의 dev-loop 밖 단독 사용 분석. 공백 2건을 계획에 반영 — P2-2에 AC 없는 legacy 플랜의 graceful degradation, P3-4에 지침 파일 없는 레포의 AR 기록 위치 확인 절차. §1 불변식에 ⑨(단독 사용 보장) 추가.
- 다음 시작점: **P0-1** (변동 없음).

### 2026-07-22 — P0 완료 (사전 정합성 정리)
- 수행: P0-1(implementer.md "The one check" 절에 **Skill rules win** 우선순위 절 추가), P0-2(single-step-plan.md Jira 규칙에 personal repo 세션 컨텍스트 shortcut — `NO-JIRA` 기본 제안, 확인 질문 생략 가능), P0-3(상태 어휘 조사 — 아래).
- **P0-3 조사 결과** (3변형 모두 상태 어휘 동일 — 변형 간 차이는 dispatch 도구 표현뿐):
  - review-code: 상태 헤딩 없음. verdict는 라벨 줄 `Overall Correctness: Correct | Incorrect` 이분법(aggregate 후 메인 세션 작성, 한국어 1문장). 차단 기준 = `[CRITICAL]`/`[HIGH]`, 심각도 스케일 `[CRITICAL|HIGH|NORMAL|LOW]`. finding ID·triage·`## Stage Status` 부재 → P3-1~P3-3 대상 확인.
  - test-dev: worker-contract 반환 첫 헤딩 `## Test Status`, 어휘 `pass | pass-with-suspected-defects | blocked | failed`. **`pass-with-suspected-defects`는 이미 존재** — P2-4의 "어휘 추가"는 기완료 상태이고 잔여 작업은 헤딩 개칭 + status 후속 행동(자동 review 진행 금지) + 의심 결함 목록의 `## Findings`(TEST-NNN) 구조화(현재 `## Suspected Business Logic Defects`에 ID 없이 verbatim 나열). `## Decision Needed` 블록 기존재.
  - fix-dev: 헤딩이 아닌 반환 라벨 줄 `- **Status**: success | needs-confirmation | blocked | failed`. `needs-confirmation`(scope guard → plan-dev 라우팅) 기존재. P2-5 대상 = `success`→`pass` 개칭 + `Stage Status` 통일 + 선택 입력 필드(Finding ID/Loop context) 추가.
  - (참고, P2-1 대비) implement-dev worker-contract: 첫 헤딩 `## Implementation Status`, 어휘 `pass | blocked | failed`, `## Decision Needed` 기존재.
  - 공통: 세 스킬 모두 Dispatcher 레벨의 `Delegation status: unavailable | failed`가 별도로 존재 — Worker 단계 상태와 다른 축이므로 P2 개칭 대상 아님.
- 완료 기준 검증: 설치본 `~/.claude/agents/implementer.md`를 P0-1 반영본으로 동기화(1파일 선반영, 전체 설치 검증은 T2-3 유지) 후 implementer Worker로 소규모 TDD 작업 1건(scratchpad, slugify) 실행 — 테스트 스위트 10케이스를 Red→Green 순서로 작성했고 반환에 `conflict: none` 명시. 테스트 정책 해석 충돌 없음 확인.
- 편차/결정: 없음(계획 범위 내).
- 다음 시작점: **P1-1** (plan-dev SKILL.md 완료 조건 라운드 신설).
