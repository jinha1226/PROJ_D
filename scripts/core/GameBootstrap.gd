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

const _SKILL_CATEGORIES: Array = ["active", "weapon", "defense", "magic", "misc"]
const _SKILL_CATEGORY_LABELS: Dictionary = {
	"active": "ACTIVE", "weapon": "WEAPON", "defense": "DEFENSE",
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
var _bag_dlg: GameDialog = null
var _suppress_bag_reopen: bool = false
# Active bag filter ("all" | "weapon" | "armor" | "potion" | "scroll" | "book").
# Remembered across reopens so swiping/tabbing doesn't lose the user's spot.
var _bag_category: String = "all"
# Swipe-tracking state for the current bag dialog.
var _bag_swipe_start_x: float = -1.0
var _bag_swipe_start_y: float = -1.0
const _BAG_CATEGORIES: Array = ["all", "weapon", "armor", "cloak", "ring", "amulet", "potion", "scroll", "book"]
# Swipe state for the skill dialog's category tabs — same pattern as
# _bag_swipe_* but keyed per-dialog so closing one doesn't bleed into
# the other.
var _skills_swipe_dlg: GameDialog = null
var _skills_swipe_category: String = ""
var _skills_swipe_start_x: float = -1.0
var _skills_swipe_start_y: float = -1.0
var _skills_dlg: GameDialog = null
var _status_dlg: GameDialog = null
var _map_dlg: GameDialog = null
var _magic_dlg: GameDialog = null
var _combat_log_label: Label = null
var _targeting_spell: String = ""
# Ranged-attack targeting mode — set when the player presses "f" / the
# Fire HUD button with a bow-skill weapon equipped. Mutually exclusive
# with _targeting_spell; _on_target_selected branches on whichever is
# active.
var _ranged_targeting: bool = false
## 2-tap confirm flow for area spells. First tap stores the intended
## blast center here and paints the AoE radius around it; a second tap
## on the same tile commits. Taps on a different tile move the preview
## instead of firing. Vector2i(-1, -1) means "no pending selection".
var _pending_area_target: Vector2i = Vector2i(-1, -1)
## Wand targeting — set when Player emits wand_target_requested. We hold
## the inventory index + resolved kind here so _on_target_selected can
## call back into Player.fire_wand_at once the player confirms.
var _targeting_wand_index: int = -1
var _targeting_wand_id: String = ""
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
	# Test-character boost — MainMenu's "Spell Test" button sets this
	# flag. Bump to XL 27, fill HP/MP, learn every registered spell.
	if GameManager != null and GameManager.test_character_mode:
		_apply_test_character_boost()
		GameManager.test_character_mode = false
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
	if player.has_signal("wand_target_requested"):
		player.wand_target_requested.connect(_on_wand_target_requested)

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
	if top_hud != null and top_hud.has_method("set_location"):
		top_hud.set_location(BranchRegistry.short_name(GameManager.current_branch),
				GameManager.current_depth)
	elif top_hud != null and top_hud.has_method("set_depth"):
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
	if bottom_hud != null and bottom_hud.has_signal("quickslot_swap_requested"):
		bottom_hud.quickslot_swap_requested.connect(_on_quickslot_swap)
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
	if not TurnManager.player_turn_started.is_connected(_on_turn_tick_portal):
		TurnManager.player_turn_started.connect(_on_turn_tick_portal)
	if not TurnManager.player_turn_started.is_connected(_on_turn_tick_clouds):
		TurnManager.player_turn_started.connect(_on_turn_tick_clouds)
	if not TurnManager.player_turn_started.is_connected(_on_turn_tick_silence):
		TurnManager.player_turn_started.connect(_on_turn_tick_silence)
	if not TurnManager.player_turn_started.is_connected(_on_turn_tick_abyss):
		TurnManager.player_turn_started.connect(_on_turn_tick_abyss)

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
	# Tappable strip — opens the full history dialog. Uses MOUSE_FILTER_STOP
	# so the tap doesn't fall through to the DungeonMap underneath.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton \
				and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT:
			_open_combat_log_dialog())
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


## Debug-only — takes the freshly-seeded player and maxes them out so
## the Spell Test launcher drops you straight into a usable kit for
## iterating on fireball / hailstorm / cloud residue etc. Safe to call
## more than once but meant to run once at setup. No-op if called
## before Player.setup populates stats / skills.
func _apply_test_character_boost() -> void:
	if player == null or player.stats == null:
		return
	# Bump XL — _apply_level_up_growth recomputes hp_max / mp_max from
	# scratch using the now-level-27 fighting / spellcasting skills.
	player.level = 27
	if player.has_method("_apply_level_up_growth"):
		player._apply_level_up_growth()
	player.stats.HP = player.stats.hp_max
	player.stats.MP = player.stats.mp_max
	# Learn every spell in SpellRegistry.SPELLS so the Magic dialog has
	# the full catalogue available for testing. Duplicates are guarded
	# by the has() check so repeated boost calls don't balloon the list.
	if "learned_spells" in player:
		for spell_id in SpellRegistry.SPELLS.keys():
			if not player.learned_spells.has(spell_id):
				player.learned_spells.append(String(spell_id))
	# Stock a handful of utility consumables beyond the archmage kit so
	# we can test scroll interactions without fishing for drops.
	for extra_id in ["scroll_fog", "scroll_blink", "scroll_teleport",
			"potion_might", "potion_resistance", "potion_berserk_rage"]:
		if ConsumableRegistry.has(extra_id):
			var cinfo: Dictionary = ConsumableRegistry.get_info(extra_id)
			player.items.append({
				"id": extra_id,
				"name": String(cinfo.get("name", extra_id)),
				"kind": String(cinfo.get("kind", "potion")),
				"color": cinfo.get("color", Color(0.75, 0.75, 0.85)),
			})
			GameManager.identify(extra_id)
	if player.has_signal("stats_changed"):
		player.stats_changed.emit()
	if player.has_signal("inventory_changed"):
		player.inventory_changed.emit()
	CombatLog.add("[Test character: XL 27, all spells learned.]")


## Full combat-log history dialog — opened by tapping the 3-line strip
## above BottomHUD. Shows every message still in CombatLog's rolling
## buffer (MAX_MESSAGES = 60), newest at the bottom, auto-scrolled.
func _open_combat_log_dialog() -> void:
	var dlg := GameDialog.create("Combat Log", Vector2i(960, 1800))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 4)
	var msgs: Array[String] = CombatLog.get_all()
	if msgs.is_empty():
		vb.add_child(UICards.dim_hint("(no messages yet)"))
		return
	for msg in msgs:
		var lbl := Label.new()
		lbl.text = msg
		lbl.add_theme_font_size_override("font_size", 42)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(lbl)
	# Scroll to bottom so the most recent line is visible on open.
	var scroll: ScrollContainer = vb.get_parent() as ScrollContainer
	if scroll != null:
		await get_tree().process_frame
		scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)


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


## DCSS rune + Orb placement. Called from _regenerate_dungeon once
## per floor generation. Drops the branch-specific rune on its final
## floor (the deepest floor of a runed branch) and places the Orb of
## Zot on Zot:5. Both guard against re-placement on floor-revisit
## via GameManager.runes_placed / orb_placed sets.
func _maybe_place_rune_and_orb() -> void:
	if generator == null or player == null:
		return
	var branch: String = GameManager.current_branch
	var depth: int = GameManager.current_depth
	# Rune drop: only on the deepest floor of a runed branch.
	var rune_id: String = RuneRegistry.rune_for_branch(branch)
	if rune_id != "" and not player.runes.has(rune_id):
		var branch_floors: int = BranchRegistry.floors_in(branch)
		# Final floor of the branch. DCSS places rune at the bottom.
		if depth >= branch_floors:
			var placed_key: String = "%s:%d" % [branch, depth]
			if not GameManager.runes_placed.has(placed_key):
				_spawn_rune_item(rune_id)
				GameManager.runes_placed[placed_key] = true
	# Orb of Zot: exclusively on Zot:5.
	if branch == "zot" and depth == 5 and not GameManager.orb_placed and not player.has_orb:
		_spawn_orb_of_zot()
		GameManager.orb_placed = true


## Spawn a rune pickup on a random floor tile. The item uses the
## FloorItem pathway so the existing pickup flow recognises it — a
## new kind "rune" feeds Player.runes.append on step-on.
func _spawn_rune_item(rune_id: String) -> void:
	var info: Dictionary = RuneRegistry.get_info(rune_id)
	if info.is_empty():
		return
	var entity_layer: Node = get_node_or_null("EntityLayer")
	if entity_layer == null:
		return
	var pos: Vector2i = _pick_random_floor_tile_away_from_player(5)
	if pos == Vector2i(-1, -1):
		return
	var fi: FloorItem = FloorItem.new()
	entity_layer.add_child(fi)
	fi.setup(pos, rune_id, String(info.get("name", rune_id)), "rune",
			info.get("color", Color.WHITE), {"rune_id": rune_id})
	CombatLog.add("A %s radiates power somewhere on this floor." % \
			String(info.get("name", rune_id)))


## Spawn the Orb of Zot on Zot:5.
func _spawn_orb_of_zot() -> void:
	var entity_layer: Node = get_node_or_null("EntityLayer")
	if entity_layer == null:
		return
	var pos: Vector2i = _pick_random_floor_tile_away_from_player(8)
	if pos == Vector2i(-1, -1):
		return
	var fi: FloorItem = FloorItem.new()
	entity_layer.add_child(fi)
	fi.setup(pos, "orb_of_zot", "the Orb of Zot", "orb",
			Color(1.00, 0.85, 0.15), {"orb": true})
	CombatLog.add("The Orb of Zot blazes at the heart of this floor!")


## Random walkable tile at least `min_dist` tiles from the player's
## spawn. Used for rune / Orb placement so the loot isn't sitting on
## the stairs the player just arrived on.
func _pick_random_floor_tile_away_from_player(min_dist: int) -> Vector2i:
	if generator == null or player == null:
		return Vector2i(-1, -1)
	var tiles: Array = []
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var p: Vector2i = Vector2i(x, y)
			if not generator.is_walkable(p):
				continue
			var d: int = maxi(abs(p.x - player.grid_pos.x), abs(p.y - player.grid_pos.y))
			if d >= min_dist:
				tiles.append(p)
	if tiles.is_empty():
		return Vector2i(-1, -1)
	return tiles[randi() % tiles.size()]


## DCSS floor-arrival portal detection. If the freshly-generated
## floor has any portal-vault entrances (sewer/ossuary/bailey/volcano/
## icecave), drop a CombatLog line per entrance so the player knows
## a timed side-detour is available without having to stumble onto
## the tile. Only fires on dungeon floors — child branches don't nest
## portals in our port.
func _announce_portals_on_floor() -> void:
	if generator == null or generator.branch_entrances.is_empty():
		return
	for pos in generator.branch_entrances.keys():
		var bid: String = String(generator.branch_entrances[pos])
		if not BranchRegistry.is_portal(bid):
			continue
		var name_s: String = BranchRegistry.display_name(bid)
		var dur: int = BranchRegistry.portal_duration(bid)
		CombatLog.add("A portal to %s shimmers somewhere on this floor (%d turns inside)." % \
				[name_s, dur])


## DCSS portal-vault expiry. Ticks the per-portal turn counter each
## player turn. Warns at the 10-turn and 5-turn marks, then force-
## collapses the portal when it hits zero (returns the player to the
## parent branch via GameManager.leave_branch + _regenerate_dungeon).
func _on_turn_tick_portal() -> void:
	if GameManager == null or GameManager.portal_turns_left <= 0:
		return
	GameManager.portal_turns_left -= 1
	var left: int = GameManager.portal_turns_left
	if left == 10:
		CombatLog.add("The portal begins to fade... (10 turns)")
	elif left == 5:
		CombatLog.add("The portal wavers wildly! (5 turns)")
	elif left <= 0:
		CombatLog.add("The portal collapses — you are flung back!")
		_save_current_floor()
		if GameManager.leave_branch():
			_regenerate_dungeon(true, false)


## Cloud tick — decrement every cloud's turns_left, remove expired ones,
## and apply per-turn damage / status to any actor standing on a cloud
## tile. Called each player turn. The FOV opaque callback already checks
## smoke clouds via GameManager.clouds, so expired smoke naturally
## stops blocking sight on the next redraw.
## Silent Spectre and related mobs project a radius-2 silence zone.
## Standing in the aura silences the player for the next turn (blocks
## spellcasting via SpellCast's existing _silenced_turns check and
## invocations via SpellCast.cast -> confusion/silence gate). Checked
## every player turn so the status clears the moment you step out.
const _SILENCE_AURA_SOURCES: Array = [
	"silent_spectre", "silent_lich", "silence_mage",
]
const _SILENCE_AURA_RADIUS: int = 2


## Abyss per-turn drift — while standing in the Abyss branch, every
## few player turns we re-roll ~3% of the floor's interior tiles:
## walls ↔ floor, with a rare spatial ripple that nudges the player
## in a random direction. Keeps the DCSS "Abyss regenerates around
## you" feel without rebuilding the whole map every turn (which
## would also wipe the player's pathing). Cloud state, items, and
## monsters are untouched — only the base tile grid twists.
const _ABYSS_SHIFT_INTERVAL: int = 4
const _ABYSS_SHIFT_RATIO: float = 0.03
var _abyss_tick_counter: int = 0


func _on_turn_tick_abyss() -> void:
	if GameManager == null or String(GameManager.current_branch) != "abyss":
		_abyss_tick_counter = 0
		return
	if generator == null or player == null:
		return
	_abyss_tick_counter += 1
	if _abyss_tick_counter < _ABYSS_SHIFT_INTERVAL:
		return
	_abyss_tick_counter = 0
	var target_shifts: int = int(float(DungeonGenerator.MAP_WIDTH) \
			* float(DungeonGenerator.MAP_HEIGHT) * _ABYSS_SHIFT_RATIO)
	var shifts: int = 0
	for _i in 200:
		if shifts >= target_shifts:
			break
		var rx: int = 1 + randi() % (DungeonGenerator.MAP_WIDTH - 2)
		var ry: int = 1 + randi() % (DungeonGenerator.MAP_HEIGHT - 2)
		var here: Vector2i = Vector2i(rx, ry)
		# Never ripple the player's own tile or immediate neighbours
		# (would trap them in a wall mid-turn).
		if maxi(abs(rx - player.grid_pos.x), abs(ry - player.grid_pos.y)) <= 1:
			continue
		var t: int = generator.map[rx][ry]
		if t == DungeonGenerator.TileType.WALL:
			generator.map[rx][ry] = DungeonGenerator.TileType.FLOOR
			shifts += 1
		elif t == DungeonGenerator.TileType.FLOOR:
			generator.map[rx][ry] = DungeonGenerator.TileType.WALL
			shifts += 1
	if shifts > 0:
		var dmap: DungeonMap = $DungeonLayer/DungeonMap
		if dmap != null:
			dmap.update_fov(player.grid_pos)
			dmap.queue_redraw()
		# Occasionally nudge the player a step — DCSS Abyss will shove
		# the wanderer toward a random direction when space ripples.
		if randf() < 0.25:
			var dirs_a: Array = [Vector2i(1,0), Vector2i(-1,0),
					Vector2i(0,1), Vector2i(0,-1)]
			dirs_a.shuffle()
			for d in dirs_a:
				var dest: Vector2i = player.grid_pos + d
				if generator.is_walkable(dest):
					player.grid_pos = dest
					player.position = Vector2(
							dest.x * TILE_SIZE + TILE_SIZE / 2.0,
							dest.y * TILE_SIZE + TILE_SIZE / 2.0)
					player.moved.emit(dest)
					CombatLog.add("The Abyss shifts around you.")
					break


func _on_turn_tick_silence() -> void:
	if player == null or not player.is_alive:
		return
	var any_aura: bool = false
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if m.data == null:
			continue
		if not _SILENCE_AURA_SOURCES.has(String(m.data.id)):
			continue
		var d: int = max(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y))
		if d <= _SILENCE_AURA_RADIUS:
			any_aura = true
			break
	if any_aura:
		var prev: int = int(player.get_meta("_silenced_turns", 0))
		if prev < 2:
			player.set_meta("_silenced_turns", 2)
		if not player.has_meta("_silence_aura_in"):
			player.set_meta("_silence_aura_in", true)
			CombatLog.add("An unnatural silence presses against you.")
	else:
		if player.has_meta("_silence_aura_in"):
			player.remove_meta("_silence_aura_in")


func _on_turn_tick_clouds() -> void:
	if GameManager == null or GameManager.clouds.is_empty():
		return
	# Apply damage first so an actor standing on a 1-turn cloud still
	# takes the final tick before the cloud dissolves.
	if player != null and player.is_alive:
		var pc: Dictionary = GameManager.clouds.get(player.grid_pos, {})
		if not pc.is_empty():
			CloudSystem.apply_to_actor(pc, player)
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		var mc: Dictionary = GameManager.clouds.get(m.grid_pos, {})
		if not mc.is_empty():
			CloudSystem.apply_to_actor(mc, m)
	var expired: Array = CloudSystem.tick(GameManager.clouds)
	if not expired.is_empty():
		var dmap: DungeonMap = $DungeonLayer/DungeonMap
		if dmap != null:
			# If any smoke cloud expired, recompute FOV since sight may
			# have just opened up through that tile.
			dmap.update_fov(player.grid_pos)
			dmap.queue_redraw()


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
## Swap two quickslot bindings when the player drags from one slot to
## another. Works for any combo (empty ↔ assigned, spell ↔ item, etc).
func _on_quickslot_swap(from_index: int, to_index: int) -> void:
	if player == null:
		return
	var slots: Array = player.quickslot_ids
	if from_index < 0 or from_index >= slots.size():
		return
	if to_index < 0 or to_index >= slots.size():
		return
	var tmp: String = slots[from_index]
	slots[from_index] = slots[to_index]
	slots[to_index] = tmp
	player.quickslots_changed.emit()


func _on_quickslot_long_pressed(index: int) -> void:
	if player == null:
		return
	var id: String = player.quickslot_ids[index] if index < player.quickslot_ids.size() else ""
	if id == "":
		_open_quickslot_picker(index)
		return
	_open_quickslot_manage_dialog(index, id)


