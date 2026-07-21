# Migrating Claude Code to OpenCode

이 문서는 **Claude Code → OpenCode** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 새 스킬·서브에이전트·훅이 추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**, 그리고 **Claude → OpenCode**다. Personal 환경의 중심은 Claude Code이고 OpenCode는 Personal의 하위 변형이므로, OpenCode는 Claude Code에서만 파생되며 OpenCode를 소스로 쓰는 역방향은 지원하지 않는다. Work 환경의 중심은 Codex이고 Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. 이 문서의 소스는 Claude 변형(`skills/claude/`, `agents/claude/`, `hooks/claude/`)이고, 대상은 OpenCode 변형(`skills/opencode/`, `agents/opencode/`, `hooks/opencode/`)이다. Claude → Codex 단계는 [MIGRATE_TO_CODEX.md](MIGRATE_TO_CODEX.md), Codex → Claude Code 단계는 [MIGRATE_TO_CLAUDE.md](MIGRATE_TO_CLAUDE.md)를 참고한다.

OpenCode는 Claude Code 호환 모드를 기본 제공하여 `~/.claude/skills/`, `~/.claude/CLAUDE.md`, `~/.claude/agents/`를 fallback으로 읽을 수 있다. 하지만 이 harness는 플랫폼별 독립 변형을 유지하므로, Claude 호환 fallback에 의존하지 않고 `~/.config/opencode/` 아래에 OpenCode 전용 변형을 배포한다. 호환 모드는 마이그레이션 누락 시 안전망일 뿐, source of truth는 OpenCode 변형이다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom agent 정의 파일), 훅(hook 설정·스크립트) — 이고, 아래도 그 순서로 나눈다. 단, OpenCode의 훅은 shell script가 아니라 JS/TS plugin이므로 "Hook migration"에서는 Claude의 shell-script hook을 OpenCode plugin으로 변환하는 규칙을 다룬다.

## Skill migration

`skills/claude/<skill>`를 `skills/opencode/<skill>`로 옮길 때의 규칙이다.

### Start from the Claude variant

- 소스 오브 트루스는 `skills/claude/<skill>`다. Claude Code가 Personal의 대표이고 OpenCode는 그 하위 변형이므로, OpenCode 변형은 Claude 변형에서 파생한다.
- 트리 구조, 파일명, `references/`·`scripts/` 경로, frontmatter `name`은 기본적으로 유지한다. `references/`와 `scripts/`가 host-neutral하면 그대로 복사한다.
- OpenCode는 Claude Code 호환 모드로 `~/.claude/skills/`도 읽지만, 독립 변형을 유지하려면 `skills/opencode/<skill>/SKILL.md`를 별도로 둔다. 호환 fallback에 의존하지 않는다.
- 호스트 무관 스킬은 거의 그대로 옮긴다. 위임(subagent), plan mode, Claude 전용 tool 이름이 본문에 없으면 차이를 만들지 않는다.

### Replace Claude Code tool names with OpenCode-safe wording

Claude Code Skill에는 `Read`, `Grep`, `Glob`, `Bash`, `Edit`, `Write`, `MultiEdit`, `AskUserQuestion`, `ExitPlanMode`, `Agent` 같은 도구명이 직접 들어가 있을 수 있다. OpenCode 환경에서는 도구 이름과 사용 방식이 다르므로, Skill 본문은 OpenCode에서 실행 가능한 표현으로 바꾼다.

