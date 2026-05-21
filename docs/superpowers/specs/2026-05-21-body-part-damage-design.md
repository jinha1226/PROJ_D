# Body Part Damage System — Design Spec
Date: 2026-05-21

## Overview
Cataclysm / Caves of Qud-style body part damage layer on top of PocketCrawl's existing single-HP-pool combat. Hit location is determined per attack using attacker position + defender facing direction; wounds accumulate in two levels (light → severe) and apply status effects via the existing `Status.gd` system. Applies to both Player and Monster via duck-typing.

---

## Architecture

### New file: `scripts/systems/BodyPartSystem.gd`
Static module, same pattern as `Status.gd`. No autoload needed.

**Key constants:**

```gdscript
# Body type → hit location config
# humanoid uses directional weights (see process_hit); base weights are neutral fallback.
const BODY_TYPES: Dictionary = {
    "humanoid": {
        "parts":   ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"],
        "weights": [10,     30,      15,         15,          15,         15]
    },
    "serpentine": {
        "parts":   ["head", "body"],
        "weights": [25,     75]
    },
    "flying": {
        "parts":   ["head", "body", "left_wing", "right_wing"],
        "weights": [20,     40,     20,          20]
    },
    "quadruped": {
        "parts":   ["head", "body", "left_leg", "right_leg"],
        "weights": [15,     45,     20,          20]
    },
}

# part → { level → [status_id:turns, ...] }
const WOUND_EFFECTS: Dictionary = {
    "head":       { 1: ["confused:3"],              2: ["confused:6", "blind:3"] },
    "torso":      { 1: ["bleeding:4"],              2: ["bleeding:8", "weakened:6"] },
    "left_arm":   { 1: ["attack_penalty:4"],        2: ["attack_penalty:8"] },
    "right_arm":  { 1: ["attack_penalty:4"],        2: ["attack_penalty:8"] },
    "left_leg":   { 1: ["slow:4"],                  2: ["slow:8", "crippled:4"] },
    "right_leg":  { 1: ["slow:4"],                  2: ["slow:8", "crippled:4"] },
    "body":       { 1: ["bleeding:4"],              2: ["bleeding:8", "weakened:4"] },
    "left_wing":  { 1: ["slow:3"],                  2: ["slow:6"] },
    "right_wing": { 1: ["slow:3"],                  2: ["slow:6"] },
}

# Maps a side tag to the parts it biases when hit from that direction.
# "front"  = attacker is in the direction the defender is facing
# "back"   = attacker is behind the defender
# "left"   = attacker is to the defender's left flank
# "right"  = attacker is to the defender's right flank
const DIRECTION_BIAS: Dictionary = {
    "front": {"head": 2.0, "torso": 1.5},
    "back":  {"torso": 1.5, "left_leg": 1.3, "right_leg": 1.3},
    "left":  {"left_arm": 2.5, "left_leg": 2.0},
    "right": {"right_arm": 2.5, "right_leg": 2.0},
}
```

**Public API:**

```gdscript
# Called from CombatSystem after final damage is resolved.
# attacker_pos: Vector2i map position of the attacker.
static func process_hit(defender, final_damage: int, attacker_pos: Vector2i) -> void

# Called from potion_healing / healing spells.
static func reduce_wounds(actor, levels: int = 1) -> void

# Returns Array of [part_id, level] pairs where level > 0. Used by UI.
static func active_wounds(actor) -> Array
```

**`process_hit` logic:**
1. Determine `body_type`: `MonsterData.body_type` for monsters, `"humanoid"` for Player.
2. Compute attack direction: `attack_vec = attacker_pos - defender.map_pos` → snap to 4-cardinal or 8-directional.
3. Compare attack direction to `defender.facing` → classify as `"front"` / `"back"` / `"left"` / `"right"`.
4. Apply `DIRECTION_BIAS` multipliers to base part weights → weighted random roll → hit `part`.
5. `wound_chance = float(final_damage) / float(defender.hp_max)`.
6. `if randf() < wound_chance`: upgrade `body_wounds[part]` by 1 (capped at 2).
7. Apply each status from `WOUND_EFFECTS[part][new_level]` via `Status.apply(defender, id, turns)`.
8. Log: `"Your [part] is [lightly/badly] wounded!"` for Player; silent for Monster.

---

## Facing direction

### `Player.gd`
```gdscript
var facing: Vector2i = Vector2i(1, 0)   # default: facing right
```
Updated in the movement handler: `facing = move_direction` whenever the player moves.

