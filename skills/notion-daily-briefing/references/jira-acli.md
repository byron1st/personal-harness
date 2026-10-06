# Reading my Jira tickets with acli (read-only)

How `notion-daily-briefing` and `notion-daily-wrapup` collect their input: use Atlassian's official CLI, `acli`, to read only my tickets with their descriptions and comments. The examples use the briefing's JQL; the wrap-up skill swaps in its own.

## Principles

- **Read-only.** The only commands allowed are `auth status`, `workitem search`, `workitem view`, and `workitem comment list`. Never run `create`, `edit`, `transition`, `assign`, or `comment create/update/delete`.
- The scope is the calling skill's JQL. Do not read any other tickets.
- Always settle the list of keys with `search` first, before calling `view` on individual tickets.

## 0. Preflight

```bash
acli --version
acli jira auth status
```

If not authenticated, ask the user to run `acli jira auth login --web` themselves and stop. Do not attempt to log in on their behalf. Note that `acli jira auth` is separate from the authentication for `acli confluence` and `acli admin`.

`auth status` also prints the site (e.g. `example.atlassian.net`); ticket links are `https://<site>/browse/<KEY>`.

## 1. Build the list of target ticket keys

```bash
JQL='assignee = currentUser() AND statusCategory != Done ORDER BY key ASC'

acli jira workitem search --jql "$JQL" --fields "key,summary,status" --json --paginate
```

Things to watch for:

- **Without `--paginate`, only the first page is returned, silently.** There is no warning, so always include it.
- Filter on `statusCategory`, not `status`: status names differ per project (`To Do`, `Open`, `In Review`, …), but every status belongs to one of the three categories `To Do`, `In Progress`, `Done`. On Jira Software boards, "Backlog" is often not a status at all, so `status = "Backlog"` may match nothing.
- The status category is at `.fields.status.statusCategory.name` (or `.key`: `new` / `indeterminate` / `done`). If it is missing from the search output, read it from `view`.
- `search` rejects some fields (`created`, `statuscategorychangedate`, …) with "not allowed". Request those on `view` instead.
- The JSON shape (array vs. object, whether values live under `.fields`) can vary by version. Run `jq 'type, (.[0] | keys)'` once to inspect the shape, then adjust the jq filters.

Extract just the keys:

```bash
acli jira workitem search --jql "$JQL" --fields "key" --json --paginate | jq -r '.[].key'
```

## 2. Read each ticket's description and comments

```bash
acli jira workitem view "$KEY" --fields "summary,status,description,comment,updated" --json
```

If the `view` output has no comments, fetch them separately:

```bash
acli jira workitem comment list --key "$KEY" --json --paginate
```

For tickets with many comments, fetch all of them with `--paginate`, but when summarizing focus on recent comments and decisions.

## 3. Convert ADF to plain text

In Jira Cloud, both the description and comment bodies are ADF (Atlassian Document Format) JSON. Do not read the raw JSON; extract the text.

```bash
# Concatenate only the text nodes from an ADF document
adf_text() {
  jq -r '[.. | objects | select(.type == "text") | .text] | join("")'
}

acli jira workitem view "$KEY" --fields "description" --json | jq '.fields.description' | adf_text
```

If paragraph boundaries matter, split by `paragraph` nodes:

```bash
jq -r '.. | objects | select(.type == "paragraph") | [.. | objects | select(.type == "text") | .text] | join("")'
```

For tickets where code blocks, links, or mentions matter, also extract those nodes (for mentions, use `attrs.text` on `mention` nodes).

## 4. One-shot collection script

```bash
#!/usr/bin/env bash
set -euo pipefail

JQL='assignee = currentUser() AND statusCategory != Done ORDER BY key ASC'

acli jira auth status >/dev/null

keys=$(acli jira workitem search --jql "$JQL" --fields "key" --json --paginate | jq -r '.[].key')

for key in $keys; do
  echo "=== $key ==="
  acli jira workitem view "$key" --fields "summary,status,description,comment,updated" --json
done
```

If there are many tickets (roughly 20 or more), do not load all of them into context at once. Show the key list first, then read and summarize them group by group.

## 5. Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| Zero results | Check the real status categories: `acli jira workitem search --jql 'assignee = currentUser() AND updated >= -30d' --fields "key,status" --json --paginate \| jq -r '.[].fields.status.statusCategory.name' \| sort \| uniq -c` |
| Result count is exactly one page | `--paginate` is missing |
| `unauthorized`-style error | Expired token. Ask the user to re-run `acli jira auth login --web` |
| A mistyped subcommand does not error | `acli jira <unknown> --help` falls back to `acli jira --help` with no error. If the output is general help, suspect the command |
| Comments are empty | The `comment` field was not honored by `--fields` on `view`. Call `comment list` separately |
