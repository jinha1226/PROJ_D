class_name Player
extends Node2D
## Player entity. Grid-based movement, melee combat, hooked into TurnManager.

signal moved(new_grid_pos: Vector2i)
signal died
signal attacked(target)
signal stats_changed
signal leveled_up(new_level: int)
signal xp_changed(cur: int, to_next: int, level: int)
## Emitted when Scroll of Identification is used. GameBootstrap shows a
## picker popup that lets the player choose which inventory item to reveal.
signal identify_one_requested

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var stats: Stats
var base_stats: Stats
var job_id: String = ""
var race_id: String = ""
var job_res: JobData = null
var race_res: RaceData = null
var tile_size: int = 32
var is_alive: bool = true
var level: int = 1
var xp: int = 0
# XP required to reach (level+1) from current level. Linear ramp.
const _XP_PER_LEVEL: int = 100
const _HP_PER_LEVEL: int = 5
const _MP_PER_LEVEL: int = 3

# [skill-agent] equipped weapon + per-skill state (level/xp/training).
var equipped_weapon_id: String = ""
# Slot-keyed Dict: "chest"/"legs"/"boots"/"helm"/"gloves" → {id,name,ac,color,slot}
# Missing key = nothing in that slot.
var equipped_armor: Dictionary = {}
var skill_state: Dictionary = {}

# M1 dummy inventory — Array of Dictionary (FloorItem.as_dict()).
var items: Array = []
signal inventory_changed
# 4 quickslot ids — "" means empty. Filled automatically on pickup of
# the first unique consumable id, cleared when no matching inventory item
# remains. Drives BottomHUD's four quickslot buttons.
var quickslot_ids: Array[String] = ["", "", "", ""]
signal quickslots_changed

const _CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
const _MOVE_TWEEN_DUR: float = 0.12
const _ATTACK_LUNGE_DUR: float = 0.08
var _sprite: CharacterSprite = null
var _walk_idle_timer: SceneTreeTimer = null
var _move_tween: Tween = null
# Spriggan-style free-move counter: increments on each move, resets when
# the turn actually ends. With race.move_speed_mod=1, every other move
# is "free" (doesn't end the turn) — effectively double speed.
var _free_move_counter: int = 0


func _ready() -> void:
	# Player reacts to its turn but waits for input — does not auto-act.
	if TurnManager and not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)
	z_index = 10
	_ensure_sprite()
	_load_sprite_preset()
	if not attacked.is_connected(_on_self_attacked):
		attacked.connect(_on_self_attacked)
	if not died.is_connected(_on_self_died):
		died.connect(_on_self_died)


func _ensure_sprite() -> void:
	if _sprite != null:
		return
	_sprite = _CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	if _sprite:
		add_child(_sprite)


func _load_sprite_preset() -> void:
	if _sprite == null:
		return
	var preset: Dictionary = _compose_preset()
	if preset.is_empty():
		# Fallback to disk-based preset if composition failed.
		var fallback_id := "%s_%s" % [job_id if job_id != "" else "barbarian", race_id if race_id != "" else "human"]
		preset = LPCPresetLoader.load_with_fallback(fallback_id, "barbarian_human")
	if preset.is_empty():
		push_error("Player: no preset available, sprite will be blank")
		return
	_sprite.load_character(preset)
	_sprite.set_direction("down")
	_sprite.play_anim("idle", true)


