---
name: summarize-week
description: Write an Obsidian weekly coding summary from Daily notes and linked Plan/Research docs. Use with an ISO week (`YYYY-WNN`) or date; saves `51. Weekly/YYYY-WNN.md`.
---

# summarize-week

Produce a `51. Weekly/YYYY-WNN.md` file in the Obsidian vault that narrates one week of coding work, derived from the week's Daily notes and the Plan / Research documents they link to.

## Vault layout

- Vault root: `${OBSIDIAN_HOME}`
- Daily notes:       `50. Daily/YYYY-MM-DD.md`
- Weekly summaries:  `51. Weekly/YYYY-WNN.md`  (this skill's output)
- Plans:             `00. Plans/...`
- Research:          `01. Research/...`

Directory names have a `NN. ` prefix and contain spaces — always quote them in shell commands.

Plan filenames follow `YYYYMMDD_{JIRA-TICKET|NO-JIRA}_{project-slug}_{topic-slug}`. Research filenames are free-form descriptive slugs.

## Required argument

One argument identifying the target week. Accept either form:

- ISO week: `2026-W17`
- Any date within the week: `2026-04-22` — resolved to the containing ISO week (Monday–Sunday)

If the user does not supply an argument, stop and ask which week before doing anything else. Do not silently assume "this week" or "last week" — the user explicitly wants the argument to be deliberate.

## Workflow

### 1. Resolve the week to a date range

Run the bundled resolver to get the canonical week id and Monday / Sunday boundary dates:

```bash
python3 <skill-dir>/scripts/resolve-week.py <argument>
```

Output is one line: `<week-id> <monday-YYYY-MM-DD> <sunday-YYYY-MM-DD>`. Capture all three.

### 2. Gather Daily notes

For each of the seven consecutive dates from Monday to Sunday, read `${OBSIDIAN_HOME}/50. Daily/YYYY-MM-DD.md` if it exists. Skip missing dates silently — not every day will have a Daily note.

If **no** Daily note exists for any day in the range, stop and tell the user. Do not create an empty summary.

### 3. Parse `## Plans & Research` from each Daily note

Each Daily note has a section shaped like:

```markdown
## Plans & Research

- [[00. Plans/20260417_BLC-683_keyway-admin_add-key-blob-schema-admin-pages]]
- [[01. Research/keyway-admin-Structure-key-blob-schema-admin-surface]]
```

Extract every wikilink under this heading until the next `##` heading or end of file.

- Strip `[[` and `]]`.
- If a link has an alias (`[[target|alias]]`), keep only the target (the part before `|`).
- A link of the form `00. Plans/foo` resolves to `${OBSIDIAN_HOME}/00. Plans/foo.md`.
- **Deduplicate across the whole week.** The same Plan often appears on several days as work continues; the weekly summary should discuss each Plan once.

Also glance at the `## What I've done` section if it has content — it sometimes carries narrative that would otherwise be missed. Treat it as supplementary, not authoritative.

### 4. Read every linked Plan and Research document

This step is the whole point of the skill. The Daily note is only an index; the real signal is inside the Plan / Research docs. Read each one in full before drafting.

What to look for:

- **Plan docs** (produced by the `plan-dev` skill) contain goal, technical approach, affected files, risks and assumptions, verification strategy, and a TODO/Tasks checklist. The checkmarks tell you what actually shipped versus what was planned-but-not-done.
- **Research docs** contain investigation notes and findings — focus on the conclusion or open question.

While reading each Plan, also record any wikilinks inside its body that point at `01. Research/...`. These are needed for classification in the next step.

### 5. Classify each Plan and Research, then synthesize

**Classify each Plan** by filename:

- Filename contains `NO-JIRA` → **Personal**
- Filename contains a Jira ticket (e.g. `BLC-683`) → **Work**

**Classify each Research** by applying these signals in order:

1. **Plan-internal links (authoritative)** — from Step 4, check which Plans link to this Research in their body. Linked from at least one Work Plan → **Work**. Linked only from Personal Plans → **Personal**.
2. **Daily note co-occurrence (fallback)** — if no Plan links to the Research, look at the Daily notes where the Research appears. Co-listed under `## Plans & Research` on the same day as at least one Work Plan → **Work**; otherwise **Personal**.
3. **Tie-breaker when signals disagree or both apply** — classify as **Work**. Work has external accountability; a followup quietly filed under Personal is easier to lose.
4. **Last resort** — if none of the above classify it (Research is linked nowhere and appears alone in Daily notes), mark as **Work** and append `(unlinked — defaulted)` to its bullet so it can be manually reclassified.

**Before drafting, identify:**

- For each of Work and Personal separately: the **projects / repos that dominated** — group related Plans by `project-slug` (third underscore-separated field of the Plan filename, e.g. `keyway-admin`, `file-diff`).
- **Jira tickets touched** — pull them from Work Plan filenames.
- **Recurring themes within each track**, plus any **cross-track patterns** worth calling out (e.g. overflow between the two sides of the week, shared techniques, one track crowding out the other).
- **Open threads per track** — TODOs not checked off, unresolved research questions.

**Use this exact template:**

```markdown
# Week <week-id> (<Mon DD> – <Sun DD>)

## Highlights

- [Work] <punchy bullet>
- [Personal] <punchy bullet>
- <2–4 bullets total; tag each with [Work] or [Personal] so the mix of the week is visible at a glance.>

## Work

### Plans Executed

- **[JIRA-TICKET] `<project-slug>`: <plan goal>** — <one-line outcome inferred from TODO checkmarks or explicit notes. Mention what's still open if relevant.>

### Research

- **<topic>** — <main finding or question answered.>

## Personal

### Plans Executed

- **`<project-slug>`: <plan goal>** — <one-line outcome.>

### Research

- **<topic>** — <main finding or question answered.>

## Themes & Patterns

<1–3 short paragraphs. Synthesize across both tracks — be explicit about which track each theme belongs to, and use cross-track contrast when it's informative (e.g. "Work dominated Monday–Wednesday; personal time was confined to Thursday afternoon"). This is the value-add — the synthesis that cannot be reconstructed from the link list alone.>

## Notes for Next Week

### Work

- <Followups, open TODOs, unresolved questions tied to Work Plans and Research.>

### Personal

- <Followups tied to Personal Plans and Research.>
```

**Formatting notes:**

- Title date range: abbreviated month + day, e.g. `Apr 20 – Apr 26`. Use the week-id verbatim.
- Keep section headings stable even when empty — if a track has no Plans or no Research this week, write `_None this week._` under the relevant subheading rather than omitting it. Historical weeks read much easier with a predictable shape.

### 6. Write the output file

Save to `${OBSIDIAN_HOME}/51. Weekly/<week-id>.md`.

If the file already exists, ask the user whether to overwrite before writing.

### 7. Report back

Print the output path and a one-line essence of the week. Do not open the file.

## Edge cases

- **Unresolved wikilink** — link target does not exist on disk. Add a `## Broken Links` appendix listing the unresolved targets rather than failing the whole run.
- **`## Plans & Research` present but malformed** (section exists but is not a bullet list of wikilinks) — include the raw section verbatim in a `## Raw Daily Content` appendix so nothing is silently dropped.
- **Existing output file** — always ask before overwriting; weekly summaries are not append-only and manual edits may have been made.
- **Year-boundary weeks** (e.g. `2026-W53`, `2027-W01`) — the resolver handles these correctly; just enumerate the seven dates it returns and read whichever Daily notes exist, ignoring the year prefix in the filename when iterating.
