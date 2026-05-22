extends Node2D

const DungeonMapScene = preload("res://scripts/dungeon/DungeonMap.gd")
const PlayerScene = preload("res://scripts/entities/Player.gd")
const CompanionScene = preload("res://scripts/entities/Companion.gd")
const MonsterScene = preload("res://scripts/entities/Monster.gd")
const FloorItemScene = preload("res://scripts/entities/FloorItem.gd")
const TopHUDScene = preload("res://scenes/ui/TopHUD.tscn")
const BottomHUDScene = preload("res://scenes/ui/BottomHUD.tscn")
const ResultScreenScene = preload("res://scenes/ui/ResultScreen.tscn")
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"
const TOWN_SCENE_PATH: String = "res://scenes/town/Town.tscn"

# Monster weapon pools: monster_id -> [normal_weapons], rare_brands (5% chance)
const _MONSTER_WEAPON_POOLS: Dictionary = {
	"kobold":          [["dagger", "short_sword"],           ["venom_dagger"]],
	"hobgoblin":       [["dagger", "short_sword", "mace"],   []],
	"orc":             [["short_sword", "mace", "spear"],    ["flaming_sword"]],
	"orc_warrior":     [["short_sword", "long_sword", "mace", "spear"], ["flaming_sword", "shock_mace"]],
	"orc_priest":      [["mace", "staff"],                   ["shock_mace"]],
	"orc_wizard":      [["staff"],                           []],
	"orc_warchief":    [["long_sword", "battle_axe"],        ["flaming_sword"]],
	"gnoll":           [["short_sword", "spear"],            []],
	"gnoll_sergeant":  [["long_sword", "spear", "mace"],     ["flaming_sword"]],
	"gnoll_shaman":    [["staff"],                           []],
	"gnoll_warlord":   [["battle_axe", "long_sword"],        ["flaming_sword"]],
	"minotaur":        [["battle_axe"],                      ["flaming_sword"]],
	"skeletal_warrior":[["long_sword", "mace"],              ["frost_dagger"]],
	"vampire_knight":  [["long_sword", "arming_sword"],      ["flaming_sword"]],
	"harrow_knight":   [["long_sword", "arming_sword"],      ["frost_dagger"]],
	"deep_elf_archer": [["shortbow"],                        ["longbow"]],
	"cyclops":         [["battle_axe"],                      []],
	"two_headed_ogre": [["battle_axe", "long_sword"],        []],
}

const _CORPSE_BLOOD_RED: String = "res://assets/tiles/corpses/blood_puddle_red.png"
const _CORPSE_BLOOD_GREEN: String = "res://assets/tiles/corpses/blood_green.png"
# Monsters with green ichor (insects, plants, jelly) per DCSS convention.
const _CORPSE_GREEN_BLOOD: Dictionary = {
	"giant_cockroach": true,
	"hornet": true,
	"scorpion": true,
	"giant_wolf_spider": true,
}

@onready var GameManager = get_node("/root/GameManager")
@onready var TurnManager = get_node("/root/TurnManager")
@onready var CombatLog = get_node("/root/CombatLog")
@onready var SaveManager = get_node("/root/SaveManager")
@onready var MonsterRegistry = get_node("/root/MonsterRegistry")
@onready var ItemRegistry = get_node("/root/ItemRegistry")
@onready var SpellRegistry = get_node("/root/SpellRegistry")
@onready var RaceRegistry = get_node("/root/RaceRegistry")
@onready var RacePassiveSystem = get_node("/root/RacePassiveSystem")

var _floor_lifecycle: FloorLifecycle
var _spawn_service: SpawnService
var _effects_layer: EffectsLayer
var _spell_targeting: SpellTargeting
var map: DungeonMap
var player: Player
var _companions: Array = []  # Array[Companion] — active in-dungeon nodes
var items_layer: Node2D
var monsters_layer: Node2D
var npcs_layer: Node2D
var camera: Camera2D
var ui_layer: CanvasLayer
var top_hud: TopHUD
var bottom_hud: BottomHUD
var log_strip: CombatLogStrip
var _effect_layer: Node2D

var _targeting_spell: SpellData = null
var _targeting_tiles: Array = []
var _targeting_node: SpellTargetOverlay = null
var _targeting_monster: Monster = null
var _targeting_throw_entry: Dictionary = {}
var _pending_essence_pickups: Array = []
var _essence_pickup_popup_open: bool = false

# Abyss state
var _abyss_turn_counter: int = 0
const _ABYSS_SHIFT_INTERVAL: int = 8  # tiles shift every 8 player turns
const _ABYSS_SHIFT_COUNT: int = 12    # tiles flipped per shift

# Shop state — reset each floor, persisted in floor cache
var _shop_items: Array = []           # Array of {item_data: ItemData, price: int, sold: bool}
var _shop_is_special: bool = false
var _shop_tile_pos: Vector2i = Vector2i(-1, -1)

# Auto-walk state — when the player taps a distant explored tile,
# we enqueue a BFS path here and step one tile each player turn
# until we hit the goal, an enemy enters view, or HP drops.
var _auto_path: Array = []
var _auto_prev_hp: int = 0

const _LONG_PRESS_SEC: float = 0.5
var _lp_pos: Vector2 = Vector2.ZERO
var _lp_time: float = 0.0
var _lp_active: bool = false
var _lp_fired: bool = false
var _auto_known_ids: Dictionary = {}
# Set when ACT triggers continuous auto-explore; cleared on cancel or completion.
var _auto_exploring: bool = false
var _path_overlay: PathOverlay = null
var _auto_step_token: int = 0
var _auto_step_queued: bool = false

const AUTO_PATH_PREVIEW_SEC: float = 0.12
const AUTO_STEP_DELAY_SEC: float = 0.05

func _ready() -> void:
	add_to_group("game")
	_floor_lifecycle = FloorLifecycle.new()
	_floor_lifecycle.name = "FloorLifecycle"
	add_child(_floor_lifecycle)
	_floor_lifecycle.setup(self)
	_spawn_service = SpawnService.new()
	_spawn_service.name = "SpawnService"
	add_child(_spawn_service)
	_spawn_service.setup(self)
	_effects_layer = EffectsLayer.new()
	_effects_layer.name = "EffectsLayer"
	add_child(_effects_layer)
	_effects_layer.setup(self)
	_spell_targeting = SpellTargeting.new()
	_spell_targeting.name = "SpellTargeting"
	add_child(_spell_targeting)
	_spell_targeting.setup(self)
	if not GameManager.run_in_progress:
		GameManager.start_new_run()
	PartyManager.on_run_start(GameManager.depth)
	_spawn_map()
	_spawn_service._spawn_items_layer()
	_spawn_service._spawn_monsters_layer()
	_spawn_service._spawn_npcs_layer()
	_spawn_service._spawn_npcs_for_floor(10)
	_spawn_path_overlay()
	_spawn_player()
	if not GameManager.pending_player_state.is_empty():
		_apply_loaded_player_state(GameManager.pending_player_state)
		GameManager.pending_player_state = {}
	elif GameManager.depth <= 1:
		_apply_race_mods(GameManager.selected_race_id)
		player.set_race_from_id(GameManager.selected_race_id)
		player.init_skills()
		player.set_active_skills([])
		player.refresh_ac_from_equipment()
		player._refresh_paperdoll()
		_apply_starter_kit()
		if GameManager.selected_race_id == "tester":
			_apply_tester_character_setup()
		var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
		var race_name: String = race.display_name if race != null else "adventurer"
		CombatLog.post(LocaleManager.t("LOG_YOU_START_AS") % [race_name, ""],
			Color(0.85, 0.9, 1.0))
	# Resume into branch: the cache-hit path inside _generate_branch_floor
	# restores tiles/items/monsters/atmosphere. Falls back to fresh generation
	# if the loaded save predates branch_floor_cache persistence.
	if GameManager.branch_zone != "" and GameManager.branch_floor > 0:
		_generate_branch_floor(GameManager.branch_zone, GameManager.branch_floor, true)
	else:
		_floor_lifecycle._generate_floor(GameManager.depth, _floor_lifecycle._floor_seed(GameManager.depth))
		_spawn_companions()
		_spawn_camera()
		_spawn_ui()
		if GameManager.selected_race_id == "tester":
			_spawn_debug_floor_panel()
		TurnManager.player_turn_started.connect(_on_player_turn_started)
	if not ExpeditionState.exhausted.is_connected(_on_turn_budget_exhausted):
		ExpeditionState.exhausted.connect(_on_turn_budget_exhausted)
	_update_hud()
	_refresh_quickslots()
	# Initialize budget for the floor we just spawned into (covers both fresh
	# runs and resume-from-save paths).
	_reset_expedition_budget()
	CombatLog.post(LocaleManager.t("LOG_B_TAP_A_TILE_OR") \
			% GameManager.depth, Color(0.7, 0.9, 1.0))

func _process(delta: float) -> void:
	if _lp_active and not _lp_fired:
		_lp_time += delta
		if _lp_time >= _LONG_PRESS_SEC:
			_lp_fired = true
			_lp_active = false
			var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
			var world_pos: Vector2 = canvas_tf.affine_inverse() * _lp_pos
			var tile: Vector2i = map.world_to_grid(world_pos)
			TileTooltip.show_at(tile, self)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or map == null or camera == null:
		return
	if player.hp <= 0:
		return

	# Track touch/mouse for long-press detection. Release commits the tap if
	# the hold was short; long-press is consumed in _process().
	if event is InputEventScreenTouch:
		if event.pressed:
			_lp_pos = event.position
			_lp_time = 0.0
			_lp_active = true
			_lp_fired = false
		else:
			var was_short: bool = _lp_active and not _lp_fired
			_lp_active = false
			if not was_short:
				return  # already handled as long-press or cancelled
			# Fall through to handle as normal tap.
			var screen_pos: Vector2 = event.position
			if not _auto_path.is_empty() or _auto_exploring:
				_cancel_auto_walk("tapped")
			if _targeting_spell != null or not _targeting_throw_entry.is_empty():
				var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
				var world_pos: Vector2 = canvas_tf.affine_inverse() * screen_pos
				var tile: Vector2i = map.world_to_grid(world_pos)
				if not _targeting_throw_entry.is_empty():
					if _targeting_tiles.has(tile):
						_confirm_throw(tile)
					else:
						_cancel_throw()
						CombatLog.post("Throw cancelled.", Color(0.65, 0.65, 0.65))
				elif _targeting_monster != null and tile == _targeting_monster.grid_pos:
					_spell_targeting._confirm_targeting()
				elif _targeting_monster == null and _targeting_tiles.has(tile):
					_spell_targeting._confirm_targeting()
				else:
					_spell_targeting._cancel_targeting()
					CombatLog.post(LocaleManager.t("LOG_SPELL_CANCELLED"), Color(0.65, 0.65, 0.65))
				get_viewport().set_input_as_handled()
				return
			if not TurnManager.is_player_turn:
				return
			_handle_tap(screen_pos)
			get_viewport().set_input_as_handled()
		return

	# InputEventScreenDrag: cancel long-press if finger moves significantly.
	if event is InputEventScreenDrag:
		if _lp_active and event.position.distance_to(_lp_pos) > 12.0:
			_lp_active = false
		return

	# Mouse fallback (desktop testing).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_lp_pos = event.position
			_lp_time = 0.0
			_lp_active = true
			_lp_fired = false
		else:
			var was_short: bool = _lp_active and not _lp_fired
			_lp_active = false
			if not was_short:
				return
			var screen_pos: Vector2 = event.position
			if not _auto_path.is_empty() or _auto_exploring:
				_cancel_auto_walk("tapped")
			if _targeting_spell != null or not _targeting_throw_entry.is_empty():
				var canvas_tf: Transform2D = get_viewport().get_canvas_transform()
				var world_pos: Vector2 = canvas_tf.affine_inverse() * screen_pos
				var tile: Vector2i = map.world_to_grid(world_pos)
				if not _targeting_throw_entry.is_empty():
					if _targeting_tiles.has(tile):
						_confirm_throw(tile)
					else:
						_cancel_throw()
						CombatLog.post("Throw cancelled.", Color(0.65, 0.65, 0.65))
				elif _targeting_monster != null and tile == _targeting_monster.grid_pos:
					_spell_targeting._confirm_targeting()
				elif _targeting_monster == null and _targeting_tiles.has(tile):
					_spell_targeting._confirm_targeting()
				else:
					_spell_targeting._cancel_targeting()
					CombatLog.post(LocaleManager.t("LOG_SPELL_CANCELLED"), Color(0.65, 0.65, 0.65))
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
	if player.can_attack_tile(target):
		var w_id: String = player.equipped_weapon_id
		var w: ItemData = ItemRegistry.get_by_id(w_id) if ItemRegistry != null and w_id != "" else null
		var dist: int = max(abs(target.x - player.grid_pos.x), abs(target.y - player.grid_pos.y))
		if w != null and w.category == "ranged" and dist > 1:
			var cs: float = DungeonMap.CELL_SIZE
			var world_start := player.position + Vector2(cs * 0.5, cs * 0.5)
			var world_end := map.grid_to_world(target) + Vector2(cs * 0.5, cs * 0.5)
			spawn_spell_bolt(world_start, world_end, "", func(): player.try_attack_tile(target))
		else:
			player.try_attack_tile(target)
		return
	if target == player.grid_pos:
		if _pickup_current_tile():
			return
		var tile: int = map.tile_at(player.grid_pos)
		if tile == DungeonMap.Tile.STAIRS_DOWN:
			_on_stairs_down()
		elif tile == DungeonMap.Tile.STAIRS_UP:
			_on_stairs_up()
		elif tile == DungeonMap.Tile.BRANCH_DOWN:
			_on_branch_enter()
		else:
			player.wait_turn()
			TurnManager.end_player_turn(Status.speed_mult(player))
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
	if not map.is_walkable(goal) and map.tile_at(goal) != DungeonMap.Tile.DOOR_CLOSED:
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
			var nt := map.tile_at(n)
			if not map.in_bounds(n) or (not map.is_walkable(n) and nt != DungeonMap.Tile.DOOR_CLOSED):
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
	if _monster_at(next) != null:
		_cancel_auto_walk("new enemy")
		return
	var dir: Vector2i = next - player.grid_pos
	if abs(dir.x) > 1 or abs(dir.y) > 1:
		_cancel_auto_walk("path broken")
		return
	_auto_path.remove_at(0)
	if _path_overlay != null:
		_path_overlay.set_path(_auto_path)
	_auto_prev_hp = player.hp
	var prev_pos: Vector2i = player.grid_pos
	player.try_step(dir)
	# Door was opened but player stayed put — keep next tile in path for next step.
	if player.grid_pos == prev_pos:
		_auto_path.push_front(next)
		if _path_overlay != null:
			_path_overlay.set_path(_auto_path)

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
		if not (n is Monster) or n.is_ally:
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
		CombatLog.post(LocaleManager.t("LOG_YOU_STOP_ENEMY_APPROACHES"), Color(1.0, 0.7, 0.5))

