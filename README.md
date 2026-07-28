# My personal harness

개인 사용 목적으로 만든 Agent Skills 와 Global instruction, 그리고 설치 스크립트.

## 폴더 구조

```
personal-harness/
├── skills/           # 플랫폼별 Agent Skills (claude/ · codex/, 스킬마다 별도 폴더)
├── agents/           # persona 서브에이전트 정의 (claude/*.md · codex/*.toml)
├── hooks/            # 플랫폼별 훅 (claude: settings.json + *.sh · codex: hooks.json + *.sh)
├── instructions/     # 전역 지침 AGENTS.md 배포 소스
├── scripts/          # 설치·동기화 스크립트 (apply-to-personal.sh · apply-to-work.sh · apply-to-all.sh · setup-ctx7.sh)
├── docs/             # 하네스 문서 (sync-harness/: SYNC_TO_* 변환 규칙 · loop-engineering/: 루프 엔지니어링 계획·조사 문서)
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
plan-dev → dev-loop( implement-dev → test-dev → review-code → (fix-dev → test-dev → review-code)* ) → commit-code → request-merge
```

1. **계획 수립**: `plan-dev` 스킬을 호출해 인터뷰로 계획을 수립한다. 완료 조건 라운드에서 TODO별 완료 조건·증거(`Acceptance Contract`)와 권한 경계·루프 예산(`Authority Boundaries`)을 함께 확정하고, 계획을 승인하면 PLAN/RESEARCH 파일이 `docs/agents/` 아래에 저장된다.
2. **루프 실행**: 승인된 플랜 경로를 지정해 `dev-loop` 스킬을 명시적으로 호출한다. 이후 `implement-dev → test-dev → review-code → (fix-dev → test-dev → review-code)*`가 종료 술어(TODO 완료 ∧ AC 증거 충족 ∧ 검증 green ∧ 차단 finding 0)를 만족할 때까지 자율 반복된다. 멀티스텝 플랜은 sub-plan(`-STEP-N`) 단위로 `dev-loop`를 호출한다.
3. **중간 개입은 두 경우뿐**: (a) 리뷰에서 HIGH/CRITICAL이 발견되면 항목별 Fix/Accept 분류 질문에 답한다 — Accept 항목은 `AGENTS.md`의 `Accepted Review Exceptions`에 기록되어 다음 리뷰부터 Waived(`Applied Exceptions`)로 강등 표시되고 차단 finding으로 계산되지 않는다. (b) blocked·예산 소진·no-progress로 에스컬레이션되면 지시를 내린다 — 방향 문제면 `plan-dev`로 재진입한다.
4. **완료 확인과 커밋**: 루프는 READY_TO_COMMIT에서 멈춘다. Implementation Report와 LOOP 상태 파일을 확인한 뒤 `commit-code`, 필요 시 `request-merge`를 직접 호출한다 — 커밋·푸시·PR/MR 생성은 루프 권한 밖이다.
5. **중단·재개**: 루프가 중간에 끊겨도 상태는 `docs/agents/dev/*_LOOP_*.md`에 남으므로, 같은 플랜으로 `dev-loop`를 다시 호출하면 마지막 라운드에서 이어서 진행한다.

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
| `implement-dev` | 승인된 플랜을 TDD(Red-Green-Refactor)로 구현하고 AC별 증거를 수집. 방향 충돌 시 `blocked` 반환 | Dispatcher → `implementer` Worker | 코드 + IMPL 리포트 (`## TODO Fulfillment` 축) |
| `fix-dev` | 리뷰·검증에서 발견된 결함을 한 건씩 원인 분석·수정·검증. 커밋하지 않음 | Dispatcher → Worker | IMPL 리포트에 `## Fix` 누적 |
| `test-dev` | git scope(기본: `main` 대비 diff) 기준으로 유닛/E2E 갭 채움과 mutation LIVED 제거. production 코드는 불변 | Dispatcher → Worker | 테스트 코드 (파일 아티팩트 없음) |
| `review-code` | 4 리뷰 페르소나 병렬 dispatch 후 finding 종합. HIGH/CRITICAL은 사용자 Fix/Accept 트리아지, Accept는 AR로 기록해 이후 리뷰에서 Waived 강등 | Dispatcher → 4 reviewers | finding 리포트, `Accepted Review Exceptions` |
| `review-code-claude` | 명시적 `$review-code-claude` 호출에만 Claude Code의 `review-code`를 별도 읽기 전용 프로세스로 실행하고 Codex에서 트리아지 | Codex → Claude CLI → 4 Claude reviewers | finding 리포트, `Accepted Review Exceptions` |
| `dev-loop` | 승인된 플랜(AC·AB 필수)으로 구현→테스트→리뷰→fix 사이클을 종료 술어 충족까지 자율 반복, READY_TO_COMMIT에서 정지. 트리아지·AR 승인·커밋은 사람 몫 | 메인 세션 (각 단계 스킬의 Dispatcher 흐름 호출) | LOOP 파일 (append-only) |
| `commit-code` | 수정된 파일 기반 커밋 생성 + 커밋 후 문서 드리프트 검사(읽기 전용 보고) | 메인 세션 | 커밋 |
| `request-merge` | `gh`(personal) / `glab`(work)로 PR/MR 생성·업데이트 | 메인 세션 | PR/MR |

