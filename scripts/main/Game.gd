extends Node2D

const DungeonMapScene = preload("res://scripts/dungeon/DungeonMap.gd")
const PlayerScene = preload("res://scripts/entities/Player.gd")
const MonsterScene = preload("res://scripts/entities/Monster.gd")
const FloorItemScene = preload("res://scripts/entities/FloorItem.gd")
const TopHUDScene = preload("res://scenes/ui/TopHUD.tscn")
const BottomHUDScene = preload("res://scenes/ui/BottomHUD.tscn")
const ResultScreenScene = preload("res://scenes/ui/ResultScreen.tscn")
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"

var map: DungeonMap
var player: Player
var items_layer: Node2D
var monsters_layer: Node2D
var camera: Camera2D
var ui_layer: CanvasLayer
var top_hud: TopHUD
var bottom_hud: BottomHUD
var log_strip: CombatLogStrip
var _effect_layer: Node2D

var _targeting_spell: SpellData = null
var _targeting_tiles: Array = []
var _targeting_node: SpellTargetOverlay = null

# Auto-walk state — when the player taps a distant explored tile,
# we enqueue a BFS path here and step one tile each player turn
# until we hit the goal, an enemy enters view, or HP drops.
var _auto_path: Array = []
var _auto_prev_hp: int = 0
var _auto_known_ids: Dictionary = {}
# Set when ACT triggers continuous auto-explore; cleared on cancel or completion.
var _auto_exploring: bool = false
var _path_overlay: PathOverlay = null
var _auto_step_token: int = 0
var _auto_step_queued: bool = false

const AUTO_PATH_PREVIEW_SEC: float = 0.12
const AUTO_STEP_DELAY_SEC: float = 0.05

