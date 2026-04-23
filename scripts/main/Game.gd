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
	_refresh_quickslots()
	CombatLog.post("B%d — tap a tile (or arrows) to step, bump to attack." \
			% GameManager.depth, Color(0.7, 0.9, 1.0))

func _unhandled_input(event: InputEvent) -> void:
	if player == null or map == null or camera == null:
		return
	if player.hp <= 0 or not TurnManager.is_player_turn:
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
	_handle_tap(screen_pos)
	get_viewport().set_input_as_handled()

func _handle_tap(screen_pos: Vector2) -> void:
	# Convert screen → world via canvas transform (camera-aware).
	var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
	var world_pos: Vector2 = canvas_tf.affine_inverse() * screen_pos
	var target: Vector2i = map.world_to_grid(world_pos)
	if target == player.grid_pos:
		# Tap on self = wait one turn.
		player.wait_turn()
		TurnManager.end_player_turn()
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
	player.statuses = data.get("statuses", {})
	player.skills = data.get("skills", {})
	if player.skills.is_empty():
		player.init_skills()
	var saved_qs = data.get("quickslots", null)
	if saved_qs is Array and saved_qs.size() == player.quickslots.size():
		player.quickslots = saved_qs
	player.set_race_from_id(GameManager.selected_race_id)
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

func _spawn_player() -> void:
	player = PlayerScene.new()
	player.name = "Player"
	add_child(player)
	player.moved.connect(_on_player_moved)
	player.died.connect(_on_player_died)
	player.stepped_on_stairs_down.connect(_on_stairs_down)
	player.stats_changed.connect(_update_hud)
	player.item_dropped.connect(_on_item_dropped)

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
		m.hit_taken.connect(_on_monster_hit.bind(m))
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

func _update_minimap() -> void:
	if map == null or player == null:
		return
	var tex: ImageTexture = MinimapRenderer.render(map, player, self)
	if top_hud != null:
		top_hud.set_minimap_texture(tex)

func _on_minimap_tapped() -> void:
	if map == null or player == null:
		return
	var dlg: GameDialog = GameDialog.create("Map")
	add_child(dlg)
	var body := dlg.body()
	var tex: ImageTexture = MinimapRenderer.render(map, player, self, 8)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(0, 900)
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(rect)

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
	_refresh_quickslots()