## Long-press popup for an assigned quickslot. Shows the spell or item
## info at the top, followed by Reassign / Clear Slot buttons so the
## player can retire a slot without having to clear it from the
## picker's tail. Replaces the info-only popup path that offered no
## way to empty a slot once used.
func _open_quickslot_manage_dialog(slot_index: int, assigned_id: String) -> void:
	var is_spell: bool = assigned_id.begins_with("spell:")
	var title: String
	var body_text: String
	if is_spell:
		var spell_id: String = assigned_id.substr(6)
		var info: Dictionary = SpellRegistry.get_spell(spell_id)
		title = String(info.get("name", spell_id))
		body_text = _spell_info_text(spell_id, info)
	else:
		var it: Dictionary = _find_inventory_item_by_id(assigned_id)
		if it.is_empty():
			it = {"id": assigned_id, "name": assigned_id.capitalize().replace("_", " ")}
		title = String(it.get("name", "Item"))
		body_text = _build_item_tooltip(it)
	var dlg := GameDialog.create("Quickslot %d — %s" % [slot_index + 1, title],
			Vector2i(960, 1200))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)

	var lab := Label.new()
	lab.text = body_text
	lab.add_theme_font_size_override("font_size", 42)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lab)

	vb.add_child(HSeparator.new())

	var reassign_btn := Button.new()
	reassign_btn.text = "Reassign Slot"
	reassign_btn.custom_minimum_size = Vector2(0, 96)
	reassign_btn.add_theme_font_size_override("font_size", 44)
	reassign_btn.pressed.connect(func():
		dlg.close()
		_open_quickslot_picker(slot_index))
	vb.add_child(reassign_btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Slot"
	clear_btn.custom_minimum_size = Vector2(0, 96)
	clear_btn.add_theme_font_size_override("font_size", 44)
	clear_btn.modulate = Color(1.0, 0.55, 0.55)
	clear_btn.pressed.connect(func():
		if player != null and slot_index < player.quickslot_ids.size():
			player.quickslot_ids[slot_index] = ""
			player.quickslots_changed.emit()
		dlg.close())
	vb.add_child(clear_btn)


## Extracted body of _show_spell_info so the Quickslot Manage popup
## can reuse the exact stat block without popping a second dialog.
func _spell_info_text(spell_id: String, info: Dictionary) -> String:
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
	return text


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
			_pending_area_target = Vector2i(-1, -1)
			if touch_input != null:
				touch_input.targeting_mode = true
			_show_targeting_hint()
		return
	player.use_quickslot(index)


func _open_quickslot_picker(slot_index: int) -> void:
	if player == null:
		return
	var dlg := GameDialog.create("Assign Quickslot %d" % (slot_index + 1), Vector2i(960, 1400))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 6)

	vb.add_child(UICards.section_header("Items"))

	var seen_ids: Dictionary = {}
	var any_items: bool = false
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		var kind: String = String(it.get("kind", ""))
		if kind != "potion" and kind != "scroll" and kind != "book":
			continue
		if seen_ids.has(iid):
			continue
		seen_ids[iid] = true
		any_items = true
		var btn := Button.new()
		var disp: String = GameManager.display_name_for_item(iid, String(it.get("name", iid)), kind)
		btn.text = "%s [%s]" % [disp, kind]
		btn.custom_minimum_size = Vector2(0, 72)
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(_assign_quickslot_item.bind(slot_index, iid, dlg))
		vb.add_child(btn)
	if not any_items:
		vb.add_child(UICards.dim_hint("No usable items."))

	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_system)
	if not known.is_empty():
		vb.add_child(UICards.section_header("Spells"))
		for spell_id in known:
			var info: Dictionary = SpellRegistry.get_spell(spell_id)
			var btn := Button.new()
			btn.text = "%s [%d MP]" % [String(info.get("name", spell_id)), int(info.get("mp", 0))]
			btn.custom_minimum_size = Vector2(0, 72)
			btn.add_theme_font_size_override("font_size", 40)
			btn.add_theme_color_override("font_color", info.get("color", Color.WHITE))
			btn.pressed.connect(_assign_quickslot_item.bind(slot_index, "spell:" + spell_id, dlg))
			vb.add_child(btn)

	var clear_btn := Button.new()
	clear_btn.text = "Clear Slot"
	clear_btn.custom_minimum_size = Vector2(0, 72)
	clear_btn.add_theme_font_size_override("font_size", 40)
	clear_btn.modulate = Color(1.0, 0.5, 0.5)
	clear_btn.pressed.connect(_assign_quickslot_item.bind(slot_index, "", dlg))
	vb.add_child(clear_btn)


func _assign_quickslot_item(slot_index: int, id: String, dlg: GameDialog) -> void:
	if player != null and slot_index < player.quickslot_ids.size():
		player.quickslot_ids[slot_index] = id
		player.quickslots_changed.emit()
	dlg.close()


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
	var dlg := GameDialog.create("Inspect", Vector2i(960, 600))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	var lbl := Label.new()
	lbl.text = "\n".join(PackedStringArray(lines))
	lbl.add_theme_font_size_override("font_size", 36)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lbl)


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
	var dlg := GameDialog.create("Menu", Vector2i(960, 700))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 16)

	var save_btn := Button.new()
	save_btn.text = "Save & Continue"
	save_btn.custom_minimum_size = Vector2(0, 96)
	save_btn.add_theme_font_size_override("font_size", 40)
	save_btn.pressed.connect(func():
		if meta != null:
			meta.save_to_disk()
		print("Game saved.")
		dlg.close())
	vb.add_child(save_btn)

	var restart_btn := Button.new()
	restart_btn.text = "Restart Run"
	restart_btn.custom_minimum_size = Vector2(0, 96)
	restart_btn.add_theme_font_size_override("font_size", 40)
	restart_btn.pressed.connect(func():
		dlg.close()
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
		dlg.close()
		get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn"))
	vb.add_child(quit_btn)


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
	"ring_the_mage", "ring_sustenance",
	"ring_life_protection", "ring_poison_resistance",
	"ring_lightning", "ring_see_invisible", "ring_flight",
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
	# DCSS unrandart drop — 1.5% chance per item at depth ≥ 5. Each
	# unrand is a uniquely-named artefact; UnrandartRegistry picks one
	# at random from those whose min_depth gates are satisfied. Unrands
	# are never cursed and bypass the rest of the category rolls.
	if depth >= 5 and randf() < 0.015:
		var urid: String = UnrandartRegistry.roll_for_depth(depth)
		if urid != "":
			var udict: Dictionary = UnrandartRegistry.make_item(urid)
			var ucolor: Color = udict.get("color", Color(1, 1, 1))
			fi.setup(pos, urid, String(udict.get("name", urid)),
					String(udict.get("kind", "weapon")), ucolor, udict)
			return true
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
		# DCSS item-prop.cc rolls an ego (SPARM_*) with a base rate
		# scaled by depth — deeper floors have richer loot. Null ego
		# keeps the item plain.
		var ego_chance: float = clampf(0.06 + float(depth) * 0.008, 0.06, 0.25)
		var ego_id: String = ArmorRegistry.roll_ego(
				String(info.get("slot", "chest")), ego_chance)
		if ego_id != "":
			aname += " " + ArmorRegistry.ego_label(ego_id)
		if is_cursed:
			aname = "Cursed " + aname
		fi.setup(pos, aid, aname, "armor",
				info.get("color", Color(0.6, 0.6, 0.7)),
				{"ac": int(info.get("ac", 0)),
				 "slot": String(info.get("slot", "chest")),
				 "ego": ego_id,
				 "cursed": is_cursed})
	elif drop_roll < 0.73:
		# Rings — 3% of drops. At depth≥4, ~15% chance to be a randart.
		if depth >= 4 and randf() < 0.15:
			var rart: Dictionary = RandartGenerator.generate_ring(depth)
			fi.setup(pos, rart["id"], rart["name"], "ring", rart["color"], rart)
		else:
			var rid: String = _RING_POOL[randi() % _RING_POOL.size()]
			var ring_info: Dictionary = RingRegistry.get_info(rid)
			fi.setup(pos, rid, String(ring_info.get("name", rid)), "ring",
					ring_info.get("color", Color(0.85, 0.85, 0.90)))
	elif drop_roll < 0.75:
		# Amulets — 2% of drops, same rarity tier as rings. From depth ≥ 4
		# a 15% slice rolls a randart amulet (unique name + 1-4 props)
		# matching the ring path; otherwise pick from the base catalogue.
		if depth >= 4 and randf() < 0.15:
			var arart: Dictionary = RandartGenerator.generate_amulet(depth)
			fi.setup(pos, arart["id"], arart["name"], "amulet",
					arart["color"], arart)
		else:
			var amid: String = AmuletRegistry.random_id()
			var amu_info: Dictionary = AmuletRegistry.get_info(amid)
			fi.setup(pos, amid, String(amu_info.get("name", amid)), "amulet",
					amu_info.get("color", Color(1.00, 0.90, 0.30)))
	elif drop_roll < 0.80:
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
	# DCSS death clouds: rot / plague / elemental monsters release a cloud
	# on death. Burst radius 1 for normal ids, 2 for explosive types so
	# fire vortex / fire elemental deaths leave a real hazard trail.
	if monster != null and monster.data != null and GameManager != null:
		var death_info: Dictionary = _monster_death_cloud(String(monster.data.id))
		var dtype: String = String(death_info.get("type", ""))
		if dtype != "":
			CloudSystem.place_patch(GameManager.clouds, monster.grid_pos,
					dtype, int(death_info.get("radius", 1)))
			var dmap_d: DungeonMap = $DungeonLayer/DungeonMap
			if dmap_d != null:
				dmap_d.update_fov(player.grid_pos if player != null else monster.grid_pos)
				dmap_d.queue_redraw()
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
		# DCSS god conducts — per-kill piety modifiers keyed to the
		# victim's holiness / shape / genus. Each branch overrides
		# `gain` with bonuses or outright penalties (negative = piety
		# loss + log line). Only the most-distinctive deity conducts
		# are wired for now; quiet gods pass through at base rate.
		gain = _apply_god_conduct(player.current_god, monster, gain)
		if gain != 0:
			var cap: int = int(god.get("piety_cap", 200))
			# Amulet of Faith: +50% piety from all sources (DCSS amulet.cc).
			if player.has_meta("_amulet_piety_boost") and gain > 0:
				gain = (gain * 3) / 2
			if gain >= 0:
				player.piety = min(cap, player.piety + gain)
			else:
				player.piety = max(0, player.piety + gain)
				CombatLog.add("%s frowns at you." % \
						String(god.get("title", player.current_god)))
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
		# Ashenzari passive — curse-proportional skill boost. Per DCSS,
		# each cursed equipped slot adds a percentage to XP gain (Ashenzari
		# rewards the burden of curses). We count cursed weapon + each
		# cursed armor slot and apply +5% XP per cursed slot.
		if player.current_god == "ashenzari":
			var curse_count: int = 0
			if "equipped_weapon_cursed" in player and player.equipped_weapon_cursed:
				curse_count += 1
			for slot in player.equipped_armor.keys():
				var a: Dictionary = player.equipped_armor[slot]
				if bool(a.get("cursed", false)):
					curse_count += 1
			if curse_count > 0:
				xp_gain = int(xp_gain * (100 + curse_count * 5) / 100.0)
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


## In-game help dialog. A bundled substitute for DCSS's ~15 reference
## sections — covers the information a new player actually needs in
## the first hour: controls, combat math, skills, identification,
## gods, save/restart. Dialog lives under GameDialog so it inherits
## the same dim/panel/close chrome as the rest of the UI.
func _show_help_dialog() -> void:
	var dlg := GameDialog.create("Help", Vector2i(960, 1800))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 14)

	var sections: Array = [
		["Controls", """Tap: move / attack / pickup
Long-press: inspect tile
? : this help
I : bag    Z : magic
Q : quaff  R : read   E : evoke
F : fire ranged   A : invocations
, : pickup   >< : stairs
X : examine   S/space : rest
Esc : cancel / close dialog"""],
		["Combat basics", """Damage = weapon × (1 + weapon_skill/30) × (1 + fighting/30)
To-hit beats the target's EV (dodge).
AC soaks random 0..AC of the hit.
Shields (SH) roll a separate block — past the block, damage still falls through AC.
Range penalty: -3 to-hit per tile past 2."""],
		["Skills", """Weapon skills: DMG + to-hit + faster swings.
Fighting: DMG × + HP.
Armour: body-AC multiplier (1 + lv/10).
Dodging: EV bonus.
Shields: SH block + shield EV penalty ↓.
Spellcasting: fail ↓ + MP + memory cap.
School skills: spell power for that school.
Stealth: monsters wake slower + stab bonus.
Evocations: wand / essence power."""],
		["Identification", """Potions and scrolls show a pseudonym (Red Potion, Scroll labeled ZUN TAB) until you drink/read them.
Rings and amulets show a metal/shape pseudonym (Silver Ring) until you equip them.
Unrandarts (the X) are always identified — you see the artefact name on pickup.
Randarts (the Adj Noun) show rolled name; equip to reveal props."""],
		["Gods & piety", """Altars (☥) let you pledge. Kill enemies to earn piety; spend at the Abilities menu (A).
Per-god conducts: killing the wrong kind of foe loses piety (Beogh frowns on orc-kin slayers, Fedhas on plant-burners, etc.).
Amulet of Faith gives +50% piety on gains.
Stasis blocks all teleports."""],
		["Status effects", """Slow / Petrifying / Exhausted — half speed via alternating skip.
Paralysis / Petrified / Frozen — full action block.
Weak — -33% melee damage.
Poison stacks in 3 levels; rPois+ one-shots a level."""],
	]
	for s in sections:
		vb.add_child(UICards.section_header(String(s[0])))
		var body := Label.new()
		body.text = String(s[1])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 34)
		body.modulate = Color(0.88, 0.88, 0.95)
		vb.add_child(body)


## DCSS `?/` lookup — search monster / spell / item names across our
## registries. Case-insensitive substring match; results list id →
## short summary in a scroll. Primary use: "I got hit by a bolt —
## what's a yaktaur again?" without leaving the dungeon.
func _show_search_dialog() -> void:
	var dlg := GameDialog.create("Search (?/)", Vector2i(960, 1800))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 10)

	var input := LineEdit.new()
	input.placeholder_text = "type part of a name (monster / spell / item)..."
	input.add_theme_font_size_override("font_size", 40)
	input.custom_minimum_size = Vector2(0, 80)
	vb.add_child(input)

	vb.add_child(UICards.section_header("Results"))
	var results := VBoxContainer.new()
	results.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results.add_theme_constant_override("separation", 4)
	vb.add_child(results)

	var on_query = func(text: String) -> void:
		for c in results.get_children():
			c.queue_free()
		if text.length() < 2:
			var hint := UICards.dim_hint("Type at least 2 characters.")
			results.add_child(hint)
			return
		var needle: String = text.to_lower()
		var total: int = 0
		# Monsters — scan MonsterRegistry ids.
		for mid in MonsterRegistry.all_ids():
			if total >= 30:
				break
			var mid_s: String = String(mid)
			if mid_s.to_lower().find(needle) < 0:
				continue
			var md: MonsterData = MonsterRegistry.fetch(mid_s)
			if md == null:
				continue
			results.add_child(_search_row(
					String(md.display_name),
					"Monster · HD %d · HP ~%d · %s" % [
						md.hd, md.hp, String(md.shape)]))
			total += 1
		# Spells — iterate SpellRegistry's built-in catalog.
		for sid in SpellRegistry.SPELLS.keys():
			if total >= 60:
				break
			var sid_s: String = String(sid)
			var info: Dictionary = SpellRegistry.get_spell(sid_s)
			var sname: String = String(info.get("name", sid_s))
			if sname.to_lower().find(needle) < 0 \
					and sid_s.to_lower().find(needle) < 0:
				continue
			results.add_child(_search_row(sname,
					"Spell · %d MP · %s" % [
						int(info.get("mp", 0)),
						", ".join(PackedStringArray(SpellRegistry.get_schools(sid_s)))]))
			total += 1
		# Items — consumables + wands (weapons/armor names would clutter).
		for cid in ConsumableRegistry.all_ids():
			if total >= 90:
				break
			var cid_s: String = String(cid)
			var cinfo: Dictionary = ConsumableRegistry.get_info(cid_s)
			var cname: String = String(cinfo.get("name", cid_s))
			if cname.to_lower().find(needle) < 0 \
					and cid_s.to_lower().find(needle) < 0:
				continue
			results.add_child(_search_row(cname,
					"%s · %s" % [String(cinfo.get("kind", "item")).capitalize(),
						String(cinfo.get("desc", ""))]))
			total += 1
		if total == 0:
			results.add_child(UICards.dim_hint("No matches."))

	input.text_changed.connect(on_query)
	input.call_deferred("grab_focus")


## Single row inside the `?/` search results. Kept tiny so the scroll
## fits lots of hits.
func _search_row(title: String, subtitle: String) -> Control:
	var col := VBoxContainer.new()
	var name_lbl := Label.new()
	name_lbl.text = title
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.add_theme_color_override("font_color", Color(1.0, 0.90, 0.55))
	col.add_child(name_lbl)
	var sub := Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 28)
	sub.modulate = Color(0.80, 0.80, 0.92)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(sub)
	return col


## DCSS Makhleb Minor/Major Destruction. Rolls one of a fixed pool of
## zaps and fires it at the nearest visible enemy via SpellRegistry's
## damage curves so each invocation feels like a rolled spell rather
## than a flat damage range. `major=true` uses the bigger pool from
## DCSS god-abil.cc:makhleb_major_destruction.
func _makhleb_random_zap(major: bool) -> void:
	var pool_minor: Array = [
			"magic_dart", "throw_flame", "throw_frost", "stone_arrow"]
	var pool_major: Array = [
			"fireball", "iron_shot", "bolt_of_fire", "bolt_of_draining",
			"lehudibs_crystal_spear"]
	var pool: Array = pool_major if major else pool_minor
	var target: Monster = _find_nearest_visible_monster(10)
	if target == null:
		CombatLog.add("Makhleb's destruction finds no target.")
		return
	var spell_id: String = String(pool[randi() % pool.size()])
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	# Piety-derived power — Makhleb invocations scale with piety, not
	# Invocations skill in DCSS (it's a quick-tempered god).
	var power: int = 40 + int(player.piety) / 4
	var dmg: int = SpellRegistry.roll_damage(spell_id, power)
	if dmg <= 0:
		dmg = randi_range(8, 18)
	var elem: String = SpellRegistry.element_for(spell_id)
	target.take_damage(dmg, elem)
	var sname: String = String(info.get("name", spell_id.replace("_", " ")))
	CombatLog.add("Makhleb hurls %s at the %s for %d!" % \
			[sname, _mon_name(target), dmg])


