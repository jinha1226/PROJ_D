extends Node2D

const TILE_SIZE: int = 32
const PLAYER_SCENE: PackedScene = preload("res://scenes/entities/Player.tscn")
const TOUCH_INPUT_SCRIPT: Script = preload("res://scripts/ui/TouchInput.gd")
const ESSENCE_SYSTEM_SCRIPT: Script = preload("res://scripts/systems/EssenceSystem.gd")
# [skill-agent] DCSS-style skill tracker + XP distribution.
const SKILL_SYSTEM_SCRIPT: Script = preload("res://scripts/systems/SkillSystem.gd")
# [meta-agent] M1 meta progression + result screen.
const META_SCRIPT: Script = preload("res://scripts/systems/MetaProgression.gd")
const RESULT_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/ResultScreen.tscn")
# [skill-ui-agent] skill screen + level-up toast prefabs.
const SKILLS_SCREEN_SCENE: PackedScene = preload("res://scenes/ui/SkillsScreen.tscn")
const SKILL_TOAST_SCENE: PackedScene = preload("res://scenes/ui/SkillLevelUpToast.tscn")
const MAX_DEPTH: int = 15

var generator: DungeonGenerator
var player: Player
var touch_input: Node
var essence_system: EssenceSystem
# [skill-agent] skill system instance (named "SkillSystem" for lookup).
var skill_system: SkillSystem
var ui: Node
# [meta-agent] run tracking + meta refs.
var meta: MetaProgression
# [skill-ui-agent] persistent toast layer for skill level-up messages.
var skill_toast: Node = null
var _top_hud_ref: Node = null
var kill_count: int = 0
var last_killer_name: String = ""
var run_over: bool = false


func _ready() -> void:
	# [meta-agent] Instantiate MetaProgression (M1: child of Game root; autoload later).
	meta = META_SCRIPT.new()
	meta.name = "MetaProgression"
	add_child(meta)
	meta.load_from_disk()

	generator = DungeonGenerator.new()
	add_child(generator)
	generator.generate(GameManager.current_depth)

	var dungeon_layer: Node2D = $DungeonLayer
	var dmap: DungeonMap = dungeon_layer.get_node("DungeonMap")
	dmap.render(generator)

	var cam: Camera2D = $Camera2D
	cam.position = Vector2(generator.spawn_pos.x * TILE_SIZE + TILE_SIZE / 2.0, generator.spawn_pos.y * TILE_SIZE + TILE_SIZE / 2.0)

	# Spawn player.
	var entity_layer: Node2D = $EntityLayer
	player = PLAYER_SCENE.instantiate()
	entity_layer.add_child(player)
	var race: RaceData = load("res://resources/races/human.tres")
	var job: JobData = load("res://resources/jobs/barbarian.tres")
	player.setup(generator, generator.spawn_pos, job, race)

	# [skill-agent] SkillSystem must exist before first attack; attach as child
	# of Game root with node name "SkillSystem" so Player.try_attack_at can
	# fetch it via get_node_or_null("Game/SkillSystem").
	skill_system = SKILL_SYSTEM_SCRIPT.new()
	skill_system.name = "SkillSystem"
	add_child(skill_system)
	var starting_skills: Dictionary = job.starting_skills if job else {}
	skill_system.init_for_player(player, starting_skills)

	player.moved.connect(_on_player_moved)
	# [meta-agent] hook player death → result screen.
	player.died.connect(_on_player_died)

	# UI lookup.
	ui = get_node_or_null("UILayer/UI")
	var top_hud: Node = ui.get_node_or_null("TopHUD") if ui else null
	var bottom_hud: Node = ui.get_node_or_null("BottomHUD") if ui else null
	var popup_mgr: Node = ui.get_node_or_null("PopupManager") if ui else null

	# Hook TopHUD HP/MP binding.
	if top_hud != null:
		player.stats_changed.connect(func():
			if player.stats == null:
				return
			if top_hud.has_method("set_hp"):
				top_hud.set_hp(player.stats.HP, player.stats.hp_max)
			if top_hud.has_method("set_mp"):
				top_hud.set_mp(player.stats.MP, player.stats.mp_max))
		if top_hud.has_method("set_hp") and player.stats != null:
			top_hud.set_hp(player.stats.HP, player.stats.hp_max)
			top_hud.set_mp(player.stats.MP, player.stats.mp_max)

	# [skill-ui-agent] TopHUD skills-button → spawn SkillsScreen.
	_top_hud_ref = top_hud
	if top_hud != null and top_hud.has_signal("skills_button_pressed"):
		top_hud.skills_button_pressed.connect(_on_skills_button_pressed)

	# [skill-ui-agent] persistent level-up toast layer.
	skill_toast = SKILL_TOAST_SCENE.instantiate()
	add_child(skill_toast)
	if skill_system != null:
		skill_system.skill_leveled_up.connect(_on_skill_leveled_up_toast)
		skill_system.xp_gained.connect(_on_skill_xp_gained_hud)
		skill_system.skill_leveled_up.connect(_on_skill_leveled_up_hud)
	if player != null:
		player.stats_changed.connect(_refresh_weapon_skill_hud)
	_refresh_weapon_skill_hud()

	# EssenceSystem setup.
	essence_system = EssenceSystem.new()
	essence_system.name = "EssenceSystem"
	essence_system.player = player
	add_child(essence_system)
	essence_system.slot_changed.connect(func(index: int, essence):
		if bottom_hud == null:
			return
		if essence == null:
			bottom_hud.set_essence("", Color(0.3, 0.3, 0.3))
		else:
			bottom_hud.set_essence(essence.id, essence_system.get_color_for(essence)))
	essence_system.essence_acquired.connect(func(essence):
		print("Acquired: %s" % essence.display_name))
	essence_system.inventory_full.connect(func(pending):
		print("Inventory full; dropped: %s" % pending.display_name))

	# BottomHUD essence slot tap → swap popup.
	if bottom_hud != null and popup_mgr != null:
		bottom_hud.essence_slot_tapped.connect(func():
			var current: EssenceData = essence_system.slots[0]
			var current_id: String = current.id if current != null else ""
			var inv_ids: Array = []
			for e in essence_system.inventory:
				if e != null:
					inv_ids.append(e.id)
			popup_mgr.show_essence_swap_popup(0, current_id, inv_ids, func(selected_id):
				if selected_id == "":
					essence_system.unequip(0)
				else:
					var target: EssenceData = essence_system.find_essence_by_id(selected_id)
					if target != null:
						essence_system.equip(0, target)))

	# Touch input.
	touch_input = Node.new()
	touch_input.set_script(TOUCH_INPUT_SCRIPT)
	touch_input.name = "TouchInput"
	touch_input.generator = generator
	touch_input.player = player
	touch_input.camera = cam
	add_child(touch_input)
	touch_input.stairs_tapped.connect(_on_stairs_tapped)

	await get_tree().process_frame
	_spawn_monsters_for_current_depth()

	TurnManager.start_player_turn()


