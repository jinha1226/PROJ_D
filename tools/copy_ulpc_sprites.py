#!/usr/bin/env python3
"""Mirror ULPC spritesheets referenced by assets/lpc_defs/*.json into assets/ulpc/.

Run from repo root:
    python3 tools/copy_ulpc_sprites.py

Copies only the PNGs actually referenced by our def files, preserving the
relative directory structure so paths resolve 1:1 at runtime.
"""
from __future__ import annotations

import json
import shutil
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
ULPC_SRC = REPO / "Universal-LPC-Spritesheet-Character-Generator" / "spritesheets"
DEFS_DIR = REPO / "assets" / "lpc_defs"
DST = REPO / "assets" / "ulpc"

BODY_KEYS = ("male", "muscular", "female", "pregnant", "teen", "child")


def collect_layer_paths(def_data: dict) -> list[dict]:
    layers = []
    for key, val in def_data.items():
        if not key.startswith("layer_") or not isinstance(val, dict):
            continue
        layers.append(val)
    return layers


def iter_layer_png_paths(def_data: dict):
    """Yield relative PNG paths (POSIX) this def needs.

    For standard layers (no custom_animation), probes the source to discover
    which animation subfolders actually exist — ULPC layouts are irregular
    (e.g. bow foreground has shoot/hurt but not walk, which is replaced by
    walk_128 on a different layer).
    """
    layers = collect_layer_paths(def_data)
    has_variants = bool(def_data.get("variants"))
    variants = def_data.get("variants") or [""]

    for layer in layers:
        is_custom = bool(layer.get("custom_animation"))
        dirs = set()
        for bk in BODY_KEYS:
            p = layer.get(bk)
            if p:
                dirs.add(p.rstrip("/"))
        for d in dirs:
            if is_custom:
                if has_variants:
                    for v in variants:
                        yield f"{d}/{v}.png"
                else:
                    # No variants: the custom-anim PNG is just the layer dir
                    # itself (rare for our defs, but keep the shape).
                    yield f"{d.rstrip('/')}.png"
            else:
                src_dir = ULPC_SRC / d
                if not src_dir.is_dir():
                    continue
                if has_variants:
                    for anim_dir in sorted(src_dir.iterdir()):
                        if not anim_dir.is_dir():
                            continue
                        # ULPC uses structural subfolders (behind/, bg/, ...)
                        # gate on actual variant.png existence to skip them.
                        for v in variants:
                            if (anim_dir / f"{v}.png").is_file():
                                yield f"{d}/{anim_dir.name}/{v}.png"
                else:
                    # Variant-less layout (armor): {dir}/{anim}.png directly.
                    for child in sorted(src_dir.iterdir()):
                        if child.is_file() and child.suffix == ".png":
                            yield f"{d}/{child.name}"


def main() -> int:
    if not ULPC_SRC.is_dir():
        print(f"ULPC source missing: {ULPC_SRC}", file=sys.stderr)
        return 1
    if not DEFS_DIR.is_dir():
        print(f"Defs dir missing: {DEFS_DIR}", file=sys.stderr)
        return 1

    DST.mkdir(parents=True, exist_ok=True)

    index_path = DEFS_DIR / "index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))

    wanted: set[str] = set()
    for item_id, fname in index.items():
        def_file = DEFS_DIR / fname
        data = json.loads(def_file.read_text(encoding="utf-8"))
        for rel in iter_layer_png_paths(data):
            wanted.add(rel)

    copied = skipped = missing = 0
    for rel in sorted(wanted):
        src = ULPC_SRC / rel
        dst = DST / rel
        if not src.is_file():
            missing += 1
            print(f"  MISS {rel}")
            continue
        if dst.is_file() and dst.stat().st_size == src.stat().st_size:
            skipped += 1
            continue
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, dst)
        copied += 1

    print(
        f"Done. wanted={len(wanted)} copied={copied} "
        f"skipped(unchanged)={skipped} missing={missing}"
    )
    return 0 if missing == 0 else 2


if __name__ == "__main__":
    raise SystemExit(main())
