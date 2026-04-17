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
# [skill-ui-agent] level-up toast prefab.
const SKILL_TOAST_SCENE: PackedScene = preload("res://scenes/ui/SkillLevelUpToast.tscn")

const _SKILL_CATEGORIES: Array = ["weapon", "defense", "magic", "misc"]
const _SKILL_CATEGORY_LABELS: Dictionary = {
	"weapon": "WEAPON", "defense": "DEFENSE",
	"magic": "MAGIC", "misc": "MISC",
}

const _COMPANION_SCENE: PackedScene = preload("res://scenes/entities/Companion.tscn")
# Essence id → companion archetype (MonsterData tres filename).
const _ESSENCE_TO_COMPANION: Dictionary = {
	"boneknight_essence":   "skeleton",
	"lich_essence":         "skeleton",
	"ogre_essence":         "goblin",     # placeholder — a beefy orc would be better
	"titan_essence":        "orc",
	"fire_sprite_essence":  "fire_sprite",
	"dragon_essence":       "orc",        # placeholder
	"snake_essence":        "adder",
	"dryad_essence":        "adder",
	"void_essence":         "kobold",
}
# [zoom-agent] pinch gesture + UI zoom buttons.
const ZOOM_CONTROLLER_SCRIPT: Script = preload("res://scripts/ui/ZoomController.gd")
const MAX_DEPTH: int = 25

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
# Fixed per-run seed. generator.generate(depth, _base_seed) adds depth*1000
# internally so each depth has a stable, distinct map.
var _base_seed: int = 0
# Per-depth snapshot of monsters/items captured when the player leaves that
# floor. Restored on revisit so killed enemies stay dead and picked-up items
# stay gone. Keyed by int depth.
var _floor_state: Dictionary = {}
# Toggle tracking — pressing the same HUD button again closes its popup.
var _bag_dlg: AcceptDialog = null
var _skills_dlg: AcceptDialog = null
var _status_dlg: AcceptDialog = null
var _map_dlg: AcceptDialog = null
var _magic_dlg: AcceptDialog = null
var _targeting_spell: String = ""
# Camera follow tween so the view doesn't snap.
var _cam_tween: Tween = null
const _CAM_FOLLOW_DUR: float = 0.14

# REST mode — advances turns while regenerating HP/MP. Interrupts when any
# monster enters player FOV or caps reached.
var _resting: bool = false
var _rest_turns: int = 0
const _REST_MAX_TURNS: int = 50
const _REST_HP_PER_TURN: int = 2
const _REST_MP_PER_TURN: int = 1


func _ready() -> void:
	var ui_layer: Node = get_node_or_null("UILayer")
	if ui_layer:
		var ui_ctrl: Node = ui_layer.get_node_or_null("UI")
		if ui_ctrl and ui_ctrl is CanvasItem:
			ui_ctrl.theme = GameTheme.create()
	meta = META_SCRIPT.new()
	meta.name = "MetaProgression"
	add_child(meta)
	meta.load_from_disk()

	_base_seed = randi()
	GameManager.current_branch = GameManager.branch_for_depth(GameManager.current_depth)
	TileRenderer._cache.clear()
	generator = DungeonGenerator.new()
	add_child(generator)
	generator.generate(GameManager.current_depth, _base_seed)

	var dungeon_layer: Node2D = $DungeonLayer
	var dmap: DungeonMap = dungeon_layer.get_node("DungeonMap")
	dmap.render(generator)
	dmap.update_fov(generator.spawn_pos)
	# Initial minimap preview feed — set_xp below also triggers a label refresh.

	var cam: Camera2D = $Camera2D
	cam.position = Vector2(generator.spawn_pos.x * TILE_SIZE + TILE_SIZE / 2.0, generator.spawn_pos.y * TILE_SIZE + TILE_SIZE / 2.0)

	# Spawn player.
	var entity_layer: Node2D = $EntityLayer
	player = PLAYER_SCENE.instantiate()
	entity_layer.add_child(player)
	# Default loadout until MainMenu selection is implemented.
	# GameManager.selected_race_id / selected_job_id can override later.
	var trait_id: String = GameManager.selected_race_id if GameManager.selected_race_id != "" else "tough"
	var job_id: String = GameManager.selected_job_id if GameManager.selected_job_id != "" else "fighter"
	GameManager.start_new_run(job_id, trait_id)
	var job: JobData = load("res://resources/jobs/%s.tres" % job_id)
	var trait_res: TraitData = load("res://resources/traits/%s.tres" % trait_id)
	player.setup(generator, generator.spawn_pos, job, null, trait_res)

	# [skill-agent] SkillSystem must exist before first attack; attach as child
	# of Game root with node name "SkillSystem" so Player.try_attack_at can
	# fetch it via get_node_or_null("Game/SkillSystem").
	skill_system = SKILL_SYSTEM_SCRIPT.new()
	skill_system.name = "SkillSystem"
	add_child(skill_system)
	skill_system.add_to_group("skill_system")
	var starting_skills: Dictionary = {}
	if job:
		for sk in job.starting_skills:
			starting_skills[sk] = int(job.starting_skills[sk])
	if trait_res != null:
		var trait_skills: Dictionary = _get_trait_skills(trait_res.id)
		for sk in trait_skills:
			starting_skills[sk] = int(starting_skills.get(sk, 0)) + int(trait_skills[sk])
	skill_system.init_for_player(player, starting_skills)

	player.moved.connect(_on_player_moved)
	# [meta-agent] hook player death → result screen.
	player.died.connect(_on_player_died)
	player.leveled_up.connect(_on_player_leveled_up)
	player.identify_one_requested.connect(_on_identify_one_requested)
	if player.has_signal("summon_companion_requested"):
		player.summon_companion_requested.connect(_on_summon_companion_requested)

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

	# TopHUD keeps HP/MP/XP bars + minimap preview; all other buttons moved
	# to BottomHUD. Wire depth, XP updates, minimap preview + click.
	_top_hud_ref = top_hud
	if top_hud != null and top_hud.has_method("set_depth"):
		top_hud.set_depth(GameManager.current_depth)
	if top_hud != null and top_hud.has_method("set_xp"):
		top_hud.set_xp(player.xp, player.xp_for_next_level(), player.level)
	if top_hud != null and top_hud.has_signal("minimap_pressed"):
		top_hud.minimap_pressed.connect(_on_minimap_pressed)
	if player.has_signal("xp_changed"):
		player.xp_changed.connect(_on_player_xp_changed.bind(top_hud))
	_refresh_minimap_preview(dmap, generator.spawn_pos)

	# BottomHUD is where the action buttons live now.
	if bottom_hud != null and bottom_hud.has_signal("bag_pressed"):
		bottom_hud.bag_pressed.connect(_on_bag_pressed)
	if bottom_hud != null and bottom_hud.has_signal("skills_pressed"):
		bottom_hud.skills_pressed.connect(_on_skills_button_pressed)
	if bottom_hud != null and bottom_hud.has_signal("status_pressed"):
		bottom_hud.status_pressed.connect(_on_status_pressed)
	if bottom_hud != null and bottom_hud.has_signal("magic_pressed"):
		bottom_hud.magic_pressed.connect(_on_magic_pressed)
	if bottom_hud != null and bottom_hud.has_signal("wait_pressed"):
		bottom_hud.wait_pressed.connect(_on_wait_pressed)
	if bottom_hud != null and bottom_hud.has_signal("menu_pressed"):
		bottom_hud.menu_pressed.connect(_on_menu_pressed)

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

	# BottomHUD REST button.
	if bottom_hud != null and bottom_hud.has_signal("rest_pressed"):
		bottom_hud.rest_pressed.connect(_on_rest_pressed)

	# Quickslots: pressed index → player.use_quickslot; player.quickslots_changed
	# → refresh display.
	if bottom_hud != null and bottom_hud.has_signal("quickslot_pressed"):
		bottom_hud.quickslot_pressed.connect(_on_quickslot_pressed)
	if player.has_signal("quickslots_changed"):
		player.quickslots_changed.connect(_refresh_quickslots.bind(bottom_hud))
	if player.has_signal("inventory_changed"):
		player.inventory_changed.connect(_refresh_quickslots.bind(bottom_hud))
	_refresh_quickslots(bottom_hud)

	# Essence management moved into the Status popup; BottomHUD no longer
	# hosts an essence slot. The swap UI is still available via the button
	# inside Status → _show_essence_swap().

	# Touch input.
	touch_input = Node.new()
	touch_input.set_script(TOUCH_INPUT_SCRIPT)
	touch_input.name = "TouchInput"
	touch_input.generator = generator
	touch_input.player = player
	touch_input.camera = cam
	touch_input.dmap = dmap
	add_child(touch_input)
	touch_input.stairs_tapped.connect(_on_stairs_tapped)
	touch_input.stairs_up_tapped.connect(_on_stairs_up_tapped)
	touch_input.target_selected.connect(_on_target_selected)
	touch_input.inspect_requested.connect(_on_inspect_requested)

	# Pinch-zoom (mobile) / wheel (desktop). No on-screen +/- buttons.
	var zoom_ctrl: Node = ZOOM_CONTROLLER_SCRIPT.new()
	zoom_ctrl.name = "ZoomController"
	zoom_ctrl.camera = cam
	add_child(zoom_ctrl)

	await get_tree().process_frame
	_spawn_monsters_for_current_depth()
	_spawn_dummy_items(5)
	_refresh_actor_visibility(dmap)

	if not TurnManager.player_turn_started.is_connected(_on_turn_refresh_visibility):
		TurnManager.player_turn_started.connect(_on_turn_refresh_visibility)
	TurnManager.start_player_turn()


func _on_turn_refresh_visibility() -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		_refresh_actor_visibility(dmap)
		_refresh_danger_tiles(dmap)
	_apply_passive_racial_traits()
	if essence_system != null:
		essence_system.on_turn_tick()
	if _resting:
		_rest_tick()


func _refresh_danger_tiles(dmap: DungeonMap) -> void:
	dmap.danger_tiles.clear()
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster):
			continue
		if m.boss_ai == null:
			continue
		if m.boss_ai.shows_danger_tiles():
			dmap.danger_tiles.append_array(m.boss_ai.danger_tiles)
	dmap.queue_redraw()


## Per-turn racial passives (Troll regen for now; extend with new traits).
func _apply_passive_racial_traits() -> void:
	if player == null or player.stats == null or not player.is_alive:
		return
	var special: String = ""
	if player.trait_res != null:
		special = player.trait_res.special
	elif player.race_res != null:
		special = player.race_res.racial_trait
	if special == "regen":
		if player.stats.HP < player.stats.hp_max:
			player.stats.HP = min(player.stats.hp_max, player.stats.HP + 1)
			player.stats_changed.emit()


