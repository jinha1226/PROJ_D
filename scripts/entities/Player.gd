class_name Player extends Node2D

signal stats_changed
signal moved(new_pos: Vector2i)
signal died
signal stepped_on_stairs_down

@export var grid_pos: Vector2i = Vector2i(1, 1)

const SIGHT_RADIUS: int = 8
const TEX_PLAYER: Texture2D = preload(
	"res://assets/tiles/individual/player/base/human_m.png")

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

var _map: DungeonMap

func _ready() -> void:
	add_to_group("player")

func bind_map(map: DungeonMap, spawn: Vector2i) -> void:
	_map = map
	grid_pos = spawn
	position = _map.grid_to_world(grid_pos)
	queue_redraw()

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
	if _map.tile_at(grid_pos) == DungeonMap.Tile.STAIRS_DOWN:
		emit_signal("stepped_on_stairs_down")
		return  # regen will call end_player_turn or reset flow
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

func take_damage(amount: int, _source: String = "") -> void:
	hp = max(0, hp - amount)
	emit_signal("stats_changed")
	if hp <= 0:
		emit_signal("died")

func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)
	emit_signal("stats_changed")

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	draw_texture_rect(TEX_PLAYER, rect, false)
