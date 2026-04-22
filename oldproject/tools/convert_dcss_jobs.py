#!/usr/bin/env python3
"""Convert DCSS background YAMLs → resources/jobs/*.tres.

Reads crawl-ref/source/dat/jobs/*.yaml, maps item/skill/spell names to our
in-game ids, and regenerates JobData .tres files. Non-DCSS job .tres files
(warlock, cleric, etc.) are deleted.

Hand-written `description` strings in existing .tres files are preserved
(DCSS YAMLs don't carry flavour text).

Run from project root:
    python3 tools/convert_dcss_jobs.py
"""

import json
import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

ROOT = Path("/mnt/d/PROJ_D")
YAML_DIR = ROOT / "crawl/crawl-ref/source/dat/jobs"
OUT_DIR = ROOT / "resources/jobs"

# DCSS equipment string → our id. Values of None → drop silently.
# Values of "?" → warn and fall back to FALLBACK_*.
ITEM_MAP = {
    # Armours
    "robe": "robe",
    "leather armour": "leather_armour",
    "scale mail": "scale_mail",
    "chain mail": "chain_mail",
    "plate armour": "plate_armour",
    "ring mail": "ring_mail",
    "animal skin": "animal_skin",
    "cloak": "cloak",
    "hat": "hat",
    "helmet": "helmet",
    "buckler": "buckler",
    "kite shield": "kite_shield",
    "orb": "orb",
    # Weapons
    "dagger": "dagger",
    "club": "club",
    "mace": "mace",  # forgewright's hammer is a mace variant
    "short sword": "short_sword",
    "rapier": "rapier",
    "shortbow": "short_bow",
    "sling": "slingshot",
    # Consumables with direct matches
    "potion of magic": "potion_magic",
    "potion of might": "potion_might",
    "potion of haste": "potion_haste",
    "potion of curing": "potion_curing",
    "potion of resistance": "potion_resistance",
    "potion of agility": "potion_agility",
    "potion of brilliance": "potion_brilliance",
    "scroll of fear": "scroll_fear",
    "scroll of fog": "scroll_fog",
    "scroll of blinking": "scroll_blink",
    "scroll of teleportation": "scroll_teleport",
    "scroll of magic mapping": "scroll_magic_map",
    "scroll of revelation": "scroll_magic_map",
    "scroll of identify": "scroll_identify",
    "scroll of remove curse": "scroll_remove_curse",
    "scroll of enchant armour": "scroll_enchant_armor",
    "scroll of enchant weapon": "scroll_enchant_weapon",
    "scroll of immolation": "scroll_immolation",
    "scroll of holy word": "scroll_holy_word",
    "scroll of vulnerability": "scroll_vulnerability",
    "scroll of acquirement": "scroll_acquirement",
    # Fallback substitutions (DCSS item → closest we have)
    "potion of invisibility": "potion_haste",
    "potion of ambrosia": "potion_curing",
    "potion of lignification": "potion_resistance",
    # Wands collapse to the one we have
    "wand of flame": "wand_simple",
    "wand of charming": "wand_simple",
    "wand of iceblast": "wand_simple",
    "wand of digging": "wand_simple",
    "wand of random effects": "wand_simple",
    # Talismans (new): map to our per-form talisman ids.
    "quill talisman": "talisman_quill",
    "protean talisman": "talisman_protean",
    # Still-unmodelled bits — drop silently.
    "scroll of butterflies": "scroll_butterflies",
    "scroll of poison": "scroll_poison",
    "throwing net": None,
    "dart": None,
    "flux bauble": None,
}

# DCSS skill name → our SkillSystem skill id. None → drop.
# "weapon" is a placeholder — handled in map_skills via weapon_skill arg.
SKILL_MAP = {
    "fighting": "fighting",
    "armour": "armour",
    "dodging": "dodging",
    "shields": "shields",
    "stealth": "stealth",
    "spellcasting": "spellcasting",
    "conjurations": "conjurations",
    "hexes": "hexes",
    "summonings": "summonings",
    "necromancy": "necromancy",
    "translocations": "translocations",
    "fire magic": "fire",
    "ice magic": "cold",
    "earth magic": "earth",
    "air magic": "air",
    "throwing": "throwing",
    "evocations": "evocations",
    # Skills we don't model — drop or approximate
    "alchemy": None,
    "forgecraft": None,
    "shapeshifting": None,
    "unarmed combat": "fighting",
}

