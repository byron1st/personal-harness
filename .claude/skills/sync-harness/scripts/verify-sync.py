#!/usr/bin/env python3
"""sync-harness verifier.

Mechanizes the "Verify" checklists from docs/sync-harness/ so a migration
can be checked without eyeballing:

  - shared skill tree: skills/<name>/ for the 13 harness skills, SKILL.md
    name matches the directory
  - residual sweep on the shared skill tree (host tool names, platform
    script paths, allowed-tools)
  - sub-agent frontmatter parses as YAML (the colon-space trap)
  - agent name matches filename across claude/codex variants
  - hooks.json valid JSON
  - bash -n on every hook script

Exit code 0 = clean, 1 = at least one failure. Warnings never fail the run.
Usage: verify-sync.py [REPO_ROOT]   (defaults to git toplevel / cwd ancestor)
"""
from __future__ import annotations
import json
import re
import subprocess
import sys
from pathlib import Path

FAILURES: list[tuple[str, str]] = []
WARNINGS: list[tuple[str, str]] = []

HARNESS_SKILLS = {
    "application-research-sync",
    "chat-summary",
    "commit-code",
    "dev-loop",
    "fix-dev",
    "implement-dev",
    "learn-from-manual-edits",
    "loki-log-search",
    "plan-dev",
    "review-code",
    "setup-initial-repo",
    "spec-creator",
    "test-dev",
}

SKILL_RESIDUALS = (
    "AskUserQuestion",
    "AskQuestion",
    "ExitPlanMode",
    "fork_turns",
    "allowed-tools",
    "$HOME/.claude/scripts",
    "$HOME/.cursor/scripts",
    "$HOME/.codex/scripts",
    "$HOME/.grok/scripts",
)

PLATFORM_SKILL_DIRS = ("claude", "codex", "cursor", "grok")


def fail(section: str, msg: str) -> None:
    FAILURES.append((section, msg))


def warn(section: str, msg: str) -> None:
    WARNINGS.append((section, msg))


def find_root(argv: list[str]) -> Path:
    if len(argv) > 1:
        return Path(argv[1]).resolve()
    try:
        top = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"], stderr=subprocess.DEVNULL
        ).decode().strip()
        if top:
            return Path(top)
    except Exception:
        pass
    here = Path.cwd()
    for cand in [here, *here.parents]:
        if (cand / "docs" / "sync-harness" / "SYNC_TO_CODEX.md").exists():
            return cand
    return here


def load_frontmatter(path: Path):
    """Return (data, error). Prefers PyYAML; falls back to a heuristic that
    still flags the unquoted colon-space trap the migration cares about."""
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return None, "no frontmatter fence"
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None, "unterminated frontmatter fence"
    block = parts[1]
    try:
        import yaml  # type: ignore
        try:
            return yaml.safe_load(block) or {}, None
        except Exception as e:
            return None, f"YAML parse error: {e}"
    except ImportError:
        pass
    data: dict[str, str] = {}
    for raw in block.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        m = re.match(r"^([A-Za-z0-9_-]+):\s?(.*)$", line)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        if val and val[0] in "\"'":
            data[key] = val.strip("\"'")
        else:
            if ": " in val:
                return None, f"unquoted value contains ': ' (YAML colon trap): {line.strip()}"
            data[key] = val
    return data, None


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


def check_agents(root: Path) -> None:
    sec = "agents/tree-parity"
    cl, cx = root / "agents/claude", root / "agents/codex"
    if not cl.is_dir():
        return
    claude = {p.stem for p in cl.glob("*.md")}
    codex = {p.stem for p in cx.glob("*.toml")}
    if claude != codex:
        fail(sec, f"claude(.md) vs codex(.toml) differ: only-claude={claude - codex} only-codex={codex - claude}")

    for name in sorted(codex):
        toml = read(cx / f"{name}.toml")
        for key in ("name", "description", "developer_instructions"):
            if not re.search(rf"^\s*{key}\s*=", toml, re.M):
                fail("agents/codex", f"{name}.toml missing `{key}`")
        m = re.search(r'^\s*name\s*=\s*"([^"]+)"', toml, re.M)
        if m and m.group(1) != name:
            fail("agents/codex", f"{name}.toml name=\"{m.group(1)}\" != filename `{name}`")


