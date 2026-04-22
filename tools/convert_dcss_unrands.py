#!/usr/bin/env python3
"""Parse DCSS crawl-ref/source/art-data.txt and emit the canonical
unrandart roster in the shape expected by our `UnrandartRegistry.gd`
`_UNRANDS` dictionary.

Outputs:
  tools/generated/unrands_gd.txt   GDScript snippet (tabs + Color() literals)
  assets/dcss_unrands/unrands.json JSON cache for future in-script loading

Deliberate omissions / behaviours:
  * Skip DUMMY entries.
  * Skip any entry whose BOOL contains `nogen` or `deleted`.
  * Skip any entry whose OBJ base we can't map to a WeaponRegistry /
    ArmorRegistry id (printed at the end).
  * Preserve DCSS entry order — entries emit in the order they appear in
    art-data.txt so future diffs vs upstream are trivial.
  * min_depth is derived from base-tier heuristics; no DCSS field backs it.

This parser is idempotent: rerunning with no source changes produces
byte-identical outputs.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent
ART_DATA = REPO / "crawl" / "crawl-ref" / "source" / "art-data.txt"
OUT_GD   = HERE / "generated" / "unrands_gd.txt"
OUT_JSON = REPO / "assets" / "dcss_unrands" / "unrands.json"


# ------------------------------------------------------------------ #
#  Mapping tables                                                    #
# ------------------------------------------------------------------ #

# DCSS WPN_* / ARM_* -> our registry ids. Only entries we actually have
# bases for are listed; anything missing is reported as a skip warning
# so the human can decide whether to add a base or drop the unrand.
#
# Source: WeaponRegistry.DATA keys, ArmorRegistry._SLOT_MAP keys.
OBJ_TYPE_MAP = {
    # --- Weapons ---
    "WPN_CLUB":             "club",
    "WPN_WHIP":             "whip",
    "WPN_MACE":             "mace",
    "WPN_FLAIL":            "flail",
    "WPN_MORNINGSTAR":      "morningstar",
    "WPN_EVENINGSTAR":      "morningstar",   # no eveningstar base; morningstar is closest
    "WPN_DIRE_FLAIL":       "great_mace",    # no dire_flail base; use great_mace tier
    "WPN_GREAT_MACE":       "great_mace",
    "WPN_DEMON_WHIP":       "whip",          # no demon_whip base; use whip
    "WPN_DAGGER":           "dagger",
    "WPN_QUICK_BLADE":      "quick_blade",
    "WPN_SHORT_SWORD":      "short_sword",
    "WPN_RAPIER":           "rapier",
    "WPN_FALCHION":         "falchion",
    "WPN_LONG_SWORD":       "long_sword",
    "WPN_SCIMITAR":         "scimitar",
    "WPN_GREAT_SWORD":      "great_sword",
    "WPN_DOUBLE_SWORD":     "great_sword",   # no double_sword base; great_sword is closest
    "WPN_TRIPLE_SWORD":     "great_sword",   # same
    "WPN_DEMON_BLADE":      "long_sword",    # no demon_blade base
    "WPN_EUDEMON_BLADE":    "long_sword",    # no eudemon_blade base
    "WPN_HAND_AXE":         "hand_axe",
    "WPN_WAR_AXE":          "war_axe",
    "WPN_BROAD_AXE":        "broad_axe",
    "WPN_BATTLEAXE":        "battleaxe",
    "WPN_EXECUTIONERS_AXE": "battleaxe",     # no executioners_axe base; battleaxe tier
    "WPN_SPEAR":            "spear",
    "WPN_TRIDENT":          "trident",
    "WPN_DEMON_TRIDENT":    "trident",
    "WPN_TRISHULA":         "trident",
    "WPN_HALBERD":          "halberd",
    "WPN_GLAIVE":           "glaive",
    "WPN_BARDICHE":         "bardiche",
    "WPN_STAFF":            "quarterstaff",
    "WPN_QUARTERSTAFF":     "quarterstaff",
    "WPN_LAJATANG":         "quarterstaff",  # no lajatang base; use quarterstaff
    "WPN_SLING":            "slingshot",
    "WPN_SHORTBOW":         "shortbow",
    "WPN_LONGBOW":          "longbow",
    "WPN_ARBALEST":         "arbalest",
    "WPN_CROSSBOW":         "crossbow",
    "WPN_TRIPLE_CROSSBOW":  "crossbow",
    "WPN_GIANT_CLUB":       "club",          # no giant_club base; treat as club
    "WPN_HAND_CANNON":      "crossbow",      # no hand_cannon base; crossbow is closest ranged tier
    # --- Armour ---
    "ARM_ROBE":                    "robe",
    "ARM_LEATHER_ARMOUR":          "leather_armour",
    "ARM_TROLL_LEATHER_ARMOUR":    "troll_leather_armour",
    "ARM_RING_MAIL":               "ring_mail",
    "ARM_SCALE_MAIL":              "scale_mail",
    "ARM_CHAIN_MAIL":              "chain_mail",
    "ARM_PLATE_ARMOUR":            "plate_armour",
    "ARM_CRYSTAL_PLATE_ARMOUR":    "crystal_plate_armour",
    "ARM_ANIMAL_SKIN":             "animal_skin",
    "ARM_ACID_DRAGON_ARMOUR":      "leather_armour",  # no acid_dragon base; leather tier
    "ARM_GOLDEN_DRAGON_ARMOUR":    "plate_armour",    # no golden_dragon base
    "ARM_CLOAK":                   "cloak",
    "ARM_SCARF":                   "scarf",
    "ARM_HAT":                     "hat",
    "ARM_HELMET":                  "helmet",
    "ARM_GLOVES":                  "gloves",
    "ARM_BOOTS":                   "boots",
    "ARM_BARDING":                 "barding",
    "ARM_BUCKLER":                 "buckler",
    "ARM_KITE_SHIELD":             "kite_shield",
    "ARM_TOWER_SHIELD":            "tower_shield",
    "ARM_ORB":                     "orb",
    # --- Jewellery: we flag via `kind` ring/amulet, base_id not used for lookup ---
    "RING_STEALTH":          "ring",
    "RING_EVASION":          "ring",
    "RING_PROTECTION":       "ring",
    "RING_WIZARDRY":         "ring",
    "RING_FIRST_RING":       "ring",
    "AMU_NOTHING":           "amulet",
    "AMU_ACROBAT":           "amulet",
    "AMU_GUARDIAN_SPIRIT":   "amulet",
    "AMU_FAITH":             "amulet",
}

# DCSS SPWPN_* -> our CombatSystem brand id. Where we don't support the
# brand directly, we pick the closest known mechanic and the comment
# lives next to the mapping.
BRAND_MAP = {
    "SPWPN_HOLY_WRATH":       "holy_wrath",
    "SPWPN_FLAMING":          "flaming",
    "SPWPN_FREEZING":         "freezing",
    "SPWPN_DRAINING":         "draining",
    "SPWPN_SPEED":            "speed",
    "SPWPN_ELECTROCUTION":    "electrocution",
    "SPWPN_PROTECTION":       "protection",
    "SPWPN_VENOM":            "venom",
    "SPWPN_CHAOS":            "chaos",
    "SPWPN_DISTORTION":       "distortion",
    "SPWPN_PAIN":             "pain",
    "SPWPN_VORPAL":           "vorpal",
    "SPWPN_HEAVY":            "vorpal",       # HEAVY is the DCSS 0.32+ rename
    "SPWPN_ANTIMAGIC":        "antimagic",
    "SPWPN_VAMPIRISM":        "vampirism",
    "SPWPN_REAPING":          "reaping",
    "SPWPN_PENETRATION":      "penetration",
    "SPWPN_ACID":             "venom",        # no dedicated acid brand; venom is closest
    "SPWPN_FOUL_FLAME":       "flaming",      # no foul_flame; flaming is closest
    "SPWPN_VALOUR":           "",             # removed brand, no mapping
    "SPWPN_NORMAL":           "",
}

# DCSS SPARM_* -> our ArmorRegistry.EGOS id.
EGO_MAP = {
    "SPARM_FIRE_RESISTANCE":   "fire_resistance",
    "SPARM_COLD_RESISTANCE":   "cold_resistance",
    "SPARM_POISON_RESISTANCE": "poison_resistance",
    "SPARM_POSITIVE_ENERGY":   "positive_energy",
    "SPARM_MAGIC_RESISTANCE":  "willpower",
    "SPARM_WILLPOWER":         "willpower",
    "SPARM_STEALTH":           "stealth",
    "SPARM_RESISTANCE":        "resistance",
    "SPARM_PROTECTION":        "protection",
    "SPARM_STRENGTH":          "strength",
    "SPARM_DEXTERITY":         "dexterity",
    "SPARM_INTELLIGENCE":      "intelligence",
    "SPARM_PONDEROUSNESS":     "ponderousness",
    "SPARM_FLYING":            "flying",
    "SPARM_JUMPING":           "jumping",
    "SPARM_MAYHEM":            "mayhem",
    "SPARM_GUILE":             "guile",
    "SPARM_RAMPAGING":         "rampaging",
    "SPARM_INFUSION":          "infusion",
    "SPARM_SPIRIT_SHIELD":     "spirit_shield",
    "SPARM_ARCHERY":           "archery",
    "SPARM_LIGHT":             "light",
    "SPARM_REFLECTION":        "reflection",
    "SPARM_HARM":              "harm",
    "SPARM_SHADOWS":           "shadows",
    "SPARM_ARCHMAGI":          "archmagi",
    "SPARM_ENERGY":            "energy",
    "SPARM_SEE_INVISIBLE":     "see_invisible",
    "SPARM_COMMAND":           "command",
    "SPARM_REPULSION":         "repulsion",
    "SPARM_RESONANCE":         "resonance",
    "SPARM_HURLING":           "hurling",
    "SPARM_HIGH_PRIEST":       "",  # not in our EGO table
    "SPARM_NORMAL":            "",
}

# DCSS defines.h / element palette -> Godot Color literal tuples.
COLOUR_MAP = {
    "WHITE":             (1.00, 1.00, 1.00),
    "BLACK":             (0.15, 0.15, 0.15),
    "RED":               (0.85, 0.15, 0.15),
    "GREEN":             (0.15, 0.85, 0.15),
    "BLUE":              (0.25, 0.35, 0.95),
    "CYAN":              (0.30, 0.85, 0.95),
    "MAGENTA":           (0.85, 0.25, 0.85),
    "BROWN":             (0.60, 0.40, 0.20),
    "LIGHTGREY":         (0.75, 0.75, 0.78),
    "LIGHTGRAY":         (0.75, 0.75, 0.78),
    "DARKGREY":          (0.45, 0.45, 0.48),
    "DARKGRAY":          (0.45, 0.45, 0.48),
    "LIGHTBLUE":         (0.55, 0.70, 1.00),
    "LIGHTGREEN":        (0.45, 1.00, 0.55),
    "LIGHTCYAN":         (0.55, 0.95, 1.00),
    "LIGHTRED":          (1.00, 0.50, 0.45),
    "LIGHTMAGENTA":      (1.00, 0.55, 0.95),
    "YELLOW":            (1.00, 0.95, 0.45),
    # Element tints (view.h / colour.cc palette).
    "ETC_GOLD":          (1.00, 0.85, 0.30),
    "ETC_FIRE":          (1.00, 0.45, 0.20),
    "ETC_ICE":           (0.55, 0.85, 1.00),
    "ETC_ELECTRICITY":   (0.95, 0.95, 0.55),
    "ETC_NECRO":         (0.45, 0.25, 0.60),
    "ETC_HOLY":          (1.00, 0.95, 0.65),
    "ETC_DARK":          (0.20, 0.20, 0.25),
    "ETC_DEATH":         (0.35, 0.15, 0.20),
    "ETC_MUTAGENIC":     (0.75, 0.45, 0.95),
    "ETC_RANDOM":        (0.85, 0.85, 0.85),
    "ETC_POISON":        (0.25, 0.75, 0.35),
    "ETC_DIVINE":        (1.00, 1.00, 0.85),
    "ETC_FLASH":         (1.00, 1.00, 1.00),
    "ETC_AIR":           (0.80, 0.95, 1.00),
    "ETC_EARTH":         (0.60, 0.45, 0.25),
    "ETC_MAGIC":         (0.60, 0.45, 0.90),
    "ETC_BONE":          (0.95, 0.90, 0.75),
    "ETC_CRYSTAL":       (0.85, 0.55, 1.00),
    "ETC_DEVIL":         (0.85, 0.25, 0.15),
    "ETC_UNHOLY":        (0.45, 0.10, 0.20),
    # Extras observed while parsing art-data.txt:
    "ETC_BLOOD":         (0.75, 0.12, 0.15),
    "ETC_JEWEL":         (0.95, 0.55, 0.75),
    "ETC_FOUL_FLAME":    (0.55, 0.15, 0.35),
    "ETC_SLIME":         (0.55, 0.85, 0.20),
    "ETC_WATER":         (0.25, 0.55, 0.90),
    "ETC_SHIMMER_BLUE":  (0.55, 0.80, 1.00),
    "ETC_BEOGH":         (0.45, 0.65, 0.35),
    "ETC_SILVER":        (0.90, 0.90, 0.95),
    "ETC_ENCHANT":       (0.55, 0.70, 1.00),
    "ETC_MIST":          (0.75, 0.85, 0.90),
    "ETC_HEAL":          (0.55, 1.00, 0.75),
    "ETC_VEHUMET":       (0.65, 0.15, 0.75),
    "ETC_WARP":          (0.65, 0.35, 0.95),
    "ETC_IRON":          (0.55, 0.55, 0.60),
    "ETC_DITHMENOS":     (0.25, 0.22, 0.32),
    "ETC_DISJUNCTION":   (0.55, 0.25, 0.75),
    "ETC_INCARNADINE":   (0.80, 0.10, 0.25),
    "ETC_MOUNTAIN":      (0.60, 0.55, 0.45),
}

# Ring / amulet property field -> our canonical prop key.
PROP_MAP = {
    "STR":     "str",
    "DEX":     "dex",
    "INT":     "int_",
    "AC":      "ac",
    "EV":      "ev",
    "MP":      "mp_max",
    "HP":      "hp_max",
    "SLAY":    "dmg_bonus",
    "STEALTH": "stealth",
    "REGEN":   "regen",
    "SEEINV":  "see_invis",
    "FIRE":    "fire_apt",
    "COLD":    "cold_apt",
    "LIFE":    "neg_apt",
    "WILL":    "willpower",
    "ELEC":    "elec_apt",
    "POISON":  "poison_apt",
    "RCORR":   "corr_apt",
    "RMUT":    "mut_apt",
    "SH":      "sh",
}

# Base-tier min_depth table.
WEAPON_DEPTH = {
    # Early
    "dagger": 4, "club": 4, "short_sword": 5, "whip": 5, "spear": 5, "slingshot": 4,
    "mace": 5, "hand_axe": 5, "falchion": 6, "rapier": 6,
    # Mid
    "flail": 7, "shortbow": 7, "quick_blade": 8, "quarterstaff": 7,
    "morningstar": 8, "trident": 8, "war_axe": 8, "long_sword": 8, "scimitar": 9,
    "longbow": 9, "halberd": 10, "broad_axe": 10, "crossbow": 10, "arbalest": 11,
    # Late
    "great_sword": 11, "great_mace": 11, "battleaxe": 11, "glaive": 11,
    "bardiche": 13,
}

ARMOUR_DEPTH = {
    "robe": 4, "animal_skin": 4, "leather_armour": 5, "cloak": 5, "hat": 4,
    "scarf": 5, "buckler": 5, "helmet": 6, "gloves": 6, "boots": 6, "barding": 6,
    "troll_leather_armour": 8, "ring_mail": 7, "scale_mail": 8,
    "kite_shield": 8, "tower_shield": 10, "orb": 9,
    "chain_mail": 10, "plate_armour": 12, "crystal_plate_armour": 14,
}

# Hardcoded overrides for legendaries / endgame pieces.
LEGEND_DEPTH = {
    "sceptre of torment": 16, "orb of dispater": 18, "sceptre of asmodeus": 18,
    "sword of cerebov": 18, "singing sword": 10, "wrath of trog": 12,
    "staff of olgreb": 12, "vampire's tooth": 12, "autumn katana": 12,
    "elemental staff": 12, "majin-bo": 13, "obsidian axe": 14, "dark maul": 13,
    "plutonium sword": 13, "axe of woe": 18, "lochaber axe": 14,
    "trishula \"condemnation\"": 14, "crown of eternal torment": 16,
    "storm queen's shield": 13, "kryia's mail coat": 12,
    "maxwell's patent armour": 14, "maxwell's thermic engine": 14,
    "demon trident \"rift\"": 13, "arc blade": 12, "storm bow": 10,
    "arbalest \"damnation\"": 13, "longbow \"zephyr\"": 11,
    "orange crystal plate armour": 14, "lear's hauberk": 12,
    "dragonskin cloak": 14, "scales of the dragon king": 14,
    "frozen axe \"frostbite\"": 13, "demon whip \"spellbinder\"": 12,
    "lajatang of order": 14, "great mace \"firestarter\"": 12,
    "sword of the dread knight": 13, "pair of quick blades \"gyre\" and \"gimble\"": 13,
    "consecrated labrys": 13,
}


def _min_depth_for(base_id: str, name: str, kind: str) -> int:
    """Derive a min_depth guess from base tier + name overrides.

    Rule:
      1. If the (lowercased) name is in LEGEND_DEPTH, use that.
      2. Else: look up base_id in WEAPON_DEPTH or ARMOUR_DEPTH.
      3. Else: default 6 for weapons/armour, 5 for jewellery.
    """
    lname = name.lower()
    if lname in LEGEND_DEPTH:
        return LEGEND_DEPTH[lname]
    if kind == "weapon":
        return WEAPON_DEPTH.get(base_id, 6)
    if kind == "armor":
        return ARMOUR_DEPTH.get(base_id, 6)
    return 5  # ring/amulet default


# ------------------------------------------------------------------ #
#  art-data.txt parser                                               #
# ------------------------------------------------------------------ #

class Entry:
    __slots__ = ("fields", "descrip", "dbrand", "bool_flags", "order")

    def __init__(self, order: int):
        self.order = order
        self.fields: dict[str, str] = {}
        self.descrip: list[str] = []
        self.dbrand:  list[str] = []
        self.bool_flags: set[str] = set()


def _parse_blocks(path: Path) -> list[Entry]:
    text = path.read_text(encoding="utf-8")
    # Strip comment lines and collapse to blocks split by blank lines.
    raw_lines = text.splitlines()
    lines: list[str] = []
    for ln in raw_lines:
        stripped = ln.lstrip()
        # Comment line (starts with # at col 0 or after whitespace only).
        if stripped.startswith("#"):
            continue
        lines.append(ln)

    blocks: list[list[str]] = []
    cur: list[str] = []
    for ln in lines:
        if not ln.strip():
            if cur:
                blocks.append(cur)
                cur = []
            continue
        cur.append(ln)
    if cur:
        blocks.append(cur)

    entries: list[Entry] = []
    for idx, block in enumerate(blocks):
        ent = Entry(order=idx)
        last_multi: list[str] | None = None
        last_key: str | None = None
        for ln in block:
            # Continuation: starts with space and previous line was a
            # multi-line field (DESCRIP/DBRAND).
            if ln.startswith(" ") and last_multi is not None:
                last_multi.append(ln.strip())
                continue
            m = re.match(r"^([A-Z_]+):\s*(.*)$", ln)
            if not m:
                # "+Foo: ..." continuations for DESCRIP/DBRAND
                if ln.startswith("+") and last_key in ("DESCRIP", "DBRAND"):
                    if last_key == "DESCRIP":
                        ent.descrip.append(ln[1:].strip())
                        last_multi = ent.descrip
                    else:
                        ent.dbrand.append(ln[1:].strip())
                        last_multi = ent.dbrand
                continue
            key, val = m.group(1), m.group(2).strip()
            last_key = key
            if key == "DESCRIP":
                ent.descrip.append(val)
                last_multi = ent.descrip
            elif key == "DBRAND":
                ent.dbrand.append(val)
                last_multi = ent.dbrand
            elif key == "BOOL":
                last_multi = None
                for tok in val.split(","):
                    t = tok.strip()
                    if t:
                        ent.bool_flags.add(t)
            else:
                last_multi = None
                ent.fields[key] = val
        if "NAME" in ent.fields and "OBJ" in ent.fields:
            entries.append(ent)
    return entries


# ------------------------------------------------------------------ #
#  Transform to our schema                                           #
# ------------------------------------------------------------------ #

def _id_from_name(name: str) -> str:
    """Derive the unrand_* id from the DCSS NAME, matching the
    existing UnrandartRegistry naming convention.

    Rules, in order:
      1. Quoted nickname inside the name ("Bloodbane") -> unrand_bloodbane.
      2. " of " in the name  -> take the trailing part.
      3. Otherwise the full name.
    """
    q = re.search(r'"([^"]+)"', name)
    if q:
        stem = q.group(1)
    elif " of " in name.lower():
        # keep everything after the first " of "
        parts = re.split(r" of ", name, maxsplit=1, flags=re.IGNORECASE)
        stem = parts[1] if len(parts) > 1 else name
    else:
        stem = name
    stem = stem.lower()
    stem = stem.replace("'", "")
    stem = re.sub(r'[^a-z0-9]+', "_", stem).strip("_")
    return "unrand_" + stem


def _parse_plus(val: str) -> int:
    v = val.strip()
    if v.startswith("+"):
        v = v[1:]
    try:
        return int(v)
    except ValueError:
        return 0


def _obj_base(obj: str) -> tuple[str, str]:
    """Return (base_enum, base_id) or (enum, '') if unmapped.

    `enum` is the raw WPN_* / ARM_* / RING_* / AMU_* token, `base_id`
    is our registry id (or "" if unmapped).
    """
    parts = obj.split("/")
    if len(parts) != 2:
        return ("", "")
    enum = parts[1].strip()
    return (enum, OBJ_TYPE_MAP.get(enum, ""))


def _kind_from_obj(obj: str) -> str:
    if obj.startswith("OBJ_WEAPONS"):
        return "weapon"
    if obj.startswith("OBJ_ARMOUR"):
        return "armor"
    if obj.startswith("OBJ_JEWELLERY"):
        # refine by second half
        enum = obj.split("/")[-1]
        if enum.startswith("RING_"):
            return "ring"
        return "amulet"
    return ""


def _slot_for_armour(base_id: str) -> str:
    SLOT = {
        "robe": "chest", "animal_skin": "chest", "leather_armour": "chest",
        "troll_leather_armour": "chest", "ring_mail": "chest", "scale_mail": "chest",
        "chain_mail": "chest", "plate_armour": "chest", "crystal_plate_armour": "chest",
        "cloak": "cloak", "scarf": "cloak",
        "gloves": "gloves", "boots": "boots", "barding": "boots",
        "hat": "helm", "helmet": "helm",
        "buckler": "shield", "kite_shield": "shield", "tower_shield": "shield",
        "orb": "offhand",
    }
    return SLOT.get(base_id, "chest")


def _combine_desc(ent: Entry) -> str:
    parts: list[str] = []
    if ent.descrip:
        parts.append(" ".join(ent.descrip))
    if ent.dbrand:
        parts.append(" ".join(ent.dbrand))
    text = " ".join(parts)
    # collapse whitespace
    text = re.sub(r"\s+", " ", text).strip()
    return text


def _extract_props(ent: Entry) -> dict[str, int]:
    props: dict[str, int] = {}
    for dcss_key, our_key in PROP_MAP.items():
        if dcss_key in ent.fields:
            v = _parse_plus(ent.fields[dcss_key])
            if v != 0:
                props[our_key] = v
    # BOOL flag flavours that map onto props/flags
    if "seeinv" in ent.bool_flags:
        props["see_invis"] = 1
    if "fly" in ent.bool_flags:
        props.setdefault("flying", 1)
    if "rmsl" in ent.bool_flags:
        props.setdefault("missile_dodge", 1)
    if "clarity" in ent.bool_flags:
        props.setdefault("clarity", 1)
    return props


# ------------------------------------------------------------------ #
#  Emission                                                          #
# ------------------------------------------------------------------ #

def _color_literal(colour: str) -> str:
    rgb = COLOUR_MAP.get(colour)
    if rgb is None:
        return "Color(0.85, 0.85, 0.85)"  # fallback neutral
    return "Color(%.2f, %.2f, %.2f)" % rgb


def _quote(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def _emit_weapon(uid: str, ent: Entry, base_id: str) -> str:
    name = ent.fields["NAME"]
    plus = _parse_plus(ent.fields.get("PLUS", "0"))
    brand_enum = ent.fields.get("BRAND", "")
    brand = BRAND_MAP.get(brand_enum, "")
    # dmg / delay / skill come from WeaponRegistry at lookup time, but
    # we record the nominal base values so tooltips look right before
    # the registry is loaded.
    WPN_STATS = {
        "club":(5,"mace",1.3),"whip":(6,"mace",1.1),"mace":(8,"mace",1.4),
        "flail":(10,"mace",1.4),"morningstar":(13,"mace",1.5),
        "great_mace":(17,"mace",1.7),
        "dagger":(4,"short_blade",1.0),"quick_blade":(4,"short_blade",1.5),
        "short_sword":(5,"short_blade",1.0),"rapier":(7,"short_blade",1.2),
        "falchion":(8,"long_blade",1.3),"long_sword":(10,"long_blade",1.4),
        "scimitar":(12,"long_blade",1.4),"great_sword":(17,"long_blade",1.7),
        "hand_axe":(7,"axe",1.3),"war_axe":(11,"axe",1.5),"broad_axe":(13,"axe",1.6),
        "battleaxe":(15,"axe",1.7),
        "spear":(6,"polearm",1.1),"trident":(9,"polearm",1.3),
        "halberd":(13,"polearm",1.5),"glaive":(15,"polearm",1.7),
        "bardiche":(18,"polearm",1.9),
        "quarterstaff":(10,"staff",1.3),
        "slingshot":(7,"bow",1.4),"shortbow":(8,"bow",1.4),
        "longbow":(14,"bow",1.7),"arbalest":(16,"bow",1.9),"crossbow":(16,"bow",1.9),
    }
    dmg, skill, delay = WPN_STATS.get(base_id, (8, "short_blade", 1.3))
    desc = _combine_desc(ent)
    colour = ent.fields.get("COLOUR", "WHITE")
    depth = _min_depth_for(base_id, name, "weapon")

    lines: list[str] = []
    lines.append(f'\t{_quote(uid)}: {{')
    lines.append(f'\t\t"kind": "weapon",')
    lines.append(f'\t\t"base": {_quote(base_id)},')
    lines.append(f'\t\t"name": {_quote("the " + name if not name[0].isupper() or " " in name else name)},')
    lines.append(f'\t\t"dmg": {dmg}, "skill": {_quote(skill)}, "delay": {delay},')
    pline = []
    if plus != 0:
        pline.append(f'"plus": {plus}')
    if brand:
        pline.append(f'"brand": {_quote(brand)}')
    if pline:
        lines.append('\t\t' + ', '.join(pline) + ',')
    lines.append(f'\t\t"color": {_color_literal(colour)},')
    lines.append(f'\t\t"min_depth": {depth},')
    if desc:
        lines.append(f'\t\t"desc": {_quote(desc)},')
    lines.append('\t},')
    return "\n".join(lines)


def _emit_armor(uid: str, ent: Entry, base_id: str) -> str:
    name = ent.fields["NAME"]
    slot = _slot_for_armour(base_id)
    # AC: body armour bases define their own AC via ArmorRegistry JSON;
    # unrand AC field is a bonus. We carry PLUS as enchant bonus and AC
    # from PLUS/AC as a gentle base guess for tooltips.
    plus = _parse_plus(ent.fields.get("PLUS", "0"))
    ac_bonus = _parse_plus(ent.fields.get("AC", "0"))
    brand_enum = ent.fields.get("BRAND", "")
    ego = EGO_MAP.get(brand_enum, "")
    desc = _combine_desc(ent)
    colour = ent.fields.get("COLOUR", "WHITE")
    depth = _min_depth_for(base_id, name, "armor")

    # AC value: we report the PLUS (armour enchant) as `plus`; give a
    # rough ac baseline from the base-tier table for tooltips.
    AC_BASE = {
        "robe": 2, "animal_skin": 2, "leather_armour": 3, "troll_leather_armour": 4,
        "ring_mail": 5, "scale_mail": 6, "chain_mail": 7, "plate_armour": 10,
        "crystal_plate_armour": 14, "cloak": 1, "scarf": 0, "hat": 1, "helmet": 2,
        "gloves": 1, "boots": 1, "barding": 4, "buckler": 3, "kite_shield": 8,
        "tower_shield": 13, "orb": 0,
    }
    ac = AC_BASE.get(base_id, 2) + max(0, ac_bonus)

    lines: list[str] = []
    display_name = ("the " + name) if name[:1].islower() else name
    lines.append(f'\t{_quote(uid)}: {{')
    lines.append(f'\t\t"kind": "armor",')
    lines.append(f'\t\t"base": {_quote(base_id)},')
    lines.append(f'\t\t"name": {_quote(display_name)},')
    lines.append(f'\t\t"slot": {_quote(slot)},')
    lines.append(f'\t\t"ac": {ac}, "plus": {plus},')
    if ego:
        lines.append(f'\t\t"ego": {_quote(ego)},')
    lines.append(f'\t\t"color": {_color_literal(colour)},')
    lines.append(f'\t\t"min_depth": {depth},')
    if desc:
        lines.append(f'\t\t"desc": {_quote(desc)},')
    lines.append('\t},')
    return "\n".join(lines)


def _emit_jewel(uid: str, ent: Entry, kind: str) -> str:
    name = ent.fields["NAME"]
    colour = ent.fields.get("COLOUR", "WHITE")
    props = _extract_props(ent)
    desc = _combine_desc(ent)
    depth = _min_depth_for("", name, kind)
    # Include the OBJ-base for amulets when a sensible base id exists,
    # so equip code can fall back to the generic amulet row.
    enum, _ = _obj_base(ent.fields["OBJ"])
    amulet_base = ""
    if kind == "amulet":
        AMU = {
            "AMU_FAITH": "amulet_faith",
            "AMU_ACROBAT": "amulet_acrobat",
            "AMU_GUARDIAN_SPIRIT": "amulet_guardian_spirit",
            "AMU_NOTHING": "amulet_nothing",
        }
        amulet_base = AMU.get(enum, "")
    display_name = ("the " + name) if name[:1].islower() else name

    lines: list[str] = []
    lines.append(f'\t{_quote(uid)}: {{')
    lines.append(f'\t\t"kind": {_quote(kind)},')
    lines.append(f'\t\t"name": {_quote(display_name)},')
    # Serialize props dict.
    if props:
        prop_items = ", ".join(f'"{k}": {v}' for k, v in props.items())
        lines.append(f'\t\t"props": {{{prop_items}}},')
    else:
        lines.append(f'\t\t"props": {{}},')
    lines.append(f'\t\t"color": {_color_literal(colour)},')
    lines.append(f'\t\t"min_depth": {depth},')
    if amulet_base:
        lines.append(f'\t\t"base": {_quote(amulet_base)},')
    if desc:
        lines.append(f'\t\t"desc": {_quote(desc)},')
    lines.append('\t},')
    return "\n".join(lines)


# ------------------------------------------------------------------ #
#  Main                                                              #
# ------------------------------------------------------------------ #

def main() -> int:
    if not ART_DATA.exists():
        print(f"art-data.txt not found: {ART_DATA}", file=sys.stderr)
        return 2

    entries = _parse_blocks(ART_DATA)

    parsed = 0
    skipped: list[str] = []
    missing_base: list[str] = []
    unknown_colours: dict[str, int] = {}
    unknown_brands:  dict[str, int] = {}
    unknown_egos:    dict[str, int] = {}

    gd_chunks: list[str] = []
    json_entries: list[dict] = []

    seen_ids: set[str] = set()
    for ent in entries:
        name = ent.fields.get("NAME", "")
        if name.startswith("DUMMY UNRANDART"):
            skipped.append(f"{name}: sentinel")
            continue
        if "nogen" in ent.bool_flags:
            skipped.append(f"{name}: nogen")
            continue
        if "deleted" in ent.bool_flags:
            skipped.append(f"{name}: deleted")
            continue
        obj = ent.fields.get("OBJ", "")
        kind = _kind_from_obj(obj)
        if not kind:
            skipped.append(f"{name}: unknown obj {obj}")
            continue
        enum, base_id = _obj_base(obj)
        if kind in ("weapon", "armor") and not base_id:
            missing_base.append(f"{name}: OBJ {enum} not in OBJ_TYPE_MAP")
            continue
        uid = _id_from_name(name)
        # disambiguate collisions: prefix with the kind so ring/weapon
        # collisions (e.g. trident vs ring "of the Octopus King") stay
        # human-readable.
        if uid in seen_ids:
            uid = f"unrand_{kind}_" + uid[len("unrand_"):]
        if uid in seen_ids:
            uid = f"{uid}_{ent.order}"
        seen_ids.add(uid)

        colour = ent.fields.get("COLOUR", "WHITE")
        if colour not in COLOUR_MAP:
            unknown_colours[colour] = unknown_colours.get(colour, 0) + 1
        brand_enum = ent.fields.get("BRAND", "")
        if brand_enum and kind == "weapon" and brand_enum not in BRAND_MAP:
            unknown_brands[brand_enum] = unknown_brands.get(brand_enum, 0) + 1
        if brand_enum and kind == "armor" and brand_enum not in EGO_MAP:
            unknown_egos[brand_enum] = unknown_egos.get(brand_enum, 0) + 1

        if kind == "weapon":
            gd_chunks.append(_emit_weapon(uid, ent, base_id))
        elif kind == "armor":
            gd_chunks.append(_emit_armor(uid, ent, base_id))
        else:
            gd_chunks.append(_emit_jewel(uid, ent, kind))

        # JSON cache
        json_entries.append({
            "id": uid,
            "kind": kind,
            "base": base_id,
            "name": name,
            "obj": obj,
            "plus": _parse_plus(ent.fields.get("PLUS", "0")),
            "brand_enum": brand_enum,
            "colour_enum": colour,
            "bool": sorted(ent.bool_flags),
            "descrip": " ".join(ent.descrip),
            "dbrand":  " ".join(ent.dbrand),
        })
        parsed += 1

    # ------- write outputs -------
    OUT_GD.parent.mkdir(parents=True, exist_ok=True)
    OUT_JSON.parent.mkdir(parents=True, exist_ok=True)

    gd_text = "\n".join(gd_chunks) + "\n"
    OUT_GD.write_text(gd_text, encoding="utf-8")

    OUT_JSON.write_text(
        json.dumps(json_entries, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    # ------- report -------
    print(f"Parsed {parsed} unrandarts from {ART_DATA}")
    print(f"Skipped {len(skipped)} entries:")
    for s in skipped:
        print(f"  - {s}")
    if missing_base:
        print(f"WARNING: {len(missing_base)} entries had unmapped OBJ bases (skipped):")
        for m in missing_base:
            print(f"  - {m}")
    if unknown_colours:
        print("Unknown COLOUR tokens:")
        for k, v in sorted(unknown_colours.items()):
            print(f"  - {k} ({v})")
    if unknown_brands:
        print("Unknown SPWPN_* brands:")
        for k, v in sorted(unknown_brands.items()):
            print(f"  - {k} ({v})")
    if unknown_egos:
        print("Unknown SPARM_* egos:")
        for k, v in sorted(unknown_egos.items()):
            print(f"  - {k} ({v})")
    print(f"GD snippet:  {OUT_GD}  ({len(gd_text.splitlines())} lines)")
    print(f"JSON cache:  {OUT_JSON}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