func _apply_starter_kit() -> void:
	# Use the player's Starter Shop selection if present; otherwise fall
	# back to a minimal race-neutral kit (covers save-test paths that
	# bypass the shop or savefile loads that lost the pending list).
	var kit: Array = GameManager.pending_starter_items
	if kit.is_empty():
		kit = ["dagger", "leather_armor", "potion_healing", "potion_healing", "scroll_identify"]
	for id in kit:
		player.items.append({"id": String(id), "plus": 0})
		if GameManager != null:
			GameManager.identify(String(id))
	# Auto-equip first weapon and first armor found in the kit, mirroring
	# the prior default-kit behavior so the player walks into floor 1 ready.
	if player.equipped_weapon_id == "":
		for id in kit:
			var wdata = ItemRegistry.get_by_id(String(id)) if ItemRegistry != null else null
			if wdata != null and String(wdata.kind) == "weapon":
				player.equipped_weapon_id = String(id)
				break
	if player.equipped_armor_id == "":
		for id in kit:
			var adata = ItemRegistry.get_by_id(String(id)) if ItemRegistry != null else null
			if adata != null and String(adata.kind) == "armor":
				player.equipped_armor_id = String(id)
				break
	player.refresh_ac_from_equipment()
	player._refresh_paperdoll()
	GameManager.selected_starting_weapon_id = ""
	GameManager.selected_starting_school_id = ""
	GameManager.selected_starting_essence_id = ""
	GameManager.selected_faith_id = ""
	# Consumed; clear so a subsequent new-run starts fresh.
	GameManager.pending_starter_items = []

func _apply_tester_character_setup() -> void:
	# Debug-only race. Keep this explicit and easy to remove before release.
	player.xl = Player.MAX_XL
	player.xp = 0
	player.hp_max = max(player.hp_max, 999)
	player.hp = player.hp_max
	player.mp_max = max(player.mp_max, 250)
	player.mp = player.mp_max
	player.gold = max(player.gold, 9999)
	GameManager.gold = max(GameManager.gold, 9999)
	player.strength = max(player.strength, 40)
	player.dexterity = max(player.dexterity, 40)
	player.intelligence = max(player.intelligence, 40)
	player.resists = {"fire": 3, "cold": 3, "poison": 3, "necro": 3}

	for sid in Player.SKILL_IDS:
		player.skills[String(sid)] = {"level": Player.MAX_SKILL_LEVEL, "xp": 0.0}
	for sid in Player.HIDDEN_SUBSKILL_IDS:
		player.hidden_skills[String(sid)] = {"level": Player.MAX_SKILL_LEVEL, "xp": 0.0}
	player.set_active_skills([])

	player.known_spells.clear()
	if SpellRegistry != null:
		for spell in SpellRegistry.all:
			if spell != null and "id" in spell:
				var spell_id: String = String(spell.id)
				if spell_id != "" and not player.known_spells.has(spell_id):
					player.known_spells.append(spell_id)

	if ItemRegistry != null:
		for item in ItemRegistry.all:
			if item == null or not ("id" in item):
				continue
			var item_id: String = String(item.id)
			if item_id == "":
				continue
			if String(item.kind) in ["potion", "scroll", "wand", "spellpage"]:
				player.items.append({"id": item_id, "plus": 0})
				GameManager.identify(item_id)
		var practical_gear: Array = [
			"great_blade", "battle_axe", "longbow", "crossbow", "staff",
			"plate_mail", "tower_shield", "great_helm", "iron_gauntlets",
			"iron_greaves", "ring_wizardry", "ring_slaying", "amulet_magic",
			"rune_swamp", "rune_ice", "rune_infernal", "rune_crypt",
		]
		for item_id in practical_gear:
			if ItemRegistry.get_by_id(String(item_id)) != null:
				player.items.append({"id": String(item_id), "plus": 9})
				GameManager.identify(String(item_id))

	player.essence_inventory.clear()
	for essence_id in EssenceSystem.all_ids():
		player.essence_inventory.append(String(essence_id))
	player.essence_slots = ["essence_arcana", "essence_swiftness", "essence_vitality"]

	player.equipped_weapon_id = "great_blade"
	player.equipped_armor_id = "plate_mail"
	player.equipped_shield_id = ""
	player.equipped_helmet_id = "great_helm"
	player.equipped_gloves_id = "iron_gauntlets"
	player.equipped_boots_id = "iron_greaves"
	player.equipped_ring_id = "ring_wizardry"
	player.equipped_amulet_id = "amulet_magic"
	player.quickslots = ["fireball", "blink", "haste", "scroll_magic_mapping", "potion_healing", "wand_digging"]
	player.refresh_ac_from_equipment()
	player._refresh_paperdoll()
	CombatLog.post("Tester character initialized: max skills, all spells, all essences, consumables, scrolls, runes, and warp panel.", Color(1.0, 0.85, 0.3))

func _apply_race_mods(race_id: String) -> void:
	var race: RaceData = RaceRegistry.get_by_id(race_id)
	if race == null:
		return
	player.strength = max(1, player.strength + race.str_mod)
	player.dexterity = max(1, player.dexterity + race.dex_mod)
	player.intelligence = max(1, player.intelligence + race.int_mod)
	player._apply_max_hp_gain(race.hp_mod)
	player.hp = player.hp_max
	player._apply_max_mp_gain(race.mp_mod)
	player.mp = player.mp_max
	player.resists = Player.resists_from_tags(race.resist_mods)
	RacePassiveSystem.register(player)

func _apply_loaded_player_state(data: Dictionary) -> void:
	player.hp = int(data.get("hp", 22))
	player.hp_max = int(data.get("hp_max", 22))
	player.mp = int(data.get("mp", 5))
	player.mp_max = int(data.get("mp_max", 5))
	player.ac = int(data.get("ac", 0))
	player.ev = int(data.get("ev", 5))
	player.wl = int(data.get("wl", 0))
	player.strength = int(data.get("str", 10))
	player.dexterity = int(data.get("dex", 10))
	player.intelligence = int(data.get("int", 10))
	player.xl = int(data.get("xl", 1))
	player.xl = clampi(player.xl, 1, Player.MAX_XL)
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
	player.equipped_shield_id = shield_id
	var helmet_id: String = String(data.get("helmet", ""))
	if helmet_id != "" and ItemRegistry.get_by_id(helmet_id) != null:
		player.set_equipped_helmet(helmet_id)
	var gloves_id: String = String(data.get("gloves", ""))
	if gloves_id != "" and ItemRegistry.get_by_id(gloves_id) != null:
		player.set_equipped_gloves(gloves_id)
	var boots_id: String = String(data.get("boots", ""))
	if boots_id != "" and ItemRegistry.get_by_id(boots_id) != null:
		player.set_equipped_boots(boots_id)
	player.kills = int(data.get("kills", 0))
	player.last_killer = String(data.get("last_killer", ""))
	player.known_spells = data.get("known_spells", [])
	# Migrate old spell IDs that no longer exist in SpellRegistry.
	var _spell_remap: Dictionary = {"magic_dart": "pain", "heal_wounds": ""}
	var _migrated: Array = []
	for _sid: String in player.known_spells:
		var _resolved: String = _sid
		if _spell_remap.has(_sid):
			_resolved = _spell_remap[_sid]
		if _resolved != "" and SpellRegistry.get_by_id(_resolved) != null:
			_migrated.append(_resolved)
	player.known_spells = _migrated
	player.statuses = data.get("statuses", {})
	player.body_wounds = data.get("body_wounds", {})
	# Resists were Array[tag] pre-2026-05; now Dict[element → int]. Migrate either.
	var loaded_resists = data.get("resists", {})
	if typeof(loaded_resists) == TYPE_DICTIONARY:
		var migrated: Dictionary = {}
		for k in loaded_resists.keys():
			migrated[String(k)] = int(loaded_resists[k])
		player.resists = migrated
	elif typeof(loaded_resists) == TYPE_ARRAY:
		player.resists = Player.resists_from_tags(loaded_resists)
	else:
		player.resists = {}
	# ── Skill migration to dual-tier 9+30 (save_version >= 5) ──────────────
	# Old saves carry a `skills` dict that may contain any of:
	#   - DCSS 30-split sub-skill ids (post-2026-05 saves)
	#   - PROJ_G 9-skill ids (current format)
	#   - even older umbrella ids (melee/magic/defense/dodge/stealth)
	# Strategy: route every old key through Player.SKILL_REMAP to a canonical
	# visible bucket; level becomes max-of-old, XP becomes sum-of-old per
	# bucket. Hidden tier is reconstructed by copying any sub-skill keys from
	# the old `skills` dict (per-sub-skill data preserved verbatim), then
	# overwritten by `hidden_skills` if present (post-v5 saves).
	var loaded_skills: Dictionary = data.get("skills", {})
	var loaded_hidden: Dictionary = data.get("hidden_skills", {})
	# Pre-v5 umbrella keys: collapse to nearest sub-skill so SKILL_REMAP works.
	if loaded_skills.has("melee") and not loaded_skills.has("fighting"):
		loaded_skills["fighting"] = loaded_skills["melee"]
	loaded_skills.erase("melee")
	if loaded_skills.has("magic") and not loaded_skills.has("spellcasting"):
		loaded_skills["spellcasting"] = loaded_skills["magic"]
	loaded_skills.erase("magic")
	if loaded_skills.has("dodge") and not loaded_skills.has("dodging"):
		loaded_skills["dodging"] = loaded_skills["dodge"]
	loaded_skills.erase("dodge")
	# Visible: sum XP across old keys that remap to the same new bucket;
	# level becomes max-of-old.
	var new_visible: Dictionary = {}
	for vid in Player.SKILL_IDS:
		new_visible[vid] = {"level": 0, "xp": 0.0}
	for old_id in loaded_skills.keys():
		var canon: String = String(Player.SKILL_REMAP.get(old_id, ""))
		if canon == "" or not new_visible.has(canon):
			continue
		var old_entry = loaded_skills[old_id]
		if typeof(old_entry) != TYPE_DICTIONARY:
			continue
		var lv: int = clampi(int(old_entry.get("level", 0)), 0, Player.MAX_SKILL_LEVEL)
		var xp: float = float(old_entry.get("xp", 0.0))
		new_visible[canon]["xp"] = float(new_visible[canon]["xp"]) + xp
		new_visible[canon]["level"] = max(int(new_visible[canon]["level"]), lv)
	player.skills = new_visible
	# Hidden: preserve per-sub-skill data verbatim.
	#   1) pre-v5 saves: the old `skills` dict itself contains sub-skill keys.
	#   2) v5+ saves: `hidden_skills` is the canonical source — it overrides.
	var new_hidden: Dictionary = {}
	for hid in Player.HIDDEN_SUBSKILL_IDS:
		new_hidden[hid] = {"level": 0, "xp": 0.0}
	for old_id in loaded_skills.keys():
		if Player.HIDDEN_SUBSKILL_IDS.has(old_id) and typeof(loaded_skills[old_id]) == TYPE_DICTIONARY:
			new_hidden[old_id] = (loaded_skills[old_id] as Dictionary).duplicate(true)
	for hid in loaded_hidden.keys():
		if Player.HIDDEN_SUBSKILL_IDS.has(hid) and typeof(loaded_hidden[hid]) == TYPE_DICTIONARY:
			new_hidden[hid] = (loaded_hidden[hid] as Dictionary).duplicate(true)
	player.hidden_skills = new_hidden
	# Active skills: route legacy ids through SKILL_REMAP via set_active_skills,
	# which dedupes and emits stats_changed.
	player.active_skills = data.get("active_skills", [])
	player.set_active_skills(player.active_skills)
	var saved_qs = data.get("quickslots", null)
	if saved_qs is Array:
		for i in range(min(int(saved_qs.size()), player.quickslots.size())):
			player.quickslots[i] = String(saved_qs[i])
	var saved_es = data.get("essence_slots", null)
	if saved_es is Array:
		for i in range(mini(int(saved_es.size()), player.essence_slots.size())):
			var eid: String = String(saved_es[i])
			if not EssenceSystem.slot_is_unlocked(player, i):
				if eid != "":
					player.essence_inventory.append(eid)
				continue
			player.essence_slots[i] = eid
			if eid != "":
				EssenceSystem.apply(player, eid)
	var saved_ei = data.get("essence_inventory", null)
	if saved_ei is Array:
		player.essence_inventory = saved_ei.duplicate()
	player.faith_id = String(data.get("faith_id", ""))
	player.first_shrine_choice_done = bool(data.get("first_shrine_choice_done", false))
	FaithSystem.normalize_player_state(player)
	player.refresh_ac_from_equipment()
	player.set_race_from_id(GameManager.selected_race_id)
	RacePassiveSystem.register(player)
	player._refresh_paperdoll()
	CombatLog.post(LocaleManager.t("LOG_RUN_RESUMED_FLOOR_B") % GameManager.depth,
		Color(0.7, 0.9, 1.0))

