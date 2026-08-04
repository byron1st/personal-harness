# 모델 티어링 리팩토링 — 분석 및 제안

> 작성일: 2026-07-31 · 최종 개정: 2026-08-02 · 구현 범위: Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`) 우선 · 분석 범위: **Claude Code / Codex / Cursor 3개 플랫폼**(§4, §8, §9) · 산출물 성격: 분석·제안(구현 계약 아님)
>
> 가격·벤치마크는 **2026-07-31 기준**, 예산·크레딧 조사는 **2026-08-02 기준**이다. GPT-5.6 가격은 2026-07-30 인하가 반영된 값이며, Sonnet 5 introductory 가격은 2026-08-31에 종료된다.
>
> **2026-08-02 개정 요지**: GitHub Copilot을 대상에서 **제외**하고(사용 포기), OpenCode·Pi 경유 통합도 **미채택**으로 확정했다(관련 후속 조사 문서 삭제). 도구는 **Claude Code · Codex CLI · Cursor 3종 직접 사용**으로 고정한다. 세 플랫폼 모두 **API 정가 정량제**(Claude Enterprise·OpenAI Enterprise·Cursor Team)이므로, 구 §9(Copilot 크레딧 분석)를 **§9 예산 배분 분석**으로 전면 교체했다. 같은 날 **§6d(세션 길이 vs 컨텍스트 크기)를 신설**하고, **초판의 열린 질문 13건을 모두 처리**해 §10을 결정 기록으로 바꿨다 — 그 과정에서 **Codex `implementer`의 Terra 미사용 결정이 뒤집혔다**(§9.6b). 모든 수치는 **정가 기준**이며 인트로 가격 버전은 **부록 B**에 있다.

## 요약 (결론 먼저)

1. **"계획=고성능, 구현=고효율"은 방향은 맞지만 잘못된 변수를 짚고 있다.** 실제 변수는 *단계 이름*이 아니라 **명세 밀도와 되돌릴 수 있는가**다. 계획 단계가 고성능을 필요로 하는 이유는 "계획이라서"가 아니라 "명세가 없고 틀려도 실행자가 자가 수정할 수 없어서"다. 이 렌즈로 보면 배치가 완전히 달라진다(§1, §4).
2. **plan-dev를 세밀화하지 마라.** "구현 디테일 계획 단계 추가"는 이 하네스가 의도적으로 세운 원칙을 뒤집고, 고성능 모델에 *추측*을 시켜 비용을 늘리며, detail 충돌을 direction 충돌로 승격시켜 human gate를 증가시킨다. 대신 **escalation hatch**(필요할 때만 고성능 자문)와 **Authority Boundaries 강화**로 푼다(§3).
3. **Claude에서는 가장 큰 절감이 모델 교체가 아니다.** Opus 5 → Sonnet 5는 입·출력 모두 **1.67배**밖에 안 싸다(현재 introductory 가격 기준 2.5배지만 2026-08-31 종료). 반면 dev-loop 라운드가 1회만 더 늘어도 그 절감분은 대부분 상쇄된다. 실질 절감은 ① **effort 하향**, ② **리뷰어 4중 정적 텍스트 중복 제거 + 프롬프트 캐시 정렬**, ③ **결정론적 계산의 셸 이전** 순서다(§2, §6). **Codex·Cursor는 반대다** — Sol→Luna가 25배라 모델 교체의 기대 절감이 훨씬 크다(§8).
4. **서브에이전트를 많이 쓰는 현재 구조는 불리하지 않다. 이 리팩토링의 전제조건이다.** 프롬프트 캐시는 모델 단위로 스코프되므로, 한 세션 안에서 모델을 바꾸면 캐시가 전부 깨진다. 서브에이전트는 자체 캐시·자체 모델을 가지므로 **혼합 티어링이 가능한 유일한 구조**다(§6). 세 플랫폼 모두 이 성질을 공유한다.
5. **구조적 차단 요소가 2개 있다.** `test-dev`와 `fix-dev`가 `subagent_type: general-purpose`(빌트인)를 쓰고 있어 **모델을 지정할 파일이 없다.** `tester` / `fixer` 에이전트 신설이 티어링을 표현하기 위한 최소 선행 작업이다(§4).
6. **이식성: Codex ✅ 완전 가능 / Cursor ⚠️ 조건부.** Codex agent role `.toml`은 `ConfigToml`을 flatten하므로 `model`·`model_reasoning_effort` 두 줄만 추가하면 된다. Cursor는 표현은 되지만 **핀이 보장이 아니고**(플랜·관리자 설정에 따라 조용히 폴백) **`tools:` 필드가 없어 리뷰어의 read-only 계약이 약해진다**(§8).
7. **세 플랫폼에서 결론이 수렴한다: 최하위 티어의 자리가 거의 없다.** Haiku 4.5(200K ctx) · Luna(MRCR 41.3% 장문맥 절벽) · Composer 2.5(200K ctx)가 못하는 일이 정확히 하네스의 T2 작업(repo-slice 추론)이기 때문이다(§8.1).
8. **확정 계획은 Cursor $21 → Claude $100 → Codex $150 단위로 $700까지이며, 전량 소진 시 월 약 60작업이다(§9.8).** 정렬 기준은 비용이 아니라 **승인 마찰**이다. 참고로 세 풀의 기본 예산($100 / $100 / $21) 합은 월 16작업, 이론적 최대치($680 / $700 / $51)는 월 85작업이다. 셋 다 **API 정가 정량제**다 — Claude Enterprise는 시트가 + 전량 API 종량, Codex는 1 credit = $0.04로 정가에 1:1 대응, Cursor만 계량 단위가 다르다(first-party 풀 → 소진 시 달러 풀로 **spill-over**). 미공개인 first-party 풀 크기가 Cursor 추정의 신뢰도를 지배한다(§9.5). **모든 수치는 정가 기준이며 인트로 가격 버전은 부록 B에 별첨한다.**
9. **어떤 예산에서든 가장 큰 레버는 모델이 아니라 remediation 라운드 수다.** 라운드 평균 1.5회 → 0회면 같은 예산에서 작업 수가 **1.8배**가 된다. Opus→Sonnet 전면 교체(1.67배)보다 크다(§9.6a).
10. **Codex의 `implementer`는 Terra로 내린다 — 초판의 “Terra 미사용” 결정을 뒤집었다.** 근거였던 Pareto 논증이 **Luna를 값싼 대체재로 경유**하는데, 장문맥 역할인 `implementer`에서는 Luna가 애초에 후보가 아니다(MRCR 41.3%). 선택지가 Sol·Terra로 좁혀지면 **MRCR 89.6 vs 91.5 · SWE-Bench Pro 63.4% vs 64.6%에 가격은 2.5배 차이**다. 단일 배치 변경 중 절감폭이 가장 크다(§9.6b).
11. **캐시 히트율은 세션 길이가 아니라 프리픽스 안정성으로 올린다.** 세션을 늘리면 재전송 토큰이 **제곱으로** 늘어 캐시 할인(고정 배수)을 압도한다 — 콜드 스타트 한 번의 값이 200K 컨텍스트에서의 추가 턴 한 번과 같다(§6d).
12. **가장 큰 절감은 모델도 캐시도 아니라 리뷰 축을 버리는 것이다.** `dev-loop-light`(2축) · `dev-loop-noreview`(리뷰 없음) 신설로 작업당 **−46~−72%**, 예산 증액 없이 **월 59.8 → 158.2작업**이 된다. 기본값은 **Codex `light` / Cursor·Claude `noreview`**이며, 현행 `dev-loop`은 심각하거나 거대한 작업에만 쓴다(§9.9).

---

## §1. "계획=고성능, 구현=고효율" 통념 검증

### 근거는 있다

- **강-약 모델 협업 실증 연구**(repo-level code generation, GitHub issue resolution 벤치마크): 가장 효과적인 협업 전략이 **강 모델 단독과 동등한 성능을 40% 낮은 비용으로** 달성. pipeline·context 기반 방식이 가장 효율적이라고 결론.
- **RouteLLM**: 전체 호출의 14~26%만 강 모델로 라우팅하면서 GPT-4 품질의 약 95%를 유지 → 75~85% 비용 절감.
- **저비용 executor + 고비용 advisor**: 값싼 실행자에 강한 자문을 붙이면 실행자 단독 점수가 2배 이상 상승.

### 그러나 통념은 세 지점에서 부정확하다

**(1) 진짜 변수는 "계획 vs 구현"이 아니라 "명세 밀도 × 되돌림 가능성"이다.**
약 모델이 강 모델을 따라잡는 조건은 *작업이 충분히 명세되어 있고 결과가 기계로 검증 가능할 때*다. 벌어지는 조건은 *스스로 되돌릴 수 없는 판단을 해야 할 때*다. 계획 단계가 전자에 해당하지 않을 뿐이며, "계획"이라는 라벨 자체는 인과가 아니다. 이 구분이 중요한 이유: **구현 단계에도 되돌릴 수 없는 판단은 존재하고(§3), 반대로 계획 이후 단계에도 완전히 명세된 작업이 많다(test-dev, fix-dev).**

**(2) 통념이 빠뜨린 절반 — 검증(리뷰)도 비용 대비 효과가 큰 지점이다.**
13개 모델 × 실제 PR 50건 코드리뷰 벤치마크 결과:

| 모델 | F1 | PR당 비용 |
| --- | --- | --- |
| GPT-5.2 | 60.5% | $1.25 |
| Claude Opus 4.6 | 59.8% | $3.11 |
| Claude Sonnet 4.6 | 57.4% | $1.15 |
| Kimi K2.5 | 51.9% | $0.41 |
| Gemini 3 Flash | 49.5% | $0.34 |
| MiniMax M2.7 | 45.6% | $0.15 |

핵심 발견 두 가지: **비용이 리뷰 품질 분산의 21%만 설명한다**는 것, 그리고 **저비용 모델로 여러 번 돌리는 편이 고비용 모델로 한 번 돌리는 것보다 싸면서 버그 탐지가 낫다**는 것. 이 하네스는 이미 4개 리뷰어를 병렬로 돌리고 있으므로 — **벤치마크가 권장하는 multi-pass 구조를 이미 갖췄다.** 그렇다면 자연스러운 수는 "Opus 리뷰어 4개 유지"가 아니라 **"리뷰어 fleet을 효율 티어로 내리고 축(axis)을 유지/확대"**다(단, 축별로 miss 비용이 다르므로 균일 하향은 금물 — §4).

**(3) 에이전트 루프에서는 모델 단가보다 루프 구조가 지배적이다.**
에이전트 세션의 토큰 소비는 입력이 99% 이상을 차지하고, 그 대부분이 **누적 컨텍스트 재전송**이다. 실측 사례에서 cache read 94.5% / cache write 5% / output 0.5% 분포가 보고됐고, 캐시 읽기가 출력 토큰의 약 100:1까지 나온다. 결론: *"루프 아키텍처가 모델 선택보다 중요하다"*. 이것이 §2와 §6의 근거다.

### 이 하네스에 적용한 정정

> 통념: 계획은 고성능, 구현은 고효율.
> 정정: **되돌릴 수 없고 기계 검증이 불가능한 결정은 고성능. 명세가 있고 기계 검증이 가능한 작업은 고효율. 판단이 사실상 없는 변환·집계는 최저 티어 또는 셸.**

---

## §2. 비용 구조 진단 — 어디서 돈이 새는가

측정 없이 구조만으로 확정할 수 있는 항목들이다.

### (a) Opus → Sonnet의 절감폭은 생각보다 작다

| 모델 | 입력 $/1M | 출력 $/1M | 컨텍스트 | 캐시 최소 프리픽스 |
| --- | --- | --- | --- | --- |
| Claude Opus 5 | $5.00 | $25.00 | 1M | 512 tok |
| Claude Sonnet 5 | $3.00 (인트로 $2.00) | $15.00 (인트로 $10.00) | 1M | 1024 tok |
| Claude Haiku 4.5 | $1.00 | $5.00 | **200K** | **4096 tok** |

- Opus → Sonnet = **1.67배** 절감. 인트로 가격($2/$10) 기준으로는 2.5배지만 **2026-08-31에 종료**되므로, 비용 모델을 인트로 가격 위에 세우면 9월에 계획이 무너진다.
- Opus → Haiku = 5배 절감. 그러나 Haiku 4.5는 **컨텍스트 200K**(리뷰 diff가 큰 경우 제약), **캐시 최소 프리픽스 4096 토큰**(짧은 프롬프트는 조용히 캐시되지 않음), **effort 파라미터 미지원**(모델 레벨)이라는 세 제약이 있다. 이 하네스에서 Haiku가 안전하게 들어갈 자리는 사실상 없다 — 진짜 기계적인 일은 셸로 내리는 편이 낫다(§6).
- 캐시 경제: 읽기 ≈ 0.1×, 쓰기 = 1.25×(5분 TTL) / 2×(1시간 TTL). **캐시 히트율을 1%p 올리는 것이 모델을 한 단계 내리는 것보다 종종 크다.**

### (b) dev-loop 라운드 증폭 — 티어링을 무효화할 수 있는 유일한 리스크

remediation 라운드 1회 = `fix-dev`(finding 수만큼) + `test-dev`(reduced) + `review-code`(에이전트 4개). Loop budget 기본값 3.
**효율 모델 때문에 라운드가 1회만 더 늘어도, 리뷰 fleet 1회 + 테스트 1회의 비용이 추가된다 — Opus→Sonnet 40% 절감분을 넘길 수 있다.**

→ 이것이 §3에서 "escalation hatch"를 제안하는 이유이자, §7에서 **라운드 수를 유일한 성공 지표로 삼자**고 하는 이유다. 다행히 dev-loop는 이미 LOOP 파일에 라운드를 append-only로 체크포인트하므로 **계측 장치가 이미 디스크에 있다.**

### (c) review-code의 4중 정적 텍스트 중복

`review-code/SKILL.md`의 "Dispatch the four reviewers" 절에 따르면 각 dispatch 프롬프트는 diff + AGENTS.md 발췌 + 파일 목록 + **bug bar(7개 조건) + priority 정의 4종 + per-finding block 포맷 + specificity rules 6종 + AR suppression rule(축자) + lane reminder**를 담는다. 뒤쪽 항목들은 **모든 라운드, 모든 리뷰어에게 동일한 정적 텍스트**다. 4개 서브에이전트는 각각 **별도 프롬프트 캐시**를 가지므로(문서 확인), 이 정적 블록은 리뷰 라운드마다 4× 전액 지불된다.

동시에 문서의 나열 순서가 **diff 먼저 → 정적 규칙 나중**이다. 프리픽스 캐싱은 접두 일치이므로 **변동 콘텐츠가 앞에 오면 그 뒤 전부가 무효화된다.** 즉 현재 나열 순서는 캐싱 관점에서 정확히 역순이다.

### (d) Worker cold start 재확립 비용

명명된 서브에이전트는 대화 기록 없이 시작한다(fork 제외). 그래서 매 라운드마다:

- `implementer`: 플랜 전체 + 링크된 research 파일 + AGENTS.md/CLAUDE.md + **언어 컨벤션 파일 전문**(go 127행 / swift 154행 / ts-nextjs 197행, 다국어면 전부) + 검증 커맨드 재발견.
- `test-dev` Worker: scope diff + 컨벤션 + 검증 커맨드 재발견 + e2e 레이아웃 탐색 + mutation 툴링 탐색.
- 리뷰어 4개: 위 (c).

이 중 **검증 커맨드 발견과 scope 해석은 LLM 추론이 아니라 셸 계산**이다(§6).

### (e) effort가 사실상 최대 미사용 레버

Claude Code는 **에이전트 frontmatter의 `effort`**와 **스킬 frontmatter의 `effort`**를 모두 지원한다(`low|medium|high|xhigh|max`, 세션 값 override). 현재 하네스에는 어느 파일에도 `effort`가 없다 → 전부 세션 값(사용자 설정 Extra=xhigh) 상속.
Anthropic의 Opus 5 마이그레이션 가이드는 명시적으로 *"low/medium이 이 모델에서 유난히 강하다 — 이전 모델의 effort 기본값은 거의 이식되지 않는다"*, 그리고 코드리뷰에 대해 *"낮은 effort에서도 정확도가 유지되므로, 리뷰 시점의 값싼 빠른 패스 + 이후의 철저한 패스 조합이 실용적"*이라고 한다. **모델을 그대로 두고 effort만 내려도 유의미한 절감이 나오며, 아키텍처 변경이 0이다.**

---

## §3. plan-dev coarse-grained 문제를 어떻게 풀 것인가

### 제안하신 안(구현 디테일 계획 단계 추가)에 대한 평가

**권장하지 않는다.** 세 가지 이유:

1. **plan-dev의 원칙을 거스르는데, 그 원칙에는 근거가 있다.** `plan-dev/SKILL.md` "Plan granularity"는 line-level 편집·코드 스케치·헬퍼 시그니처·엣지 케이스를 defer하는 이유를 *"실행 중인 코드베이스에 대고 정하는 편이 read-only plan mode에서 추측하는 것보다 싸고 정확하다"*고 명시한다. 디테일 계획 단계는 컴파일도, 테스트 실행도, 실제 코드 상태 확인도 못 하는 상태에서 **고성능 모델에게 추측을 시키는 것**이다. 비싼 값을 주고 더 낮은 품질의 결정을 사는 구조다.
2. **같은 문서가 그 부작용도 이미 적어놨다.** 과잉 명세는 *"플랜을 길고 신호가 낮게 만들어, 실행자가 개별 지시를 얼마나 신뢰성 있게 따르는지를 저하시킨다."* 즉 효율 모델에게 주려던 "더 나은 명세"가 오히려 **지시 준수율을 떨어뜨린다.**
3. **human gate를 늘린다.** `implement-dev`는 detail-level 장애물은 Worker가 스스로 해결하고, **direction-level 충돌만** `blocked`로 승격한다. 디테일을 플랜에 박아넣으면 detail 충돌이 자동으로 direction 충돌이 되고 → `BLOCKED_DIRECTION` 정지가 늘고 → 사람이 개입해야 한다. 비용을 토큰에서 사람 시간으로 옮기는 셈이다.

### 대안 — 레버리지 순

**(A) escalation hatch: 사전 명세 대신 필요 시 자문 (핵심 제안)**

효율 모델이 *실제로 갈림길에 섰을 때만* 고성능 판단을 구매하게 한다. API 레벨의 advisor tool(저비용 executor + 고비용 advisor로 단독 점수 2배 이상)의 Claude Code 대응물이다.

- 신규 read-only 에이전트 `plan-consultant`(T1 티어, `tools: Read, Grep, Glob, Bash`)를 만든다.
- `implementer`가 **detail도 direction도 아닌 중간 밴드**(예: 두 접근이 모두 플랜과 정합하지만 되돌리기 비싼 경우)에 부딪히면, 사람 대신 이 에이전트를 호출해 **짧은 결정 + 근거**를 받는다. 서브에이전트는 3계층까지 중첩 가능하므로(main → implementer → consultant = depth 2) 구조적으로 가능하다.
- 비용: 작업당 갈림길 몇 개 × 짧은 턴. 전체 디테일 플랜 대비 한 자릿수 %.
- 이 밴드의 정의와 호출 조건은 `implement-dev/references/implement-flow.md`의 3-bucket 규칙에 4번째 밴드를 추가하는 형태로 표현한다.

**(B) 새 단계 대신 `## Authority Boundaries`를 강화 (비용 0)**

