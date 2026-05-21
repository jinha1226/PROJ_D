# Body Part Damage System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a CoQ/Cataclysm-style hit location + wound system that biases hit parts based on attacker position and defender facing direction, applies temporary status effects on wounding, and displays persistent wounds in HUD and mannequin overlay.

**Architecture:** New static module `BodyPartSystem.gd` (Status.gd pattern) owns all body-part logic. Player/Monster store `body_wounds: Dictionary` and `facing: Vector2i`. CombatSystem calls `BodyPartSystem.process_hit` after resolving final damage; UI reads `BodyPartSystem.active_wounds` each HUD refresh.

**Tech Stack:** GDScript 4, Godot 4.6. No test framework — verify with Tester character (race_id = "tester") and in-game combat log.

---

## File map

| File | Action |
|------|--------|
| `scripts/systems/Status.gd` | Add `bleeding`, `crippled` to INFO |
| `scripts/systems/BodyPartSystem.gd` | **CREATE** — core module |
| `scripts/entities/Player.gd` | `body_wounds` + `facing` fields, `_try_move` crippled block, save/load hook |
| `scripts/entities/Monster.gd` | `body_wounds` + `facing` fields, update `facing` in `try_move` |
| `scripts/entities/MonsterData.gd` | `body_type: String` field |
| `scripts/systems/CombatSystem.gd` | `process_hit` at 4 attack paths + arm penalty in damage calc |
| `scripts/core/SaveManager.gd` | Persist `body_wounds` in player save dict |
| `scripts/main/Game.gd` | Load `body_wounds` in `_apply_loaded_player_state`; call `set_wounds` in `_update_hud` |
| `scripts/ui/TopHUD.gd` | Add `set_wounds(wounds: Array)` |
| `scripts/ui/StatusDialog.gd` | Add `_add_wound_overlay` to portrait stack |

---

## Task 1 — Status.gd: add `bleeding` and `crippled`

**Files:**
- Modify: `scripts/systems/Status.gd:12-58`

- [ ] **Step 1: Open Status.gd and locate INFO dict**

  Read `scripts/systems/Status.gd` lines 12–58.

