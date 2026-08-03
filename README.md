# My personal harness

개인 사용 목적으로 만든 Agent Skills 와 Global instruction, 그리고 설치 스크립트.

## 폴더 구조

```
personal-harness/
├── skills/           # 플랫폼별 Agent Skills (claude/ · codex/, 스킬마다 별도 폴더)
├── agents/           # persona 서브에이전트 정의 (claude/*.md · codex/*.toml)
├── hooks/            # 플랫폼별 훅 (claude: settings.json + *.sh · codex: hooks.json + *.sh)
├── instructions/     # 전역 지침 AGENTS.md 배포 소스
├── scripts/          # 설치·동기화 스크립트 (apply-to-personal.sh · apply-to-work.sh · apply-to-all.sh · setup-ctx7.sh) + claude/: ~/.claude/scripts/로 설치되는 런타임 스크립트
├── docs/             # 하네스 문서 (sync-harness/: SYNC_TO_* 변환 규칙 · loop-engineering/: 루프 엔지니어링 계획·조사 문서 · cost-effective/: 모델 티어링 비용 분석)
└── .agents/skills/   # 하네스 자체용 메타 스킬 (sync-harness; .claude/skills/에 동일 사본)
```

훅의 상세 동작은 [Harness > Hooks](#hooks) 참조. 훅이 `rg`/`fd` 사용을 강제하므로 [ripgrep](https://github.com/BurntSushi/ripgrep)과 [fd](https://github.com/sharkdp/fd) 설치가 필요하다(Prerequisites 참조).

플랫폼 변형은 **Claude ↔ Codex** 토폴로지로 마이그레이션한다. Personal 환경에서는 Claude Code를 중심으로 Grok Build도 사용하지만, Grok Build는 Claude Code와 완벽히 호환되므로 별도 변형을 유지하지 않는다. Work 환경의 중심은 Codex이며, Claude Code와 Codex 두 변형은 양방향으로 공유할 수 있다. `review-code-claude`만 Claude Code를 외부 프로세스로 호출하는 Codex 전용 어댑터이므로 Claude counterpart를 두지 않는다. 각 방향의 변환 규칙은 [SYNC_TO_CODEX.md](docs/sync-harness/SYNC_TO_CODEX.md)(Claude Code → Codex), [SYNC_TO_CLAUDE.md](docs/sync-harness/SYNC_TO_CLAUDE.md)(Codex → Claude Code)에 정리되어 있다.

## Prerequisites

이 harness의 skills·hooks·설치 스크립트가 정상 동작하려면 아래 CLI 도구들이 PATH에 설치되어 있어야 한다. 플랫폼별로 일부 도구는 필수가 아닐 수 있으므로 각 항목의 적용 범위를 확인한다.

| 도구 | 적용 범위 | 용도 | 설치 |
| --- | --- | --- | --- |
| `jq` | 전체(Claude/Codex shell hook + `apply-to-personal.sh`) | hook 입력 파싱, `settings.json` 머지, `loki-log-search`의 LogQL URL 인코딩 | `brew install jq` |
| `git` | 전체 shell hook 및 `commit-code` | 세션 컨텍스트 분류, git identity 검증, 커밋 후 문서 드리프트 검사 | `brew install git` |
| `make` | 전체 `auto-format` hook | 프로젝트 Makefile의 `fmt`/`format` 타겟 실행 | macOS: Xcode Command Line Tools, Linux: `build-essential` |
| `rg` (ripgrep) | 전체 `enforce-rg` hook + AGENTS.md | 재귀 `grep` 대신 코드 검색 강제 | `brew install ripgrep` |
| `fd` | 전체 `enforce-fd` hook + AGENTS.md | 파일명/경로 검색용 `find` 대체 강제 | `brew install fd` |
| `ctx7` | AGENTS.md context7 룰 + `scripts/setup-ctx7.sh` | 라이브러리/프레임워크 공식 문서 fetch | `npm install -g ctx7` 후 `ctx7 login`(또는 `CONTEXT7_API_KEY` 설정) |
| `claude` | Codex `review-code-claude` | 설치된 Claude `review-code`와 reviewer agent 4개를 비대화형으로 실행 | [Claude Code 설치](https://code.claude.com/docs/en/setup) 후 인증 |
| `gh` | `request-merge`(personal), `setup-initial-repo`(personal 원격 생성) | GitHub PR 생성/업데이트, 개인 private repo 자동 생성 | `brew install gh` 후 `gh auth login` |
| `glab` | `request-merge`(work) | GitLab MR 생성/업데이트 | `brew install glab` 후 `glab auth login` |
| `gcx` | `loki-log-search` | Grafana Loki 로그 조회용 `gcx api` passthrough | `gcx` 배포본 설치 후 `gcx config current-context`로 컨텍스트 구성 |

참고:
- `rg`/`fd`는 이미 폴더 구조 설명의 `hooks` 항목에서 언급한 대로 hook이 사용을 강제하므로 반드시 설치해야 한다.
- `gh`·`glab`는 각각 personal/work 저장소에서만 호출되므로, 사용하지 않는 저장소 유형의 도구는 생략 가능하다.
- 프로젝트 템플릿(`skills/*/setup-initial-repo/references/{go-makefile.md,swift-makefile.md,ts-nextjs-packagejson.md}`)이 `setup-initial-repo`로 참조될 때 함께 따라가는 `go`, `golangci-lint`, `mockery`, `gremlins`, `swag`, `swiftlint`, `swiftformat`, `eslint`, `vitest`, `playwright`, `stryker` 등은 생성되는 프로젝트의 빌드 도구이지 이 harness 자체의 prerequisite은 아니다.

### 환경변수

Skills 실행에 필요한 환경변수 목록. 각 Agent 의 환경변수 설정에 등록되어 있어야 한다 (예: Claude Code 의 settings.json 파일 내 `env` 설정 또는 Codex 의 config.toml 파일 내 `shell_environment_policy` 항목의 `set` 설정)

- `PERSONAL_GIT_EMAIL`: 개인 저장소 커밋 시 사용할 Git 이메일
- `PERSONAL_GIT_NAME`: 개인 저장소 커밋 시 사용할 Git 이름
- `WORK_GIT_EMAIL`: 회사 저장소 커밋 시 사용할 Git 이메일
- `WORK_GIT_NAME`: 회사 저장소 커밋 시 사용할 Git 이름
- `WORK_GITLAB_HOST`: 회사 GitLab 호스트 주소 (저장소 구분에 사용)
- `WORK_GITLAB_USERNAME`: 회사 GitLab 사용자명 (MR 생성 시 --assignee 옵션에 사용)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: 회사 GitLab 기본 리뷰어 (MR 생성 시 --reviewer 옵션에 사용)

## Development

기본 개발 흐름은 아래 두 방식으로 사용할 수 있다. `dev-loop` 오케스트레이터에 구현 사이클을 맡기는 **Loop Engineering** 방식과, 각 스킬을 단계마다 직접 호출하는 **Manual Development** 방식이다. 두 방식은 같은 스킬 집합([Harness > Skills](#skills))과 같은 산출물 형식(플랜/리포트/리뷰 finding)을 공유하므로 중간에 서로 갈아탈 수 있다.

### Loop Engineering

```
plan-dev → dev-loop*( implement-dev → test-dev → [review-code] → (fix-dev → test-dev → [review-code])* ) → commit-code → request-merge
```

**루프는 세 변형이 병존한다. 시작 전에 고르며, 도중에 바꾸지 않는다.**

| 스킬 | 리뷰 | mutation | 용도 |
| --- | --- | --- | --- |
| `dev-loop-noreview` | 없음 | 안 함 | **기본값.** 대부분의 일상 작업 |
| `dev-loop-light` | `maintainability` + `senior-generalist` 2축 | 안 함 | 리뷰는 필요하지만 4축까지는 과한 작업 |
| `dev-loop` | 4축 전부 | 함 | 진짜 심각하거나 거대한 기능 개발, 또는 보안·신뢰성 민감 경로를 건드리는 변경 |

`dev-loop-light`이 버리는 두 축(`security`·`reliability`)은 miss 비용이 회복 불가능한 쪽이다. authn/authz·비밀·동시성·부분 실패 경로를 건드리면 `light`이 아니라 `dev-loop`다.

**어느 변형도 게이트가 없지는 않다.** 셋 다 사람 게이트 2개(TESTING의 suspected-defect **Fix/Accept** 분류, READY_TO_COMMIT)를 그대로 갖는다. 리뷰를 끄면 사라지는 것은 리뷰어 4종이지 사람의 판단이 아니다.

1. **계획 수립**: `plan-dev` 스킬을 호출해 인터뷰로 계획을 수립한다. 완료 조건 라운드에서 TODO별 완료 조건·증거(`Acceptance Contract`)와 권한 경계·루프 예산(`Authority Boundaries`)을 함께 확정하고, 계획을 승인하면 PLAN/RESEARCH 파일이 `docs/agents/` 아래에 저장된다. **`plan-dev`는 Opus 세션에서 돌린다**([Model Tier](#model-tier)).
2. **루프 실행**: 위 표에서 변형을 고른 뒤 승인된 플랜 경로를 지정해 명시적으로 호출한다. 이후 종료 술어(TODO 완료 ∧ AC 증거 충족 ∧ 검증 green ∧ 차단 finding 0)를 만족할 때까지 자율 반복된다. 멀티스텝 플랜은 sub-plan(`-STEP-N`) 단위로 호출한다. **루프 실행 세션은 변형과 무관하게 Sonnet이다** — T1 에이전트는 프론트매터 핀으로 Opus에서 돈다.
3. **중간 개입은 두 경우뿐**: (a) 리뷰(있는 변형만) 또는 TESTING 게이트에서 finding이 나오면 항목별 Fix/Accept 분류 질문에 답한다 — Accept 항목은 `AGENTS.md`의 `Accepted Review Exceptions`에 기록되어 다음 리뷰부터 Waived(`Applied Exceptions`)로 강등 표시되고 차단 finding으로 계산되지 않는다. (b) blocked·예산 소진·no-progress로 에스컬레이션되면 지시를 내린다 — 방향 문제면 `plan-dev`로 재진입한다.
4. **완료 확인과 커밋**: 루프는 READY_TO_COMMIT에서 멈춘다. Implementation Report와 LOOP 상태 파일을 확인한 뒤 `commit-code`, 필요 시 `request-merge`를 직접 호출한다 — 커밋·푸시·PR/MR 생성은 루프 권한 밖이다. **`dev-loop-noreview`에서는 리뷰어가 아무도 변경을 읽지 않았으므로**, IMPL 리포트의 `## TODO Fulfillment`와 AC 증거를 직접 본다 — 4축 리뷰가 잡아주던 instruction drift가 여기서는 사람 몫이다.
5. **중단·재개**: 루프가 중간에 끊겨도 상태는 `docs/agents/dev/*_LOOP_*.md`에 남으므로(LOOP 포맷은 세 변형 공통), 같은 플랜으로 같은 변형을 다시 호출하면 마지막 라운드에서 이어서 진행한다.

### Manual Development

`dev-loop` 없이 각 스킬을 단계마다 직접 호출하는 방식이다. 각 스킬은 단독 사용도 가능하지만, 보통 앞 스킬이 만든 산출물(플랜 / 구현 결과 / 리뷰 코멘트 등)을 다음 스킬이 입력으로 받는다.

```
plan-dev → implement-dev → (이슈 발견 시 fix-dev 반복) → test-dev → review-code → (이슈 발견 시 fix-dev 반복) → commit-code → request-merge
```

1. `plan-dev`로 계획을 수립하고 승인한다.
2. `implement-dev`에 승인된 플랜 경로를 넘겨 구현한다.
3. `test-dev`로 변경 범위의 테스트를 보강한다.
4. `review-code`로 리뷰하고, 발견된 결함은 `fix-dev`로 하나씩 수정한 뒤 필요한 범위를 재검증한다.
5. `commit-code`로 커밋하고, 필요 시 `request-merge`로 PR/MR을 생성한다.

리뷰의 HIGH/CRITICAL 트리아지(Fix/Accept 분류)와 `Accepted Review Exceptions` 기록은 단독 `review-code` 호출에서도 동일하게 동작한다. 어느 단계를 건너뛰거나 반복할지는 사용자가 결정한다.

## Harness

### Skills

각 스킬은 `skills/<platform>/`(claude/codex) 아래 플랫폼 변형으로 관리되며, 스킬마다 별도 폴더를 갖는다. 상세 계약은 각 스킬의 `SKILL.md` 참조.

**Core Development Process:**

| 스킬 | 설명 | 실행 방식 | 산출물 |
| --- | --- | --- | --- |
| `plan-dev` | 내장 Plan 모드의 인터뷰로 구현 플랜을 수립·승인. 완료 조건 라운드에서 `Acceptance Contract`·`Authority Boundaries` 확정, 필요 시 다단계(main + sub-plans) 분할 | 메인 세션 (`planner` 조건부 위임) | PLAN·RESEARCH (`docs/agents/`) |
| `implement-dev` | 승인된 플랜을 TDD(Red-Green-Refactor)로 구현하고 AC별 증거를 수집. 방향 충돌 시 `blocked` 반환. `(design-bearing)` TODO에서만 `plan-consultant` 자문 | Dispatcher → `implementer` Worker | 코드 + IMPL 리포트 (`## TODO Fulfillment` 축) |
| `fix-dev` | 리뷰·검증에서 발견된 결함을 한 건씩 원인 분석·수정·검증. 커밋하지 않음 | Dispatcher → `fixer` Worker | IMPL 리포트에 `## Fix` 누적 |
| `test-dev` | git scope(기본: `main` 대비 diff) 기준으로 유닛/E2E 갭 채움과 mutation LIVED 제거. production 코드는 불변. 호출자가 mutation을 범위 밖으로 지정할 수 있다 | Dispatcher → `tester` Worker | 테스트 코드 (파일 아티팩트 없음) |
| `review-code` | 리뷰 페르소나 병렬 dispatch(기본 4축, 호출자가 부분집합 지정 가능) 후 finding 종합. 리뷰어는 `Confidence`를 달아 전부 보고하고 **필터링은 이 스킬의 집계 단계**가 한다. HIGH/CRITICAL은 사용자 Fix/Accept 트리아지, Accept는 AR로 기록해 이후 리뷰에서 Waived 강등 | Dispatcher → reviewers | finding 리포트, `Accepted Review Exceptions` |
| `review-code-claude` | 명시적 `$review-code-claude` 호출에만 Claude Code의 `review-code`를 별도 읽기 전용 프로세스로 실행하고 Codex에서 트리아지 | Codex → Claude CLI → 4 Claude reviewers | finding 리포트, `Accepted Review Exceptions` |
| `dev-loop` | 승인된 플랜(AC·AB 필수)으로 구현→테스트→리뷰(4축)→fix 사이클을 종료 술어 충족까지 자율 반복, READY_TO_COMMIT에서 정지. 트리아지·AR 승인·커밋은 사람 몫. **무겁다 — 심각하거나 거대한 작업 전용** | 메인 세션 (각 단계 스킬의 Dispatcher 흐름 호출) | LOOP 파일 (append-only) |
| `dev-loop-light` | 같은 컨트롤러, 리뷰 2축(`maintainability`·`senior-generalist`) + mutation 제외 | 메인 세션 | LOOP 파일 (append-only) |
| `dev-loop-noreview` | **기본값.** 같은 컨트롤러, 리뷰 없음 + mutation 제외. TESTING의 Fix/Accept 게이트는 그대로 남는다 | 메인 세션 | LOOP 파일 (append-only) |
| `commit-code` | 수정된 파일 기반 커밋 생성 + 커밋 후 문서 드리프트 검사(읽기 전용 보고) | 메인 세션 | 커밋 |
| `request-merge` | `gh`(personal) / `glab`(work)로 PR/MR 생성·업데이트 | 메인 세션 | PR/MR |

**Misc:**

| 스킬 | 설명 | 산출물 |
| --- | --- | --- |
| `spec-creator` | 신규 프로젝트 요구사항을 단계적 인터뷰로 정리 | 한국어 SPEC.md |
| `setup-initial-repo` | SPEC.md 기반 신규 저장소 부트스트랩 — 지침 파일, 빌드 스크립트, .gitignore, git identity, remote origin | 초기 레포 스캐폴드 |
| `application-research-sync` | 코드 변경을 분석해 Research 파일 일괄 갱신 (index 먼저, 필요한 본문만) | `docs/agents/research/*` |
| `learn-from-manual-edits` | 에이전트 작성 코드 위의 사용자 수동 편집에서 일반 선호를 추론해 컨벤션으로 기록 | CLAUDE.md/AGENTS.md 컨벤션 섹션 |
| `chat-summary` | 대화 내용을 vault 기존 category/tag 어휘로 정리한 자기완결 Obsidian 노트(YAML frontmatter + 본문)로 작성 | Obsidian 노트 (.md) |
| `find-docs` | 라이브러리/프레임워크 공식 문서를 Context7(`ctx7`)로 조회. Context7이 자동 설치하는 서드파티 스킬(이 harness가 직접 작성한 것이 아님) | 없음 (채팅 보고) |
| `loki-log-search` | Grafana Loki 로그를 `gcx api` 경유로 조회 | 없음 (채팅 보고) |

### Custom Agents

`agents/<platform>/`의 persona 서브에이전트 정의. 포맷은 Claude Code가 Markdown(YAML frontmatter), Codex가 TOML이다. 사용자가 직접 호출하기보다 스킬이 위임(dispatch)하는 것이 기본이다.

에이전트마다 `model`·`effort`를 프론트매터에 직접 핀한다 — 배치와 근거는 [Model Tier](#model-tier) 참조. `inherit`은 이 하네스 어디에도 없다.

| 에이전트 | 페르소나 · 담당 | 호출 스킬 | 권한 |
| --- | --- | --- | --- |
| `planner` | 소프트웨어 아키텍트 — 방향·경계·인터페이스·리스크 검토, 사용자에게 물을 질문 목록 반환, 플랜 초안 리뷰 | `plan-dev` (모호·횡단·아키텍처 민감 작업에서 조건부) | 읽기 전용 |
| `plan-consultant` | escalation hatch — 두 접근이 모두 플랜과 정합하지만 되돌리기 비싼 갈림길을 판정. 짧은 결정만 반환하고 코드는 쓰지 않음 | `implementer` (`(design-bearing)` TODO 한정) | 읽기 전용 |
| `implementer` | 최소 코드 규율(minimal-code discipline)의 구현 Worker — 스코프 재논의 없음 | `implement-dev` | 편집 가능 |
| `tester` | 테스트 보강 Worker — 유닛/E2E 갭, LIVED mutant. 테스트 코드 전용이며 의심 결함은 `TEST-NNN` finding으로 보고 | `test-dev` | 편집 가능 |
| `fixer` | 단일 결함 실행자 — 최소 올바른 수정 + 회귀 테스트. 별도 플랜이 필요하면 `needs-confirmation` | `fix-dev` | 편집 가능 |
| `security-reviewer` | 보안 축 — authn/authz, 비밀 처리, 주입, 암호화 오용, TOCTOU | `review-code` (병렬) | 읽기 전용 |
| `reliability-reviewer` | 신뢰성 축 — 오류 처리, 리소스 수명, 동시성, 타임아웃, 부분 실패 | `review-code` (병렬) | 읽기 전용 |
| `maintainability-reviewer` | 유지보수성 축 — 스타일 일관성, 추상화 적정성, 네이밍, 모듈 경계, dead code | `review-code` (병렬) | 읽기 전용 |
| `senior-generalist-reviewer` | 나머지 ISO 25010 축 — 성능, 호환성, UX, 기능 적합성, 운영 안전성 | `review-code` (병렬) | 읽기 전용 |

리뷰어 4종은 동일한 `## Reporting contract` 절(bug bar, priority·confidence 척도, per-finding block, specificity rules)을 본문에 갖는다. `review-code`의 dispatch 프롬프트가 아니라 여기 있는 이유는 캐싱이다 — 라운드마다 4× 축자 전송하던 정적 텍스트가 리뷰어별 시스템 프롬프트에 한 번 캐시된다. 되돌리지 말 것.

### Hooks

`hooks/<platform>/`의 훅 정의와 실행 스크립트. 공통 셸 훅(`hooks/<platform>/hooks/*.sh`):

| 훅 | 시점 | 역할 |
| --- | --- | --- |
| `session-context.sh` | 세션 시작 | `WORK_GITLAB_HOST`·origin remote로 work/personal repo 판별 후 세션 컨텍스트 주입 |
| `git-identity-guard.sh` | Bash 실행 전 | 커밋 시 git identity(이름/이메일)가 repo 유형에 맞는지 검증 |
| `enforce-rg.sh` | Bash 실행 전 | 코드 검색에 재귀 `grep` 대신 `rg` 강제 |
| `enforce-fd.sh` | Bash 실행 전 | 파일/경로 검색에 `find` 대신 `fd` 강제 |
| `auto-format.sh` | 파일 편집 후 | 프로젝트 Makefile의 `fmt`/`format` 타겟 실행 |

플랫폼별 설정 형식: Claude Code는 `hooks/claude/settings.json`의 `hooks` 블록, Codex는 `hooks/codex/hooks.json`을 사용한다. 훅은 정책을 강제하는 가드레일이며 `dev-loop`의 단계 전환·재시도·완료 판정에는 관여하지 않는다.

### Runtime Scripts

`scripts/claude/*.sh`는 `apply-to-personal.sh`가 `~/.claude/scripts/`로 설치한다(레포 최상위 `scripts/`와 다르다 — 그쪽은 설치 스크립트 전용이며 홈으로 복사되지 않는다). 스킬이 매번 cold Worker에서 LLM으로 재도출하던 사실을 셸로 내린 것이다.

| 스크립트 | 소비 스킬 | 반환 |
| --- | --- | --- |
| `detect-commands.sh` | `implement-dev` · `test-dev` · `fix-dev` | `Makefile` 타겟과 `package.json` 스크립트에서 lint/format/test/build/mutation/e2e 커맨드를 JSON으로. 산문에만 있는 것은 `null` — 그건 호출자가 직접 읽는다 |
| `resolve-scope.sh` | `test-dev` · `review-code` | diff 범위, 변경 파일 절대경로, 관여 언어를 JSON 한 덩어리로 |

소비 스킬은 `$HOME/.claude/scripts/…`를 문자 그대로 호출하고 `allowed-tools`에 같은 리터럴을 프리어프루브한다. 스크립트가 스킬 폴더 밖에 있어 `${CLAUDE_SKILL_DIR}` 치환을 쓸 수 없기 때문이며, `$HOME`은 양쪽 모두 리터럴로 남고 셸이 실행 시점에 확장한다. 어긋나도 대가는 권한 프롬프트 한 번뿐이다.

## Model Tier

에이전트마다 model·effort를 자기 프론트매터에 핀한다. `inherit`은 쓰지 않는다 — 그건 티어가 아니라 세션이 어쩌다 갖게 된 값이고, 루프를 Sonnet 세션에서 돌리는 순간 `security-reviewer`·`reliability-reviewer`가 파일 한 줄 안 바뀐 채 T2로 내려간다.

역할의 티어는 모델 세대가 아니라 **일의 성질**이다. 그래서 각 에이전트 본문에 `Tier:` 근거 한 줄을 남긴다 — 모델명이 바뀌어도 판단 근거는 살아남는다.

| 티어 | 정의 | Claude |
| --- | --- | --- |
| **T1 judgment** | 되돌릴 수 없고 기계 검증이 불가능한 결정 | `opus` |
| **T2 execution** | 명세가 있고 결과가 기계로 검증 가능한 작업 | `sonnet` |
| **T3 mechanical** | 판단이 사실상 없는 변환·집계 | *(미사용 — 아래 참조)* |

**T3는 의도적으로 비어 있다.** Haiku는 컨텍스트 200K·캐시 최소 프리픽스 4096 tok·모델 레벨 effort 미지원인데, 이 하네스의 T2 작업은 대부분 repo-slice 추론이라 최저 티어가 가장 못하는 일이다. 진짜 기계적인 일은 더 작은 모델이 아니라 셸로 내린다(위 Runtime Scripts).

### 에이전트 배치

| 에이전트 | `model` | `effort` | 근거 |
| --- | --- | --- | --- |
| `planner` | `opus` | `high` | 아키텍처 판단은 되돌릴 수 없고 기계 검증이 불가능 |
| `plan-consultant` | `opus` | `high` | 실행자가 검증도 취소도 못 하는 판단을 위해 존재 |
| `security-reviewer` | `opus` | `medium` | authz 우회 miss는 회복 불가 — 4축 중 miss 비용 최대 |
| `reliability-reviewer` | `opus` | `medium` | 반사실 시뮬레이션은 약한 모델이 가장 먼저 무너지는 영역 |
| `implementer` | `sonnet` | `high` | TDD가 ground truth지만 plan+research+컨벤션+코드를 함께 추론 — T2의 최상단이지 그 아래가 아니다 |
| `tester` | `sonnet` | `medium` | mutation score ≥80%가 기계 목표, 프로덕션 코드 수정 금지 |
| `fixer` | `sonnet` | `medium` | 리뷰 finding이 곧 명세이고 재테스트로 검증됨 |
| `maintainability-reviewer` | `sonnet` | `medium` | 주변 코드·프로젝트 규칙 대조는 명세된 패턴 매칭 |
| `senior-generalist-reviewer` | `sonnet` | `medium` | calibrated catch-all, miss 비용 최저 |

**effort 규칙 둘.** 최상단은 사지 않는다 — 기본 effort에서 `max`까지 올려도 티어 전반에서 몇 점 차이라, `xhigh`는 되돌릴 수 없는 결정에만 쓴다. 그리고 모델을 내릴 때 effort까지 같이 내리지 않는다: `implementer`는 `sonnet`으로 내려가면서 `effort: high`를 유지했다.

### 세션 운용 규칙

스킬 프론트매터의 `model:`은 **해당 턴에만** 적용되고 다음 프롬프트에서 세션 모델로 복귀한다. `plan-dev`는 멀티턴 인터뷰이고 모든 루프는 사람 게이트에서 턴이 끊기므로, 둘 다 이 필드로 고정할 수 없다. 따라서 **호출 경계 = 세션 경계**로 운용한다:

| 세션 | 모델 | 근거 |
| --- | --- | --- |
| `plan-dev` | **Opus** | 방향·경계·AC는 되돌릴 수 없고 실행자가 자가 수정 불가 |
| **모든 `dev-loop*` 실행** | **Sonnet** | 컨트롤러가 하는 일은 전이표 조회 + LOOP append. T1 에이전트는 프론트매터 핀으로 Opus에서 돈다 |

4축을 도는 `dev-loop`도 예외가 아니다 — 리뷰어 4종의 모델이 전부 파일에 명시돼 있으므로 세션 모델이 어떤 에이전트의 티어도 바꾸지 못한다.

**이 항목만 파일이 아니라 습관이다.** 세션을 시작하는 순간 발효되고, 레포 안에 이를 강제하는 장치는 없다.

### 운용 스위치 — 켜지 않는다

`CLAUDE_CODE_SUBAGENT_MODEL`은 프론트매터와 호출 인자를 **모두** 덮어쓰므로, 켜두면 위 표의 티어 핀이 통째로 무력화된다. `hooks/claude/settings.json`에 이 변수를 위한 `env` 블록을 두지 않은 것은 의도이며, 미설정이 정상 상태다. A/B 비교용 임시 레버로만 쓰고 반드시 되돌린다. (v2.1.196부터 값을 `inherit`으로 두면 미설정과 동일하게 취급되어 해석이 정상적으로 아래 단계로 내려간다.)

## Scripts

`scripts/`에는 설치·동기화 스크립트 4개가 있다. `apply-to-*.sh`는 이 레포의 소스 변형을 사용자 홈의 실제 에이전트 환경으로 배포하고, `setup-ctx7.sh`는 반대로 외부 생성물을 레포 소스에 반영한다. 설치 대상 디렉토리는 기존 내용을 비운 뒤 다시 채우는 방식이라, 홈 디렉토리에서 직접 수정한 스킬·에이전트·훅은 다음 실행 때 소스 기준으로 덮어써진다.

### apply-to-personal.sh

Personal 환경(Claude Code) 설치 스크립트다.

- Claude Code: `instructions/AGENTS.md`를 `~/.claude/CLAUDE.md`로 복사하고, `~/.claude/skills`·`~/.claude/agents`·`~/.claude/hooks`·`~/.claude/scripts`를 비운 뒤 각각 `skills/claude/`·`agents/claude/`·`hooks/claude/hooks/`·`scripts/claude/`의 내용으로 다시 채운다. 훅과 런타임 스크립트는 `cp -rp`로 복사해 실행 권한을 보존한다.
- Claude Code 설정: `hooks/claude/settings.json`의 `hooks` 블록을 `~/.claude/settings.json`에 `jq`로 머지한다. 사용자의 `permissions`/`model`/`env` 등 다른 설정은 보존되며, 대상 파일이 없으면 통째로 생성한다 (jq 필요).
- 마지막에 항목별 설치 개수와 상태 요약을 출력한다.

### apply-to-work.sh

Work 환경(Codex) 설치 스크립트다.

- `instructions/AGENTS.md`를 `~/.codex/AGENTS.md`로 복사한다.
- `~/.agents/skills`를 비운 뒤 `skills/codex/`의 스킬로 다시 채운다.
- `~/.codex/agents/`를 비운 뒤 `agents/codex/*.toml`을 복사한다.
- `~/.codex/hooks/`를 비운 뒤 `hooks/codex/hooks/*`를 복사하고, `hooks/codex/hooks.json`을 `~/.codex/hooks.json`으로 복사한다.
- 마지막에 항목별 설치 개수와 상태 요약을 출력한다.

### apply-to-all.sh

`apply-to-personal.sh`와 `apply-to-work.sh`를 순서대로 실행하는 래퍼다. 내부 경로가 레포 루트 기준 상대 경로이므로 레포 루트에서 실행해야 한다.

Codex에서 `review-code-claude`를 사용하려면 Claude `review-code`와 reviewer agent 4개도 필요하므로 `apply-to-all.sh`로 두 플랫폼을 함께 설치한다. 스킬은 명시적 `$review-code-claude` 호출에만 활성화된다.

### setup-ctx7.sh

Context7이 배포하는 서드파티 `find-docs` 스킬과 context7 지침 블록을 최신 버전으로 재생성해 레포 소스에 반영한다. 설치 환경(`~/.claude` 등)이 아니라 레포 안의 소스를 갱신하는 스크립트이며, 갱신 결과는 이후 `apply-to-*.sh` 실행 시 배포된다 (`ctx7` CLI 필요).

- `ctx7 upgrade`로 CLI 업데이트 여부를 먼저 확인한다 (업데이트가 있으면 안내만 출력하고 자동 설치하지는 않는다).
- 임시 디렉토리에서 `ctx7 setup --cli --claude|--codex -y -p`를 실행해 각 플랫폼 전용 `find-docs` 스킬을 생성한다. 생성물은 플랫폼마다 다르다 (예: Codex 변형에는 샌드박스 밖에서 네트워크 요청을 재시도하라는 지침이 포함된다).
- 생성물의 `npx ctx7@latest` 호출을 전역 설치된 `ctx7` 명령으로 치환한다.
- 두 변형이 모두 정상 생성된 것을 확인한 뒤 각 생성물을 대응하는 `skills/<platform>/find-docs`로 복사한다 (부분 갱신 방지를 위해 생성·검증 완료 후 일괄 복사).
- `instructions/AGENTS.md`의 `<!-- context7 -->` 블록을 Claude 룰 내용으로 교체한다 (두 플랫폼이 공유하는 지침 파일이므로 플랫폼 중립적인 Claude 룰을 쓴다).