효율 모델에게 부족한 건 디테일이 아니라 **자기 권한의 경계**다. plan-dev는 이미 `## Acceptance Contract`와 `## Authority Boundaries`를 강제한다. 업그레이드는 새 파이프라인 단계가 아니라 **이 두 섹션이 하중을 지게 만드는 것**이다: TODO별로 "여기서 로컬 판단해도 되는 것 / 반드시 escalate할 것"을 한 줄씩. 이는 `plan-dev/references/single-step-plan.md`의 레퍼런스 수정이며, 플랜 길이는 거의 늘지 않는다.

여기에 **TODO 난이도 태그**를 얹으면 (A)의 호출 조건이 규칙이 된다: 각 TODO에 `(mechanical)` / `(design-bearing)`을 붙여 plan-dev가 기록하고, `design-bearing` TODO에서만 consultant 호출을 허용한다. **2026-08-02 결정: 호출 횟수의 명시적 상한은 두지 않는다** — 대신 이 태그가 유일한 게이트가 되므로, `design-bearing` 태그를 인색하게 붙이는 것이 사실상의 예산 통제다. 상한 대신 §7의 사용량 대시보드 델타로 사후 관찰한다.

**(C) Cascade — 실패했을 때만 고성능으로 재실행 (보험, 침습성 최저)**

`implement-dev`와 `fix-dev`에는 이미 **"같은 에러 3회 실패 시 중단"** 규칙이 있다. 이 지점에 훅을 걸어, 중단 대신 **T1 모델로 1회 재시도**하게 한다. (A)가 *자문*이라면 (C)는 *재실행*이며, 둘은 배타적이지 않다 — (A)는 갈림길에서, (C)는 막다른 길에서 작동한다. 기존 규칙에 접속하는 것이라 신규 아티팩트·신규 단계가 없고, **효율 모델 도입의 실패 꼬리를 자르는 가장 값싼 보험**이다. 재시도 1회 상한은 필수(무한 승격 금지).

**(D) 조건부 Implementation Brief — 사용자 아이디어 중 살아남는 형태**

§3 앞부분에서 기각한 것은 *"항상 실행되고, 인간 승인을 받으며, 길고, PLAN 본문을 세밀화하는"* 디테일 계획 단계다. 그 네 속성을 모두 뒤집으면 반론이 대부분 무력화된다:

| 기각 사유 | Brief가 이를 피하는 방식 |
| --- | --- |
| 모든 작업에 고정비 추가 | **조건부** — trivial(단일 스텝 + TODO ≤2 + 예상 터치 파일 ≤3 + 아키텍처 비민감, 순수 문서·설정)은 생략 |
| 장문 저신호 문서 → 지시 준수율 저하 | **1~2화면 상한.** 포함: TODO→파일/심볼 맵, 선택한 API shape 1안, 명시적 non-touch, 실패 시 관찰점. 금지: 전체 코드 초안, 엣지 케이스 사전 나열, 검증 명령 복제 |
| human gate 증가 | **인간 승인 없음.** 방향·AC는 PLAN에서 이미 승인됐고 Brief는 executor 입력일 뿐 |
| PLAN coarse 불변식 위반 | **별도 아티팩트**(`docs/agents/dev/{stem}_BRIEF_{title}.md`). PLAN 본문은 그대로 |

남는 약점은 두 가지다. **(i) 스냅샷 부패** — Brief 작성 시점과 implement 시점 사이에 트리가 변하면 Brief가 거짓이 된다(dev-loop 재개·다중 라운드에서 특히). **(ii) 여전히 read-only 추측이다** — 컴파일러도 테스트도 못 돌린 상태의 판단이라는 §3의 원래 반론이 완전히 해소되지는 않는다. 따라서 **Brief는 (A)+(B)를 대체하지 않고 보완한다**: (B)로 경계를 명시하고, (A)로 갈림길을 처리하고, 그래도 방향 재도출 부담이 큰 **cross-cutting·신규 모듈·스키마/API 계약·동시성·보안 경로**에서만 Brief를 강제하는 것이 순서다.

**(E) 마지막 카드 — 생성이 아니라 검증에 고성능을 쓴다**

*효율 모델이 디테일 계획을 쓰고, 고성능 모델이 그것을 짧게 리뷰한다.* 생성은 비싸고 검증은 싸다는 비대칭을 이용한다. (A)~(D)로 충분하다면 불필요하다.

**권장 도입 순서: (B) → (C) → (A) → (D).** 비용 0이고 되돌리기 쉬운 것부터, 신규 아티팩트를 만드는 것은 마지막.

---

## §4. 단계별 티어 배치안

### 티어 정의

| 티어 | 정의 | Claude | Codex | Cursor |
| --- | --- | --- | --- | --- |
| **T1 judgment** | 되돌릴 수 없고 기계 검증이 불가능한 결정 | `opus` (Opus 5) | GPT-5.6 **Sol** | **Grok 4.5** |
| **T2 execution** | 명세가 있고 기계 검증이 가능한 작업 | `sonnet` (Sonnet 5) | **Terra**(장문맥 역할) 또는 **Luna**(컨텍스트 소형 한정) | **Composer 2.5**, 단 agentic 역할은 Grok 4.5 |
| **T3 mechanical** | 판단이 사실상 없는 변환·집계 | `haiku` | Luna | Composer 2.5 |

> **T3는 사실상 비어 있다.** 세 플랫폼의 최저 티어가 모두 같은 이유로 이 하네스에 부적합하다 — Haiku 4.5는 컨텍스트 200K·캐시 최소 4096 tok, Luna는 장문맥 절벽(MRCR 41.3% vs Sol 91.5%), Composer 2.5는 컨텍스트 200K. **하네스의 T2 작업은 대부분 repo-slice 추론이라 최저 티어가 가장 못하는 일이다.** 진짜 기계적인 일은 모델이 아니라 셸로 내려라(§6a).
>
> **Codex의 Terra — 2026-08-02에 결정을 뒤집었다.** 초판은 Artificial Analysis의 Pareto 논증(*"어떤 Terra effort 조합에 대해서도, 같은 비용에 더 똑똑하거나 같은 지능에 더 싼 Luna/Sol 조합이 존재한다"*)을 근거로 **Terra 전면 미사용**을 정했었다. 그러나 **그 논증은 Luna를 값싼 대체재로 경유한다.** `implementer`에서는 Luna가 장문맥으로 실격이므로(MRCR 41.3%) 선택지가 Sol과 Terra 둘뿐이고, 그 좁혀진 비교에서는 결론이 반대다 — **MRCR v2 8-needle에서 Terra 89.6 / Sol 91.5(256K~512K), 72.5 / 73.8(512K~1M)로 Terra는 Sol과 같은 편에 서 있고, 절벽 아래로 떨어지는 것은 Luna뿐이다.** SWE-Bench Pro도 Terra 63.4% vs Sol 64.6%로 1.2pp 차다. **따라서 `implementer`만 Terra로 내리고, 나머지 역할에서는 Pareto 논증이 그대로 성립하므로 Sol 또는 Luna를 유지한다**(§9.6b).

### 배치

effort 값은 각 플랫폼의 지원 범위 안에서만 유효하다 — Claude `low~max`, Codex `none/minimal/low/medium/high/xhigh/max/ultra`(기본 medium), **Grok 4.5는 `low/medium/high`뿐**(기본 high, xhigh·max 없음). **Cursor에서 Composer 2.5는 effort 지정 자체가 불가하다**(2026-08-02 사용자 확인) — 아래 Cursor 열의 Composer 행에 effort가 비어 있는 것은 누락이 아니라 제약이다.

| 실행 단위 (위치) | 티어 | Claude | Codex | Cursor | 근거 |
| --- | --- | --- | --- | --- | --- |
| `plan-dev` (세션) | **T1** | opus / xhigh | Sol / xhigh | Grok 4.5 / **high (상한)** | 방향·경계·AC는 되돌릴 수 없고, 틀려도 실행자가 자가 수정 불가 |
| `planner` (subagent) | **T1** | opus / high | Sol / high | Grok 4.5 / high | 아키텍처 판단. 조건부 호출이라 빈도 낮음 |
| `plan-consultant` (신규, subagent) | **T1** | opus / high | Sol / high | Grok 4.5 / high | escalation hatch(§3-A). 호출 빈도가 비용을 결정 |
| `dev-loop` 컨트롤러 (세션) | **T2** | sonnet / medium | Luna / medium | Composer 2.5 | 전이표 조회 + LOOP append — 규칙 기반, 컨텍스트 소형 |
| `implementer` (subagent) | **T2** | sonnet / high | **Terra / high** | **Grok 4.5 / medium** | TDD가 ground truth지만 plan+research+컨벤션+코드를 함께 추론 → **장문맥 역할이라 Luna·Composer 부적합**. Codex는 Terra가 MRCR에서 Sol과 동급이면서 2.5배 싸다 |
| `tester` (**신규 필요**) | **T2** | sonnet / medium | Luna / high | Composer 2.5 | mutation score ≥80%가 기계 목표. 프로덕션 코드 수정 금지라 blast radius 제한적 |
| `fixer` (**신규 필요**) | **T2** | sonnet / medium | Luna / high | Composer 2.5 | 리뷰 finding이 곧 명세이고, 재테스트·재리뷰로 검증됨. 단일 결함 = 소형 컨텍스트 |
| `security-reviewer` | **T1** | opus / medium | Sol / medium | Grok 4.5 / high | authz 우회 miss는 회복 불가. 4축 중 miss 비용 최대 |
| `reliability-reviewer` | **T1** | opus / medium | Sol / medium | Grok 4.5 / high | 반사실 시뮬레이션(경쟁 상태·부분 실패)은 약 모델이 가장 먼저 무너지는 영역 |
| `maintainability-reviewer` | **T2** | sonnet / medium | Luna / high | Composer 2.5 | 주변 코드 스타일·AGENTS.md 규칙 대조 = 명세된 패턴 매칭 |
| `senior-generalist-reviewer` | **T2** | sonnet / medium | Luna / high | Composer 2.5 | calibrated catch-all. miss 비용 낮음 |
| `review-code` 집계·triage (세션) | **T2** | sonnet | Sol / low | Grok 4.5 / low | dedup·정렬·id 부여는 기계적이고, **Fix/Accept 최종 판단은 사람** |
| `commit-code` / `request-merge` (세션) | **T2** | sonnet / low | Luna / low | Composer 2.5 | 거의 기계적 |

**effort 배분 원칙 3가지** (§8.4의 벤치마크에서 유도):

