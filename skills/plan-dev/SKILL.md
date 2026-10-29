---
name: plan-dev
description: Plan non-trivial work before coding by investigating the repo and settling with the user what done means, what is out of scope, and what must not change. Use when the user asks to plan, scope, or define acceptance criteria before implementing.
---

# Plan Dev

A plan's job is the part the implementer cannot recover from the code: what "done" means, what is out of scope, and what must not change. How to build it stays coarse — that is cheaper and more correct to settle against running code.

Plan in the host's plan mode when it has one. Nothing is written to the working tree until the user approves.

## Process

1. **Investigate first**, so every question you put to the user is one the code cannot answer. When a SPEC.md is the input, start from its `## Open Questions` and `[ASSUMED]` markers — they are decisions deliberately deferred to this moment.
2. **Settle with the user**, scaled to the work (one confirmation for a trivial task):
   - **Done when** — each outcome as an observable state plus the evidence that proves it: a command and its expected result, or a scenario a person runs. Name anything deliberately left unverified.
   - **Out of scope** — what this work will not do, even where it looks adjacent.
   - **Do not touch** — files, interfaces, behaviors, or data that must stay as they are.
   - **Key decision** — only when two approaches both fit and the wrong one is expensive to reverse: which one, and why.
3. **Check before presenting**: could someone who did not write the plan decide pass/fail for every "done when" item from the plan alone? If not, sharpen it.

## Output

Put those sections first, then a short approach. Leave out line-level edits, helper signatures, and the generic lint/test/build commands the repo already defines.

Also give the "done when" items as one completion condition the user can paste into the host's goal or stop-condition feature (for example Claude Code's `/goal`). Add the repo's own gates, "no existing test weakened or deleted", and a turn cap.

Save the plan to a file only when the work will span sessions or be handed to another session or tool: `docs/agents/dev/{timestamp}_{Jira key or NO-JIRA}_PLAN_{title}.md`, content in Korean. Otherwise the approved plan in the conversation is the artifact.