## Every frame make sure monsters/items don't leak into unexplored tiles.
## Cheap — ~30 nodes max, single dict lookup each. Catches tween-mid
## movement where grid_pos changed but no signal fired yet.
func _process(_delta: float) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null and generator != null:
		_refresh_actor_visibility(dmap)


func _on_quickslot_pressed(index: int) -> void:
	if player == null:
		return
	var id: String = player.quickslot_ids[index] if index < player.quickslot_ids.size() else ""
	if id == "":
		_open_quickslot_picker(index)
		return
	if id.begins_with("spell:"):
		var spell_id: String = id.substr(6)
		var info: Dictionary = SpellRegistry.get_spell(spell_id)
		if info.is_empty():
			return
		var targeting_type: String = String(info.get("targeting", "single"))
		if targeting_type == "self":
			var result: Dictionary = _execute_cast(spell_id)
			print("[Spell] %s" % result.get("message", spell_id))
			if result.get("success", false):
				if skill_system != null:
					var school: String = String(info.get("school", "spellcasting"))
					skill_system.grant_xp(player, float(info.get("mp", 1)) * 8.0, [school, "spellcasting"])
				TurnManager.end_player_turn()
		else:
			_targeting_spell = spell_id
			if touch_input != null:
				touch_input.targeting_mode = true
			_show_targeting_hint()
		return
	player.use_quickslot(index)


func _open_quickslot_picker(slot_index: int) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Assign Quickslot %d" % (slot_index + 1)
	dlg.ok_button_text = "Cancel"

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	dlg.add_child(vb)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1200)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var items_header := Label.new()
	items_header.text = "--- Items ---"
	items_header.add_theme_font_size_override("font_size", 40)
	items_header.modulate = Color(0.8, 0.8, 0.6)
	rows.add_child(items_header)

	var seen_ids: Dictionary = {}
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		var kind: String = String(it.get("kind", ""))
		if kind != "potion" and kind != "scroll" and kind != "book":
			continue
		if seen_ids.has(iid):
			continue
		seen_ids[iid] = true
		var btn := Button.new()
		var disp: String = GameManager.display_name_for_item(iid, String(it.get("name", iid)), kind)
		btn.text = "%s [%s]" % [disp, kind]
		btn.custom_minimum_size = Vector2(0, 72)
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(_assign_quickslot_item.bind(slot_index, iid, dlg))
		rows.add_child(btn)

	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_system)
	if not known.is_empty():
		var spell_header := Label.new()
		spell_header.text = "--- Spells ---"
		spell_header.add_theme_font_size_override("font_size", 40)
		spell_header.modulate = Color(0.6, 0.7, 1.0)
		rows.add_child(spell_header)
		for spell_id in known:
			var info: Dictionary = SpellRegistry.get_spell(spell_id)
			var btn := Button.new()
			btn.text = "%s [%d MP]" % [String(info.get("name", spell_id)), int(info.get("mp", 0))]
			btn.custom_minimum_size = Vector2(0, 72)
			btn.add_theme_font_size_override("font_size", 40)
			btn.add_theme_color_override("font_color", info.get("color", Color.WHITE))
			btn.pressed.connect(_assign_quickslot_item.bind(slot_index, "spell:" + spell_id, dlg))
			rows.add_child(btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Slot"
	clear_btn.custom_minimum_size = Vector2(0, 72)
	clear_btn.add_theme_font_size_override("font_size", 40)
	clear_btn.modulate = Color(1.0, 0.5, 0.5)
	clear_btn.pressed.connect(_assign_quickslot_item.bind(slot_index, "", dlg))
	vb.add_child(clear_btn)

	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 1400))


func _assign_quickslot_item(slot_index: int, id: String, dlg: AcceptDialog) -> void:
	if player != null and slot_index < player.quickslot_ids.size():
		player.quickslot_ids[slot_index] = id
		player.quickslots_changed.emit()
	dlg.queue_free()


## Rebuild the BottomHUD quickslot labels/colours from player.quickslot_ids +
## current inventory counts. Shows a short label (first 3 chars) tinted with
## the consumable's colour; empty slots render as "+".
func _refresh_quickslots(bottom_hud: Node) -> void:
	if bottom_hud == null or player == null:
		return
	for i in player.quickslot_ids.size():
		var id: String = player.quickslot_ids[i]
		if id == "":
			bottom_hud.set_quickslot_display(i, "", Color.WHITE)
			continue
		if id.begins_with("spell:"):
			var spell_id: String = id.substr(6)
			var spell_info: Dictionary = SpellRegistry.get_spell(spell_id)
			var spell_name: String = String(spell_info.get("name", spell_id))
			var tag: String = spell_name.substr(0, 6)
			var spell_color: Color = spell_info.get("color", Color(0.6, 0.6, 1.0))
			bottom_hud.set_quickslot_display(i, tag, spell_color)
			continue
		var info: Dictionary = ConsumableRegistry.get_info(id)
		var color: Color = info.get("color", Color(0.9, 0.9, 0.4))
		var count: int = 0
		for inv_it in player.get_items():
			if String(inv_it.get("id", "")) == id:
				count += 1
		var disp_name: String = GameManager.display_name_for_item(
				id, String(info.get("name", id)), String(info.get("kind", "")))
		var tag: String = disp_name.split(" ")[0].substr(0, 6)
		if count > 1:
			tag = "%s×%d" % [tag, count]
		bottom_hud.set_quickslot_display(i, tag, color)


func _on_inspect_requested(pos: Vector2i) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var lines: Array = []
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	# Tile info
	if generator != null:
		var t: int = generator.get_tile(pos)
		var tile_names: Dictionary = {
			0: "Wall", 1: "Floor", 2: "Open Door", 3: "Closed Door",
			4: "Stairs Down", 5: "Stairs Up", 6: "Water", 7: "Lava",
		}
		lines.append("Tile: %s (%d,%d)" % [tile_names.get(t, "Unknown"), pos.x, pos.y])
	# Monster info
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster and m.grid_pos == pos:
			var mname: String = String(m.data.display_name) if m.data else "?"
			lines.append("")
			lines.append("--- %s ---" % mname)
			lines.append("HP: %d / %d" % [m.hp, m.data.hp if m.data else 0])
			lines.append("STR: %d  DEX: %d" % [m.data.str if m.data else 0, m.data.dex if m.data else 0])
			lines.append("AC: %d  EV: %d" % [m.ac, m.data.ev if m.data else 0])
			if m.data != null and m.data.is_boss:
				lines.append("** BOSS **")
			break
	# Floor item info
	for it in get_tree().get_nodes_in_group("floor_items"):
		if is_instance_valid(it) and it is FloorItem and it.grid_pos == pos:
			lines.append("")
			lines.append("Item: %s [%s]" % [it.display_name, it.kind])
			break
	# Player info
	if player != null and player.grid_pos == pos:
		lines.append("")
		lines.append("--- You ---")
		lines.append("Turn: %d" % TurnManager.turn_number)
	if lines.is_empty():
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Inspect"
	dlg.ok_button_text = "Close"
	dlg.dialog_text = "\n".join(PackedStringArray(lines))
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(700, 600))


func _get_trait_skills(trait_id: String) -> Dictionary:
	match trait_id:
		"sword": return {"long_blade": 3}
		"polearm_trait": return {"polearm": 3}
		"shield_trait": return {"shields": 3, "short_blade": 1}
		"heavy_armor": return {"armour": 3}
		"axe_trait": return {"axe": 3}
		"mace_trait": return {"mace": 3}
		"brawler": return {"fighting": 3}
		"throwing_trait": return {"throwing": 3}
		"bow_trait": return {"bow": 3}
		"crossbow_trait": return {"crossbow": 3}
		"throwing_ranger": return {"throwing": 3}
		"scout": return {"stealth": 3, "bow": 1}
		"dagger_trait": return {"short_blade": 3}
		"acrobat": return {"dodging": 3}
		"shadow": return {"stealth": 3}
		"evoker": return {"evocations": 3}
		"fire": return {"fire": 3, "spellcasting": 1}
		"ice": return {"cold": 3, "spellcasting": 1}
		"earth": return {"earth": 3, "spellcasting": 1}
		"air": return {"air": 3, "spellcasting": 1}
		"necro": return {"necromancy": 3, "spellcasting": 1}
		"hexer": return {"hexes": 3, "spellcasting": 1}
		"arcane": return {"conjurations": 3, "spellcasting": 1}
		"warper": return {"translocations": 3, "spellcasting": 1}
	return {}


func _on_wait_pressed() -> void:
	if player == null or not player.is_alive or run_over:
		return
	TurnManager.end_player_turn()