## Build a CharacterSprite preset dict reflecting the player's CURRENT
## state (race + currently equipped weapon/armor), not their starting
## loadout. Called both at setup and whenever equipment changes so the
## sprite always matches what's worn.
func _compose_preset() -> Dictionary:
	if race_res == null and race_id != "":
		race_res = load("res://resources/races/%s.tres" % race_id) as RaceData
	if job_res == null and job_id != "":
		job_res = load("res://resources/jobs/%s.tres" % job_id) as JobData
	if race_res == null:
		return {}
	var equipment: Array = []
	# Racial visual: hair / beard / horns / ears.
	if race_res.hair_def != "":
		equipment.append({"def": race_res.hair_def, "variant": race_res.hair_color})
	if race_res.beard_def != "":
		equipment.append({"def": race_res.beard_def, "variant": race_res.beard_color})
	if race_res.horns_def != "":
		equipment.append({"def": race_res.horns_def, "variant": race_res.horns_color})
	if race_res.ears_def != "":
		equipment.append({"def": race_res.ears_def, "variant": race_res.ears_color})
	# Currently equipped weapon (if any).
	if equipped_weapon_id != "":
		equipment.append(_item_id_to_preset_entry(equipped_weapon_id))
	# Currently equipped armor pieces, slot by slot.
	for slot_dict in equipped_armor.values():
		var aid: String = String(slot_dict.get("id", ""))
		if aid != "":
			equipment.append(_item_id_to_preset_entry(aid))
	return {
		"id": "%s_%s" % [job_id, race_id],
		"body_def": race_res.body_def,
		"body_variant": "",
		"skin_tint": race_res.skin_tint,
		"equipment": equipment,
	}


func _item_id_to_preset_entry(item_id: String) -> Dictionary:
	# Weapons: no material variant; the weapon def has no variants.
	if WeaponRegistry.is_weapon(item_id):
		return {"def": item_id, "variant": ""}
	# Armor / clothing: default to brown material for leather tones.
	# Specific job tres files can override by embedding a "{id}|{color}" form
	# (e.g., "leather_chest|steel") which we split here.
	if "|" in item_id:
		var parts: PackedStringArray = item_id.split("|")
		return {"def": parts[0], "variant": parts[1]}
	return {"def": item_id, "variant": "brown"}


func _on_self_attacked(_target) -> void:
	if _sprite:
		_sprite.play_anim("slash", false)


func _on_self_died() -> void:
	if _sprite:
		_sprite.play_anim("hurt", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.3, 0.6)


func _on_player_turn_started() -> void:
	# No-op: player turn is driven by TouchInput.
	pass


func setup(gen: DungeonGenerator, start_pos: Vector2i, job: JobData, race: RaceData) -> void:
	generator = gen
	grid_pos = start_pos
	position = Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)
	job_id = job.id if job else ""
	race_id = race.id if race else ""
	job_res = job
	race_res = race
	_ensure_sprite()
	# Sprite preset is composed AFTER equipped_* fields are set below so the
	# starting gear actually appears. _load_sprite_preset call lives at the
	# end of setup().

	var s := Stats.new()
	var base_str: int = (race.base_str if race else 10) + (job.str_bonus if job else 0)
	var base_dex: int = (race.base_dex if race else 10) + (job.dex_bonus if job else 0)
	var base_int: int = (race.base_int if race else 10) + (job.int_bonus if job else 0)
	s.STR = base_str
	s.DEX = base_dex
	s.INT = base_int
	var hp_total: int = (race.hp_per_level if race else 5) * level + 10
	var mp_total: int = (race.mp_per_level if race else 3) * level + 5
	s.hp_max = hp_total
	s.HP = hp_total
	s.mp_max = mp_total
	s.MP = mp_total
	s.AC = 0
	s.EV = 0
	stats = s
	base_stats = s.clone()

	# Pick first weapon from starting_equipment. Every armor piece slots
	# itself by ArmorRegistry.slot_for so a job can start with chest+legs+
	# boots (or more) and they all stack.
	equipped_weapon_id = ""
	equipped_armor = {}
	if job != null:
		for eq_id in job.starting_equipment:
			var sid: String = String(eq_id)
			if WeaponRegistry.is_weapon(sid) and equipped_weapon_id == "":
				equipped_weapon_id = sid
			elif ArmorRegistry.is_armor(sid):
				var info: Dictionary = ArmorRegistry.get_info(sid)
				var slot: String = String(info.get("slot", "chest"))
				if not equipped_armor.has(slot):
					equipped_armor[slot] = info
	_recompute_defense()

	stats_changed.emit()
	queue_redraw()
	# Now compose the sprite preset with the starting weapon + armor applied.
	_load_sprite_preset()


