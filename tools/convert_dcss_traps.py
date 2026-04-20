#!/usr/bin/env python3
"""Encode DCSS trap data → assets/dcss_traps/traps.json

Data from feature-data.h (trap definitions) and traps.cc (effects).
Mechanical traps (spear, bolt) deal projectile-style damage scaled by depth.
"""
import json
from pathlib import Path

OUT = Path(__file__).parent.parent / "assets/dcss_traps/traps.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

# From feature-data.h TRAP() macros and traps.cc trigger logic.
# damage: dice expression evaluated at depth, or special string.
# depth_range: [min_abs_depth, max_abs_depth] for natural generation.
TRAPS = [
    {
        "id":          "trap_mechanical",
        "name":        "mechanical trap",
        "effect":      "physical_damage",
        "damage":      "1d(4+depth/3)",
        "depth_range": [1, 27],
        "tile":        "dngn/traps/trap_bolt.png",
        "color":       "lightcyan",
        "destroys":    False,
        "description": "Generic mechanical trap; shoots a bolt or spear.",
    },
    {
        "id":          "trap_spear",
        "name":        "spear trap",
        "effect":      "physical_damage",
        "damage":      "1d(6+depth/3)",
        "depth_range": [1, 20],
        "tile":        "dngn/traps/trap_spear.png",
        "color":       "lightcyan",
        "destroys":    False,
        "description": "Fires a spear. Damage scales with depth.",
    },
    {
        "id":          "trap_bolt",
        "name":        "bolt trap",
        "effect":      "physical_damage",
        "damage":      "1d(5+depth/3)",
        "depth_range": [1, 20],
        "tile":        "dngn/traps/trap_bolt.png",
        "color":       "lightcyan",
        "destroys":    False,
        "description": "Fires a crossbow bolt. Damage scales with depth.",
    },
    {
        "id":          "trap_net",
        "name":        "net trap",
        "effect":      "ensnare",
        "damage":      "0",
        "depth_range": [1, 15],
        "tile":        "dngn/traps/trap_net.png",
        "color":       "lightcyan",
        "destroys":    False,
        "description": "Captures the player in a net, preventing movement.",
    },
    {
        "id":          "trap_teleport",
        "name":        "teleport trap",
        "effect":      "teleport",
        "damage":      "0",
        "depth_range": [1, 27],
        "tile":        "dngn/traps/trap_teleport.png",
        "color":       "lightblue",
        "destroys":    True,
        "description": "Teleports the player to a random location. Destroyed on use.",
    },
    {
        "id":          "trap_teleport_permanent",
        "name":        "permanent teleport trap",
        "effect":      "teleport",
        "damage":      "0",
        "depth_range": [3, 27],
        "tile":        "dngn/traps/trap_teleport_permanent.png",
        "color":       "lightblue",
        "destroys":    False,
        "description": "Repeatedly teleports the player; not consumed on use.",
    },
    {
        "id":          "trap_alarm",
        "name":        "alarm trap",
        "effect":      "alert_monsters",
        "damage":      "0",
        "depth_range": [3, 27],
        "tile":        "dngn/traps/trap_alarm.png",
        "color":       "lightred",
        "destroys":    True,
        "description": "Marks the player — all monsters in LOS are alerted.",
    },
    {
        "id":          "trap_dispersal",
        "name":        "dispersal trap",
        "effect":      "blink_all",
        "damage":      "0",
        "depth_range": [5, 27],
        "tile":        "dngn/traps/trap_dispersal.png",
        "color":       "magenta",
        "destroys":    False,
        "description": "Blinks all creatures in the area, then goes dormant.",
    },
    {
        "id":          "trap_shadow",
        "name":        "shadow trap",
        "effect":      "summon_shadow",
        "damage":      "0",
        "depth_range": [10, 27],
        "tile":        "dngn/traps/trap_shadow.png",
        "color":       "blue",
        "destroys":    False,
        "description": "Summons shadow-type monsters near the player.",
    },
    {
        "id":          "trap_zot",
        "name":        "Zot trap",
        "effect":      "random_bad",
        "damage":      "varies",
        "depth_range": [20, 27],
        "tile":        "dngn/traps/trap_zot.png",
        "color":       "lightmagenta",
        "destroys":    False,
        "description": "Triggers a random bad effect — teleport, summon, or stat drain.",
    },
    {
        "id":          "trap_shaft",
        "name":        "shaft",
        "effect":      "fall_down",
        "damage":      "0",
        "depth_range": [3, 26],
        "tile":        "dngn/traps/shaft.png",
        "color":       "brown",
        "destroys":    True,
        "description": "Falls the player 1-3 floors deeper.",
    },
    {
        "id":          "trap_web",
        "name":        "web",
        "effect":      "ensnare_web",
        "damage":      "0",
        "depth_range": [1, 27],
        "tile":        "dngn/traps/web.png",
        "color":       "lightgrey",
        "destroys":    False,
        "description": "Catches the player in a web; movement chance to break free.",
    },
    {
        "id":          "trap_plate",
        "name":        "pressure plate",
        "effect":      "vault_trigger",
        "damage":      "varies",
        "depth_range": [5, 27],
        "tile":        "dngn/traps/trap_plate.png",
        "color":       "lightcyan",
        "destroys":    False,
        "description": "Vault-defined trigger; effect depends on vault design.",
    },
    {
        "id":          "trap_tyrant",
        "name":        "tyrant's trap",
        "effect":      "weaken_player",
        "damage":      "0",
        "depth_range": [10, 27],
        "tile":        "dngn/traps/trap_tyrant.png",
        "color":       "white",
        "destroys":    False,
        "description": "Applies DUR_WEAK to player; buffs nearby monsters with might.",
        "dur_base": 10, "dur_rand": 5,
    },
    {
        "id":          "trap_archmage",
        "name":        "archmage's trap",
        "effect":      "drain_mp_buff_monsters",
        "damage":      "0",
        "depth_range": [10, 27],
        "tile":        "dngn/traps/trap_archmage.png",
        "color":       "blue",
        "destroys":    False,
        "description": "Drains player MP; empowers monster spells.",
        "mp_drain_pct": 0.33,
    },
    {
        "id":          "trap_harlequin",
        "name":        "harlequin's trap",
        "effect":      "chaos_buff_monsters",
        "damage":      "0",
        "depth_range": [10, 27],
        "tile":        "dngn/traps/trap_harlequin.png",
        "color":       "yellow",
        "destroys":    False,
        "description": "Laces nearby monster attacks with chaos for ~200 turns.",
    },
    {
        "id":          "trap_devourer",
        "name":        "devourer's trap",
        "effect":      "corrode",
        "damage":      "corrode_6",
        "depth_range": [10, 27],
        "tile":        "dngn/traps/trap_devourer.png",
        "color":       "lightgreen",
        "destroys":    False,
        "description": "75% chance: corrodes player items by 6.",
    },
]