func _on_menu_pressed() -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Menu"
	dlg.ok_button_text = "Close"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	dlg.add_child(vb)

	var save_btn := Button.new()
	save_btn.text = "Save & Continue"
	save_btn.custom_minimum_size = Vector2(0, 96)
	save_btn.add_theme_font_size_override("font_size", 40)
	save_btn.pressed.connect(func():
		if meta != null:
			meta.save_to_disk()
		print("Game saved.")
		dlg.queue_free())
	vb.add_child(save_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart Run"
	restart_btn.custom_minimum_size = Vector2(0, 96)
	restart_btn.add_theme_font_size_override("font_size", 40)
	restart_btn.pressed.connect(func():
		dlg.queue_free()
		GameManager.current_depth = 1
		get_tree().change_scene_to_file("res://scenes/main/Game.tscn"))
	vb.add_child(restart_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit to Title"
	quit_btn.custom_minimum_size = Vector2(0, 96)
	quit_btn.add_theme_font_size_override("font_size", 40)
	quit_btn.pressed.connect(func():
		if meta != null:
			meta.save_to_disk()
		dlg.queue_free()
		get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn"))
	vb.add_child(quit_btn)

	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(700, 700))


func _on_rest_pressed() -> void:
	if player == null or player.stats == null:
		return
	if _resting:
		_cancel_rest("cancelled")
		return
	if player.stats.HP >= player.stats.hp_max and player.stats.MP >= player.stats.mp_max:
		print("Already at full health.")
		return
	if _visible_monster_nearby():
		print("Can't rest — enemy in sight.")
		return
	_resting = true
	_rest_turns = 0
	_rest_tick()


func _rest_tick() -> void:
	if not _resting or player == null or player.stats == null:
		return
	if _visible_monster_nearby():
		_cancel_rest("interrupted by enemy")
		return
	var s = player.stats
	s.HP = min(s.hp_max, s.HP + _REST_HP_PER_TURN)
	s.MP = min(s.mp_max, s.MP + _REST_MP_PER_TURN)
	player.stats_changed.emit()
	_rest_turns += 1
	var full: bool = s.HP >= s.hp_max and s.MP >= s.mp_max
	if full or _rest_turns >= _REST_MAX_TURNS:
		_cancel_rest("fully rested" if full else "rest limit reached")
		return
	TurnManager.end_player_turn()


func _cancel_rest(reason: String) -> void:
	if not _resting:
		return
	_resting = false
	print("Rest: %s (%d turns)" % [reason, _rest_turns])
	_rest_turns = 0


func _visible_monster_nearby() -> bool:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null:
		return false
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster and m.is_alive:
			if dmap.is_tile_visible(m.grid_pos):
				return true
	return false


func _spawn_monsters_for_current_depth() -> void:
	# [meta-agent] spawn + connect death to both essence-drop and kill counter.
	var monsters: Array[Monster] = MonsterSpawner.spawn_for_depth(GameManager.current_depth, generator, $EntityLayer)
	for m in monsters:
		if m != null and not m.died.is_connected(_on_monster_died):
			m.died.connect(_on_monster_died)


const _LOOT_DROP_CHANCE: float = 0.35
const _WEAPON_POOL: Array = ["dagger", "short_sword", "arming_sword", "axe", "mace", "club"]
const _ARMOR_POOL: Array = [
	"leather_chest", "chain_chest", "plate_chest",
	"leather_legs", "chain_legs", "plate_legs",
	"leather_boots", "plate_boots",
	"leather_helm", "plate_helm",
	"leather_gloves", "plate_gloves",
]


func _maybe_drop_loot(monster: Monster) -> void:
	if monster == null or not ("grid_pos" in monster):
		return
	if randf() > _LOOT_DROP_CHANCE:
		return
	var entity_layer: Node = $EntityLayer
	var fi: FloorItem = FloorItem.new()
	entity_layer.add_child(fi)
	if randf() < 0.6:
		# Weapon drop — picks from a tier-1-ish pool for M1.
		var wid: String = _WEAPON_POOL[randi() % _WEAPON_POOL.size()]
		fi.setup(monster.grid_pos, wid, WeaponRegistry.display_name_for(wid),
				"weapon", Color(0.75, 0.75, 0.85))
	else:
		var aid: String = _ARMOR_POOL[randi() % _ARMOR_POOL.size()]
		var info: Dictionary = ArmorRegistry.get_info(aid)
		fi.setup(monster.grid_pos, aid, String(info.get("name", aid)),
				"armor", info.get("color", Color(0.6, 0.6, 0.7)),
				{"ac": int(info.get("ac", 0)), "slot": String(info.get("slot", "chest"))})


func _spawn_dummy_items(count: int) -> void:
	# Drop a sample of every consumable so all effects are reachable in test play.
	var entity_layer: Node = $EntityLayer
	var ids: Array = ConsumableRegistry.all_ids()
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 200:
		attempts += 1
		var x: int = randi() % DungeonGenerator.MAP_WIDTH
		var y: int = randi() % DungeonGenerator.MAP_HEIGHT
		var gp: Vector2i = Vector2i(x, y)
		if not generator.is_walkable(gp):
			continue
		if gp == player.grid_pos:
			continue
		var iid: String = String(ids[placed % ids.size()])
		var info: Dictionary = ConsumableRegistry.get_info(iid)
		var fi: FloorItem = FloorItem.new()
		entity_layer.add_child(fi)
		fi.setup(gp, iid, String(info.get("name", iid)), String(info.get("kind", "junk")),
				info.get("color", Color(0.9, 0.9, 0.4)))
		placed += 1


func _on_monster_died(monster: Monster) -> void:
	kill_count += 1
	if meta != null and monster != null and monster.data != null:
		meta.record_kill(String(monster.data.id))
	if player != null and player.trait_res != null and player.trait_res.special == "holy_light":
		if player.stats != null and player.is_alive:
			var heal: int = max(1, int(player.stats.hp_max * 0.2))
			player.stats.HP = min(player.stats.hp_max, player.stats.HP + heal)
			player.stats_changed.emit()
	if essence_system != null:
		essence_system.try_drop_from_monster(monster)
	# M1: small chance of loot drop at death tile.
	_maybe_drop_loot(monster)
	# [skill-agent] award XP to trained skills matching weapon + passive tags.
	if skill_system != null and player != null and monster != null and monster.data != null:
		var xp_gain: int = int(monster.data.xp_value)
		if xp_gain <= 0:
			xp_gain = max(1, int(monster.data.tier) * 8)
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
		# Player-level XP: same magnitude as skill grant. Player.grant_xp handles
		# rollover and emits leveled_up for the popup flow.
		player.grant_xp(xp_gain)


func _on_player_moved(new_pos: Vector2i) -> void:
	# Any deliberate movement cancels an in-progress rest.
	if _resting:
		_cancel_rest("movement")
	var cam: Camera2D = $Camera2D
	var cam_target: Vector2 = Vector2(new_pos.x * TILE_SIZE + TILE_SIZE / 2.0, new_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween()
	_cam_tween.tween_property(cam, "position", cam_target, _CAM_FOLLOW_DUR)
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		dmap.update_fov(new_pos)
		_refresh_actor_visibility(dmap)
		_refresh_minimap_preview(dmap, new_pos)


func _refresh_minimap_preview(dmap: DungeonMap, player_pos: Vector2i) -> void:
	if _top_hud_ref == null or not _top_hud_ref.has_method("set_minimap_texture"):
		return
	var tex: ImageTexture = _build_minimap_texture(dmap, player_pos)
	_top_hud_ref.set_minimap_texture(tex)


func _on_player_xp_changed(cur: int, to_next: int, lv: int, top_hud: Node) -> void:
	if top_hud != null and top_hud.has_method("set_xp"):
		top_hud.set_xp(cur, to_next, lv)


func _refresh_actor_visibility(dmap: DungeonMap) -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster:
			m.visible = dmap.is_tile_visible(m.grid_pos)
			if m.visible and meta != null and m.data != null:
				meta.register_monster(String(m.data.id))
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c) and c is Companion:
			# Companions stay visible whenever their tile is explored — even
			# if the player turns their back, the player knows their ally
			# is there.
			c.visible = dmap.is_explored(c.grid_pos)
	for it in get_tree().get_nodes_in_group("floor_items"):
		if is_instance_valid(it) and it is FloorItem:
			it.visible = dmap.is_tile_visible(it.grid_pos)


func _on_stairs_tapped(_pos: Vector2i) -> void:
	if run_over:
		return
	if GameManager.current_depth >= MAX_DEPTH:
		_end_run(true, "")
		return
	var used_secondary: bool = (player.grid_pos == generator.stairs_down_pos2)
	_save_current_floor()
	GameManager.current_depth += 1
	_regenerate_dungeon(false, used_secondary)


func _on_stairs_up_tapped(_pos: Vector2i) -> void:
	if run_over:
		return
	if GameManager.current_depth <= 1:
		return
	var used_secondary: bool = (player.grid_pos == generator.spawn_pos2)
	_save_current_floor()
	GameManager.current_depth -= 1
	_regenerate_dungeon(true, used_secondary)


## going_up=true places the player at the new floor's stairs_down (where they
## originally descended). Otherwise spawn_pos (= stairs_up, natural entry
## when descending). _base_seed is fixed per run so the same depth yields
## the same map on every revisit.
func _regenerate_dungeon(going_up: bool, secondary: bool = false) -> void:
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m):
			TurnManager.unregister_actor(m)
			m.queue_free()
	# Summoned companions don't follow between floors — they unravel back
	# into the essence until the player re-invokes.
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c):
			TurnManager.unregister_actor(c)
			c.queue_free()
	for it in get_tree().get_nodes_in_group("floor_items"):
		if is_instance_valid(it):
			it.queue_free()
	if is_instance_valid(generator):
		generator.queue_free()
	GameManager.current_branch = GameManager.branch_for_depth(GameManager.current_depth)
	TileRenderer._cache.clear()
	generator = DungeonGenerator.new()
	add_child(generator)
	generator.generate(GameManager.current_depth, _base_seed)
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	dmap.render(generator)
	player.generator = generator
	var entry_pos: Vector2i
	if going_up:
		entry_pos = generator.stairs_down_pos2 if secondary else generator.stairs_down_pos
	else:
		entry_pos = generator.spawn_pos2 if secondary else generator.spawn_pos
	player.grid_pos = entry_pos
	player.position = Vector2(entry_pos.x * TILE_SIZE + TILE_SIZE / 2.0, entry_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	player.visible = true
	player.queue_redraw()
	dmap.update_fov(entry_pos)
	var cam: Camera2D = $Camera2D
	cam.position = player.position
	if touch_input:
		touch_input.generator = generator
	if _top_hud_ref != null and _top_hud_ref.has_method("set_depth"):
		_top_hud_ref.set_depth(GameManager.current_depth)
	_refresh_minimap_preview(dmap, entry_pos)
	await get_tree().process_frame
	if _floor_state.has(GameManager.current_depth):
		_restore_floor(GameManager.current_depth)
	else:
		_spawn_monsters_for_current_depth()
		_spawn_dummy_items(5)
	_refresh_actor_visibility(dmap)


func _save_current_floor() -> void:
	if generator == null:
		return
	var snapshot: Dictionary = {"monsters": [], "items": []}
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster):
			continue
		if not m.is_alive:
			continue
		var mid: String = String(m.data.id) if m.data != null else ""
		if mid == "":
			continue
		snapshot.monsters.append({
			"id": mid,
			"pos": m.grid_pos,
			"hp": m.hp,
		})
	for it in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(it) or not (it is FloorItem):
			continue
		snapshot.items.append({
			"pos": it.grid_pos,
			"id": it.item_id,
			"name": it.display_name,
			"kind": it.kind,
			"color": it.color,
			"extra": it.extra.duplicate(),
		})
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		snapshot["explored"] = dmap.explored.duplicate()
	_floor_state[GameManager.current_depth] = snapshot


