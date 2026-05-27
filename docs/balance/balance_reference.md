# PocketCrawl — Balance Reference

_Source of truth: actual PROJ_D code as of 2026-05-23_
_Extracted from: Player.gd, CombatSystem.gd, EssenceSystem.gd, ItemRegistry.gd, ZoneManager.gd, TurnManager.gd, RaceData.gd_

---

## Progression

- **Max XL**: 20
- **XP curve** (XP to reach each level): `[0, 10, 25, 50, 90, 150, 230, 320, 420, 540, 650, 800, 980, 1190, 1430, 1700, 2000, 2330, 2690, 3080]`
- **HP gain per XL**: `race.hp_per_level + STR/8` (human default: 5)
- **MP gain per XL**: `1 + INT/3`
- **Auto stat bump**: +1 to lowest stat at XL 12, 15, 18 (tie-break: STR > DEX > INT)

---

## Skills

### 9 Visible Skills (scale 0–9)

| ID | Category | XP actions |
|---|---|---|
| `weapon_mastery` | Combat | melee attacks |
| `archery` | Combat | ranged attacks |
| `tactics` | Combat | melee attacks (secondary); +5 HP per level-up |
| `defense` | Defense | taking hits (armor/shield equipped), blocking |
| `magery` | Magic | casting spells |
| `stealth` | Utility | sneaking; +1 EV per level-up |
| `tracking` | Utility | +1 flat XP per kill |
| `survival` | Utility | potion use, rest |
| `lockpicking` | Utility | picking locks |

- **Max level**: 9
- **XP per level** (lv0→1 … lv8→9): `[12, 28, 55, 95, 150, 230, 340, 490, 700]`
- **Aptitude multiplier**: `1.2 ^ aptitude` (range -3 to +3; +2 apt ≈ 1.44×, -2 ≈ 0.69×)

### Hidden Sub-skills (familiarity tier)

33 sub-skill IDs that map into the 9 visible buckets via `SKILL_REMAP`. Stored in `hidden_skills`, level up silently. Examples:

| Sub-skill IDs | → Visible skill |
|---|---|
| `short_blades`, `long_blades`, `axes`, `maces`, `polearms`, `staves`, `unarmed` | `weapon_mastery` |
| `bows`, `crossbows`, `slings`, `throwing` | `archery` |
| `fighting` | `tactics` |
| `armor`, `shields` | `defense` |
| `dodging` | `stealth` |
| `spellcasting`, all 8 schools & 5 elements | `magery` |

### XP Routing

- **Active skills empty**: full kill XP → action skill (or `weapon_mastery` fallback)
- **Active skills set**: XP split equally across active visible skills below cap
- **Defense XP**: dodge +2.0 / hit-taken +1.5 / block +3.0 per event
- **Tracking bonus**: +1.0 XP per kill regardless of active skills
- **Backstab bonus**: Tactics +5 XP if backstab triggered

---

## Combat (d100 System)

### Hit Chance
```
player_acc = 84 + (stat - 10)×2 + skill_lv×4 + weapon_plus×3 + slay_bonus×4
           + req_hit_pen×5 - status_hit_penalty×5
monster_ev  = evasion × 3  (percent deduction)
hit_chance  = clamp(player_acc - monster_ev, 10, 92)  %
```

Monster accuracy: `68 + hd×3 - status_hit_penalty×5`

### Damage Pipeline

1. **Base roll**: weapon damage dice (see table)
2. **Stat modifier**: bracket on `(stat + size_score)`
   - ≤12 → -1, 13–20 → 0, 21–28 → +1, 29–36 → +2, >36 → +3
3. **Skill bonus**: lv 0–2 → +0, lv 3–5 → +1, lv 6–8 → +2, lv 9 → +3
4. **Flat additions**: weapon_plus, slay_bonus, arm-wound penalty (-2 each), damage_boost status (+1–4)
5. **Multiplicative chain**: ranged mult (essence/faith) × melee mult × unaware mult × plague synergy
6. **Armor soak**: roll based on AC (0–7+)
7. **Brand extra**: resist-scaled, applied after multipliers

### Weapon Dice Table

| Weapon | Dice |
|---|---|
| Dagger / frost_dagger / venom_dagger / stiletto | 1d4 |
| Dirk / quick_blade | 1d4+2 |
| Assassin blade | 1d6+1 |
| Short sword | 1d6 |
| Arming sword / longsword / flaming sword | 1d8 |
| Bastard sword | 1d10 |
| Great blade | 2d6 |
| Mace / shock_mace | 1d6+1 |
| Battle axe | 1d8+1 |
| Spear / javelin | 1d6 |
| Shortbow | 1d6 |
| Longbow | 1d8 |
| Crossbow | 1d8+1 |
| Staff | 1d6 |

