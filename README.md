# My personal harness

개인 사용 목적으로 만든 Agent Skills 와 Global instruction, 그리고 설치 스크립트.

## 폴더 구조

- **skills**: 개인 Agent Skills를 모아놓은 디렉토리. 각 스킬은 별도의 폴더로 관리된다.
- **agents**: 커스텀 sub-agent 정의 모음. 플랫폼별 서브 디렉토리(`agents/claude/`, `agents/codex/`, `agents/opencode/` 등)로 구분된다. 리뷰나 플래닝처럼 스킬 또는 사용자가 위임하는 persona 에이전트들이 여기에 들어간다.
- **hooks**: 플랫폼별 Hook 정의와 실행 스크립트 모음. 예: `hooks/claude/`에는 Claude Code의 `settings.json` 스니펫과 hook 스크립트(`hooks/claude/hooks/*.sh`)가 들어 있고, `hooks/codex/`에는 Codex의 `hooks.json`과 hook 스크립트(`hooks/codex/hooks/*.sh`)가 들어있으며, `hooks/opencode/`에는 OpenCode의 JS plugin(`hooks/opencode/personal-harness.js`)이 들어있다. SessionStart/sessionStart/session.created 훅은 `WORK_GITLAB_HOST`와 origin remote로 work/personal repo를 판별해 세션 컨텍스트로 주입하고, 코드/파일 검색은 `rg`(ripgrep)와 `fd` 사용을 강제하므로 [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd) 설치가 필요하다.
- **instructions**: Claude Code, Codex, OpenCode 실행 시 사용할 전역 명령어와 개발 원칙을 정의하는 `AGENTS.md` 파일을 포함한다.
- **scripts**: 스킬과 전역 명령어를 여러 에디터/에이전트에 설치·동기화하는 배포 스크립트를 포함한다.

플랫폼 변형은 **Claude ↔ Codex**, 그리고 **Claude → OpenCode** 토폴로지로 마이그레이션한다. Personal 환경의 중심은 Claude Code이고 Work 환경의 중심은 Codex이므로, Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. OpenCode는 Personal의 하위 변형이므로 Claude Code에서만 파생되며 OpenCode를 소스로 쓰는 역방향은 지원하지 않는다. 각 단계의 변환 규칙은 [MIGRATE_TO_CODEX.md](MIGRATE_TO_CODEX.md)(Claude → Codex), [MIGRATE_TO_CLAUDE.md](MIGRATE_TO_CLAUDE.md)(Codex → Claude Code), [MIGRATE_TO_OPENCODE.md](MIGRATE_TO_OPENCODE.md)(Claude → OpenCode)에 정리되어 있다.

