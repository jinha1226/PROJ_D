#!/usr/bin/env python3
"""Extract DCSS per-spell damage dice from zap-data.h → assets/dcss_spells/zaps.json.

Parses two sources in the DCSS tree:
  1. spl-zap.cc `_spl_zaps[]` — SPELL_X → ZAP_Y lookup pairs.
  2. zap-data.h — the `new dicedef_calculator<N, A, mn, md>` or
     `new calcdice_calculator<N, A, mn, md>` template args that carry the
     player-damage coefficients for each zap.

Output: `assets/dcss_spells/zaps.json`, a dict keyed by our lowercased spell
id (e.g. "magic_dart"), each entry:

    {
        "kind": "dicedef"|"calcdice",
        "n": <num_dice>, "a": <adder>, "mn": <mult_num>, "md": <mult_denom>,
        "zap": "ZAP_MAGIC_DART"   # reference, not used at runtime
    }

`dicedef`: N dice of size `A + pow * mn / md`.
`calcdice`: N dice; total max is `A + pow * mn / md`, distributed evenly.

Run from project root:
    python3 tools/convert_dcss_zaps.py
"""

import json
import re
import sys
from pathlib import Path

ROOT = Path("/mnt/d/PROJ_D")
SPL_ZAP = ROOT / "crawl/crawl-ref/source/spl-zap.cc"
ZAP_DATA = ROOT / "crawl/crawl-ref/source/zap-data.h"
OUT = ROOT / "assets/dcss_spells/zaps.json"


def parse_spl_zaps() -> dict:
    """Return a dict SPELL_X → ZAP_Y from spl-zap.cc `_spl_zaps` table.

    The table has duplicate SPELL_X entries (last wins in DCSS code because
    zap_to_spell walks in order and returns first match); we keep the first
    mapping so UNLEASH_DESTRUCTION_PIERCING etc. don't clobber the primary.
    """
    spl_to_zap: dict = {}
    if not SPL_ZAP.is_file():
        sys.exit(f"ERROR: missing {SPL_ZAP}")
    for line in SPL_ZAP.read_text(encoding="utf-8").splitlines():
        m = re.match(r"\s*\{\s*(SPELL_[A-Z0-9_]+)\s*,\s*(ZAP_[A-Z0-9_]+)\s*\}", line)
        if m:
            spell = m.group(1)
            zap = m.group(2)
            if spell not in spl_to_zap:
                spl_to_zap[spell] = zap
    return spl_to_zap


_ENUM_RE = re.compile(r"(ZAP_[A-Z0-9_]+)")
_CALC_RE = re.compile(
    r"new\s+(dicedef|calcdice)_calculator<\s*"
    r"(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*,\s*(-?\d+)\s*>"
)


def parse_zap_data() -> dict:
    """Return a dict ZAP_Y → {kind, n, a, mn, md} from zap-data.h.

    Splits the file into `{ ... }` blocks by nesting-depth tracking (braces
    inside string literals and comments are rare here, so a naive depth
    counter suffices). Within each block we read the *player* damage slot,
    which is the first of the two damage fields. If it's nullptr, we skip.
    """
    if not ZAP_DATA.is_file():
        sys.exit(f"ERROR: missing {ZAP_DATA}")
    text = ZAP_DATA.read_text(encoding="utf-8")
    # zap_data[] is a big `{ ... }` array literal and each zap is an inner
    # brace block at depth 1 inside that array. We want the depth-1 blocks.
    blocks: list = []
    depth = 0
    start = -1
    for i, ch in enumerate(text):
        if ch == "{":
            depth += 1
            if depth == 2:
                start = i
        elif ch == "}":
            if depth == 2 and start >= 0:
                blocks.append(text[start:i + 1])
                start = -1
            depth -= 1

    out: dict = {}
    for block in blocks:
        enum_match = _ENUM_RE.search(block)
        if not enum_match:
            continue
        zap = enum_match.group(1)
        # The player damage slot is the first dicedef/calcdice in the block.
        # If `nullptr` precedes it textually before any dicedef/calcdice,
        # we've got the monster calc instead and must skip.
        calc_match = _CALC_RE.search(block)
        if not calc_match:
            continue
        # Snippet between end of zap name and start of first calc: look for
        # two commas with `nullptr` between them as a conservative test that
        # the player slot is empty.
        prefix = block[enum_match.end():calc_match.start()]
        # Normalise whitespace for the nullptr check.
        squashed = re.sub(r"\s+", " ", prefix)
        # Player-damage slot is position 2 (after enum and name). An empty
        # player slot shows up as ", nullptr," before the calc call.
        if ", nullptr," in squashed and squashed.index(", nullptr,") < squashed.find("new "):
            continue
        if zap in out:
            continue
        out[zap] = {
            "kind": calc_match.group(1),
            "n": int(calc_match.group(2)),
            "a": int(calc_match.group(3)),
            "mn": int(calc_match.group(4)),
            "md": int(calc_match.group(5)),
        }
    return out


def main() -> int:
    spl_to_zap = parse_spl_zaps()
    zap_to_dice = parse_zap_data()

    by_spell: dict = {}
    missing: list = []
    for spell, zap in spl_to_zap.items():
        # SPELL_MAGIC_DART → magic_dart
        sid = spell[len("SPELL_"):].lower()
        dice = zap_to_dice.get(zap)
        if dice is None:
            missing.append((sid, zap))
            continue
        entry = dict(dice)
        entry["zap"] = zap
        by_spell[sid] = entry

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(by_spell, f, ensure_ascii=False, indent=1, sort_keys=True)

    print(f"wrote {OUT.relative_to(ROOT)} with {len(by_spell)} spells")
    print(f"skipped {len(missing)} zaps without player-damage calc")
    if missing:
        for sid, zap in missing[:10]:
            print(f"  {sid}: {zap} (no dicedef/calcdice)")
        if len(missing) > 10:
            print(f"  ... and {len(missing) - 10} more")
    return 0


if __name__ == "__main__":
    sys.exit(main())