### Weapon Delay
```
mult = max(0.75, 1.0 - skill_lv × 0.025)   (caps at 25% reduction at lv 9 → ×0.775)
```

### Weapon Requirements
```
missing = max(0, req - skill_lv)
hit_penalty  = missing × -2  (pct)
damage_mult  = max(0.3, 1.0 - missing × 0.05)
```

### Special Attacks
- **Backstab** (unaware target): `base_dmg × (0.5 + stealth_lv×0.05 + [+0.25 dagger], max 1.0)`
  - Only triggers on unaware monsters
- **Parry** (blades): `weapon_mastery_lv × 0.03` chance → halves incoming damage
- **Cleave** (axes): `base_dmg / 2` to adjacent enemies
- **Dagger swift strike** (on kill): `weapon_mastery_lv × 0.05` chance → free follow-up attack

### Shield Block
```
block% = clamp(shield.effect_value + shield_lv×3 - missing_shield_lv×4, 3, 75)
```
Block XP: +3.0 per successful block.

### AC / EV
```
EV = 1 + DEX/2 + stealth_lv
EV -= armor.ev_penalty × max(0, 1 - armor_lv×0.1)
EV -= max(0, armor.req - armor_lv)     [missing skill penalty]
EV -= shield.ev_penalty
EV -= max(0, shield.req - shield_lv)
EV += EssenceSystem.bonus_ev(player)

AC = armor.ac_bonus + weapon_plus + EssenceSystem.bonus_ac(player)
```

### Kill XP
```
xp_award = monster.xp_value × 2.2
```
Rune completion bonus: `entry_depth × 150` (crypt 150, swamp 300, ice_caves 450, infernal 600)

---

## Races

Base stats: STR 10, DEX 10, INT 10, HP ~28, MP ~6

| Race | STR | DEX | INT | HP/lv | Size | Passive | Unlocked |
|---|---|---|---|---|---|---|---|
| human | 0 | 0 | 0 | 5 | 10 | adaptable | always |
| hill_orc | +2 | -2 | 0 | 6 | 11 | bloodthirst | default on |
| elf | -1 | +1 | +2 | 4 | 9 | spell_focus | always |
| kobold | -1 | +2 | 0 | 4 | 8 | pack_hunter | kill kobold |
| troll | +4 | -2 | -2 | 8 | 13 | regeneration | default off |
| dwarf | +1 | -1 | 0 | 6 | 10 | stone_sense | default on |
| minotaur | +3 | -1 | -2 | 7 | 12 | horns | default off |
| spriggan | -3 | +4 | +1 | 3 | 7 | nature_step | default off |
| vampire | 0 | +1 | +1 | 4 | 9 | sanguine | default off |
| gargoyle | +2 | -2 | 0 | 7 | 11 | stone_form | default off |

Skill aptitudes stored per race in `.tres` files (range -3 to +3, affect XP gain).

---

## Essence System

### Slots
- 3 slots total
- Unlock thresholds: expedition 0 (slot 1), expedition 6 (slot 2), expedition 14 (slot 3)
- Inventory cap: 4 (+ faith bonus)

### Normal Tier
| ID | Key Bonuses | Penalties |
|---|---|---|
| essence_fire | melee fire +3, ignite 35% | — |
| essence_cold | freeze chance 40% (1 turn) | — |
| essence_swiftness | +1 DEX, +1 EV, stealth +2 | — |
| essence_vitality | +8 HP, +3 HP on kill | -1 EV |
| essence_regeneration | +1 HP/2 turns | fire vulnerable |
| essence_venom | poison on hit (venom_touch) | -2 Will |

### Rare Tier
| ID | Key Bonuses | Penalties |
|---|---|---|
| essence_might | +2 STR, kill momentum | — |
| essence_stone | +2 AC, -1 incoming dmg | — |
| essence_warding | +5 Will, -1 incoming dmg | — |