# [skill-agent] Swap the current weapon. Skill id update happens implicitly via
# WeaponRegistry lookup on next attack; we just re-emit stats_changed so HUDs
# refresh. Returns the previously-equipped weapon id ("" if none). Also
# triggers a sprite-preset reload so the on-screen LPC layers update.
func equip_weapon(weapon_id: String) -> String:
	var prev: String = equipped_weapon_id
	equipped_weapon_id = weapon_id
	stats_changed.emit()
	_load_sprite_preset()
	return prev


## Equip an armor dict that includes a "slot" key. Replaces the prior armor
## in that slot, returning the displaced dict (empty if the slot was empty).
## Caller is responsible for putting the previous item back into inventory.
func equip_armor(armor: Dictionary) -> Dictionary:
	var slot: String = String(armor.get("slot", "chest"))
	var prev: Dictionary = equipped_armor.get(slot, {})
	equipped_armor[slot] = armor
	_recompute_defense()
	_load_sprite_preset()
	return prev


## Remove an armor slot's entry (e.g. for unequip). Returns the dict.
func unequip_armor_slot(slot: String) -> Dictionary:
	var prev: Dictionary = equipped_armor.get(slot, {})
	equipped_armor.erase(slot)
	_recompute_defense()
	_load_sprite_preset()
	return prev


func _recompute_defense() -> void:
	if stats == null:
		return
	var ac: int = 0
	if race_res != null:
		ac += race_res.base_ac
	for slot_dict in equipped_armor.values():
		ac += int(slot_dict.get("ac", 0))
	stats.AC = ac
	stats_changed.emit()


func get_current_weapon_skill() -> String:
	if equipped_weapon_id == "":
		return ""
	return WeaponRegistry.weapon_skill_for(equipped_weapon_id)


func apply_essence_bonuses(essences: Array) -> void:
	# Snapshot pre-recompute HP/MP to preserve current/max deltas.
	if base_stats == null:
		base_stats = stats.clone() if stats != null else Stats.new()
	var prev_hp: int = stats.HP if stats != null else base_stats.HP
	var prev_mp: int = stats.MP if stats != null else base_stats.MP
	var prev_hp_max: int = stats.hp_max if stats != null else base_stats.hp_max
	var new_stats: Stats = base_stats.clone()
	for e in essences:
		if e == null:
			continue
		new_stats.STR += e.str_bonus
		new_stats.DEX += e.dex_bonus
		new_stats.INT += e.int_bonus
		new_stats.hp_max += e.hp_bonus
		new_stats.AC += e.armor_bonus
		new_stats.EV += e.evasion_bonus
	# HP delta handling: grow current hp on hp_max increase; clamp on decrease.
	var hp_delta: int = new_stats.hp_max - prev_hp_max
	var new_hp: int = prev_hp + max(0, hp_delta)
	if new_hp > new_stats.hp_max:
		new_hp = new_stats.hp_max
	new_stats.HP = new_hp
	new_stats.MP = min(prev_mp, new_stats.mp_max)
	stats = new_stats
	stats_changed.emit()
	queue_redraw()


func try_move(delta: Vector2i) -> bool:
	if not is_alive:
		return false
	if generator == null:
		return false
	var target: Vector2i = grid_pos + delta
	# Check monster occupancy → attack instead.
	var monster: Node = _monster_at(target)
	if monster != null:
		try_attack_at(target)
		return false
	if not generator.is_walkable(target):
		return false
	grid_pos = target
	var target_px: Vector2 = Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)
	_tween_visual_to(target_px, _MOVE_TWEEN_DUR)
	_pickup_items_here()
	if _sprite:
		_sprite.face_toward(delta)
		_sprite.play_anim("walk", true)
		_walk_idle_timer = get_tree().create_timer(0.2)
		_walk_idle_timer.timeout.connect(_return_to_idle)
	moved.emit(grid_pos)
	# Spriggan / fast races: every move_speed_mod-th step is "free" — does
	# not end the player turn, so monsters don't get to act yet.
	var should_end_turn: bool = true
	if race_res != null and race_res.move_speed_mod > 0:
		_free_move_counter += 1
		if _free_move_counter <= race_res.move_speed_mod:
			should_end_turn = false
		else:
			_free_move_counter = 0
	if should_end_turn:
		TurnManager.end_player_turn()
	return true


