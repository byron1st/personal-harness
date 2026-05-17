# My personal harness

개인 사용 목적으로 만든 Agent Skills 와 Global instruction, 그리고 설치 스크립트.

## 폴더 구조

- **skills**: 개인 Agent Skills를 모아놓은 디렉토리. 각 스킬은 별도의 폴더로 관리된다.
- **instructions**: Claude Code, OpenCode, Codex 등 에이전트 실행 시 사용할 전역 명령어와 개발 원칙을 정의하는 `AGENTS.md` 파일을 포함한다.
- **scripts**: 스킬과 전역 명령어를 여러 에디터/에이전트에 설치·동기화하는 배포 스크립트를 포함한다.

## Skills

### Core Development Process

- `plan-dev`: 호스트 에이전트(Claude Code, Codex, OpenCode 등)의 내장 Plan 모드를 활용해 구현 플랜을 수립하고 Obsidian에 저장한다. 필요 시 다단계(main + sub-plans) 플랜으로 분할한다. 
- `implement-dev`: `plan-dev`가 생성한 구현 플랜을 실행(TDD Red-Green-Refactor)해 코드를 작성하고 Obsidian에 완료 보고서를 저장한다. 단일 단계/다단계 플랜을 자동 인식하며, 다단계 모드에서는 각 step을 sub-agent에 위임해 메인 세션 컨텍스트를 깨끗하게 유지한다.
- `test-dev`: `implement-dev` 이후(혹은 코드베이스 전체)의 테스트 스위트를 보강한다. 유닛/E2E 테스트 갭 채우기와 mutation testing의 LIVED mutant 제거를 순차적으로 수행한다.
- `review-code`: 보안·신뢰성·유지보수성 관점에서 코드 변경(diff, PR, 브랜치 등)을 리뷰한다.
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
