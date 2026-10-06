---
name: notion-daily-briefing
description: Ensure today's Notion Daily Note, then summarize my not-Done Jira tickets into its "아침 브리핑" section.
---

# Notion Daily Briefing

Ensure today's Daily Note, summarize my open Jira tickets, and fill the note's morning-briefing section. Jira is read-only; Notion is written only in today's Daily Note.

- Jira collection (acli commands, JQL, ADF → text, troubleshooting): [references/jira-acli.md](references/jira-acli.md). Read it before step 2.
- Notion calls go through `ntn` (the `notion-cli` skill). Run `ntn api <path> --help` / `--spec` instead of guessing request shapes.

## Fixed targets

| Item | Value |
| --- | --- |
| Daily Notes data source | `$NOTION_DAILY_NOTES_DS_ID` |
| Template `YYYY-MM-DD (요일)` | `$NOTION_DAILY_NOTE_TEMPLATE_ID` |
| Properties written | `Name` (title, e.g. `2026-10-06 (화)`), `Date` (date, `YYYY-MM-DD`) |
| Section | `## 🤖 아침 브리핑 …` → `### 진행 중`, `### 백로그` (followed by `## 🌙 하루 마무리 …`) |

If an ID returns 404, re-resolve it: `ntn api v1/search -d '{"query":"Daily Notes","filter":{"property":"object","value":"data_source"}}'` and `ntn api v1/data_sources/<id>/templates`. Tell the user the new IDs so they can update the env vars.

## 0. Preflight

```bash
acli jira auth status
ntn whoami
```

If either is not authenticated, ask the user to log in themselves (`acli jira auth login --web`, `ntn login`) and stop.

If `NOTION_DAILY_NOTES_DS_ID` or `NOTION_DAILY_NOTE_TEMPLATE_ID` is unset, ask the user to set it in the agent's env settings and stop.

## 1. Find or create today's Daily Note

"Today" is the local date:

```bash
DS=$NOTION_DAILY_NOTES_DS_ID
TODAY=$(date +%F)
NAME=$(LC_ALL=ko_KR.UTF-8 date +'%F (%a)')   # 2026-10-06 (화)

ntn api v1/data_sources/$DS/query \
  -d "{\"filter\":{\"property\":\"Date\",\"date\":{\"equals\":\"$TODAY\"}}}" \
  | jq -r '.results[] | [.id, .url] | @tsv'
```

- One result → use it as `PAGE_ID`.
- More than one → show them to the user and ask which one to use.
- None → create it from the template:

```bash
jq -n --arg ds "$DS" --arg tpl "$NOTION_DAILY_NOTE_TEMPLATE_ID" --arg name "$NAME" --arg date "$TODAY" '{
  parent: {type: "data_source_id", data_source_id: $ds},
  properties: {
    Name: {title: [{text: {content: $name}}]},
    Date: {date: {start: $date}}
  },
  template: {type: "template_id", template_id: $tpl, timezone: "Asia/Seoul"}
}' | ntn api v1/pages -d @- | jq -r '[.id, .url] | @tsv'
```

The template body is applied asynchronously. Poll `ntn api v1/pages/$PAGE_ID/markdown | jq -r .markdown` every few seconds (up to ~30s) until it contains `### 백로그`. Then confirm `Name` and `Date` on `ntn api v1/pages/$PAGE_ID`; if the template overwrote them, `PATCH v1/pages/$PAGE_ID` with the same `properties` object.

## 2. Collect Jira tickets

Follow [references/jira-acli.md](references/jira-acli.md): `assignee = currentUser() AND statusCategory != Done ORDER BY key ASC`, then `view` each key for description and comments.

Group by status category:

| Status category | Section |
| --- | --- |
| `In Progress` | `### 진행 중` |
| `To Do` (e.g. `Backlog`) | `### 백로그` |

Within each section, sort by ticket number ascending (`PROJ-9` before `PROJ-10`; compare the number numerically, not as a string).

## 3. Summarize each ticket

Write 2–3 bullets per ticket, in Korean, about **where it stands now** — not its history.

- Weight the latest comments and the most recent decision most. Older comments matter only if they are still the current state (an unresolved question, a pending dependency).
- In Progress: what is done so far, what is next, and any blocker or person being waited on.
- Backlog: the goal in one line, plus what is undecided or what it is waiting on.
- Do not guess beyond the description and comments. If there is nothing to go on, write a single bullet `설명/코멘트 없음`.
- Drop greetings and bare acknowledgements. Mention a person or date only when it matters.

## 4. Write the 아침 브리핑 section

Build the replacement block. Ticket keys link to `https://<site>/browse/<KEY>` (site from `acli jira auth status`). Child bullets are indented with a tab. An empty section gets `- 없음`.

```markdown
### 진행 중
- [PROJ-101](https://example.atlassian.net/browse/PROJ-101) <summary>
	- <bullet>
	- <bullet>
### 백로그
- [PROJ-102](https://example.atlassian.net/browse/PROJ-102) <summary>
	- <bullet>
```

Replace the current `### 진행 중` … `### 백로그` contents. Everything else on the page, including the `## 🤖 아침 브리핑` heading, stays as is. On a re-run this overwrites the previous briefing instead of appending a duplicate.

```bash
OLD=$(ntn api v1/pages/$PAGE_ID/markdown | jq -r .markdown \
  | awk '/^## .*아침 브리핑/{s=1; next} s && /^### 진행 중/{f=1} f && /^## /{exit} f')

jq -n --arg old "$OLD" --arg new "$NEW" \
  '{type: "update_content", update_content: {content_updates: [{old_str: $old, new_str: $new}]}}' \
  | ntn api v1/pages/$PAGE_ID/markdown -X PATCH -d @-
```

If `OLD` is empty (the user renamed or removed the headings), do not write anywhere else. Show the page's headings and ask where to put the briefing.

After writing, re-read the markdown and check that both subsections contain the expected keys.

## 5. Report

Reply with the page URL, whether the note was created or already existed, and the ticket count per section. Do not repeat the full summaries in chat unless asked.
