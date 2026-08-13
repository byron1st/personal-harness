# Grok Build 변형 구현 계획

> 작성일: 2026-08-03 · 상위 문서: [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md) · 선행: [PLAN_CLAUDE.md](PLAN_CLAUDE.md) · [PLAN_CURSOR.md](PLAN_CURSOR.md) · [PLAN_CODEX.md](PLAN_CODEX.md)(적용 완료) · 범위: **`skills/grok/` · `agents/grok/` · `hooks/grok/` 신설 + `scripts/apply-to-grok.sh` + 동기화·문서** · 성격: 구현 계약
>
> 상위 문서 §8·§9는 **Grok Build CLI를 독립 플랫폼으로 다루지 않았다.** Grok 4.5 숫자·effort 3단·Cursor 열 배치는 있지만, 그것은 Cursor 안의 Grok 슬롯이다. 이 문서는 **Grok Build TUI/CLI 자체**(버전 **0.2.118**, 2026-08-03 로컬 확인)를 대상으로 한 그린필드 변형 계획이다.
>
> **의도적 비호환.** Grok Build는 Claude/Cursor/Codex 경로를 `[compat.*]`로 읽을 수 있다. 사용자는 **그 옵션을 쓰지 않는다.** Claude 설정을 그대로 가져오지 않고 **Grok 전용 변형만** 설치한다. 설치 스크립트와 Prerequisites에 `compat.claude` / `compat.cursor` 끄기를 명시한다.
>
> **2026-08-03 개정**: 초판 §8 미결 8건을 사용자 답변으로 전부 닫았다(이 문서 §8·§9). 과금은 **SuperGrok 구독 쿼터**, agent `effort` frontmatter **적용 확인**, `permission_mode: plan`은 읽기 셸 허용, cascade/`implementer-strict` **없음**, 전역 지침 파일명 **`AGENTS.md`**, sync는 **Claude → Grok 단방향**, 모델은 **`grok-4.5` 단일**. `PreToolUse` spawn payload에 model·타입이 있어 선택 가드는 가능하나 **기본 범위에는 넣지 않는다**.
>
> **2026-08-13 개정**: Grok 4.6 출시 후 현행 핀은 `AGENTS.md` Model Tier가 권위다. 카탈로그는 `grok-4.6`(기본) + `grok-4.5`. T1·implementer/fixer/tester는 4.6, T2 리뷰어는 4.5. `plan-dev` 세션은 4.6 / **xhigh**. 이 문서 본문의 “단일 모델·effort 3단”은 초판 시점의 기록이다.
>
> **참조 표기**: `§N`은 상위 문서 [ANALYSIS_AND_PROPOSAL.md](ANALYSIS_AND_PROPOSAL.md)의 절, `PLAN_CLAUDE` · `PLAN_CURSOR` · `PLAN_CODEX`는 각 계획서, 그 외 `§N`이 이 문서 자신을 가리킬 때는 "이 문서 §N"으로 적는다.

## 요약 (결론 먼저)

