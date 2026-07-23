# Loop Learning Flywheel — learn-from-manual-edits와 루프 실패 로그의 연결

[PLAN_TO_UPGRADE.md](PLAN_TO_UPGRADE.md)의 **P7-2** 태스크 상세 설계 근거 문서다. 착수는 P5 완료 후 별도 사용자 결정이며(on-hold), 착수 시 이 문서를 plan-dev의 입력으로 사용한다.

한 문장으로: **dev-loop가 돌 때마다 디스크에 쌓이는 실패·개입 기록을 학습 신호로 승격시켜, "같은 실수를 다음 루프에서 반복하지 않는" 세 번째 루프를 닫는 작업**이다.

## 1. 삼중 루프에서의 위치

P4~P5까지 완성되는 것은 두 개의 루프다 — dev-loop의 내부 검증 루프(이번 작업을 올바르게)와 multi-step 외곽 루프(P7-1, 큰 작업을 단계적으로). 둘 다 **이번 작업**을 완성하는 루프다. P7-2는 compounding engineering(Plan→Delegate→Assess→**Codify**)의 마지막 단계에 해당하는 **학습 루프**다: 이번 루프의 실패가 다음 루프의 입력(컨벤션·프롬프트·질문지)을 개선해서, 회차가 거듭될수록 하네스 자체가 좋아지는 구조. Thoughtworks의 프레이밍이 정확히 이것이다 — 인간은 in-the-loop(산출물 줄 검수)가 아니라 **on-the-loop**(하네스 설계·튜닝)에 서고, "반복 실패 시 산출물만 고치지 말고 하네스를 고친다."

## 2. 왜 기존 스킬만으로는 안 되는가

현재 [learn-from-manual-edits](../skills/claude/learn-from-manual-edits/SKILL.md)의 신호 소스는 딱 하나 — **working tree에 남은 사용자의 수동 코드 편집**이다. "사용자가 직접 고쳤다 = 처음부터 이렇게 쓰길 원했다"는 피드백을 컨벤션으로 승격한다.

그런데 dev-loop가 도입되면 역설이 생긴다. **루프가 잘 돌수록 사용자는 코드를 직접 고치지 않게 된다.** 사용자 개입의 형태가 코드 편집에서 **결정**으로 바뀌기 때문이다 — triage에서 Fix/Accept 선택, 에스컬레이션 시 지시, BLOCKED_DIRECTION에서 재계획. 기존 스킬의 신호 소스는 마르는데, 그 대신 새로운 신호가 LOOP 파일(`docs/agents/dev/*_LOOP_*.md`)에 구조화되어 쌓인다. P7-2는 이 새 신호 소스를 기존 스킬의 학습 파이프라인(추론 → 일반화 → 기록)에 연결하는 확장이다.

## 3. LOOP 파일의 신호와 각각의 교훈

LOOP 파일 형식(라운드별 Stage Status, finding ID와 분류, 시도한 수정과 결과, 중단 사유 — PLAN_TO_UPGRADE.md P4-2)을 여러 루프에 걸쳐 모아 보면, 신호 유형별로 서로 다른 하네스 개선이 도출된다:

| LOOP 파일의 신호 | 반복되면 의미하는 것 | 도출되는 개선 |
| --- | --- | --- |
| 같은 유형의 REVIEW finding이 여러 루프에서 반복 | 그 규칙이 컨벤션으로 없어서 구현 단계가 매번 틀림 | AGENTS.md 컨벤션 추가 → 리뷰(하류)에서 잡던 것을 구현(상류)에서 예방 |
| 특정 영역에서 fix 재진입(FIXING 라운드)이 잦음 | implement-dev가 처음부터 틀리는 패턴, 또는 플랜이 그 영역의 제약을 못 담음 | 컨벤션 추가 또는 plan-dev 완료 조건 라운드의 질문 보강 |
| BLOCKED_DIRECTION 탈출이 잦고 사유가 유사 | plan-dev 인터뷰가 특정 유형의 모호성을 반복적으로 놓침 | planner의 질문 렌즈(P1-7)에 해당 유형 추가 |
| triage에서 같은 유형이 반복 Accept됨 | 개별 AR로는 이미 기록되지만, 그 축의 reviewer가 이 프로젝트 특성에 과민(캘리브레이션 문제) | dispatch prompt의 bug bar 조정 제안, 또는 플랜 Authority Boundaries에 사전 반영 |
| 예산 소진·no-progress 중단이 잦음 | 게이트가 과하거나 예산이 작업 유형과 안 맞음 | 예산 기본값·재진입 스코프 튜닝(P5의 연장) |

