---
name: chat-summary
description: Turn the conversation you just had into one self-contained Obsidian note — markdown with YAML frontmatter (title, category, tags, description, created_at) — reusing the vault's existing category/tag vocabulary instead of inventing near-duplicates. Use this whenever the user wants to keep what came out of a chat — "이 대화 정리해줘", "노트로 만들어줘", "옵시디언에 저장", "이거 기록해둬", "summarize this conversation", "save this as a note", "write this thread up for my vault", "turn this into markdown". Trigger even when the words "Obsidian", "note", or "skill" never appear — any signal that the research, decisions, or ideas in this conversation are worth not losing is enough. Also use when the user asks to re-summarize, split, or re-tag a note produced earlier in the session.
---
 
# Chat Summary
 
The user reaches for this at the end of a conversation, when they think: *this was worth something, don't let it get buried.* Usually the conversation was research on a topic, or a design idea that got hammered into shape through back-and-forth.
 
So the note has one job: **six months from now, reading only this note, the user should get the value back without reopening the chat.** That is a much higher bar than "summarize the conversation." A transcript recap fails it. A vague abstract fails it. What survives is the *substance* — what was found, what was decided, why, what's still open, and the concrete details (versions, numbers, URLs, commands) that are annoying to reconstruct.
 
## Process
 
```
Step 1: Scope     → what is this note about, and what gets thrown away
Step 2: Taxonomy  → load the existing vocabulary before picking category/tags
Step 3: Write     → frontmatter + body
Step 4: Deliver   → file out, frontmatter shown in chat, vocabulary updates flagged
```
 
---
 
## Step 1 — Scope the note
 
Read back over the whole conversation and decide what is actually worth keeping.
 
**Keep:** research findings, comparisons and tradeoffs, decisions and the reasoning behind them, ideas and designs, working code or config, gotchas discovered, source links.
 
**Throw away:** greetings and small talk, the user's meta-instructions ("shorter please", "in Korean"), the model's hedging and filler, dead-end tangents that taught nothing, restatements of the same point.
 
**One note = one topic.** If the conversation genuinely covered two independent subjects worth keeping, ask the user which one they want — or offer to split it into two notes. Don't silently staple unrelated material together; a note about two things is findable as neither. A minor tangent inside one topic isn't a second topic, just drop it or fold it into a sentence.
 
If the conversation produced nothing worth keeping — it was a quick lookup, a debugging session that ended in a one-line fix — say so plainly instead of manufacturing a note. A vault full of thin notes is worse than no notes.
 
---
 
## Step 2 — Ground the taxonomy before choosing anything
 
The whole point of controlled `category`/`tags` is that a vault where one note is tagged `k8s`, another `kubernetes`, and a third `k8s-ops` is a vault where search stops working. So resolve the existing vocabulary **before** deciding on tags, not after.
 
**`references/taxonomy.md` is the source of truth. Read it every time**, before deciding anything — not from memory of what a note earlier in this session used, and not from what feels natural for the topic. It ships with this skill, so it's always available.
 
The one thing that overrides it is a fresher vocabulary the user supplied in this conversation — an uploaded or pasted list of what the vault actually uses. Take that over the bundle when it's there, but never ask for it. The bundle drifts slowly, and Step 4 has the loop that pulls it back in sync.
 
### Choosing `category`
 
One value, always from the existing list. Category is the coarse shelf the note lives on, so the list stays small — around ten. Plenty of notes could plausibly sit in two of them; `taxonomy.md` has a borderline table with worked examples, so consult it instead of deciding fresh. Deciding fresh every time is exactly how a vocabulary rots.
 
If nothing fits, don't invent one silently — pick the closest, and tell the user you think a new category may be warranted and what you'd call it. Let them decide.
 
### Choosing `tags`
 
Three to six. Lowercase, kebab-case, English, singular unless the plural is the established form.
 
Tags are **retrieval keys, not a summary**. The test for each tag: *is this a word I'd actually type into search when hunting for this note later?* "interesting" fails. "grafana" passes.
 
Prefer an existing tag every time. Before adding a new one, check the existing list for:
- **Synonyms and abbreviations** — `golang`/`go`, `k8s`/`kubernetes`, `postgres`/`postgresql`. `references/taxonomy.md` has an alias table; follow it, and extend it when you settle a new one.
- **Singular/plural drift** — `agent` vs `agents`.
- **Near-spellings** — `llm-agent` vs `llm-agents` vs `ai-agent`.
Only mint a new tag if it passes this: **will this tag plausibly get used on at least three more notes?** A tag used once is noise that makes every future tag decision harder. If it fails the test, use the nearest existing tag instead and let the note body carry the specificity.
 
