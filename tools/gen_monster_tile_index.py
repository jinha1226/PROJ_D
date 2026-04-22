#!/usr/bin/env python3
"""Rebuild assets/dcss_tiles/monster_tile_index.json.

Walks `assets/dcss_tiles/individual/mon/**` and emits a stem → relative-path
dict consumed by TileRenderer.monster(). Re-run after dropping new DCSS
monster tiles into the assets tree.
"""
import json
import os

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
MON_DIR = os.path.join(ROOT, "assets/dcss_tiles/individual/mon")
OUT = os.path.join(ROOT, "assets/dcss_tiles/monster_tile_index.json")
REL_ROOT = os.path.join(ROOT, "assets/dcss_tiles/individual")


def main() -> None:
    index: dict[str, str] = {}
    for dirpath, _, files in os.walk(MON_DIR):
        for f in files:
            if not f.endswith(".png") or f.endswith(".import"):
                continue
            stem = f[:-4]
            rel = os.path.relpath(os.path.join(dirpath, f), REL_ROOT)
            # Prefer the shortest path when the same stem appears in multiple
            # subdirectories — the top-level copy tends to be the "canonical"
            # variant used by DCSS.
            existing = index.get(stem)
            if existing is None or len(rel) < len(existing):
                index[stem] = rel

    # Also alias zero-suffixed base names, so "orc0.png" is findable as "orc".
    for stem in list(index.keys()):
        if stem.endswith("0") and stem[:-1] not in index:
            index[stem[:-1]] = index[stem]

    with open(OUT, "w") as fp:
        json.dump(index, fp, sort_keys=True, indent=2)
    print(f"wrote {OUT} ({len(index)} entries)")


if __name__ == "__main__":
    main()