- Claude Code의 `Agent` tool은 OpenCode의 **Task tool**로 바꾼다. 본문에서 "dispatch via the `Agent` tool"은 "dispatch via OpenCode's Task tool"로 적는다.
- Claude Code의 `subagent_type: general-purpose`는 OpenCode의 **`subagent_type: general`**로 바꾼다. 현재 OpenCode의 built-in subagent 이름은 `general`, `explore`다.
- Claude Code의 `AskUserQuestion`은 OpenCode의 **question tool**(또는 "ask the user"라는 기능 중심 표현)로 바꾼다.
- Claude Code의 `ExitPlanMode`는 OpenCode Plan agent의 **`plan_exit`** 흐름으로 바꾼다. 아래 "Convert plan-mode instructions"에서 다룬다.
- Claude Code의 `Read`, `Grep`, `Glob`, `Bash` 도구명은 기능 중심 표현("file reads", "grep/glob searches", "shell execution")으로 바꾸거나, workflow 이해에 직접 도움이 되는 경우에만 OpenCode 도구명을 쓴다. repo 규칙(`rg`/`fd` 사용)처럼 OpenCode에서도 유효한 지시는 그대로 둔다.
- `MultiEdit`은 OpenCode에 없다. `edit`/`write`/`apply_patch`로 바꾼다. hook이나 도구 allowlist에서는 `edit`을 기준으로 생각한다.
- 전역 지시 파일은 OpenCode가 읽는 `AGENTS.md`를 우선하되, Claude Code 호환 모드로 `CLAUDE.md`도 fallback으로 읽으므로 "legacy `CLAUDE.md` when present" 표현을 쓴다. Claude 변형의 "`AGENTS.md` / `CLAUDE.md`" 표현은 OpenCode 변형에서 "`AGENTS.md` and legacy `CLAUDE.md` when present"로 바꾼다.

### Map Claude Code subagent dispatch to OpenCode Task tool and preserve the failure gate

Claude Code는 `Agent` tool과 `subagent_type`으로 subagent를 dispatch한다. OpenCode도 Task tool과 `subagent_type`으로 subagent를 dispatch하므로, 개념은 동일하지만 이름과 디스패치 표현이 다르다.

- Claude Code의 `Agent` tool → OpenCode의 **Task tool**. 본문에서 "invoke the `Agent` tool (subagent_type `general-purpose`)"는 "invoke OpenCode's Task tool with `subagent_type: general`"로 바꾼다.
- Claude Code의 "sub-agent"(하이픈) 표현은 OpenCode 공식 용어인 **"subagent"**(하이픈 없음)로 통일한다.
- 이 repo의 reviewer persona는 세 플랫폼에서 같은 이름(`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`)을 유지한다. dispatch 참조도 같은 이름을 쓴다.
- 활성 skill의 위임 지시는 OpenCode에서도 충분한 dispatch 의도다. 사용자가 subagent 사용을 반복해서 요청하도록 별도 gate를 추가하지 않는다.
- Task tool이나 호환 subagent capability가 없거나 dispatch가 실패하면 substantive 작업 전에 중단하고, `Delegation status: unavailable` 또는 `failed`와 관찰된 원인을 보고한 뒤 question tool로 direct fallback 여부를 묻는다. 사용자의 명시적 선택 전에는 main-session 작업으로 대체하지 않는다.
- 병렬 reviewer 중 일부만 실패하면 성공한 결과를 보존하고 실패한 axis를 보고한 뒤, 누락된 pass를 main session에서 수행할지 사용자에게 묻는다.
- Worker는 다시 Task tool로 subagent를 dispatch하지 않는다.
- 사용자가 명시적으로 "main session only", "no subagents" 같은 제한을 둔 경우에는 그 지시가 우선한다.
- Claude Code의 custom subagent는 `Agent` tool로 호출하지만, OpenCode의 custom subagent는 Task tool 또는 `@mention`으로 호출한다. skill 본문에서 dispatch를 설명할 때는 Task tool을 기준으로 적는다.

### Convert plan-mode instructions to OpenCode Plan/Build mode

Claude Code의 `ExitPlanMode`에 대응해 현재 OpenCode Plan agent는 `plan_exit`을 사용할 수 있다. 최종 계획을 제시한 뒤 `plan_exit`으로 전환 승인을 요청하고, 승인되어 Build agent로 전환된 뒤 persistence를 수행한다.