### Unique Tier (branch rewards & drops)
| ID | Key Bonuses | Penalties |
|---|---|---|
| essence_arcana | +2 INT, spell INT req -2 | — |
| essence_fury | +1 dmg bonus 2t on kill | -1 AC |
| essence_drain | +4 HP on kill | -2 HP max |
| essence_gloam | unaware ×1.35 dmg, stealth +2 | — |
| essence_undeath | drain 2 HP on melee hit | -4 HP max, -15% healing |
| essence_plague | (swamp boss) | — |
| essence_glacial | (ice_caves boss) | — |
| essence_infernal | fire dmg ×1.25 | — |
| essence_serpent | ambush poison +, hit poison 20% | — |
| essence_bastion | +2 AC, +2 DR | -1 EV, -2 EV |
| essence_tempest | ranged dmg ×1.15 | — |
| essence_cinder | — | — |
| essence_bloodwake | potion heal ×0.8 | — |
| essence_pale_star | spell INT req -2 | — |
| essence_dread | — | — |

### Resonance Synergies (active with 2+ matching essences)
| Name | Requires | Bonus |
|---|---|---|
| Blazecraft | fire + arcana | fire spell power +4 |
| Frostcraft | cold + arcana | cold spell power +4 |
| Bulwark Heart | stone + vitality | +1 DR, +3 potion healing |
| Bloodrush | fury + drain | +2 HP on kill |
| Ghost Venom / Gloam Swift | gloam + swiftness | stealth +2, weakens first unaware hit |
| Bastion Vital | bastion + vitality | stacks DR/AC |

### Key Essence Functions
```
bonus_ac(player):     stone +2, bastion +2, swiftness -1, fury -1, tempest -1
bonus_ev(player):     swiftness +1, vitality -1, bastion -2
bonus_incoming_dr:    stone +1, warding +1, bastion +2, (stone+vitality synergy) +1
potion_heal_mult:     1.0 normally, 0.8 if bloodwake
ranged_dmg_mult:      1.15 if tempest
unaware_dmg_mult:     1.35 if gloam, 1.25 if (serpent+swiftness)
spell_int_discount:   +2 arcana, +2 pale_star, max +4 with synergies
```

---

## Zones & Turn Budget

### Main Path (6 floors)

| Depth | Zone ID | Style | Turn Budget |
|---|---|---|---|
| 1 | dungeon | BSP | 240 |
| 2 | lair | cave | 260 |
| 3 | orc_mines | BSP | 270 |
| 4 | elven_halls | BSP large | 290 |
| 5 | crypt | crypt | 310 |
| 6 | abyss | cave | 320 |

### Branches (4, each 3 floors)

| ID | Env | Turn Budget | Boss | Essence Reward |
|---|---|---|---|---|
| swamp | poison | 180 | bog_serpent | essence_plague |
| ice_caves | cold | 180 | glacial_sovereign | essence_glacial |
| infernal | fire | 180 | ember_tyrant | essence_infernal |
| vault | neutral | 180 | golden_dragon | essence_bastion |

Branch entrances:
- swamp at depth 2, ice_caves at depth 3, infernal at depth 4, vault at depth 5

Completion bonuses: +35 per branch rune, +120 for all 4.

---

## Items

### Loot Distribution (per floor drop)

| Category | Chance |
|---|---|
| Potion | 31% |
| Scroll | 27% |
| Wand | 18% |
| Equipment | 10% |
| Throwing | 6% |
| Gold | 5% |
| Spellpage | 2% |
| Book | 1% |

### Equipment Tier by Depth

Main floors 1–6. Branch effective depths up to 8 (swamp 3–5, ice_caves 4–6, infernal 5–7, vault 6–8).

| Depth | T1 | T2 | T3 | T4 | T5 |
|---|---|---|---|---|---|
| 1 | 70% | 25% | 5% | — | — |
| 2 | 30% | 45% | 20% | 5% | — |
| 3 | 10% | 30% | 40% | 18% | 2% |
| 4 | — | 15% | 35% | 35% | 15% |
| 5 | — | 5% | 25% | 45% | 25% |
| 6+ | — | — | 10% | 40% | 50% |

### Randart Generation
```
chance = clamp(0.05 + depth×0.012, 0, 0.33)    (+8% for rings/amulets)
positive mods: 1 base; 22%→+1 extra; 62%→+2; 90%→+3
negative mods: 18% chance 1 neg; 12% sub-chance 2nd neg
```

### Spell Pools by Tier

