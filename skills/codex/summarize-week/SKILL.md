---
name: summarize-week
description: Summarize one week of coding work from repository-local docs/agents plan, implementation, and research documents. Use with an ISO week (`YYYY-WNN`) or date; outputs the summary in chat.
---

# summarize-week

Produce a chat summary for one week of coding work, derived from `docs/agents/dev` Plan / Implementation Report documents and related `docs/agents/research` documents.

## Document layout

- Project docs root: `docs/agents`
- Plans and implementation reports: `docs/agents/dev/`
- Research: `docs/agents/research/`

Plan filenames follow `{timestamp}_{JIRA-TICKET|NO-JIRA}_PLAN_{title}.md`. Implementation report filenames follow `{timestamp}_{JIRA-TICKET|NO-JIRA}_IMPL_{title}.md`. Research filenames are descriptive slugs.

## Required argument

One argument identifying the target week. Accept either form:

- ISO week: `2026-W17`
- Any date within the week: `2026-04-22` - resolved to the containing ISO week (Monday-Sunday)

If the user does not supply an argument, stop and ask which week before doing anything else. Do not silently assume "this week" or "last week"; the user explicitly wants the argument to be deliberate.

## Workflow

### 1. Resolve the week to a date range

Run the bundled resolver to get the canonical week id and Monday / Sunday boundary dates:

```bash
python3 <skill-dir>/scripts/resolve-week.py <argument>
```

Output is one line: `<week-id> <monday-YYYY-MM-DD> <sunday-YYYY-MM-DD>`. Capture all three.

### 2. Gather plan and implementation documents

List markdown files under `docs/agents/dev/`. Select files whose leading timestamp falls within the resolved Monday-Sunday date range.

Timestamp parsing:
- File format begins with `YYYYMMDDHHMMSS_`.
- Use the `YYYYMMDD` prefix for week inclusion.
- Include both `_PLAN_` and `_IMPL_` files.

If no Plan or Implementation Report exists for the range, stop and tell the user. Do not create an empty summary.

### 3. Read linked and related Research documents

Read every selected Plan and Implementation Report in full before drafting.

While reading:
- Record Markdown links that point at `docs/agents/research/` or `../research/`.
- Also read `docs/agents/research/index.md` and include research files whose indexed `Application` matches an application mentioned by a selected Plan or Implementation Report and whose `Description` clearly overlaps the week's work.
- Deduplicate research documents across the whole week.

If `docs/agents/research/index.md` is missing, use only research files directly linked from the selected Plan / Implementation Report documents. Do not scan every research file to infer metadata.

Research docs contain investigation notes and findings; focus on conclusions, constraints, and open questions.

### 4. Classify documents, then synthesize

**Classify each Plan / Implementation Report** by filename:

- Filename contains `NO-JIRA` -> **Personal**
- Filename contains a Jira ticket (e.g. `BLC-683`) -> **Work**

**Classify each Research** by applying these signals in order:

1. **Plan/report links (authoritative)** - linked from at least one Work document -> **Work**. Linked only from Personal documents -> **Personal**.
2. **Application and topic overlap (fallback)** - if no document links to the Research, compare indexed metadata and description against selected documents. If it overlaps Work, classify as **Work**; otherwise **Personal**.
3. **Tie-breaker when signals disagree or both apply** - classify as **Work**. Work has external accountability; a follow-up quietly filed under Personal is easier to lose.
4. **Last resort** - if none of the above classify it, mark as **Work** and append `(unlinked - defaulted)` to its bullet so it can be manually reclassified.

**Before drafting, identify:**

- For each of Work and Personal separately: the projects / repos that dominated. Use the document frontmatter `Application` field, falling back to the current repository basename when missing.
- Jira tickets touched.
- Recurring themes within each track, plus any cross-track patterns worth calling out.
- Open threads per track: TODOs not checked off, unresolved research questions, open report questions.

**Use this exact template:**

```markdown
# Week <week-id> (<Mon DD> - <Sun DD>)

## Highlights

- [Work] <punchy bullet>
- [Personal] <punchy bullet>
- <2-4 bullets total; tag each with [Work] or [Personal] so the mix of the week is visible at a glance.>

## Work

### Plans / Implementations

- **[JIRA-TICKET] `<Application>`: <plan goal>** - <one-line outcome inferred from TODO checkmarks, implementation reports, or explicit notes. Mention what's still open if relevant.>

### Research

- **<topic>** - <main finding or question answered.>

## Personal

### Plans / Implementations

- **`<Application>`: <plan goal>** - <one-line outcome.>

### Research

- **<topic>** - <main finding or question answered.>

## Themes & Patterns

<1-3 short paragraphs. Synthesize across both tracks. Be explicit about which track each theme belongs to, and use cross-track contrast when it is informative.>

## Notes for Next Week

### Work

- <Followups, open TODOs, unresolved questions tied to Work Plans, Implementation Reports, and Research.>

### Personal

- <Followups tied to Personal Plans, Implementation Reports, and Research.>
```

**Formatting notes:**

- Title date range: abbreviated month + day, e.g. `Apr 20 - Apr 26`. Use the week-id verbatim.
- Keep section headings stable even when empty. If a track has no Plans / Implementations or no Research this week, write `_None this week._` under the relevant subheading rather than omitting it.

### 5. Report back

Print the weekly summary directly in chat. Do not write a weekly summary file.

## Edge cases

- **Unresolved Markdown link** - link target does not exist on disk. Add a `## Broken Links` appendix listing the unresolved targets rather than failing the whole run.
- **Malformed filename** - if a file in `docs/agents/dev/` does not match the timestamp prefix pattern, skip it and mention it in a short note only if it appears relevant to the requested week.
- **Year-boundary weeks** (e.g. `2026-W53`, `2027-W01`) - the resolver handles these correctly. Just enumerate the seven dates it returns and match timestamp prefixes against those dates.