func _spawn_monsters_for_current_depth() -> void:
	# [meta-agent] spawn + connect death to both essence-drop and kill counter.
	var monsters: Array[Monster] = MonsterSpawner.spawn_for_depth(GameManager.current_depth, generator, $EntityLayer)
	for m in monsters:
		if m != null and not m.died.is_connected(_on_monster_died):
			m.died.connect(_on_monster_died)


func _on_monster_died(monster: Monster) -> void:
	# [meta-agent] track kills for result screen.
	kill_count += 1
	if essence_system != null:
		essence_system.try_drop_from_monster(monster)
	# [skill-agent] award XP to trained skills matching weapon + passive tags.
	if skill_system != null and player != null and monster != null and monster.data != null:
		var xp_gain: int = int(monster.data.xp_value)
		if xp_gain <= 0:
			xp_gain = max(1, int(monster.data.tier) * 3)
		var tags: Array = []
		var wskill: String = player.get_current_weapon_skill()
		if wskill != "":
			tags.append(wskill)
		tags.append("fighting")
		# M1 stubs: always train armour (player has leather), skip shields/dodging.
		tags.append("armour")
		var leveled: Array = skill_system.grant_xp(player, float(xp_gain), tags)
		for entry in leveled:
			print("%s trained to %d" % [entry["skill_id"], entry["new_level"]])


func _on_player_moved(new_pos: Vector2i) -> void:
	var cam: Camera2D = $Camera2D
	cam.position = Vector2(new_pos.x * TILE_SIZE + TILE_SIZE / 2.0, new_pos.y * TILE_SIZE + TILE_SIZE / 2.0)