## DCSS per-god kill conducts. Returns the adjusted piety gain for this
## kill (negative = piety loss). Bonuses fire on favoured victims
## (TSO evil-kill, Yred holy-kill), penalties on disliked victims
## (Elyvilon neutral, Beogh orc, Fedhas plant). Gods not listed here
## return `base_gain` unchanged.
func _apply_god_conduct(god_id: String, monster: Monster, base_gain: int) -> int:
	if monster == null or monster.data == null:
		return base_gain
	var holiness: String = ""
	# Holiness derived the same way CombatSystem / Monster does — read
	# shape + flags. "undead"/"demonic"/"holy"/"plant" are the four
	# conduct-bearing classes.
	if String(monster.data.shape) == "undead":
		holiness = "undead"
	elif monster.data.flags != null:
		for f in monster.data.flags:
			var lf: String = String(f).to_lower()
			if lf in ["undead", "demonic", "holy", "plant", "natural"]:
				holiness = lf
				break
	var mid: String = String(monster.data.id) if "id" in monster.data else ""
	match god_id:
		"the_shining_one":
			# TSO +50% from evil kills (undead + demonic); penalty for
			# slaughtering the natural-aligned.
			if holiness == "undead" or holiness == "demonic":
				return base_gain + maxi(1, base_gain / 2)
		"yredelemnul":
			# Yred loves necrotic prey flipped: bonus for holy kills,
			# outright penalty for slaughtering the undead (they're allies
			# in spirit).
			if holiness == "holy":
				return base_gain + 2
			if holiness == "undead":
				return -1
		"zin":
			# Zin forbids mutation + chaos. Chaos demons / shapeshifters
			# anger Zin even on kill (player should be cleansing, not
			# slaying chaos). Small penalty.
			if "chaos" in mid or "shapeshifter" in mid:
				return -1
			if holiness == "demonic":
				return base_gain + 1
		"elyvilon":
			# Elyvilon — the pacifist. Kills of neutral/natural creatures
			# cost piety; only undead and demonic kills are rewarded.
			if holiness == "undead" or holiness == "demonic":
				return base_gain
			return -1
		"cheibriados":
			# Cheibriados cares more about speed than kills — no per-kill
			# conduct, but passes base through. The haste-ban is enforced
			# elsewhere (caster/buff sites).
			return base_gain
		"beogh":
			# Beogh — orc god. Killing non-orc non-pets gains piety; orc
			# kills are a hard penalty ("Beogh frowns").
			if mid.begins_with("orc") or "orc_" in mid or mid == "orc":
				return -3
		"fedhas":
			# Fedhas — plant god. Any plant kill is a -2 penalty.
			if holiness == "plant":
				return -2
		"okawaru":
			# Okawaru — lone warrior. No penalty on kills, but the summon/
			# ally ban lives in the invocation/essence paths.
			return base_gain
	return base_gain


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
	# DCSS reflection — a target wearing SPARM_REFLECTION / Amulet of
	# Reflection has a 20% chance to bounce the spell back. We attenuate
	# by 25% on reflect to reward building into it without making the
	# player themselves get full-damage bolted on a miss-roll.
	if target.has_method("has_meta") and \
			(target.has_meta("_ego_reflect") or target.has_meta("_amulet_reflect")) \
			and randi() % 100 < 20:
		CombatLog.add("The %s reflects the spell!" % \
				(String(target.data.display_name) if "data" in target and target.data else "target"))
		var back_dmg: int = maxi(1, dmg * 3 / 4)
		if player != null and player.has_method("take_damage"):
			player.take_damage(back_dmg, element)
		return
	target.take_damage(dmg, element)
	# DCSS burn_wall_effect — fire / flame spells char adjacent trees
	# (TILE_TREE → TILE_FLOOR) over a small radius. Light-side QoL:
	# clears the foliage so you can path through later.
	if (element == "fire" or spell_id.begins_with("bolt_of_fire") \
			or spell_id == "fireball") and target is Monster \
			and target.generator != null:
		var r: int = 1 if spell_id != "fireball" else 2
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c: Vector2i = target.grid_pos + Vector2i(dx, dy)
				if target.generator.get_tile(c) == DungeonGenerator.TileType.TREE:
					target.generator.map[c.x][c.y] = DungeonGenerator.TileType.FLOOR


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
		var fov_r: int = player.get_fov_radius() if player != null and player.has_method("get_fov_radius") else DungeonMap.EXPLORE_RADIUS
		dmap.update_fov(new_pos, fov_r)
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
	# DCSS victory: stairs-up off D:1 of the Dungeon with the Orb of
	# Zot in hand ends the run in triumph. Classic endgame gate.
	if GameManager.current_branch == "dungeon" and GameManager.current_depth == 1 \
			and player != null and player.has_orb:
		CombatLog.add("You escape the dungeon with the Orb of Zot!")
		_end_run(true, "")
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
	if skill_id == "dodging" or skill_id == "stealth" or skill_id == "armour" \
			or skill_id == "shields":
		if player.has_method("_recompute_defense"):
			player._recompute_defense()
	# DCSS calc_hp / calc_mp recomputes live on every query, so a fighting
	# / spellcasting level bump should flow through to HP / MP immediately.
	# We call _apply_level_up_growth (reused from XL level-up) because it
	# already folds fighting + spellcasting into the max-HP/MP formula and
	# preserves the current HP / MP ratio across the change.
	if skill_id == "fighting" or skill_id == "spellcasting":
		if player.has_method("_apply_level_up_growth"):
			player._apply_level_up_growth()
	# Shapeshifting levelling mid-form should retune the active form so
	# the skill bump actually lands. Easiest: re-apply_form with the
	# current id; apply_form clears the prior state and rebuilds with
	# the new skill level folded in.
	if skill_id == "shapeshifting" and player.current_form != "":
		var cur_form: String = player.current_form
		player.clear_form()
		player.apply_form(cur_form)


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
			player.apply_poison(1, "a dart")
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
			# DCSS teleport trap drops you at least 6 tiles away (trap.cc
			# trap_effect). Random destinations close to the trap don't
			# count — retry up to 20 times before falling back to plain
			# random teleport.
			CombatLog.add("Space wobbles — you are teleported!")
			var old_pos: Vector2i = player.grid_pos
			var landed: bool = false
			for _attempt in 20:
				if player.has_method("_teleport_random"):
					player._teleport_random()
				var dx_t: int = abs(player.grid_pos.x - old_pos.x)
				var dy_t: int = abs(player.grid_pos.y - old_pos.y)
				if maxi(dx_t, dy_t) >= 6:
					landed = true
					break
			if not landed and player.has_method("_teleport_random"):
				player._teleport_random()
		"shaft":
			# DCSS shaft drops the victim 1-3 floors down. Uses the same
			# level-descent pipeline as stairs so floor state persistence
			# (kills-stay-dead, items stay gone) still works.
			var depth_drop: int = 1 + randi() % 3
			var target_depth: int = mini(MAX_DEPTH, GameManager.current_depth + depth_drop)
			if target_depth <= GameManager.current_depth:
				CombatLog.add("The floor gives way, but you catch yourself!")
			else:
				CombatLog.add("The floor collapses — you plunge %d floors!" % \
						(target_depth - GameManager.current_depth))
				GameManager.current_depth = target_depth
				_regenerate_dungeon(false, false)
		"alarm":
			CombatLog.add("An alarm blares!")
			MonsterAI.broadcast_noise(get_tree(), pos, 30, 0)
		"net":
			player.set_meta("_rooted_turns", 5)
			CombatLog.add("A net falls on you! (rooted for 5 turns)")
		"zot":
			# DCSS Zot trap — cascade of nastiness. Rolls one of: heavy
			# damage, random bad status, summon 1-3 dangerous mobs, or a
			# teleport. Scales with depth so late-game Zot traps are
			# catastrophic, early-game traps are merely bad.
			CombatLog.add("A flash of evil energy — the Zot trap triggers!")
			var zot_roll: int = randi() % 4
			match zot_roll:
				0:
					var zd: int = 10 + randi() % max(10 + depth, 10)
					player.take_damage(zd, "negative")
					CombatLog.add("Baleful magic rakes you for %d damage!" % zd)
				1:
					var bad_statuses: Array = ["_confused", "_slowed_turns",
							"_afraid_turns", "_paralysis_turns"]
					var pick: String = String(bad_statuses[randi() % bad_statuses.size()])
					if pick == "_confused":
						player.set_meta("_confused", true)
						player.set_meta("_confusion_turns", 6)
					else:
						player.set_meta(pick, 4 + randi() % 6)
					CombatLog.add("A curse grips you! (%s)" % pick.replace("_turns", "").replace("_", ""))
				2:
					var zot_pool: Array = ["orange_demon", "hell_hound",
							"iron_golem", "ynoxinul", "shadow_demon"]
					for _i in 1 + randi() % 3:
						var sid: String = String(zot_pool[randi() % zot_pool.size()])
						_spawn_hostile(sid, player.grid_pos)
					CombatLog.add("Shapes coalesce around you!")
				3:
					CombatLog.add("You are flung across the floor!")
					if player.has_method("_teleport_random"):
						player._teleport_random()
		"golubria":
			# DCSS Passage of Golubria trap — short-range controlled
			# teleport to a visible walkable tile. No direct damage; the
			# payoff is that monsters adjacent to the old position lose
			# their tempo. Fires once per trigger.
			CombatLog.add("A portal of Golubria opens — you step through!")
			var dmap_g: DungeonMap = $DungeonLayer/DungeonMap
			var candidates: Array[Vector2i] = []
			if dmap_g != null:
				for dx_g in range(-6, 7):
					for dy_g in range(-6, 7):
						var cand: Vector2i = player.grid_pos + Vector2i(dx_g, dy_g)
						if not generator.is_walkable(cand):
							continue
						if not dmap_g.is_tile_visible(cand):
							continue
						if maxi(abs(dx_g), abs(dy_g)) < 3:
							continue
						candidates.append(cand)
			if not candidates.is_empty():
				var dest: Vector2i = candidates[randi() % candidates.size()]
				player.grid_pos = dest
				player.position = Vector2(dest.x * TILE_SIZE + TILE_SIZE / 2.0,
						dest.y * TILE_SIZE + TILE_SIZE / 2.0)
				player.moved.emit(dest)
				if dmap_g != null:
					dmap_g.update_fov(dest)
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
		"fire":
			# Ranged fire: a bow/sling/crossbow must be equipped. Enters
			# the same targeting mode spells use, then resolves to
			# Player.try_ranged_attack when the user taps a target.
			if WeaponRegistry.weapon_skill_for(player.equipped_weapon_id) != "bow":
				CombatLog.add("You have no ranged weapon equipped.")
			elif touch_input != null:
				_ranged_targeting = true
				_targeting_spell = ""
				touch_input.targeting_mode = true
				CombatLog.add("Fire at which tile? Tap to aim, Esc to cancel.")
		"help":
			_show_help_dialog()
		"search":
			_show_search_dialog()
		"cancel":
			# Close any active popup. GameDialog auto-closes on Esc,
			# but the path here also ensures targeting mode releases.
			_ranged_targeting = false
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
	var kind: String = String(shop.get("kind", "general"))
	var title: String = "Shop — %s (you have %d gold)" % [kind.capitalize(), player.gold]
	var dlg := GameDialog.create(title, Vector2i(960, 1200))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	var inventory: Array = shop.get("inventory", [])
	if inventory.is_empty():
		var lbl := Label.new()
		lbl.text = "Shop is empty."
		lbl.add_theme_font_size_override("font_size", 40)
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
			btn.custom_minimum_size = Vector2(0, 80)
			btn.add_theme_font_size_override("font_size", 40)
			btn.disabled = player.gold < price
			btn.pressed.connect(_buy_from_shop.bind(pos, entry, dlg))
			vb.add_child(btn)


func _buy_from_shop(pos: Vector2i, entry: Dictionary, dlg: GameDialog) -> void:
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
		dlg.close()
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
	var dlg := GameDialog.create(String(info.get("title", god_id)), Vector2i(960, 1400))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 20)

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
	vb.add_child(desc_lbl)

	vb.add_child(HSeparator.new())

	var guide_lbl := Label.new()
	guide_lbl.text = GodRegistry.get_guide(god_id)
	guide_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_lbl.add_theme_font_size_override("font_size", 34)
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
		dlg.close())
	vb.add_child(pledge_btn)


## Open a popup listing the current god's invocations. Greyed rows are
## locked by piety threshold; active rows fire `_invoke(inv_id)`.
func _show_invocations_menu() -> void:
	if player == null or player.current_god == "":
		return
	var god: Dictionary = GodRegistry.get_info(player.current_god)
	var title: String = "%s — Piety %d/%d" % [String(god.get("title", "")), player.piety,
			int(god.get("piety_cap", 200))]
	var dlg := GameDialog.create(title, Vector2i(960, 1100))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	for inv_id in god.get("invocations", []):
		var inv: Dictionary = GodRegistry.invocation(String(inv_id))
		var btn := Button.new()
		var locked: bool = player.piety < int(inv.get("min_piety", 999))
		btn.text = "%s  — %d piety  [%s]" % [String(inv.get("name", inv_id)),
				int(inv.get("cost", 0)), ("LOCKED" if locked else "READY")]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 40)
		btn.disabled = locked or player.piety < int(inv.get("cost", 0))
		btn.pressed.connect(_invoke.bind(String(inv_id), dlg))
		vb.add_child(btn)