# Our weapon id → SkillSystem weapon skill id. Mirrors
# scripts/systems/SkillSystem.gd WEAPON_SKILL.
WEAPON_TO_SKILL = {
    "dagger": "short_blade",
    "short_sword": "short_blade",
    "rapier": "short_blade",
    "club": "mace",
    "mace": "mace",
    "short_bow": "bow",
    "slingshot": "sling",
}

# DCSS `weapon_choice: plain` / `weapon_choice: good` backgrounds don't ship
# with a weapon in their YAML — DCSS asks the player at new-game time. We
# don't have that UI yet, so give each a sensible default that trains one
# of the weapon skills. TODO: expose player weapon choice at char-creation.
DEFAULT_WEAPON_FOR_JOB = {
    "fighter": "mace",
    "gladiator": "mace",
    "berserker": "mace",
    "monk": "mace",
    "chaos_knight": "mace",
    "cinder_acolyte": "mace",
    "delver": "dagger",
    "reaver": "mace",
    "warper": "dagger",
    "shapeshifter": "dagger",  # unarmed-focused; dagger for basic defense
}


def clean_item_token(raw: str) -> str:
    """Strip DCSS modifiers ('dagger plus:2 ego:flaming' → 'dagger').

    Also strip tile/wtile/itemname overrides used only for visual reskins.
    """
    s = raw.strip()
    # Drop any "key:value" suffix tokens
    s = re.sub(r"\s+\S+:\S+", "", s)
    s = re.sub(r"\s+no_exclude\b", "", s)
    return s.strip().lower()


def map_equipment(dcss_items: list) -> tuple[list, list]:
    """Return (our_ids, warnings) with unknown items logged."""
    out = []
    warn = []
    for raw in dcss_items:
        if not isinstance(raw, str):
            continue
        clean = clean_item_token(raw)
        if clean not in ITEM_MAP:
            warn.append(f"UNKNOWN item '{raw}' (cleaned: '{clean}')")
            continue
        mapped = ITEM_MAP[clean]
        if mapped is None:
            continue
        out.append(mapped)
    return out, warn


def map_skills(dcss_skills: dict, weapon_skill: str) -> tuple[dict, list]:
    """Translate DCSS skill names → our skill ids.

    `weapon_skill` is the skill id to use for the placeholder `weapon: N`
    entry (e.g. "short_blade" for dagger-starting jobs).
    """
    out = {}
    warn = []
    for k, v in (dcss_skills or {}).items():
        key = str(k).lower().strip()
        if key == "weapon":
            mapped = weapon_skill
        else:
            mapped = SKILL_MAP.get(key, "__missing__")
        if mapped == "__missing__":
            warn.append(f"UNKNOWN skill '{k}'")
            continue
        if mapped is None:
            continue
        # Accumulate in case two DCSS skills both map to our skill (e.g.
        # "unarmed combat" + "fighting" → "fighting").
        out[mapped] = out.get(mapped, 0) + int(v)
    return out, warn


def determine_weapon_skill(equipment: list) -> str:
    """Pick the weapon skill matching the first weapon in equipment.

    Falls back to "fighting" if no weapon is present (shouldn't happen once
    DEFAULT_WEAPON_FOR_JOB has injected one).
    """
    for eid in equipment:
        if eid in WEAPON_TO_SKILL:
            return WEAPON_TO_SKILL[eid]
    return "fighting"


def map_spells(dcss_spells: list) -> list:
    """SPELL_STONE_ARROW → stone_arrow."""
    out = []
    for s in dcss_spells or []:
        name = str(s)
        if not name.startswith("SPELL_"):
            continue
        out.append(name[len("SPELL_"):].lower())
    return out


def job_id_from_filename(path: Path) -> str:
    return path.stem.replace("-", "_")


def existing_description(tres_path: Path) -> str:
    """Preserve hand-written description from old .tres if present."""
    if not tres_path.is_file():
        return ""
    try:
        for line in tres_path.read_text(encoding="utf-8").splitlines():
            m = re.match(r'^description\s*=\s*"(.*)"\s*$', line)
            if m:
                return m.group(1)
    except OSError:
        pass
    return ""