func _spawn_map() -> void:
	map = DungeonMapScene.new()
	map.name = "DungeonMap"
	map.reveal_all = false
	add_child(map)

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
	player.weapon_attacked.connect(_on_player_weapon_attacked)


func _spawn_companions() -> void:
	if map == null or player == null:
		return
	for cdata in PartyManager.get_active_companions():
		var companion := CompanionScene.new()
		companion.name = "Companion_" + cdata.id
		add_child(companion)
		var spawn_pos: Vector2i = _find_companion_spawn_pos(player.grid_pos)
		companion.setup(cdata, map, spawn_pos)
		_companions.append(companion)
		TurnManager.register_actor(companion)


func _despawn_companions() -> void:
	for c in _companions:
		if is_instance_valid(c):
			TurnManager.unregister_actor(c)
			c.sync_to_data()
			c.queue_free()
	_companions.clear()


func _find_companion_spawn_pos(near: Vector2i) -> Vector2i:
	var offsets: Array = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for off in offsets:
		var candidate: Vector2i = near + off
		if map != null and map.is_walkable(candidate) and _tile_free_of_actors(candidate):
			return candidate
	return near  # fallback: overlap (rare)


func _tile_free_of_actors(pos: Vector2i) -> bool:
	if player != null and player.grid_pos == pos:
		return false
	for c in _companions:
		if is_instance_valid(c) and c.grid_pos == pos:
			return false
	return true


func _on_companion_died(companion_node: Companion) -> void:
	TurnManager.unregister_actor(companion_node)
	_companions.erase(companion_node)
	if companion_node.data != null:
		CombatLog.post(companion_node.data.display_name + "이(가) 쓰러졌습니다!",
			Color(1.0, 0.4, 0.4))

func _queue_essence_pickup(essence_id: String, floor_item: FloorItem = null) -> void:
	if player == null or essence_id == "":
		return
	if player.essence_slots.has(essence_id) or player.essence_inventory.has(essence_id):
		CombatLog.post(LocaleManager.t("LOG_AN_ESSENCE_FADES_AWAY") % EssenceSystem.display_name(essence_id),
			Color(0.6, 0.55, 0.7))
		if floor_item != null and is_instance_valid(floor_item):
			floor_item.queue_free()
		return
	_pending_essence_pickups.append({
		"essence_id": essence_id,
		"floor_item": floor_item,
	})
	_try_open_essence_pickup_popup()

func _try_open_essence_pickup_popup() -> void:
	if _essence_pickup_popup_open or _pending_essence_pickups.is_empty():
		return
	if player == null:
		_pending_essence_pickups.clear()
		return
	var queued: Dictionary = _pending_essence_pickups.pop_front()
	var essence_id: String = String(queued.get("essence_id", ""))
	var floor_item: FloorItem = queued.get("floor_item", null)
	if essence_id == "" or player.essence_slots.has(essence_id) or player.essence_inventory.has(essence_id):
		if floor_item != null and is_instance_valid(floor_item):
			floor_item.queue_free()
		_try_open_essence_pickup_popup()
		return
	_essence_pickup_popup_open = true
	_cancel_auto_walk("essence")
	var popup := PopupManager.new()
	add_child(popup)
	var take_cb := func() -> void:
		if player != null and player.add_essence(essence_id):
			CombatLog.post(LocaleManager.t("LOG_YOU_CLAIM") % EssenceSystem.display_name(essence_id),
				Color(0.82, 0.64, 1.0))
			if floor_item != null and is_instance_valid(floor_item):
				floor_item.queue_free()
		_close_essence_pickup_popup(popup)
	var replace_cb := func(replaced_id: String) -> void:
		if player != null and player.replace_inventory_essence(replaced_id, essence_id):
			CombatLog.post(LocaleManager.t("LOG_YOU_LEAVE_AND_TAKE") % [
				EssenceSystem.display_name(replaced_id),
				EssenceSystem.display_name(essence_id),
			], Color(0.82, 0.64, 1.0))
			if floor_item != null and is_instance_valid(floor_item):
				floor_item.queue_free()
		_close_essence_pickup_popup(popup)
	var leave_cb := func() -> void:
		# Unchosen essences vanish — no second-thoughts pickup. Forces a real
		# decision at drop time and prevents floor clutter from rejected drops.
		CombatLog.post(LocaleManager.t("LOG_THE_ESSENCE_FADES_AWAY") % EssenceSystem.display_name(essence_id),
			Color(0.62, 0.62, 0.72))
		if floor_item != null and is_instance_valid(floor_item):
			floor_item.queue_free()
		_close_essence_pickup_popup(popup)
	popup.show_essence_pickup_popup(
		essence_id,
		player.essence_inventory.duplicate(),
		EssenceSystem.inventory_capacity(player),
		{
			"take": take_cb,
			"replace": replace_cb,
			"leave": leave_cb,
		}
	)

func _close_essence_pickup_popup(popup: PopupManager) -> void:
	_essence_pickup_popup_open = false
	if is_instance_valid(popup):
		popup.queue_free()
	_try_open_essence_pickup_popup()

const ZOOM_MIN: float = 0.7
const ZOOM_MAX: float = 2.2
const ZOOM_STEP: float = 0.2

func _spawn_camera() -> void:
	camera = Camera2D.new()
	camera.name = "Camera2D"
	camera.zoom = Vector2(1.6, 1.6)
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
	# Sit above BottomHUD (which is the bottom 148px) with a 50px gap so the
	# log doesn't overlap quickslot/menu buttons. ~136px tall band.
	log_strip.offset_top = -334.0
	log_strip.offset_bottom = -198.0
	log_strip.grow_horizontal = 2
	log_strip.grow_vertical = 0
	ui_layer.add_child(log_strip)
	bottom_hud.bag_pressed.connect(_on_bag_pressed)
	bottom_hud.status_pressed.connect(_on_status_pressed)
	bottom_hud.rest_pressed.connect(_on_rest_pressed)
	bottom_hud.act_pressed.connect(_on_act_pressed)
	bottom_hud.skills_pressed.connect(_on_skills_pressed)
	bottom_hud.magic_pressed.connect(_on_magic_pressed)
	bottom_hud.quickslot_pressed.connect(_on_quickslot_pressed)
	bottom_hud.quickslot_long_pressed.connect(_on_quickslot_long_pressed)
	bottom_hud.quickslot_swap_requested.connect(_on_quickslot_swap_requested)
	if bottom_hud.has_signal("menu_pressed"):
		bottom_hud.menu_pressed.connect(_on_menu_button_pressed)
	if bottom_hud.has_signal("party_pressed"):
		bottom_hud.party_pressed.connect(_on_party_pressed)
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


func _place_shop_tile() -> void:
	# Pick a room that's not the player spawn room and not the stairs room.
	var eligible_rooms: Array = []
	for room in map.rooms:
		if room.has_point(map.spawn_pos) or room.has_point(map.stairs_down_pos):
			continue
		eligible_rooms.append(room)
	if eligible_rooms.is_empty():
		return
	var chosen_room: Rect2i = eligible_rooms[randi() % eligible_rooms.size()]
	var shop_pos := Vector2i(
		chosen_room.position.x + chosen_room.size.x / 2,
		chosen_room.position.y + chosen_room.size.y / 2
	)
	map.set_tile(shop_pos, DungeonMap.Tile.SHOP)
	_shop_tile_pos = shop_pos
	_shop_items = []  # generated lazily on first visit
	_shop_is_special = (randf() < 0.15)

## Tier-based purchase price for shop items.
## Randarts use a separate (premium) price table.
## Consumables (potion/scroll/spellpage) use a lower table.
## Books use consumable table × 1.5.
## Equipment uses the standard table.
func _shop_price(item_data: ItemData, is_randart: bool) -> int:
	if item_data == null:
		return 0
	var tier: int = clamp(item_data.tier, 1, 5)
	if is_randart:
		var randart_prices := [0, 0, 0, 0, 220, 320]
		return randart_prices[tier]
	var kind: String = String(item_data.kind)
	if kind in ["potion", "scroll", "spellpage"]:
		var consumable_prices := [0, 15, 25, 40, 60, 80]
		return consumable_prices[tier]
	elif kind == "book":
		var base_prices := [0, 15, 25, 40, 60, 80]
		return int(base_prices[tier] * 1.5)
	else:
		# equipment: weapon, armor, ring, amulet, shield, wand, throwing
		var equipment_prices := [0, 40, 70, 110, 160, 220]
		return equipment_prices[tier]

## Populate _shop_items lazily on first visit to a shop tile.
## Normal shop (85% chance): 4-6 mixed items.
## Special shop (15% chance): 3-4 high-tier equipment entries + 1-2 consumables.
## Partial books are excluded (ShopDialog requires ItemData; generate_partial_book
## returns a Dictionary). Full school books may appear via normal item picks.
func _generate_shop_inventory() -> void:
	_shop_items = []
	if ItemRegistry == null:
		return
	var depth: int = GameManager.depth

	if _shop_is_special:
		# Special shop: premium equipment (boosted depth for higher tiers) + consumables.
		var boosted_depth: int = min(depth + 4, 20)
		var eq_count: int = randi_range(3, 4)
		for _i in range(eq_count):
			var base_item: ItemData = ItemRegistry.pick_equipment_weighted(boosted_depth)
			if base_item == null:
				continue
			var entry: Dictionary = ItemRegistry.make_entry(base_item.id, boosted_depth)
			var is_randart: bool = entry.has("mods")
			var display_item: ItemData = ItemRegistry.get_by_id(
				String(entry.get("base_id", entry.get("id", ""))))
			if display_item == null:
				continue
			var price: int = _shop_price(display_item, is_randart)
			_shop_items.append({
				"item_data": display_item,
				"entry": entry,
				"price": price,
				"sold": false,
			})
		var consumable_count: int = randi_range(1, 2)
		for _i in range(consumable_count):
			var kind_roll: float = randf()
			var item: ItemData
			if kind_roll < 0.6:
				item = ItemRegistry.pick_kind(boosted_depth, "potion")
			else:
				item = ItemRegistry.pick_kind(boosted_depth, "scroll")
			if item == null:
				continue
			_shop_items.append({
				"item_data": item,
				"price": _shop_price(item, false),
				"sold": false,
			})
	else:
		# Normal shop: 4-6 mixed items.
		var count: int = randi_range(4, 6)
		for _i in range(count):
			var roll: float = randf()
			if roll < 0.25:
				# Potion
				var item: ItemData = ItemRegistry.pick_kind(depth, "potion")
				if item == null:
					continue
				_shop_items.append({"item_data": item, "price": _shop_price(item, false), "sold": false})
			elif roll < 0.45:
				# Scroll
				var item: ItemData = ItemRegistry.pick_kind(depth, "scroll")
				if item == null:
					continue
				_shop_items.append({"item_data": item, "price": _shop_price(item, false), "sold": false})
			elif roll < 0.65:
				# Equipment (may become randart via make_entry)
				var base_item: ItemData = ItemRegistry.pick_equipment_weighted(depth)
				if base_item == null:
					continue
				var entry: Dictionary = ItemRegistry.make_entry(base_item.id, depth)
				var is_randart: bool = entry.has("mods")
				var display_item: ItemData = ItemRegistry.get_by_id(
					String(entry.get("base_id", entry.get("id", ""))))
				if display_item == null:
					continue
				_shop_items.append({
					"item_data": display_item,
					"entry": entry,
					"price": _shop_price(display_item, is_randart),
					"sold": false,
				})
			elif roll < 0.80:
				# Spellpage
				var item: ItemData = ItemRegistry.pick_random_spellpage(depth)
				if item == null:
					continue
				_shop_items.append({"item_data": item, "price": _shop_price(item, false), "sold": false})
			else:
				# Full school book
				var item: ItemData = ItemRegistry.pick_kind(depth, "book")
				if item == null:
					continue
				_shop_items.append({"item_data": item, "price": _shop_price(item, false), "sold": false})

## Open the shop dialog. Generates inventory on first visit (lazy).
func _open_shop() -> void:
	if _shop_items.is_empty():
		_generate_shop_inventory()
	ShopDialog.open(_shop_items, player, get_tree().current_scene)

func _spawn_final_boss_floor() -> void:
	var md: MonsterData = MonsterRegistry.get_by_id("abyssal_sovereign")
	if md == null:
		push_error("abyssal_sovereign MonsterData not found!")
		return
	# Place boss in center of map, away from spawn
	var center := Vector2i(DungeonMap.GRID_W / 2, DungeonMap.GRID_H / 2)
	var best := center
	var best_d: int = 0
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			if map.tile_at(p) != DungeonMap.Tile.FLOOR:
				continue
			var d: int = max(abs(p.x - map.spawn_pos.x), abs(p.y - map.spawn_pos.y))
			if d > best_d and d > 6:
				best_d = d
				best = p
	var m: Monster = MonsterScene.new()
	monsters_layer.add_child(m)
	m.setup(md, map, best)
	m.hit_taken.connect(_on_monster_hit.bind(m))
	m.died.connect(_on_monster_died)
	m.awareness_changed.connect(_on_monster_awareness_changed)
	TurnManager.register_actor(m)
	CombatLog.post(LocaleManager.t("LOG_A_CRUSHING_DARKNESS_FILLS_THE"),
			Color(0.6, 0.1, 0.9))
	map.queue_redraw()
	# Also spawn a handful of undead guards
	var guard_ids: Array = ["wraith", "crypt_zombie", "shadow_wraith"]
	var spawned: int = 0
	for attempt in range(40):
		if spawned >= 4:
			break
		var rx: int = randi_range(1, DungeonMap.GRID_W - 2)
		var ry: int = randi_range(1, DungeonMap.GRID_H - 2)
		var gp := Vector2i(rx, ry)
		if map.tile_at(gp) != DungeonMap.Tile.FLOOR:
			continue
		var dist_player: int = max(abs(gp.x - map.spawn_pos.x), abs(gp.y - map.spawn_pos.y))
		if dist_player < 5:
			continue
		var gid: String = guard_ids[randi() % guard_ids.size()]
		if spawn_monster_at(gid, gp):
			spawned += 1

