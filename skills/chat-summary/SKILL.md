---
name: chat-summary
description: Turn the conversation you just had into one self-contained Obsidian note — markdown with YAML frontmatter (title, category, tags, description, created_at) — reusing the vault's existing category/tag vocabulary instead of inventing near-duplicates. Use this whenever the user wants to keep what came out of a chat — "이 대화 정리해줘", "노트로 만들어줘", "옵시디언에 저장", "이거 기록해둬", "summarize this conversation", "save this as a note", "write this thread up for my vault", "turn this into markdown". Trigger even when the words "Obsidian", "note", or "skill" never appear — any signal that the research, decisions, or ideas in this conversation are worth not losing is enough. Also use when the user asks to re-summarize, split, or re-tag a note produced earlier in the session.
---

# Chat Summary

The user reaches for this when they think: *this was worth something, don't let it get buried.* Usually the conversation was research on a topic, or a design idea hammered into shape through back-and-forth.

The note has one job: **six months from now, reading only this note, the user gets the value back without reopening the chat.** That is a much higher bar than "summarize the conversation" — a transcript recap fails it, and so does a vague abstract. What survives is the *substance*: what was found, what was decided, why, what is still open, and the concrete details (versions, numbers, URLs, commands) that are annoying to reconstruct.

## 1. Scope the note

**Keep**: research findings, comparisons and tradeoffs, decisions and their reasoning, ideas and designs, working code or config, gotchas discovered, source links.

**Throw away**: greetings, the user's meta-instructions ("shorter please", "in Korean"), hedging and filler, dead-end tangents that taught nothing, restatements.

**One note = one topic.** If the conversation genuinely covered two independent subjects worth keeping, ask which one they want, or offer to split it. A note about two things is findable as neither. A minor tangent inside one topic is not a second topic — drop it or fold it into a sentence.

If the conversation produced nothing worth keeping — a quick lookup, a debugging session that ended in a one-line fix — **say so plainly instead of manufacturing a note.** A vault full of thin notes is worse than no notes.

## 2. Ground the taxonomy before choosing anything

A vault where one note is tagged `k8s`, another `kubernetes`, and a third `k8s-ops` is a vault where search stops working. So resolve the existing vocabulary **before** deciding, not after.

**[references/taxonomy.md](references/taxonomy.md) is the source of truth. Read it every time** — not from memory of what a note earlier in this session used, and not from what feels natural for the topic. The one thing that overrides it is a fresher list the user supplied in this conversation; take that when it is there, but never ask for it.

**`category`** — one value, always from the existing list, around ten in total. Plenty of notes could sit in two; `taxonomy.md` has a borderline table with worked examples, so consult it rather than deciding fresh each time — deciding fresh is exactly how a vocabulary rots. If nothing fits, do not invent one silently: pick the closest and tell the user a new category may be warranted and what you would call it.

**`tags`** — three to six, lowercase, kebab-case, English, singular unless the plural is established. Tags are **retrieval keys, not a summary**: the test is *would I type this into search when hunting for this note later?* "interesting" fails; "grafana" passes.

Prefer an existing tag every time. Before minting one, check the list for synonyms and abbreviations (`golang`/`go`, `k8s`/`kubernetes` — `taxonomy.md` has an alias table; follow it and extend it when you settle a new one), singular/plural drift (`agent` vs `agents`), and near-spellings (`llm-agent` vs `ai-agent`). Then apply the reuse test: **will this tag plausibly land on at least three more notes?** A tag used once is noise that makes every future tag decision harder — if it fails, use the nearest existing tag and let the body carry the specificity.

Do not stack a general tag on a specific one when the category already does that job: if category is `infra`, `infra` is not also a tag.

## 3. Write

Exactly these five frontmatter fields, in this order:

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

- **title** — a searchable noun phrase, specific enough to disambiguate from its neighbors. Never "대화 정리", "Chat summary", or a bare date. It doubles as the filename, so keep it free of `/ \ : * ? " < > |`.
- **description** — one sentence, roughly 40–90 characters, answering "should I open this?" for a future self scanning a list. Not a restatement of the title.
- **created_at** — `YYYY-MM-DD HH:mm` in the user's local time (KST), dated to when the *conversation* happened.

Body — use only the sections with real content; an empty section with "없음" under it is worse than no section.

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

For an English conversation use `Context / Notes / Conclusion / Open questions / References`, and match the conversation's language throughout the body.

Two conversation shapes weight these differently. **Research** ("X에 대해 알아보자") puts most of the weight in `정리`, organized by subtopic, and `참고` matters a lot — every source URL behind a claim goes in. **Idea / design** ("이거 어떻게 만들까") puts most of the weight in `결론`, because the value is the decisions; record the rejected alternatives and why, since that reasoning is the first thing to evaporate and the thing most regretted when revisiting the design.

### Writing rules

- **Add nothing the conversation did not contain.** No filling gaps from general knowledge, no rounding out a half-explored topic. If something genuinely needs a note that was not discussed, mark it: `> [!note] 노트 작성 중 추가`.
- **Preserve specifics verbatim** — version numbers, benchmark figures, flag names, commands, library names, URLs. These are the expensive-to-reconstruct parts, and the main reason the note beats memory.
- **Separate established from speculative.** A guess, an untested assumption, a "probably" — say so. A note presenting a hunch as a conclusion is worse than no note.
- **Reconstruct, don't transcribe.** No "사용자가 물었고 / 내가 답했다", no Q&A, no speaker attribution. One document in one voice.
- **Code and config: final version only**, in fenced blocks with language tags. Broken attempts go in only when the failure itself is the lesson.
- **Length**: roughly a fifth to a tenth of the conversation — 2–5 minutes to read. Self-contained, but short enough to actually reread.
- **Wikilinks only when confirmed.** `[[Some Note]]` only if a live vault scan showed it exists.

## 4. Deliver

Filename `{title}.md` with illegal characters stripped. Write into the vault when the path is known, into whatever folder the scan shows similar notes living in; otherwise write to the outputs directory and hand the file over.

**In chat, show the frontmatter block only**, plus one line inviting corrections to title/category/tags. Do not paste the note back — the user just lived through the conversation and now has the file.

Then close the vocabulary loop, because a browser chat cannot write back into the skill bundle and silent vocabulary growth is exactly the drift this skill exists to prevent:

- **Nothing new** — say nothing. Don't add noise to a clean run.
- **One to three new tags** — print just the lines to paste into `references/taxonomy.md`, under the right cluster, with any alias worth recording.
- **More than that, or a new category** — emit the full updated `taxonomy.md` as a second file to replace outright.

Keep it at the end of the message, after the frontmatter. It is bookkeeping, not the point.

## Before handing it over

- Would this make sense to someone who was not in the conversation?
- Are the specifics still in there — versions, figures, URLs, commands?
- Does every tag already exist, or does each new one pass the reuse test?
- Reading only `description`, could the user decide whether to open it?
- Is there anything in the note the conversation did not actually establish?
