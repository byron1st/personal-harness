# Pi Flow 워크플로우 아키텍처

## 목적

이 문서는 Pi Coding Agent 위에 개인 코어 개발 워크플로우를 구축하기 위한 전체 그림을 정의한다. 목표는 기존 Codex 하네스처럼 사용자가 각 스킬을 매번 직접 호출하는 방식에 머무르지 않고, Pi 확장이 워크플로우의 상태, 전이 조건, 산출물, 검증 게이트를 관리하는 구조를 만드는 것이다.

대상 코어 워크플로우는 다음과 같다.

```text
plan-dev -> implement-dev -> fix-dev (optional, loop) -> test-dev (optional) -> review-code (optional) -> apply-review-results via custom prompts (optional) -> commit-code -> request-merge (optional)
```

## 핵심 관점

Pi에서도 단계별 작업 규약은 여전히 skill로 유지하는 것이 좋다. 다만 Pi의 장점은 skill을 사용자가 직접 순서대로 호출하는 명령 목록으로만 쓰지 않고, 확장이 참조하는 단계별 프로토콜로 다룰 수 있다는 점이다.

따라서 최종 구조는 다음처럼 잡는다.

- `skills/pi/*`: 각 단계의 상세 실행 계약. 기존 Codex skill을 Pi 실행 모델에 맞게 변환한 문서 자산.
- `agents/pi/*`: 리뷰어, 구현자, 검증자 등 재사용 가능한 persona agent 정의. Pi subagent 확장 또는 자체 flow 확장이 읽는다.
- `pi-flow` 확장: 워크플로우 런타임. 상태 저장, 다음 단계 추천/실행, 읽기 전용 게이트, 검증 게이트, 리뷰 finding queue, commit/MR 준비 게이트를 담당한다.
- `pi-harness` package: skills, agents, extension, prompt templates, themes/config를 묶어 설치 가능한 Pi package.

핵심 개선은 자동화량 자체가 아니라, 매 단계의 산출물과 전이 조건을 명시적으로 보존해서 긴 작업이 세션, 컨텍스트, 수동 호출 순서에 덜 의존하게 만드는 것이다.

## Pi가 구조를 바꾸는 이유

Codex, Claude Code, Cursor 하네스에서는 제품이 이미 제공하는 plan mode, hooks, subagents, permissions 같은 표면에 skill을 맞춘다. Pi는 의도적으로 작은 코어를 유지하고 extension, skills, prompt templates, packages로 워크플로우별 동작을 밀어낸다. 이 때문에 Pi 중심 하네스는 "문서와 복사 스크립트"보다 "상태 있는 TypeScript extension + 문서화된 skill protocol" 쪽이 자연스럽다.

Pi 코어만으로는 plan mode, MCP, subagent, permission popup, hook system이 기본 제공되지 않는다고 가정한다. 필요한 기능은 Pi extension 또는 Pi package로 제공한다.

## 사용자 경험

최종 사용 경험은 명령형 skill chain이 아니라 `/flow` 중심이다.

```text
/flow start <goal or SPEC.md or note>
/flow status
/flow next
/flow review
/flow apply-review
/flow commit
/flow mr
```

일반적인 흐름은 다음과 같다.

1. 사용자가 `/flow start`로 작업 목표를 준다.
2. 확장이 flow state를 만들고 `plan-dev`를 현재 단계로 설정한다.
3. agent는 `plan-dev` skill을 로드해 계획을 작성하되, 확장은 쓰기 가능한 도구를 막아 plan gate를 만든다.
4. 사용자가 계획을 승인하면 확장이 plan artifact를 저장하고 `implement-dev`로 전이한다.
5. 구현 후 확장이 plan TODO, implementation report, verification command, git diff를 검사해 다음 전이를 허용한다.
6. 필요하면 `fix-dev`, `test-dev`, `review-code`를 반복한다.
7. review findings는 queue로 저장되고, `/flow apply-review`가 finding 단위의 fix prompt를 생성한다.
8. commit 직전에는 identity, doc drift, verification freshness, dirty artifact policy를 확인한다.
9. request-merge는 commit과 branch readiness가 맞을 때만 실행한다.

## 워크플로우 상태 모델

Flow 상태는 Pi session context에만 묻지 말고 파일로 저장한다. 세션을 fork, resume, compact해도 워크플로우 상태가 살아 있어야 한다.

권장 위치는 다음과 같다.

```text
.pi/flow/state.json
.pi/flow/events.jsonl
.pi/flow/findings.jsonl
.pi/flow/artifacts.json
```

상태 예시는 다음과 같다.

