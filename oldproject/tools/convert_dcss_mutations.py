#!/usr/bin/env python3
"""Parse DCSS mutation-data.h → assets/dcss_mutations/mutations.json.

Each entry starts with `{ MUT_X, weight, levels, flags,` followed by
short_desc string, then `have[3]`, `gain[3]`, `lose[3]` braced string
lists, plus a tile id and optional `will_gain[3]`. We only care about:

  - id (MUT_X → lower-case)
  - weight (commonality for random-mutation rolls; 0 = never random)
  - levels (1..3)
  - flags (good/bad/neutral/physical/anatomy/…)
  - short_desc

Full flavor text for the player gets trimmed to the short_desc.

Run from project root:
    python3 tools/convert_dcss_mutations.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path("/mnt/d/PROJ_D")
SRC = ROOT / "crawl/crawl-ref/source/mutation-data.h"
OUT = ROOT / "assets/dcss_mutations/mutations.json"


_ENTRY_RE = re.compile(
    r"\{\s*MUT_([A-Z0-9_]+)\s*,\s*"             # id
    r"(-?\d+)\s*,\s*"                           # weight
    r"(-?\d+)\s*,\s*"                           # levels
    r"([^,]+?(?:\|[^,]+?)*)\s*,\s*"             # flags (may include | chains)
    r'"([^"]*)"'                                # short_desc
)


def parse_flags(raw: str) -> list:
    """`mutflag::good | mutflag::anatomy` → ['good', 'anatomy']."""
    out: list = []
    for tok in re.split(r"[|\s]+", raw):
        tok = tok.strip()
        if tok.startswith("mutflag::"):
            out.append(tok[len("mutflag::"):])
    return out


def main() -> int:
    if not SRC.is_file():
        sys.exit(f"ERROR: missing {SRC}")
    text = SRC.read_text(encoding="utf-8")
    out: dict = {}
    for m in _ENTRY_RE.finditer(text):
        mid = m.group(1).lower()
        weight = int(m.group(2))
        levels = int(m.group(3))
        flags = parse_flags(m.group(4))
        short_desc = m.group(5)
        # Skip entries with obvious noise (no short_desc, no levels).
        if levels <= 0:
            continue
        out[mid] = {
            "id": mid,
            "weight": weight,
            "levels": levels,
            "flags": flags,
            "desc": short_desc,
        }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"wrote {OUT.relative_to(ROOT)} with {len(out)} mutations")
    return 0


if __name__ == "__main__":
    sys.exit(main())
