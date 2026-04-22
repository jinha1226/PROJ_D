class_name Monster extends Node2D

signal died(monster)
signal stats_changed

var data: MonsterData
var hp: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var status: Dictionary = {}

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
	MonsterAI.take_turn(self, _map)

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
	if hp <= 0:
		die()

func die() -> void:
	emit_signal("died", self)
	TurnManager.unregister_actor(self)
	remove_from_group("monsters")
	queue_free()

func _draw() -> void:
	if data == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if _tex != null:
		draw_texture_rect(_tex, rect, false)
	else:
		draw_string(_font, Vector2(4, DungeonMap.CELL_SIZE - 6),
			data.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 4,
			data.glyph_color)