1. **카탈로그에 모델이 하나뿐이다.** 이 환경의 `grok models` / `models_cache.json` 결과는 **`grok-4.5` 단일**이다(500K ctx, `supports_reasoning_effort: true`, effort 메뉴 **`low` · `medium` · `high`**, 기본 **`high`**). Claude의 opus/sonnet·Codex의 Sol/Terra/Luna·Cursor의 Grok+Composer 이원 구조가 없다. **T1/T2는 모델 교체가 아니라 effort(와 세션 습관)로만 나뉜다.**
2. **effort 표현 경로는 세 겹이다.** (a) 에이전트 frontmatter `model` + `effort`, (b) 스킬 frontmatter `model` + `effort`, (c) 역할/페르소나 TOML의 `reasoning_effort`. spawn 호출의 `model` 인자는 부모를 이길 수 있으나, **effort 인자는 spawn 스키마에 없다** — effort 핀은 파일 쪽에 둔다. CLI/세션의 `/effort`·`--reasoning-effort`는 컨트롤러 세션용.
3. **가장 큰 구조 제약: 서브에이전트 중첩 깊이 = 1.** 문서 원문: *"Only the top-level session spawns subagents. A subagent cannot spawn its own subagents."* Cursor는 메인+직속 1단까지 허용해 `implementer → plan-consultant`가 들어갔지만, **Grok에서는 L1 Worker가 L2를 낳을 수 없다.** design-bearing 자문은 **Dispatcher(메인)가 직접 `plan-consultant`를 spawn**하는 흐름으로 바꿔야 한다(이 문서 §3).
4. **read-only는 세 장치로 겹친다.** `permission_mode: plan`(또는 에이전트 본문의 읽기 전용 규칙) · spawn 시 `capability_mode: "read-only"` · 선택적 `tools`/`disallowedTools` 화이트리스트. Cursor의 `readonly: true` 한 줄보다 표현력이 크다 — **리뷰어·planner·consultant에 `capability_mode`/`permission_mode`를 빠짐없이 핀한다.**
5. **훅 스키마는 Claude 쪽(중첩)과 가깝고, 페이로드는 camelCase다.** `SessionStart` stdout은 **무시**(주입 불가). `SubagentStart`는 **비차단**이라 Cursor `model-pin-guard` 패턴을 그대로 쓸 수 없다. 핀 권위는 agent frontmatter; `PreToolUse` on `spawn_subagent`로 가드할 **여지는 있으나 1차 범위 밖**.
6. **기본 루프는 `dev-loop-noreview`.** SuperGrok **구독 쿼터**에서도 라운드·effort·200K 경계가 쿼터를 태운다. Codex처럼 light가 거의 공짜가 아니다. Claude/Cursor와 같다. `dev-loop-light`·`dev-loop`는 병존.
7. **compat 끄기가 변형의 전제다.** 지금 `grok inspect`는 `~/.claude/agents/*`·훅·MCP를 이미 읽고 있다. pure 변형을 깔아도 compat가 켜져 있으면 Claude 판이 섞인다 → **`[compat.claude]` · `[compat.cursor]` 전부 `false`** (또는 env)를 Prerequisites + 설치 안내로 고정.
8. **에이전트 `effort` frontmatter는 서브에이전트에 적용된다**(사용자 확인). T1/T2 분리는 파일 한 줄로 충분하고 role TOML 이중 핀은 필요 없다.

---

## §1. Grok Build 사양 — 조사 결과 (2026-08-03)

전부 로컬 설치 **0.2.118**, `~/.grok/docs/user-guide/*`, `grok models`, `grok inspect --json`, `models_cache.json`, 바이너리 문자열에서 확인했다.

### 1.1 모델 카탈로그 (실측)

| 항목 | 값 |
| --- | --- |
| 사용 가능 모델 | **`grok-4.5`만** (`grok models` 출력 1줄) |
| 표시명 | Grok 4.5 — "SpaceXAI's new frontier model" |
| 컨텍스트 | **500_000** |
| API backend | `responses` (cli-chat-proxy) |
| auth (이 머신) | `session` (grok.com 로그인) |
| reasoning | `supports_reasoning_effort: true` |
| effort 메뉴 | **`high`(default)** · `medium` · `low` |
| CLI 일반 스케일 | `none` · `minimal` · `low` · `medium` · `high` · `xhigh` · `max` — **하지만 grok-4.5 메뉴는 3단뿐**. `xhigh`/`max`를 넣어도 모델이 받지 않으면 무효·경고 쪽으로 떨어져야 하며, 하네스는 **메뉴에 있는 값만 쓴다.** |

**과금 (사용자 확정): SuperGrok subscription 구독 쿼터.** API 정가($/1M)로 작업 수를 세는 §9 표는 Grok Build 풀에 직접 적용하지 않는다. 참고용 API 단가(상위 문서 §8.4 Cursor/Grok 열)는 상대 비용 감각용으로만 둔다:

| | 입력 | cached | 출력 | 비고 |
| --- | --- | --- | --- | --- |
| ≤200K 프롬프트 | $2.00/1M | $0.30~0.50/1M | $6.00/1M | 캐시 할인 약 4×(셋 중 가장 약함, §6d) |
| **>200K 프롬프트** | **$4 / $1 / $12** | | | **초과분만이 아니라 요청 전체 2배**(§8.4) |

구독 쿼터에서도 **effort·라운드 수·200K 경계·Worker 컨텍스트 크기**가 쿼터·지연·품질에 직접 영향을 준다. 배치(§4)의 동기는 달러 절감이 아니라 **쿼터 효율 + 품질 보존**이다.

### 1.2 서브에이전트

| 항목 | 사실 |
| --- | --- |
| 스폰 툴 | `spawn_subagent` (Claude `Agent` / Cursor `Task` 대응). 훅 matcher 별칭 `Task` → `spawn_subagent` |
| 빌트인 타입 | `general-purpose` · `explore` · `plan` |
| 커스텀 | `~/.grok/agents/*.md` · `.grok/agents/*.md` — **이름 = `subagent_type`** |
| **중첩** | **깊이 1.** 서브에이전트가 `spawn_subagent` 호출 → depth-limit 에러 |
| capability_mode | `read-only` · `read-write` · `execute` · `all` (spawn 인자) |
| isolation | `none` (기본) · `worktree` |
| 모델 해석 | spawn `model` → role/`[subagents.models]` → agent 정의 `model` → 부모. **`model: inherit`은 부모** |
| effort 해석 | persona/role의 `reasoning_effort` · agent `effort` · 부모 세션. **spawn 파라미터로 effort 없음**(현재 툴 스키마) |
| 비활성 | `GROK_SUBAGENTS=0` 또는 `[subagents] enabled = false` |