| Tier | Depth | Sample spells |
|---|---|---|
| 1 | 1 | freeze, pain, shock, sleep, slow, sandblast, foxfire |
| 2 | 2 | animate_skeleton, blink, call_imp (+8) |
| 3 | 3 | confuse, hex_fear, lightning_bolt (+8) |
| 4 | 4 | airstrike, animate_dead, hex_sleep (+7) |
| 5 | 5 | deaths_door, fireball, ignition (+8) |
| 6–7 | 6+ | haste, haunt, chain_lightning, fire_storm, glaciate |

Books contain 2–3 random spells from tiers ≤ current depth.

### Spell INT Requirement
```
int_req = max(5, 7 + spell_level×2 - essence_discount - wizardry_bonus)
discount range: 0–4 (from arcana/pale_star essences)
```

---

## Monster Data

- **Accuracy base**: 68 + hd×3
- **XP value** on kill: `xp_value × 2.2` (pace multiplier)
- Gold drop (humanoids): 30% chance for `randi_range(gold_max/2, gold_max)`
- Speed default: 10 (faster = < 10 turns per player action, slower = > 10)

### Depth Distribution (min_depth → max_depth)

Main floors depth 1–6. Branch effective depths: swamp 3–5, ice_caves 4–6, infernal 5–7, vault 6–8.

| Depth | Monsters |
|---|---|
| 1–2 (fodder) | rat, jackal, bat, kobold, zombie, goblin, giant_cockroach, hobgoblin, adder |
| 2–3 | hound, scorpion, vampire_bat, gnoll, gnoll_sergeant, black_bear, crimson_imp, wolf, phantom, wight\*, crypt_zombie\* |
| 3–4 | orc, orc_warrior, orc_priest, orc_wizard, centaur, gargoyle, giant_wolf_spider, warg, yak, basilisk, steam_dragon, ghoul\*, mummy\*, gnoll_shaman |
| 4–5 | hornet, ogre, red_devil, two_headed_ogre, fire_elemental, earth_elemental, deep_elf_archer, manticore, troll, wyvern, swamp_dragon, cyclops, deep_troll, ogre_mage, vampire, deep_elf_death_mage, wraith, ice_devil, minotaur |
| 5–7 | skeletal_warrior\*, vampire_knight, fire_dragon, fire_giant, frost_giant, balrug, ice_dragon, lich\*, shadow_wraith, revenant, iron_golem |
| 6–7 | executioner, stone_giant, bone_dragon, titan, golden_dragon |

\* = primarily appears in thematic branch (wight/crypt_zombie/mummy/ghoul in crypt, skeletal_warrior in crypt, lich in crypt)

### Bosses (spawned by zone, not pick_by_depth)

| Boss | Depth | HP | Notes |
|---|---|---|---|
| gnoll_warlord | 2 | 70 | main path floor 2 |
| orc_warchief | 3 | 80 | main path floor 3 |
| bog_serpent | 4 | 78 | swamp branch boss |
| stone_warden | 4 | 60 | unique, depth 4 |
| ogre_chieftain | 4 | 95 | main path floor 4 |
| blood_duke | 5 | 70 | unique, depth 5 |
| glacial_sovereign | 5 | 75 | ice_caves branch boss |
| ember_tyrant | 6 | 85 | infernal branch boss |
| golden_dragon | 6 | 108 | vault branch boss (HD 18) |
| sovereign_jelly | 6 | 90 | unique, depth 6 |
| abyssal_sovereign | 7 | 300 | final boss |

### Stat Outliers Fixed (2026-05-23)

| Monster | What changed |
|---|---|
| iron_golem | HP 270→110, AC 24→12, damage 50→30 |
| earth_elemental | AC 14→8, damage 36→20 |
| titan | damage 55→35 |
| stone_giant | damage 45→30, ranged 14→10 |
| bone_dragon | HP 154→90, AC 18→8 |
| orc_warchief | HP 45→80 |
| ancient_lich | HD 27→18 |
| ghoul | XP 5→22 (bug fix) |
| storm_hierophant | min_depth 19→4 (never spawned before) |
| pale_scholar | min_depth 22→5 (never spawned before) |

---

## Faith System

Faith is a parallel build axis alongside Essence. State is normalized via `FaithSystem`. Key interface:
- `melee_damage_mult(player)` — affects melee multiplier in damage pipeline
- `ranged_damage_mult(player)` — affects ranged multiplier
- `potion_heal_mult(player)` — stacks with essence
- `wand_charge_save_chance(player)` — 0.0 default (wand charge always consumed)
- `first_strike_mult(player)` — applies to backstab base damage
- `faith_id == ""` is migration-state only when `first_shrine_choice_done == true`
