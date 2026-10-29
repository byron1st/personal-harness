# My personal harness

[English](README.md) | **한국어**

개인 사용 목적의 Agent Skills · 전역 지침 · 훅 · 설치 스크립트 하네스.

회사 업무는 쿼터를 **Cursor → Claude → Codex** 순으로 소진한다(승인 마찰이 가벼운 풀부터). 개인 프로젝트는 **Grok Build**(SuperGrok 구독 쿼터)를 쓴다.

## 사용법

이 하네스는 개발 흐름을 강제하지 않는다. 무엇을 만들지 — "완료"가 무엇인지, 범위 밖은 무엇인지, 건드리면 안 되는 것은 무엇인지 — 를 전달하고, 계획과 구현은 모델이 자기 방식대로 하게 둔다. 스킬은 모델이 스스로 알 수 없는 것만 채운다: 도구·환경 지식, 그리고 "완료"를 검사 가능하게 만드는 몇 가지 습관. 선택적 단계는 [Development](#development)를 본다.

이전의 루프 기반 하네스(plan → implement → test → review 상태 머신, persona 서브에이전트, 모델 티어 핀)는 `pre-lean-harness` git 태그에 보존되어 있다.

## 폴더 구조

```
personal-harness/
├── skills/           # 공유 Agent Skills (스킬마다 별도 폴더; ~/.agents/skills 로 설치)
├── hooks/            # 플랫폼별 훅 (claude: settings.json + *.sh · codex/cursor/grok: hooks.json + *.sh)
├── instructions/     # 전역 지침 AGENTS.md 배포 소스
├── scripts/          # 설치 스크립트 (apply-to.sh · apply-to-{claude,codex,cursor,grok}.sh · apply-to-all.sh · setup-ctx7.sh)
└── docs/             # 하네스 문서 (sync-harness/: SYNC_TO_* 훅 변환 규칙)
```

훅의 상세 동작은 [Harness > Hooks](#hooks) 참조. 훅이 `rg`/`fd` 사용을 강제하므로 [ripgrep](https://github.com/BurntSushi/ripgrep)과 [fd](https://github.com/sharkdp/fd) 설치가 필요하다(Prerequisites 참조).

스킬은 공유한다 (`skills/<name>/` → `~/.agents/skills`). 훅은 **Claude ↔ Codex**(양방향) + **Claude → Cursor**(단방향) + **Claude → Grok Build**(단방향, pure 경로)로 마이그레이션한다. Grok Build는 Claude 호환 경로를 쓰지 않는다. Cursor·Grok에서 시작한 훅 변경도 Claude 변형에 먼저 반영한 뒤 내려보낸다. 별도의 동기화 스킬은 없다 — 에이전트가 해당 체크리스트를 읽고 직접 적용한다. 변환 규칙은 [SYNC_TO_CODEX.md](docs/sync-harness/SYNC_TO_CODEX.md), [SYNC_TO_CLAUDE.md](docs/sync-harness/SYNC_TO_CLAUDE.md), [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md), [SYNC_TO_GROK.md](docs/sync-harness/SYNC_TO_GROK.md)에 정리되어 있다.

## Prerequisites

이 harness의 skills·hooks·설치 스크립트가 정상 동작하려면 아래 CLI 도구들이 PATH에 설치되어 있어야 한다. 플랫폼별로 일부 도구는 필수가 아닐 수 있으므로 각 항목의 적용 범위를 확인한다.

| 도구 | 적용 범위 | 용도 | 설치 |
| --- | --- | --- | --- |
| `jq` | 전체(Claude/Codex shell hook + `apply-to-claude.sh`) | hook 입력 파싱, `settings.json` 머지, `loki-log-search`의 LogQL URL 인코딩 | `brew install jq` |
| `git` | 전체 shell hook 및 `commit-code` | 세션 컨텍스트 분류, git identity 검증, 커밋 후 문서 드리프트 검사 | `brew install git` |
| `make` | 전체 `auto-format` hook | 프로젝트 Makefile의 `fmt`/`format` 타겟 실행 | macOS: Xcode Command Line Tools, Linux: `build-essential` |
| `rg` (ripgrep) | 전체 `enforce-rg` hook + AGENTS.md | 재귀 `grep` 대신 코드 검색 강제 | `brew install ripgrep` |
| `fd` | 전체 `enforce-fd` hook + AGENTS.md | 파일명/경로 검색용 `find` 대체 강제 | `brew install fd` |
| `ctx7` | AGENTS.md context7 룰 + `scripts/setup-ctx7.sh` | 라이브러리/프레임워크 공식 문서 fetch | `npm install -g ctx7` 후 `ctx7 login`(또는 `CONTEXT7_API_KEY` 설정) |
| `codegraph` | AGENTS.md CodeGraph 룰 + `setup-initial-repo` | 코드 인텔리전스 인덱스, `setup-initial-repo`가 새 저장소에서 `codegraph init` 실행 | `npm install -g @colbymchenry/codegraph` |
| `gh` | `commit-code`(personal PR 경로), `setup-initial-repo`(personal 원격 생성) | GitHub PR 생성/업데이트, 개인 private repo 자동 생성 | `brew install gh` 후 `gh auth login` |
| `glab` | `commit-code`(work MR 경로), `notion-daily-briefing` | GitLab MR 생성/업데이트, 어제 요약용 MR·커밋 읽기 전용 검색 | `brew install glab` 후 `glab auth login` |
| `gcx` | `loki-log-search` | Grafana Loki 로그 조회용 `gcx api` passthrough | `gcx` 배포본 설치 후 `gcx config current-context`로 컨텍스트 구성 |
| `acli` | `notion-daily-briefing` | Jira 티켓 조회(search/view/comment list)용 Atlassian CLI (읽기 전용) | `brew tap atlassian/homebrew-acli && brew install acli` 후 `acli jira auth login --web` |
| `ntn` | `notion-daily-briefing`, `notion-cli` | Daily Note 조회·생성·markdown 수정용 Notion CLI | `curl -fsSL https://ntn.dev \| bash` 후 `ntn login` |
| Cursor 2.4+ | Cursor 변형 전체 | Agent Skills, `hooks.json` | Cursor 앱 업데이트 |
| `grok` (Grok Build 0.2+) | Grok 변형 전체 | `~/.grok/{skills,hooks,rules}`, SuperGrok 구독 권장 | [Grok Build CLI 설치](https://x.ai/cli) 후 `grok login` |

참고:
- `rg`/`fd`는 이미 폴더 구조 설명의 `hooks` 항목에서 언급한 대로 hook이 사용을 강제하므로 반드시 설치해야 한다.
- `gh`·`glab`는 각각 personal/work 저장소에서만 호출되므로, 사용하지 않는 저장소 유형의 도구는 생략 가능하다.
- 프로젝트 템플릿(`skills/*/setup-initial-repo/references/{go-makefile.md,swift-makefile.md,ts-nextjs-packagejson.md}`)이 `setup-initial-repo`로 참조될 때 함께 따라가는 `go`, `golangci-lint`, `mockery`, `gremlins`, `swag`, `swiftlint`, `swiftformat`, `eslint`, `vitest`, `playwright`, `stryker` 등은 생성되는 프로젝트의 빌드 도구이지 이 harness 자체의 prerequisite은 아니다.

### 1회성 필수 설정 (Cursor · Grok Build)

설치 스크립트가 대신 쓸 수 없는 UI/설정 파일 단계다. 새 머신·재설치·설정 초기화 때마다 다시 확인한다.

#### Cursor — `~/.claude` / `~/.codex` 호환 경로 끄기

Cursor는 `~/.cursor/`·`~/.agents/skills` 외에 **`~/.claude/`·`~/.codex/`의 스킬도 사용자 스코프로 읽는다.** 호환이 켜져 있으면 Claude 스킬 단위 심링크까지 읽어 공유 스킬이 모두 두 번 로드된다. 호환 경로 읽기는 **Cursor 설정(UI)** 이라 설치 스크립트가 보장할 수 없고, 되살아나도 **에러가 나지 않는다.**

**할 일:** Cursor 설정에서 Claude / Codex 호환(또는 “read from `~/.claude` / `~/.codex`”) 경로를 **끈다.** 설정 위치는 Cursor 버전에 따라 UI 라벨이 다를 수 있으니, Agents / Skills 관련 설정에서 호환 경로 옵션을 찾아 off 한다.

#### Grok Build — `[compat.claude]` · `[compat.cursor]` 끄기

Grok Build는 기본적으로 Claude/Cursor 경로를 `[compat.*]`로 읽을 수 있다. 이 harness는 **pure `~/.grok/{skills,hooks,rules}`와 `~/.agents/skills`만** 쓴다. compat가 켜져 있으면 `~/.claude/skills` 심링크 등이 섞여 같은 이름이 두 번 로드된다.

`~/.grok/config.toml`에 아래를 붙여 넣거나, 기존 블록이 있으면 값을 전부 `false`로 맞춘다.

```toml
# ~/.grok/config.toml — pure Grok 변형 (설치 스크립트가 설정하지 않음)
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

### 환경변수

Skills 실행에 필요한 환경변수 목록. 각 Agent 의 환경변수 설정에 등록되어 있어야 한다 (예: Claude Code 의 settings.json 파일 내 `env` 설정 또는 Codex 의 config.toml 파일 내 `shell_environment_policy` 항목의 `set` 설정)

- `PERSONAL_GIT_EMAIL`: 개인 저장소 커밋 시 사용할 Git 이메일
- `PERSONAL_GIT_NAME`: 개인 저장소 커밋 시 사용할 Git 이름
- `WORK_GIT_EMAIL`: 회사 저장소 커밋 시 사용할 Git 이메일
- `WORK_GIT_NAME`: 회사 저장소 커밋 시 사용할 Git 이름
- `WORK_GITLAB_HOST`: 회사 GitLab 호스트 주소 (저장소 구분에 사용, `notion-daily-briefing`의 `glab --hostname`도 이 값에서 도출)
- `WORK_GITLAB_USERNAME`: 회사 GitLab 사용자명 (MR 생성 시 --assignee 옵션에 사용)
- `WORK_GITLAB_DEFAULT_REVIEWERS`: 회사 GitLab 기본 리뷰어 (MR 생성 시 --reviewer 옵션에 사용)
- `NOTION_DAILY_NOTES_DS_ID`: Notion Daily Notes 데이터 소스 ID (`notion-daily-briefing`)
- `NOTION_DAILY_NOTE_TEMPLATE_ID`: Notion Daily Note 템플릿 ID (`notion-daily-briefing`)

## Development

```
plan-dev → 같은 세션에서 구현 → /goal <완료 조건> → test-dev (새 컨텍스트) → 리뷰 → commit-code
```

모든 단계는 선택이며 작업 크기에 맞춰 고른다. 한 문장짜리 변경에는 아무것도 필요 없고, 중간 크기 기능은 보통 `plan-dev`와 리뷰 한 번, 길거나 무인으로 돌릴 작업은 전부를 쓰면 좋다.

1. **계획** (`plan-dev`): 모델이 레포를 조사한 뒤, "완료"가 무엇인지(관찰 가능한 상태 + 증거), 범위 밖은 무엇인지, 건드리면 안 되는 것은 무엇인지를 사용자와 확정한다. "완료 조건" 항목은 하나의 완료 조건 문장으로 돌려준다. 플랜은 대화 안에 두고, 작업이 여러 세션에 걸치거나 다른 세션·도구로 넘길 때만 `docs/agents/dev/` 아래에 저장한다.
2. **구현**: 별도 실행자 없이 같은 세션에서 한다. 전역 지침이 완료 조건마다 증거를 보고하게 하고, 테스트 약화를 금지하며, 목표·범위·금지 영역을 바꾸는 결정에서만 멈추고 묻게 한다.
3. **끝까지 돌리기** (`/goal`, Claude Code): 완료 조건을 붙여 넣는다. 예: `/goal AC-1..N이 각각 대화에 보이는 명령 출력으로 통과, make test와 make lint가 0으로 종료, 기존 테스트 파일은 수정·삭제하지 않음 — 또는 15턴 후 중단`. 작은 평가 모델이 매 턴 조건을 확인하는데 대화만 보므로, 주장 대신 명령 출력을 요구한다. 무인 실행이면 auto mode와 함께 쓴다.
4. **테스트 보강** (`test-dev`): 작성자의 의도가 아니라 diff를 읽도록 새 컨텍스트(서브에이전트나 새 세션)에서 실행한다. 테스트 코드만 쓰고, 의심 결함은 production 코드를 고치지 않고 보고한다.
5. **리뷰**: 호스트 내장 리뷰를 쓴다 (Claude Code: `/code-review`; authn/authz·비밀·동시성·부분 실패 경로를 건드리면 `/security-review`도).
6. **커밋** (`commit-code`): PR/MR이 필요하면 그 호출에서 함께 요청한다 (`request-merge`는 라우팅 별칭).

## Harness

### Skills

각 스킬은 `skills/<name>/` 한곳에 두고 `~/.agents/skills`로 설치한다. Claude만 `~/.claude/skills/<name>` 스킬 단위 심링크를 건다. 상세 계약은 각 스킬의 `SKILL.md` 참조.

**Development:**

| 스킬 | 설명 | 산출물 |
| --- | --- | --- |
| `plan-dev` | 레포를 조사하고 완료 조건 / 범위 밖 / 건드리지 말 것을 사용자와 확정; 완료 조건을 goal 조건으로 제시 | 대화 안의 플랜; 여러 세션·인계 작업일 때만 `docs/agents/dev` 아래 파일 |
| `test-dev` | git scope(기본: `main` 대비 diff) 기준 새 컨텍스트 테스트 보강. 테스트 코드 전용; 의심 결함은 보고만 하고 고치지 않음 | 테스트 코드 (파일 아티팩트 없음) |
| `commit-code` | 수정된 파일 기반 커밋 생성 + 커밋 후 문서 드리프트 검사(읽기 전용 보고). 프롬프트가 요청할 때만 PR/MR 생성(`gh` personal / `glab` work; `request-merge`는 라우팅 별칭). dirty tree + PR 요청이면 먼저 커밋 | 커밋 · (선택) PR/MR |

**Misc:**

| 스킬 | 설명 | 산출물 |
| --- | --- | --- |
| `spec-creator` | 신규 프로젝트 요구사항을 단계적 인터뷰로 정리 | 한국어 SPEC.md |
| `setup-initial-repo` | SPEC.md 기반 신규 저장소 부트스트랩 — 지침 파일, 빌드 스크립트, .gitignore, git identity, remote origin | 초기 레포 스캐폴드 |
| `learn-from-manual-edits` | 에이전트 작성 코드 위의 사용자 수동 편집에서 일반 선호를 추론해 컨벤션으로 기록 | CLAUDE.md/AGENTS.md 컨벤션 섹션 |
| `chat-summary` | 대화 내용을 vault 기존 category/tag 어휘로 정리한 자기완결 Obsidian 노트(YAML frontmatter + 본문)로 작성 | Obsidian 노트 (.md) |
| `loki-log-search` | Grafana Loki 로그를 `gcx api` 경유로 조회 | 없음 (채팅 보고) |
| `notion-daily-briefing` | 오늘 Notion Daily Note를 확인·생성(템플릿)하고, `acli`로 내게 할당된 Done 아닌 Jira 티켓을 읽기 전용으로 요약해 "아침 브리핑" 섹션에 작성하고, 어제의 Jira 코멘트와 GitLab MR·커밋(`glab`, 읽기 전용)을 파란 콜아웃으로 정리하고, 전날(월요일이면 지난 금요일) 노트의 "할 일" 섹션을 오늘 노트에 그대로 복사 | 오늘 Notion Daily Note |

**외부 (공식, `skills/`에 vendoring하지 않음):** `apply-to.sh`가 [`EXTERNAL_SKILLS`](scripts/install-shared.sh)를 `npx skills add`로 설치한다.

| 스킬 | 출처 | 설명 |
| --- | --- | --- |
| `notion-cli` | `makenotion/skills` (Notion 공식) | Notion CLI(`ntn`)로 Notion API 호출, worker 배포, 파일 업로드 |

### Hooks

`hooks/<platform>/`의 훅 정의와 실행 스크립트. 공통 셸 훅(`hooks/<platform>/hooks/*.sh`):

| 훅 | 시점 | 역할 |
| --- | --- | --- |
| `session-context.sh` | 세션 시작 | `WORK_GITLAB_HOST`·origin remote로 work/personal repo 판별 후 세션 컨텍스트 주입 |
| `git-identity-guard.sh` | Bash 실행 전 | 커밋 시 git identity(이름/이메일)가 repo 유형에 맞는지 검증 |
| `enforce-rg.sh` | Bash 실행 전 | 코드 검색에 재귀 `grep` 대신 `rg` 강제 |
| `enforce-fd.sh` | Bash 실행 전 | 파일/경로 검색에 `find` 대신 `fd` 강제 |
| `auto-format.sh` | 파일 편집 후 | 프로젝트 Makefile의 `fmt`/`format` 타겟 실행 |

플랫폼별 설정 형식: Claude Code는 `hooks/claude/settings.json`의 `hooks` 블록, Codex·Cursor·Grok은 각각 `hooks.json`을 사용한다(스키마가 다르다 — Cursor는 평평한 배열, [SYNC_TO_CURSOR.md](docs/sync-harness/SYNC_TO_CURSOR.md) 참조; Grok은 `~/.grok/hooks/harness.json`으로 설치되고 `~/.grok/hooks/*.json`을 머지). 훅은 정책을 강제하는 가드레일이지 작업 흐름이 아니다.

## Scripts

`scripts/`에는 설치 스크립트가 있다. `apply-to-*.sh`는 이 레포의 소스 변형을 사용자 홈의 실제 에이전트 환경으로 배포하고, `setup-ctx7.sh`는 반대로 외부 생성물을 레포 소스에 반영한다. harness 소유 설치 대상은 기존 내용을 비운 뒤 다시 채우는 방식이라, 홈 디렉토리에서 직접 수정한 스킬·훅은 다음 실행 때 소스 기준으로 덮어써진다.

하네스가 더 이상 배포하지 않는 스킬·에이전트·런타임 스크립트는 `scripts/install-shared.sh`의 `RETIRED_SKILLS` · `RETIRED_AGENTS` · `RETIRED_SCRIPTS`에 나열되어 있다. 설치 스크립트가 모든 설치 대상에서 그 이름들을 지우므로, 업그레이드한 머신에서는 더 이상 로드되지 않는다. 해당 디렉토리의 다른 파일은 건드리지 않는다.

### apply-to.sh

에이전트 이름을 인자로 받아 해당 설치 스크립트만 순차 실행하는 공통 진입점이다. 플랫폼별 설치 전에 harness 소유·은퇴 이름을 `~/.agents/skills`에서 지운 뒤 `skills/<name>/`을 한 번만 복사하고 (호스트 공용), `~/.agents/scripts`에서 은퇴한 스크립트를 지운다. 이어서 `EXTERNAL_SKILLS`(`scripts/install-shared.sh`)의 외부 스킬을 `npx skills add <source> --skill <name> -g -a universal -y`로 설치한다(네트워크 필요). `apply-to-claude.sh`가 하네스 스킬처럼 `~/.claude/skills`에서 심링크한다.

```bash
scripts/apply-to.sh claude
scripts/apply-to.sh claude cursor
scripts/apply-to.sh claude codex cursor grok
```

허용 인자: `claude` · `codex` · `cursor` · `grok` (대소문자 무시, 중복 제거). 구 이름 `personal`/`work`는 거부하고 `claude`/`codex`로 안내한다.

### apply-to-claude.sh

Claude Code 설치 스크립트다.

- Claude Code: `instructions/AGENTS.md`를 `~/.claude/CLAUDE.md`로 복사하고, `~/.claude/skills/<name>` 스킬 단위 심링크를 `~/.agents/skills`로 다시 건다(은퇴한 이름은 링크가 제거된다). `~/.claude/agents`에서 은퇴한 harness 에이전트를 지우고, `~/.claude/hooks`는 `hooks/claude/hooks/`로 다시 채운다.
- Claude Code 설정: `hooks/claude/settings.json`의 `hooks` 블록을 `~/.claude/settings.json`에 `jq`로 머지한다. 사용자의 다른 설정(`permissions`/`model`/`env` 등)은 보존되며, 대상 파일이 없으면 통째로 생성한다 (jq 필요).
- 마지막에 항목별 설치 상태 요약을 출력한다.

### apply-to-codex.sh

Codex 설치 스크립트다.

- `instructions/AGENTS.md`를 `~/.codex/AGENTS.md`로 복사한다.
- `~/.codex/skills`에서 harness·은퇴 스킬 이름을, `~/.codex/agents/`에서 은퇴한 harness 에이전트를 제거한다.
- `~/.codex/hooks/`를 비운 뒤 `hooks/codex/hooks/*`를 복사하고, `hooks/codex/hooks.json`을 `~/.codex/hooks.json`으로 복사한다.
- 마지막에 항목별 설치 상태 요약을 출력한다.

### apply-to-cursor.sh

Cursor 설치 스크립트다.

- `instructions/AGENTS.md`를 `~/.cursor/AGENTS.md`로 복사한다. **Cursor는 이 파일을 읽지 않는다** — `session-context.sh`가 읽어서 `additional_context`로 주입한다. Cursor에 사용자 전역 지침 파일이 없고 User Rules는 설치 스크립트가 쓸 수 없는 UI 상태이기 때문이다.
- `~/.cursor/skills`에서 harness·은퇴 스킬 이름을, `~/.cursor/agents`에서 은퇴한 harness 에이전트를 제거한다. `~/.cursor/hooks`는 `hooks/cursor/hooks/`로 다시 채운다.
- `hooks/cursor/hooks.json`을 `~/.cursor/hooks.json`으로 **머지가 아니라 교체**한다. Claude의 `settings.json`은 다른 설정과 파일을 공유하지만 Cursor의 `hooks.json`은 훅 전용이다.
- 마지막에 설치 요약과 함께, 스크립트가 대신할 수 없는 1회성 수동 단계(`~/.claude` 호환 경로 끄기)를 안내한다.

### apply-to-grok.sh

Grok Build 전용 변형 설치 스크립트다(Claude/Cursor compat 경로를 쓰지 않는다).

- `instructions/AGENTS.md`를 **`~/.grok/rules/AGENTS.md`**로 복사한다(SessionStart 주입이 아니라 네이티브 rules 로드).
- `~/.grok/skills`에서 harness·은퇴 스킬 이름을, `~/.grok/agents/`에서 은퇴한 harness 에이전트를 제거한다.
- 훅 스크립트를 `~/.grok/hooks/`에 두고, `hooks/grok/hooks.json`을 **`~/.grok/hooks/harness.json`**으로 복사한다(Grok은 `~/.grok/hooks/*.json`을 머지).
- 종료 시 **`[compat.claude]`·`[compat.cursor]` 끄기**를 안내한다.

### apply-to-all.sh

`apply-to.sh claude codex cursor grok`를 호출해 네 에이전트 설치를 순서대로 실행하는 래퍼다. 어디서 실행해도 된다(스크립트가 자체 경로 기준으로 해석한다).

### setup-ctx7.sh

Context7이 배포하는 context7 지침 블록을 최신 버전으로 재생성해 레포 소스에 반영한다. 설치 환경(`~/.claude` 등)이 아니라 레포 안의 소스를 갱신하는 스크립트이며, 갱신 결과는 이후 `apply-to-*.sh` 실행 시 배포된다 (`ctx7` CLI 필요).

- `ctx7 upgrade`로 CLI 업데이트 여부를 먼저 확인한다 (업데이트가 있으면 안내만 출력하고 자동 설치하지는 않는다).
- 임시 디렉토리에서 `ctx7 setup --cli --claude -y -p`를 실행해 context7 룰을 생성한다. `ctx7`은 `find-docs` 스킬도 함께 내놓지만 이 harness는 그것을 벤더링하지 않는다 — 같은 지침이 `instructions/AGENTS.md`의 context7 블록에 이미 들어 있어, 스킬까지 설치하면 네 플랫폼 모두에서 스킬 목록 예산만 중복으로 소모한다.
- 생성물의 `npx ctx7@latest` 호출을 전역 설치된 `ctx7` 명령으로 치환한다.
- `ctx7`이 내보내는 `## Steps` 헤딩을 `### Context7 Steps`로 강등한다. AGENTS.md에 붙으면 H2가 `## Key Principles` 등과 동급 최상위 섹션이 되어 ctx7 전용 단계로 읽히지 않기 때문이다.
- `instructions/AGENTS.md`의 `<!-- context7 -->` 블록을 Claude 룰 내용으로 교체한다 (네 플랫폼이 공유하는 지침 파일이므로 플랫폼 중립적인 Claude 룰을 쓴다).
