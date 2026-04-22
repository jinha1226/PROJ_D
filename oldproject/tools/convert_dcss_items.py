#!/usr/bin/env python3
"""Parse DCSS item-prop.cc → assets/dcss_items/weapons.json + armours.json"""
import re, json, sys
from pathlib import Path

SRC = Path(__file__).parent.parent / "crawl/crawl-ref/source/item-prop.cc"
OUT_DIR = Path(__file__).parent.parent / "assets/dcss_items"
OUT_DIR.mkdir(parents=True, exist_ok=True)

text = SRC.read_text(encoding="utf-8")

# ── Skill mapping ─────────────────────────────────────────────────────────────
SKILL_MAP = {
    "SK_SHORT_BLADES":   "short_blade",
    "SK_LONG_BLADES":    "long_blade",
    "SK_MACES_FLAILS":   "mace",
    "SK_AXES":           "axe",
    "SK_POLEARMS":       "polearm",
    "SK_STAVES":         "staff",
    "SK_RANGED_WEAPONS": "bow",
    "SK_THROWING":       "throwing",
    "SK_UNARMED_COMBAT": "unarmed",
}

# ── Weapons ───────────────────────────────────────────────────────────────────
# Each entry: { WPN_FOO, "name", dam, hit, speed, SK_BAR, SIZE_..., SIZE_..., dam_type, commonness, ...}
# We only care about name, dam, hit, speed, skill, commonness.

# Extract the Weapon_prop[] block
wp_start = text.index("static const weapon_def Weapon_prop[]")
wp_end   = text.index("\n};", wp_start) + 3
wp_block = text[wp_start:wp_end]

# Match individual entries
WPN_RE = re.compile(
    r'\{\s*(WPN_\w+)\s*,\s*"([^"]+)"\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*\n?\s*(SK_\w+)',
    re.MULTILINE,
)

# Commonness is the 10th field (index 9) — grab it separately
COMMON_RE = re.compile(
    r'\{\s*WPN_\w+[^}]*?,\s*(\d+)\s*,\s*(\d+)\s*,\s*\d+\s*[,\}]',
    re.DOTALL,
)

weapons = []
for m in WPN_RE.finditer(wp_block):
    wpn_id, name, dam, hit, speed, sk = m.groups()
    # skip "old" / removed items
    if name.startswith("old ") or name.startswith("removed "):
        continue
    skill = SKILL_MAP.get(sk, sk.lower().replace("sk_", ""))
    # derive our internal id from name
    item_id = name.lower().replace(" ", "_").replace("'", "").replace("-", "_")
    weapons.append({
        "id":         item_id,
        "dcss_enum":  wpn_id,
        "name":       name.title(),
        "damage":     int(dam),
        "accuracy":   int(hit),
        "speed":      int(speed),
        "skill":      skill,
    })

# ── Armours ───────────────────────────────────────────────────────────────────
# { ARM_FOO, "name", ac, ev_penalty, price, slot, fit_min, fit_max, ... }

arm_start = text.index("static const armour_def Armour_prop[]")
arm_end   = text.index("\n};", arm_start) + 3
arm_block = text[arm_start:arm_end]

ARM_RE = re.compile(
    r'\{\s*(ARM_\w+)\s*,\s*"([^"]+)"\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)',
    re.MULTILINE,
)

armours = []
for m in ARM_RE.finditer(arm_block):
    arm_id, name, ac, ev_pen, price = m.groups()
    if name.startswith("removed "):
        continue
    item_id = name.lower().replace(" ", "_").replace("'", "").replace("-", "_")
    armours.append({
        "id":         item_id,
        "dcss_enum":  arm_id,
        "name":       name.title(),
        "ac":         int(ac),
        "ev_penalty": int(ev_pen),   # negative = EV loss; stored as-is
        "price":      int(price),
    })

# ── Write JSON ────────────────────────────────────────────────────────────────
(OUT_DIR / "weapons.json").write_text(json.dumps(weapons, indent=2, ensure_ascii=False))
(OUT_DIR / "armours.json").write_text(json.dumps(armours, indent=2, ensure_ascii=False))

print(f"Wrote {len(weapons)} weapons → assets/dcss_items/weapons.json")
print(f"Wrote {len(armours)} armours → assets/dcss_items/armours.json")