```json
{
  "flowId": "20260609-personal-harness-pi-flow",
  "status": "active",
  "currentStep": "implement-dev",
  "goal": "Build the core workflow on top of Pi Agent",
  "mode": "single-step",
  "plan": {
    "path": "/Users/a13340/Obsidian/Notes/00. Plans/20260609_NO-JIRA_personal-harness_pi-flow.md",
    "approvedAt": "2026-06-09T11:30:00+09:00"
  },
  "implementation": {
    "reportPath": "/Users/a13340/Obsidian/Notes/02. Implementation Reports/20260609_NO-JIRA_personal-harness_pi-flow.md",
    "lastVerification": {
      "command": "make test",
      "status": "passed",
      "finishedAt": "2026-06-09T12:45:00+09:00"
    }
  },
  "review": {
    "status": "pending",
    "openFindings": 0
  },
  "git": {
    "branch": "feature/pi-flow",
    "base": "main",
    "commitPolicy": "manual"
  }
}
```

## 단계별 계약

각 워크플로우 단계에는 계약이 있다. 이 계약은 일부는 skill에 있고, 일부는 확장이 강제한다.

| 단계 | 스킬 책임 | 확장 책임 |
| --- | --- | --- |
| `plan-dev` | 리서치, 가정 명확화, 한국어 plan/research 작성, TODO와 verification 정의. | 승인 전 읽기 전용 게이트 강제, 승인 후 plan artifact 저장, plan path 등록. |
| `implement-dev` | TDD로 plan 실행, TODO 즉시 갱신, implementation report 작성. | 현재 plan/report 추적, TODO/report 존재 확인, verification evidence 기록, report 없이 전이 방지. |
| `fix-dev` | 경계가 분명한 결함을 진단하고 수정하며 report에 `## Fix` 추가. | fix를 finding/report에 연결, 시도 횟수 추적, loop scope 유지, 사용자가 강제하지 않는 broad redesign 차단. |
| `test-dev` | test-only 개선, mutation/e2e hardening 수행. | 가능한 경우 test file write scope 강제, production defect 의심은 별도 기록. |
| `review-code` | 네 축 리뷰를 실행하고 findings 생성. | reviewer subagent orchestration, finding 정규화와 중복 제거, finding queue 저장. |
| `apply-review-results` | 승인된 findings를 focused prompt로 적용. | finding 단위 또는 root cause가 같은 cluster 단위 prompt 생성, finding lifecycle 표시. |
| `commit-code` | eligible changes로 commit 생성. | identity, doc drift, verification freshness, excluded artifact policy 검사. |
| `request-merge` | `gh` 또는 `glab`으로 PR/MR 생성 또는 갱신. | branch push, commit 존재, review/fix/test gate resolved 또는 explicit skip 여부 확인. |

## 상태 머신

워크플로우는 `/flow next`가 왜 진행 가능한지 또는 왜 진행할 수 없는지 정확히 말할 수 있을 만큼 명시적이어야 한다.

```text
new
  -> planning
  -> plan-review
  -> plan-approved
  -> implementing
  -> implementation-review
  -> fixing
  -> testing
  -> code-review
  -> applying-review
  -> ready-to-commit
  -> committed
  -> ready-to-merge-request
  -> merge-requested
  -> complete
```

Optional step은 보이지 않게 사라지면 안 된다. 이유와 시각이 있는 명시적 skip decision으로 남긴다.

Skip record 예시는 다음과 같다.

```json
{
  "step": "test-dev",
  "decision": "skipped",
  "reason": "Implementation only changed Markdown documentation",
  "decidedBy": "user",
  "decidedAt": "2026-06-09T13:00:00+09:00"
}
```

## Flow 명령

### `/flow start`

새 flow를 시작한다. 자유 형식 목표, SPEC path, Obsidian note reference, issue URL, local file reference를 받을 수 있다.

책임은 다음과 같다.

- `.pi/flow/state.json` 생성.
- repository root, branch, base branch, current dirty state, relevant instruction files 기록.
- 초기 모드 선택. 기본은 single-step이고, multi-step은 명시적 요청이 있을 때만 사용한다.
- `plan-dev` 계약을 호출하는 prompt queue 생성.

### `/flow status`

대화 히스토리에서 모델이 상태를 추론하게 하지 않고 현재 상태를 직접 보여준다.

출력에는 다음이 포함되어야 한다.

- 현재 단계.
- 필요한 artifact paths.
- 열린 blocker.
- 마지막 verification command/result/time.
- 열린 review findings.
- 추천 next command.

### `/flow next`

다음으로 허용되는 전이를 계산한다. 먼저 결정적으로 판단하고, 필요한 경우에만 모델 보조 판단을 사용한다.