- Claude Code의 `ExitPlanMode` 호출은 OpenCode의 **`plan_exit`** 호출로 바꾼다.
- plan presentation 끝에 사용자에게 수동 Tab 전환과 별도 `continue` 응답을 요구하지 않는다. 최종 계획을 제시하고 `plan_exit`을 호출한다.
- 계획 단계는 read-only라는 원칙을 유지한다. OpenCode Plan agent는 일반 파일 편집을 거부하고 plan 파일 위치만 편집할 수 있다.
- 승인 후 첫 write가 스킬이 요구하는 persistence(Obsidian 저장 등)여야 한다는 정책은 유지한다. "첫 번째 Build-mode turn의 첫 tool calls"로 표현한다.
- Claude Code의 `Plan` subagent는 OpenCode의 **Plan agent**(primary agent)로 대응된다. "Claude Code의 `Plan` subagent가 생성한 출력"은 "OpenCode의 Plan agent가 생성한 출력"으로 바꾼다.
- `AskUserQuestion`으로 모드를 묻는 부분은 "question tool" 또는 "ask the user"로 바꾼다.

### Handle OpenCode skill discovery and frontmatter

OpenCode는 skill을 다음 경로에서 발견한다:

- `~/.config/opencode/skills/<name>/SKILL.md` (global)
- `.opencode/skills/<name>/SKILL.md` (project)
- `~/.claude/skills/<name>/SKILL.md`, `.claude/skills/<name>/SKILL.md` (Claude 호환 fallback)
- `~/.agents/skills/<name>/SKILL.md`, `.agents/skills/<name>/SKILL.md` (agent 호환 fallback)

- OpenCode 변형의 설치 대상은 `~/.config/opencode/skills/<name>/`이다. Claude 호환 경로에 의존하지 않는다.
- OpenCode skill frontmatter는 `name`, `description`, `license`, `compatibility`, `metadata` 필드만 인식한다. Unknown 필드는 무시된다.
- `name`은 1–64자, lowercase alphanumeric + single hyphen, 디렉터리명과 일치해야 한다. Claude 변형과 동일한 규칙이므로 그대로 둔다.
- `description`은 1–1024자. OpenCode도 skill description으로 자동 선택에 사용하므로 trigger가 충분해야 한다. Claude 변형의 description을 그대로 쓰되, Claude 전용 tool 이름이 들어있으면 OpenCode 표현으로 바꾼다.
- YAML 콜론 함정을 확인한다. 값에 `: `(콜론+공백)이 있으면 따옴표로 감싼다.

### Verify

- 트리 패리티: 대상 skill에 `SKILL.md`가 있고, host-neutral `references/`·`scripts/` 트리가 Claude 소스와 동일한가.
- 각 `SKILL.md`의 `name:`이 디렉터리명과 일치하고 YAML이 파싱되는가.
- 잔존 스윕(`rg`): Claude 전용 `Agent` tool, `subagent_type: general-purpose`, `AskUserQuestion`, `ExitPlanMode`, `MultiEdit`, `sub-agent`(하이픈)가 문맥상 의도된 것인지 확인한다. `sub-agent`는 OpenCode 공식 용어인 `subagent`로 통일해야 한다.
- 위임형 skill은 OpenCode에서 Task tool / `subagent_type` 흐름이 자연스럽고, 명시적 실패 gate와 Worker의 재-dispatch 금지를 보존하며 실패 시 main session으로 조용히 대체하지 않는가.
- plan-mode skill은 최종 계획 후 `plan_exit`으로 승인을 요청하고, 수동 Tab + `continue` hand-off를 요구하지 않는가.
- `AGENTS.md` / `CLAUDE.md` 표현이 OpenCode 변형에서 "`AGENTS.md` and legacy `CLAUDE.md` when present"로 바뀌었는가.

## Sub-agent migration

`agents/claude/*.md`(custom agent)를 `agents/opencode/*.md`로 옮길 때의 규칙이다.

### Convert Claude Code Markdown agents to OpenCode Markdown agents

