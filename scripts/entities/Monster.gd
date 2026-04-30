class_name Monster extends Node2D

var TurnManager = null
var GameManager = null

signal died(monster)
signal stats_changed
signal hit_taken(amount: int)
signal awareness_changed(monster, aware: bool)

var data: MonsterData
var hp: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var status: Dictionary = {}
var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var is_alerted: bool = false
var is_aware: bool = false

var pending_energy: float = 0.0
## Telegraphed ability state: {name, tiles, damage, message} — fires next turn
var _ability_charge: Dictionary = {}

var is_ally: bool = false
var ally_turns_left: int = 0  # 0 = indefinite; > 0 counts down each player turn

var equipped_weapon_id: String = ""  # weapon the monster is carrying; dropped on death
var _summoned_once: bool = false      # summoner AI: fires only once per encounter

var _map: DungeonMap
var _tex: Texture2D = null
var _font: Font

func _ready() -> void:
	TurnManager = get_node_or_null("/root/TurnManager")
	GameManager = get_node_or_null("/root/GameManager")
	_font = ThemeDB.fallback_font
	add_to_group("monsters")

func setup(monster_data: MonsterData, map: DungeonMap, pos: Vector2i) -> void:
	data = monster_data
	hp = data.hp
	_map = map
	grid_pos = pos
	position = map.grid_to_world(pos)
	if data.tile_path != "":
		_tex = load(data.tile_path) as Texture2D
	queue_redraw()

func take_turn() -> void:
	if hp <= 0 or data == null or _map == null:
		return
	_tick_statuses()
	_tick_cloud_damage()
	if hp <= 0:
		return
	MonsterAI.take_turn(self, _map)

func _tick_cloud_damage() -> void:
	var cloud: Dictionary = _map.cloud_tiles.get(grid_pos, {})
	if not cloud.is_empty():
		var type: String = cloud.get("type", "fire")
		var dmg: int = 0
		match type:
			"fire":        dmg = randi_range(2, 4)
			"poison":      dmg = 1; Status.apply(self, "poison", 3)
			"cold":        dmg = randi_range(1, 3)
			"electricity": dmg = randi_range(1, 3)
			"lava":        dmg = randi_range(6, 10)
		if dmg > 0:
			take_damage(dmg)
			return
	var htype: String = _map.hazard_tiles.get(grid_pos, "")
	if htype == "lava":
		take_damage(randi_range(6, 10))
	elif htype == "shallow_water":
		apply_wet(3)

func _tick_statuses() -> void:
	Status.tick_actor(self)

func is_wet() -> bool:
	return status.get("wet", 0) > 0

func apply_wet(turns: int = 4) -> void:
	status["wet"] = max(status.get("wet", 0), turns)

func try_move(dir: Vector2i) -> bool:
	var target: Vector2i = grid_pos + dir
	if _map.tile_at(target) == DungeonMap.Tile.DOOR_CLOSED:
		_map.set_tile(target, DungeonMap.Tile.DOOR_OPEN)
		return true
	if not _map.is_walkable(target):
		return false
	grid_pos = target
	position = _map.grid_to_world(target)
	return true

func take_damage(amount: int) -> void:
	hp = max(0, hp - amount)
	emit_signal("stats_changed")
	hit_taken.emit(amount)
	# Red flash
	modulate = Color(1.0, 0.25, 0.25, 1.0)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.18)
	if hp <= 0:
		die()

func become_aware(player_pos: Vector2i) -> void:
	if is_aware:
		last_known_player_pos = player_pos
		is_alerted = true
		return
	is_aware = true
	is_alerted = true
	last_known_player_pos = player_pos
	awareness_changed.emit(self, true)
	queue_redraw()

func lose_awareness() -> void:
	if not is_aware:
		return
	is_aware = false
	awareness_changed.emit(self, false)
	queue_redraw()

func die() -> void:
	emit_signal("died", self)
	TurnManager.unregister_actor(self)
	remove_from_group("monsters")
	if not _ability_charge.is_empty() and _map != null:
		for t in _ability_charge.get("tiles", []):
			_map.warning_tiles.erase(t)
		_map.queue_redraw()
		_ability_charge = {}
	# Brief fade-out before freeing
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)

func _draw() -> void:
	if data == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	var tint: Color = Color(0.55, 1.0, 0.6) if is_ally else Color.WHITE
	if GameManager.use_tiles and _tex != null:
		draw_texture_rect(_tex, rect, false, tint)
	else:
		var glyph_col: Color = (tint * data.glyph_color) if is_ally else data.glyph_color
		draw_string(_font, Vector2(6, DungeonMap.CELL_SIZE - 6),
			data.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			glyph_col)
	if not is_aware and hp > 0:
		var center := Vector2(DungeonMap.CELL_SIZE * 0.5, 4.0)
		draw_circle(center, 5.0, Color(0.1, 0.15, 0.2, 0.85))
		draw_circle(center, 4.0, Color(0.9, 0.95, 1.0, 0.95))
		draw_string(_font, Vector2(center.x - 2.5, 8.5), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.15, 0.25, 0.45))