**Agents vs Personas vs Roles**

| | Agents (`.md`) | Roles (`.toml`) | Personas (`.toml`) |
| --- | --- | --- | --- |
| 무엇 | 세션/자식의 타입·툴·본문 | capability/model 기본값 | 행동 오버레이(`<system-reminder>`) |
| 하네스 사용 | **persona 에이전트 9개 = Agents** | 선택(effort 보조) | **쓰지 않음**(본문을 agent body에 둠) |

번들 role 예: `reasoning_effort = "high"|"medium"|"low"`, `default_capability_mode = "read-only"|"all"`.

### 1.3 에이전트 frontmatter (`.grok/agents/*.md`)

번들 + 바이너리 스키마에서 확인된 필드(하네스가 쓰는 것만):

| 필드 | 용도 | 하네스 |
| --- | --- | --- |
| `name` | 타입 id | 필수, Claude와 동일 이름 |
| `description` | spawn 힌트 | 필수 |
| `model` | 모델 id 또는 `inherit` | **`grok-4.5` 고정** (inherit 금지) |
| `effort` | reasoning effort | **`high` / `medium` / `low`** |
| `permission_mode` / `permissionMode` | `default` · `plan` · `auto` · `bypassPermissions` … | 읽기 전용 역할은 **`plan`** |
| `tools` / `disallowedTools` | 툴 화이트·블랙 | 선택. 1차 방어는 capability_mode |
| `prompt_mode` | `full` 등 | 번들과 같이 `full` 가능 |
| `agents_md` | 프로젝트 규칙 주입 | `true` 권장 |
| `mcpInheritance` | MCP 상속 | 기본 `all`; 필요 시 축소 |

**Cursor의 `readonly: true` / Claude의 `tools:` 화이트리스트 대응물** = `permission_mode: plan` + spawn `capability_mode: "read-only"` + 본문 hard rule. 툴 화이트리스트는 2차.

번들 `explore`/`plan`은 `permission_mode: plan`이고 본문에 "NO file editing tools". `general-purpose`는 `model: inherit` + 재귀 spawn 언급이 있으나 **런타임 depth는 1** — 문서가 우선.

### 1.4 스킬 (`.grok/skills/<name>/SKILL.md`)

| 필드 | 비고 |
| --- | --- |
| `name` · `description` | 필수 계열 |
| `model` · `effort` | **스킬 단위 override 지원** (Claude 스킬과 동일 계열) |
| `allowed-tools` | 지원 |
| `disable-model-invocation` | 지원 |
| `when-to-use` | 자동 호출 트리거 분리 |

탐색 우선순위: CWD/repo `.grok/skills` → user `~/.grok/skills` → (compat 시) Claude/Cursor 경로. **pure 변형은 `~/.grok/skills`만 사용.**

### 1.5 훅

- 위치: `~/.grok/hooks/*.json` · 프로젝트 `.grok/hooks/*.json` · config.toml `[[hooks.*]]`
- 스키마: Claude와 같은 **중첩** `hooks.<Event>[].hooks[]` (`type` · `command` · `timeout`)
- 이벤트: `SessionStart` · `PreToolUse` · `PostToolUse` · `SubagentStart`(비차단) · `SubagentStop`(차단 가능) · `Stop` …
- stdin: **camelCase** (`hookEventName`, `toolName`, `toolInput`, `cwd`, `workspaceRoot`, …)
- matcher 툴 별칭: `Bash`→`run_terminal_command`, `Edit|Write`→`search_replace`, `Task`→`spawn_subagent`, …
- 차단: `PreToolUse`에 `{"decision":"deny","reason":"…"}` 또는 exit 2. **실패는 fail-open**
- **`SessionStart` stdout 무시** — Claude/Cursor의 `additionalContext` 주입 불가
- 프로젝트 훅은 folder trust 필요 (`/hooks-trust`)

### 1.6 지침 파일