> Cursor 연동: 이 harness는 Cursor 변형을 직접 제공하지 않는다. Cursor 사용자는 [opencode-cursor](https://github.com/Nomadcxx/opencode-cursor)를 이용해 OpenCode 환경을 Cursor에 연동해 사용한다.

## Prerequisites

이 harness의 skills·hooks·설치 스크립트가 정상 동작하려면 아래 CLI 도구들이 PATH에 설치되어 있어야 한다. 플랫폼별로 일부 도구는 필수가 아닐 수 있으므로 각 항목의 적용 범위를 확인한다.

| 도구 | 적용 범위 | 용도 | 설치 |
| --- | --- | --- | --- |
| `jq` | 전체(Claude/Codex shell hook + `apply-to-personal.sh`) | hook 입력 파싱, `settings.json` 머지, `loki-log-search`의 LogQL URL 인코딩 | `brew install jq` |
| `git` | 전체 shell hook 및 `commit-code` | 세션 컨텍스트 분류, git identity 검증, 커밋 후 문서 드리프트 검사 | `brew install git` |
| `make` | 전체 `auto-format` hook | 프로젝트 Makefile의 `fmt`/`format` 타겟 실행 | macOS: Xcode Command Line Tools, Linux: `build-essential` |
| `rg` (ripgrep) | 전체 `enforce-rg` hook + AGENTS.md | 재귀 `grep` 대신 코드 검색 강제 | `brew install ripgrep` |
| `fd` | 전체 `enforce-fd` hook + AGENTS.md | 파일명/경로 검색용 `find` 대체 강제 | `brew install fd` |
| `node` | OpenCode plugin(`hooks/opencode/personal-harness.js`) | OpenCode용 JS plugin 실행 | `brew install node` 또는 Node Version Manager |
| `ctx7` | AGENTS.md context7 룰 + `scripts/setup-ctx7.sh` | 라이브러리/프레임워크 공식 문서 fetch | `npm install -g ctx7` 후 `ctx7 login`(또는 `CONTEXT7_API_KEY` 설정) |
| `gh` | `request-merge`(personal), `setup-initial-repo`(personal 원격 생성) | GitHub PR 생성/업데이트, 개인 private repo 자동 생성 | `brew install gh` 후 `gh auth login` |
| `glab` | `request-merge`(work) | GitLab MR 생성/업데이트 | `brew install glab` 후 `glab auth login` |
| `gcx` | `loki-log-search` | Grafana Loki 로그 조회용 `gcx api` passthrough | `gcx` 배포본 설치 후 `gcx config current-context`로 컨텍스트 구성 |

참고:
- `rg`/`fd`는 이미 폴더 구조 설명의 `hooks` 항목에서 언급한 대로 hook이 사용을 강제하므로 반드시 설치해야 한다.
- `gh`·`glab`는 각각 personal/work 저장소에서만 호출되므로, 사용하지 않는 저장소 유형의 도구는 생략 가능하다.
- 프로젝트 템플릿(`skills/*/setup-initial-repo/references/{go-makefile.md,swift-makefile.md,ts-nextjs-packagejson.md}`)이 `setup-initial-repo`로 참조될 때 함께 따라가는 `go`, `golangci-lint`, `mockery`, `gremlins`, `swag`, `swiftlint`, `swiftformat`, `eslint`, `vitest`, `playwright`, `stryker` 등은 생성되는 프로젝트의 빌드 도구이지 이 harness 자체의 prerequisite은 아니다.

## Skills

### Core Development Process

기본 개발 흐름은 다음 체인으로 조립된다. 각 스킬은 단독 사용도 가능하지만, 보통 앞 스킬이 만든 산출물(플랜 / 구현 결과 / 리뷰 코멘트 등)을 다음 스킬이 입력으로 받는다.

```
plan-dev → implement-dev → (이슈 발견 시 fix-dev 반복) → test-dev → review-code → (이슈 발견 시 fix-dev 반복) → commit-code → request-merge
```

- `plan-dev`: 호스트 에이전트(Claude Code, Codex, OpenCode)의 내장 Plan 모드를 활용해 구현 플랜을 수립하고 프로젝트 루트의 `docs/agents/dev`와 `docs/agents/research`에 저장한다. 필요 시 다단계(main + sub-plans) 플랜으로 분할한다.
- `implement-dev`: `plan-dev`가 생성한 구현 플랜을 실행(TDD Red-Green-Refactor)해 코드를 작성하고 `docs/agents/dev`에 완료 보고서를 저장한다. 실행 모드는 두 가지다. (1) 기본인 Dispatcher 모드 — 메인 세션이 직접 코드/테스트/리포트를 편집하지 않고, `worker-contract.md`의 표준 프롬프트로 `implementer` Worker 1개를 띄워 구현을 위임하고, Worker가 고정 `##` 헤딩으로 반환한 상태를 파싱해 사용자에게 짧은 요약과 리포트 링크만 전달한다. (2) Worker 모드 — 위 위임 프롬프트로 호출된 서브에이전트가 구현 흐름을 직접 실행하고(재-dispatch 없음) 고정 헤딩의 반환 메시지를 돌려준다. 완료 보고서는 `## TODO Fulfillment`를 축으로 TODO별 구현/테스트/편차를 묶어 제공하며, 방향 충돌 시 Worker는 `blocked`와 필요한 결정을 반환하고 인터랙티브 실행 시에는 사용자에게 직접 묻는다.
- `fix-dev`: 리뷰 단계(단일 step 구현 완료 직후, 또는 다단계 step 사이)에서 발견된 결함을 원인 분석·수정·검증까지 처리하고 결과를 요약한다. 지원 플랫폼 또는 명시적 위임 요청이 있는 Codex 세션에서는 sub-agent에 위임할 수 있다. 수정 후에는 해당 Implementation Report 끝에 `## Fix` 섹션을 누적해 변경 내역을 기록한다. 커밋은 하지 않고 working tree를 그대로 둔다(커밋은 흐름의 마지막 `commit-code` 단계에서).
- `test-dev`: `implement-dev` 이후의 변경이나 사용자가 지정한 범위를 **git 기준 scope**(기본: `main` 대비 diff)로 잡아 테스트 스위트를 보강한다. 유닛/E2E 테스트 갭 채우기와 mutation testing의 LIVED mutant 제거를 순차적으로 수행하며, production/business logic은 수정하지 않는다. 지원 플랫폼에서는 메인 세션이 scope·검증 명령을 정리한 뒤 단일 delegated subagent에 실제 테스트 수정을 맡기는 Dispatcher 흐름을 사용할 수 있고, Codex에서는 명시적 위임 요청이 있을 때만 delegation을 사용한다.
- `review-code`: 보안·신뢰성·유지보수성을 포함한 ISO 25010 품질 속성 관점에서 코드 변경(diff, PR, 브랜치 등)을 리뷰한다. 지원 플랫폼 또는 명시적 위임 요청이 있는 Codex 세션에서는 네 persona 에이전트(`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`)를 병렬 dispatch하고 finding을 종합한다. Codex에서 위임 요청이 없으면 메인 세션이 같은 네 축으로 리뷰한다.
- `commit-code`: 현재 수정된 파일을 기반으로 커밋을 생성한다.
- `request-merge`: `gh` 또는 `glab` CLI를 사용해 Pull Request / Merge Request를 생성하거나 업데이트한다.

### Misc

- `spec-creator`: 신규 소프트웨어 프로젝트의 요구사항을 단계적으로 정리해 한국어 SPEC.md 문서를 만든다.
- `setup-initial-repo`: SPEC.md 문서를 기반으로 신규 프로젝트 저장소를 부트스트랩한다. CLAUDE.md/AGENTS.md, Makefile 또는 package.json scripts, .gitignore 생성 및 적절한 Git identity로 `git init`과 remote origin 연결까지 수행한다.
- `application-research-sync`: 코드 변경 사항을 분석해 `docs/agents/research`의 Research 파일을 일괄 업데이트한다. Research 검색은 `docs/agents/research/index.md`의 메타데이터와 파일 링크를 먼저 읽고 필요한 본문만 여는 방식으로 수행한다.
- `learn-from-manual-edits`: 에이전트가 작성한 코드 위에 사용자가 직접 수정한 부분을 식별해 각 수정 배경의 일반적인 선호(스타일·아키텍처·네이밍 등)를 추론하고, 프로젝트의 CLAUDE.md(Claude Code) 또는 AGENTS.md(Codex/OpenCode)에 재사용 가능한 컨벤션으로 기록한다.
- `loki-log-search`: Grafana Loki 로그를 `gcx api` 경유로 조회한다.

## 환경변수

Skills 실행에 필요한 환경변수 목록. 각 Agent 의 환경변수 설정에 등록되어 있어야 한다 (예: Claude Code 의 settings.json 파일 내 `env` 설정, Codex 의 config.toml 파일 내 `shell_environment_policy` 항목의 `set` 설정, 또는 OpenCode 의 opencode.json 설정)

- `PERSONAL_GIT_EMAIL`: 개인 저장소 커밋 시 사용할 Git 이메일
- `PERSONAL_GIT_NAME`: 개인 저장소 커밋 시 사용할 Git 이름
- `WORK_GIT_EMAIL`: 회사 저장소 커밋 시 사용할 Git 이메일
- `WORK_GIT_NAME`: 회사 저장소 커밋 시 사용할 Git 이름
- `WORK_GITLAB_HOST`: 회사 GitLab 호스트 주소 (저장소 구분에 사용)
- `WORK_GITLAB_USERNAME`: 회사 GitLab 사용자명 (MR 생성 시 --assignee 옵션에 사용)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: 회사 GitLab 기본 리뷰어 (MR 생성 시 --reviewer 옵션에 사용)

## Scripts

### apply-to-personal.sh / apply-to-work.sh

스킬과 전역 명령어를 개인용 Claude Code/OpenCode 환경과 업무용 Codex 환경에 나누어 설치·동기화하는 스크립트다.

**동작:**
- `scripts/apply-to-personal.sh`는 Claude Code와 OpenCode 설치 스크립트다. `skills/claude/` 디렉토리의 스킬을 `~/.claude/skills`로 복사하고, `instructions/AGENTS.md` 파일을 `~/.claude/CLAUDE.md`로 복사한다.
- Claude Code 전용으로 `agents/claude/*`를 `~/.claude/agents/`로, `hooks/claude/hooks/*`를 `~/.claude/hooks/`로 동기화한다.
- `hooks/claude/settings.json`의 `hooks` 블록을 `~/.claude/settings.json`에 `jq`로 머지한다. 사용자의 `permissions`/`model`/`env` 등 다른 설정은 보존되며, 대상 파일이 없으면 통째로 생성한다 (jq 필요).
- OpenCode 전용으로 `skills/opencode/`를 `~/.config/opencode/skills/`로, `agents/opencode/*`를 `~/.config/opencode/agents/`로 동기화하고, `instructions/AGENTS.md`를 `~/.config/opencode/AGENTS.md`로 복사한다. `hooks/opencode/personal-harness.js`를 `~/.config/opencode/personal-harness.js`로 설치하며, `~/.config/opencode/opencode.jsonc`가 있으면 이를 우선 사용하고 없으면 `opencode.json`에 plugin을 등록한다.
- `scripts/apply-to-work.sh`는 Codex 전용 설치 스크립트다. `skills/codex/` 디렉토리의 스킬을 `~/.agents/skills`로 복사하고, `instructions/AGENTS.md` 파일을 `~/.codex/AGENTS.md`로 복사한다.
- Codex 전용으로 `~/.codex/agents/`를 정리한 뒤 `agents/codex/*.toml`을 동기화한다.
- Codex 전용으로 `~/.codex/hooks/`를 정리한 뒤 `hooks/codex/hooks/*`를 동기화하고, `hooks/codex/hooks.json`을 `~/.codex/hooks.json`으로 복사한다.
- 관리 대상 설치 파일을 최신 상태로 갱신한다.
