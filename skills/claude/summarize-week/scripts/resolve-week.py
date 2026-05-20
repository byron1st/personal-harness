#!/usr/bin/env python3
"""Resolve a week argument to (iso-week-id, monday, sunday).

Usage:
  resolve-week.py 2026-W17      # ISO week form
  resolve-week.py 2026-04-22    # any date within the week

Output (single line, space-separated):
  <YYYY-WNN> <YYYY-MM-DD> <YYYY-MM-DD>

Exits non-zero with an explanatory message on stderr for bad input.
ISO week boundaries (Monday .. Sunday) are used, which handles year
boundaries correctly (e.g. 2027-01-01 belongs to 2026-W53).
"""
from __future__ import annotations

import re
import sys
from datetime import date, timedelta


def resolve(arg: str) -> tuple[str, date, date]:
    m = re.fullmatch(r"(\d{4})-W(\d{1,2})", arg)
    if m:
        year, week = int(m.group(1)), int(m.group(2))
        monday = date.fromisocalendar(year, week, 1)
    else:
        try:
            d = date.fromisoformat(arg)
        except ValueError as e:
            raise ValueError(
                f"invalid argument {arg!r}: expected YYYY-WNN or YYYY-MM-DD"
            ) from e
        monday = d - timedelta(days=d.isoweekday() - 1)

    sunday = monday + timedelta(days=6)
    iy, iw, _ = monday.isocalendar()
    return f"{iy}-W{iw:02d}", monday, sunday


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: resolve-week.py <YYYY-WNN | YYYY-MM-DD>", file=sys.stderr)
        return 2
    try:
        week_id, monday, sunday = resolve(argv[1])
    except ValueError as e:
        print(str(e), file=sys.stderr)
        return 2
    print(f"{week_id} {monday.isoformat()} {sunday.isoformat()}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
