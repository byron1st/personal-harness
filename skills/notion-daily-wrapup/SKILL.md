---
name: notion-daily-wrapup
description: Ensure today's Notion Daily Note, then summarize today's Jira activity on my tickets into its "하루 마무리" section.
---

# Notion Daily Wrap-up

Summarize what happened today on my Jira tickets and write it into today's Daily Note under "하루 마무리". Jira is read-only; Notion is written only in today's Daily Note.

- Jira collection (acli commands, ADF → text, troubleshooting): [../notion-daily-briefing/references/jira-acli.md](../notion-daily-briefing/references/jira-acli.md). Read it before step 2, but use the JQL below instead of its examples.
- Notion calls go through `ntn` (the `notion-cli` skill).

## 1. Preflight and today's Daily Note

Run **only steps 0 and 1** of [../notion-daily-briefing/SKILL.md](../notion-daily-briefing/SKILL.md) (auth check, find or create today's note → `PAGE_ID`). Do not run its later steps.

## 2. Collect today's activity

```bash
TODAY=$(date +%F)
JQL='assignee = currentUser() AND updated >= startOfDay() ORDER BY key ASC'
```

`updated` also moves on field edits nobody cares about, so filter each candidate with `view`:

```bash
acli jira workitem view "$KEY" --fields "summary,status,created,statuscategorychangedate,description,comment" --json
```

Keep a ticket only if at least one of these is dated `$TODAY` (compare the `YYYY-MM-DD` prefix; values carry the local `+0900` offset):

- `.fields.created`: the ticket was created today
- `.fields.comment.comments[].created`: a comment was written today
- `.fields.statuscategorychangedate`: it moved between To Do / In Progress / Done today

If `view` returns no comments, use `comment list` as the reference describes.

## 3. Summarize each ticket

Write 2–3 bullets per ticket, in Korean, about **today only**.

- Use today's comments and today's change (created / started / finished). Read the description and older comments only as context to make today's bullets understandable; do not summarize them.
- Say what got done, what was decided, and what is left for tomorrow if today's activity says so.
- Do not guess beyond what Jira shows. Drop greetings and bare acknowledgements.

## 4. Write the 하루 마무리 section

One top-level bullet per ticket, sorted by ticket number ascending (compare numerically). Ticket keys link to `https://<site>/browse/<KEY>` (site from `acli jira auth status`). Child bullets are indented with a tab. No subsections. With no qualifying tickets, write `- 오늘 Jira 활동 없음`.

```markdown
## 🌙 하루 마무리 — 오늘 진행 내용
- [PROJ-101](https://example.atlassian.net/browse/PROJ-101) <summary> (<status>)
	- <bullet>
	- <bullet>
- [PROJ-102](https://example.atlassian.net/browse/PROJ-102) <summary> (<status>)
	- <bullet>
```

Replace the section heading and everything under it up to the next `#`/`##` heading (or the end of the page). The heading is part of `OLD` so a bare `-` placeholder never matches another section. Keep the heading line exactly as it was. On a re-run this overwrites the previous wrap-up.

```bash
OLD=$(ntn api v1/pages/$PAGE_ID/markdown | jq -r .markdown \
  | awk '/^## .*하루 마무리/{f=1; print; next} f && /^##? /{exit} f')

jq -n --arg old "$OLD" --arg new "$NEW" \
  '{type: "update_content", update_content: {content_updates: [{old_str: $old, new_str: $new}]}}' \
  | ntn api v1/pages/$PAGE_ID/markdown -X PATCH -d @-
```

If `OLD` is empty (the heading was renamed or removed), do not write anywhere else. Show the page's headings and ask where to put the wrap-up.

After writing, re-read the markdown and check that the section contains the expected keys.

## 5. Report

Reply with the page URL, whether the note was created or already existed, and the number of tickets written. Do not repeat the summaries in chat unless asked.
