# Migrating Codex to Cursor

이 문서는 **Codex → Cursor** 마이그레이션 점검표다. 특정 스킬에 묶이지 않도록 작성하며, 스킬·서브에이전트·훅이 변경·추가될 때도 같은 기준으로 검사한다.

마이그레이션 토폴로지는 **Claude ↔ Codex**, 그리고 **Codex → Cursor**다. Personal 환경의 중심은 Claude Code이고 Work 환경의 중심은 Codex이므로, Claude Code와 Codex 변형은 양방향으로 공유할 수 있다. Cursor는 Work의 하위 변형이므로 Codex에서만 파생되며 Cursor를 소스로 쓰는 역방향은 지원하지 않는다. 이 문서의 소스는 Codex 변형(`skills/codex/`, `agents/codex/`, `hooks/codex/`)이고, 대상은 Cursor 변형(`skills/cursor/`, `agents/cursor/`, `hooks/cursor/`)이다. Claude → Codex 단계는 [MIGRATE_TO_CODEX.md](MIGRATE_TO_CODEX.md), Codex → Claude Code 단계는 [MIGRATE_TO_CLAUDE.md](MIGRATE_TO_CLAUDE.md)를 참고한다.

Cursor는 Claude Code처럼 subagent와 plan mode를 기본 지원하지만, 이 harness의 Cursor 변형은 Codex 변형의 동작(명시적 요청 시에만 위임)을 유지한다. 따라서 마이그레이션은 "재설계"가 아니라 "Codex 고유 표현을 Cursor 표현으로 치환"하는 작업에 가깝다 — 핵심은 서브에이전트 위임, Codex 전용 용어·plan mode, 구조화 사용자 입력 처리다.

옮기는 대상은 크게 세 가지 — 스킬(`SKILL.md`), 서브에이전트(custom subagent 정의), 훅(hook 설정·스크립트) — 이고, 각 대섹션 끝에 마이그레이션 후 검증 항목을 둔다.

## Skill migration

`skills/codex/<skill>`를 `skills/cursor/<skill>`로 옮길 때의 규칙이다.

### Include Work-only skills

- `loki-log-search`는 Work-only 스킬이다. `skills/codex/loki-log-search`를 소스로 삼아 `skills/cursor/loki-log-search`로 전파하며, Claude Code/OpenCode 같은 personal 변형으로는 전파하지 않는다.
- 이 스킬은 Codex와 Cursor의 Work 환경에만 존재해야 한다. 검증 시 shared skill parity와 별도로 Codex/Cursor 양쪽에 있고 Claude/OpenCode에는 없는지 확인한다.

### Start from the Codex variant and keep its behavior

- 소스 오브 트루스는 `skills/codex/<skill>`다. claude 변형(`skills/claude/<skill>`)은 항상 자동 위임을 전제로 하므로 Cursor 변형의 출발점으로 쓰지 않는다.
- 트리 구조, 파일명, `references/`·`scripts/` 경로, frontmatter `name`은 그대로 둔다. Cursor도 동일한 `SKILL.md` 표준을 읽으며, `name`은 반드시 폴더명과 일치해야 한다.
- skill-local `agents/openai.yaml`은 Codex/OpenAI UI 메타데이터이며 Cursor custom subagent 정의가 아니다. Codex 소스에 이 파일이 있어도 `skills/cursor/<skill>/agents/openai.yaml`로 복사하지 말고, Cursor 대상 스킬에는 필요한 `SKILL.md`, host-neutral `references/`, `scripts/`만 둔다.
- 호스트 무관 스킬은 사실상 그대로 복사된다. 위임(subagent), plan mode, "Codex" 같은 표현이 본문에 없으면 바꿀 것이 없다. 예: `commit-code`, `request-merge`, `application-research-sync`, `test-dev`.
- 위임 게이팅("사용자가 명시적으로 요청했을 때만")은 Codex 변형 그대로 유지한다. Cursor가 자동 위임을 지원한다고 해서 always-on으로 바꾸지 않는다.
- Cursor는 스킬을 `.cursor/skills/`, `.agents/skills/`, 그리고 레거시 `.codex/skills/`까지 읽는다.

### Map Codex agent names to Cursor subagents