## Thin pass-through to SpawnService — kept for external callers (MagicSystem).
func spawn_ally(monster_id: String, near_pos: Vector2i, turns: int) -> bool:
	return _spawn_service.spawn_ally(monster_id, near_pos, turns)

## Thin pass-through to SpawnService — kept for external callers (MonsterAI).
func spawn_monster_at(monster_id: String, pos: Vector2i) -> bool:
	return _spawn_service.spawn_monster_at(monster_id, pos)

## Orc treasure room: for floors 7-9 pick a room away from player and stairs,
## scatter gold piles and bonus equipment inside it.
func _spawn_orc_treasure_room(depth: int, rng: RandomNumberGenerator) -> void:
	if depth < 7 or depth > 9:
		return
	if map == null or map.rooms.is_empty():
		return
	# Find rooms that don't contain spawn_pos or stairs_down_pos.
	var eligible: Array[Rect2i] = []
	for room in map.rooms:
		if room.has_point(map.spawn_pos):
			continue
		if room.has_point(map.stairs_down_pos):
			continue
		eligible.append(room)
	if eligible.is_empty():
		# Fall back to any room if no eligible room found.
		eligible = map.rooms.duplicate()
	var treasure_room: Rect2i = eligible[rng.randi() % eligible.size()]
	# Scatter 8-12 gold piles of 50-120g each.
	var gold_count: int = rng.randi_range(8, 12)
	for _i in range(gold_count):
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var x: int = rng.randi_range(treasure_room.position.x, treasure_room.position.x + treasure_room.size.x - 1)
			var y: int = rng.randi_range(treasure_room.position.y, treasure_room.position.y + treasure_room.size.y - 1)
			var gpos := Vector2i(x, y)
			if not map.is_walkable(gpos):
				continue
			if gpos == player.grid_pos:
				continue
			_spawn_service._spawn_gold_pile(gpos, rng.randi_range(50, 120))
			break
	# Scatter 2-3 bonus equipment items.
	var eq_count: int = rng.randi_range(2, 3)
	for _i in range(eq_count):
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var x: int = rng.randi_range(treasure_room.position.x, treasure_room.position.x + treasure_room.size.x - 1)
			var y: int = rng.randi_range(treasure_room.position.y, treasure_room.position.y + treasure_room.size.y - 1)
			var epos := Vector2i(x, y)
			if not map.is_walkable(epos):
				continue
			if epos == player.grid_pos:
				continue
			if _item_at(epos) != null:
				continue
			var eq_data: ItemData = ItemRegistry.pick_equipment_weighted(depth) if ItemRegistry != null else null
			if eq_data == null:
				break
			var eq_entry: Dictionary = ItemRegistry.make_entry(eq_data.id, depth, 0) if ItemRegistry != null else {"id": eq_data.id, "plus": 0}
			_spawn_service._spawn_floor_item(eq_data, epos, 0, eq_entry)
			break

## DCSS-style corpse composition: monster body tile, darkened, blitted onto a
## blood puddle background. Result is cached per monster id so each monster
## type composes only once per session.
var _corpse_tex_cache: Dictionary = {}

func _refresh_fov() -> void:
	if player == null or map == null:
		return
	var newly_revealed: int = map.set_fov(player.compute_fov())
	if newly_revealed > 0:
		player.grant_skill_xp("tracking", float(newly_revealed) * 0.2)
	_grant_sight_bestiary_unlocks()
	_update_minimap()
	_refresh_entity_visibility()
	if bottom_hud != null:
		var hostile: bool = _monster_in_sight()
		bottom_hud.set_rest_label(hostile)
		bottom_hud.set_act_label(hostile)

func _grant_sight_bestiary_unlocks() -> void:
	# Tracking ≥ 3: monsters seen in FOV are auto-recorded in the bestiary
	# without needing to be killed. kill_counts goes 0 → 1; no XP awarded
	# here (the natural kill XP path still pays out if/when killed).
	if player == null or map == null:
		return
	if player.get_skill_level("tracking") < 3:
		return
	var tree := get_tree()
	if tree == null:
		return
	var any_unlocked: bool = false
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster) or n.data == null:
			continue
		var mid: String = n.data.id
		if int(GameManager.kill_counts.get(mid, 0)) > 0:
			continue
		if not map.visible_tiles.has(n.grid_pos):
			continue
		GameManager.kill_counts[mid] = 1
		any_unlocked = true
		CombatLog.post(LocaleManager.t("LOG_TRACKING_OBSERVED") % n.data.display_name,
			Color(0.6, 0.85, 1.0))
	if any_unlocked:
		GameManager._save_settings()

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
	_floor_lifecycle._cache_current_floor()
	const MAP_SCALE: int = 6
	var tex: ImageTexture = MinimapRenderer.render(map, player, self, MAP_SCALE)
	var dlg: GameDialog = GameDialog.create_ratio("Map", 0.96, 0.96)
	add_child(dlg)
	var body := dlg.body()
	if body == null:
		return

	var vp_size := get_viewport().get_visible_rect().size
	var map_rect := TextureRect.new()
	map_rect.texture = tex
	map_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	map_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_rect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_rect.custom_minimum_size = Vector2(vp_size.x * 0.88, vp_size.y * 0.78)
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
		# STRETCH_KEEP_ASPECT_CENTERED letterboxes the texture inside
		# map_rect, so we can't map local_pos directly to grid coords —
		# need to convert through the actual displayed texture rect.
		var rs: Vector2 = map_rect.size
		var ts: Vector2 = map_rect.texture.get_size()
		if ts.x <= 0 or ts.y <= 0 or rs.x <= 0 or rs.y <= 0:
			return
		var scale: float = min(rs.x / ts.x, rs.y / ts.y)
		var disp: Vector2 = ts * scale
		var origin: Vector2 = (rs - disp) * 0.5
		var local_pos: Vector2 = map_rect.get_local_mouse_position() - origin
		if local_pos.x < 0 or local_pos.y < 0 \
				or local_pos.x >= disp.x or local_pos.y >= disp.y:
			return
		var gx := int(local_pos.x * DungeonMap.GRID_W / disp.x)
		var gy := int(local_pos.y * DungeonMap.GRID_H / disp.y)
		var nav_target := Vector2i(gx, gy)
		if not map.in_bounds(nav_target) or not map.explored.has(nav_target) \
				or not map.is_walkable(nav_target) or nav_target == player.grid_pos:
			return
		dlg.close()
		var nav_path := _bfs_path(player.grid_pos, nav_target)
		if nav_path.size() > 0:
			_begin_auto_walk(nav_path, false)
	)

	var all_depths: Array = GameManager.floor_cache.keys().duplicate()
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
	if GameManager.branch_zone != "":
		var bcfg: Dictionary = ZoneManager.branch_config(GameManager.branch_zone)
		var bname: String = bcfg.get("display_name", GameManager.branch_zone)
		top_hud.set_location(bname, GameManager.branch_floor)
	else:
		top_hud.set_depth(GameManager.depth)
	top_hud.set_gold(player.gold)
	top_hud.set_turn(TurnManager.turn_number)
	top_hud.set_turn_budget(ExpeditionState.turns_remaining(), ExpeditionState.turn_budget)
	top_hud.set_buffs(player.statuses)
	top_hud.set_wounds(BodyPartSystem.active_wounds(player))
	top_hud.set_runes(player.items)
	if bottom_hud != null:
		var hostile_visible: bool = _monster_in_sight()
		bottom_hud.set_rest_label(hostile_visible)
		bottom_hud.set_act_label(hostile_visible)