func _tween_visual_to(target_px: Vector2, duration: float) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_px, duration)


func _pickup_items_here() -> void:
	for it in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(it):
			continue
		if it is FloorItem and it.grid_pos == grid_pos:
			items.append(it.as_dict())
			var shown: String = GameManager.display_name_for_item(
					it.item_id, it.display_name, it.kind) if GameManager != null else it.display_name
			print("Picked up: %s" % shown)
			_try_assign_quickslot(it.item_id, it.kind)
			it.queue_free()
	inventory_changed.emit()


## Fill the first empty quickslot with this consumable id, unless it's
## already quickslotted. Weapons/armor/junk don't go into quickslots.
func _try_assign_quickslot(id: String, kind: String) -> void:
	if kind != "potion" and kind != "scroll":
		return
	if quickslot_ids.has(id):
		return
	for i in quickslot_ids.size():
		if quickslot_ids[i] == "":
			quickslot_ids[i] = id
			quickslots_changed.emit()
			return


## Use the quickslotted consumable in the given slot. Returns true if an
## item was found and consumed. Auto-clears the slot when the last matching
## item is used.
func use_quickslot(index: int) -> bool:
	if index < 0 or index >= quickslot_ids.size():
		return false
	var id: String = quickslot_ids[index]
	if id == "":
		return false
	for i in items.size():
		if String(items[i].get("id", "")) == id:
			use_item(i)
			if not _inventory_contains(id):
				quickslot_ids[index] = ""
				quickslots_changed.emit()
			return true
	# No item of this id left — clear the stale slot.
	quickslot_ids[index] = ""
	quickslots_changed.emit()
	return false


func _inventory_contains(id: String) -> bool:
	for it in items:
		if String(it.get("id", "")) == id:
			return true
	return false


func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	var item_id: String = String(it.get("id", ""))
	var info: Dictionary = ConsumableRegistry.get_info(item_id)
	var consumed: bool = false
	if info.is_empty():
		# Unknown id — fall back to legacy kind heuristic.
		match String(it.get("kind", "")):
			"potion":
				if stats != null:
					stats.HP = min(stats.hp_max, stats.HP + 20)
					stats_changed.emit()
				consumed = true
			"scroll":
				print("Read scroll: %s" % it.get("name", ""))
				consumed = true
			_:
				print("Used: %s" % it.get("name", ""))
				consumed = true
	else:
		consumed = _apply_consumable_effect(info)
	if consumed:
		# Auto-identify on use so the player learns what each unknown
		# potion/scroll was.
		if GameManager != null:
			GameManager.identify(item_id)
		items.remove_at(index)
		inventory_changed.emit()
		# Using an item costs a turn.
		TurnManager.end_player_turn()


func _apply_consumable_effect(info: Dictionary) -> bool:
	match String(info.get("effect", "")):
		"heal":
			if stats == null:
				return false
			stats.HP = min(stats.hp_max, stats.HP + int(info.get("amount", 20)))
			stats_changed.emit()
			return true
		"restore_mp":
			if stats == null:
				return false
			stats.MP = min(stats.mp_max, stats.MP + int(info.get("amount", 20)))
			stats_changed.emit()
			return true
		"teleport_random":
			return _teleport_random()
		"blink":
			return _teleport_blink(4)
		"magic_mapping":
			var dmap: Node = get_tree().root.get_node_or_null("Game/DungeonLayer/DungeonMap")
			if dmap != null and dmap.has_method("reveal_all"):
				dmap.reveal_all()
				return true
			return false
		"identify_one":
			# Hand the choice off to the UI — GameBootstrap opens a picker.
			identify_one_requested.emit()
			return true
		_:
			print("Unknown consumable effect: %s" % info.get("effect"))
			return false