1. **모델은 아래로, effort는 위로.** Codex에서 Sol→Luna는 입력 25배·출력 25배 절감인데, Luna를 `high`로 올리는 비용은 그 절감분에 비해 미미하다. 값싼 모델을 낮은 effort로 쓰는 것보다 **값싼 모델을 높은 effort로 쓰는 편이 같은 예산에서 더 똑똑하다.** Claude에서는 Opus→Sonnet이 1.67배뿐이라 이 전략의 이득이 훨씬 작다(§2a).
2. **최상단 effort는 사지 마라.** AA Intelligence Index v4.1에서 **기본 effort → `max`는 티어 전반에 걸쳐 2~4점밖에 못 올린다.** `plan-dev`처럼 되돌릴 수 없는 결정에만 `xhigh`를 쓰고, 나머지 T1(리뷰어)은 `medium`으로 충분하다.
3. **Codex `ultra`는 금지.** Codex 정의상 *"automatic task delegation을 동반한 최대 추론"*이라 **dev-loop가 이미 소유한 위임과 충돌**하며, Terminal-Bench 기준 **3배 비용에 +3.1점**이다. 이미 오케스트레이션된 하네스 안에서는 순손실이다.

**세션 모델 운용**: 스킬 frontmatter의 `model:`은 *현재 턴에만* 적용되고 다음 프롬프트에서 세션 모델로 복귀한다. `plan-dev`(멀티턴 인터뷰)와 `dev-loop`(human gate로 턴이 끊김)는 이 필드로 고정할 수 없다. 따라서 **호출 경계 = 세션 경계**로 운용한다: **plan-dev는 Opus 세션에서, dev-loop 실행은 Sonnet 세션에서.** 세션이 Sonnet이어도 T1 에이전트(planner, security/reliability reviewer, consultant)는 frontmatter 핀으로 Opus에서 돈다.

### 선행 차단 요소 (반드시 먼저)

- `test-dev`는 `subagent_type: general-purpose`, `fix-dev`도 `subagent_type: general-purpose`를 쓴다. **빌트인이라 정의 파일이 없고 = frontmatter로 모델·effort를 지정할 수 없다.** `agents/claude/tester.md`, `agents/claude/fixer.md` 신설이 티어링 표현의 최소 선행 작업이다.
- (대안으로 Agent 툴의 per-invocation `model` 파라미터가 있으나, 선언적 에이전트 정의가 하네스의 기존 패턴과 맞고 버전 간 안정적이다.)

---

## §5. 티어 바인딩 설계 (추상 티어 + 매핑 테이블)

### Claude Code의 실제 필드가 이미 추상 티어다

`model:` frontmatter가 받는 값은 `sonnet` | `opus` | `haiku` | `fable` | 전체 모델 ID | `inherit`(기본). **별칭은 특정 모델 ID가 아니라 "현재의 Opus/Sonnet/Haiku"로 해석된다.** 즉 Claude에서는 추상 티어와 별칭이 일치하므로, 별도 매핑 계층을 만들 필요가 없다. 매핑 테이블의 역할은 두 가지로 좁혀진다:

1. **왜 이 에이전트가 이 티어인가**를 기록해서, 모델 세대가 바뀌어도 판단 근거가 살아남게 한다.
2. **Codex/Cursor로의 번역**(별칭 어휘가 다름).

### 구체안

- `agents/claude/*.md` frontmatter: `model: opus|sonnet|haiku` + `effort: …` — 실제로 동작하는 필드.
- 각 에이전트 본문에 한 줄: `Tier: T1 judgment — {근거 한 줄}`. 모델명이 아니라 **근거**가 문서화 대상이다.
- `AGENTS.md`에 **Model Tier** 섹션 신설: 티어 정의표 + 플랫폼 매핑표 + 에이전트/스킬 배치표(§4).
- `docs/sync-harness/SYNC_TO_CODEX.md`에 변환 규칙 추가: Claude `model:` 별칭 → Codex `model` + `model_reasoning_effort`, Claude `effort:` → Codex `model_reasoning_effort`(값 매핑은 §8.2). 현재 `agents/codex/*.toml`에는 두 키가 모두 없다 — **표현 자체는 가능하다는 것이 §8.2에서 확인됐다.**
- **`docs/sync-harness/SYNC_TO_CURSOR.md` 신설** (2026-08-02 결정, §8.3): Claude `model: opus` 별칭 → Cursor `claude-opus-5[effort=high]` 파라미터 문법, `tools:` → `readonly:` 축약(정보 손실을 주석으로 명시), **effort는 Grok에만 부여하고 Composer 행에서는 생략**. `skills/cursor/`·`agents/cursor/`가 대상이다.

### 운용 스위치 (문서화 필요)

세 플랫폼 모두 "전 서브에이전트를 한 모델로 강제"하는 전역 스위치를 가지며, **켜둔 채 잊으면 모든 티어 핀이 무력화**된다. A/B 테스트나 "오늘은 전부 싸게"용 임시 스위치로만 문서화할 것.

| 플랫폼 | 스위치 | 비고 |
| --- | --- | --- |
| Claude | `CLAUDE_CODE_SUBAGENT_MODEL` 환경변수 | per-invocation 파라미터와 frontmatter를 **모두** override. `inherit`로 두면 정상 해석 복귀. 설정하려면 `hooks/claude/settings.json`의 `env` 블록(현재 없음)에 |
| Codex | `config.toml`의 `[agents] default_subagent_model` / `default_subagent_reasoning_effort` | 이쪽은 **fallback**이라 더 안전하다 — role 파일이 명시한 값을 덮어쓰지 않고, spawn 호출도 role도 지정하지 않았을 때만 적용 |
| Cursor | 명시적 스위치 없음 | 대신 **의도치 않은 폴백**이 존재한다(§8.3) — 관리자 차단·플랜 제약 시 핀이 조용히 무시된다 |

---

## §6. 그 외 보강 영역

### (a) Hooks로 추론 토큰 절약 — 부분적으로 맞지만 경계가 있다

**하면 안 되는 것**: 훅으로 단계 전이나 완료 판정을 하는 것. `AGENTS.md`는 *"Hooks are guardrails; they take no part in `dev-loop` stage transitions or completion decisions"*라고 못 박았고, `dev-loop`의 Prohibitions에도 *"orchestrates control flow through hooks"*가 금지 목록에 있다. 이건 의도된 불변식이므로 건드리지 않는다.

**해도 되는 것 — "셸이 계산할 수 있는 것은 셸에서"**(제어 흐름이 아니라 입력 준비):

1. **scope 해석 스크립트** (`scripts/resolve-scope.sh` 등): `test-dev`와 `review-code`가 각각 main 세션에서 diff 범위·변경 파일 절대경로·언어를 LLM 추론 + 여러 Bash 왕복으로 재도출한다. 순수 셸 계산이다. JSON 한 덩어리로 만들어 **라운드당 1회 계산 후 4개 리뷰어 전부에 전달**하면 왕복과 추론이 함께 사라진다.
2. **검증 커맨드 탐지** (`scripts/detect-commands.sh` 등): `implement-dev`와 `test-dev`가 매 Worker·매 라운드 `Makefile`/`AGENTS.md`/`CLAUDE.md`/`README.md`에서 lint·format·test·build·mutation 커맨드를 재발견한다. Makefile 타겟 grep으로 결정론적으로 뽑을 수 있고, **드리프트 한 종류가 함께 제거**된다.
3. **언어 컨벤션 게이트 스코핑**: 컨벤션 파일 자체를 안 읽을 수는 없지만, *어떤 언어가 관여하는지*는 diff의 확장자에서 결정론적으로 나온다. 위 scope JSON이 그 판단을 대신하면 Worker가 "이 플랜에 어떤 언어가 있나"를 추론하지 않아도 된다.
4. **diff-class 라벨** (레버리지 최대): `git diff --stat` 기반으로 `trivial | standard | heavy`를 스크립트가 계산한다. 이 한 값이 **리뷰 축 수, Brief 필요 여부, mutation 생략**을 규칙으로 결정한다 — 지금은 LLM이 매번 판단하는 것들이다. 앞의 셋이 *입력을 줄이는* 레버라면, 이건 **비싼 단계를 아예 실행할지 말지를 게이팅**하므로 절감폭이 한 자릿수 배 크다.

효과는 토큰 절감만이 아니다 — **효율 모델이 사실을 재도출하지 않게 만들어 신뢰성을 함께 올린다.** 티어 하향과 상호 보완적이다.

### (b) 서브에이전트 중심 구조의 평가 — 유리하다

**유리한 점 (결정적)**: 프롬프트 캐시는 **모델 단위로 스코프**된다. 한 세션 안에서 모델을 바꾸면 캐시가 전부 무효화된다. Anthropic 문서의 권고가 정확히 이것이다 — *"서브 태스크는 값싼 모델의 서브에이전트를 띄우고, 메인 루프는 한 모델로 유지하라."* 서브에이전트는 **자체 모델 + 자체 캐시**를 가지므로, Opus 세션 아래 Sonnet Worker가 돌아도 세션 캐시가 깨지지 않는다. **즉 현재의 서브에이전트 중심 구조가 혼합 티어링을 가능하게 하는 유일한 이유다.**

**대가**: 명명된 서브에이전트는 cold start — 대화 기록 없음, 캐시 별도. §2(c)(d)의 재확립 비용이 여기서 나온다.

**완화책**:

- **축 수를 줄여라 — 티어 조정보다 큰 레버다.** 지금까지의 논의는 4축의 *단가*를 낮추는 것이었지만, 4× fan-out에 가장 직접적인 답은 **축 자체를 줄이는 것**이다. §6a-4의 diff-class 라벨을 게이트로 삼아, `trivial`(순수 문서, 테스트 전용, 3파일 미만 논로직 변경)은 **security + reliability 2축만** 돌린다. 단, **화이트리스트 방식으로만** — 프로덕션 로직이 바뀌면 무조건 4축을 유지한다(오분류의 비용이 절감분보다 크다). trivial 비중이 실제 작업의 상당 부분이라면, 이 규칙 하나가 리뷰 비용을 절반으로 만든다.
- **정적 계약을 dispatch 프롬프트에서 에이전트 시스템 프롬프트로 이전**: bug bar, priority 정의, per-finding block 포맷, specificity rules, lane reminder는 리뷰어별로 불변이다. `agents/claude/*-reviewer.md` 본문으로 옮기면 **캐시되는 시스템 프롬프트의 일부**가 되고, 4× 전액 지불이 사라진다. `review-code/SKILL.md`는 축자 전달 대신 참조만 하면 된다. (AR suppression rule은 AR 엔트리가 있을 때만 전달되므로 현행 유지가 맞다.)
- **dispatch 프롬프트를 stable-first로 재정렬**: 현재 나열 순서는 diff가 먼저다. 프리픽스 캐싱은 접두 일치이므로 **불변 → 준불변(AGENTS.md 발췌) → 변동(diff)** 순서를 `review-code/SKILL.md`에 명시해야 한다. 비용 0의 개선.
- **fork는 쓰지 말 것**: fork 서브에이전트는 부모 캐시를 공유해 더 싸지만 **대화 전체를 상속**한다. `test-dev`와 `review-code`가 의도적으로 확보한 *fresh, unanchored perspective*(작성자 서사가 아니라 diff만 본다)를 파괴한다. 매력적으로 보이지만 설계 불변식을 깨는 최적화다.

**한계**: 중첩은 main 아래 3계층까지. main → Dispatcher(=main) → Worker → consultant 구조는 여유가 있다.

### (c) 티어 하향과 상호작용하는 품질 리스크 — 리뷰 recall

Anthropic의 Opus 5 / Sonnet 5 마이그레이션 가이드는 반복해서 경고한다: 리뷰 프롬프트에 *"only report high-severity"*, *"be conservative"*, *"don't nitpick"* 류의 필터가 있으면 **최신 모델이 그것을 문자 그대로 따라 measured recall이 떨어진다**(버그 탐지 능력은 올라갔는데도). 권고는 *"전부 보고하게 하고 confidence·severity를 붙인 뒤 downstream에서 필터링"*이다.

현재 `review-code`의 "What counts as a bug"는 7개 AND 조건 + *"Ignore style, formatting, typos, and nits"*로 보수적인 필터다. **여기서 모델까지 티어를 내리면 recall 손실이 복합된다.** → **2026-08-02 결정: 이 리팩토링에 포함한다.** 필터를 완화해 리뷰어가 confidence·severity를 붙여 전부 보고하게 하고, **필터링은 `review-code` 집계 단계로 옮긴다.** 티어링과 독립된 이슈가 아니므로 리뷰어 티어 분화와 **같은 단계에서** 처리한다(§7-5) — 순서가 갈리면 recall 하락의 원인이 모델 때문인지 필터 때문인지 구분되지 않는다.

**교차 벤더 리뷰**: 구현 모델과 리뷰 모델을 다른 계열로 두면 같은 계열의 blind spot이 분산된다는 실무 관행이 있다. 이 하네스는 이미 `skills/codex/review-code-claude`라는 형태로 그 패턴을 갖고 있다. 티어링과 결합하면 **비용을 늘리지 않고 얻을 수 있는 품질 레버**가 된다. 다만 도구를 3종 직접 사용으로 고정한 뒤로는(§9) **한 플랫폼 안에서 벤더를 섞을 수 없다** — Claude Code는 Anthropic, Codex는 OpenAI뿐이고, Cursor만 Grok(xAI)+Composer(Anthropic 계열 자체 모델)로 유일하게 벤더가 갈린다. 따라서 교차 벤더는 **플랫폼 간 배치**로만 얻을 수 있다: 구현을 한 플랫폼에서 돌리고 리뷰를 다른 플랫폼에서 돌리는 운용이 그것이며, 대가는 **세션이 갈려 캐시가 공유되지 않는 것**이다. 품질과 캐시 효율의 교환이므로 자동으로 옳은 선택이 아니다.

### (d) 세션을 길게 vs 컨텍스트를 작게 — 어느 쪽이 토큰을 아끼는가

"캐시 히트를 늘리려면 한 세션을 최대한 길게 가져가라"는 조언과 §8.4의 200K 임계 회피는 **충돌하는 것처럼 보이지만 같은 식의 다른 항에 작용한다.**

> 한 턴의 비용 = **컨텍스트 크기 N** × 기본단가 × **캐시계수** × **티어계수**

세션 연장은 캐시계수를 개선(÷4~÷10)하는 대신 **N을 키우고**, 200K 규율은 티어계수를 1로 묶는다. **결정적인 차이는 N이 모든 항에 곱해지면서 세션 길이에 따라 자란다는 것이다** — 메시지 이력은 선형으로 늘지만 매 호출이 이전 컨텍스트를 재전송하므로 **누적 청구 입력 토큰은 세션 길이의 제곱으로 증가**한다(턴마다 1,000 토큰이 쌓이는 20스텝 루프의 누적 입력은 20,000이 아니라 **210,000**이다). 캐시 할인은 길이와 무관한 **고정 배수**다. 한쪽은 복리, 한쪽은 단리다.

**손익분기 (Grok 4.5 기준).** 콜드 스타트로 50K 컨텍스트를 재확립 = 50K × $2.00/1M = **$0.10**. 200K 컨텍스트에서 캐시 히트 상태로 턴 하나 더 = 200K × $0.50/1M = **$0.10**. 즉 **콜드 스타트 한 번의 값이 200K에서의 추가 턴 한 번과 같다.** 세션 연장으로 재시작 하나를 아끼려면 대가가 턴 하나여야 본전인데, 실제로는 훨씬 많이 붙는다.

Worker 런 하나(30턴, 컨텍스트 50K→250K)를 쪼갤지 말지로 계산하면:

| 안 | 계산 | 비용 |
| --- | --- | --- |
| A. 한 번에 | 1~24턴 3.0M @ $0.50 + 25~30턴 1.35M @ **$1.00**(200K 초과) | **$2.85** |
| **B. 15턴씩 둘로** | 1.5M @ $0.50 + (콜드 $0.10 + 1.5M @ $0.50) | **$1.60** |

**쪼개는 쪽이 44% 싸다.**

**200K 임계는 절벽이 아니라 증상 표시다.** 평균 컨텍스트 75K → 210K가 된 20턴 런은 $0.75 → $4.20으로 **5.6배**가 되는데, **티어 할증은 그중 2.0배뿐이고 나머지 2.8배는 단순히 토큰이 늘어난 것**이다. 임계선을 아슬아슬하게 피해 다니는 것은 요점이 아니다 — 그 근처에 갔다는 사실 자체가 이미 볼륨으로 2.8배를 내고 있다는 뜻이다. **컨텍스트 크기를 직접 줄이면 임계 문제는 따라온다.** 덧붙여 **캐시로 임계를 피할 수 없다** — 캐시된 토큰도 prompt token으로 임계 판정에 포함되고, 초과 시 캐시 입력가 자체가 $0.50 → $1.00으로 함께 오른다.

**따라서 두 조언은 충돌하지 않는다.** 충돌로 보이는 것은 *"캐시 히트율을 올리는 방법이 세션 길이뿐"*이라고 가정할 때뿐이다. 컨텍스트를 키우지 않고 히트율을 올리는 수단이 (b)에 이미 셋 있다 — **프리픽스 안정화**(현재 dispatch는 diff가 먼저라 정확히 역순이다), **정적 계약의 시스템 프롬프트 이전**, **(a)의 셸 이전**. 이 셋은 순이득이고 세션 연장은 교환이다. *"세션을 길게"*는 컨텍스트가 작고 고정적인 챗 워크로드의 조언이지, **컨텍스트가 지배항이면서 자라는 에이전트 루프의 조언이 아니다.**

**플랫폼마다 지배 레버가 다르다.**

| 플랫폼 | 캐시 미스 페널티 | 캐시 쓰기 과금 | 장문맥 티어 | **지배 레버** |
| --- | --- | --- | --- | --- |
| Claude | 10× | ✅ 1.25~2× | 없음 (1M) | **캐시 히트율** — 재시작이 가장 비싸다 |
| Codex | 10× | ❌ 없음 | 있음 (Sol $5→$10, 임계 미확인) | 캐시 히트율. 재시작이 가장 싸다 |
| **Cursor** | **4×** | ❌ 없음 | **200K 확정, 요청 전체 적용** | **컨텍스트 크기** |

Grok의 캐시 할인은 4배로 셋 중 가장 약하다. 즉 **캐시 히트율의 값어치가 Cursor에서 가장 낮고 컨텍스트 크기의 값어치가 가장 높은데, 하필 볼륨을 가장 많이 돌릴 곳이다**(§9.7-1).

**이 하네스는 이미 이 답을 구현하고 있다.** Dispatcher/Worker + cold-start Worker + fork 금지는 *"긴 컨텍스트 하나"*가 아니라 **"짧은 컨텍스트 여럿"을 선택한 설계**다. 위 B안이 안전한 이유도 구조에 있다 — **`docs/agents/dev/*_LOOP_*.md`와 IMPL 리포트가 그 자체로 compaction 요약**이어서, append-only 체크포인트가 짧은 Worker 런의 핸드오프 손실을 메운다. 운용 규칙으로 정리하면:

| 주체 | 세션 정책 | 근거 |
| --- | --- | --- |
| 메인 세션 (`plan-dev`, `dev-loop` 컨트롤러) | **길게 유지** | 컨텍스트가 작고(대화 + LOOP 파일) 캐시 연속성 이득이 크다 |
| Worker (`implementer`, `tester`, `fixer`) | **1 작업 1 인스턴스, 짧게** | 컨텍스트가 앞에 몰려 로드되고 턴이 많다 — 200K를 넘길 후보 |
| 리뷰어 4종 | **최단** | diff만 본다. 정적 계약을 시스템 프롬프트로 내리면 프리픽스가 공유된다 |

> **한 줄 규칙: 캐시 히트율은 세션 길이가 아니라 프리픽스 안정성으로 올리고, 세션 길이는 컨텍스트 크기로 정하라.**

### (e) 타 플랫폼 전파

→ §8에서 별도로 다룬다. 결론만: **Codex는 완전 이식 가능, Cursor는 조건부 가능**(핀이 보장이 아니고 read-only 강제가 약해짐).

---

## §7. 실행 순서 제안

**리스크 낮고 절감 큰 것부터.** 각 단계 후 LOOP 파일의 라운드 수를 확인하고 다음으로 넘어간다. 1~3번이 앞에 오는 이유는 §6d가 정량화한다 — **컨텍스트를 키우지 않으면서 단가를 낮추는 항목(1·2)과 비싼 단계 자체를 게이팅하는 항목(3)이, 컨텍스트가 자라는 것을 전제로 한 어떤 최적화보다 먼저다.**

| # | 작업 | 아키텍처 변경 | 기대 효과 |
| --- | --- | --- | --- |
| 1 | 모든 에이전트에 `effort` 명시(리뷰어 medium, implementer high, planner high) | 없음 | 즉시. 모델 교체 없음 |
| 2 | 리뷰어 정적 계약을 에이전트 정의로 이전 + dispatch 프롬프트 stable-first 재정렬 | 없음(문서 이동) | 리뷰 라운드당 4× 중복 제거. **§6d로 근거가 강화됐다** — 컨텍스트를 키우지 않고 캐시 히트율을 올리는 유일한 부류이고, 현재 diff-first 정렬은 정확히 역순이다 |
| 3 | **diff-class 스크립트 + trivial 축 축소 화이트리스트**(§6a-4, §6b) | 스크립트 1개 + review-code 규칙 | **축 수를 줄이는 유일한 항목.** 티어 조정보다 절감폭이 크다 |
| 3b | **`dev-loop-light` · `dev-loop-noreview` 스킬 신설**(§9.9) | 신규 스킬 2개 (기존 스킬 무변경) | **문서 전체에서 절감폭이 가장 크다** — 작업당 −46~−72%, 예산 증액 없이 월 59.8 → 158.2작업. 기존 스킬을 건드리지 않아 리스크도 낮다 |
| 4 | `tester` / `fixer` 에이전트 신설 (T2 핀) | 신규 파일 2개 | 티어링 표현 가능해짐 |
| 5 | 리뷰어 티어 분화 (maintainability·generalist → T2) **+ §6c 리뷰 필터 완화를 같은 단계에서** | frontmatter + review-code 규칙 | 리뷰 fleet 비용 ~40%↓. **둘을 붙여야 recall 하락의 원인이 모델인지 필터인지 구분된다**(§6c) |
| 6 | dev-loop 실행 세션을 T2로 운용 (plan-dev는 T1 세션 유지) | 운용 규칙 | 컨트롤러·Dispatcher 비용 |
| 7 | `## Authority Boundaries` 강화 + TODO `(mechanical)`/`(design-bearing)` 태그 (§3-B) | 레퍼런스 수정 | 비용 0. 8~9의 **선행 조건** |
| 8 | **cascade**: 3-fail 시 중단 대신 T1 1회 재시도 (§3-C) | implement/fix-dev 규칙 | 효율 모델의 실패 꼬리 절단 (보험) |
| 8b | **(Codex 변형) `implementer` → Terra / high** | frontmatter | **단일 배치 변경 중 최대 절감** — 월 +2.0작업(+38%). 8번 이후여야 실패 꼬리가 확보된다(§9.6b) |
| 9 | `implementer` → T2 + `plan-consultant` escalation hatch (§3-A) | 신규 에이전트 + implement-flow 수정 | 최대 절감이자 최대 리스크. 7·8 이후에만 |
| 10 | scope/커맨드 탐지 스크립트 (§6a-1·2) | 신규 스크립트 2개 | 반복 추론 제거 + 드리프트 제거 |
| 11 | (조건부) Implementation Brief (§3-D) | 신규 아티팩트 + 얇은 스킬 | 9로 부족할 때만. **신규 아티팩트를 만드는 유일한 항목이라 마지막** |

### 측정과 롤백

**주 지표는 "플랜당 remediation 라운드 수"다.** 이미 `docs/agents/dev/*_LOOP_*.md`에 append-only로 기록되고 있으므로 별도 계측 도구가 필요 없다. 티어를 내린 뒤 라운드 중앙값이 오르면 절감은 환상이다(§2b). 각 단계 전후로 이 값을 비교한다. **보조 지표는 각 플랫폼 사용량 대시보드의 델타**다 — 세 플랫폼 모두 정량제이므로 dev-loop 1사이클 전후 값을 한 번 읽으면 §9의 추정 비율이 전부 실측으로 교체된다(§9.7).

**롤백 기준 — 하나라도 걸리면 직전 단계를 되돌린다:**

1. remediation 라운드 중앙값이 **+1 이상 지속**된다.
2. security·reliability 계열 결함이 **인간 리뷰에서 연속으로 발견**된다(= 티어를 내린 축이 실제로 놓치고 있다).
3. 효율 모델 implementer의 **instruction drift** — AC 미이행, 플랜 TODO 체크박스 누락, 컨벤션 위반이 증가한다.
4. `blocked`(direction conflict) 비율이 증가한다(= 경계 명시가 부족한데 티어만 내렸다).

이 네 가지는 각각 §7 표의 특정 단계를 지목한다: 1·3은 9번(implementer 하향), 2는 5번(리뷰어 분화), 4는 7번(경계 강화)이 불충분했다는 신호다.

---

## §8. Codex / Cursor 이식성 분석

### 8.1 분석 원칙은 그대로 통하는가

| 절 | 내용 | Codex | Cursor |
| --- | --- | --- | --- |
| §1 | 변수는 "단계 이름"이 아니라 **명세 밀도 × 되돌림 가능성** | ✅ 모델 무관 | ✅ 모델 무관 |
| §2a | *"값싼 티어는 생각보다 안 싸다"* | ❌ **반대다.** Sol→Luna는 입·출력 모두 **25배**. 모델 교체의 기대 절감이 Claude보다 훨씬 크다 | ❌ 반대다. Composer 2.5가 Grok 4.5보다 대부분 워크로드에서 크게 싸다 |
| §2b | 라운드 증폭이 절감을 상쇄 | ✅ 동일 적용. 절감폭이 큰 만큼 허용 오차는 넓다 | ✅ 동일 적용 |
| §2c·d | 캐시 정렬·cold start | ✅ cache read 90% 할인 | ✅ Grok 4.5 cached input $0.30~0.50/1M |
| §2e | **effort가 최대 미사용 레버** | ✅ 8단계로 Claude보다 세분화 | ⚠️ Grok은 `low/medium/high` 3단뿐 |
| §3 | escalation hatch (중첩 서브에이전트) | ✅ 가능 | ✅ 가능 (2계층 상한 안) |
| §6b | **서브에이전트가 혼합 티어링의 전제조건** | ✅ 서브에이전트별 독립 컨텍스트 | ✅ 서브에이전트별 독립 컨텍스트·모델 |

**핵심 수렴 결과 하나**: 세 플랫폼의 최저 티어가 **같은 이유로** 이 하네스에 안 맞는다 — Haiku 4.5(200K ctx), Luna(MRCR 41.3%로 장문맥 절벽), Composer 2.5(200K ctx). 하네스의 T2 작업 대부분이 repo-slice 추론이기 때문이다. 플랫폼이 달라도 결론은 같다: **최하위 티어의 자리는 거의 없고, 기계적인 일은 셸로(§6a).**

### 8.2 Codex — ✅ 완전 이식 가능

- **에이전트별 모델·effort 지정이 이미 지원된다.** Codex의 agent role 파일(`agents/*.toml`)은 `name` / `description` / `nickname_candidates` + **`ConfigToml` 전체를 flatten**한 스키마다. 즉 `model`과 `model_reasoning_effort`를 그대로 키로 추가하면 된다. 현재 `agents/codex/*.toml`이 쓰는 `name` / `description` / `sandbox_mode` / `developer_instructions` 조합이 정확히 이 포맷이므로 **파일 구조 변경 없이 두 줄만 추가**하면 된다.
- **해석 우선순위**: `spawn_agent` 호출 인자 → role 파일 → `[agents] default_subagent_*` → 부모 상속. role이 명시하지 않은 항목은 호출자의 모델·effort·provider·service tier를 보존한다. Claude의 `CLAUDE_CODE_SUBAGENT_MODEL`이 **모든 것을 덮어쓰는 것과 달리, Codex의 전역 기본값은 fallback이라 티어 핀을 파괴하지 않는다** — 운용상 더 안전하다.
- effort는 모델별 `supported_reasoning_levels`로 검증되므로 잘못된 조합은 조용히 무시되지 않고 에러가 난다.
- **`ultra` 금지**(§4 원칙 3).

### 8.3 Cursor — ⚠️ 조건부 가능 (제약 3개 + 뜻밖의 발견 1개)

- **표현은 가능하다.** Cursor 2.4의 서브에이전트는 `.cursor/agents/*.md`에 `name` / `description` / `model` / `readonly` / `is_background` frontmatter를 갖고, `model`은 `inherit`(기본) · 모델 ID(`composer-2.5`, `gpt-5.6-sol`) · **파라미터 문법**(`claude-opus-5[effort=high]`, `claude-opus-5[context=300k]`)을 받는다. 즉 모델 + effort를 에이전트별로 핀할 수 있다.
- **제약 1 — 핀이 보장이 아니다.** 팀 관리자 차단 / Max Mode 없는 레거시 요청형 플랜 / 플랜 미제공 모델인 경우 Cursor가 *"compatible model"*로 **조용히 폴백**한다. Claude·Codex와 달리 **T1 핀이 무시될 수 있고, 그러면 비용도 품질도 예측 불가**가 된다. 회사 계정이라면 관리자 모델 허용 목록을 먼저 확인해야 한다.
- **제약 2 — `tools:` 필드가 없다.** 커스텀 서브에이전트는 부모의 **모든 툴을 상속**하고, 제한 수단은 `readonly: true` 불리언 하나뿐이다. 하네스의 리뷰어 4종·`planner`·`plan-consultant`는 Claude에서 `tools: Read, Grep, Glob, Bash`로 write를 원천 차단하는데, Cursor에서는 이 불변식이 **약해진다**. → **2026-08-02 결정: 이 약화를 수용한다.** `readonly: true`로 표현 가능한 만큼만 보장하고, Cursor 변형의 리뷰어·planner 정의에 *“Cursor에서는 read-only가 `readonly` 불리언으로만 강제된다”*를 주석으로 남긴다. 별도 세션으로 돌리는 우회는 채택하지 않는다.
- **제약 3 — 중첩 2계층.** 서브에이전트는 자식을 낳을 수 있지만 **그 자식은 더 못 낳는다.** `implementer` → `plan-consultant`는 성립하므로 현 설계엔 충분하나, 그 아래로 확장할 여지는 없다.
- **Cursor는 `.claude/agents/`와 `.codex/agents/`도 읽는다.** 공식 문서의 서브에이전트 위치 표에 세 디렉터리가 모두 프로젝트 스코프로 명시돼 있어 *“Cursor 전용 변형이 불필요할 수도 있다”*는 가능성이 있었다. → **2026-08-02 결정: 그래도 `skills/cursor/`·`agents/cursor/` 변형을 별도 신설한다.** frontmatter 방언이 실제로 다르고(`model: opus` 별칭 vs `claude-opus-5[effort=high]`, `tools:` vs `readonly:`), 교차 인식에 의존하면 Cursor가 조용히 다르게 해석해도 알아챌 수단이 없다. **명시적 변형이 §8.3 제약 1·2의 차이를 파일에 드러내는 유일한 방법이다.** `docs/sync-harness/SYNC_TO_CURSOR.md` 신설이 따라온다.
- **effort 지정 범위 (2026-08-02 사용자 확인)**: **Grok 4.5는 effort 지정이 가능하고, Composer 2.5는 불가하다.** 따라서 Cursor에서 effort 레버는 **T1(Grok)에만** 존재하며, T2(Composer) 역할은 모델 선택만으로 조절해야 한다. §4 Cursor 열의 Composer 행에 effort가 비어 있는 것은 이 제약의 반영이다.

