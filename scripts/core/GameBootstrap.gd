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
var _suppress_bag_reopen: bool = false
# Active bag filter ("all" | "weapon" | "armor" | "potion" | "scroll" | "book").
# Remembered across reopens so swiping/tabbing doesn't lose the user's spot.
var _bag_category: String = "all"
# Swipe-tracking state for the current bag dialog.
var _bag_swipe_start_x: float = -1.0
var _bag_swipe_start_y: float = -1.0
const _BAG_CATEGORIES: Array = ["all", "weapon", "armor", "cloak", "ring", "potion", "scroll", "book"]
# Swipe state for the skill dialog's category tabs — same pattern as
# _bag_swipe_* but keyed per-dialog so closing one doesn't bleed into
# the other.
var _skills_swipe_dlg: AcceptDialog = null
var _skills_swipe_category: String = ""
var _skills_swipe_start_x: float = -1.0
var _skills_swipe_start_y: float = -1.0
var _skills_dlg: AcceptDialog = null
var _status_dlg: AcceptDialog = null
var _map_dlg: AcceptDialog = null
var _magic_dlg: AcceptDialog = null
var _combat_log_label: Label = null
var _targeting_spell: String = ""
# Camera follow tween so the view doesn't snap.
var _cam_tween: Tween = null
const _CAM_FOLLOW_DUR: float = 0.14

# REST mode — advances turns while regenerating HP/MP. Interrupts when any
# monster enters player FOV or caps reached.
var _resting: bool = false
var _rest_turns: int = 0
const _REST_MAX_TURNS: int = 50
## DCSS rest doesn't heal faster than walking — it just advances time
## safely. The `_REST_*` constants are kept only so save files from the
## old format load cleanly; the `_rest_turn()` handler no longer adds
## them on top of the normal per-turn regen.
const _REST_HP_PER_TURN: int = 0
const _REST_MP_PER_TURN: int = 0
## DCSS-style regen accumulators (cleared on floor change). Incremented
## per turn by `20 + hp_max/6` for HP and `7 + mp_max/7` for MP; each
## full 100 ticks a single HP / MP recovery.
var _hp_regen_accum: int = 0
var _mp_regen_accum: int = 0


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
	var job_id: String = GameManager.selected_job_id if GameManager.selected_job_id != "" else "fighter"
	var race_id: String = GameManager.selected_race_id if GameManager.selected_race_id != "" else "human"
	GameManager.start_new_run(job_id, race_id)
	var job: JobData = load("res://resources/jobs/%s.tres" % job_id)
	# Route through RaceRegistry so DCSS aptitudes + hp_mod/mp_mod get
	# merged onto the hand-tuned .tres before Player reads the data.
	var race_res: RaceData = RaceRegistry.fetch(race_id)
	player.setup(generator, generator.spawn_pos, job, race_res, null)

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
	skill_system.init_for_player(player, starting_skills)
	# Dodging / stealth / armour skills need to be present before EV can
	# be computed correctly, so refresh defense stats now that the skill
	# system has populated skill_state.
	if player.has_method("_recompute_defense"):
		player._recompute_defense()
	# Re-run on every skill level-up so dodging gains translate into
	# EV bumps immediately (instead of waiting for the next equip swap).
	if not skill_system.skill_leveled_up.is_connected(_on_skill_leveled_up_for_stats):
		skill_system.skill_leveled_up.connect(_on_skill_leveled_up_for_stats)

	player.moved.connect(_on_player_moved)
	# [meta-agent] hook player death → result screen.
	player.died.connect(_on_player_died)
	player.damaged.connect(_on_player_damaged)
	player.leveled_up.connect(_on_player_leveled_up)
	player.identify_one_requested.connect(_on_identify_one_requested)
	if player.has_signal("enchant_one_requested"):
		player.enchant_one_requested.connect(_on_enchant_one_requested)
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
				top_hud.set_mp(player.stats.MP, player.stats.mp_max)
			if top_hud.has_method("set_gold"):
				top_hud.set_gold(player.gold)
			_update_low_hp_overlay())
		player.inventory_changed.connect(func():
			if top_hud.has_method("set_gold"):
				top_hud.set_gold(player.gold))
		if top_hud.has_method("set_hp") and player.stats != null:
			top_hud.set_hp(player.stats.HP, player.stats.hp_max)
			top_hud.set_mp(player.stats.MP, player.stats.mp_max)

	_setup_low_hp_overlay()

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
	if bottom_hud != null and bottom_hud.has_signal("auto_move_pressed"):
		bottom_hud.auto_move_pressed.connect(_on_auto_move_pressed)
	if bottom_hud != null and bottom_hud.has_signal("auto_attack_pressed"):
		bottom_hud.auto_attack_pressed.connect(_on_auto_attack_pressed)

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
	if bottom_hud != null and bottom_hud.has_signal("quickslot_long_pressed"):
		bottom_hud.quickslot_long_pressed.connect(_on_quickslot_long_pressed)
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
	touch_input.branch_entrance_tapped.connect(_on_branch_entrance_tapped)
	touch_input.altar_tapped.connect(_on_altar_tapped)
	touch_input.shop_tapped.connect(_on_shop_tapped)
	touch_input.key_action.connect(_on_key_action)
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

	_setup_combat_log(ui)
	TurnManager.start_player_turn()


func _setup_combat_log(ui_root: Node) -> void:
	if ui_root == null:
		return
	var panel := PanelContainer.new()
	panel.name = "CombatLogPanel"
	# Anchor to lower portion of screen, above BottomHUD (~72-82% down).
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.72
	panel.anchor_bottom = 0.82
	panel.offset_top = 0
	panel.offset_bottom = 0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Inner margin so text doesn't hug the screen edges — the left side
	# was getting clipped against the viewport.
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(margin)
	var label := Label.new()
	label.name = "LogLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 34)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(label)
	ui_root.add_child(panel)
	_combat_log_label = label
	CombatLog.message_added.connect(func(_m: String) -> void:
		if _combat_log_label != null and is_instance_valid(_combat_log_label):
			var recent := CombatLog.get_recent(3)
			_combat_log_label.text = "\n".join(PackedStringArray(recent)))


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
	# DCSS regeneration (player.cc:player_regen): per-turn accumulator
	# of `20 + hp_max/6` points, heal 1 HP at 100. At XL 1 with ~15 HP
	# that's 22/turn → ~5 turns per HP, matching the slow DCSS crawl
	# (Lv 10 ~70 HP → ~30/turn → ~3 turns per HP).
	var hp_rate: int = 20 + player.stats.hp_max / 6
	_hp_regen_accum += hp_rate
	while _hp_regen_accum >= 100 and player.stats.HP < player.stats.hp_max:
		player.stats.HP += 1
		_hp_regen_accum -= 100
		player.stats_changed.emit()
	# DCSS player_mp_regen (player.cc:1298): `7 + mp_max / 2`.
	# We previously divided by 7 which scaled MP regen 2–3× too slowly
	# at mid/late game (at 60 MP max: DCSS 37/turn, ours 15/turn). The
	# divisor is now corrected so MP flow matches the source.
	var mp_rate: int = 7 + player.stats.mp_max / 2
	_mp_regen_accum += mp_rate
	while _mp_regen_accum >= 100 and player.stats.MP < player.stats.mp_max:
		player.stats.MP += 1
		_mp_regen_accum -= 100
		player.stats_changed.emit()
	var special: String = ""
	if player.trait_res != null:
		special = player.trait_res.special
	elif player.race_res != null:
		special = player.race_res.racial_trait
	match special:
		"regen":
			if player.stats.HP < player.stats.hp_max:
				player.stats.HP = min(player.stats.hp_max, player.stats.HP + 1)
				player.stats_changed.emit()
		"trollregen":
			# Trolls regen fast — 2 HP/turn as long as not capped.
			if player.stats.HP < player.stats.hp_max:
				player.stats.HP = min(player.stats.hp_max, player.stats.HP + 2)
				player.stats_changed.emit()
		"vine_stalker_mpregen":
			# Plant-ish MP trickle; stacks with the bigger kill-bonus pulse.
			if player.stats.MP < player.stats.mp_max:
				player.stats.MP = min(player.stats.mp_max, player.stats.MP + 1)
				player.stats_changed.emit()
	# Equipment-sourced regen (ring of regeneration, etc) — stacks on top
	# of any racial regen above.
	var gear_regen: int = player.gear_regen_per_turn() if player.has_method("gear_regen_per_turn") else 0
	if gear_regen > 0 and player.stats.HP < player.stats.hp_max:
		player.stats.HP = min(player.stats.hp_max, player.stats.HP + gear_regen)
		player.stats_changed.emit()


## Every frame make sure monsters/items don't leak into unexplored tiles.
## Cheap — ~30 nodes max, single dict lookup each. Catches tween-mid
## movement where grid_pos changed but no signal fired yet.
func _process(_delta: float) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null and generator != null:
		_refresh_actor_visibility(dmap)


## Long-press on a quickslot → show its assigned item/spell info instead of
## firing it. Empty slots still just open the picker so users can assign
## something — no info to show.
func _on_quickslot_long_pressed(index: int) -> void:
	if player == null:
		return
	var id: String = player.quickslot_ids[index] if index < player.quickslot_ids.size() else ""
	if id == "":
		_open_quickslot_picker(index)
		return
	if id.begins_with("spell:"):
		_show_spell_info(id.substr(6))
		return
	# Assume item id — show via the same info popup the bag uses.
	var item_dict: Dictionary = _find_inventory_item_by_id(id)
	if item_dict.is_empty():
		item_dict = {"id": id, "name": id.capitalize().replace("_", " ")}
	_on_bag_info(item_dict)


func _find_inventory_item_by_id(iid: String) -> Dictionary:
	if player == null:
		return {}
	for it in player.get_items():
		if String(it.get("id", "")) == iid:
			return it
	return {}


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
			if result.get("message", "") != "":
				CombatLog.add(result.get("message", ""))
			if result.get("success", false):
				if skill_system != null:
					var tags: Array = SpellRegistry.get_schools(spell_id).duplicate()
					tags.append("spellcasting")
					skill_system.grant_xp(player, float(info.get("mp", 1)) * 8.0, tags)
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

	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 20
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
			8: "Trap", 9: "Branch Entrance", 10: "Shop", 11: "Altar",
			12: "Tree",
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


func _on_auto_move_pressed() -> void:
	if player == null or not player.is_alive or run_over:
		return
	if touch_input != null and touch_input.has_method("begin_auto_explore"):
		touch_input.begin_auto_explore()


func _on_auto_attack_pressed() -> void:
	if player == null or not player.is_alive or run_over:
		return
	# Find nearest visible monster and move/attack toward it.
	var nearest = null
	var nearest_dist: int = 999
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not ("grid_pos" in m):
			continue
		if "is_alive" in m and not m.is_alive:
			continue
		var d: int = max(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y))
		if d < nearest_dist:
			nearest_dist = d
			nearest = m
	if nearest == null:
		return
	var delta: Vector2i = nearest.grid_pos - player.grid_pos
	if nearest_dist <= 1:
		player.try_move(delta)
	else:
		var path: Array[Vector2i] = Pathfinding.find_path(generator, player.grid_pos, nearest.grid_pos)
		if not path.is_empty():
			player.try_move(path[0] - player.grid_pos)


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
		CombatLog.add("You are already at full health.")
		return
	if _visible_monster_nearby():
		CombatLog.add("Can't rest — enemy nearby!")
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
	CombatLog.add("Rest: %s." % reason)
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
	print("[spawn] depth=%d spawned=%d" % [GameManager.current_depth, monsters.size()])


const _LOOT_DROP_CHANCE: float = 0.30
const _CURSE_CHANCE: float = 0.12

# Depth-scaled item generation loaded from assets/dcss_items/item_gen.json
const _ITEM_GEN_PATH: String = "res://assets/dcss_items/item_gen.json"
static var _item_gen: Dictionary = {}
static var _item_gen_loaded: bool = false

