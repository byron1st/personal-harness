---
name: notion-daily-briefing
description: Ensure today's Notion Daily Note, then summarize my not-Done Jira tickets into its "아침 브리핑" section and add a recap of yesterday's Jira comments and GitLab MRs/commits right after it.
---

# Notion Daily Briefing

Ensure today's Daily Note, summarize my open Jira tickets, fill the note's morning-briefing section, and add a recap of what I did yesterday. Jira and GitLab are read-only; Notion is written only in today's Daily Note.

- Jira collection (acli commands, JQL, ADF → text, troubleshooting): [references/jira-acli.md](references/jira-acli.md). Read it before step 2.
- Notion calls go through `ntn` (the `notion-cli` skill). Run `ntn api <path> --help` / `--spec` instead of guessing request shapes.

## Fixed targets

| Item | Value |
| --- | --- |
| Daily Notes data source | `$NOTION_DAILY_NOTES_DS_ID` |
| Template `YYYY-MM-DD (요일)` | `$NOTION_DAILY_NOTE_TEMPLATE_ID` |
| Properties written | `Name` (title, e.g. `2026-10-06 (화)`), `Date` (date, `YYYY-MM-DD`) |
| Section | `## 🤖 아침 브리핑 …` → `### 진행 중`, `### 백로그` (followed by `## 🌙 하루 마무리 …`) |
| Yesterday recap | Blue callout `**어제 한 일 — …**` between `### 백로그` and `## 🌙 하루 마무리 …` |
| GitLab | `glab --hostname ${WORK_GITLAB_HOST#git@}` |

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

## 5. Recap yesterday

"Yesterday" is the previous local calendar day (KST). GitLab timestamps are UTC, so the window is KST midnight to midnight expressed in UTC (for 2026-10-07: `2026-10-06T15:00:00Z` ≤ t < `2026-10-07T15:00:00Z`):

```bash
YESTERDAY=$(date -v-1d +%F)
YLABEL=$(LC_ALL=ko_KR.UTF-8 date -v-1d +'%F (%a)')   # for the callout title
S=$(date -v-2d +%F)T15:00:00Z
E=${YESTERDAY}T15:00:00Z
```

Tickets: `assignee = currentUser() AND updated >= startOfDay(-1) ORDER BY key ASC` (with `--paginate`). Updates made today also match; that is fine, because tickets with no activity yesterday drop out below.

For each key:

```bash
H=${WORK_GITLAB_HOST#git@}   # git@host → host
# Jira comments created yesterday. `comment list` has no timestamps; `view` does (KST, +0900).
acli jira workitem view "$KEY" --fields comment --json \
  | jq -r --arg d "$YESTERDAY" '.fields.comment.comments[] | select(.created | startswith($d))
      | [.created, .author.displayName, ([.body | .. | objects | select(.type=="text") | .text] | join(" "))] | @tsv'

# MRs mentioning the key, kept if created, merged, or updated in the window
glab api --hostname $H "search?scope=merge_requests&search=$KEY&per_page=100" \
  | jq -r --arg s "$S" --arg e "$E" '.[] | select([.created_at, .merged_at, .updated_at] | map(select(. != null and . >= $s and . < $e)) | length > 0)
      | [.references.full, .state, .web_url, .title] | @tsv'

# Commits mentioning the key (catches direct pushes, e.g. deployment config repos)
glab api --hostname $H "search?scope=commits&search=$KEY&per_page=100" \
  | jq -r --arg s "$S" --arg e "$E" '.[] | select(.committed_date >= $s and .committed_date < $e) | [.project_id, .short_id, .title] | @tsv'
```

- Do not add `--paginate` to the `search` calls. It walks every page and can take minutes; one page of 100 covers a day.
- Commit search only indexes default branches. Commits pushed to an unmerged branch with no MR are not found; that is acceptable.
- Resolve a `project_id` to a name with `glab api --hostname $H projects/<id> | jq -r .path_with_namespace`.
- Commits that belong to an MR listed above are already covered by that MR. Do not list them again; fold any new information into the MR bullet.

Write the recap in Korean, short and factual. One parent bullet per ticket that had activity yesterday, with 1–3 child bullets: merged/opened MRs (link `!<iid>` to `web_url`, plus a few words on what it does), direct-push work grouped by theme (e.g. STAGE 설정 추가), and the gist of any comment I wrote or that needs my reply. Skip merge commits and doc-sync chores. If nothing happened yesterday, write a single bullet `- 기록된 활동 없음`.

```markdown
<callout icon="🗓️" color="blue_bg">
	**어제 한 일 — 2026-10-07 (수)**
	- [PROJ-101](https://example.atlassian.net/browse/PROJ-101) <summary>
		- MR 머지: service-a [!12](<web_url>) <what it does>
		- service-a STAGE 설정 추가
</callout>
```

Insert it just before the `## 🌙 하루 마무리` heading:

```bash
jq -n --arg new "$CALLOUT"$'\n## 🌙 하루 마무리' \
  '{type: "update_content", update_content: {content_updates: [{old_str: "## 🌙 하루 마무리", new_str: $new}]}}' \
  | ntn api v1/pages/$PAGE_ID/markdown -X PATCH -d @-
```

On a re-run, if the page already has a callout containing `어제 한 일`, replace that callout (`<callout` … `</callout>`, as read back from the page) instead of inserting a second one. After writing, re-read the markdown and check that the callout sits between `### 백로그` and `## 🌙 하루 마무리`.

## 6. Report

Reply with the page URL, whether the note was created or already existed, the ticket count per section, and the number of tickets in the yesterday recap. Do not repeat the full summaries in chat unless asked.
