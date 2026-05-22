#!/usr/bin/env python3
from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ZONE_MANAGER = ROOT / "scripts/systems/ZoneManager.gd"
DUNGEON_MAP = ROOT / "scripts/dungeon/DungeonMap.gd"


ROW_TYPE_BY_CATEGORY = {
    "floor": "floor",
    "wall": "wall",
    "water": "floor",
    "doors": "object",
    "gateways": "object",
    "altars": "object",
    "decor": "object",
    "statues": "object",
    "trees": "object",
    "traps": "object",
    "shops": "object",
}


def res_to_project(path: str) -> str:
    return path.replace("res://", "")


def category(path: str) -> str:
    marker = "assets/tiles/individual/dngn/"
    if marker not in path:
        return "other"
    rest = path.split(marker, 1)[1]
    parts = rest.split("/")
    return parts[0] if len(parts) > 1 else "misc"


def row_type(path: str) -> str:
    return ROW_TYPE_BY_CATEGORY.get(category(path), "object")


def add_tile(groups: dict, concept: str, path: str, role: str) -> None:
    project_path = res_to_project(path)
    entry = {
        "role": role,
        "category": category(project_path),
        "row_type": row_type(project_path),
        "path": project_path,
        "exists": (ROOT / project_path).exists(),
    }
    groups[concept].append(entry)


def extract_zone_blocks(text: str, const_name: str) -> str:
    start = text.index(f"const {const_name}")
    next_const = text.find("\nconst ", start + 1)
    if next_const == -1:
        return text[start:]
    return text[start:next_const]


def parse_zone_manager() -> dict:
    text = ZONE_MANAGER.read_text(encoding="utf-8")
    groups: dict[str, list[dict]] = defaultdict(list)

    main_block = extract_zone_blocks(text, "MAIN_ZONES")
    for match in re.finditer(r'\{"id":\s*"([^"]+)".*?\n\s*"wall":\s*"([^"]+)".*?\n\s*"floor":\s*"([^"]+)"', main_block, re.S):
        concept, wall, floor = match.groups()
        add_tile(groups, concept, floor, "configured_floor")
        add_tile(groups, concept, wall, "configured_wall")

    branches_block = extract_zone_blocks(text, "BRANCHES")
    for match in re.finditer(r'"([^"]+)":\s*\{(.*?)\n\t\}', branches_block, re.S):
        concept, block = match.groups()
        if concept in {"display_name", "map_style", "env"}:
            continue
        for key, role in (
            ("floor", "configured_floor"),
            ("wall", "configured_wall"),
            ("entrance_tile", "branch_entrance"),
        ):
            km = re.search(rf'"{key}":\s*"([^"]+)"', block)
            if km:
                add_tile(groups, concept, km.group(1), role)

    return groups


def parse_dungeon_map(groups: dict) -> None:
    text = DUNGEON_MAP.read_text(encoding="utf-8")
    shared_roles = {
        "metal_stairs_up.png": "stairs_up",
        "metal_stairs_down.png": "stairs_down",
        "closed_door.png": "door_closed",
        "open_door.png": "door_open",
    }
    for path in sorted(set(re.findall(r'"res://assets/tiles/individual/dngn/[^"]+\.png"', text))):
        clean = path.strip('"')
        filename = clean.rsplit("/", 1)[-1]
        if filename in shared_roles:
            add_tile(groups, "shared_features", clean, shared_roles[filename])

    add_tile(groups, "temple", "res://assets/tiles/individual/dngn/floor/mosaic0.png", "override_floor")
    add_tile(groups, "temple", "res://assets/tiles/individual/dngn/wall/marble_wall1.png", "override_wall")

    altar_block = re.search(r"const ALTAR_TEXTURES: Dictionary = \{(.*?)\n\}", text, re.S)
    if altar_block:
        for faith_id, path in re.findall(r'"([^"]+)":\s*"([^"]+)"', altar_block.group(1)):
            add_tile(groups, "temple", path, f"faith_altar:{faith_id}")

    broken_block = re.search(r"const _BROKEN_ALTAR_PATHS: Array = \[(.*?)\n\]", text, re.S)
    if broken_block:
        for path in re.findall(r'"([^"]+)"', broken_block.group(1)):
            add_tile(groups, "temple", path, "broken_altar_variant")


def summarize(entries: list[dict]) -> dict:
    counts = defaultdict(int)
    for entry in entries:
        counts[entry["row_type"]] += 1
    return {
        "floor": counts["floor"],
        "wall": counts["wall"],
        "object": counts["object"],
        "total": len(entries),
    }


def main() -> None:
    groups = parse_zone_manager()
    parse_dungeon_map(groups)

    # De-duplicate exact path+role entries while preserving concept-specific rows.
    concepts = {}
    for concept, entries in sorted(groups.items()):
        seen = set()
        deduped = []
        for entry in entries:
            key = (entry["path"], entry["role"])
            if key in seen:
                continue
            seen.add(key)
            deduped.append(entry)
        concepts[concept] = {
            "counts": summarize(deduped),
            "tiles": deduped,
        }

    out = {
        "source": [
            "scripts/systems/ZoneManager.gd",
            "scripts/dungeon/DungeonMap.gd",
        ],
        "note": "Currently referenced dngn terrain/object tiles, grouped by runtime concept.",
        "concepts": concepts,
    }

    target = ROOT / "assets/tiles/sheets/ulpc_concepts/used_dngn_tile_inventory.json"
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({k: v["counts"] for k, v in concepts.items()}, indent=2))


if __name__ == "__main__":
    main()
