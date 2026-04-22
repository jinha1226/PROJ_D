class_name Player extends Node2D

signal stats_changed
signal moved(new_pos: Vector2i)
signal died

@export var grid_pos: Vector2i = Vector2i(1, 1)

var hp: int = 30
var hp_max: int = 30
var mp: int = 5
var mp_max: int = 5
var ac: int = 0
var ev: int = 5
var wl: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var xl: int = 1
var xp: int = 0
var items: Array = []

const SIGHT_RADIUS: int = 8

var _map: DungeonMap
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	add_to_group("player")

func bind_map(map: DungeonMap, spawn: Vector2i) -> void:
	_map = map
	grid_pos = spawn
	position = _map.grid_to_world(grid_pos)

func _unhandled_input(event: InputEvent) -> void:
	if _map == null or hp <= 0:
		return
	if not TurnManager.is_player_turn:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var dir: Vector2i = _dir_for_key(event.keycode)
		if dir != Vector2i.ZERO:
			_try_move(dir)
			get_viewport().set_input_as_handled()

func _dir_for_key(k: int) -> Vector2i:
	match k:
		KEY_UP, KEY_W, KEY_K:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_J:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_H:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_L:
			return Vector2i(1, 0)
	return Vector2i.ZERO

func _try_move(dir: Vector2i) -> void:
	var target: Vector2i = grid_pos + dir
	var monster: Monster = _monster_at(target)
	if monster != null:
		CombatSystem.player_attack_monster(self, monster)
		TurnManager.end_player_turn()
		return
	if not _map.is_walkable(target):
		return
	grid_pos = target
	position = _map.grid_to_world(grid_pos)
	emit_signal("moved", grid_pos)
	emit_signal("stats_changed")
	TurnManager.end_player_turn()

func _monster_at(pos: Vector2i) -> Monster:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null

func compute_fov() -> Dictionary:
	if _map == null:
		return {}
	var is_opaque := func(p: Vector2i) -> bool: return _map.is_opaque(p)
	return FieldOfView.compute(grid_pos, SIGHT_RADIUS, is_opaque)

func take_damage(amount: int, source: String = "") -> void:
	hp = max(0, hp - amount)
	emit_signal("stats_changed")
	if hp <= 0:
		emit_signal("died")

func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)
	emit_signal("stats_changed")

func _draw() -> void:
	draw_string(_font,
		Vector2(2, DungeonMap.CELL_SIZE - 4),
		"@", HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 2,
		Color(1.0, 0.95, 0.5))