func _teleport_random() -> bool:
	if generator == null:
		return false
	var candidates: Array = []
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var p: Vector2i = Vector2i(x, y)
			if generator.is_walkable(p) and p != grid_pos:
				candidates.append(p)
	if candidates.is_empty():
		return false
	_teleport_to(candidates[randi() % candidates.size()])
	return true


func _teleport_blink(radius: int) -> bool:
	if generator == null:
		return false
	var candidates: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if max(abs(dx), abs(dy)) > radius:
				continue
			var p: Vector2i = grid_pos + Vector2i(dx, dy)
			if generator.is_walkable(p):
				candidates.append(p)
	if candidates.is_empty():
		return false
	_teleport_to(candidates[randi() % candidates.size()])
	return true


func _teleport_to(target: Vector2i) -> void:
	grid_pos = target
	position = Vector2(target.x * tile_size + tile_size / 2.0, target.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	moved.emit(grid_pos)


func drop_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	items.remove_at(index)
	inventory_changed.emit()
	var parent: Node = get_parent()
	if parent == null:
		return
	var fi: FloorItem = FloorItem.new()
	parent.add_child(fi)
	var extra: Dictionary = {}
	for k in it.keys():
		if k in ["id", "name", "kind", "color"]:
			continue
		extra[k] = it[k]
	fi.setup(grid_pos, String(it.get("id", "")), String(it.get("name", "")),
			String(it.get("kind", "junk")), it.get("color", Color(0.9, 0.9, 0.4)),
			extra)


func get_items() -> Array:
	return items


## Called on monster kill. Grants raw XP to the player level pool and
## promotes as many levels as the running total allows. Each level-up
## emits leveled_up so UI can pop the stat-choice dialog.
func grant_xp(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	xp += amount
	while xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		_apply_level_up_growth()
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_for_next_level(), level)


func xp_for_next_level() -> int:
	return _XP_PER_LEVEL * level


func _apply_level_up_growth() -> void:
	if stats == null:
		return
	stats.hp_max += _HP_PER_LEVEL
	stats.HP = stats.hp_max  # full heal on level up
	stats.mp_max += _MP_PER_LEVEL
	stats.MP = stats.mp_max
	stats_changed.emit()


## Called by the level-up popup with a chosen stat id ("STR"/"DEX"/"INT").
func apply_level_up_stat(stat: String) -> void:
	if stats == null:
		return
	match stat:
		"STR": stats.STR += 2
		"DEX": stats.DEX += 2
		"INT": stats.INT += 2
	stats_changed.emit()


func _return_to_idle() -> void:
	if _sprite:
		_sprite.play_anim("idle", true)


func try_attack_at(target_pos: Vector2i) -> Node:
	if not is_alive:
		return null
	var monster: Node = _monster_at(target_pos)
	if monster == null:
		return null
	# Chebyshev adjacency check.
	var dx: int = abs(target_pos.x - grid_pos.x)
	var dy: int = abs(target_pos.y - grid_pos.y)
	if max(dx, dy) > 1:
		return null
	var delta := Vector2i(sign(target_pos.x - grid_pos.x), sign(target_pos.y - grid_pos.y))
	if _sprite:
		_sprite.face_toward(delta)
	# Sprite slash animation carries the attack feel — no position lunge.
	# [skill-agent] route through CombatSystem so skill levels are factored in.
	var skill_sys: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	CombatSystem.melee_attack(self, monster, skill_sys)
	attacked.emit(monster)
	TurnManager.end_player_turn()
	return monster


func take_damage(amount: int) -> void:
	if not is_alive:
		return
	stats.HP -= amount
	if stats.HP <= 0:
		stats.HP = 0
		is_alive = false
		died.emit()
	elif _sprite:
		_sprite.play_anim("hurt", false)
	stats_changed.emit()


func _monster_at(p: Vector2i) -> Node:
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if "grid_pos" in m and m.grid_pos == p:
			return m
	return null
