#!/usr/bin/env python3
"""sync-harness verifier.

Mechanizes the "Verify" checklists from MIGRATE_TO_CODEX.md and
MIGRATE_TO_CURSOR.md so a migration can be checked without eyeballing:

  - tree parity across claude/ codex/ cursor/ (skills, agents, hooks)
  - sub-agent frontmatter parses as YAML (the colon-space trap) and carries
    readonly: true with name == filename
  - skill / agent `name` matches its directory or filename across variants
  - residual sweep: leftover Codex / worker / explorer / sandbox-and-approval /
    Claude-tool references in the Cursor (and a lighter pass on Codex) variants
  - hooks.json valid JSON, Cursor has version:1 + relative ./hooks/ commands
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
    cl, cx, cu = root / "agents/claude", root / "agents/codex", root / "agents/cursor"
    if not cl.is_dir():
        return
    claude = {p.stem for p in cl.glob("*.md")}
    codex = {p.stem for p in cx.glob("*.toml")}
    cursor = {p.stem for p in cu.glob("*.md")}
    if claude != codex:
        fail(sec, f"claude(.md) vs codex(.toml) differ: only-claude={claude - codex} only-codex={codex - claude}")
    if codex != cursor:
        fail(sec, f"codex(.toml) vs cursor(.md) differ: only-codex={codex - cursor} only-cursor={cursor - codex}")

    for name in sorted(codex):
        toml = read(cx / f"{name}.toml")
        for key in ("name", "description", "developer_instructions"):
            if not re.search(rf"^\s*{key}\s*=", toml, re.M):
                fail("agents/codex", f"{name}.toml missing `{key}`")
        m = re.search(r'^\s*name\s*=\s*"([^"]+)"', toml, re.M)
        if m and m.group(1) != name:
            fail("agents/codex", f"{name}.toml name=\"{m.group(1)}\" != filename `{name}`")

    for name in sorted(cursor):
        data, err = load_frontmatter(cu / f"{name}.md")
        if err:
            fail("agents/cursor", f"{name}.md frontmatter: {err}")
            continue
        if str(data.get("name")) != name:
            fail("agents/cursor", f"{name}.md name `{data.get('name')}` != filename `{name}`")
        if data.get("readonly") not in (True, "true"):
            fail("agents/cursor", f"{name}.md missing `readonly: true` (reviewers are read-only)")
        if not data.get("description"):
            fail("agents/cursor", f"{name}.md missing `description`")


def skill_dirs(base: Path) -> set[str]:
    return {p.name for p in base.iterdir() if p.is_dir()} if base.is_dir() else set()


def subtree(base: Path) -> set[str]:
    return {str(p.relative_to(base)) for p in base.rglob("*") if p.is_file()} if base.is_dir() else set()


# Work-only skills live in Codex/Cursor (Work variants) but not in Claude
# (Personal). MIGRATE_TO_CODEX.md / MIGRATE_TO_CURSOR.md document this split.
WORK_ONLY_SKILLS = {"loki-log-search"}


def check_skills(root: Path) -> None:
    cl, cx, cu = root / "skills/claude", root / "skills/codex", root / "skills/cursor"
    if not cl.is_dir():
        return
    sc, sx, su = skill_dirs(cl), skill_dirs(cx), skill_dirs(cu)
    # Strip Work-only skills before comparing the shared tree; they are allowed
    # to exist only in codex/cursor and must NOT appear in claude.
    sc_shared = sc - WORK_ONLY_SKILLS
    sx_shared = sx - WORK_ONLY_SKILLS
    su_shared = su - WORK_ONLY_SKILLS
    if not (sc_shared == sx_shared == su_shared):
        fail("skills/tree-parity", f"skill sets differ: claude={sc} codex={sx} cursor={su}")
    # Work-only skills must be present in codex+cursor and absent in claude.
    for name in WORK_ONLY_SKILLS:
        if name in sc:
            fail("skills/tree-parity", f"Work-only skill `{name}` must not exist in claude/")
        elif not (name in sx and name in su):
            fail("skills/tree-parity", f"Work-only skill `{name}` missing from codex/cursor")

    for name in sorted(sc_shared & sx_shared & su_shared):
        # name frontmatter must match dir across all three variants
        for plat, base in (("claude", cl), ("codex", cx), ("cursor", cu)):
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
            t = {plat: subtree(base / name / sub) for plat, base in (("claude", cl), ("codex", cx), ("cursor", cu))}
            if not (t["claude"] == t["codex"] == t["cursor"]):
                fail("skills/subtree-parity", f"{name}/{sub} trees differ: {t}")


# Cursor variants must be free of Codex-execution-model leftovers. Per-skill
# allowlist mirrors the intentional exceptions named in MIGRATE_TO_CURSOR.md.
CURSOR_FORBIDDEN = {
    r"\bCodex\b": "Codex",
    r"\bsandbox and approval\b": "sandbox and approval",
    r"\bExitPlanMode\b": "ExitPlanMode",
    r"\bsubagent_type\b": "subagent_type",
    r"\bworker\b": "worker",
    r"\bexplorer\b": "explorer",  # lowercase Codex agent; Cursor builtin is `Explore`
}
ALLOW = {  # skill name -> tokens that are intentional there
    "setup-initial-repo": {"Codex"},
    "spec-creator": {"worker"},
    "implement-dev": {"worker"},  # Worker delegation role + worker-contract.md reference (cross-platform)
}


def check_cursor_residuals(root: Path) -> None:
    cu_sk, cu_ag = root / "skills/cursor", root / "agents/cursor"
    files = list(cu_sk.rglob("*.md")) if cu_sk.is_dir() else []
    files += list(cu_ag.glob("*.md")) if cu_ag.is_dir() else []
    for f in files:
        skill_name = None
        try:
            rel = f.relative_to(cu_sk)
            skill_name = rel.parts[0]
        except ValueError:
            pass
        allowed = ALLOW.get(skill_name or "", set())
        body = read(f)
        for pat, label in CURSOR_FORBIDDEN.items():
            if label in allowed:
                continue
            if re.search(pat, body):
                fail("cursor/residual-sweep", f"{f.relative_to(root)} still contains `{label}`")
        if ".tool_input.command" in body:
            fail("cursor/residual-sweep", f"{f.relative_to(root)} uses Codex field `.tool_input.command`")
        if re.search(r"\bMCP\b", body):
            warn("cursor/residual-sweep", f"{f.relative_to(root)} mentions MCP (Cursor plan mode disables MCP — confirm intentional)")


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
    cu = root / "hooks/cursor/hooks"
    if not cl.is_dir():
        return
    s_cl = {p.name for p in cl.glob("*.sh")}
    s_cx = {p.name for p in cx.glob("*.sh")}
    s_cu = {p.name for p in cu.glob("*.sh")}
    if s_cl != s_cx:
        fail("hooks/tree-parity", f"claude vs codex scripts differ: {s_cl ^ s_cx}")
    extra = s_cu - s_cx
    if not s_cx <= s_cu:
        fail("hooks/tree-parity", f"cursor missing codex scripts: {s_cx - s_cu}")
    if extra - {"doc-drift-flag.sh"}:
        fail("hooks/tree-parity", f"cursor has unexpected extra scripts: {extra - {'doc-drift-flag.sh'}}")

    # Codex hooks.json: valid JSON, points at ~/.codex (not ~/.claude)
    cxj = root / "hooks/codex/hooks.json"
    if cxj.exists():
        try:
            json.loads(read(cxj))
        except Exception as e:
            fail("hooks/codex", f"hooks.json invalid JSON: {e}")
        if "$HOME/.claude/" in read(cxj):
            fail("hooks/codex", "hooks.json still references $HOME/.claude/ (should be $HOME/.codex/)")

    # Cursor hooks.json: version:1 + relative ./hooks/ commands
    cuj = root / "hooks/cursor/hooks.json"
    if cuj.exists():
        try:
            data = json.loads(read(cuj))
        except Exception as e:
            fail("hooks/cursor", f"hooks.json invalid JSON: {e}")
            data = None
        if isinstance(data, dict):
            if data.get("version") != 1:
                fail("hooks/cursor", 'hooks.json missing `"version": 1`')
            for event, entries in (data.get("hooks") or {}).items():
                for ent in entries:
                    cmd = ent.get("command", "")
                    if not cmd.startswith("./hooks/"):
                        fail("hooks/cursor", f"{event} command not relative `./hooks/...`: {cmd}")

    # bash -n on every hook script across all three variants
    for base in (cl, cx, cu):
        for sh in sorted(base.glob("*.sh")):
            r = subprocess.run(["bash", "-n", str(sh)], capture_output=True, text=True)
            if r.returncode != 0:
                fail("hooks/syntax", f"{sh.relative_to(root)} bash -n: {r.stderr.strip()}")
    # Cursor scripts should use the Cursor input schema, not Codex's
    for sh in (cu.glob("*.sh") if cu.is_dir() else []):
        if ".tool_input.command" in read(sh):
            fail("hooks/cursor", f"{sh.relative_to(root)} uses Codex field `.tool_input.command` (use `.command`)")


def main() -> int:
    root = find_root(sys.argv)
    if not (root / "MIGRATE_TO_CODEX.md").exists():
        print(f"warning: {root} doesn't look like the harness root (no MIGRATE_TO_CODEX.md)", file=sys.stderr)
    for fn in (check_agents, check_skills, check_cursor_residuals,
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