static func _ensure_item_gen() -> void:
	if _item_gen_loaded:
		return
	_item_gen_loaded = true
	var f := FileAccess.open(_ITEM_GEN_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		_item_gen = parsed

## Pick a random item id from depth-scaled DCSS tier tables.
## table_key = "weapon" | "armour" | "consumable"
static func _pick_by_depth(table_key: String, depth: int) -> String:
	_ensure_item_gen()
	var tiers: Dictionary = _item_gen.get(table_key + "_tiers", {})
	var by_depth: Dictionary = _item_gen.get(table_key + "_by_depth", {})
	var d_key: String = str(clampi(depth, 1, 27))
	var tier_weights: Array = by_depth.get(d_key, [])
	if tiers.is_empty() or tier_weights.is_empty():
		return ""
	# Weighted tier selection
	var total_w: int = 0
	for tw in tier_weights:
		total_w += int(tw[1])
	var roll: int = randi() % max(total_w, 1)
	var chosen_tier: String = ""
	var acc: int = 0
	for tw in tier_weights:
		acc += int(tw[1])
		if roll < acc:
			chosen_tier = String(tw[0])
			break
	var pool = tiers.get(chosen_tier, {})
	if pool is Array:
		if pool.is_empty():
			return ""
		return String(pool[randi() % pool.size()])
	# pool is Dictionary {id: weight}
	var pool_dict: Dictionary = pool as Dictionary
	if pool_dict.is_empty():
		return ""
	var p_total: int = 0
	for w in pool_dict.values():
		p_total += int(w)
	var p_roll: int = randi() % max(p_total, 1)
	var p_acc: int = 0
	for id in pool_dict.keys():
		p_acc += int(pool_dict[id])
		if p_roll < p_acc:
			return String(id)
	return String(pool_dict.keys()[0])

# Ring drop pool — a small chance branches into this pool instead of
# armor/weapon/consumable on any monster drop.
const _RING_POOL: Array = [
	"ring_str", "ring_dex", "ring_int",
	"ring_protection", "ring_evasion", "ring_slaying",
	"ring_magical_power", "ring_wizardry",
	"ring_regeneration", "ring_stealth",
	"ring_fire", "ring_ice",
]


## DCSS gold-on-kill: only monsters that "carry" gold (humanoid,
## intelligent, not animals/plants) drop a small pile. Amount scales
## with the victim's HD so a stone giant gives more than an orc.
func _maybe_drop_gold(monster: Monster) -> void:
	if monster == null or monster.data == null or not ("grid_pos" in monster):
		return
	var intel: String = String(monster.data.intelligence)
	if intel == "animal" or intel == "plant" or intel == "brainless":
		return
	if randf() >= 0.30:
		return
	var hd: int = int(monster.data.hd)
	var amount: int = max(1, hd + randi() % max(hd * 2, 3))
	var fi: FloorItem = FloorItem.new()
	$EntityLayer.add_child(fi)
	fi.setup(monster.grid_pos, "gold", "%d gold" % amount, "gold",
			Color(1.0, 0.85, 0.30), {"gold": amount})


func _maybe_drop_loot(monster: Monster) -> void:
	if monster == null or not ("grid_pos" in monster):
		return
	# DCSS species-specific drops: trolls exclusively drop their own hide
	# armour (troll_leather_armour is never floor-generated). Gate this
	# before the generic roll so the yield is independent of the 30%
	# generic loot chance.
	if monster.data != null and String(monster.data.id).begins_with("troll"):
		if randf() < 0.25:
			var fi: FloorItem = FloorItem.new()
			$EntityLayer.add_child(fi)
			var ainfo: Dictionary = ArmorRegistry.get_info("troll_leather_armour")
			fi.setup(monster.grid_pos, "troll_leather_armour",
					String(ainfo.get("name", "troll leather armour")),
					"armor",
					ainfo.get("color", Color(0.45, 0.55, 0.30)),
					{"ac": int(ainfo.get("ac", 4)),
					 "slot": String(ainfo.get("slot", "chest")),
					 "cursed": false})
			return
	if randf() > _LOOT_DROP_CHANCE:
		return
	# Reuse the same distribution as floor-gen so kill drops and loose
	# items share a single tuning surface.
	_place_random_floor_item(monster.grid_pos, GameManager.current_depth,
			$EntityLayer)


## DCSS floor-gen item placement (dungeon.cc:_builder_items). Items per
## floor = `3 + 3d9` (dungeon.cc:_num_items_wanted), so 6..30 per floor.
## Item type is sampled from a weapon/armour/consumable/ring mix tuned to
## match the feel of DCSS's OBJ_RANDOM distribution.
func _spawn_dummy_items(_count: int) -> void:
	var depth: int = GameManager.current_depth
	# DCSS dungeon.cc:_num_items_wanted uses 3 + 3d9 (avg 18) but that's
	# calibrated for full 80x70 floors. Our mobile maps are smaller and
	# that density felt cluttered in playtesting ("1층부터 반지도 트롤갑도
	# 너무 많아"). Scaled to 1 + 2d5 (avg 7) so each floor has a handful
	# of picks without a yard sale on every corner.
	var d_roll: int = randi_range(1, 5) + randi_range(1, 5)
	var item_count: int = 1 + d_roll
	var entity_layer: Node = $EntityLayer
	var placed: int = 0
	var attempts: int = 0
	while placed < item_count and attempts < 800:
		attempts += 1
		var x: int = randi() % DungeonGenerator.MAP_WIDTH
		var y: int = randi() % DungeonGenerator.MAP_HEIGHT
		var gp: Vector2i = Vector2i(x, y)
		if not generator.is_walkable(gp):
			continue
		if player != null and gp == player.grid_pos:
			continue
		if _place_random_floor_item(gp, depth, entity_layer):
			placed += 1


## Spawn a single FloorItem at `pos` of a type sampled from the
## depth-weighted tables. Returns false if the item couldn't be built
## (unknown id, missing registry data). Same type-mix as monster-kill
## loot so floor items and drops feel like one distribution.
func _place_random_floor_item(pos: Vector2i, depth: int, parent: Node) -> bool:
	var is_cursed: bool = randf() < _CURSE_CHANCE
	var drop_roll: float = randf()
	var fi: FloorItem = FloorItem.new()
	parent.add_child(fi)
	if drop_roll < 0.42:
		var wid: String = _pick_by_depth("weapon", depth)
		if wid.is_empty():
			wid = "dagger"
		var wname: String = WeaponRegistry.display_name_for(wid)
		if is_cursed:
			wname = "Cursed " + wname
		fi.setup(pos, wid, wname, "weapon", Color(0.75, 0.75, 0.85),
				{"cursed": is_cursed})
	elif drop_roll < 0.70:
		var aid: String = _pick_by_depth("armour", depth)
		if aid.is_empty():
			aid = "leather_armour"
		var info: Dictionary = ArmorRegistry.get_info(aid)
		var aname: String = String(info.get("name", aid))
		if is_cursed:
			aname = "Cursed " + aname
		fi.setup(pos, aid, aname, "armor",
				info.get("color", Color(0.6, 0.6, 0.7)),
				{"ac": int(info.get("ac", 0)),
				 "slot": String(info.get("slot", "chest")),
				 "cursed": is_cursed})
	elif drop_roll < 0.73:
		# Rings were dropping too frequently on Lv1 per user feedback.
		# DCSS rings are rare picks — this trims the ring band from 8%
		# down to 3% of drops. Monster-kill loot has its own flow.
		var rid: String = _RING_POOL[randi() % _RING_POOL.size()]
		var ring_info: Dictionary = RingRegistry.get_info(rid)
		fi.setup(pos, rid, String(ring_info.get("name", rid)), "ring",
				ring_info.get("color", Color(0.85, 0.85, 0.90)))
	elif drop_roll < 0.78:
		# Wand drop: pick one of the 12 DCSS wands, roll its starting
		# charges, stash both in `extra` so the FloorItem/inventory can
		# track remaining charges through pickup and evocation.
		var wand_ids: Array = WandRegistry.all_ids()
		var wid_w: String = String(wand_ids[randi() % wand_ids.size()])
		var wand_info: Dictionary = WandRegistry.get_info(wid_w)
		var charges: int = WandRegistry.roll_charges(wid_w)
		fi.setup(pos, wid_w, String(wand_info.get("name", wid_w)), "wand",
				wand_info.get("color", Color(0.85, 0.85, 0.95)),
				{"charges": charges})
	else:
		# 74% potion / scroll, 20% book, 3% talisman, 3% misc evocable.
		var cid: String
		var roll: float = randf()
		if roll < 0.20:
			var all_books: Array = ConsumableRegistry.all_ids().filter(
					func(k): return String(ConsumableRegistry.get_info(k).get("kind", "")) == "book")
			cid = String(all_books[randi() % all_books.size()]) if not all_books.is_empty() \
					else _pick_by_depth("consumable", depth)
		elif roll < 0.23:
			var all_tali: Array = ConsumableRegistry.all_ids().filter(
					func(k): return String(ConsumableRegistry.get_info(k).get("kind", "")) == "talisman")
			cid = String(all_tali[randi() % all_tali.size()]) if not all_tali.is_empty() \
					else _pick_by_depth("consumable", depth)
		elif roll < 0.26:
			var all_evoc: Array = ConsumableRegistry.all_ids().filter(
					func(k): return String(ConsumableRegistry.get_info(k).get("kind", "")) == "evocable")
			cid = String(all_evoc[randi() % all_evoc.size()]) if not all_evoc.is_empty() \
					else _pick_by_depth("consumable", depth)
		else:
			cid = _pick_by_depth("consumable", depth)
		# Evocables need `charges` rolled at spawn time.
		var _pre_info: Dictionary = ConsumableRegistry.get_info(cid)
		if String(_pre_info.get("kind", "")) == "evocable":
			var cb: int = int(_pre_info.get("charges_base", 3))
			var cr: int = int(_pre_info.get("charges_rand", 3))
			var rolled_charges: int = max(1, cb + (randi() % max(cr, 1)))
			var cinfo_e: Dictionary = _pre_info
			fi.setup(pos, cid, String(cinfo_e.get("name", cid)), "evocable",
					cinfo_e.get("color", Color(0.8, 0.8, 1.0)),
					{"charges": rolled_charges})
			return true
		if cid.is_empty():
			cid = "potion_curing"
		var cinfo: Dictionary = ConsumableRegistry.get_info(cid)
		fi.setup(pos, cid, String(cinfo.get("name", cid)),
				String(cinfo.get("kind", "junk")),
				cinfo.get("color", Color(0.9, 0.5, 0.3)))
	return true


func _on_monster_died(monster: Monster) -> void:
	kill_count += 1
	if monster != null and monster.data != null:
		CombatLog.add("You kill the %s!" % String(monster.data.display_name))
	if meta != null and monster != null and monster.data != null:
		meta.record_kill(String(monster.data.id))
	# DCSS gold drop: 30% of intelligent humanoid kills drop a small pile
	# scaled by monster HD. Orcs/humans/gnolls carry purses; animals
	# don't. Dropped as a floor pickup so the player has to step to it.
	_maybe_drop_gold(monster)
	# DCSS piety gain: every god who likes kills (Trog/Okawaru/Zin)
	# rewards the player per-victim. Amount is scaled down from DCSS
	# because our runs are shorter; cap at the god's piety_cap.
	if player != null and player.current_god != "":
		var god: Dictionary = GodRegistry.get_info(player.current_god)
		var gain: int = int(god.get("kill_piety", 0))
		if gain > 0:
			var cap: int = int(god.get("piety_cap", 200))
			player.piety = min(cap, player.piety + gain)
	if player != null and player.trait_res != null and player.trait_res.special == "holy_light":
		if player.stats != null and player.is_alive:
			var heal: int = max(1, int(player.stats.hp_max * 0.2))
			player.stats.HP = min(player.stats.hp_max, player.stats.HP + heal)
			player.stats_changed.emit()
	# Racial kill bonuses (vampire bloodfeast, vine-stalker MP pulse, …).
	if player != null and player.has_method("apply_kill_bonuses"):
		player.apply_kill_bonuses(monster)
	if essence_system != null:
		essence_system.try_drop_from_monster(monster)
	# M1: small chance of loot drop at death tile.
	_maybe_drop_loot(monster)
	# [skill-agent] award XP to trained skills matching weapon + passive tags.
	if skill_system != null and player != null and monster != null and monster.data != null:
		var xp_gain: int = int(monster.data.xp_value)
		if xp_gain <= 0:
			xp_gain = max(1, int(monster.data.tier) * 8)
		# Racial XP modifiers: barachi absorb more, demigod/mummy learn slow.
		xp_gain = int(round(float(xp_gain) * _racial_xp_multiplier()))
		xp_gain = max(1, xp_gain)
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


## Oni (and any future magical-might race) get a 20% spell power bump so
## their conjurations hit harder than the base formula suggests.
func _apply_racial_spellpower(power: int) -> int:
	if player == null or player.race_res == null:
		return power
	if player.race_res.racial_trait == "oni_magical_might":
		return int(round(float(power) * 1.2))
	return power


## Roll a spell's damage. Prefers DCSS per-spell zap dice (zap-data.h via
## assets/dcss_spells/zaps.json); falls back to the legacy flat min/max +
## power/2 formula when the spell has no zap (e.g. scorch, vampiric drain,
## most hex-like or buff spells that compute damage procedurally in DCSS).
func _spell_roll_dmg(spell_id: String, info: Dictionary, power: int) -> int:
	var zap_dmg: int = SpellRegistry.roll_damage(spell_id, power)
	if zap_dmg >= 0:
		return zap_dmg
	return randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 2


## Deal spell damage to `target` with the correct element routed through
## so target.take_damage can apply the resist scaling. Logs + damage
## numbers come from the caller.
func _spell_deal_dmg(target: Node, dmg: int, spell_id: String) -> void:
	if target == null or not target.has_method("take_damage"):
		return
	var element: String = SpellRegistry.element_for(spell_id)
	target.take_damage(dmg, element)


## Global XP multiplier sourced from the player's racial trait. Applied to
## both skill XP and character XP on every kill so the curve stays
## consistent with the DCSS feel of slow-leveling demigods and XP-chugging
## barachi.
func _racial_xp_multiplier() -> float:
	if player == null:
		return 1.0
	var race_trait: String = ""
	if player.race_res != null:
		race_trait = player.race_res.racial_trait
	match race_trait:
		"barachi_xp_bonus": return 1.25
		"demigod_slow_xp":  return 0.50
		"mummy_undead":     return 0.75
		_:                  return 1.0


func _on_player_moved(new_pos: Vector2i) -> void:
	# Any deliberate movement cancels an in-progress rest.
	if _resting:
		_cancel_rest("movement")
	# Trap trigger: stepping onto a TRAP tile resolves the trap's
	# effect once (trap tile stays for visual, like DCSS's revealed
	# traps — player can disarm via stealth in the real game).
	if generator != null and generator.get_tile(new_pos) == DungeonGenerator.TileType.TRAP:
		_trigger_trap(new_pos)
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
	# Branch-aware stairs-down: on the main dungeon trunk, depth 15 (the
	# DCSS D:15 endpoint) wins the run if the player has chosen to stop
	# there — `MAX_DEPTH` acts as our soft cap. Inside a branch, the
	# branch's own floor count gates further descent.
	if GameManager.current_branch == "dungeon":
		if GameManager.current_depth >= MAX_DEPTH:
			_end_run(true, "")
			return
	else:
		var branch_floors: int = BranchRegistry.floors_in(GameManager.current_branch)
		if GameManager.current_depth >= branch_floors:
			CombatLog.add("You are at the bottom of %s." % \
					BranchRegistry.display_name(GameManager.current_branch))
			return
	var used_secondary: bool = (player.grid_pos == generator.stairs_down_pos2)
	_save_current_floor()
	GameManager.current_depth += 1
	_regenerate_dungeon(false, used_secondary)


func _on_stairs_up_tapped(_pos: Vector2i) -> void:
	if run_over:
		return
	# If we're on depth 1 of a non-trunk branch, stairs-up returns to the
	# parent floor on the main dungeon tree instead of being a no-op.
	if GameManager.current_branch != "dungeon" and GameManager.current_depth == 1:
		_save_current_floor()
		if GameManager.leave_branch():
			_regenerate_dungeon(false, false)
		return
	if GameManager.current_depth <= 1:
		return
	var used_secondary: bool = (player.grid_pos == generator.spawn_pos2)
	_save_current_floor()
	GameManager.current_depth -= 1
	_regenerate_dungeon(true, used_secondary)


## Skill level-up callback that refreshes defense stats. Dodging /
## stealth / armour all feed into EV, and a new skill level should
## propagate to the player's cached `stats.EV` immediately.
func _on_skill_leveled_up_for_stats(p: Node, skill_id: String, _new_level: int) -> void:
	if p != player or player == null:
		return
	if skill_id == "dodging" or skill_id == "stealth" or skill_id == "armour":
		if player.has_method("_recompute_defense"):
			player._recompute_defense()


## Trigger a trap the player just stepped on. Effect depends on the
## trap's `type` field; DCSS damage scales with depth. After firing,
## most traps remain in place (visible reminder) but arrow/bolt/spear
## mechanicals can wear out — we keep them for simplicity.
func _trigger_trap(pos: Vector2i) -> void:
	if player == null or generator == null:
		return
	var info: Dictionary = generator.traps.get(pos, {})
	var ttype: String = String(info.get("type", ""))
	var depth: int = int(info.get("depth", 1))
	match ttype:
		"dart":
			var d: int = 1 + randi() % max(3 + depth / 3, 3)
			player.take_damage(d, "physical")
			player.set_meta("_poison_turns", 5)
			player.set_meta("_poison_dmg", 2)
			CombatLog.add("A poisoned dart hits you for %d!" % d)
		"arrow":
			var a: int = 1 + randi() % max(4 + depth / 3, 4)
			player.take_damage(a, "physical")
			CombatLog.add("An arrow thuds into you! (%d dmg)" % a)
		"spear":
			var s: int = 1 + randi() % max(6 + depth / 3, 6)
			player.take_damage(s, "physical")
			CombatLog.add("A spear stabs you! (%d dmg)" % s)
		"bolt":
			var b: int = 1 + randi() % max(5 + depth / 3, 5)
			player.take_damage(b, "physical")
			CombatLog.add("A crossbow bolt fires into you! (%d dmg)" % b)
		"teleport":
			CombatLog.add("Space wobbles — you are teleported!")
			if player.has_method("_teleport_random"):
				player._teleport_random()
		"alarm":
			CombatLog.add("An alarm blares!")
			MonsterAI.broadcast_noise(get_tree(), pos, 30, 0)
		"net":
			player.set_meta("_rooted_turns", 5)
			CombatLog.add("A net falls on you! (rooted for 5 turns)")
		_:
			CombatLog.add("A trap triggers, but nothing happens.")


## Keyboard command dispatcher. Wires the vi-key / function-key
## shortcuts (`i`, `z`, `q`, `r`, `,`, `o`, `s`, `a`, …) to the same
## dialogs the on-screen buttons open. Movement keys route through
## `try_move` directly in TouchInput; this handler only takes the
## non-directional actions.
func _on_key_action(action: String) -> void:
	if run_over or player == null:
		return
	match action:
		"inventory":
			_open_bag_filtered("all")
		"magic":
			_open_magic_dialog()
		"quickspell":
			# Shift-Z: fire the first quickslotted spell, if any.
			if player.quickslot_ids.size() > 0:
				var qs: String = String(player.quickslot_ids[0])
				if qs.begins_with("spell:"):
					var result: Dictionary = _execute_cast(qs.substr(6))
					if result.get("message", "") != "":
						CombatLog.add(result.get("message", ""))
		"quaff":
			_open_bag_filtered("potion")
		"read":
			_open_bag_filtered("scroll")
		"evoke":
			_open_bag_filtered("wand")
		"pickup":
			# Movement already auto-picks up; this just triggers a re-scan
			# of the current tile in case items arrived mid-turn.
			if player.has_method("_pickup_items_here"):
				player._pickup_items_here()
		"auto_explore":
			if touch_input != null and touch_input.has_method("begin_auto_explore"):
				touch_input.begin_auto_explore()
		"rest":
			if player.has_method("begin_rest"):
				player.begin_rest()
			else:
				# Fallback: spend a single turn in place.
				player.try_move(Vector2i.ZERO)
				TurnManager.end_player_turn()
		"abilities":
			# If aligned to a god, show invocations; otherwise log a hint.
			if player.current_god != "":
				_show_invocations_menu()
			else:
				CombatLog.add("You have no abilities to invoke.")
		"examine":
			CombatLog.add("Examine mode: tap a tile to inspect. (stub)")
		"cancel":
			# Close any active popup. Godot's AcceptDialog auto-closes on
			# Esc, but the path here also ensures targeting mode releases.
			if touch_input != null and "targeting_mode" in touch_input:
				touch_input.targeting_mode = false


## Shop tap: open a buying menu against the shop's rolled inventory.
## Items are removed from the shop's list on purchase and added to the
## player's inventory; gold decrements. Re-entering a shop floor shows
## the same inventory minus any bought items (state persists via the
## generator, which is saved in the floor snapshot).
func _on_shop_tapped(pos: Vector2i) -> void:
	if run_over or generator == null or player == null:
		return
	var shop: Dictionary = generator.shops.get(pos, {})
	if shop.is_empty():
		return
	_open_shop_dialog(pos, shop)


func _open_shop_dialog(pos: Vector2i, shop: Dictionary) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dlg := AcceptDialog.new()
	var kind: String = String(shop.get("kind", "general"))
	dlg.title = "Shop — %s (you have %d gold)" % [kind.capitalize(), player.gold]
	dlg.exclusive = false
	dlg.ok_button_text = "Leave"
	var vb := VBoxContainer.new()
	dlg.add_child(vb)
	var inventory: Array = shop.get("inventory", [])
	if inventory.is_empty():
		var lbl := Label.new()
		lbl.text = "Shop is empty."
		vb.add_child(lbl)
	else:
		for entry in inventory:
			var item_id: String = String(entry.get("id", ""))
			var price: int = int(entry.get("price", 0))
			var name_s: String = item_id.replace("_", " ").capitalize()
			var info_row: Dictionary = ConsumableRegistry.get_info(item_id)
			if not info_row.is_empty():
				name_s = String(info_row.get("name", name_s))
			var btn := Button.new()
			btn.text = "%s — %d gold" % [name_s, price]
			btn.disabled = player.gold < price
			btn.pressed.connect(_buy_from_shop.bind(pos, entry, dlg))
			vb.add_child(btn)
	popup_mgr.add_child(dlg)
	dlg.popup_centered(Vector2i(760, 640))


func _buy_from_shop(pos: Vector2i, entry: Dictionary, dlg: AcceptDialog) -> void:
	if player == null or generator == null:
		return
	var shop: Dictionary = generator.shops.get(pos, {})
	if shop.is_empty():
		return
	var price: int = int(entry.get("price", 0))
	if player.gold < price:
		CombatLog.add("You cannot afford that.")
		return
	player.gold -= price
	# Hand the item over. Items slot into inventory via ConsumableRegistry
	# (potions/scrolls) or WeaponRegistry/ArmorRegistry (gear).
	var item_id: String = String(entry.get("id", ""))
	var explicit_kind: String = String(entry.get("kind", ""))
	var item_dict: Dictionary = {"id": item_id, "name": item_id.replace("_", " ").capitalize()}
	var info_row: Dictionary = ConsumableRegistry.get_info(item_id)
	if not info_row.is_empty():
		item_dict = info_row
	elif explicit_kind == "weapon":
		item_dict = {"id": item_id, "kind": "weapon",
				"name": WeaponRegistry.display_name_for(item_id)}
	elif explicit_kind == "armor":
		var ainfo: Dictionary = ArmorRegistry.get_info(item_id)
		item_dict = {"id": item_id, "kind": "armor",
				"name": String(ainfo.get("name", item_id)),
				"ac": int(ainfo.get("ac", 0)),
				"slot": String(ainfo.get("slot", "chest"))}
	player.items.append(item_dict)
	player.inventory_changed.emit()
	CombatLog.add("Bought %s for %d gold." % [String(item_dict.get("name", item_id)), price])
	shop["inventory"].erase(entry)
	generator.shops[pos] = shop
	# Refresh the dialog so the bought row disappears.
	if dlg != null:
		dlg.queue_free()
		_open_shop_dialog(pos, shop)


## Altar tap: if the player is unaligned, this pledges them to the
## altar's god (DCSS `pray` / worship). If already aligned to this god,
## open the invocations menu. If aligned to another god, politely
## refuse — the player must abandon first (not modelled here).
func _on_altar_tapped(pos: Vector2i) -> void:
	if run_over or generator == null or player == null:
		return
	var god_id: String = String(generator.altars.get(pos, ""))
	if god_id == "":
		return
	var info: Dictionary = GodRegistry.get_info(god_id)
	if info.is_empty():
		return
	# Already pledged to this god → open the invocations menu directly.
	if player.current_god == god_id:
		_show_invocations_menu()
		return
	if player.current_god != "":
		CombatLog.add("You are already pledged to %s." % \
				GodRegistry.get_info(player.current_god).get("title", player.current_god))
		return
	_show_altar_guide(god_id, info)


## Altar pledge prompt — shows the beginner guide (how to please the
## god, what powers unlock, what not to do) and a Pledge / Cancel
## pair. First-time players can read the actual contract before
## committing to a permanent pledge.
func _show_altar_guide(god_id: String, info: Dictionary) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = String(info.get("title", god_id))
	dlg.ok_button_text = "Cancel"

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	dlg.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = String(info.get("title", god_id))
	name_lbl.add_theme_font_size_override("font_size", 56)
	name_lbl.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(info.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 40)
	desc_lbl.modulate = Color(0.85, 0.85, 0.95)
	desc_lbl.custom_minimum_size = Vector2(820, 0)
	vb.add_child(desc_lbl)

	vb.add_child(HSeparator.new())

	var guide_lbl := Label.new()
	guide_lbl.text = GodRegistry.get_guide(god_id)
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_lbl.add_theme_font_size_override("font_size", 34)
	guide_lbl.custom_minimum_size = Vector2(820, 0)
	vb.add_child(guide_lbl)

	vb.add_child(HSeparator.new())

	var pledge_btn := Button.new()
	pledge_btn.text = "Pledge yourself to %s" % String(info.get("name", god_id))
	pledge_btn.add_theme_font_size_override("font_size", 42)
	pledge_btn.custom_minimum_size = Vector2(0, 112)
	pledge_btn.pressed.connect(func():
		player.current_god = god_id
		player.piety = 10
		CombatLog.add("You pledge yourself to %s." % String(info.get("title", god_id)))
		dlg.queue_free())
	vb.add_child(pledge_btn)

	popup_mgr.add_child(dlg)
	dlg.popup_centered(Vector2i(900, 1100))


## Open a popup listing the current god's invocations. Greyed rows are
## locked by piety threshold; active rows fire `_invoke(inv_id)`.
func _show_invocations_menu() -> void:
	if player == null or player.current_god == "":
		return
	var god: Dictionary = GodRegistry.get_info(player.current_god)
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	var dlg := AcceptDialog.new()
	dlg.title = "%s — Piety %d/%d" % [String(god.get("title", "")), player.piety,
			int(god.get("piety_cap", 200))]
	dlg.exclusive = false
	var vb := VBoxContainer.new()
	dlg.add_child(vb)
	for inv_id in god.get("invocations", []):
		var inv: Dictionary = GodRegistry.invocation(String(inv_id))
		var btn := Button.new()
		var locked: bool = player.piety < int(inv.get("min_piety", 999))
		btn.text = "%s  — %d piety  [%s]" % [String(inv.get("name", inv_id)),
				int(inv.get("cost", 0)), ("LOCKED" if locked else "READY")]
		btn.disabled = locked or player.piety < int(inv.get("cost", 0))
		btn.pressed.connect(_invoke.bind(String(inv_id), dlg))
		vb.add_child(btn)
	popup_mgr.add_child(dlg)
	dlg.popup_centered(Vector2i(720, 560))


func _invoke(inv_id: String, dlg: AcceptDialog) -> void:
	var inv: Dictionary = GodRegistry.invocation(inv_id)
	if inv.is_empty() or player == null:
		return
	if player.piety < int(inv.get("cost", 0)):
		CombatLog.add("Not enough piety.")
		return
	player.piety -= int(inv.get("cost", 0))
	if dlg != null:
		dlg.queue_free()
	_dispatch_invocation(String(inv.get("effect", "")))


## Invocation effect switchboard. One big match that branches to helpers
## so each god's power reads compactly. Effects that are just a rename
## of an existing potion/scroll reuse `_apply_consumable_effect`; novel
## ones get inline logic.
func _dispatch_invocation(effect: String) -> void:
	match effect:
		# ---- Trog ----
		"berserk":
			player._apply_consumable_effect({"effect": "berserk", "dur_base": 15, "dur_rand": 10})
		"trog_hand":
			_summon_ally("orc_warrior", 60, "Trog's Hand strikes your side!")
		"brothers":
			for i in 3:
				_summon_ally("deep_troll", 40, "")
			CombatLog.add("Trog sends his brothers in arms!")
		# ---- Okawaru ----
		"heroism":
			player.set_meta("_heroism_turns", 25)
			CombatLog.add("Your combat prowess surges!")
		"finesse":
			player.set_meta("_finesse_turns", 10)
			CombatLog.add("Your strikes blur into a flurry!")
		"duel":
			var duel_t: Monster = _find_nearest_visible_monster(10)
			if duel_t != null:
				duel_t.take_damage(randi_range(25, 45))
				CombatLog.add("Okawaru pulls the %s into a duel!" % _mon_name(duel_t))
		# ---- Makhleb ----
		"minor_destruction":
			_damage_nearest_visible(12, 22, "A burst of chaos strikes %s!")
		"major_destruction":
			_damage_nearest_visible(28, 55, "Makhleb's destruction engulfs %s!")
		"summon_demon":
			_summon_ally("red_devil", 50, "A demon rises to serve!")
		# ---- Uskayaw ----
		"stomp":
			_aoe_damage_visible(8, 10, 20, "Uskayaw's stomp rattles the floor!")
		"line_pass":
			_aoe_damage_visible(12, 15, 30, "You dance through the enemy line!")
		# ---- Zin / TSO / Elyvilon ----
		"vitalisation":
			_heal_player(40, 20, "Zin's light fills you.")
		"imprison":
			var imp_t: Monster = _find_nearest_visible_monster(8)
			if imp_t != null:
				imp_t.set_meta("_paralysis_turns", 10)
				CombatLog.add("Stone walls seal the %s in place." % _mon_name(imp_t))
		"sanctuary":
			player.set_meta("_sanctuary_turns", 12)
			CombatLog.add("A peaceful silence falls around you.")
		"divine_shield":
			if player.stats != null:
				player.stats.AC += 6
				player.set_meta("_divine_shield_turns", 15)
				player.set_meta("_divine_shield_ac", 6)
				player.stats_changed.emit()
			CombatLog.add("A golden shield surrounds you.")
		"cleansing_flame":
			_aoe_damage_visible(12, 20, 40, "Cleansing flame burns every foe!")
		"summon_angel":
			_summon_ally("angel", 80, "An angel descends to your aid!")
		"lesser_healing":
			_heal_player(15, 0, "Elyvilon mends your wounds.")
		"greater_healing":
			_heal_player(40, 0, "Elyvilon heals you deeply.")
		"pacify":
			var pac_t: Monster = _find_nearest_visible_monster(8)
			if pac_t != null:
				pac_t.set_meta("_flee_turns", 20)
				CombatLog.add("The %s calms and flees in peace." % _mon_name(pac_t))
		# ---- Vehumet ----
		"gift_spell":
			if player.learned_spells.size() < 20:
				var pool: Array = ["throw_flame", "throw_frost", "bolt_of_fire", "bolt_of_cold"]
				var sp: String = String(pool[randi() % pool.size()])
				if not player.learned_spells.has(sp):
					player.learned_spells.append(sp)
					CombatLog.add("Vehumet gifts you %s." % sp.replace("_", " "))
		# ---- Sif Muna ----
		"channel_mana":
			if player.stats != null:
				player.stats.MP = min(player.stats.mp_max, player.stats.MP + 15)
				player.stats_changed.emit()
			CombatLog.add("Sif Muna channels arcane energy into you.")
		"divine_exegesis":
			if player.stats != null:
				player.stats.MP = min(player.stats.mp_max, player.stats.MP + 30)
				player.stats_changed.emit()
			CombatLog.add("Your next spell will hit like a meteor.")
		"amnesia":
			player._apply_consumable_effect({"effect": "amnesia"})
		# ---- Kikubaaqudgha ----
		"receive_corpses":
			for i in 3:
				_summon_ally("zombie", 30, "")
			CombatLog.add("Corpses stir to your service.")
		"god_torment":
			player._apply_consumable_effect({"effect": "torment"})
		"unearthly_bond":
			player.set_meta("_unearthly_bond", true)
			CombatLog.add("Your summons are bound to you.")
		# ---- Nemelex ----
		"draw_card":
			_nemelex_draw_card()
		"stack_five":
			for i in 3:
				_nemelex_draw_card()
			CombatLog.add("You stack the deck and draw three.")
		# ---- Yredelemnul ----
		"yred_animate":
			for i in 2:
				_summon_ally("zombie", 50, "")
			CombatLog.add("The dead answer your call.")
		"drain_life":
			var drained: int = _aoe_damage_visible(10, 5, 15, "Life flows out of the living!")
			_heal_player(drained / 2, 0, "")
		"enslave_soul":
			var es_t: Monster = _find_nearest_visible_monster(8)
			if es_t != null:
				es_t.set_meta("_enslaved_on_death", true)
				CombatLog.add("The %s's soul is yours to claim." % _mon_name(es_t))
		# ---- Beogh ----
		"recall_followers":
			CombatLog.add("Orc allies rally to your side.")
		"smite":
			var sm_t: Monster = _find_nearest_visible_monster(10)
			if sm_t != null:
				sm_t.take_damage(randi_range(20, 40))
				CombatLog.add("Divine wrath smites the %s!" % _mon_name(sm_t))
		# ---- Jiyva ----
		"jelly_prayer":
			player.piety = min(200, player.piety + 10)
			CombatLog.add("The slimes commune with their god.")
		"cure_bad_mutation":
			_cure_one_bad_mutation()
		"slimify":
			player.set_meta("_slimify_turns", 10)
			CombatLog.add("Your weapon oozes acidic slime.")
		# ---- Fedhas ----
		"sunlight":
			var dmap_s: DungeonMap = $DungeonLayer/DungeonMap
			if dmap_s != null and dmap_s.has_method("reveal_all"):
				dmap_s.reveal_all()
			CombatLog.add("Sunlight floods the level.")
		"plant_ring":
			CombatLog.add("Plants rise around you (decorative for now).")
		"rain":
			CombatLog.add("Rain soaks the floor.")
		# ---- Cheibriados ----
		"bend_time":
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.slowed_turns = 6
			CombatLog.add("Time slows for every foe.")
		"temporal_distortion":
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.slowed_turns = randi_range(3, 10)
			CombatLog.add("Time fractures unpredictably.")
		"slouch":
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.take_damage(randi_range(8, 20))
			CombatLog.add("Slouch hits the swift!")
		# ---- Lugonu ----
		"bend_space":
			var bs_t: Monster = _find_nearest_visible_monster(8)
			if bs_t != null:
				bs_t.take_damage(randi_range(5, 12))
				CombatLog.add("Space warps around the %s." % _mon_name(bs_t))
		"banishment":
			var bn_t: Monster = _find_nearest_visible_monster(8)
			if bn_t != null:
				bn_t.take_damage(9999)
				CombatLog.add("The %s vanishes into the Abyss!" % _mon_name(bn_t))
		"corrupt_level":
			CombatLog.add("The level writhes and corrupts (cosmetic for now).")
		# ---- Ashenzari ----
		"scry":
			var dmap_y: DungeonMap = $DungeonLayer/DungeonMap
			if dmap_y != null and dmap_y.has_method("reveal_all"):
				dmap_y.reveal_all()
			CombatLog.add("Ashenzari grants you sight.")
		"transfer_knowledge":
			CombatLog.add("Your skills shift. (stub — no UI yet)")
		# ---- Dithmenos ----
		"shadow_step":
			var ss_t: Monster = _find_nearest_visible_monster(10)
			if ss_t != null:
				var near: Vector2i = _find_free_adjacent_tile(ss_t.grid_pos)
				if near != ss_t.grid_pos:
					player.grid_pos = near
					player.position = Vector2(near.x * TILE_SIZE + TILE_SIZE / 2.0,
							near.y * TILE_SIZE + TILE_SIZE / 2.0)
					player.moved.emit(near)
					CombatLog.add("You step through shadow!")
		"shadow_form":
			player.set_meta("_shadow_form_turns", 20)
			CombatLog.add("You become a living shadow.")
		"summon_shadow":
			_summon_ally("shadow", 50, "A shadow detaches from you.")
		# ---- Gozag ----
		"potion_petition":
			if player.gold < 50:
				CombatLog.add("Gozag requires 50 gold for a petition.")
			else:
				player.gold -= 50
				for i in 3:
					var pot_ids: Array = ["potion_curing", "potion_haste", "potion_might",
							"potion_brilliance", "potion_resistance", "potion_magic"]
					var pid: String = String(pot_ids[randi() % pot_ids.size()])
					player.items.append(ConsumableRegistry.get_info(pid))
				player.inventory_changed.emit()
				CombatLog.add("Gozag sells you three potions for 50 gold.")
		"call_merchant":
			if player.gold < 100:
				CombatLog.add("Gozag requires 100 gold to call a merchant.")
			else:
				player.gold -= 100
				_summon_shop_near_player()
		"bribe_branch":
			if player.gold < 250:
				CombatLog.add("Gozag requires 250 gold to bribe the branch.")
			else:
				player.gold -= 250
				for m in get_tree().get_nodes_in_group("monsters"):
					if is_instance_valid(m) and m.is_alive:
						m.set_meta("_flee_turns", 30)
				CombatLog.add("Gold changes hands; monsters retreat.")
		# ---- Qazlal ----
		"upheaval":
			_damage_nearest_visible(25, 50, "Upheaval tears up the floor!")
		"elemental_force":
			for i in 3:
				_summon_ally("fire_elemental", 30, "")
			CombatLog.add("Elementals swirl at your command.")
		"disaster_area":
			_aoe_damage_visible(12, 30, 60, "Disaster area erupts!")
		# ---- Ru ----
		"draw_out_power":
			if player.stats != null:
				player.stats.HP = player.stats.hp_max
				player.stats.MP = player.stats.mp_max
				player.stats_changed.emit()
			CombatLog.add("Ru surges power through you!")
		"power_leap":
			_aoe_damage_visible(12, 20, 40, "You leap with awesome power!")
		"apocalypse":
			_aoe_damage_visible(15, 40, 80, "Apocalypse!")
		# ---- Wu Jian ----
		"wall_jump":
			_aoe_damage_visible(8, 12, 24, "You pivot off the wall!")
		"heavenly_storm":
			player.set_meta("_heavenly_storm_turns", 20)
			CombatLog.add("Heavenly storm girds your attacks.")
		# ---- Hepliaklqana ----
		"recall_ancestor":
			_summon_ally("orc_knight", 999, "Your ancestor answers the call.")
		"idealise":
			CombatLog.add("Your ancestor gleams with potential.")
		"transference":
			CombatLog.add("You swap places with your ancestor. (stub)")
		# ---- Ignis ----
		"fiery_armour":
			player.set_meta("_fiery_armour_turns", 30)
			CombatLog.add("Flames wreath your armour.")
		"foxfire_swarm":
			for i in 4:
				_summon_ally("fire_elemental", 20, "")
			CombatLog.add("A swarm of foxfires flits out.")
		"rising_flame":
			_damage_nearest_visible(30, 55, "A spire of flame engulfs %s!")
		_:
			CombatLog.add("The god is silent.")


## ---- Invocation helpers ---------------------------------------------------

func _mon_name(m: Node) -> String:
	if m == null or not ("data" in m) or m.data == null:
		return "foe"
	return String(m.data.display_name)


func _heal_player(hp: int, mp: int, msg: String) -> void:
	if player == null or player.stats == null:
		return
	if hp > 0:
		player.stats.HP = min(player.stats.hp_max, player.stats.HP + hp)
	if mp > 0:
		player.stats.MP = min(player.stats.mp_max, player.stats.MP + mp)
	player.stats_changed.emit()
	if msg != "":
		CombatLog.add(msg)


func _damage_nearest_visible(lo: int, hi: int, msg: String) -> void:
	var t: Monster = _find_nearest_visible_monster(12)
	if t == null:
		return
	var dmg: int = randi_range(lo, hi)
	t.take_damage(dmg)
	if "%s" in msg:
		CombatLog.add(msg % _mon_name(t))
	else:
		CombatLog.add(msg)


## AoE across every currently visible hostile. Returns total damage dealt
## so lifesteal effects like drain_life can feed it back to the player.
func _aoe_damage_visible(radius: int, lo: int, hi: int, msg: String) -> int:
	var total: int = 0
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if dmap != null and not dmap.is_tile_visible(m.grid_pos):
			continue
		var d: int = max(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y))
		if d > radius:
			continue
		var dmg: int = randi_range(lo, hi)
		m.take_damage(dmg)
		total += dmg
	if msg != "":
		CombatLog.add(msg)
	return total


