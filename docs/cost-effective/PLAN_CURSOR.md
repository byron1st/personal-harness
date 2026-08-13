# Cursor 변형 구현 계획

> 작성일: 2026-08-03 · 상위 문서: [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md) · 선행: [PLAN_CLAUDE.md](PLAN_CLAUDE.md)(적용 완료, `e3da36c`~`78ff059`) · 범위: **`skills/cursor/` · `agents/cursor/` · `hooks/cursor/` 신설 + 설치·동기화 문서** · 성격: 구현 계약
>
> Cursor 사양은 **2026-08-03에 공식 문서로 직접 확인**했다(§1). 상위 문서 §8.3이 초판에서 추정으로 남긴 항목 중 **3개가 정정됐고 2개가 새로 발견**됐다 — 특히 effort의 표현 방식과 `subagentStart` 훅은 §8.3에 없던 사실이다.
>
> **2026-08-03 개정**: 초판의 검토·검증 항목 7건이 전부 확정됐다(이 문서 §8). 가장 큰 변화는 **설치 충돌(초판 §5, 최대 위험 항목)이 Cursor 옵션으로 해소**된 것이다 — 이에 따라 선행 실험 K0이 사라지고 프로젝트 스코프 설치라는 분기도 없어졌다. `Task` 툴과 `AskQuestion` 툴 이름이 확정되어 **텍스트 프로토콜 후퇴도 불필요**해졌고, `readonly`가 읽기 셸을 막지 않는 것이 확인되어 리뷰어 4종의 `readonly: true`가 안전해졌다.
>
> **2026-08-13 개정**: Grok 4.6 출시 후 현행 핀은 `AGENTS.md` Model Tier가 권위다. T1·implementer/fixer는 `grok-4.6`, T2 bulk(tester·maintainability·senior-generalist)는 Composer 유지. `plan-dev` 세션은 Grok 4.6 / **xhigh**. 이 문서 본문의 `grok-4.5[effort=…]` 예시는 초판 시점의 기록이다.
>
> **참조 표기**: `§N`은 상위 문서 [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md)의 절, `PLAN_CLAUDE §N`은 Claude 계획서의 절, 그 외 `§N`이 이 문서 자신을 가리킬 때는 "이 문서 §N"으로 적는다.

## 요약 (결론 먼저)

1. **포팅 자체는 기계적이다 — 본문은 그대로 가고 프론트매터만 접힌다.** 스킬 17개와 에이전트 9개의 산문은 플랫폼 무관이고, 손대야 하는 것은 프론트매터 변환과 본문의 툴 이름 몇 곳뿐이다. 초판이 최대 위험으로 꼽았던 설치 충돌(`~/.claude/` 교차 인식)은 **Cursor 옵션으로 호환 경로를 끌 수 있어 해소**됐다 — 다만 설치 스크립트가 보장할 수 없는 **1회성 수동 단계로 남으므로 Prerequisites에 명시한다**(§5).
2. **effort는 프론트매터 필드가 아니라 모델 문자열의 파라미터다.** Cursor 서브에이전트 프론트매터는 `name` · `description` · `model` · `readonly` · `is_background` **다섯 개가 전부**다. Claude의 `model:` + `effort:` 두 줄은 **`model: "grok-4.5[effort=high]"` 한 줄로 접힌다**(§1.1).
3. **같은 문법이 Cursor 최대의 비용 함정을 정확히 막아준다.** §8.4가 경고한 Composer Standard/Fast 문제(Fast가 IDE 기본값·6배 가격·T1인 Grok보다도 비쌈)를 **`composer-2.5[fast=false]`로 에이전트별로 못 박을 수 있다.** 상위 문서는 이 문법을 몰라 "설정에서 강제하라"고만 적었다 — **파일로 표현 가능하다는 것이 이번 조사의 가장 실용적인 소득**이다(§4).
4. **훅 포팅은 예상보다 작다.** Cursor에 Claude와 **같은 모양의 제네릭 `preToolUse` 훅**이 있다(`tool_name` · `tool_input.command` · `cwd`). 덕분에 5개 스크립트 중 **3개가 jq 경로까지 무수정**이고, 2개만 고치면 된다(§6 V3).
5. **Cursor에만 있는 훅으로 §8.3 제약 1을 실제로 막을 수 있다.** `subagentStart` 훅은 스폰 직전에 **해석된 `subagent_model`을 보고 거부할 수 있다.** 상위 문서가 *"조용히 폴백되면 사용량 대시보드에서 사후에나 드러난다"*며 추적을 포기한 문제(§10 추적 안 함 1번)를, **T1 에이전트에 한해 즉시 실패로 바꿀 수 있다**(§6 V3-c). Claude 변형에는 대응물이 없는 Cursor 고유 이점이며, **모델 ID 문자열을 실측 없이 확정한 이번 결정(§8 결정 5)의 안전망이기도 하다.**
6. **전역 지침을 놓을 파일이 Cursor에는 없다.** `~/.claude/CLAUDE.md`·`~/.codex/AGENTS.md`에 해당하는 사용자 전역 파일이 문서에 없고 User Rules는 UI 관리다. → **`sessionStart` 훅의 `additional_context`로 주입한다**(§3-c). `instructions/AGENTS.md`가 59행이라 비용도 무시할 만하다.
7. **Cursor는 예산 소진 순서상 가장 먼저, 가장 많이 쓰는 도구다.** §9.8이 승인 마찰 0인 Cursor $21을 1순위로 두었고 기본 스킬은 `dev-loop-noreview`($4.40/작업 → 13.9작업)다. **이 변형은 "나중에 여유 되면"이 아니라 실사용 1순위다.**

---

## §1. Cursor 에이전트 사양 — 조사 결과

