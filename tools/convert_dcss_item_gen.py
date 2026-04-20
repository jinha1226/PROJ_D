#!/usr/bin/env python3
"""Encode DCSS makeitem depth-based item generation tables → assets/dcss_items/item_gen.json

Tables:
  weapon_tiers: depth → weighted list of weapon ids
  armour_tiers: depth → weighted list of armour ids
  consumable_tiers: depth → weighted list of consumable ids (from ConsumableRegistry)

Encoding of DCSS _determine_weapon_subtype(item_level):
  tier0 (≤5):  common early weapons
  tier1 (6-14): mid-range
  tier2 (15-22): good finds
  tier3 (23+):  rare powerful

For armour we replicate pick_random_body_armour_type(item_level) tiers.
"""
import json
from pathlib import Path

OUT = Path(__file__).parent.parent / "assets/dcss_items/item_gen.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

# DCSS _determine_weapon_subtype tier mapping → our weapon ids
# "common" tier: always available; "mid" from depth ~5; "good" ~10; "rare" ~15+
WEAPON_TIERS = {
    "common": {            # depth 1-5: basic gear
        "club":2, "dagger":2, "hand_axe":1, "mace":1,
        "short_sword":1, "spear":1, "whip":1,
    },
    "mid": {               # depth 6-12: decent weapons
        "flail":2, "long_sword":2, "falchion":2, "rapier":2,
        "war_axe":2, "trident":2, "quarterstaff":1,
        "shortbow":1, "orcbow":1,
    },
    "good": {              # depth 13-20: powerful
        "scimitar":2, "halberd":2, "morningstar":2,
        "broad_axe":2, "glaive":2, "arbalest":2, "longbow":2,
        "battleaxe":1, "eveningstar":1, "dire_flail":1,
        "lajatang":1,
    },
    "rare": {              # depth 21+: high-end
        "great_sword":2, "demon_blade":2, "executioners_axe":2,
        "bardiche":2, "triple_sword":1, "quick_blade":1,
        "lajatang":2, "double_sword":1,
    },
}

# depth → [tier weights as (weight, tier_name)]
# Probabilities based on x_chance_in_y(item_level+1, 27) logic
WEAPON_BY_DEPTH = {}
for d in range(1, 28):
    if d <= 5:
        weights = [("common", 70), ("mid", 25), ("good", 5), ("rare", 0)]
    elif d <= 12:
        weights = [("common", 30), ("mid", 50), ("good", 18), ("rare", 2)]
    elif d <= 20:
        weights = [("common", 10), ("mid", 25), ("good", 50), ("rare", 15)]
    else:
        weights = [("common", 5), ("mid", 10), ("good", 35), ("rare", 50)]
    WEAPON_BY_DEPTH[str(d)] = weights

# DCSS pick_random_body_armour_type tier mapping → our armour ids
ARMOUR_TIERS = {
    "common": {        # robe, leather, ring mail
        "robe":2, "leather_armour":2, "ring_mail":1,
    },
    "mid": {           # scale, chain, + common
        "scale_mail":2, "chain_mail":2,
        "robe":1, "leather_armour":1,
    },
    "good": {          # plate + mid
        "plate_armour":2, "chain_mail":1,
        "troll_leather_armour":1,
    },
    "rare": {          # crystal plate
        "crystal_plate_armour":2, "plate_armour":1,
    },
    # aux armour (shields, helms etc.) — picked 1-in-5
    "aux": {
        "buckler":3, "kite_shield":2, "tower_shield":1,
        "helmet":3, "gloves":2, "boots":2, "cloak":2, "hat":1,
    },
}

ARMOUR_BY_DEPTH = {}
for d in range(1, 28):
    if d <= 5:
        body = [("common", 75), ("mid", 20), ("good", 5), ("rare", 0)]
    elif d <= 12:
        body = [("common", 30), ("mid", 50), ("good", 18), ("rare", 2)]
    elif d <= 20:
        body = [("common", 10), ("mid", 30), ("good", 50), ("rare", 10)]
    else:
        body = [("common", 5), ("mid", 10), ("good", 40), ("rare", 45)]
    ARMOUR_BY_DEPTH[str(d)] = body

# Consumable tier pools (our ids)
CONSUMABLE_TIERS = {
    "common": [
        "minor_potion", "potion_curing", "scroll_identify",
        "scroll_blink", "scroll_teleport",
    ],
    "mid": [
        "major_potion", "mana_potion", "potion_haste", "potion_might",
        "potion_brilliance", "potion_agility", "scroll_magic_map",
        "scroll_enchant_weapon", "scroll_enchant_armor", "scroll_remove_curse",
        "scroll_fear",
    ],
    "good": [
        "potion_resistance", "potion_magic", "potion_restore",
        "scroll_vulnerability", "scroll_immolation", "scroll_fog",
        "scroll_holy_word", "scroll_acquirement",
    ],
}

CONS_BY_DEPTH = {}
for d in range(1, 28):
    if d <= 5:
        pools = [("common", 80), ("mid", 18), ("good", 2)]
    elif d <= 14:
        pools = [("common", 40), ("mid", 50), ("good", 10)]
    else:
        pools = [("common", 20), ("mid", 45), ("good", 35)]
    CONS_BY_DEPTH[str(d)] = pools

output = {
    "_comment": "DCSS-based depth-scaled item generation tables.",
    "weapon_tiers":    WEAPON_TIERS,
    "weapon_by_depth": WEAPON_BY_DEPTH,
    "armour_tiers":    ARMOUR_TIERS,
    "armour_by_depth": ARMOUR_BY_DEPTH,
    "consumable_tiers":    CONSUMABLE_TIERS,
    "consumable_by_depth": CONS_BY_DEPTH,
}

OUT.write_text(json.dumps(output, indent=2))
print(f"Wrote item_gen.json — weapon tiers: {len(WEAPON_TIERS)}, armour tiers: {len(ARMOUR_TIERS)}")
