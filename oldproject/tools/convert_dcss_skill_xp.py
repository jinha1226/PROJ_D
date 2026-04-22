#!/usr/bin/env python3
"""Compute DCSS skill XP thresholds per level → assets/dcss_skills/xp_table.json

Formula from crawl-ref/source/skills.cc:
  _modulo_skill_cost(n)  = 25 * n * (n + 1)
  breakpoints            = [9, 18, 26]
  skill_cost_table[lev]  = _modulo(lev) + sum(_modulo(lev - bp) / 2) for bp in breakpoints if lev > bp
  skill_exp_needed(lev, apt=0) = skill_cost_table[lev] * apt_to_factor(apt)
  apt_to_factor(apt)     = 1 / exp(ln(2) * apt / 4)   (apt=0 → factor=1.0)

We pre-compute cumulative XP for levels 0..27 with apt=0 (human baseline),
then apply a mobile 1.5× multiplier to slow progression slightly on phones.
"""
import json, math
from pathlib import Path

OUT = Path(__file__).parent.parent / "assets/dcss_skills/xp_table.json"
OUT.parent.mkdir(parents=True, exist_ok=True)

MOBILE_MULT = 1.5   # user-chosen slowdown

BREAKPOINTS = [9, 18, 26]

def modulo_cost(n: int) -> int:
    return 25 * n * (n + 1)

def skill_cost_table(level: int) -> int:
    cost = modulo_cost(level)
    for bp in BREAKPOINTS:
        if level > bp:
            cost += modulo_cost(level - bp) // 2
    return cost

def apt_to_factor(apt: int) -> float:
    return 1.0 / math.exp(math.log(2) * apt / 4.0)

# Build per-level XP thresholds (cumulative from level 0 to level N).
# skill_exp_needed(lev) = skill_cost_table[lev] * factor
# XP to reach level N = sum of skill_cost_table[0..N-1] * factor
# (DCSS stores skill_points as a running total up to the table value.)

def xp_thresholds(apt: int = 0, mult: float = 1.0) -> list:
    factor = apt_to_factor(apt) * mult
    cumulative = 0
    thresholds = []  # thresholds[i] = cumulative XP to reach level i
    for lev in range(28):   # levels 0..27 (DCSS MAX_SKILL_LEVEL = 27)
        thresholds.append(int(round(cumulative)))
        cumulative += skill_cost_table(lev) * factor
    return thresholds

human_thresholds = xp_thresholds(apt=0, mult=MOBILE_MULT)

# Also store the per-level cost (XP to go from level N to N+1).
costs = [human_thresholds[i+1] - human_thresholds[i] for i in range(26)]
costs.append(costs[-1])  # level 26 → 27

output = {
    "_comment": "DCSS skill XP table, apt=0 (human), mobile 1.5x. thresholds[i] = total XP to reach level i.",
    "max_level": 27,
    "mobile_multiplier": MOBILE_MULT,
    "thresholds": human_thresholds,
    "per_level_cost": costs,
    # apt_factor lookup: apt -5..+5 (store as string keys)
    "apt_factors": {str(apt): round(apt_to_factor(apt), 4) for apt in range(-6, 7)},
}

OUT.write_text(json.dumps(output, indent=2))
print(f"Wrote {OUT.relative_to(Path.cwd())}")
print("Thresholds (human, mobile):")
for i, v in enumerate(human_thresholds[:15]):
    cost = costs[i]
    print(f"  Lv{i:2d}: cumulative={v:6d}  (cost to next: {cost})")
