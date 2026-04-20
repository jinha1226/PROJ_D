#!/usr/bin/env python3
"""Parse DCSS mon-spell.h → assets/dcss_mons/spellbooks.json.

`mspell_list[]` in DCSS is an array of
    { MST_FOO, { { SPELL_X, freq, flags }, ... } }
entries. We extract each MST_FOO into a lowercase spellbook id (so our
monsters.json's `spells: orc_wizard` key matches), and each row inside
the inner brace block becomes a `{spell, freq, flags}` dict.

Spell ids are stripped of `SPELL_` and lowercased to match our
spells.json. Flags are kept as a list so the caller can branch on
MON_SPELL_WIZARD / MAGICAL / VOCAL / BREATH.

Output shape (JSON dict keyed by lowercase MST name):
    {
      "orc_wizard": [
        {"spell": "magic_dart",  "freq": 9,  "flags": ["wizard"]},
        {"spell": "throw_flame", "freq": 9,  "flags": ["wizard"]},
        ...
      ],
      ...
    }

Run from project root:
    python3 tools/convert_dcss_mon_spells.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path("/mnt/d/PROJ_D")
SRC = ROOT / "crawl/crawl-ref/source/mon-spell.h"
OUT = ROOT / "assets/dcss_mons/spellbooks.json"


_BOOK_RE = re.compile(
    r"\{\s*MST_([A-Z0-9_]+)\s*,\s*\{(.*?)\}\s*\}",
    re.DOTALL,
)

_ROW_RE = re.compile(
    r"\{\s*SPELL_([A-Z0-9_]+)\s*,\s*(-?\d+)\s*,\s*([^}]+?)\s*\}",
    re.DOTALL,
)


def parse_flags(raw: str) -> list:
    """`MON_SPELL_WIZARD | MON_SPELL_NO_SILENT` → ["wizard", "no_silent"]."""
    out: list = []
    for tok in re.split(r"[|\s]+", raw):
        tok = tok.strip()
        if tok.startswith("MON_SPELL_"):
            out.append(tok[len("MON_SPELL_"):].lower())
    return out


def main() -> int:
    if not SRC.is_file():
        sys.exit(f"ERROR: missing {SRC}")
    text = SRC.read_text(encoding="utf-8")
    books: dict = {}
    for m in _BOOK_RE.finditer(text):
        book_id = m.group(1).lower()
        body = m.group(2)
        rows: list = []
        for r in _ROW_RE.finditer(body):
            spell = r.group(1).lower()
            freq = int(r.group(2))
            flags = parse_flags(r.group(3))
            rows.append({"spell": spell, "freq": freq, "flags": flags})
        if rows:
            books[book_id] = rows
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(books, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"wrote {OUT.relative_to(ROOT)} with {len(books)} monster spellbooks")
    return 0


if __name__ == "__main__":
    sys.exit(main())