Cursor 내장 subagent는 `Explore`(읽기 중심 병렬 탐색), `Bash`, `Browser`다. 커스텀 subagent는 `.cursor/agents/`에 Markdown(YAML frontmatter)으로 정의하고, Task tool 또는 `/name`으로 호출하며, 한 턴에 여러 Task 호출로 병렬 실행한다.

- Codex `worker`(구현/수정 위임) → 범용 **Cursor subagent를 Task tool로 디스패치**한다. 전용 에이전트 이름을 박지 말고, self-contained 프롬프트를 넘기고 요약만 반환받는다.
- `review-code`의 네 persona 이름은 세 플랫폼에서 동일하게 쓴다: `security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`. "Codex custom agent" → "Cursor custom subagent (Task tool)"로 표현만 바꾼다. 병렬 dispatch는 "한 턴에 여러 Task 호출"로 적는다. 정의 자체는 "Sub-agent migration"에서 다룬다.
- Codex `explorer` 폴백 → Cursor 내장 **`Explore`** subagent로 바꾸고, persona 지시는 프롬프트에 임베드한다.
- subagent는 clean context이므로 필요한 입력을 프롬프트에 모두 담는다는 원칙은 유지한다.
- 게이팅 문장은 플랫폼 단정("Cursor only spawns subagents when…")이 아니라 스킬 정책 문장("Subagents are spawned only when the user explicitly asks…")으로 적는다. Cursor는 실제로 자동 위임이 가능하므로 잘못된 단정을 피한다.

### Rewrite plan-mode mechanics for Cursor

Cursor Plan Mode는 Shift+Tab(또는 복잡한 작업에서 자동 제안)으로 진입하고, 계획 단계는 read-only다 — 파일 쓰기와 빌드 명령이 차단된다.

- "Codex plan mode" → "Cursor plan mode"로 바꾼다. 계획 종료는 사용자가 plan을 **build**할 때(빌드 액션, 또는 Shift+Tab / mode picker)다.
- agent가 호출하는 plan-exit tool은 Cursor에 없다. Claude Code의 `ExitPlanMode` 같은 호출을 넣지 않는다. "host-specific plan-exit tool을 호출하지 말 것"이라는 지시는 그대로 유효하다.
- 승인 후 첫 write는 스킬이 요구하는 persistence(예: Obsidian 저장)여야 한다는 흐름은 Codex와 동일하므로 구조를 보존하고 명칭만 Cursor로 바꾼다.
- 계획 단계 read는 read-only 도구로 한정한다. **Cursor Plan Mode는 MCP 도구도 비활성화**하므로, 계획 단계의 Obsidian 조회는 MCP가 아니라 `obsidian base:query`나 `${OBSIDIAN_HOME}` 파일 검색으로 둔다.

### Strip Codex execution-model terms and rename to Cursor

- 본문과 `description`의 "Codex" → "Cursor"로 바꾼다. Cursor도 `description`으로 스킬을 동적 로딩하므로 trigger 문구가 깨지지 않게 한다.
- "sandbox and approval policy" 같은 Codex 실행모델 용어를 제거한다. 위임 시 권한 전제는 Cursor 표현("부모 세션과 동일한 권한으로 실행", "clean context에서 시작")으로 바꾸고, delegated subagent가 독립 권한을 가진다고 가정하지 않는다.
- Codex 기본 agent 이름(`default`, `worker`, `explorer`)을 Cursor용 지시에 남기지 않는다.
- 도구 표현은 Cursor 기준으로 쓴다. subagent dispatch는 **Task tool**, 읽기 전용 탐색은 내장 `Explore`. Claude식 `Agent` tool / `subagent_type` 표현이 흘러들어오지 않게 한다.

### Keep structured-input fallbacks for Cursor

- "current Codex mode provides it" 류 표현은 "current Cursor mode provides it"로 바꾼다.
- Cursor 에이전트 챗에는 다지선다용 구조화 입력 도구가 표준으로 제공되지 않는다. 따라서 plain-text(번호 옵션) 폴백을 반드시 남긴다. Codex 변형에 이미 폴백이 있으면 그대로 둔다.

### Format printed file links for Cursor