# Depth-weighted generation pool (from _place_trap in dungeon.cc logic).
# Players rarely see all trap types; most common are mechanical/teleport/alarm.
TRAP_WEIGHTS_BY_DEPTH = {}
for d in range(1, 28):
    pool = [
        ("trap_spear",    4 if d <= 20 else 0),
        ("trap_bolt",     4 if d <= 20 else 0),
        ("trap_net",      3 if d <= 15 else 0),
        ("trap_teleport", 4),
        ("trap_alarm",    3 if d >= 3 else 0),
        ("trap_shaft",    4 if 3 <= d <= 26 else 0),
        ("trap_web",      2),
        ("trap_dispersal",2 if d >= 5 else 0),
        ("trap_zot",      3 if d >= 20 else 0),
        ("trap_tyrant",   1 if d >= 10 else 0),
        ("trap_archmage", 1 if d >= 10 else 0),
        ("trap_harlequin",1 if d >= 10 else 0),
        ("trap_devourer", 1 if d >= 10 else 0),
        ("trap_shadow",   1 if d >= 10 else 0),
    ]
    TRAP_WEIGHTS_BY_DEPTH[str(d)] = [(t, w) for t, w in pool if w > 0]

output = {
    "_comment": "DCSS trap data from feature-data.h and traps.cc (0.32).",
    "traps":    TRAPS,
    "by_id":    {t["id"]: t for t in TRAPS},
    "weights_by_depth": TRAP_WEIGHTS_BY_DEPTH,
}

OUT.write_text(json.dumps(output, indent=2, ensure_ascii=False))
print(f"Wrote {len(TRAPS)} trap types → {OUT.relative_to(Path.cwd())}")
for t in TRAPS:
    print(f"  {t['id']:30s} effect={t['effect']:25s} depth={t['depth_range']}")
