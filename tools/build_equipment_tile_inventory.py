#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ITEM_DIR = ROOT / "resources/items"
OUT = ROOT / "assets/tiles/sheets/ulpc_equipment/equipment_tile_inventory.json"
EQUIPMENT_KINDS = {"weapon", "armor", "shield", "helmet", "gloves", "boots", "ring", "amulet"}


def get_value(text: str, key: str) -> str:
    match = re.search(rf'^{key}\s*=\s*"([^"]*)"', text, re.M)
    return match.group(1) if match else ""


def target_group(kind: str, slot: str) -> str:
    if kind == "weapon":
        return "weapons"
    if kind in {"armor", "shield", "helmet", "gloves", "boots"}:
        return "armour"
    if kind in {"ring", "amulet"}:
        return "jewellery"
    return slot or kind or "misc"


def default_target(item_id: str, kind: str) -> str:
    group = target_group(kind, "")
    return f"assets/tiles/individual/item/ulpc_equipment/{group}/{item_id}.png"


def main() -> None:
    entries = []
    for path in sorted(ITEM_DIR.glob("*.tres")):
        text = path.read_text(encoding="utf-8")
        kind = get_value(text, "kind")
        slot = get_value(text, "slot")
        if kind not in EQUIPMENT_KINDS:
            continue
        item_id = get_value(text, "id")
        tile_path = get_value(text, "tile_path")
        entries.append(
            {
                "id": item_id,
                "display_name": get_value(text, "display_name"),
                "kind": kind,
                "slot": slot,
                "resource": str(path.relative_to(ROOT)),
                "original_tile_path": tile_path.replace("res://", ""),
            }
        )

    by_path = defaultdict(list)
    for entry in entries:
        by_path[entry["original_tile_path"]].append(entry["id"])

    for entry in entries:
        original = entry["original_tile_path"]
        needs_new = original == "" or len(by_path[original]) > 1
        entry["target_tile_path"] = default_target(entry["id"], entry["kind"]) if needs_new else original
        entry["updates_resource_tile_path"] = needs_new

    groups = defaultdict(list)
    for entry in entries:
        groups[target_group(entry["kind"], entry["slot"])].append(entry)

    out = {
        "tile_size": 32,
        "chroma_key": "#ff00ff",
        "note": "Equipment floor/shop/inventory icons. Items with empty or shared tile_path get unique generated paths.",
        "counts": {
            "items": len(entries),
            "unique_targets": len({e["target_tile_path"] for e in entries}),
            "resource_updates": sum(1 for e in entries if e["updates_resource_tile_path"]),
        },
        "groups": {k: v for k, v in sorted(groups.items())},
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(out, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(out["counts"], indent=2))
    for group, values in sorted(groups.items()):
        print(group, len(values))


if __name__ == "__main__":
    main()