핵심 통찰은 GEPA(Reflective Prompt Evolution, ICLR 2026)에서 온다 — **스칼라 점수보다 실행 궤적과 자연어 피드백이 훨씬 풍부한 학습 매체**라는 것. LOOP 파일이 바로 그 궤적이다. GEPA는 이 반성(reflection)을 자동 최적화로 돌리지만, P7-2는 같은 원리의 **인간 게이트가 있는 수동 버전**이다.

## 4. 예상 동작 방식

구현 시점(plan-dev)에 확정하되, 현재 구상은 다음과 같다:

1. **트리거**: 기존과 동일하게 사용자 명시 호출(예: "루프 기록에서 배울 것 정리해줘"). 자동 실행은 하지 않는다.
2. **입력 확장**: working tree diff(기존) + `docs/agents/dev/*_LOOP_*.md` 여러 개 + IMPL 리포트의 `## Fix` 이력.
3. **분석 필터**: 기존 Step 2의 "generalizes" 철학 그대로 — **1회 발생은 노이즈, 여러 루프에 걸친 반복만 신호**. 단일 루프의 단일 실패로 컨벤션을 만들지 않는다.
4. **출력 2계층**:
   - **프로젝트 수준**: 대상 레포 AGENTS.md/CLAUDE.md의 `Conventions Learned from Manual Edits` 섹션에 기록 — 기존 메커니즘 재사용. 이 시점에 섹션명을 "Learned Conventions" 정도로 일반화하는 것을 검토한다(더 이상 manual edits만이 소스가 아니므로).
   - **하네스 수준**: 스킬·에이전트 프롬프트 개선은 **제안까지만**. personal-harness 레포의 파일을 사용자 승인 후 수정하고 sync-harness로 전파하는 별도 작업으로 넘긴다.

## 5. 경계 (불변식과의 관계)

- **하네스 자동 수정 금지**: 루프가 자기 게이트를 스스로 고치는 순간 reward hacking 경로가 열린다(까다로운 reviewer 프롬프트를 "학습"이라는 명목으로 완화하는 식). AR 인간 전용 불변식과 동일한 이유로, 하네스 수준 변경은 항상 제안 → 사용자 승인이다.
- **AR과의 분리**: 반복 Accept 패턴을 발견해도 이 스킬이 AR을 만들지 않는다. AR 생성은 review-code triage의 전용 경로(PLAN_TO_UPGRADE.md §1 불변식 ①)이고, 여기서는 "이 패턴이 반복된다"는 관찰과 개선 제안까지만 한다.

## 6. 착수 전제 (왜 on-hold인가)

1. **표본**: 반복 패턴 추출은 실사용 LOOP 파일이 여러 개 쌓인 뒤에야 의미가 있다. P5 드라이런 2~3건으로는 부족하다. 표본 없는 flywheel은 공회전이다.
2. **형식 안정**: P4-2의 LOOP 파일 형식이 P5 튜닝을 거쳐 고정되어야 파싱 대상이 안정된다.

## 7. 착수 시 확정할 결정 목록

착수 시 plan-dev 인터뷰에서 확정할 미결 사항:

- 기존 learn-from-manual-edits 스킬을 확장할지, 별도 스킬(예: `learn-from-loops`)로 분리할지. 분리 시 두 스킬의 트리거 문구 충돌 여부.
- `Conventions Learned from Manual Edits` 섹션명 일반화 여부와 마이그레이션 방법(기존 레포들의 섹션명 호환).
- "여러 루프에 걸친 반복"의 최소 임계값(예: 서로 다른 플랜 2개 이상에서 동일 패턴).
- 하네스 수준 제안의 출력 형식(채팅 보고만 vs. 별도 제안 파일).
- 분석 대상 LOOP 파일의 범위(전체 vs. 최근 N개 vs. 사용자 지정).
