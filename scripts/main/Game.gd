extends Node2D

const DungeonMapScene = preload("res://scripts/dungeon/DungeonMap.gd")
const PlayerScene = preload("res://scripts/entities/Player.gd")
const MonsterScene = preload("res://scripts/entities/Monster.gd")

var map: DungeonMap
var player: Player
var monsters_layer: Node2D
var camera: Camera2D

func _ready() -> void:
	if not GameManager.run_in_progress:
		GameManager.start_new_run()
	_spawn_map()
	_spawn_monsters_layer()
	_spawn_player()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth))
	_spawn_camera()
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	CombatLog.post("Welcome. Arrow keys / WASD to move, bump to attack. '>' descends.",
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
	player.moved.connect(_on_player_moved)
	player.died.connect(_on_player_died)
	player.stepped_on_stairs_down.connect(_on_stairs_down)

func _spawn_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.2, 1.2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 14.0
	add_child(camera)
	_center_camera_on_player(true)

func _floor_seed(depth: int) -> int:
	return GameManager.seed * 1009 + depth * 31

func _generate_floor(depth: int, map_seed: int) -> void:
	map.generate(map_seed)
	player.bind_map(map, map.spawn_pos)
	_spawn_monsters_for_floor(depth)
	_refresh_fov()

func _spawn_monsters_for_floor(depth: int) -> void:
	var count: int = _monster_count_for_depth(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(depth) ^ 0x5A5A5A5A
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = map.random_floor_tile(rng)
		if not map.is_walkable(p):
			continue
		if p == player.grid_pos:
			continue
		if _chebyshev(p, player.grid_pos) < 5:
			continue
		if _monster_at(p) != null:
			continue
		var data: MonsterData = MonsterRegistry.pick_by_depth(depth)
		if data == null:
			return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		TurnManager.register_actor(m)
		placed += 1

func _monster_count_for_depth(d: int) -> int:
	if d <= 5:
		return randi_range(8, 12)
	if d <= 15:
		return randi_range(15, 22)
	return randi_range(10, 18)

func _clear_monsters() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		TurnManager.unregister_actor(n)
		n.remove_from_group("monsters")
		n.queue_free()

func _refresh_fov() -> void:
	if player == null or map == null:
		return
	map.set_fov(player.compute_fov())

func _center_camera_on_player(snap: bool = false) -> void:
	if player == null or camera == null:
		return
	var cell_center: Vector2 = player.position + Vector2(
		DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	camera.position = cell_center
	if snap:
		camera.reset_smoothing()

func _on_player_moved(_new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()

func _on_player_turn_started() -> void:
	pass

func _on_player_died() -> void:
	CombatLog.post("You have died.", Color(1.0, 0.4, 0.4))
	GameManager.end_run("death")

func _on_stairs_down() -> void:
	GameManager.descend()
	CombatLog.post("You descend to floor %d." % GameManager.depth,
		Color(0.6, 1.0, 1.0))
	_clear_monsters()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth))
	_center_camera_on_player(true)
	# Descending is the player's action this turn; resume monster turn cycle.
	TurnManager.end_player_turn()

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _monster_at(pos: Vector2i) -> Monster:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null