- [ ] **Step 2: Add two new entries after the last damage-over-time entry**

  After `"diseased"` entry (currently ends around line 20), add:

  ```gdscript
  "bleeding":     {"name": "Bleeding",     "color": Color(0.9, 0.25, 0.25),
      "ticks_hp": 1, "element": ""},
  "crippled":     {"name": "Crippled",     "color": Color(0.8, 0.45, 0.1)},
  ```

  `element: ""` means bleeding bypasses all resists. `crippled` has no auto-tick effect — Player._try_move reads it directly.

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/systems/Status.gd
  git commit -m "feat(status): add bleeding and crippled status types"
  ```

---

## Task 2 — Create `BodyPartSystem.gd`

**Files:**
- Create: `scripts/systems/BodyPartSystem.gd`

- [ ] **Step 1: Create the file with all constants**

  ```gdscript
  class_name BodyPartSystem extends RefCounted

  ## Hit-location, wound tracking, and wound-effect dispatch.
  ## Duck-types Player and Monster — both need grid_pos, facing, body_wounds, hp_max.

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
          "weights": [15,     45,     20,         20]
      },
  }

  ## part → { level(1 or 2) → [status_id:turns, ...] }
  ## Arm damage penalty is NOT a status — CombatSystem reads body_wounds directly.
  const WOUND_EFFECTS: Dictionary = {
      "head":       {1: ["confused:3"],              2: ["confused:6", "blind:3"]},
      "torso":      {1: ["bleeding:4"],              2: ["bleeding:8", "weakened:6"]},
      "left_arm":   {1: [],                          2: ["bleeding:3", "weakened:4"]},
      "right_arm":  {1: [],                          2: ["bleeding:3", "weakened:4"]},
      "left_leg":   {1: ["slow:4"],                  2: ["slow:8",  "crippled:4"]},
      "right_leg":  {1: ["slow:4"],                  2: ["slow:8",  "crippled:4"]},
      "body":       {1: ["bleeding:4"],              2: ["bleeding:8", "weakened:4"]},
      "left_wing":  {1: ["slow:3"],                  2: ["slow:6"]},
      "right_wing": {1: ["slow:3"],                  2: ["slow:6"]},
  }

  ## Direction → per-part weight multipliers.
  ## "front"  = attacker is in the direction defender is facing.
  ## "back"   = attacker is behind.
  ## "left"   = attacker is on defender's left flank.
  ## "right"  = attacker is on defender's right flank.
  const DIRECTION_BIAS: Dictionary = {
      "front": {"head": 2.0,  "torso": 1.5},
      "back":  {"torso": 1.5, "left_leg": 1.3, "right_leg": 1.3},
      "left":  {"left_arm": 2.5,  "left_leg": 2.0},
      "right": {"right_arm": 2.5, "right_leg": 2.0},
  }

  const PART_LABELS: Dictionary = {
      "head": "머리", "torso": "몸통",
      "left_arm": "좌팔", "right_arm": "우팔",
      "left_leg": "좌다리", "right_leg": "우다리",
      "body": "몸통", "left_wing": "좌날개", "right_wing": "우날개",
  }
  ```

- [ ] **Step 2: Add public API functions**

  Append to the same file:

  ```gdscript
  ## Called from CombatSystem after final damage is resolved.
  static func process_hit(defender, final_damage: int, attacker_pos: Vector2i) -> void:
      var body_type: String = "humanoid"
      if "data" in defender and defender.data != null and "body_type" in defender.data:
          body_type = String(defender.data.body_type)
      var bt: Dictionary = BODY_TYPES.get(body_type, BODY_TYPES["humanoid"])
      var side: String = _attack_side(defender, attacker_pos)
      var part: String = _weighted_part(bt, side)
      if part == "":
          return
      var wound_chance: float = float(final_damage) / float(max(1, int(defender.hp_max)))
      if randf() >= wound_chance:
          return
      var wounds: Dictionary = defender.body_wounds if "body_wounds" in defender else {}
      var current: int = int(wounds.get(part, 0))
      if current >= 2:
          return
      var new_level: int = current + 1
      wounds[part] = new_level
      if "body_wounds" in defender:
          defender.body_wounds = wounds
      var effects: Array = WOUND_EFFECTS.get(part, {}).get(new_level, [])
      for entry in effects:
          var parts2: Array = String(entry).split(":")
          if parts2.size() == 2:
              Status.apply(defender, parts2[0], int(parts2[1]))
      if defender is Player:
          var severity: String = "심하게" if new_level == 2 else "약간"
          var label: String = PART_LABELS.get(part, part)
          CombatLog.post("%s 부위가 %s 다쳤습니다!" % [label, severity],
              Color(1.0, 0.55, 0.3) if new_level == 1 else Color(0.9, 0.15, 0.15))

  ## Decrement every wound by `levels`. Called by healing items/spells.
  static func reduce_wounds(actor, levels: int = 1) -> void:
      if not ("body_wounds" in actor):
          return
      var wounds: Dictionary = actor.body_wounds
      for part in wounds.keys().duplicate():
          var val: int = max(0, int(wounds[part]) - levels)
          if val <= 0:
              wounds.erase(part)
          else:
              wounds[part] = val
      actor.body_wounds = wounds

  ## Returns [[part_id, level], ...] for all parts where level > 0. Used by UI.
  static func active_wounds(actor) -> Array:
      if not ("body_wounds" in actor):
          return []
      var result: Array = []
      for part in actor.body_wounds.keys():
          var lvl: int = int(actor.body_wounds[part])
          if lvl > 0:
              result.append([part, lvl])
      return result
  ```

- [ ] **Step 3: Add private helpers**

  Append to the same file:

  ```gdscript
  ## Classifies attacker direction relative to defender's facing.
  static func _attack_side(defender, attacker_pos: Vector2i) -> String:
      if not ("grid_pos" in defender) or not ("facing" in defender):
          return "front"
      var av: Vector2i = attacker_pos - defender.grid_pos
      if av == Vector2i.ZERO:
          return "front"
      var f: Vector2i = defender.facing
      var dot: int   = av.x * f.x + av.y * f.y
      var cross: int = av.x * f.y - av.y * f.x
      if absi(dot) >= absi(cross):
          return "front" if dot >= 0 else "back"
      return "left" if cross > 0 else "right"

  ## Weighted random part selection with direction bias applied.
  static func _weighted_part(bt: Dictionary, side: String) -> String:
      var parts: Array  = bt.get("parts", [])
      var weights: Array = bt.get("weights", [])
      if parts.is_empty():
          return ""
      var bias: Dictionary = DIRECTION_BIAS.get(side, {})
      var adjusted: Array = []
      var total: float = 0.0
      for i in parts.size():
          var w: float = float(weights[i] if i < weights.size() else 1)
          w *= float(bias.get(parts[i], 1.0))
          adjusted.append(w)
          total += w
      var roll: float = randf() * total
      var acc: float = 0.0
      for i in parts.size():
          acc += float(adjusted[i])
          if roll < acc:
              return parts[i]
      return parts[-1]
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/systems/BodyPartSystem.gd
  git commit -m "feat(combat): add BodyPartSystem static module"
  ```

---

## Task 3 — Player.gd: `body_wounds`, `facing`, crippled block

**Files:**
- Modify: `scripts/entities/Player.gd`

- [ ] **Step 1: Add fields near the top of Player.gd**

  Locate the block of `var` declarations around line 71–100 where `hp`, `resists`, `statuses` are defined. Add after `var statuses: Dictionary = {}`:

  ```gdscript
  var body_wounds: Dictionary = {}   # part_id → 1 (light) or 2 (severe)
  var facing: Vector2i = Vector2i(1, 0)
  ```

- [ ] **Step 2: Update facing in `_try_move`**

  In `_try_move` (around line 249), the block that moves the player is:
  ```gdscript
      grid_pos = target
      position = _map.grid_to_world(grid_pos)
  ```
  Change it to:
  ```gdscript
      grid_pos = target
      facing = dir
      position = _map.grid_to_world(grid_pos)
  ```

- [ ] **Step 3: Add crippled movement block in `_try_move`**

  After the `try_attack_tile(target)` early-return (around line 251), add:

  ```gdscript
      if Status.has(self, "crippled"):
          CombatLog.post("심한 부상으로 이동할 수 없습니다!", Color(1.0, 0.55, 0.3))
          return
  ```

  Full revised function head should look like:
  ```gdscript
  func _try_move(dir: Vector2i) -> void:
      var target: Vector2i = grid_pos + dir
      if try_attack_tile(target):
          return
      if Status.has(self, "crippled"):
          CombatLog.post("심한 부상으로 이동할 수 없습니다!", Color(1.0, 0.55, 0.3))
          return
      if _map.tile_at(target) == DungeonMap.Tile.DOOR_CLOSED:
          ...
  ```

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/entities/Player.gd
  git commit -m "feat(player): add body_wounds, facing fields and crippled movement block"
  ```

