---
Application: personal-harness
ResearchType: Structure
Description: apply-to-*.sh 설치 대상, 각 호스트의 스킬 탐색 경로(~/.agents/skills 포함), verify-sync.py가 스킬 트리를 어떻게 검사하는지.
---

# Research: 설치와 스킬 탐색

> Type: Structure

## 인스톨러

진입점: `scripts/apply-to.sh`가 `claude|codex|cursor|grok`를 받아 `apply-to-${agent}.sh`를 실행. `apply-to-all.sh`는 네 플랫폼 전부.

**공통 패턴 (현재):** 대상 디렉터리를 **통째로 비운 뒤** 레포 변형을 복사한다. harness 이름만 골라 지우지 않는다. 따라서 사용자가 `~/.cursor/skills`에 넣어 둔 비-harness 스킬도 apply 한 번에 사라진다.

### apply-to-claude.sh

| 대상 | 동작 |
| --- | --- |
| `~/.claude/CLAUDE.md` | `instructions/AGENTS.md` 복사 |
| `~/.claude/skills` | 비우고 `skills/claude/` 복사 |
| `~/.claude/agents` | 비우고 `agents/claude/` 복사 |
| `~/.claude/hooks` | 비우고 `hooks/claude/hooks/` `cp -rp` |
| `~/.claude/scripts` | 비우고 `scripts/runtime/` `cp -rp` |
| `~/.claude/settings.json` | `jq -s '.[0] * .[1]'`로 기존 파일에 `hooks/claude/settings.json` 병합. 소스 키는 `"hooks"`뿐 |

`~/.agents/skills`에 쓰지 않는다. 레포 `.claude/skills/sync-harness`도 설치하지 않는다.

### apply-to-codex.sh

`~/.codex/AGENTS.md`, `~/.codex/skills` ← `skills/codex/`, `~/.codex/agents` ← `*.toml`만, `~/.codex/hooks/` 스크립트, `~/.codex/hooks.json` **replace**, `~/.codex/scripts` ← runtime.

### apply-to-cursor.sh

`~/.cursor/AGENTS.md` (Cursor는 이 파일을 직접 안 읽음. `session-context.sh`가 주입), skills/agents/hooks/scripts 전부 wipe+copy, `~/.cursor/hooks.json` **replace**. stdout: `~/.claude`/`~/.codex` 호환 경로를 끄라고 안내.

### apply-to-grok.sh

`~/.grok/rules/AGENTS.md`, `~/.grok/skills` ← `skills/grok/`, `~/.grok/agents` `*.md`, 훅 스크립트는 `*.json`을 남기고 복사, `~/.grok/hooks/harness.json` ← `hooks/grok/hooks.json` (Grok은 `~/.grok/hooks/*.json` 머지), `~/.grok/scripts`. stdout: `[compat.claude]`/`[compat.cursor]`를 false로.

**네 인스톨러 모두 `~/.agents/skills`와 `~/.agents/scripts`를 만들지 않는다.**

## 호스트 탐색 경로 (2026-09 문서 기준)

| 호스트 | `~/.agents/skills` | 자체 유저 경로 | 비고 |
| --- | --- | --- | --- |
| Claude Code | **안 읽음** | `~/.claude/skills/<name>/SKILL.md` | 공식: 스킬 **엔트리**가 심링크일 수 있음. 디렉터리 통째 심링크는 slash `Unknown skill` 버그 사례가 있음. `skillsPaths` 설정은 미구현 이슈. |
| Cursor | **네이티브** (`~/.agents/skills`, `.agents/skills`) | `~/.cursor/skills` | 호환으로 `~/.claude/skills`·`~/.codex/skills`도 읽음. 디듀프는 문서화되어 있지 않음. |
| Codex | **네이티브 USER 정규 경로** | `~/.codex/skills` (구경로, 아직 스캔) | 같은 `name`이 두 경로에 있으면 셀렉터에 **두 줄**. 머지하지 않음. |
| Grok Build | `.agents/skills`를 `.grok` 티어와 함께 스캔 (cwd→루트 + 유저). SpaceXAI 문서는 `~/.agents/skills/`를 유저 스킬로 명시 | `~/.grok/skills` | 이름 디듀프, 높은 우선순위가 이김. `[skills] paths`로 추가 가능. `[compat.*] skills=false`면 Claude/Cursor 홈을 안 읽음. `grok inspect`가 source를 보여 줌. |

Grok 샌드박스가 거부하는 심링크는 `$GROK_HOME`과 hooks-paths다. 스킬 심링크가 아니다.

Cursor는 스킬 루트를 **재귀** 탐색한다. 런타임 스크립트를 `~/.agents/skills/_runtime`에 넣으면 안 된다. 형제는 `~/.agents/scripts`.

## sync-harness verifier

경로: `.agents/skills/sync-harness/scripts/verify-sync.py` (`.claude/skills/sync-harness/scripts/`에 복본).

실제 검사:

- 스킬 디렉터리 이름 패리티: `skills/claude` vs `skills/codex`만. Cursor/Grok는 비교하지 않음. `CODEX_ONLY_SKILLS`는 빈 set.
- 스킬 `name` == 디렉터리명, frontmatter YAML.
- 스킬별 `references/`·`scripts/` 파일 집합 패리티 (claude vs codex).
- Codex residual: `subagent_type`, `ExitPlanMode`, `AskUserQuestion`이 Codex `*.md`에 있으면 fail.
- 에이전트: `agents/claude/*.md` stem vs `agents/codex/*.toml` stem.
- 훅: claude vs codex `*.sh` 이름, Codex `hooks.json`에 `$HOME/.claude/` 없음, `bash -n`.

검사하지 않음: Cursor/Grok 트리, `allowed-tools`, `$HOME/.*/scripts` 일관성, spawn 툴 이름 전반.

Makefile·테스트 스위트는 레포에 없다. 검증은 `verify-sync.py` + apply 관찰이다.

## 문서가 가정하는 레이아웃

`AGENTS.md` 49행, `README.md` 46·177·335행 부근: `skills/<platform>/` → `~/.claude/skills` 등.

런타임 스크립트: `AGENTS.md` 100–107, `README.md` 238–246. 네 홈 경로 + Claude `allowed-tools` 문장.

`plan-consultant` 행 (`AGENTS.md` 72): Claude/Codex/Cursor는 implementer가 `(design-bearing)`에서 소환, Grok은 Dispatcher + `needs-design-decision`.

`instructions/AGENTS.md`(설치되는 전역 지침)는 스킬 디렉터리 레이아웃을 말하지 않는다.

## 레포 `.agents/skills` vs 유저 `~/.agents/skills`

| 위치 | 지금 역할 |
| --- | --- |
| `<repo>/.agents/skills/sync-harness/` | 이 하네스 마이그레이션용 레포 스코프 스킬 |
| `<repo>/.claude/skills/sync-harness/` | 같은 내용 Claude 복본 |
| `~/.agents/skills` | 인스톨러가 만들지 않음 |
| `~/.claude/skills` 등 | apply 후 13개 제품 스킬. `sync-harness` 없음 |

설치된 Claude 홈에 `request-merge`, `dev-loop-light`, `dev-loop-noreview`가 보일 수 있다. 레포 `skills/claude/`에는 없다. 예전 설치 잔여이거나 별도 복사다. 새 인스톨러는 harness 소유 13개 이름만 관리해야 이 잔여와 충돌을 명시적으로 다룰 수 있다.