func _invoke(inv_id: String, dlg: GameDialog) -> void:
	var inv: Dictionary = GodRegistry.invocation(inv_id)
	if inv.is_empty() or player == null:
		return
	if player.piety < int(inv.get("cost", 0)):
		CombatLog.add("Not enough piety.")
		return
	player.piety -= int(inv.get("cost", 0))
	if dlg != null:
		dlg.close()
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
			# DCSS Duel: banish the target + player to a private arena
			# tile where nothing else can interfere. We approximate by
			# teleporting the player adjacent to the target, nuking any
			# other monsters within 3 tiles via a flee meta, and
			# damaging the target. Not a full arena but the "1v1" feel
			# is preserved.
			var duel_t: Monster = _find_nearest_visible_monster(10)
			if duel_t != null:
				# Step player onto a tile adjacent to the target.
				var dirs: Array = [Vector2i(1,0), Vector2i(-1,0),
						Vector2i(0,1), Vector2i(0,-1)]
				for d in dirs:
					var cand: Vector2i = duel_t.grid_pos + d
					if player.has_method("_player_can_walk_on") \
							and player._player_can_walk_on(cand):
						player.grid_pos = cand
						player.position = Vector2(
								cand.x * TILE_SIZE + TILE_SIZE / 2.0,
								cand.y * TILE_SIZE + TILE_SIZE / 2.0)
						break
				# Clear the arena: nearby other monsters flee.
				for m in get_tree().get_nodes_in_group("monsters"):
					if m == duel_t or not is_instance_valid(m):
						continue
					if maxi(abs(m.grid_pos.x - player.grid_pos.x),
							abs(m.grid_pos.y - player.grid_pos.y)) <= 3:
						m.set_meta("_flee_turns", 8)
				var duel_rng: Array = _inv_scale_range(25, 45)
				duel_t.take_damage(randi_range(int(duel_rng[0]), int(duel_rng[1])))
				CombatLog.add("Okawaru opens a private arena with the %s!" % \
						_mon_name(duel_t))
		# ---- Makhleb ----
		"minor_destruction":
			# DCSS rolls one of: throw_frost / throw_flame / magic_dart /
			# lightning. Pick from the pool and route through SpellRegistry
			# for damage to inherit per-element resist scaling.
			_makhleb_random_zap(false)
		"major_destruction":
			# DCSS rolls one of: fireball / iron_shot / bolt_of_draining /
			# lehudibs_crystal_spear / bolt_of_fire. Each is a real zap with
			# its own element + damage curve.
			_makhleb_random_zap(true)
		"summon_demon":
			# DCSS rolls a random Pan-lord-tier demon. We rotate across the
			# demonic roster in our registry so each call feels distinct.
			var demon_pool: Array = ["red_devil", "yellow_devil", "green_death",
					"blue_devil", "iron_devil"]
			_summon_ally(String(demon_pool[randi() % demon_pool.size()]),
					50, "A demon rises to serve!")
		# ---- Uskayaw ----
		"stomp":
			var stomp_r: Array = _inv_scale_range(10, 20)
			_aoe_damage_visible(8, int(stomp_r[0]), int(stomp_r[1]),
					"Uskayaw's stomp rattles the floor!")
		"line_pass":
			var lp_r: Array = _inv_scale_range(15, 30)
			_aoe_damage_visible(12, int(lp_r[0]), int(lp_r[1]),
					"You dance through the enemy line!")
		# ---- Zin / TSO / Elyvilon ----
		"vitalisation":
			_heal_player(_inv_scale_int(40), _inv_scale_int(20),
					"Zin's light fills you.")
		"imprison":
			var imp_t: Monster = _find_nearest_visible_monster(8)
			if imp_t != null:
				imp_t.set_meta("_paralysis_turns", _inv_scale_int(10))
				CombatLog.add("Stone walls seal the %s in place." % _mon_name(imp_t))
		"sanctuary":
			player.set_meta("_sanctuary_turns", _inv_scale_int(12))
			CombatLog.add("A peaceful silence falls around you.")
		"divine_shield":
			if player.stats != null:
				var ds_ac: int = _inv_scale_int(6)
				player.stats.AC += ds_ac
				player.set_meta("_divine_shield_turns", _inv_scale_int(15))
				player.set_meta("_divine_shield_ac", ds_ac)
				player.stats_changed.emit()
			CombatLog.add("A golden shield surrounds you.")
		"cleansing_flame":
			var cf_r: Array = _inv_scale_range(20, 40)
			_aoe_damage_visible(12, int(cf_r[0]), int(cf_r[1]),
					"Cleansing flame burns every foe!")
		"summon_angel":
			_summon_ally("angel", _inv_scale_int(80),
					"An angel descends to your aid!")
		"lesser_healing":
			_heal_player(_inv_scale_int(15), 0, "Elyvilon mends your wounds.")
		"greater_healing":
			_heal_player(_inv_scale_int(40), 0, "Elyvilon heals you deeply.")
		"pacify":
			var pac_t: Monster = _find_nearest_visible_monster(8)
			if pac_t != null:
				pac_t.set_meta("_flee_turns", _inv_scale_int(20))
				CombatLog.add("The %s calms and flees in peace." % _mon_name(pac_t))
		# ---- Vehumet ----
		"gift_spell":
			# DCSS Vehumet gifts destructive spells tiered by piety.
			# Low piety → throw_*; high piety → bolt_of_* / fireball.
			var low_pool: Array = ["throw_flame", "throw_frost", "magic_dart",
					"mephitic_cloud"]
			var mid_pool: Array = ["sticky_flame", "bolt_of_fire", "bolt_of_cold",
					"iron_shot", "stone_arrow"]
			var high_pool: Array = ["fireball", "bolt_of_magma", "bolt_of_draining",
					"lehudibs_crystal_spear"]
			var pick_pool: Array = low_pool if player.piety < 80 \
					else (mid_pool if player.piety < 140 else high_pool)
			# Don't overflow the memorisation cap — bail if it's full.
			if player.used_spell_levels() >= player.max_spell_levels():
				CombatLog.add("Vehumet's lips form a spell but you have no memory to hold it.")
				return
			for _i in 10:
				var sp: String = String(pick_pool[randi() % pick_pool.size()])
				if not player.learned_spells.has(sp):
					player.learned_spells.append(sp)
					CombatLog.add("Vehumet gifts you %s." % sp.replace("_", " "))
					player.spells_learned.emit()
					break
		# ---- Sif Muna ----
		"channel_mana":
			if player.stats != null:
				var mp_gain: int = _inv_scale_int(15)
				player.stats.MP = min(player.stats.mp_max, player.stats.MP + mp_gain)
				player.stats_changed.emit()
			CombatLog.add("Sif Muna channels arcane energy into you.")
		"divine_exegesis":
			# DCSS Divine Exegesis — lets the player cast any spell they
			# know at +power AND skips the fail roll. Our approximation:
			# restore MP to full AND set `_exegesis_turns` for 3 turns,
			# during which cast failure rate is forced to 0 and spell
			# power gets a flat +30 bump. SpellCast reads both metas.
			if player.stats != null:
				player.stats.MP = player.stats.mp_max
				player.stats_changed.emit()
			player.set_meta("_exegesis_turns", 3)
			CombatLog.add("Sif Muna's insight fills you — next 3 spells cannot fail.")
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
			var dl_r: Array = _inv_scale_range(5, 15)
			var drained: int = _aoe_damage_visible(10, int(dl_r[0]), int(dl_r[1]),
					"Life flows out of the living!")
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
				var sm_r: Array = _inv_scale_range(20, 40)
				sm_t.take_damage(randi_range(int(sm_r[0]), int(sm_r[1])))
				CombatLog.add("Divine wrath smites the %s!" % _mon_name(sm_t))
		# ---- Jiyva ----
		"jelly_prayer":
			var jp_gain: int = 15 if player.has_meta("_amulet_piety_boost") else 10
			player.piety = min(200, player.piety + jp_gain)
			CombatLog.add("The slimes commune with their god.")
		"cure_bad_mutation":
			_cure_one_bad_mutation()
		"slimify":
			player.set_meta("_slimify_turns", 10)
			CombatLog.add("Your weapon oozes acidic slime.")
		# ---- Fedhas ----
		"sunlight":
			# DCSS Sunlight: dispels invisibility, reveals the area,
			# and damages undead/demonic. We add the undead bonus to
			# the existing reveal_all path.
			var dmap_s: DungeonMap = $DungeonLayer/DungeonMap
			if dmap_s != null and dmap_s.has_method("reveal_all"):
				dmap_s.reveal_all()
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not m.is_alive:
					continue
				if not dmap_s.is_tile_visible(m.grid_pos):
					continue
				var hol_s: String = ""
				if m.data and m.data.shape == "undead":
					hol_s = "undead"
				elif m.data and m.data.flags != null:
					for f in m.data.flags:
						if String(f).to_lower() == "demonic":
							hol_s = "demonic"
							break
				if hol_s != "":
					m.take_damage(randi_range(12, 24), "holy")
			CombatLog.add("Sunlight sears the shadows.")
		"plant_ring":
			# Summon 2-4 plants around the player, same pattern as other
			# ally summons but short-lived (20 turns). Acts as a temporary
			# fence of cover against enemies.
			for i in randi_range(2, 4):
				_summon_ally("plant", 20, "")
			CombatLog.add("Verdant plants burst from the ground around you.")
		"rain":
			# DCSS Rain: converts floor → shallow water over a radius and
			# douses fires. We convert nearby tiles to WATER (DCSS water
			# impedes movement for non-amphibious — matches via
			# _player_can_walk_on).
			if generator != null:
				var dmap_r: DungeonMap = $DungeonLayer/DungeonMap
				for dx in range(-4, 5):
					for dy in range(-4, 5):
						var cc: Vector2i = player.grid_pos + Vector2i(dx, dy)
						if cc.x < 0 or cc.x >= DungeonGenerator.MAP_WIDTH:
							continue
						if cc.y < 0 or cc.y >= DungeonGenerator.MAP_HEIGHT:
							continue
						if generator.get_tile(cc) == DungeonGenerator.TileType.FLOOR \
								and abs(dx) + abs(dy) >= 2 \
								and abs(dx) + abs(dy) <= 5:
							if randf() < 0.35:
								generator.map[cc.x][cc.y] = DungeonGenerator.TileType.WATER
				if dmap_r != null:
					dmap_r.render(generator)
			CombatLog.add("Rain floods the area with fresh water.")
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
			var sl_r: Array = _inv_scale_range(8, 20)
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.take_damage(randi_range(int(sl_r[0]), int(sl_r[1])))
			CombatLog.add("Slouch hits the swift!")
		# ---- Lugonu ----
		"bend_space":
			var bs_t: Monster = _find_nearest_visible_monster(8)
			if bs_t != null:
				var bsr: Array = _inv_scale_range(5, 12)
				bs_t.take_damage(randi_range(int(bsr[0]), int(bsr[1])))
				CombatLog.add("Space warps around the %s." % _mon_name(bs_t))
		"banishment":
			var bn_t: Monster = _find_nearest_visible_monster(8)
			if bn_t != null:
				bn_t.take_damage(9999)
				CombatLog.add("The %s vanishes into the Abyss!" % _mon_name(bn_t))
		"corrupt_level":
			# DCSS Lugonu Corrupt: twists the level into an Abyss-like
			# chaos zone. Full-floor warp is beyond our scope, so we
			# banish the 5 most-dangerous monsters (highest HD) and
			# confuse the rest for 15 turns.
			var mons_list: Array = []
			for m in get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m is Monster and m.is_alive:
					mons_list.append(m)
			mons_list.sort_custom(func(a, b):
				return int(a.data.hd) > int(b.data.hd))
			for i in min(5, mons_list.size()):
				var victim: Monster = mons_list[i]
				victim.take_damage(9999)
			for m in mons_list.slice(5):
				m.set_meta("_confusion_turns", 15)
			CombatLog.add("The dungeon writhes — Lugonu corrupts everything in sight!")
		# ---- Ashenzari ----
		"scry":
			var dmap_y: DungeonMap = $DungeonLayer/DungeonMap
			if dmap_y != null and dmap_y.has_method("reveal_all"):
				dmap_y.reveal_all()
			CombatLog.add("Ashenzari grants you sight.")
		"transfer_knowledge":
			# DCSS Transfer Knowledge: move XP from one skill to another.
			# Our simplification: grant 1500 XP split across currently-
			# trained skills (the ones marked training = true). Matches
			# the "skill swap" spirit while skipping the two-skill picker
			# UI.
			if skill_system != null:
				var trained: Array = []
				for sk in SkillSystem.SKILL_IDS:
					var st: Dictionary = player.skill_state.get(sk, {})
					if bool(st.get("training", false)):
						trained.append(sk)
				if trained.is_empty():
					CombatLog.add("Enable skills to train before calling the transfer.")
				else:
					skill_system.grant_xp(player, 1500.0, trained)
					CombatLog.add("Ashenzari pours arcane knowledge into your training.")
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
			# DCSS Heplia: summons a persistent ancestor companion. We
			# use a generic orc_knight stand-in since we don't yet
			# model ancestor class choice.
			_summon_ally("orc_knight", 999, "Your ancestor answers the call.")
		"idealise":
			# DCSS Idealise: heal + haste every companion. Approx via
			# the _haste_turns meta the action pipeline already reads.
			var idealised: int = 0
			for c in get_tree().get_nodes_in_group("companions"):
				if is_instance_valid(c) and c.is_alive:
					if "hp" in c and "data" in c and c.data != null:
						c.hp = int(c.data.hp)
					if c.has_method("set_meta"):
						c.set_meta("_haste_turns", 20)
					idealised += 1
			if idealised > 0:
				CombatLog.add("Your %d allies blaze with ancestral power!" % idealised)
			else:
				CombatLog.add("No allies answer the call.")
		"transference":
			# Swap positions with the nearest ally (companion) so the
			# player can duck out of melee range. DCSS also hurts nearby
			# enemies — we skip that for simplicity.
			var closest: Node = null
			var closest_d: int = 999999
			for c in get_tree().get_nodes_in_group("companions"):
				if not is_instance_valid(c) or not c.is_alive:
					continue
				var d: int = maxi(abs(c.grid_pos.x - player.grid_pos.x),
						abs(c.grid_pos.y - player.grid_pos.y))
				if d < closest_d:
					closest_d = d
					closest = c
			if closest != null:
				var old_p: Vector2i = player.grid_pos
				player.grid_pos = closest.grid_pos
				player.position = Vector2(
						player.grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
						player.grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
				closest.grid_pos = old_p
				closest.position = Vector2(
						old_p.x * TILE_SIZE + TILE_SIZE / 2.0,
						old_p.y * TILE_SIZE + TILE_SIZE / 2.0)
				CombatLog.add("You swap places with your ancestor.")
			else:
				CombatLog.add("No ally to bind with.")
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


## Invocations-skill multiplier for god ability potency. Linear: skill
## 0 → 1.0×, skill 27 → 2.0×. Applied to heal amount, AoE damage ranges,
## paralysis / sanctuary / divine-shield durations, and summon lifetimes
## so a newly-pledged acolyte's smite does meaningful-but-weaker work
## and a 27-skill zealot's smite hits roughly DCSS full-strength values.
func _inv_factor() -> float:
	if skill_system == null or player == null:
		return 1.0
	var inv: int = int(skill_system.get_level(player, "invocations"))
	return 1.0 + float(inv) / 27.0


func _inv_scale_int(base: int) -> int:
	return int(float(base) * _inv_factor())


func _inv_scale_range(lo: int, hi: int) -> Array:
	var f: float = _inv_factor()
	return [int(lo * f), int(hi * f)]


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
	# DCSS Zot gate — the Zot entrance demands at least N runes of Zot.
	# Turn the player back at the portal if they're under the threshold.
	if branch_id == "zot":
		var have: int = player.runes.size() if player != null else 0
		var need: int = RuneRegistry.ZOT_GATE_REQUIREMENT
		if have < need:
			CombatLog.add("The gates of Zot refuse you — %d / %d runes." % [have, need])
			return
	# Confirmation dialog — players walked onto branch entrances thinking
	# they were stairs-down and got yanked to D:1 of a sub-branch. Now
	# tapping pops a prompt; the branch is only entered on explicit
	# confirm so the main-trunk descent stays predictable.
	var dlg := GameDialog.create("Enter a new branch?", Vector2i(960, 900))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 14)
	var name_lbl := Label.new()
	name_lbl.text = BranchRegistry.display_name(branch_id)
	name_lbl.add_theme_font_size_override("font_size", 56)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(name_lbl)
	var is_portal: bool = BranchRegistry.is_portal(branch_id)
	var detail := Label.new()
	if is_portal:
		detail.text = "A timed portal — %d turns inside before it collapses and flings you back to the parent floor." % \
				BranchRegistry.portal_duration(branch_id)
	else:
		detail.text = "Persistent branch — you can walk back up the branch's stairs to return to this floor."
	detail.add_theme_font_size_override("font_size", 38)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(detail)
	var gate_msg: String = BranchRegistry.entry_message(branch_id)
	if gate_msg != "":
		var gate_lbl := Label.new()
		gate_lbl.text = gate_msg
		gate_lbl.add_theme_font_size_override("font_size", 34)
		gate_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		gate_lbl.modulate = Color(0.85, 0.85, 1.0)
		gate_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(gate_lbl)
	vb.add_child(HSeparator.new())
	var enter_btn := Button.new()
	enter_btn.text = "Enter"
	enter_btn.custom_minimum_size = Vector2(0, 120)
	enter_btn.add_theme_font_size_override("font_size", 52)
	enter_btn.modulate = Color(1.0, 0.95, 0.55)
	enter_btn.pressed.connect(func():
		dlg.close()
		_confirm_enter_branch(branch_id))
	vb.add_child(enter_btn)
	var stay_btn := Button.new()
	stay_btn.text = "Stay"
	stay_btn.custom_minimum_size = Vector2(0, 96)
	stay_btn.add_theme_font_size_override("font_size", 44)
	stay_btn.pressed.connect(dlg.close)
	vb.add_child(stay_btn)


func _confirm_enter_branch(branch_id: String) -> void:
	if run_over:
		return
	# Trove gate — custodian demands gold before letting the player in.
	# Price scales with current depth so late-game Troves cost more.
	# Player with not enough gold is turned away; refusing bypass is
	# always allowed (cancel popup).
	if branch_id == "trove":
		var price: int = 100 + GameManager.current_depth * 25
		if player == null or player.gold < price:
			CombatLog.add("The Trove custodian demands %d gold — you don't have it." % price)
			return
		_prompt_trove_payment(branch_id, price)
		return
	if branch_id == "zot":
		CombatLog.add("The Zot gates recognise your runes and part.")
	_save_current_floor()
	GameManager.enter_branch(branch_id)
	var is_portal: bool = BranchRegistry.is_portal(branch_id)
	if is_portal:
		CombatLog.add("You step into %s. (%d turns before it collapses)" % [
				BranchRegistry.display_name(branch_id),
				BranchRegistry.portal_duration(branch_id)])
		var msg: String = BranchRegistry.entry_message(branch_id)
		if msg != "":
			CombatLog.add(msg)
	else:
		CombatLog.add("You enter %s." % BranchRegistry.display_name(branch_id))
	_regenerate_dungeon(false, false)


## Payment prompt for the Trove custodian. Accept deducts gold and
## enters the branch; Decline leaves the portal alone so the player
## can come back later with more funds (until the portal decays).
func _prompt_trove_payment(branch_id: String, price: int) -> void:
	var dlg := GameDialog.create("The Custodian", Vector2i(960, 900))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 14)
	var msg := Label.new()
	msg.text = "A hooded figure bars the doorway. They hold out a hand, wordless."
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.add_theme_font_size_override("font_size", 38)
	vb.add_child(msg)
	var price_lbl := Label.new()
	price_lbl.text = "Pay %d gold?   (You have %d)" % [price, player.gold]
	price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", 46)
	price_lbl.modulate = Color(1.0, 0.9, 0.4)
	vb.add_child(price_lbl)
	vb.add_child(HSeparator.new())
	var pay := Button.new()
	pay.text = "Pay %d" % price
	pay.custom_minimum_size = Vector2(0, 120)
	pay.add_theme_font_size_override("font_size", 52)
	pay.modulate = Color(1.0, 0.95, 0.55)
	pay.pressed.connect(func():
		dlg.close()
		player.gold -= price
		player.inventory_changed.emit()
		CombatLog.add("You drop %d gold into the Custodian's hand." % price)
		_save_current_floor()
		GameManager.enter_branch(branch_id)
		CombatLog.add("You step into %s." % BranchRegistry.display_name(branch_id))
		var entry_msg: String = BranchRegistry.entry_message(branch_id)
		if entry_msg != "":
			CombatLog.add(entry_msg)
		_regenerate_dungeon(false, false))
	vb.add_child(pay)
	var decline := Button.new()
	decline.text = "Walk away"
	decline.custom_minimum_size = Vector2(0, 96)
	decline.add_theme_font_size_override("font_size", 44)
	decline.pressed.connect(dlg.close)
	vb.add_child(decline)


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
	# Clouds are per-floor and don't persist across stairs. Clearing
	# also prevents stale Vector2i keys from a prior map leaking onto
	# a newly-generated one of different dimensions.
	if GameManager != null:
		GameManager.clouds.clear()
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
	if _top_hud_ref != null and _top_hud_ref.has_method("set_location"):
		_top_hud_ref.set_location(BranchRegistry.short_name(GameManager.current_branch),
				GameManager.current_depth)
	elif _top_hud_ref != null and _top_hud_ref.has_method("set_depth"):
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
	# DCSS arrival announce: if the new floor carries any portal-vault
	# entrances, tell the player so they know a timed detour is waiting.
	# The player sense what's on their floor even before they discover it.
	_announce_portals_on_floor()
	# End-game placement: drop the branch's rune on its final floor, and
	# the Orb of Zot on Zot:5. Both only appear once per run (guarded by
	# GameManager.runes_placed / orb_placed).
	_maybe_place_rune_and_orb()


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


## Spawn one hostile Monster of `monster_id` adjacent to `center` — used
## by Zot traps and other hostile-summon sources. No-op when the template
## resource is missing or every neighbour is blocked.
func _spawn_hostile(monster_id: String, center: Vector2i) -> void:
	if generator == null:
		return
	var tres_path: String = "res://resources/monsters/%s.tres" % monster_id
	if not ResourceLoader.exists(tres_path):
		return
	var mdata: MonsterData = load(tres_path)
	if mdata == null:
		return
	var sp: Vector2i = _find_free_adjacent_tile(center)
	if sp == center:
		return
	var monster_scene: PackedScene = load("res://scenes/entities/Monster.tscn")
	if monster_scene == null:
		return
	var m: Monster = monster_scene.instantiate()
	$EntityLayer.add_child(m)
	m.setup(generator, sp, mdata)
	if not m.died.is_connected(_on_monster_died):
		m.died.connect(_on_monster_died)


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
	if player == null:
		return
	_suppress_bag_reopen = true
	# Close the bag / any other open dialog first so the identify picker
	# surfaces on top. Without this it stacks behind the bag and becomes
	# untouchable.
	_close_all_dialogs()
	# Dedupe by item id — carrying three of the same unknown potion should
	# show one row in the picker, and identifying it reveals all three.
	# Also surfaces unidentified rings / amulets and ego-bearing armour
	# so Scroll of Identify works the DCSS way (any unknown magical item,
	# not just consumables).
	var unidentified: Array = []
	var seen_ids: Dictionary = {}
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		if iid == "" or seen_ids.has(iid):
			continue
		if iid.begins_with("randart_") or iid.begins_with("unrand_"):
			continue
		var kind_it: String = String(it.get("kind", ""))
		var is_candidate: bool = false
		if ConsumableRegistry.has(iid) and not GameManager.is_identified(iid):
			is_candidate = true
		elif (kind_it == "ring" or kind_it == "amulet") \
				and not GameManager.is_identified(iid):
			is_candidate = true
		elif kind_it == "armor":
			var ego_it: String = String(it.get("ego", ""))
			if ego_it != "" and not GameManager.is_identified(
					GameManager.armor_ego_key(ego_it)):
				is_candidate = true
		if is_candidate:
			seen_ids[iid] = true
			unidentified.append(it)
	var dlg := GameDialog.create("Identify Which?", Vector2i(960, 1200))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 8)
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


func _on_identify_pick(id: String, dlg: GameDialog) -> void:
	# Armour egos are identified by the ego key, not the item id, so the
	# picker resolves which path to use based on whether any inventory
	# row under this id carries an ego.
	GameManager.identify(id)
	if player != null:
		for it in player.get_items():
			if String(it.get("id", "")) != id:
				continue
			var ego: String = String(it.get("ego", ""))
			if ego != "":
				GameManager.identify_armor_ego(ego)
			break
	dlg.close()


## Scroll of Enchant Weapon / Armour — pops a picker listing every
## weapon (or every armor piece) the player has, equipped or in the
## bag. Tapping one bumps its enchant `plus` by 1.
func _on_enchant_one_requested(kind: String) -> void:
	if player == null:
		return
	_close_all_dialogs()
	var title: String = "Enchant Which Weapon?" if kind == "weapon" else "Enchant Which Armour?"
	var dlg := GameDialog.create(title, Vector2i(960, 1200))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 8)
	var prompt := Label.new()
	prompt.add_theme_font_size_override("font_size", 40)
	vb.add_child(prompt)

	if kind == "weapon":
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


func _make_enchant_btn(text: String, dlg: GameDialog,
		on_pick: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 80)
	btn.add_theme_font_size_override("font_size", 38)
	btn.pressed.connect(func():
		on_pick.call()
		dlg.close())
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
	# Persist the richer run summary for the high-score board. record_run_end
	# only tracked best_depth + total_runs; this gives us the roster the
	# main menu can display.
	if meta != null and meta.has_method("record_run_history"):
		meta.record_run_history({
			"race": player.race_res.display_name if player and player.race_res else "",
			"job":  player.job_res.display_name if player and player.job_res else "",
			"god":  player.current_god if player else "",
			"level": player.level if player else 0,
			"depth": depth_reached,
			"branch": GameManager.current_branch,
			"turns": TurnManager.turn_number,
			"kills": kill_count,
			"victory": victory,
			"killer": killer,
			"timestamp": Time.get_unix_time_from_system(),
		})
	GameManager.end_run(victory)
	# DCSS morgue dump — write a text record of the run to user:// so the
	# player can review what happened after the result screen closes.
	# Safely best-effort: file failures don't block the result screen.
	_write_morgue_dump(victory, killer, depth_reached)
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


