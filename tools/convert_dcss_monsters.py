#!/usr/bin/env python3
"""Parse DCSS dat/mons/*.yaml → assets/dcss_monsters/monster_data.json

Extracts per-monster: name, exp, hd, hp_10x, ac, ev, speed, attacks,
resists, spells, holiness, size, flags.
"""
import json, re
from pathlib import Path

try:
    import yaml
    USE_YAML = True
except ImportError:
    USE_YAML = False

SRC = Path(__file__).parent.parent / "crawl/crawl-ref/source/dat/mons"
OUT = Path(__file__).parent.parent / "assets/dcss_monsters/monster_data.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")

def parse_yaml_simple(text: str) -> dict:
    """Minimal YAML parser — handles flat key: value and simple lists."""
    result = {}
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            i += 1
            continue
        m = re.match(r'^(\w[\w\-]*):\s*(.*)', stripped)
        if m:
            key, val = m.group(1), m.group(2).strip()
            if val.startswith('['):
                items = re.findall(r'[\w\-]+', val)
                result[key] = items
            elif val == '':
                # could be block list
                block = []
                i += 1
                while i < len(lines):
                    sub = lines[i].strip()
                    if not sub or not sub.startswith('-'):
                        break
                    block.append(sub.lstrip('- ').strip())
                    i += 1
                result[key] = block
                continue
            else:
                # strip quotes
                val = val.strip('"\'')
                result[key] = val
        i += 1
    return result

monsters = []
yaml_files = sorted(SRC.glob("*.yaml"))

for fpath in yaml_files:
    stem = fpath.stem
    if stem.startswith("TEST"):
        continue
    text = fpath.read_text(encoding="utf-8")

    if USE_YAML:
        try:
            data = yaml.safe_load(text) or {}
        except Exception:
            data = parse_yaml_simple(text)
    else:
        data = parse_yaml_simple(text)

    if not isinstance(data, dict):
        continue

    name = str(data.get("name", stem.replace("-", " ")))
    monster_id = _slug(name)

    # Attacks
    attacks = []
    raw_attacks = data.get("attacks", [])
    if isinstance(raw_attacks, list):
        for atk in raw_attacks:
            if isinstance(atk, dict):
                attacks.append({
                    "type":    str(atk.get("type", "hit")),
                    "flavour": str(atk.get("flavour", "")),
                    "damage":  int(atk.get("damage", 0)),
                })
            elif isinstance(atk, str):
                dm = re.search(r'\d+', atk)
                attacks.append({"type": "hit", "flavour": "", "damage": int(dm.group()) if dm else 0})

    # Resists
    resists_raw = data.get("resists", {})
    resists = {}
    if isinstance(resists_raw, dict):
        resists = {str(k): int(v) for k, v in resists_raw.items()}

    # Flags
    flags = data.get("flags", [])
    if isinstance(flags, str):
        flags = [flags]

    # Holiness
    holiness = data.get("holiness", [])
    if isinstance(holiness, str):
        holiness = [holiness]

    # hp_10x → average hp
    hp_10x = int(data.get("hp_10x", 0))
    avg_hp = round(hp_10x / 10.0, 1) if hp_10x else 0

    entry = {
        "id":       monster_id,
        "name":     name,
        "exp":      int(data.get("exp", 0)),
        "hd":       int(data.get("hd", 1)),
        "avg_hp":   avg_hp,
        "ac":       int(data.get("ac", 0)),
        "ev":       int(data.get("ev", 10)),
        "speed":    int(data.get("speed", 10)),
        "attacks":  attacks,
        "resists":  resists,
        "holiness": holiness,
        "flags":    flags if isinstance(flags, list) else [str(flags)],
        "size":     str(data.get("size", "medium")),
        "spells":   str(data.get("spells", "")),
        "intel":    str(data.get("intelligence", "animal")),
    }
    monsters.append(entry)

# Build lookup dict
lookup = {m["id"]: m for m in monsters}

OUT.write_text(json.dumps({"monsters": monsters, "by_id": lookup}, indent=2, ensure_ascii=False))
print(f"Wrote {len(monsters)} monsters → {OUT.relative_to(Path.cwd())}")
# Preview a few
for m in monsters[:5]:
    print(f"  {m['id']:30s} hd={m['hd']:2d} exp={m['exp']:5d} hp={m['avg_hp']}")