예시는 다음과 같다.

- 현재 단계가 `planning`이고 plan이 승인되지 않았다면 approval이 필요하다고 말한다.
- 현재 단계가 `implementing`이고 report가 없으면 agent에게 `implement-dev` report를 마무리하라고 요청한다.
- 구현이 끝났고 review가 optional이면 `review-code` 실행, skip, commit 진행 중 무엇을 할지 묻는다.
- review findings가 있으면 `/flow apply-review`로 라우팅한다.

### `/flow review`

review 단계를 실행한다. 가능하면 Pi subagent를 사용한다.

기본 reviewer는 다음과 같다.

- `security-reviewer`
- `reliability-reviewer`
- `maintainability-reviewer`
- `senior-generalist-reviewer`

이 명령은 diff/context를 한 번만 수집하고, 병렬 reviewer task를 dispatch한 뒤, 모든 결과를 기다리고, location/root cause 기준으로 중복 제거한 다음 `.pi/flow/findings.jsonl`에 findings를 저장한다.

### `/flow apply-review`

review 결과를 막연한 "전부 고쳐줘" prompt로 만들지 않고 통제된 방식으로 적용한다.

모드는 다음과 같다.

- `--finding <id>`: finding 하나를 적용한다.
- `--all`: 승인된 모든 findings를 적용하되, root cause가 같은 경우에만 묶는다.
- `--plan-only`: 편집 없이 findings에 대한 fix plan만 만든다.
- `--reject <id> --reason <text>`: finding을 의도적으로 적용하지 않았다고 표시한다.

각 accepted finding에 대해 확장은 focused prompt를 생성한다.

```text
Use fix-dev for finding FLOW-FINDING-003.

Finding:
...

Scope:
- Fix only this finding and tightly coupled tests.
- Do not refactor adjacent code.
- Update the existing implementation report under ## Fix.
- Run the recorded verification commands.
```

### `/flow commit`

commit gate를 실행한 뒤 `commit-code` 계약을 호출한다.

게이트 검사는 다음과 같다.

- Git identity가 personal/work repository type과 일치한다.
- 필요한 docs drift check가 unresolved 상태로 남아 있지 않다.
- Plan TODO가 최신이다.
- Implementation report가 존재한다.
- Review findings가 resolved, rejected, 또는 explicitly deferred 상태다.
- Verification이 현재 diff에 대해 충분히 최신이다.
- 제외해야 할 artifact가 staged 상태가 아니다.

### `/flow mr`

merge-request gate를 실행한 뒤 `request-merge`를 호출한다.

게이트 검사는 다음과 같다.

- Branch가 base보다 적어도 하나 이상의 commit을 가진다.
- Remote가 설정되어 있다.
- 현재 branch가 push되어 있거나 사용자가 push를 승인한다.
- PR/MR title을 유도할 수 있거나 필요한 ticket이 제공되어 있다.
- Optional review-after-MR policy가 알려져 있다.

## 확장 도구

확장은 사용자용 slash command만 제공하지 말고, 모델이 호출할 수 있는 도구도 노출해야 한다.

후보 도구는 다음과 같다.

- `flow_state_read`: 정규화된 flow state를 읽는다.
- `flow_state_update`: 통제된 state field를 갱신한다.
- `flow_transition`: evidence와 함께 state transition을 요청한다.
- `flow_register_artifact`: plan/report/research/MR URL을 등록한다.
- `flow_record_verification`: command, status, summary, timestamp를 기록한다.
- `flow_record_finding`: review finding을 추가하거나 갱신한다.
- `flow_generate_fix_prompt`: finding에 대한 focused prompt를 생성한다.
- `flow_gate_check`: deterministic readiness check를 실행한다.

이 도구들은 모델이 chat 안에 들고 있어야 하는 상태량을 줄인다. 또한 워크플로우가 실제로 지켜졌는지 감사하기 쉽게 만든다.

## 이벤트 훅과 가드

Pi 코어가 Codex-style hook system을 직접 제공할 필요는 없다. flow 확장이 Pi event를 직접 구독할 수 있다면 충분하다. 가능한 경우 확장은 tool call과 session event를 가로채야 한다.

필요한 가드는 다음과 같다.