## DCSS morgue-style death log. Dumps stats, skills, equipment, kills,
## resists and cause of death to user://morgues/morgue-<stamp>.txt so
## the player (and post-hoc bug-hunts) have a record. Best-effort —
## never raises; a file-write failure just logs a warning.
func _write_morgue_dump(victory: bool, killer: String, depth: int) -> void:
	if player == null:
		return
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("morgues"):
		dir.make_dir("morgues")
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-")
	var path: String = "user://morgues/morgue-%s.txt" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("morgue dump: couldn't open %s" % path)
		return
	var race_name: String = player.race_res.display_name if player.race_res else "?"
	var job_name: String = player.job_res.display_name if player.job_res else "?"
	var god_name: String = "Unaligned"
	if player.current_god != "":
		god_name = String(GodRegistry.get_info(player.current_god).get("title", player.current_god))
	f.store_line("=== PROJ_D Morgue ===")
	f.store_line("Timestamp : %s" % stamp)
	f.store_line("Outcome   : %s" % ("VICTORY" if victory else "DEATH"))
	if not victory and killer != "":
		f.store_line("Slain by  : %s" % killer)
	f.store_line("")
	f.store_line("Character : %s %s (Lv %d)" % [race_name, job_name, player.level])
	f.store_line("God       : %s  (piety %d)" % [god_name, int(player.piety)])
	f.store_line("Depth     : %s %d" % [
			BranchRegistry.display_name(GameManager.current_branch), depth])
	f.store_line("Turns     : %d" % TurnManager.turn_number)
	f.store_line("Kills     : %d" % kill_count)
	var s = player.stats
	if s != null:
		f.store_line("")
		f.store_line("HP %d/%d    MP %d/%d" % [s.HP, s.hp_max, s.MP, s.mp_max])
		f.store_line("STR %d  DEX %d  INT %d" % [s.STR, s.DEX, s.INT])
		f.store_line("AC %d  EV %d  SH %d  WL %d" % [s.AC, s.EV, s.SH, s.WL])
	if player.equipped_weapon_id != "":
		f.store_line("")
		f.store_line("Weapon : %s +%d" % [
				WeaponRegistry.display_name_for(player.equipped_weapon_id),
				player.equipped_weapon_plus])
	if not player.equipped_armor.is_empty():
		f.store_line("Armor  :")
		for slot in player.equipped_armor.keys():
			var a: Dictionary = player.equipped_armor[slot]
			f.store_line("  %s: %s +%d" % [
					String(slot), String(a.get("name", "?")),
					int(a.get("plus", 0))])
	f.store_line("")
	f.store_line("Resistances: rF %d  rC %d  rElec %d  rPois %d  rN %d" % [
			player.get_resist("fire"), player.get_resist("cold"),
			player.get_resist("elec"), player.get_resist("poison"),
			player.get_resist("neg")])
	if player.learned_spells.size() > 0:
		f.store_line("")
		f.store_line("Known spells (%d / %d memory):" % [
				player.used_spell_levels(), player.max_spell_levels()])
		for sp in player.learned_spells:
			f.store_line("  %s" % SpellRegistry.get_spell(String(sp)).get("name", sp))
	f.close()
	CombatLog.add("Morgue saved to %s" % path)


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
	_open_skills_dialog("active")


func _open_skills_dialog(category: String = "active") -> void:
	if player == null:
		return

	var dlg := GameDialog.create("Skills", Vector2i(960, 1800))
	add_child(dlg)
	_skills_dlg = dlg
	dlg.set_on_close(func():
		if _skills_dlg == dlg: _skills_dlg = null)

	var vb: VBoxContainer = dlg.body()

	var hint := UICards.dim_hint("Tap name to toggle.  Long-press for details.")
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hint)

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	tabs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cat in _SKILL_CATEGORIES:
		var tb := Button.new()
		tb.text = _SKILL_CATEGORY_LABELS.get(cat, cat)
		tb.custom_minimum_size = Vector2(0, 80)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Tab buttons are narrow columns — clip text + smaller font so
		# the widest label ("DEFENSE") doesn't push the HBox wider than
		# the dialog's viewport-derived width, which would drag the
		# whole Window out past the 92% cap.
		tb.clip_contents = true
		tb.toggle_mode = true
		tb.button_pressed = (cat == category)
		tb.add_theme_font_size_override("font_size", 32)
		tb.pressed.connect(_on_skills_tab.bind(cat, dlg))
		tabs_hbox.add_child(tb)
	vb.add_child(tabs_hbox)

	# Horizontal swipe on the dialog body cycles category tabs (mirrors the
	# bag screen). Threshold + axis check come from the shared helper.
	_skills_swipe_dlg = dlg
	_skills_swipe_category = category
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.gui_input.connect(_on_skills_swipe_input)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	vb.add_child(rows)

	var state: Dictionary = {}
	if "skill_state" in player and player.skill_state is Dictionary:
		state = player.skill_state

	if category == "active":
		_build_active_tab(rows, state)
	else:
		var any_shown: bool = false
		for skill_id in SkillSystem.SKILL_IDS:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			if cat_id != category:
				continue
			rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))
			any_shown = true
		if not any_shown:
			var empty_hint := UICards.dim_hint("No skills in this category.")
			empty_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rows.add_child(empty_hint)


## Build the ACTIVE tab body: split into "Training" (currently enabled)
## and "Learned" (level>0 but not trained) sub-sections so toggling a
## skill reshuffles it between the two lists.
func _build_active_tab(rows: VBoxContainer, state: Dictionary) -> void:
	var training_ids: Array = []
	var learned_ids: Array = []
	for skill_id in SkillSystem.SKILL_IDS:
		var entry: Dictionary = state.get(skill_id, {})
		var is_training: bool = bool(entry.get("training", false))
		var lv: int = int(entry.get("level", 0))
		if is_training:
			training_ids.append(skill_id)
		elif lv > 0:
			learned_ids.append(skill_id)
	if training_ids.is_empty() and learned_ids.is_empty():
		var hint := UICards.dim_hint("No skills trained yet.\nEnable skills in the other tabs.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(hint)
		return
	if not training_ids.is_empty():
		rows.add_child(UICards.section_header("Training"))
		for skill_id in training_ids:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))
	if not learned_ids.is_empty():
		rows.add_child(UICards.section_header("Learned"))
		for skill_id in learned_ids:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))


func _on_skills_tab(cat: String, dlg: GameDialog) -> void:
	dlg.close()
	_open_skills_dialog(cat)


func _on_skill_training_toggled(pressed: bool, skill_id: String) -> void:
	if skill_system == null or player == null:
		return
	skill_system.set_training(player, skill_id, pressed)
	# When the ACTIVE tab is currently open, toggling a skill moves it
	# between Training/Learned sub-sections — rebuild the dialog so the
	# row reshuffles in place.
	if _skills_swipe_category == "active" and _skills_dlg != null and is_instance_valid(_skills_dlg):
		_skills_dlg.close()
		_open_skills_dialog("active")


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
	"unarmed_combat": "Fist DMG +1 per 3 lv + faster swings",
	"fighting": "Melee DMG × 1 + lv/30, HP += XL × lv / 14",
	"armour": "Body AC × (1 + lv/10), body-armour EV penalty scaled down",
	"dodging": "EV += (dodging × 10 × DEX × 8) / (2000 − 100 × size)",
	"shields": "SH = base×2 + plus×2 + lv×(base×2+13)/10; EV penalty ↓",
	"spellcasting": "Max memorised spells += lv/3, fail −3%/lv, MP += lv/2",
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
	"shapeshifting": "Form unarmed DMG + AC scale with lv (×0.1/lv on scaling forms)",
}

func _build_skill_row(skill_id: String, category: String, entry: Dictionary) -> Control:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 88)
	row.add_theme_constant_override("separation", 8)

	# Skill-name button replaces the old checkbox + label pair:
	#   tap  → toggle training on/off
	#   long-press → show the description popup
	# Training status is indicated by colour (green = training, grey =
	# idle) and a leading ▶ bullet.
	var is_training_now: bool = bool(entry.get("training", false))
	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.text = ("▶ " if is_training_now else "  ") \
			+ String(SkillRow.SKILL_NAMES.get(skill_id, skill_id))
	name_btn.add_theme_font_size_override("font_size", 48)
	name_btn.add_theme_color_override("font_color",
			Color(0.55, 1.00, 0.55) if is_training_now \
			else Color(0.80, 0.80, 0.85))
	# Per-button state for long-press detection. Stored via set_meta so
	# the lambdas below share it without capturing a mutable closure var.
	name_btn.set_meta("_press_start_ms", -1)
	name_btn.set_meta("_long_press_fired", false)
	name_btn.gui_input.connect(_on_skill_button_input.bind(name_btn, skill_id))
	row.add_child(name_btn)

	var level: int = int(entry.get("level", 0))
	var xp: float = float(entry.get("xp", 0.0))
	var need: float = SkillSystem.xp_for_level(level + 1)
	var lv_lab := Label.new()
	if level >= SkillSystem.MAX_LEVEL:
		lv_lab.text = "MAX"
	else:
		lv_lab.text = "Lv.%d" % level
	lv_lab.add_theme_font_size_override("font_size", 48)
	lv_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(lv_lab)

	var apt_lab := Label.new()
	apt_lab.text = _format_aptitude(skill_id)
	apt_lab.add_theme_font_size_override("font_size", 48)
	apt_lab.custom_minimum_size = Vector2(110, 0)
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

	# Terse under-row info — just XP progress + split ratio. The full
	# description now lives behind the long-press popup to keep the
	# Skills list scannable.
	var is_training: bool = bool(entry.get("training", false))
	var parts: Array = []
	if (is_training or level > 0) and level < SkillSystem.MAX_LEVEL:
		parts.append("XP %d/%d" % [int(xp), int(need)])
	if not skill_system.auto_training and is_training:
		var trained_count: int = _count_trained_skills()
		if trained_count > 0:
			parts.append("%d%% XP" % int(100.0 / trained_count))
	if not parts.is_empty():
		var info_line := Label.new()
		info_line.text = "  |  ".join(PackedStringArray(parts))
		info_line.add_theme_font_size_override("font_size", 40)
		info_line.modulate = Color(0.65, 0.80, 0.65)
		outer.add_child(info_line)

	outer.add_child(HSeparator.new())
	return outer


## Long-press-aware input handler for skill rows. A tap toggles the
## skill's training flag; holding past 400ms opens the description
## popup instead. Implemented via press timestamp recorded on
## button-down, checked on button-up + a periodic poll during the
## gui_input stream so the popup fires while the finger is still on
## the button.
const _SKILL_LONG_PRESS_MS: int = 400

func _on_skill_button_input(event: InputEvent, btn: Button, skill_id: String) -> void:
	var is_down := false
	var is_up := false
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		is_down = event.pressed
		is_up = not event.pressed
	elif event is InputEventScreenTouch:
		is_down = event.pressed
		is_up = not event.pressed
	else:
		return
	if is_down:
		btn.set_meta("_press_start_ms", Time.get_ticks_msec())
		btn.set_meta("_long_press_fired", false)
		# Defer a long-press check — if the user is still holding after
		# _SKILL_LONG_PRESS_MS, trigger the description popup. Using a
		# named method via Callable.bind instead of an inline multi-line
		# lambda so the parser can't choke on the closing paren position.
		var press_id: int = Time.get_ticks_msec()
		btn.set_meta("_press_id", press_id)
		var timer: SceneTreeTimer = get_tree().create_timer(_SKILL_LONG_PRESS_MS / 1000.0)
		timer.timeout.connect(_skill_long_press_check.bind(btn, press_id, skill_id))
	elif is_up:
		var start_ms: int = int(btn.get_meta("_press_start_ms", -1))
		var long_fired: bool = bool(btn.get_meta("_long_press_fired", false))
		btn.set_meta("_press_start_ms", -1)
		if long_fired:
			return  # popup already shown; don't toggle training
		if start_ms > 0:
			var held_ms: int = Time.get_ticks_msec() - start_ms
			if held_ms < _SKILL_LONG_PRESS_MS:
				# Short tap — flip training state. Reuse the existing
				# handler so the "ACTIVE tab rebuild" path fires.
				var currently: bool = false
				if "skill_state" in player:
					var st: Dictionary = player.skill_state.get(skill_id, {})
					currently = bool(st.get("training", false))
				_on_skill_training_toggled(not currently, skill_id)


## Deferred long-press check. Fires after _SKILL_LONG_PRESS_MS if the
## finger is still on the skill button (matches the press_id the
## button-down captured + the _press_start_ms flag hasn't been cleared
## by button-up). Named function so the gui_input handler doesn't need
## a multi-line inline lambda.
func _skill_long_press_check(btn: Button, press_id: int, skill_id: String) -> void:
	if not is_instance_valid(btn):
		return
	if int(btn.get_meta("_press_id", -1)) != press_id:
		return
	if int(btn.get_meta("_press_start_ms", -1)) <= 0:
		return
	btn.set_meta("_long_press_fired", true)
	_show_skill_desc_popup(skill_id)


## Description popup for a single skill. Opens on long-press of the
## name button in the Skills dialog. Lightweight — title + desc text.
func _show_skill_desc_popup(skill_id: String) -> void:
	var name_s: String = String(SkillRow.SKILL_NAMES.get(skill_id, skill_id))
	var dlg := GameDialog.create(name_s, Vector2i(960, 800))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)
	var apt_val: int = _player_aptitude(skill_id)
	var apt_str: String = "+%d" % apt_val if apt_val > 0 else str(apt_val)
	vb.add_child(UICards.section_header("%s  (aptitude %s)" % [name_s, apt_str]))
	var desc := Label.new()
	desc.text = String(_SKILL_DESCS.get(skill_id, "No description available."))
	desc.add_theme_font_size_override("font_size", 38)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.modulate = Color(0.88, 0.88, 0.95)
	vb.add_child(desc)
	# Progress — current level + XP.
	var lv: int = 0
	var xp: float = 0.0
	if "skill_state" in player:
		var st: Dictionary = player.skill_state.get(skill_id, {})
		lv = int(st.get("level", 0))
		xp = float(st.get("xp", 0.0))
	var need: float = SkillSystem.xp_for_level(lv + 1)
	vb.add_child(UICards.section_header("Progress"))
	var prog := Label.new()
	prog.text = "Level %d  ·  %d / %d XP" % [lv, int(xp), int(need)]
	prog.add_theme_font_size_override("font_size", 40)
	vb.add_child(prog)
	# Current-level effects. Each skill rolls its own formula —
	# _skill_effects_at_level returns an array of "label: value" lines
	# so the player sees exactly what their current investment buys.
	var effect_lines: Array = _skill_effects_at_level(skill_id, lv)
	if not effect_lines.is_empty():
		vb.add_child(UICards.section_header("At Lv.%d" % lv))
		for line_s in effect_lines:
			var eff_lbl := Label.new()
			eff_lbl.text = String(line_s)
			eff_lbl.add_theme_font_size_override("font_size", 34)
			eff_lbl.modulate = Color(0.85, 0.92, 0.75)
			eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			vb.add_child(eff_lbl)


## Per-skill "what does this do at Lv.N" summary for the long-press
## popup. Returns an array of strings, one effect per line. Numbers
## pull from the same formulas the combat / gear / skill pipelines
## actually use so what you see is what you get.
func _skill_effects_at_level(skill_id: String, lv: int) -> Array:
	var out: Array = []
	# Weapon skills (all route through the same DCSS melee pipeline).
	var weapon_skills: Array = ["axe", "short_blade", "long_blade", "mace",
			"polearm", "staff", "bow", "crossbow", "sling", "throwing",
			"unarmed_combat"]
	if weapon_skills.has(skill_id):
		# DCSS: damage × random2(1 + lv*100) / 2500 averages ~lv/50.
		# Also: attack_delay -= min(lv, 10) * 10 / 20 ticks (half at skill 10).
		var dmg_avg_pct: int = lv * 2  # rough: ~2% per skill level averaged
		var delay_cut: int = mini(lv, 10) * 10 / 20  # in 0.1-tick units
		out.append("Damage: up to +%d%% per swing (average +%d%%)" % \
				[lv * 4, dmg_avg_pct])
		out.append("Attack delay: −%.1f ticks (mindelay at Lv.10)" % (float(delay_cut) / 10.0))
		out.append("To-hit: random2(%d+1)/100 roll added" % (lv * 100))
		if skill_id == "unarmed_combat":
			out.append("Fists: +%d flat damage (lv/3)" % (lv / 3))
		return out
	match skill_id:
		"fighting":
			# HP formula: xl * fighting * 5 / 70 + (fighting * 3 + 1) / 2.
			var xl: int = player.level if player != null else 1
			var hp_gain: int = xl * lv * 5 / 70 + (lv * 3 + 1) / 2
			out.append("HP: +%d (XL %d × %d × 5 / 70 + constant)" % [hp_gain, xl, lv])
			out.append("Damage: random2(%d+1)/3000 multiplier on every swing" % (lv * 100))
			return out
		"armour":
			# Body AC × (1 + lv/10). Also body-armour EV penalty reduction.
			out.append("Body AC × %.2f (base AC multiplied by 1 + lv/10)" % \
					(1.0 + float(lv) / 10.0))
			var reduce_pct: int = mini(lv * 10, 100)  # 100% at lv10
			out.append("Body-armour EV penalty: %d%% mitigated" % reduce_pct)
			return out
		"dodging":
			# (800 + lv*10*dex*8) / (20 - size) / 100 scaled EV.
			var dex: int = int(player.stats.DEX) if player != null and player.stats != null else 10
			var ev_gain: int = lv * 10 * dex * 8 / 2000
			out.append("EV: +%d (lv × DEX × 4 / 100)" % ev_gain)
			out.append("Formula: (800 + lv × 10 × DEX × 8) / (20 − size) / 100")
			return out
		"shields":
			# SH = base*2 + plus*2 + lv*(base*2+13)/10.
			var sh_buckler: int = 6 + lv * 19 / 10
			var sh_kite: int = 16 + lv * 29 / 10
			var sh_tower: int = 26 + lv * 39 / 10
			out.append("SH (buckler): %d" % sh_buckler)
			out.append("SH (kite):    %d" % sh_kite)
			out.append("SH (tower):   %d" % sh_tower)
			out.append("Shield EV penalty: %d%% mitigated" % mini(lv * 4, 100))
			return out
		"stealth":
			# player_stealth = dex*3 + lv*15 - armour_pen² * 2/3.
			var dex2: int = int(player.stats.DEX) if player != null and player.stats != null else 10
			out.append("Stealth score: DEX×3 + lv×15 = %d + %d = %d" % \
					[dex2 * 3, lv * 15, dex2 * 3 + lv * 15])
			out.append("Monster wake: harder with higher stealth")
			out.append("Stab damage: ×(lv+10)/10 on sleeping/paralysed foes")
			return out
		"spellcasting":
			# Max spell levels: XL/2 + lv/3.
			var xl2: int = player.level if player != null else 1
			var max_mem: int = mini(xl2, 27) / 2 + lv / 3
			out.append("Max memorised spell levels: %d (XL/2 + lv/3)" % max_mem)
			out.append("MP bonus: scales with XL + lv (half of highest school)")
			out.append("Spell fail: polynomial reduction (−3% per lv approx)")
			return out
		"conjurations", "fire", "cold", "earth", "air", "necromancy", \
				"hexes", "translocations", "summonings":
			# Spell power averages across schools. Each level adds ~2 to
			# a one-school spell's power (DCSS calc_spell_power).
			out.append("Spell power: +%d to %s-school spells" % [lv * 2, skill_id])
			out.append("Multi-school spells: uses the AVERAGE of matched schools")
			out.append("Failure rate: min(matched school skills) lowers it")
			return out
		"evocations":
			# Wand power = 15 + lv*7.
			var wand_pow: int = 15 + lv * 7
			out.append("Wand power: %d (base 15 + lv × 7)" % wand_pow)
			out.append("Evocable range / duration scales proportionally")
			return out
		"shapeshifting":
			# Form unarmed += unarmed_scaling × lv / 10; same for ac.
			out.append("Form unarmed bonus: + (form.unarmed_scaling × %d) / 10" % lv)
			out.append("Form AC bonus: + (form.ac_scaling × %d) / 10" % lv)
			out.append("Dragon (scale 10): +%d unarmed, (scale 6 ac): +%d AC" % \
					[lv, lv * 6 / 10])
			return out
		"essence_channeling":
			# Custom — essence active-ability power scales with level.
			out.append("Essence active power: +%d%% (lv × 5)" % (lv * 5))
			out.append("Essence cooldowns: −%d%% (lv × 2)" % mini(lv * 2, 50))
			return out
	return out