func _on_stairs_tapped(_pos: Vector2i) -> void:
	# [meta-agent] descend or trigger clear-result.
	if run_over:
		return
	if GameManager.current_depth >= MAX_DEPTH:
		_end_run(true, "")
		return
	GameManager.current_depth += 1
	_regenerate_dungeon()


func _regenerate_dungeon() -> void:
	# [meta-agent] rebuild dungeon + monsters for the new depth; keep player instance.
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m):
			TurnManager.unregister_actor(m)
			m.queue_free()
	if is_instance_valid(generator):
		generator.queue_free()
	generator = DungeonGenerator.new()
	add_child(generator)
	generator.generate(GameManager.current_depth, randi())
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	dmap.render(generator)
	player.generator = generator
	player.grid_pos = generator.spawn_pos
	player.position = Vector2(generator.spawn_pos.x * TILE_SIZE + TILE_SIZE / 2.0, generator.spawn_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	var cam: Camera2D = $Camera2D
	cam.position = player.position
	if touch_input:
		touch_input.generator = generator
	await get_tree().process_frame
	_spawn_monsters_for_current_depth()


func _on_player_died() -> void:
	# [meta-agent] best-effort killer name = adjacent monster at moment of death.
	if last_killer_name == "":
		last_killer_name = _guess_killer_name()
	_end_run(false, last_killer_name)


func _guess_killer_name() -> String:
	if player == null:
		return ""
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if "grid_pos" in m:
			var d: Vector2i = m.grid_pos - player.grid_pos
			if max(abs(d.x), abs(d.y)) <= 1:
				if "display_name" in m:
					return String(m.display_name)
				return m.name
	return ""


func _end_run(victory: bool, killer: String) -> void:
	# [meta-agent] record shards, show result screen.
	if run_over:
		return
	run_over = true
	var depth_reached: int = GameManager.current_depth
	var shards_gained: int = meta.record_run_end(depth_reached, victory)
	GameManager.end_run(victory)
	var screen: CanvasLayer = RESULT_SCREEN_SCENE.instantiate()
	add_child(screen)
	screen.show_result({
		"victory": victory,
		"depth": depth_reached,
		"kills": kill_count,
		"turns": TurnManager.turn_number,
		"shards_gained": shards_gained,
		"shards_total": meta.rune_shards,
		"killer": killer,
	})


# [skill-ui-agent] ---- skill UI wiring ------------------------------------

func _on_skills_button_pressed() -> void:
	var ui_layer: Node = get_node_or_null("UILayer")
	if ui_layer == null or player == null:
		return
	# Avoid duplicates.
	var existing: Node = ui_layer.get_node_or_null("SkillsScreen")
	if existing != null:
		return
	var screen: CanvasLayer = SKILLS_SCREEN_SCENE.instantiate()
	screen.name = "SkillsScreen"
	ui_layer.add_child(screen)
	screen.show_for_player(player)


func _on_skill_leveled_up_toast(p: Node, skill_id: String, new_level: int) -> void:
	if p != player or skill_toast == null:
		return
	var nm: String = String(SkillRow.SKILL_NAMES.get(skill_id, skill_id))
	if skill_toast.has_method("show_toast"):
		skill_toast.show_toast("%s Lv.%d!" % [nm, new_level])


func _on_skill_xp_gained_hud(p: Node, _skill_id: String, _amt: float) -> void:
	if p != player:
		return
	_refresh_weapon_skill_hud()


func _on_skill_leveled_up_hud(p: Node, _skill_id: String, _new_level: int) -> void:
	if p != player:
		return
	_refresh_weapon_skill_hud()


func _refresh_weapon_skill_hud() -> void:
	if _top_hud_ref == null or player == null:
		return
	if not _top_hud_ref.has_method("set_weapon_skill_info"):
		return
	var skill_id: String = ""
	if player.has_method("get_current_weapon_skill"):
		skill_id = player.get_current_weapon_skill()
	if skill_id == "" or skill_system == null:
		_top_hud_ref.set_weapon_skill_info("", 0, 0.0, 0.0)
		return
	var nm: String = String(SkillRow.SKILL_NAMES.get(skill_id, skill_id))
	var lvl: int = skill_system.get_level(player, skill_id)
	var xp: float = skill_system.get_xp(player, skill_id)
	var need: float = SkillSystem.xp_for_level(lvl + 1)
	_top_hud_ref.set_weapon_skill_info(nm, lvl, xp, need)