Also: don't stack a general tag on top of a specific one when the general one is already doing its job as the category. If category is `infra`, `infra` doesn't need to be a tag too.
 
---
 
## Step 3 — Write the note
 
### Frontmatter
 
Exactly these five fields, in this order:
 
```yaml
---
title: Grafana Loki 로그 파이프라인 비용 최적화
category: infra
tags:
  - grafana
  - loki
  - observability
  - cost-optimization
description: Loki 스토리지 비용을 줄이기 위한 retention/압축 옵션 비교와 최종 선택
created_at: 2026-07-29 21:40
---
```
 
- **title** — a searchable noun phrase, specific enough to disambiguate from neighbors in the vault. Never "대화 정리", "Chat summary", or the date alone. This doubles as the filename, so keep it free of `/ \ : * ? " < > |`.
- **description** — one sentence, roughly 40–90 characters. It answers "should I open this?" for a future self scanning a list. Not a restatement of the title.
- **created_at** — `YYYY-MM-DD HH:mm` in the user's local time (KST), the date the *conversation* happened.
### Body
 
Use only the sections that have real content. An empty section with "없음" under it is worse than no section.
 
```markdown
## 배경
왜 이 얘기를 꺼냈는지, 무슨 문제를 풀려던 건지. 2–4문장.
 
## 정리
본론. 주제별로 ### 소제목을 두고 산문 중심으로.
 
## 결론
확정한 것, 고른 것, 그리고 왜 그걸 골랐는지.
 
## 남은 것
미해결 질문, 다음에 확인해볼 것.
 
## 참고
- URL — 한 줄 설명
```
 
For an English conversation use `Context / Notes / Conclusion / Open questions / References` instead — match the conversation's language throughout the body.
 
Two conversations shapes show up, and they weight these sections differently:
 
- **Research** ("X에 대해 알아보자") — most of the weight in `정리`, organized by subtopic. Findings, numbers, comparisons. `참고` matters a lot here; every source URL that informed a claim goes in.
- **Idea / design** ("이거 어떻게 만들까") — most of the weight in `결론`, because the value is the decisions. Record the alternatives that were rejected and why; that reasoning is the first thing to evaporate from memory and the thing you most regret losing when you revisit the design.
### Writing rules
 
- **Don't add material the conversation didn't contain.** No filling gaps from general knowledge, no rounding out a half-explored topic. If something genuinely needs a note that wasn't discussed, mark it: `> [!note] 노트 작성 중 추가`.
- **Preserve the specifics verbatim.** Version numbers, benchmark figures, flag names, commands, library names, URLs. These are the expensive-to-reconstruct parts and the main reason the note beats memory.
- **Separate established from speculative.** If something was a guess, an untested assumption, or "probably", say so. A note that presents a hunch as a conclusion is worse than no note.
- **Reconstruct, don't transcribe.** No "사용자가 물었고 / 내가 답했다", no Q&A format, no speaker attribution. One document written by one voice.
- **Code and config: final version only.** The three broken attempts don't go in unless the failure itself is the lesson. Fenced blocks with language tags.
- **Length: roughly a fifth to a tenth of the conversation; 2–5 minutes to read.** Long enough to be self-contained, short enough to actually reread.
- **Wikilinks only when confirmed.** `[[Some Note]]` only if a live vault scan showed that note exists. A vault of broken links is a vault nobody trusts.
---
 
## Step 4 — Deliver
 
1. **Filename:** `{title}.md`, with filesystem-illegal characters stripped.
2. **Location:** write into the vault if the path is known (into whatever folder the scan shows similar notes living in); otherwise write to the outputs directory and hand the file over so the user can drop it in themselves.
3. **In chat, show the frontmatter block only** — plus one line inviting corrections to title/category/tags. Do not paste the whole note back; the user just lived through the conversation and now has the file.
4. **Close the vocabulary loop.** A browser chat can't write back into the skill bundle, so the update has to be handed to the user or it never happens — and silent vocabulary growth is exactly the drift this skill exists to prevent.
   - **Nothing new** (every tag already existed): say nothing about it. Don't add noise to a clean run.
   - **One to three new tags**: print just the lines to paste into `references/taxonomy.md`, under the right cluster and with any alias worth recording.
   - **More than that, or a new category**: emit the full updated `references/taxonomy.md` as a second file so the user can replace it outright and re-save the skill.
   Either way, keep it to the end of the message, after the frontmatter. It's bookkeeping, not the point.
## Before handing it over, check
 
- Would this make sense to someone who wasn't in the conversation?
- Are the specifics still in there — versions, figures, URLs, commands?
- Does every tag already exist, or does each new one pass the reuse test?
- Reading only `description`, could the user decide whether to open it?
- Is there anything in the note that the conversation didn't actually establish?