func _ready() -> void:
	if not GameManager.run_in_progress:
		GameManager.start_new_run()
	_spawn_map()
	_spawn_items_layer()
	_spawn_monsters_layer()
	_spawn_path_overlay()
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
	_refresh_quickslots()
	CombatLog.post("B%d — tap a tile (or arrows) to step, bump to attack." \
			% GameManager.depth, Color(0.7, 0.9, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if player == null or map == null or camera == null:
		return
	if player.hp <= 0:
		return
	var screen_pos: Vector2 = Vector2.ZERO
	var is_tap: bool = false
	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		is_tap = true
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		screen_pos = event.position
		is_tap = true
	if not is_tap:
		return
	# Any tap during auto-walk cancels it. The tap itself is then
	# processed as a fresh action (most commonly the same tile the
	# user already wanted).
	if not _auto_path.is_empty() or _auto_exploring:
		_cancel_auto_walk("tapped")
	if _targeting_spell != null:
		var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
		var world_pos: Vector2 = canvas_tf.affine_inverse() * screen_pos
		var tile: Vector2i = map.world_to_grid(world_pos)
		if _targeting_tiles.has(tile):
			_confirm_targeting()
		else:
			_cancel_targeting()
			CombatLog.post("Spell cancelled.", Color(0.65, 0.65, 0.65))
		get_viewport().set_input_as_handled()
		return
	if not TurnManager.is_player_turn:
		return
	_handle_tap(screen_pos)
	get_viewport().set_input_as_handled()

func _handle_tap(screen_pos: Vector2) -> void:
	# Convert screen → world via canvas transform (camera-aware).
	var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
	var world_pos: Vector2 = canvas_tf.affine_inverse() * screen_pos
	var target: Vector2i = map.world_to_grid(world_pos)
	if target == player.grid_pos:
		var tile: int = map.tile_at(player.grid_pos)
		if tile == DungeonMap.Tile.STAIRS_DOWN:
			_on_stairs_down()
		elif tile == DungeonMap.Tile.STAIRS_UP:
			_on_stairs_up()
		else:
			player.wait_turn()
			TurnManager.end_player_turn()
		return
	# Distant explored tile → auto-walk. Existing visible enemies don't
	# block the start (DCSS-style travel); a _new_ monster entering FOV
	# mid-walk halts it via _advance_auto_walk.
	var chebyshev: int = max(abs(target.x - player.grid_pos.x),
			abs(target.y - player.grid_pos.y))
	if chebyshev > 1 \
			and (map.explored.has(target) or map.visible_tiles.has(target)) \
			and map.is_walkable(target):
		var path: Array = _bfs_path(player.grid_pos, target)
		if path.size() > 0:
			_begin_auto_walk(path, false)
			return
	var dx: int = sign(target.x - player.grid_pos.x)
	var dy: int = sign(target.y - player.grid_pos.y)
	# Prefer diagonal only when the target is diagonal-ish; otherwise
	# snap to the dominant axis so tapping a distant corridor tile
	# walks straight rather than zig-zagging.
	if abs(target.x - player.grid_pos.x) > abs(target.y - player.grid_pos.y) * 2:
		dy = 0
	elif abs(target.y - player.grid_pos.y) > abs(target.x - player.grid_pos.x) * 2:
		dx = 0
	var dir: Vector2i = Vector2i(dx, dy)
	if dir == Vector2i.ZERO:
		return
	player.try_step(dir)

func _bfs_path(start: Vector2i, goal: Vector2i) -> Array:
	if start == goal:
		return []
	if not map.is_walkable(goal):
		return []
	var came_from: Dictionary = {start: start}
	var frontier: Array = [start]
	var dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		if p == goal:
			var path: Array = []
			var cur: Vector2i = goal
			while cur != start:
				path.append(cur)
				cur = came_from[cur]
			path.reverse()
			return path
		for d in dirs:
			var n: Vector2i = p + d
			if came_from.has(n):
				continue
			if not map.in_bounds(n) or not map.is_walkable(n):
				continue
			if not map.explored.has(n) and not map.visible_tiles.has(n):
				continue
			came_from[n] = p
			frontier.append(n)
	return []

func _advance_auto_walk() -> void:
	if _auto_path.is_empty():
		return
	if _new_monster_in_sight():
		_cancel_auto_walk("new enemy")
		return
	if player.hp < _auto_prev_hp:
		_cancel_auto_walk("took damage")
		return
	var next: Vector2i = _auto_path[0]
	var dir: Vector2i = next - player.grid_pos
	if abs(dir.x) > 1 or abs(dir.y) > 1:
		_cancel_auto_walk("path broken")
		return
	_auto_path.remove_at(0)
	if _path_overlay != null:
		_path_overlay.set_path(_auto_path)
	_auto_prev_hp = player.hp
	player.try_step(dir)

func _begin_auto_walk(path: Array, keep_exploring: bool) -> void:
	if path.is_empty():
		return
	_auto_step_token += 1
	_auto_step_queued = false
	_auto_path = path
	_auto_exploring = keep_exploring
	if _path_overlay != null:
		_path_overlay.set_path(_auto_path)
	_auto_prev_hp = player.hp
	_auto_known_ids = _snapshot_visible_monster_ids()
	_queue_auto_walk_step(AUTO_PATH_PREVIEW_SEC)

func _queue_auto_walk_step(delay_sec: float = AUTO_STEP_DELAY_SEC) -> void:
	if _auto_path.is_empty() or _auto_step_queued:
		return
	_auto_step_queued = true
	var token: int = _auto_step_token
	_defer_auto_walk_step(token, delay_sec)

func _defer_auto_walk_step(token: int, delay_sec: float) -> void:
	await get_tree().create_timer(delay_sec).timeout
	if token != _auto_step_token:
		return
	_auto_step_queued = false
	if _auto_path.is_empty() or not TurnManager.is_player_turn:
		return
	_advance_auto_walk()

func _snapshot_visible_monster_ids() -> Dictionary:
	var out: Dictionary = {}
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and map.visible_tiles.has(n.grid_pos):
			out[n.get_instance_id()] = true
	return out

func _new_monster_in_sight() -> bool:
	for n in get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not map.visible_tiles.has(n.grid_pos):
			continue
		if not _auto_known_ids.has(n.get_instance_id()):
			return true
	return false

func _cancel_auto_walk(reason: String) -> void:
	if _auto_path.is_empty() and not _auto_exploring:
		return
	_auto_step_token += 1
	_auto_step_queued = false
	_auto_path.clear()
	if _path_overlay != null:
		_path_overlay.set_path([])
	_auto_exploring = false
	_auto_known_ids.clear()
	if reason == "new enemy":
		CombatLog.post("You stop — enemy approaches.", Color(1.0, 0.7, 0.5))

func _apply_class_to_player(class_id: String) -> void:
	var data: ClassData = ClassRegistry.get_by_id(class_id)
	if data == null:
		return
	player.strength = data.starting_str
	player.dexterity = data.starting_dex
	player.intelligence = data.starting_int
	player.hp_max = data.starting_hp + data.starting_str / 2
	player.hp = player.hp_max
	player.mp_max = data.starting_mp
	player.mp = data.starting_mp
	_apply_race_mods(GameManager.selected_race_id)
	player.set_race_from_id(GameManager.selected_race_id)
	if data.starting_weapon != "":
		player.items.append({"id": data.starting_weapon, "plus": 0})
		player.equipped_weapon_id = data.starting_weapon
	if data.starting_armor != "":
		player.items.append({"id": data.starting_armor, "plus": 0})
		player.equipped_armor_id = data.starting_armor
	player.init_skills()
	for skill_id in data.starting_skills.keys():
		player.skills[skill_id]["level"] = int(data.starting_skills[skill_id])
	if data.starting_xl > 0:
		player.xl = data.starting_xl
	player.refresh_ac_from_equipment()
	player._refresh_paperdoll()
	player.known_spells = data.starting_spells.duplicate()
	for id in _class_starter_items(class_id):
		player.items.append({"id": id, "plus": 0})
		player.auto_bind_quickslot(id)
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	var race_name: String = race.display_name if race != null else "adventurer"
	CombatLog.post("You start as %s %s." % [race_name, data.display_name],
		Color(0.85, 0.9, 1.0))

func _apply_race_mods(race_id: String) -> void:
	var race: RaceData = RaceRegistry.get_by_id(race_id)
	if race == null:
		return
	player.strength = max(1, player.strength + race.str_mod)
	player.dexterity = max(1, player.dexterity + race.dex_mod)
	player.intelligence = max(1, player.intelligence + race.int_mod)
	player.hp_max = max(1, player.hp_max + race.hp_mod)
	player.hp = player.hp_max
	player.mp_max = max(0, player.mp_max + race.mp_mod)
	player.mp = player.mp_max
	player.resists = race.resist_mods.duplicate()
	RacePassiveSystem.register(player)

func _class_starter_items(class_id: String) -> Array:
	match class_id:
		"warrior":
			return ["potion_healing", "potion_healing"]
		"mage":
			return ["scroll_blinking", "scroll_blinking", "potion_healing"]
		"rogue":
			return ["potion_healing", "scroll_blinking"]
		"archmage":
			return [
				"potion_healing", "potion_healing", "potion_healing",
				"potion_might", "potion_might",
				"potion_cure_poison", "potion_cure_poison",
				"potion_magic", "potion_magic",
				"potion_berserk",
				"scroll_blinking", "scroll_blinking",
				"scroll_magic_mapping", "scroll_magic_mapping",
				"scroll_teleport", "scroll_teleport",
				"scroll_enchant_weapon", "scroll_enchant_weapon",
				"scroll_enchant_armor", "scroll_enchant_armor",
				"scroll_identify", "scroll_identify",
			]
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
	var ring_id: String = String(data.get("ring", ""))
	if ring_id != "":
		player._apply_accessory_stat(ring_id)
	player.equipped_ring_id = ring_id
	var amulet_id: String = String(data.get("amulet", ""))
	if amulet_id != "":
		player._apply_accessory_stat(amulet_id)
	player.equipped_amulet_id = amulet_id
	var shield_id: String = String(data.get("shield", ""))
	if shield_id != "":
		var sh: ItemData = ItemRegistry.get_by_id(shield_id)
		if sh != null:
			player.ev = maxi(0, player.ev - sh.ev_penalty)
	player.equipped_shield_id = shield_id
	player.kills = int(data.get("kills", 0))
	player.last_killer = String(data.get("last_killer", ""))
	player.known_spells = data.get("known_spells", [])
	# Migrate old spell IDs that no longer exist in SpellRegistry.
	var _spell_remap: Dictionary = {"magic_dart": "magic_missile", "blink": "", "heal_wounds": ""}
	var _migrated: Array = []
	for _sid: String in player.known_spells:
		var _resolved: String = _sid
		if _spell_remap.has(_sid):
			_resolved = _spell_remap[_sid]
		if _resolved != "" and SpellRegistry.get_by_id(_resolved) != null:
			_migrated.append(_resolved)
	player.known_spells = _migrated
	if player.known_spells.is_empty():
		var cls: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
		if cls != null:
			player.known_spells = cls.starting_spells.duplicate()
	player.statuses = data.get("statuses", {})
	player.resists = data.get("resists", [])
	player.skills = data.get("skills", {})
	if player.skills.is_empty():
		player.init_skills()
	var saved_qs = data.get("quickslots", null)
	if saved_qs is Array:
		for i in range(min(int(saved_qs.size()), player.quickslots.size())):
			player.quickslots[i] = String(saved_qs[i])
	var saved_es = data.get("essence_slots", null)
	if saved_es is Array:
		for i in range(mini(int(saved_es.size()), player.essence_slots.size())):
			var eid: String = String(saved_es[i])
			player.essence_slots[i] = eid
			if eid != "":
				EssenceSystem.apply(player, eid)
	var saved_ei = data.get("essence_inventory", null)
	if saved_ei is Array:
		player.essence_inventory = saved_ei.duplicate()
	player.set_race_from_id(GameManager.selected_race_id)
	RacePassiveSystem.register(player)
	player._refresh_paperdoll()
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

func _spawn_path_overlay() -> void:
	_path_overlay = PathOverlay.new()
	_path_overlay.name = "PathOverlay"
	_path_overlay.z_index = 4
	add_child(_path_overlay)

func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	add_child(player)
	player.moved.connect(_on_player_moved)
	player.died.connect(_on_player_died)
	player.stats_changed.connect(_update_hud)
	player.item_dropped.connect(_on_item_dropped)
	player.damaged.connect(_on_player_damaged)

const ZOOM_MIN: float = 0.7
const ZOOM_MAX: float = 2.2
const ZOOM_STEP: float = 0.2

func _spawn_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.2, 1.2)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 14.0
	add_child(camera)
	_center_camera_on_player(true)

func _zoom_by(delta: float) -> void:
	if camera == null:
		return
	var new_zoom: float = clamp(camera.zoom.x + delta, ZOOM_MIN, ZOOM_MAX)
	camera.zoom = Vector2(new_zoom, new_zoom)

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
	bottom_hud.rest_pressed.connect(_on_rest_pressed)
	bottom_hud.act_pressed.connect(_on_act_pressed)
	bottom_hud.menu_pressed.connect(_on_menu_pressed)
	bottom_hud.skills_pressed.connect(_on_skills_pressed)
	bottom_hud.magic_pressed.connect(_on_magic_pressed)
	bottom_hud.quickslot_pressed.connect(_on_quickslot_pressed)
	bottom_hud.quickslot_long_pressed.connect(_on_quickslot_long_pressed)
	if top_hud.has_signal("zoom_in_pressed"):
		top_hud.zoom_in_pressed.connect(func(): _zoom_by(ZOOM_STEP))
	if top_hud.has_signal("zoom_out_pressed"):
		top_hud.zoom_out_pressed.connect(func(): _zoom_by(-ZOOM_STEP))
	if top_hud.has_signal("minimap_pressed"):
		top_hud.minimap_pressed.connect(_on_minimap_tapped)
	log_strip.tapped.connect(_on_log_tapped)
	_effect_layer = Node2D.new()
	_effect_layer.name = "EffectLayer"
	_effect_layer.z_index = 5
	add_child(_effect_layer)
	_refresh_quickslots()


func _floor_seed(depth: int) -> int:
	return GameManager.seed * 1009 + depth * 31

func _generate_floor(depth: int, map_seed: int,
		arrive_from_above: bool = true) -> void:
	if GameManager.floor_cache.has(depth):
		_restore_floor_from_cache(depth, arrive_from_above)
	else:
		map.generate(map_seed)
		player.bind_map(map, map.spawn_pos)
		_spawn_items_for_floor(depth)
		_spawn_monsters_for_floor(depth)
	_refresh_fov()

func _cache_current_floor() -> void:
	if map == null or GameManager == null:
		return
	var state: Dictionary = {
		"tiles": PackedByteArray(map.tiles),
		"explored": map.explored.duplicate(true),
		"spawn_pos": map.spawn_pos,
		"stairs_down_pos": map.stairs_down_pos,
		"stairs_up_pos": map.stairs_up_pos,
		"rooms": map.rooms.duplicate(),
		"items": [],
		"monsters": [],
	}
	for n in get_tree().get_nodes_in_group("floor_items"):
		if n is FloorItem and n.data != null:
			state.items.append({
				"id": n.data.id,
				"pos": n.grid_pos,
				"plus": n.plus,
			})
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.data != null and n.hp > 0:
			state.monsters.append({
				"id": n.data.id,
				"pos": n.grid_pos,
				"hp": n.hp,
				"status": n.status.duplicate(),
			})
	GameManager.floor_cache[GameManager.depth] = state

func _restore_floor_from_cache(depth: int, arrive_from_above: bool) -> void:
	var state: Dictionary = GameManager.floor_cache[depth]
	map.tiles = state.tiles
	map.explored = state.explored.duplicate(true)
	map.spawn_pos = state.spawn_pos
	map.stairs_down_pos = state.stairs_down_pos
	map.stairs_up_pos = state.stairs_up_pos
	map.rooms = state.rooms.duplicate()
	map.visible_tiles.clear()
	map._load_atmosphere(depth)
	map.queue_redraw()
	var arrival: Vector2i = map.stairs_up_pos if arrive_from_above \
			else map.stairs_down_pos
	player.bind_map(map, arrival)
	for entry in state.items:
		var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", "")))
		if d == null:
			continue
		var p: Vector2i = entry.get("pos", Vector2i.ZERO)
		if p == player.grid_pos:
			continue  # Don't spawn item under player on arrival.
		_spawn_floor_item(d, p, int(entry.get("plus", 0)))
	for entry in state.monsters:
		var md: MonsterData = MonsterRegistry.get_by_id(
				String(entry.get("id", "")))
		if md == null:
			continue
		var p: Vector2i = entry.get("pos", Vector2i.ZERO)
		if p == player.grid_pos:
			continue  # Skip monster that would spawn on top of player.
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(md, map, p)
		m.hp = int(entry.get("hp", md.hp))
		m.status = entry.get("status", {}).duplicate()
		if m.has_signal("hit_taken"):
			m.hit_taken.connect(_on_monster_hit.bind(m))
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)

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
		m.hit_taken.connect(_on_monster_hit.bind(m))
		m.died.connect(_on_monster_died.bind(m))
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
	_update_minimap()
	_refresh_entity_visibility()

