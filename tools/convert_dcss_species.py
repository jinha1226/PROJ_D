#!/usr/bin/env python3
"""Convert DCSS species YAML files into a single aptitudes JSON.

Output: assets/dcss_species/aptitudes.json
Format: {id: {"aptitudes": {skill: int, ...}, "base_str": int, "base_int": int,
              "base_dex": int, "levelup_stat_frequency": int,
              "levelup_stats": [...], "hp_mod": int, "mp_mod": int,
              "xp_mod": int, "wl": int}}

ID is the YAML filename stem with `-` → `_` (e.g. deep-elf → deep_elf).
Our game's skill keys differ from DCSS's; `_SKILL_MAP` translates them.
"""

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("pip install pyyaml")

SRC = Path("/mnt/d/PROJ_D/crawl/crawl-ref/source/dat/species")
OUT = Path("/mnt/d/PROJ_D/assets/dcss_species/aptitudes.json")

# DCSS YAML skill name → our game's skill_aptitudes key.
_SKILL_MAP = {
    "fighting": "fighting",
    "short_blades": "short_blade",
    "long_blades": "long_blade",
    "axes": "axe",
    "maces_and_flails": "mace",
    "polearms": "polearm",
    "staves": "staff",
    "ranged_weapons": "bow",     # our game splits; bow is the primary
    "ranged weapons": "bow",
    "throwing": "throwing",
    "armour": "armour",
    "dodging": "dodging",
    "stealth": "stealth",
    "shields": "shields",
    "unarmed_combat": "unarmed",
    "spellcasting": "spellcasting",
    "conjurations": "conjurations",
    "hexes": "hexes",
    "summoning": "summonings",
    "forgecraft": "forgecraft",
    "necromancy": "necromancy",
    "translocations": "translocations",
    "shapeshifting": "shapeshifting",
    "fire_magic": "fire",
    "ice_magic": "cold",
    "air_magic": "air",
    "earth_magic": "earth",
    "alchemy": "alchemy",
    "evocations": "evocations",
    "invocations": "invocations",
}

# Special non-skill aptitudes kept separately.
_META_APTS = {"xp", "hp", "mp_mod", "wl", "mr"}


def convert_one(path: Path) -> tuple[str, dict] | None:
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        return None
    sid = path.stem.replace("-", "_")
    apts_raw = data.get("aptitudes", {}) or {}
    mapped: dict = {}
    meta: dict = {}
    for k, v in apts_raw.items():
        if k in _META_APTS:
            meta[k] = int(v)
            continue
        our_k = _SKILL_MAP.get(k)
        if our_k is None:
            continue
        mapped[our_k] = int(v)
    entry = {
        "aptitudes": mapped,
        "base_str": int(data.get("str", 8)),
        "base_int": int(data.get("int", 8)),
        "base_dex": int(data.get("dex", 8)),
        "levelup_stat_frequency": int(data.get("levelup_stat_frequency", 4)),
        "levelup_stats": [str(s) for s in (data.get("levelup_stats") or [])],
        "difficulty": str(data.get("difficulty", "Intermediate")),
    }
    # Attach optional aptitude meta (xp, hp, mp_mod, wl).
    if meta:
        entry.update(meta)
    return sid, entry


def main() -> int:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    out: dict = {}
    for yml in sorted(SRC.glob("*.yaml")):
        if yml.name.startswith("deprecated-"):
            continue
        res = convert_one(yml)
        if res is None:
            continue
        sid, entry = res
        out[sid] = entry
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"Wrote {OUT} with {len(out)} species.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