## Try to summon a friendly Companion of `monster_id` adjacent to the
## player. Silently no-ops if the id is unknown or no free tile exists.
func _summon_ally(monster_id: String, lifetime: int, msg: String) -> void:
	if generator == null or player == null:
		return
	var mdata: MonsterData = MonsterRegistry.fetch(monster_id)
	if mdata == null:
		return
	var tile: Vector2i = _find_free_adjacent_tile(player.grid_pos)
	if tile == player.grid_pos:
		return
	var c: Companion = _COMPANION_SCENE.instantiate()
	$EntityLayer.add_child(c)
	c.setup(generator, tile, mdata)
	c.lifetime = lifetime
	if msg != "":
		CombatLog.add(msg)


## Gozag's "Call Merchant" — turn the adjacent floor tile into a fresh
## shop with a rolled inventory so the player can spend the rest of
## their gold in situ.
func _summon_shop_near_player() -> void:
	if player == null or generator == null:
		return
	var tile: Vector2i = _find_free_adjacent_tile(player.grid_pos)
	if tile == player.grid_pos:
		CombatLog.add("No room next to you.")
		return
	generator.map[tile.x][tile.y] = DungeonGenerator.TileType.SHOP
	generator.shops[tile] = {
		"kind": "general",
		"inventory": generator._roll_shop_inventory("general", GameManager.current_depth),
	}
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		dmap.queue_redraw()
	CombatLog.add("A merchant sets up stall at your side.")