func _refresh_entity_visibility() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster:
			n.visible = map.visible_tiles.has(n.grid_pos)
	for n in get_tree().get_nodes_in_group("floor_items"):
		if n is FloorItem:
			n.visible = map.explored.has(n.grid_pos)

func _update_minimap() -> void:
	if map == null or player == null:
		return
	var tex: ImageTexture = MinimapRenderer.render(map, player, self)
	if top_hud != null:
		top_hud.set_minimap_texture(tex)

func _on_minimap_tapped() -> void:
	if map == null or player == null:
		return
	_cache_current_floor()
	const MAP_SCALE: int = 6
	var tex: ImageTexture = MinimapRenderer.render(map, player, self, MAP_SCALE)
	var dlg: GameDialog = GameDialog.create_ratio("Map", 0.96, 0.96)
	add_child(dlg)
	var body := dlg.body()
	if body == null:
		return

	var map_rect := TextureRect.new()
	map_rect.texture = tex
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	body.add_child(map_rect)

	map_rect.gui_input.connect(func(ev: InputEvent) -> void:
		var is_press := false
		if ev is InputEventScreenTouch and ev.pressed:
			is_press = true
		elif ev is InputEventMouseButton \
				and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			is_press = true
		if not is_press:
			return
		var local_pos := map_rect.get_local_mouse_position()
		var gx := int(local_pos.x * DungeonMap.GRID_W / map_rect.size.x)
		var gy := int(local_pos.y * DungeonMap.GRID_H / map_rect.size.y)
		var nav_target := Vector2i(gx, gy)
		if not map.in_bounds(nav_target) or not map.explored.has(nav_target) \
				or not map.is_walkable(nav_target) or nav_target == player.grid_pos:
			return
		dlg.close()
		var nav_path := _bfs_path(player.grid_pos, nav_target)
		if nav_path.size() > 0:
			_begin_auto_walk(nav_path, false)
	)

	var is_archmage: bool = GameManager.selected_class_id == "archmage"
	var all_depths: Array
	if is_archmage:
		all_depths = []
		for d in range(1, 26):
			all_depths.append(d)
	else:
		all_depths = GameManager.floor_cache.keys().duplicate()
		all_depths.sort()
	if all_depths.size() > 1:
		# Add floor nav as a footer outside the scrollable body.
		var window_vbox: VBoxContainer = dlg.get_node_or_null(
				"Dim/Window/Margin/VBox") as VBoxContainer
		var footer_target: Node = window_vbox if window_vbox != null else body
		var floor_header: Label = UICards.section_header("FLOORS", 24)
		footer_target.add_child(floor_header)
		if window_vbox != null:
			window_vbox.move_child(floor_header, window_vbox.get_child_count() - 2)
		var floor_row := HBoxContainer.new()
		floor_row.add_theme_constant_override("separation", 6)
		floor_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		footer_target.add_child(floor_row)
		if window_vbox != null:
			window_vbox.move_child(floor_row, window_vbox.get_child_count() - 2)
		for d in all_depths:
			var is_current: bool = (d == GameManager.depth)
			var fbtn := Button.new()
			fbtn.text = "B%d" % d
			fbtn.custom_minimum_size = Vector2(80, 52)
			fbtn.add_theme_font_size_override("font_size", 22)
			if is_current:
				fbtn.disabled = true
			else:
				var target_d: int = d
				fbtn.pressed.connect(func():
					dlg.close()
					_travel_to_floor(target_d))
			floor_row.add_child(fbtn)

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
	top_hud.set_turn(TurnManager.turn_number)