---

## Task 4 — Monster.gd + MonsterData.gd: `body_wounds`, `facing`, `body_type`

**Files:**
- Modify: `scripts/entities/Monster.gd`
- Modify: `scripts/entities/MonsterData.gd`

- [ ] **Step 1: Add fields to Monster.gd**

  Locate the `var` declarations near the top of `Monster.gd` (near `grid_pos`, `hp`). Add:

  ```gdscript
  var body_wounds: Dictionary = {}
  var facing: Vector2i = Vector2i(1, 0)
  ```

- [ ] **Step 2: Update `facing` in Monster.`try_move`**

  In `try_move` (line 87), the successful move block is:
  ```gdscript
      grid_pos = target
      position = _map.grid_to_world(target)
      return true
  ```
  Change to:
  ```gdscript
      grid_pos = target
      facing = dir
      position = _map.grid_to_world(target)
      return true
  ```

- [ ] **Step 3: Add `body_type` to MonsterData.gd**

  Locate `scripts/entities/MonsterData.gd`. Add after the existing exports/vars (find the group of String vars like `display_name`, `id`):

  ```gdscript
  var body_type: String = "humanoid"
  ```

  Default `"humanoid"` means all existing `.tres` monster files work without changes.

- [ ] **Step 4: Commit**

  ```bash
  git add scripts/entities/Monster.gd scripts/entities/MonsterData.gd
  git commit -m "feat(monster): add body_wounds, facing, body_type fields"
  ```

---

## Task 5 — CombatSystem.gd: `process_hit` calls + arm penalty

**Files:**
- Modify: `scripts/systems/CombatSystem.gd`