- 프로젝트: `AGENTS.md` / `Agents.md` / `Claude.md` 등 (디렉터리 트리 누적, 깊은 쪽이 우선)
- 홈 규칙: **`$GROK_HOME/rules/*.md`** (기본 `~/.grok/rules/`) — 항상 스캔
- Claude 홈 `~/.claude/CLAUDE.md`는 **compat.claude 켜진 경우에만**
- pure 변형 전역 지침 설치 위치: **`~/.grok/rules/AGENTS.md`** — Cursor처럼 훅 주입이 필요 없음. 파일명은 프로젝트 규칙과 같은 `AGENTS.md`를 쓴다(§8-6 확정).

### 1.7 툴 이름 대응 (스킬 본문 치환)

| Claude | Cursor | **Grok Build** |
| --- | --- | --- |
| `Agent` | `Task` | **`spawn_subagent`** |
| `AskUserQuestion` | `AskQuestion` | **`ask_user_question`** |
| `Bash` | `Shell` | **`run_terminal_command`** |
| `Read` | `Read` | **`read_file`** |
| `Edit` / `Write` | `Edit` / `Write` | **`search_replace`** (단일 편집 툴) |
| `Grep` | `Grep` | **`grep`** |
| `Glob` | `Glob` | **`list_dir`** / 검색 패턴 |

### 1.8 현재 머신 상태 (변형 전)

`grok inspect` 스냅샷 요지:

- Claude compat **enabled** → `~/.claude/agents/*`(implementer·planner·리뷰어 4) · hooks · MCP(context7 등) 로드
- Grok 전용 harness agents/skills: **없음**
- 프로젝트 `Agents.md` + `Claude.md`는 네이티브로 로드 (compat 무관)

→ pure 변형을 깔기 전에 compat를 끄지 않으면 **Claude frontmatter(`model: sonnet`, `tools:`)가 Grok에 부분 해석**되거나 무시되며, 어느 쪽이든 조용한 드리프트다.

---

## §2. 상위 문서와의 관계 — Grok Build 열을 새로 깐다

ANALYSIS §4 Cursor 열:

| 역할 | Cursor | **Grok Build (이 문서)** |
| --- | --- | --- |
| T1 | Grok 4.5 | **동일 모델** |
| T2 bulk | Composer 2.5 Standard | **같은 Grok 4.5 + 낮은 effort** (Composer 없음) |
| implementer | Grok 4.5 / medium | **Grok 4.5 / medium** (동일) |
| 세션 plan-dev | Grok high | **Grok high** |
| 세션 dev-loop* | Composer Standard | **Grok medium** (컨트롤러) |

**의미:** Cursor 변형의 비용 구조(T2를 Composer로 내림)를 Grok Build에서는 **재현할 수 없다.** pure Grok 풀에서는 T2도 Grok 단가다. 절감 레버 우선순위:

1. **루프 축 축소** (`dev-loop-noreview` 기본) — §9.9와 동일 논리, 효과가 가장 큼  
2. **effort 하향** (T2 bulk `medium`/`low`, 컨트롤러 `medium`)  
3. **200K 경계 회피** (Worker 프롬프트·scope 스크립트)  
4. **캐시** — Grok 캐시 할인 4×로 Claude보다 약함(§6d); cold start 손익분기는 이미 §6d에 계산됨  

Composer가 없어서 T2 단가 절감폭은 Claude(1.67×)보다도 작을 수 있다 — **effort와 루프 변형이 전부다.**

---

## §3. 표현 손실·구조 변경 (Claude → Grok)

### 3.1 중첩 깊이 1 → design-bearing 재설계 (**필수**)

| 플랫폼 | `implementer → plan-consultant` |
| --- | --- |
| Claude | 가능 (Agent 툴, 깊이 여유) |
| Cursor | 가능 (정확히 2계층 한도) |
| Codex | 가능 (spawn, depth 여유 전제) |
| **Grok** | **불가** |

**채택 프로토콜 (Grok 전용):**

1. `implementer`는 `(design-bearing)` TODO에서 **자문을 직접 spawn하지 않는다.**
2. 대신 고정 상태 헤딩으로 반환한다 — 예: `status: needs-design-decision` + 질문 블록(선택지 2개, 되돌리기 비용, 플랜 정합 근거).
3. **Dispatcher(메인 세션, `implement-dev` 스킬)** 가 `plan-consultant`를 spawn하고 결정을 받은 뒤, **같은 implementer를 `resume_from`으로 재개**하거나 새 implementer에 결정 요약을 실어 재dispatch한다.
4. 방향 충돌(`blocked`)은 기존과 같이 사용자에게 — consultant가 방향을 바꾸지 못한다.

본문·`implement-dev` SKILL에 위 프로토콜을 명시한다. Claude/Cursor 판의 "implementer가 consultant를 부른다" 문장은 **Grok 판에서 삭제**.