func _on_player_moved(_new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()
	_refresh_quickslots()

func _on_player_turn_started() -> void:
	if player != null and player.hp > 0:
		player.tick_statuses()
		RacePassiveSystem.on_player_turn_end(player)
	if not _auto_path.is_empty():
		_queue_auto_walk_step()
	elif _auto_exploring:
		_start_auto_explore()

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
	GameManager.selected_race_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)

func _on_result_meta(res: Node) -> void:
	if is_instance_valid(res):
		res.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _on_stairs_down() -> void:
	_cancel_auto_walk("stairs")
	_cache_current_floor()
	GameManager.descend()
	CombatLog.post("You descend to B%d." % GameManager.depth,
		Color(0.6, 1.0, 1.0))
	_clear_monsters()
	_clear_floor_items()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth), true)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _on_stairs_up() -> void:
	if GameManager.depth <= 1:
		CombatLog.post("The way up is blocked.", Color(0.7, 0.7, 0.7))
		TurnManager.end_player_turn()
		return
	_cancel_auto_walk("stairs")
	_cache_current_floor()
	GameManager.ascend()
	CombatLog.post("You climb to B%d." % GameManager.depth,
		Color(0.85, 1.0, 0.85))
	_clear_monsters()
	_clear_floor_items()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth), false)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _travel_to_floor(target_depth: int) -> void:
	if target_depth == GameManager.depth:
		return
	var is_archmage: bool = GameManager.selected_class_id == "archmage"
	if not is_archmage and not GameManager.floor_cache.has(target_depth):
		return
	_cancel_auto_walk("floor travel")
	_cache_current_floor()
	_clear_monsters()
	_clear_floor_items()
	var going_down: bool = target_depth > GameManager.depth
	GameManager.travel_to(target_depth)
	CombatLog.post("You travel to B%d." % target_depth, Color(0.7, 0.9, 1.0))
	_generate_floor(target_depth, _floor_seed(target_depth), going_down)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _on_item_dropped(item_id: String, at_pos: Vector2i, plus: int) -> void:
	var data: ItemData = ItemRegistry.get_by_id(item_id)
	if data == null:
		return
	_spawn_floor_item(data, at_pos, plus)
	CombatLog.post("You drop %s." % GameManager.display_name_of(item_id))