func _restore_floor(depth: int) -> void:
	var snapshot: Dictionary = _floor_state.get(depth, {})
	if snapshot.is_empty():
		return
	var monster_scene: PackedScene = load("res://scenes/entities/Monster.tscn")
	var entity_layer: Node = $EntityLayer
	if monster_scene != null:
		for m_info in snapshot.get("monsters", []):
			var mid: String = String(m_info.get("id", ""))
			if mid == "":
				continue
			var tres: Resource = load("res://resources/monsters/%s.tres" % mid)
			if tres == null:
				continue
			var m: Monster = monster_scene.instantiate()
			entity_layer.add_child(m)
			m.setup(generator, m_info.get("pos", Vector2i.ZERO), tres)
			m.hp = int(m_info.get("hp", m.hp))
			if not m.died.is_connected(_on_monster_died):
				m.died.connect(_on_monster_died)
	for it_info in snapshot.get("items", []):
		var fi := FloorItem.new()
		entity_layer.add_child(fi)
		fi.setup(it_info.get("pos", Vector2i.ZERO),
				String(it_info.get("id", "")),
				String(it_info.get("name", "")),
				String(it_info.get("kind", "junk")),
				it_info.get("color", Color(1, 1, 0)),
				it_info.get("extra", {}))
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null and snapshot.has("explored"):
		dmap.explored = snapshot["explored"].duplicate()
		dmap.queue_redraw()


## Spawn a Companion at the first walkable tile adjacent to the player.
## Uses the MonsterData resource keyed by essence id as the companion's
## stat block + visual.
func _on_summon_companion_requested(essence_id: String) -> void:
	if player == null or generator == null:
		return
	var companion_id: String = String(_ESSENCE_TO_COMPANION.get(essence_id, ""))
	if companion_id == "":
		print("(no companion template for essence %s)" % essence_id)
		return
	var tres_path: String = "res://resources/monsters/%s.tres" % companion_id
	if not ResourceLoader.exists(tres_path):
		print("(companion template missing: %s)" % tres_path)
		return
	var mdata: MonsterData = load(tres_path)
	var spawn_pos: Vector2i = _find_free_adjacent_tile(player.grid_pos)
	if spawn_pos == player.grid_pos:  # no room found
		print("(no free tile next to you to summon on)")
		return
	var c: Companion = _COMPANION_SCENE.instantiate()
	$EntityLayer.add_child(c)
	c.setup(generator, spawn_pos, mdata)
	c.lifetime = 60  # ~60 turns before despawning
	print("Summoned %s." % companion_id)


## First walkable, unoccupied 8-neighbour of `center`. Returns center itself
## if nothing is free (caller should treat that as failure).
func _find_free_adjacent_tile(center: Vector2i) -> Vector2i:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var p: Vector2i = center + Vector2i(dx, dy)
			if not generator.is_walkable(p):
				continue
			if _tile_occupied_any(p):
				continue
			return p
	return center


func _tile_occupied_any(pos: Vector2i) -> bool:
	for m in get_tree().get_nodes_in_group("monsters"):
		if m is Monster and m.grid_pos == pos:
			return true
	for c in get_tree().get_nodes_in_group("companions"):
		if c is Companion and c.grid_pos == pos:
			return true
	if player != null and player.grid_pos == pos:
		return true
	return false


func _on_identify_one_requested() -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var unidentified: Array = []
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		if ConsumableRegistry.has(iid) and not GameManager.is_identified(iid):
			unidentified.append(it)
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Identify Which?"
	dlg.ok_button_text = "Cancel"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)
	if unidentified.is_empty():
		var l := Label.new()
		l.text = "You have nothing left to identify."
		l.add_theme_font_size_override("font_size", 40)
		vb.add_child(l)
	else:
		var prompt := Label.new()
		prompt.text = "Choose an item to reveal:"
		prompt.add_theme_font_size_override("font_size", 40)
		vb.add_child(prompt)
		for it in unidentified:
			var iid: String = String(it.get("id", ""))
			var kind: String = String(it.get("kind", ""))
			var disp: String = GameManager.display_name_for_item(iid, String(it.get("name", "?")), kind)
			var btn := Button.new()
			btn.text = "%s [%s]" % [disp, kind]
			btn.custom_minimum_size = Vector2(0, 80)
			btn.add_theme_font_size_override("font_size", 40)
			btn.pressed.connect(_on_identify_pick.bind(iid, dlg))
			vb.add_child(btn)
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 1000))


func _on_identify_pick(id: String, dlg: AcceptDialog) -> void:
	GameManager.identify(id)
	dlg.queue_free()


func _on_player_leveled_up(new_level: int) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or not popup_mgr.has_method("show_levelup_popup"):
		return
	popup_mgr.show_levelup_popup(new_level, Callable(player, "apply_level_up_stat"))


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

func _close_all_dialogs() -> void:
	for d in [_bag_dlg, _skills_dlg, _magic_dlg, _status_dlg, _map_dlg]:
		if d != null and is_instance_valid(d):
			d.queue_free()
	_bag_dlg = null
	_skills_dlg = null
	_magic_dlg = null
	_status_dlg = null
	_map_dlg = null


func _on_magic_pressed() -> void:
	if _magic_dlg != null and is_instance_valid(_magic_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	_open_magic_dialog()


func _on_skills_button_pressed() -> void:
	if _skills_dlg != null and is_instance_valid(_skills_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	_open_skills_dialog("weapon")


func _open_skills_dialog(category: String) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Skills"
	dlg.ok_button_text = "Close"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)

	var skill_header := HBoxContainer.new()
	skill_header.add_theme_constant_override("separation", 8)
	var skill_title := Label.new()
	skill_title.text = "Skills"
	skill_title.add_theme_font_size_override("font_size", 40)
	skill_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_header.add_child(skill_title)
	var skill_close := Button.new()
	skill_close.text = "X"
	skill_close.custom_minimum_size = Vector2(72, 72)
	skill_close.add_theme_font_size_override("font_size", 40)
	skill_close.pressed.connect(dlg.queue_free)
	skill_header.add_child(skill_close)
	vb.add_child(skill_header)

	var mode_hbox := HBoxContainer.new()
	mode_hbox.add_theme_constant_override("separation", 8)
	var mode_label := Label.new()
	mode_label.text = "Training:"
	mode_label.add_theme_font_size_override("font_size", 40)
	mode_hbox.add_child(mode_label)
	var mode_btn := Button.new()
	mode_btn.text = "AUTO" if skill_system.auto_training else "MANUAL"
	mode_btn.custom_minimum_size = Vector2(200, 56)
	mode_btn.add_theme_font_size_override("font_size", 40)
	mode_btn.pressed.connect(func():
		skill_system.auto_training = not skill_system.auto_training
		mode_btn.text = "AUTO" if skill_system.auto_training else "MANUAL")
	mode_hbox.add_child(mode_btn)
	vb.add_child(mode_hbox)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	for cat in _SKILL_CATEGORIES:
		var tb := Button.new()
		tb.text = _SKILL_CATEGORY_LABELS.get(cat, cat)
		tb.custom_minimum_size = Vector2(0, 48)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		tb.button_pressed = (cat == category)
		tb.pressed.connect(_on_skills_tab.bind(cat, dlg))
		tabs_hbox.add_child(tb)
	vb.add_child(tabs_hbox)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	scroll.add_child(rows)

	var state: Dictionary = {}
	if "skill_state" in player and player.skill_state is Dictionary:
		state = player.skill_state
	for skill_id in SkillSystem.SKILL_IDS:
		var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
		if category != "" and cat_id != category:
			continue
		rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))

	popup_mgr.add_child(dlg)
	_skills_dlg = dlg
	dlg.tree_exited.connect(func():
		if _skills_dlg == dlg: _skills_dlg = null)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(960, 1700))


func _on_skills_tab(cat: String, dlg: AcceptDialog) -> void:
	dlg.queue_free()
	_open_skills_dialog(cat)


func _on_skill_training_toggled(pressed: bool, skill_id: String) -> void:
	if skill_system == null or player == null:
		return
	skill_system.set_training(player, skill_id, pressed)


const _SKILL_DESCS: Dictionary = {
	"axe": "Axe DMG +5%/lv",
	"short_blade": "Dagger DMG +5%/lv",
	"long_blade": "Sword DMG +5%/lv",
	"mace": "Mace DMG +5%/lv",
	"polearm": "Polearm DMG +5%/lv",
	"staff": "Staff DMG +5%/lv",
	"bow": "Bow DMG +5%/lv",
	"crossbow": "Crossbow DMG +5%/lv",
	"sling": "Sling DMG +5%/lv",
	"throwing": "Throw DMG +5%/lv",
	"fighting": "Melee DMG +2/lv",
	"armour": "AC +1 per 4 lv",
	"dodging": "EV +1 per 3 lv",
	"shields": "Block 5%/lv",
	"spellcasting": "Fail rate -3%/lv, MP +1/lv",
	"conjurations": "Conj power +2/lv",
	"fire": "Fire power +2/lv",
	"cold": "Ice power +2/lv",
	"earth": "Earth power +2/lv",
	"air": "Air power +2/lv",
	"necromancy": "Necro power +2/lv",
	"hexes": "Hex power +2/lv",
	"translocations": "Blink range +1/lv",
	"summonings": "Summon power +2/lv",
	"stealth": "Detect range -1/lv",
	"evocations": "Wand power +2/lv",
	"essence_channeling": "Essence power +2/lv",
}

func _build_skill_row(skill_id: String, category: String, entry: Dictionary) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 8)

	var chk := CheckBox.new()
	chk.button_pressed = bool(entry.get("training", false))
	chk.custom_minimum_size = Vector2(56, 56)
	chk.toggled.connect(_on_skill_training_toggled.bind(skill_id))
	row.add_child(chk)

	var name_lab := Label.new()
	name_lab.text = String(SkillRow.SKILL_NAMES.get(skill_id, skill_id))
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.add_theme_font_size_override("font_size", 40)
	row.add_child(name_lab)

	var level: int = int(entry.get("level", 0))
	var xp: float = float(entry.get("xp", 0.0))
	var need: float = SkillSystem.xp_for_level(level + 1)
	var lv_lab := Label.new()
	if level >= SkillSystem.MAX_LEVEL:
		lv_lab.text = "MAX"
	else:
		lv_lab.text = "Lv.%d" % level
	lv_lab.add_theme_font_size_override("font_size", 40)
	lv_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lv_lab)
	outer.add_child(row)

	var info_line := Label.new()
	var desc_text: String = String(_SKILL_DESCS.get(skill_id, ""))
	var is_training: bool = bool(entry.get("training", false))
	var parts: Array = [desc_text]
	if level > 0 and level < SkillSystem.MAX_LEVEL:
		parts.append("XP %d/%d" % [int(xp), int(need)])
	if not skill_system.auto_training and is_training:
		var trained_count: int = _count_trained_skills()
		if trained_count > 0:
			parts.append("%d%% XP" % int(100.0 / trained_count))
	info_line.text = "  |  ".join(PackedStringArray(parts))
	info_line.add_theme_font_size_override("font_size", 34)
	info_line.modulate = Color(0.6, 0.75, 0.6)
	outer.add_child(info_line)

	outer.add_child(HSeparator.new())
	return outer