- Search guard: code search에 recursive `grep` 사용을 막고 `rg`를 제안한다.
- File search guard: file/code search에 `find` 사용을 막고 `fd`를 제안하되, metadata-only `find`는 허용한다.
- Git identity guard: local identity가 personal/work remote classification과 맞지 않으면 `git commit`과 `git push`를 막는다.
- Plan read-only guard: `planning`과 `plan-review` 동안 `write`, `edit`, unsafe `bash`를 막는다.
- Test-dev write scope guard: `test-dev` 동안 사용자가 test-only contract를 명시적으로 벗어나지 않는 한 non-test production file edits를 막는다.
- Doc drift guard: commit/MR/complete 전 source가 바뀌었는데 `README.md`, `AGENTS.md`, `CLAUDE.md` 검토가 없으면 확인한다.
- Auto-format: 파일 변경 후 `make fmt` 또는 `make format`이 있으면 실행하고 실패를 flow state에 보고한다.

가드는 blocked action과 correction hint를 모두 `events.jsonl`에 기록해야 한다.

## Plan Mode 에뮬레이션

Pi가 Codex plan mode를 정확히 복제할 필요는 없다. flow 확장은 이 하네스에 맞는 더 좁은 gate를 구현하면 된다.

Plan gate 동작은 다음과 같다.

- `currentStep = planning`이면 read-only tool policy가 활성화된다.
- 허용되는 built-in tools는 `read`, `grep`, `find`, `ls`다.
- Shell 사용은 비활성화하거나 읽기 전용 command로 제한한다.
- 사용자 승인 전까지 Obsidian과 repo에 대한 write를 막는다.
- Plan content는 memory 또는 extension-managed pending state에 draft한다.
- 승인되면 확장이 research files, plan files, daily note update 순서로 persistence를 수행한다.

중요한 불변식은 UI label이 "plan mode"인지가 아니라, 사용자가 계획을 승인하기 전에 durable side effect가 발생하지 않는다는 점이다.

## Subagent Orchestration

Pi subagent는 사용자가 직접 조율해야 하는 별도 기능이 아니라 `/flow` 뒤의 execution backend로 취급해야 한다.

권장 agent role은 다음과 같다.

- `planner`: read-only plan critique와 gap finder.
- `worker`: delegation이 요청되었거나 유용한 경우 implementation/fix executor.
- `verifier`: code를 변경하지 않고 check 실행과 evidence 수집.
- `security-reviewer`: security axis 전용.
- `reliability-reviewer`: reliability axis 전용.
- `maintainability-reviewer`: maintainability axis 전용.
- `senior-generalist-reviewer`: 나머지 ISO 25010, 운영, product fit 이슈.
- `docs-writer`: doc drift와 research sync 지원.

Review에서는 병렬성이 가치 있다. Multi-step implementation에서는 보통 병렬성의 가치가 낮다. 이 하네스는 각 step을 병합하기 전에 per-step review gate를 기대하기 때문이다. 따라서 flow 확장은 parallel review를 지원하되, 미래 workflow가 independent worktrees와 merge policy를 명시적으로 정의하기 전까지 implementation step은 sequential하게 유지해야 한다.

## Artifact Registry

Flow 확장은 모델에게 file path를 기억하게 하지 말고 artifact registry를 유지해야 한다.

Artifact type은 다음과 같다.

- `plan`
- `sub-plan`
- `research`
- `implementation-report`
- `review-report`
- `verification-log`
- `commit`
- `pull-request`
- `merge-request`

예시는 다음과 같다.

```json
{
  "artifacts": [
    {
      "type": "plan",
      "path": "/Users/a13340/Obsidian/Notes/00. Plans/20260609_NO-JIRA_personal-harness_pi-flow.md",
      "createdAt": "2026-06-09T11:30:00+09:00"
    },
    {
      "type": "commit",
      "sha": "abc1234",
      "title": "feat: add pi flow controller design",
      "createdAt": "2026-06-09T14:00:00+09:00"
    }
  ]
}
```

## Findings Queue

Review findings는 일급 workflow object여야 한다.

Finding lifecycle은 다음과 같다.

```text
open -> accepted -> applying -> resolved
open -> rejected
open -> deferred
resolved -> verified
```

Finding shape는 다음과 같다.

```json
{
  "id": "FLOW-FINDING-003",
  "source": "reliability-reviewer",
  "priority": "HIGH",
  "title": "Context not propagated to downstream call",
  "location": "internal/billing/service.go:L88-L92",
  "body": "Korean review comment...",
  "status": "open",
  "fixReportPath": null,
  "verification": null
}
```

이 구조는 `/flow apply-review --finding FLOW-FINDING-003`를 가능하게 만들고, review result를 적용하는 custom prompt를 재현 가능하게 만든다.

## Pi 아키텍처에서 Skill의 역할

"이게 결국 skill 호출과 다른가?"에 대한 답은 다음과 같다. 확장이 상태와 전이를 소유한다면 다르다.