func _on_bag_pressed() -> void:
	if player == null:
		return
	BagDialog.open(player, self)

func _on_status_pressed() -> void:
	if player == null:
		return
	StatusDialog.open(player, self)

func _on_bestiary_pressed() -> void:
	if player == null:
		return
	BestiaryDialog.open(self)

func begin_spell_targeting(spell: SpellData, p: Player) -> void:
	_cancel_targeting()
	_targeting_spell = spell
	var visible: Dictionary = p.compute_fov()
	_targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - p.grid_pos.x), abs(tile.y - p.grid_pos.y))
		if d > 0 and d <= spell.max_range:
			_targeting_tiles.append(tile)
	_targeting_node = SpellTargetOverlay.new()
	_effect_layer.add_child(_targeting_node)
	_targeting_node.init(spell, p, _targeting_tiles)
	CombatLog.post("Tap highlighted tile to cast %s — tap elsewhere to cancel." \
			% spell.display_name, Color(0.8, 0.75, 1.0))

func _cancel_targeting() -> void:
	_targeting_spell = null
	_targeting_tiles = []
	if _targeting_node != null:
		_targeting_node.queue_free()
		_targeting_node = null

func _confirm_targeting() -> void:
	var spell := _targeting_spell
	_cancel_targeting()
	var ok: bool = MagicSystem.cast(spell.id, player, self)
	if ok:
		TurnManager.end_player_turn()

