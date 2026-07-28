---
name: review-code-claude
description: Run the installed Claude Code review-code workflow from Codex and return its four-axis review for Codex-side triage. Use only when the user explicitly invokes $review-code-claude; never activate it for ordinary code-review requests.
---

# Review Code with Claude

Run Claude Code as a separate non-interactive process. Do not dispatch Codex reviewers or invoke `$review-code` as part of this workflow.

## Preconditions

Proceed only after the user explicitly invokes this skill in a repository they trust. The Claude process can read repository content and send it to Anthropic. If trust is unclear, stop and ask before running it.

Resolve this skill's directory from the loaded `SKILL.md` path. Confirm that the sibling `../review-code/SKILL.md` exists; it provides the Codex-side triage contract. The runner performs the remaining dependency checks.

## Run the delegated review

Use the user's requested review scope verbatim. When no scope is supplied, use: `현재 브랜치와 main의 차이를 리뷰하라.`

From the target repository root, run:

```bash
<skill-dir>/scripts/run-claude-review.sh "<review request>"
```

The runner owns the Claude permission policy, JSON validation, report-shape validation, and before/after working-tree fingerprint. Do not add flags, loosen its tool policy, or wrap a failed invocation with a direct Codex review.

## Handle the result

On runner failure:

1. Report `Delegation status: failed`, the exit status, and the runner's error.
2. If it reports a working-tree change, call that out explicitly and leave the change untouched.
3. Stop. Do not invoke `$review-code`, dispatch Codex reviewers, or review in the main session unless the user makes a separate request afterward.

On runner success, display the returned Claude report without rewriting or re-aggregating it.

When the report contains a non-waived `[CRITICAL]` or `[HIGH]` finding, read and apply only these sections from `../review-code/SKILL.md`:

- `Triage blocking findings`
- `Accepted Review Exceptions registry`
- `Stage Status and overall verdict`

Keep every blocking finding unclassified until the user explicitly replies with `fix` or `accept` for its `REVIEW-NNN` id. Record an AR entry only for an explicit `accept`. A `fix` classification records the decision but does not modify code. Do not infer classifications, fix findings, or rerun either review workflow.

When no blocking finding exists, return the Claude report as the final result.
