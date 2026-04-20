#!/usr/bin/env python3
"""Parse DCSS art-data.txt → assets/dcss_items/unique_items.json

Each unrandart block: NAME, OBJ, PLUS, COLOUR, BRAND, PROP, BOOL, VALUE, DESCRIP.
"""
import re, json
from pathlib import Path

SRC = Path(__file__).parent.parent / "crawl/crawl-ref/source/art-data.txt"
OUT = Path(__file__).parent.parent / "assets/dcss_items/unique_items.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

# Weapon type enum → our id
WPN_MAP = {
    "WPN_DOUBLE_SWORD": "double_sword", "WPN_BATTLEAXE": "battleaxe",
    "WPN_EXECUTIONERS_AXE": "executioners_axe", "WPN_GREAT_MACE": "morningstar",
    "WPN_GREAT_SWORD": "great_sword", "WPN_LONG_SWORD": "long_sword",
    "WPN_BROAD_AXE": "broad_axe", "WPN_WAR_AXE": "war_axe",
    "WPN_HAND_AXE": "hand_axe", "WPN_DAGGER": "dagger",
    "WPN_SHORT_SWORD": "short_sword", "WPN_RAPIER": "rapier",
    "WPN_QUARTERSTAFF": "quarterstaff", "WPN_LAJATANG": "lajatang",
    "WPN_HALBERD": "halberd", "WPN_GLAIVE": "glaive",
    "WPN_BARDICHE": "bardiche", "WPN_TRIDENT": "trident",
    "WPN_SPEAR": "spear", "WPN_MORNINGSTAR": "morningstar",
    "WPN_FLAIL": "flail", "WPN_DIRE_FLAIL": "dire_flail",
    "WPN_EVENINGSTAR": "eveningstar", "WPN_MACE": "mace",
    "WPN_CLUB": "club", "WPN_WHIP": "whip",
    "WPN_DEMON_BLADE": "demon_blade", "WPN_TRIPLE_SWORD": "triple_sword",
    "WPN_QUICK_BLADE": "quick_blade", "WPN_SCIMITAR": "scimitar",
    "WPN_FALCHION": "falchion", "WPN_PARTISAN": "glaive",
    "OBJ_RANDOM": "unknown",
}
ARMOUR_MAP = {
    "ARM_ROBE": "robe", "ARM_LEATHER_ARMOUR": "leather_armour",
    "ARM_RING_MAIL": "ring_mail", "ARM_SCALE_MAIL": "scale_mail",
    "ARM_CHAIN_MAIL": "chain_mail", "ARM_PLATE_ARMOUR": "plate_armour",
    "ARM_CRYSTAL_PLATE_ARMOUR": "crystal_plate_armour",
    "ARM_CLOAK": "cloak", "ARM_HAT": "hat", "ARM_HELMET": "helmet",
    "ARM_GLOVES": "gloves", "ARM_BOOTS": "boots",
    "ARM_BUCKLER": "buckler", "ARM_KITE_SHIELD": "kite_shield",
    "ARM_TOWER_SHIELD": "tower_shield",
    "ARM_TROLL_LEATHER_ARMOUR": "troll_leather_armour",
}
BRAND_MAP = {
    "SPWPN_FLAMING": "flaming", "SPWPN_FREEZING": "freezing",
    "SPWPN_HOLY_WRATH": "holy_wrath", "SPWPN_ELECTROCUTION": "electrocution",
    "SPWPN_VENOM": "venom", "SPWPN_PROTECTION": "protection",
    "SPWPN_DRAINING": "draining", "SPWPN_SPEED": "speed",
    "SPWPN_HEAVY": "heavy", "SPWPN_VAMPIRISM": "vampirism",
    "SPWPN_PAIN": "pain", "SPWPN_ANTIMAGIC": "antimagic",
    "SPWPN_DISTORTION": "distortion", "SPWPN_CHAOS": "chaos",
    "SPWPN_PENETRATION": "penetration", "SPWPN_REAPING": "reaping",
    "SPWPN_VORPAL": "vorpal", "SPWPN_NORMAL": "normal",
}

text = SRC.read_text(encoding="utf-8")
# Split on blank lines to get blocks
raw_blocks = re.split(r'\n\n+', text)

items = []
for block in raw_blocks:
    if "NAME:" not in block:
        continue
    name_m = re.search(r'^NAME:\s+(.+)', block, re.MULTILINE)
    if not name_m:
        continue
    name = name_m.group(1).strip()
    if "DUMMY" in name:
        continue

    obj_m  = re.search(r'^OBJ:\s+(\S+)/(\S+)', block, re.MULTILINE)
    plus_m = re.search(r'^PLUS:\s+([+\-]?\d+)', block, re.MULTILINE)
    val_m  = re.search(r'^VALUE:\s+(\d+)', block, re.MULTILINE)
    brand_m= re.search(r'^BRAND:\s+(\w+)', block, re.MULTILINE)
    desc_m = re.search(r'^DESCRIP:\s+(.+?)(?=\n[A-Z+]|\Z)', block, re.MULTILINE | re.DOTALL)
    # props (PROP lines)
    props = re.findall(r'^PROP:\s+(.+)', block, re.MULTILINE)
    bools = []
    bool_m = re.search(r'^BOOL:\s+(.+)', block, re.MULTILINE)
    if bool_m:
        bools = [b.strip() for b in bool_m.group(1).split(",")]

    obj_type = obj_m.group(1) if obj_m else ""
    obj_sub  = obj_m.group(2) if obj_m else ""

    # Determine item category and base id
    category = "unknown"
    base_id  = "unknown"
    if obj_type == "OBJ_WEAPONS":
        category = "weapon"
        base_id  = WPN_MAP.get(obj_sub, obj_sub.replace("WPN_", "").lower())
    elif obj_type == "OBJ_ARMOUR":
        category = "armour"
        base_id  = ARMOUR_MAP.get(obj_sub, obj_sub.replace("ARM_", "").lower())
    elif obj_type == "OBJ_JEWELLERY":
        category = "jewellery"
        base_id  = obj_sub.replace("RING_", "ring_").replace("AMU_", "amulet_").lower()
    elif obj_type == "OBJ_WEAPONS" and obj_sub == "OBJ_RANDOM":
        category = "weapon"
        base_id  = "unknown"

    slug = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")

    item = {
        "id":       slug,
        "name":     name,
        "category": category,
        "base":     base_id,
        "plus":     int(plus_m.group(1)) if plus_m else 0,
        "value":    int(val_m.group(1)) if val_m else 0,
        "brand":    BRAND_MAP.get(brand_m.group(1), brand_m.group(1).lower()) if brand_m else "",
        "props":    props,
        "bools":    bools,
        "desc":     desc_m.group(1).strip().replace("\n ", " ") if desc_m else "",
    }
    items.append(item)

output = {
    "_comment": "DCSS unrandart data from art-data.txt (0.32). 143 unique items.",
    "items": items,
    "by_id": {i["id"]: i for i in items},
}

OUT.write_text(json.dumps(output, indent=2, ensure_ascii=False))
print(f"Wrote {len(items)} unique items → {OUT.relative_to(Path.cwd())}")
for item in items[:5]:
    print(f"  {item['id']:35s} base={item['base']:20s} +{item['plus']} brand={item['brand']}")
