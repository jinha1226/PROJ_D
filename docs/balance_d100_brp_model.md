# PocketCrawl d100 / BRP-Style Balance Model

This document records the current internal combat balance model so future tuning
does not have to be rediscovered from code.

## Intent

PocketCrawl keeps its roguelike data shape, but combat resolution now borrows
from BRP/d100:

- contested physical hit rolls are expressed as explicit 1-100 percent chances
- physical weapon damage is rolled from weapon dice
- STR plus hidden race size gives a small damage modifier
- armor reduces damage by soak, not by hit chance

The UI does not need to expose all of this. The goal is a clear tuning grammar.

## Current Model IDs

Declared in `config/balance/core_rules.json`:

- `resolution_model`: `d100_adapter_v1`
- `damage_model`: `brp_weapon_dice_soak_v1`

Implemented in `scripts/systems/CombatSystem.gd`.

## Hit Resolution

All physical hit checks roll `1d100 <= chance`.

Player hit chance:

```text
72 base player accuracy
+ (attack stat - 10) * 2
+ visible weapon skill level * 4
+ weapon enchantment plus * 3
+ slay_bonus * 4
+ weapon_mastery bonus for melee
- status hit penalties
- target EV * 3
clamped to 10..92
```

Monster hit chance:

```text
68 base monster accuracy
+ monster HD * 3
- status hit penalties
- player EV * 3
clamped to 10..92
```

Shield block is checked after a hit and before damage:

```text
block chance =
  shield.effect_value
  + defense skill * 3
  - missing required skill * 4
clamped to 3..75
```

## Weapon Damage

Physical player damage uses:

```text
weapon dice
+ damage modifier from STR + race size
+ skill step bonus
+ weapon enchantment plus
+ slay_bonus
- arm wound penalty
- armor soak
minimum 1
```

Current weapon dice table:

```text
dagger / frost_dagger / venom_dagger / stiletto: 1d4+1
dirk / quick_blade: 1d4+2
assassin_blade: 1d6+1
short_sword: 1d6
arming_sword / long_sword / flaming_sword: 1d8
bastard_sword: 1d10
great_blade: 2d6
mace / shock_mace: 1d6+1
battle_axe: 1d8+1
spear / javelin: 1d6
shortbow: 1d6
longbow: 1d8
crossbow: 1d8+1
staff: 1d6
unarmed fallback: 1d3
```

Unknown weapons are mapped from their existing `damage` value into a nearby die.

## Damage Modifier

Damage modifier is based on:

```text
score = attack stat + race.size_score
```

Attack stat comes from weapon type:

- STR for most melee weapons
- DEX for ranged weapons and dagger-category weapons
- INT for staves

Current modifier table:

```text
score <= 12: -1
13..20:      +0
21..28:      +1
29..36:      +2
37+:         +3
```

This is intentionally flatter than tabletop BRP damage bonus dice. It keeps
PocketCrawl mobile-readable while preserving the STR+size idea.

## Race Size Scores

`RaceData.size_score` is internal and not shown in UI.

```text
spriggan: 4
kobold:   6
elf:      9
dwarf:    9
human:   10
vampire: 10
gargoyle:10
hill_orc:11
tester:  12
minotaur:14
troll:   18
```

## Skill Damage Steps

Visible skill levels remain `0..9`. Damage bonus is stepped:

```text
skill 0..2: +0
skill 3..5: +1
skill 6..8: +2
skill 9:    +3
```

This avoids tiny per-level noise in 32x32/mobile combat readability while still
making mastery matter.

## Armor Soak

Existing `ac` / `ac_bonus` values are adapted into BRP-style soak rolls:

```text
AC 0:      0
AC 1:      0..1
AC 2:      1..2
AC 3..4:   1..3
AC 5..6:   2..4
AC 7..8:   3..5
AC 9+:     4..7, plus small bonus for very high AC
```

Practical item targets:

```text
robe:       light soak, usually 0..1
leather:    1..2
ring/scale: 1..3 or 2..4
chain:      2..4
plate:      4..7
```

EV remains the defense against being hit. Armor is protection after a hit.

## Still Not Converted

These systems still use older formulas or separate logic:

- spell damage
- status success/resistance
- monster natural weapon dice
- body-part wound severity
- brand damage dice and proc chances

Those should be converted only after the physical combat model feels good.
