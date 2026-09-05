# Swift / macOS project skills

For Swift / macOS projects, `setup-initial-repo` copies a fixed set of Agent Skills into the target repo at `.agents/skills/<name>/`. Hosts that scan project-local `.agents/skills` then load them with the project.

The trees themselves are **not** vendored in this harness. They live in a sibling checkout named `external-skills` (third-party: Paul Hudson's MIT skills, plus Apple's Xcode 27 skills). The copy script is [scripts/copy-swift-project-skills.sh](../scripts/copy-swift-project-skills.sh).

## What to copy

From every top-level directory in `external-skills` **except** `xcode27-skills`: copy each Agent Skill directory that contains `SKILL.md` one level down (today: `swiftui-pro`, `swift-concurrency-pro`, `swift-testing-pro`, `swiftdata-pro`).

From `xcode27-skills`, copy **only**:

- `swiftui-specialist`
- `swiftui-whats-new-27`

Do not copy the rest of the Xcode 27 bundle (`uikit-app-modernization`, `test-modernizer`, `c-bounds-safety`, `audit-xcode-security-settings`, `device-interaction`).

Some upstream repos also nest an npx wrapper at `<skill>/skills/<skill>/` (SKILL.md plus a relative `references` symlink). Copy the canonical skill directory (the one that already has `SKILL.md` and `references/`), not that wrapper. The script strips `.git`, `.claude-plugin`, and the nested `skills/` directory after copying.

## Source resolution

The script picks the source root in this order:

1. The second CLI argument, when the agent already has a path.
2. `$SWIFT_SKILLS_SOURCE`, when set.
3. A directory named `external-skills` that is a sibling of any ancestor of the destination (so a new project next to `personal-harness` and `external-skills` just works).

If none of those resolve, ask the user for the path and re-run with it as the second argument.

## Destination

`<target-repo>/.agents/skills/<skill-name>/`

Commit these files with the rest of the scaffolding. Do not gitignore `.agents/skills`.