func _on_player_moved(new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()
	_refresh_quickslots()
	if map != null and map.tile_at(new_pos) == DungeonMap.Tile.SHOP:
		_open_shop()

const _RESPAWN_INTERVAL: int = 18

## Per-turn passive XP for skills with no event-driven trigger:
##   stealth: trickles while no monster is aware of the player (sneaking)
##   invocations: trickles while a faith is chosen (devotional practice)
## Amounts kept tiny (0.25-0.4) since this fires every player turn — over a
## long run accumulates without dominating active skill growth.
func _grant_passive_skill_xp() -> void:
	if player == null:
		return
	var any_aware: bool = false
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.is_aware and n.hp > 0:
			any_aware = true
			break
	if not any_aware:
		player.grant_skill_xp("stealth", 0.4)
	if String(player.faith_id) != "":
		player.grant_skill_xp("invocations", 0.25)

func _on_player_turn_started() -> void:
	if player != null and player.hp > 0:
		player.tick_statuses()
		RacePassiveSystem.on_player_turn_end(player)
		_grant_passive_skill_xp()
		if ZoneManager.zone_id_for_depth(GameManager.depth) == "abyss" \
				and GameManager.branch_zone == "":
			_tick_abyss()
	if map != null:
		map.tick_fog()
		map.tick_clouds()
		_tick_cloud_damage_player()
		_tick_hazard_damage_player()
		_refresh_entity_visibility()
		# Tick corpse lifetimes
		var i: int = map.corpses.size() - 1
		while i >= 0:
			map.corpses[i]["turns_left"] -= 1
			if map.corpses[i]["turns_left"] <= 0:
				map.corpses.remove_at(i)
			i -= 1
		# Tick ally lifetimes
		for n in get_tree().get_nodes_in_group("monsters"):
			if n is Monster and n.is_ally and n.ally_turns_left > 0:
				n.ally_turns_left -= 1
				if n.ally_turns_left <= 0:
					CombatLog.post(LocaleManager.t("LOG_YOUR_FADES_AWAY") % n.data.display_name, Color(0.7, 0.7, 0.8))
					n.die()
	if TurnManager.turn_number % _RESPAWN_INTERVAL == 0:
		_try_respawn_monster()
	if not _auto_path.is_empty():
		if _new_monster_in_sight():
			_cancel_auto_walk("new enemy")
			return
		_queue_auto_walk_step()
	elif _auto_exploring:
		if _new_monster_in_sight():
			_cancel_auto_walk("new enemy")
			return
		_start_auto_explore()

## AOE bridges — Player.use_item duck-types these on the current scene.
## Pass-throughs to SpellTargeting (Phase 0 extraction).
func apply_fear_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	_spell_targeting.apply_fear_aoe(origin, radius, turns)

func apply_fog_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	_spell_targeting.apply_fog_aoe(origin, radius, turns)

func apply_silence_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	_spell_targeting.apply_silence_aoe(origin, radius, turns)

func alert_all_monsters() -> void:
	_spell_targeting.alert_all_monsters()

func dig_toward(target: Vector2i) -> void:
	_spell_targeting.dig_toward(target)

func apply_immolation_aoe(origin: Vector2i, radius: int) -> void:
	_spell_targeting.apply_immolation_aoe(origin, radius)


func _tick_cloud_damage_player() -> void:
	if player == null or player.hp <= 0 or map == null:
		return
	var cloud: Dictionary = map.cloud_tiles.get(player.grid_pos, {})
	if cloud.is_empty():
		return
	var dmg: int = _cloud_damage(cloud.get("type", "fire"), player, null)
	if dmg > 0:
		player.take_damage(dmg, "cloud_%s" % cloud.get("type", ""))
		CombatLog.damage_taken(LocaleManager.t("LOG_THE_CLOUD_BURNS_YOU_FOR") \
				% [cloud.get("type", ""), dmg])

func _tick_hazard_damage_player() -> void:
	if player == null or player.hp <= 0 or map == null:
		return
	var htype: String = map.hazard_tiles.get(player.grid_pos, "")
	if htype == "":
		return
	match htype:
		"lava":
			player.take_damage(8, "lava")
			CombatLog.damage_taken(LocaleManager.t("LOG_THE_LAVA_SCORCHES_YOU_FOR"))
		"shallow_water":
			player.apply_wet(3)

static func _cloud_damage(type: String, target_player, target_monster) -> int:
	match type:
		"fire":        return randi_range(2, 4)
		"poison":      return 1
		"cold":        return randi_range(1, 3)
		"electricity": return randi_range(1, 3)
		"lava":        return randi_range(6, 10)
	return 0

func _try_respawn_monster() -> void:
	if map == null or player == null or player.hp <= 0:
		return
	var current: int = get_tree().get_nodes_in_group("monsters").size()
	var branch_id: String = GameManager.branch_zone
	var eff_depth: int = GameManager.depth
	if branch_id != "":
		eff_depth = ZoneManager.branch_effective_depth(branch_id, GameManager.branch_floor)
	var max_count: int = _spawn_service._monster_count_for_depth(eff_depth)
	if current >= max_count:
		return
	var attempts: int = 0
	while attempts < 40:
		attempts += 1
		var p: Vector2i = map.random_floor_tile()
		if not map.is_walkable(p):
			continue
		if _chebyshev(p, player.grid_pos) < 8:
			continue
		if _monster_at(p) != null:
			continue
		var data: MonsterData
		if branch_id != "":
			data = MonsterRegistry.pick_by_branch(branch_id, eff_depth)
		else:
			data = MonsterRegistry.pick_by_depth(eff_depth)
		if data == null:
			return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		m.hit_taken.connect(_on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died)
		TurnManager.register_actor(m)
		_spawn_service._roll_monster_weapon(m)
		return

func _reset_expedition_budget() -> void:
	var depth: int = GameManager.depth
	var zone_id: String = ZoneManager.zone_id_for_depth(depth)
	var budget: int = ZoneManager.turn_budget_for_depth(depth)
	if GameManager.branch_zone != "":
		zone_id = GameManager.branch_zone
		budget = ZoneManager.turn_budget_for_branch(zone_id)
	ExpeditionState.on_floor_enter(zone_id, depth, budget)

func _on_turn_budget_exhausted() -> void:
	TurnManager.abort_actor_loop()
	var chance: float = ExpeditionState.safe_return_chance(player, GameManager.depth)
	CombatLog.post(
		LocaleManager.t("LOG_EXPEDITION_SAFE_RETURN_ATTEMPT") % int(chance * 100.0),
		Color(0.9, 0.7, 0.5))
	if randf() < chance:
		# Survival XP: successful safe return is a major endurance milestone.
		if player != null:
			player.grant_skill_xp("survival", 15.0)
		CombatLog.post(LocaleManager.t("LOG_EXPEDITION_SAFE_RETURN_OK"), Color(0.5, 0.95, 0.7))
		PartyManager.on_run_complete()
		TownState.record_safe_return({
			"race": GameManager.selected_race_id,
			"depth_reached": GameManager.depth,
			"kills": player.kills,
			"turns": TurnManager.turn_number,
		})
		await get_tree().create_timer(2.0).timeout
		get_tree().change_scene_to_file(TOWN_SCENE_PATH)
	else:
		CombatLog.post(LocaleManager.t("LOG_EXPEDITION_SAFE_RETURN_FAIL"), Color(1.0, 0.3, 0.3))
		player.last_killer = "lost in the dungeon"
		player.hp = 0
		_on_player_died()

func _on_player_died() -> void:
	# Stop the in-flight monster loop (audit H8) so subsequent actors don't
	# keep spamming damage against a corpse.
	TurnManager.abort_actor_loop()
	CombatLog.post(LocaleManager.t("LOG_YOU_DIED"), Color(1.0, 0.3, 0.3))
	PartyManager.on_run_failed()
	GameManager.end_run("death")
	TownState.record_death({
		"race": GameManager.selected_race_id,
		"depth_reached": GameManager.depth,
		"kills": player.kills,
		"turns": TurnManager.turn_number,
		"death_cause": player.last_killer,
	})
	_show_result_screen(false)

func _show_result_screen(victory: bool) -> void:
	var res = ResultScreenScene.instantiate()
	ui_layer.add_child(res)
	var data: Dictionary = {
		"victory": victory,
		"depth": GameManager.depth,
		"kills": player.kills,
		"turns": TurnManager.turn_number,
		"runes": _count_collected_runes(),
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
	GameManager.selected_race_id = ""
	get_tree().change_scene_to_file(TOWN_SCENE_PATH)

func _on_result_meta(res: Node) -> void:
	if is_instance_valid(res):
		res.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

# ── Branch navigation ────────────────────────────────────────────────────────

func _on_branch_enter() -> void:
	var branch_id: String = ZoneManager.branch_entrance_for_depth(GameManager.depth)
	if branch_id == "" or GameManager.branches_cleared.has(branch_id):
		if GameManager.branches_cleared.has(branch_id):
			CombatLog.post(LocaleManager.t("LOG_YOU_HAVE_ALREADY_CLEARED_THE") \
				% ZoneManager.branch_config(branch_id).get("display_name", branch_id),
				Color(0.7, 0.7, 0.5))
		return
	_cancel_auto_walk("branch")
	_floor_lifecycle._cache_current_floor()
	GameManager.branch_zone = branch_id
	GameManager.branch_floor = 1
	GameManager.branch_entry_depth = GameManager.depth
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	CombatLog.post(LocaleManager.t("LOG_YOU_ENTER_THE") % cfg.get("display_name", branch_id),
		Color(0.4, 1.0, 0.6))
	_despawn_companions()
	_generate_branch_floor(branch_id, 1, true)
	_spawn_companions()
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_branch_stairs_down() -> void:
	var branch_id: String = GameManager.branch_zone
	if branch_id == "":
		return
	var _floors: int = int(ZoneManager.branch_config(branch_id).get("floors", 4))
	if GameManager.branch_floor >= _floors:
		TurnManager.end_player_turn(Status.speed_mult(player))
		return
	_cancel_auto_walk("stairs")
	_cache_branch_floor(branch_id, GameManager.branch_floor)
	GameManager.branch_floor += 1
	CombatLog.post(LocaleManager.t("LOG_B") % [ZoneManager.branch_config(branch_id).get("display_name", branch_id),
		GameManager.branch_floor], Color(0.4, 1.0, 0.6))
	_despawn_companions()
	_generate_branch_floor(branch_id, GameManager.branch_floor, true)
	_spawn_companions()
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	save_with_cache()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_branch_stairs_up() -> void:
	var branch_id: String = GameManager.branch_zone
	if branch_id == "":
		return
	_cancel_auto_walk("stairs")
	_despawn_companions()
	if GameManager.branch_floor <= 1:
		# Exit branch back to main path
		_cache_branch_floor(branch_id, 1)
		GameManager.branch_zone = ""
		GameManager.branch_floor = 0
		CombatLog.post(LocaleManager.t("LOG_YOU_RETURN_TO_THE_MAIN"), Color(0.7, 0.9, 1.0))
		GameManager.depth = GameManager.branch_entry_depth
		# If the main-path floor was never cached (e.g. old save from before
		# floor_cache persistence, or branch entered on depth 1 fresh), fall
		# back to fresh generation rather than crashing on missing key.
		if GameManager.floor_cache.has(GameManager.depth):
			_floor_lifecycle._restore_floor_from_cache(GameManager.depth, false)
		else:
			_floor_lifecycle._generate_floor(GameManager.depth, _floor_lifecycle._floor_seed(GameManager.depth), false)
		_refresh_fov()
	else:
		_cache_branch_floor(branch_id, GameManager.branch_floor)
		GameManager.branch_floor -= 1
		_generate_branch_floor(branch_id, GameManager.branch_floor, false)
	_spawn_companions()
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	save_with_cache()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_branch_cleared(branch_id: String) -> void:
	if GameManager.branches_cleared.has(branch_id):
		return
	GameManager.branches_cleared.append(branch_id)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	CombatLog.post(LocaleManager.t("LOG_CLEARED") % cfg.get("display_name", branch_id), Color(1.0, 0.9, 0.3))
	# Per-branch title
	match branch_id:
		"swamp":      GameManager.earn_title("The Poisoner")
		"ice_caves":  GameManager.earn_title("The Frozen")
		"infernal":   GameManager.earn_title("The Infernal")
		"crypt": GameManager.earn_title("The Deathless")
	# All-branches bonus
	if GameManager.branches_cleared.size() >= 4:
		GameManager.earn_title("The Delver")
		CombatLog.post(LocaleManager.t("LOG_ALL_BRANCHES_CLEARED"), Color(1.0, 0.9, 0.3))

func _generate_branch_floor(branch_id: String, branch_floor: int, arrive_from_above: bool) -> void:
	var cache_key: String = "%s_%d" % [branch_id, branch_floor]
	if GameManager.branch_floor_cache.has(cache_key):
		var state: Dictionary = GameManager.branch_floor_cache[cache_key]
		map.tiles = state["tiles"]
		map.explored = state["explored"].duplicate(true)
		map.spawn_pos = state["spawn_pos"]
		map.stairs_down_pos = state["stairs_down_pos"]
		map.extra_stairs_down_positions = state.get("extra_stairs_down_positions", []).duplicate()
		map.stairs_up_pos = state["stairs_up_pos"]
		map.rooms = state["rooms"].duplicate()
		map.visible_tiles.clear()
		map.corpses = state.get("corpses", []).duplicate(true)
		for corpse in map.corpses:
			if not (corpse is Dictionary):
				continue
			if corpse.get("tile", null) != null:
				continue
			var mid: String = String(corpse.get("monster_id", ""))
			if mid == "":
				continue
			if _corpse_tex_cache.has(mid):
				corpse["tile"] = _corpse_tex_cache[mid]
				continue
			var mdata: MonsterData = MonsterRegistry.get_by_id(mid) if MonsterRegistry != null else null
			if mdata != null:
				var tex: Texture2D = _effects_layer._build_corpse_texture(mdata)
				_corpse_tex_cache[mid] = tex
				corpse["tile"] = tex
		map.cloud_tiles = state.get("cloud_tiles", {}).duplicate(true)
		map.hazard_tiles = state.get("hazard_tiles", {}).duplicate(true)
		map.fog_tiles = state.get("fog_tiles", {}).duplicate(true)
		var cfg: Dictionary = ZoneManager.branch_config(branch_id)
		map._tex_wall = load(cfg.get("wall", "")) as Texture2D
		map._tex_floor = load(cfg.get("floor", "")) as Texture2D
		map.queue_redraw()
		var arrival: Vector2i = map.spawn_pos if arrive_from_above else map.stairs_down_pos
		player.bind_map(map, arrival)
		# Restore monsters
		_spawn_service._clear_monsters()
		_spawn_service._clear_floor_items()
		_spawn_service._clear_npcs()
		for entry in state.get("monsters", []):
			var md: MonsterData = MonsterRegistry.get_by_id(String(entry.get("id", "")))
			if md == null: continue
			var p: Vector2i = entry.get("pos", Vector2i.ZERO)
			if p == player.grid_pos: continue
			var m: Monster = MonsterScene.new()
			monsters_layer.add_child(m)
			m.setup(md, map, p)
			m.hp = int(entry.get("hp", m.hp))
			m.status = entry.get("status", {}).duplicate()
			if entry.has("is_aware"): m.is_aware = bool(entry["is_aware"])
			if entry.has("is_alerted"): m.is_alerted = bool(entry["is_alerted"])
			if entry.has("last_known_player_pos"):
				var lkp = entry["last_known_player_pos"]
				if lkp is Vector2i: m.last_known_player_pos = lkp
			if entry.has("pending_energy"): m.pending_energy = float(entry["pending_energy"])
			if entry.has("_ability_charge"): m._ability_charge = (entry["_ability_charge"] as Dictionary).duplicate(true) if entry["_ability_charge"] is Dictionary else {}
			m.hit_taken.connect(_on_monster_hit.bind(m))
			if m.has_signal("awareness_changed"):
				m.awareness_changed.connect(_on_monster_awareness_changed)
			var boss_id: String = String(ZoneManager.branch_config(branch_id).get("boss_id", ""))
			if boss_id != "" and String(md.id) == boss_id:
				m.died.connect(_on_branch_boss_died.bind(branch_id))
			else:
				m.died.connect(_on_monster_died)
			TurnManager.register_actor(m)
			_spawn_service._roll_monster_weapon(m)
		for entry in state.get("items", []):
			var item_entry: Dictionary = entry.get("entry", {"id": String(entry.get("id", "")), "plus": int(entry.get("plus", 0))})
			var d: ItemData = ItemRegistry.get_by_id(String(item_entry.get("id", ""))) if ItemRegistry != null else null
			if d == null: continue
			_spawn_service._spawn_floor_item(d, entry.get("pos", Vector2i.ZERO), int(item_entry.get("plus", 0)), item_entry)
		_refresh_fov()
		return

	# Fresh branch floor generation
	var branch_seed: int = GameManager.seed ^ (branch_id.hash() + branch_floor * 17)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	var is_boss_floor: bool = (branch_floor >= int(cfg.get("floors", 4)))
	var map_style: String = String(cfg.get("map_style", "bsp"))
	map.generate(branch_seed, not is_boss_floor, map_style)
	# Boss floor: remove down stairs so player can't descend further.
	# _on_branch_boss_died will later convert stairs_down_pos → STAIRS_UP.
	if is_boss_floor:
		map.set_tile(map.stairs_down_pos, DungeonMap.Tile.FLOOR)
		map.extra_stairs_down_positions.clear()
	var eff_depth: int = ZoneManager.branch_effective_depth(branch_id, branch_floor)
	map._tex_wall = load(cfg.get("wall", "")) as Texture2D
	map._tex_floor = load(cfg.get("floor", "")) as Texture2D
	map.queue_redraw()
	var arrival_pos: Vector2i = map.spawn_pos if arrive_from_above else map.stairs_down_pos
	player.bind_map(map, arrival_pos)
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	if is_boss_floor:
		_spawn_branch_boss(branch_id)
	else:
		_spawn_branch_monsters(branch_id, eff_depth)
		_spawn_service._spawn_items_for_floor(eff_depth)
		if branch_floor == 1:
			_spawn_branch_resistance_hint(branch_id)
	_scatter_hazard_tiles(cfg.get("env", ""))
	_refresh_fov()

## Scatter persistent hazard tiles based on branch environment.
func _scatter_hazard_tiles(env: String) -> void:
	if map == null or env == "":
		return
	map.hazard_tiles.clear()
	var htype: String = ""
	var density: float = 0.0
	match env:
		"fire":   htype = "lava";          density = 0.06
		"poison": htype = "shallow_water"; density = 0.08
		"cold":   htype = "shallow_water"; density = 0.07
	if htype == "" or density == 0.0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.seed ^ env.hash()
	var floor_tiles: Array = []
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			if map.tile_at(p) == DungeonMap.Tile.FLOOR \
					and not _is_reserved_map_feature(p):
				floor_tiles.append(p)
	var count: int = int(floor_tiles.size() * density)
	for i in range(count):
		var idx: int = rng.randi_range(0, floor_tiles.size() - 1)
		map.hazard_tiles[floor_tiles[idx]] = htype
	map.queue_redraw()


func _spawn_abyss_floor(depth: int) -> void:
	_abyss_turn_counter = 0
	# Remove up stairs — no escape from the Abyss
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			if map.tile_at(p) == DungeonMap.Tile.STAIRS_UP:
				map.set_tile(p, DungeonMap.Tile.FLOOR)
	CombatLog.post(LocaleManager.t("LOG_THE_ABYSS_WARPS_AROUND_YOU"), Color(0.6, 0.3, 0.9))
	# Spawn monsters — all immediately aware
	var count: int = _spawn_service._monster_count_for_depth(depth) + 2
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_lifecycle._floor_seed(depth) ^ 0xAB155001
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = map.random_floor_tile(rng)
		if not map.is_walkable(p): continue
		if p == player.grid_pos: continue
		if _chebyshev(p, player.grid_pos) < 4: continue
		if _monster_at(p) != null: continue
		var data: MonsterData = MonsterRegistry.pick_by_depth(depth)
		if data == null: return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		m.hit_taken.connect(_on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died)
		m.become_aware(player.grid_pos)
		TurnManager.register_actor(m)
		_spawn_service._roll_monster_weapon(m)
		placed += 1

func _tick_abyss() -> void:
	if map == null or player == null:
		return
	_abyss_turn_counter += 1
	if _abyss_turn_counter % _ABYSS_SHIFT_INTERVAL != 0:
		return
	# Collect shiftable tiles (floor/wall, not player, not stairs, not monsters)
	var occupied: Dictionary = {}
	occupied[player.grid_pos] = true
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			var t: int = map.tile_at(p)
			if t == DungeonMap.Tile.STAIRS_DOWN or t == DungeonMap.Tile.STAIRS_UP:
				occupied[p] = true
	for node in get_tree().get_nodes_in_group("monsters"):
		if node is Monster:
			occupied[(node as Monster).grid_pos] = true
	var visible_candidates: Array = []
	var distant_candidates: Array = []
	for y in range(1, DungeonMap.GRID_H - 1):
		for x in range(1, DungeonMap.GRID_W - 1):
			var p := Vector2i(x, y)
			if occupied.has(p):
				continue
			var t: int = map.tile_at(p)
			if t == DungeonMap.Tile.FLOOR or t == DungeonMap.Tile.WALL:
				if map.visible_tiles.has(p):
					visible_candidates.append(p)
				else:
					distant_candidates.append(p)
	visible_candidates.shuffle()
	distant_candidates.shuffle()
	# Guarantee at least half the shifts are within the player's view
	var vis_quota: int = _ABYSS_SHIFT_COUNT / 2
	var all_candidates: Array = visible_candidates.slice(0, vis_quota) \
			+ distant_candidates + visible_candidates.slice(vis_quota)
	var flipped: int = 0
	for p in all_candidates:
		if flipped >= _ABYSS_SHIFT_COUNT:
			break
		var t: int = map.tile_at(p)
		map.set_tile(p, DungeonMap.Tile.WALL if t == DungeonMap.Tile.FLOOR else DungeonMap.Tile.FLOOR)
		map.explored.erase(p)
		flipped += 1
	# Move the exit to a new reachable floor tile
	var new_exit: Vector2i = _abyss_find_new_exit()
	if new_exit != Vector2i(-1, -1):
		# Clear old exits
		for y in range(DungeonMap.GRID_H):
			for x in range(DungeonMap.GRID_W):
				if map.tile_at(Vector2i(x, y)) == DungeonMap.Tile.STAIRS_DOWN:
					map.set_tile(Vector2i(x, y), DungeonMap.Tile.FLOOR)
		map.stairs_down_pos = new_exit
		map.extra_stairs_down_positions.clear()
		map.set_tile(new_exit, DungeonMap.Tile.STAIRS_DOWN)
		CombatLog.post(LocaleManager.t("LOG_THE_ABYSS_SHIFTS_THE_EXIT"), Color(0.6, 0.3, 0.9))
	map.queue_redraw()

func _abyss_find_new_exit() -> Vector2i:
	# BFS from player to find floor tiles, pick one far away
	var dist: Dictionary = {player.grid_pos: 0}
	var frontier: Array[Vector2i] = [player.grid_pos]
	var far_tiles: Array = []
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		var d: int = int(dist[p])
		if d >= 8:
			far_tiles.append(p)
		for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var n: Vector2i = p + step
			if dist.has(n): continue
			if not map.is_walkable(n): continue
			dist[n] = d + 1
			frontier.append(n)
	if far_tiles.is_empty():
		return Vector2i(-1, -1)
	return far_tiles[randi() % far_tiles.size()]

func _spawn_branch_monsters(branch_id: String, eff_depth: int) -> void:
	var count: int = _spawn_service._monster_count_for_depth(eff_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_lifecycle._floor_seed(eff_depth) ^ 0xBBAACC11
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = map.random_floor_tile(rng)
		if not map.is_walkable(p): continue
		if p == player.grid_pos: continue
		if _chebyshev(p, player.grid_pos) < 3: continue
		if _monster_at(p) != null: continue
		var data: MonsterData = MonsterRegistry.pick_by_branch(branch_id, eff_depth)
		if data == null: return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		m.hit_taken.connect(_on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died)
		TurnManager.register_actor(m)
		_spawn_service._roll_monster_weapon(m)
		placed += 1

func _spawn_branch_boss(branch_id: String) -> void:
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	var boss_id: String = String(cfg.get("boss_id", ""))
	if boss_id == "":
		return
	var boss_data: MonsterData = MonsterRegistry.get_by_id(boss_id)
	if boss_data == null:
		push_warning("Branch boss not found: %s" % boss_id)
		return
	var stair_candidates: Array[Vector2i] = _all_down_stairs_positions()
	var spawn_pos: Vector2i = stair_candidates[0] if not stair_candidates.is_empty() else map.stairs_down_pos
	# Place boss in center of a room far from player
	if not map.rooms.is_empty():
		var mid_room: Rect2i = map.rooms[map.rooms.size() / 2]
		spawn_pos = mid_room.get_center()
	var m: Monster = MonsterScene.new()
	monsters_layer.add_child(m)
	m.setup(boss_data, map, spawn_pos)
	m.hit_taken.connect(_on_monster_hit.bind(m))
	if m.has_signal("awareness_changed"):
		m.awareness_changed.connect(_on_monster_awareness_changed)
	m.died.connect(_on_branch_boss_died.bind(branch_id))
	TurnManager.register_actor(m)
	_spawn_service._roll_monster_weapon(m)
	CombatLog.post(LocaleManager.t("LOG_A_POWERFUL_PRESENCE_FILLS_THE"), Color(1.0, 0.5, 0.2))

func _spawn_branch_resistance_hint(branch_id: String) -> void:
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	if FaithSystem.allows_essence(player):
		var essence_id: String = String(cfg.get("essence_reward", ""))
		if essence_id != "":
			_spawn_service._spawn_essence_floor_item(essence_id, map.spawn_pos + Vector2i(1, 0))
			CombatLog.post(LocaleManager.t("LOG_THE_ENVIRONMENT_HERE_IS_HOSTILE"), Color(0.9, 0.85, 0.4))
	else:
		var ring_id: String = String(cfg.get("resist_ring", ""))
		if ring_id != "":
			var ring_data: ItemData = ItemRegistry.get_by_id(ring_id) if ItemRegistry != null and ring_id != "" else null
			if ring_data != null:
				_spawn_service._spawn_floor_item(ring_data, map.spawn_pos + Vector2i(1, 0), 0)
				CombatLog.post(LocaleManager.t("LOG_THE_ENVIRONMENT_HERE_IS_HOSTILE_2"), Color(0.9, 0.85, 0.4))

func _on_branch_boss_died(monster: Monster, branch_id: String) -> void:
	_on_monster_died(monster)
	_on_branch_cleared(branch_id)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	# Brand scroll reward
	var element: String = String(cfg.get("brand_element", ""))
	var scroll_id: String = "scroll_brand_%s" % element
	var scroll_data: ItemData = ItemRegistry.get_by_id(scroll_id) if ItemRegistry != null and scroll_id != "" else null
	if scroll_data != null:
		_spawn_service._spawn_floor_item(scroll_data, monster.grid_pos, 0)
	# Rune — always dropped near the boss
	var rune_id: String = String(cfg.get("rune_reward", ""))
	if rune_id != "":
		var rune_data: ItemData = ItemRegistry.get_by_id(rune_id) if ItemRegistry != null and rune_id != "" else null
		if rune_data != null:
			_spawn_service._spawn_floor_item(rune_data, monster.grid_pos, 0)
			CombatLog.post(LocaleManager.t("LOG_A_RUNE_MATERIALISES"), Color(1.0, 0.9, 0.3))
	# Essence or ring depending on faith
	if FaithSystem.allows_essence(player):
		var essence_id: String = String(cfg.get("essence_reward", ""))
		if essence_id != "":
			_spawn_service._spawn_essence_floor_item(essence_id, monster.grid_pos)
	else:
		var ring_id: String = String(cfg.get("ring_reward", ""))
		if ring_id != "":
			var ring_data: ItemData = ItemRegistry.get_by_id(ring_id) if ItemRegistry != null and ring_id != "" else null
			if ring_data != null:
				_spawn_service._spawn_floor_item(ring_data, monster.grid_pos, 0)
				CombatLog.post(LocaleManager.t("LOG_A_UNIQUE_RING_APPEARS"), Color(0.8, 0.7, 1.0))
	# Place stairs back to main
	for p in _all_down_stairs_positions():
		map.set_tile(p, DungeonMap.Tile.STAIRS_UP)
	map.extra_stairs_down_positions.clear()

func _cache_branch_floor(branch_id: String, branch_floor: int) -> void:
	var cache_key: String = "%s_%d" % [branch_id, branch_floor]
	var state: Dictionary = {
		"tiles": PackedByteArray(map.tiles),
		"explored": map.explored.duplicate(true),
		"spawn_pos": map.spawn_pos,
		"stairs_down_pos": map.stairs_down_pos,
		"extra_stairs_down_positions": map.extra_stairs_down_positions.duplicate(),
		"stairs_up_pos": map.stairs_up_pos,
		"rooms": map.rooms.duplicate(),
		"items": [],
		"monsters": [],
		"corpses": map.corpses.duplicate(true),
		"cloud_tiles": map.cloud_tiles.duplicate(true),
		"hazard_tiles": map.hazard_tiles.duplicate(true),
		"fog_tiles": map.fog_tiles.duplicate(true),
	}
	for n in get_tree().get_nodes_in_group("floor_items"):
		if n is FloorItem and n.data != null:
			state.items.append({"id": n.data.id, "pos": n.grid_pos, "plus": n.plus, "entry": n.entry.duplicate(true) if not n.entry.is_empty() else {"id": n.data.id, "plus": n.plus}})
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.data != null and n.hp > 0:
			var msnap: Dictionary = {"id": n.data.id, "pos": n.grid_pos, "hp": n.hp,
				"status": n.status.duplicate()}
			if "is_aware" in n: msnap["is_aware"] = n.is_aware
			if "is_alerted" in n: msnap["is_alerted"] = n.is_alerted
			if "last_known_player_pos" in n: msnap["last_known_player_pos"] = n.last_known_player_pos
			if "pending_energy" in n: msnap["pending_energy"] = n.pending_energy
			if "_ability_charge" in n: msnap["_ability_charge"] = n._ability_charge
			state.monsters.append(msnap)
	GameManager.branch_floor_cache[cache_key] = state

# Single source of truth for persisting a run — caches the current floor
# (main or branch) before writing the save, so mid-floor saves include
# alive monsters, dropped items, fog, hazards, corpses, and awareness flags.
func save_with_cache() -> void:
	if map == null or player == null:
		return
	if GameManager.branch_zone != "" and GameManager.branch_floor > 0:
		_cache_branch_floor(GameManager.branch_zone, GameManager.branch_floor)
	else:
		_floor_lifecycle._cache_current_floor()
	SaveManager.save_run(player, GameManager)

func _on_dungeon_cleared() -> void:
	CombatLog.post(LocaleManager.t("LOG_YOU_HAVE_CLEARED_THE_DUNGEON"), Color(1.0, 0.9, 0.2))
	PartyManager.on_run_complete()
	GameManager.end_run("victory")
	TownState.record_victory({
		"race": GameManager.selected_race_id,
		"depth_reached": GameManager.depth,
		"kills": player.kills,
		"turns": TurnManager.turn_number,
		"death_cause": "",
	})
	_show_result_screen(true)

func _count_collected_runes() -> int:
	if player == null:
		return 0
	var count: int = 0
	for entry in player.items:
		var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
		if d != null and d.kind == "rune":
			count += 1
	return count

func _on_stairs_down() -> void:
	# Inside a branch — go deeper in branch
	if GameManager.branch_zone != "":
		_on_branch_stairs_down()
		return
	_cancel_auto_walk("stairs")
	_floor_lifecycle._cache_current_floor()
	GameManager.descend()
	if GameManager.depth >= 6:
		_on_dungeon_cleared()
		return
	CombatLog.post(LocaleManager.t("LOG_YOU_DESCEND_TO_B") % GameManager.depth, Color(0.6, 1.0, 1.0))
	_despawn_companions()
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	_floor_lifecycle._generate_floor(GameManager.depth, _floor_lifecycle._floor_seed(GameManager.depth), true)
	_spawn_companions()
	RacePassiveSystem.on_floor_changed(player)
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	save_with_cache()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_stairs_up() -> void:
	if GameManager.branch_zone != "":
		_on_branch_stairs_up()
		return
	if GameManager.depth <= 1:
		CombatLog.post(LocaleManager.t("LOG_THE_WAY_UP_IS_BLOCKED"), Color(0.7, 0.7, 0.7))
		TurnManager.end_player_turn(Status.speed_mult(player))
		return
	_cancel_auto_walk("stairs")
	_floor_lifecycle._cache_current_floor()
	GameManager.ascend()
	CombatLog.post(LocaleManager.t("LOG_YOU_CLIMB_TO_B") % GameManager.depth,
		Color(0.85, 1.0, 0.85))
	_despawn_companions()
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	_floor_lifecycle._generate_floor(GameManager.depth, _floor_lifecycle._floor_seed(GameManager.depth), false)
	_spawn_companions()
	RacePassiveSystem.on_floor_changed(player)
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	save_with_cache()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _travel_to_floor(target_depth: int) -> void:
	if target_depth == GameManager.depth:
		return
	if not GameManager.floor_cache.has(target_depth):
		return
	_cancel_auto_walk("floor travel")
	_floor_lifecycle._cache_current_floor()
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	var going_down: bool = target_depth > GameManager.depth
	GameManager.travel_to(target_depth)
	CombatLog.post(LocaleManager.t("LOG_YOU_TRAVEL_TO_B") % target_depth, Color(0.7, 0.9, 1.0))
	_floor_lifecycle._generate_floor(target_depth, _floor_lifecycle._floor_seed(target_depth), going_down)
	RacePassiveSystem.on_floor_changed(player)
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
	save_with_cache()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_item_dropped(entry: Dictionary, at_pos: Vector2i) -> void:
	var item_id: String = String(entry.get("id", ""))
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null and item_id != "" else null
	if data == null:
		return
	_spawn_service._spawn_floor_item(data, at_pos, int(entry.get("plus", 0)), entry)
	var item_name: String = ItemRegistry.entry_display_name(entry) if ItemRegistry != null else GameManager.display_name_of(item_id)
	CombatLog.post(LocaleManager.t("LOG_YOU_DROP") % item_name)

func _on_menu_button_pressed() -> void:
	var dlg: GameDialog = GameDialog.create("Menu")
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 10)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.custom_minimum_size = Vector2(0, 56)
	save_btn.add_theme_font_size_override("font_size", 24)
	save_btn.pressed.connect(func():
		save_with_cache()
		CombatLog.post(LocaleManager.t("LOG_GAME_SAVED"), Color(0.6, 0.9, 0.6))
		dlg.queue_free())
	body.add_child(save_btn)

	var bestiary_btn := Button.new()
	bestiary_btn.text = "Bestiary"
	bestiary_btn.custom_minimum_size = Vector2(0, 56)
	bestiary_btn.add_theme_font_size_override("font_size", 24)
	bestiary_btn.pressed.connect(func():
		dlg.queue_free()
		BestiaryDialog.open(self))
	body.add_child(bestiary_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Save & Main Menu"
	quit_btn.custom_minimum_size = Vector2(0, 56)
	quit_btn.add_theme_font_size_override("font_size", 24)
	quit_btn.pressed.connect(func():
		save_with_cache()
		get_tree().change_scene_to_file(MENU_SCENE_PATH))
	body.add_child(quit_btn)

func _on_bag_pressed() -> void:
	if player == null:
		return
	BagDialog.open(player, self)

func _on_status_pressed() -> void:
	if player == null:
		return
	StatusDialog.open(player, self)


func _on_party_pressed() -> void:
	_open_party_dialog()


func _open_party_dialog() -> void:
	var active := PartyManager.get_active_companions()
	if active.is_empty():
		CombatLog.post("동료가 없습니다.", Color(0.7, 0.7, 0.7))
		return
	var dlg: GameDialog = GameDialog.create_ratio("파티", 0.9, 0.85)
	add_child(dlg)
	var body: VBoxContainer = dlg.get_body()
	for cdata in active:
		var companion_btn := Button.new()
		companion_btn.text = cdata.display_name + "  XL" + str(cdata.xl) + \
			("  [장기]" if cdata.is_long_term else "")
		companion_btn.pressed.connect(func() -> void:
			CompanionUI.open(cdata, player, self))
		body.add_child(companion_btn)
	# Hire button — show if can recruit and pool is not empty
	if PartyManager.can_recruit() and not PartyManager.hireable_pool.is_empty():
		var sep := HSeparator.new()
		body.add_child(sep)
		var hire_lbl := Label.new()
		hire_lbl.text = "고용 가능"
		hire_lbl.add_theme_color_override("font_color", Color(0.8, 0.9, 0.6))
		body.add_child(hire_lbl)
		for cdata in PartyManager.hireable_pool:
			var hire_btn := Button.new()
			hire_btn.text = "[고용] " + cdata.display_name + " (" + _job_display(cdata.job_id) + ")"
			hire_btn.pressed.connect(func() -> void:
				if PartyManager.recruit(cdata):
					_spawn_companions()
					dlg.close()
					_open_party_dialog())
			body.add_child(hire_btn)


func _job_display(job_id: String) -> String:
	match job_id:
		"fighter": return "전사"
		"ranger": return "궁수"
		"mage": return "마법사"
	return job_id


func _on_bestiary_pressed() -> void:
	if player == null:
		return
	BestiaryDialog.open(self)

func begin_spell_targeting(spell: SpellData, p: Player) -> void:
	_spell_targeting.begin_spell_targeting(spell, p)

func begin_spell_targeting_auto(spell: SpellData, p: Player) -> void:
	_spell_targeting.begin_spell_targeting_auto(spell, p)

func begin_throw_targeting(entry: Dictionary) -> void:
	if player == null or map == null:
		return
	_spell_targeting._cancel_targeting()
	_targeting_throw_entry = entry.duplicate()
	var visible: Dictionary = player.compute_fov()
	_targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - player.grid_pos.x), abs(tile.y - player.grid_pos.y))
		if d > 0 and d <= ThrowSystem.THROW_RANGE:
			_targeting_tiles.append(tile)
	_targeting_node = SpellTargetOverlay.new()
	_effect_layer.add_child(_targeting_node)
	_targeting_node.init(null, player, _targeting_tiles)
	CombatLog.post("Select a tile to throw to (tap again to cancel).", Color(0.85, 0.85, 0.5))

func _confirm_throw(tile: Vector2i) -> void:
	var entry: Dictionary = _targeting_throw_entry.duplicate()
	_cancel_throw()
	ThrowSystem.resolve(entry, tile, player, self)
	TurnManager.end_player_turn(Status.speed_mult(player))

func _cancel_throw() -> void:
	_targeting_throw_entry = {}
	_targeting_tiles = []
	if _targeting_node != null:
		_targeting_node.queue_free()
		_targeting_node = null

func _on_rest_pressed() -> void:
	if player == null or player.hp <= 0 or not TurnManager.is_player_turn:
		return
	if _monster_in_sight():
		# WAIT: single turn pass when enemies are visible
		player.wait_turn()
		TurnManager.end_player_turn(Status.speed_mult(player))
		return
	if player.hp >= player.hp_max and player.mp >= player.mp_max:
		CombatLog.post(LocaleManager.t("LOG_YOU_ARE_ALREADY_FULLY_RESTED"), Color(0.7, 0.9, 0.6))
		return
	var ticks: int = 0
	while ticks < 100 and (player.hp < player.hp_max or player.mp < player.mp_max) and player.hp > 0:
		player.wait_turn()
		TurnManager.end_player_turn(Status.speed_mult(player), true)
		ticks += 1
		if _monster_in_sight():
			CombatLog.post(LocaleManager.t("LOG_YOU_STOP_RESTING_ENEMY_SPOTTED"), Color(1.0, 0.7, 0.5))
			break

func _monster_in_sight() -> bool:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and not n.is_ally and map.visible_tiles.has(n.grid_pos):
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
	var spell: SpellData = SpellRegistry.get_by_id(slot_id)
	if spell != null:
		if not TurnManager.is_player_turn:
			return
		if spell.targeting in ["single", "auto", "nearest"]:
			begin_spell_targeting_auto(spell, player)
		else:
			var ok: bool = MagicSystem.cast(slot_id, player, self)
			if ok:
				player.play_spellcast_anim()
				TurnManager.end_player_turn(Status.speed_mult(player))
		return
	const _WAND_ELEMENTS := {"wand_fire": "fire", "wand_frost": "cold", "wand_lightning": "lightning"}
	if _WAND_ELEMENTS.has(slot_id):
		if player.count_item(slot_id) == 0:
			QuickslotPicker.open(player, self, index, _refresh_quickslots)
			return
		if not TurnManager.is_player_turn:
			return
		_use_targeting_wand(slot_id, _WAND_ELEMENTS[slot_id], index)
		return
	if player.count_item(slot_id) == 0:
		QuickslotPicker.open(player, self, index, _refresh_quickslots)
		return
	if not TurnManager.is_player_turn:
		return
	var used: bool = player.use_quickslot(index)
	_refresh_quickslots()
	if used:
		TurnManager.end_player_turn(Status.speed_mult(player))

func _use_targeting_wand(item_id: String, element: String, slot_index: int) -> void:
	var visible: Dictionary = player.compute_fov()
	var best: Monster = null
	var best_d: int = 999
	for n in get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x), abs(n.grid_pos.y - player.grid_pos.y))
		if d < best_d:
			best_d = d
			best = n
	if best == null:
		CombatLog.post(LocaleManager.t("LOG_NO_TARGETS_IN_RANGE"), Color(0.75, 0.75, 0.75))
		return
	var dmg: int = 8 + randi_range(0, 8)
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	var ws: Vector2 = map.grid_to_world(player.grid_pos) + half
	var we: Vector2 = map.grid_to_world(best.grid_pos) + half
	var target_ref := best
	spawn_spell_bolt(ws, we, element, func():
		if is_instance_valid(target_ref) and target_ref.hp > 0:
			target_ref.take_damage(dmg)
	)
	CombatLog.post(LocaleManager.t("LOG_THE_WAND_FIRES_AT_THE") % best.data.display_name, Color(1.0, 0.85, 0.4))
	player.use_quickslot(slot_index)
	_refresh_quickslots()
	TurnManager.end_player_turn(Status.speed_mult(player))