`resume_from` 제약: 소스 completed · 동일 agent type · 같은 세션. 재개는 가능하나 모델은 소스 핀을 따른다.

### 3.2 모델 티어 없음 → effort 티어

| Claude | Grok |
| --- | --- |
| `model: opus` + `effort: medium` | `model: grok-4.5` + `effort: high` |
| `model: sonnet` + `effort: high` | `model: grok-4.5` + `effort: medium` |
| `inherit` | **금지** — 전부 명시 |

### 3.3 전역 지침

| Cursor | Grok |
| --- | --- |
| sessionStart `additional_context` 주입 | **불필요** — `~/.grok/rules/` 네이티브 로드 |
| SessionStart로 컨텍스트 JSON | Grok SessionStart **stdout 무시** |

`session-context.sh`(저장소 personal/work 분류)는:

- Claude: stdout JSON hookSpecificOutput  
- Grok: **파일을 쓰거나 env만 쓰는 변형**이 필요. 권장: 분류 결과를 `~/.grok/rules/zz-session-repo-class.md`에 쓰지 말고, **훅이 하는 일을 스킬/지침에 "origin remote + WORK_GITLAB_HOST로 분류"**로 문서화하거나, PreToolUse git-identity가 이미 쓰는 것과 같은 셸 판별을 유지.  
- 최소: Grok용 `session-context.sh`는 **분류 로그 + 필요 env export 시도**에 그치고, 전역 지침은 rules 파일에만 둔다.

### 3.4 모델 핀 가드

| Cursor | Grok |
| --- | --- |
| `subagentStart` 차단 가능 | **`SubagentStart` 비차단** |
| 해석된 `subagent_model` | spawn `toolInput`에 **model·타입 있음**(§8-2 확정) |

**1차 범위: 가드 훅 없음.** 핀 권위 = agent frontmatter `model` + `effort`(effort 적용은 §8-3 확정).  
`PreToolUse` matcher `spawn_subagent|Task`로 `toolInput.model`을 거부하는 가드는 **가능하지만 후순위** — 설치·티어 안정화 뒤에만 검토.

### 3.5 cascade (implementer failed → T1 재시도)

Claude/Codex: spawn 인자로 상위 모델 1회.  
Grok: **상위 모델이 없고, cascade용 `implementer-strict`도 두지 않는다**(§8-4 확정).

- `agents/grok/implementer.md` = **`effort: medium` 단일**
- Worker `failed` 시 Dispatcher는 동일 핀으로 재시도 정책을 스킬 본문에 맡기거나 사용자 에스컬레이션 — **effort 상향 전용 에이전트 파일 없음**

---

## §4. 티어 배치 — Grok Build 판

전제: 모델은 전부 `grok-4.5`. effort만 표에 적는다.

| 에이전트 / 세션 | 티어 | **effort** | 권한 | 근거 |
| --- | --- | --- | --- | --- |
| `plan-dev` (세션 습관) | T1 | **high** | — | 상한. xhigh 없음(§4 원칙 2의 Grok 해석) |
| `planner` | T1 | **high** | plan / read-only | 아키텍처. `permission_mode: plan`은 **읽기 셸 허용**(§8-5) |
| `plan-consultant` | T1 | **high** | plan / read-only | escalation; **메인이 spawn** |
| `security-reviewer` | T1 | **high** | plan / read-only | miss 비용 최대; 3단 스케일에서 medium 한 칸 아래는 약함 |
| `reliability-reviewer` | T1 | **high** | plan / read-only | 반사실 시뮬레이션 |
| `implementer` | T2 | **medium** | default / all | 장문맥+agentic. cascade 없음. 모델 내릴 곳 없음 |
| `tester` | T2 | **medium** | default / all | 기계 목표; 프로덕션 금지는 본문 |
| `fixer` | T2 | **medium** | default / all | finding = 명세 |
| `maintainability-reviewer` | T2 | **medium** | plan / read-only | 패턴 매칭; plan 모드에서도 `git diff`·`rg` 가능 |
| `senior-generalist-reviewer` | T2 | **medium** | plan / read-only | catch-all |
| `dev-loop*` (세션 습관) | T2 | **medium** | — | 전이표+append |
| `review-code` 집계 (세션) | T2 | **low** | — | dedup·정렬; Fix/Accept는 사람 |
| `commit-code` / `request-merge` | T2 | **low** | — | 거의 기계적 |

**에이전트 파일 예시:**

```yaml
---
name: security-reviewer
description: "…(Claude 판 서술 유지)"
model: grok-4.5
effort: high
permission_mode: plan
agents_md: true
---
```