func _on_rest_pressed() -> void:
	if player == null or player.hp <= 0 or not TurnManager.is_player_turn:
		return
	if _monster_in_sight():
		# WAIT: single turn pass when enemies are visible
		player.wait_turn()
		TurnManager.end_player_turn()
		return
	if player.hp >= player.hp_max and player.mp >= player.mp_max:
		CombatLog.post("You are already fully rested.", Color(0.7, 0.9, 0.6))
		return
	var ticks: int = 0
	while ticks < 100 and (player.hp < player.hp_max or player.mp < player.mp_max) and player.hp > 0:
		player.wait_turn()
		TurnManager.end_player_turn(true)
		ticks += 1
		if _monster_in_sight():
			CombatLog.post("You stop resting — enemy spotted.", Color(1.0, 0.7, 0.5))
			break

func _monster_in_sight() -> bool:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and map.visible_tiles.has(n.grid_pos):
			return true
	return false

func _on_skills_pressed() -> void:
	if player == null:
		return
	SkillsDialog.open(player, self)

func _on_quickslot_pressed(index: int) -> void:
	if player == null or player.hp <= 0:
		return
	var slot_id: String = String(player.quickslots[index])
	if slot_id == "":
		QuickslotPicker.open(player, self, index, _refresh_quickslots)
		return
	# Check if it's a spell
	var spell: SpellData = SpellRegistry.get_by_id(slot_id)
	if spell != null:
		if not TurnManager.is_player_turn:
			return
		if spell.effect == "heal" or spell.effect == "blink":
			var ok: bool = MagicSystem.cast(slot_id, player, self)
			if ok:
				TurnManager.end_player_turn()
		else:
			begin_spell_targeting(spell, player)
		return
	# Item path
	if player.count_item(slot_id) == 0:
		QuickslotPicker.open(player, self, index, _refresh_quickslots)
		return
	if not TurnManager.is_player_turn:
		return
	var used: bool = player.use_quickslot(index)
	_refresh_quickslots()
	if used:
		TurnManager.end_player_turn()

func _on_quickslot_long_pressed(index: int) -> void:
	if player == null:
		return
	QuickslotPicker.open(player, self, index, _refresh_quickslots)

func _on_log_tapped() -> void:
	LogDialog.open(self)

func _refresh_quickslots() -> void:
	if bottom_hud == null or player == null:
		return
	for i in range(player.quickslots.size()):
		var id: String = String(player.quickslots[i])
		if id == "":
			bottom_hud.set_quickslot(i, null, "")
			continue
		# Spell slot
		var spell: SpellData = SpellRegistry.get_by_id(id)
		if spell != null:
			bottom_hud.set_quickslot_display(i, spell.display_name.left(3),
					Color(0.7, 0.5, 1.0))
			continue
		# Item slot
		var data: ItemData = ItemRegistry.get_by_id(id)
		if data == null:
			bottom_hud.set_quickslot(i, null, "")
			continue
		var count: int = player.count_item(id)
		if count <= 0:
			player.quickslots[i] = ""
			bottom_hud.set_quickslot(i, null, "")
			continue
		var text: String = ("x%d" % count) if count > 1 else ""
		if GameManager.use_tiles and data.tile_path != "":
			var tex: Texture2D = _make_item_icon(data)
			bottom_hud.set_quickslot(i, tex, text)
		else:
			bottom_hud.set_quickslot_display(i, data.glyph, data.glyph_color)