func _on_quickslot_long_pressed(index: int) -> void:
	if player == null:
		return
	QuickslotPicker.open(player, self, index, _refresh_quickslots)

func _on_quickslot_swap_requested(from_index: int, to_index: int) -> void:
	if player == null:
		return
	if from_index < 0 or to_index < 0:
		return
	if from_index >= player.quickslots.size() or to_index >= player.quickslots.size():
		return
	var tmp: String = String(player.quickslots[from_index])
	player.quickslots[from_index] = String(player.quickslots[to_index])
	player.quickslots[to_index] = tmp
	_refresh_quickslots()

func _on_log_tapped() -> void:
	LogDialog.open(self)

func _on_item_slot_pressed(index: int) -> void:
	if player == null or player.hp <= 0:
		return
	if not TurnManager.is_player_turn:
		return
	var item_ids: Array[String] = _top_item_bar_ids()
	if index < 0 or index >= item_ids.size():
		return
	var target_id: String = item_ids[index]
	if target_id == "":
		return
	for i in range(player.items.size()):
		if String(player.items[i].get("id", "")) == target_id:
			player.use_item(i)
			_refresh_quickslots()
			TurnManager.end_player_turn(Status.speed_mult(player))
			return

func _top_item_bar_ids() -> Array[String]:
	var result: Array[String] = []
	if player == null:
		return result
	var seen: Dictionary = {}
	for entry in player.items:
		var id: String = String(entry.get("id", ""))
		if id == "" or seen.has(id):
			continue
		var data: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
		if data == null:
			continue
		if data.kind in ["weapon", "armor", "shield", "ring", "amulet", "gold", "essence"]:
			continue
		seen[id] = true
		result.append(id)
		if result.size() >= 4:
			break
	return result

