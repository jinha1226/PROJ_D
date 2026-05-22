# PocketCrawl — Balance Reference (Expedition Model)

_Source of truth: `/mnt/d/proj_g/expedition_roguelike_proto/scripts/systems/Expedition*Rules.gd`_
_Last synced: 2026-05-22_

Old docs (pre-expedition, 5-skill/class model) archived to `docs/balance/archive_pre_expedition/`.

---

## Skills

9 skills, 0–100 scale. PROJ_D stores them snake_case (`weapon_mastery`); expedition reference uses Title Case (`Weapon Mastery`).

| ID (PROJ_D) | Name | Category | Role |
|---|---|---|---|
| `weapon_mastery` | Weapon Mastery | Combat | Melee accuracy, damage, all weapon types |
| `archery` | Archery | Combat | Ranged accuracy, range penalty, crit |
| `tactics` | Tactics | Combat | Crits, weakness exploit, positional bonus |
| `defense` | Defense | Defense | Armor handling, shield block, damage reduction |
| `magery` | Magery | Magic | Spell reliability, spell power, MP cost |
| `stealth` | Stealth | Utility | Sneaking, ambush damage, detection avoidance |
| `lockpicking` | Lockpicking | Utility | Doors, chests, traps, tool break prevention |
| `tracking` | Tracking | Utility | Monster trails, danger preview, hidden paths |
| `survival` | Survival | Utility | Endurance, recovery, safe return, status recovery |

**XP formula** (`ExpeditionSkillRules.action_xp`):
```
skill_factor = clamp(1.15 - skill_value/120, 0.25, 1.15)
diff_factor  = clamp(0.65 + difficulty*0.35, 0.35, 2.25)
xp = base_xp * skill_factor * diff_factor * risk * anti_grind
```

**Level-up cost**: `10 + band*8` XP per point, where band = `floor(skill/10)` (bands 0–9 → costs 10, 18, 26, …, 82).

**Rank names**: Novice (0–9), Apprentice (10–19), Adept (20–29), Skilled (30–39), Veteran (40–49), Expert (50–59), Master (60–69), Grandmaster (70–79), Legendary (80–89), Mythic (90–100).

> **PROJ_D divergence**: current code caps at 9, uses hidden sub-skills, still has legacy `agility`/`armor`/`shield`. Migration to 0–100 is pending.

---

## Races

10 playable races. Base stats: STR 10, DEX 10, INT 10, HP 28, MP 6. Starting skills all 10.0.

| Race | STR | DEX | INT | HP | MP | Skill mods |
|---|---|---|---|---|---|---|
| Human | 0 | 0 | 0 | 0 | 0 | Survival +3, Tactics +3 |
| Hill Orc | +2 | 0 | -1 | +4 | 0 | Weapon Mastery +5, Tactics +3, Magery -4 |
| Elf | -1 | 0 | +2 | 0 | +4 | Magery +6, Archery +3, Defense -3 |
| Kobold | -1 | +2 | 0 | -3 | 0 | Stealth +6, Lockpicking +5, Defense -3 |
| Troll | +4 | 0 | -3 | +10 | -3 | Weapon Mastery +4, Defense +4, Magery -8, Stealth -5 |
| Dwarf | +1 | -1 | 0 | +5 | 0 | Defense +6, Lockpicking +3, Survival +3 |
| Minotaur | +3 | 0 | -2 | +6 | 0 | Weapon Mastery +6, Tactics +4, Magery -7 |
| Spriggan | -3 | +4 | 0 | -6 | +2 | Stealth +8, Tracking +5, Defense -5 |
| Vampire | 0 | +1 | +1 | -2 | 0 | Stealth +5, Magery +4, Survival -3 |
| Gargoyle | +1 | -2 | 0 | +4 | 0 | Defense +8, Stealth -6, Archery -2 |

> **PROJ_D divergence**: PROJ_D has `orc.tres` (not `hill_orc`); expedition reference uses `hill_orc`. Race `.tres` aptitudes use the old 5-skill IDs — need updating.

---

## Combat Formulas

Source: `ExpeditionSkillRules.gd`

### Hit chance
```
chance = 15 + attacker_skill*0.35 + tactics*0.10 + stat_bonus + weapon_bonus - target_evasion
clamped to [10, 95]
```

### Weapon damage
```
skill_flat = floor(skill_value / 20)
tactics_mult = 1.0 + min(0.20, tactics * 0.002)
final = max(1, (base_dmg + skill_flat + stat_bonus) * weapon_mult * tactics_mult)
```

### Defense reduction
```
defense_mult = 1.0 - min(0.35, defense * 0.0035)    # max 35% reduction at defense=100
final = max(1, round((raw - armor_soak) * defense_mult))
```

### Block chance
```
chance = clamp(5 + defense*0.25 + shield_bonus, 0, 55)
```

### Spell formulas
```
cast_chance = clamp(75 + magery*0.25 + focus_bonus - spell_difficulty, 10, 98)
spell_power = base_power * (1 + magery*0.004) * (1 + min(0.10, tactics*0.001))
mp_cost = max(1, ceil(base_cost * (1 - min(0.25, magery*0.0025))))
```

