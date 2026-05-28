#!/usr/bin/env python3
"""Add essence_ids arrays to all monster .tres files.
Each monster gets a pool of 2-3 thematically appropriate essences.
The drop logic in Game.gd picks one at random each time the monster dies.
"""

import re
from pathlib import Path

MONSTER_DIR = Path("/mnt/d/PROJ_D/resources/monsters")

# monster_id -> list of essence IDs (normal/rare for regulars, may include unique for bosses)
POOLS = {
    # ── Z1: Dungeon Entrance ──────────────────────────────────────────────
    "goblin":           ["essence_fang", "essence_pack", "essence_nimble"],
    "kobold":           ["essence_nimble", "essence_swiftness", "essence_fang"],
    "hobgoblin":        ["essence_fang", "essence_iron_will", "essence_might"],
    "zombie":           ["essence_marrow", "essence_regeneration", "essence_vitality"],
    "wolf":             ["essence_fang", "essence_pack", "essence_swiftness"],

    # ── Z2: Shallow Dungeon ───────────────────────────────────────────────
    "adder":            ["essence_venom", "essence_nimble", "essence_swiftness"],
    "viper":            ["essence_venom", "essence_scales", "essence_nimble"],
    "anaconda":         ["essence_constrict", "essence_scales", "essence_might"],
    "orc":              ["essence_fang", "essence_iron_will", "essence_vitality"],
    "orc_warrior":      ["essence_iron_will", "essence_fang", "essence_might"],
    "orc_priest":       ["essence_warding", "essence_marrow", "essence_vitality"],
    "orc_wizard":       ["essence_warding", "essence_shadow", "essence_swiftness"],
    "gnoll":            ["essence_fang", "essence_pack", "essence_tracker"],
    "gnoll_sergeant":   ["essence_iron_will", "essence_fang", "essence_pack"],
    "scorpion":         ["essence_venom", "essence_scales", "essence_fang"],
    "black_bear":       ["essence_vitality", "essence_might", "essence_regeneration"],

    # ── Z3: Mid Dungeon ───────────────────────────────────────────────────
    "gnoll_shaman":     ["essence_wither", "essence_tracker", "essence_shadow"],
    "crimson_imp":      ["essence_fire", "essence_nimble", "essence_swiftness"],
    "red_devil":        ["essence_fire", "essence_iron_will", "essence_might"],
    "shadow_wraith":    ["essence_shadow", "essence_wither", "essence_cold"],
    "wraith":           ["essence_shadow", "essence_wither", "essence_marrow"],
    "ghoul":            ["essence_marrow", "essence_wither", "essence_venom"],
    "giant_wolf_spider":["essence_venom", "essence_swiftness", "essence_nimble"],
    "troll":            ["essence_regeneration", "essence_might", "essence_vitality"],
    "ogre":             ["essence_might", "essence_iron_will", "essence_vitality"],
    "ogre_mage":        ["essence_warding", "essence_shadow", "essence_might"],

    # ── Z4: Deep Dungeon ──────────────────────────────────────────────────
    "skeletal_warrior": ["essence_marrow", "essence_iron_will", "essence_might"],
    "mummy":            ["essence_wither", "essence_marrow", "essence_stone"],
    "vampire":          ["essence_blood", "essence_shadow", "essence_swiftness"],
    "vampire_bat":      ["essence_blood", "essence_nimble", "essence_swiftness"],
    "vampire_knight":   ["essence_blood", "essence_iron_will", "essence_shadow"],
    "gargoyle":         ["essence_stone", "essence_scales", "essence_iron_will"],
    "stone_warden":     ["essence_stone", "essence_scales", "essence_warding"],
    "deep_elf_archer":  ["essence_tracker", "essence_swiftness", "essence_nimble"],
    "deep_elf_death_mage": ["essence_wither", "essence_shadow", "essence_marrow"],

    # ── Z5: Abyss Approach ────────────────────────────────────────────────
    "lich":             ["essence_wither", "essence_marrow", "essence_shadow"],
    "cyclops":          ["essence_might", "essence_iron_will", "essence_stone"],
    "stone_giant":      ["essence_stone", "essence_might", "essence_iron_will"],
    "titan":            ["essence_titan", "essence_might", "essence_iron_will"],
    "executioner":      ["essence_fang", "essence_wither", "essence_shadow"],
    "balrug":           ["essence_fire", "essence_might", "essence_iron_will"],
    "bone_dragon":      ["essence_marrow", "essence_scales", "essence_might"],

    # ── Z6: The Vault ─────────────────────────────────────────────────────
    "fire_dragon":      ["essence_fire", "essence_scales", "essence_might"],
    "ice_dragon":       ["essence_cold", "essence_scales", "essence_iron_will"],
    "swamp_dragon":     ["essence_venom", "essence_scales", "essence_constrict"],

    # ── Branch bosses (unique=true; drop unique-tier essences) ────────────
    "ancient_lich":     ["essence_necromancer", "essence_undeath", "essence_abyssal"],
    "bog_serpent":      ["essence_serpent", "essence_plague", "essence_constrict"],
    "ember_tyrant":     ["essence_cinder", "essence_infernal", "essence_war_cry"],
    "glacial_sovereign":["essence_glacial", "essence_tempest", "essence_cold"],
    "golden_dragon":    ["essence_golden", "essence_bastion", "essence_dread"],
}


def array_gdscript(ids):
    quoted = ", ".join(f'"{x}"' for x in ids)
    return f"[{quoted}]"


def update_tres(path: Path, pool: list[str]) -> bool:
    text = path.read_text(encoding="utf-8")

    # Already has essence_ids? Replace it.
    if "essence_ids" in text:
        new_text = re.sub(
            r'essence_ids\s*=\s*.*',
            f'essence_ids = {array_gdscript(pool)}',
            text,
        )
        if new_text != text:
            path.write_text(new_text, encoding="utf-8")
            return True
        return False

    # Insert after essence_id line (or append before the last blank line).
    insert_line = f'essence_ids = {array_gdscript(pool)}'
    if "essence_id" in text:
        new_text = re.sub(
            r'(essence_id\s*=\s*"[^"]*")',
            r'\1\n' + insert_line,
            text,
            count=1,
        )
    else:
        # Append before trailing newline
        new_text = text.rstrip("\n") + f"\n{insert_line}\n"

    path.write_text(new_text, encoding="utf-8")
    return True


updated = 0
skipped = 0
for monster_id, pool in POOLS.items():
    tres = MONSTER_DIR / f"{monster_id}.tres"
    if not tres.exists():
        print(f"  MISSING: {tres.name}")
        skipped += 1
        continue
    if update_tres(tres, pool):
        print(f"  OK: {monster_id} <- {pool}")
        updated += 1
    else:
        print(f"  SKIP (no change): {monster_id}")
        skipped += 1

print(f"\nDone. {updated} updated, {skipped} skipped/missing.")
