---
name: application-research-sync
description: >
  Batch-update Obsidian Vault Research files to reflect code changes.
  Supports three change scopes: uncommitted changes, changes since a specific commit,
  or a full codebase review. Analyzes code diffs (or the entire source tree) alongside
  the Plan file and Research file descriptions to determine which Research files are
  outdated, then surgically updates only the affected sections.
  Use this skill when:
  - The user asks to "update research files", "sync research", "research sync", etc.
  - Documentation sync is needed after code implementation
  - The user mentions "obsidian update", "vault sync", or anything related to Obsidian research docs
  - A Plan has been implemented and related research documents need to reflect the changes
  - Research files may have drifted from the actual codebase over time
  Even if Plan or Research files are not explicitly mentioned, use this skill whenever
  the context involves syncing documentation with code.
---

# Application Research Sync

Automatically update Obsidian Vault Research files based on code changes.

## Background

- **Research files**: Markdown documents in the Obsidian Vault that investigate and describe an Application's (identified by Git repository name) features, flows, or architecture. Each file has a `Description` field in its frontmatter. They are located in `${OBSIDIAN_HOME}/01. Research`.
- **Plan files**: Implementation plan documents, also located in `${OBSIDIAN_HOME}/00. Plans`.
- A single Application can have multiple Research files. When code changes, some of these files may become outdated.

## When to Run

Typical timing is after code implementation, before committing. However, this skill also supports syncing against a specific commit range or the full codebase, so it can be run at any point when Research files may be out of date.

## Workflow

### Step 1: Determine Change Scope

Ask the user which scope to use for detecting changes:

| Mode | Description | Command |
|------|-------------|---------|
| **Uncommitted** | Only uncommitted changes (staged + unstaged) | `git diff HEAD` |
| **Since commit** | All changes after a specific commit | `git diff <commit-hash>` |
| **Full codebase** | Analyze the entire current codebase regardless of changes | *(no diff — read the full source tree)* |

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
- Otherwise, ask the user to provide the name of the Plan file. Then, use `${OBSIDIAN_HOME}/00. Plans/${PLAN_FILE_NAME}.md`
- In **Full codebase** mode, the Plan file is optional — if unavailable, proceed without it and rely on comparing Research content directly against the source code.

Read the Plan file to understand the implementation goals and scope of changes.

### Step 4: Query Research File Metadata

Retrieve the list of Research files and their metadata for the Application.

```bash
obsidian base:query file="Research.base" format=json view=${APPLICATION_NAME}
```

Returned metadata looks like:

```
[
  {
    "path": "01. Research/keyway-Flow-key-sharing-metadata-persistence.md",
    "수정된 시간": "2026-03-30T17:35:11",
    "Application": "keyway",
    "ResearchType": "Flow",
    "이름": "keyway-Flow-key-sharing-metadata-persistence",
    "Description": "..."
  },
  {
    "path": "01. Research/keyway-Structure-key-sharing-persistence-contracts.md",
    "수정된 시간": "2026-03-30T17:35:11",
    "Application": "keyway",
    "ResearchType": "Structure",
    "이름": "keyway-Structure-key-sharing-persistence-contracts",
    "Description": "..."
  }
]
```

Extract each Research file's **Description** from the returned metadata. This description is the key indicator of what each file investigates.
Also, extract each Research file's **path** from the returned metadata. This path is used when you read the file's content.

### Step 5: Impact Analysis — Determine Which Research Files Need Updates
 
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
 
Do not touch Research files that are unaffected. When in doubt, include the file — one unnecessary review is better than leaving a document outdated.

### Step 6: Read and Update Research Files

Read each Research file identified in Step 5 and apply targeted updates.

Research file path pattern: `${OBSIDIAN_HOME}/${RESEARCH_FILE_PATH_EXTRACTED_FROM_THE_RETURNED_METADATA_AT_STEP_4}`

#### Update Principles

- **Modify only the sections that need changes.** Do not rewrite the entire file.
- Preserve the existing tone, structure, and formatting.
- Update frontmatter (`Description`, etc.) only if the content has materially changed.
- Remove or revise content that is no longer valid due to code changes.
- When new features or flows have been added, weave them naturally into the existing document structure.
- If code snippets are included, update them to match the current code.

#### Important Guidelines

- Research files are **investigative documents** — they are written to understand a feature or architecture, not as API docs or code comments. Maintain this exploratory, explanatory tone.
- Do not leave traces of the update — no "changed due to commit X" notes. The file should read as if it was always written to describe the current state.
- When uncertain about any detail, read the actual source code to verify before making changes.

### Step 7: Report Results

After completing all updates, report the following:

- List of updated Research files with a brief summary of what changed in each
- List of Research files excluded from updates, with short justifications
- Any areas that need the user's manual review, if applicable
