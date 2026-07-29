# Taxonomy
 
The controlled vocabulary for `category` and `tags`. Read it before choosing either.
 
This list is a starting point derived from the kinds of conversations that actually get saved —
backend and distributed system design, blockchain, AI coding agents, infra operations, personal
tooling, real estate, career, and travel/life. It's meant to be curated by hand, not to be
exhaustive.
 
The vault itself is the final authority: every note carries its own tags, so this file can always
be rebuilt from what the notes actually use. See Maintenance at the bottom.
 
---
 
## Categories
 
Exactly one per note. Ten entries, and it should stay around ten — a category list that keeps
growing stops being a shelf and turns into a second tag list.
 
| category | what lives here |
|---|---|
| `dev` | 언어·런타임·라이브러리 수준의 실무 지식, 디버깅, 코드 레벨 성능 |
| `architecture` | 시스템 설계, 컴포넌트 분해, 데이터 흐름, 설계 트레이드오프 |
| `infra` | 클라우드·운영·배포·관측. 이미 돌아가는 시스템을 굴리는 쪽 |
| `blockchain` | 체인 프로토콜, 컨트랙트, 암호학, 키 관리 |
| `ai` | LLM, 코딩 에이전트, 하네스, 프롬프트, 스킬 |
| `tooling` | 내가 쓰거나 만드는 도구와 워크플로 (git, zsh, CLI, 에디터, 옵시디언) |
| `product` | 무엇을 만들지 — 서비스 아이디어, 시장·경쟁 조사, 스코프 결정 |
| `career` | 이직, JD 분석, 이력서·자기소개서, 커리어 방향 |
| `finance` | 부동산, 대출·정책, 투자, 가계 |
| `life` | 여행, 육아, 건강, 그 외 개인 |
 
### Borderline calls
 
These are the pairs that actually collide. Decide with this table rather than from scratch.
 
| 내용 | category | 왜 |
|---|---|---|
| Go 동시성 패턴, 에러 처리 관례 | `dev` | 언어 안에서 끝나는 얘기 |
| 저지연 입찰 서버 컴포넌트 설계 | `architecture` | 무엇을 어떻게 쪼갤지가 본론 |
| EKS pod에서 장시간 작업 돌리기, kubectl 조회 | `infra` | 운영 행위 |
| Envoy가 뭔지, L4/L7 프록시 구조 | `infra` | 인프라 구성요소 학습 |
| git rebase 사용법, zsh 시작 속도 | `tooling` | 도구 사용법 |
| gdiff·opml-digest 같은 내 도구 만들기 | `tooling` | 만드는 대상이 도구 |
| Ethereum reorg가 왜 생기고 어떻게 감지하나 | `blockchain` | 프로토콜 이해 |
| reorg 알림을 서비스로 팔 수 있나 | `product` | 사업성 판단 |
| reorg 알림 서버를 어떻게 설계하나 | `architecture` | 설계 결정 |
| Codex/OpenCode 시스템 프롬프트 뜯어보기 | `ai` | 에이전트 내부 구조 |
| 스킬·서브에이전트 파이프라인 구성 | `ai` | 에이전트 워크플로 설계 |
| 불변 DB 후보 비교 (Tessera, immudb) | `architecture` | 기술 선택 의사결정 |
| KMS 키 파생, PKCS#11 | `blockchain` | 암호·키 관리 묶음 |
| 진보 정부와 집값의 관계 분석 | `finance` | 시장·정책 이해 |
| 특정 JD에 맞춘 자기소개서 재작성 | `career` | |
| 영문 안내문 검수, 문서 번역 | `life` | 태그로 `translation` 부착 |
 
When it's still 50:50, ask what the note is *for*. Something you'd reopen while building is
`architecture`; while operating, `infra`; while deciding whether to build at all, `product`.
 
## Tags
 
Three to six per note. Lowercase, kebab-case, English, singular by default. Retrieval keys, not a
summary. New tags only when they'll plausibly land on three or more future notes.
 
**Language & runtime**
`go` · `typescript` · `python` · `swift` · `rust` · `bash`
 