- 스킬이 최종 채팅 출력에 Markdown 파일 링크를 만들 때, 저장된 문서의 `path:line` 앵커는 그대로 두고 **채팅에 출력하는 링크 target만** Cursor용으로 바꾼다.
- Codex/Claude Code의 일반 로컬 Markdown target(`(/absolute/path:line)`)을 Cursor로 옮길 때는 VS Code 계열 URL 형식의 Cursor scheme을 쓴다: `[src/app.ts:42](cursor://file//Users/me/repo/src/app.ts:42:1)`. Unix 절대경로는 `/`로 시작하므로 `cursor://file//Users/...`처럼 `file` 뒤에 슬래시가 두 개 온다.
- 링크 label은 reviewer가 읽기 쉬운 repo-relative `path:line`으로 유지한다. target은 absolute path, line, column 1을 포함해 클릭 시 Cursor가 해당 파일 위치로 열 수 있게 한다.

### Fix project-target and global-instruction wording

- 신규 프로젝트의 에이전트 파일을 고르는 안내(예: `setup-initial-repo`)에는 Cursor를 예시에 포함한다. Cursor는 `AGENTS.md`를 읽으므로 "Claude Code → CLAUDE.md, Cursor / Codex / other agents → AGENTS.md"처럼 적는다.
- 전역 지시 파일은 Cursor가 읽는 `AGENTS.md`와 `.cursor/rules`를 우선하되, cross-agent repo에서 `CLAUDE.md`가 병존하면 필요한 경우 둘 다 확인하도록 둔다.

### Verify

- 트리 패리티: 대상 skill에 `SKILL.md`가 있고, host-neutral `references/`·`scripts/` 트리가 Codex 소스와 동일한가.
- skill-local `agents/openai.yaml`이 Cursor 대상에 복사되지 않았는가. Cursor custom subagent는 repo-level `agents/cursor/*.md`로만 관리한다.
- 각 `SKILL.md`의 `name:`이 디렉터리명과 일치하는가.
- 잔존 스윕(`rg`): `Codex`, 단어 `worker`, `sandbox and approval`, 소문자 `explorer`, Claude식 `Agent` tool / `subagent_type`, `ExitPlanMode`, `MCP`가 남아있지 않은가. 의도적 예외만 허용한다 — `setup-initial-repo`의 "Codex" 예시, `spec-creator`의 런타임 "worker process" 용어.
- bulk 치환 후 어색한 중복(`subagent agent`, `subagent subagent` 등)이 없는가.
- `description`이 짧고 trigger 중심인가(Cursor도 description으로 동적 로딩). 치환 과정에서 trigger 문구가 손상되지 않았는가.

## Sub-agent migration

`agents/codex/*.toml`를 `agents/cursor/*.md`로 옮길 때의 규칙이다(`agents/claude/*.md`와 평행).

### Convert the reviewer sub-agents (Codex TOML → Cursor Markdown)

`review-code`가 위임하는 네 persona(`security-reviewer`, `reliability-reviewer`, `maintainability-reviewer`, `senior-generalist-reviewer`)는 Cursor custom subagent로 별도 정의해야 한다(스킬 본문이 이름으로 참조하기 때문).

- **파일 형식·위치**: standalone TOML → Markdown(YAML frontmatter + 본문)으로 바꾸고 확장자도 `.toml` → `.md`로 바꾼다. 설치 대상은 전역이면 `~/.cursor/agents/`, 프로젝트 범위면 `.cursor/agents/`다. Cursor가 `.codex/agents/`·`.claude/agents/`도 읽지만 이는 디렉토리 호환일 뿐 포맷 호환이 아니므로(subagent는 항상 Markdown), 기존 `.toml`을 그 경로에 둬도 인식되지 않는다 — 반드시 `.md`로 새로 만든다.
- **필드 매핑**: 아래 표대로 옮긴다.

| Codex TOML | Cursor frontmatter/본문 | 메모 |
| --- | --- | --- |
| `name = "..."` | `name:` | hyphen·lowercase, 파일명과 일치 |
| `description = "..."` | `description:` | 원문 유지. `: `(콜론+공백) 포함 시 반드시 따옴표 |
| `sandbox_mode = "read-only"` | `readonly: true` | 읽기 전용 강제의 핵심 매핑 |
| `developer_instructions = """..."""` | `---` 아래 본문 | 그대로 이동 |