## Remove one random "bad" mutation from the player, reversing its
## delta. Used by Jiyva's `cure_bad_mutation`.
func _cure_one_bad_mutation() -> void:
	if player == null or player.mutations.is_empty():
		CombatLog.add("You have no mutations to cure.")
		return
	var bad_ids: Array = []
	for mid in player.mutations.keys():
		var flags: Array = MutationRegistry.get_info(String(mid)).get("flags", [])
		if flags.has("bad"):
			bad_ids.append(String(mid))
	if bad_ids.is_empty():
		CombatLog.add("Nothing bad to purge.")
		return
	var picked: String = String(bad_ids[randi() % bad_ids.size()])
	player.remove_mutation(picked)
	CombatLog.add("You feel %s drain away." % picked.replace("_", " "))


## Nemelex-style single card draw. We reuse existing consumable effects
## weighted by a small table; fancier decks can come later.
func _nemelex_draw_card() -> void:
	if player == null:
		return
	var cards: Array = [
		{"effect": "haste", "dur_base": 10, "dur_rand": 5, "msg": "Card of Haste!"},
		{"effect": "heal", "hp_base": 20, "hp_rand": 10, "msg": "Card of Healing!"},
		{"effect": "blink", "msg": "Card of Blink!"},
		{"effect": "immolation", "msg": "Card of Fire!"},
		{"effect": "fog", "msg": "Card of Warp!"},
		{"effect": "buff_temp", "stat": "STR", "amount": 6, "dur_base": 15, "dur_rand": 10, "msg": "Card of Might!"},
	]
	var card: Dictionary = cards[randi() % cards.size()]
	CombatLog.add(String(card.get("msg", "A card shimmers.")))
	player._apply_consumable_effect(card)


## DCSS-style branch entry: tapping onto a BRANCH_ENTRANCE tile saves
## the current floor, pushes it onto the return stack, and rolls into
## the child branch at depth 1.
func _on_branch_entrance_tapped(pos: Vector2i) -> void:
	if run_over or generator == null:
		return
	var branch_id: String = String(generator.branch_entrances.get(pos, ""))
	if branch_id == "":
		return
	_save_current_floor()
	GameManager.enter_branch(branch_id)
	CombatLog.add("You enter %s." % BranchRegistry.display_name(branch_id))
	_regenerate_dungeon(false, false)


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
	# Legacy: this used to overwrite `current_branch` with the tileset
	# bucket on every depth change. That clobbered real branch state
	# (lair/orc/vaults/…) set by `enter_branch`, so floor_key lookups
	# drifted on re-entry and saved explored maps vanished. Tileset
	# selection now goes through GameManager.tileset_branch() which
	# derives the theme without mutating current_branch.
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
	await get_tree().process_frame
	if _floor_state.has(GameManager.floor_key()):
		_restore_floor(GameManager.current_depth)
	else:
		_spawn_monsters_for_current_depth()
		_spawn_dummy_items(5)
	# Build the minimap AFTER restoring the explored-tile bitmap and spawning
	# monsters. Doing this before _restore_floor gave us a thumbnail drawn
	# from an empty explored set on every revisit.
	_refresh_minimap_preview(dmap, entry_pos)
	_refresh_actor_visibility(dmap)


func _save_current_floor() -> void:
	if generator == null:
		return
	var snapshot: Dictionary = {"monsters": [], "items": [], "map": []}
	# Snapshot the raw tile grid so revisits show the same geometry even
	# when generation involves non-deterministic branches (hyper fallbacks,
	# vault placements, etc.).
	for x in DungeonGenerator.MAP_WIDTH:
		var col: Array = []
		for y in DungeonGenerator.MAP_HEIGHT:
			col.append(generator.map[x][y])
		snapshot["map"].append(col)
	snapshot["stairs_down_pos"] = generator.stairs_down_pos
	snapshot["stairs_down_pos2"] = generator.stairs_down_pos2
	snapshot["spawn_pos"] = generator.spawn_pos
	snapshot["spawn_pos2"] = generator.spawn_pos2
	snapshot["rooms"] = generator.rooms.duplicate()
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
	_floor_state[GameManager.floor_key()] = snapshot


func _restore_floor(_depth: int) -> void:
	var snapshot: Dictionary = _floor_state.get(GameManager.floor_key(), {})
	if snapshot.is_empty():
		return
	# Prefer restoring the exact tile grid we saved rather than relying on
	# the regenerator to replay the same RNG path — fallback builders,
	# vault placement jitter and other stray randomness can drift. When a
	# saved map exists, apply it verbatim.
	if snapshot.has("map"):
		var saved_map: Array = snapshot["map"]
		for x in DungeonGenerator.MAP_WIDTH:
			for y in DungeonGenerator.MAP_HEIGHT:
				generator.map[x][y] = int(saved_map[x][y])
		if snapshot.has("stairs_down_pos"):
			generator.stairs_down_pos = snapshot["stairs_down_pos"]
		if snapshot.has("stairs_down_pos2"):
			generator.stairs_down_pos2 = snapshot["stairs_down_pos2"]
		if snapshot.has("spawn_pos"):
			generator.spawn_pos = snapshot["spawn_pos"]
		if snapshot.has("spawn_pos2"):
			generator.spawn_pos2 = snapshot["spawn_pos2"]
		if snapshot.has("rooms"):
			generator.rooms = snapshot["rooms"].duplicate()
		var dmap_early: DungeonMap = $DungeonLayer/DungeonMap
		if dmap_early != null:
			dmap_early.queue_redraw()
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
		if player != null:
			dmap.update_fov(player.grid_pos)
		else:
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
	_suppress_bag_reopen = true
	# Close the bag / any other open dialog first so the identify picker
	# surfaces on top. Without this it stacks behind the bag and becomes
	# untouchable.
	_close_all_dialogs()
	# Dedupe by item id — carrying three of the same unknown potion should
	# show one row in the picker, and identifying it reveals all three.
	var unidentified: Array = []
	var seen_ids: Dictionary = {}
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		if iid == "" or seen_ids.has(iid):
			continue
		if ConsumableRegistry.has(iid) and not GameManager.is_identified(iid):
			seen_ids[iid] = true
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


## Scroll of Enchant Weapon / Armour — pops a picker listing every
## weapon (or every armor piece) the player has, equipped or in the
## bag. Tapping one bumps its enchant `plus` by 1.
func _on_enchant_one_requested(kind: String) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	_close_all_dialogs()
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.ok_button_text = "Cancel"
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg.add_child(vb)
	var prompt := Label.new()
	prompt.add_theme_font_size_override("font_size", 40)
	vb.add_child(prompt)

	if kind == "weapon":
		dlg.title = "Enchant Which Weapon?"
		prompt.text = "Choose a weapon to enchant (+1 damage):"
		# Equipped weapon first
		if player.equipped_weapon_id != "":
			var wid: String = player.equipped_weapon_id
			var label: String = "%s (equipped)" % _weapon_name_with_plus(wid, player.equipped_weapon_plus)
			var btn := _make_enchant_btn(label, dlg,
					func(): _apply_enchant_equipped_weapon(1))
			vb.add_child(btn)
		# Inventory weapons
		for i in range(player.get_items().size()):
			var it: Dictionary = player.get_items()[i]
			if String(it.get("kind", "")) != "weapon":
				continue
			var wid2: String = String(it.get("id", ""))
			var lbl: String = _weapon_name_with_plus(wid2, int(it.get("plus", 0)))
			var idx: int = i
			var btn2 := _make_enchant_btn(lbl, dlg,
					func(): _apply_enchant_inventory_item(idx, 1))
			vb.add_child(btn2)
	else:
		dlg.title = "Enchant Which Armour?"
		prompt.text = "Choose an armour piece to enchant (+1 AC):"
		# Equipped armor slots
		for slot in ["chest", "cloak", "legs", "helm", "gloves", "boots"]:
			if not player.equipped_armor.has(slot):
				continue
			var a: Dictionary = player.equipped_armor[slot]
			var label: String = "%s (%s, equipped)" % [
				_armor_name_with_plus(a),
				slot,
			]
			var slot_cap: String = slot
			var btn := _make_enchant_btn(label, dlg,
					func(): _apply_enchant_equipped_armor(slot_cap, 1))
			vb.add_child(btn)
		# Inventory armor
		for i in range(player.get_items().size()):
			var it: Dictionary = player.get_items()[i]
			if String(it.get("kind", "")) != "armor":
				continue
			var lbl: String = _armor_name_with_plus(it)
			var idx: int = i
			var btn2 := _make_enchant_btn(lbl, dlg,
					func(): _apply_enchant_inventory_item(idx, 1))
			vb.add_child(btn2)

	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(900, 1200))


func _make_enchant_btn(text: String, dlg: AcceptDialog,
		on_pick: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 38)
	btn.pressed.connect(func():
		on_pick.call()
		dlg.queue_free())
	return btn


func _apply_enchant_equipped_weapon(amount: int) -> void:
	if player == null:
		return
	player.equipped_weapon_plus += amount
	CombatLog.add("Your %s glows brightly! (now +%d)" % [
			WeaponRegistry.display_name_for(player.equipped_weapon_id),
			player.equipped_weapon_plus])
	player.stats_changed.emit()


func _apply_enchant_equipped_armor(slot: String, amount: int) -> void:
	if player == null or not player.equipped_armor.has(slot):
		return
	var a: Dictionary = player.equipped_armor[slot]
	a["plus"] = int(a.get("plus", 0)) + amount
	CombatLog.add("Your %s shimmers! (now +%d)" % [
			String(a.get("name", "armour")), int(a["plus"])])
	player._recompute_gear_stats()


func _apply_enchant_inventory_item(idx: int, amount: int) -> void:
	if player == null:
		return
	var items: Array = player.get_items()
	if idx < 0 or idx >= items.size():
		return
	var it: Dictionary = items[idx]
	it["plus"] = int(it.get("plus", 0)) + amount
	CombatLog.add("Your %s shimmers! (now +%d)" % [
			String(it.get("name", "item")), int(it["plus"])])
	player.inventory_changed.emit()


## Format helper: "Longsword +2" when plus > 0, plain name otherwise.
func _weapon_name_with_plus(wid: String, plus: int) -> String:
	var n: String = WeaponRegistry.display_name_for(wid)
	if plus > 0:
		return "%s +%d" % [n, plus]
	return n


func _armor_name_with_plus(a: Dictionary) -> String:
	var n: String = String(a.get("name", a.get("id", "Armour")))
	var p: int = int(a.get("plus", 0))
	if p > 0:
		return "%s +%d" % [n, p]
	return n


func _on_player_leveled_up(new_level: int) -> void:
	# DCSS-style pacing — stat point every 3 levels (so 3 / 6 / 9 / …).
	# Other level-ups still trigger the toast stack via player.leveled_up
	# but skip the stat-picker popup.
	if new_level % 3 != 0:
		if skill_toast != null and skill_toast.has_method("show_toast"):
			skill_toast.show_toast("Lv.%d" % new_level)
		return
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or not popup_mgr.has_method("show_levelup_popup"):
		return
	popup_mgr.show_levelup_popup(new_level, Callable(player, "apply_level_up_stat"))


## Low-HP warning vignette — a full-screen red ColorRect that pulses when
## HP drops below 25% max. Created once, then modulated on/off.
var _low_hp_overlay: ColorRect = null
var _low_hp_tween: Tween = null