전부 2026-08-03에 [cursor.com/docs](https://cursor.com/docs) 및 Context7 `/websites/cursor`로 직접 확인했다. **상위 문서 §8.3과 다른 부분은 표시했다.**

### 1.1 서브에이전트 (`.cursor/agents/*.md`)

| 필드 | 타입 | 기본값 | 설명 |
| --- | --- | --- | --- |
| `name` | string | 파일명 | 소문자·하이픈 |
| `description` | string | — | Task 툴 힌트에 노출 |
| `model` | string | `inherit` | `inherit` 또는 모델 ID |
| `readonly` | boolean | `false` | true면 **파일 편집 금지 + 상태 변경 셸 명령 금지** |
| `is_background` | boolean | `false` | true면 블로킹 없이 백그라운드 실행 |

**이게 전부다. `tools:`도 `effort:`도 없다.**

**모델 문자열의 파라미터 문법** — §8.3이 `[effort=high]`만 언급했으나 실제 범위가 더 넓다:

```
composer-2.5[]                        # 베이스 모델 고정
composer-2.5[fast=false]              # ★ Standard 변형 선택
claude-opus-5[effort=high]
claude-opus-5[context=300k]
claude-opus-5[effort=high,context=300k]
```

**탐색 경로** (프로젝트가 사용자 스코프보다 우선):

| 스코프 | 경로 |
| --- | --- |
| 프로젝트 | `.cursor/agents/` · **`.claude/agents/`** · **`.codex/agents/`** |
| 사용자 | `~/.cursor/agents/` · **`~/.claude/agents/`** · **`~/.codex/agents/`** |

**중첩**: *"메인 에이전트와 그 직속 서브에이전트는 자식을 낳을 수 있지만, 서브에이전트가 낳은 서브에이전트는 더 낳을 수 없다."* → **메인 아래 2계층.** 하네스는 main(Dispatcher) → Worker(L1) → `plan-consultant`(L2)이므로 **정확히 한도에 걸려서 들어간다** — 여유가 없다.

**툴 상속**: *"부모의 모든 툴을 상속한다(MCP 툴 포함)."* 제한 수단은 `readonly` 하나뿐.

**모델 폴백 조건 (§8.3 제약 1의 실체)**: 팀 관리자 제한 · 레거시 Max Mode 요구 · 플랜 제약 셋 중 하나면 *"Cursor가 호환 모델로 폴백한다."*

### 1.2 스킬 (`.cursor/skills/<name>/SKILL.md`)

| 필드 | 필수 | 설명 |
| --- | --- | --- |
| `name` | ✅ | 부모 폴더명과 일치 |
| `description` | ✅ | 무엇을·언제 |
| `paths` | | 글롭으로 스킬 활성 파일 제한 |
| `disable-model-invocation` | | true면 `/skill-name`으로만 |
| `metadata` | | 임의 key-value |

**`model` · `effort` · `allowed-tools` · `context: fork` 전부 없다.** Claude 스킬 프론트매터에서 이 넷이 사라진다.

`scripts/` · `references/` · `assets/` 하위 디렉터리를 지원하고 **스킬 루트 기준 상대 경로**로 참조한다. `${CLAUDE_SKILL_DIR}` 같은 치환 변수는 없다.

**탐색 경로**: 프로젝트 `.cursor/skills/` · `.agents/skills/` · **`.claude/skills/`** · `.codex/skills/`, 사용자 `~/.cursor/skills/` · `~/.agents/skills/` · **`~/.claude/skills/`** · `~/.codex/skills/`.

### 1.3 훅 (`.cursor/hooks.json` · `~/.cursor/hooks.json`)

**스키마가 Claude와 다르다** — 중첩 `hooks[].hooks[]`가 아니라 평평한 배열이다:

```json
{
  "version": 1,
  "hooks": {
    "preToolUse": [{ "command": "...", "matcher": "..." }],
    "sessionStart": [{ "command": "..." }]
  }
}
```

이번 계획에 쓰는 이벤트:

| 이벤트 | 입력 | 출력 | 하네스 용도 |
| --- | --- | --- | --- |
| `sessionStart` | `session_id` · `is_background_agent` · `composer_mode` (+공통) | `{"env":{…},"additional_context":"…"}` | 저장소 분류 주입 **+ 전역 지침 주입**(§3-c) |
| `preToolUse` | `tool_name` · `tool_input.command` · `cwd` · `model_params` | `{"permission":"allow\|deny\|ask","user_message","agent_message"}` | rg/fd 강제, git identity 가드 |
| `afterFileEdit` | `file_path` · `edits` | 없음 | auto-format |
| **`subagentStart`** | `subagent_type` · **`subagent_model`(해석된 값)** · `task` | `{"permission":"allow\|deny","user_message"}` | **모델 핀 폴백 감지**(§6 V3-c) |

**공통 입력 필드**: `conversation_id` · `generation_id` · `model` · `model_id` · `model_params` · `hook_event_name` · `cursor_version` · **`workspace_roots`(배열)** · `user_email` · `transcript_path`.

**차단 방법**: 종료 코드 `2` = 차단(= `permission: "deny"`와 동등). JSON으로 명시하는 편이 안전하다.

### 1.4 지침 파일

- **`AGENTS.md`를 네이티브로 읽는다.** 프로젝트 루트 + 하위 디렉터리 중첩 지원, 구체적인 쪽이 우선.
- `.cursor/rules/*.mdc` — `alwaysApply` · `description` · `globs` 프론트매터. **`.md` 확장자는 무시된다.**
- 적용 순서: Team Rules → Project Rules → User Rules.
- **사용자 전역 지침 파일이 없다.** User Rules는 Cursor 설정 UI에서 관리하며 문서화된 파일 경로가 없다. → §3-c.

### 1.5 §8.3에 대한 정정·추가

| # | §8.3의 서술 | 조사 결과 |
| --- | --- | --- |
| 1 | *"`[effort=high]` 파라미터 문법"* | ✅ 맞음. **추가**: `[fast=false]` · `[context=300k]` · 조합도 된다 |
| 2 | *"`tools:` 필드가 없다. `readonly` 불리언뿐"* | ✅ 맞음. **추가**: 문서 표현은 *"상태 변경 셸 명령도 막는다"*지만 **실제로 막히는 것은 파일시스템 write/edit뿐이고 `git diff`·`rg`는 통과한다**(§8 결정 6) |
| 3 | *"중첩 2계층"* | ✅ 맞음. **추가**: 하네스가 정확히 한도를 다 쓴다 |
| 4 | *"`.claude/agents/`도 읽는다"* | ✅ 맞음. **추가**: **`~/.claude/skills/`도 읽는다.** 단 `~/.cursor/`가 우선하고 호환 경로는 끌 수 있다(§5) |
| 5 | (없음) | **신규**: `subagentStart` 훅으로 해석된 모델을 보고 거부할 수 있다 → 제약 1의 실효적 대응책 |
| 6 | (없음) | **신규**: 사용자 전역 지침 파일이 없다 → `sessionStart` 주입으로 대체 |

---

## §2. 포팅 대상 — Claude 하네스의 현재 상태

`PLAN_CLAUDE.md`의 W1~W9가 전부 반영된 상태(`78ff059`)를 원본으로 삼는다.

**에이전트 9개** (`agents/claude/`): `planner`(opus/high) · `plan-consultant`(opus/high) · `security-reviewer`(opus/medium) · `reliability-reviewer`(opus/medium) · `implementer`(sonnet/high) · `tester`(sonnet/medium) · `fixer`(sonnet/medium) · `maintainability-reviewer`(sonnet/medium) · `senior-generalist-reviewer`(sonnet/medium). **`inherit`은 한 곳도 없다.**

**스킬 17개** (`skills/claude/`): `dev-loop` · `dev-loop-light` · `dev-loop-noreview` 3종을 포함.

**런타임 스크립트 2개** (`scripts/claude/`): `detect-commands.sh` · `resolve-scope.sh`. **내용을 확인한 결과 플랫폼 의존성이 없다** — Makefile·package.json·git만 읽는다. 주석 한 줄이 `CLAUDE.md`를 언급할 뿐이다.

**훅 5개** (`hooks/claude/hooks/`) + `settings.json`.

**리뷰어 4종의 `## Reporting contract`가 에이전트 본문에 있다**(커밋 `4e5aea5`). 본문은 그대로 포팅되므로 **이 구조가 Cursor에서도 그대로 이득이 된다** — 오히려 Cursor는 서브에이전트가 부모 툴을 전부 상속해 dispatch 프롬프트가 더 길어지기 쉬우므로 이득이 크다.

---

## §3. 표현 손실 3가지와 대응

Claude에서 표현되던 것 중 Cursor에 대응 필드가 없는 것들이다.

### (a) `tools:` → `readonly: true` — **수용**(§10-7 기결)

| Claude | Cursor | 잃는 것 |
| --- | --- | --- |
| `tools: Read, Grep, Glob, Bash` | `readonly: true` | 툴 화이트리스트. Cursor 에이전트는 **MCP 툴 포함 부모의 모든 툴을 상속**하고, `readonly`가 그중 쓰기 계열만 막는다 |
| `tools: …, Skill, Agent` | (필드 없음) | **명시적 허용이 불필요해진다** — 전부 상속되므로 `implementer`가 `plan-consultant`를 부르는 데 별도 선언이 필요 없다 |

**Claude에서 `implementer.md`의 `tools:`에 `Agent`를 추가해야 했던 문제(PLAN_CLAUDE B3)가 Cursor에서는 존재하지 않는다.** 대신 반대 방향의 위험이 생긴다 — 아무것도 안 쓰면 모든 에이전트가 모든 툴을 갖는다. 6개 읽기 전용 에이전트에 `readonly: true`를 **빠짐없이** 넣는 것이 이 변형의 유일한 권한 장치다.

각 read-only 에이전트 본문에 한 줄 주석을 남긴다: *"Cursor에서는 read-only가 `readonly` 불리언으로만 강제되며, 툴 화이트리스트는 존재하지 않는다."* (§8.3 제약 2의 결정 사항)

**`readonly: true`가 리뷰어의 조사 능력을 해치지 않는 것이 확인됐다**(§8 결정 6) — 막히는 것은 **파일시스템 write/edit뿐**이고 `git diff`·`rg` 같은 읽기 셸은 통과한다. 초판이 남겼던 "리뷰어가 diff를 못 볼 수 있다"는 리스크는 없다.

### (b) `effort:` → 모델 문자열 파라미터

`model:` 한 줄로 접힌다. **Composer는 effort를 받지 않고**(§10-6 사용자 확인) 대신 `fast`를 받으므로, T2 행에는 effort 대신 `[fast=false]`가 들어간다. §4의 배치표가 이 형태다.

### (c) 전역 지침 → `sessionStart` 훅의 `additional_context`

`instructions/AGENTS.md`(59행)를 놓을 사용자 전역 파일이 Cursor에 없다. 세 가지 선택지 중 3번을 택한다:

| 안 | 방법 | 판정 |
| --- | --- | --- |
| 1 | 사용자가 Cursor 설정 UI의 User Rules에 수동 붙여넣기 | ❌ 설치 스크립트가 보장할 수 없고 드리프트가 조용하다 |
| 2 | 프로젝트마다 `.cursor/rules/*.mdc` 생성 | ❌ 전역이 아니다. 하네스가 남의 저장소를 오염시킨다 |
| **3** | **`sessionStart` 훅이 `additional_context`로 주입** | ✅ 설치로 보장되고, 이미 있는 `session-context.sh`가 같은 필드를 쓴다 |

**구현**: `session-context.sh`가 지금 만드는 저장소 분류 컨텍스트 뒤에 `~/.cursor/AGENTS.md`(설치 스크립트가 여기 복사)의 내용을 이어 붙여 하나의 `additional_context`로 낸다. Cursor가 그 경로를 읽지는 않지만 **훅이 읽어서 넣어주므로 상관없다.**

**대가**: 매 세션 59행이 초기 시스템 컨텍스트에 들어간다 — `~/.claude/CLAUDE.md`가 하는 일과 같으므로 순증이 아니다.

---

## §4. 티어 배치 — Cursor 판

§4 배치표의 Cursor 열을 파일로 옮긴 것이다. **effort와 fast가 모델 문자열 안으로 들어간다.**

| 에이전트 | Claude (현행) | **Cursor `model:`** | `readonly` | 근거 |
| --- | --- | --- | --- | --- |
| `planner` | opus / high | `grok-4.5[effort=high]` | `true` | T1 — 아키텍처 판단 |
| `plan-consultant` | opus / high | `grok-4.5[effort=high]` | `true` | T1 — escalation hatch |
| `security-reviewer` | opus / medium | `grok-4.5[effort=high]` | `true` | T1 — miss 비용 최대 |
| `reliability-reviewer` | opus / medium | `grok-4.5[effort=high]` | `true` | T1 — 반사실 시뮬레이션 |
| `implementer` | sonnet / high | `grok-4.5[effort=medium]` | `false` | agentic 격차 83.3 vs 69.3이 정확히 이 일에 떨어진다(§8.4) |
| `tester` | sonnet / medium | `composer-2.5[fast=false]` | `false` | 기계 목표 + 프로덕션 코드 금지 |
| `fixer` | sonnet / medium | `composer-2.5[fast=false]` | `false` | finding이 곧 명세, 재테스트로 검증 |
| `maintainability-reviewer` | sonnet / medium | `composer-2.5[fast=false]` | `true` | 명세된 패턴 매칭 |
| `senior-generalist-reviewer` | sonnet / medium | `composer-2.5[fast=false]` | `true` | calibrated catch-all |

**리뷰어 effort가 Claude보다 높은 이유**(medium → high): Grok 4.5는 `low/medium/high` 3단뿐이고 **기본값이 high**다. Claude에서 `medium`을 고른 §4 원칙 2(*"최상단 effort는 사지 마라"*)는 `xhigh`·`max`가 있는 스케일을 전제한 것이라 Grok에는 적용되지 않는다. §4 표도 Cursor 열에 `high`를 적어 두었다.

**`[fast=false]`가 이 표에서 가장 중요한 토큰이다.** §8.4·§9.3의 경고 — Fast는 Cursor IDE 기본값이고, 지능은 같은데 약 6배 비싸며, **T1인 Grok($2/$6)보다도 비싸(Composer Fast $3/$15) 티어가 역전된다.** first-party 풀로 계량되는 지금은 **희소 자원을 3.6배 빨리 태운다**는 뜻이다. 상위 문서는 "Cursor 설정에서 Standard를 강제하라"는 운용 지시로만 남겼지만, **파일에 박을 수 있다는 것이 이번 조사의 소득**이다.

**세션 모델** (파일이 아니라 습관 — PLAN_CLAUDE W4와 같은 구조):

| 세션 | 모델 픽커 |
| --- | --- |
| `plan-dev` | **Grok 4.5** (effort high) |
| 모든 `dev-loop*` 실행 | **Composer 2.5 Standard** |

**`is_background`는 전부 기본값 `false`로 둔다.** Dispatcher/Worker 패턴은 Worker의 반환을 기다려야 성립한다. 명시하지 않으면 기본이 `false`라 별도 선언은 불필요하지만, `tester`·`implementer`처럼 오래 도는 에이전트에 누군가 나중에 `true`를 붙이지 않도록 **본문에 한 줄로 이유를 남긴다.**

---

## §5. 설치 충돌 — 해결됨, 단 수동 단계가 남는다

Cursor는 `~/.cursor/`뿐 아니라 **`~/.claude/agents/`·`~/.claude/skills/`를 호환 경로로 읽는다**(§1.1·§1.2). 두 플랫폼을 같은 머신에서 쓰므로 설치 직후 Cursor에게는 같은 이름의 에이전트 9개·스킬 17개가 두 벌씩 보이고, **같은 사용자 스코프 안에서의 우선순위는 문서화돼 있지 않다.**

**2026-08-03 확인: `~/.cursor/`가 이기고, `~/.claude/` 호환 읽기는 Cursor 옵션에서 끌 수 있다**(§8 결정 4). 초판이 준비했던 15분 선행 실험(K0)과 프로젝트 스코프 설치 분기는 **모두 불필요해졌다.**

**그래도 이 절을 남기는 이유 두 가지.**

1. **호환 경로 끄기는 설치 스크립트가 보장할 수 없는 UI 설정이다.** 새 머신·재설치·설정 초기화 때 되살아나고, 되살아나도 **에러가 나지 않는다.** → `README.md` Prerequisites에 1회성 설정 단계로 명시한다(V7).
2. **되살아났을 때의 피해가 조용하고 크다.** Cursor가 `~/.claude/agents/security-reviewer.md`를 채택하면 `tools:`는 Cursor 필드가 아니라 무시되어 **리뷰어가 쓰기 권한을 얻고**, `effort:`도 무시되며, `model: sonnet`은 Cursor가 해석하는지 불명이다. 셋 다 에러 없이 일어난다.

**따라서 감지 장치를 둔다.** V3-c의 `model-pin-guard.sh`가 `subagent_model`을 보므로, Claude 판이 채택되면 **T1 에이전트에서 즉시 걸린다**(해석된 모델이 `grok-4.5[…]`가 아니게 된다). 옵션이 꺼져 있는 한 발화하지 않고, 되살아나면 첫 라운드에서 잡힌다.

## §6. 작업 단위

Claude 계획과 같은 방식으로 **한 번에 적용하되 커밋은 항목별로** 나눈다.

| 커밋 | 항목 | 내용 |
| --- | --- | --- |
| K1 | V1 | `agents/cursor/*.md` 9개 |
| K2 | V2 | `skills/cursor/` 17개 |
| K3 | V3 | `hooks/cursor/hooks.json` + 스크립트 6개(신규 1 포함) |
| K4 | V4 | 런타임 스크립트 설치 대상 확장 |
| K5 | V5 | `scripts/apply-to-cursor.sh` + `apply-to-all.sh` |
| K6 | V6 | `docs/sync-harness/SYNC_TO_CURSOR.md` |
| K7 | V7 | `AGENTS.md` · `README.md` 갱신 |

### V1 — `agents/cursor/*.md` 9개 · **K1**

**본문은 Claude 판을 그대로 옮긴다.** 리뷰어 4종의 `## Reporting contract`, `implementer`의 3-bucket + 4번째 밴드, `tester`의 Global Rule 6 요지 — 전부 플랫폼 무관한 산문이다.

**프론트매터만 변환한다**(§4 표):

```yaml
---
name: security-reviewer
description: "…(Claude 판 그대로)"
model: grok-4.5[effort=high]
readonly: true
---
```

**본문에서 손봐야 할 것 3가지**:

1. **Claude 툴 이름 언급** — `Read` / `Grep` / `Glob` / `Bash` / `Edit` / `Write`가 본문에 나오면 Cursor 어휘로 바꾸거나 툴 중립 표현으로("파일을 읽고", "셸에서"). `SYNC_TO_CODEX.md`의 *"Replace Claude-specific tool names"* 규칙과 같은 처리다.
2. **read-only 약화 주석** — §3-a의 한 줄.
3. **`Tier:` 근거 줄** — Claude 판에 있는 형식을 유지하되 모델명이 아니라 근거를 남긴다(§5의 원래 취지).

**`implementer.md`에서는 `tools:`의 `Agent` 추가가 불필요해진다**(§3-a). 대신 **중첩 한도를 정확히 다 쓴다는 사실**을 본문에 한 줄 남긴다 — 나중에 `plan-consultant` 아래로 뭔가를 더 붙이려는 시도를 막기 위해서다.

### V2 — `skills/cursor/` 17개 · **K2**

**프론트매터**: `name` + `description`만 남는다. Claude 스킬에 `model`·`effort`·`allowed-tools`·`context`가 없었으므로(PLAN_CLAUDE §1.2) **실제 삭제 대상은 없다.** `allowed-tools`는 `PLAN_CLAUDE` W8에서 런타임 스크립트용으로 추가됐으므로 그 한 줄만 사라진다 → Cursor에는 스킬 단위 권한 프리어프루브가 없다(§8 결정 2).

**본문에서 손봐야 할 것 5가지**:

| # | Claude | Cursor | 비고 |
| --- | --- | --- | --- |
| 1 | `Agent(subagent_type: implementer, prompt: …)` | **`Task(subagent_type: …, prompt: …)`** | 확정(§8 결정 7). 인자 이름이 같으므로 **툴 이름만 치환**하면 된다 |
| 2 | `AskUserQuestion`으로 Fix/Accept 분류 | **`AskQuestion`** | 확정(§8 결정 7). **텍스트 프로토콜 후퇴가 불필요**해져 두 휴먼 게이트가 Claude와 같은 강제력을 유지한다 |
| 3 | `${CLAUDE_SKILL_DIR}` | 없음 | 스킬 루트 기준 **상대 경로**. 현재 하네스는 이 변수를 `allowed-tools`에만 썼으므로 영향 적음 |
| 4 | `$HOME/.claude/scripts/…` | `$HOME/.cursor/scripts/…` | V4 |
| 5 | `agents/claude/*-reviewer.md` 참조 (review-code SKILL.md 53·120·130행) | `agents/cursor/…` | 경로 문자열 |

**세 루프 변형의 상태 기계는 손대지 않는다.** 전이표·종료 술어·휴먼 게이트는 플랫폼 무관이다. 단 **`dev-loop-light`의 2축 dispatch와 `review-code`의 축 부분집합 규칙**은 Cursor에서도 그대로 필요하다.

**`disable-model-invocation`을 쓸 것인가**: Claude 판은 안 쓴다. Cursor에서도 기본은 안 쓰되, **`commit-code`·`request-merge`처럼 부작용이 있는 스킬**은 검토할 만하다 — 다만 이건 Claude 판과의 차이를 만드는 일이라 **이번 범위에서 제외**하고 §7에 남긴다.

### V3 — `hooks/cursor/` · **K3**

#### (a) `hooks.json` — 새 스키마로 재작성

```json
{
  "version": 1,
  "hooks": {
    "sessionStart":  [{ "command": "$HOME/.cursor/hooks/session-context.sh" }],
    "preToolUse":    [{ "command": "$HOME/.cursor/hooks/git-identity-guard.sh" },
                      { "command": "$HOME/.cursor/hooks/enforce-rg.sh" },
                      { "command": "$HOME/.cursor/hooks/enforce-fd.sh" }],
    "afterFileEdit": [{ "command": "$HOME/.cursor/hooks/auto-format.sh" }],
    "subagentStart": [{ "command": "$HOME/.cursor/hooks/model-pin-guard.sh" }]
  }
}
```

> **`hooks/codex/hooks.json`을 본뜨지 말 것.** 그 파일은 Claude의 중첩 스키마(`hooks[].hooks[].type`)를 경로만 바꿔 복사한 형태인데, **Cursor의 스키마는 평평한 `[{command, matcher}]`다**(§1.3). Codex 판의 정확성은 이 계획의 범위가 아니지만, 참고 대상으로 삼으면 안 된다.

**`matcher`를 쓰지 않고 스크립트 안에서 `tool_name`을 검사한다.** `preToolUse`의 matcher가 `tool_name`을 대상으로 하는지 명령 문자열을 대상으로 하는지 문서가 모호하다(플러그인 예시는 `"matcher": "rm|curl|wget"`로 **명령**을 매칭한다). 세 스크립트 앞에 한 줄을 넣으면 이 불확실성이 사라진다:

```bash
[ "$(echo "$input" | jq -r '.tool_name // ""')" = "Shell" ] || exit 0
```

#### (b) 기존 스크립트 5개 — 3개는 무수정

| 스크립트 | 이벤트 | 변경 |
| --- | --- | --- |
| `enforce-rg.sh` | `preToolUse` | **`tool_name` 가드 한 줄만.** `.tool_input.command`·`exit 2` 그대로 |
| `enforce-fd.sh` | `preToolUse` | 동일 |
| `git-identity-guard.sh` | `preToolUse` | 동일. `.cwd`도 `preToolUse` 입력에 있다 |
| `session-context.sh` | `sessionStart` | **2곳**: `.cwd` → `.workspace_roots[0]`(sessionStart에는 `cwd`가 없다), 출력 `{hookSpecificOutput:{…additionalContext}}` → **`{additional_context: …}`**. 여기에 §3-c의 전역 지침 이어 붙이기 |
| `auto-format.sh` | `afterFileEdit` | **1곳**: `.cwd` → `.workspace_roots[0]`. `afterFileEdit`은 출력 계약이 없으므로 `exit 2`의 의미가 Claude와 다르다 → **실패를 조용히 넘기고 로그만 남기는 형태로 바꾼다** |

**차단 방식**: 종료 코드 2가 Cursor에서도 차단이다. 다만 **stderr가 에이전트에게 전달되는지가 문서에 없으므로**, 세 차단 훅은 `exit 2` 대신 `{"permission":"deny","agent_message":"…"}`를 stdout으로 내는 형태로 바꾸는 것이 안전하다. 기존 heredoc 메시지를 `agent_message`에 담으면 된다.

#### (c) **`model-pin-guard.sh` (신규)** — §8.3 제약 1의 실효적 대응

`subagentStart`는 스폰 직전에 **해석된 `subagent_model`**과 `subagent_type`을 준다. 즉 **핀이 먹혔는지를 실행 시점에 알 수 있다.**

```
기대 모델 표(§4) 조회
  ├─ subagent_type이 T1(planner·plan-consultant·security-reviewer·reliability-reviewer)
  │    └─ subagent_model이 기대와 다르면 → {"permission":"deny", "user_message":"…"}
  └─ 그 외(T2)
       └─ 다르면 → 로그 파일에 한 줄, permission allow
```

**T1만 거부하고 T2는 허용+기록하는 이유**: `subagentStart`의 출력은 `allow`/`deny` 둘뿐이라 "경고"가 없다. 전부 거부하면 폴백 한 번에 루프가 멈춰 브레이크가 너무 세다. **되돌릴 수 없는 miss가 발생하는 축(§4가 T1에 둔 이유)에만 하드 스톱을 걸고**, 나머지는 사후 관찰로 둔다.

**이 훅이 감지기 두 개를 겸한다.**

1. **모델 ID 문자열의 오류**(§8 결정 5) — §4 표의 ID는 실측 없이 확정했다. 틀리면 Cursor가 호환 모델로 폴백하므로 `subagent_model`이 기대값과 달라지고 **첫 라운드에서 걸린다.** 실측을 생략한 결정이 안전한 이유가 이것이다.
2. **§5 호환 경로의 부활** — Claude 판이 채택되면 해석된 모델이 `grok-4.5[…]`가 아니게 되므로 역시 T1에서 걸린다.

즉 이 훅은 "핀이 먹었는가"라는 하나의 질문으로 **폴백·오타·설치 충돌 셋을 동시에** 감시한다.

**주의**: 이 훅은 **하네스가 처음으로 갖는 "차단하는 정책 훅"**이다. `AGENTS.md`가 *"Hooks are guardrails; they take no part in `dev-loop` stage transitions or completion decisions"*라고 못 박아 두었는데, 이 훅은 **단계 전이를 결정하지 않고 잘못된 모델로의 실행을 거부할 뿐**이므로 그 불변식과 충돌하지 않는다. 다만 경계에 가까우므로 `AGENTS.md`의 훅 절에 한 줄로 성격을 밝힌다(V7).

### V4 — 런타임 스크립트 · **K4**

`scripts/claude/detect-commands.sh`·`resolve-scope.sh`는 **플랫폼 의존성이 없다**(§2 확인). 두 안:

**`scripts/claude/` → `scripts/runtime/`으로 이름을 바꾼다**(§8 결정 1 확정). 설치 스크립트 둘이 같은 소스를 각각 `~/.claude/scripts/`·`~/.cursor/scripts/`로 복사한다. 중복본을 만들지 않으므로 드리프트가 원천 차단된다.

**딸려 오는 변경 3가지 — 이 계획에서 Claude 쪽을 건드리는 유일한 항목이다:**

1. `scripts/apply-to-personal.sh`의 `SCRIPTS_SOURCE_DIR` 경로.
2. `AGENTS.md` §Runtime Scripts의 서술(*"`scripts/claude/*.sh`는 `apply-to-personal.sh`가 `~/.claude/scripts/`에 설치"*) — 어차피 Cursor 추가로 고쳐야 했다.
3. **소비 스킬 본문의 호출 경로.** `$HOME/.claude/scripts/…`는 설치 **대상** 경로라 그대로다 — 바뀌는 것은 저장소 안의 소스 경로뿐이므로 **스킬 본문은 무변경**이다. `AGENTS.md`가 소스 경로를 언급하는 곳만 고치면 된다.

### V5 — `scripts/apply-to-cursor.sh` · **K5**

`apply-to-personal.sh`를 본뜨되 대상이 다르다:

| 소스 | 대상 |
| --- | --- |
| `skills/cursor/*` | `~/.cursor/skills/` |
| `agents/cursor/*` | `~/.cursor/agents/` |
| `hooks/cursor/hooks/*` | `~/.cursor/hooks/` (**`cp -rp`로 실행 권한 보존**) |
| `hooks/cursor/hooks.json` | `~/.cursor/hooks.json` (**병합이 아니라 교체** — Claude의 `settings.json`은 다른 설정과 공유하지만 Cursor의 `hooks.json`은 훅 전용이다) |
| `scripts/runtime/*` (V4) | `~/.cursor/scripts/` |
| `instructions/AGENTS.md` | `~/.cursor/AGENTS.md` (**Cursor가 읽지 않는다** — `session-context.sh`가 읽어서 주입한다, §3-c) |

`apply-to-all.sh`에 한 줄 추가. **전역 설치로 확정**이므로(§8 결정 4) 저장소를 인자로 받는 형태는 필요 없다.

### V6 — `docs/sync-harness/SYNC_TO_CURSOR.md` · **K6**

`SYNC_TO_CODEX.md`(156행)의 구조를 따른다: Platform invariants → Skill migration → Sub-agent migration → Hook migration. Cursor 고유 규칙으로 최소 다음이 들어간다:

- 프론트매터 5필드 매핑표와 **`model` + `effort` → 단일 문자열 접기** 규칙
- **`[fast=false]`를 T2 전 행에 강제**하는 규칙 (빠뜨리면 조용히 6배)
- `tools:` → `readonly:` 축약과 **정보 손실을 주석으로 남기라**는 요구(§10-7)
- `hooks.json` 스키마 재작성 (Codex 판을 본뜨지 말라는 경고 포함)
- `Agent(…)` → `Task(…)`, `AskUserQuestion` → `AskQuestion` (인자 이름은 동일)
- **`~/.claude/` 호환 경로를 끄는 것이 설치 전제**라는 경고(§5)

### V7 — 문서 · **K7**

| 파일 | 변경 |
| --- | --- |
| `AGENTS.md:3` · `:5` | *"두 플랫폼 — Claude Code와 Codex"* → **3개**. 토폴로지에 Cursor 추가 |
| `AGENTS.md:13` 폴더 구조 | `skills/`·`agents/`·`hooks/`의 `claude/ · codex/` → `+ cursor/`. `scripts/` 설명(V4-A면 `runtime/`) |
| `AGENTS.md` §Model Tier | 티어 정의표에 **Cursor 열** 추가, 에이전트 배치표에 Cursor `model` 문자열, 세션 운용 규칙에 Cursor 행 |
| `AGENTS.md` §Hooks | `model-pin-guard.sh` 행 추가 + 가드레일 불변식과의 관계 한 줄(V3-c) |
| `AGENTS.md` §Operating switch | Cursor에는 대응 스위치가 없고 **의도치 않은 폴백**이 그 자리를 대신한다는 서술(§8.3 제약 1 → V3-c로 대응) |
| `README.md` | 같은 항목 + Prerequisites에 Cursor 버전 요구사항, 그리고 **`~/.claude/` 호환 경로 끄기를 1회성 필수 설정으로 명시**(§5) |

---

## §7. 하지 않는 것

| 항목 | 판단 |
| --- | --- |
| **`.cursor/rules/*.mdc` 생성** | 하지 않는다. 전역이 아니고 남의 저장소를 오염시킨다(§3-c 2안) |
| **`disable-model-invocation` 도입** | 이번 범위 밖. Claude 판과 차이를 만드는 결정이라 별도로 다룬다 |
| **`paths` 프론트매터로 스킬 스코핑** | 하지 않는다. Claude 판에 대응물이 없어 두 변형이 갈라진다 |
| **Cursor CLI(`cursor-agent`) 대응** | 범위 밖. 이 계획은 IDE Agent 채팅을 전제한다 |
| **`context=300k` 파라미터 활용** | 하지 않는다. Grok의 200K 임계를 넘기면 **요청 전체가 2배**가 되므로(§8.4), 컨텍스트를 키우는 파라미터는 정확히 반대 방향이다 |
| **`is_background: true`** | 하지 않는다. Dispatcher/Worker가 반환을 기다려야 한다(§4) |
| **Codex 변형 갱신** | 범위 밖. `hooks/codex/hooks.json`이 Claude 스키마를 그대로 쓰는 문제를 발견했으나(V3-a 주석) 별건이다 |

---

## §8. 결정 기록

**열린 질문은 남기지 않는다.** 초판이 남긴 검토 3건·선행 검증 4건이 2026-08-03에 전부 확정됐다.

| # | 항목 | 결정 | 이 계획에 미친 영향 |
| --- | --- | --- | --- |
| 1 | 런타임 스크립트 위치 | ✅ **(A) `scripts/claude/` → `scripts/runtime/` 개명** | K4. Claude 쪽을 건드리는 유일한 항목이지만 **스킬 본문은 무변경**이다 — 바뀌는 것은 저장소 안 소스 경로뿐이고 설치 대상 경로(`$HOME/.claude/scripts/…`)는 그대로다(V4) |
| 2 | 스킬 권한 프리어프루브 상실 | ✅ **수용.** 프롬프트를 감수한다 | Cursor 스킬에 `allowed-tools`가 없다. 런타임 스크립트 호출 시 권한 프롬프트가 뜰 수 있으나 **무해한 실패 모드**다 |
| 3 | `dev-loop-light`을 Cursor에도 | ✅ **만든다. 필요에 따라 쓴다** | 루프 3종 전부 포팅. `review-code`의 축 부분집합 규칙도 함께 간다(V2). Claude와 동일한 구성이 되어 SYNC 규칙이 단순해진다 |
| 4 | `~/.cursor/` vs `~/.claude/` 우선순위 | ✅ **`~/.cursor/`가 이긴다. 게다가 호환 경로를 옵션에서 끌 수 있다** | **초판의 최대 위험 항목이 소멸.** 선행 실험 K0 삭제, 프로젝트 스코프 분기 삭제. 다만 옵션 끄기가 **1회성 수동 단계**로 남아 Prerequisites에 명시(§5, V7) |
| 5 | Grok 4.5의 모델 ID 문자열 | ✅ **실측 없이 §4 표대로 확정** | §4의 `grok-4.5[effort=…]`가 계획의 기준이 된다. **틀리면 폴백이 일어나고 `model-pin-guard.sh`가 첫 라운드에서 잡는다**(V3-c) — 실측을 생략해도 되는 이유가 이 훅이다 |
| 6 | `readonly`가 읽기 셸을 막는가 | ✅ **막지 않는다. 파일시스템 write/edit만 금지** | 리뷰어 4종·`planner`·`plan-consultant`의 `readonly: true`가 안전하다. `git diff`·`rg` 정상. **초판의 후퇴안(`readonly: false` + 산문 제약)은 불필요** |
| 7 | 서브에이전트 dispatch 툴 · 질문 툴 이름 | ✅ **`Task(subagent_type: …, prompt: …)` · `AskQuestion`** | **텍스트 프로토콜 후퇴가 불필요**해졌다. 인자 이름이 Claude와 같아 **툴 이름 치환만으로 끝난다**(V2) |

**5번의 성격을 한 줄로**: 이건 "확인하지 않기로 한" 결정이지 "확인했다"는 결정이 아니다. 문서에 표시명(Grok 4.5)만 있고 ID 문자열이 없어서, **틀렸을 때 조용히 지나가지 않는 장치가 있다는 조건에서만** 생략이 정당하다. 그 장치가 `model-pin-guard.sh`이므로 **K3는 K1과 함께 가야 하고, 이 훅을 빼는 순간 5번 결정의 근거가 사라진다.**

---

## §9. 검증과 롤백

**적용 후 첫 실행에서 확인할 것 4가지** — 전부 첫 `dev-loop-noreview` 1회로 관찰된다:

1. **`model-pin-guard.sh`가 한 번도 안 걸린다** = 핀이 먹었다. 걸리면 **로그의 `subagent_model` 값이 원인을 알려준다** — `sonnet` 계열이면 §5의 호환 경로 부활, 다른 Cursor 모델이면 §4 표의 **모델 ID 오류(§8 결정 5)** 또는 관리자·플랜 폴백이다.
2. **`cursor.com/dashboard/usage`의 first-party 풀 소모 속도.** `[fast=false]`가 먹었는지는 여기서 드러난다 — 안 먹으면 **3.6배 빨리 탄다**(§9.3). §9.5가 *"측정 한 번이 3행 추정을 1행으로 줄인다"*고 한 그 측정이다.
3. **훅 6개가 전부 발화하는가.** 특히 `session-context.sh`의 저장소 분류와 전역 지침이 대화 첫머리에 나타나는지 — 안 나오면 `workspace_roots` 변환이 틀렸다.
4. **`Task`·`AskQuestion` 호출이 실제로 성립하는가.** 두 휴먼 게이트(TESTING Fix/Accept, review triage)가 Cursor에서 질문 UI로 뜨는지 — 안 뜨면 `SYNC_TO_CODEX.md`의 텍스트 프로토콜 선례로 후퇴한다.

**롤백**:

| 신호 | 되돌릴 커밋 | 비고 |
| --- | --- | --- |
| T1 에이전트가 반복적으로 거부돼 루프가 진행되지 않는다 | **K3의 `model-pin-guard.sh`만** — T1 거부를 로그로 강등 | 가드를 끄는 것이지 티어를 포기하는 게 아니다 |
| 스킬·에이전트가 Claude 판과 섞여 동작이 불안정하다 | **되돌릴 커밋 없음** — Cursor 옵션에서 `~/.claude/` 호환 경로를 끈다(§5) | 파일이 아니라 설정 문제다 |
| `Task`·`AskQuestion`이 기대대로 동작하지 않는다 | **K2의 해당 호출부** → 텍스트 프로토콜 | 게이트의 강제력이 약해지지만 흐름은 유지된다 |
| Composer가 코드 품질에서 명백히 부족하다 | **K1의 T2 4행** → `grok-4.5[effort=medium]` | 비용은 오르지만 §9.4의 Cursor 열이 무너지는 것보다 낫다 |

**주 지표는 Claude와 동일하다 — 플랜당 remediation 라운드 수**(`docs/agents/dev/*_LOOP_*.md`). Claude 변형 적용 후의 기록이 곧 비교 기준선이므로, **Cursor에서 같은 플랜을 한 번 돌려 보는 것이 가장 값싼 검증**이다.