func _refresh_quickslots() -> void:
	if player == null:
		return
	if bottom_hud == null:
		return
	for i in range(player.quickslots.size()):
		var id: String = String(player.quickslots[i])
		if id == "":
			bottom_hud.set_quickslot(i, null, "")
			continue
		var spell: SpellData = SpellRegistry.get_by_id(id)
		if spell != null:
			if spell.icon_path != "" and ResourceLoader.exists(spell.icon_path):
				var tex: Texture2D = load(spell.icon_path)
				bottom_hud.set_quickslot(i, tex, "")
			else:
				bottom_hud.set_quickslot_display(i, spell.display_name.left(3), Color(0.7, 0.5, 1.0))
			continue
		var data2: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
		if data2 == null:
			bottom_hud.set_quickslot(i, null, "")
			continue
		var count2: int = player.count_item(id)
		if count2 <= 0:
			player.quickslots[i] = ""
			bottom_hud.set_quickslot(i, null, "")
			continue
		var text2: String = ("x%d" % count2) if count2 > 1 else ""
		if GameManager.use_tiles and data2.tile_path != "":
			var tex2: Texture2D = _make_item_icon(data2)
			if tex2 != null:
				bottom_hud.set_quickslot(i, tex2, text2)
			else:
				bottom_hud.set_quickslot_display(i, data2.glyph, data2.glyph_color)
		else:
			bottom_hud.set_quickslot_display(i, data2.glyph, data2.glyph_color)

func _make_item_icon(data: ItemData) -> Texture2D:
	var base_path: String = data.tile_path
	if data.kind == "potion":
		base_path = GameManager.potion_color_tile(data.id)
	if base_path == "" or not ResourceLoader.exists(base_path):
		return null
	if GameManager.is_identified(data.id) and data.identified_tile_path != "" \
			and ResourceLoader.exists(data.identified_tile_path):
		var img_base: Image = (load(base_path) as Texture2D).get_image()
		var img_over: Image = (load(data.identified_tile_path) as Texture2D).get_image()
		if data.kind == "potion":
			# Small corner overlay (bottom-right ~44% of tile size).
			var base_w: int = img_base.get_width()
			var base_h: int = img_base.get_height()
			var cw: int = int(base_w * 0.44)
			var ch: int = int(base_h * 0.44)
			img_over.resize(cw, ch, Image.INTERPOLATE_BILINEAR)
			img_base.blend_rect(img_over,
					Rect2i(Vector2i.ZERO, Vector2i(cw, ch)),
					Vector2i(base_w - cw, base_h - ch))
		else:
			if img_base.get_size() == img_over.get_size():
				img_base.blend_rect(img_over,
						Rect2i(Vector2i.ZERO, img_over.get_size()), Vector2i.ZERO)
		return ImageTexture.create_from_image(img_base)
	return load(base_path) as Texture2D

func _on_magic_pressed() -> void:
	if player == null:
		return
	MagicDialog.open(player, self)