func _setup_low_hp_overlay() -> void:
	if _low_hp_overlay != null and is_instance_valid(_low_hp_overlay):
		return
	var ui_root: Node = get_node_or_null("UILayer/UI")
	if ui_root == null:
		return
	var rect := ColorRect.new()
	rect.name = "LowHPVignette"
	rect.color = Color(0.75, 0.05, 0.05, 0.0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.z_index = -10  # Behind HUD so buttons/text stay readable.
	# Inner gradient: only the border area is red-ish; centre stays clear.
	# Simple cheat — use a shader-like material? We go simpler: just a full
	# overlay with low alpha during pulse.
	ui_root.add_child(rect)
	_low_hp_overlay = rect
	_update_low_hp_overlay()


func _update_low_hp_overlay() -> void:
	if player == null or player.stats == null or _low_hp_overlay == null:
		return
	var hp_pct: float = float(player.stats.HP) / float(max(player.stats.hp_max, 1))
	var threshold: float = 0.25
	if hp_pct > threshold or not player.is_alive:
		if _low_hp_tween != null and _low_hp_tween.is_valid():
			_low_hp_tween.kill()
		_low_hp_tween = null
		_low_hp_overlay.color.a = 0.0
		return
	# Already pulsing — don't restart.
	if _low_hp_tween != null and _low_hp_tween.is_valid():
		return
	# Loop a slow red pulse; each cycle 0.15 → 0.35 → 0.15 alpha.
	_low_hp_tween = create_tween().set_loops()
	_low_hp_tween.tween_property(_low_hp_overlay, "color:a", 0.35, 0.55) \
			.set_trans(Tween.TRANS_SINE)
	_low_hp_tween.tween_property(_low_hp_overlay, "color:a", 0.15, 0.55) \
			.set_trans(Tween.TRANS_SINE)


## Camera shake scaled to the hit. Small jabs get nothing (<5 dmg); anything
## bigger gets a brief random-offset shake that tapers back to the player's
## actual position. Uses Camera2D.offset so the base `position` tween
## (which follows the player) is untouched.
func _on_player_damaged(amount: int) -> void:
	if amount < 5:
		return
	var cam: Camera2D = $Camera2D
	if cam == null:
		return
	var magnitude: float = clamp(float(amount) * 1.5, 8.0, 32.0)
	_shake_camera(cam, magnitude, 0.25)


func _shake_camera(cam: Camera2D, magnitude: float, duration: float) -> void:
	if cam == null:
		return
	var steps: int = 6
	var step_t: float = duration / float(steps)
	var base_offset: Vector2 = cam.offset
	var tw: Tween = cam.create_tween()
	for i in steps:
		var falloff: float = 1.0 - float(i) / float(steps)
		var jitter: Vector2 = Vector2(
			randf_range(-magnitude, magnitude),
			randf_range(-magnitude, magnitude)) * falloff
		tw.tween_property(cam, "offset", base_offset + jitter, step_t)
	tw.tween_property(cam, "offset", base_offset, step_t)


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

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	for cat in _SKILL_CATEGORIES:
		var tb := Button.new()
		tb.text = _SKILL_CATEGORY_LABELS.get(cat, cat)
		tb.custom_minimum_size = Vector2(0, 64)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		tb.button_pressed = (cat == category)
		tb.add_theme_font_size_override("font_size", 40)
		tb.pressed.connect(_on_skills_tab.bind(cat, dlg))
		tabs_hbox.add_child(tb)
	vb.add_child(tabs_hbox)

	# Horizontal swipe on the dialog body cycles category tabs (mirrors the
	# bag screen). Threshold + axis check come from the shared helper.
	_skills_swipe_dlg = dlg
	_skills_swipe_category = category
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.gui_input.connect(_on_skills_swipe_input)

	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 20
	scroll.custom_minimum_size = Vector2(0, 1200)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 20
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
	dlg.popup_centered(Vector2i(960, 1500))


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
	name_lab.add_theme_font_size_override("font_size", 46)
	row.add_child(name_lab)

	var level: int = int(entry.get("level", 0))
	var xp: float = float(entry.get("xp", 0.0))
	var need: float = SkillSystem.xp_for_level(level + 1)
	var lv_lab := Label.new()
	if level >= SkillSystem.MAX_LEVEL:
		lv_lab.text = "MAX"
	else:
		lv_lab.text = "Lv.%d" % level
	lv_lab.add_theme_font_size_override("font_size", 46)
	lv_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lv_lab)

	# Racial aptitude label (+2 / 0 / -3) — green for positive, red for
	# negative. Gives the player an instant read on why a given skill
	# trains fast or slow for this race.
	var apt_lab := Label.new()
	apt_lab.text = _format_aptitude(skill_id)
	apt_lab.add_theme_font_size_override("font_size", 46)
	apt_lab.custom_minimum_size = Vector2(100, 0)
	apt_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var apt_val: int = _player_aptitude(skill_id)
	if apt_val > 0:
		apt_lab.add_theme_color_override("font_color", Color(0.55, 1.0, 0.55))
	elif apt_val < 0:
		apt_lab.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55))
	else:
		apt_lab.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	row.add_child(apt_lab)
	outer.add_child(row)

	var info_line := Label.new()
	var desc_text: String = String(_SKILL_DESCS.get(skill_id, ""))
	var is_training: bool = bool(entry.get("training", false))
	var parts: Array = [desc_text]
	# Show XP as soon as the skill is being trained (or has any level) so
	# the player sees progress from the very first kill instead of having
	# to wait for the first level-up.
	if (is_training or level > 0) and level < SkillSystem.MAX_LEVEL:
		parts.append("XP %d/%d" % [int(xp), int(need)])
	if not skill_system.auto_training and is_training:
		var trained_count: int = _count_trained_skills()
		if trained_count > 0:
			parts.append("%d%% XP" % int(100.0 / trained_count))
	info_line.text = "  |  ".join(PackedStringArray(parts))
	info_line.add_theme_font_size_override("font_size", 38)
	info_line.modulate = Color(0.6, 0.75, 0.6)
	outer.add_child(info_line)

	outer.add_child(HSeparator.new())
	return outer


## Current aptitude integer for `skill_id` pulled from the player's race
## resource. 0 when not set (baseline human behaviour).
func _player_aptitude(skill_id: String) -> int:
	if player == null or player.race_res == null:
		return 0
	var apts: Dictionary = player.race_res.skill_aptitudes
	return int(apts.get(skill_id, 0))


## Signed-integer aptitude formatted for the skill row (`"+3"`, `"0"`,
## `"-2"`) — padded width is handled by the label's custom_minimum_size.
func _format_aptitude(skill_id: String) -> String:
	var v: int = _player_aptitude(skill_id)
	if v == 0:
		return "0"
	return "%+d" % v


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

	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 20
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
	dlg.popup_centered(Vector2i(960, 1500))


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
	var fail_p: int = SpellRegistry.failure_rate(spell_id, player)
	var fail_txt: String = " (%d%%)" % fail_p if fail_p > 0 else ""
	var range_txt: String = ""
	if int(info.get("range", 0)) > 0:
		range_txt = "  range %d" % int(info.get("range", 0))
	name_btn.text = "%s  [%d MP]%s%s" % [spell_name, int(info.get("mp", 0)), fail_txt, range_txt]
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
	dlg.ok_button_text = ""
	# Show all schools (multi-school spells like iron_shot list both).
	var schools_list: Array = SpellRegistry.get_schools(spell_id)
	var schools_txt: String = ""
	if schools_list.size() > 0:
		var parts: Array = []
		for sname in schools_list:
			var lv: int = skill_system.get_level(player, String(sname)) if skill_system and player else 0
			parts.append("%s Lv.%d" % [String(sname).capitalize(), lv])
		schools_txt = ", ".join(PackedStringArray(parts))
	var fail_pct: int = SpellRegistry.failure_rate(spell_id, player)
	var spell_pow: int = SpellRegistry.calc_spell_power(spell_id, player)
	var text: String = "%s\n\nMP Cost: %d\nSchools: %s\nDifficulty: %d\nPower: %d\nFailure: %d%%\nRange: %d" % [
		String(info.get("desc", "")),
		int(info.get("mp", 0)),
		schools_txt,
		int(info.get("difficulty", 1)),
		spell_pow,
		fail_pct,
		int(info.get("range", 6)),
	]
	if info.has("min_dmg") and int(info.get("min_dmg", 0)) > 0:
		text += "\nDamage: %d-%d + power" % [int(info.get("min_dmg", 0)), int(info.get("max_dmg", 0))]
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	dlg.add_child(vb)
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 20
	scroll.custom_minimum_size = Vector2(860, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lab)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 44)
	close_btn.custom_minimum_size = Vector2(0, 96)
	close_btn.pressed.connect(dlg.queue_free)
	vb.add_child(close_btn)
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(920, 900))


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
		CombatLog.add("Targeting cancelled.")
		_targeting_spell = ""
		return
	# Refuse if target isn't visible — wall-blocked (no LOS) or outside
	# FOV. Refund nothing; the spell didn't actually fire.
	if dmap != null and not dmap.is_tile_visible(target_monster.grid_pos):
		CombatLog.add("Your line of sight is blocked.")
		_targeting_spell = ""
		return
	# Range check: spell's max range from the registry.
	var info_for_range: Dictionary = SpellRegistry.get_spell(_targeting_spell)
	var max_range: int = int(info_for_range.get("range", 99))
	var d: int = max(abs(pos.x - player.grid_pos.x), abs(pos.y - player.grid_pos.y))
	if d > max_range:
		CombatLog.add("Target is out of range (%d > %d)." % [d, max_range])
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
	CombatLog.add("Target a tile to cast %s. Tap empty space to cancel." % String(info.get("name", _targeting_spell)))