def check_skills(root: Path) -> None:
    skills = root / "skills"
    if not skills.is_dir():
        fail("skills/tree", "skills/ directory missing")
        return

    present = {p.name for p in skills.iterdir() if p.is_dir()}
    platform_leftovers = present & set(PLATFORM_SKILL_DIRS)
    if platform_leftovers:
        fail("skills/tree", f"platform skill forks still present: {sorted(platform_leftovers)}")

    missing = HARNESS_SKILLS - present
    extra = present - HARNESS_SKILLS - set(PLATFORM_SKILL_DIRS)
    if missing:
        fail("skills/tree", f"missing harness skills: {sorted(missing)}")
    if extra:
        warn("skills/tree", f"non-harness entries under skills/: {sorted(extra)}")

    for name in sorted(HARNESS_SKILLS & present):
        sk = skills / name / "SKILL.md"
        if not sk.exists():
            fail("skills/structure", f"{name} missing SKILL.md")
            continue
        data, err = load_frontmatter(sk)
        if err:
            fail("skills/frontmatter", f"{name}/SKILL.md frontmatter: {err}")
        elif data and str(data.get("name")) != name:
            fail("skills/frontmatter", f"{name}/SKILL.md name `{data.get('name')}` != dir `{name}`")


def check_skill_residuals(root: Path) -> None:
    skills = root / "skills"
    if not skills.is_dir():
        return
    for f in skills.rglob("*.md"):
        # Skip leftover platform dirs if they still exist; check_skills already fails them.
        rel = f.relative_to(skills)
        if rel.parts and rel.parts[0] in PLATFORM_SKILL_DIRS:
            continue
        body = read(f)
        for tok in SKILL_RESIDUALS:
            if tok in body:
                fail("skills/residual-sweep", f"{f.relative_to(root)} contains `{tok}`")


def check_hooks(root: Path) -> None:
    cl = root / "hooks/claude/hooks"
    cx = root / "hooks/codex/hooks"
    if not cl.is_dir():
        return
    s_cl = {p.name for p in cl.glob("*.sh")}
    s_cx = {p.name for p in cx.glob("*.sh")}
    if s_cl != s_cx:
        fail("hooks/tree-parity", f"claude vs codex scripts differ: {s_cl ^ s_cx}")

    cxj = root / "hooks/codex/hooks.json"
    if cxj.exists():
        try:
            json.loads(read(cxj))
        except Exception as e:
            fail("hooks/codex", f"hooks.json invalid JSON: {e}")
        if "$HOME/.claude/" in read(cxj):
            fail("hooks/codex", "hooks.json still references $HOME/.claude/ (should be $HOME/.codex/)")

    cl_settings = root / "hooks/claude/settings.json"
    if cl_settings.exists() and '"permissions"' in read(cl_settings):
        fail("hooks/claude", "settings.json must not contain permissions (allow is appended at install)")

    for base in (cl, cx):
        for sh in sorted(base.glob("*.sh")):
            r = subprocess.run(["bash", "-n", str(sh)], capture_output=True, text=True)
            if r.returncode != 0:
                fail("hooks/syntax", f"{sh.relative_to(root)} bash -n: {r.stderr.strip()}")


def main() -> int:
    root = find_root(sys.argv)
    if not (root / "docs" / "sync-harness" / "SYNC_TO_CODEX.md").exists():
        print(f"warning: {root} doesn't look like the harness root (no docs/sync-harness/SYNC_TO_CODEX.md)", file=sys.stderr)
    for fn in (check_agents, check_skills, check_skill_residuals, check_hooks):
        try:
            fn(root)
        except Exception as e:
            fail("verifier", f"{fn.__name__} crashed: {e}")

    print(f"sync-harness verify @ {root}")
    if WARNINGS:
        print(f"\n  {len(WARNINGS)} warning(s):")
        for s, m in WARNINGS:
            print(f"    ~ [{s}] {m}")
    if FAILURES:
        print(f"\n  {len(FAILURES)} FAILURE(s):")
        for s, m in FAILURES:
            print(f"    ✗ [{s}] {m}")
        print("\nFAIL")
        return 1
    print("\n  all parity / format / residual checks passed\nPASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