**Misc:**

| 스킬 | 설명 | 산출물 |
| --- | --- | --- |
| `spec-creator` | 신규 프로젝트 요구사항을 단계적 인터뷰로 정리 | 한국어 SPEC.md |
| `setup-initial-repo` | SPEC.md 기반 신규 저장소 부트스트랩 — 지침 파일, 빌드 스크립트, .gitignore, git identity, remote origin | 초기 레포 스캐폴드 |
| `application-research-sync` | 코드 변경을 분석해 Research 파일 일괄 갱신 (index 먼저, 필요한 본문만) | `docs/agents/research/*` |
| `learn-from-manual-edits` | 에이전트 작성 코드 위의 사용자 수동 편집에서 일반 선호를 추론해 컨벤션으로 기록 | CLAUDE.md/AGENTS.md 컨벤션 섹션 |
| `find-docs` | 라이브러리/프레임워크 공식 문서를 Context7(`ctx7`)로 조회. Context7이 자동 설치하는 서드파티 스킬(이 harness가 직접 작성한 것이 아님) | 없음 (채팅 보고) |
| `loki-log-search` | Grafana Loki 로그를 `gcx api` 경유로 조회 | 없음 (채팅 보고) |

### Custom Agents

`agents/<platform>/`의 persona 서브에이전트 정의. 포맷은 Claude Code가 Markdown(YAML frontmatter), Codex가 TOML이다. 사용자가 직접 호출하기보다 스킬이 위임(dispatch)하는 것이 기본이다.

| 에이전트 | 페르소나 · 담당 | 호출 스킬 | 권한 |
| --- | --- | --- | --- |
| `planner` | 소프트웨어 아키텍트 — 방향·경계·인터페이스·리스크 검토, 사용자에게 물을 질문 목록 반환, 플랜 초안 리뷰 | `plan-dev` (모호·횡단·아키텍처 민감 작업에서 조건부) | 읽기 전용 |
| `implementer` | 최소 코드 규율(minimal-code discipline)의 구현 Worker — 스코프 재논의 없음 | `implement-dev` | 편집 가능 |
| `security-reviewer` | 보안 축 — authn/authz, 비밀 처리, 주입, 암호화 오용, TOCTOU | `review-code` (4축 병렬) | 읽기 전용 |
| `reliability-reviewer` | 신뢰성 축 — 오류 처리, 리소스 수명, 동시성, 타임아웃, 부분 실패 | `review-code` (4축 병렬) | 읽기 전용 |
| `maintainability-reviewer` | 유지보수성 축 — 스타일 일관성, 추상화 적정성, 네이밍, 모듈 경계, dead code | `review-code` (4축 병렬) | 읽기 전용 |
| `senior-generalist-reviewer` | 나머지 ISO 25010 축 — 성능, 호환성, UX, 기능 적합성, 운영 안전성 | `review-code` (4축 병렬) | 읽기 전용 |

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

## Scripts

`scripts/`에는 설치·동기화 스크립트 4개가 있다. `apply-to-*.sh`는 이 레포의 소스 변형을 사용자 홈의 실제 에이전트 환경으로 배포하고, `setup-ctx7.sh`는 반대로 외부 생성물을 레포 소스에 반영한다. 설치 대상 디렉토리는 기존 내용을 비운 뒤 다시 채우는 방식이라, 홈 디렉토리에서 직접 수정한 스킬·에이전트·훅은 다음 실행 때 소스 기준으로 덮어써진다.

### apply-to-personal.sh

Personal 환경(Claude Code) 설치 스크립트다.

- Claude Code: `instructions/AGENTS.md`를 `~/.claude/CLAUDE.md`로 복사하고, `~/.claude/skills`·`~/.claude/agents`·`~/.claude/hooks`를 비운 뒤 각각 `skills/claude/`·`agents/claude/`·`hooks/claude/hooks/`의 내용으로 다시 채운다.
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