- [ ] **Step 1: Add arm penalty to `_player_attack_base_damage` (line ~84)**

  In `_player_attack_base_damage`, after `var raw: int = weapon_dmg + ...` (line 84) and before the `Status.has(player, "damage_boost")` check, insert:

  ```gdscript
      if "body_wounds" in player:
          var arm_penalty: int = (int(player.body_wounds.get("left_arm", 0))
              + int(player.body_wounds.get("right_arm", 0))) * 2
          raw = max(1, raw - arm_penalty)
  ```

- [ ] **Step 2: Wire `process_hit` after `monster.take_damage` in `player_attack_monster` (~line 151)**

  After `monster.take_damage(final)` (line 151), add:
  ```gdscript
      BodyPartSystem.process_hit(monster, final, player.grid_pos)
  ```

- [ ] **Step 3: Wire `process_hit` after `player.take_damage` in `monster_attack_player` (~line 393)**

  After `player.take_damage(final, monster.data.id)` in `monster_attack_player`, add:
  ```gdscript
      BodyPartSystem.process_hit(player, final, monster.grid_pos)
  ```

- [ ] **Step 4: Wire `process_hit` after `player.take_damage` in `monster_ranged_attack_player` (~line 393)**

  After `player.take_damage(final, monster.data.id)` in `monster_ranged_attack_player`, add:
  ```gdscript
      BodyPartSystem.process_hit(player, final, monster.grid_pos)
  ```

