# Delegation Contract

Use these templates verbatim except for replacing placeholders. If a placeholder has no value, use `none` rather than omitting it.

## Implementation Subagent Prompt

```text
Use the `implement-dev` skill to execute this existing plan-dev plan: {PLAN_PATH}

You are running as the implementation stage subagent in a larger delegated dev flow. You own only the implementation stage. Do not run test-dev or review-code. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

At the end, return a structured summary with exactly these headings:

## Implementation Status
pass | blocked | failed

## Implementation Report
absolute path or "none"

## Changed Files
one absolute path per line

## Verification
commands run and pass/fail result

## Red Flags
bullets, or "none"

## Open Questions
bullets, or "none"
```

Stop the whole flow if this stage returns `blocked` or `failed`, unless the result is explicitly safe to review only.

## Test-Hardening Subagent Prompt

```text
Use the `test-dev` skill to strengthen tests for the implementation completed in this session.

Scope the work to these implementation files when possible:
{CHANGED_FILES}

Implementation report under `.agents/doc/dev`:
{IMPLEMENTATION_REPORT_PATH}

You are running as the test-hardening stage subagent in a larger delegated dev flow. You own only the test-dev stage. Do not edit production/business logic. Do not run review-code. Do not revert edits made by others. Follow the repository's AGENTS.md / CLAUDE.md / README.md / Makefile instructions.

At the end, return a structured summary with exactly these headings:

## Test Status
pass | blocked | failed | pass-with-suspected-defects

## Scope
files or packages tested

## Test Changes
one absolute path per line, or "none"

## Unit
tests added and final result

## E2E
tests added and final result, or skipped reason

## Mutation
starting efficacy -> final efficacy, LIVED before -> after, or skipped reason

## Suspected Business Logic Defects
bullets with file:line, test path, observed vs expected, red/skipped status, or "none"

## Remaining Attention Items
bullets, or "none"
```

If this stage reports suspected business-logic defects, continue to review-code but mark the final status as `blocked`.

## Review Subagent Prompt

```text
Use the `review-code` skill to review the final diff after implementation and test hardening.

This is an explicit request for delegated subagent review. Use the review-code skill's delegated reviewer flow with the security, reliability, maintainability, and senior-generalist reviewer subagents when available.

Implementation report under `.agents/doc/dev`:
{IMPLEMENTATION_REPORT_PATH}

Test summary:
{TEST_SUMMARY}

Review the current branch diff including uncommitted changes. Focus on bugs, security, reliability, maintainability, and missing tests introduced by this flow.

At the end, return the review-code output and add this machine-readable footer:

## Review Status
pass | incorrect | blocked | failed

## Blocking Findings
bullets, or "none"

## Nonblocking Findings
bullets, or "none"
```

Treat `Overall Correctness: Incorrect` or any `[CRITICAL]` / `[HIGH]` finding as blocked.

## Final Chat Output Schema

Show this Markdown directly in the chat. Do not write it to a file.

```markdown
# Dev Flow Summary

## Input Plan
- Plan: {absolute path}

## Final Status
- Status: ready-for-user-review | blocked | failed
- Reason: {one sentence}

## Implementation
- Status: {status}
- Report: {path}
- Changed files:
  - {path}
- Verification:
  - {command}: {result}
- Red flags: {summary}
- Open questions: {summary}

## Test Hardening
- Status: {status}
- Test changes:
  - {path}
- Unit: {summary}
- E2E: {summary}
- Mutation: {summary}
- Suspected business-logic defects: {summary}
- Remaining attention items: {summary}

## Review
- Status: {status}
- Overall correctness: {Correct | Incorrect | unknown}
- Blocking findings: {summary}
- Nonblocking findings: {summary}

## Next Actions
- {actionable item, or "none"}
```
