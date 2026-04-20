#!/usr/bin/env python3
"""Parse DCSS dat/forms/*.yaml → assets/dcss_forms/forms.json.

DCSS form definitions carry a grab bag of fields; we flatten the subset
that actually drives runtime stats:

  id             file stem (dragon.yaml → "dragon")
  name           short_name or enum
  hp_mod         percentage of base HP (100 = baseline, 150 = +50%)
  ac_base        fixed AC bump
  ac_scaling     AC per 10 skill levels (approx)
  str_delta      STR adjustment
  dex_delta      DEX adjustment
  unarmed_base   unarmed attack damage
  resists        dict of {element: level}
  can_fly / can_swim   terrain flags
  move_speed     action-speed override
  melds          array of "slots" that unequip while the form is active
  is_badform     true for punitive forms like Pig / Bat / Fungus

Deprecated forms (deprecated-*.yaml) are skipped.

Run from project root:
    python3 tools/convert_dcss_forms.py
"""

import json
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML required: pip install pyyaml")

ROOT = Path("/mnt/d/PROJ_D")
SRC_DIR = ROOT / "crawl/crawl-ref/source/dat/forms"
OUT = ROOT / "assets/dcss_forms/forms.json"


def parse_form(path: Path) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        raw = yaml.safe_load(f) or {}
    ac = raw.get("ac", {}) or {}
    unarmed = raw.get("unarmed", {}) or {}
    out: dict = {
        "id": path.stem.replace("-", "_"),
        "name": str(raw.get("short_name") or raw.get("long_name") or raw.get("enum", path.stem)),
        "description": str(raw.get("description", "")),
        "hp_mod": int(raw.get("hp_mod", 100)),
        "str_delta": int(raw.get("str", 0)),
        "dex_delta": int(raw.get("dex", 0)),
        "ac_base": int(ac.get("base", 0)) if isinstance(ac, dict) else 0,
        "ac_scaling": int(ac.get("scaling", 0)) if isinstance(ac, dict) else 0,
        "unarmed_base": int(unarmed.get("base", 0)) if isinstance(unarmed, dict) else 0,
        "unarmed_scaling": int(unarmed.get("scaling", 0)) if isinstance(unarmed, dict) else 0,
        "resists": raw.get("resists", {}) or {},
        "can_fly": bool(raw.get("can_fly", False)),
        "can_swim": bool(raw.get("can_swim", False)),
        "move_speed": int(raw.get("move_speed", 10)),
        "melds": list(raw.get("melds", []) or []),
        "size": str(raw.get("size", "medium")),
        "is_badform": bool(raw.get("is_badform", False)),
        "talisman": str(raw.get("talisman", "")),
    }
    return out


def main() -> int:
    if not SRC_DIR.is_dir():
        sys.exit(f"ERROR: missing {SRC_DIR}")
    out: dict = {}
    for path in sorted(SRC_DIR.glob("*.yaml")):
        if path.name.startswith("deprecated-") or path.name == "none.yaml":
            continue
        entry = parse_form(path)
        if entry["id"]:
            out[entry["id"]] = entry
    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1, sort_keys=True)
    print(f"wrote {OUT.relative_to(ROOT)} with {len(out)} forms")
    return 0


if __name__ == "__main__":
    sys.exit(main())