func _count_trained_skills() -> int:
	if player == null or not ("skill_state" in player):
		return 1
	var count: int = 0
	for sid in player.skill_state:
		if bool(player.skill_state[sid].get("training", false)):
			count += 1
	return max(1, count)


## ---- MAGIC DIALOG (separate from Skills) ---------------------------------

func _open_magic_dialog() -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Magic"
	dlg.ok_button_text = "Close"

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var mp_lab := Label.new()
	var cur_mp: int = player.stats.MP if player.stats != null else 0
	var max_mp: int = player.stats.mp_max if player.stats != null else 0
	mp_lab.text = "MP  %d / %d" % [cur_mp, max_mp]
	mp_lab.add_theme_font_size_override("font_size", 40)
	mp_lab.modulate = Color(0.45, 0.7, 1.0)
	mp_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(mp_lab)
	var close_btn := Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(72, 72)
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.pressed.connect(dlg.queue_free)
	header.add_child(close_btn)
	vb.add_child(header)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_system)
	if known.is_empty():
		var hint := Label.new()
		hint.text = "No spells known.\nRead spellbooks or pick a magic job to learn spells."
		hint.add_theme_font_size_override("font_size", 40)
		hint.modulate = Color(0.7, 0.7, 0.8)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(hint)
	else:
		for spell_id in known:
			rows.add_child(_build_magic_row(spell_id, dlg))

	popup_mgr.add_child(dlg)
	_magic_dlg = dlg
	dlg.tree_exited.connect(func():
		if _magic_dlg == dlg: _magic_dlg = null)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(900, 1700))


func _build_magic_row(spell_id: String, dlg: AcceptDialog) -> Control:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return Control.new()

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 110)
	row.add_theme_constant_override("separation", 8)

	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spell_name: String = String(info.get("name", spell_id))
	var sch_id: String = String(info.get("school", ""))
	var s_lv: int = skill_system.get_level(player, sch_id) if skill_system and player else 0
	var s_sc: int = skill_system.get_level(player, "spellcasting") if skill_system and player else 0
	var fail_p: int = int(SpellRegistry.failure_chance(spell_id, s_lv, s_sc) * 100)
	var fail_txt: String = " (%d%%)" % fail_p if fail_p > 0 else ""
	name_btn.text = "%s  [%d MP]%s" % [spell_name, int(info.get("mp", 0)), fail_txt]
	name_btn.add_theme_font_size_override("font_size", 40)
	name_btn.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	name_btn.pressed.connect(_show_spell_info.bind(spell_id))
	row.add_child(name_btn)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)

	var cast_btn := Button.new()
	cast_btn.text = "Cast"
	cast_btn.custom_minimum_size = Vector2(140, 56)
	cast_btn.add_theme_font_size_override("font_size", 40)
	cast_btn.disabled = (player.stats == null or player.stats.MP < int(info.get("mp", 1)))
	var targeting_type: String = String(info.get("targeting", "single"))
	if targeting_type == "self":
		cast_btn.pressed.connect(_on_cast_pressed.bind(spell_id, dlg))
	else:
		cast_btn.pressed.connect(_on_cast_with_targeting.bind(spell_id, dlg))
	btns.add_child(cast_btn)

	var qs_btn := Button.new()
	qs_btn.text = "Quickslot"
	qs_btn.custom_minimum_size = Vector2(140, 48)
	qs_btn.add_theme_font_size_override("font_size", 40)
	qs_btn.pressed.connect(_assign_spell_quickslot.bind(spell_id, dlg))
	btns.add_child(qs_btn)

	row.add_child(btns)
	return row


func _show_spell_info(spell_id: String) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = String(info.get("name", spell_id))
	dlg.ok_button_text = "Close"
	var sch: String = String(info.get("school", "?"))
	var sch_lv: int = skill_system.get_level(player, sch) if skill_system and player else 0
	var sc_lv: int = skill_system.get_level(player, "spellcasting") if skill_system and player else 0
	var fail_pct: int = int(SpellRegistry.failure_chance(spell_id, sch_lv, sc_lv) * 100)
	var text: String = "%s\n\nMP Cost: %d\nSchool: %s (Lv.%d)\nDifficulty: %d\nFailure: %d%%\nRange: %d" % [
		String(info.get("desc", "")),
		int(info.get("mp", 0)),
		sch, sch_lv,
		int(info.get("difficulty", 1)),
		fail_pct,
		int(info.get("range", 6)),
	]
	if info.has("min_dmg") and int(info.get("min_dmg", 0)) > 0:
		text += "\nDamage: %d-%d + power" % [int(info.get("min_dmg", 0)), int(info.get("max_dmg", 0))]
	dlg.dialog_text = text
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(700, 600))


func _on_cast_with_targeting(spell_id: String, dlg: AcceptDialog) -> void:
	dlg.queue_free()
	_targeting_spell = spell_id
	if touch_input != null:
		touch_input.targeting_mode = true
	_show_targeting_hint()


func _on_target_selected(pos: Vector2i) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		dmap.danger_tiles.clear()
		dmap.queue_redraw()
	if _targeting_spell == "":
		return
	var target_monster: Monster = null
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster and m.is_alive and m.grid_pos == pos:
			target_monster = m
			break
	if target_monster == null:
		print("Targeting cancelled.")
		_targeting_spell = ""
		return
	var spell_id: String = _targeting_spell
	_targeting_spell = ""
	_execute_targeted_cast(spell_id, target_monster)


func _show_targeting_hint() -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or player == null:
		return
	var info: Dictionary = SpellRegistry.get_spell(_targeting_spell)
	var spell_range: int = int(info.get("range", 6))
	var targets: Array[Vector2i] = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if not dmap.is_tile_visible(m.grid_pos):
			continue
		if player.grid_pos.distance_to(m.grid_pos) <= float(spell_range):
			targets.append(m.grid_pos)
	dmap.danger_tiles = targets
	dmap.queue_redraw()
	print("Tap a target to cast %s. Tap empty tile to cancel." % String(info.get("name", _targeting_spell)))


func _execute_targeted_cast(spell_id: String, target: Monster) -> void:
	if player == null or player.stats == null:
		return
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return
	var mp_cost: int = int(info.get("mp", 1))
	if player.stats.MP < mp_cost:
		print("Not enough MP.")
		return
	player.stats.MP -= mp_cost
	player.stats_changed.emit()
	var school: String = String(info.get("school", "spellcasting"))
	var school_lv: int = skill_system.get_level(player, school) if skill_system else 0
	var sc_lv: int = skill_system.get_level(player, "spellcasting") if skill_system else 0
	var staff_school2: String = WeaponRegistry.staff_spell_school(player.equipped_weapon_id)
	var staff_bonus2: int = 0
	if staff_school2 == school or staff_school2 == "":
		staff_bonus2 = WeaponRegistry.staff_spell_bonus(player.equipped_weapon_id)
	var eff_school2: int = school_lv + staff_bonus2
	var fail: float = SpellRegistry.failure_chance(spell_id, eff_school2, sc_lv)
	if randf() < fail:
		print("Spell fizzles! (%d%% fail)" % int(fail * 100))
		TurnManager.end_player_turn()
		return
	var int_bonus: int = player.stats.INT / 3 if player.stats else 0
	var power: int = eff_school2 + sc_lv / 2 + int_bonus
	var spell_color: Color = info.get("color", Color.WHITE)
	var fx_layer: Node2D = $EntityLayer
	var targeting_type: String = String(info.get("targeting", "single"))
	if targeting_type == "area":
		var radius: int = int(info.get("radius", 2))
		var total_dmg: int = 0
		var hits: int = 0
		var hit_positions: Array = []
		for m in get_tree().get_nodes_in_group("monsters"):
			if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
				continue
			var dist: int = max(abs(m.grid_pos.x - target.grid_pos.x), abs(m.grid_pos.y - target.grid_pos.y))
			if dist > radius:
				continue
			var dmg: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2
			if dist > 0:
				dmg = max(1, dmg - dist * 3)
			hit_positions.append(m.position)
			m.take_damage(dmg)
			total_dmg += dmg
			hits += 1
		SpellFX.cast_area(fx_layer, player.position, target.position, hit_positions, spell_color, float(radius) * float(TILE_SIZE) + float(TILE_SIZE) / 2.0)
		print("%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg])
	else:
		var dmg: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2
		var effect_type: String = String(info.get("effect", "damage"))
		if effect_type == "slow":
			target.slowed_turns = 4
			SpellFX.cast_slow(fx_layer, target.position, spell_color)
			print("%s is slowed!" % String(target.data.display_name if target.data else "enemy"))
		else:
			target.take_damage(dmg)
			SpellFX.cast_single(fx_layer, player.position, target, dmg, spell_color)
			print("%s → %d dmg" % [String(info.get("name", spell_id)), dmg])
	if skill_system != null:
		skill_system.grant_xp(player, float(info.get("mp", 1)) * 8.0, [school, "spellcasting"])
	TurnManager.end_player_turn()


func _assign_spell_quickslot(spell_id: String, dlg: AcceptDialog) -> void:
	if player == null:
		return
	for i in player.quickslot_ids.size():
		if player.quickslot_ids[i] == "":
			player.quickslot_ids[i] = "spell:" + spell_id
			player.quickslots_changed.emit()
			dlg.queue_free()
			_on_magic_pressed()
			return
	for i in player.quickslot_ids.size():
		if player.quickslot_ids[i].begins_with("spell:"):
			player.quickslot_ids[i] = "spell:" + spell_id
			player.quickslots_changed.emit()
			dlg.queue_free()
			_on_magic_pressed()
			return
	print("No empty quickslot.")


## ---- SPELL CASTING -------------------------------------------------------

## Builds the spell panel for the CAST tab of the skills dialog.
func _build_spell_panel(container: VBoxContainer, dlg: AcceptDialog) -> void:
	# MP header.
	var mp_lab := Label.new()
	var cur_mp: int = player.stats.MP if player.stats != null else 0
	var max_mp: int = player.stats.mp_max if player.stats != null else 0
	mp_lab.text = "MP  %d / %d" % [cur_mp, max_mp]
	mp_lab.add_theme_font_size_override("font_size", 40)
	mp_lab.modulate = Color(0.45, 0.7, 1.0)
	container.add_child(mp_lab)
	container.add_child(HSeparator.new())

	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_system)
	if known.is_empty():
		var hint := Label.new()
		hint.text = "No spells known.\nTrain conjurations, fire, cold, earth, air,\nnecromancy, hexes, or translocations (lv 1+)\nto unlock spells."
		hint.add_theme_font_size_override("font_size", 40)
		hint.modulate = Color(0.7, 0.7, 0.8)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		container.add_child(hint)
		return

	for spell_id in known:
		var info: Dictionary = SpellRegistry.get_spell(spell_id)
		if info.is_empty():
			continue

		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 96)
		row.add_theme_constant_override("separation", 12)

		# Colour swatch + name + MP cost.
		var name_vb := VBoxContainer.new()
		name_vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_lab := Label.new()
		name_lab.text = "%s  [%d MP]" % [String(info.get("name", spell_id)), int(info.get("mp", 0))]
		name_lab.add_theme_font_size_override("font_size", 40)
		name_lab.modulate = info.get("color", Color.WHITE)
		name_vb.add_child(name_lab)
		var desc_lab := Label.new()
		desc_lab.text = String(info.get("desc", ""))
		desc_lab.add_theme_font_size_override("font_size", 40)
		desc_lab.modulate = Color(0.75, 0.75, 0.85)
		desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_vb.add_child(desc_lab)
		row.add_child(name_vb)

		var cast_btn := Button.new()
		cast_btn.text = "Cast"
		cast_btn.custom_minimum_size = Vector2(130, 0)
		cast_btn.add_theme_font_size_override("font_size", 40)
		cast_btn.disabled = (player.stats == null or player.stats.MP < int(info.get("mp", 1)))
		cast_btn.pressed.connect(_on_cast_pressed.bind(spell_id, dlg))
		row.add_child(cast_btn)

		container.add_child(row)
		container.add_child(HSeparator.new())


