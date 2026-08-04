# .gitignore Baseline

Common entries every repository should ignore, regardless of language. Use this as the starting point and append language-, framework-, and tooling-specific patterns based on the actual project.

## Common baseline

```gitignore
# OS
.DS_Store
Thumbs.db

# IDE / editors
.idea/
.vscode/
.zed/
*.swp
*.swo

# Env / secrets
.env
.env.local
.env.*.local

# Logs
*.log
```

## What the agent must decide per project

The agent reads SPEC.md (Tech Stack) and inspects the working directory, then appends entries for:

- **Build artifacts** — produced binaries, packaged outputs, transpiler outputs (e.g., `bin/`, `dist/`, `build/`, `target/`).
- **Test / coverage outputs** — coverage reports, profiling dumps, generated test artifacts.
- **Dependency caches** — language-specific caches that should not be committed (e.g., `node_modules/`, `__pycache__/`, `.venv/`).
- **Vendored dependencies** — only ignore if the project does NOT vendor; vendored projects must commit their vendor directory.
- **Local-only configuration** — IDE profile files specific to this repo, generated configs, etc.
- **Tooling artifacts** — e.g., `.next/`, `.turbo/`, `.gradle/`, `.mypy_cache/`.

When unsure whether a pattern belongs in `.gitignore` or in the project, prefer asking the user once over committing noise.