func _on_menu_pressed() -> void:
	PauseMenuDialog.open(self)

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _monster_at(pos: Vector2i) -> Monster:
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null

func _all_down_stairs_positions() -> Array[Vector2i]:
	if map == null:
		return []
	return map.all_stairs_down_positions()

func _is_reserved_map_feature(p: Vector2i) -> bool:
	return map != null and map.is_reserved_feature_tile(p)

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
		if player.can_attack_tile(nearest.grid_pos):
			player.try_attack_tile(nearest.grid_pos)
			return
		var dir := _greedy_step_toward(nearest.grid_pos)
		if dir != Vector2i.ZERO:
			player.try_step(dir)
		else:
			CombatLog.post(LocaleManager.t("LOG_CAN_T_REACH_THE") % nearest.data.display_name,
					Color(1.0, 0.7, 0.5))
	else:
		_start_auto_explore()


func _pickup_current_tile() -> bool:
	if player == null or player.hp <= 0 or not TurnManager.is_player_turn:
		return false
	var item: FloorItem = _item_at(player.grid_pos)
	if item == null:
		return false
	player.pickup(item)
	TurnManager.end_player_turn(Status.speed_mult(player))
	return true

func _pickup_essence_floor_item(floor_item: FloorItem) -> void:
	if floor_item == null or floor_item.data == null:
		return
	var essence_id: String = String(floor_item.entry.get("essence_id", ""))
	if essence_id == "":
		return
	_queue_essence_pickup(essence_id, floor_item)


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
		CombatLog.post(LocaleManager.t("LOG_NOWHERE_LEFT_TO_EXPLORE"), Color(0.7, 0.9, 0.7))
		return
	var path := _bfs_path(player.grid_pos, target)
	if path.is_empty():
		_auto_exploring = false
		CombatLog.post(LocaleManager.t("LOG_CAN_T_REACH_UNEXPLORED_AREA"), Color(0.7, 0.7, 0.5))
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
			var nt2 := map.tile_at(n)
			if (not map.is_walkable(n) and nt2 != DungeonMap.Tile.DOOR_CLOSED) or not map.explored.has(n):
				continue
			visited[n] = true
			queue.append(n)
	return Vector2i(-1, -1)


func _nearest_visible_monster() -> Monster:
	var nearest: Monster = null
	var best: int = 99999
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and not n.is_ally and map.visible_tiles.has(n.grid_pos):
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
	# Allies don't give XP or drops
	if monster != null and monster.is_ally:
		return
	# Drop equipped weapon
	if monster != null and monster.equipped_weapon_id != "":
		var wdata: ItemData = ItemRegistry.get_by_id(monster.equipped_weapon_id) if ItemRegistry != null else null
		if wdata != null:
			_spawn_service._spawn_floor_item(wdata, monster.grid_pos, 0)
	# Leave a corpse (non-unique only)
	if monster != null and monster.data != null and not monster.data.is_unique:
		map.corpses.append({
			"pos": monster.grid_pos,
			"monster_id": String(monster.data.id),
			"tile": _effects_layer._corpse_tile_for_monster(monster),
			"turns_left": 40,
		})
		map.queue_redraw()
	# Death faith: on-kill HP/MP sustain
	var kill_hp: int = FaithSystem.on_kill_hp(player)
	var kill_mp: int = FaithSystem.on_kill_mp(player)
	if kill_hp > 0:
		player.heal(kill_hp)
	if kill_mp > 0:
		player.mp = min(player.mp_max, player.mp + kill_mp)
	# Final boss death → victory
	if monster != null and monster.data != null \
			and monster.data.id == "abyssal_sovereign":
		await get_tree().create_timer(1.2).timeout
		CombatLog.post(LocaleManager.t("LOG_THE_ABYSSAL_SOVEREIGN_COLLAPSES_THE"),
				Color(0.85, 0.6, 1.0))
		await get_tree().create_timer(1.5).timeout
		TownState.record_victory({
			"race": GameManager.selected_race_id,
			"depth_reached": GameManager.depth,
			"kills": player.kills,
			"turns": TurnManager.turn_number,
			"death_cause": "",
		})
		_show_result_screen(true)
		return
	_handle_monster_essence_drop(monster)

func _handle_monster_essence_drop(monster: Monster) -> void:
	if monster == null or monster.data == null:
		return
	if monster.data.is_unique:
		var drop_chance: float = monster.data.drop_chance_override if monster.data.drop_chance_override >= 0.0 else 0.5
		drop_chance = minf(1.0, drop_chance + FaithSystem.unique_essence_drop_bonus(player))
		if randf() >= drop_chance:
			return
		var uid: String = String(monster.data.essence_id)
		if uid == "":
			uid = EssenceSystem.random_id()
		CombatLog.post(LocaleManager.t("LOG_THE_LEAVES_BEHIND_AN_ESSENCE") % [
			monster.data.display_name, EssenceSystem.display_name(uid)],
			Color(1.0, 0.75, 0.3))
		_spawn_service._spawn_essence_floor_item(uid, monster.grid_pos)
		return
	# Tuned 2026-05-06: 0.22+d×0.01/0.40 → 0.10+d×0.005/0.20 → 0.05+d×0.003/0.12.
	# Original was every 3-4 kills (clutter). First cut to every 7-10 kills was
	# still too frequent; this lands at every 15-20 kills so essences feel
	# noticeably rare and worth picking up.
	var chance: float = min(0.05 + GameManager.depth * 0.003, 0.12)
	if randf() >= chance:
		return
	var essence_id: String
	if String(monster.data.essence_id) != "":
		essence_id = String(monster.data.essence_id)
	else:
		essence_id = EssenceSystem.random_id()
	CombatLog.post(LocaleManager.t("LOG_AN_ESSENCE_MATERIALIZES") % EssenceSystem.display_name(essence_id),
		Color(0.8, 0.6, 1.0))
	_spawn_service._spawn_essence_floor_item(essence_id, monster.grid_pos)

func _on_monster_hit(amount: int, monster: Monster) -> void:
	if not is_instance_valid(monster):
		return
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = monster.position + Vector2(cell_size * 0.5, 0.0)
	spawn_damage_number(world_pos, amount, Color(1.0, 0.85, 0.2))

func _on_monster_awareness_changed(monster: Monster, aware: bool) -> void:
	if not is_instance_valid(monster) or monster.data == null or player == null or map == null:
		return
	var sees_monster: bool = map.visible_tiles.has(monster.grid_pos)
	if not sees_monster:
		return
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = monster.position + Vector2(cell_size * 0.5, -6.0)
	if aware:
		CombatLog.post(LocaleManager.t("LOG_THE_NOTICES_YOU") % monster.data.display_name, Color(1.0, 0.72, 0.45))
		spawn_text_popup(world_pos, "!", Color(1.0, 0.72, 0.35), 32, 0.55)
	else:
		CombatLog.post(LocaleManager.t("LOG_THE_LOSES_TRACK_OF_YOU") % monster.data.display_name, Color(0.7, 0.82, 0.95))
		spawn_text_popup(world_pos, "?", Color(0.75, 0.88, 1.0), 26, 0.5)

func _on_player_damaged(amount: int) -> void:
	if player == null:
		return
	# Survival XP: endurance gained from taking hits (while still alive).
	if amount > 0 and player.hp > 0:
		player.grant_skill_xp("survival", float(amount) * 0.3)
	var cell_size: float = DungeonMap.CELL_SIZE
	var world_pos: Vector2 = player.position + Vector2(cell_size * 0.5, 0.0)
	spawn_damage_number(world_pos, amount, Color(1.0, 0.35, 0.35))
	spawn_hit_flash(player)


## Spawn a floating damage number at the given world position.
func spawn_damage_number(world_pos: Vector2, amount: int, color: Color) -> void:
	_effects_layer.spawn_damage_number(world_pos, amount, color)

func spawn_text_popup(world_pos: Vector2, text: String, color: Color,
		font_size: int = 28, duration: float = 0.6) -> void:
	_effects_layer.spawn_text_popup(world_pos, text, color, font_size, duration)


func _on_player_weapon_attacked(_target: Vector2i, _weapon_skill: String) -> void:
	pass

## Spawn a brief hit flash on a monster sprite node.
func spawn_hit_flash(target_node: Node2D) -> void:
	_effects_layer.spawn_hit_flash(target_node)

## Spawn a DCSS tile projectile from world_start to world_end.
func spawn_projectile(world_start: Vector2, world_end: Vector2,
		_color: Color, on_arrive: Callable = Callable()) -> void:
	_effects_layer.spawn_projectile(world_start, world_end, _color, on_arrive)

func spawn_spell_bolt(world_start: Vector2, world_end: Vector2,
		element: String, on_arrive: Callable = Callable(),
		delay: float = 0.0) -> void:
	_effects_layer.spawn_spell_bolt(world_start, world_end, element, on_arrive, delay)

func spawn_hit_effect(_world_pos: Vector2, _element: String) -> void:
	_effects_layer.spawn_hit_effect(_world_pos, _element)

func spawn_aoe_burst(_target_positions: Array, _element: String) -> void:
	_effects_layer.spawn_aoe_burst(_target_positions, _element)

# ── Archmage debug floor panel ───────────────────────────────────────────────
var _debug_panel: PanelContainer = null
var _debug_panel_visible: bool = false

func _spawn_debug_floor_panel() -> void:
	# Toggle button in top-left corner
	var toggle := Button.new()
	toggle.text = "B?"
	toggle.add_theme_font_size_override("font_size", 22)
	toggle.custom_minimum_size = Vector2(64, 48)
	toggle.anchor_left = 0.0
	toggle.anchor_top = 0.0
	toggle.anchor_right = 0.0
	toggle.anchor_bottom = 0.0
	toggle.offset_left = 8.0
	toggle.offset_top = 8.0
	toggle.offset_right = 72.0
	toggle.offset_bottom = 56.0
	ui_layer.add_child(toggle)

	# Panel
	_debug_panel = PanelContainer.new()
	_debug_panel.anchor_left = 0.0
	_debug_panel.anchor_top = 0.0
	_debug_panel.anchor_right = 0.0
	_debug_panel.anchor_bottom = 0.0
	_debug_panel.offset_left = 8.0
	_debug_panel.offset_top = 62.0
	_debug_panel.offset_right = 360.0
	_debug_panel.offset_bottom = 620.0
	_debug_panel.visible = false
	ui_layer.add_child(_debug_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(352, 550)
	_debug_panel.add_child(scroll)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	scroll.add_child(vb)

	# Main floors 1-16
	var hdr := Label.new()
	hdr.text = "── Main Dungeon ──"
	hdr.add_theme_font_size_override("font_size", 20)
	hdr.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(hdr)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)
	for d in range(1, 17):
		var btn := Button.new()
		btn.text = "B%d" % d
		btn.custom_minimum_size = Vector2(72, 48)
		btn.add_theme_font_size_override("font_size", 20)
		btn.pressed.connect(_debug_warp_to.bind(d))
		grid.add_child(btn)

	# Branch sections
	var branches: Dictionary = {
		"swamp": "Swamp", "ice_caves": "Ice Caves",
		"infernal": "Infernal", "crypt": "Crypt",
	}
	for branch_id in branches.keys():
		var bhdr := Label.new()
		bhdr.text = "── %s ──" % branches[branch_id]
		bhdr.add_theme_font_size_override("font_size", 20)
		bhdr.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7))
		bhdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(bhdr)
		var bgrid := GridContainer.new()
		bgrid.columns = 4
		bgrid.add_theme_constant_override("h_separation", 6)
		bgrid.add_theme_constant_override("v_separation", 6)
		vb.add_child(bgrid)
		for bf in range(1, 5):
			var bbtn := Button.new()
			bbtn.text = "F%d" % bf
			bbtn.custom_minimum_size = Vector2(72, 48)
			bbtn.add_theme_font_size_override("font_size", 20)
			bbtn.pressed.connect(_debug_warp_to_branch.bind(branch_id, bf))
			bgrid.add_child(bbtn)

	toggle.pressed.connect(func():
		_debug_panel_visible = not _debug_panel_visible
		_debug_panel.visible = _debug_panel_visible)

func _debug_warp_to(target_depth: int) -> void:
	_debug_panel.visible = false
	_debug_panel_visible = false
	# Exit branch if inside one
	if GameManager.branch_zone != "":
		GameManager.branch_zone = ""
		GameManager.branch_floor = 0
	_floor_lifecycle._cache_current_floor()
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	GameManager.travel_to(target_depth)
	CombatLog.post(LocaleManager.t("LOG_DEBUG_WARP_TO_B") % target_depth, Color(1.0, 0.85, 0.3))
	_floor_lifecycle._generate_floor(target_depth, _floor_lifecycle._floor_seed(target_depth), true)
	RacePassiveSystem.on_floor_changed(player)
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()

func _debug_warp_to_branch(branch_id: String, branch_floor: int) -> void:
	_debug_panel.visible = false
	_debug_panel_visible = false
	_floor_lifecycle._cache_current_floor()
	_spawn_service._clear_monsters()
	_spawn_service._clear_floor_items()
	_spawn_service._clear_npcs()
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	var entry_depth: int = int(cfg.get("entrance_range", [1, 1])[1])
	GameManager.branch_zone = branch_id
	GameManager.branch_floor = branch_floor
	GameManager.branch_entry_depth = entry_depth
	GameManager.branches_cleared.erase(branch_id)
	GameManager.branch_floor_cache.erase("%s_%d" % [branch_id, branch_floor])
	CombatLog.post(LocaleManager.t("LOG_DEBUG_WARP_TO_F") % [branch_id, branch_floor], Color(1.0, 0.85, 0.3))
	_generate_branch_floor(branch_id, branch_floor, true)
	RacePassiveSystem.on_floor_changed(player)
	_reset_expedition_budget()
	_center_camera_on_player(true)
	_update_hud()