- **인식되는 frontmatter 키는 `name`, `description`, `model`, `readonly`, `is_background` 5개뿐**이다. Claude의 `tools:` 같은 도구 allowlist 키는 Cursor에 없다 — 도구 제한은 `readonly: true`로만 표현하고, 본문에도 "Read-only. No edits. No commits."를 남겨 이중으로 강화한다.
- `model`은 기본값이 `inherit`이라 부모 모델을 그대로 쓰면 생략한다(명시해도 무방). `is_background`는 생략한다(=false) — `review-code`는 네 리뷰어를 띄운 뒤 전원 회신을 받아 집계하므로 부모가 대기해야 하고, 병렬성은 백그라운드가 아니라 "한 턴에 여러 Task 호출"로 얻는다.
- 본문(=`developer_instructions`)이 이미 host-neutral하면 그대로 옮긴다. "Codex"·"sandbox"·`worker`/`explorer`·Claude식 도구명이 본문에 남아있지 않은지 확인한다.
- **YAML 콜론 함정**: TOML 값은 따옴표 안이라 콜론이 무해하지만, 같은 텍스트를 따옴표 없는 YAML 스칼라로 옮기면 `findings: authn`의 `: `를 파서가 매핑 구분자로 오인해 frontmatter 전체가 깨진다(`mapping values are not allowed here`). 콜론 자체는 허용되나 `: `(콜론+공백)가 값에 있으면 값을 따옴표로 감싼다(`description: "...findings: authn/authz..."`). 콜론 뒤 공백이 없으면(`http://...`) 따옴표가 필요 없다.
- **네이밍**: `name`은 Cursor가 spawn에 쓰는 식별자이자 skill 본문 참조의 대상이다. Cursor가 lowercase+hyphen을 권장하고 Codex도 hyphen을 허용하므로 세 플랫폼 모두 hyphen 이름으로 통일한다. 파일명과 `name`을 일치시키고, 내장 이름(`Explore`, `Bash`, `Browser`)과 충돌하는 custom `name`은 피한다. 이름을 바꾸면 skill 본문의 dispatch 참조도 함께 바꾼다 — 불변식은 "`name` 값 == skill의 dispatch 이름"이다(파일명은 컨벤션).

변환 예시(`security-reviewer`):

```markdown
---
name: security-reviewer
description: "Read-only code reviewer focused only on security findings: authn/authz, ..."
readonly: true
---

# Security Reviewer
...본문 (developer_instructions 내용 그대로)...
```

### Verify

- 서브 에이전트 트리 패리티: `agents/codex/*.toml`와 `agents/cursor/*.md`가 1:1로 대응하는가(확장자만 차이).
- 각 `agents/cursor/*.md` frontmatter가 실제 YAML 파서로 파싱되는가 — 특히 `description`의 `: `(콜론+공백)를 따옴표로 감쌌는가.
- 각 서브 에이전트의 `name`이 파일명·skill 본문 dispatch 참조와 일치하고 `readonly: true`가 있는가.
- 각 본문이 대응하는 Codex `developer_instructions`와 동일한가.

## Hook migration

`hooks/codex/`를 `hooks/cursor/`로 옮길 때의 규칙이다(`hooks/claude/`와 평행).

### Convert the hooks (Codex hooks.json → Cursor hooks.json)

Codex hook은 Claude식 `hooks.json`(`PreToolUse`/`PostToolUse`/`Stop`)이지만 Cursor hook은 이벤트 이름·차단 방식·I/O 스키마가 근본적으로 다르다. 단순 치환이 아니라 이벤트 모델 재매핑이다.

- **파일·경로**: `hooks.json`에 **`"version": 1` 필수**. 설치 대상은 전역 `~/.cursor/hooks.json` + `~/.cursor/hooks/`(프로젝트 범위면 `<repo>/.cursor/`). command는 상대경로 — 전역 훅은 `~/.cursor/`에서 실행되므로 `./hooks/foo.sh`로 적는다(codex의 절대경로 `$HOME/.codex/hooks/...` 대체). 스크립트는 `chmod +x` 필요.
- **이벤트 매핑**: 도구 단위 matcher 대신 목적별 이벤트로 옮긴다.

| Codex | Cursor 이벤트 | 비고 |
| --- | --- | --- |
| `SessionStart` | `sessionStart` | `hookSpecificOutput.additionalContext` → Cursor `additional_context`로 재매핑 |
| `PreToolUse` matcher `Bash` | `beforeShellExecution` | 입력에 `command`·`cwd` 제공 |
| `PostToolUse` matcher `apply_patch\|Edit\|Write` | `afterFileEdit` | 입력에 `file_path`·`edits`; **관찰 전용** |
| `Stop` | `stop` | Codex `Stop`의 `{decision:"block",reason}` → Cursor `{followup_message:...}`로 재매핑(아래) |

