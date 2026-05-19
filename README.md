# My personal harness

개인 사용 목적으로 만든 Agent Skills 와 Global instruction, 그리고 설치 스크립트.

## 폴더 구조

- **skills**: 개인 Agent Skills를 모아놓은 디렉토리. 각 스킬은 별도의 폴더로 관리된다.
- **agents**: 커스텀 sub-agent 정의 모음. 플랫폼별 서브 디렉토리(`agents/claude/` 등)로 구분된다. 스킬이 일부 단계를 위임할 때 dispatch하는 persona 에이전트들이 여기에 들어간다.
- **hooks**: 플랫폼별 Hook 정의와 실행 스크립트 모음. 예: `hooks/claude/`에는 Claude Code의 `settings.json` 스니펫과 hook 스크립트(`hooks/claude/hooks/*.sh`)가 들어있다. 코드/파일 검색은 `rg`(ripgrep)와 `fd` 사용을 강제하므로 [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd) 설치가 필요하다.
- **instructions**: Claude Code, OpenCode, Codex 등 에이전트 실행 시 사용할 전역 명령어와 개발 원칙을 정의하는 `AGENTS.md` 파일을 포함한다.
- **scripts**: 스킬과 전역 명령어를 여러 에디터/에이전트에 설치·동기화하는 배포 스크립트를 포함한다.

## Skills

### Core Development Process

기본 개발 흐름은 다음 체인으로 조립된다. 각 스킬은 단독 사용도 가능하지만, 보통 앞 스킬이 만든 산출물(플랜 / 구현 결과 / 리뷰 코멘트 등)을 다음 스킬이 입력으로 받는다.

```
plan-dev → implement-dev → (이슈 발견 시 fix-dev 반복) → test-dev → review-code → (이슈 발견 시 fix-dev 반복) → commit-code → request-merge
```

- `plan-dev`: 호스트 에이전트(Claude Code, Codex, OpenCode 등)의 내장 Plan 모드를 활용해 구현 플랜을 수립하고 Obsidian에 저장한다. 필요 시 다단계(main + sub-plans) 플랜으로 분할한다.
- `implement-dev`: `plan-dev`가 생성한 구현 플랜을 실행(TDD Red-Green-Refactor)해 코드를 작성하고 Obsidian에 완료 보고서를 저장한다. 단일 단계/다단계 플랜을 자동 인식하며, 다단계 모드에서는 각 step을 sub-agent에 위임해 메인 세션 컨텍스트를 깨끗하게 유지한다.
- `fix-dev`: 리뷰 단계(단일 step 구현 완료 직후, 또는 다단계 step 사이)에서 발견된 결함을 sub-agent에 위임해 원인 분석·수정·검증까지 마치고 결과 요약만 메인 세션에 반환한다. 수정 후에는 해당 Implementation Report 끝에 `## Fix` 섹션을 누적해 변경 내역을 기록한다. 명시적 요청이 없으면 커밋은 하지 않는다.
- `test-dev`: `implement-dev` 이후(혹은 코드베이스 전체)의 테스트 스위트를 보강한다. 유닛/E2E 테스트 갭 채우기와 mutation testing의 LIVED mutant 제거를 순차적으로 수행한다.
- `review-code`: 보안·신뢰성·유지보수성을 포함한 ISO 25010 품질 속성 관점에서 코드 변경(diff, PR, 브랜치 등)을 리뷰한다. 메인 세션은 오케스트레이터로서 컨텍스트를 한 번 수집한 뒤, `security-reviewer` / `reliability-reviewer` / `maintainability-reviewer` / `senior-generalist-reviewer` 네 persona 에이전트를 병렬 dispatch하고 finding을 종합한다.
- `commit-code`: 현재 수정된 파일을 기반으로 커밋을 생성한다.
- `request-merge`: `gh` 또는 `glab` CLI를 사용해 Pull Request / Merge Request를 생성하거나 업데이트한다.

### Misc

- `setup-initial-repo`: SPEC.md 문서를 기반으로 신규 프로젝트 저장소를 부트스트랩한다. CLAUDE.md/AGENTS.md, 언어별 컨벤션 docs, Makefile, .gitignore 생성 및 적절한 Git identity로 `git init`과 remote origin 연결까지 수행한다.
- `application-research-sync`: 코드 변경 사항을 분석해 Obsidian Vault의 Research 파일을 일괄 업데이트한다.
- `summarize-week`: Obsidian의 Daily note와 플랜·Research 문서를 읽어 주간 코딩 요약을 작성한다.

## 환경변수

Skills 실행에 필요한 환경변수 목록. 각 Agent 의 환경변수 설정에 등록되어 있어야 한다 (예: Claude Code 의 settings.json 파일 내 `env` 설정 또는 Codex 의 config.toml 파일 내 `shell_environment_policy` 항목의 `set` 설정)

- `OBSIDIAN_HOME`: Obsidian Vault의 루트 디렉토리 경로
- `PERSONAL_GIT_EMAIL`: 개인 저장소 커밋 시 사용할 Git 이메일
- `PERSONAL_GIT_NAME`: 개인 저장소 커밋 시 사용할 Git 이름
- `WORK_GIT_EMAIL`: 회사 저장소 커밋 시 사용할 Git 이메일
- `WORK_GIT_NAME`: 회사 저장소 커밋 시 사용할 Git 이름
- `WORK_GITLAB_HOST`: 회사 GitLab 호스트 주소 (저장소 구분에 사용)
- `WORK_GITLAB_USERNAME`: 회사 GitLab 사용자명 (MR 생성 시 --assignee 옵션에 사용)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: 회사 GitLab 기본 리뷰어 (MR 생성 시 --reviewer 옵션에 사용)

## Scripts

### apply-to-global.sh

스킬과 전역 명령어를 Claude Code, Cursor, OpenCode, Codex 등 여러 에이전트 플랫폼에 설치·동기화하는 스크립트다.

**동작:**
- `skills/` 디렉토리의 모든 스킬을 `~/.claude/skills`, `~/.cursor/skills`, `~/.agents/skills`로 복사한다.
- `instructions/AGENTS.md` 파일을 각 플랫폼의 설정 디렉토리에 `CLAUDE.md`, `AGENTS.md` 형식으로 복사한다.
- 기존 설치 파일을 정리한 후 최신 상태로 갱신한다.