func _make_item_icon(data: ItemData) -> Texture2D:
	if data.tile_path == "" or not ResourceLoader.exists(data.tile_path):
		return null
	if GameManager.is_identified(data.id) and data.identified_tile_path != "" \
			and ResourceLoader.exists(data.identified_tile_path):
		var img_base: Image = (load(data.tile_path) as Texture2D).get_image()
		var img_over: Image = (load(data.identified_tile_path) as Texture2D).get_image()
		if img_base.get_size() == img_over.get_size():
			img_base.blend_rect(img_over,
					Rect2i(Vector2i.ZERO, img_over.get_size()), Vector2i.ZERO)
		return ImageTexture.create_from_image(img_base)
	return load(data.tile_path) as Texture2D

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


func _on_act_pressed() -> void:
	if player == null or player.hp <= 0 or not TurnManager.is_player_turn:
		return
	if _auto_exploring:
		_cancel_auto_walk("act cancel")
		return
	var nearest := _nearest_visible_monster()
	if nearest != null:
		var dir := _greedy_step_toward(nearest.grid_pos)
		if dir != Vector2i.ZERO:
			player.try_step(dir)
		else:
			CombatLog.post("Can't reach the %s." % nearest.data.display_name,
					Color(1.0, 0.7, 0.5))
	else:
		_start_auto_explore()


func _start_auto_explore() -> void:
	# Route to nearest reachable floor item first.
	var item_target := _find_item_target()
	if item_target != Vector2i(-1, -1):
		var ipath := _bfs_path(player.grid_pos, item_target)
		if not ipath.is_empty():
			_begin_auto_walk(ipath, true)
			return
	var target := _find_explore_target()
	if target == Vector2i(-1, -1):
		_auto_exploring = false
		CombatLog.post("Nowhere left to explore.", Color(0.7, 0.9, 0.7))
		return
	var path := _bfs_path(player.grid_pos, target)
	if path.is_empty():
		_auto_exploring = false
		CombatLog.post("Can't reach unexplored area.", Color(0.7, 0.7, 0.5))
		return
	_begin_auto_walk(path, true)

func _find_item_target() -> Vector2i:
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = 9999
	for n in get_tree().get_nodes_in_group("floor_items"):
		if not (n is FloorItem) or not map.explored.has(n.grid_pos):
			continue
		var d: int = (n.grid_pos - player.grid_pos).length_squared()
		if d < best_dist:
			best_dist = d
			best = n.grid_pos
	return best


func _find_explore_target() -> Vector2i:
	var dirs8 := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]
	var visited: Dictionary = {player.grid_pos: true}
	var queue: Array = [player.grid_pos]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if p != player.grid_pos:
			for d in dirs8:
				var n: Vector2i = p + d
				if map.in_bounds(n) and not map.explored.has(n):
					return p
		for d in dirs8:
			var n: Vector2i = p + d
			if visited.has(n) or not map.in_bounds(n):
				continue
			if not map.is_walkable(n) or not map.explored.has(n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


func _nearest_visible_monster() -> Monster:
	var nearest: Monster = null
	var best: int = 99999
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and map.visible_tiles.has(n.grid_pos):
			var d := _chebyshev(player.grid_pos, n.grid_pos)
			if d < best:
				best = d
				nearest = n
	return nearest


func _greedy_step_toward(target: Vector2i) -> Vector2i:
	var dx: int = sign(target.x - player.grid_pos.x)
	var dy: int = sign(target.y - player.grid_pos.y)
	if dx != 0 and dy != 0 and map.is_walkable(player.grid_pos + Vector2i(dx, dy)):
		return Vector2i(dx, dy)
	if dx != 0 and map.is_walkable(player.grid_pos + Vector2i(dx, 0)):
		return Vector2i(dx, 0)
	if dy != 0 and map.is_walkable(player.grid_pos + Vector2i(0, dy)):
		return Vector2i(0, dy)
	return Vector2i.ZERO


func _on_monster_died(monster: Monster) -> void:
	if player == null or player.hp <= 0:
		return
	var chance: float = 0.08 + GameManager.depth * 0.005
	if randf() < chance:
		var essence_id: String
		if monster != null and monster.data != null and String(monster.data.essence_id) != "":
			essence_id = String(monster.data.essence_id)
		else:
			essence_id = EssenceSystem.random_id()
		player.add_essence(essence_id)
		CombatLog.post("An essence materializes! (%s)" % EssenceSystem.display_name(essence_id),
			Color(0.8, 0.6, 1.0))

func _on_monster_hit(amount: int, monster: Monster) -> void:
	if not is_instance_valid(monster):
		return
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = monster.position + Vector2(cell_size * 0.5, 0.0)
	spawn_damage_number(world_pos, amount, Color(1.0, 0.85, 0.2))

func _on_player_damaged(amount: int) -> void:
	if player == null:
		return
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = player.position + Vector2(cell_size * 0.5, 0.0)
	spawn_damage_number(world_pos, amount, Color(1.0, 0.35, 0.35))
	spawn_hit_flash(player)


## Spawn a floating damage number at the given world position.
func spawn_damage_number(world_pos: Vector2, amount: int, color: Color) -> void:
	if _effect_layer == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = world_pos + Vector2(-20, -32)
	lbl.z_index = 10
	_effect_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 48.0, 0.65)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.tween_callback(lbl.queue_free)