- **I/O·차단**: stdin JSON → stdout JSON → exit code. 모든 agent 훅에 **공통 base 필드**(`conversation_id`·`generation_id`·`workspace_roots`·`hook_event_name` 등)가 들어오나 **`cwd`는 `beforeShellExecution`에만** 있다. 차단은 `{"permission":"deny","user_message":...,"agent_message":...}`(또는 exit 2). exit 0=stdout JSON 사용, exit 2=deny, 그 외=**fail-open** — 반드시 막아야 하는 가드는 entry에 `failClosed:true`를 둔다.
- **입력 필드 변경**: `.tool_input.command`→`.command`; `.cwd`→이벤트별(`beforeShellExecution`만 `.cwd`, file/stop 계열은 `.workspace_roots[0]`); `Stop`의 `.stop_hook_active`→`stop`의 `.loop_count`(루프 가드 용도).
- **차단 메시지 이동**: codex의 `stderr`+`exit 2`를 `agent_message`(에이전트에 전달)로 옮긴다. 통과 시 `{"permission":"allow"}`+exit 0.
- **능력 손실 주의**: `afterFileEdit`는 출력 무시·차단 불가 — 포매터는 돌리되 **실패를 에이전트에 surface 못 한다**(stderr 로그만, best-effort).
- **`Stop`→`stop` doc-drift 재매핑**: Codex `Stop`은 `.stop_hook_active` 가드 + `{decision:"block",reason}`로 에이전트를 재개하지만, Cursor `stop`은 `stop_hook_active` 필드가 없다. 대신 `loop_count==0`(첫 stop) 가드로 1회만 발화하고, `{followup_message:...}`를 출력하면 Cursor가 다음 user 메시지로 자동 제출한다. repo 경로는 `.workspace_roots[0]`, 변경 파일은 `git diff --name-only HEAD`에서 `.md`를 제외해 발화 조건으로 삼는다. `beforeSubmitPrompt` 플래그 분리는 더 이상 사용하지 않는다.
- **matcher(선택)**: `beforeShellExecution`의 matcher는 *셸 명령 문자열* 정규식이다(`preToolUse`는 도구 이름). codex처럼 스크립트가 내부에서 필터하면 생략한다.

대상 `hooks/cursor/hooks.json` 예시:

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "command": "./hooks/session-context.sh" }
    ],
    "beforeShellExecution": [
      { "command": "./hooks/git-identity-guard.sh", "failClosed": true },
      { "command": "./hooks/enforce-rg.sh" },
      { "command": "./hooks/enforce-fd.sh" }
    ],
    "afterFileEdit": [{ "command": "./hooks/auto-format.sh" }],
    "stop": [{ "command": "./hooks/doc-drift-reminder.sh" }]
  }
}
```

### Verify

- hooks 트리 대응: `hooks/codex/`와 `hooks/cursor/`의 스크립트가 1:1로 매핑되는가(doc-drift는 양쪽 모두 단일 `stop` 훅).
- `hooks/cursor/hooks.json`이 유효 JSON이고 `"version":1`이 있으며 command가 `./hooks/...` 상대경로인가; 스크립트가 `chmod +x`·`bash -n`을 통과하는가.
- 샘플 stdin 스모크 테스트: session-context가 `additional_context`를 내는가; 차단 케이스가 `{"permission":"deny"}`, 통과가 `{"permission":"allow"}`를 내는가; doc-drift는 `loop_count==0` 가드와 `followup_message` 출력이 동작하는가.
- 입력 필드가 Cursor 스키마(`.command`/`.file_path`/`.workspace_roots[0]`)를 쓰는가 — 잔존 `.tool_input.command`나 무조건적 `.cwd` 의존이 없는가.

## Out of scope

- 설치/배포 배선은 이 점검표가 아니라 `scripts/apply-to-work.sh`가 담당한다(cursor 분기는 이미 구현됨) — `skills/cursor/`·`agents/cursor/`·`hooks/cursor/`를 각각 `~/.cursor/`의 `skills`·`agents`·`hooks`(+ `hooks.json`)로 동기화한다. 동작은 README의 apply-to-personal.sh / apply-to-work.sh 항목을 참고한다. 이 문서는 스킬·서브에이전트·훅 본문 마이그레이션 규칙에 집중한다.
