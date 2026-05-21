# Body Part Damage System — Design Spec
Date: 2026-05-21

## Overview
Cataclysm / Caves of Qud-style body part damage layer on top of PocketCrawl's existing single-HP-pool combat. Hit location is determined per attack; wounds accumulate in two levels (light → severe) and apply status effects via the existing `Status.gd` system. Applies to both Player and Monster via duck-typing.

---

## Architecture

### New file: `scripts/systems/BodyPartSystem.gd`
Static module, same pattern as `Status.gd`. No autoload needed.

**Key constants:**

```gdscript
# Body type → hit location config
const BODY_TYPES: Dictionary = {
    "humanoid": {
        "parts":   ["head", "torso", "arms", "legs"],
        "weights": [10,     35,      30,     25]
    },
    "serpentine": {
        "parts":   ["head", "body"],
        "weights": [25,     75]
    },
    "flying": {
        "parts":   ["head", "body", "wings"],
        "weights": [20,     50,     30]
    },
    "quadruped": {
        "parts":   ["head", "body", "legs"],
        "weights": [15,     55,     30]
    },
}

# part → { level → [status_id:turns, ...] }
const WOUND_EFFECTS: Dictionary = {
    "head":  {
        1: ["confused:3"],
        2: ["confused:6", "blind:3"]
    },
    "torso": {
        1: ["bleeding:4"],
        2: ["bleeding:8", "weakened:6"]
    },
    "arms":  {
        1: ["attack_penalty:4"],
        2: ["attack_penalty:8"]
    },
    "legs":  {
        1: ["slow:4"],
        2: ["slow:8", "crippled:4"]
    },
    "body":  {
        1: ["bleeding:4"],
        2: ["bleeding:8", "weakened:4"]
    },
    "wings": {
        1: ["slow:3"],
        2: ["slow:6"]   # grounded: flying monsters lose range advantage
    },
}
```

**Public API:**

```gdscript
# Called from CombatSystem after final damage is resolved.
static func process_hit(defender, final_damage: int) -> void

# Called from potion_healing / healing spells.
static func reduce_wounds(actor, levels: int = 1) -> void

# Returns Array of [part_id, level] pairs where level > 0. Used by UI.
static func active_wounds(actor) -> Array
```

**`process_hit` logic:**
1. Determine `body_type`: `MonsterData.body_type` for monsters, `"humanoid"` for Player.
2. Weighted random roll → hit `part`.
3. `wound_chance = float(final_damage) / float(defender.hp_max)`.
4. `if randf() < wound_chance`: upgrade `body_wounds[part]` by 1 (capped at 2).
5. Apply each status from `WOUND_EFFECTS[part][new_level]` via `Status.apply(defender, id, turns)`.
6. Log message: `"Your [part] is [lightly/badly] wounded!"` for Player; silent for Monster.

---

## Data model changes

### `Player.gd`
```gdscript
var body_wounds: Dictionary = {}   # part_id → 0/1/2
```
- Persisted in save data (add to `_collect_save_state` / `_apply_loaded_player_state`).
- Cleared on new run start.

### `MonsterData.gd`
```gdscript
var body_type: String = "humanoid"
```
- Default `"humanoid"` covers most existing monsters without `.tres` edits.
- Serpentine/flying/quadruped monsters updated in their `.tres` files as follow-up.

### `Monster.gd`
```gdscript
var body_wounds: Dictionary = {}   # part_id → 0/1/2
```
- Not persisted (monsters don't survive floor transitions).

---

## CombatSystem integration

Two call sites added, after `player.take_damage(final, ...)` / `monster.take_damage(final)`:

```gdscript
# monster_attack_player — after player.take_damage(final, monster.data.id)
BodyPartSystem.process_hit(player, final)

# player_attack_monster — after monster.take_damage(final)
BodyPartSystem.process_hit(monster, final)
```

Ranged and backstab paths follow the same pattern.

---

## Healing integration

`potion_healing` and `heal` spell: call `BodyPartSystem.reduce_wounds(player, 1)` after HP restore. Each call decrements every wound by 1 level; parts at 0 are untouched.

---

## New status effects needed

Add to `Status.INFO` in `Status.gd`:

| id | effect |
|----|--------|
| `bleeding` | `ticks_hp: 1, element: ""` (physical, no resist) |
| `attack_penalty` | checked in `CombatSystem._player_weapon_damage` → `-2 per level` |
| `crippled` | `skip_move: true` (player loses free movement, can still attack/cast) |

`slow` already exists; `confused`, `weakened`, `blind` already exist.

`attack_penalty` is not a turn-skip status — CombatSystem reads `Status.has(player, "attack_penalty")` and subtracts a flat damage amount.

---

## UI

### HUD status icon row
`BodyPartSystem.active_wounds(player)` is called each HUD refresh. For each active wound, a `Label` node is appended to the status icon row:

- Level 1 (light): orange text, e.g. `[머리]`
- Level 2 (severe): red text, e.g. `[머리!]`

Labels are pooled/rebuilt the same way existing status icons are handled.

### StatusDialog mannequin overlay
In `_portrait_stack`, after existing layers:

```gdscript
_add_wound_overlay(layers, player.body_wounds)
```

`_add_wound_overlay` places semi-transparent `ColorRect` nodes over pre-defined UV regions of the 96×96 portrait:

| part | region (x, y, w, h) |
|------|---------------------|
| head | 32, 0, 32, 22 |
| torso | 24, 22, 48, 36 |
| arms | 0, 22, 24, 36 — mirrored right side |
| legs | 24, 58, 48, 38 |

Colors: `Color(1.0, 0.55, 0.1, 0.45)` light, `Color(0.9, 0.1, 0.1, 0.55)` severe.

---

## Out of scope (explicit non-goals)
- Per-body-part HP bars.
- Wound type (slash / crush / burn) — wound severity by damage magnitude only.
- Body part destruction / amputation.
- Wound textures / PNG icons (text labels only for now; icon paths stubbed as constants for later swap).

---

## Files touched
| File | Change |
|------|--------|
| `scripts/systems/BodyPartSystem.gd` | **new** |
| `scripts/systems/Status.gd` | add `bleeding`, `attack_penalty`, `crippled` to INFO |
| `scripts/systems/CombatSystem.gd` | `process_hit` calls at 4 attack paths |
| `scripts/entities/Player.gd` | `body_wounds` field + save/load + `reduce_wounds` hook |
| `scripts/entities/Monster.gd` | `body_wounds` field |
| `scripts/entities/MonsterData.gd` | `body_type` field |
| `scripts/ui/StatusDialog.gd` | `_add_wound_overlay` in portrait stack |
| `scripts/main/Game.gd` or HUD script | wound label row in status icon area |