```yaml
---
name: implementer
description: "…"
model: grok-4.5
effort: medium
permission_mode: default
agents_md: true
---
```

**`[subagents.models]` 전역 오버라이드는 쓰지 않는다** — 역할 파일과 이중 진실이 된다. 역할 파일이 단일 소스.

**세션 습관 (파일 아님):**

| 세션 | `/model` · `/effort` |
| --- | --- |
| `plan-dev` | `grok-4.5` · **high** |
| 모든 `dev-loop*` | `grok-4.5` · **medium** |

스킬 frontmatter `model`/`effort`는 턴 단위일 수 있으나 plan-dev·dev-loop는 멀티턴이라 **세션 습관이 권위** (Claude W4와 동일).

---

## §5. 포팅 대상 — Claude 원본 인벤토리

원본: `PLAN_CLAUDE` 적용 완료분 + Cursor/Codex와 같은 스킬 집합.

| 구분 | 개수 | 비고 |
| --- | --- | --- |
| 에이전트 | 9 | planner · plan-consultant · implementer · tester · fixer · 리뷰어 4 |
| 스킬 | 17 | dev-loop 3종 포함. **`review-code-claude` 없음**(Codex 전용) |
| 런타임 스크립트 | 2 | `scripts/runtime/*` → `~/.grok/scripts/` |
| 훅 스크립트 | 5 | Claude 세트 포팅; pin-guard **1차 범위 제외** |

본문 산문(Reporting contract, AC/AB, LOOP 전이, Fix/Accept)은 플랫폼 무관 — **그대로 옮긴 뒤** 툴 이름·design-bearing·경로만 치환.

---

## §6. 작업 단위

한 번에 적용, 커밋은 항목별.

| 커밋 | 항목 | 내용 |
| --- | --- | --- |
| G1 | A1 | `agents/grok/*.md` 9개 (`implementer` medium 단일, strict 없음) |
| G2 | A2 | `skills/grok/` 17개 (design-bearing Dispatcher 프로토콜 포함) |
| G3 | A3 | `hooks/grok/` hooks.json + 스크립트 |
| G4 | A4 | `apply-to-grok.sh` + runtime 설치 + `apply-to-all` 연동 |
| G5 | A5 | `docs/sync-harness/SYNC_TO_GROK.md` |
| G6 | A6 | `AGENTS.md` · `README.md` · (선택) ANALYSIS 부록 한 절 |

### A1 — 에이전트 9개

- 본문: Claude/Cursor 판 이식 + `Tier:` 한 줄(Grok: effort 근거).
- frontmatter: §4 표 — **`model: grok-4.5` + `effort`가 서브에이전트에 적용됨**(§8-3).
- read-only 6종: `permission_mode: plan` + 본문 hard rule. **읽기 셸은 plan 모드에서도 통과**(§8-5).
- `implementer`: design-bearing 절을 **Dispatcher 에스컬레이션**으로 교체; 중첩 금지 한 줄; **cascade/strict 파일 없음**.
- **`inherit` 0건.**

### A2 — 스킬 17개

치환 표:

| Claude / Cursor | Grok |
| --- | --- |
| `Agent(` / `Task(` | `spawn_subagent(` 서술 |
| `AskUserQuestion` / `AskQuestion` | `ask_user_question` |
| `$HOME/.claude/scripts` / `.cursor/scripts` | **`$HOME/.grok/scripts`** |
| `capability` 없음 | Worker spawn에 **`capability_mode`** 명시 (리뷰어 `read-only`, implementer/tester/fixer `all` 또는 생략) |
| implementer→consultant | **Dispatcher→consultant** (§3.1) |
| 병렬 리뷰 4 | 메인에서 spawn 4 parallel (depth 1 충족) |

루프 상태 기계·AC/AB·Fix/Accept **불변.**  
기본 권장 스킬 문서 문구: **`dev-loop-noreview`.**

스킬 frontmatter에 `model`/`effort`를 넣을지: plan-dev·commit-code 등 **메인 세션 스킬**은 세션 습관에 맡기고 비워도 됨. 넣으면 턴 단위로만 먹을 수 있음 — **에이전트 핀이 주력, 스킬 핀은 보조.**

### A3 — 훅

