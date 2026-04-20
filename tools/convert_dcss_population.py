#!/usr/bin/env python3
"""Parse DCSS mon-pick-data.h into a JSON population table.

Emits assets/dcss_mons/population.json with structure:
    {
      "<branch_name>": [
        {"min": 1, "max": 3, "weight": 1000, "shape": "FLAT", "id": "bat"},
        ...
      ],
      ...
    }

Branches come from the C++ vector array; entries are tuples inside braces.
The C++ macro POP_DEPTHS expands inline; we follow the #define and inject
its entries wherever the branch sections reference it. monster ids lose the
`MONS_` prefix and lowercase with underscores to match our monster-yaml id
convention (e.g. MONS_FIRE_DRAGON → fire_dragon).
"""

import json
import re
import sys
from pathlib import Path

SRC = Path("/mnt/d/PROJ_D/crawl/crawl-ref/source/mon-pick-data.h")
OUT = Path("/mnt/d/PROJ_D/assets/dcss_mons/population.json")


ENTRY_RE = re.compile(
    r"\{\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(\d+)\s*,\s*(\w+)\s*,\s*MONS_([A-Z0-9_]+)\s*,?\s*\}"
)
BRANCH_HEAD_RE = re.compile(r"^\{\s*//\s*(.+)")


def mons_to_id(mons_name: str) -> str:
    return mons_name.lower()


def parse_file(text: str):
    """Return a dict {branch_name: [entries]}."""
    # Read the POP_DEPTHS macro block first. The macro spans multiple lines
    # with trailing backslashes; we extract its body between the opening and
    # closing braces after `#define POP_DEPTHS`.
    depths_body = ""
    m = re.search(r"#define POP_DEPTHS\s*\\\s*\n(.*?)\n\}\s*$", text,
                  re.MULTILINE | re.DOTALL)
    if m:
        depths_body = m.group(1)
    depths_entries = ENTRY_RE.findall(depths_body)

    # Find each branch section. The C++ declares
    #   static const vector<pop_entry> population[] = {
    # then successive `{ // Branchname ... }` blocks. Split by the `{ //`
    # comment markers at column 0.
    branches_raw = re.split(r"^\{\s*//\s*", text, flags=re.MULTILINE)[1:]
    out: dict = {}
    for chunk in branches_raw:
        first_line, _, rest = chunk.partition("\n")
        branch_name = first_line.split("(")[0].strip().rstrip("*").strip()
        if not branch_name:
            continue
        # Grab everything up to the matching closing brace for this branch.
        # Branches end with a line that contains just `},` or `}` at col 0.
        body_lines = []
        for line in rest.splitlines():
            if re.match(r"^\}[,\s]*$", line):
                break
            body_lines.append(line)
        body = "\n".join(body_lines)
        entries = ENTRY_RE.findall(body)
        # If the branch uses `POP_DEPTHS`, inject the depths entries.
        if "POP_DEPTHS" in body:
            entries.extend(depths_entries)
        out[branch_name] = [
            {
                "min": int(e[0]),
                "max": int(e[1]),
                "weight": int(e[2]),
                "shape": e[3],
                "id": mons_to_id(e[4]),
            }
            for e in entries
        ]
    return out


def main() -> int:
    if not SRC.is_file():
        print(f"ERROR: {SRC} not found", file=sys.stderr)
        return 1
    text = SRC.read_text(encoding="utf-8")
    table = parse_file(text)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(table, f, ensure_ascii=False, indent=1, sort_keys=True)
    total = sum(len(v) for v in table.values())
    print(f"Wrote {OUT} with {len(table)} branches, {total} total entries.")
    for br, entries in sorted(table.items()):
        print(f"  {br:30s} {len(entries):>4} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