Claude Code와 OpenCode 모두 Markdown 파일의 YAML frontmatter와 본문으로 custom agent를 정의한다. 하지만 frontmatter 필드와 권한 모델이 다르다.

- Claude Code agent 소스는 `agents/claude/<name>.md`, OpenCode 대상은 `agents/opencode/<name>.md`다.
- 설치 대상은 개인 전역 agent면 `~/.config/opencode/agents/`, 프로젝트 범위 agent면 `.opencode/agents/`다. personal harness에서는 배포 스크립트가 `agents/opencode/*`를 `~/.config/opencode/agents/`로 동기화한다.
- OpenCode는 Markdown 파일명을 agent 이름으로 사용한다. filename과 frontmatter `name`을 같은 hyphenated name으로 유지한다.
- 본문이 host-neutral하면 그대로 옮긴다. Claude 전용 tool 이름, 권한 표현만 제거하거나 OpenCode 표현으로 바꾼다.

### Field mapping

| Claude Code frontmatter | OpenCode frontmatter | 메모 |
| --- | --- | --- |
| `name: <name>` | `name: <name>` | 파일명과 일치. OpenCode는 filename을 이름으로 사용 |
| `description: "..."` | `description: "..."` | 생략 가능하지만 없으면 Task tool 목록에서 수동 호출 전용으로 안내된다. 자동 위임용 trigger·persona를 충분히 설명 |
| `tools: Read, Grep, Glob, Bash` | `permission:` 객체 (아래 참조) | Claude `tools:` allowlist → OpenCode `permission:` 매핑 |
| (없음) | `mode: subagent` | 선택 필드지만 이 repo의 persona agent는 Task 전용임을 명확히 하려고 명시 |
| (없음) | `hidden: true` (선택) | `@mention` 자동완성에서 숨김. review-code처럼 dispatch-only agent에 사용 |

### Convert read-only and tool policy

Claude Code는 `tools:` allowlist로 도구 접근을 제한한다. OpenCode는 `tools:`가 deprecated되었으며 **`permission:` 객체**로 도구 접근을 제어한다. permission 값은 `"allow"`, `"ask"`, `"deny"` 또는 glob 패턴 객체다.

Claude Code의 reviewer agent(`tools: Read, Grep, Glob, Bash` + "Read-only. No edits. No commits.")를 OpenCode로 옮길 때:

```yaml
mode: subagent
permission:
  read: allow
  glob: allow
  grep: allow
  list: allow
  edit: deny
  task: deny
  bash:
    "*": ask
    "git diff*": allow
    "git status*": allow
    "git log*": allow
    "rg *": allow
    "fd *": allow
```

- Claude Code의 `tools: Read, Grep, Glob, Bash`는 OpenCode에서 `read: allow`, `glob: allow`, `grep: allow`, `list: allow`로 매핑한다. OpenCode는 `list`를 별도 permission key로 둔다.
- read-only 강제를 위해 `edit: deny`, `task: deny`를 추가한다. reviewer가 subagent를 spawn하지 못하게 한다.
- `bash`는 전체를 `deny`하지 않고 glob 패턴으로 세분한다. 검증·검색 명령(`rg`, `fd`, `git diff/status/log`)은 `allow`, 그 외는 `ask`로 둔다. 이 repo의 reviewer persona는 코드를 읽기 위해 shell을 쓸 수 있되 편집은 불가해야 하므로, bash를 조건부 허용한다.
- 본문에도 "Read-only. No edits. No commits. No changes to the working tree." hard rule을 유지한다. permission 설정과 본문 규칙으로 이중 강제한다.
- Claude Code의 `tools:`에 없던 도구(`write`, `edit`, `webfetch` 등)는 `permission:`에서 명시적으로 `deny`하거나 생략한다. 생략하면 global permission 정책을 따른다.

### Permission key reference

OpenCode permission key와 대응하는 도구:

| Permission key | Tools it gates |
| --- | --- |
| `read` | `read` |
| `edit` | `write`, `edit`, `apply_patch` |
| `glob` | `glob` |
| `grep` | `grep` |
| `list` | `list` |
| `bash` | `bash` |
| `task` | `task` |
| `external_directory` | external file read/write tools |
| `todowrite` | `todowrite`, `todoread` |
| `webfetch` | `webfetch` |
| `websearch` | `websearch` |
| `lsp` | `lsp` |
| `skill` | `skill` |
| `question` | `question` |

`read`, `edit`, `glob`, `grep`, `list`, `bash`, `task`, `external_directory`, `lsp`, `skill`은 shorthand action(`"allow"`/`"ask"`/`"deny"`) 또는 glob→action 객체를 모두 지원한다. 나머지는 shorthand action만 지원한다.

### Restore richer descriptions

- Claude Code subagent description은 OpenCode에서도 agent 선택과 자동 위임에 직접 영향을 준다. reviewer persona처럼 선택 기준이 중요한 agent는 역할·범위·금지 범위를 그대로 유지한다.
- description에서 Claude 전용 표현("`AGENTS.md` / `CLAUDE.md`")은 OpenCode 표현("`AGENTS.md` and legacy `CLAUDE.md` when present")으로 바꾼다.
- YAML 콜론 함정을 확인한다. `description: "...findings: authn/authz..."`처럼 값에 `: `가 있으면 따옴표로 감싼다.

### Built-in agent name mapping

OpenCode의 built-in agent 이름은 Claude Code와 다르다. skill 본문에서 built-in agent를 참조할 때 매핑한다:

| Claude Code | OpenCode | 메모 |
| --- | --- | --- |
| `Plan` subagent | `plan` agent (primary) | OpenCode Plan은 primary agent |
| (직접 구현) | `build` agent (primary) | OpenCode Build는 기본 primary agent |
| `general-purpose` subagent | `general` subagent | Task tool의 기본 subagent_type |
| (없음) | `explore` subagent | 읽기 전용 코드 탐색 |

- Claude Code의 `subagent_type: general-purpose`는 OpenCode의 **`general`**로 바꾼다. 이름 충돌을 피하기 위해 custom agent 이름은 `general`, `explore`, `build`, `plan`과 겹치지 않게 한다.
- skill 본문에서 "Claude Code의 `Plan` subagent"는 "OpenCode의 Plan agent"로 바꾼다.

### Verify

- 서브에이전트 트리 패리티: `agents/claude/*.md`와 `agents/opencode/*.md`가 필요한 범위에서 1:1로 대응하는가.
- 각 `agents/opencode/*.md` frontmatter가 실제 YAML 파서로 파싱되는가 — 특히 `description`의 `: `(콜론+공백)를 따옴표로 감쌌는가.
- 각 agent에 `mode: subagent`가 있는가 (reviewer persona의 경우).
- 각 `name`이 파일명·skill 본문 dispatch 참조와 일치하는가.
- read-only persona에 `edit: deny`, `task: deny`가 있고, `bash`가 glob 패턴으로 세분되어 있는가.
- 본문에 "Read-only. No edits. No commits." hard rule이 있는가.
- 본문에 Claude 전용 표현(`tools:`, `sub-agent`, `Agent` tool, `general-purpose`)이 의도 없이 남지 않았는가.

## Hook migration

`hooks/claude/`(shell-script hooks)를 OpenCode plugin으로 옮길 때의 규칙이다. OpenCode는 Claude Code·Codex와 달리 shell-script hook이 아니라 **JS/TS plugin**으로 hook을 구현한다.

### Convert Claude Code shell-script hooks to OpenCode plugin

Claude Code hook은 `settings.json`의 `hooks` 블록과 `hooks/*.sh` 스크립트로 구성된다. OpenCode plugin은 JS/TS 모듈로 정의하며, plugin function이 hook handler 객체를 반환한다. personal harness는 plugin을 OpenCode config에 명시적으로 등록하는 방식을 사용한다.

