# Claude 변형 구현 계획

> 작성일: 2026-08-02 · 최종 개정: 2026-08-03 · 상위 문서: [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md) · 범위: **`skills/claude/` · `agents/claude/` · `hooks/claude/`만** · 성격: 구현 계약(이 문서를 보고 실제 파일을 만든다)
>
> **2026-08-03 개정 요지**: **W1~W9를 단계별 관찰 없이 한 번에 적용**하기로 확정. 이에 따라 초판의 "현 실효값(Opus)으로 중립 배치한 뒤 단계별로 하향" 전략을 **폐기**하고 모든 에이전트를 **처음부터 최종 티어**로 만든다. §4는 롤아웃 순서가 아니라 **의존 관계와 커밋 분할**을 정의하는 절로 바뀌었고, §8의 롤백은 단계 되돌리기에서 **항목별 되돌리기**로 재설계했다. 같은 날 **열린 결정 3건이 전부 확정**되어 §7은 결정 기록이 됐다 — `dev-loop-light`은 **Claude에서도 실사용**(원본 제공 목적이 아니다), 런타임 스크립트는 **`scripts/claude/` 신설**, `test-dev`의 suspected defect는 **사람이 Fix/Accept로 분류**한다. 셋째 결정이 W2의 상태 기계를 바꿨다(§5 W2.2).
>
> Codex·Cursor 변형은 이 계획에 포함하지 않는다. 단 `dev-loop-light`은 Claude에서 쓰는 동시에 **Codex 기본값의 원본**이기도 하다(개인 하네스의 중심은 Claude Code이고 Codex는 `SYNC_TO_CODEX.md` 경유).

## 요약 (결론 먼저)

1. **Claude의 기본 경로가 `dev-loop-noreview`로 정해진 순간(§9.9), 상위 문서 §7의 우선순위는 Claude에 그대로 적용되지 않는다.** 리뷰가 기본 경로에서 사라지면 라운드 토큰의 **80%가 `implementer`, 20%가 `tester`**가 되고, §7이 2·3·5번으로 앞세운 리뷰어 관련 항목들이 기본 경로 밖으로 밀려난다. 다만 **`dev-loop-light`을 Claude에서도 실사용하기로 했으므로**(§7 결정 1) T2 리뷰어 2종(`maintainability` · `senior-generalist`)은 "밖"이 아니라 **"덜 자주 쓰는 경로 안"**이다 — T1 리뷰어 2종만 `dev-loop`(4축) 전용으로 남는다. 일괄 적용이라 순서는 안 바뀌지만 **어디에 검증 노력을 쓸지**는 이것이 정한다(§8).
2. **절감의 3분의 2는 `dev-loop-noreview` 신설 하나에서 나온다.** 현재 상태($100 → 2.8작업)에서 이 항목만으로 8.5작업, 나머지 전부를 더해 **약 13작업(4.7배)**이 된다. §9.9의 remediation 0회 가정으로는 14.2작업이지만, **`test-dev`의 suspected defect를 사람이 분류하기로 확정했으므로**(§7 결정 3) Fix로 분류된 몫만큼 라운드가 남는다(§3).
3. **`model: inherit`를 하네스에서 완전히 제거한다.** 지금 6개 에이전트가 전부 `inherit`이라, dev-loop 실행 세션을 Sonnet으로 내리는 순간 **`security-reviewer`·`reliability-reviewer`가 파일 한 줄 안 바뀐 채 T2로 내려간다** — §4가 *"miss 비용 최대"*라며 T1에 둔 바로 그 둘이다. `inherit`은 티어가 아니라 "세션이 어쩌다 갖게 된 값"이므로, **티어는 파일의 속성이어야 한다.**
4. **§9.9의 "기존 스킬 무변경"은 성립하지 않는다.** `dev-loop-noreview`는 `test-dev`에 "mutation은 이 변형의 범위 밖"을 전달해야 하는데 현재 계약상 mutation 커맨드 부재는 `blocked` 사유다. `dev-loop-light`는 `review-code`가 축 부분집합을 받아야 한다. 여기에 **§7 결정 3(test finding도 Fix/Accept 분류)**이 `dev-loop`의 TESTING 게이트까지 바꾸므로, 기존 스킬 수정은 **`test-dev` · `review-code` · `dev-loop` 3개**로 늘어난다(W2).
   - 그 결과 **`dev-loop-noreview`에서도 AR 레지스트리가 살아남는다.** 초판은 리뷰가 없으니 triage·AR이 통째로 사라진다고 봤는데, Accept 대상이 REVIEW-NNN에서 **TEST-NNN으로 바뀔 뿐 기구는 그대로**다. 종료 술어 ⑦(Accept → AR 기록)이 되살아난다(§5 W2.2).
5. **상위 문서 §6a가 말한 `scripts/resolve-scope.sh`는 그 위치에 두면 동작하지 않는다.** 저장소 루트 `scripts/`는 **설치 스크립트 전용**이고 `~/.claude/`로 복사되지 않는다(W8).
6. **`implementer`는 지금 `plan-consultant`를 호출할 수 없다.** `tools:`에 `Agent`가 없기 때문이다 — 공식 문서상 서브에이전트가 자식을 낳으려면 `tools`에 `Agent`가 명시돼야 한다(W7).
7. **일괄 적용의 대가는 귀속 불가(attribution)다.** 9개 변경이 동시에 들어가면 회귀가 생겨도 어느 변경 탓인지 구분할 수 없다. 이건 순서로는 못 풀고 **되돌리기 단위**로 푼다 — **항목별 커밋**으로 나눠 두면 신호 하나당 `git revert` 한 번으로 대응된다(§4.2). 다행히 **기준선은 이미 디스크에 있다** — `docs/agents/dev/*_LOOP_*.md`의 기존 라운드 기록이 변경 전 중앙값이다(§8).

---

## §1. 현재 상태 — 파일 단위 사실

전부 이 세션에서 직접 확인한 값이다.

### 1.1 에이전트 (`agents/claude/`, 6개)

| 파일 | `model` | `effort` | `tools` |
| --- | --- | --- | --- |
| `implementer.md` | `inherit` | 없음 | `Read, Edit, Write, Bash, Grep, Glob, Skill` |
| `planner.md` | **없음** | 없음 | `Read, Grep, Glob, Bash` |
| `security-reviewer.md` | **없음** | 없음 | `Read, Grep, Glob, Bash` |
| `reliability-reviewer.md` | **없음** | 없음 | `Read, Grep, Glob, Bash` |
| `maintainability-reviewer.md` | **없음** | 없음 | `Read, Grep, Glob, Bash` |
| `senior-generalist-reviewer.md` | **없음** | 없음 | `Read, Grep, Glob, Bash` |

`model` 생략은 `inherit`과 같으므로 **6개 전부 세션 모델을 따른다.** `effort`는 어디에도 없어 전부 세션 effort를 상속한다.

### 1.2 스킬 (`skills/claude/`, 15개)

15개 `SKILL.md` 중 **`model` / `effort` / `context` 프론트매터를 가진 파일은 하나도 없다.** 전부 `name` + `description`뿐이다.

### 1.3 티어링을 막고 있는 구조적 사실 6가지