func _on_cast_pressed(spell_id: String, dlg: AcceptDialog) -> void:
	dlg.queue_free()
	var result: Dictionary = _execute_cast(spell_id)
	print("[Spell] %s" % result.get("message", spell_id))
	if result.get("success", false):
		# Train school + spellcasting on successful cast.
		if skill_system != null:
			var info: Dictionary = SpellRegistry.get_spell(spell_id)
			var school: String = String(info.get("school", "spellcasting"))
			var xp_gain: float = float(info.get("mp", 1)) * 8.0
			skill_system.grant_xp(player, xp_gain, [school, "spellcasting"])
		TurnManager.end_player_turn()


func _execute_cast(spell_id: String) -> Dictionary:
	if player == null or player.stats == null:
		return {"success": false, "message": "No player"}
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return {"success": false, "message": "Unknown spell: %s" % spell_id}

	var mp_cost: int = int(info.get("mp", 1))
	if player.stats.MP < mp_cost:
		return {"success": false, "message": "Not enough MP (%d/%d)" % [player.stats.MP, mp_cost]}

	player.stats.MP -= mp_cost
	player.stats_changed.emit()

	var school: String = String(info.get("school", "spellcasting"))
	var school_lv: int = skill_system.get_level(player, school) if skill_system else 0
	var sc_lv: int = skill_system.get_level(player, "spellcasting") if skill_system else 0
	var staff_school: String = WeaponRegistry.staff_spell_school(player.equipped_weapon_id)
	var staff_bonus: int = 0
	if staff_school == school or staff_school == "":
		staff_bonus = WeaponRegistry.staff_spell_bonus(player.equipped_weapon_id)
	var eff_school: int = school_lv + staff_bonus
	var fail: float = SpellRegistry.failure_chance(spell_id, eff_school, sc_lv)
	if randf() < fail:
		return {"success": false, "message": "Spell fizzles! (%d%% fail)" % int(fail * 100)}
	var int_bonus: int = player.stats.INT / 3 if player.stats else 0
	var power: int = eff_school + sc_lv / 2 + int_bonus

	var targeting: String = String(info.get("targeting", "single"))
	match targeting:
		"self":   return _cast_self_spell(spell_id, info, power)
		"single": return _cast_single_target(spell_id, info, power)
		"area":   return _cast_area_spell(spell_id, info, power)
		_:        return {"success": true, "message": "Spell fizzles."}


func _cast_single_target(spell_id: String, info: Dictionary, power: int) -> Dictionary:
	var target: Monster = _find_nearest_visible_monster(int(info.get("range", 6)))
	if target == null:
		# Refund MP — no valid target.
		player.stats.MP = min(player.stats.mp_max, player.stats.MP + int(info.get("mp", 1)))
		player.stats_changed.emit()
		return {"success": false, "message": "No visible target in range."}

	var tname: String = ""
	if target.data != null and "display_name" in target.data:
		tname = String(target.data.display_name)
	else:
		tname = target.name

	var spell_color: Color = info.get("color", Color.WHITE)
	var fx_layer: Node2D = $EntityLayer
	var effect: String = String(info.get("effect", "damage"))

	if effect == "slow":
		target.slowed_turns = 4
		SpellFX.cast_slow(fx_layer, target.position, spell_color)
		return {"success": true, "message": "%s is slowed for 4 turns!" % tname}
	if effect == "confuse":
		target.slowed_turns = 4
		SpellFX.cast_slow(fx_layer, target.position, spell_color)
		return {"success": true, "message": "%s is confused for 4 turns!" % tname}
	if effect == "petrify":
		target.slowed_turns = 5
		SpellFX.cast_slow(fx_layer, target.position, spell_color)
		return {"success": true, "message": "%s is petrified for 5 turns!" % tname}
	if effect == "agony":
		var half_hp: int = max(1, target.hp / 2)
		target.take_damage(half_hp)
		SpellFX.cast_single(fx_layer, player.position, target, half_hp, spell_color)
		return {"success": true, "message": "%s: HP halved! (%d dmg)" % [tname, half_hp]}
	if effect == "vampiric":
		var dmg_v: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2
		target.take_damage(dmg_v)
		player.stats.HP = min(player.stats.hp_max, player.stats.HP + dmg_v)
		player.stats_changed.emit()
		SpellFX.cast_single(fx_layer, player.position, target, dmg_v, spell_color)
		return {"success": true, "message": "Drained %d HP from %s!" % [dmg_v, tname]}
	if effect == "dot_fire":
		var dmg_f: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 4
		target.take_damage(dmg_f)
		target.slowed_turns = 0
		if target.has_method("set_meta"):
			target.set_meta("burn_turns", 4)
			target.set_meta("burn_dmg", max(1, dmg_f / 2))
		SpellFX.cast_single(fx_layer, player.position, target, dmg_f, spell_color)
		return {"success": true, "message": "%s is burning! (%d + %d/turn)" % [tname, dmg_f, max(1, dmg_f / 2)]}

	var dmg: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2
	target.take_damage(dmg)
	SpellFX.cast_single(fx_layer, player.position, target, dmg, spell_color)
	return {"success": true, "message": "%s → %s: %d dmg" % [String(info.get("name", spell_id)), tname, dmg], "damage": dmg}


func _cast_area_spell(spell_id: String, info: Dictionary, power: int) -> Dictionary:
	var center_m: Monster = _find_nearest_visible_monster(int(info.get("range", 8)))
	if center_m == null:
		player.stats.MP = min(player.stats.mp_max, player.stats.MP + int(info.get("mp", 1)))
		player.stats_changed.emit()
		return {"success": false, "message": "No visible target in range."}

	var center: Vector2i = center_m.grid_pos
	var center_px: Vector2 = center_m.position
	var radius: int = int(info.get("radius", 2))
	var spell_color: Color = info.get("color", Color.WHITE)
	var fx_layer: Node2D = $EntityLayer

	var total_dmg: int = 0
	var hits: int = 0
	var hit_positions: Array = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		var dist: int = max(abs(m.grid_pos.x - center.x), abs(m.grid_pos.y - center.y))
		if dist > radius:
			continue
		var dmg: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2
		if dist > 0:
			dmg = max(1, dmg - dist * 3)
		hit_positions.append(m.position)
		m.take_damage(dmg)
		total_dmg += dmg
		hits += 1

	var tile_r_px: float = float(radius) * float(TILE_SIZE) + float(TILE_SIZE) / 2.0
	SpellFX.cast_area(fx_layer, player.position, center_px, hit_positions, spell_color, tile_r_px)
	SpellFX.float_text(fx_layer, center_px + Vector2(0, -24),
			"%d dmg" % total_dmg, spell_color)

	if hits == 0:
		return {"success": true, "message": "%s hits nothing." % String(info.get("name", spell_id))}
	return {"success": true, "message": "%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg]}


func _cast_self_spell(spell_id: String, _info: Dictionary, _power: int) -> Dictionary:
	if spell_id == "blink":
		var old_px: Vector2 = player.position
		var fx_layer: Node2D = $EntityLayer
		for _i in 60:
			var dx: int = randi_range(-6, 6)
			var dy: int = randi_range(-6, 6)
			if abs(dx) + abs(dy) < 2:
				continue
			var dest: Vector2i = player.grid_pos + Vector2i(dx, dy)
			if generator == null or not generator.is_walkable(dest):
				continue
			var blocked: bool = false
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m is Monster and m.grid_pos == dest:
					blocked = true
					break
			if blocked:
				continue
			player.grid_pos = dest
			player.position = Vector2(dest.x * TILE_SIZE + TILE_SIZE / 2, dest.y * TILE_SIZE + TILE_SIZE / 2)
			var dmap: DungeonMap = $DungeonLayer/DungeonMap
			dmap.update_fov(dest)
			_refresh_minimap_preview(dmap, dest)
			var cam: Camera2D = $Camera2D
			cam.position = player.position
			SpellFX.cast_blink(fx_layer, old_px, player.position)
			return {"success": true, "message": "You blink to a new location."}
		return {"success": true, "message": "Blink fizzles — nowhere safe nearby."}
	return {"success": true, "message": ""}


func _find_nearest_visible_monster(range_tiles: int = 99) -> Monster:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or player == null:
		return null
	var best: Monster = null
	var best_dist: float = INF
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if not dmap.is_tile_visible(m.grid_pos):
			continue
		var d: float = float(player.grid_pos.distance_to(m.grid_pos))
		if d <= float(range_tiles) and d < best_dist:
			best_dist = d
			best = m
	return best


## ---- BAG -----------------------------------------------------------------

func _on_bag_pressed() -> void:
	if _bag_dlg != null and is_instance_valid(_bag_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Bag"
	dlg.ok_button_text = "Close"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	var bag_title := Label.new()
	bag_title.text = "Bag"
	bag_title.add_theme_font_size_override("font_size", 40)
	bag_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(bag_title)
	var bag_close := Button.new()
	bag_close.text = "X"
	bag_close.custom_minimum_size = Vector2(72, 72)
	bag_close.add_theme_font_size_override("font_size", 40)
	bag_close.pressed.connect(dlg.queue_free)
	header.add_child(bag_close)
	vb.add_child(header)

	var cat_tabs := HBoxContainer.new()
	cat_tabs.add_theme_constant_override("separation", 4)
	for cat in ["all", "weapon", "armor", "potion", "scroll", "book"]:
		var tab_btn := Button.new()
		tab_btn.text = cat.to_upper()
		tab_btn.custom_minimum_size = Vector2(0, 48)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 40)
		tab_btn.pressed.connect(func():
			_bag_dlg = null
			dlg.queue_free()
			_open_bag_filtered(cat))
		cat_tabs.add_child(tab_btn)
	vb.add_child(cat_tabs)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var items: Array = player.get_items() if player != null else []
	if items.is_empty():
		var empty := Label.new()
		empty.text = "Inventory is empty."
		empty.add_theme_font_size_override("font_size", 40)
		rows.add_child(empty)
	else:
		for i in range(items.size()):
			var it: Dictionary = items[i]
			var kind: String = String(it.get("kind", ""))
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 80)
			row.add_theme_constant_override("separation", 8)
			var iid_row: String = String(it.get("id", ""))
			var tex: Texture2D = TileRenderer.item(iid_row)
			if tex != null:
				var icon := TextureRect.new()
				icon.texture = tex
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.custom_minimum_size = Vector2(48, 48)
				icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				row.add_child(icon)
			var info_btn := Button.new()
			var disp_name: String = GameManager.display_name_for_item(
					iid_row, String(it.get("name", "?")), kind)
			info_btn.text = disp_name
			info_btn.flat = true
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			info_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_btn.add_theme_font_size_override("font_size", 40)
			info_btn.pressed.connect(_on_bag_info.bind(it))
			row.add_child(info_btn)
			if kind == "weapon" or kind == "armor":
				var eq_btn := Button.new()
				eq_btn.text = "Equip"
				eq_btn.add_theme_font_size_override("font_size", 40)
				eq_btn.custom_minimum_size = Vector2(130, 64)
				eq_btn.pressed.connect(_on_bag_equip.bind(i, dlg))
				row.add_child(eq_btn)
			else:
				var use_btn := Button.new()
				use_btn.text = "Use"
				use_btn.add_theme_font_size_override("font_size", 40)
				use_btn.custom_minimum_size = Vector2(100, 64)
				use_btn.pressed.connect(_on_bag_use.bind(i, dlg))
				row.add_child(use_btn)
			var drop_btn := Button.new()
			drop_btn.text = "Drop"
			drop_btn.add_theme_font_size_override("font_size", 40)
			drop_btn.custom_minimum_size = Vector2(100, 64)
			drop_btn.pressed.connect(_on_bag_drop.bind(i, dlg))
			row.add_child(drop_btn)
			rows.add_child(row)
	popup_mgr.add_child(dlg)
	_bag_dlg = dlg
	dlg.tree_exited.connect(func():
		if _bag_dlg == dlg: _bag_dlg = null)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(960, 1700))