func _on_player_turn_started() -> void:
	if player != null and player.hp > 0:
		player.tick_statuses()

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
	body.add_theme_constant_override("separation", 10)

	# Character card
	var char_card := UICards.card(Color(0.5, 0.8, 1.0))
	var char_vb := VBoxContainer.new()
	char_vb.add_theme_constant_override("separation", 4)
	char_card.add_child(char_vb)
	char_vb.add_child(UICards.accent_value("Lv.%d  — XP %d / %d" % [player.xl, player.xp, player.xp_to_next()]))
	char_vb.add_child(UICards.dim_hint("Kills: %d   Gold: %dg   Floor: B%d" % [player.kills, player.gold, GameManager.depth]))
	body.add_child(char_card)

	# Vitals card
	var vital_card := UICards.card(Color(1.0, 0.4, 0.4))
	var vital_vb := VBoxContainer.new()
	vital_vb.add_theme_constant_override("separation", 4)
	vital_card.add_child(vital_vb)
	vital_vb.add_child(UICards.accent_value("HP  %d / %d" % [player.hp, player.hp_max]))
	vital_vb.add_child(UICards.accent_value("MP  %d / %d" % [player.mp, player.mp_max], 34))
	body.add_child(vital_card)

	# Stats card
	var stat_card := UICards.card(Color(0.9, 0.75, 0.3))
	var stat_vb := VBoxContainer.new()
	stat_vb.add_theme_constant_override("separation", 4)
	stat_card.add_child(stat_vb)
	stat_vb.add_child(UICards.accent_value("STR %d   DEX %d   INT %d" % [player.strength, player.dexterity, player.intelligence]))
	stat_vb.add_child(UICards.dim_hint("AC %d   EV %d   WL %d" % [player.ac, player.ev, player.wl]))
	body.add_child(stat_card)

	# Equipment card
	var w_data: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	var a_data: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
	var eq_card := UICards.card(Color(0.6, 0.9, 0.6))
	var eq_vb := VBoxContainer.new()
	eq_vb.add_theme_constant_override("separation", 4)
	eq_card.add_child(eq_vb)
	eq_vb.add_child(UICards.section_header("EQUIPMENT"))
	eq_vb.add_child(UICards.dim_hint("⚔  " + (w_data.display_name if w_data != null else "unarmed")))
	eq_vb.add_child(UICards.dim_hint("🛡  " + (a_data.display_name if a_data != null else "none")))
	body.add_child(eq_card)

	# Active statuses
	if not player.statuses.is_empty():
		var st_card := UICards.card(Color(1.0, 0.5, 0.8))
		var st_vb := VBoxContainer.new()
		st_vb.add_theme_constant_override("separation", 4)
		st_card.add_child(st_vb)
		st_vb.add_child(UICards.section_header("STATUSES"))
		var parts: Array = []
		for sid in player.statuses.keys():
			parts.append("%s (%d)" % [sid, int(player.statuses[sid])])
		st_vb.add_child(UICards.dim_hint(", ".join(parts)))
		body.add_child(st_card)

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
		var ok: bool = MagicSystem.cast(slot_id, player, self)
		if ok:
			TurnManager.end_player_turn()
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
			var tex: Texture2D = load(data.tile_path) as Texture2D
			bottom_hud.set_quickslot(i, tex, text)
		else:
			bottom_hud.set_quickslot_display(i, data.glyph, data.glyph_color)

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
	var nearest := _nearest_visible_monster()
	if nearest != null:
		var dir := _greedy_step_toward(nearest.grid_pos)
		if dir != Vector2i.ZERO:
			player.try_step(dir)
		else:
			CombatLog.post("Can't reach the %s." % nearest.data.display_name,
					Color(1.0, 0.7, 0.5))
	else:
		# Auto-explore: walk toward stairs
		var dir := _greedy_step_toward(map.stairs_down_pos)
		if dir != Vector2i.ZERO:
			player.try_step(dir)
		else:
			CombatLog.post("Nothing to do.", Color(0.7, 0.7, 0.5))


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
	var dx := sign(target.x - player.grid_pos.x)
	var dy := sign(target.y - player.grid_pos.y)
	if dx != 0 and dy != 0 and map.is_walkable(player.grid_pos + Vector2i(dx, dy)):
		return Vector2i(dx, dy)
	if dx != 0 and map.is_walkable(player.grid_pos + Vector2i(dx, 0)):
		return Vector2i(dx, 0)
	if dy != 0 and map.is_walkable(player.grid_pos + Vector2i(0, dy)):
		return Vector2i(0, dy)
	return Vector2i.ZERO


func _on_monster_hit(amount: int, monster: Monster) -> void:
	if not is_instance_valid(monster):
		return
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = monster.position + Vector2(cell_size * 0.5, 0.0)
	spawn_damage_number(world_pos, amount, Color(1.0, 0.85, 0.2))


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


## Spawn a projectile that travels from world_start to world_end, then calls on_arrive.
func spawn_projectile(world_start: Vector2, world_end: Vector2,
		color: Color, on_arrive: Callable = Callable()) -> void:
	if _effect_layer == null:
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var dot := ColorRect.new()
	dot.size = Vector2(10, 10)
	dot.color = color
	dot.position = world_start
	dot.z_index = 8
	_effect_layer.add_child(dot)
	var tw := dot.create_tween()
	tw.tween_property(dot, "position", world_end, 0.18)
	tw.tween_callback(dot.queue_free)
	if on_arrive.is_valid():
		tw.tween_callback(on_arrive)
