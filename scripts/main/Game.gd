extends Node2D

const DungeonMapScene = preload("res://scripts/dungeon/DungeonMap.gd")
const PlayerScene = preload("res://scripts/entities/Player.gd")
const MonsterScene = preload("res://scripts/entities/Monster.gd")

const MONSTERS_PER_FLOOR: int = 6

var map: DungeonMap
var player: Player
var monsters_layer: Node2D
var camera: Camera2D

func _ready() -> void:
	_spawn_map()
	_spawn_monsters_layer()
	_spawn_player()
	_spawn_monsters()
	_spawn_camera()
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	_refresh_fov()
	CombatLog.post("Welcome. Arrow keys / WASD to move, bump to attack.",
		Color(0.7, 0.9, 1.0))

func _spawn_map() -> void:
	map = DungeonMapScene.new()
	map.name = "DungeonMap"
	map.reveal_all = false
	add_child(map)

func _spawn_monsters_layer() -> void:
	monsters_layer = Node2D.new()
	monsters_layer.name = "Monsters"
	add_child(monsters_layer)

func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	add_child(player)
	var spawn: Vector2i = map.find_spawn()
	player.bind_map(map, spawn)
	player.moved.connect(_on_player_moved)
	player.died.connect(_on_player_died)

func _spawn_monsters() -> void:
	var placed: int = 0
	var attempts: int = 0
	while placed < MONSTERS_PER_FLOOR and attempts < 500:
		attempts += 1
		var p := Vector2i(
			randi_range(1, DungeonMap.GRID_W - 2),
			randi_range(1, DungeonMap.GRID_H - 2))
		if not map.is_walkable(p):
			continue
		if p == player.grid_pos:
			continue
		if _chebyshev(p, player.grid_pos) < 5:
			continue  # don't spawn on top of player
		if _monster_at(p) != null:
			continue
		var data: MonsterData = MonsterRegistry.pick_by_depth(GameManager.depth)
		if data == null:
			return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		TurnManager.register_actor(m)
		placed += 1

func _spawn_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.6, 1.6)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 14.0
	add_child(camera)
	_center_camera_on_player()

func _center_camera_on_player() -> void:
	if player != null and camera != null:
		var cell_center: Vector2 = player.position + Vector2(
			DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
		camera.position = cell_center

func _refresh_fov() -> void:
	if player == null or map == null:
		return
	var vis: Dictionary = player.compute_fov()
	map.set_fov(vis)

func _on_player_moved(_new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()

func _on_player_turn_started() -> void:
	pass

func _on_player_died() -> void:
	CombatLog.post("You have died.", Color(1.0, 0.4, 0.4))
	GameManager.end_run("death")

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _monster_at(pos: Vector2i) -> Monster:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null