func _open_bag_filtered(category: String) -> void:
	if category == "all":
		_on_bag_pressed()
		return
	_on_bag_pressed()


## Build a multi-line tooltip string comparing this item to what the
## player currently has equipped in the same slot.
func _build_item_tooltip(it: Dictionary) -> String:
	var kind: String = String(it.get("kind", ""))
	var id: String = String(it.get("id", ""))
	# Unidentified consumables show their pseudonym; weapons/armor always
	# show their real name.
	var raw_name: String = String(it.get("name", WeaponRegistry.display_name_for(id)))
	var name_s: String = GameManager.display_name_for_item(id, raw_name, kind)
	match kind:
		"weapon":
			var new_dmg: int = WeaponRegistry.weapon_damage_for(id)
			var new_delay: float = WeaponRegistry.weapon_delay_for(id)
			var new_skill: String = WeaponRegistry.weapon_skill_for(id)
			var cur_id: String = player.equipped_weapon_id if player else ""
			var cur_dmg: int = WeaponRegistry.weapon_damage_for(cur_id)
			var cur_delay: float = WeaponRegistry.weapon_delay_for(cur_id)
			var cur_name: String = WeaponRegistry.display_name_for(cur_id) if cur_id != "" else "unarmed"
			var diff_dmg: int = new_dmg - cur_dmg
			var sign_d: String = "+" if diff_dmg >= 0 else ""
			return "%s\nDamage: %d (%s%d vs %s)\nDelay: %.2f (cur %.2f)\nSkill: %s" % [
				name_s, new_dmg, sign_d, diff_dmg, cur_name, new_delay, cur_delay, new_skill,
			]
		"armor":
			var new_ac: int = int(it.get("ac", 0))
			# Slot-aware comparison: look up what's worn in this item's slot.
			var slot: String = String(it.get("slot", ArmorRegistry.slot_for(id)))
			var cur: Dictionary = {}
			if player != null and player.equipped_armor.has(slot):
				cur = player.equipped_armor[slot]
			var cur_ac: int = int(cur.get("ac", 0))
			var cur_name: String = String(cur.get("name", "(empty)"))
			var diff_ac: int = new_ac - cur_ac
			var sign_a: String = "+" if diff_ac >= 0 else ""
			return "%s [%s slot]\nAC: %d (%s%d vs %s)" % [
				name_s, slot, new_ac, sign_a, diff_ac, cur_name,
			]
		"potion", "scroll":
			# Description hidden until identified — "?" keeps the mystery
			# so the player has to experiment or read an identify scroll.
			var desc: String = ""
			if GameManager.is_identified(id):
				desc = ConsumableRegistry.description_for(id)
			if desc == "":
				desc = ("Drink to find out." if kind == "potion" else "Read aloud to find out.")
			return "%s\n%s" % [name_s, desc]
		_:
			return "%s\nMiscellaneous junk." % name_s


func _on_bag_info(it: Dictionary) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	_close_all_dialogs()
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = String(it.get("name", "Item"))
	dlg.ok_button_text = "Close"
	var lab := Label.new()
	lab.text = _build_item_tooltip(it)
	lab.add_theme_font_size_override("font_size", 40)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg.add_child(lab)
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 700))


func _on_bag_use(idx: int, dlg: AcceptDialog) -> void:
	if player != null:
		player.use_item(idx)
	_bag_dlg = null  # Clear BEFORE reopening so toggle check doesn't see stale ref.
	dlg.queue_free()
	_on_bag_pressed()


func _on_bag_equip(idx: int, dlg: AcceptDialog) -> void:
	if player != null:
		var items: Array = player.get_items()
		if idx >= 0 and idx < items.size():
			var it: Dictionary = items[idx]
			var kind: String = String(it.get("kind", ""))
			items.remove_at(idx)
			if kind == "weapon":
				var wid: String = String(it.get("id", ""))
				var prev_id: String = player.equip_weapon(wid)
				if prev_id != "":
					items.append({
						"id": prev_id,
						"name": WeaponRegistry.display_name_for(prev_id),
						"kind": "weapon",
						"color": Color(0.75, 0.75, 0.85),
					})
			elif kind == "armor":
				# Always rehydrate from ArmorRegistry so the slot info is
				# correct even for older floor items missing it in extra.
				var aid: String = String(it.get("id", ""))
				var armor_info: Dictionary = ArmorRegistry.get_info(aid)
				if armor_info.is_empty():
					armor_info = {
						"id": aid,
						"name": String(it.get("name", aid)),
						"ac": int(it.get("ac", 0)),
						"color": it.get("color", Color(0.6, 0.6, 0.7)),
						"slot": String(it.get("slot", "chest")),
					}
				var prev_armor: Dictionary = player.equip_armor(armor_info)
				if not prev_armor.is_empty():
					items.append({
						"id": String(prev_armor.get("id", "")),
						"name": String(prev_armor.get("name", "")),
						"kind": "armor",
						"ac": int(prev_armor.get("ac", 0)),
						"slot": String(prev_armor.get("slot", "chest")),
						"color": prev_armor.get("color", Color(0.6, 0.6, 0.7)),
					})
			player.inventory_changed.emit()
	_bag_dlg = null
	dlg.queue_free()
	_on_bag_pressed()


func _on_bag_drop(idx: int, dlg: AcceptDialog) -> void:
	if player != null:
		player.drop_item(idx)
	_bag_dlg = null
	dlg.queue_free()
	_on_bag_pressed()


func _on_status_pressed() -> void:
	if _status_dlg != null and is_instance_valid(_status_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Status"
	dlg.ok_button_text = "Close"

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(800, 1200)
	dlg.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var lab := Label.new()
	lab.text = _build_status_text()
	lab.add_theme_font_size_override("font_size", 40)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lab)

	# Essence slots (3) — each row shows name, stat summary, and a Cast
	# button if the essence carries an active ability.
	if essence_system != null:
		var hdr := Label.new()
		hdr.text = "--- Essences ---"
		hdr.add_theme_font_size_override("font_size", 40)
		hdr.modulate = Color(0.85, 0.85, 1.0)
		vb.add_child(hdr)
		for i in essence_system.slots.size():
			vb.add_child(_build_essence_row(i, dlg))

	# Explicit Close at the bottom in case the OK footer is hard to reach.
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 40)
	close_btn.custom_minimum_size = Vector2(0, 96)
	close_btn.pressed.connect(dlg.queue_free)
	vb.add_child(close_btn)

	popup_mgr.add_child(dlg)
	_status_dlg = dlg
	dlg.tree_exited.connect(func():
		if _status_dlg == dlg: _status_dlg = null)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(880, 1700))