### 8.4 모델·비용 지형 (2026-07-31 기준)

| 플랫폼 | 모델 | 입력 $/1M | 출력 $/1M | 컨텍스트 | effort 범위 |
| --- | --- | --- | --- | --- | --- |
| Claude | Opus 5 | 5.00 | 25.00 | 1M | low~max |
| Claude | Sonnet 5 | 3.00 (인트로 2.00, ~08-31) | 15.00 (인트로 10.00) | 1M | low~max |
| Claude | Haiku 4.5 | 1.00 | 5.00 | 200K | — (모델 단 미지원) |
| Codex | GPT-5.6 Sol | 5.00 | 30.00 | 1M | none~ultra |
| Codex | GPT-5.6 Terra | 2.00 | 12.00 | 1M | low~ultra (기본 medium) |
| Codex | GPT-5.6 Luna | **0.20** | **1.20** | 1M | low~ultra |
| Cursor | Grok 4.5 | 2.00 (cached 0.30~0.50) | 6.00 | **500K** | **low/medium/high** (기본 high) |
| Cursor | Composer 2.5 **Standard** | ≈0.50 | ≈2.50 | 200K | 미확인 |
| Cursor | Composer 2.5 **Fast** | ≈3.00 | ≈15.00 | 200K | 미확인 |

> ⚠️ **Cursor의 가장 큰 비용 함정: Composer 2.5의 Standard / Fast 구분.** 둘은 **지능이 동일하고 가격만 약 6배 차이**나며(태스크당 ≈$0.07 vs ≈$0.44), **Fast가 Cursor 기본값**이다. 즉 아무 설정도 하지 않으면 하네스의 T2 bulk가 전부 6배 요금으로 돈다 — 심지어 **Fast($3/$15)가 T1인 Grok 4.5($2/$6)보다 비싸서 티어링이 역전된다.** §4 배치의 Cursor 열은 전부 **Standard**를 의미하며, Fast는 티어가 아니라 IDE 체감 속도 옵션으로만 취급해야 한다. (Standard/Fast 단가는 선행 조사 문서 기준이며 이번 세션에서 직접 검증하지 못했다 — 실제 요금표로 확인 필요.)
>
> **Grok 4.5의 장문맥 2배 티어는 200K 프롬프트 토큰 기준으로 확인됐다(2026-08-02).** 200K 이하는 $2 / $0.50(cached) / $6, 초과 시 $4 / $1 / $12이며 — **초과분만이 아니라 요청 전체에 적용된다.** 즉 Grok의 500K 컨텍스트는 "쓸 수 있다"이지 "싸게 쓸 수 있다"가 아니고, **200K 경계를 한 번 넘기면 그 요청의 비용이 정확히 2배**가 된다. Worker에 불필요한 컨텍스트를 싣지 않는 것이 그 자체로 비용 레버이며, §6a의 scope 스크립트·§6b의 축 축소가 여기에 직접 작용한다.

**벤치마크 요약** (출처별 코호트가 달라 서로 직접 비교 금지):

- **AA Intelligence Index v4.1 (max effort)**: Sol 59 / Terra 55 / Luna 51. Claude Fable 5가 60. **기본 effort → max는 티어 전반 2~4점.**
- **Agents' Last Exam**: Sol max 53.6(SOTA). **Sol medium이 Fable 5보다 11.4점 앞서면서 추정 비용은 약 1/4.** Luna는 Sol과 약 3.3점 차.
- **AA Coding Agent Index**: Sol 80 / Terra 77.4 / Luna 74.6.
- **장문맥(MRCR)**: **Luna 41.3% vs Sol 91.5%** — Luna를 대형 코드베이스 추론에 쓰면 안 되는 정량적 근거.
- **Cursor 진영**: agentic 비교에서 Grok 4.5 **83.3** vs Composer 2.5 **69.3**. CursorBench 3.2는 Grok 66.7 vs Composer 56.1, SWE Multilingual은 Composer 79.8 vs Grok 78.0. Grok 4.5는 SWE-Bench Pro 64.7%이면서 **태스크당 출력 토큰 15,954개 — Opus 4.8 max(67,020)의 약 1/4.2**로, 헤드라인 단가보다 실효 비용이 낮다.

이 숫자들이 §4 배치의 근거다: **agentic 격차(83.3 vs 69.3)가 정확히 `implementer`의 일에 떨어지므로 Cursor에서 implementer만 Grok에 남겼고**, 장문맥 절벽(41.3%)이 정확히 `implementer`의 입력 형태(plan + research + 컨벤션 + 코드)와 겹치므로 **Codex에서도 implementer만 Sol에 남겼다.**

---

## §9. 예산 배분 — 세 정량제 풀로 몇 작업이 가능한가

> 2026-08-02 전면 개정. 구 §9(GitHub Copilot 1,900 크레딧 분석)를 대체한다. **Copilot은 사용하지 않기로 했고**, 도구는 Claude Code · Codex CLI · Cursor 3종 직접 사용으로 고정됐다. OpenCode·Pi를 경유한 통합도 미채택이다.

### 9.1 전제 — 세 풀 모두 정량제지만, 계량 단위가 다르다

| 풀 | 과금 단위 | 기본 예산 | 승인 시 상한 | 실제 계량 대상 |
| --- | --- | --- | --- | --- |
| **Claude Code** | API 정가 달러 | $100 | $680 | 토큰 (입력·캐시입력·캐시쓰기·출력 4축). **Enterprise = 시트가 + 전량 API 정가 종량**으로 확인됨(§10 해결 13) |
| **Codex** | 크레딧, **1 credit = $0.04** | $100 (= 2,500 credits) | $700 (= 17,500 credits) | 토큰. **크레딧 rate card가 API 정가에 1:1 대응** |
| **Cursor** | ⚠️ **두 개의 풀** | $21 ($20 included + $1 on-demand) | $51 | 달러 풀은 third-party 모델만. **Grok 4.5·Composer 2.5는 별도 first-party 풀**. 계정은 **Team**이다(§9.5) |

Codex 크레딧이 API 정가와 1:1이라는 점은 검산으로 확인된다 — GPT-5.5 입력 125 credits/1M × $0.04 = $5.00/1M, 캐시입력 12.5 → $0.50, 출력 750 → $30.00으로 정가표와 일치한다. **즉 Codex 예산은 달러로 그대로 환산해도 되고, 이 절의 계산에 별도 보정이 필요 없다.**

**Cursor만 다르다.** 이 계획은 Grok 4.5와 Composer 2.5만 쓰는데, 둘 다 first-party 풀 소속이다. 즉 **$20 included도 $1 on-demand도 사실상 건드리지 않는다.** Cursor의 상한을 정하는 것은 예산이 아니라 **미공개인 first-party 풀의 크기**다 → §9.5에서 따로 다룬다.

### 9.2 작업 1회의 정의

§9.4 이후의 모든 숫자는 이 단위 위에 서 있다. **실측이 아니라 §1·§2의 토큰 프로파일로 세운 1차 근사이며, 절대값이 아니라 비율을 보라.**

**라운드 단위 1회** = `implement + test + review×4` ≈ 캐시읽기 9M / 신규입력 0.6M / 출력 0.2M / 캐시쓰기 0.5M.

**`plan-dev → dev-loop` 작업 1회**는 그보다 크다:

| 구성 | 라운드 단위 환산 | 근거 |
| --- | --- | --- |
| `plan-dev` (인터뷰 + 리서치) | 0.20 | 세션이지 40턴 Worker 팬아웃이 아님 |
| dev-loop 라운드 0 | 1.00 | 위 정의 |
| remediation 라운드 × 평균 1.5회 | 1.05 | 라운드당 0.7 — fix는 단일 결함, test는 reduced, **review×4는 전액** |
| `commit-code` + `request-merge` | 0.05 | 거의 기계적 |
| **1작업 =** | **2.3 단위** | |

라운드 토큰 배분은 `implementer` 35% / `tester` 15% / 리뷰어 4개 50%(각 12.5%)로 잡았다. **§4 배치는 세 플랫폼 모두 implementer + 리뷰어 2개를 T1급에 두므로, 어느 플랫폼에서도 T1 지분이 60%다.**

### 9.3 캐시 입력가 기준 실질 단가

에이전트 루프는 캐시 읽기가 지배적이므로(§1: cache read 94.5%) **헤드라인 입력가가 아니라 캐시 입력가가 실질 단가**다.

| 모델 | 입력 | **캐시 입력** | 출력 | 캐시 쓰기 | **$/라운드 단위** |
| --- | --- | --- | --- | --- | --- |
| GPT-5.6 Luna | 0.20 | **0.02** | 1.20 | — | **0.54** |
| Composer 2.5 **Standard** | 0.50 | 0.20 | 2.50 | — | **2.60** |
| Claude Haiku 4.5 | 1.00 | 0.10 | 5.00 | 1.25 | 3.13 |
| GPT-5.6 Terra (medium) | 2.00 | 0.20 | 12.00 | — | 5.40 |
| GPT-5.6 Terra (**high**, 추론 토큰 1.5× 가정) | 2.00 | 0.20 | 12.00 | — | **6.87** |
| Claude Sonnet 5 (인트로, ~08-31) | 2.00 | 0.20 | 10.00 | 2.50 | 6.25 |
| **Grok 4.5** | 2.00 | **0.50** | **6.00** | — | **6.90** |
| Composer 2.5 **Fast** | 3.00 | 0.50 | 15.00 | — | 9.30 |
| Claude Sonnet 5 (정가, 09-01~) | 3.00 | 0.30 | 15.00 | 3.75 | **9.38** |
| GPT-5.6 Sol | 5.00 | 0.50 | 30.00 | — | **13.50** |
| Claude Opus 5 | 5.00 | 0.50 | 25.00 | 6.25 | **15.63** |

두 가지가 눈에 띈다. **(1) Grok 4.5는 캐시 입력가가 Opus 5·Sol과 같은 $0.50인데 출력이 $6.00 — Opus의 1/4.2, Sol의 1/5**다. §8.4의 SWE-Bench Pro 측정에서 태스크당 출력이 Opus 4.8 max의 1/4.2였으므로, 출력 축의 이점이 단가와 토큰 수 양쪽에서 곱해진다. **(2) Composer 2.5 Fast는 Grok 4.5보다 비싸다** — T2가 T1보다 비싸지는 티어 역전이므로, §8.4의 경고대로 Cursor 설정에서 **Standard 강제가 1순위 조치**다. first-party 풀로 계량되는 지금은 이게 더 중요해졌다: Fast는 **희소 자원인 풀을 3.6배 빨리 태운다.**

### 9.4 풀별 사이클 비용과 가용 작업 수

§4 배치(T1 60% / T2 40%)를 적용한 결과다.

**모든 숫자는 정가 기준이다.** Sonnet 5 인트로 가격(~2026-08-31)으로 계산한 값은 의사결정에 쓰지 않으며 **부록 B**에 별첨한다.

| 풀 | T1 | T2 | $/라운드 | **$/작업** | 기본 예산 | **기본 작업 수** | 상한 예산 | **상한 작업 수** |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Claude** | Opus 5 (25%) | Sonnet 5 (75%) | 10.94 | **25.2** | $100 | **4.0** | $680 | **27.0** |
| **Codex** | Sol (25%) | **Terra/high** (35%) + Luna (40%) | 6.00 | **13.8** | $100 | **7.2** | $700 | **50.7** |
| **Cursor** | Grok 4.5 (60%) | Composer Std (40%) | 5.18 | **11.9** | $21 (+first-party 풀) | **~5.2** | $51 (+first-party 풀) | **~7.7** |

> 지분이 플랫폼마다 다른 이유는 `implementer` 때문이다. Claude는 `implementer`가 Sonnet(T2)이라 T1 지분이 25%지만, Cursor는 Grok(T1급)이라 60%다. Codex는 `implementer`를 Terra로 내리면서 **Sol 25% / Terra 35% / Luna 40%의 3단 구성**이 됐고, 이것이 Codex가 가장 싸진 이유다(§9.6b).

**합계 — 기본 예산 월 약 16작업, 상한 예산 월 약 85작업.**

| | Claude | Codex | Cursor | **합계** |
| --- | --- | --- | --- | --- |
| 기본 ($100 / $100 / $21) | 4.0 | **7.2** | ~5.2 | **~16.4** |
| 상한 ($680 / $700 / $51) | 27.0 | **50.7** | ~7.7 | **~85.4** |

Cursor 열은 **미공개인 first-party 풀 추정을 포함**하므로 다른 두 열과 신뢰도가 다르다(§9.5). 주목할 점 둘: **(1) Codex가 세 풀 중 가장 효율적이다** — `implementer` Terra 전환 하나로 기본 5.2 → 7.2작업이 됐고, 상한에서는 50.7작업으로 Claude의 1.9배다. **(2) 상한 예산에서 Cursor의 기여도는 상대적으로 작아진다** — Claude·Codex는 예산이 6.8~7배 늘지만 Cursor는 $21→$51로 2.4배일 뿐이고, Premium 시트($120/월)는 $51 예산 밖이다(§9.5).

### 9.5 Cursor first-party 풀 — 별도 취급이 필요한 이유

**Cursor는 2026-06~07에 걸쳐 included usage를 두 개의 풀로 분리했다.**

| 풀 | 대상 모델 | 계량 단위 | 이 계획과의 관계 |
| --- | --- | --- | --- |
| **third-party API 풀** | Claude · GPT · Gemini | **달러** (Pro $20 / Pro+ $70 / Ultra $400) | **쓰지 않음** |
| **first-party (Cursor Models) 풀** | **Auto · Composer 2.5 · Grok 4.5** | 미공개 (달러 아님) | **전량 여기서 나감** |

확인된 성질:

