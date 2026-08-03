---
name: application-research-sync
description: Sync repository-local docs/agents/research files with code changes. Use after implementation, when research docs may be stale, or when asked to update research against uncommitted changes, a commit range, or the full codebase.
---

# Application Research Sync

Automatically update repository-local Research files based on code changes.

## Background

- **Research files**: Markdown documents in `docs/agents/research/` that investigate and describe an Application's (identified by Git repository name) features, flows, or architecture. Each file has a `Description` field in its frontmatter.
- **Research index**: `docs/agents/research/index.md`, a metadata table containing each Research file's frontmatter fields plus a Markdown link to the file. Agents read this first to decide which Research files to open.
- **Plan files**: Implementation plan documents located in `docs/agents/dev/`.
- A single Application can have multiple Research files. When code changes, some of these files may become outdated.

## When to Run

Typical timing is after code implementation, before committing. However, this skill also supports syncing against a specific commit range or the full codebase, so it can be run at any point when Research files may be out of date.

## Workflow

### Step 1: Determine Change Scope

Use `AskQuestion` to ask which scope to use for detecting changes:

| Mode | Description | Command |
|------|-------------|---------|
| **Uncommitted** | Only uncommitted changes (staged + unstaged) | `git diff HEAD` |
| **Since commit** | All changes after a specific commit | `git diff <commit-hash>` |
| **Full codebase** | Analyze the entire current codebase regardless of changes | *(no diff - read the full source tree)* |

If the user has already specified the mode in their request, use it without asking.

**Uncommitted** and **Since commit** modes: if the diff is empty, inform the user and stop.

**Full codebase** mode: skip the diff step entirely. In Step 5, compare each Research file's description against the actual codebase rather than a diff. This mode is useful when Research files may have drifted over time without a clear single change point.

### Step 2: Identify the Application

Determine the Application name from the current Git repository.

```bash
basename $(git rev-parse --show-toplevel)
```

### Step 3: Locate the Plan File

Identify the Plan file from the current session context.

- If the Plan file path is available from the conversation context, use it.
- Otherwise, ask the user to provide the plan file path. If they provide only a filename, resolve it under `docs/agents/dev/`.
- In **Full codebase** mode, the Plan file is optional. If unavailable, proceed without it and rely on comparing Research content directly against the source code.

Read the Plan file to understand the implementation goals and scope of changes.

### Step 4: Read Research Index

Retrieve the list of Research files and their metadata for the Application.

1. Read `docs/agents/research/index.md`.
2. Parse its metadata table.
3. Keep rows where `Application` matches the current Application. If `Application` is missing, keep it only when the linked filename or `Description` clearly matches the current repository.

Expected index shape:

```markdown
# Research Index

| File | Application | ResearchType | Description |
|------|-------------|--------------|-------------|
| [key-sharing-metadata-persistence](./key-sharing-metadata-persistence.md) | keyway | Flow | Explains key sharing metadata persistence flow. |
```

Extract each Research file's **Description** from the index. This description is the key indicator of what each file investigates. Also retain each linked file path for Step 6.

If `index.md` is missing but research files exist in `docs/agents/research/`, create it before continuing: scan every `docs/agents/research/*.md` file's frontmatter and build the index table in the shape shown above, then proceed using the freshly built index. If `docs/agents/research/` contains no research files at all, report that there is nothing to sync and stop.

### Step 5: Impact Analysis - Determine Which Research Files Need Updates

Cross-reference the following information to decide which Research files require updates:

**For Uncommitted / Since commit modes:**

1. **Code changes** (diff output from Step 1)
2. **Plan file** (implementation goals and scope)
3. **Each Research file's description** (the topic it covers)

**For Full codebase mode:**

1. **Current source code** (the actual codebase as it stands)
2. **Plan file** (implementation goals and scope, if available)
3. **Each Research file's description** (the topic it covers)

In Full codebase mode, read each Research file and verify its content against the current source code. A Research file needs an update if its description covers an area where the actual code no longer matches what the document says.

Criteria for inclusion:
- Do the code changes affect the area (feature, flow, or architecture) described by a Research file's description?
- Are the changes outlined in the Plan related to the Research file's topic?
- Do the modified files, functions, or modules correspond to components described in the Research file?

Do not touch Research files that are unaffected. When in doubt, include the file; one unnecessary review is better than leaving a document outdated.

### Step 6: Read and Update Research Files

Read each Research file identified in Step 5 and apply targeted updates.

Research file path pattern: `docs/agents/research/{title}.md`.

#### Update Principles

- **Modify only the sections that need changes.** Do not rewrite the entire file.
- Preserve the existing tone, structure, and formatting.
- Update frontmatter (`Description`, etc.) only if the content has materially changed.
- If frontmatter changes, update `docs/agents/research/index.md` in the same step.
- Remove or revise content that is no longer valid due to code changes.
- When new features or flows have been added, weave them naturally into the existing document structure.
- If code snippets are included, update them to match the current code.

#### Important Guidelines

- Research files are **investigative documents**. They are written to understand a feature or architecture, not as API docs or code comments. Maintain this exploratory, explanatory tone.
- Do not leave traces of the update; no "changed due to commit X" notes. The file should read as if it was always written to describe the current state.
- When uncertain about any detail, read the actual source code to verify before making changes.

### Step 7: Report Results

After completing all updates, report the following:

- List of updated Research files with a brief summary of what changed in each
- Whether `docs/agents/research/index.md` was created or updated
- List of Research files excluded from updates, with short justifications
- Any areas that need the user's manual review, if applicable
