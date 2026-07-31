# 모델 티어링 리팩토링 — 분석 및 제안

> 작성일: 2026-07-31 · 구현 범위: Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`) 우선 · 분석 범위: Claude / Codex / Cursor 3개 플랫폼(§4, §8) · 산출물 성격: 분석·제안(구현 계약 아님)
>
> 가격·벤치마크는 **2026-07-31 기준**이며, GPT-5.6 가격은 2026-07-30 인하가 반영된 값이다. Sonnet 5 introductory 가격은 2026-08-31에 종료된다.

## 요약 (결론 먼저)

1. **"계획=고성능, 구현=고효율"은 방향은 맞지만 잘못된 변수를 짚고 있다.** 실제 변수는 *단계 이름*이 아니라 **명세 밀도와 되돌릴 수 있는가**다. 계획 단계가 고성능을 필요로 하는 이유는 "계획이라서"가 아니라 "명세가 없고 틀려도 실행자가 자가 수정할 수 없어서"다. 이 렌즈로 보면 배치가 완전히 달라진다(§1, §4).
2. **plan-dev를 세밀화하지 마라.** "구현 디테일 계획 단계 추가"는 이 하네스가 의도적으로 세운 원칙을 뒤집고, 고성능 모델에 *추측*을 시켜 비용을 늘리며, detail 충돌을 direction 충돌로 승격시켜 human gate를 증가시킨다. 대신 **escalation hatch**(필요할 때만 고성능 자문)와 **Authority Boundaries 강화**로 푼다(§3).
3. **Claude에서는 가장 큰 절감이 모델 교체가 아니다.** Opus 5 → Sonnet 5는 입·출력 모두 **1.67배**밖에 안 싸다(현재 introductory 가격 기준 2.5배지만 2026-08-31 종료). 반면 dev-loop 라운드가 1회만 더 늘어도 그 절감분은 대부분 상쇄된다. 실질 절감은 ① **effort 하향**, ② **리뷰어 4중 정적 텍스트 중복 제거 + 프롬프트 캐시 정렬**, ③ **결정론적 계산의 셸 이전** 순서다(§2, §6). **Codex·Cursor는 반대다** — Sol→Luna가 25배라 모델 교체의 기대 절감이 훨씬 크다(§8).
4. **서브에이전트를 많이 쓰는 현재 구조는 불리하지 않다. 이 리팩토링의 전제조건이다.** 프롬프트 캐시는 모델 단위로 스코프되므로, 한 세션 안에서 모델을 바꾸면 캐시가 전부 깨진다. 서브에이전트는 자체 캐시·자체 모델을 가지므로 **혼합 티어링이 가능한 유일한 구조**다(§6). 세 플랫폼 모두 이 성질을 공유한다.
5. **구조적 차단 요소가 2개 있다.** `test-dev`와 `fix-dev`가 `subagent_type: general-purpose`(빌트인)를 쓰고 있어 **모델을 지정할 파일이 없다.** `tester` / `fixer` 에이전트 신설이 티어링을 표현하기 위한 최소 선행 작업이다(§4).
6. **이식성: Codex ✅ 완전 가능 / Cursor ⚠️ 조건부.** Codex agent role `.toml`은 `ConfigToml`을 flatten하므로 `model`·`model_reasoning_effort` 두 줄만 추가하면 된다. Cursor는 표현은 되지만 **핀이 보장이 아니고**(플랜·관리자 설정에 따라 조용히 폴백) **`tools:` 필드가 없어 리뷰어의 read-only 계약이 약해진다**(§8).
7. **세 플랫폼에서 결론이 수렴한다: 최하위 티어의 자리가 거의 없다.** Haiku 4.5(200K ctx) · Luna(MRCR 41.3% 장문맥 절벽) · Composer 2.5(200K ctx)가 못하는 일이 정확히 하네스의 T2 작업(repo-slice 추론)이기 때문이다(§8.1).
8. **Copilot(월 1,900 크레딧 = $19)에서는 티어링이 선택이 아니라 필수다.** 전 fleet Opus 5면 월 1사이클을 겨우 넘긴다. 권장 조합은 **T1 Grok 4.5(단 `plan-dev`만 Opus 5) + T2 Kimi K2.7 Code / Luna**로, 사이클당 비용이 약 1/4로 줄어 월 6사이클 내외가 된다(§9).

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

여기에 **TODO 난이도 태그**를 얹으면 (A)의 호출 조건이 규칙이 된다: 각 TODO에 `(mechanical)` / `(design-bearing)`을 붙여 plan-dev가 기록하고, `design-bearing` TODO에서만 consultant 호출을 허용한다. 플랜에 단어 하나씩 늘리는 비용으로 escalation 빈도 상한(§10-10)을 규칙화할 수 있다.

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

| 티어 | 정의 | Claude | Codex | Cursor | Copilot (§9) |
| --- | --- | --- | --- | --- | --- |
| **T1 judgment** | 되돌릴 수 없고 기계 검증이 불가능한 결정 | `opus` (Opus 5) | GPT-5.6 **Sol** | **Grok 4.5** | **Grok 4.5** (plan-dev만 Opus 5) |
| **T2 execution** | 명세가 있고 기계 검증이 가능한 작업 | `sonnet` (Sonnet 5) | **Sol 저effort** 또는 **Luna**(컨텍스트 소형 한정) | **Composer 2.5**, 단 agentic 역할은 Grok 4.5 | **Kimi K2.7 Code**, 소형 컨텍스트 역할은 **Luna** |
| **T3 mechanical** | 판단이 사실상 없는 변환·집계 | `haiku` | Luna | Composer 2.5 | MAI-Code-1-Flash / Luna |

> **T3는 사실상 비어 있다.** 세 플랫폼의 최저 티어가 모두 같은 이유로 이 하네스에 부적합하다 — Haiku 4.5는 컨텍스트 200K·캐시 최소 4096 tok, Luna는 장문맥 절벽(MRCR 41.3% vs Sol 91.5%), Composer 2.5는 컨텍스트 200K. **하네스의 T2 작업은 대부분 repo-slice 추론이라 최저 티어가 가장 못하는 일이다.** 진짜 기계적인 일은 모델이 아니라 셸로 내려라(§6a).
>
> **Codex에서 Terra는 쓰지 않는다.** Artificial Analysis: *"Luna와 Sol은 항상 Terra보다 Pareto frontier 앞에 있다 — 어떤 Terra effort 조합에 대해서도, 같은 비용에 더 똑똑하거나 같은 지능에 더 싼 Luna/Sol 조합이 존재한다."* 2026-07-30 가격 인하(Luna −80%, Terra −20%)로 격차는 더 벌어졌다.

### 배치

effort 값은 각 플랫폼의 지원 범위 안에서만 유효하다 — Claude `low~max`, Codex `none/minimal/low/medium/high/xhigh/max/ultra`(기본 medium), **Grok 4.5는 `low/medium/high`뿐**(기본 high, xhigh·max 없음).

| 실행 단위 (위치) | 티어 | Claude | Codex | Cursor | 근거 |
| --- | --- | --- | --- | --- | --- |
| `plan-dev` (세션) | **T1** | opus / xhigh | Sol / xhigh | Grok 4.5 / **high (상한)** | 방향·경계·AC는 되돌릴 수 없고, 틀려도 실행자가 자가 수정 불가 |
| `planner` (subagent) | **T1** | opus / high | Sol / high | Grok 4.5 / high | 아키텍처 판단. 조건부 호출이라 빈도 낮음 |
| `plan-consultant` (신규, subagent) | **T1** | opus / high | Sol / high | Grok 4.5 / high | escalation hatch(§3-A). 호출 빈도가 비용을 결정 |
| `dev-loop` 컨트롤러 (세션) | **T2** | sonnet / medium | Luna / medium | Composer 2.5 | 전이표 조회 + LOOP append — 규칙 기반, 컨텍스트 소형 |
| `implementer` (subagent) | **T2** | sonnet / high | **Sol / medium** | **Grok 4.5 / medium** | TDD가 ground truth지만 plan+research+컨벤션+코드를 함께 추론 → **장문맥 역할이라 Luna·Composer 부적합** |
| `tester` (**신규 필요**) | **T2** | sonnet / medium | Luna / high | Composer 2.5 | mutation score ≥80%가 기계 목표. 프로덕션 코드 수정 금지라 blast radius 제한적 |
| `fixer` (**신규 필요**) | **T2** | sonnet / medium | Luna / high | Composer 2.5 | 리뷰 finding이 곧 명세이고, 재테스트·재리뷰로 검증됨. 단일 결함 = 소형 컨텍스트 |
| `security-reviewer` | **T1** | opus / medium | Sol / medium | Grok 4.5 / high | authz 우회 miss는 회복 불가. 4축 중 miss 비용 최대 |
| `reliability-reviewer` | **T1** | opus / medium | Sol / medium | Grok 4.5 / high | 반사실 시뮬레이션(경쟁 상태·부분 실패)은 약 모델이 가장 먼저 무너지는 영역 |
| `maintainability-reviewer` | **T2** | sonnet / medium | Luna / high | Composer 2.5 | 주변 코드 스타일·AGENTS.md 규칙 대조 = 명세된 패턴 매칭 |
| `senior-generalist-reviewer` | **T2** | sonnet / medium | Luna / high | Composer 2.5 | calibrated catch-all. miss 비용 낮음 |
| `review-code` 집계·triage (세션) | **T2** | sonnet | Sol / low | Grok 4.5 / low | dedup·정렬·id 부여는 기계적이고, **Fix/Accept 최종 판단은 사람** |
| `commit-code` / `request-merge` (세션) | **T2** | sonnet / low | Luna / low | Composer 2.5 | 거의 기계적 |

**effort 배분 원칙 3가지** (§9의 벤치마크에서 유도):

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
- `docs/sync-harness/SYNC_TO_CODEX.md`에 변환 규칙 추가: Claude `model:` 별칭 → Codex `model` + `model_reasoning_effort`, Claude `effort:` → Codex `model_reasoning_effort`(값 매핑은 §9). 현재 `agents/codex/*.toml`에는 두 키가 모두 없다 — **표현 자체는 가능하다는 것이 §9에서 확인됐다.**

### 운용 스위치 (문서화 필요)

세 플랫폼 모두 "전 서브에이전트를 한 모델로 강제"하는 전역 스위치를 가지며, **켜둔 채 잊으면 모든 티어 핀이 무력화**된다. A/B 테스트나 "오늘은 전부 싸게"용 임시 스위치로만 문서화할 것.

| 플랫폼 | 스위치 | 비고 |
| --- | --- | --- |
| Claude | `CLAUDE_CODE_SUBAGENT_MODEL` 환경변수 | per-invocation 파라미터와 frontmatter를 **모두** override. `inherit`로 두면 정상 해석 복귀. 설정하려면 `hooks/claude/settings.json`의 `env` 블록(현재 없음)에 |
| Codex | `config.toml`의 `[agents] default_subagent_model` / `default_subagent_reasoning_effort` | 이쪽은 **fallback**이라 더 안전하다 — role 파일이 명시한 값을 덮어쓰지 않고, spawn 호출도 role도 지정하지 않았을 때만 적용 |
| Cursor | 명시적 스위치 없음 | 대신 **의도치 않은 폴백**이 존재한다(§9) — 관리자 차단·플랜 제약 시 핀이 조용히 무시된다 |

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

현재 `review-code`의 "What counts as a bug"는 7개 AND 조건 + *"Ignore style, formatting, typos, and nits"*로 보수적인 필터다. **여기서 모델까지 티어를 내리면 recall 손실이 복합된다.** 티어 하향과 함께 이 필터를 완화하고 severity 판단을 집계 단계로 옮기는 것을 같이 검토해야 한다 — 티어링과 독립된 이슈가 아니다.

**교차 벤더 리뷰**: 구현 모델과 리뷰 모델을 다른 계열로 두면 같은 계열의 blind spot이 분산된다는 실무 관행이 있다. 이 하네스는 이미 `skills/codex/review-code-claude`라는 형태로 그 패턴을 갖고 있다. 티어링과 결합하면 **비용을 늘리지 않고 얻을 수 있는 품질 레버**가 된다 — 예컨대 Copilot(§9)은 한 구독 안에 Anthropic·OpenAI·xAI·Moonshot이 모두 있으므로, T2 구현을 Kimi로 두고 T1 리뷰를 Grok으로 두는 §9.5 배치가 **의도치 않게 교차 벤더를 만족한다.** 반대로 단일 벤더로 통일하는 방향의 절감안은 이 이점을 잃는다는 점을 인지하고 선택해야 한다.

### (d) 타 플랫폼 전파

→ §8에서 별도로 다룬다. 결론만: **Codex는 완전 이식 가능, Cursor는 조건부 가능**(핀이 보장이 아니고 read-only 강제가 약해짐).

---

## §7. 실행 순서 제안

**리스크 낮고 절감 큰 것부터.** 각 단계 후 LOOP 파일의 라운드 수를 확인하고 다음으로 넘어간다.

| # | 작업 | 아키텍처 변경 | 기대 효과 |
| --- | --- | --- | --- |
| 1 | 모든 에이전트에 `effort` 명시(리뷰어 medium, implementer high, planner high) | 없음 | 즉시. 모델 교체 없음 |
| 2 | 리뷰어 정적 계약을 에이전트 정의로 이전 + dispatch 프롬프트 stable-first 재정렬 | 없음(문서 이동) | 리뷰 라운드당 4× 중복 제거 |
| 3 | **diff-class 스크립트 + trivial 축 축소 화이트리스트**(§6a-4, §6b) | 스크립트 1개 + review-code 규칙 | **축 수를 줄이는 유일한 항목.** 티어 조정보다 절감폭이 크다 |
| 4 | `tester` / `fixer` 에이전트 신설 (T2 핀) | 신규 파일 2개 | 티어링 표현 가능해짐 |
| 5 | 리뷰어 티어 분화 (maintainability·generalist → T2) | frontmatter | 리뷰 fleet 비용 ~40%↓ |
| 6 | dev-loop 실행 세션을 T2로 운용 (plan-dev는 T1 세션 유지) | 운용 규칙 | 컨트롤러·Dispatcher 비용 |
| 7 | `## Authority Boundaries` 강화 + TODO `(mechanical)`/`(design-bearing)` 태그 (§3-B) | 레퍼런스 수정 | 비용 0. 8~9의 **선행 조건** |
| 8 | **cascade**: 3-fail 시 중단 대신 T1 1회 재시도 (§3-C) | implement/fix-dev 규칙 | 효율 모델의 실패 꼬리 절단 (보험) |
| 9 | `implementer` → T2 + `plan-consultant` escalation hatch (§3-A) | 신규 에이전트 + implement-flow 수정 | 최대 절감이자 최대 리스크. 7·8 이후에만 |
| 10 | scope/커맨드 탐지 스크립트 (§6a-1·2) | 신규 스크립트 2개 | 반복 추론 제거 + 드리프트 제거 |
| 11 | (조건부) Implementation Brief (§3-D) | 신규 아티팩트 + 얇은 스킬 | 9로 부족할 때만. **신규 아티팩트를 만드는 유일한 항목이라 마지막** |

### 측정과 롤백

**주 지표는 "플랜당 remediation 라운드 수"다.** 이미 `docs/agents/dev/*_LOOP_*.md`에 append-only로 기록되고 있으므로 별도 계측 도구가 필요 없다. 티어를 내린 뒤 라운드 중앙값이 오르면 절감은 환상이다(§2b). 각 단계 전후로 이 값을 비교한다. Copilot은 여기에 더해 사용량 대시보드의 크레딧 델타를 직접 읽을 수 있다(§9.4).

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
- **제약 2 — `tools:` 필드가 없다.** 커스텀 서브에이전트는 부모의 **모든 툴을 상속**하고, 제한 수단은 `readonly: true` 불리언 하나뿐이다. 하네스의 리뷰어 4종·`planner`·`plan-consultant`는 Claude에서 `tools: Read, Grep, Glob, Bash`로 write를 원천 차단하는데, Cursor에서는 이 불변식이 **약해진다**. read-only가 설계 계약인 에이전트들이므로 이건 비용이 아니라 **안전성 이슈**다.
- **제약 3 — 중첩 2계층.** 서브에이전트는 자식을 낳을 수 있지만 **그 자식은 더 못 낳는다.** `implementer` → `plan-consultant`는 성립하므로 현 설계엔 충분하나, 그 아래로 확장할 여지는 없다.
- **뜻밖의 발견 — Cursor는 `.claude/agents/`와 `.codex/agents/`도 읽는다.** 공식 문서의 서브에이전트 위치 표에 세 디렉터리가 모두 프로젝트 스코프로 명시돼 있다. **Cursor 전용 변형을 새로 만들 필요가 없을 수도 있다.** 다만 frontmatter 방언이 다르다(`model: opus` 별칭 vs `claude-opus-5[effort=high]`, `tools:` vs `readonly:`) — 아래 미확인 항목의 답에 따라 "변형 불필요" ↔ "얇은 어댑터 변형 필요"가 갈린다.

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
> Grok 4.5의 장문맥 2배 티어는 **약 200K 컨텍스트부터**로 보이나 미확인이다(§10-2). 사실이라면 Grok의 500K 컨텍스트는 "쓸 수 있다"이지 "싸게 쓸 수 있다"가 아니며, Worker에 불필요한 컨텍스트를 싣지 않는 것이 그 자체로 비용 레버가 된다.

**벤치마크 요약** (출처별 코호트가 달라 서로 직접 비교 금지):

- **AA Intelligence Index v4.1 (max effort)**: Sol 59 / Terra 55 / Luna 51. Claude Fable 5가 60. **기본 effort → max는 티어 전반 2~4점.**
- **Agents' Last Exam**: Sol max 53.6(SOTA). **Sol medium이 Fable 5보다 11.4점 앞서면서 추정 비용은 약 1/4.** Luna는 Sol과 약 3.3점 차.
- **AA Coding Agent Index**: Sol 80 / Terra 77.4 / Luna 74.6.
- **장문맥(MRCR)**: **Luna 41.3% vs Sol 91.5%** — Luna를 대형 코드베이스 추론에 쓰면 안 되는 정량적 근거.
- **Cursor 진영**: agentic 비교에서 Grok 4.5 **83.3** vs Composer 2.5 **69.3**. CursorBench 3.2는 Grok 66.7 vs Composer 56.1, SWE Multilingual은 Composer 79.8 vs Grok 78.0. Grok 4.5는 SWE-Bench Pro 64.7%이면서 **태스크당 출력 토큰 15,954개 — Opus 4.8 max(67,020)의 약 1/4.2**로, 헤드라인 단가보다 실효 비용이 낮다.

이 숫자들이 §4 배치의 근거다: **agentic 격차(83.3 vs 69.3)가 정확히 `implementer`의 일에 떨어지므로 Cursor에서 implementer만 Grok에 남겼고**, 장문맥 절벽(41.3%)이 정확히 `implementer`의 입력 형태(plan + research + 컨벤션 + 코드)와 겹치므로 **Codex에서도 implementer만 Sol에 남겼다.**

---

## §9. GitHub Copilot — 예산 1,900 크레딧 기준 모델 선정

### 9.1 전제: 크레딧은 요청 수가 아니라 **돈**이다

Copilot은 2026-06-01부로 premium request 방식에서 **AI Credits 사용량 과금**으로 전환됐고, 공식 문서 기준 **1 AI credit = $0.01 USD**다. 입력·캐시 입력·캐시 쓰기·출력이 모델별로 각각 과금된다.

> **1,900 크레딧 = 월 $19.**

이것이 이 절의 모든 결론을 지배한다. 그리고 **Copilot의 모델 단가는 각 provider의 정가를 거의 그대로 통과시킨다**(Opus 5 $5/$25, Sol $5/$30, Luna $0.20/$1.20, Grok 4.5 $2/$6). 따라서 §8.4의 벤치마크·가격 분석이 Copilot에도 그대로 유효하고, **Copilot 고유의 배수(multiplier) 왜곡은 없다.**

### 9.2 Copilot 고유의 함정 3가지

1. **장문맥 할증 티어가 존재한다.** GPT·Grok·Gemini에는 두 번째 가격대가 있다 — Sol `$5/$30 → $10/$45`, Terra `$2/$12 → $4/$18`, Luna `$0.20/$1.20 → $0.40/$1.80`, Grok 4.5 `$2/$6 → $4/$12`. **Claude 계열과 Kimi K2.7 Code에는 이 티어가 없다.** 하네스의 Worker는 plan + research + 컨벤션 + diff를 함께 싣기 때문에 임계를 넘기기 쉽고, 넘기면 입력 비용이 조용히 2배가 된다. → **T2를 Kimi로 두는 결정적 이유 중 하나다.**
2. **Anthropic 모델만 캐시 쓰기가 별도 과금된다** (Opus $6.25 / Sonnet 5 $2.50 / Haiku $1.25 per 1M). 다른 provider는 해당 열이 비어 있다. 캐시 쓰기가 토큰의 약 5%라는 §2 프로파일을 적용하면 **Opus 5의 실효 비용이 약 25% 더 올라간다.**
3. **캐시 할인율이 모델마다 다르다.** 대부분 10배(0.1×)인데 **Grok 4.5는 4배($2.00→$0.50), Kimi K2.7 Code는 5배($0.95→$0.19)**뿐이다. 에이전트 루프는 캐시 읽기가 지배적(§1: cache read 94.5%)이므로 **헤드라인 입력가가 아니라 "캐시 입력가"가 실질 단가**다.

### 9.3 캐시 입력가 기준 실질 단가 순위

| 모델 | 입력 | **캐시 입력** | 출력 | 장문맥 티어 |
| --- | --- | --- | --- | --- |
| GPT-5.6 Luna | 0.20 | **0.02** | 1.20 | 있음 (2×) |
| MAI-Code-1-Flash | 0.75 | **0.075** | 4.50 | 없음 |
| Claude Haiku 4.5 | 1.00 | 0.10 | 5.00 | 없음 (캐시 쓰기 1.25) |
| Kimi K2.7 Code | 0.95 | **0.19** | 4.00 | **없음** |
| Claude Sonnet 5 (프로모) | 2.00 | 0.20 | 10.00 | 없음 (캐시 쓰기 2.50) |
| GPT-5.6 Terra | 2.00 | 0.20 | 12.00 | 있음 (2×) |
| GPT-5.4 | 2.50 | 0.25 | 15.00 | 있음 |
| Claude Sonnet 4.6 | 3.00 | 0.30 | 15.00 | 없음 (캐시 쓰기 3.75) |
| **Grok 4.5** | 2.00 | 0.50 | **6.00** | 있음 (2×) |
| Claude Opus 5 / 4.8 | 5.00 | 0.50 | 25.00 | 없음 (캐시 쓰기 6.25) |
| GPT-5.6 Sol / GPT-5.5 | 5.00 | 0.50 | 30.00 | 있음 (2×) |

**여기서 Grok 4.5가 튄다**: 캐시 입력가는 Opus 5·Sol과 같은 $0.50인데 **출력이 $6.00 — Opus 5의 1/4.2, Sol의 1/5**다. 게다가 §8.4의 SWE-Bench Pro 측정에서 **태스크당 출력 15,954 토큰(Opus 4.8 max의 1/4.2)**이므로, 출력 축의 이점이 단가와 토큰 수 양쪽에서 곱해진다.

### 9.4 예산으로 환산하면 — $19가 얼마나 빡빡한가

**아래 숫자는 실측이 아니라 §1·§2의 토큰 프로파일로 세운 1차 근사다.** 절대값이 아니라 **비율**을 보라. 가정: dev-loop 1사이클(implement + test + 4-리뷰어) ≈ 캐시읽기 9M / 신규입력 0.6M / 출력 0.2M / 캐시쓰기 0.5M.

| 전 fleet을 이 모델로 | 사이클당 | $19로 가능한 사이클 |
| --- | --- | --- |
| Claude Opus 5 | ≈ $15.6 | **1.2** |
| GPT-5.6 Sol / GPT-5.5 | ≈ $13.5 | 1.4 |
| Claude Sonnet 4.6 | ≈ $9.4 | 2.0 |
| **Grok 4.5** | ≈ $6.9 | 2.8 |
| Claude Sonnet 5 (프로모) | ≈ $6.3 | 3.0 |
| GPT-5.6 Terra | ≈ $5.4 | 3.5 |
| **Kimi K2.7 Code** | ≈ $3.1 | 6.2 |
| MAI-Code-1-Flash | ≈ $2.0 | 9.4 |
| GPT-5.6 Luna | ≈ $0.5 | 35 |

| 혼합 fleet (T1 25% / T2 75%) | 사이클당 | $19로 가능한 사이클 |
| --- | --- | --- |
| T1 Opus 5 + T2 Sonnet 5 | ≈ $8.6 | 2.2 |
| **T1 Grok 4.5 + T2 Kimi K2.7 Code** | ≈ **$4.0** | **4.7** |
| T1 Grok 4.5 + T2 Luna | ≈ $2.1 | 8.9 |

**결론: Copilot에서 전 fleet을 Opus 5로 돌리면 월 1사이클을 겨우 넘긴다.** 1,900 크레딧은 이 하네스에 대해 "티어링을 할까 말까"가 아니라 **"티어링 없이는 못 쓴다"** 수준의 예산이다.

### 9.5 Copilot 배치안

| 실행 단위 | 티어 | 모델 | effort | 근거 |
| --- | --- | --- | --- | --- |
| `plan-dev` (세션) | T1 | **Claude Opus 5** | xhigh | 세션당 토큰량이 dev-loop 대비 작다(인터뷰+리서치, 40턴짜리 Worker 루프 아님). **비싼 판단을 사기 가장 값싼 지점** |
| `planner` | T1 | Grok 4.5 | high | 조건부 호출, 빈도 낮음 |
| `plan-consultant` (신규) | T1 | Grok 4.5 | high | 짧은 결정 반환 → 출력 단가가 지배적. Grok의 강점 |
| `security-reviewer` | T1 | Grok 4.5 | high | miss 비용 최대. 캐시 입력가는 Opus와 동일하고 출력은 1/4 |
| `reliability-reviewer` | T1 | Grok 4.5 | high | 동상 |
| `implementer` | T2 | **Kimi K2.7 Code** | — | **장문맥 티어가 없는 유일한 저가 모델**이고, 스스로 long-horizon agentic·대형 코드베이스 분석을 표방. K2.6 기준 SWE-bench Verified 80.2%, 추론 토큰 K2.6 대비 −30% |
| `tester` (신규) | T2 | Kimi K2.7 Code | — | 스코프가 커질 수 있어 장문맥 안전 모델 유지 |
| `fixer` (신규) | T2 | GPT-5.6 Luna | high | 단일 결함 = 소형 컨텍스트. Luna의 절벽에 닿지 않음 |
| `maintainability-reviewer` | T2 | GPT-5.6 Luna | high | 청크된 diff = 소형 컨텍스트 |
| `senior-generalist-reviewer` | T2 | GPT-5.6 Luna | high | 동상 |
| `dev-loop` 컨트롤러 / `review-code` 집계 | T2 | MAI-Code-1-Flash | — | Copilot 생태계 내 최고 토큰 효율. 규칙 기반 작업 |
| `commit-code` / `request-merge` | T3 | MAI-Code-1-Flash | — | 거의 기계적 |

이 배치의 사이클당 비용은 위 표의 "T1 Grok + T2 Kimi"($4.0)와 "T1 Grok + T2 Luna"($2.1) 사이, 대략 **$3 안팎 → 월 6사이클 내외**다.

### 9.6 구조적 이식 가능성 — ✅ 가능

Copilot은 `.github/agents/*.agent.md`(프로젝트) 또는 `~/.copilot/agents/`(사용자)의 파일 기반 커스텀 에이전트를 지원하고, 커스텀 에이전트의 작업은 **subagent**로 수행된다. SDK 문서 기준 에이전트 설정에는 **`model`과 `reasoningEffort`가 모두 per-agent 오버라이드로 존재하며**, *"서브에이전트는 다른 모델을 쓸 수 있다 — 메인 에이전트가 범용 모델을 쓰는 동안 서브에이전트는 코드 리뷰나 리서치에 특화된 모델을 쓸 수 있다"*고 명시한다. `tools` 제한과 `infer`(자동 선택 여부)도 있어 하네스의 read-only 리뷰어 계약도 표현 가능하다. → **Cursor보다 이식성이 좋다.**

### 9.7 과금 방식 확정 (2026-07-31, 사용자 확인)

**AI Credits 사용량 과금이 맞다 — 레거시 premium request 과금이 아니다.** 따라서 §9.1~9.6의 토큰 기반 분석과 §9.5 배치안이 조건 없이 적용된다.

이 확정이 갖는 의미를 명시해 둔다: 레거시였다면 *사용자 프롬프트만 과금되고 내부 tool call은 무료*여서 서브에이전트 fleet이 사실상 공짜가 되고, 최적화 대상이 토큰이 아니라 프롬프트 횟수가 되어 **가장 강한 모델을 최대 effort로 쓰는 것이 옳았을 것이다.** AI Credits에서는 그 반대이므로, 이 하네스처럼 **서브에이전트 fan-out과 다중 라운드가 많은 구조일수록 티어링의 효과가 크다.** §2(b)의 라운드 증폭 리스크도 Copilot에서 가장 크게 작동한다 — **예산이 $19이므로 라운드 1회 초과가 곧 그 달의 가용 사이클 손실**이다.

---

## §10. 열린 질문 / 확인 필요

> **해결됨**: Copilot 과금 방식 = AI Credits (2026-07-31 확인, §9.7).

1. **[최우선] Copilot `.agent.md`의 정확한 frontmatter 키 이름** — SDK 문서는 `model` / `reasoningEffort` / `tools` / `infer`를 명시하지만, 파일 기반 `.agent.md` 스펙 문서에서는 `tools` 외 키가 확인되지 않았다. **§9.5 배치안 전체가 이 키들에 달려 있으므로 파일 하나로 먼저 검증할 것.**
2. **[최우선] 장문맥 할증의 임계 토큰 수** — GPT·Grok의 2배 티어가 몇 토큰부터 걸리는지. 선행 조사에서는 Grok 기준 **약 200K**로 보았으나 미확인이다. 하네스 Worker의 실제 컨텍스트 크기와 비교해야 §9.5의 Grok/Luna 배치와 §8의 Cursor Grok 배치가 확정된다. **$19 예산에서 입력비 2배는 치명적이다.**
2b. **Cursor Composer 2.5 Standard/Fast 실제 단가와 기본값** — §8.4의 경고가 사실이면 Cursor 설정에서 **Standard 강제가 1순위 조치**가 된다. 요금표 한 번 확인으로 끝난다.
3. **MAI-Code-1-Flash의 컨텍스트 윈도우** — 미확인. 작으면 §9.5의 컨트롤러·집계 역할도 재검토 필요.
4. **Cursor가 `.claude/agents/`를 읽을 때** (a) `model: opus` 같은 Claude 별칭을 해석하는지, (b) `tools:` 같은 미지의 키를 무시하는지 에러내는지. **이 두 답이 "Cursor 변형 신설 여부"를 결정한다** — 실제 파일 하나로 5분이면 검증 가능하다.
5. **Cursor에서 Composer 2.5 / Grok 4.5가 `[effort=...]` 파라미터를 받는지.** 공식 문서 예시는 `claude-opus-5[effort=high]`와 `composer-2.5[]`(빈 괄호)뿐이라, Grok의 low/medium/high를 frontmatter에서 지정 가능한지 미확인. 불가하면 Cursor의 effort 레버는 세션 설정뿐이다.
6. **Cursor의 read-only 약화(§8.3 제약 2)를 수용할지.** 리뷰어·planner의 read-only는 설계 계약이므로, 수용 불가라면 Cursor에서는 이들을 서브에이전트가 아니라 별도 세션으로 돌리는 우회가 필요하다.
7. **Cursor 2.4 Skills가 `.claude/skills/`를 교차 인식하는지** — 공식 changelog에 언급 없음. 인식하지 않으면 `skills/cursor/` 변형이 별도로 필요하다.
8. **Sonnet 5 인트로 가격 종료(2026-08-31)** — 지금 측정한 절감률은 9월에 1.67배로 축소된다. 의사결정 기준은 정가로 세울 것.
9. **§6c의 리뷰 필터 완화**를 이 리팩토링에 포함할지, 별도 이슈로 분리할지.
10. **`plan-consultant` 호출 빈도 상한** — 상한이 없으면 escalation hatch가 조용히 T1 사용량을 되돌릴 수 있다. `## Authority Boundaries`의 loop budget처럼 명시적 상한을 둘지.
11. **§9.4의 사이클 비용은 추정이다.** 실측 대체 방법: Copilot 사용량 대시보드에서 dev-loop 1사이클 전후 크레딧 차이를 한 번 읽으면 모든 비율이 실측으로 교체된다. **AI Credits 확정이므로 이 계측은 대시보드에서 바로 가능하다.**

---

## 부록. 병합된 선행 조사 (`RESEARCH_MODEL_ROUTING.md`, 2026-07-31 삭제)

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

1. **"Mid = Terra"** — 선행 조사는 Terra를 Codex Mid 1순위로 두었으나, 근거였던 단가(Terra $2.50/$15, Luna $1/$6)가 **2026-07-30 인하 이전 값**이다. 실제는 Terra $2/$12, **Luna $0.20/$1.20**이고, Artificial Analysis의 **"Luna·Sol이 Terra를 Pareto 지배"** 결과와 합쳐지면 Terra를 선택할 이유가 사라진다. → §4의 결론(**Terra 미사용**)을 유지한다.
2. **"L 티어 = Haiku/Luna로 탐색·기계 작업"** — 방향은 이 문서와 같으나, 이 문서는 한 발 더 나간다: 그 작업들은 **모델이 아니라 셸로** 내리는 것이 맞다(§6a). 최하위 티어에 남길 일이 사실상 없다는 것이 §8.1의 결론이다.
3. **Sonnet 5 / Opus 4.8 벤치마크 표와 "Sonnet 5는 cyber 능력이 의도적으로 낮다"** — 이번 세션에서 직접 검증하지 못했다. 다만 사실이라면 §4의 `security-reviewer` T1 유지 결정을 **강화**하는 방향이므로, 배치를 바꾸지 않고 근거만 보류해 둔다.

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
- [GitHub Docs — Models and pricing for GitHub Copilot](https://docs.github.com/en/copilot/reference/copilot-billing/models-and-pricing) — **1 AI credit = $0.01**, 모델별 입력/캐시입력/캐시쓰기/출력 단가표, 장문맥 할증 티어
- [GitHub Docs — Requests in GitHub Copilot (legacy)](https://docs.github.com/en/copilot/concepts/billing/copilot-requests) — 레거시 premium request 과금에서 *"tool call은 과금되지 않고 사용자 프롬프트만 과금"*
- [GitHub Docs — Custom agents and sub-agent orchestration](https://docs.github.com/en/copilot/how-tos/copilot-sdk/features/custom-agents) — per-agent `model` / `reasoningEffort` / `tools` / `infer`, 서브에이전트별 모델 분리
- [GitHub Docs — Creating and using custom agents for Copilot CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli) — `.github/agents/*.agent.md` · `~/.copilot/agents/`
- [Kimi K2.7 Code — Moonshot AI](https://www.kimi.com/resources/kimi-k2-7-code) / [OpenRouter](https://openrouter.ai/moonshotai/kimi-k2.7-code) — 256K 컨텍스트, 1T MoE(32B active), long-horizon agentic 지향, 추론 토큰 K2.6 대비 −30%
- [MAI-Code-1-Flash 가이드 — Shareuhack](https://www.shareuhack.com/en/posts/github-copilot-mai-code-1-flash-guide-2026) — SWE-Bench Verified 71.6%, Copilot 생태계 내 최고 속도·토큰 효율