1. **두 풀은 siloed가 아니다 — 한 방향으로 흐른다 (2026-08-02 확인).** first-party 풀이 소진되면 **Grok·Composer 사용이 third-party 달러 풀로 흘러넘친다(spill-over).** Cursor 스태프 확인: 개인 Pro는 *"Auto/Composer를 쓰다가 Auto+Composer 풀이 떨어지면 사용량이 API 쿼터로 넘어간다 … Composer 2.5는 Auto+Composer 풀에 묶여 있지 않다. API 쿼터가 남아 있으면 거기서 계속 동작한다"*, Teams 신규 요금제는 *"Auto/Composer/Grok 사용은 first-party 풀에서 먼저 나가고, 그 풀이 소진되면 추가 사용분은 API 풀에서 나간다"*. **개인·Teams 양쪽 모두 성립한다.** 넘어간 분은 해당 모델의 per-token 정가(Grok $2/$0.50/$6, Composer Std $0.50/$0.20/$2.50)로 과금되고, 달러 풀까지 소진되면 on-demand가 같은 API 정가로 이어받는다.
   - 반대 방향은 **잔액 이전이 아니라 모델 라우팅**이다: third-party 달러가 소진되면 Cursor가 요청을 first-party 모델로 **전환**해 예상치 못한 overage를 막는다. 즉 *미사용* first-party 잔량이 third-party 초과분을 메워주지는 않는다 — 이 서술이 일부 2차 자료에서 "siloed"로 잘못 요약돼 있다.
   - **이 성질이 §9.4의 Cursor 숫자를 바꾼다.** first-party 풀이 상한이 아니라 **바닥**이고, 그 위에 달러 풀 + on-demand가 얹힌다.
2. **first-party 풀은 2026-07-16/21에 영구적으로 2배가 됐다.** 개인(Pro·Pro+·Ultra)·Teams 전 플랜 대상이며 종료일이 공지되지 않았다. Hobby·레거시 엔터프라이즈는 제외.
3. **크기는 공개되지 않는다.** Cursor 스태프는 *"상위 티어일수록 first-party 한도도 높다"*고만 확인했고, *"Cursor Models 풀에 대해서는 깔끔한 N배 숫자를 제시하지 않는다"*고 명시했다. 전체 볼륨 기준으로 Ultra ≈ Pro의 20배라는 언급만 있다(이는 third-party 달러 풀의 $400/$20 = 20배와 정확히 일치한다).
4. **Grok 4.5의 출시 50% 할인은 2026-07-21에 종료됐다.** 이제 Grok은 (2배가 된) 풀을 full per-token rate로 소모한다.

**"보너스 크레딧"이라 불리는 것이 실은 세 가지다** — 이 계획에 유효한 건 하나뿐이다.

| 통칭 | 실체 | $21~$51 구간에서 유효한가 |
| --- | --- | --- |
| 플랜가 초과 포함분 | Pro+ $60 → **$70**, Ultra $200 → **$400**. 상위 티어일수록 배수가 커진다 | △ Pro는 $20 → $20으로 1:1이라 이 구간에선 보너스가 아니다. 다만 spill-over 때문에 **이 달러 풀도 실제로 쓰이긴 한다** |
| **first-party 풀 영구 2배** (2026-07) | 달러가 아니라 별도 한도의 확장 | ✅ **가장 큰 보너스** |
| 레퍼럴 보너스 | 신규 가입 유도용 일회성 크레딧 | ❌ 반복 예산과 무관 |

**추정 — 그림자 달러로 환산하면.** 풀 크기가 미공개이므로 직접 계산이 불가능하다. 유일하게 근거 있는 앵커는 *"Ultra ≈ 20× Pro"*가 third-party 달러비($400/$20)와 정확히 일치한다는 점이다. **first-party 풀도 같은 비율로 스케일하고, Pro의 first-party 풀이 대략 플랜가 수준의 추론량을 담았다고 보면**, 2026-07 2배 적용 후 Pro ≈ **$40 상당**이 된다. 여기에 spill-over(성질 1)로 **달러 풀과 on-demand가 순차로 얹힌다**:

| 시나리오 (Pro $20 + on-demand $1) | first-party 풀 (그림자) | + 달러 풀 $20 | + on-demand $1 | **작업 수/월** |
| --- | --- | --- | --- | --- |
| 비관 — 풀 ≈ 플랜가, 2배 미반영 | $20 → 1.7 | +1.7 | +0.1 | **3.5** |
| **기준 — 플랜가 × 2배** | **$40 → 3.4** | **+1.7** | **+0.1** | **5.2** |
| 낙관 — Cursor가 자사 인프라를 크게 보조 | $120 → 10.1 | +1.7 | +0.1 | **11.9** |

> ⚠️ **first-party 풀 열은 추정이며, 이 문서에서 신뢰도가 가장 낮은 숫자다.** Cursor가 수치를 공개하지 않으므로 유일한 확정 방법은 **`cursor.com/dashboard/usage`의 카운터를 dev-loop 1사이클 전후로 읽는 것**이다. 그 한 번의 측정이 위 3행을 1행으로 줄인다(§9.7). 반면 달러 풀·on-demand 열은 정가가 공개돼 있으므로 확정값이다.

**계정은 이미 Team이다 (2026-08-02 확인).** 초판이 권했던 *"Teams Standard 시드로 전환"*은 **철회한다** — 표기부터 오기였고(*시드*가 아니라 **시트**, seat = 좌석), 이미 회사 Team 계정이므로 전환할 대상이 없다. Team 계정에서 실제로 남는 레버는 **시트 등급**뿐이다:

| Cursor Teams 시트 | 월 가격 (연납) | 포함 사용량 | $51 예산 안에 들어오나 |
| --- | --- | --- | --- |
| **Standard** (현재로 추정) | $40 ($32) | 기준 | ✅ |
| **Premium** | $120 ($96) | **Standard의 5배**(두 풀 모두), 가격은 3배 | ❌ **예산 초과** |

Premium 시트는 **3배 가격에 5배 사용량**이라 단위당 가치는 명확히 낫지만 $120/월이라 $51 밖이다. 따라서 **$51 구간에서 Cursor를 늘리는 방법은 on-demand밖에 없고, 그 추가분은 전부 정가 종량이다.**

| $51 예산의 구성 | 계산 | **작업 수/월** |
| --- | --- | --- |
| first-party 풀 (그림자 $40) + 달러 풀 $20 + on-demand $31 | 3.4 + 1.7 + 2.6 | **7.7** |

두 가지를 덧붙인다. **(a) §8.3 제약 1은 Team 계정이면 이미 해결 가능하다** — 관리자 모델 허용 목록으로 조용한 폴백을 막을 수 있으므로, 이건 예산 문제가 아니라 **관리자 설정 한 번**의 문제다. 하네스의 T1 핀이 무시되면 비용도 품질도 예측 불가가 되므로 우선 확인할 것. **(b) Teams·Enterprise에는 third-party 요청에 $0.25/1M의 Cursor Token Rate 부가금**이 붙지만 **first-party 모델은 면제**다 — 이 계획에는 거의 영향이 없다(spill-over분의 면제 여부만 미확인). 조직 차원에서는 **Enterprise의 pooled usage**(시트별이 아니라 조직 전체가 사용량을 공유)가 별도 레버지만, 개인 예산 결정이 아니라 계약 협상 사항이다.

### 9.6 예산보다 큰 레버 — 라운드 수, 그다음이 implementer

**(a) remediation 라운드 수.** §2b의 경고가 숫자로 확인된다. 라운드 수만 바꾼 민감도:

| remediation 라운드 | 1작업 단위 | 기본 예산 합계 | 상한 예산 합계 |
| --- | --- | --- | --- |
| 0회 (클린런) | 1.25 | **30.0** | **157.0** |
| 1회 | 1.95 | 19.2 | 100.7 |
| 1.5회 (기준) | 2.30 | 16.4 | 85.4 |
| 3회 (loop budget 상한) | 3.35 | 11.3 | 58.6 |

**라운드 1.5회 → 0회가 16.4 → 30.0작업(1.8배)**이다. Opus→Sonnet 전면 교체(1.67배)보다 크고, 예산을 늘리지 않고 얻는다. §7의 "라운드 수를 유일한 성공 지표로"가 예산 관점에서도 맞다는 뜻이다.

**(b) implementer를 T1에서 내리는 것 — 플랫폼마다 값이 다르다.** 같은 구조 변경인데 절감폭이 3.5배 차이 난다.

| 변경 | 변경 후 $/작업 | 기본 예산 작업 수 | 증가율 |
| --- | --- | --- | --- |
| **Codex**: implementer Sol → **Terra/high** ✅ 채택 | 13.8 | 5.2 → **7.2** | **+38%** |
| **Cursor**: implementer Grok → **Composer Std** (미채택) | 8.5 | 5.2 → **7.2** | +38% |
| **Claude**: 리뷰어 2종 Opus → Sonnet (미채택) | 21.6 | 4.0 → **4.6** | +15% |

이것이 §2a와 §8.1의 결론을 예산으로 재확인한다: **Claude에서는 모델 교체의 절감이 작고(1.67배 격차), Codex·Cursor에서는 크다.** 따라서 최적화 순서가 플랫폼마다 다르다 — **Claude는 라운드 수와 캐시 정렬(§6), Codex·Cursor는 implementer 티어**가 1순위다.

**Codex `implementer` = Terra / high로 확정한 근거 (2026-08-02).** §4의 *"Terra 미사용"* 결정을 이 역할에 한해 뒤집었다.

| 축 | Sol | **Terra** | Luna | 판정 |
| --- | --- | --- | --- | --- |
| **MRCR v2 8-needle 256K~512K** | 91.5 | **89.6** | 41.3 | Terra는 Sol과 **1.9pp** 차. **절벽은 Luna에만 있다** |
| MRCR v2 8-needle 512K~1M | 73.8 | 72.5 | 41.3 | 동일 결론 |
| SWE-Bench Pro | 64.6% | 63.4% | — | **1.2pp** 차 |
| AA Coding Agent Index | 80 | 77.4 | 74.6 | 2.6pt 차 |
| $/라운드 단위 | 13.50 | **5.40** (medium) / 6.87 (high) | 0.54 | **2.0~2.5배 싸다** |

핵심은 **AA의 Pareto 논증이 Luna를 값싼 대체재로 경유한다**는 점이다 — *"어떤 Terra effort 조합에도 더 낫거나 더 싼 Luna/Sol 조합이 존재한다."* 그런데 `implementer`는 plan + research + 컨벤션 + 코드를 함께 싣는 장문맥 역할이라 **Luna가 애초에 후보가 아니다.** 선택지가 Sol과 Terra 둘로 좁혀지면 Pareto 논증은 적용되지 않고, 남는 것은 위 표의 1~2pp 격차와 2.0~2.5배 가격차뿐이다.

**effort로 대응하는 안에 대해.** 이것은 §4 effort 원칙 1(*"모델은 아래로, effort는 위로"*)의 교과서적 사례다. Terra를 `high`로 올리면 추론 토큰이 늘어 라운드당 $5.40 → **$6.87**(1.5배 가정)이 되지만, **Sol `medium`의 $13.50에는 여전히 절반 수준**이다. 세 가지를 함께 봐야 한다:

- **effort는 격차를 메우지 초과하지 못한다.** AA 관측은 기본 effort → `max`가 티어 전반에 **2~4점**인데, Sol–Terra의 모델 격차가 정확히 그 범위(AA Index 4점, Coding Agent Index 2.6점)다. 즉 **Terra/high ≈ Sol/medium에 근접할 수는 있어도 넘어서지는 못한다** — 목표를 "동급 도달"로 잡아야지 "상회"로 잡으면 안 된다.
- **`ultra`는 여전히 금지**(§4 원칙 3). 3배 비용에 +3.1점이고 dev-loop의 위임과 충돌한다.
- **실패 꼬리는 §3-C cascade가 받는다.** Terra가 막히면 3-fail 시 Sol로 1회 승격하므로, 하향의 리스크가 구조적으로 잘려 있다. **이것이 Terra 전환을 §7-8(cascade) 이후로 두어야 하는 이유다.**

### 9.7 운용 결론

1. **소진 순서는 §9.8에 확정돼 있다 — Cursor → Claude → Codex.** 정렬 기준은 비용이 아니라 승인 마찰이지만, 결과적으로 **가장 값싼 Cursor가 먼저**라 비용 관점과도 충돌하지 않는다. Cursor를 먼저 태워야 하는 고유한 이유도 있다 — 보조된 first-party 풀은 **남긴 채 월을 넘기면 그냥 소멸한다.**
2. **Cursor 설정에서 Composer Standard를 강제하라.** Fast가 기본값이고, 풀을 3.6배 빨리 태우며, T1인 Grok보다도 비싸 티어가 역전된다(§9.3).
3. **Cursor는 $21에서 묶는다(§9.8).** 계정이 이미 Team이고 Premium 시트($120/월)는 예산 밖이라 추가분은 전부 정가 종량이 되는데, 승인 1회당 가치가 Codex $150 단계의 1/4에 불과하다.
4. **[필수] Cursor에 spend limit을 걸어라.** first-party 풀이 비면 **경고 없이 달러 풀 → on-demand 순으로 자동 전환**된다(§9.5 성질 1). 예산 상한이 곧 정책인 환경에서는 이 자동 전환이 그대로 초과 지출이 되므로, 승인된 상한($21 또는 $51)에 하드 리밋을 설정하는 것이 §9.4 계산의 전제다.
5. **Cursor 관리자 모델 허용 목록을 먼저 확인하라.** Team 계정이므로 §8.3 제약 1(핀이 조용히 폴백되는 문제)을 설정 한 번으로 막을 수 있다. 이걸 안 하면 §9.4의 Cursor 열 전체가 무의미해진다.
6. **가장 큰 단일 배치 변경은 Codex `implementer` → Terra/high다** — 기본 예산에서 월 +2.0작업(+38%), 상한에서 +14작업이다. 단 §7-8(cascade) 이후에 적용해 실패 꼬리를 먼저 확보할 것(§9.6b).
7. **이 문서의 모든 수치는 정가 기준이다.** Sonnet 5 인트로 가격(~2026-08-31)은 **부록 B**에만 남겼다 — 8월 실측치를 9월 계획의 근거로 쓰지 말 것.

---

### 9.8 예산 소진 순서 — 확정 계획 (2026-08-02)

**정렬 기준은 비용 효율이 아니라 조직 마찰이다.** 세 쿼터는 서로 독립된 예산 항목이고 승인 절차의 무게가 다르므로, **승인이 가벼운 것부터 소진한다.**

| 순서 | 풀 | 금액 | 요구되는 승인 | $/작업 | 이 단계 작업 | **누적 작업** |
| --- | --- | --- | --- | --- | --- | --- |
| **1** | **Cursor** | $21 | **없음** | 11.9 | 5.1 | **5.1** |
| **2** | **Claude** | $100 (여기서 중지) | 리더 승인 | 25.2 | 4.0 | **9.1** |
| **3** | **Codex** | $150 단위로 최대 $700 | 리더 승인 + **IT Operations 검증** | 13.8 | +10.9 / 단계 | **20.0 → 59.8** |

3단계 상세:

| Codex 누적 | 이 단계 작업 | 전체 누적 작업 |
| --- | --- | --- |
| $150 | 10.9 | 20.0 |
| $300 | 10.9 | 30.8 |
| $450 | 10.9 | 41.7 |
| $600 | 10.9 | 52.6 |
| $700 (최종 +$100) | 7.2 | **59.8** |

**전량 소진 시 월 약 60작업, 총예산 $821.**