func _execute_targeted_cast(spell_id: String, target: Monster) -> void:
	if player == null:
		return
	# Route every cast through SpellCast (DCSS spl-cast.cc port): it owns
	# silence/confusion/MP validation, pays MP up front, rolls failure,
	# and returns the resolved power. Effect dispatch stays here because
	# it needs the scene tree + SpellFX nodes.
	var ctx: Dictionary = {
		"tree": get_tree(),
		"dmap": $DungeonLayer/DungeonMap,
		"spellpower_fn": Callable(self, "_apply_racial_spellpower"),
	}
	var result: Dictionary = SpellCast.cast(player, spell_id, target, ctx)
	var fx_layer: Node2D = $EntityLayer
	var spret: int = int(result.get("spret", SpellCast.SPRET_ABORT))
	if spret == SpellCast.SPRET_ABORT:
		if result.get("message", "") != "":
			CombatLog.add(result["message"])
		return
	if spret == SpellCast.SPRET_FAIL:
		CombatLog.add(result.get("message", "Spell fizzles!"))
		SpellFX.cast_fizzle(fx_layer, player.position, \
				result.get("school", ""), result.get("spell_color", Color.WHITE))
		TurnManager.end_player_turn()
		return
	var info: Dictionary = result.get("info", SpellRegistry.get_spell(spell_id))
	var power: int = int(result.get("power", 0))
	var spell_color: Color = result.get("spell_color", Color.WHITE)
	var school: String = String(result.get("school", "spellcasting"))
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
			var dmg: int = _spell_roll_dmg(spell_id, info, power)
			if dist > 0:
				dmg = max(1, dmg - dist * 3)
			hit_positions.append(m.position)
			m.take_damage(dmg, SpellRegistry.element_for(spell_id))
			total_dmg += dmg
			hits += 1
		SpellFX.cast_area(fx_layer, player.position, target.position, hit_positions, spell_color, float(radius) * float(TILE_SIZE) + float(TILE_SIZE) / 2.0, school)
		CombatLog.add("%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg])
	else:
		var effect_type: String = String(info.get("effect", "damage"))
		if effect_type == "slow":
			target.slowed_turns = 4
			SpellFX.cast_status(fx_layer, target.position, spell_color, school, "SLOW")
			CombatLog.add("%s is slowed!" % String(target.data.display_name if target.data else "enemy"))
		else:
			# DCSS beam.cc::do_fire — trace the ray to stop at walls
			# and deal damage to every monster along the path (for
			# piercing bolts) or the first one (for darts/shots).
			var beam_range: int = int(info.get("range", 6))
			var beam_real_target: Monster = _beam_resolve_target(target, spell_id, beam_range)
			if beam_real_target == null:
				SpellFX.cast_fizzle(fx_layer, player.position, school, spell_color)
				CombatLog.add("%s splashes against the wall." % String(info.get("name", spell_id)))
			else:
				var dmg: int = _spell_roll_dmg(spell_id, info, power)
				var total_dmg: int = 0
				if Beam.should_pierce(spell_id):
					# Roll once per victim, like DCSS beams that damage
					# each cell. The beam hits every monster on the path.
					for vmon in _beam_path_hits(target, spell_id, beam_range):
						if vmon == null or not is_instance_valid(vmon):
							continue
						var vdmg: int = _spell_roll_dmg(spell_id, info, power)
						vmon.take_damage(vdmg, SpellRegistry.element_for(spell_id))
						total_dmg += vdmg
					SpellFX.cast_single(fx_layer, player.position, beam_real_target, dmg, spell_color, school)
					CombatLog.add("%s pierces for %d dmg total" % [String(info.get("name", spell_id)), total_dmg])
				else:
					beam_real_target.take_damage(dmg, SpellRegistry.element_for(spell_id))
					SpellFX.cast_single(fx_layer, player.position, beam_real_target, dmg, spell_color, school)
					CombatLog.add("%s → %d dmg" % [String(info.get("name", spell_id)), dmg])
	if skill_system != null:
		var tags: Array = SpellRegistry.get_schools(spell_id).duplicate()
		tags.append("spellcasting")
		skill_system.grant_xp(player, float(info.get("mp", 1)) * 8.0, tags)
	# Spellcasting noise: loudness scales with spell level (DCSS
	# spell-level * 2 baseline). Stealth reduces the effective radius so
	# quiet hexes don't broadcast the caster's position.
	var spell_lv: int = int(info.get("difficulty", 1))
	var stealth_lv: int = skill_system.get_level(player, "stealth") if skill_system else 0
	MonsterAI.broadcast_noise(get_tree(), player.grid_pos, spell_lv * 2 + 4, stealth_lv)
	# DCSS Trog conduct: every spell cast angers the berserker god.
	_apply_spell_piety_penalty(spell_lv)
	TurnManager.end_player_turn()


## Piety hit for casting a spell while pledged to a spell-hating god
## (Trog). Scales with spell difficulty so Lv1 cantrips barely register
## and Lv9 nukes can excommunicate in a few casts.
func _apply_spell_piety_penalty(spell_level: int) -> void:
	if player == null or player.current_god == "":
		return
	if not GodRegistry.has_conduct(player.current_god, "spells"):
		return
	var loss: int = max(1, spell_level * 2)
	player.piety = max(0, player.piety - loss)
	var god: Dictionary = GodRegistry.get_info(player.current_god)
	CombatLog.add("%s scowls at your spellcraft. (-%d piety)" % \
			[String(god.get("title", player.current_god)), loss])


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
	if result.get("message", "") != "":
		CombatLog.add(result.get("message", ""))
	if result.get("success", false):
		# Train all schools + spellcasting on successful cast (DCSS trains
		# every discipline a spell involves, split evenly).
		if skill_system != null:
			var info: Dictionary = SpellRegistry.get_spell(spell_id)
			var tags: Array = SpellRegistry.get_schools(spell_id).duplicate()
			tags.append("spellcasting")
			var xp_gain: float = float(info.get("mp", 1)) * 8.0
			skill_system.grant_xp(player, xp_gain, tags)
		TurnManager.end_player_turn()


func _execute_cast(spell_id: String) -> Dictionary:
	# Book-menu cast path. Routes through SpellCast (DCSS spl-cast.cc
	# port) for silence / confusion / MP / fail / power, then dispatches
	# the effect to _cast_*_spell helpers.
	if player == null:
		return {"success": false, "message": "No player"}
	var ctx: Dictionary = {
		"tree": get_tree(),
		"dmap": $DungeonLayer/DungeonMap,
		"spellpower_fn": Callable(self, "_apply_racial_spellpower"),
	}
	var result: Dictionary = SpellCast.cast(player, spell_id, null, ctx)
	var spret: int = int(result.get("spret", SpellCast.SPRET_ABORT))
	var info: Dictionary = result.get("info", SpellRegistry.get_spell(spell_id))
	var school: String = String(result.get("school", "spellcasting"))
	if spret == SpellCast.SPRET_ABORT:
		return {"success": false, "message": result.get("message", "")}
	if spret == SpellCast.SPRET_FAIL:
		var fx_layer_f: Node2D = $EntityLayer
		SpellFX.cast_fizzle(fx_layer_f, player.position, school, result.get("spell_color", Color.WHITE))
		return {"success": false, "message": result.get("message", "Spell fizzles.")}
	var power: int = int(result.get("power", 0))
	# SpellCast.cast resolves the target node internally; pull it out so
	# we don't run auto-picking twice.
	var resolved_target = result.get("target", null)
	var targeting: String = String(info.get("targeting", "single"))
	match targeting:
		"self":   return _cast_self_spell(spell_id, info, power)
		"single": return _cast_single_target(spell_id, info, power, resolved_target)
		"area":   return _cast_area_spell(spell_id, info, power, resolved_target)
		_:        return {"success": true, "message": "Spell fizzles."}


func _cast_single_target(spell_id: String, info: Dictionary, power: int, target: Monster = null) -> Dictionary:
	# SpellCast already resolved the target (and paid MP). Legacy callers
	# that pass null get the old auto-pick behaviour.
	if target == null:
		target = _find_nearest_visible_monster(int(info.get("range", 6)))
	if target == null:
		SpellCast.refund(player, int(info.get("mp", 1)))
		return {"success": false, "message": "No visible target in range."}
	# DCSS beam.cc::do_fire — walk the beam from caster to target so
	# walls block and monsters in the line eat the hit. Damage spells
	# get the full beam pipeline; status spells (slow/confuse) still
	# teleport-apply since DCSS treats those as single-creature hexes
	# not beams of damage.
	var effect_type_check: String = String(info.get("effect", "damage"))
	if effect_type_check == "damage" or effect_type_check == "":
		target = _beam_resolve_target(target, spell_id, int(info.get("range", 6)))
		if target == null:
			# Beam hit a wall before reaching any foe — nothing to damage.
			var fx_layer_f: Node2D = $EntityLayer
			SpellFX.cast_fizzle(fx_layer_f, player.position,
					String(info.get("school", "")), info.get("color", Color.WHITE))
			return {"success": true, "message": "%s splashes against the wall." \
					% String(info.get("name", spell_id))}

	var tname: String = ""
	if target.data != null and "display_name" in target.data:
		tname = String(target.data.display_name)
	else:
		tname = target.name

	var spell_color: Color = info.get("color", Color.WHITE)
	var school: String = String(info.get("school", ""))
	var fx_layer: Node2D = $EntityLayer
	var effect: String = String(info.get("effect", "damage"))

	if effect == "slow":
		target.slowed_turns = 4
		SpellFX.cast_status(fx_layer, target.position, spell_color, school, "SLOW")
		return {"success": true, "message": "%s is slowed for 4 turns!" % tname}
	if effect == "confuse":
		target.slowed_turns = 4
		SpellFX.cast_status(fx_layer, target.position, spell_color, school, "CONFUSE")
		return {"success": true, "message": "%s is confused for 4 turns!" % tname}
	if effect == "petrify":
		target.slowed_turns = 5
		SpellFX.cast_status(fx_layer, target.position, spell_color, school, "PETRIFY")
		return {"success": true, "message": "%s is petrified for 5 turns!" % tname}
	if effect == "agony":
		var half_hp: int = max(1, target.hp / 2)
		target.take_damage(half_hp)
		SpellFX.cast_single(fx_layer, player.position, target, half_hp, spell_color, school)
		return {"success": true, "message": "%s: HP halved! (%d dmg)" % [tname, half_hp]}
	if effect == "vampiric":
		var dmg_v: int = _spell_roll_dmg(spell_id, info, power)
		target.take_damage(dmg_v)
		player.stats.HP = min(player.stats.hp_max, player.stats.HP + dmg_v)
		player.stats_changed.emit()
		SpellFX.cast_single(fx_layer, player.position, target, dmg_v, spell_color, school)
		return {"success": true, "message": "Drained %d HP from %s!" % [dmg_v, tname]}
	if effect == "dot_fire":
		var dmg_f: int = randi_range(int(info.get("min_dmg", 1)), int(info.get("max_dmg", 3))) + power / 4
		target.take_damage(dmg_f)
		target.slowed_turns = 0
		if target.has_method("set_meta"):
			target.set_meta("burn_turns", 4)
			target.set_meta("burn_dmg", max(1, dmg_f / 2))
		SpellFX.cast_single(fx_layer, player.position, target, dmg_f, spell_color, school)
		return {"success": true, "message": "%s is burning! (%d + %d/turn)" % [tname, dmg_f, max(1, dmg_f / 2)]}

	var dmg: int = _spell_roll_dmg(spell_id, info, power)
	target.take_damage(dmg, SpellRegistry.element_for(spell_id))
	SpellFX.cast_single(fx_layer, player.position, target, dmg, spell_color, school)
	return {"success": true, "message": "%s → %s: %d dmg" % [String(info.get("name", spell_id)), tname, dmg], "damage": dmg}


func _cast_area_spell(spell_id: String, info: Dictionary, power: int, center_m: Monster = null) -> Dictionary:
	if center_m == null:
		center_m = _find_nearest_visible_monster(int(info.get("range", 8)))
	if center_m == null:
		SpellCast.refund(player, int(info.get("mp", 1)))
		return {"success": false, "message": "No visible target in range."}

	var center: Vector2i = center_m.grid_pos
	var center_px: Vector2 = center_m.position
	var radius: int = int(info.get("radius", 2))
	var spell_color: Color = info.get("color", Color.WHITE)
	var school: String = String(info.get("school", ""))
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
		var dmg: int = _spell_roll_dmg(spell_id, info, power)
		if dist > 0:
			dmg = max(1, dmg - dist * 3)
		hit_positions.append(m.position)
		m.take_damage(dmg, SpellRegistry.element_for(spell_id))
		total_dmg += dmg
		hits += 1

	var tile_r_px: float = float(radius) * float(TILE_SIZE) + float(TILE_SIZE) / 2.0
	SpellFX.cast_area(fx_layer, player.position, center_px, hit_positions, spell_color, tile_r_px, school)
	SpellFX.float_text(fx_layer, center_px + Vector2(0, -24),
			"%d dmg" % total_dmg, spell_color)

	if hits == 0:
		return {"success": true, "message": "%s hits nothing." % String(info.get("name", spell_id))}
	return {"success": true, "message": "%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg]}


func _cast_self_spell(spell_id: String, _info: Dictionary, _power: int) -> Dictionary:
	if spell_id == "blink":
		# Formicid stasis blocks every teleport path.
		if player != null and player.race_res != null \
				and player.race_res.racial_trait == "formicid_stasis":
			return {"success": true, "message": "Your stasis prevents the blink."}
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


## Walk the beam from player to the pre-resolved target. If the beam
## is blocked by a wall before reaching the target, or hits another
## monster first (on a non-pierce spell), redirect to whatever the
## beam actually lands on. Returns null iff the beam wall-splashed
## with no valid victim.
func _beam_resolve_target(picked: Monster, spell_id: String, range_tiles: int) -> Monster:
	if picked == null or player == null:
		return picked
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	var opaque_cb: Callable = func(cell: Vector2i) -> int:
		if dmap == null or dmap.generator == null:
			return 0
		return dmap._opaque_at(cell)
	var mon_cb: Callable = func(cell: Vector2i):
		for m in get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(m) and m is Monster and m.is_alive \
					and m.grid_pos == cell:
				return m
		return null
	var pierce: bool = Beam.should_pierce(spell_id)
	var trace: Dictionary = Beam.trace(player.grid_pos, picked.grid_pos,
			range_tiles, pierce, opaque_cb, mon_cb)
	var hits: Array = trace.get("hits", [])
	if hits.is_empty():
		return null
	# Non-pierce: the first monster on the line IS the real target,
	# not whatever the user tapped.
	if not pierce:
		return hits[0]
	# Pierce: keep the original pick (caller handles splash damage to
	# the hit list via _beam_apply_pierce_damage below if desired).
	return picked


## Return every monster struck by the beam from player to `picked`.
## Used by pierce-type spells (bolt_of_fire etc.) to enumerate victims.
## For non-pierce, callers should use _beam_resolve_target and hit a
## single monster.
func _beam_path_hits(picked: Monster, spell_id: String, range_tiles: int) -> Array:
	if picked == null or player == null:
		return []
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	var opaque_cb: Callable = func(cell: Vector2i) -> int:
		if dmap == null or dmap.generator == null:
			return 0
		return dmap._opaque_at(cell)
	var mon_cb: Callable = func(cell: Vector2i):
		for m in get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(m) and m is Monster and m.is_alive \
					and m.grid_pos == cell:
				return m
		return null
	var trace: Dictionary = Beam.trace(player.grid_pos, picked.grid_pos,
			range_tiles, true, opaque_cb, mon_cb)
	return trace.get("hits", [])


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
	for cat in _BAG_CATEGORIES:
		var tab_btn := Button.new()
		tab_btn.text = cat.to_upper()
		tab_btn.custom_minimum_size = Vector2(0, 48)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 40)
		if cat == _bag_category:
			# Active tab — brighter so the user sees the current filter.
			tab_btn.modulate = Color(1.0, 1.0, 0.75)
			tab_btn.disabled = true
		tab_btn.pressed.connect(func():
			_bag_category = cat
			_bag_dlg = null
			dlg.queue_free()
			_on_bag_pressed())
		cat_tabs.add_child(tab_btn)
	vb.add_child(cat_tabs)

	# Horizontal swipe cycles tabs (mobile UX).
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.gui_input.connect(_on_bag_swipe_input)

	_build_equipped_section(vb)

	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 20
	scroll.custom_minimum_size = Vector2(0, 1300)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	scroll.add_child(rows)

	var all_items: Array = player.get_items() if player != null else []
	# Build filtered view while keeping the original inventory index paired
	# with each row — equip/use/drop handlers all take the player-inventory
	# index, not the filtered position.
	var visible: Array = []  # Array of {orig: int, item: Dictionary}
	for orig_i in range(all_items.size()):
		var it_d: Dictionary = all_items[orig_i]
		if _bag_category == "all" or String(it_d.get("kind", "")) == _bag_category:
			visible.append({"orig": orig_i, "item": it_d})
	if visible.is_empty():
		var empty := Label.new()
		if all_items.is_empty():
			empty.text = "Inventory is empty."
		else:
			empty.text = "No %s." % _bag_category
		empty.add_theme_font_size_override("font_size", 40)
		rows.add_child(empty)
	else:
		# Group identical items together so the list shows "Potion x3"
		# instead of three rows. Key off (id, cursed) so a cursed and a
		# clean copy stay separate. Preserves first-seen order.
		var groups: Array = []                # ordered list of group dicts
		var group_idx: Dictionary = {}        # key → index into `groups`
		for entry_v in visible:
			var entry: Dictionary = entry_v
			var it_g: Dictionary = entry["item"]
			var key: String = "%s|%d" % [
				String(it_g.get("id", "")),
				1 if bool(it_g.get("cursed", false)) else 0,
			]
			if not group_idx.has(key):
				group_idx[key] = groups.size()
				groups.append({"first_orig": int(entry["orig"]),
						"item": it_g, "count": 1})
			else:
				groups[group_idx[key]]["count"] = int(groups[group_idx[key]]["count"]) + 1
		for g_v in groups:
			var g: Dictionary = g_v
			var i: int = int(g["first_orig"])
			var it: Dictionary = g["item"]
			var count: int = int(g["count"])
			var kind: String = String(it.get("kind", ""))
			var row := HBoxContainer.new()
			row.custom_minimum_size = Vector2(0, 80)
			row.add_theme_constant_override("separation", 8)
			var iid_row: String = String(it.get("id", ""))
			var icon_node: Control = _build_bag_item_thumbnail(iid_row, kind)
			if icon_node != null:
				row.add_child(icon_node)
			var info_btn := Button.new()
			var disp_name: String = GameManager.display_name_for_item(
					iid_row, String(it.get("name", "?")), kind)
			var plus_amt: int = int(it.get("plus", 0))
			if plus_amt > 0:
				disp_name = "%s +%d" % [disp_name, plus_amt]
			if count > 1:
				disp_name = "%s  ×%d" % [disp_name, count]
			info_btn.text = disp_name
			info_btn.flat = true
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			info_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_btn.add_theme_font_size_override("font_size", 40)
			info_btn.pressed.connect(_on_bag_info.bind(it))
			row.add_child(info_btn)
			if kind == "weapon" or kind == "armor" or kind == "ring":
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
	_bag_category = category if category != "" else "all"
	if _bag_dlg != null and is_instance_valid(_bag_dlg):
		_bag_dlg.queue_free()
		_bag_dlg = null
	_on_bag_pressed()


## Horizontal-swipe detector for the bag dialog. Left swipe → next tab,
## right swipe → previous. Press start is recorded in `_bag_swipe_start_*`
## so this plays nicely with ScrollContainer's own vertical drag.
func _on_bag_swipe_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_bag_swipe_start_x = st.position.x
			_bag_swipe_start_y = st.position.y
		else:
			_try_bag_swipe(st.position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_bag_swipe_start_x = mb.position.x
			_bag_swipe_start_y = mb.position.y
		else:
			_try_bag_swipe(mb.position)


func _try_bag_swipe(end_pos: Vector2) -> void:
	if _bag_swipe_start_x < 0:
		return
	var dx: float = end_pos.x - _bag_swipe_start_x
	var dy: float = end_pos.y - _bag_swipe_start_y
	_bag_swipe_start_x = -1.0
	_bag_swipe_start_y = -1.0
	# Need a clear horizontal intent: |dx| > 120px and |dx| > 1.5*|dy|.
	if abs(dx) < 120.0 or abs(dx) < abs(dy) * 1.5:
		return
	var step: int = -1 if dx > 0 else 1  # right-swipe → prev; left → next
	_shift_bag_category(step)


func _shift_bag_category(step: int) -> void:
	var idx: int = _BAG_CATEGORIES.find(_bag_category)
	if idx < 0:
		idx = 0
	var next_idx: int = (idx + step + _BAG_CATEGORIES.size()) % _BAG_CATEGORIES.size()
	_open_bag_filtered(String(_BAG_CATEGORIES[next_idx]))


## Skill dialog swipe handler — identical shape to _on_bag_swipe_input.
func _on_skills_swipe_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_skills_swipe_start_x = st.position.x
			_skills_swipe_start_y = st.position.y
		else:
			_try_skills_swipe(st.position)
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_skills_swipe_start_x = mb.position.x
			_skills_swipe_start_y = mb.position.y
		else:
			_try_skills_swipe(mb.position)


func _try_skills_swipe(end_pos: Vector2) -> void:
	if _skills_swipe_start_x < 0:
		return
	var dx: float = end_pos.x - _skills_swipe_start_x
	var dy: float = end_pos.y - _skills_swipe_start_y
	_skills_swipe_start_x = -1.0
	_skills_swipe_start_y = -1.0
	if abs(dx) < 120.0 or abs(dx) < abs(dy) * 1.5:
		return
	var step: int = -1 if dx > 0 else 1
	var idx: int = _SKILL_CATEGORIES.find(_skills_swipe_category)
	if idx < 0:
		idx = 0
	var next_idx: int = (idx + step + _SKILL_CATEGORIES.size()) % _SKILL_CATEGORIES.size()
	var dlg: AcceptDialog = _skills_swipe_dlg
	if dlg == null or not is_instance_valid(dlg):
		return
	dlg.queue_free()
	_skills_dlg = null
	_open_skills_dialog(String(_SKILL_CATEGORIES[next_idx]))


## Render the "Equipped" block at the top of the bag. Shows the current
## weapon + every armor slot the player has filled, with icon + name.
## Silently renders nothing if the player has nothing equipped.
func _build_equipped_section(vb: VBoxContainer) -> void:
	if player == null:
		return
	var has_any: bool = false
	if player.equipped_weapon_id != "":
		has_any = true
	if not has_any and player.equipped_armor is Dictionary and not player.equipped_armor.is_empty():
		has_any = true
	if not has_any:
		return

	var header := Label.new()
	header.text = "Equipped"
	header.add_theme_font_size_override("font_size", 32)
	header.modulate = Color(0.85, 0.85, 0.7)
	vb.add_child(header)

	# Weapon row
	if player.equipped_weapon_id != "":
		var wid: String = player.equipped_weapon_id
		var wname: String = WeaponRegistry.display_name_for(wid)
		if player.equipped_weapon_plus > 0:
			wname = "%s +%d" % [wname, player.equipped_weapon_plus]
		if player.equipped_weapon_cursed:
			wname += "  (cursed)"
		var winfo: Dictionary = {"id": wid, "name": wname, "kind": "weapon",
				"plus": player.equipped_weapon_plus}
		_append_equipped_row(vb, "weapon", wname, TileRenderer.item(wid), winfo)

	# Armor rows — stable slot order, cloak sits after chest.
	var armor_slots: Array = ["chest", "cloak", "legs", "helm", "gloves", "boots"]
	for slot in armor_slots:
		if not player.equipped_armor.has(slot):
			continue
		var a: Dictionary = player.equipped_armor[slot]
		var aid: String = String(a.get("id", ""))
		var aname: String = String(a.get("name", aid))
		var ap: int = int(a.get("plus", 0))
		if ap > 0:
			aname = "%s +%d" % [aname, ap]
		if bool(a.get("cursed", false)):
			aname += "  (cursed)"
		var ainfo: Dictionary = a.duplicate()
		ainfo["id"] = aid
		ainfo["name"] = aname
		ainfo["kind"] = "armor"
		_append_equipped_row(vb, slot, aname, TileRenderer.item(aid), ainfo)

	# Ring rows — one per slot so octopodes' eight show cleanly.
	if player.equipped_rings is Array:
		for i in player.equipped_rings.size():
			var ring: Dictionary = player.equipped_rings[i] if typeof(player.equipped_rings[i]) == TYPE_DICTIONARY else {}
			if ring.is_empty():
				continue
			var rid: String = String(ring.get("id", ""))
			var rname: String = String(ring.get("name", rid))
			var rinfo: Dictionary = ring.duplicate()
			rinfo["id"] = rid
			rinfo["name"] = rname
			rinfo["kind"] = "ring"
			_append_equipped_row(vb, "ring %d" % (i + 1), rname, TileRenderer.item(rid), rinfo)

	var sep := HSeparator.new()
	vb.add_child(sep)


func _append_equipped_row(vb: VBoxContainer, slot: String, display: String,
		tex: Texture2D, item_dict: Dictionary = {}) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override("separation", 8)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(40, 40)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var slot_label := Label.new()
	slot_label.text = slot.capitalize() + ":"
	slot_label.add_theme_font_size_override("font_size", 28)
	slot_label.custom_minimum_size = Vector2(160, 0)
	slot_label.modulate = Color(0.7, 0.7, 0.7)
	row.add_child(slot_label)
	# Name is now a flat button so a tap opens the standard item info
	# popup — same flow as tapping an unequipped item in the list.
	var name_btn := Button.new()
	name_btn.text = display
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.add_theme_font_size_override("font_size", 32)
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not item_dict.is_empty():
		name_btn.pressed.connect(_on_bag_info.bind(item_dict))
	row.add_child(name_btn)
	vb.add_child(row)


## Build a multi-line tooltip string comparing this item to what the
## player currently has equipped in the same slot. Covers every kind
## the game ships so ring/wand/book/talisman/evocable descriptions
## surface the real mechanical data (DPS, charges, form stats, …).
func _build_item_tooltip(it: Dictionary) -> String:
	var kind: String = String(it.get("kind", ""))
	var id: String = String(it.get("id", ""))
	var raw_name: String = String(it.get("name", WeaponRegistry.display_name_for(id)))
	var name_s: String = GameManager.display_name_for_item(id, raw_name, kind)
	match kind:
		"weapon":   return _tooltip_weapon(id, name_s, it)
		"armor":    return _tooltip_armor(id, name_s, it)
		"ring":     return _tooltip_ring(id, name_s, it)
		"potion":   return _tooltip_consumable(id, name_s, "potion")
		"scroll":   return _tooltip_consumable(id, name_s, "scroll")
		"book":     return _tooltip_book(id, name_s, it)
		"wand":     return _tooltip_wand(id, name_s, it)
		"talisman": return _tooltip_talisman(id, name_s, it)
		"evocable": return _tooltip_evocable(id, name_s, it)
		"gold":     return "%d gold coins." % int(it.get("gold", 0))
		_:          return "%s\nMiscellaneous junk." % name_s


func _tooltip_weapon(id: String, name_s: String, it: Dictionary) -> String:
	var new_dmg: int = WeaponRegistry.weapon_damage_for(id)
	var new_delay: float = WeaponRegistry.weapon_delay_for(id)
	var new_skill: String = WeaponRegistry.weapon_skill_for(id)
	var plus: int = int(it.get("plus", 0))
	var total_dmg: int = new_dmg + plus
	var cur_id: String = player.equipped_weapon_id if player else ""
	var cur_dmg: int = WeaponRegistry.weapon_damage_for(cur_id) \
			+ (int(player.equipped_weapon_plus) if player and cur_id != "" else 0)
	var cur_delay: float = WeaponRegistry.weapon_delay_for(cur_id)
	var cur_name: String = WeaponRegistry.display_name_for(cur_id) if cur_id != "" else "unarmed"
	var new_dps: float = float(total_dmg) / max(new_delay, 0.1)
	var cur_dps: float = float(cur_dmg) / max(cur_delay, 0.1)
	var diff_dmg: int = total_dmg - cur_dmg
	var diff_dps: float = new_dps - cur_dps
	var lines: Array = [name_s]
	if plus != 0:
		lines.append("Enchant: +%d" % plus)
	lines.append("Damage: %d  (%s%d vs %s)" % [
			total_dmg, ("+" if diff_dmg >= 0 else ""), diff_dmg, cur_name])
	lines.append("Delay: %.2f  (cur %.2f — lower is faster)" % [new_delay, cur_delay])
	lines.append("DPS: %.1f  (%s%.1f)" % [
			new_dps, ("+" if diff_dps >= 0 else ""), diff_dps])
	lines.append("Trains: %s" % new_skill.replace("_", " "))
	var staff_school: String = WeaponRegistry.staff_spell_school(id)
	if staff_school != "":
		lines.append("Magical staff: +%d spell power to %s school" % [
				WeaponRegistry.staff_spell_bonus(id), staff_school])
	if bool(it.get("cursed", false)):
		lines.append("[color=#c55]*** Cursed *** — you cannot unequip it.[/color]")
	return "\n".join(PackedStringArray(lines))


func _tooltip_armor(id: String, name_s: String, it: Dictionary) -> String:
	var new_ac: int = int(it.get("ac", 0))
	var slot: String = String(it.get("slot", ArmorRegistry.slot_for(id)))
	var ev_penalty: int = ArmorRegistry.ev_penalty_for(id)
	var cur: Dictionary = {}
	if player != null and player.equipped_armor.has(slot):
		cur = player.equipped_armor[slot]
	var cur_ac: int = int(cur.get("ac", 0))
	var cur_name: String = String(cur.get("name", "(empty)"))
	var diff_ac: int = new_ac - cur_ac
	var lines: Array = [name_s, "Slot: %s" % slot]
	lines.append("AC: +%d  (%s%d vs %s)" % [
			new_ac, ("+" if diff_ac >= 0 else ""), diff_ac, cur_name])
	if ev_penalty < 0:
		# ArmorRegistry stores raw PARM_EVASION (negative). `-40` = -4 EV,
		# `-180` = -18 EV. Also slows spellcasting via encumbrance.
		lines.append("EV penalty: %d  (heavier armour → worse dodge + spells)" \
				% (ev_penalty / 10))
	if bool(it.get("cursed", false)):
		lines.append("[color=#c55]*** Cursed *** — you cannot remove it.[/color]")
	return "\n".join(PackedStringArray(lines))


func _tooltip_ring(id: String, name_s: String, it: Dictionary) -> String:
	var info: Dictionary = RingRegistry.get_info(id)
	if info.is_empty():
		return "%s\nA small band of unknown metal." % name_s
	var lines: Array = [name_s, "Slot: ring"]
	# Pretty-print every effect field present.
	var pairs: Array = [
		["str",         "STR +%d"],
		["dex",         "DEX +%d"],
		["int_",        "INT +%d"],
		["ac",          "AC +%d"],
		["ev",          "EV +%d"],
		["mp_max",      "Max MP +%d"],
		["dmg_bonus",   "Melee damage +%d"],
		["spell_power", "Spell power +%d"],
		["regen",       "HP regen +%d / turn"],
		["stealth",     "Stealth +%d"],
		["fire_apt",    "Fire aptitude +%d (spells + resist)"],
		["cold_apt",    "Cold aptitude +%d (spells + resist)"],
	]
	for p in pairs:
		var key: String = p[0]
		var fmt: String = p[1]
		if info.has(key) and int(info[key]) != 0:
			lines.append(fmt % int(info[key]))
	# Stacking hint: shows how many rings we already wear.
	if player != null:
		var worn: int = player.equipped_rings.size() if "equipped_rings" in player else 0
		var cap: int = 8 if player.race_res and player.race_res.racial_trait == "octopode_rings" else 2
		lines.append("Worn: %d / %d rings" % [worn, cap])
	return "\n".join(PackedStringArray(lines))


func _tooltip_consumable(id: String, name_s: String, kind: String) -> String:
	var desc: String = ""
	if GameManager.is_identified(id):
		desc = ConsumableRegistry.description_for(id)
	if desc == "":
		desc = ("Drink to find out." if kind == "potion" else "Read aloud to find out.")
	return "%s\n%s" % [name_s, desc]


func _tooltip_book(id: String, name_s: String, _it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var spells: Array = info.get("spells", [])
	var lines: Array = [name_s]
	if spells.is_empty():
		lines.append("Teaches nothing you can learn.")
	else:
		lines.append("Spells taught:")
		for sid in spells:
			var sid_s: String = String(sid)
			var spell_info: Dictionary = SpellRegistry.get_spell(sid_s)
			var sp_name: String = String(spell_info.get("name", sid_s.replace("_", " ").capitalize()))
			var lv: int = int(spell_info.get("difficulty", 1))
			var known: bool = player != null and player.learned_spells.has(sid_s)
			var marker: String = " (known)" if known else ""
			lines.append("  • %s  [Lv.%d]%s" % [sp_name, lv, marker])
	return "\n".join(PackedStringArray(lines))


func _tooltip_wand(id: String, name_s: String, it: Dictionary) -> String:
	var info: Dictionary = WandRegistry.get_info(id)
	if info.is_empty():
		return "%s\nA thin rod of unknown craft." % name_s
	var charges: int = int(it.get("charges", 0))
	var spell_id: String = String(info.get("spell", ""))
	var sp_name: String = spell_id.replace("_", " ").capitalize()
	if spell_id != "":
		var sp_info: Dictionary = SpellRegistry.get_spell(spell_id)
		if not sp_info.is_empty():
			sp_name = String(sp_info.get("name", sp_name))
	var evo: int = 0
	if player != null and player.skill_state.has("evocations"):
		evo = int(player.skill_state["evocations"].get("level", 0))
	var eff_power: int = 15 + evo * 7
	var lines: Array = [name_s, "Charges: %d" % charges]
	lines.append("Effect: %s" % sp_name)
	lines.append("Evocation power: %d  (Evocations Lv.%d)" % [eff_power, evo])
	lines.append(String(info.get("desc", "")))
	return "\n".join(PackedStringArray(lines))


func _tooltip_talisman(id: String, name_s: String, _it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var form_id: String = String(info.get("form", id.replace("talisman_", "")))
	var form: Dictionary = FormRegistry.get_info(form_id)
	var lines: Array = [name_s]
	lines.append(String(info.get("desc", "")))
	if form.is_empty():
		return "\n".join(PackedStringArray(lines))
	var hp_mod: int = int(form.get("hp_mod", 100))
	if hp_mod != 100:
		lines.append("HP: %d%% of normal" % hp_mod)
	if int(form.get("str_delta", 0)) != 0:
		lines.append("STR %+d" % int(form.get("str_delta", 0)))
	if int(form.get("dex_delta", 0)) != 0:
		lines.append("DEX %+d" % int(form.get("dex_delta", 0)))
	if int(form.get("ac_base", 0)) != 0:
		lines.append("AC +%d  (+%d per 10 skill)" % [
				int(form.get("ac_base", 0)), int(form.get("ac_scaling", 0))])
	if int(form.get("unarmed_base", 0)) > 0:
		lines.append("Unarmed attack: %d base  (+%d per 10 skill)" % [
				int(form.get("unarmed_base", 0)), int(form.get("unarmed_scaling", 0))])
	var resists: Dictionary = form.get("resists", {})
	if not resists.is_empty():
		var parts: Array = []
		for r in resists.keys():
			parts.append("r%s+%d" % [String(r), int(resists[r])])
		lines.append("Resists: %s" % ", ".join(parts))
	var flags: Array = []
	if bool(form.get("can_fly", false)):
		flags.append("fly")
	if bool(form.get("can_swim", false)):
		flags.append("swim")
	if not flags.is_empty():
		lines.append("Movement: %s" % ", ".join(flags))
	if player != null and player.current_form == form_id:
		lines.append("[color=#8dd]Currently active — evoke again to revert.[/color]")
	return "\n".join(PackedStringArray(lines))


func _tooltip_evocable(id: String, name_s: String, it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var charges: int = int(it.get("charges", 0))
	var lines: Array = [name_s, "Charges: %d" % charges]
	lines.append(String(info.get("desc", "Activate to release its power.")))
	return "\n".join(PackedStringArray(lines))


## Compose a bag thumbnail. For potions/scrolls the base-colour tile is
## the bottom layer; the effect icon stacks on top once identified. For
## everything else the identified item texture is shown directly.
## Returns null when no texture is available.
func _build_bag_item_thumbnail(iid: String, kind: String) -> Control:
	var icon_size: Vector2 = Vector2(64, 64)
	var is_consumable: bool = (kind == "potion" or kind == "scroll")
	if is_consumable:
		var stack := Control.new()
		stack.custom_minimum_size = icon_size
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var base_tex: Texture2D = TileRenderer.consumable_base(iid, kind)
		if base_tex != null:
			var base_rect := TextureRect.new()
			base_rect.texture = base_tex
			base_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			base_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			base_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
			base_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			base_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stack.add_child(base_rect)
		if GameManager != null and GameManager.is_identified(iid):
			var overlay: Texture2D = TileRenderer.item(iid)
			if overlay != null:
				var over_rect := TextureRect.new()
				over_rect.texture = overlay
				over_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				over_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
				over_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
				over_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				over_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
				stack.add_child(over_rect)
		return stack
	var tex: Texture2D = TileRenderer.item(iid)
	if tex == null:
		return null
	var icon := TextureRect.new()
	icon.texture = tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.custom_minimum_size = icon_size
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _on_bag_info(it: Dictionary) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return
	_close_all_dialogs()
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = String(it.get("name", "Item"))
	# Hide AcceptDialog's built-in OK footer — we ship our own Close
	# button that's easier to hit on a tall mobile screen.
	dlg.ok_button_text = ""
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dlg.add_child(vb)
	# Scroll the tooltip so a long description doesn't balloon the
	# dialog out to the full viewport height (which was pushing the
	# text to the top of the screen).
	var scroll := ScrollContainer.new()
	scroll.scroll_deadzone = 20
	scroll.custom_minimum_size = Vector2(860, 700)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(scroll)
	var lab := Label.new()
	lab.text = _build_item_tooltip(it)
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lab)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.add_theme_font_size_override("font_size", 44)
	close_btn.custom_minimum_size = Vector2(0, 96)
	close_btn.pressed.connect(dlg.queue_free)
	vb.add_child(close_btn)
	popup_mgr.add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	# Fixed compact size, centred. popup_centered sets the window size
	# exactly to this Vector2i so the dialog sits in the middle of the
	# viewport regardless of content length.
	dlg.popup_centered(Vector2i(920, 900))


func _on_bag_use(idx: int, dlg: AcceptDialog) -> void:
	_suppress_bag_reopen = false
	if player != null:
		player.use_item(idx)
	_bag_dlg = null  # Clear BEFORE reopening so toggle check doesn't see stale ref.
	dlg.queue_free()
	if not _suppress_bag_reopen:
		_on_bag_pressed()
	_suppress_bag_reopen = false


func _on_bag_equip(idx: int, dlg: AcceptDialog) -> void:
	if player != null:
		var items: Array = player.get_items()
		if idx >= 0 and idx < items.size():
			var it: Dictionary = items[idx]
			var kind: String = String(it.get("kind", ""))
			items.remove_at(idx)
			if kind == "weapon":
				var wid: String = String(it.get("id", ""))
				var new_plus: int = int(it.get("plus", 0))
				var prev_id: String = player.equipped_weapon_id
				var prev_plus: int = player.equipped_weapon_plus
				var returned_id: String = player.equip_weapon(wid, new_plus)
				if returned_id == wid:
					# equip_weapon returned same id → was blocked (cursed).
					items.insert(idx, it)
				else:
					if bool(it.get("cursed", false)):
						player.equipped_weapon_cursed = true
						CombatLog.add("The %s is cursed!" % WeaponRegistry.display_name_for(wid))
					if prev_id != "":
						items.append({
							"id": prev_id,
							"name": WeaponRegistry.display_name_for(prev_id),
							"kind": "weapon",
							"plus": prev_plus,
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
				if bool(it.get("cursed", false)):
					armor_info["cursed"] = true
				# Carry the enchant level over onto the armor slot dict
				# so the equipped AC calc sees it.
				armor_info["plus"] = int(it.get("plus", 0))
				var prev_armor: Dictionary = player.equip_armor(armor_info)
				if bool(it.get("cursed", false)):
					CombatLog.add("The %s is cursed!" % String(armor_info.get("name", aid)))
				if not prev_armor.is_empty():
					items.append({
						"id": String(prev_armor.get("id", "")),
						"name": String(prev_armor.get("name", "")),
						"kind": "armor",
						"ac": int(prev_armor.get("ac", 0)),
						"plus": int(prev_armor.get("plus", 0)),
						"slot": String(prev_armor.get("slot", "chest")),
						"color": prev_armor.get("color", Color(0.6, 0.6, 0.7)),
					})
			elif kind == "ring":
				var rid: String = String(it.get("id", ""))
				var ring_info: Dictionary = RingRegistry.get_info(rid)
				if ring_info.is_empty():
					ring_info = {
						"id": rid,
						"name": String(it.get("name", rid)),
						"slot": "ring",
						"kind": "ring",
						"color": it.get("color", Color(0.85, 0.85, 0.90)),
					}
				# Slot-0 replacement by default; we'll add a proper picker later.
				var prev_ring: Dictionary = player.equip_ring(ring_info)
				CombatLog.add("You slip on the %s." % String(ring_info.get("name", rid)))
				if not prev_ring.is_empty():
					prev_ring["kind"] = "ring"
					items.append(prev_ring)
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

	var scroll := ScrollContainer.new(); scroll.scroll_deadzone = 20
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(920, 1500)
	dlg.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 20)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	_status_build_header(vb)
	_status_build_vitals(vb)
	_status_build_piety(vb)
	_status_build_attributes(vb)
	_status_build_combat(vb)
	_status_build_equipment(vb)
	_status_build_rings(vb)
	_status_build_resistances(vb)
	_status_build_trait(vb)

	# Essence slots retained — each row handles its own cast/swap buttons.
	if essence_system != null and essence_system.slots.size() > 0:
		vb.add_child(_status_section_header("Essences"))
		for i in essence_system.slots.size():
			vb.add_child(_build_essence_row(i, dlg))

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
	dlg.popup_centered(Vector2i(960, 1800))


# ---- Status sections -----------------------------------------------------

func _status_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	# Bumped from 40 → 52 per user "상태창에 글씨를 전체적으로 좀 크게" —
	# section headers anchor each card, so they take the biggest lift.
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.40))
	return lbl


## Piety card — shows current god portrait, piety bar, and per-kill
## gain. Rendered just below the vital bars so a new pledge is
## visible without scrolling. Absent if the player hasn't pledged.
func _status_build_piety(vb: VBoxContainer) -> void:
	if player == null or player.current_god == "":
		return
	var info: Dictionary = GodRegistry.get_info(player.current_god)
	if info.is_empty():
		return
	vb.add_child(_status_section_header("Faith"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var name_lbl := Label.new()
	name_lbl.text = String(info.get("title", player.current_god))
	name_lbl.custom_minimum_size = Vector2(360, 0)
	name_lbl.add_theme_font_size_override("font_size", 42)
	name_lbl.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	row.add_child(name_lbl)
	var cap: int = int(info.get("piety_cap", 200))
	var bar := ProgressBar.new()
	bar.max_value = maxi(1, cap)
	bar.value = int(player.piety)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 56)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := StyleBoxFlat.new()
	fill.bg_color = info.get("color", Color(0.85, 0.70, 0.30))
	for c in ["corner_radius_top_left", "corner_radius_top_right",
			"corner_radius_bottom_left", "corner_radius_bottom_right"]:
		fill.set(c, 4)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var val_lbl := Label.new()
	val_lbl.text = "%d / %d" % [int(player.piety), cap]
	val_lbl.add_theme_font_size_override("font_size", 40)
	val_lbl.custom_minimum_size = Vector2(240, 0)
	row.add_child(val_lbl)
	vb.add_child(row)
	# "+N piety per kill" hint so the player knows if their god is a
	# kill-piety god or a gold/sacrifice-piety god.
	var hint := Label.new()
	hint.text = "+%d piety per kill" % int(info.get("kill_piety", 0))
	hint.add_theme_font_size_override("font_size", 34)
	hint.modulate = Color(0.78, 0.78, 0.85)
	vb.add_child(hint)


## Title row: doll portrait + race/job line + level/XP/turn.
func _status_build_header(vb: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)

	# Paper-doll portrait using current equipment.
	var armor_map: Dictionary = {}
	for slot in player.equipped_armor.keys():
		armor_map[slot] = String(player.equipped_armor[slot].get("id", ""))
	var portrait_tex: Texture2D = TileRenderer.compose_doll(
			player.race_id if player.race_id != "" else player.job_id,
			player.equipped_weapon_id, armor_map)
	if portrait_tex != null:
		var portrait := TextureRect.new()
		portrait.texture = portrait_tex
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(160, 160)
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		header.add_child(portrait)

	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(text_col)

	var race_name: String = player.race_res.display_name if player.race_res else "?"
	var job_name: String = player.job_res.display_name if player.job_res else "?"
	var name_lbl := Label.new()
	name_lbl.text = "%s %s" % [race_name, job_name]
	name_lbl.add_theme_font_size_override("font_size", 56)
	text_col.add_child(name_lbl)

	var meta_lbl := Label.new()
	meta_lbl.text = "Lv.%d   XP %d / %d   Turn %d" % [
		player.level, player.xp, player.xp_for_next_level(),
		TurnManager.turn_number]
	meta_lbl.add_theme_font_size_override("font_size", 40)
	meta_lbl.modulate = Color(0.85, 0.85, 0.95)
	text_col.add_child(meta_lbl)

	vb.add_child(header)


## HP / MP progress bars with "current / max" overlaid text.
func _status_build_vitals(vb: VBoxContainer) -> void:
	var s = player.stats
	if s == null:
		return
	vb.add_child(_status_vital_bar("HP", s.HP, s.hp_max,
			Color(0.85, 0.15, 0.15), Color(0.30, 0.05, 0.05)))
	vb.add_child(_status_vital_bar("MP", s.MP, s.mp_max,
			Color(0.25, 0.45, 0.95), Color(0.05, 0.10, 0.30)))
	# Per-turn regen readout. DCSS accumulator: `rate` points per turn,
	# 100 points = +1 HP/MP. Display as the fractional HP/MP per turn so
	# the user can see the exact flow rate.
	var hp_rate: int = 20 + s.hp_max / 6
	var mp_rate: int = 7 + s.mp_max / 2
	var regen_lbl := Label.new()
	regen_lbl.text = "Regen  HP %.2f/turn   MP %.2f/turn" \
			% [float(hp_rate) / 100.0, float(mp_rate) / 100.0]
	regen_lbl.add_theme_font_size_override("font_size", 40)
	regen_lbl.modulate = Color(0.78, 0.78, 0.85)
	vb.add_child(regen_lbl)


func _status_vital_bar(label: String, cur: int, maxv: int,
		fill: Color, bg: Color) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.add_theme_constant_override("separation", 16)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.custom_minimum_size = Vector2(80, 0)
	name_lbl.add_theme_font_size_override("font_size", 48)
	row.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.max_value = max(1, maxv)
	bar.value = cur
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 56)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill
	fill_style.corner_radius_top_left = 4
	fill_style.corner_radius_top_right = 4
	fill_style.corner_radius_bottom_left = 4
	fill_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = bg
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("background", bg_style)
	row.add_child(bar)
	var val_lbl := Label.new()
	val_lbl.text = "%d / %d" % [cur, maxv]
	val_lbl.add_theme_font_size_override("font_size", 42)
	val_lbl.custom_minimum_size = Vector2(240, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	return row


## STR / DEX / INT row — three equal cards.
func _status_build_attributes(vb: VBoxContainer) -> void:
	var s = player.stats
	if s == null:
		return
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_status_attr_card("STR", s.STR, Color(1.00, 0.55, 0.35)))
	h.add_child(_status_attr_card("DEX", s.DEX, Color(0.40, 1.00, 0.55)))
	h.add_child(_status_attr_card("INT", s.INT, Color(0.55, 0.70, 1.00)))
	vb.add_child(h)


func _status_attr_card(label: String, value: int, tint: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.15, tint.g * 0.15, tint.b * 0.15, 0.8)
	sb.border_color = tint
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.modulate = tint
	col.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 72)
	col.add_child(val_lbl)
	return panel


## AC / EV / ATK read-out.
func _status_build_combat(vb: VBoxContainer) -> void:
	var s = player.stats
	if s == null:
		return
	vb.add_child(_status_section_header("Combat"))
	var w_dmg: int = WeaponRegistry.weapon_damage_for(player.equipped_weapon_id)
	var str_bonus: int = s.STR / 3
	var gear_dmg: int = player.gear_damage_bonus() if player.has_method("gear_damage_bonus") else 0
	var total_atk: int = w_dmg + str_bonus + player.weapon_bonus_dmg + gear_dmg
	var ev_bonus: int = s.EV
	var dex_ev: int = s.DEX / 2
	var total_ev: int = dex_ev + ev_bonus

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_status_stat_card("AC", s.AC,
			"race %+d · armor %+d" % [
				player.race_res.base_ac if player.race_res else 0,
				s.AC - (player.race_res.base_ac if player.race_res else 0)]))
	h.add_child(_status_stat_card("EV", total_ev,
			"DEX/2 %+d · gear %+d" % [dex_ev, ev_bonus]))
	h.add_child(_status_stat_card("ATK", total_atk,
			"wpn %d · STR %+d · gear %+d" % [w_dmg, str_bonus, gear_dmg + player.weapon_bonus_dmg]))
	vb.add_child(h)


func _status_stat_card(label: String, value: int, sub: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.10, 0.14, 0.85)
	sb.border_color = Color(0.45, 0.45, 0.55)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 12)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.modulate = Color(0.75, 0.80, 0.90)
	head.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_font_size_override("font_size", 58)
	head.add_child(val_lbl)
	col.add_child(head)
	var sub_lbl := Label.new()
	sub_lbl.text = sub
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_font_size_override("font_size", 28)
	sub_lbl.modulate = Color(0.65, 0.65, 0.70)
	col.add_child(sub_lbl)
	return panel


