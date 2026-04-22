#!/usr/bin/env python3
"""Convert DCSS monster YAML files into a single JSON map used by our game.

Run from the project root:
    python3 tools/convert_dcss_mons.py

Output: assets/dcss_mons/monsters.json with one entry per monster id.
Skips files starting with 'deprecated-' or 'TEST' and the README.

We only pull fields that matter at runtime:
  name, glyph (char/colour), hd, hp_10x, ac, ev, speed, will, exp,
  attacks, size, intelligence, shape, habitat, flags, shout, genus
"""

import json
import os
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

SOURCE_DIR = Path("/mnt/d/PROJ_D/crawl/crawl-ref/source/dat/mons")
OUT_FILE = Path("/mnt/d/PROJ_D/assets/dcss_mons/monsters.json")

FIELDS_KEEP = {
    "name", "glyph", "hd", "hp_10x", "ac", "ev", "speed", "will", "exp",
    "attacks", "size", "intelligence", "shape", "habitat", "flags",
    "shout", "genus", "resists", "uses", "holiness", "energy", "has_corpse",
    "spells",
}


def file_id(path: Path) -> str:
    """Convert 'orc-warrior.yaml' → 'orc_warrior'."""
    stem = path.stem.replace("-", "_")
    return stem


def load_yaml(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f) or {}


def clean(entry: dict) -> dict:
    """Keep only fields we use in the game."""
    return {k: v for k, v in entry.items() if k in FIELDS_KEEP}


def main() -> int:
    if not SOURCE_DIR.is_dir():
        print(f"ERROR: source dir missing: {SOURCE_DIR}", file=sys.stderr)
        return 1
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    out: dict = {}
    skipped = 0
    errors: list[str] = []
    for yml in sorted(SOURCE_DIR.glob("*.yaml")):
        name = yml.name
        if name.startswith("deprecated-") or name.startswith("TEST"):
            skipped += 1
            continue
        try:
            data = load_yaml(yml)
        except yaml.YAMLError as e:
            errors.append(f"{name}: {e}")
            continue
        if not isinstance(data, dict):
            errors.append(f"{name}: not a dict")
            continue
        mid = file_id(yml)
        out[mid] = clean(data)
    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"Wrote {OUT_FILE} with {len(out)} monsters "
          f"(skipped {skipped} deprecated/test).")
    if errors:
        print(f"--- {len(errors)} parse errors:", file=sys.stderr)
        for e in errors[:10]:
            print(f"  {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
