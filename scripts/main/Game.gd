extends Node2D

const DungeonMapScene = preload("res://scripts/dungeon/DungeonMap.gd")
const PlayerScene = preload("res://scripts/entities/Player.gd")
const MonsterScene = preload("res://scripts/entities/Monster.gd")
const FloorItemScene = preload("res://scripts/entities/FloorItem.gd")
const TopHUDScene = preload("res://scenes/ui/TopHUD.tscn")
const BottomHUDScene = preload("res://scenes/ui/BottomHUD.tscn")
const ResultScreenScene = preload("res://scenes/ui/ResultScreen.tscn")
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const JOB_SELECT_PATH: String = "res://scenes/menu/JobSelect.tscn"

var map: DungeonMap
var player: Player
var items_layer: Node2D
var monsters_layer: Node2D
var camera: Camera2D
var ui_layer: CanvasLayer
var top_hud: TopHUD
var bottom_hud: BottomHUD
var log_strip: CombatLogStrip

func _ready() -> void:
	if not GameManager.run_in_progress:
		GameManager.start_new_run()
	_spawn_map()
	_spawn_items_layer()
	_spawn_monsters_layer()
	_spawn_player()
	if not GameManager.pending_player_state.is_empty():
		_apply_loaded_player_state(GameManager.pending_player_state)
		GameManager.pending_player_state = {}
	elif GameManager.depth <= 1:
		_apply_class_to_player(GameManager.selected_class_id)
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth))
	_spawn_camera()
	_spawn_ui()
	TurnManager.player_turn_started.connect(_on_player_turn_started)
	_update_hud()
	CombatLog.post("B%d — arrow/WASD to move, bump to attack, '>' descends." \
			% GameManager.depth, Color(0.7, 0.9, 1.0))

func _apply_class_to_player(class_id: String) -> void:
	var data: ClassData = ClassRegistry.get_by_id(class_id)
	if data == null:
		return
	player.hp_max = data.starting_hp
	player.hp = data.starting_hp
	player.mp_max = data.starting_mp
	player.mp = data.starting_mp
	player.strength = data.starting_str
	player.dexterity = data.starting_dex
	player.intelligence = data.starting_int
	if data.starting_weapon != "":
		player.items.append({"id": data.starting_weapon, "plus": 0})
		player.equipped_weapon_id = data.starting_weapon
	if data.starting_armor != "":
		player.items.append({"id": data.starting_armor, "plus": 0})
		player.equipped_armor_id = data.starting_armor
	player.refresh_ac_from_equipment()
	player.known_spells = data.starting_spells.duplicate()
	for id in _class_starter_items(class_id):
		player.items.append({"id": id, "plus": 0})
	CombatLog.post("You start as %s." % data.display_name,
		Color(0.85, 0.9, 1.0))

func _class_starter_items(class_id: String) -> Array:
	match class_id:
		"warrior":
			return ["potion_healing", "potion_healing"]
		"mage":
			return ["scroll_blinking", "scroll_blinking", "potion_healing"]
		"rogue":
			return ["potion_healing", "scroll_blinking"]
	return []

func _apply_loaded_player_state(data: Dictionary) -> void:
	player.hp = int(data.get("hp", 30))
	player.hp_max = int(data.get("hp_max", 30))
	player.mp = int(data.get("mp", 5))
	player.mp_max = int(data.get("mp_max", 5))
	player.ac = int(data.get("ac", 0))
	player.ev = int(data.get("ev", 5))
	player.wl = int(data.get("wl", 0))
	player.strength = int(data.get("str", 10))
	player.dexterity = int(data.get("dex", 10))
	player.intelligence = int(data.get("int", 10))
	player.xl = int(data.get("xl", 1))
	player.xp = int(data.get("xp", 0))
	player.gold = int(data.get("gold", 0))
	player.items = data.get("items", [])
	player.equipped_weapon_id = String(data.get("weapon", ""))
	player.equipped_armor_id = String(data.get("armor", ""))
	player.kills = int(data.get("kills", 0))
	player.last_killer = String(data.get("last_killer", ""))
	player.known_spells = data.get("known_spells", [])
	CombatLog.post("Run resumed. Floor B%d." % GameManager.depth,
		Color(0.7, 0.9, 1.0))