## Current aptitude integer for `skill_id` pulled from the player's race
## resource. 0 when not set (baseline human behaviour).
func _player_aptitude(skill_id: String) -> int:
	if player == null or player.race_res == null:
		return 0
	var apts: Dictionary = player.race_res.skill_aptitudes
	# DCSS aptitude JSON uses "unarmed" as the key; our internal skill id
	# is "unarmed_combat" (matches SK_UNARMED_COMBAT). Alias-lookup so
	# species-authored aptitudes still apply.
	if skill_id == "unarmed_combat" and not apts.has(skill_id):
		return int(apts.get("unarmed", 0))
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
	if player == null:
		return
	var dlg := GameDialog.create("Magic", Vector2i(960, 1800))
	add_child(dlg)
	_magic_dlg = dlg
	dlg.set_on_close(func():
		if _magic_dlg == dlg: _magic_dlg = null)
	var vb: VBoxContainer = dlg.body()

	# MP + memory readouts sit as the first body rows so they're visible
	# over the scrollable spell list. DCSS shows spell-levels used/cap
	# right under MP — essential for knowing how many more spells you
	# can learn before Spellcasting ticks up.
	var cur_mp: int = player.stats.MP if player.stats != null else 0
	var max_mp: int = player.stats.mp_max if player.stats != null else 0
	var mp_lab := Label.new()
	mp_lab.text = "MP  %d / %d" % [cur_mp, max_mp]
	mp_lab.add_theme_font_size_override("font_size", 48)
	mp_lab.modulate = Color(0.45, 0.7, 1.0)
	vb.add_child(mp_lab)

	var used_lv: int = player.used_spell_levels() if player.has_method("used_spell_levels") else 0
	var cap_lv: int = player.max_spell_levels() if player.has_method("max_spell_levels") else 0
	var mem_lab := Label.new()
	mem_lab.text = "Memory  %d / %d spell levels" % [used_lv, cap_lv]
	mem_lab.add_theme_font_size_override("font_size", 40)
	mem_lab.modulate = Color(0.85, 0.80, 0.35) if used_lv < cap_lv \
			else Color(0.95, 0.45, 0.35)
	vb.add_child(mem_lab)

	vb.add_child(UICards.section_header("Known Spells"))

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	vb.add_child(rows)

	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_system)
	if known.is_empty():
		var hint := UICards.dim_hint("No spells known.\nRead spellbooks or pick a magic job to learn spells.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(hint)
	else:
		for spell_id in known:
			rows.add_child(_build_magic_row(spell_id, dlg))


func _build_magic_row(spell_id: String, dlg: GameDialog) -> Control:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return Control.new()

	# Outer vbox stacks (schools-pill-row, main-info-row) so pills sit
	# above the name/cost text without cramping the cast-button column.
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)

	# Row 1 — school pills. Each school gets a compact 3-letter pill
	# coloured to match UICards.SCHOOL_COLOURS.
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 4)
	for school in SpellRegistry.get_schools(spell_id):
		var tag: String = String(school).substr(0, 3).to_upper()
		pill_row.add_child(UICards.pill(tag, UICards.school_colour(String(school))))
	# Trailing spacer so pills hug the left edge even on short rows.
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill_row.add_child(spacer)
	outer.add_child(pill_row)

	# Row 2 — name/cost on the left, Pow/Fail accent + Cast/QSlot on the right.
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 8)

	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Clip the name button so long spell names ("Lehudib's Crystal
	# Spear [8 MP] range 8") don't demand width beyond the dialog cap.
	name_btn.clip_contents = true
	var spell_name: String = String(info.get("name", spell_id))
	var range_txt: String = ""
	if int(info.get("range", 0)) > 0:
		range_txt = "  r%d" % int(info.get("range", 0))
	name_btn.text = "%s  [%d MP]%s" % [spell_name, int(info.get("mp", 0)), range_txt]
	name_btn.add_theme_font_size_override("font_size", 36)
	name_btn.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	name_btn.pressed.connect(_show_spell_info.bind(spell_id))
	row.add_child(name_btn)

	# Power + Failure accented in gold so they stand out against the
	# spell-name colour. Only render failure when it's non-zero to keep
	# low-risk rows quieter.
	var spell_pow: int = SpellRegistry.calc_spell_power(spell_id, player)
	var fail_p: int = SpellRegistry.failure_rate(spell_id, player)
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 2)
	stats_col.custom_minimum_size = Vector2(110, 0)
	stats_col.add_child(UICards.accent_value("Pow %d" % spell_pow, 28))
	if fail_p > 0:
		stats_col.add_child(UICards.accent_value("Fail %d%%" % fail_p, 28))
	row.add_child(stats_col)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)

	var cast_btn := Button.new()
	cast_btn.text = "Cast"
	cast_btn.custom_minimum_size = Vector2(110, 58)
	cast_btn.add_theme_font_size_override("font_size", 32)
	cast_btn.disabled = (player.stats == null or player.stats.MP < int(info.get("mp", 1)))
	var targeting_type: String = String(info.get("targeting", "single"))
	if targeting_type == "self":
		cast_btn.pressed.connect(_on_cast_pressed.bind(spell_id, dlg))
	else:
		cast_btn.pressed.connect(_on_cast_with_targeting.bind(spell_id, dlg))
	btns.add_child(cast_btn)

	var qs_btn := Button.new()
	qs_btn.text = "QSlot"
	qs_btn.custom_minimum_size = Vector2(110, 48)
	qs_btn.add_theme_font_size_override("font_size", 30)
	qs_btn.pressed.connect(_assign_spell_quickslot.bind(spell_id, dlg))
	btns.add_child(qs_btn)

	row.add_child(btns)
	outer.add_child(row)
	return outer


func _show_spell_info(spell_id: String) -> void:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return
	var dlg := GameDialog.create(String(info.get("name", spell_id)), Vector2i(960, 1100))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)
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
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lab)


func _on_cast_with_targeting(spell_id: String, dlg: GameDialog) -> void:
	dlg.close()
	_targeting_spell = spell_id
	_pending_area_target = Vector2i(-1, -1)
	if touch_input != null:
		touch_input.targeting_mode = true
	_show_targeting_hint()


## Player emitted wand_target_requested — kick the same 2-tap tile
## targeting flow the spells use, but stash the inventory index so the
## confirm tap can call Player.fire_wand_at with the chosen creature.
func _on_wand_target_requested(item_index: int) -> void:
	if player == null:
		return
	if item_index < 0 or item_index >= player.get_items().size():
		return
	_targeting_wand_index = item_index
	_targeting_wand_id = String(player.get_items()[item_index].get("id", ""))
	_pending_area_target = Vector2i(-1, -1)
	if touch_input != null:
		touch_input.targeting_mode = true
	CombatLog.add("Tap an enemy to evoke, tap again to confirm.")


func _on_target_selected(pos: Vector2i) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	# Ranged-fire branch — when the player triggered "fire", the tap
	# resolves a bow shot instead of a spell. Early-out so the spell
	# targeting path below doesn't also run.
	if _ranged_targeting:
		if dmap != null:
			dmap.danger_tiles.clear()
			dmap.aoe_preview_tiles.clear()
			dmap.beam_preview_tiles.clear()
			dmap.queue_redraw()
		_ranged_targeting = false
		if touch_input != null:
			touch_input.targeting_mode = false
		if player != null:
			player.try_ranged_attack(pos)
		return
	# ----- Wand targeting (2-tap confirm) ------------------------------
	if _targeting_wand_index >= 0:
		var wand_info: Dictionary = WandRegistry.get_info(_targeting_wand_id)
		var wand_kind: String = String(wand_info.get("kind", "direct"))
		# Dig wands: tapped tile is a DIRECTION hint. We carve a line of
		# walls from the player toward that tile up to 4 cells deep.
		# Two-tap same as damage wands — first tap paints the carve
		# preview, second tap commits.
		if wand_kind == "utility_dig":
			var dig_cells: Array[Vector2i] = _wand_dig_line(pos)
			if dig_cells.is_empty():
				CombatLog.add("Nothing there to dig.")
				_targeting_wand_index = -1
				_targeting_wand_id = ""
				_pending_area_target = Vector2i(-1, -1)
				if dmap != null:
					dmap.aoe_preview_tiles.clear()
					dmap.queue_redraw()
				if touch_input != null:
					touch_input.targeting_mode = false
				return
			if _pending_area_target == pos:
				var dig_idx: int = _targeting_wand_index
				_targeting_wand_index = -1
				_targeting_wand_id = ""
				_pending_area_target = Vector2i(-1, -1)
				if dmap != null:
					dmap.aoe_preview_tiles.clear()
					dmap.queue_redraw()
				if touch_input != null:
					touch_input.targeting_mode = false
				_apply_wand_dig(dig_idx, dig_cells)
				TurnManager.end_player_turn()
				return
			_pending_area_target = pos
			if dmap != null:
				dmap.aoe_preview_tiles = dig_cells
				dmap.beam_preview_tiles.clear()
				dmap.danger_tiles.clear()
				dmap.queue_redraw()
			CombatLog.add("Tap again to carve through the wall.")
			return
		var wtm: Monster = null
		for m in get_tree().get_nodes_in_group("monsters"):
			if is_instance_valid(m) and m is Monster and m.is_alive and m.grid_pos == pos:
				wtm = m
				break
		if wtm == null:
			if dmap != null:
				dmap.beam_preview_tiles.clear()
				dmap.danger_tiles.clear()
				dmap.queue_redraw()
			CombatLog.add("Wand targeting cancelled.")
			_targeting_wand_index = -1
			_targeting_wand_id = ""
			_pending_area_target = Vector2i(-1, -1)
			if touch_input != null:
				touch_input.targeting_mode = false
			return
		if dmap != null and not dmap.is_tile_visible(wtm.grid_pos):
			CombatLog.add("Your line of sight is blocked.")
			return
		if _pending_area_target == pos:
			var fire_idx: int = _targeting_wand_index
			_targeting_wand_index = -1
			_targeting_wand_id = ""
			_pending_area_target = Vector2i(-1, -1)
			if dmap != null:
				dmap.beam_preview_tiles.clear()
				dmap.danger_tiles.clear()
				dmap.queue_redraw()
			if touch_input != null:
				touch_input.targeting_mode = false
			if player.fire_wand_at(fire_idx, wtm):
				TurnManager.end_player_turn()
			return
		_pending_area_target = pos
		_repaint_beam_preview(wtm, 8)
		CombatLog.add("Tap again to fire the wand.")
		return
	if _targeting_spell == "":
		if dmap != null:
			dmap.danger_tiles.clear()
			dmap.aoe_preview_tiles.clear()
			dmap.beam_preview_tiles.clear()
			dmap.queue_redraw()
		return
	var info_for_range: Dictionary = SpellRegistry.get_spell(_targeting_spell)
	var max_range: int = int(info_for_range.get("range", 99))
	var d: int = max(abs(pos.x - player.grid_pos.x), abs(pos.y - player.grid_pos.y))
	var targeting_kind: String = String(info_for_range.get("targeting", "single"))

	# ----- 2-tap confirm flow for area spells ---------------------------
	# First tap picks the blast center and paints the AoE radius; a
	# second tap on the same tile commits. Different tile → move the
	# preview. Out-of-range taps are silently rejected so the player
	# can adjust without losing the pending state.
	if targeting_kind == "area":
		if d > max_range:
			CombatLog.add("Out of range (%d > %d). Tap a closer tile." % [d, max_range])
			return
		if _pending_area_target == pos:
			var spell_id_a: String = _targeting_spell
			_targeting_spell = ""
			_pending_area_target = Vector2i(-1, -1)
			if dmap != null:
				dmap.aoe_preview_tiles.clear()
				dmap.danger_tiles.clear()
				dmap.queue_redraw()
			_execute_targeted_cast(spell_id_a, pos)
			return
		# Move the preview to the new tap location. Keep targeting mode
		# active so the next tap in the same spot confirms.
		_pending_area_target = pos
		_repaint_area_preview(pos)
		CombatLog.add("Tap again to cast %s." % String(info_for_range.get("name",
				_targeting_spell)))
		return

	# ----- Single-target 2-tap confirm ---------------------------------
	# Matches the area flow: first tap on a visible enemy paints the
	# beam path from player to that target, second tap on the same
	# enemy fires. Moving the tap repaints the beam onto the new
	# target. Single-target spells still require a creature (tapping
	# empty floor cancels), so the beam only starts tracking once the
	# player has actually selected an enemy.
	var target_monster: Monster = null
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster and m.is_alive and m.grid_pos == pos:
			target_monster = m
			break
	if target_monster == null:
		if dmap != null:
			dmap.danger_tiles.clear()
			dmap.aoe_preview_tiles.clear()
			dmap.beam_preview_tiles.clear()
			dmap.queue_redraw()
		CombatLog.add("Targeting cancelled.")
		_targeting_spell = ""
		_pending_area_target = Vector2i(-1, -1)
		return
	if dmap != null and not dmap.is_tile_visible(target_monster.grid_pos):
		CombatLog.add("Your line of sight is blocked.")
		return
	if d > max_range:
		CombatLog.add("Target is out of range (%d > %d). Tap a closer enemy." \
				% [d, max_range])
		return
	if _pending_area_target == pos:
		var spell_id: String = _targeting_spell
		_targeting_spell = ""
		_pending_area_target = Vector2i(-1, -1)
		if dmap != null:
			dmap.danger_tiles.clear()
			dmap.aoe_preview_tiles.clear()
			dmap.beam_preview_tiles.clear()
			dmap.queue_redraw()
		_execute_targeted_cast(spell_id, target_monster)
		return
	_pending_area_target = pos
	_repaint_beam_preview(target_monster, max_range)
	CombatLog.add("Tap again to cast %s." % String(info_for_range.get("name",
			_targeting_spell)))


## Paint the AoE tiles around the pending blast center so the 2-tap
## area-spell UX shows exactly which tiles will be hit before commit.
## Keeps the usual enemy highlights so the player can see who's inside
## the radius.
func _repaint_area_preview(center: Vector2i) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or _targeting_spell == "":
		return
	var info: Dictionary = SpellRegistry.get_spell(_targeting_spell)
	var aoe_radius: int = int(info.get("radius", 1))
	var preview: Array[Vector2i] = []
	for dy in range(-aoe_radius, aoe_radius + 1):
		for dx in range(-aoe_radius, aoe_radius + 1):
			if maxi(absi(dx), absi(dy)) > aoe_radius:
				continue
			preview.append(Vector2i(center.x + dx, center.y + dy))
	dmap.aoe_preview_tiles = preview
	dmap.beam_preview_tiles.clear()
	# Keep enemy highlights so the player can see which foes sit in the
	# radius about to be confirmed.
	var spell_range: int = int(info.get("range", 6))
	var enemies: Array[Vector2i] = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if not dmap.is_tile_visible(m.grid_pos):
			continue
		if player.grid_pos.distance_to(m.grid_pos) <= float(spell_range):
			enemies.append(m.grid_pos)
	dmap.danger_tiles = enemies
	dmap.queue_redraw()