def gd_string_array(vals: list) -> str:
    if not vals:
        return "Array[String]([])"
    quoted = ", ".join(f'"{v}"' for v in vals)
    return f"Array[String]([{quoted}])"


def gd_skills_dict(skills: dict) -> str:
    if not skills:
        return "{}"
    pairs = ", ".join(f'"{k}": {v}' for k, v in sorted(skills.items()))
    return "{" + pairs + "}"


def write_tres(jid: str, name: str, desc: str, str_b: int, int_b: int, dex_b: int,
               equip: list, skills: dict, spells: list) -> str:
    return (
        '[gd_resource type="Resource" script_class="JobData" load_steps=2 format=3]\n\n'
        '[ext_resource type="Script" path="res://resources/jobs/JobData.gd" id="1"]\n\n'
        '[resource]\n'
        'script = ExtResource("1")\n'
        f'id = "{jid}"\n'
        f'display_name = "{name}"\n'
        f'description = "{desc}"\n'
        f'str_bonus = {str_b}\n'
        f'dex_bonus = {dex_b}\n'
        f'int_bonus = {int_b}\n'
        f'starting_equipment = {gd_string_array(equip)}\n'
        f'starting_skills = {gd_skills_dict(skills)}\n'
        f'starting_spells = {gd_string_array(spells)}\n'
        'unique_ability = ""\n'
    )


def main() -> int:
    if not YAML_DIR.is_dir():
        print(f"ERROR: missing {YAML_DIR}", file=sys.stderr)
        return 1
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    dcss_job_ids: set = set()
    all_warnings: dict = {}

    for ypath in sorted(YAML_DIR.glob("*.yaml")):
        with open(ypath, "r", encoding="utf-8") as f:
            data = yaml.safe_load(f) or {}

        jid = job_id_from_filename(ypath)
        dcss_job_ids.add(jid)

        # Wanderer's YAML is intentionally blank (DCSS randomises everything
        # in ng-wanderer.cc at char-creation time). We can't port that yet,
        # so preserve our hand-tuned baseline kit rather than overwriting.
        if jid == "wanderer":
            continue

        # DCSS uses flat ints for str/int/dex offsets from species base.
        str_b = int(data.get("str", 0))
        int_b = int(data.get("int", 0))
        dex_b = int(data.get("dex", 0))

        name = str(data.get("name", jid))
        equip, w1 = map_equipment(data.get("equipment", []))
        # Inject a default weapon for `weapon_choice: plain/good` jobs that
        # don't ship with one in their YAML.
        default_wpn = DEFAULT_WEAPON_FOR_JOB.get(jid)
        if default_wpn and default_wpn not in equip:
            # Put the weapon first so it's the "primary" gear in the UI.
            equip = [default_wpn] + equip
        weapon_skill = determine_weapon_skill(equip)
        skills, w2 = map_skills(data.get("skills", {}), weapon_skill)
        spells = map_spells(data.get("spells", []))

        warnings = w1 + w2
        if warnings:
            all_warnings[jid] = warnings

        tres_path = OUT_DIR / f"{jid}.tres"
        desc = existing_description(tres_path)
        # Wanderer has randomised stats/equipment in DCSS — give it a clear note.
        if jid == "wanderer" and not desc:
            desc = "Randomised starting gear and skills."

        tres_path.write_text(
            write_tres(jid, name, desc, str_b, int_b, dex_b, equip, skills, spells),
            encoding="utf-8",
        )
        print(f"wrote {tres_path.name}")

    # Delete non-DCSS .tres files.
    removed = []
    for tres in sorted(OUT_DIR.glob("*.tres")):
        if tres.stem not in dcss_job_ids:
            tres.unlink()
            # Also nuke the .uid sidecar if present.
            uid = tres.with_suffix(".tres.uid")
            if uid.exists():
                uid.unlink()
            removed.append(tres.stem)

    print(f"\n--- Converted {len(dcss_job_ids)} DCSS jobs ---")
    if removed:
        print(f"Removed {len(removed)} non-DCSS jobs: {', '.join(removed)}")

    if all_warnings:
        print("\n--- Mapping warnings ---")
        for jid, ws in sorted(all_warnings.items()):
            for w in ws:
                print(f"  [{jid}] {w}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