func _spawn_map() -> void:
	map = DungeonMapScene.new()
	map.name = "DungeonMap"
	map.reveal_all = false
	add_child(map)

func _spawn_items_layer() -> void:
	items_layer = Node2D.new()
	items_layer.name = "Items"
	add_child(items_layer)

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
	player.stats_changed.connect(_update_hud)
	player.item_dropped.connect(_on_item_dropped)

func _spawn_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.2, 1.2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 14.0
	add_child(camera)
	_center_camera_on_player(true)

func _spawn_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.name = "UI"
	ui_layer.layer = 10
	add_child(ui_layer)
	top_hud = TopHUDScene.instantiate()
	top_hud.name = "TopHUD"
	ui_layer.add_child(top_hud)
	bottom_hud = BottomHUDScene.instantiate()
	bottom_hud.name = "BottomHUD"
	ui_layer.add_child(bottom_hud)
	log_strip = CombatLogStrip.new()
	log_strip.name = "CombatLogStrip"
	log_strip.anchor_left = 0.0
	log_strip.anchor_right = 1.0
	log_strip.anchor_top = 1.0
	log_strip.anchor_bottom = 1.0
	log_strip.offset_top = -380.0
	log_strip.offset_bottom = -240.0
	log_strip.grow_horizontal = 2
	log_strip.grow_vertical = 0
	ui_layer.add_child(log_strip)
	bottom_hud.bag_pressed.connect(_on_bag_pressed)
	bottom_hud.status_pressed.connect(_on_status_pressed)
	bottom_hud.wait_pressed.connect(_on_wait_pressed)
	bottom_hud.menu_pressed.connect(_on_menu_pressed)
	bottom_hud.rest_pressed.connect(_on_rest_pressed)
	bottom_hud.skills_pressed.connect(_on_skills_pressed)
	bottom_hud.magic_pressed.connect(_on_magic_pressed)

func _floor_seed(depth: int) -> int:
	return GameManager.seed * 1009 + depth * 31

func _generate_floor(depth: int, map_seed: int) -> void:
	map.generate(map_seed)
	player.bind_map(map, map.spawn_pos)
	_spawn_items_for_floor(depth)
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

func _spawn_items_for_floor(depth: int) -> void:
	var count: int = randi_range(4, 8)
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(depth) ^ 0x3C3C3C3C
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 400:
		attempts += 1
		var p: Vector2i = map.random_floor_tile(rng)
		if not map.is_walkable(p):
			continue
		if p == player.grid_pos:
			continue
		if _item_at(p) != null:
			continue
		var data: ItemData = ItemRegistry.pick_by_depth(depth)
		if data == null:
			return
		_spawn_floor_item(data, p, 0)
		placed += 1

func _spawn_floor_item(data: ItemData, pos: Vector2i, plus: int) -> void:
	if items_layer == null:
		return
	var fi: FloorItem = FloorItemScene.new()
	items_layer.add_child(fi)
	fi.setup(data, map, pos, plus)

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

func _clear_floor_items() -> void:
	for n in get_tree().get_nodes_in_group("floor_items"):
		n.remove_from_group("floor_items")
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

func _update_hud() -> void:
	if top_hud == null or player == null:
		return
	top_hud.set_hp(player.hp, player.hp_max)
	top_hud.set_mp(player.mp, player.mp_max)
	top_hud.set_xp(player.xp, player.xp_to_next(), player.xl)
	top_hud.set_depth(GameManager.depth)
	top_hud.set_gold(player.gold)