---

## Starter Shop & Gold

Starting gold: **120**. Starting loadout: empty (all gear bought at starter shop).

Starter shop items:
- Weapons: short_sword 35g, battle_axe 45g, spear 40g, shortbow 50g, staff 30g
- Armor: leather_armor 35g, buckler 30g
- Tools: throwing_knife 25g, bandage 25g
- Magic: spellpage_freeze 45g
- Consumable: potion_healing 20g

---

## Essence System

3 slots total. Slot unlocks: expedition 1 → slot 1, expedition 6 → slot 2, expedition 14 → slot 3.

### Normal Tier
| ID | Name | Bonuses | Penalties |
|---|---|---|---|
| essence_fire | Fire Essence | melee_fire_flat +3, fire_resist +1 | cold_resist -1 |
| essence_cold | Ice Essence | melee_chill_chance 25%, cold_resist +1 | fire_resist -1 |
| essence_swiftness | Swift Essence | Stealth +8, evasion +2 | armor_soak -1 |
| essence_vitality | Life Essence | max_hp +8, on_kill_hp +3 | evasion -1 |
| essence_venom | Venom Essence | poison_on_hit_chance 25% | Survival -5 |

### Rare Tier
| ID | Name | Bonuses | Penalties |
|---|---|---|---|
| essence_might | War Essence | Weapon Mastery +8, Tactics +5 | Magery -8 |
| essence_stone | Stone Essence | armor_soak +2, flat dmg reduction +1 | Stealth -8 |
| essence_warding | Ward Essence | spell_resist +1, Survival +5 | max_mp -2 |

### Unique Tier (branch rewards)
| ID | Name | Branch | Bonuses | Penalties |
|---|---|---|---|---|
| essence_arcana | Arcane Essence | — | Magery +10, spell_cost ×0.92 | max_hp -6 |
| essence_gloam | Gloam Essence | — | unaware_dmg ×1.30, Stealth +6 | max_hp -4 |
| essence_serpent | Serpent Essence | — | ambush_poison 5t, poison_hit 20% | Defense -5 |
| essence_undeath | Essence of Undeath | crypt | drain_touch +2, death_resist +1 | healing ×0.85 |
| essence_plague | Plague Essence | swamp | poison_dmg ×1.20, poison_resist +1 | recovery ×0.90 |
| essence_glacial | Glacial Essence | ice_caves | cold_dmg ×1.18, burst flat -2 | fire_resist -1 |
| essence_infernal | Infernal Essence | infernal | fire_dmg ×1.22, Tactics +6 | Survival -8 |

### Synergies
| ID | Requires | Bonus |
|---|---|---|
| blazecraft | fire + arcana | fire_dmg ×1.18 |
| ghost_venom | swiftness + venom | ambush_poison +2t |
| bulwark_heart | stone + vitality | max_hp +6, flat dmg -1 |
| gloam_swift | gloam + swiftness | unaware ×1.12, Tracking +5 |

---

## Zones & Turn Budget

### Main Route
| Stage | Zone | Depth Range | Turn Budget | Branch |
|---|---|---|---|---|
| 1 | Buried Catacombs | 1–3 | 240 | crypt |
| 2 | Green Lair | 4–6 | 260 | swamp |
| 3 | Orc Mines | 7–9 | 270 | ice_caves |
| 4 | Elven Halls | 10–12 | 290 | infernal |
| 5 | Shattered Abyss | 13–14 | 300 | (none, final boss) |

### Branches
| ID | Name | Parent Stage | Floors | Budget | Boss | Essence Reward |
|---|---|---|---|---|---|---|
| crypt | Sunken Crypt | 1 | 3 | 190 | ancient_lich | essence_undeath |
| swamp | Blackfen Swamp | 2 | 3 | 170 | bog_serpent | essence_plague |
| ice_caves | Ice Caves | 3 | 3 | 180 | glacial_sovereign | essence_glacial |
| infernal | Infernal Gate | 4 | 3 | 190 | ember_tyrant | essence_infernal |

Layouts are **static** (`static_layout: true`), 96×96, persistent per character lifetime.

---

## Implementation Gap Tracker

| Area | Expedition spec | PROJ_D status |
|---|---|---|
| Skill scale | 0–100, 10 ranks | 0–9, needs migration |
| Skill IDs | Title Case | snake_case (OK — just label difference) |
| Race IDs | `hill_orc` | `orc.tres` (rename needed) |
| Race aptitudes | 9-skill mods | Old 5-skill mods in .tres files |
| No class system | Race-only starts | Classes still referenced in old code |
| Turn budget | Per-zone, tracked | Partial (TurnManager exists) |
| Zone structure | 5 stages + 4 branches | 5 dungeon floors exist |
| Faith system | Not present | Present (parallel axis, may keep or cut) |
| Essence slots | 3, expedition-unlock | 1 slot currently live |
| Essence list | 15 essences | Partial |
| Static maps | 96×96, authored | Dynamic 32×36 procedural |