## Spawn a brief hit flash on a monster sprite node.
func spawn_hit_flash(target_node: Node2D) -> void:
	if target_node == null:
		return
	var tw := target_node.create_tween()
	tw.tween_property(target_node, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.06)
	tw.tween_property(target_node, "modulate", Color.WHITE, 0.12)


const _BOLT_TILES: Dictionary = {
	"fire":      "res://assets/tiles/effects/bolt/fire_bolt.png",
	"cold":      "res://assets/tiles/effects/bolt/ice_bolt.png",
	"lightning": "res://assets/tiles/effects/bolt/lightning_bolt.png",
	"poison":    "res://assets/tiles/effects/bolt/poison_bolt.png",
	"death":     "res://assets/tiles/effects/bolt/death_bolt.png",
	"drain":     "res://assets/tiles/effects/bolt/drain_bolt.png",
	"":          "res://assets/tiles/effects/bolt/magic_dart.png",
}
const _HIT_TILES: Dictionary = {
	"fire":      ["res://assets/tiles/effects/hit/fire0.png",
				  "res://assets/tiles/effects/hit/fire1.png",
				  "res://assets/tiles/effects/hit/fire2.png"],
	"cold":      ["res://assets/tiles/effects/hit/ice0.png",
				  "res://assets/tiles/effects/hit/ice1.png",
				  "res://assets/tiles/effects/hit/ice2.png"],
	"lightning": ["res://assets/tiles/effects/hit/lightning0.png",
				  "res://assets/tiles/effects/hit/lightning1.png",
				  "res://assets/tiles/effects/hit/lightning2.png"],
	"poison":    ["res://assets/tiles/effects/hit/poison0.png",
				  "res://assets/tiles/effects/hit/poison1.png",
				  "res://assets/tiles/effects/hit/poison2.png"],
	"drain":     ["res://assets/tiles/effects/hit/drain0.png",
				  "res://assets/tiles/effects/hit/drain1.png",
				  "res://assets/tiles/effects/hit/drain2.png"],
	"death":     ["res://assets/tiles/effects/hit/drain0.png",
				  "res://assets/tiles/effects/hit/drain1.png",
				  "res://assets/tiles/effects/hit/drain2.png"],
	"heal":      ["res://assets/tiles/effects/hit/heal0.png",
				  "res://assets/tiles/effects/hit/heal1.png"],
	"":          ["res://assets/tiles/effects/hit/magic0.png",
				  "res://assets/tiles/effects/hit/magic1.png"],
}

## Spawn a DCSS tile projectile from world_start to world_end.
func spawn_projectile(world_start: Vector2, world_end: Vector2,
		_color: Color, on_arrive: Callable = Callable()) -> void:
	spawn_spell_bolt(world_start, world_end, "", on_arrive)

func spawn_spell_bolt(world_start: Vector2, world_end: Vector2,
		element: String, on_arrive: Callable = Callable()) -> void:
	if _effect_layer == null:
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var key: String = element if _BOLT_TILES.has(element) else ""
	var tile_path: String = _BOLT_TILES[key]
	const SZ := 32.0
	var half := Vector2(SZ * 0.5, SZ * 0.5)
	if ResourceLoader.exists(tile_path):
		var rect := TextureRect.new()
		rect.texture = load(tile_path)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(SZ, SZ)
		rect.size = Vector2(SZ, SZ)
		rect.pivot_offset = half
		rect.rotation = (world_end - world_start).angle()
		rect.position = world_start - half
		rect.z_index = 8
		_effect_layer.add_child(rect)
		var tw := rect.create_tween()
		tw.tween_property(rect, "position", world_end - half, 0.18)
		tw.tween_callback(rect.queue_free)
		if on_arrive.is_valid():
			tw.tween_callback(on_arrive)
		tw.tween_callback(func(): spawn_hit_effect(world_end, element))
	else:
		if on_arrive.is_valid():
			on_arrive.call()

func spawn_hit_effect(world_pos: Vector2, element: String) -> void:
	if _effect_layer == null:
		return
	var key: String = element if _HIT_TILES.has(element) else ""
	var frames: Array = _HIT_TILES[key]
	const SZ := 32.0
	var half := Vector2(SZ * 0.5, SZ * 0.5)
	if frames.is_empty() or not ResourceLoader.exists(frames[0]):
		return
	var rect := TextureRect.new()
	rect.texture = load(frames[0])
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(SZ, SZ)
	rect.size = Vector2(SZ, SZ)
	rect.position = world_pos - half
	rect.z_index = 9
	_effect_layer.add_child(rect)
	var tw := rect.create_tween()
	for i in range(1, frames.size()):
		var fp: String = frames[i]
		if ResourceLoader.exists(fp):
			tw.tween_callback(func(): rect.texture = load(fp))
		tw.tween_interval(0.08)
	tw.tween_property(rect, "modulate:a", 0.0, 0.1)
	tw.tween_callback(rect.queue_free)

func spawn_aoe_burst(target_positions: Array, element: String) -> void:
	for pos in target_positions:
		spawn_hit_effect(pos, element)