**Backend**
`concurrency` · `performance` · `testing` · `error-handling` · `grpc` · `rest-api` · `webhook`
· `sse` · `caching` · `redis` · `api-design`
 
**Data**
`postgresql` · `mysql` · `bigquery` · `database-design` · `cdc` · `partitioning` · `migration`
· `data-integrity`
 
**Architecture**
`distributed-systems` · `event-driven` · `multi-tenancy` · `load-balancing` · `latency`
· `scalability` · `reliability`
 
**Infra & ops**
`aws` · `kubernetes` · `docker` · `terraform` · `argocd` · `gitlab-ci` · `envoy` · `nginx`
· `grafana` · `loki` · `prometheus` · `observability` · `cost-optimization` · `networking`
· `security`
 
**Blockchain**
`ethereum` · `evm` · `solidity` · `reorg` · `beacon-api` · `consensus` · `mev` · `erc20`
· `hyperledger-fabric` · `aptos` · `cryptography` · `kms` · `key-management` · `merkle-tree`
· `transparency-log` · `web3`
 
**AI**
`llm` · `claude-code` · `codex` · `opencode` · `agent-harness` · `agent-design` · `subagent`
· `system-prompt` · `prompt-engineering` · `skills` · `mcp` · `rag` · `model-comparison`
· `open-weight-model`
 
**Frontend & mobile**
`nextjs` · `react` · `react-native` · `swiftui` · `tailwind` · `ui-design` · `tui`
 
**Tooling & workflow**
`cli` · `git` · `zsh` · `macos` · `neovim` · `obsidian` · `homelab` · `tailscale` · `automation`
· `goreleaser` · `diff-algorithm` · `tmux`
 
**Career & writing**
`resume` · `cover-letter` · `job-description` · `interview` · `translation` · `english-writing`
 
**Finance**
`real-estate` · `mortgage` · `housing-policy` · `investment` · `household-finance`
 
**Life**
`travel` · `parenting` · `health` · `airbnb`
 
## Aliases
 
Normalize left to right. Extending this table when a new synonym shows up is much cheaper than
merging a split tag later.
 
| write this | not this |
|---|---|
| `go` | `golang`, `go-lang` |
| `kubernetes` | `k8s`, `kube` |
| `postgresql` | `postgres`, `psql`, `pg` |
| `typescript` | `ts` |
| `llm` | `llms`, `large-language-model` |
| `agent-design` | `agents`, `ai-agent`, `agentic` |
| `agent-harness` | `harness`, `coding-agent` |
| `nextjs` | `next`, `next-js` |
| `react-native` | `rn` |
| `observability` | `monitoring`, `o11y` |
| `rest-api` | `api`, `restful` |
| `reorg` | `re-org`, `reorganization` |
| `cost-optimization` | `cost`, `cost-saving`, `비용최적화` |
| `real-estate` | `부동산`, `property` |
| `cover-letter` | `자기소개서`, `self-introduction` |
 
Composite cases — one concept, two tags:
 
- `eks` → `kubernetes` + `aws`. Same for `nks`, `gke`.
- `pkcs11`, `hsm`, `mpc`, `tss` → `cryptography` + `key-management`.
- `pglogrepl`, `wal`, `logical-replication` → `postgresql` + `cdc`.
## Things that are not tags
 
- **Place names** (`guam`, `jeju`, `pangyo`). They belong in the title and body. `travel` or
  `real-estate` is the retrieval key; nobody searches a vault by island.
- **Products touched once** (`tesla`, `immudb`, `alchemy`). Name them in the body. If one shows
  up a third time, promote it then.
- **Sentiment or status** (`important`, `todo`, `wip`). Obsidian has better mechanisms for those,
  and they decay into lies within a month.
## Maintenance
 
Rebuild this file from the vault every couple of months, with `scan_vault.py` kept alongside the
vault (not inside this skill):
 
```bash
python scan_vault.py <vault-path> --out taxonomy.md
```
 
It reports what's actually in use, plus near-duplicate pairs and tags used exactly once — both are
cleanup signals. Paste the result back into this file and re-save the skill.
 
- A tag used exactly once either gets applied to more notes or folded into a broader one.
- Past ~150 tags the vocabulary has stopped being a vocabulary. Prune.