### `Monster.gd`
```gdscript
var facing: Vector2i = Vector2i(1, 0)
```
Updated in `MonsterAI` each time the monster steps: `monster.facing = step_direction`.

Both actors use `map_pos: Vector2i` which already exists in the codebase.

---

## Data model changes

### `Player.gd`
```gdscript
var body_wounds: Dictionary = {}   # part_id → 0/1/2
var facing: Vector2i = Vector2i(1, 0)
```
- `body_wounds` persisted in save data (`_collect_save_state` / `_apply_loaded_player_state`).
- `facing` not persisted (cosmetic, defaults on load).
- Both cleared on new run start.

### `MonsterData.gd`
```gdscript
var body_type: String = "humanoid"
```
- Default `"humanoid"` covers most existing monsters without `.tres` edits.
- Serpentine/flying/quadruped monsters updated in their `.tres` files as a follow-up pass.

### `Monster.gd`
```gdscript
var body_wounds: Dictionary = {}   # part_id → 0/1/2
var facing: Vector2i = Vector2i(1, 0)
```
- Not persisted (monsters don't survive floor transitions).

---

## CombatSystem integration

After `player.take_damage` / `monster.take_damage`, pass attacker map position:

```gdscript
# monster_attack_player
BodyPartSystem.process_hit(player, final, monster.map_pos)

# player_attack_monster
BodyPartSystem.process_hit(monster, final, player.map_pos)

# monster_ranged_attack_player
BodyPartSystem.process_hit(player, final, monster.map_pos)

# player ranged/backstab (attacker position already available)
BodyPartSystem.process_hit(monster, final, player.map_pos)
```

---

## Healing integration

`potion_healing` and `heal` spell: call `BodyPartSystem.reduce_wounds(player, 1)` after HP restore. Each call decrements every wound by 1 level; parts already at 0 are untouched.

---

## New status effects needed

Add to `Status.INFO` in `Status.gd`:

| id | effect |
|----|--------|
| `bleeding` | `ticks_hp: 1, element: ""` (physical, no resist) |
| `attack_penalty` | read in `CombatSystem` weapon damage calc → flat `-2` per stack |
| `crippled` | `skip_move: true` — player/monster cannot move but can still act |

`slow`, `confused`, `weakened`, `blind` already exist.

`attack_penalty` is not a turn-skip status — CombatSystem reads `Status.has(actor, "attack_penalty")` and subtracts a flat amount from outgoing damage.

---

## UI

### HUD status icon row
`BodyPartSystem.active_wounds(player)` called each HUD refresh. Per active wound, a `Label` appended to the status icon row:

- Level 1 (light): orange, e.g. `[좌팔]`
- Level 2 (severe): red, e.g. `[좌팔!]`

Part display names (Korean):

| part_id | label |
|---------|-------|
| head | 머리 |
| torso | 몸통 |
| left_arm | 좌팔 |
| right_arm | 우팔 |
| left_leg | 좌다리 |
| right_leg | 우다리 |
| body | 몸통 |
| left_wing | 좌날개 |
| right_wing | 우날개 |

### StatusDialog mannequin overlay
In `_portrait_stack`, after existing layers:

```gdscript
_add_wound_overlay(layers, player.body_wounds)
```

`_add_wound_overlay` places semi-transparent `ColorRect` nodes over pre-defined regions of the 96×96 portrait:

| part | region (x, y, w, h) |
|------|---------------------|
| head | 32, 0, 32, 22 |
| torso | 24, 22, 48, 36 |
| left_arm | 0, 22, 24, 36 |
| right_arm | 72, 22, 24, 36 |
| left_leg | 24, 58, 24, 38 |
| right_leg | 48, 58, 24, 38 |

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
| `scripts/systems/CombatSystem.gd` | `process_hit` calls at 4 attack paths (pass attacker map_pos) |
| `scripts/entities/Player.gd` | `body_wounds` + `facing` fields, save/load, heal hook |
| `scripts/entities/Monster.gd` | `body_wounds` + `facing` fields |
| `scripts/entities/MonsterData.gd` | `body_type: String` field |
| `scripts/systems/MonsterAI.gd` | update `monster.facing` on each step |
| `scripts/ui/StatusDialog.gd` | `_add_wound_overlay` in portrait stack |
| `scripts/main/Game.gd` or HUD script | wound label row in status icon area |
