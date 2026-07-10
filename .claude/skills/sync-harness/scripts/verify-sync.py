#!/usr/bin/env python3
"""sync-harness verifier.

Mechanizes the "Verify" checklists from MIGRATE_TO_CODEX.md and
MIGRATE_TO_CLAUDE.md so a migration can be checked without eyeballing:

  - tree parity across claude/ codex/ opencode/ (skills, agents, hooks)
  - sub-agent frontmatter parses as YAML (the colon-space trap)
  - skill / agent `name` matches its directory or filename across variants
  - residual sweep: leftover Claude-only references in the Codex variants
  - hooks.json valid JSON
  - bash -n on every hook script

Exit code 0 = clean, 1 = at least one failure. Warnings never fail the run.
Usage: verify-sync.py [REPO_ROOT]   (defaults to git toplevel / cwd ancestor)
"""
from __future__ import annotations
import json
import os
import re
import subprocess
import sys
from pathlib import Path

FAILURES: list[tuple[str, str]] = []
WARNINGS: list[tuple[str, str]] = []


def fail(section: str, msg: str) -> None:
    FAILURES.append((section, msg))


def warn(section: str, msg: str) -> None:
    WARNINGS.append((section, msg))


# ── locating the repo root ──────────────────────────────────────────────────
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
        if (cand / "MIGRATE_TO_CODEX.md").exists():
            return cand
    return here


# ── tiny frontmatter loader (no external deps) ──────────────────────────────
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
        except Exception as e:  # YAMLError and friends
            return None, f"YAML parse error: {e}"
    except ImportError:
        pass
    # Heuristic parser: top-level "key: value" lines only.
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
            # Unquoted scalar containing another ': ' would break a real parser.
            if ": " in val:
                return None, f"unquoted value contains ': ' (YAML colon trap): {line.strip()}"
            data[key] = val
    return data, None


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except Exception:
        return ""


# ── checks ──────────────────────────────────────────────────────────────────
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


def skill_dirs(base: Path) -> set[str]:
    return {p.name for p in base.iterdir() if p.is_dir()} if base.is_dir() else set()


def subtree(base: Path) -> set[str]:
    return {str(p.relative_to(base)) for p in base.rglob("*") if p.is_file()} if base.is_dir() else set()


def check_skills(root: Path) -> None:
    cl, cx = root / "skills/claude", root / "skills/codex"
    if not cl.is_dir():
        return
    op = root / "skills/opencode"
    sc, sx = skill_dirs(cl), skill_dirs(cx)
    so = skill_dirs(op)

    if not (sc == sx == so):
        fail("skills/tree-parity", f"skill sets differ: claude={sc} codex={sx} opencode={so}")

    for name in sorted(sc & sx & so):
        # name frontmatter must match dir across all three variants
        for plat, base in (("claude", cl), ("codex", cx), ("opencode", op)):
            sk = base / name / "SKILL.md"
            if not sk.exists():
                fail("skills/structure", f"{plat}/{name} missing SKILL.md")
                continue
            data, err = load_frontmatter(sk)
            if err:
                fail(f"skills/{plat}", f"{name}/SKILL.md frontmatter: {err}")
            elif data and str(data.get("name")) != name:
                fail(f"skills/{plat}", f"{name}/SKILL.md name `{data.get('name')}` != dir `{name}`")
        # references/ and scripts/ copy verbatim — trees must be identical
        for sub in ("references", "scripts"):
            t = {plat: subtree(base / name / sub) for plat, base in (("claude", cl), ("codex", cx), ("opencode", op))}
            if not (t["claude"] == t["codex"] == t["opencode"]):
                fail("skills/subtree-parity", f"{name}/{sub} trees differ: {t}")


def check_codex_residuals(root: Path) -> None:
    cx = root / "skills/codex"
    for f in (cx.rglob("*.md") if cx.is_dir() else []):
        body = read(f)
        for tok in ("subagent_type", "ExitPlanMode", "AskUserQuestion"):
            if tok in body:
                fail("codex/residual-sweep", f"{f.relative_to(root)} still contains Claude-only `{tok}`")


def check_hooks(root: Path) -> None:
    cl = root / "hooks/claude/hooks"
    cx = root / "hooks/codex/hooks"
    if not cl.is_dir():
        return
    s_cl = {p.name for p in cl.glob("*.sh")}
    s_cx = {p.name for p in cx.glob("*.sh")}
    if s_cl != s_cx:
        fail("hooks/tree-parity", f"claude vs codex scripts differ: {s_cl ^ s_cx}")

    # Codex hooks.json: valid JSON, points at ~/.codex (not ~/.claude)
    cxj = root / "hooks/codex/hooks.json"
    if cxj.exists():
        try:
            json.loads(read(cxj))
        except Exception as e:
            fail("hooks/codex", f"hooks.json invalid JSON: {e}")
        if "$HOME/.claude/" in read(cxj):
            fail("hooks/codex", "hooks.json still references $HOME/.claude/ (should be $HOME/.codex/)")

    # bash -n on every hook script across both variants
    for base in (cl, cx):
        for sh in sorted(base.glob("*.sh")):
            r = subprocess.run(["bash", "-n", str(sh)], capture_output=True, text=True)
            if r.returncode != 0:
                fail("hooks/syntax", f"{sh.relative_to(root)} bash -n: {r.stderr.strip()}")


def main() -> int:
    root = find_root(sys.argv)
    if not (root / "MIGRATE_TO_CODEX.md").exists():
        print(f"warning: {root} doesn't look like the harness root (no MIGRATE_TO_CODEX.md)", file=sys.stderr)
    for fn in (check_agents, check_skills,
               check_codex_residuals, check_hooks):
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
