#!/usr/bin/env python3
"""Parse DCSS spl-data.h → assets/dcss_spells/spells.json

Each spell block (actual format):
  line 0: SPELL_FOO, "Spell Name",
  line 1: spschool::foo | spschool::bar,
  line 2: spflag::x | spflag::y,
  line 3: level,
  line 4: power_cap,
  line 5: min_range, max_range,
  line 6: effect_noise,
  line 7: TILEG_...,
"""
import re, json
from pathlib import Path

SRC = Path(__file__).parent.parent / "crawl/crawl-ref/source/spl-data.h"
OUT = Path(__file__).parent.parent / "assets/dcss_spells/spells.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

text = SRC.read_text(encoding="utf-8")

SCHOOL_MAP = {
    "conjuration":  "conjurations",
    "fire":         "fire",
    "ice":          "cold",
    "air":          "air",
    "earth":        "earth",
    "necromancy":   "necromancy",
    "hexes":        "hexes",
    "summoning":    "summoning",
    "translocation":"translocation",
    "alchemy":      "alchemy",
    "forgecraft":   "forgecraft",
    "none":         "none",
    "random":       "none",
}

FLAG_MAP = {
    "dir_or_target": "targeted",
    "target":        "targeted",
    "area":          "area",
    "not_self":      "not_self",
    "WL_check":      "wl_check",
    "needs_tracer":  "tracer",
    "obj":           "object",
    "selfench":      "self",
    "helpful":       "helpful",
    "hasty":         "hasty",
    "destructive":   "destructive",
}

BLOCK_RE = re.compile(r'\{([^{}]+)\}', re.DOTALL)
spells = []

for m in BLOCK_RE.finditer(text):
    body = m.group(1).strip()
    lines = [ln.strip().rstrip(',') for ln in body.splitlines() if ln.strip()]
    if len(lines) < 5:
        continue

    # Line 0: "SPELL_FOO, "Spell Name""
    line0 = lines[0]
    if not line0.startswith("SPELL_"):
        continue

    # Extract enum id (everything before the first comma)
    enum_id = line0.split(",")[0].strip()
    if enum_id in ("SPELL_NO_SPELL", "SPELL_DEBUGGING_RAY"):
        continue

    # Extract name from quoted part of line 0
    name_m = re.search(r'"([^"]+)"', line0)
    if not name_m:
        continue
    name = name_m.group(1)

    # Line 1: schools
    schools = []
    for part in re.split(r'\|', lines[1]):
        sc_m = re.match(r'spschool::(\w+)', part.strip())
        if sc_m:
            sc = SCHOOL_MAP.get(sc_m.group(1), sc_m.group(1))
            if sc not in schools:
                schools.append(sc)

    # Line 2: flags
    flags = []
    for part in re.split(r'\|', lines[2]):
        flag_m = re.match(r'spflag::(\w+)', part.strip())
        if flag_m:
            f = FLAG_MAP.get(flag_m.group(1), "")
            if f and f not in flags:
                flags.append(f)

    # Line 3: level
    level = 0
    try:
        level = int(lines[3])
    except (ValueError, IndexError):
        pass

    # Line 4: power_cap
    power_cap = 0
    try:
        power_cap = int(lines[4])
    except (ValueError, IndexError):
        pass

    # Line 5: "min_range, max_range" or "-1, -1" or "LOS_RADIUS, LOS_RADIUS" or "5, 5"
    min_range = max_range = -1
    if len(lines) > 5:
        range_line = lines[5].replace("LOS_RADIUS", "9")
        range_parts = [p.strip() for p in range_line.split(",")]
        try:
            min_range = int(range_parts[0])
        except (ValueError, IndexError):
            pass
        try:
            max_range = int(range_parts[1]) if len(range_parts) > 1 else min_range
        except ValueError:
            pass

    spell_id = enum_id.replace("SPELL_", "").lower()

    # Derive targeting type from flags
    targeting = "self"
    if "targeted" in flags:
        targeting = "single"
    if "area" in flags:
        targeting = "area"

    spells.append({
        "id":        spell_id,
        "name":      name,
        "schools":   schools,
        "flags":     flags,
        "level":     level,
        "power_cap": power_cap,
        "min_range": min_range,
        "max_range": max_range,
        "mp":        level,           # proxy: DCSS level ≈ MP cost
        "targeting": targeting,
    })

OUT.write_text(json.dumps(spells, indent=2, ensure_ascii=False))
print(f"Wrote {len(spells)} spells → {OUT.relative_to(Path.cwd())}")
# Quick preview
for s in spells[:8]:
    print(f"  {s['id']:30s} lv{s['level']}  {s['schools']}  range={s['max_range']}")