**요구하지 않기로 한 것 둘 (2026-08-02 결정):**

- **Cursor on-demand $30 (→ $51)** — 추가분이 전부 정가 종량이라 단위 효율이 개선되지 않는데(§9.5), 얻는 것은 **+2.6작업**뿐이다. 같은 승인 한 번으로 Codex는 $150에 **+10.9작업**을 준다. **승인 1회당 가치가 4배 차이**나므로 Cursor 증액은 요구하지 않는다.
- **Claude $100 초과 (→ $680)** — **작업당 단가가 세 풀 중 가장 높다**($25.2 vs Codex $13.8 vs Cursor $11.9). Opus→Sonnet 격차가 1.67배뿐이라 티어링으로 개선할 여지도 가장 작다(§2a). $100에서 중지한다.

**이 순서가 만드는 성질 두 가지.**

1. **승인 요청 1회당 수익이 뒤로 갈수록 커진다.** 요청 0회로 5.1작업, 가벼운 요청 1회로 9.1작업, 그 뒤로는 무거운 요청 1회당 +10.9작업이다. 즉 **월 9작업이 넘어갈 것 같으면 2단계를 건너뛰고 3단계로 가는 편이 요청 횟수 기준으로 효율적**이지만, 그건 마찰이 아니라 총량을 기준으로 정렬한 순서다. 현재 계획은 **의도적으로 마찰을 우선**한다.
2. **쿼터가 독립적이라 순서가 총량을 바꾸지 않는다.** 어떤 순서로 써도 상한은 59.8작업이다. 순서가 정하는 것은 *언제 승인 게이트를 만나는가*뿐이며, 이 계획은 그 시점을 최대한 뒤로 미룬다.

> §9.4의 "상한 예산" 열은 **$680 / $700 / $51을 모두 쓸 때의 이론적 상한**(85.4작업)이다. 위 계획은 그중 Claude를 $100, Cursor를 $21로 묶었으므로 **실제 계획 상한은 59.8작업**이다. 단, 이 표는 현행 `dev-loop`(4축 리뷰) 기준이다 — **§9.9의 경량 변형을 기본값으로 쓰면 같은 예산에서 158.2작업**이 된다.

### 9.9 dev-loop 경량 변형 — 신규 스킬 2종 (2026-08-02 확정)

**현행 `dev-loop`의 4축 강제 리뷰가 대부분의 작업에 과하다는 판단에 따라, 리뷰 강도가 다른 변형 2종을 신설한다.** 세 스킬은 병존하며 서로를 대체하지 않는다.

| 스킬 | 구성 | 용도 |
| --- | --- | --- |
| `dev-loop` (현행 유지) | implement + test(mutation 포함) + **리뷰 4축** | **진짜 심각하거나 거대한 기능 개발** |
| **`dev-loop-light`** (신규) | implement + test(**mutation 제외**) + **maintainability · senior-generalist 2축** | **Codex 기본값** |
| **`dev-loop-noreview`** (신규) | implement + test(**mutation 제외**), **리뷰 없음** | **Cursor · Claude 기본값** |

**계산 가정**: mutation testing ≈ test-dev 토큰의 40%(라운드 내 tester 비중 15% → 9%, remediation의 reduced-test 8% → 5%), remediation 라운드 1.5회 → `light` 1.0회 → `noreview` 0회(리뷰가 없으면 finding이 없다). 나머지는 §9.2 그대로.

**라운드 단가**

| | Claude | Codex | Cursor |
| --- | --- | --- | --- |
| `dev-loop` | $10.94 | $6.00 | $5.18 |
| `dev-loop-light` | $6.47 (−41%) | $2.59 (−57%) | $3.30 (−36%) |
| `dev-loop-noreview` | $4.13 (−62%) | $2.45 (−59%) | $2.65 (−49%) |

**작업 1회 단가** (plan-dev · remediation · commit 포함, §9.4의 정가 기준값에 감소율을 적용)

| | Claude | Codex | Cursor |
| --- | --- | --- | --- |
| `dev-loop` | $25.2 | $13.8 | $11.9 |
| `dev-loop-light` | $13.36 (**−47%**) | $5.38 (**−61%**) | $6.43 (**−46%**) |
| `dev-loop-noreview` | $7.06 (**−72%**) | $5.11 (**−63%**) | $4.40 (**−63%**) |

**기본값 배정의 근거 — T2 티어 단가가 결정한다.** 두 변형의 격차가 플랫폼마다 다르다:

| | `light` → `noreview` 추가 절감 | 남은 리뷰어 2종의 모델 |
| --- | --- | --- |
| **Codex** | **−5%** ($5.38 → $5.11) | Luna $0.54/라운드 단위 — **사실상 공짜** |
| Cursor | −32% ($6.43 → $4.40) | Composer $2.60 |
| **Claude** | **−47%** ($13.36 → $7.06) | Sonnet $9.38 |

Codex에서는 `light`가 이미 `noreview` 절감의 95%를 달성하므로 **리뷰 2축을 더 버려도 얻는 것이 작업당 $0.27뿐**이다. 반대로 Claude는 T2가 Sonnet이라 리뷰어 2종이 여전히 비싸고, Cursor는 Composer로 그 중간이다. **확정된 기본값(Codex→`light`, Cursor·Claude→`noreview`)은 이 경제성과 정확히 일치한다.**

**민감도**: 가장 무른 가정인 remediation 라운드 감소(1.5 → 1.0)를 빼고 1.5회로 두면 `light`의 감소율이 Claude −47%→−40%, Cursor −46%→−41%로 움직이지만 **Codex는 −61%→−60%로 사실상 불변**이다. mutation 비중을 40%→60%로 바꿔도 1pp 이내다. **결론은 리뷰 축 수에 거의 전적으로 달려 있다.**

**§9.8 예산 계획에 대입하면** (각 풀에 확정 기본값 적용):

| 순서 | 풀 · 사용 스킬 | $/작업 | 이 단계 작업 | **누적 작업** |
| --- | --- | --- | --- | --- |
| 1 | Cursor $21 · `noreview` | 4.40 | 13.9 | **13.9** |
| 2 | Claude $100 · `noreview` | 7.06 | 14.2 | **28.1** |
| 3 | Codex $150 단위 → $700 · `light` | 5.38 | +27.9 / 단계 | **56.0 → 158.2** |

**승인 없이 쓸 수 있는 구간이 5.1 → 13.9작업, 전량 소진 시 59.8 → 158.2작업(2.6배)이 된다.** 예산을 한 푼도 늘리지 않고 얻는 값이라, §7의 어떤 항목보다 절감폭이 크다.

> **§7-3(diff-class 자동 게이팅)과 겹친다.** 그쪽은 trivial diff에서 축을 4→2로 *자동* 축소하는 규칙이고, `dev-loop-light`는 같은 축소를 *사람이 스킬 선택으로* 결정한다. 기본값을 `light`/`noreview`로 두면 자동 게이팅의 한계 이득이 줄어들므로, **§7-3은 `dev-loop`(전체 4축)을 쓰는 무거운 작업에만 적용되는 레버로 축소해서 보아야 한다.**

---

## §10. 결정 기록 / 남은 확인

**2026-08-02에 초판의 열린 질문 13건이 전부 처리됐다.** 아래는 무엇이 어떻게 정해졌는지의 기록이다 — 근거가 있는 것은 근거를, 사용자 판단인 것은 그렇다고 밝힌다.

| # | 항목 | 결정 | 근거·성격 |
| --- | --- | --- | --- |
| 1 | Cursor first-party 풀의 실제 크기 | **조사하지 않는다.** §9.5의 그림자 추정을 그대로 쓴다 | 사용자 판단 — 값이 수시로 바뀌므로 대략값이면 충분 |
| 2 | 장문맥 할증 임계 대응 | **대응하지 않는다.** 2배로 튀면 튀는 대로 쓴다 | 사용자 판단 — 실효적 대안이 없다. 단 §6d의 컨텍스트 축소 레버는 여전히 유효하다 |
| 3 | Codex `implementer`를 Terra로 | ✅ **채택. Terra / high** | **조사 결과** — MRCR 89.6 vs Sol 91.5, SWE-Bench Pro 63.4% vs 64.6%, 가격 2.5배 차(§9.6b) |
| 4 | Cursor 시트 등급 | **현행 유지.** Premium 시트($120/월)는 $51 예산 밖 | **조사 결과** — 계정이 이미 Team이므로 초판의 “전환” 권고는 철회(§9.5) |
| 5 | Cursor가 `.claude/agents/`를 읽는가 | **무관. `agents/cursor/` 변형을 별도 신설한다** | 사용자 결정 — 교차 인식에 의존하면 방언 차이를 알아챌 수 없다(§8.3) |
| 6 | Cursor의 `[effort=…]` 지원 | **Grok 4.5 가능 / Composer 2.5 불가** | 사용자 확인 — Cursor의 effort 레버는 T1에만 존재(§8.3, §4) |
| 7 | Cursor의 read-only 약화 | ✅ **수용.** `readonly: true`로 표현 가능한 만큼만 보장 | 사용자 결정 — 별도 세션 우회는 미채택(§8.3) |
| 8 | Cursor Skills 교차 인식 | **무관. `skills/cursor/` 변형을 별도 신설한다** | 사용자 결정 — 5번과 동일(§8.3) |
| 9 | Sonnet 5 인트로 가격 | **전 계산을 정가 기준으로 통일.** 인트로 버전은 부록 B에 별첨 | 사용자 결정 — 8월 수치로 9월 계획을 세우지 않기 위함 |
| 10 | §6c 리뷰 필터 완화 | ✅ **이 리팩토링에 포함.** §7-5에서 리뷰어 티어 분화와 같은 단계에 처리 | 사용자 결정(§6c) |
| 11 | `plan-consultant` 호출 상한 | **상한 없이 진행.** `(design-bearing)` 태그가 유일한 게이트 | 사용자 결정 — 사후 대시보드 관찰로 대체(§3-B) |
| 12 | §9 토큰 프로파일 실측 | **하지 않는다.** 현재 예측값으로 진행 | 사용자 판단 — §9의 모든 수치는 추정으로 남는다 |
| 13 | Claude $100의 실체 | ✅ **API 정가 정량이 맞다** | **조사 결과** — Claude Enterprise는 *“시트가 + API 정가 종량”*이며 chat·Claude Code·Cowork의 **모든 토큰이 정가로 계량**된다. 포함 사용량이 없다 |

> **13번 부연**: Enterprise는 Team과 과금 모델이 다르다. Team의 Premium 시트($100/seat)는 *"표준 시트의 5배 사용량"*이 **포함된** 정액형이지만, **Enterprise는 시트가가 접근권만 사고 사용량은 전량 별도 종량**이다. 즉 §9.4의 Claude 계산(정가 토큰 × 4축)이 조건 없이 그대로 적용되며, §9.4의 4.0작업은 하한이 아니라 **실제 추정치**다. 초판이 병기했던 *"Team Premium 시트라면 하한일 수 있다"*는 단서는 이로써 무효다.

### 추적하지 않기로 한 항목 (2026-08-02)

**열린 질문은 남기지 않는다.** 아래 넷은 확인하면 §9의 정밀도가 올라가지만, **확인 비용 대비 의사결정을 바꾸지 않으므로 추적하지 않는다.** 나중에 §9 수치가 실제와 크게 어긋나면 여기부터 의심하면 된다.

- **Cursor 관리자 모델 허용 목록에 Grok 4.5·Composer 2.5가 있는지** — 없으면 §8.3 제약 1(T1 핀이 조용히 폴백)이 발동해 §9.4의 Cursor 열이 성립하지 않는다. **넷 중 영향이 가장 큰 항목**이지만, 실제로 폴백이 일어나면 사용량 대시보드에서 드러나므로 사전 확인 없이 사후 관찰로 대체한다.
- **현재 Cursor 시트 등급(Standard / Premium)** — §9.5의 그림자 풀 추정은 Standard 가정이다. Premium이면 first-party 풀이 5배라 Cursor 작업 수가 크게 늘어난다(= 현재 추정이 보수적이라는 뜻).
- **Codex(Sol·Terra)의 장문맥 할증 임계** — Grok은 200K로 확정됐으나 GPT 계열은 미확인. 어차피 할증에 대응하지 않기로 했으므로(§10-2) 조치 항목이 아니며, §9.4의 Codex 수치가 낙관 쪽으로 치우칠 수 있다는 단서로만 남긴다.
- **Cursor Token Rate($0.25/1M) 면제가 spill-over분에도 유지되는지** — first-party 모델은 면제지만 그 사용이 달러 풀에서 나갈 때의 취급은 문서에 없다. 금액 영향이 작다.

---

## 부록 A. 병합된 선행 조사 (`RESEARCH_MODEL_ROUTING.md`, 2026-07-31 삭제)

Codex 중심으로 작성된 별도 조사 문서를 이 문서에 병합했다. 원본은 삭제했으므로, **채택한 것과 기각한 것을 여기에 남긴다.**

**채택 (이 문서에 없던 레버):**

| 항목 | 반영 위치 |
| --- | --- |
| 조건부·자동·짧은 **Implementation Brief** (인간 승인 없음, 별도 아티팩트) | §3-D |
| **Cascade** — 3-fail 시 중단 대신 T1 1회 재시도 | §3-C, §7-8 |
| TODO `(mechanical)` / `(design-bearing)` 난이도 태그 | §3-B |
| **trivial diff 시 리뷰 축 축소**(4축 → 2축, 화이트리스트) | §6b, §7-3 |
| **diff-class 라벨 스크립트**가 축 수·Brief·mutation을 규칙으로 게이팅 | §6a-4, §7-3 |
| 교차 벤더 리뷰 (`skills/codex/review-code-claude`가 이미 그 패턴) | §6c |
| 롤백 기준 (라운드 +1, 보안 누락 연속, instruction drift, blocked 증가) | §7 |
| Cursor **Composer Standard vs Fast** 함정 | §8.4 |

**기각 / 정정 (선행 조사가 이 문서와 충돌한 지점):**

1. ~~**"Mid = Terra"**~~ — **2026-08-02에 이 기각을 부분 철회한다.** 당시 근거는 두 가지였다: (a) 선행 조사의 단가가 2026-07-30 인하 이전 값이라는 것(이건 여전히 사실이다 — 실제는 Terra $2/$12, Luna $0.20/$1.20), (b) Artificial Analysis의 **"Luna·Sol이 Terra를 Pareto 지배"**. **(b)가 `implementer`에는 적용되지 않는다** — 그 논증이 경유하는 값싼 대체재 Luna가 장문맥으로 실격이기 때문이다(MRCR 41.3%). **결과적으로 선행 조사의 "Mid = Terra"가 이 역할에 한해 옳았다.** §4·§9.6b 참조. 다른 역할에서는 기각을 유지한다.
2. **"L 티어 = Haiku/Luna로 탐색·기계 작업"** — 방향은 이 문서와 같으나, 이 문서는 한 발 더 나간다: 그 작업들은 **모델이 아니라 셸로** 내리는 것이 맞다(§6a). 최하위 티어에 남길 일이 사실상 없다는 것이 §8.1의 결론이다.
3. **Sonnet 5 / Opus 4.8 벤치마크 표와 "Sonnet 5는 cyber 능력이 의도적으로 낮다"** — 이번 세션에서 직접 검증하지 못했다. 다만 사실이라면 §4의 `security-reviewer` T1 유지 결정을 **강화**하는 방향이므로, 배치를 바꾸지 않고 근거만 보류해 둔다.