## One row per equipment slot with icon + name + stat summary.
func _status_build_equipment(vb: VBoxContainer) -> void:
	vb.add_child(_status_section_header("Equipment"))
	# Weapon
	var w_id: String = player.equipped_weapon_id
	if w_id != "":
		var w_dmg: int = WeaponRegistry.weapon_damage_for(w_id)
		vb.add_child(_status_gear_row("Weapon",
				WeaponRegistry.display_name_for(w_id),
				"dmg %d" % w_dmg, TileRenderer.item(w_id),
				player.equipped_weapon_cursed))
	else:
		vb.add_child(_status_gear_row("Weapon", "(unarmed)", "", null, false))
	for slot in ["chest", "cloak", "legs", "boots", "helm", "gloves"]:
		if player.equipped_armor.has(slot):
			var a: Dictionary = player.equipped_armor[slot]
			var aid: String = String(a.get("id", ""))
			var bits: Array = []
			if int(a.get("ac", 0)) != 0:
				bits.append("AC +%d" % int(a.get("ac", 0)))
			if int(a.get("ev_bonus", 0)) != 0:
				bits.append("EV +%d" % int(a.get("ev_bonus", 0)))
			vb.add_child(_status_gear_row(slot.capitalize(),
					String(a.get("name", aid)),
					"  ".join(PackedStringArray(bits)),
					TileRenderer.item(aid),
					bool(a.get("cursed", false))))