| # | 사실 | 영향 |
| --- | --- | --- |
| **B1** | `test-dev`가 `subagent_type: general-purpose`로 Worker를 띄운다 (`SKILL.md` 실행 모드 절 + `references/worker-contract.md`) | 정의 파일이 없어 모델·effort를 지정할 대상이 없다 |
| **B2** | `fix-dev`도 `subagent_type: general-purpose` (`SKILL.md` "2. Dispatch one sub-agent by default") | 동일 |
| **B3** | `implementer.md`의 `tools:`에 **`Agent`가 없다** | `plan-consultant` 중첩 호출 불가 — 공식 문서: *"서브에이전트 정의에서 `tools`에 `Agent`를 나열하면 깊이 한도 안에서 자식을 낳을 수 있다"* |
| **B4** | 스킬 `model:`은 **해당 턴에만** 적용되고 다음 프롬프트에서 세션 모델로 복귀 (공식 문서 확인) | `plan-dev`(멀티턴 인터뷰)·`dev-loop`(휴먼 게이트로 턴이 끊김)는 프론트매터로 고정 불가 → **세션 경계 운용만이 유일한 수단** |
| **B5** | `hooks/claude/settings.json`에 `env` 블록이 없다 | `CLAUDE_CODE_SUBAGENT_MODEL`은 미설정 상태 = 정상. 단 이 변수는 **프론트매터와 호출 인자를 모두 덮어쓰므로**(문서 확인) 켜두면 전 티어 핀이 무력화된다 |
| **B6** | 저장소 `scripts/`는 **설치 스크립트 전용**이고 `~/.claude/`로 복사되지 않는다 (`apply-to-personal.sh` 확인) | §6a의 런타임 스크립트를 `scripts/`에 두면 설치본에서 사라진다 |

### 1.4 설치 경로 (`scripts/apply-to-personal.sh`)

`skills/claude/*` → `~/.claude/skills/` · `agents/claude/*` → `~/.claude/agents/` · `hooks/claude/hooks/*` → `~/.claude/hooks/` · `hooks/claude/settings.json`은 `jq -s '.[0] * .[1]'`로 기존 `settings.json`에 **재귀 병합**. 스킬·에이전트는 매번 **디렉터리 전체를 지우고 복사**하므로, 설치본에만 존재하는 파일은 살아남지 못한다.

**중요**: 스킬은 소스에서도 설치본에서도 **형제 디렉터리**다(`skills/claude/A/` ↔ `~/.claude/skills/A/`). 따라서 `../dev-loop/references/loop-state.md` 같은 스킬 간 상대 링크가 **양쪽에서 동일하게 해석된다.** W2가 이 성질에 기댄다.

---

## §2. 확인된 Claude Code 사양 (구현이 이 위에 선다)

이 세션에서 공식 문서로 직접 확인한 것만 적는다.