`hooks/grok/hooks.json` 예:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "startup|resume|clear|compact",
        "hooks": [
          { "type": "command", "command": "$HOME/.grok/hooks/session-context.sh" }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Bash|run_terminal_command",
        "hooks": [
          { "type": "command", "command": "$HOME/.grok/hooks/git-identity-guard.sh" },
          { "type": "command", "command": "$HOME/.grok/hooks/enforce-rg.sh" },
          { "type": "command", "command": "$HOME/.grok/hooks/enforce-fd.sh" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write|MultiEdit|search_replace",
        "hooks": [
          { "type": "command", "command": "$HOME/.grok/hooks/auto-format.sh" }
        ]
      }
    ]
  }
}
```

스크립트 변경:

| 스크립트 | 변경 |
| --- | --- |
| enforce-rg/fd · git-identity | stdin **camelCase** (`toolInput.command`, `cwd`). deny JSON `decision` |
| auto-format | matcher가 `search_replace`도 잡음; 경로 필드 확인 |
| session-context | **additionalContext 출력 제거**; 분류만 수행하거나 no-op + 주석 |

### A4 — 설치

`scripts/apply-to-grok.sh`:

| 소스 | 대상 |
| --- | --- |
| `skills/grok/*` | `~/.grok/skills/` (wipe + copy) |
| `agents/grok/*.md` | `~/.grok/agents/` |
| `hooks/grok/hooks/*` | `~/.grok/hooks/` (scripts) |
| `hooks/grok/hooks.json` | `~/.grok/hooks/harness.json` (또는 단일 파일 규약) |
| `instructions/AGENTS.md` | **`~/.grok/rules/AGENTS.md`** |
| `scripts/runtime/*` | **`~/.grok/scripts/`** |

설치 종료 시 출력에 **필수 수동 단계**:

```toml
# ~/.grok/config.toml — pure Grok 변형
[compat.claude]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false

[compat.cursor]
skills = false
rules = false
agents = false
mcps = false
hooks = false
sessions = false
```

`apply-to-all.sh`에 `apply-to-grok.sh` 추가 여부는 사용자 선택 — Personal 중심이 Claude+Grok이면 all에 넣는 편이 맞다.

### A5 — `SYNC_TO_GROK.md`

변환 규칙 요약:

- Claude `model: opus|sonnet` → `model: grok-4.5` + effort 매핑 표(§4)
- Claude `tools:` → `permission_mode` + spawn `capability_mode` (+ 선택 tools)
- Claude `Agent` → `spawn_subagent`; design-bearing은 Dispatcher 승격
- 훅 snake_case → camelCase; SessionStart 주입 삭제
- 경로 `~/.claude` → `~/.grok`
- **Claude → Grok 단방향이 기본**(§8-7 확정, Cursor `SYNC_TO_CURSOR`와 같은 방향). 소스는 항상 Claude 변형. Grok에서 시작한 변경은 Claude에 먼저 반영한 뒤 다시 내려보낸다 — 역방향 자동 sync는 범위 밖.

### A6 — 문서

- `AGENTS.md` Model Tier 표에 **Grok Build 열** 추가 (Cursor 열과 분리 — Cursor는 Composer 이원, Grok Build는 effort 단일 축 · SuperGrok 쿼터)
- Folder structure · Runtime Scripts · apply 스크립트 · 기본 루프 문구
- README Prerequisites: Grok 0.2+ · compat 끄기 · `grok` CLI · SuperGrok 구독
- 토폴로지: Personal = Claude → Grok Build(단방향 sync) + 기존 Codex/Cursor. **compat 경로 공유 금지, 파일 변형만 공유.**

---

## §7. 목표 상태 체크리스트

적용 후 `grok inspect --json`에서:

- [ ] `externalCompat.cells` claude/cursor **enabled: false** (설정 반영)
- [ ] agents 9개가 `source.path` `~/.grok/agents/…`
- [ ] skills 17개가 `~/.grok/skills/…`
- [ ] hooks가 `~/.grok/hooks` (claude 경로 훅 0)
- [ ] `~/.grok/scripts/detect-commands.sh` · `resolve-scope.sh` 존재
- [ ] `~/.grok/rules/AGENTS.md` 로드 (rules 목록)
- [ ] 에이전트 frontmatter에 `inherit` 없음, effort 전부 명시
- [ ] implement-dev 스킬 본문에 Dispatcher consultant 프로토콜
- [ ] 리뷰어 spawn에 `capability_mode: read-only` (또는 동등)
- [ ] `implementer-strict` / cascade 전용 에이전트 **없음**

---

## §8. 미결 해소 (2026-08-03 사용자 답변)

초판의 적용 전 확인 8건을 전부 닫았다.

| # | 질문 | **확정 답** | 계획에 반영된 결과 |
| --- | --- | --- | --- |
| 1 | 과금 모델 | **SuperGrok subscription 구독 쿼터** | §1.1·§2: $/작업 표 대신 쿼터 효율. API 단가는 참고만 |
| 2 | spawn `toolInput`에 model·타입 | **있음** | §3.4: PreToolUse 가드 **가능**. 1차 범위에는 넣지 않음 |
| 3 | agent `effort` frontmatter 적용 | **적용됨** | §4·A1: effort 핀이 티어의 단일 소스. role TOML 이중 핀 불필요 |
| 4 | `implementer-strict` / cascade | **기본(medium 단일, cascade 없음)** | §3.5·A1: strict 파일 없음 |
| 5 | `permission_mode: plan` + 읽기 셸 | **막지 않음** | 리뷰어 6종에 `plan` 안전. capability_mode와 병행 |
| 6 | 홈 rules 파일명 | **`AGENTS.md`가 기본** | 설치 대상 `~/.grok/rules/AGENTS.md` |
| 7 | sync 방향 | **Claude → Grok 기본** | A5·SYNC_TO_GROK 단방향. 역방향 자동 없음 |
| 8 | 모델 카탈로그 | **지금은 `grok-4.5` 단일** | 전 역할 동일 model 문자열. 카탈로그 확장 시 재검토 |

**남아 있는 구현 리스크(미결이 아님, 적용 중 관찰):** SuperGrok 쿼터 소진 체감 vs effort 배치 미세 조정, compat 끄기 누락 시 Claude 판 혼입.

---

## §9. 결정 기록

| # | 결정 |
| --- | --- |
| 1 | **Claude/Cursor compat 사용 안 함** — pure `skills/grok` · `agents/grok` · `hooks/grok` |
| 2 | **모델 핀 = `grok-4.5` only**; T1/T2 = effort 축 |
| 3 | **effort 스케일 = low/medium/high only** (메뉴 실측); frontmatter effort **적용 확인** |
| 4 | **T1 effort = high**, **T2 effort = medium** (집계/커밋 세션은 low 습관) |
| 5 | **기본 루프 = `dev-loop-noreview`** |
| 6 | **design-bearing = Dispatcher spawn consultant** (깊이 1) |
| 7 | **pin-guard 1차 없음** (SubagentStart 비차단; PreToolUse 가드는 후순위) |
| 8 | **전역 지침 = `~/.grok/rules/AGENTS.md`**, SessionStart 주입 없음 |
| 9 | **런타임 스크립트 = `~/.grok/scripts/`**, 소스 `scripts/runtime/` 공유 |
| 10 | 소스 오브 트루스 = **Claude 변형**; **Claude → Grok** SYNC로 생성 |
| 11 | **과금 = SuperGrok 구독 쿼터** (API 정가 예산 표 비적용) |
| 12 | **cascade / `implementer-strict` 없음** — implementer medium 단일 |
| 13 | **`permission_mode: plan` + 읽기 셸 허용** — 리뷰어·planner·consultant에 plan 사용 |

---

## §10. 상위 문서에 대한 정정·추가 (적용 후 ANALYSIS에 반영 후보)

| # | ANALYSIS | 이 조사 |
| --- | --- | --- |
| 1 | Grok은 Cursor 열에만 존재 | **Grok Build = 4번째 플랫폼 변형** |
| 2 | Cursor implementer만 Grok medium | pure Grok에서는 **전 역할 Grok**, implementer medium 유지 |
| 3 | T2 = Composer로 단가 절감 | **Grok Build에서 불가** — noreview + effort가 주력 |
| 4 | (없음) | **서브에이전트 depth 1** — design-bearing 프로토콜 분기 |
| 5 | (없음) | **SessionStart 컨텍스트 주입 없음** |
| 6 | (없음) | **compat 기본 on** — pure 설치의 최대 운영 리스크 |
| 7 | 예산 풀 3종(API 정가) | Grok Build는 **SuperGrok 구독 쿼터** — §9 표를 네 번째 풀로 억지 편입하지 말 것 |

---

## §11. 비범위

- Grok 번들 스킬(`implement`, `review`, `design`, …)을 하네스 루프로 대체·삭제하지 않음 — 이름 충돌 시 `user:` 한정 또는 harness 스킬명 유지(현재 하네스 이름과 번들 충돌 최소)
- workflow Rhai / plugin marketplace
- ACP IDE 전용 프로파일
- Claude 변형 본문의 행동 변경(Grok 전용 분기만 `skills/grok`)

---

## §12. 한 줄 요약

**Grok Build 변형은 SuperGrok 구독 위·`grok-4.5` 단일 모델 하네스다. 티어는 effort 세 칸과 `dev-loop-noreview`로 쿼터를 아끼고, 깊이 1 때문에 consultant는 Dispatcher가 부르며, Claude→Grok 단방향 SYNC로 `~/.grok/{agents,skills,hooks,scripts,rules/AGENTS.md}`에만 깐다.**
