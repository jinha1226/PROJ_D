class_name Monster extends Node2D

signal died(monster)
signal stats_changed
signal hit_taken(amount: int)

var data: MonsterData
var hp: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var status: Dictionary = {}
var last_known_player_pos: Vector2i = Vector2i(-1, -1)
var is_alerted: bool = false

var _map: DungeonMap
var _tex: Texture2D = null
var _font: Font

func _ready() -> void:
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
	MonsterAI.take_turn(self, _map)

func _tick_statuses() -> void:
	Status.tick_actor(self)

func is_wet() -> bool:
	return status.get("wet", 0) > 0

func apply_wet(turns: int = 4) -> void:
	status["wet"] = max(status.get("wet", 0), turns)

func try_move(dir: Vector2i) -> bool:
	var target: Vector2i = grid_pos + dir
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

func die() -> void:
	emit_signal("died", self)
	TurnManager.unregister_actor(self)
	remove_from_group("monsters")
	# Brief fade-out before freeing
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.12)
	tw.tween_callback(queue_free)

func _draw() -> void:
	if data == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager.use_tiles and _tex != null:
		draw_texture_rect(_tex, rect, false)
		return
	draw_string(_font, Vector2(6, DungeonMap.CELL_SIZE - 6),
		data.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
		data.glyph_color)