func _on_player_moved(_new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()

func _on_player_turn_started() -> void:
	pass

func _on_player_died() -> void:
	CombatLog.post("You have died.", Color(1.0, 0.4, 0.4))
	var shards: int = max(1, GameManager.depth * 2 + player.xl * 3)
	GameManager.add_rune_shards(shards)
	GameManager.end_run("death")
	_show_result_screen(false, shards)

func _show_result_screen(victory: bool, shards: int) -> void:
	var res = ResultScreenScene.instantiate()
	ui_layer.add_child(res)
	var data: Dictionary = {
		"victory": victory,
		"depth": GameManager.depth,
		"kills": player.kills,
		"turns": TurnManager.turn_number,
		"shards_gained": shards,
		"shards_total": GameManager.rune_shards,
		"killer": player.last_killer,
	}
	res.show_result(data)
	if res.has_signal("retry_pressed"):
		res.retry_pressed.connect(_on_result_retry.bind(res))
	if res.has_signal("meta_pressed"):
		res.meta_pressed.connect(_on_result_meta.bind(res))

func _on_result_retry(res: Node) -> void:
	if is_instance_valid(res):
		res.queue_free()
	GameManager.selected_class_id = ""
	get_tree().change_scene_to_file(JOB_SELECT_PATH)

func _on_result_meta(res: Node) -> void:
	if is_instance_valid(res):
		res.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _on_stairs_down() -> void:
	GameManager.descend()
	CombatLog.post("You descend to B%d." % GameManager.depth,
		Color(0.6, 1.0, 1.0))
	_clear_monsters()
	_clear_floor_items()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth))
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _on_item_dropped(item_id: String, at_pos: Vector2i, plus: int) -> void:
	var data: ItemData = ItemRegistry.get_by_id(item_id)
	if data == null:
		return
	_spawn_floor_item(data, at_pos, plus)
	CombatLog.post("You drop %s." % data.display_name)

func _on_bag_pressed() -> void:
	if player == null:
		return
	BagDialog.open(player, self)

func _on_status_pressed() -> void:
	if player == null:
		return
	var dlg: GameDialog = GameDialog.create("Status")
	add_child(dlg)
	var body := dlg.body()
	for text in _status_lines():
		var lab := Label.new()
		lab.text = text
		lab.add_theme_font_size_override("font_size", 26)
		body.add_child(lab)

func _status_lines() -> Array:
	var w_data: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	var a_data: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
	return [
		"Level: %d  (XP %d / %d)" % [player.xl, player.xp, player.xp_to_next()],
		"HP: %d / %d" % [player.hp, player.hp_max],
		"MP: %d / %d" % [player.mp, player.mp_max],
		"STR %d  DEX %d  INT %d" % [player.strength, player.dexterity, player.intelligence],
		"AC %d  EV %d  WL %d" % [player.ac, player.ev, player.wl],
		"Weapon: %s" % (w_data.display_name if w_data != null else "(unarmed)"),
		"Armor: %s" % (a_data.display_name if a_data != null else "(none)"),
		"Gold: %d" % player.gold,
		"Depth: B%d" % GameManager.depth,
	]

func _on_wait_pressed() -> void:
	if player == null or not TurnManager.is_player_turn or player.hp <= 0:
		return
	player.wait_turn()
	TurnManager.end_player_turn()

func _on_rest_pressed() -> void:
	# Auto-rest until HP/MP full or a monster appears in view.
	if player == null:
		return
	if _monster_in_sight():
		CombatLog.post("Can't rest — enemy in sight.", Color(1.0, 0.7, 0.5))
		return
	var ticks: int = 0
	while ticks < 60 and player.hp < player.hp_max and player.hp > 0:
		player.wait_turn()
		TurnManager.end_player_turn(true)
		ticks += 1
		if _monster_in_sight():
			CombatLog.post("You stop resting — enemy spotted.",
				Color(1.0, 0.7, 0.5))
			break

func _monster_in_sight() -> bool:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and map.visible_tiles.has(n.grid_pos):
			return true
	return false

func _on_skills_pressed() -> void:
	CombatLog.post("Skills not yet implemented.", Color(0.7, 0.7, 0.7))

func _on_magic_pressed() -> void:
	if player == null:
		return
	MagicDialog.open(player, self)

func _on_menu_pressed() -> void:
	# Save on quit so Continue can pick up the run.
	if player != null and player.hp > 0:
		SaveManager.save_run(player, GameManager)
	GameManager.run_in_progress = false
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _monster_at(pos: Vector2i) -> Monster:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null

func _item_at(pos: Vector2i) -> FloorItem:
	for n in get_tree().get_nodes_in_group("floor_items"):
		if n is FloorItem and n.grid_pos == pos:
			return n
	return null