## One row in the Status popup per essence slot. Shows the slotted essence's
## name + stat summary, a Swap button, and (when the essence has an active
## ability) a Cast button that funnels through EssenceSystem.invoke.
func _build_essence_row(slot_idx: int, status_dlg: AcceptDialog) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.custom_minimum_size = Vector2(0, 120)
	var e: EssenceData = essence_system.slots[slot_idx] if essence_system != null else null
	var title := Label.new()
	if e == null:
		title.text = "Slot %d: (empty)" % (slot_idx + 1)
		title.modulate = Color(0.6, 0.6, 0.6)
	else:
		var stat_parts: Array = []
		if e.str_bonus != 0: stat_parts.append("STR %+d" % e.str_bonus)
		if e.dex_bonus != 0: stat_parts.append("DEX %+d" % e.dex_bonus)
		if e.int_bonus != 0: stat_parts.append("INT %+d" % e.int_bonus)
		if e.hp_bonus != 0:  stat_parts.append("HP %+d" % e.hp_bonus)
		if e.armor_bonus != 0: stat_parts.append("AC %+d" % e.armor_bonus)
		title.text = "Slot %d: %s  (%s)" % [
			slot_idx + 1, e.display_name, " ".join(PackedStringArray(stat_parts)),
		]
	title.add_theme_font_size_override("font_size", 40)
	row.add_child(title)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 8)
	var swap_btn := Button.new()
	swap_btn.text = "Swap"
	swap_btn.custom_minimum_size = Vector2(160, 72)
	swap_btn.add_theme_font_size_override("font_size", 40)
	swap_btn.pressed.connect(_on_swap_essence_slot.bind(slot_idx, status_dlg))
	btns.add_child(swap_btn)
	if e != null and e.ability_id != "":
		var cd: int = essence_system.cooldowns[slot_idx]
		var cast_btn := Button.new()
		cast_btn.custom_minimum_size = Vector2(260, 72)
		cast_btn.add_theme_font_size_override("font_size", 40)
		if cd > 0:
			cast_btn.text = "Cast (CD %d)" % cd
			cast_btn.disabled = true
		else:
			cast_btn.text = "Cast (%d MP)" % e.ability_mp
		cast_btn.pressed.connect(_on_cast_essence_ability.bind(slot_idx, status_dlg))
		btns.add_child(cast_btn)
		var desc := Label.new()
		desc.text = e.ability_desc
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 40)
		desc.modulate = Color(0.75, 0.75, 0.85)
		row.add_child(btns)
		row.add_child(desc)
		return row
	row.add_child(btns)
	return row


func _on_cast_essence_ability(slot_idx: int, status_dlg: AcceptDialog) -> void:
	if essence_system == null:
		return
	var ok: bool = essence_system.invoke(slot_idx)
	status_dlg.queue_free()
	if ok:
		TurnManager.end_player_turn()


func _on_swap_essence_slot(slot_idx: int, status_dlg: AcceptDialog) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or essence_system == null:
		return
	status_dlg.queue_free()
	var current: EssenceData = essence_system.slots[slot_idx]
	var current_id: String = current.id if current != null else ""
	var inv_ids: Array = []
	for e in essence_system.inventory:
		if e != null:
			inv_ids.append(e.id)
	popup_mgr.show_essence_swap_popup(slot_idx, current_id, inv_ids, func(selected_id):
		if selected_id == "":
			essence_system.unequip(slot_idx)
		else:
			var target: EssenceData = essence_system.find_essence_by_id(selected_id)
			if target != null:
				essence_system.equip(slot_idx, target))


func _build_status_text() -> String:
	var s = player.stats
	var race_name: String = player.race_res.display_name if player.race_res else "?"
	var job_name: String = player.job_res.display_name if player.job_res else "?"
	var trait_id: String = player.race_res.racial_trait if player.race_res else ""
	var hp_text: String = "%d / %d" % [s.HP, s.hp_max] if s != null else "?"
	var mp_text: String = "%d / %d" % [s.MP, s.mp_max] if s != null else "?"
	var ac_breakdown: String = ""
	var race_ac: int = player.race_res.base_ac if player.race_res else 0
	var armor_ac: int = 0
	for slot_dict in player.equipped_armor.values():
		armor_ac += int(slot_dict.get("ac", 0))
	ac_breakdown = "AC %d  (race +%d, armor +%d)" % [s.AC if s != null else 0, race_ac, armor_ac]

	var lines: Array = []
	var trait_name: String = player.trait_res.display_name if player.trait_res else ""
	var title: String = job_name
	if trait_name != "":
		title = "%s — %s" % [job_name, trait_name]
	lines.append("=== %s ===" % title)
	lines.append("Lv.%d   XP %d / %d   Turn %d" % [player.level, player.xp, player.xp_for_next_level(), TurnManager.turn_number])
	lines.append("")
	lines.append("HP   %s" % hp_text)
	lines.append("MP   %s" % mp_text)
	if s != null:
		lines.append("STR %d   DEX %d   INT %d" % [s.STR, s.DEX, s.INT])
	lines.append(ac_breakdown)
	var w_dmg: int = WeaponRegistry.weapon_damage_for(player.equipped_weapon_id)
	var str_bonus: int = s.STR / 3 if s != null else 0
	var total_atk: int = w_dmg + str_bonus + player.weapon_bonus_dmg
	var total_ev: int = s.DEX / 2 if s != null else 0
	lines.append("")
	lines.append("--- Combat ---")
	lines.append("ATK %d  (weapon %d + STR %d + bonus %d)" % [total_atk, w_dmg, str_bonus, player.weapon_bonus_dmg])
	lines.append("DEF %d  (AC)" % [s.AC if s != null else 0])
	lines.append("EV  %d  (DEX/2)" % total_ev)
	lines.append("")
	lines.append("--- Equipped ---")
	var w_id: String = player.equipped_weapon_id
	lines.append("Weapon : %s" % (WeaponRegistry.display_name_for(w_id) if w_id != "" else "(unarmed)"))
	for slot in ["helm", "chest", "legs", "boots", "gloves"]:
		var name_s: String = "(empty)"
		if player.equipped_armor.has(slot):
			name_s = "%s  (+%d AC)" % [
				String(player.equipped_armor[slot].get("name", "")),
				int(player.equipped_armor[slot].get("ac", 0)),
			]
		lines.append("%-7s: %s" % [slot.capitalize(), name_s])
	if trait_id != "":
		lines.append("")
		lines.append("--- Trait ---")
		lines.append(_describe_trait(trait_id))
	return "\n".join(PackedStringArray(lines))


func _describe_trait(trait_id: String) -> String:
	match trait_id:
		"trollregen":     return "Troll Regeneration — recovers 1 HP every turn."
		"spriggan_speed": return "Spriggan Speed — moves twice per enemy turn."
		"draconian_resist": return "Draconian Scales — bonus AC and elemental resistance."
		"minotaur_headbutt": return "Minotaur Headbutt — 25% chance for bonus melee damage."
		"catfolk_claws":  return "Catfolk Claws — +3 damage when fighting unarmed."
		_: return trait_id


const _MM_SCALE: int = 12  # pixels per tile in the minimap texture


func _on_minimap_pressed() -> void:
	if _map_dlg != null and is_instance_valid(_map_dlg):
		_map_dlg.queue_free()
		_map_dlg = null
		return
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or generator == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	var depth: int = GameManager.current_depth if GameManager != null else 1
	dlg.title = "Map — B%dF (tap to travel)" % depth
	dlg.ok_button_text = "Close"

	var vb := VBoxContainer.new()
	dlg.add_child(vb)
	var tex_rect := TextureRect.new()
	tex_rect.texture = _build_minimap_texture(dmap, player.grid_pos if player else Vector2i.ZERO)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var mm_w: int = DungeonGenerator.MAP_WIDTH * _MM_SCALE
	var mm_h: int = DungeonGenerator.MAP_HEIGHT * _MM_SCALE
	tex_rect.custom_minimum_size = Vector2(mm_w, mm_h)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(_on_minimap_tapped.bind(tex_rect, dlg))
	vb.add_child(tex_rect)

	popup_mgr.add_child(dlg)
	_map_dlg = dlg
	dlg.tree_exited.connect(func():
		if _map_dlg == dlg: _map_dlg = null)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(mm_w + 80, mm_h + 240))


## Tapping on the minimap converts local pixel → grid tile and kicks off
## auto-move toward it. Closes the popup on success.
func _on_minimap_tapped(event: InputEvent, tex_rect: TextureRect, dlg: AcceptDialog) -> void:
	var is_tap: bool = false
	var pos: Vector2 = Vector2.ZERO
	if event is InputEventMouseButton and event.pressed:
		is_tap = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		is_tap = true
		pos = event.position
	if not is_tap or player == null or generator == null or touch_input == null:
		return
	# Reverse the STRETCH_KEEP_ASPECT_CENTERED transform to find the tile.
	var rect_size: Vector2 = tex_rect.size
	var mm_w: float = DungeonGenerator.MAP_WIDTH * _MM_SCALE
	var mm_h: float = DungeonGenerator.MAP_HEIGHT * _MM_SCALE
	var scale: float = min(rect_size.x / mm_w, rect_size.y / mm_h)
	var draw_w: float = mm_w * scale
	var draw_h: float = mm_h * scale
	var off_x: float = (rect_size.x - draw_w) * 0.5
	var off_y: float = (rect_size.y - draw_h) * 0.5
	var local_x: float = pos.x - off_x
	var local_y: float = pos.y - off_y
	if local_x < 0 or local_y < 0 or local_x > draw_w or local_y > draw_h:
		return
	var tx: int = int(local_x / (_MM_SCALE * scale))
	var ty: int = int(local_y / (_MM_SCALE * scale))
	var target: Vector2i = Vector2i(tx, ty)
	if not generator.is_walkable(target):
		return
	if not $DungeonLayer/DungeonMap.is_explored(target):
		return  # Can't travel to fog.
	# Close map and start auto-move.
	dlg.queue_free()
	touch_input.begin_auto_move_to(target)


func _build_minimap_texture(dmap: DungeonMap, player_pos: Vector2i) -> ImageTexture:
	var MM_SCALE: int = _MM_SCALE
	var mw: int = DungeonGenerator.MAP_WIDTH
	var mh: int = DungeonGenerator.MAP_HEIGHT
	var img: Image = Image.create(mw * MM_SCALE, mh * MM_SCALE, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.02, 0.02, 0.04, 1))  # unseen = near-black
	var wall_col := Color(0.25, 0.25, 0.3)
	var floor_col := Color(0.55, 0.55, 0.6)
	var down_col := Color(0.95, 0.82, 0.15)
	var up_col := Color(0.55, 0.78, 0.95)
	for x in mw:
		for y in mh:
			if not dmap.is_explored(Vector2i(x, y)):
				continue
			var t: int = generator.map[x][y]
			var c: Color = floor_col
			match t:
				DungeonGenerator.TileType.WALL: c = wall_col
				DungeonGenerator.TileType.STAIRS_DOWN: c = down_col
				DungeonGenerator.TileType.STAIRS_UP: c = up_col
			img.fill_rect(Rect2i(x * MM_SCALE, y * MM_SCALE, MM_SCALE, MM_SCALE), c)
	# Player marker (bright red, 2× tile).
	var px: int = player_pos.x * MM_SCALE
	var py: int = player_pos.y * MM_SCALE
	img.fill_rect(Rect2i(px - MM_SCALE / 2, py - MM_SCALE / 2, MM_SCALE * 2, MM_SCALE * 2), Color(1, 0.2, 0.2))
	return ImageTexture.create_from_image(img)


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