## Walk a line from the player toward the target tile and return the
## up-to-4 cells that the Wand of Digging would carve. Stops at map
## edge or at CRYSTAL_WALL (indestructible rock). An empty result means
## the direction has no walls in reach — caller treats that as "nothing
## to dig" and cancels the targeting cleanly.
func _wand_dig_line(target_tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if player == null or generator == null:
		return out
	var dx: int = target_tile.x - player.grid_pos.x
	var dy: int = target_tile.y - player.grid_pos.y
	if dx == 0 and dy == 0:
		return out
	var step: Vector2i = Vector2i(
		0 if dx == 0 else (1 if dx > 0 else -1),
		0 if dy == 0 else (1 if dy > 0 else -1))
	var cur: Vector2i = player.grid_pos + step
	for _i in 4:
		if cur.x < 0 or cur.x >= DungeonGenerator.MAP_WIDTH:
			break
		if cur.y < 0 or cur.y >= DungeonGenerator.MAP_HEIGHT:
			break
		var t: int = generator.get_tile(cur)
		if t == DungeonGenerator.TileType.CRYSTAL_WALL:
			break
		if t == DungeonGenerator.TileType.WALL:
			out.append(cur)
		# Continue into the next cell even past floor — dig keeps going
		# until it hits the wall-chain limit (matches DCSS behaviour of
		# tunnelling straight through until the charge budget runs out).
		cur += step
	return out


## Convert the dig line to floor, spend the wand charge, identify it.
## Separate from _wand_dig_line so the preview path can compute without
## mutating anything.
func _apply_wand_dig(item_index: int, cells: Array[Vector2i]) -> void:
	if player == null or generator == null:
		return
	for c in cells:
		generator.map[c.x][c.y] = DungeonGenerator.TileType.FLOOR
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap != null:
		dmap.update_fov(player.grid_pos)
		dmap.queue_redraw()
	CombatLog.add("The wand tunnels through %d tiles of rock." % cells.size())
	var it: Dictionary = player.get_items()[item_index]
	var wand_id: String = String(it.get("id", ""))
	player._spend_wand_charge(item_index, wand_id)
	if GameManager != null:
		GameManager.identify(wand_id)


## Paint the single-target beam path so the 2-tap confirm flow shows
## exactly which line the zap will travel (including wall stops and
## monster interception). Mirrors _repaint_area_preview but uses a
## Beam.trace along the player → target ray.
func _repaint_beam_preview(target: Monster, spell_range: int) -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or target == null or player == null or _targeting_spell == "":
		return
	var opaque_cb: Callable = func(cell: Vector2i) -> int:
		return dmap._opaque_at(cell) if dmap != null else 0
	var mon_cb: Callable = func(_cell: Vector2i):
		return null
	var pierce: bool = Beam.should_pierce(_targeting_spell)
	var trace: Dictionary = Beam.trace(player.grid_pos, target.grid_pos,
			spell_range, pierce, opaque_cb, mon_cb)
	var cells: Array = trace.get("cells", [])
	var beam: Array[Vector2i] = []
	for c in cells:
		beam.append(c)
	dmap.beam_preview_tiles = beam
	dmap.aoe_preview_tiles.clear()
	dmap.danger_tiles = [target.grid_pos]
	dmap.queue_redraw()


func _show_targeting_hint() -> void:
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or player == null:
		return
	var info: Dictionary = SpellRegistry.get_spell(_targeting_spell)
	var spell_range: int = int(info.get("range", 6))
	var targeting_type: String = String(info.get("targeting", "single"))
	var aoe_radius: int = int(info.get("radius", 0))
	var targets: Array[Vector2i] = []
	var aoe_preview: Array[Vector2i] = []
	var beam_preview: Array[Vector2i] = []
	var seen_enemies: Array = []
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		if not dmap.is_tile_visible(m.grid_pos):
			continue
		if player.grid_pos.distance_to(m.grid_pos) <= float(spell_range):
			targets.append(m.grid_pos)
			seen_enemies.append(m)
	dmap.danger_tiles = targets
	# DCSS targeter preview — populate the AoE radius for area spells
	# and the beam path for single-target zaps, so the player can see
	# exactly which tiles would be hit before committing the tap.
	if targeting_type == "area" and aoe_radius > 0:
		var seen: Dictionary = {}
		for m in seen_enemies:
			var cx: int = m.grid_pos.x
			var cy: int = m.grid_pos.y
			for dy in range(-aoe_radius, aoe_radius + 1):
				for dx in range(-aoe_radius, aoe_radius + 1):
					if maxi(absi(dx), absi(dy)) > aoe_radius:
						continue
					var cell: Vector2i = Vector2i(cx + dx, cy + dy)
					if seen.has(cell):
						continue
					seen[cell] = true
					aoe_preview.append(cell)
	elif targeting_type == "single":
		# Beam preview: trace the line from player to each visible foe
		# so walls and allied blockers in the way are obvious.
		var opaque_cb: Callable = func(cell: Vector2i) -> int:
			return dmap._opaque_at(cell) if dmap != null else 0
		var mon_cb: Callable = func(_cell: Vector2i):
			return null  # preview doesn't need monster lookups; pierce is visual only
		var pierce: bool = Beam.should_pierce(_targeting_spell)
		var seen2: Dictionary = {}
		for m in seen_enemies:
			var trace: Dictionary = Beam.trace(player.grid_pos, m.grid_pos,
					spell_range, pierce, opaque_cb, mon_cb)
			for cell in trace.get("cells", []):
				if not seen2.has(cell):
					seen2[cell] = true
					beam_preview.append(cell)
	dmap.aoe_preview_tiles = aoe_preview
	dmap.beam_preview_tiles = beam_preview
	dmap.queue_redraw()
	var hint_msg: String
	if targeting_type == "area":
		hint_msg = "Tap a tile to aim %s. Tap again to confirm." \
				% String(info.get("name", _targeting_spell))
	else:
		hint_msg = "Tap an enemy to cast %s. Tap empty space to cancel." \
				% String(info.get("name", _targeting_spell))
	CombatLog.add(hint_msg)


func _execute_targeted_cast(spell_id: String, target) -> void:
	if player == null:
		return
	# `target` accepts either a Monster (single + area) or a Vector2i
	# (area-at-empty-tile path from _on_target_selected). Resolve both
	# to a grid_pos / world_pos pair so the damage loop works the same.
	var target_grid: Vector2i
	var target_world: Vector2
	if target is Vector2i:
		target_grid = target
		target_world = Vector2(target_grid.x * TILE_SIZE + TILE_SIZE / 2.0,
				target_grid.y * TILE_SIZE + TILE_SIZE / 2.0)
	elif target != null and "grid_pos" in target:
		target_grid = target.grid_pos
		target_world = target.position
	else:
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
			var dist: int = max(abs(m.grid_pos.x - target_grid.x), abs(m.grid_pos.y - target_grid.y))
			if dist > radius:
				continue
			var dmg: int = _spell_roll_dmg(spell_id, info, power)
			if dist > 0:
				dmg = max(1, dmg - dist * 3)
			hit_positions.append(m.position)
			m.take_damage(dmg, SpellRegistry.element_for(spell_id))
			total_dmg += dmg
			hits += 1
		SpellFX.cast_area(fx_layer, player.position, target_world, hit_positions, spell_color, float(radius) * float(TILE_SIZE) + float(TILE_SIZE) / 2.0, school)
		CombatLog.add("%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg])
		# Cloud residue (fireball/fire_storm/hailstorm) — same hook
		# that _cast_area_spell uses, so tapped-tile casts leave the
		# expected clouds behind.
		var cloud_residue: String = _spell_cloud_residue(spell_id)
		if cloud_residue != "" and GameManager != null:
			var dmap_c: DungeonMap = $DungeonLayer/DungeonMap
			CloudSystem.place_patch(GameManager.clouds, target_grid, cloud_residue, radius)
			if dmap_c != null:
				dmap_c.update_fov(player.grid_pos)
				dmap_c.queue_redraw()
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


func _assign_spell_quickslot(spell_id: String, dlg: GameDialog) -> void:
	if player == null:
		return
	for i in player.quickslot_ids.size():
		if player.quickslot_ids[i] == "":
			player.quickslot_ids[i] = "spell:" + spell_id
			player.quickslots_changed.emit()
			dlg.close()
			_on_magic_pressed()
			return
	for i in player.quickslot_ids.size():
		if player.quickslot_ids[i].begins_with("spell:"):
			player.quickslot_ids[i] = "spell:" + spell_id
			player.quickslots_changed.emit()
			dlg.close()
			_on_magic_pressed()
			return
	print("No empty quickslot.")


## ---- SPELL CASTING -------------------------------------------------------

## Builds the spell panel for the CAST tab of the skills dialog.
func _build_spell_panel(container: VBoxContainer, dlg: GameDialog) -> void:
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


func _on_cast_pressed(spell_id: String, dlg: GameDialog) -> void:
	dlg.close()
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
	# Resolve an explosion center. Prefer a monster so we auto-aim; fall
	# back to a visible walkable tile a few steps out so the spell still
	# fires (useful for cloud-residue / FX testing when no enemy is in
	# sight). The area still hits any monsters that happen to be inside.
	var center: Vector2i
	var center_px: Vector2
	if center_m != null:
		center = center_m.grid_pos
		center_px = center_m.position
	else:
		center = _fallback_area_center(int(info.get("range", 4)))
		center_px = Vector2(center.x * TILE_SIZE + TILE_SIZE / 2.0,
				center.y * TILE_SIZE + TILE_SIZE / 2.0)
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

	# DCSS cloud residue — some area spells leave behind a transient
	# cloud patch. The spell_id → cloud_type map lives here so spells
	# can opt in without knowing the CloudSystem exists.
	var cloud_residue: String = _spell_cloud_residue(spell_id)
	if cloud_residue != "" and GameManager != null:
		var dmap2: DungeonMap = $DungeonLayer/DungeonMap
		CloudSystem.place_patch(GameManager.clouds, center, cloud_residue, radius)
		if dmap2 != null:
			dmap2.update_fov(player.grid_pos)
			dmap2.queue_redraw()

	if hits == 0:
		return {"success": true, "message": "%s hits nothing." % String(info.get("name", spell_id))}
	return {"success": true, "message": "%s: %d hit(s), %d total dmg" % [String(info.get("name", spell_id)), hits, total_dmg]}


## Spell → cloud type mapping. DCSS source: spl-zap.cc / spell data.
## Fireball / Fire Storm leave fire clouds; Hailstorm leaves freezing
## clouds. Extend here as cloud-placing spells are ported.
func _spell_cloud_residue(spell_id: String) -> String:
	match spell_id:
		"fireball", "fire_storm":
			return "fire"
		"hailstorm":
			return "freezing"
		_:
			return ""


## DCSS death-cloud table — a handful of monster ids release a cloud
## on death. Keeps the set small (plague/rot undead + elementals) so
## most kills stay clean; the cloud is the flavour reward for taking
## down a notably nasty mob.
func _monster_death_cloud(monster_id: String) -> Dictionary:
	match monster_id:
		# Plague / rot undead — decaying flesh bursts into miasma.
		"bog_body", "plague_shambler", "rotting_hulk", "necrophage", \
		"ghoul", "death_drake":
			return {"type": "noxious", "radius": 1}
		# Fire-bodied creatures burn up into a lingering flame cloud.
		"fire_vortex", "fire_elemental", "creeping_inferno":
			return {"type": "fire", "radius": 2}
		# Cold-bodied elementals leave a freezing patch.
		"frost_giant", "ice_statue", "simulacrum":
			return {"type": "freezing", "radius": 1}
		# Smoke-bodied / shadowy creatures dissolve into smoke.
		"smoke_demon", "smoke_djinn":
			return {"type": "smoke", "radius": 2}
		_:
			return {}


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


## Pick a walkable tile to drop an area spell on when no monster is in
## range. Scans Chebyshev rings outward from the player for the first
## visible walkable tile, capped at `max_range` so the explosion stays
## reachable. Falls back to the player's own tile when nothing nearby
## is walkable — harmless, since area spells hit 0 monsters then and
## we still play FX + cloud residue.
func _fallback_area_center(max_range: int) -> Vector2i:
	if player == null or generator == null:
		return Vector2i.ZERO
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	var r: int = max(2, min(max_range, 4))
	for dist in range(2, r + 1):
		# Prefer cardinal directions at the target distance for a clean
		# forward blast; diagonals are considered after to broaden reach.
		var rings: Array = [
			Vector2i(dist, 0), Vector2i(-dist, 0),
			Vector2i(0, dist), Vector2i(0, -dist),
			Vector2i(dist, dist), Vector2i(-dist, -dist),
			Vector2i(dist, -dist), Vector2i(-dist, dist),
		]
		for d in rings:
			var cand: Vector2i = player.grid_pos + d
			if not generator.is_walkable(cand):
				continue
			if dmap != null and not dmap.is_tile_visible(cand):
				continue
			return cand
	return player.grid_pos


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
	if player == null:
		return

	var dlg := GameDialog.create("Bag", Vector2i(960, 1800))
	add_child(dlg)
	_bag_dlg = dlg
	dlg.set_on_close(func():
		if _bag_dlg == dlg: _bag_dlg = null)
	var vb: VBoxContainer = dlg.body()

	var cat_tabs := HBoxContainer.new()
	cat_tabs.add_theme_constant_override("separation", 4)
	cat_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for cat in _BAG_CATEGORIES:
		var tab_btn := Button.new()
		tab_btn.text = cat.to_upper()
		tab_btn.custom_minimum_size = Vector2(0, 64)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# 9 bag tabs need to share ~660px usable width; clip + smaller
		# font so long labels ("POTION", "AMULET", "SCROLL") don't push
		# the dialog past its viewport-ratio cap.
		tab_btn.clip_contents = true
		tab_btn.add_theme_font_size_override("font_size", 28)
		if cat == _bag_category:
			tab_btn.modulate = Color(1.0, 1.0, 0.75)
			tab_btn.disabled = true
		tab_btn.pressed.connect(func():
			_bag_category = cat
			dlg.close()
			_on_bag_pressed())
		cat_tabs.add_child(tab_btn)
	vb.add_child(cat_tabs)

	# Horizontal swipe cycles tabs (mobile UX).
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.gui_input.connect(_on_bag_swipe_input)

	_build_equipped_section(vb)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)
	vb.add_child(rows)

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
			row.custom_minimum_size = Vector2(0, 96)
			row.add_theme_constant_override("separation", 8)
			var iid_row: String = String(it.get("id", ""))
			var icon_node: Control = _build_bag_item_thumbnail(iid_row, kind)
			if icon_node != null:
				row.add_child(icon_node)
			var info_btn := Button.new()
			var disp_name: String = GameManager.display_name_for_item(
					iid_row, String(it.get("name", "?")), kind,
					String(it.get("ego", "")))
			var plus_amt: int = int(it.get("plus", 0))
			if plus_amt > 0:
				disp_name = "%s +%d" % [disp_name, plus_amt]
			if count > 1:
				disp_name = "%s  ×%d" % [disp_name, count]
			info_btn.text = disp_name
			info_btn.flat = true
			info_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			info_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info_btn.add_theme_font_size_override("font_size", 48)
			info_btn.pressed.connect(_on_bag_info.bind(it))
			row.add_child(info_btn)
			if kind == "weapon" or kind == "armor" or kind == "ring" or kind == "amulet":
				var eq_btn := Button.new()
				eq_btn.text = "Equip"
				eq_btn.add_theme_font_size_override("font_size", 44)
				eq_btn.custom_minimum_size = Vector2(150, 80)
				eq_btn.pressed.connect(_on_bag_equip.bind(i, dlg))
				row.add_child(eq_btn)
			else:
				var use_btn := Button.new()
				use_btn.text = "Use"
				use_btn.add_theme_font_size_override("font_size", 44)
				use_btn.custom_minimum_size = Vector2(110, 80)
				use_btn.pressed.connect(_on_bag_use.bind(i, dlg))
				row.add_child(use_btn)
			var drop_btn := Button.new()
			drop_btn.text = "Drop"
			drop_btn.add_theme_font_size_override("font_size", 44)
			drop_btn.custom_minimum_size = Vector2(110, 80)
			drop_btn.pressed.connect(_on_bag_drop.bind(i, dlg))
			row.add_child(drop_btn)
			rows.add_child(row)


func _open_bag_filtered(category: String) -> void:
	_bag_category = category if category != "" else "all"
	if _bag_dlg != null and is_instance_valid(_bag_dlg):
		_bag_dlg.close()
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
	var dlg: GameDialog = _skills_swipe_dlg
	if dlg == null or not is_instance_valid(dlg):
		return
	dlg.close()
	_skills_dlg = null
	_open_skills_dialog(String(_SKILL_CATEGORIES[next_idx]))


## Canonical slot tints used by the Equipped card grid.
const _EQUIP_TINTS: Dictionary = {
	"weapon": Color(1.00, 0.70, 0.40),
	"chest":  Color(0.65, 0.80, 0.95),
	"cloak":  Color(0.70, 0.60, 0.95),
	"legs":   Color(0.55, 0.75, 0.90),
	"helm":   Color(0.60, 0.85, 0.95),
	"gloves": Color(0.50, 0.80, 0.85),
	"boots":  Color(0.65, 0.75, 0.85),
	"ring":   Color(0.85, 0.80, 0.95),
	"amulet": Color(1.00, 0.90, 0.30),
}


## Render the "Equipped" block as a 2-column card grid. Always shows
## Weapon / Body(chest) / Amulet placeholders even when empty, plus one
## extra card per filled cloak/legs/helm/gloves/boots slot and per
## filled ring slot (octopodes' 8 rings each get their own card).
## Tapping a card opens the same info popup as the bag list rows.
func _build_equipped_section(vb: VBoxContainer) -> void:
	if player == null:
		return
	vb.add_child(UICards.section_header("Equipped"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Weapon — always shown so the player sees unarmed status at a glance.
	var wid: String = player.equipped_weapon_id
	var winfo: Dictionary = {}
	var wname := "—"
	if wid != "":
		wname = WeaponRegistry.display_name_for(wid)
		if player.equipped_weapon_plus > 0:
			wname = "%s +%d" % [wname, player.equipped_weapon_plus]
		if player.equipped_weapon_cursed:
			wname += "  (cursed)"
		winfo = {"id": wid, "name": wname, "kind": "weapon",
				"plus": player.equipped_weapon_plus}
	grid.add_child(_equipped_card("Weapon", wid, wname,
			_EQUIP_TINTS["weapon"], winfo))

	# Body (chest) — always shown; "—" if unarmored.
	var chest: Dictionary = player.equipped_armor.get("chest", {})
	var cname := "—"
	var cid := ""
	var cinfo: Dictionary = {}
	if not chest.is_empty():
		cid = String(chest.get("id", ""))
		cname = String(chest.get("name", cid))
		var cp: int = int(chest.get("plus", 0))
		if cp > 0:
			cname = "%s +%d" % [cname, cp]
		if bool(chest.get("cursed", false)):
			cname += "  (cursed)"
		cinfo = chest.duplicate()
		cinfo["kind"] = "armor"
	grid.add_child(_equipped_card("Body", cid, cname,
			_EQUIP_TINTS["chest"], cinfo))

	# Secondary armor slots — only shown when filled.
	for slot in ["cloak", "legs", "helm", "gloves", "boots"]:
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
		ainfo["kind"] = "armor"
		grid.add_child(_equipped_card(slot.capitalize(), aid, aname,
				_EQUIP_TINTS.get(slot, Color(0.60, 0.60, 0.70)), ainfo))

	# Ring slots — one card per filled slot; empty slots hidden so
	# 1-ring races don't see an empty second slot, but octopodes with
	# 8 rings each get their own card.
	if player.equipped_rings is Array:
		for i in player.equipped_rings.size():
			var ring: Dictionary = {}
			if typeof(player.equipped_rings[i]) == TYPE_DICTIONARY:
				ring = player.equipped_rings[i]
			if ring.is_empty():
				continue
			var rid: String = String(ring.get("id", ""))
			var rname: String = String(ring.get("name", rid))
			var rinfo: Dictionary = ring.duplicate()
			rinfo["kind"] = "ring"
			grid.add_child(_equipped_card("Ring %d" % (i + 1), rid, rname,
					_EQUIP_TINTS["ring"], rinfo))

	# Amulet — always shown.
	var am: Dictionary = {}
	if "equipped_amulet" in player and player.equipped_amulet is Dictionary:
		am = player.equipped_amulet
	var amname := "—"
	var amid := ""
	var aminfo: Dictionary = {}
	if not am.is_empty():
		amid = String(am.get("id", ""))
		amname = String(am.get("name", amid))
		aminfo = am.duplicate()
		aminfo["kind"] = "amulet"
	grid.add_child(_equipped_card("Amulet", amid, amname,
			_EQUIP_TINTS["amulet"], aminfo))

	vb.add_child(grid)


## One card in the Equipped grid. Tapping the card fires the same
## info popup as bag list rows when the slot is filled.
func _equipped_card(slot: String, item_id: String, name: String,
		tint: Color, item_dict: Dictionary = {}) -> Control:
	var panel: PanelContainer = UICards.card(tint)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)

	var slot_lbl := Label.new()
	slot_lbl.text = slot
	slot_lbl.add_theme_font_size_override("font_size", 30)
	slot_lbl.add_theme_color_override("font_color", tint)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(slot_lbl)

	var body_row := HBoxContainer.new()
	body_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body_row.add_theme_constant_override("separation", 8)
	col.add_child(body_row)

	if item_id != "":
		var tex: Texture2D = TileRenderer.item(item_id)
		if tex != null:
			var icon := TextureRect.new()
			icon.texture = tex
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(48, 48)
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			body_row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.add_child(name_lbl)

	# Make the whole card tappable when a real item lives here. A Control
	# overlay is fragile against the PanelContainer's layout — easier to
	# listen for clicks on the panel itself via gui_input.
	if not item_dict.is_empty():
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_equipped_card_input.bind(item_dict))

	return panel


func _on_equipped_card_input(event: InputEvent, item_dict: Dictionary) -> void:
	var is_click := false
	if event is InputEventMouseButton:
		is_click = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		is_click = event.pressed
	if is_click:
		_on_bag_info(item_dict)


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
	var lines: Array = [name_s, "Slot: ring"]
	# Randarts: use the compact describe string.
	if it.get("randart", false):
		lines.append(RandartGenerator.describe(it))
		if player != null:
			var worn: int = player.equipped_rings.size() if "equipped_rings" in player else 0
			var cap: int = 8 if player.race_res and player.race_res.racial_trait == "octopode_rings" else 2
			lines.append("Worn: %d / %d rings" % [worn, cap])
		return "\n".join(PackedStringArray(lines))
	var info: Dictionary = RingRegistry.get_info(id)
	if info.is_empty():
		return "%s\nA small band of unknown metal." % name_s
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
	# Resist lines from ring's resists dict.
	var ring_resists: Dictionary = info.get("resists", {})
	for elem in ring_resists.keys():
		var lv: int = int(ring_resists[elem])
		if lv != 0:
			lines.append("r%s %s" % [elem.capitalize(), "+" if lv > 0 else "-"])
	# Flag lines.
	for flag in info.get("flags", []):
		match String(flag):
			"see_invis": lines.append("See invisible")
			"flying":    lines.append("Flight")
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
	# Do NOT close the bag — info opens on top and bag stays alive.
	var dlg := GameDialog.create(String(it.get("name", "Item")), Vector2i(960, 1100))
	add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = _build_item_tooltip(it)
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lab)


