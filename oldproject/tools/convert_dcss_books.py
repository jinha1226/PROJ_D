#!/usr/bin/env python3
"""Parse DCSS book-data.h → assets/dcss_spells/books.json.

Each entry in `spellbook_templates[]` is a `{ ... }` block preceded by a
`// Book of X` comment. We split on block boundaries, extract the comment
as the book name, and pull the `SPELL_FOO` identifiers inside.

Output file: JSON dict keyed by our book id (e.g. `book_minor_magic`),
each entry carrying name, spell ids (lowercased, stripped of SPELL_),
and a derived colour hint.

Run from project root:
    python3 tools/convert_dcss_books.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path("/mnt/d/PROJ_D")
SRC = ROOT / "crawl/crawl-ref/source/book-data.h"
OUT = ROOT / "assets/dcss_spells/books.json"

# Per-book colour hints so the UI can tint each book a little differently.
# Name substring → (r, g, b). Anything unmatched uses a neutral parchment.
_COLOUR_HINTS = [
    ("flame",         (1.00, 0.40, 0.15)),
    ("fire",          (1.00, 0.40, 0.15)),
    ("spontaneous",   (1.00, 0.55, 0.20)),
    ("burglary",      (0.60, 0.55, 0.30)),
    ("frost",         (0.45, 0.80, 1.00)),
    ("ice",           (0.45, 0.80, 1.00)),
    ("rime",          (0.60, 0.85, 1.00)),
    ("winter",        (0.70, 0.90, 1.00)),
    ("lightning",     (1.00, 1.00, 0.40)),
    ("sky",           (0.70, 0.90, 1.00)),
    ("air",           (0.70, 0.90, 1.00)),
    ("storm",         (0.80, 0.95, 1.00)),
    ("death",         (0.30, 0.10, 0.45)),
    ("pain",          (0.55, 0.10, 0.50)),
    ("unlife",        (0.35, 0.10, 0.50)),
    ("necromancy",    (0.35, 0.10, 0.50)),
    ("decay",         (0.40, 0.35, 0.20)),
    ("geomancy",      (0.60, 0.45, 0.25)),
    ("stone",         (0.60, 0.55, 0.35)),
    ("earth",         (0.60, 0.45, 0.25)),
    ("battle",        (0.85, 0.70, 0.25)),
    ("armaments",     (0.80, 0.80, 0.85)),
    ("power",         (0.95, 0.85, 0.30)),
    ("annihilations", (1.00, 0.45, 0.25)),
    ("hex",           (0.80, 0.40, 0.85)),
    ("malediction",   (0.80, 0.40, 0.85)),
    ("debilitation",  (0.70, 0.45, 0.80)),
    ("control",       (0.75, 0.55, 0.95)),
    ("envenom",       (0.50, 0.80, 0.30)),
    ("poisoner",      (0.50, 0.80, 0.30)),
    ("beasts",        (0.70, 0.55, 0.25)),
    ("wilderness",    (0.45, 0.70, 0.35)),
    ("callings",      (0.75, 0.55, 0.95)),
    ("dream",         (0.60, 0.60, 0.95)),
    ("sense",         (0.85, 0.80, 0.55)),
    ("spectacle",     (0.95, 0.70, 0.95)),
    ("sphere",        (0.75, 0.75, 0.95)),
    ("moon",          (0.85, 0.85, 0.95)),
    ("dragon",        (0.85, 0.25, 0.25)),
    ("misfortune",    (0.50, 0.50, 0.60)),
    ("cantrip",       (0.85, 0.80, 0.60)),
    ("party",         (0.95, 0.85, 0.95)),
    ("transfig",      (0.75, 0.55, 0.95)),
    ("transmut",      (0.75, 0.55, 0.95)),
    ("wizard",        (0.70, 0.70, 1.00)),
    ("minor magic",   (0.85, 0.80, 0.60)),
    ("grimoire",      (0.25, 0.20, 0.30)),
    ("conjuration",   (0.75, 0.75, 1.00)),
    ("warp",          (0.70, 0.40, 1.00)),
    ("translocat",    (0.70, 0.40, 1.00)),
    ("displace",      (0.70, 0.40, 1.00)),
]


def colour_for(name: str) -> list:
    low = name.lower()
    for key, rgb in _COLOUR_HINTS:
        if key in low:
            return list(rgb)
    return [0.85, 0.80, 0.60]  # parchment default


def id_from_name(name: str) -> str:
    # "Book of Minor Magic" → "book_minor_magic"
    # "Young Poisoner's Handbook" → "book_young_poisoners_handbook"
    # "Grand Grimoire" → "book_grand_grimoire"
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    if not slug.startswith("book"):
        slug = "book_" + slug
    return slug


def parse_books(text: str) -> list:
    # spellbook_templates[] starts with an opening brace and we want every
    # inner `{ ... }` block preceded by a `// NAME` comment.
    blocks = []
    depth = 0
    current = []
    in_block = False
    start = -1
    for i, ch in enumerate(text):
        if ch == "{":
            depth += 1
            if depth == 2:
                start = i
        elif ch == "}":
            if depth == 2 and start >= 0:
                blocks.append(text[start:i + 1])
                start = -1
            depth -= 1
    # The book name appears as a `//` comment inside each block, on the
    # same line as the opening brace: `{   // Book of Minor Magic`.
    results = []
    for block in blocks:
        m = re.search(r"//\s*([^\r\n]+)", block)
        name = m.group(1).strip() if m else ""
        spells = re.findall(r"SPELL_([A-Z0-9_]+)", block)
        spells_low = [s.lower() for s in spells]
        if name and spells_low:
            results.append({"name": name, "spells": spells_low})
    return results


def main() -> int:
    if not SRC.is_file():
        sys.exit(f"ERROR: missing {SRC}")
    text = SRC.read_text(encoding="utf-8")
    books = parse_books(text)
    out: dict = {}
    for b in books:
        bid = id_from_name(b["name"])
        # Deduplicate: if two books parse to the same id (shouldn't
        # happen but guard anyway), suffix with a counter.
        suffix = 1
        base = bid
        while bid in out:
            suffix += 1
            bid = f"{base}_{suffix}"
        out[bid] = {
            "name": b["name"],
            "spells": b["spells"],
            "colour": colour_for(b["name"]),
        }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"wrote {OUT.relative_to(ROOT)} with {len(out)} books")
    return 0


if __name__ == "__main__":
    sys.exit(main())