- [ ] **Step 5: Wire `process_hit` for player ranged — find player ranged attack path**

  Search for `player_ranged_attack_monster` or the archery path where `monster.take_damage` is called. After that call, add:
  ```gdscript
      BodyPartSystem.process_hit(monster, final, player.grid_pos)
  ```

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/systems/CombatSystem.gd
  git commit -m "feat(combat): wire BodyPartSystem.process_hit at 4 attack paths + arm penalty"
  ```

---

## Task 6 — Healing integration

**Files:**
- Modify: `scripts/entities/Player.gd`

- [ ] **Step 1: Find the `"heal"` case in `use_item` (~line 483)**

  The `"heal"` case currently calls `heal(heal_amt)` then logs. Add `BodyPartSystem.reduce_wounds(self, 1)` after the heal call:

  ```gdscript
              "heal":
                  var heal_amt: int = maxi(1, int(round(float(data.effect_value) * EssenceSystem.potion_heal_mult(self) * FaithSystem.potion_heal_mult(self))))
                  heal_amt += EssenceSystem.potion_heal_bonus(self)
                  heal(heal_amt)
                  BodyPartSystem.reduce_wounds(self, 1)
                  CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_BETTER_HP") % heal_amt,
                      Color(0.6, 1.0, 0.6))
  ```

- [ ] **Step 2: Add to `"bandage"` case (~line 489)**

  ```gdscript
              "bandage":
                  var heal_amt: int = 6
                  heal(heal_amt)
                  BodyPartSystem.reduce_wounds(self, 1)
                  CombatLog.post(LocaleManager.t("LOG_YOU_BANDAGE_YOUR_WOUNDS_HP") % heal_amt, Color(0.85, 0.9, 0.65))
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/entities/Player.gd
  git commit -m "feat(player): reduce body wounds on healing potion/bandage use"
  ```

---

## Task 7 — Save/load: persist `body_wounds`

**Files:**
- Modify: `scripts/core/SaveManager.gd`
- Modify: `scripts/main/Game.gd`

- [ ] **Step 1: Add `body_wounds` to SaveManager.save_run**

  In `save_run` (`scripts/core/SaveManager.gd`), inside the `"player"` dict (after `"faith_id"` / `"first_shrine_choice_done"`), add:

  ```gdscript
              "body_wounds": player.body_wounds,
  ```

- [ ] **Step 2: Load `body_wounds` in Game._apply_loaded_player_state**

  In `Game._apply_loaded_player_state` (`scripts/main/Game.gd`), after `player.statuses = data.get("statuses", {})`, add:

  ```gdscript
      player.body_wounds = data.get("body_wounds", {})
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/core/SaveManager.gd scripts/main/Game.gd
  git commit -m "feat(save): persist player body_wounds in save file"
  ```

---

## Task 8 — HUD: wound badges in TopHUD

**Files:**
- Modify: `scripts/ui/TopHUD.gd`
- Modify: `scripts/main/Game.gd`

- [ ] **Step 1: Add `set_wounds` function to TopHUD.gd**

  In `scripts/ui/TopHUD.gd`, add a `_wound_row` field at the top near `_buff_row`:

  ```gdscript
  var _wound_row: HFlowContainer = null
  ```

  In the same init block that creates `_buff_row` (around line 50), add immediately after:

  ```gdscript
          _wound_row = HFlowContainer.new()
          _wound_row.add_theme_constant_override("h_separation", 6)
          _wound_row.add_theme_constant_override("v_separation", 2)
          bars.add_child(_wound_row)
  ```

  Then add the function:

  ```gdscript
  func set_wounds(wounds: Array) -> void:
      if _wound_row == null:
          return
      for c in _wound_row.get_children():
          c.queue_free()
      for entry in wounds:
          var part_id: String = String(entry[0])
          var lvl: int = int(entry[1])
          var label: String = BodyPartSystem.PART_LABELS.get(part_id, part_id)
          var display: String = "[%s%s]" % [label, "!" if lvl >= 2 else ""]
          var col: Color = Color(0.9, 0.15, 0.15) if lvl >= 2 else Color(1.0, 0.55, 0.1)
          var badge := _make_buff_badge(display, -1, col)
          _wound_row.add_child(badge)
  ```

- [ ] **Step 2: Call `set_wounds` from `_update_hud` in Game.gd**

  In `_update_hud` (`scripts/main/Game.gd`, around line 1269), after `top_hud.set_buffs(player.statuses)`, add:

  ```gdscript
      top_hud.set_wounds(BodyPartSystem.active_wounds(player))
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/ui/TopHUD.gd scripts/main/Game.gd
  git commit -m "feat(hud): show wound badges in TopHUD buff row"
  ```

---

## Task 9 — StatusDialog: mannequin wound overlay

**Files:**
- Modify: `scripts/ui/StatusDialog.gd`

- [ ] **Step 1: Add `_add_wound_overlay` function**

  In `scripts/ui/StatusDialog.gd`, add after `_add_portrait_layer`:

  ```gdscript
  static func _add_wound_overlay(parent: Control, body_wounds: Dictionary) -> void:
      # UV regions for each part within the 96×96 portrait.
      const PART_RECTS: Dictionary = {
          "head":      Rect2(32,  0,  32, 22),
          "torso":     Rect2(24, 22,  48, 36),
          "left_arm":  Rect2( 0, 22,  24, 36),
          "right_arm": Rect2(72, 22,  24, 36),
          "left_leg":  Rect2(24, 58,  24, 38),
          "right_leg": Rect2(48, 58,  24, 38),
      }
      for part in body_wounds.keys():
          var lvl: int = int(body_wounds[part])
          if lvl <= 0 or not PART_RECTS.has(part):
              continue
          var r: Rect2 = PART_RECTS[part]
          var rect := ColorRect.new()
          rect.position = r.position
          rect.size = r.size
          rect.color = Color(0.9, 0.1, 0.1, 0.55) if lvl >= 2 else Color(1.0, 0.55, 0.1, 0.45)
          rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
          parent.add_child(rect)
  ```

- [ ] **Step 2: Call `_add_wound_overlay` in `_portrait_stack`**

  In `_portrait_stack` (around line 457), after the four `_add_portrait_layer` calls and before `return panel`, add:

  ```gdscript
      if player != null and "body_wounds" in player:
          _add_wound_overlay(layers, player.body_wounds)
  ```

- [ ] **Step 3: Commit**

  ```bash
  git add scripts/ui/StatusDialog.gd
  git commit -m "feat(ui): add wound color overlay to StatusDialog mannequin"
  ```

---

## Verification (Tester character)

After all tasks:

- [ ] Start a new run as **Tester** race.
- [ ] Enter combat. Watch the combat log — expect messages like `"좌팔 부위가 약간 다쳤습니다!"` when taking hits.
- [ ] Confirm orange wound badges appear in TopHUD buff row.
- [ ] Open StatusDialog → confirm colored rects appear on mannequin where wounds are.
- [ ] Use a healing potion — confirm wound level decreases (badge disappears or changes color).
- [ ] Take leg wound until `crippled` fires — confirm movement is blocked by log message, but attacking still works.
- [ ] Save and reload — confirm wounds persist after resume.