**서브에이전트 프론트매터** ([code.claude.com/docs/en/sub-agents](https://code.claude.com/docs/en/sub-agents))

- `model` — `sonnet` · `opus` · `haiku` · `fable` · 전체 모델 ID · `inherit`. **기본값 `inherit`.**
- `effort` — *"이 서브에이전트가 활성일 때의 effort 레벨. 세션 effort를 덮어쓴다."* 값은 `low` · `medium` · `high` · `xhigh` · `max`이며 **모델에 따라 가용 레벨이 다르다.**
- **모델 해석 우선순위**: `CLAUDE_CODE_SUBAGENT_MODEL` 환경변수 → 호출 인자 `model` → 프론트매터 `model` → 상속. (v2.1.196부터 환경변수를 `inherit`으로 두면 미설정과 동일하게 취급되어 아래 단계로 내려간다.) → **W6 cascade가 호출 인자로 프론트매터를 덮는 근거.**
- **중첩 한도**: 기본 **메인 대화 아래 3계층**. 한도에 도달한 서브에이전트에서는 `Agent` 툴이 회수된다. `CLAUDE_CODE_MAX_SUBAGENT_SPAWN_DEPTH`로 조정 가능.
- **모든 서브에이전트에서 제거되는 툴**: `AskUserQuestion` · `EndConversation` · `EnterPlanMode` · `ExitPlanMode` · `ScheduleWakeup` · `TaskOutput` · `Workflow` 등. → **Worker가 사람에게 물을 수 없다는 하네스의 전제가 문서로 확인된다.**
- 백그라운드 서브에이전트(기본값)는 빌트인 툴이 `Read` · `Grep` · `Glob` · `Bash` · `Edit` · `Write` · `Skill` · `WebFetch` 등으로 축소된다 — **이 계획이 만드는 9개 에이전트가 쓰는 툴은 전부 이 목록 안이라 영향 없다.**

**스킬 프론트매터** ([code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills))

- `model` — *"이 스킬이 활성일 때 쓸 모델. **오버라이드는 현재 턴의 나머지에만 적용되고 설정에 저장되지 않으며, 다음 프롬프트에서 세션 모델이 복귀한다.**"* → **B4의 근거.**
- `effort` — *"세션 effort 레벨을 덮어쓴다."* 턴 스코프 여부가 `model`처럼 명시돼 있지 **않다** — 같게 동작한다고 가정하되 계획의 어떤 항목도 이 가정에 기대지 않게 했다.
- `${CLAUDE_SKILL_DIR}` — 스킬 본문과 `allowed-tools`의 Bash 규칙 **양쪽에서** 치환된다. 공식 예시가 `allowed-tools: Bash(${CLAUDE_SKILL_DIR}/scripts/render.sh *)`이다 → **W8의 스크립트 번들 패턴.**
- 스킬 본문은 호출 시 **한 번 대화에 들어가 세션 끝까지 남는다.** 다시 읽히지 않는다 → 변형 스킬을 얇게 유지할 실질적 이유다.

---

## §3. 목표 상태 — 숫자

전제: 현재 `dev-loop`을 **Opus 세션 · effort xhigh**로 돌린다(상위 문서 §2e). 라운드 단위·작업 환산은 §9.2, 단가는 §9.3의 **정가**를 그대로 쓴다.

| | 구성 | $/라운드 | $/작업 | **$100 작업 수** |
| --- | --- | --- | --- | --- |
| **적용 전** | 전부 Opus/xhigh · `dev-loop`(4축) | $15.63 | ~$35.9 | **2.8** |
| 적용 후 (§9.9 가정) | Sonnet 세션 · 최종 티어 · **`dev-loop-noreview`** | $4.13 | $7.06 | 14.2 |
| **적용 후 (실사용 추정)** | 위 + **test finding remediation** | $4.13 | $7.5~7.9 | **12.7~13.4** |

**2.8 → 약 13작업, 4.7배.**

세 번째 행이 필요한 이유: §9.9는 `noreview`의 remediation 라운드를 **0회**로 가정했다(*"리뷰가 없으면 finding이 없다"*). 그러나 **`test-dev`의 suspected defect는 그대로 남고, §7 결정 3에 따라 사람이 Fix/Accept로 분류한다.** Fix로 분류된 몫이 라운드를 만든다 — 라운드당 약 0.17단위(≈$1.6)이므로 평균 0.25회면 13.4작업, 0.5회면 12.7작업이다. **Accept가 많을수록 14.2에 가까워진다.** §9.9 표의 `noreview` 열은 **낙관 쪽 경계**로 읽어야 한다.

**4.7배의 기여 분해** (단계가 아니라 회계다 — 실제로는 동시에 들어간다):

| 기여 항목 | 이것만 있었다면 | 배수 |
| --- | --- | --- |
| `dev-loop-noreview` 기본값 (W2) | 8.5작업 | **×3.0** |
| 모델 티어링 + 세션 모델 (W1·W3·W4·W7) | ~13작업 | ×1.6 |
| effort 하향 (W1) | 위에 포함 | 한 자릿수 % |

**W2 하나가 절감의 3분의 2를 가져간다.** 나머지 8개 항목이 합쳐서 1.6배다.

**기본 경로의 토큰 지분이 바뀐다.** `dev-loop-noreview`의 라운드는 `implementer` 35% + `tester` 9%(mutation 제외분)만 남으므로, 정규화하면 **implementer 80% · tester 20%**다. 4축 시절의 implementer 35% · 리뷰어 50%와는 다른 세계다 — **이 문서가 상위 문서 §7과 갈리는 이유 전부가 이 한 줄에서 나온다.**

**effort의 상한을 미리 못 박아 둔다.** 출력 토큰은 Opus·Sonnet 모두 라운드 비용의 **32%**다($5.00/$15.63, $3.00/$9.38). effort가 건드리는 것은 그 안의 추론 토큰뿐이므로 **`xhigh` → `high`의 현실적 절감은 한 자릿수 %**로 본다. 상위 문서 §2e의 *"사실상 최대 미사용 레버"*는 **아키텍처 변경이 0이라는 뜻**으로 읽어야지 절감폭이 가장 크다는 뜻으로 읽으면 안 된다. (추론 토큰 비중은 측정하지 않았다 — §10-12에 따라 실측하지 않기로 한 항목이다.)

---

## §4. 적용 단위와 의존 관계

**W1~W9를 한 번에 적용한다.** 단계별 관찰 없이 최종 상태로 직행하므로, 초판의 "현 실효값으로 중립 배치 → 단계별 하향" 전략은 **전부 폐기**한다. 모든 에이전트는 처음부터 §4 배치의 최종 티어로 만든다.

### 4.1 최종 티어 배치 (한 번에 이 상태로 만든다)

| 에이전트 | 신규? | `model` | `effort` | `tools` |
| --- | --- | --- | --- | --- |
| `planner` | | `opus` | `high` | `Read, Grep, Glob, Bash` |
| `plan-consultant` | ✅ | `opus` | `high` | `Read, Grep, Glob, Bash` |
| `security-reviewer` | | `opus` | `medium` | `Read, Grep, Glob, Bash` |
| `reliability-reviewer` | | `opus` | `medium` | `Read, Grep, Glob, Bash` |
| `implementer` | | **`sonnet`** | `high` | `Read, Edit, Write, Bash, Grep, Glob, Skill, **Agent**` |
| `tester` | ✅ | **`sonnet`** | `medium` | `Read, Edit, Write, Bash, Grep, Glob, Skill` |
| `fixer` | ✅ | **`sonnet`** | `medium` | `Read, Edit, Write, Bash, Grep, Glob` |
| `maintainability-reviewer` | | **`sonnet`** | `medium` | `Read, Grep, Glob, Bash` |
| `senior-generalist-reviewer` | | **`sonnet`** | `medium` | `Read, Grep, Glob, Bash` |

**`inherit`은 한 곳도 남지 않는다.** 이것이 §요약-3의 요구다 — 티어는 파일의 속성이어야 하고, 세션 모델 변경이 그것을 조용히 바꿀 수 없어야 한다.

세션 모델은 파일이 아니라 **운용 습관**이다: `plan-dev`는 **Opus 세션**, 모든 `dev-loop*` 실행은 **Sonnet 세션**(W4).

### 4.2 커밋 분할 — 일괄 적용의 유일한 안전장치

동시에 적용해도 **커밋은 항목별로 나눈다.** 회귀가 생겼을 때 어느 변경 탓인지 구분할 방법이 이것뿐이기 때문이다. §8의 롤백 신호는 전부 아래 커밋 하나를 지목하도록 설계돼 있다.

| 커밋 | 항목 | 내용 | 되돌리면 잃는 것 |
| --- | --- | --- | --- |
| C1 | W1 | 6개 에이전트 `model`·`effort` 명시 + `Tier:` 근거 줄 | 티어링 전부 |
| C2 | W3 | `tester` · `fixer` 신설 + `test-dev`·`fix-dev`의 `subagent_type` 교체 | tester/fixer 티어링 (20%) |
| C3 | W2 | `dev-loop-noreview` · `dev-loop-light` 신설 + `test-dev`·`review-code` 한 문단씩 | **절감의 3분의 2** |
| C3b | W2 (분리) | **TESTING 게이트를 Fix/Accept 분류로** — `dev-loop` · 신규 변형 2종의 전이표 + AR 레지스트리 연결 | test finding의 Accept 경로 (원복 시 "fix 또는 closed"로 회귀) |
| C4 | W5 | `single-step-plan.md` 경계 강화 + TODO 난이도 태그 | W7의 게이트 |
| C5 | W6 | cascade — 3-fail 시 T1 1회 재시도 | implementer 하향의 안전망 |
| C6 | W7 | `implementer` → Sonnet + `Agent` 툴 + `plan-consultant` 신설 + implement-flow 4번째 밴드 | implementer 하향 (80%) |
| C7 | W8 | `scripts/claude/` 신설 + `apply-to-personal.sh` 블록 추가 + dispatch 프롬프트 주입 | 반복 추론 제거 |
| C8 | W9 | 리뷰어 정적 계약 이전 + stable-first 재정렬 + 필터 완화 | 4축 리뷰 품질·비용 개선 |
| C9 | W4 | `AGENTS.md` `## Model Tier` + `README.md` + 운용 스위치 경고 | 문서만 (동작 무관) |

**C6은 단독으로 되돌릴 수 있어야 한다.** 롤백 신호 6개 중 3개가 이 커밋을 지목한다(§8). `implementer.md`의 `model:` 한 줄이 실질 내용이므로 되돌리기는 실제로 한 줄이다.

### 4.3 남아 있는 진짜 의존 관계 (전부 "같은 적용분 안에서" 지켜지면 된다)

| 의존 | 이유 |
| --- | --- |
| **C1 → C9(세션 규칙)** | `inherit`이 남은 채 세션을 Sonnet으로 내리면 `security`·`reliability`가 조용히 T2가 된다. C1이 이를 원천 차단한다 |
| **C6은 B3 해소를 포함** | `implementer.md`의 `tools:`에 `Agent`가 없으면 `plan-consultant`는 만들어도 호출되지 않는다 |
| **C7은 `apply-to-personal.sh` 변경을 포함** | `scripts/claude/`가 `~/.claude/scripts/`로 복사되지 않으면 참조가 전부 깨진다(B6) |
| **C3b은 C3와 함께** | 신규 변형 2종의 전이표가 처음부터 Fix/Accept 형태여야 한다. C3b만 되돌리면 세 루프의 게이트가 갈라진다 |
| **모든 커밋 → `apply-to-personal.sh` 실행** | 저장소 수정만으로는 아무것도 바뀌지 않는다. **설치가 마지막 단일 스텝이다** |
| **설치 → 세션 습관 변경** | W4는 파일이 없다. 사용자가 Sonnet 세션으로 `dev-loop*`를 시작하는 순간 발효된다 |

### 4.4 상위 문서 §7과 갈리는 지점 둘

일괄 적용이라 "순서"는 무의미해졌지만, **어디에 검증 노력을 쓸지**는 여전히 이 두 판단이 정한다.

**(1) 상위 §7-2·7-5(리뷰어 관련)는 기본 경로 밖이다 — 단 축마다 거리가 다르다.** Claude 기본값이 `noreview`라 리뷰어가 기본 경로에 없다. 그러나 **`dev-loop-light`을 실사용하기로 했으므로**(§7 결정 1) 리뷰어 4종이 균일하게 멀어지지는 않는다:

| 리뷰어 | 어느 경로에서 도는가 | C8의 값 |
| --- | --- | --- |
| `maintainability` · `senior-generalist` | **`dev-loop-light`** + `dev-loop` + `review-code` 단독 | 실사용 경로에 있다 — (a)정적 계약 이전과 (d)Sonnet 하향이 실제로 값을 낸다 |
| `security` · `reliability` | `dev-loop`(4축) + `review-code` 단독 **뿐** | 드물다 — 이쪽은 하향도 하지 않으므로 (a)(b)(c)만 해당 |

상위 문서 §9.9 말미가 7-3에 대해 내린 판정(*"`dev-loop`을 쓰는 무거운 작업에만 적용되는 레버로 축소해서 보아야 한다"*)이 **7-2·7-5에도 적용되지만, `light`의 2축에 대해서는 절반만 적용된다.** **결과: C8은 만들되, 적용 후 검증에서는 뒤로 미룬다** — `dev-loop-light`을 실제로 몇 번 돌린 뒤에야 관찰 표본이 생긴다.

**(2) 상위 §7-8(cascade)의 성격이 보험에서 전제조건으로 바뀐다.** 4축 리뷰는 `implementer` 하향의 안전망이었다. 기본값이 `noreview`가 되면 그 그물이 사라지므로, **C5(cascade)와 C6(implementer 하향)은 짝이다.** C6만 되돌리는 것은 안전하지만 **C5만 되돌리면 안 된다.**

### 4.5 일괄 적용으로 잃는 것 — 정직하게

상위 문서 §7-5는 *"§6c 필터 완화와 리뷰어 티어 분화를 같은 단계에서 처리해야 recall 하락의 원인이 모델인지 필터인지 구분된다"*고 했다. **일괄 적용에서는 그 구분이 애초에 불가능하다** — 9개가 동시에 들어가므로 어떤 회귀든 후보가 9개다. 이건 순서로 못 푼다.

대신 이렇게 대응한다:

- **기준선은 이미 있다.** `docs/agents/dev/*_LOOP_*.md`의 기존 라운드 기록이 변경 전 중앙값이다. 적용 전에 따로 측정할 필요가 없다.
- **되돌리기 단위를 잘게 유지한다**(§4.2). 신호 → 커밋 매핑을 §8에 표로 고정해 두어, 추론 대신 표를 보고 되돌린다.
- **§8의 보조 지표 2개**(cascade 재시도 빈도, AC/TODO 누락 빈도)는 **C6만을 가리키도록** 설계했다. 9개 중 가장 위험한 하나에 대해서는 귀속이 가능하다.

---

## §5. 작업 단위 상세

### W1 — 6개 에이전트에 최종 `model`·`effort` 명시 (`inherit` 제거) · **커밋 C1**

**목적**: §4 배치를 파일에 표현하고, 세션 모델이 티어를 조용히 바꾸지 못하게 못 박는다.

값은 §4.1 표의 기존 6개 행 그대로다. **`implementer`는 여기서 바로 `sonnet`으로 가지 않고 C6에서 바꾼다** — 되돌리기 단위를 분리하기 위해서다(§4.2). C1에서는 `opus`로 두고, C6가 한 줄을 `sonnet`으로 고친다. 두 커밋이 함께 적용되므로 최종 상태는 `sonnet`이다.

**변경 형태** (`planner.md` 예):

```yaml
---
name: planner
description: "…(기존 그대로)"
tools: Read, Grep, Glob, Bash
model: opus
effort: high
---
```

본문에는 §5가 요구한 티어 근거를 **한 줄** 추가한다. 모델명이 아니라 근거가 문서화 대상이다:

```markdown
Tier: T1 judgment — 아키텍처 판단은 되돌릴 수 없고 기계 검증이 불가능하다.
```

**실질 변경은 effort뿐이다.** 모델은 현 실효값(Opus 세션이므로 전부 Opus)을 명시하는 것이라 C1 단독으로는 동작이 같고, `maintainability`·`generalist`의 `sonnet` 하향은 C8이, `implementer`는 C6가 가져간다.

**검증**: `rg -c '^model:|^effort:' agents/claude/*.md`가 모든 파일에서 2를 반환. `rg 'inherit' agents/claude/`가 **빈 결과**.

**주의**: `effort`의 가용 레벨은 모델마다 다르다(공식 문서). Opus 5·Sonnet 5는 `low~max` 전부 지원하므로 위 값은 안전하다.

---

### W2 — `dev-loop-noreview` · `dev-loop-light` 신설 · **커밋 C3 · 최대 레버**

**목적**: §9.9의 3-스킬 병존 구조를 실제로 만든다. Claude 기본값은 `dev-loop-noreview`.

**`dev-loop-light`도 함께 만드는 이유 두 가지**: **(1) Claude에서도 실사용한다**(§7 결정 1) — `noreview`로는 불안하지만 4축까지는 과한 중간 지대가 실제로 존재한다. **(2)** Codex 기본값이 `light`인데(§9.9) 개인 하네스의 중심이 Claude Code이고 Codex 변형은 `docs/sync-harness/SYNC_TO_CODEX.md` 경유로 파생되므로(AGENTS.md), **원본이 `skills/claude/`에 없으면 Codex 기본값을 만들 경로가 없다.** (1)이 확정되면서 `review-code`의 축 부분집합 수정(§2.4)과 C8의 리뷰어 하향이 **부가 작업이 아니라 실사용 경로의 작업**이 됐다.

#### 2.1 신규 파일

```
skills/claude/dev-loop-noreview/SKILL.md
skills/claude/dev-loop-noreview/references/transitions.md
skills/claude/dev-loop-light/SKILL.md
skills/claude/dev-loop-light/references/transitions.md
```

**`loop-state.md`는 복제하지 않는다.** LOOP 파일 포맷은 세 변형에서 동일하므로(`Findings`·`Applied AR` 필드가 대개 `none`이 될 뿐) 두 신규 스킬은 `../dev-loop/references/loop-state.md`를 **상대 링크로 참조**한다. §1.4에서 확인했듯 이 경로는 저장소와 설치본 양쪽에서 동일하게 해석된다. (대안은 파일 복제인데, 체크포인트 포맷이 셋으로 갈라져 드리프트하는 대가가 링크 하나의 취약성보다 크다.)

`transitions.md`는 **복제가 아니라 신규 작성**이다. `noreview`의 상태 기계는 4축 기계에서 행 몇 개를 뺀 것이 아니라 **다른 기계**이기 때문이다.

#### 2.2 `dev-loop-noreview`의 상태 기계

```
PLANNED → IMPLEMENTING → TESTING → READY_TO_COMMIT
              ├─ blocked → BLOCKED_DIRECTION
              ├─ failed  → ESCALATED
              └─ TESTING: pass-with-suspected-defects → 휴먼 게이트 → FIXING → TESTING(reduced) → READY_TO_COMMIT
```

기존 대비 달라지는 것:

- **REVIEWING 상태와 리뷰 finding triage가 없다.** 종료 술어 ⑥(HIGH/CRITICAL 미분류 0건)은 REVIEW-NNN 전용이므로 **`## Findings`의 TEST-NNN 미분류 0건으로 대체**한다. ⑤는 mutation 조항을 뺀 형태로 남는다.
- **AR 레지스트리는 살아남는다** — §7 결정 3의 직접 결과다. Accept 대상이 REVIEW-NNN에서 TEST-NNN으로 바뀔 뿐 기구는 그대로이므로 **종료 술어 ⑦(Accept → AR 기록)이 유지된다.** 초판이 "triage·AR이 통째로 없다"고 쓴 것은 이 결정으로 무효다.
- **휴먼 게이트는 2개로 유지되되 성격이 바뀐다**: `review-code` triage가 사라진 자리를 `test-dev`의 suspected-defect 게이트가 단독으로 채우고, READY_TO_COMMIT은 그대로다.
- **remediation의 유일한 출처가 `test-dev`의 `## Findings`다.** Fix로 분류된 것만 `fix-dev` → `TESTING(reduced)` → 종료 판정으로 되돌아온다(리뷰가 없으므로 REVIEWING 재진입이 없다).
- **"final mutation round" 규칙 전체가 삭제된다** — 이 변형은 mutation을 아예 돌리지 않는다.
- 예산·에스컬레이션·금지사항·훅 절은 `dev-loop`과 동일하게 유지한다(Loop budget 기본 3, `blocked`/`needs-confirmation` 즉시 정지, 커밋·푸시·PR 금지, **AR 자체 기록 금지 — 사용자의 명시적 Accept만이 기록을 만든다**).

#### 2.2b TESTING 게이트를 Fix/Accept로 (§7 결정 3) · **커밋 C3b** · 세 루프 공통

현재 `dev-loop`의 TESTING 게이트는 *"Fix → queue for FIXING / user closes it (judged not a defect) → closed"*다. `closed`는 **"결함이 아니다"** 한 가지 뜻뿐이라, **"결함이 맞지만 감수한다"**를 표현할 자리가 없다. §7 결정 3에 따라 `review-code`와 같은 어휘로 맞춘다.

| | 변경 전 | 변경 후 |
| --- | --- | --- |
| 선택지 | Fix / closed(결함 아님) | **Fix / Accept** |
| Accept의 기록 | 없음 | **AR 엔트리**(`review-code`의 `## Accepted Review Exceptions` 레지스트리 재사용) |
| 미응답 | 정지 | 정지 (동일 — 자동 분류 금지) |

**세 루프 전부에 적용한다.** 같은 test finding이 어느 루프를 돌렸느냐에 따라 다르게 처리되면 안 된다. 따라서 `dev-loop/SKILL.md`와 `dev-loop/references/transitions.md`도 C3b의 대상이다.

**AR 레지스트리 재사용 시 손볼 곳 2가지** — 스펙은 `review-code/SKILL.md`의 "Accepted Review Exceptions registry" 절에 있고, 신규 변형 2종은 `../review-code/SKILL.md`의 해당 절을 **상대 링크로 참조**한다(§1.4의 형제 디렉터리 성질, `loop-state.md`와 같은 패턴):

1. **`Original severity` 필드** — 현재 `{CRITICAL | HIGH}`만 받는다. test finding은 severity 태그가 없으므로 **`TEST (suspected defect)`**를 허용값으로 추가한다.
2. **불변식 문구** — *"an AR entry is written only on the user's explicit Accept answer in triage"*는 그대로 유효하다. 다만 "triage"가 이제 review triage와 **TESTING 게이트 둘 다**를 가리킨다는 한 줄을 덧붙인다.

**비용 영향**: Accept가 라운드를 만들지 않으므로, 이 변경은 §3 세 번째 행의 추정을 **12.7 쪽이 아니라 14.2 쪽으로 민다.** Accept 비율이 높을수록 `noreview`가 §9.9의 원래 숫자에 가까워진다.

#### 2.3 `dev-loop-light`의 상태 기계

`dev-loop`과 동일하되 두 곳만 다르다 — **REVIEWING이 `maintainability-reviewer` · `senior-generalist-reviewer` 2축만 돌리고**, **TESTING이 mutation을 제외한다**(따라서 final mutation round 규칙도 삭제). triage·AR·종료 술어 9개는 전부 그대로다.

#### 2.4 기존 스킬에 필요한 최소 변경 — **§9.9의 "기존 스킬 무변경"은 성립하지 않는다**

| 파일 | 변경 | 이유 | 어느 변형이 요구하나 |
| --- | --- | --- | --- |
| `skills/claude/test-dev/SKILL.md` (Prepare 3 · Phase 3) | *"호출자가 mutation을 명시적으로 범위 밖으로 지정하면 Phase 3을 건너뛰고, 이를 `blocked` 사유로 삼지 않는다"* 한 문단 추가 | 현재 계약상 **mutation 커맨드 부재는 `blocked` 사유**다(worker-contract B: *"필수 검증/mutation 커맨드가 없으면 `blocked`"*). 이 문장이 없으면 두 변형이 매 라운드 `blocked`로 정지한다 | **noreview · light 둘 다** |
| `skills/claude/review-code/SKILL.md` ("Reviewer roles" · "Dispatch the four reviewers") | *"호출자가 축 부분집합을 지정할 수 있으며 기본값은 4축 전부"* 한 문단 추가 | `dev-loop-light`가 2축만 돌려야 하는데 현재는 4축이 하드코딩돼 있다. **대안(변형 루프가 리뷰어를 직접 dispatch)은 `dev-loop`의 불변식 — *"never dispatches a stage's Worker directly"* — 을 깬다** | light만 |
| `skills/claude/review-code/SKILL.md` ("Accepted Review Exceptions registry") | `Original severity`에 `TEST (suspected defect)` 허용 + "triage"의 범위를 두 게이트로 명시 | §2.2b — TEST-NNN Accept가 AR 엔트리를 만든다 | **셋 다** (C3b) |
| `skills/claude/dev-loop/SKILL.md` + `references/transitions.md` | TESTING 게이트를 `Fix / closed` → **`Fix / Accept`** | §2.2b — 세 루프의 게이트가 갈라지면 안 된다 | **셋 다** (C3b) |

**결과적으로 기존 스킬 3개를 건드린다** — `test-dev` · `review-code` · `dev-loop`. §9.9가 전제한 "기존 스킬 무변경"과 가장 크게 벌어지는 지점이며, 각 변경이 한 문단 규모라 리스크 자체는 낮지만 **`dev-loop`(현행 유지하기로 한 스킬)까지 대상에 들어온다는 점**은 짚어 둔다.

#### 2.5 명명·발견성

세 스킬의 `description`은 **선택 기준을 서로 배타적으로** 써야 한다. 모델이 자동으로 고르는 것이 아니라 사용자가 `/dev-loop-noreview`로 부르는 것이 정상 경로이므로, 각 `description` 첫 문장에 용도를 박는다 — `dev-loop`은 *"진짜 심각하거나 거대한 기능 개발"*, `light`는 *"리뷰는 필요하지만 4축까지는 과한 작업"*, `noreview`는 *"기본값 — 대부분의 일상 작업"*.

**검증**: 두 변형을 실제 플랜 하나에 각각 돌려 ① `test-dev`가 mutation을 `blocked` 없이 건너뛰는지, ② LOOP 파일이 `../dev-loop/references/loop-state.md` 포맷대로 append되는지, ③ `noreview`가 REVIEWING을 한 번도 거치지 않고 READY_TO_COMMIT에 도달하는지, ④ **TEST-NNN을 Accept로 분류했을 때 AR 엔트리가 실제로 기록되고 종료 술어 ⑦이 그것을 읽는지**, ⑤ `light`가 `maintainability` · `senior-generalist` **2개만** dispatch하는지 확인.

**리스크**: `noreview`는 이름과 달리 **완전히 게이트 없는 루프가 아니다** — §2.2b 이후로 TESTING 휴먼 게이트 + AR 레지스트리를 그대로 갖는다. 사용자가 "리뷰 없는 빠른 루프"를 기대하고 불렀다가 매 라운드 분류 질문을 받으면 기대와 어긋난다. **`description`에 이 사실을 한 줄로 노출한다**(§2.5) — 사라지는 것은 *리뷰어 4종*이지 *사람의 판단*이 아니다.

---

### W3 — `tester` / `fixer` 에이전트 신설 · **커밋 C2**

**목적**: B1·B2 해소. 기본 경로 토큰의 **20%(tester)**를 티어링하고, W6 cascade가 붙을 자리를 만든다.

#### 신규 파일 2개

| 파일 | `tools` | `model` | `effort` | 비고 |
| --- | --- | --- | --- | --- |
| `agents/claude/tester.md` | `Read, Edit, Write, Bash, Grep, Glob, Skill` | `sonnet` | `medium` | `Skill` 필요 — dispatch 프롬프트가 *"Use the `test-dev` skill"*로 시작한다 |
| `agents/claude/fixer.md` | `Read, Edit, Write, Bash, Grep, Glob` | `sonnet` | `medium` | `Skill` 불필요 — `fix-dev`의 dispatch 프롬프트는 자족적이거나 SKILL.md 절대경로를 `Read`시킨다 |

**처음부터 `sonnet`이다.** §4가 이 둘에 부여한 근거가 4축 리뷰어보다 강하기 때문이다 — **`tester`는 mutation score ≥80%라는 기계 목표를 갖고 프로덕션 코드 수정이 금지돼 blast radius가 제한적이며, `fixer`는 리뷰 finding이 곧 명세이고 재테스트로 검증된다.** 롤백은 C2를 되돌리거나 두 파일의 `model:` 한 줄씩을 `opus`로 고치는 것이다(§8-4).

**본문**: 각 에이전트의 시스템 프롬프트에 해당 스킬의 Global Rules 요지를 담는다. `general-purpose`와 달리 명명 에이전트는 **본문이 곧 시스템 프롬프트**라, `test-dev`의 Global Rule 6(테스트 코드 전용) 같은 불변식이 프롬프트에 명시적으로 들어가야 한다. **툴 레벨로는 강제할 수 없다** — `tester`는 테스트 파일을 쓰기 위해 `Edit`·`Write`가 필요하고, 그 툴은 프로덕션 파일에도 열려 있다. 산문 제약으로 남는다는 사실을 본문에 못 박는다.

#### 기존 스킬 수정 2곳

- `skills/claude/test-dev/SKILL.md` "Execution modes" + `references/worker-contract.md` 도입부: `subagent_type: general-purpose` → **`tester`**.
- `skills/claude/fix-dev/SKILL.md` "2. Dispatch one sub-agent by default": `subagent_type: general-purpose` → **`fixer`**.

두 스킬 모두 *"페르소나를 못 쓰면 `general-purpose`에 계약 전문을 주는 것이 허용된 폴백"*이라는 `review-code`의 기존 문구와 같은 안전장치를 한 줄 덧붙인다.

---

### W4 — 세션 모델 운용 규칙 + `## Model Tier` 문서화 · **커밋 C9**

**의존: C1**(§4.3). `inherit`이 남아 있는 상태로 이 규칙을 적용하면 §요약-3의 조용한 하향이 발생한다.

**B4 때문에 스킬 프론트매터로는 불가능하다.** `plan-dev`는 멀티턴 인터뷰이고 `dev-loop*`는 휴먼 게이트로 턴이 끊기므로, 턴 스코프인 `model:`은 두 스킬 모두에서 다음 프롬프트에 풀린다. **호출 경계 = 세션 경계**로 운용한다:

| 세션 | 모델 | 근거 |
| --- | --- | --- |
| `plan-dev` | **Opus** | 방향·경계·AC는 되돌릴 수 없고 실행자가 자가 수정 불가 |
| **모든 `dev-loop*` 실행** | **Sonnet** | 컨트롤러는 전이표 조회 + LOOP append. T1 에이전트(planner·consultant·security·reliability 리뷰어)는 프론트매터 핀으로 Opus에서 돈다 |

일괄 적용이므로 **`dev-loop`(4축)도 예외 없이 Sonnet 세션이다** — C1과 C8이 네 리뷰어의 모델을 전부 명시해 두므로 세션이 무엇이든 티어가 유지된다. (초판은 C8이 나중에 온다는 전제로 4축만 Opus 세션을 유지하라고 했는데, 그 단서는 이 개정으로 소멸했다.)

**선택적 보조 수단**: `dev-loop-noreview/SKILL.md`에 `model: sonnet`을 넣으면 **첫 턴(preflight + IMPLEMENTING dispatch)만** Sonnet으로 돈다. 무해하지만 이후 턴에 세션 모델이 복귀하므로 세션 운용을 대체하지 못한다. **권장: 넣지 않는다.**

**문서화 (§5 요구사항)**

- `AGENTS.md`에 **`## Model Tier`** 섹션 신설: 티어 정의표(T1/T2/T3) + **§4.1의 에이전트 배치표** + **세션 운용 규칙표**(위).
- `README.md`의 대응 절도 같은 내용으로 갱신.
- **운용 스위치 경고**: `CLAUDE_CODE_SUBAGENT_MODEL`은 프론트매터와 호출 인자를 **모두** 덮어쓰므로(§2), 켜두면 전 티어 핀이 무력화된다. **`hooks/claude/settings.json`에 `env` 블록을 추가하지 않는다** — 미설정이 정상 상태다. A/B 테스트용 임시 수단으로만 `AGENTS.md`에 문서화하고, `inherit`으로 두면 미설정과 동일하게 취급된다는 점(v2.1.196+)을 함께 적는다.

**이 항목만 설치 파일이 아니라 습관이다.** `apply-to-personal.sh` 실행 후, 사용자가 Sonnet 세션에서 `dev-loop*`를 시작하는 순간 발효된다.

---

### W5 — `## Authority Boundaries` 강화 + TODO 난이도 태그 · **커밋 C4**

**목적**: 비용 0. C5·C6의 게이트. 효율 모델에게 부족한 것은 디테일이 아니라 **자기 권한의 경계**다(§3-B).

**대상**: `skills/claude/plan-dev/references/single-step-plan.md`

- **§6 Authority Boundaries**: 현재 `Discretion` / `Must-ask` / `Stop conditions` / `Loop budget` 4항목이 플랜 전체에 대해 한 번 쓰인다. 여기에 **TODO별 한 줄**을 요구하는 형태를 추가한다 — *"여기서 로컬 판단해도 되는 것 / 반드시 escalate할 것"*. 플랜 길이는 거의 늘지 않는다.
- **§7 TODO checklist**: 각 항목에 **`(mechanical)` / `(design-bearing)`** 태그를 요구한다. 기존의 `(AC-N)` · `(→ research: …)` 표기와 같은 자리에 붙인다.

```markdown
- [ ] Add rate-limiting to the public API layer (token-bucket per API key) (AC-1) (design-bearing) (→ research: rate-limit-capacity)
- [ ] Update the docs page for rate limits (AC-3) (mechanical)
```

- **§8 File skeleton**도 같이 갱신.

**이 태그가 W7의 게이트가 된다.** §10-11에서 `plan-consultant` 호출 상한을 두지 않기로 했으므로, **`design-bearing` 태그를 인색하게 붙이는 것이 사실상의 유일한 예산 통제**다. 그 사실을 `single-step-plan.md`에 한 줄로 적어 둔다.

**하위 호환**: 기존 플랜은 태그가 없어도 `implement-dev`가 거부하지 않아야 한다 — **태그 부재 = 전부 `mechanical`로 간주**.

---

### W6 — cascade: 3-fail 시 중단 대신 T1 1회 재시도 · **커밋 C5**

**의존: C2**(`fixer`가 있어야 `fix-dev` 쪽에도 붙는다). **C6와 짝** — C5만 되돌리면 안 된다(§4.4-2).

**목적**: 효율 모델의 실패 꼬리를 자른다. **`noreview`가 기본값이면 리뷰가 더 이상 implementer의 실수를 잡아주지 않으므로, 이건 보험이 아니라 C6의 전제조건이다.**

**구현 위치는 Dispatcher다 — 루프가 아니다.** `dev-loop`의 전이표는 `failed` → ESCALATED이지만, `dev-loop/SKILL.md`가 이미 *"Each skill's internal 3-attempts-per-error rule stays internal; the loop does not retry a `failed` stage on its own"*이라고 못 박아 두었다. 따라서 재시도가 **스테이지 스킬의 Dispatcher 안에서 끝나면 루프는 첫 `failed`를 아예 보지 않는다.** 루프 파일은 한 줄도 안 바뀐다.

**메커니즘**: Worker가 `## Stage Status: failed`를 반환하면, Dispatcher가 **`Agent` 툴의 호출 인자 `model: opus`로 정확히 1회** 재dispatch한다. 호출 인자는 프론트매터보다 우선한다(§2 해석 우선순위). 두 번째도 `failed`면 그대로 `failed`를 위로 올린다.

**대상 파일**:

- `skills/claude/implement-dev/references/worker-contract.md` — **§E(Delegation failure) 옆에 신규 절**. E는 *dispatch 자체가 실패*한 경우이고 cascade는 *Worker가 `failed`를 반환한* 경우라 다른 사건이다. 혼동을 막기 위해 절을 분리한다.
- `skills/claude/implement-dev/SKILL.md` "Error Recovery" 5번 — 재시도 1회가 그 뒤에 온다는 한 줄.
- `skills/claude/fix-dev/SKILL.md` "Fix work contract" 6번(3회 실패 시 `failed`) + "3. Present the result" — 동일 규칙.

**불변식**: **재시도는 정확히 1회.** 무한 승격 금지. 재시도했다는 사실과 결과를 Dispatcher의 chat summary(③)에 한 줄로 남긴다 — **남기지 않으면 §8의 보조 지표 1이 사라지고, 일괄 적용에서 유일하게 C6에 귀속 가능한 신호를 잃는다.**

---

### W7 — `implementer` → Sonnet + `plan-consultant` 신설 · **커밋 C6 · 최대 리스크**

**의존: C4(경계·태그) · C5(cascade).** 기본 경로 토큰의 **80%**가 여기 있다.

**변경 1 — `agents/claude/implementer.md`**

```yaml
model: sonnet        # C1의 opus에서 하향
effort: high         # 유지 — 여기가 기본 경로의 80%다
tools: Read, Edit, Write, Bash, Grep, Glob, Skill, Agent    # Agent 추가 (B3)
```

`Agent` 추가는 §2에서 확인한 사양의 요구다 — 서브에이전트가 자식을 낳으려면 `tools`에 `Agent`가 명시돼야 한다. 깊이는 main → implementer(1) → consultant(2)로 기본 한도 3계층 안이다.

**변경 2 — `agents/claude/plan-consultant.md` (신규)**

```yaml
name: plan-consultant
tools: Read, Grep, Glob, Bash        # read-only
model: opus
effort: high
```

본문: T1 근거 한 줄 + **"짧은 결정 + 근거만 반환하고 코드를 쓰지 않는다"**는 계약. 호출당 비용이 이 항목의 성패를 가르므로 반환 형식을 짧게 고정한다.

**변경 3 — `skills/claude/implement-dev/references/implement-flow.md` §2 "Deviations"**

현재 2-bucket(detail / direction)에 **중간 밴드**를 추가한다: *두 접근이 모두 플랜과 정합하지만 되돌리기 비싼 경우.* 이때만 `plan-consultant`를 호출한다. 호출 조건은 **C4의 `(design-bearing)` 태그가 붙은 TODO에 한정**한다 — 상한을 두지 않기로 했으므로(§10-11) 이 태그가 유일한 게이트다.

**리스크가 가장 큰 커밋이다.** 상위 문서 §7의 롤백 기준 4개 중 **1(remediation 라운드 중앙값 +1 이상 지속)과 3(instruction drift — AC 미이행·TODO 체크박스 누락·컨벤션 위반)**이 정확히 이 커밋을 지목한다. `noreview` 기본값에서는 리뷰어가 3번을 잡아주지 않으므로 **사람이 IMPL 리포트의 `## TODO Fulfillment`와 AC 증거를 직접 봐야 한다.** 그 점을 `AGENTS.md`의 운용 규칙에 적는다(C9).

**롤백**: `model: sonnet` → `opus` 한 줄. `plan-consultant`와 `Agent` 툴 추가는 남겨도 무해하다.

---

### W8 — scope·커맨드 탐지 스크립트 · **커밋 C7**

**B6 때문에 상위 문서 §6a의 경로대로 만들면 동작하지 않는다.** 저장소 `scripts/`는 설치 스크립트 전용이고 `~/.claude/`로 복사되지 않는다.

**설치 위치: `scripts/claude/` 신설** (§7 결정 2). `detect-commands.sh`의 소비자가 3개라 한 벌만 두는 쪽이 맞다.

```
scripts/claude/detect-commands.sh   →   ~/.claude/scripts/detect-commands.sh
scripts/claude/resolve-scope.sh     →   ~/.claude/scripts/resolve-scope.sh
```

**`apply-to-personal.sh`에 블록 하나를 추가한다.** 기존 hooks 블록을 그대로 본뜬다 — 대상 디렉터리를 비우고 복사하며, **`cp -rp`로 실행 권한을 보존**하는 것이 핵심이다(hooks 블록이 `-p`를 쓰는 이유가 이것이다). `SCRIPTS_SOURCE_DIR="${SCRIPT_DIR}/../scripts/claude"` · `SCRIPTS_DIR="${CLAUDE_HOME}/scripts"`를 상단 변수 블록에, `mkdir -p`에 `${SCRIPTS_DIR}`를 추가하고, 설치 요약 출력에도 한 줄 넣는다.

**권한 프리어프루브의 대가 하나.** `${CLAUDE_SKILL_DIR}` 치환을 못 쓰게 되므로(스크립트가 스킬 폴더 밖에 있다), 소비 스킬은 `$HOME/.claude/scripts/detect-commands.sh`를 **문자 그대로** 호출하고 `allowed-tools: Bash($HOME/.claude/scripts/detect-commands.sh *)`로 매칭시킨다. 공식 문서가 치환을 보장하는 변수는 `${CLAUDE_SKILL_DIR}`와 `${CLAUDE_PROJECT_DIR}` 둘뿐이라 `$HOME`은 **양쪽 모두 리터럴로 남고 셸이 실행 시점에 확장한다** — 규칙과 명령 문자열이 리터럴로 일치하므로 동작한다. 다만 문서화된 동작이 아니므로, **어긋나면 권한 프롬프트가 한 번 뜨는 것이 최악**이라는 점을 확인해 두고 넘어간다(무해한 실패 모드).

**Codex 쪽 대응은 이 계획 밖이다.** `apply-to-work.sh`가 같은 구조를 갖고 있으므로 `scripts/codex/` → `~/.codex/scripts/` 블록이 대칭으로 필요하지만, `docs/sync-harness/SYNC_TO_CODEX.md`의 변환 규칙과 함께 다뤄야 한다.

**스크립트 2개**

| 스크립트 | 소비자 | 하는 일 | 기본 경로에 있나 |
| --- | --- | --- | --- |
| `detect-commands.sh` | `implement-dev` · `test-dev` · `fix-dev` | `Makefile` 타겟 + `AGENTS.md`/`CLAUDE.md`/`README.md`에서 lint·format·test·build·mutation 커맨드를 JSON으로 추출 | ✅ **3곳 전부** |
| `resolve-scope.sh` | `test-dev` · `review-code` | diff 범위·변경 파일 절대경로·언어를 JSON 한 덩어리로 | △ `noreview`에서는 `test-dev`만 |

**절감이 가장 확실한 지점은 `implement-dev`다.** 현재 dispatch 프롬프트(`worker-contract.md` §B)는 검증 커맨드를 **전달하지 않고**, Worker가 `implement-dev`의 Prepare 2단계에서 매번 재발견한다. 반면 `test-dev`의 dispatch 프롬프트는 이미 `lint`/`unit`/`e2e`/`mutation`을 전달한다 — 그쪽에서 스크립트가 줄이는 것은 **Dispatcher의 왕복**이지 Worker의 추론이 아니다. **따라서 `detect-commands.sh`의 첫 소비자는 `implement-dev`의 dispatch 프롬프트에 검증 커맨드 블록을 추가하는 것이다.**

**언어 컨벤션 게이팅(§6a-3)에 대한 정직한 한계**: `implement-dev`의 필수 컨벤션 게이트는 Worker가 매칭되는 컨벤션 파일 **전문**(go 127행 / swift 154행 / ts-nextjs 197행)을 읽도록 요구한다. 스크립트가 diff 확장자로 *어떤 언어인지*를 결정론적으로 정해줄 수는 있지만 **읽는 행위 자체는 남는다.** 절감 대상은 판단이지 읽기가 아니다.

---

### W9 — 리뷰어 정적 계약 이전 + 필터 완화 + 리뷰어 T2 분화 · **커밋 C8 · 기본 경로 밖**

상위 문서 §7-2와 §7-5를 하나로 묶는다. **Claude 기본값이 `noreview`이므로 이 커밋 전체가 `dev-loop`(4축)과 `review-code` 단독 실행에만 값을 갖는다**(§4.4-1).

**(a) 정적 계약 이전 (상위 §7-2)** — `review-code/SKILL.md`의 dispatch 프롬프트가 매 라운드 4× 축자 전달하는 것 중 **리뷰어별로 불변인 것**을 각 에이전트 본문(=시스템 프롬프트, 캐시됨)으로 옮긴다: bug bar 7개 조건, priority 정의 4종, per-finding block 포맷, specificity rules 6종, lane reminder. **AR suppression rule은 옮기지 않는다** — AR 엔트리가 있을 때만 전달되므로 현행이 맞다. `SKILL.md`는 축자 전달 대신 참조만 남긴다.

**(b) stable-first 재정렬 (상위 §7-2)** — 현재 "Dispatch the four reviewers"의 나열 순서는 **diff가 먼저**다. 프리픽스 캐싱은 접두 일치이므로 정확히 역순이다. **불변(정적 계약) → 준불변(AGENTS.md 발췌·파일 목록) → 변동(diff)** 순서를 `SKILL.md`에 명시한다. 비용 0.

**(c) 필터 완화 (§6c, §10-10)** — "What counts as a bug"의 7개 AND 조건과 *"Ignore style, formatting, typos, and nits"*는 최신 모델이 **문자 그대로 따라 recall을 떨어뜨리는** 형태다. 리뷰어가 confidence·severity를 붙여 전부 보고하게 하고, **필터링은 `review-code`의 Aggregate 단계로 옮긴다.**

**(d) 리뷰어 T2 분화 (상위 §7-5)** — `maintainability-reviewer` · `senior-generalist-reviewer`를 `model: sonnet`으로.

**(c)와 (d)를 같은 커밋에 두는 것이 상위 §7-5의 요구였다.** 일괄 적용에서는 그 인과 구분이 어차피 불가능하지만(§4.5), **되돌리기 단위로는 여전히 의미가 있다** — C8을 통째로 되돌리면 필터와 모델이 함께 원복되므로 중간 상태가 생기지 않는다.

---

## §6. 하지 않는 것

| 항목 | 상위 문서 | 판단 |
| --- | --- | --- |
| **diff-class 스크립트 + trivial 축 축소** | §6a-4, §7-3 | **보류.** 기본 경로(`noreview`)에 리뷰가 없어 한계 이득이 0이고, `dev-loop-light`에서는 축이 이미 2개라 더 줄일 여지가 없다. **덧붙여, 나중에 도입하더라도 `light` 위에 그냥 얹을 수 없다** — §6b의 trivial 축소는 **`security`+`reliability`**(miss 비용 기준)를 남기는데 `dev-loop-light`은 **`maintainability`+`senior-generalist`**(단가 기준)를 남긴다. **정반대 쌍이다.** 두 기준을 어떻게 합칠지는 도입 시점에 따로 정해야 한다 |
| **조건부 Implementation Brief** | §3-D, §7-11 | **보류.** C6(`plan-consultant`)로 부족하다는 증거가 나온 뒤에만. 신규 아티팩트를 만드는 유일한 항목이다 |
| **Haiku 4.5 도입** | §4 T3 | **없음.** 컨텍스트 200K·캐시 최소 프리픽스 4096 tok·모델 레벨 effort 미지원으로 하네스에 안전한 자리가 없다. 진짜 기계적인 일은 셸로(W8) |
| **교차 벤더 리뷰** | §6c | **Claude 단독으로는 불가.** Claude Code는 Anthropic 모델만 쓴다 |
| **`CLAUDE_CODE_SUBAGENT_MODEL` env 설정** | §5 | **설정하지 않는다.** 미설정이 정상. 문서화만(W4) |
| **§9 토큰 프로파일 실측** | §10-12 | 사용자 결정 — 하지 않는다. 이 문서의 모든 수치는 §9의 추정 위에 서 있다 |

---

## §7. 결정 기록

**열린 질문은 남기지 않는다.** 초판의 5건 중 2건은 일괄 적용 결정으로 소멸했고(§4), 나머지 3건은 2026-08-03에 확정됐다.

> **참조 표기**: 이 문서 안에서 `§7 결정 N`은 아래 표의 행을, `상위 §7-N`은 [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md) §7 실행 순서표의 행을 가리킨다. 그 외 `§N`은 상위 문서의 절 번호다.

| # | 항목 | 결정 | 이 계획에 미친 영향 |
| --- | --- | --- | --- |
| 1 | `dev-loop-light`을 Claude에도 만들 것인가 | ✅ **만든다. 원본 제공 목적이 아니라 Claude에서도 실사용한다** | `review-code`의 축 부분집합 수정과 C8의 리뷰어 하향이 **부가 작업에서 실사용 경로 작업으로** 격상(§4.4-1, W2) |
| 2 | 런타임 스크립트 설치 위치 | ✅ **`scripts/claude/` 신설 → `~/.claude/scripts/`** | `apply-to-personal.sh`에 블록 추가가 C7에 포함. `${CLAUDE_SKILL_DIR}` 프리어프루브를 잃고 `$HOME` 리터럴 매칭으로 대체(W8) |
| 3 | `test-dev`의 suspected defect 처리 | ✅ **사람이 Fix/Accept로 분류** | **커밋 C3b 신설.** `noreview`에서도 AR 레지스트리가 살아남고 종료 술어 ⑦이 유지된다. 기존 스킬 수정 대상이 `dev-loop`까지 3개로 늘었다(W2.2b) |
| — | tester/fixer 초기 모델 | 소멸 — 단계가 없으니 처음부터 `sonnet` | §4.1 |
| — | W9 적용 시점 | 소멸 — 어차피 함께 들어간다 | §4.2 |

**3번 결정의 성격을 한 줄로**: 이건 비용 결정이 아니라 품질 정책 결정이다. Accept 경로가 생기면서 **`noreview`가 §9.9의 14.2작업 쪽으로 다시 밀리지만**(Accept는 라운드를 안 만든다), 동시에 `noreview`가 "게이트 없는 루프"가 아니게 됐다. 얻은 것은 *결함을 알면서 넘어간 기록이 남는다*는 것이고, 대가는 *리뷰를 껐는데도 분류 질문을 받는다*는 것이다.

---

## §8. 검증과 롤백

**주 지표는 상위 문서와 동일하다 — 플랜당 remediation 라운드 수.** `docs/agents/dev/*_LOOP_*.md`에 이미 append-only로 기록되므로 **적용 전 기준선이 이미 디스크에 있다**(§4.5). 적용 후 몇 번의 실행에서 중앙값을 비교한다.

**`noreview` 기본값에서 새로 필요한 보조 지표 2개** — 리뷰어가 사라져 관찰 창이 좁아지고, 일괄 적용이라 귀속이 어렵기 때문이다. **둘 다 C6만을 가리키도록 설계했다:**

1. **cascade 재시도 발생 빈도**(W6이 chat summary에 남기는 줄) — Sonnet `implementer`가 실제로 막히는 비율.
2. **IMPL 리포트의 AC 증거 누락·TODO 체크박스 누락 빈도** — 4축 리뷰가 잡아주던 instruction drift를 사람이 직접 봐야 한다.

**롤백 — 신호에서 커밋으로 바로 간다.** 일괄 적용이라 추론으로 범인을 찾을 수 없으므로, 이 표가 추론을 대신한다.

| # | 신호 | 되돌릴 커밋 | 실질 변경량 |
| --- | --- | --- | --- |
| 1 | remediation 라운드 중앙값 +1 이상 지속 | **C6** (implementer 하향) | `model:` 한 줄 |
| 2 | instruction drift 증가 — AC 미이행 · TODO 체크박스 누락 · 컨벤션 위반 | **C6** | 한 줄 |
| 3 | cascade 재시도 빈도가 실행의 상당 비율 | **C6** — Sonnet이 이 작업 유형에 부족하다는 직접 증거 | 한 줄 |
| 4 | mutation efficacy 중앙값 하락 · 테스트 약화 흔적 | **C2** (tester 하향) | `tester.md`의 `model:` 한 줄 |
| 5 | `blocked`(direction conflict) 비율 증가 | **C4** — 경계 명시가 부족한데 티어만 내렸다. **되돌리는 게 아니라 강화한다** | 레퍼런스 보강 |
| 6 | 보안·신뢰성 계열 결함이 사람 리뷰에서 연속 발견 | **C3의 기본값 선택** — `noreview`가 이 작업 유형에 맞지 않는다. 스킬을 지우는 게 아니라 **기본값을 `light`로, 그래도 안 되면 `dev-loop`로 올린다** | 운용 결정 |
| 7 | TESTING 게이트의 분류 질문이 흐름을 과도하게 끊는다 | **C3b** — `Fix / Accept` → `Fix / closed`로 회귀 | 전이표 + 게이트 문구 |

**주의 — C5(cascade)는 단독으로 되돌리지 않는다.** C6가 살아 있는 한 C5는 유일하게 남은 실패 검출 장치다(§4.4-2). C6를 되돌린 뒤에야 C5도 되돌릴 수 있다.

6번은 상위 문서에 없는 항목이다. 4축 리뷰를 기본값에서 뺀 결정 자체를 되돌려야 하는 유일한 신호이므로 따로 세운다.