func _on_bag_use(idx: int, dlg: GameDialog) -> void:
	_suppress_bag_reopen = false
	if player != null:
		player.use_item(idx)
	_bag_dlg = null  # Clear BEFORE reopening so toggle check doesn't see stale ref.
	dlg.close()
	if not _suppress_bag_reopen:
		_on_bag_pressed()
	_suppress_bag_reopen = false


func _on_bag_equip(idx: int, dlg: GameDialog) -> void:
	if player != null:
		var items: Array = player.get_items()
		if idx >= 0 and idx < items.size():
			var it: Dictionary = items[idx]
			var kind: String = String(it.get("kind", ""))
			items.remove_at(idx)
			if kind == "weapon":
				var wid: String = String(it.get("id", ""))
				var new_plus: int = int(it.get("plus", 0))
				var new_brand: String = String(it.get("brand", ""))
				var prev_id: String = player.equipped_weapon_id
				var prev_plus: int = player.equipped_weapon_plus
				var returned_id: String = player.equip_weapon(wid, new_plus, new_brand)
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
				# so the equipped AC calc sees it. Ego comes from the
				# item dict (floor gen rolled it; unrands have a fixed
				# ego); the armor_info lookup doesn't include egos so
				# this copy is the single-source-of-truth for the slot.
				armor_info["plus"] = int(it.get("plus", 0))
				if it.has("ego"):
					armor_info["ego"] = String(it.get("ego", ""))
				# Preserve the unrand's display name ("the Cloak of the
				# Thief") rather than the base ("cloak").
				if bool(it.get("unrand", false)):
					armor_info["name"] = String(it.get("name", armor_info.get("name", aid)))
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
				var ring_info: Dictionary
				# Randarts + unrands both carry their stat props on the
				# item dict (no base registry entry). Dup the whole dict
				# so the equip path sees ring_info["props"] directly.
				if it.get("randart", false) or it.get("unrand", false):
					ring_info = it.duplicate(true)
				else:
					ring_info = RingRegistry.get_info(rid)
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
			elif kind == "amulet":
				var amid: String = String(it.get("id", ""))
				var amu_info: Dictionary
				if bool(it.get("unrand", false)):
					# Unrand amulets fall back onto their `base` amulet
					# for mechanics (e.g. acrobat passive). Start from
					# the base dict then overlay the unrand's name +
					# props so the stat bonuses layer correctly.
					var base_id: String = String(it.get("base", ""))
					amu_info = AmuletRegistry.get_info(base_id) if base_id != "" else {}
					if amu_info.is_empty():
						amu_info = {}
					amu_info["id"] = amid
					amu_info["name"] = String(it.get("name", amid))
					amu_info["unrand"] = true
					if it.has("props"):
						amu_info["props"] = it.get("props", {})
				else:
					amu_info = AmuletRegistry.get_info(amid)
				if amu_info.is_empty():
					amu_info = {
						"id": amid,
						"name": String(it.get("name", amid)),
						"slot": "amulet",
						"kind": "amulet",
						"color": it.get("color", Color(1.00, 0.90, 0.30)),
					}
				var prev_amu: Dictionary = player.equip_amulet(amu_info)
				CombatLog.add("You put on the %s." % String(amu_info.get("name", amid)))
				if not prev_amu.is_empty():
					prev_amu["kind"] = "amulet"
					items.append(prev_amu)
			player.inventory_changed.emit()
	_bag_dlg = null
	dlg.close()
	_on_bag_pressed()


func _on_bag_drop(idx: int, dlg: GameDialog) -> void:
	if player != null:
		player.drop_item(idx)
	_bag_dlg = null
	dlg.close()
	_on_bag_pressed()


func _on_status_pressed() -> void:
	if _status_dlg != null and is_instance_valid(_status_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	if player == null:
		return

	var dlg := GameDialog.create("Status", Vector2i(960, 1800))
	add_child(dlg)
	_status_dlg = dlg
	dlg.set_on_close(func():
		if _status_dlg == dlg: _status_dlg = null)

	var vb: VBoxContainer = dlg.body()
	_status_build_header(vb)
	_status_build_vitals(vb)
	_status_build_piety(vb)
	_status_build_attributes(vb)
	_status_build_combat(vb)
	_status_build_equipment(vb)
	_status_build_rings(vb)
	_status_build_resistances(vb)
	_status_build_trait(vb)
	_status_build_runes(vb)

	# Essence slots retained — each row handles its own cast/swap buttons.
	if essence_system != null and essence_system.slots.size() > 0:
		vb.add_child(_status_section_header("Essences"))
		for i in essence_system.slots.size():
			vb.add_child(_build_essence_row(i, dlg))


# ---- Status sections -----------------------------------------------------

func _status_section_header(text: String) -> Label:
	return UICards.section_header(text)


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
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_status_attr_card("STR", s.STR, Color(1.00, 0.55, 0.35)))
	h.add_child(_status_attr_card("DEX", s.DEX, Color(0.40, 1.00, 0.55)))
	h.add_child(_status_attr_card("INT", s.INT, Color(0.55, 0.70, 1.00)))
	vb.add_child(h)


func _status_attr_card(label: String, value: int, tint: Color) -> Control:
	var panel: PanelContainer = UICards.card(tint)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.clip_contents = true
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
	h.add_theme_constant_override("separation", 8)
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_status_stat_card("AC", s.AC,
			"race %+d · armor %+d" % [
				player.race_res.base_ac if player.race_res else 0,
				s.AC - (player.race_res.base_ac if player.race_res else 0)]))
	h.add_child(_status_stat_card("EV", total_ev,
			"DEX/2 %+d · gear %+d" % [dex_ev, ev_bonus]))
	h.add_child(_status_stat_card("SH", s.SH, "shield block"))
	h.add_child(_status_stat_card("ATK", total_atk,
			"wpn %d · STR %+d · gear %+d" % [w_dmg, str_bonus, gear_dmg + player.weapon_bonus_dmg]))
	vb.add_child(h)


func _status_stat_card(label: String, value: int, sub: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Sub-text ("race +3 · armor +8") is the widest element and tends
	# to push the whole Combat row past the dialog's viewport-ratio
	# cap. Clipping here keeps the card fixed-width even if the sub
	# text overflows.
	panel.clip_contents = true
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
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.modulate = Color(0.65, 0.65, 0.70)
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.custom_minimum_size = Vector2(0, 0)
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
		"electric": 0, "magic": 0, "corr": 0, "mut": 0,
	}
	if player == null:
		return r
	# Read all resistances directly from Player.get_resist() so rings,
	# armour egos, mutations, and racial intrinsics are all captured in
	# one canonical place rather than duplicated here.
	r["fire"]     = player.get_resist("fire")
	r["cold"]     = player.get_resist("cold")
	# rPois is binary in DCSS: any positive level = full poison immunity,
	# so display as +++ (not a partial "+"). Negative values still render
	# as "-" for vulnerability.
	var pois: int = player.get_resist("poison")
	r["poison"]   = 3 if pois > 0 else pois
	r["negative"] = player.get_resist("neg")
	r["electric"] = player.get_resist("elec")
	r["magic"]    = player.get_resist("magic")
	r["corr"]     = player.get_resist("corr")
	r["mut"]      = player.get_resist("mut")
	return r


func _status_build_resistances(vb: VBoxContainer) -> void:
	var r: Dictionary = _status_resistances()
	vb.add_child(_status_section_header("Resistances"))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(_status_resist_card("rF",  r["fire"],     Color(1.0, 0.50, 0.30)))
	h.add_child(_status_resist_card("rC",  r["cold"],     Color(0.50, 0.85, 1.0)))
	h.add_child(_status_resist_card("rP",  r["poison"],   Color(0.45, 0.95, 0.45)))
	h.add_child(_status_resist_card("rN",  r["negative"], Color(0.65, 0.40, 0.90)))
	h.add_child(_status_resist_card("rE",  r["electric"], Color(1.0, 0.95, 0.35)))
	vb.add_child(h)
	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 8)
	h2.add_child(_status_resist_card("WL",    r["magic"],  Color(0.90, 0.50, 0.90)))
	h2.add_child(_status_resist_card("rCorr", r["corr"],   Color(0.75, 0.50, 0.25)))
	h2.add_child(_status_resist_card("rMut",  r["mut"],    Color(0.55, 0.85, 0.55)))
	vb.add_child(h2)


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
	elif value > 0:
		val_lbl.text = "+".repeat(clampi(value, 1, 3))
	else:
		val_lbl.text = "-".repeat(clampi(-value, 1, 3))
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


## Rune collection display. Header shows the count vs Zot gate
## requirement; each collected rune gets a colored name line. Orb of
## Zot, once picked up, flashes a victory reminder at the top.
func _status_build_runes(vb: VBoxContainer) -> void:
	if player == null:
		return
	var have: int = player.runes.size()
	if have == 0 and not player.has_orb:
		return  # no sense in a header for an empty collection
	var need: int = RuneRegistry.ZOT_GATE_REQUIREMENT
	vb.add_child(_status_section_header("Runes (%d / %d for Zot)" % [have, need]))
	for rid in player.runes:
		var info: Dictionary = RuneRegistry.get_info(String(rid))
		var row := Label.new()
		row.text = "• %s" % String(info.get("name", rid))
		row.add_theme_font_size_override("font_size", 36)
		row.add_theme_color_override("font_color",
				info.get("color", Color(0.85, 0.80, 0.70)))
		vb.add_child(row)
	if player.has_orb:
		var orb_lbl := Label.new()
		orb_lbl.text = "✦ the Orb of Zot — flee to the surface!"
		orb_lbl.add_theme_font_size_override("font_size", 42)
		orb_lbl.add_theme_color_override("font_color", Color(1.00, 0.85, 0.15))
		vb.add_child(orb_lbl)


## One row in the Status popup per essence slot. Shows the slotted essence's
## name + stat summary, a Swap button, and (when the essence has an active
## ability) a Cast button that funnels through EssenceSystem.invoke.
func _build_essence_row(slot_idx: int, status_dlg: GameDialog) -> Control:
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


func _on_cast_essence_ability(slot_idx: int, status_dlg: GameDialog) -> void:
	if essence_system == null:
		return
	var ok: bool = essence_system.invoke(slot_idx)
	status_dlg.close()
	if ok:
		TurnManager.end_player_turn()


func _on_swap_essence_slot(slot_idx: int, status_dlg: GameDialog) -> void:
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or essence_system == null:
		return
	status_dlg.close()
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
		_map_dlg.close()
		return
	var dmap: DungeonMap = $DungeonLayer/DungeonMap
	if dmap == null or generator == null:
		return

	var mm_w: int = DungeonGenerator.MAP_WIDTH * _MM_SCALE
	var mm_h: int = DungeonGenerator.MAP_HEIGHT * _MM_SCALE
	var dlg := GameDialog.create("Map", Vector2i(960, mm_h + 520))
	add_child(dlg)
	_map_dlg = dlg
	dlg.set_on_close(func():
		if _map_dlg == dlg: _map_dlg = null)
	var vb: VBoxContainer = dlg.body()

	# Current-floor card — branch display name + depth.
	vb.add_child(UICards.section_header("Current Floor"))
	var depth_card: PanelContainer = UICards.card(Color(1.0, 0.85, 0.40))
	var depth_col := VBoxContainer.new()
	depth_card.add_child(depth_col)
	var branch_id: String = GameManager.current_branch if GameManager else "dungeon"
	var branch_name: String = BranchRegistry.display_name(branch_id) if branch_id != "" else "Dungeon"
	var depth_n: int = GameManager.current_depth if GameManager != null else 1
	depth_col.add_child(UICards.accent_value(
			"%s  B%dF" % [branch_name, depth_n], 48))
	var hint_lbl := UICards.dim_hint("Tap a tile to auto-travel.")
	depth_col.add_child(hint_lbl)
	vb.add_child(depth_card)

	# Minimap texture — wrapped in a CenterContainer so it sits in the
	# middle of the dialog on wide phones.
	var center := CenterContainer.new()
	vb.add_child(center)
	var tex_rect := TextureRect.new()
	tex_rect.texture = _build_minimap_texture(dmap, player.grid_pos if player else Vector2i.ZERO)
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(mm_w, mm_h)
	tex_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	tex_rect.gui_input.connect(_on_minimap_tapped.bind(tex_rect, dlg))
	center.add_child(tex_rect)

	# Legend — 2-column grid of glyph + description. Glyphs mirror the
	# tile renderer (stairs up/down, altar, shop, trap, unseen fog).
	vb.add_child(UICards.section_header("Legend"))
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 24)
	legend.add_theme_constant_override("v_separation", 6)
	for pair in [
		["▲", "Stairs up"],
		["▼", "Stairs down"],
		["☥", "Altar"],
		["$", "Shop"],
		["^", "Trap"],
		["?", "Unseen / fog"],
	]:
		var glyph: Label = UICards.accent_value(String(pair[0]), 44)
		glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glyph.custom_minimum_size = Vector2(72, 0)
		legend.add_child(glyph)
		var desc := Label.new()
		desc.text = String(pair[1])
		desc.add_theme_font_size_override("font_size", 36)
		legend.add_child(desc)
	vb.add_child(legend)

	# ---- Visited-floor fast travel ------------------------------------
	# DCSS Shift+G (go to level) analog. Lists every floor already saved
	# in _floor_state, tap one to jump. Current floor is shown but not
	# clickable. Portal vaults are skipped — their state persists even
	# after the timer collapses them, but the portal itself is gone.
	vb.add_child(UICards.section_header("Travel"))
	var visited: Array = _collect_visited_floors()
	if visited.is_empty():
		vb.add_child(UICards.dim_hint("No floors visited yet."))
	else:
		for entry in visited:
			var fbid: String = String(entry.get("branch", "dungeon"))
			var fdep: int = int(entry.get("depth", 1))
			var is_current: bool = (fbid == GameManager.current_branch \
					and fdep == GameManager.current_depth)
			var row := Button.new()
			var short: String = BranchRegistry.short_name(fbid)
			var line: String = "%s : %d" % [short, fdep]
			if is_current:
				line += "   (here)"
			row.text = line
			row.custom_minimum_size = Vector2(0, 96)
			row.add_theme_font_size_override("font_size", 40)
			if is_current:
				row.disabled = true
				row.modulate = Color(0.7, 0.7, 0.7)
			else:
				row.pressed.connect(_on_fast_travel_pressed.bind(fbid, fdep, dlg))
			vb.add_child(row)


## Sorted list of visited floors for the Travel section. Each entry:
## {branch, depth}. Sort is by branch id (dungeon first), then depth.
func _collect_visited_floors() -> Array:
	var out: Array = []
	for key in _floor_state.keys():
		var parts: PackedStringArray = String(key).split(":")
		if parts.size() != 2:
			continue
		var bid: String = parts[0]
		if BranchRegistry.is_portal(bid):
			continue  # collapsed timed branches — not a valid travel target
		out.append({"branch": bid, "depth": int(parts[1])})
	# Include the current floor even if it hasn't been save-snapshotted
	# yet (first visit, not yet descended from). Handy as a "you are
	# here" anchor.
	var here: Dictionary = {
		"branch": GameManager.current_branch,
		"depth": GameManager.current_depth,
	}
	var has_current: bool = false
	for e in out:
		if e.get("branch") == here.branch and e.get("depth") == here.depth:
			has_current = true
			break
	if not has_current:
		out.append(here)
	out.sort_custom(_visited_floor_sort)
	return out


## Comparator for _collect_visited_floors. Dungeon trunk on top, then
## other branches alphabetically, then ascending by depth inside each.
func _visited_floor_sort(a: Dictionary, b: Dictionary) -> bool:
	var ba: String = String(a.get("branch", ""))
	var bb: String = String(b.get("branch", ""))
	var rank_a: int = 0 if ba == "dungeon" else 1
	var rank_b: int = 0 if bb == "dungeon" else 1
	if rank_a != rank_b:
		return rank_a < rank_b
	if ba != bb:
		return ba < bb
	return int(a.get("depth", 0)) < int(b.get("depth", 0))


func _on_fast_travel_pressed(target_branch: String, target_depth: int,
		dlg: GameDialog) -> void:
	if player == null or run_over:
		return
	dlg.close()
	_save_current_floor()
	# Fast travel bypasses the physical stairs path, so we overwrite
	# current location outright. The branch_return_stack is left alone:
	# if the target is a branch the player physically entered, the stack
	# they built up remains valid. If they fast-travel into a branch
	# they never entered before (shouldn't be possible — target has to
	# be in _floor_state), it still falls through cleanly because
	# leave_branch just fails on an empty stack.
	GameManager.current_branch = target_branch
	GameManager.current_depth = target_depth
	GameManager.portal_turns_left = 0  # non-portal targets only reach this line
	_regenerate_dungeon(false, false)
	CombatLog.add("You travel to %s:%d." % [BranchRegistry.short_name(target_branch),
			target_depth])


## Tapping on the minimap converts local pixel → grid tile and kicks off
## auto-move toward it. Closes the popup on success.
func _on_minimap_tapped(event: InputEvent, tex_rect: TextureRect, dlg: GameDialog) -> void:
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
	dlg.close()
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