## 부록 B. Sonnet 5 인트로 가격 기준 수치 (2026-08-31 종료)

**의사결정에 쓰지 말 것.** 본문 §9의 모든 수치는 정가 기준이며, 이 부록은 8월 한 달에 한해 실제 청구액이 얼마나 낮게 나오는지를 대조하기 위한 참고값이다. 인트로가 종료되면 이 표는 폐기한다.

| | 입력 | 캐시 입력 | 출력 | 캐시 쓰기 | $/라운드 단위 |
| --- | --- | --- | --- | --- | --- |
| Sonnet 5 **정가** (본문 기준) | 3.00 | 0.30 | 15.00 | 3.75 | 9.38 |
| Sonnet 5 인트로 (~2026-08-31) | 2.00 | 0.20 | 10.00 | 2.50 | 6.25 |

| Claude 풀 (T1 Opus 25% / T2 Sonnet 75%) | $/라운드 | $/작업 | $100 | $680 |
| --- | --- | --- | --- | --- |
| **정가 (본문)** | 10.94 | 25.2 | **4.0** | **27.0** |
| 인트로 (8월 한정) | 8.60 | 19.8 | 5.1 | 34.4 |

세 풀 합계로는 기본 예산 **16.4 → 17.5작업**, 상한 예산 **85.4 → 92.8작업**이 된다. 차이는 약 7%로, **8월 실측치를 9월 계획의 근거로 삼으면 Claude 몫을 약 21% 과대평가하게 된다**(5.1 → 4.0).

## 출처

- [An Empirical Study on Strong-Weak Model Collaboration for Repo-level Code Generation](https://arxiv.org/abs/2505.20182) — 강 모델 동등 성능 @ 40% 비용 절감
- [Which Model Reviews Code Best? — Factory.ai](https://factory.ai/news/code-review-benchmark) — 13개 모델 × 50 PR 리뷰 벤치마크, 비용이 품질 분산의 21%만 설명
- [AI Coding Cost Analysis: Where Token Spend Really Goes in an Agent Loop — Augment Code](https://www.augmentcode.com/guides/ai-coding-cost-analysis-agent-token-spend) — 입력 99%+, cache read 94.5%, "루프 아키텍처가 모델 선택보다 중요"
- [Best AI Model for Coding Agents in 2026: A Routing Guide — Augment Code](https://www.augmentcode.com/guides/ai-model-routing-guide) — RouteLLM 라우팅 결과, 3-tier Claude 라우팅
- [Claude Code — Create custom subagents](https://code.claude.com/docs/en/sub-agents) — `model`/`effort` frontmatter, 모델 해석 우선순위, 서브에이전트별 캐시, fork 동작, 3계층 제한
- [Claude Code — Extend Claude with skills](https://code.claude.com/docs/en/skills) — 스킬 frontmatter `model`/`effort`/`context: fork`, 턴 스코프 제약
- Anthropic 모델 가격·캐시 메커니즘·Opus 5/Sonnet 5 마이그레이션 가이드 (`claude-api` 스킬 번들 문서)
- [openai/codex — `agent_roles.rs`, `config.schema.json`, `multi_agents_common.rs`, `openai_models.rs`](https://github.com/openai/codex) (Context7 `/openai/codex`) — agent role TOML이 `ConfigToml`을 flatten해 `model`/`model_reasoning_effort`를 받는다는 점, `[agents] default_subagent_*` fallback 해석 순서, `ReasoningEffort` 8단계 enum, 모델별 `supported_reasoning_levels`
- [Artificial Analysis — GPT-5.6 has landed](https://artificialanalysis.ai/articles/gpt-5-6-has-landed) — Intelligence Index v4.1 max effort 점수(Sol 59 / Terra 55 / Luna 51), **Terra Pareto 열위** 근거
- [GPT-5.6 Sol vs Terra vs Luna — Vellum](https://www.vellum.ai/blog/gpt-5-6-sol-terra-luna-explained) — 인하 후 가격표, AA Coding Agent Index(80 / 77.4 / 74.6), *"max·ultra는 루틴 작업에서 컴퓨트 낭비"*
- [GPT-5.6 Sol, Terra, Luna 벤치마크 분석 — The Agent Report](https://the-agent-report.com/2026/07/gpt-5-6-sol-terra-luna-benchmarks-pricing-analysis/) — 기본→max가 2~4점, Sol medium이 Fable 5 대비 +11.4점/약 1/4 비용, **Luna MRCR 41.3% vs Sol 91.5%**, ultra는 Terminal-Bench 3배 비용/+3.1점
- [Cursor Docs — Subagents](https://cursor.com/docs/context/subagents) — `.cursor/` · **`.claude/`** · `.codex/agents/` 교차 인식, `model` 파라미터 문법(`[effort=high]`), 폴백 조건, `readonly` 필드, 중첩 2계층 제한
- [Cursor 2.4 changelog — Subagents, Skills](https://cursor.com/changelog/2-4) — 서브에이전트·`SKILL.md` 도입
- [Grok 4.5 — OpenRouter](https://openrouter.ai/x-ai/grok-4.5) / [Grok 4.5 리뷰 — DataCamp](https://www.datacamp.com/blog/grok-4-5) — $2/$6, cached input, 500K 컨텍스트, effort `low/medium/high`, SWE-Bench Pro 64.7%, 출력 토큰 효율
- [Composer 2.5 vs Grok 4.5 — BenchLM](https://benchlm.ai/compare/composer-2-5-vs-grok-4-5) / [Composer 2.5 — DataCamp](https://www.datacamp.com/blog/composer-2-5) — agentic 69.3 vs 83.3, CursorBench·SWE Multilingual, 컨텍스트·태스크당 비용
- [OpenAI GPT-5.6 가격 인하 (2026-07-30)](https://www.aipricing.guru/openai-pricing/) — Sol $5 / Terra $2 / Luna $0.20

**§6d 세션 길이 vs 컨텍스트 크기 (2026-08-02 조사)**

- [AI Agent Loop Token Costs: How to Constrain Context — Augment Code](https://www.augmentcode.com/guides/ai-agent-loop-token-cost-context-constraints) — **누적 청구 입력이 세션 길이의 제곱으로 증가**(20스텝 × 1,000토큰 = 20,000이 아니라 210,000)
- [Agent Context Compaction for Long-Running Sessions — Zylos Research](https://zylos.ai/research/2026-04-21-agent-context-compaction-long-running-sessions/) — *"캐시 읽기와 캐시 재작성 모두 세션 길이에 따라 제곱으로 증가"*, compaction 시 선형으로 복귀, *"cache miss 시점에 compact하면 두 항을 동시에 친다"*
- [xAI Docs — How Prompt Caching Works](https://docs.x.ai/developers/advanced-api-usage/prompt-caching/how-it-works) — 자동·**접두 일치** 캐싱, 메모리 압박·서버 라우팅으로 축출 가능(보장 아님), `x-grok-conv-id`로 히트율 개선
- [Grok API Pricing — BenchLM](https://benchlm.ai/xai/api-pricing) / [Grok 4.5 Review — Bleap](https://www.bleap.finance/en-us/blog/grok-4-5-explained) — 200K 초과 시 $4/$1/$12이며 *"한계 초과분이 아니라 요청의 모든 토큰에 적용"*, **캐시 입력가도 $0.50 → $1.00으로 함께 상승**

**§4·§9.6b Terra 전환 근거 · §10 결정 조사 (2026-08-02)**

- [GPT-5.6 Sol, Terra & Luna: Benchmarks, Specs & Pricing — Kingy](https://kingy.ai/blog/gpt-5-6-sol-terra-luna-benchmarks-specs/) — **MRCR v2 8-needle: Sol 91.5 / Terra 89.6 / Luna 41.3** (256K~512K), **73.8 / 72.5 / 41.3** (512K~1M). **장문맥 절벽은 Luna에만 있고 Terra는 Sol과 같은 편**이라는 결정적 근거
- [GPT-5.6 Sol vs Terra vs Luna: Full Comparison — AI Tools Review](https://aitoolsreview.co.uk/insights/gpt-5-6) — **SWE-Bench Pro Terra 63.4% vs Sol 64.6%**(1.2pp), 코딩 벤치 전반에서 1~2pp 격차
- [Claude — Plans & Pricing](https://claude.com/pricing) — **Enterprise = "시트가 + API 정가 종량"**, *"Usage cost scales with model and task"*. Team Premium 시트($100/seat, 표준의 5배 사용량 포함)와 과금 모델이 다름
- [Claude Enterprise Pricing — Tygart Media](https://tygartmedia.com/claude-enterprise-pricing-large-organizations-2026/) — *"시트 요금에 사용량이 포함되지 않는다 — chat·Claude Code·Cowork의 모든 토큰이 표준 API 요율로 계량된다"*
- [Improvements to Teams Pricing — Cursor](https://cursor.com/blog/teams-pricing-june-2026) — **Standard 시트 $40/월($32 연납) · Premium 시트 $120/월($96 연납)**, Premium은 **3배 가격에 5배 포함 사용량**(두 풀 모두). Enterprise는 협상가 + **조직 단위 pooled usage**

**§9 예산 분석 (2026-08-02 조사)**

- [Codex rate card — OpenAI Help Center](https://help.openai.com/en/articles/20001106-codex-rate-card) — 모델별 크레딧/1M 토큰 rate card (원문 접근 403, 아래 2차 출처로 교차 확인)
- [OpenAI Codex Pricing 2026 — Taskade](https://www.taskade.com/blog/codex-pricing-explained) — **1 credit ≈ $0.04이며 rate card가 API 정가에 1:1 대응**, GPT-5.5 = 125 / 12.5 / 750 credits per 1M, 소규모 버그픽스 ≈10 credits·다중 파일 리팩터 ≈60 credits
- [OpenAI Codex Pricing — UI Bakery](https://uibakery.io/blog/openai-codex-pricing) — 크레딧 rate card 표, **Enterprise/Edu flexible pricing은 고정 rate limit 없이 크레딧으로 스케일**, 워크스페이스 크레딧 추가 구매
- [Codex Pricing 2026 — Verdent](https://www.verdent.ai/guides/codex-pricing-2026) — *"OpenAI 추정 개발자당 월 $100~200"*, 같은 티어에서 $40~$400까지 갈리는 변동성
- [Cursor First-Party vs Third-Party Usage Pools: 2026 Split — vexp](https://vexp.dev/blog/cursor-first-party-vs-third-party-usage-pools-2026-split) — **first-party 풀 = Auto·Composer 2.5·Grok 4.5**, third-party 소진 시 first-party 모델로 자동 전환, Teams 시트 Standard $40 / Premium $120(3배 가격에 5배 사용량). ⚠️ 이 글의 *"두 풀은 siloed"* 서술은 **오해를 부른다** — 잔액이 서로 top-up되지 않는다는 뜻일 뿐이고, 실제로는 first-party 소진 시 API 풀로 spill-over한다(위 스태프 답변 2건)
- [Cursor Doubled Usage Limits — explainx.ai](https://explainx.ai/blog/cursor-doubled-usage-limits-again-july-21-2026) — **first-party 풀 영구 2배**(2026-07-16 발표·07-21 재확인), 개인·Teams 전 플랜 대상, third-party 달러 할당($20/$70/$400)은 불변, **Grok 4.5 출시 50% 할인은 07-21 종료**
- [Cursor 커뮤니티 포럼 — First-party models pool limits (Pro/Pro+/Ultra)](https://forum.cursor.com/t/question-about-first-party-models-pool-limits-between-pro-pro-plus-and-ultra-plans/166360) — 스태프 답변: 티어가 높을수록 first-party 한도도 높으나 **"Cursor Models 풀에 대해 깔끔한 N배 숫자를 제시하지 않는다"**, 전체 볼륨 기준 Ultra ≈ Pro의 20배, 확인 수단은 `cursor.com/dashboard/usage`
- [How Cursor Pricing and Credits Actually Work (2026) — Learn Cursor](https://www.learncursor.dev/pricing-explained) — 플랜가 ≈ 포함 API 지출(Pro $20 / Pro+ $60→$70 / Ultra $200→$400), 2026-06 이중 풀 도입, 소진 후 3가지 선택(스로틀·API 정가 종량·티어 상향)
- [Cursor Pricing 2026 — NxCode](https://www.nxcode.io/resources/news/cursor-ai-pricing-plans-guide-2026) / [Tessl](https://tessl.io/blog/cursor-new-pricing-structure-explained/) — **Ultra $200에 $400 포함(+보너스)**, Pro+ $60에 $70 포함 — 상위 티어의 "보너스" 실체
- [Cursor 커뮤니티 포럼 — Does Composer 2.5 fall back to API usage after Auto + Composer reaches 0%?](https://forum.cursor.com/t/does-composer-2-5-fall-back-to-api-usage-after-auto-composer-reaches-0-on-individual-pro/163366) — **spill-over 확정(개인 Pro)**. 스태프: *"Auto+Composer 풀이 떨어지면 사용량이 API 쿼터로 넘어간다 … Composer 2.5는 그 풀에 묶여 있지 않다"*
- [Cursor 커뮤니티 포럼 — Teams' first-party model pool](https://forum.cursor.com/t/teams-first-party-model-pool/165385) — **spill-over 확정(Teams)**. 스태프: *"단일 $20 풀 대신 first-party 풀과 third-party API 풀로 분리 … first-party 풀이 소진되면 추가 사용분은 API 풀에서 나간다"*
- [Cursor 커뮤니티 포럼 — Which usage pool does Grok 4.5 draw from?](https://forum.cursor.com/t/which-usage-pool-does-grok-4-5-draw-from/165461) — 스태프: Grok 4.5는 Auto·Composer 2.5와 **동일한 First-Party Models 풀**, 요청 단위가 아니라 **토큰 단위**로 소모
- [Cursor Docs — Pricing](https://cursor.com/docs/account/pricing) — 두 풀의 공식 명칭(Cursor Models / Other Models), 포함분 소진 후 **on-demand는 standard API rates**, *"Requests are never downgraded in quality or speed"*
- [Cursor Docs — Cursor Token Rate](https://cursor.com/help/models-and-usage/token-rate) — Teams·Enterprise는 third-party 요청에 **$0.25/1M 부가금**, **first-party 모델은 면제**
- [Grok 4.5 Pricing and Cursor Integration](https://www.aimadetools.com/blog/grok-4-5-pricing-cursor-integration/) — **200K 프롬프트 토큰 임계 확정**: 이하 $2/$0.50/$6, 초과 시 $4/$1/$12가 **요청 전체에 적용**
- [Claude Code Pricing in 2026 — SSD Nodes](https://www.ssdnodes.com/blog/claude-code-pricing-in-2026-every-plan-explained-pro-max-api-teams/) / [Tygart Media](https://tygartmedia.com/claude-code-billing-credit-pool-2026/) — Team Premium 시트 $100/월(Claude Code 포함, 최소 5시트), **Enterprise는 협상 시트가 + 전량 API 정가 종량**(포함 사용량 없음)
