class_name Player
extends Node2D
## Player entity. Grid-based movement, melee combat, hooked into TurnManager.

signal moved(new_grid_pos: Vector2i)
signal died
signal attacked(target)
signal stats_changed
signal leveled_up(new_level: int)

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var stats: Stats
var base_stats: Stats
var job_id: String = ""
var race_id: String = ""
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
var skill_state: Dictionary = {}

# M1 dummy inventory — Array of Dictionary (FloorItem.as_dict()).
var items: Array = []
signal inventory_changed

const _CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
const _MOVE_TWEEN_DUR: float = 0.12
const _ATTACK_LUNGE_DUR: float = 0.08
var _sprite: CharacterSprite = null
var _walk_idle_timer: SceneTreeTimer = null
var _move_tween: Tween = null


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
	var preset_id := "%s_%s" % [job_id if job_id != "" else "barbarian", race_id if race_id != "" else "human"]
	var preset := LPCPresetLoader.load_with_fallback(preset_id, "barbarian_human")
	if preset.is_empty():
		push_error("Player: no preset available, sprite will be blank")
		return
	_sprite.load_character(preset)
	_sprite.set_direction("down")
	_sprite.play_anim("idle", true)


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
	_ensure_sprite()
	_load_sprite_preset()

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

	# [skill-agent] pick first weapon from starting_equipment.
	equipped_weapon_id = ""
	if job != null:
		for eq_id in job.starting_equipment:
			var sid: String = String(eq_id)
			if WeaponRegistry.is_weapon(sid):
				equipped_weapon_id = sid
				break

	stats_changed.emit()
	queue_redraw()


# [skill-agent] Swap the current weapon. Skill id update happens implicitly via
# WeaponRegistry lookup on next attack; we just re-emit stats_changed so HUDs
# refresh.
func equip_weapon(weapon_id: String) -> void:
	equipped_weapon_id = weapon_id
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
			print("Picked up: %s" % it.display_name)
			it.queue_free()
	inventory_changed.emit()


func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	match String(it.get("kind", "")):
		"potion":
			if stats != null:
				stats.HP = min(stats.hp_max, stats.HP + 20)
				stats_changed.emit()
		"scroll":
			print("Read scroll: %s" % it.get("name", ""))
		_:
			print("Used: %s" % it.get("name", ""))
	items.remove_at(index)
	inventory_changed.emit()


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
	fi.setup(grid_pos, String(it.get("id", "")), String(it.get("name", "")),
			String(it.get("kind", "junk")), it.get("color", Color(0.9, 0.9, 0.4)))


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
	_lunge_toward(delta)
	# [skill-agent] route through CombatSystem so skill levels are factored in.
	var skill_sys: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	CombatSystem.melee_attack(self, monster, skill_sys)
	attacked.emit(monster)
	TurnManager.end_player_turn()
	return monster


func _lunge_toward(delta: Vector2i) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	var home: Vector2 = Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)
	var push: Vector2 = Vector2(delta) * float(tile_size) * 0.35
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", home + push, _ATTACK_LUNGE_DUR)
	_move_tween.tween_property(self, "position", home, _ATTACK_LUNGE_DUR)


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