- Claude Code 소스: `hooks/claude/settings.json` + `hooks/claude/hooks/*.sh`
- OpenCode 대상: `hooks/opencode/<plugin-name>.js` (단일 JS 파일로 통합)
- personal harness의 설치 대상은 `~/.config/opencode/personal-harness.js`다.
- personal harness에서는 Claude Code의 hook script(`session-context.sh`, `git-identity-guard.sh`, `enforce-rg.sh`, `enforce-fd.sh`, `auto-format.sh`)를 **하나의 plugin 파일**로 통합한다. OpenCode plugin은 이벤트별 handler를 객체로 반환하므로, 여러 hook을 한 파일에서 처리하는 것이 자연스럽다.
- 문서 드리프트 검사는 hook/plugin으로 구현하지 않는다. 모든 플랫폼의 `commit-code` skill이 커밋 후 변경 범위를 읽기 전용으로 검사하고, 필요한 문서와 업데이트 개요만 사용자에게 보고한다.
- plugin은 `opencode.jsonc`가 있으면 이를 우선하고 없으면 `opencode.json`을 사용하는 config의 `plugin` 배열에 `"./personal-harness.js"` 문자열로 등록한다. Git identity는 기본적으로 환경변수에서 읽는다.

### Event mapping

Claude Code의 hook 이벤트를 OpenCode plugin 이벤트로 매핑한다:

| Claude Code hook | OpenCode plugin event | 메모 |
| --- | --- | --- |
| `SessionStart` | `event` (filter `event.type === "session.created"`) | work/personal session context: `client.session.prompt`로 주입 |
| `PreToolUse` matcher `Bash` | `tool.execute.before` (filter `input.tool === "bash"`) | 명령 검사·차단 |
| `PostToolUse` matcher `Edit\|Write\|MultiEdit` | `tool.execute.after` (filter `["edit","write","apply_patch"].includes(input.tool)`) | auto-format |


- `tool.execute.before` handler는 `(input, output)`를 받는다. `input.tool`로 도구를 식별하고, `output.args`에서 명령/인자를 읽는다. 차단은 `throw new Error(message)`로 한다. Claude Code의 `exit 2 + stderr`와 동일한 효과다.
- `tool.execute.after` handler는 `(input)`을 받는다. `input.tool`과 `input.args`에서 파일 경로·cwd를 얻는다. side effect(auto-format)를 수행하고, 실패 시 `throw new Error`로 agent에 feedback을 전달한다. `PostToolUse`와 달리 이미 실행된 side effect를 되돌리지 않는다.

- `session.created`도 `event` handler에서 처리한다. `session-context.sh`의 work/personal 판별은 `repoContext()`로 옮기고, `client.session.prompt`로 세션 컨텍스트를 한 번 주입한다.

### Plugin structure

plugin은 async function이 context와 선택적 options를 받아 hook handler 객체를 반환하는 구조다. personal harness의 표준 config는 경로 문자열만 등록하므로 options는 기본값 `{}`를 사용한다:

```javascript
export const PersonalHarness = async ({ directory, worktree, client }, options = {}) => {
  const fallbackCwd = worktree || directory
  const gitIdentity = options.gitIdentity ?? {}

  return {
    "tool.execute.before": async (input, output) => {
      if (input.tool !== "bash") return
      const command = output.args?.command ?? output.args?.cmd ?? ""
      const cwd = output.args?.cwd ?? output.args?.directory ?? fallbackCwd
      guardSearchCommands(command)
      guardGitIdentity(command, cwd, gitIdentity)
    },

    "tool.execute.after": async (input) => {
      if (!["edit", "write", "apply_patch"].includes(input.tool)) return
      const cwd = input.args?.cwd ?? input.args?.directory ?? fallbackCwd
      runAutoFormat(cwd)
    },

    event: async ({ event }) => {
      if (event.type === "session.created") {
        await announceSessionContext(client, fallbackCwd, gitIdentity, event.properties?.sessionID)
      }
    },
  }
}
```