Skills는 깊은 human workflow rule을 인코딩하므로 계속 가치 있다.

- TDD 기대치.
- Obsidian plan/report format.
- 한국어 문서 언어 규칙.
- Review finding format.
- Commit title policy.
- Work/personal repository handling.

하지만 확장이 결정하는 것은 다음과 같다.

- 지금 활성화된 skill contract.
- Preconditions 충족 여부.
- Scope에 들어가는 artifacts.
- 다음 단계 허용 여부.
- 다음에 model로 보낼 prompt.
- Commit/MR 전 반드시 통과해야 하는 deterministic checks.

이 분리는 skill 문서를 portable하게 유지하면서도 Pi를 workflow runtime으로 만든다.

## 패키지 레이아웃

장기 package layout은 다음과 같다.

```text
pi/
├── flow-workflow-architecture.md
└── package/
    ├── package.json
    ├── extensions/
    │   └── flow/
    │       ├── index.ts
    │       ├── state.ts
    │       ├── gates.ts
    │       ├── prompts.ts
    │       ├── artifacts.ts
    │       ├── findings.ts
    │       └── subagents.ts
    ├── skills/
    │   ├── plan-dev/
    │   ├── implement-dev/
    │   ├── fix-dev/
    │   ├── test-dev/
    │   ├── review-code/
    │   ├── commit-code/
    │   └── request-merge/
    ├── agents/
    │   ├── security-reviewer.md
    │   ├── reliability-reviewer.md
    │   ├── maintainability-reviewer.md
    │   └── senior-generalist-reviewer.md
    └── prompts/
        ├── apply-review-finding.md
        ├── flow-next.md
        └── summarize-flow.md
```

Top-level repository는 package가 성숙할 때까지 `skills/pi`, `agents/pi`, `hooks/pi`를 계속 둘 수 있다. Pi package가 source of truth가 되면 install scripts는 해당 폴더에서 package로 복사하거나 `pi install`로 package를 직접 설치할 수 있다.

## 마이그레이션 전략

Pi는 Codex 아래의 부차적 변형이 아니라 first-class variant가 되어야 한다.

권장 source direction은 다음과 같다.

```text
Codex -> Pi for host-neutral skill behavior
Pi extension -> Pi-specific runtime behavior
Pi -> Codex/Claude/Cursor only for reusable workflow insights, not for runtime features
```

나중에 추가할 문서는 다음과 같다.

- `MIGRATE_TO_PI.md`: Codex/Claude/Cursor skill, agent, hook을 Pi로 변환하는 규칙.
- `MIGRATE_FROM_PI.md`: Pi workflow concept 중 Codex/Claude/Cursor로 backport 가능한 것과 불가능한 것.
- `pi/package/README.md`: install, trust, settings, package contents, security model.

## 열린 설계 결정

다음 항목은 의도적으로 구현 시점의 설계 결정으로 남긴다.

- Subagent orchestration을 `pi-flow`에 직접 구현할지, 기존 Pi subagent package에 의존할지.
- Hook-like guard를 `pi-flow`의 native event handler로 구현할지, YAML hook package로 표현할지.
- `.pi/flow/state.json`을 commit할지, ignore할지, committed template과 ignored runtime state로 나눌지.
- Obsidian write를 `obsidian` CLI 호출로 처리할지, dedicated extension tool로 처리할지.
- Context7을 Pi extension, CLI wrapper, local MCP-like bridge 중 어떤 형태로 통합할지.
- `/flow next`가 다음 prompt를 제안만 할지, 사용자 확인 후 자동 queue에 넣을지.

## 비목표

- Pi가 Codex나 Claude Code의 모든 기능을 일대일로 흉내 내게 만들지 않는다.
- 사용자 approval gate를 automation 뒤에 숨기지 않는다.
- Existing per-step review policy 없이 subagent가 implementation work를 auto-merge하게 두지 않는다.
- 모든 optional stage를 mandatory process overhead로 만들지 않는다.
- 확장이 skill에 속해야 할 technical implementation detail까지 소유하게 만들지 않는다.

## 참고 자료

- Pi documentation: https://pi.dev/docs/latest
- Pi skills: https://pi.dev/docs/latest/skills
- Pi usage and tool options: https://pi.dev/docs/latest/usage
- Pi settings and resources: https://pi.dev/docs/latest/settings
- Pi extensions: https://pi.dev/docs/latest/extensions
- Pi packages: https://pi.dev/docs/latest/packages
- Pi subagent package reference: https://pi.dev/packages/pi-sub-agent
- Pi YAML hooks package reference: https://pi.dev/packages/pi-yaml-hooks