func _status_gear_row(slot: String, display: String, sub: String,
		tex: Texture2D, cursed: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 68)
	row.add_theme_constant_override("separation", 12)
	if tex != null:
		var icon := TextureRect.new()
		icon.texture = tex
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2(56, 56)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
	var slot_lbl := Label.new()
	slot_lbl.text = slot
	slot_lbl.custom_minimum_size = Vector2(180, 0)
	slot_lbl.add_theme_font_size_override("font_size", 32)
	slot_lbl.modulate = Color(0.65, 0.65, 0.70)
	row.add_child(slot_lbl)
	var name_lbl := Label.new()
	name_lbl.text = display + ("  (cursed)" if cursed else "")
	name_lbl.add_theme_font_size_override("font_size", 40)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)
	if sub != "":
		var sub_lbl := Label.new()
		sub_lbl.text = sub
		sub_lbl.add_theme_font_size_override("font_size", 32)
		sub_lbl.modulate = Color(0.55, 0.85, 0.55)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(sub_lbl)
	return row


## Rings section (always shown if player has ring slots configured).
func _status_build_rings(vb: VBoxContainer) -> void:
	if not (player.equipped_rings is Array):
		return
	var cap: int = player.max_ring_slots() if player.has_method("max_ring_slots") else 2
	if cap <= 0:
		return
	vb.add_child(_status_section_header("Rings (%d / %d slots)" % [
			_count_equipped_rings(), cap]))
	for i in cap:
		var ring: Dictionary = {}
		if i < player.equipped_rings.size() and typeof(player.equipped_rings[i]) == TYPE_DICTIONARY:
			ring = player.equipped_rings[i]
		if ring.is_empty():
			vb.add_child(_status_gear_row("Ring %d" % (i + 1),
					"(empty)", "", null, false))
		else:
			var rid: String = String(ring.get("id", ""))
			vb.add_child(_status_gear_row("Ring %d" % (i + 1),
					String(ring.get("name", rid)),
					_ring_effect_summary(ring),
					TileRenderer.item(rid),
					false))


func _count_equipped_rings() -> int:
	var n: int = 0
	for ring in player.equipped_rings:
		if typeof(ring) == TYPE_DICTIONARY and not ring.is_empty():
			n += 1
	return n


func _ring_effect_summary(ring: Dictionary) -> String:
	var bits: Array = []
	for key in ["str", "dex", "int_", "ac", "ev", "mp_max",
			"dmg_bonus", "spell_power", "regen", "stealth",
			"fire_apt", "cold_apt"]:
		var v: int = int(ring.get(key, 0))
		if v == 0:
			continue
		var label: String = {
			"str": "STR", "dex": "DEX", "int_": "INT",
			"ac": "AC", "ev": "EV", "mp_max": "MP",
			"dmg_bonus": "dmg", "spell_power": "pow",
			"regen": "regen", "stealth": "Stealth",
			"fire_apt": "Fire", "cold_apt": "Cold",
		}.get(key, key)
		bits.append("%s %+d" % [label, v])
	return "  ".join(PackedStringArray(bits))


## Racial trait description block (only drawn when the player's race has one).
## Elemental resistance table — derived from the active racial trait and
## equipped gear. DCSS convention: each pip is one "level" of resistance.
## We don't yet consume these during damage resolution; the panel just
## surfaces them so the player sees what their build has.
func _status_resistances() -> Dictionary:
	var r: Dictionary = {
		"fire": 0, "cold": 0, "poison": 0, "negative": 0,
		"electric": 0, "magic": 0,
	}
	var trait_id: String = ""
	if player != null and player.race_res != null:
		trait_id = String(player.race_res.racial_trait)
	match trait_id:
		"djinni_flight":      r["fire"] += 1; r["cold"] -= 1
		"vampire_bloodfeast": r["cold"] += 1; r["negative"] += 1
		"mummy_undead":       r["cold"] += 1; r["negative"] += 1; r["poison"] += 1; r["fire"] -= 1
		"ghoul_claws":        r["cold"] += 1; r["negative"] += 2; r["poison"] += 1
		"gargoyle_stone":     r["poison"] += 1; r["negative"] += 1; r["electric"] += 1
		"naga_poison_spit":   r["poison"] += 2
		"formicid_stasis":    r["magic"] += 1
		"deep_dwarf_dr":      r["negative"] += 1
		"trollregen":         r["poison"] += 1
		"demonspawn_mutations": r["fire"] += 1
		"tengu_flight":       r["electric"] += 1
		"draconian_resist":   r["magic"] += 1
		"vine_stalker_mpregen": r["negative"] += 1; r["poison"] += 1
	# Ring-sourced contributions (current ring effects: fire_apt → fire+,
	# cold_apt → cold+, not true resistances but readable signal).
	if player != null and player.equipped_rings is Array:
		for ring in player.equipped_rings:
			if typeof(ring) != TYPE_DICTIONARY:
				continue
			if int(ring.get("fire_apt", 0)) > 0:
				r["fire"] += 1
			if int(ring.get("cold_apt", 0)) > 0:
				r["cold"] += 1
	return r


func _status_build_resistances(vb: VBoxContainer) -> void:
	var r: Dictionary = _status_resistances()
	vb.add_child(_status_section_header("Resistances"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.add_child(_status_resist_card("rF",  r["fire"],     Color(1.0, 0.50, 0.30)))
	h.add_child(_status_resist_card("rC",  r["cold"],     Color(0.50, 0.85, 1.0)))
	h.add_child(_status_resist_card("rP",  r["poison"],   Color(0.45, 0.95, 0.45)))
	h.add_child(_status_resist_card("rN",  r["negative"], Color(0.65, 0.40, 0.90)))
	h.add_child(_status_resist_card("rE",  r["electric"], Color(1.0, 0.95, 0.35)))
	h.add_child(_status_resist_card("MR",  r["magic"],    Color(0.90, 0.50, 0.90)))
	vb.add_child(h)


## Compact "rF +1" / "rC --" card.
func _status_resist_card(label: String, value: int, tint: Color) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.12, tint.g * 0.12, tint.b * 0.12, 0.8)
	sb.border_color = tint if value != 0 else Color(0.30, 0.30, 0.35)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 38)
	name_lbl.modulate = tint
	col.add_child(name_lbl)
	var val_lbl := Label.new()
	if value == 0:
		val_lbl.text = "--"
		val_lbl.modulate = Color(0.55, 0.55, 0.60)
	else:
		val_lbl.text = "+" + "+".repeat(max(1, value)) if value > 0 else "-" + "-".repeat(max(1, -value))
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.add_theme_font_size_override("font_size", 44)
	col.add_child(val_lbl)
	return panel


func _status_build_trait(vb: VBoxContainer) -> void:
	var trait_id: String = ""
	if player.race_res != null:
		trait_id = player.race_res.racial_trait
	if trait_id == "":
		return
	vb.add_child(_status_section_header("Racial Trait"))
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.15, 0.12, 0.05, 0.85)
	sb.border_color = Color(1.0, 0.85, 0.30)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = _describe_trait(trait_id)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 38)
	panel.add_child(lbl)
	vb.add_child(panel)


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
		"trollregen":            return "Troll Regeneration — recovers 2 HP every turn."
		"spriggan_speed":        return "Spriggan Speed — moves twice per enemy turn."
		"draconian_resist":      return "Draconian Scales — bonus AC (elemental resistance coming with element typing)."
		"minotaur_headbutt":     return "Minotaur Headbutt — 25% chance for +2–5 bonus melee damage."
		"catfolk_claws":         return "Catfolk Claws — +3 damage when fighting unarmed."
		"halfling_lucky":        return "Halfling Luck — 15% chance to dodge any incoming hit entirely."
		"deep_dwarf_dr":         return "Deep Dwarf Damage Reduction — incoming damage halved or −1."
		"ghoul_claws":           return "Ghoul Claws — +3 damage when fighting unarmed."
		"vine_stalker_mpregen":  return "Vine Regeneration — +1 MP per turn, +2 MP on kill."
		"vampire_bloodfeast":    return "Blood Feast — heal 3–5 HP on every kill."
		"barachi_xp_bonus":      return "Amphibious Insight — +25% XP from every kill."
		"demigod_slow_xp":       return "Demigod — godly stats, but gains only 50% XP."
		"mummy_undead":          return "Undead — no potions, 75% XP, bonus necromancy magic."
		"djinni_flight":         return "Djinni Flight — +2 EV, glides over water and lava."
		"tengu_flight":          return "Tengu Flight — +2 EV, can walk over water tiles."
		"gargoyle_stone":        return "Stone Body — +4 racial AC, immune to poison."
		"oni_magical_might":     return "Magical Might — spell power boosted by 20%."
		"formicid_stasis":       return "Formicid Stasis — cannot be teleported or blinked."
		"merfolk_swim":          return "Merfolk Swim — swims across water tiles."
		"naga_poison_spit":      return "Venomous Bite — +1 damage on every melee hit."
		"kobold_sneak":          return "Sneak — bonus melee damage scaled by Stealth skill."
		"gnoll_jack_of_trades":  return "Jack of All Trades — every skill trains at the same rate."
		"octopode_many_rings":   return "Many Arms — can wear up to 8 rings simultaneously."
		"coglin_dualwield":      return "Coglin Dual-Wield — exo-suit carries two weapons (in progress)."
		"demonspawn_mutations":  return "Demonspawn Mutations — gain random mutations as you level (in progress)."
		"meteoran_reroll":       return "Meteoran Echo — glimpses of unlived lives (in progress)."
		"deep_dwarf_dr":         return "Deep Dwarf — natural damage reduction."
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