- plugin function의 첫 인자 `ctx`는 `directory`, `worktree`, `project`, `client`, `$`(Bun shell)를 제공한다. cwd fallback은 `worktree || directory`를 사용한다. session context를 `client.session.prompt`로 주입하므로 `client`를 반드시 destructure한다.
- plugin function의 두 번째 인자 `options`는 tuple 형태로 plugin을 등록할 때 전달할 수 있는 선택적 옵션이다. personal harness의 표준 문자열 등록에서는 비어 있으며, `identityConfig()`가 `PERSONAL_GIT_EMAIL`, `PERSONAL_GIT_NAME`, `WORK_GIT_EMAIL`, `WORK_GIT_NAME`, `WORK_GITLAB_HOST` 환경변수로 fallback한다.
- plugin function은 hook handler 객체를 반환한다. handler key는 이벤트명(`tool.execute.before`, `tool.execute.after`, `event` 등)이다.

### Plugin configuration in opencode.jsonc or opencode.json

plugin은 OpenCode config의 `plugin` 배열에 경로 문자열로 등록한다:

```json
{
  "plugin": [
    "./personal-harness.js"
  ]
}
```

- plugin 경로는 `~/.config/opencode/` 기준 상대경로다. 설치 시 `hooks/opencode/personal-harness.js`를 `~/.config/opencode/personal-harness.js`로 복사한다.
- `scripts/apply-to-personal.sh`는 `~/.config/opencode/opencode.jsonc`가 있으면 이를 검사하고, 없으면 `opencode.json`을 검사한다. 표준 등록은 정확히 `"./personal-harness.js"` 문자열이다.
- Git identity는 Claude Code와 같은 환경변수(`PERSONAL_GIT_EMAIL`, `PERSONAL_GIT_NAME`, `WORK_GIT_EMAIL`, `WORK_GIT_NAME`, `WORK_GITLAB_HOST`)를 사용한다. plugin의 선택적 `gitIdentity` options는 호환용 override이며 표준 설치에 필수인 config가 아니다.
- Claude Code의 `hooks/claude/settings.json`은 OpenCode에서 대응물이 없다. plugin 파일 자체가 hook 정의이므로, `settings.json`의 `hooks` 블록을 별도로 둘 필요가 없다.

### Script I/O and blocking

- Claude Code hook script는 stdin JSON → exit code + stdout/stderr로 결과를 전달한다. OpenCode plugin handler는 `(input, output)` 객체를 직접 조작하며, `throw new Error`로 차단한다.
- Claude Code의 `.tool_input.command`는 OpenCode에서 `output.args.command`(또는 `output.args.cmd`)로 접근한다. `tool.execute.before` handler에서 `output.args`를 읽는다.
- Claude Code의 `.cwd`는 OpenCode에서 `output.args.cwd`(또는 `output.args.directory`)로 접근한다. `tool.execute.after`에서는 `input.args.cwd`를 사용한다. 필드가 없을 수 있으므로 `fallbackCwd`(`worktree || directory`)로 fallback한다.
- 차단 메시지는 Claude Code에서 `stderr + exit 2`를 썼지만, OpenCode에서는 `throw new Error(message)`를 쓴다. 에러 메시지가 agent에게 전달된다.
- context 주입은 Claude Code에서 `hookSpecificOutput.additionalContext` JSON을 출력했지만, OpenCode에서는 `client.session.prompt`의 `body.parts`에 text part를 넣어 주입한다.

### Hook script to plugin function mapping

Claude Code의 각 hook script를 OpenCode plugin function으로 매핑한다:

| Claude Code script | OpenCode plugin function | 이벤트 |
| --- | --- | --- |
| `session-context.sh` | `repoContext(cwd, gitIdentity)` + `announceSessionContext(client, cwd, gitIdentity, sessionID)` | `event` (`session.created`) |
| `git-identity-guard.sh` | `guardGitIdentity(command, cwd, gitIdentity)` | `tool.execute.before` |
| `enforce-rg.sh` | `guardSearchCommands(command)` (rg 부분) | `tool.execute.before` |
| `enforce-fd.sh` | `guardSearchCommands(command)` (fd 부분) | `tool.execute.before` |
| `auto-format.sh` | `runAutoFormat(cwd)` | `tool.execute.after` |

- Claude Code의 3개 PreToolUse hook script(`git-identity-guard.sh`, `enforce-rg.sh`, `enforce-fd.sh`)는 OpenCode에서 `tool.execute.before` handler 하나로 통합된다. `input.tool === "bash"`인 경우에만 `guardSearchCommands`와 `guardGitIdentity`를 순차 호출한다.
- Claude Code의 `auto-format.sh`는 `tool.execute.after` handler에서 `runAutoFormat` 함수로 옮긴다. Makefile을 찾아 `fmt`/`format` target을 실행하는 로직은 동일하다. `spawnSync` 대신 Bun의 `$` shell API를 쓸 수도 있지만, `node:child_process`의 `spawnSync`를 써도 무방하다.


### Verify

- plugin 파일이 유효한 JS module이고 `export`로 hook handler 객체를 반환하는가.
- 선택된 OpenCode config(`opencode.jsonc` 우선, 없으면 `opencode.json`)의 `plugin` 배열에 `"./personal-harness.js"` 문자열이 등록되어 있는가.
- `event` handler가 `event.type === "session.created"`를 필터링하고, work/personal context를 같은 sessionID에 한 번만 주입하는가.
- `tool.execute.before` handler가 `input.tool === "bash"` 필터를 갖고, `guardSearchCommands`와 `guardGitIdentity`를 호출하는가.
- `tool.execute.after` handler가 `["edit","write","apply_patch"].includes(input.tool)` 필터를 갖고, `runAutoFormat`을 호출하는가.

- plugin이 Claude Code와 같은 git identity 환경변수(`PERSONAL_GIT_EMAIL`, `WORK_GIT_EMAIL` 등)를 fallback으로 읽는가.
- 샘플 입력으로 스모크 테스트: 차단 케이스가 `throw new Error`를 발생시키는가; auto-format이 실패 시 에러를 전달하는가.

## Out of scope

- 이 문서는 Claude Code가 Personal 대표이고 OpenCode가 Personal 하위 변형이라는 ownership을 바꾸지 않는다. OpenCode는 Claude Code에서만 파생되며, OpenCode → Claude Code 역방향 동기화는 지원하지 않는다.
- 이 문서는 설치/배포를 수행하지 않는다. OpenCode 설치는 `scripts/apply-to-personal.sh`가 담당해야 하며, `skills/opencode/`는 `~/.config/opencode/skills/`로, `agents/opencode/`는 `~/.config/opencode/agents/`로, `hooks/opencode/personal-harness.js`는 `~/.config/opencode/personal-harness.js`로 동기화한다. 배포 스크립트 수정은 별도 작업이다.
- OpenCode → Codex 동기화는 지원하지 않는다. Work 환경의 변형은 Codex에서만 파생된다.
- Codex 변형의 변경을 OpenCode로 직접 가져오지 않는다. Codex → Claude Code → OpenCode 경로를 따른다. 즉, Work의 변경은 먼저 Claude Code로 공유된 후 Claude Code에서 OpenCode로 파생된다.
- OpenCode는 Claude Code 호환 모드로 `~/.claude/skills/`, `~/.claude/CLAUDE.md`, `~/.claude/agents/`를 fallback으로 읽을 수 있으나, 이 호환 모드에 의존하지 않고 독립 변형을 유지한다.
- OpenCode 변형의 현재 동작이 Claude Code에 맞지 않으면 그대로 복사하지 말고, 사용자-facing 의미만 보존한 채 OpenCode 실행모델로 재작성한다.
