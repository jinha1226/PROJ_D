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

@onready var GameManager = get_node("/root/GameManager")
@onready var TurnManager = get_node("/root/TurnManager")
@onready var CombatLog = get_node("/root/CombatLog")
@onready var SaveManager = get_node("/root/SaveManager")
@onready var MonsterRegistry = get_node("/root/MonsterRegistry")
@onready var ItemRegistry = get_node("/root/ItemRegistry")
@onready var ClassRegistry = get_node("/root/ClassRegistry")
@onready var SpellRegistry = get_node("/root/SpellRegistry")
@onready var RaceRegistry = get_node("/root/RaceRegistry")
@onready var RacePassiveSystem = get_node("/root/RacePassiveSystem")

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
var _targeting_monster: Monster = null
var _pending_essence_pickups: Array = []
var _essence_pickup_popup_open: bool = false

# Abyss state
var _abyss_turn_counter: int = 0
const _ABYSS_SHIFT_INTERVAL: int = 8  # tiles shift every 8 player turns
const _ABYSS_SHIFT_COUNT: int = 12    # tiles flipped per shift

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
	add_to_group("game")
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
		if _targeting_monster != null and tile == _targeting_monster.grid_pos:
			_confirm_targeting()
		elif _targeting_monster == null and _targeting_tiles.has(tile):
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
		var tile: int = map.tile_at(player.grid_pos)
		if tile == DungeonMap.Tile.STAIRS_DOWN:
			_on_stairs_down()
		elif tile == DungeonMap.Tile.STAIRS_UP:
			_on_stairs_up()
		elif tile == DungeonMap.Tile.BRANCH_DOWN:
			_on_branch_enter()
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
	if _monster_in_sight():
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
		CombatLog.post("You stop — enemy approaches.", Color(1.0, 0.7, 0.5))

func _apply_class_to_player(class_id: String) -> void:
	var data: ClassData = ClassRegistry.get_by_id(class_id) if ClassRegistry != null and class_id != "" else null
	if data == null:
		return
	player.strength = data.starting_str
	player.dexterity = data.starting_dex
	player.intelligence = data.starting_int
	player.hp_max = player.compute_starting_hp(data.starting_hp, data.starting_str)
	player.hp = player.hp_max
	player.mp_max = data.starting_mp
	player.mp = data.starting_mp
	_apply_race_mods(GameManager.selected_race_id)
	player.set_race_from_id(GameManager.selected_race_id)
	var starting_weapon_id: String = data.starting_weapon
	if (class_id == "warrior" or class_id == "ranger") \
			and GameManager.selected_starting_weapon_id != "":
		starting_weapon_id = GameManager.selected_starting_weapon_id
	if starting_weapon_id != "":
		player.items.append({"id": starting_weapon_id, "plus": 0})
		player.equipped_weapon_id = starting_weapon_id
	if data.starting_armor != "":
		player.items.append({"id": data.starting_armor, "plus": 0})
		player.equipped_armor_id = data.starting_armor
	if data.starting_shield != "":
		player.items.append({"id": data.starting_shield, "plus": 0})
		player.equipped_shield_id = data.starting_shield
	player.init_skills()
	var default_active: Array = []
	for skill_id in data.starting_skills.keys():
		var mapped_skill: String = skill_id
		if mapped_skill == "stealth" or mapped_skill == "dodge":
			mapped_skill = "agility"
		elif mapped_skill == "melee":
			var starter_weapon: ItemData = ItemRegistry.get_by_id(String(data.starting_weapon)) if ItemRegistry != null and String(data.starting_weapon) != "" else null
			mapped_skill = Player.weapon_skill_for_item(starter_weapon)
		elif mapped_skill == "magic":
			mapped_skill = "spellcasting"
		elif mapped_skill == "defense":
			mapped_skill = "armor"
		if player.skills.has(mapped_skill):
			player.skills[mapped_skill]["level"] = clampi(int(data.starting_skills[skill_id]), 0, Player.MAX_SKILL_LEVEL)
			if not default_active.has(mapped_skill):
				default_active.append(mapped_skill)
	player.set_active_skills(_class_default_active_skills(class_id, default_active))
	if data.starting_xl > 0:
		player.xl = data.starting_xl
	player.refresh_ac_from_equipment()
	player._refresh_paperdoll()
	player.known_spells = data.starting_spells.duplicate()
	if data.class_group == "mage" or class_id == "archmage":
		var start_school: String = GameManager.selected_starting_school_id
		if start_school != "" and class_id != "archmage":
			player.add_school_spells(start_school)
		else:
			for school in Player.MAGIC_SCHOOLS:
				player.add_school_spells(school)
	GameManager.selected_starting_weapon_id = ""
	GameManager.selected_starting_school_id = ""
	for id in _class_starter_items(class_id):
		player.items.append({"id": id, "plus": 0})
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	var race_name: String = race.display_name if race != null else "adventurer"
	CombatLog.post("You start as %s %s." % [race_name, data.display_name],
		Color(0.85, 0.9, 1.0))
	GameManager.selected_starting_essence_id = ""
	GameManager.selected_faith_id = ""

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
	player.resists = race.resist_mods.duplicate()
	RacePassiveSystem.register(player)

func _class_starter_items(class_id: String) -> Array:
	match class_id:
		"warrior":
			return ["potion_healing", "potion_healing"]
		"mage":
			return ["potion_healing", "potion_magic"]
		"rogue":
			return ["dagger", "potion_healing", "potion_invisible", "scroll_shrouding"]
		"ranger":
			return ["dagger", "potion_healing", "potion_healing"]
		"archmage":
			return [
				"potion_healing",
				"potion_magic",
				"scroll_identify",
				"scroll_blinking",
				"wand_fire",
				"wand_frost",
				"wand_lightning",
			]
	return []

func _class_default_active_skills(class_id: String, fallback: Array) -> Array:
	match class_id:
		"warrior":
			return ["blade", "armor", "shield"]
		"mage":
			return ["spellcasting", "arcane"]
		"rogue":
			return ["ranged", "agility", "tool"]
		"ranger":
			return ["ranged", "agility"]
		"archmage":
			return ["spellcasting", "elemental", "arcane", "hex", "necromancy", "summoning", "armor", "shield", "agility", "tool", "ranged", "blade", "hafted", "polearm", "unarmed"]
	if not fallback.is_empty():
		return fallback
	return ["blade"]

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
	if player.known_spells.is_empty():
		var cls: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id) if ClassRegistry != null and GameManager != null and GameManager.selected_class_id != "" else null
		if cls != null:
			player.known_spells = cls.starting_spells.duplicate()
	player.statuses = data.get("statuses", {})
	player.resists = data.get("resists", [])
	player.skills = data.get("skills", {})
	player.active_skills = data.get("active_skills", [])
	if player.skills.has("dodge") and not player.skills.has("agility"):
		player.skills["agility"] = player.skills["dodge"]
	player.skills.erase("dodge")
	if player.skills.has("melee"):
		var _melee_level: int = int(player.skills["melee"].get("level", 0))
		var _melee_xp: float = float(player.skills["melee"].get("xp", 0.0))
		for _sid in ["unarmed", "blade", "hafted", "polearm"]:
			if not player.skills.has(_sid) or int(player.skills[_sid].get("level", 0)) == 0:
				player.skills[_sid] = {"level": _melee_level, "xp": _melee_xp}
		player.skills.erase("melee")
	if player.skills.has("stealth") and not player.skills.has("agility"):
		player.skills["agility"] = player.skills["stealth"]
	player.skills.erase("stealth")
	if player.skills.has("magic"):
		var _magic_level: int = int(player.skills["magic"].get("level", 0))
		var _magic_xp: float = float(player.skills["magic"].get("xp", 0.0))
		if not player.skills.has("spellcasting"):
			player.skills["spellcasting"] = {"level": _magic_level, "xp": _magic_xp}
		for _sid in ["elemental", "arcane", "hex", "necromancy", "summoning"]:
			if not player.skills.has(_sid):
				player.skills[_sid] = {"level": max(0, _magic_level - 1), "xp": 0.0}
		player.skills.erase("magic")
	if player.skills.has("defense"):
		var _def_level: int = int(player.skills["defense"].get("level", 0))
		var _def_xp: float = float(player.skills["defense"].get("xp", 0.0))
		if not player.skills.has("armor"):
			player.skills["armor"] = {"level": _def_level, "xp": _def_xp}
		if not player.skills.has("shield"):
			player.skills["shield"] = {"level": max(0, _def_level - 1), "xp": 0.0}
		player.skills.erase("defense")
	# tool skill migration: old saves may not have "tool" yet (that's fine, will be added below)
	if player.skills.is_empty():
		player.init_skills()
	else:
		# Ensure all simplified skills exist and clamp legacy saves.
		for _sk_id: String in Player.SKILL_IDS:
			if not player.skills.has(_sk_id):
				player.skills[_sk_id] = {"level": 0, "xp": 0.0}
			else:
				player.skills[_sk_id]["level"] = clampi(int(player.skills[_sk_id].get("level", 0)), 0, Player.MAX_SKILL_LEVEL)
	if player.active_skills.has("dodge") and not player.active_skills.has("agility"):
		player.active_skills.append("agility")
	player.active_skills.erase("dodge")
	if player.active_skills.has("melee"):
		player.active_skills.erase("melee")
		if not player.active_skills.has("blade"):
			player.active_skills.append("blade")
	if player.active_skills.has("stealth") and not player.active_skills.has("agility"):
		player.active_skills.append("agility")
	player.active_skills.erase("stealth")
	if player.active_skills.has("magic"):
		player.active_skills.erase("magic")
		for _sid in ["spellcasting", "arcane"]:
			if not player.active_skills.has(_sid):
				player.active_skills.append(_sid)
	if player.active_skills.has("defense"):
		player.active_skills.erase("defense")
		for _sid in ["armor", "shield"]:
			if not player.active_skills.has(_sid):
				player.active_skills.append(_sid)
	if player.active_skills.is_empty():
		player.set_active_skills(_class_default_active_skills(GameManager.selected_class_id, []))
	else:
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

func _queue_essence_pickup(essence_id: String) -> void:
	if player == null or essence_id == "":
		return
	if player.essence_slots.has(essence_id) or player.essence_inventory.has(essence_id):
		CombatLog.post("An essence fades away. (%s)" % EssenceSystem.display_name(essence_id),
			Color(0.6, 0.55, 0.7))
		return
	_pending_essence_pickups.append(essence_id)
	_try_open_essence_pickup_popup()

func _try_open_essence_pickup_popup() -> void:
	if _essence_pickup_popup_open or _pending_essence_pickups.is_empty():
		return
	if player == null:
		_pending_essence_pickups.clear()
		return
	var essence_id: String = String(_pending_essence_pickups.pop_front())
	if essence_id == "" or player.essence_slots.has(essence_id) or player.essence_inventory.has(essence_id):
		_try_open_essence_pickup_popup()
		return
	# Essence only available with Essence faith
	if not FaithSystem.allows_essence(player):
		CombatLog.post("The essence fades — your faith rejects it.", Color(0.55, 0.55, 0.65))
		_try_open_essence_pickup_popup()
		return
	_essence_pickup_popup_open = true
	var popup := PopupManager.new()
	add_child(popup)
	var take_cb := func() -> void:
		if player != null and player.add_essence(essence_id):
			CombatLog.post("You claim %s." % EssenceSystem.display_name(essence_id),
				Color(0.82, 0.64, 1.0))
		_close_essence_pickup_popup(popup)
	var replace_cb := func(replaced_id: String) -> void:
		if player != null and player.replace_inventory_essence(replaced_id, essence_id):
			CombatLog.post("You leave %s and take %s." % [
				EssenceSystem.display_name(replaced_id),
				EssenceSystem.display_name(essence_id),
			], Color(0.82, 0.64, 1.0))
		_close_essence_pickup_popup(popup)
	var leave_cb := func() -> void:
		CombatLog.post("You leave %s behind." % EssenceSystem.display_name(essence_id),
			Color(0.62, 0.62, 0.72))
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
	log_strip.offset_top = -268.0
	log_strip.offset_bottom = -132.0
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
	top_hud.item_slot_pressed.connect(_on_item_slot_pressed)
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
	if GameManager.selected_class_id == "archmage":
		_spawn_debug_floor_panel()


func _floor_seed(depth: int) -> int:
	return GameManager.seed * 1009 + depth * 31

func _generate_floor(depth: int, map_seed: int,
		arrive_from_above: bool = true) -> void:
	_abyss_turn_counter = 0
	if GameManager.floor_cache.has(depth):
		_restore_floor_from_cache(depth, arrive_from_above)
	else:
		var has_branch: bool = ZoneManager.branch_entrance_for_depth(depth) != ""
		var already_cleared: bool = false
		var bid: String = ZoneManager.branch_entrance_for_depth(depth)
		if has_branch:
			already_cleared = GameManager.branches_cleared.has(bid)
		var zone: Dictionary = ZoneManager.zone_for_depth(depth)
		var zone_style: String = "temple" if depth == 3 else String(zone.get("map_style", "bsp"))
		map.generate(map_seed, has_branch and not already_cleared, zone_style)
		if has_branch and not already_cleared:
			var ecfg: Dictionary = ZoneManager.branch_config(bid)
			var etex_path: String = String(ecfg.get("entrance_tile", ""))
			map._tex_branch_entrance = load(etex_path) as Texture2D if etex_path != "" else null
		else:
			map._tex_branch_entrance = null
		if depth == 3:
			_place_b3_altars(map_seed)
		player.bind_map(map, map.spawn_pos)
		_spawn_items_for_floor(depth)
		if depth == 15:
			_spawn_b15_boss_floor()
		elif String(zone.get("id", "")) == "abyss":
			_spawn_abyss_floor(depth)
		else:
			_spawn_monsters_for_floor(depth)
		_scatter_hazard_tiles(zone.get("env", ""))
	_refresh_fov()

func _spawn_b15_boss_floor() -> void:
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
	m.died.connect(_on_monster_died.bind(m))
	m.awareness_changed.connect(_on_monster_awareness_changed)
	TurnManager.register_actor(m)
	CombatLog.post("A crushing darkness fills the air. Something ancient stirs...",
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


const _B3_FAITH_IDS: Array = ["war", "arcana", "trickery", "death", "essence"]

func _place_b3_altars(_seed: int) -> void:
	# Temple generator pre-populates broken_altar_positions and preset_faith_altar_positions.
	if map.preset_faith_altar_positions.size() == _B3_FAITH_IDS.size():
		for i in _B3_FAITH_IDS.size():
			map.altar_map[map.preset_faith_altar_positions[i]] = _B3_FAITH_IDS[i]
		map.queue_redraw()
		return

	# Fallback: random placement for non-temple layouts.
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed ^ 0xA17A1234
	var floor_tiles: Array = []
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			if map.tile_at(p) == DungeonMap.Tile.FLOOR:
				floor_tiles.append(p)
	if floor_tiles.is_empty():
		return

	var picked: Dictionary = {}
	var shuffled: Array = floor_tiles.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = tmp

	if map.broken_altar_positions.is_empty():
		var broken: Array = []
		for p in shuffled:
			if broken.size() >= 6:
				break
			if p == map.spawn_pos or p == map.stairs_down_pos or p == map.stairs_up_pos:
				continue
			broken.append(p)
			picked[p] = true
		map.broken_altar_positions = broken
	else:
		for p in map.broken_altar_positions:
			picked[p] = true

	var faith_positions: Array = []
	for fid in _B3_FAITH_IDS:
		var best: Vector2i = Vector2i(-1, -1)
		var best_score: float = -1.0
		for p in shuffled:
			if picked.get(p, false):
				continue
			if p == map.spawn_pos or p == map.stairs_down_pos or p == map.stairs_up_pos:
				continue
			var min_dist: float = 999.0
			for existing in faith_positions:
				min_dist = min(min_dist, Vector2(p.x - existing.x, p.y - existing.y).length())
			if faith_positions.is_empty():
				min_dist = 999.0
			if min_dist > best_score:
				best_score = min_dist
				best = p
		if best != Vector2i(-1, -1):
			map.altar_map[best] = fid
			faith_positions.append(best)
			picked[best] = true
	map.queue_redraw()

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
		"altar_map": map.altar_map.duplicate(),
		"broken_altar_positions": map.broken_altar_positions.duplicate(),
		"altar_active": map.altar_active,
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
	map.altar_map = state.get("altar_map", {}).duplicate()
	map.broken_altar_positions = state.get("broken_altar_positions", []).duplicate()
	map.altar_active = bool(state.get("altar_active", false))
	map.visible_tiles.clear()
	map._load_atmosphere(depth)
	map.queue_redraw()
	var arrival: Vector2i = map.stairs_up_pos if arrive_from_above \
			else map.stairs_down_pos
	player.bind_map(map, arrival)
	for entry in state.items:
		var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
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
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)

func _spawn_unique_for_floor(depth: int, rng: RandomNumberGenerator) -> void:
	var unique_data: MonsterData = MonsterRegistry.unique_for_depth(depth)
	if unique_data == null:
		return
	# Only spawn on the last floor of the sector (floor_in_sector == 2) so
	# the player has a chance to prepare across the first two floors.
	var floor_in_sector: int = (depth - 1) % 3
	if floor_in_sector != 2:
		return
	var attempts: int = 0
	while attempts < 200:
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
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(unique_data, map, p)
		m.hit_taken.connect(_on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
		CombatLog.post("A dangerous presence lurks on this floor...", Color(1.0, 0.75, 0.3))
		return

func _spawn_monsters_for_floor(depth: int) -> void:
	var count: int = _monster_count_for_depth(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(depth) ^ 0x5A5A5A5A
	_spawn_unique_for_floor(depth, rng)
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = map.random_floor_tile(rng)
		if not map.is_walkable(p):
			continue
		if p == player.grid_pos:
			continue
		if _chebyshev(p, player.grid_pos) < 3:
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
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
		placed += 1

func _spawn_items_for_floor(depth: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(depth) ^ 0x3C3C3C3C

	# Build the item list to place this floor.
	var to_place: Array[ItemData] = []

	# ── Per-floor random drops ──────────────────────────────────────────
	for _i in range(rng.randi_range(1, 3)):
		var d: ItemData = ItemRegistry.pick_kind(depth, "potion")
		if d != null: to_place.append(d)
	for _i in range(rng.randi_range(1, 3)):
		var d: ItemData = ItemRegistry.pick_kind(depth, "scroll")
		if d != null: to_place.append(d)
	for _i in range(rng.randi_range(1, 2)):
		var d: ItemData = ItemRegistry.pick_equipment_weighted(depth)
		if d != null: to_place.append(d)

	# ~1 book per 2-3 floors (40% chance)
	if rng.randf() < 0.40:
		var d: ItemData = ItemRegistry.pick_kind(depth, "book")
		if d != null: to_place.append(d)

	# ── Sector guaranteed drops (sector = 3-floor block) ───────────────
	# Sector total: enchant_weapon ×1, enchant_armor ×1, wand 1-2, healing 2-3, essence ×2
	var floor_in_sector: int = (depth - 1) % 3  # 0, 1, or 2
	if floor_in_sector == 0:
		# Floor 1: healing + enchant_weapon + wand + essence
		to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		to_place.append(ItemRegistry.get_by_id("scroll_enchant_weapon") if ItemRegistry != null else null)
		var wd: ItemData = ItemRegistry.pick_kind(depth, "wand") if ItemRegistry != null else null
		if wd != null: to_place.append(wd)
		_queue_essence_pickup(EssenceSystem.random_id())
	elif floor_in_sector == 1:
		# Floor 2: healing + enchant_armor + essence
		to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		to_place.append(ItemRegistry.get_by_id("scroll_enchant_armor") if ItemRegistry != null else null)
		_queue_essence_pickup(EssenceSystem.random_id())
	else:
		# Floor 3: 50% extra healing + 50% upgrade scroll + 50% wand
		if rng.randf() < 0.5:
			to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		if rng.randf() < 0.5:
			to_place.append(ItemRegistry.get_by_id("scroll_upgrade") if ItemRegistry != null else null)
		if rng.randf() < 0.5:
			var wd: ItemData = ItemRegistry.pick_kind(depth, "wand") if ItemRegistry != null else null
			if wd != null: to_place.append(wd)

	# ── Place all items on random floor tiles ───────────────────────────
	for item in to_place:
		if item == null:
			continue
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = map.random_floor_tile(rng)
			if not map.is_walkable(p):
				continue
			if p == player.grid_pos:
				continue
			if _item_at(p) != null:
				continue
			_spawn_floor_item(item, p, 0)
			break

func spawn_ally(monster_id: String, near_pos: Vector2i, turns: int) -> bool:
	if map == null or monsters_layer == null:
		return false
	var md: MonsterData = MonsterRegistry.get_by_id(monster_id)
	if md == null:
		return false
	# Find an open adjacent tile
	var offsets: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]
	var spawn_at: Vector2i = Vector2i(-1, -1)
	for off in offsets:
		var p: Vector2i = near_pos + off
		if map.is_walkable(p) and _monster_at(p) == null and p != player.grid_pos:
			spawn_at = p
			break
	if spawn_at == Vector2i(-1, -1):
		return false
	var m: Monster = MonsterScene.new()
	monsters_layer.add_child(m)
	m.setup(md, map, spawn_at)
	m.is_ally = true
	m.ally_turns_left = turns
	m.hit_taken.connect(_on_monster_hit.bind(m))
	m.died.connect(_on_monster_died.bind(m))
	TurnManager.register_actor(m)
	map.queue_redraw()
	return true

## Spawn a hostile monster at an exact tile (used by summoner AI).
func spawn_monster_at(monster_id: String, pos: Vector2i) -> bool:
	if map == null or monsters_layer == null:
		return false
	var md: MonsterData = MonsterRegistry.get_by_id(monster_id)
	if md == null:
		return false
	if not map.is_walkable(pos) or _monster_at(pos) != null or pos == player.grid_pos:
		return false
	var m: Monster = MonsterScene.new()
	monsters_layer.add_child(m)
	m.setup(md, map, pos)
	m.become_aware(player.grid_pos)
	m.hit_taken.connect(_on_monster_hit.bind(m))
	m.died.connect(_on_monster_died.bind(m))
	m.awareness_changed.connect(_on_monster_awareness_changed)
	_roll_monster_weapon(m)
	TurnManager.register_actor(m)
	map.queue_redraw()
	return true


func _roll_monster_weapon(monster: Monster) -> void:
	if monster.data == null:
		return
	var pool_entry = _MONSTER_WEAPON_POOLS.get(monster.data.id, null)
	if pool_entry == null:
		return
	var normal_pool: Array = pool_entry[0]
	var rare_pool: Array = pool_entry[1]
	# 5% chance for branded/rare weapon
	var weapon_id: String = ""
	if not rare_pool.is_empty() and randf() < 0.05:
		weapon_id = rare_pool[randi() % rare_pool.size()]
	elif not normal_pool.is_empty():
		weapon_id = normal_pool[randi() % normal_pool.size()]
	monster.equipped_weapon_id = weapon_id

func _spawn_floor_item(data: ItemData, pos: Vector2i, plus: int) -> void:
	if items_layer == null:
		return
	var fi: FloorItem = FloorItemScene.new()
	items_layer.add_child(fi)
	fi.setup(data, map, pos, plus)

func _monster_count_for_depth(d: int) -> int:
	if d <= 5:
		return randi_range(7, 10)
	if d <= 15:
		return randi_range(10, 14)
	return randi_range(9, 13)

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
	if bottom_hud != null:
		var hostile: bool = _monster_in_sight()
		bottom_hud.set_rest_label(hostile)
		bottom_hud.set_act_label(hostile)

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
	top_hud.set_depth(GameManager.depth)
	top_hud.set_gold(player.gold)
	top_hud.set_turn(TurnManager.turn_number)
	top_hud.set_buffs(player.statuses)
	if bottom_hud != null:
		var hostile_visible: bool = _monster_in_sight()
		bottom_hud.set_rest_label(hostile_visible)
		bottom_hud.set_act_label(hostile_visible)

func _on_player_moved(_new_pos: Vector2i) -> void:
	_refresh_fov()
	_center_camera_on_player()
	_refresh_quickslots()
	_try_open_shrine_choice()

func _try_open_shrine_choice() -> void:
	if map == null or player == null:
		return
	if not map.altar_active or FaithSystem.has_chosen_faith(player):
		return
	if not map.altar_map.has(player.grid_pos):
		return
	var faith_id: String = String(map.altar_map[player.grid_pos])
	ShrineDialog.open_single(faith_id, player, self)

const _RESPAWN_INTERVAL: int = 18

func _on_player_turn_started() -> void:
	if player != null and player.hp > 0:
		player.tick_statuses()
		RacePassiveSystem.on_player_turn_end(player)
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
					CombatLog.post("Your %s fades away." % n.data.display_name, Color(0.7, 0.7, 0.8))
					n.die()
	if TurnManager.turn_number % _RESPAWN_INTERVAL == 0:
		_try_respawn_monster()
	if not _auto_path.is_empty():
		if _monster_in_sight():
			_cancel_auto_walk("new enemy")
			return
		_queue_auto_walk_step()
	elif _auto_exploring:
		if _monster_in_sight():
			_cancel_auto_walk("new enemy")
			return
		_start_auto_explore()

func apply_immolation_aoe(origin: Vector2i, radius: int) -> void:
	if map == null:
		return
	CombatLog.post("The scroll ignites in a blazing inferno!", Color(1.0, 0.55, 0.1))
	var visible: Dictionary = player.compute_fov() if player != null else {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var pos := origin + Vector2i(dx, dy)
			if not map.in_bounds(pos) or map.tile_at(pos) == map.Tile.WALL:
				continue
			map.add_cloud(pos, "fire", 5)
	# Damage all visible monsters in radius
	for n in get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		var d: int = max(abs(n.grid_pos.x - origin.x), abs(n.grid_pos.y - origin.y))
		if d <= radius and visible.has(n.grid_pos):
			var dmg: int = randi_range(8, 16)
			n.take_damage(dmg)
			n.become_aware(origin)


func _tick_cloud_damage_player() -> void:
	if player == null or player.hp <= 0 or map == null:
		return
	var cloud: Dictionary = map.cloud_tiles.get(player.grid_pos, {})
	if cloud.is_empty():
		return
	var dmg: int = _cloud_damage(cloud.get("type", "fire"), player, null)
	if dmg > 0:
		player.take_damage(dmg, "cloud_%s" % cloud.get("type", ""))
		CombatLog.damage_taken("The %s cloud burns you for %d." \
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
			CombatLog.damage_taken("The lava scorches you for 8!")
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
	var max_count: int = _monster_count_for_depth(GameManager.depth)
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
		var data: MonsterData = MonsterRegistry.pick_by_depth(GameManager.depth)
		if data == null:
			return
		var m: Monster = MonsterScene.new()
		monsters_layer.add_child(m)
		m.setup(data, map, p)
		m.hit_taken.connect(_on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(_on_monster_awareness_changed)
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
		return

func _on_player_died() -> void:
	CombatLog.post("YOU DIED.", Color(1.0, 0.3, 0.3))
	GameManager.end_run("death")
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
	GameManager.selected_class_id = ""
	GameManager.selected_race_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)

func _on_result_meta(res: Node) -> void:
	if is_instance_valid(res):
		res.queue_free()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

# ── Branch navigation ────────────────────────────────────────────────────────

func _on_branch_enter() -> void:
	var branch_id: String = ZoneManager.branch_entrance_for_depth(GameManager.depth)
	if branch_id == "" or GameManager.branches_cleared.has(branch_id):
		if GameManager.branches_cleared.has(branch_id):
			CombatLog.post("You have already cleared the %s." \
				% ZoneManager.branch_config(branch_id).get("display_name", branch_id),
				Color(0.7, 0.7, 0.5))
		return
	_cancel_auto_walk("branch")
	_cache_current_floor()
	GameManager.branch_zone = branch_id
	GameManager.branch_floor = 1
	GameManager.branch_entry_depth = GameManager.depth
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	CombatLog.post("You enter the %s." % cfg.get("display_name", branch_id),
		Color(0.4, 1.0, 0.6))
	_generate_branch_floor(branch_id, 1, true)
	_center_camera_on_player(true)
	_update_hud()
	TurnManager.end_player_turn()

func _on_branch_stairs_down() -> void:
	var branch_id: String = GameManager.branch_zone
	if branch_id == "":
		return
	_cancel_auto_walk("stairs")
	_cache_branch_floor(branch_id, GameManager.branch_floor)
	GameManager.branch_floor += 1
	CombatLog.post("%s B%d." % [ZoneManager.branch_config(branch_id).get("display_name", branch_id),
		GameManager.branch_floor], Color(0.4, 1.0, 0.6))
	_generate_branch_floor(branch_id, GameManager.branch_floor, true)
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _on_branch_stairs_up() -> void:
	var branch_id: String = GameManager.branch_zone
	if branch_id == "":
		return
	_cancel_auto_walk("stairs")
	if GameManager.branch_floor <= 1:
		# Exit branch back to main path
		_cache_branch_floor(branch_id, 1)
		GameManager.branch_zone = ""
		GameManager.branch_floor = 0
		CombatLog.post("You return to the main dungeon.", Color(0.7, 0.9, 1.0))
		GameManager.depth = GameManager.branch_entry_depth
		_restore_floor_from_cache(GameManager.depth, false)
		_refresh_fov()
	else:
		_cache_branch_floor(branch_id, GameManager.branch_floor)
		GameManager.branch_floor -= 1
		_generate_branch_floor(branch_id, GameManager.branch_floor, false)
	_center_camera_on_player(true)
	_update_hud()
	TurnManager.end_player_turn()

func _on_branch_cleared(branch_id: String) -> void:
	if GameManager.branches_cleared.has(branch_id):
		return
	GameManager.branches_cleared.append(branch_id)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	CombatLog.post("%s cleared!" % cfg.get("display_name", branch_id), Color(1.0, 0.9, 0.3))
	# Per-branch title
	match branch_id:
		"swamp":      GameManager.earn_title("The Poisoner")
		"ice_caves":  GameManager.earn_title("The Frozen")
		"infernal":   GameManager.earn_title("The Infernal")
		"crypt": GameManager.earn_title("The Deathless")
	# All-branches bonus
	if GameManager.branches_cleared.size() >= 4:
		GameManager.earn_title("The Delver")
		CombatLog.post("All branches cleared!", Color(1.0, 0.9, 0.3))

func _generate_branch_floor(branch_id: String, branch_floor: int, arrive_from_above: bool) -> void:
	var cache_key: String = "%s_%d" % [branch_id, branch_floor]
	if GameManager.branch_floor_cache.has(cache_key):
		var state: Dictionary = GameManager.branch_floor_cache[cache_key]
		map.tiles = state["tiles"]
		map.explored = state["explored"].duplicate(true)
		map.spawn_pos = state["spawn_pos"]
		map.stairs_down_pos = state["stairs_down_pos"]
		map.stairs_up_pos = state["stairs_up_pos"]
		map.rooms = state["rooms"].duplicate()
		map.visible_tiles.clear()
		map.fog_tiles.clear()
		var cfg: Dictionary = ZoneManager.branch_config(branch_id)
		map._tex_wall = load(cfg.get("wall", "")) as Texture2D
		map._tex_floor = load(cfg.get("floor", "")) as Texture2D
		map.queue_redraw()
		var arrival: Vector2i = map.spawn_pos if arrive_from_above else map.stairs_down_pos
		player.bind_map(map, arrival)
		# Restore monsters
		_clear_monsters()
		_clear_floor_items()
		for entry in state.get("monsters", []):
			var md: MonsterData = MonsterRegistry.get_by_id(String(entry.get("id", "")))
			if md == null: continue
			var p: Vector2i = entry.get("pos", Vector2i.ZERO)
			if p == player.grid_pos: continue
			var m: Monster = MonsterScene.new()
			monsters_layer.add_child(m)
			m.setup(md, map, p)
			m.hp = int(entry.get("hp", m.hp))
			m.hit_taken.connect(_on_monster_hit.bind(m))
			if m.has_signal("awareness_changed"):
				m.awareness_changed.connect(_on_monster_awareness_changed)
			m.died.connect(_on_monster_died.bind(m))
			TurnManager.register_actor(m)
			_roll_monster_weapon(m)
		for entry in state.get("items", []):
			var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
			if d == null: continue
			_spawn_floor_item(d, entry.get("pos", Vector2i.ZERO), int(entry.get("plus", 0)))
		_refresh_fov()
		return

	# Fresh branch floor generation
	var branch_seed: int = GameManager.seed ^ (branch_id.hash() + branch_floor * 17)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	var is_boss_floor: bool = (branch_floor >= int(cfg.get("floors", 4)))
	var map_style: String = String(cfg.get("map_style", "bsp"))
	map.generate(branch_seed, not is_boss_floor, map_style)
	var eff_depth: int = ZoneManager.branch_effective_depth(branch_id, branch_floor)
	map._tex_wall = load(cfg.get("wall", "")) as Texture2D
	map._tex_floor = load(cfg.get("floor", "")) as Texture2D
	map.queue_redraw()
	player.bind_map(map, map.spawn_pos)
	_clear_monsters()
	_clear_floor_items()
	if is_boss_floor:
		_spawn_branch_boss(branch_id)
	else:
		_spawn_branch_monsters(branch_id, eff_depth)
		_spawn_items_for_floor(eff_depth)
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
					and p != map.spawn_pos and p != map.stairs_down_pos \
					and p != map.stairs_up_pos:
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
	CombatLog.post("The Abyss warps around you. There is no way back.", Color(0.6, 0.3, 0.9))
	# Spawn monsters — all immediately aware
	var count: int = _monster_count_for_depth(depth) + 2
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(depth) ^ 0xAB155001
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
		m.died.connect(_on_monster_died.bind(m))
		m.become_aware(player.grid_pos)
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
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
		# Clear old exit
		for y in range(DungeonMap.GRID_H):
			for x in range(DungeonMap.GRID_W):
				if map.tile_at(Vector2i(x, y)) == DungeonMap.Tile.STAIRS_DOWN:
					map.set_tile(Vector2i(x, y), DungeonMap.Tile.FLOOR)
		map.stairs_down_pos = new_exit
		map.set_tile(new_exit, DungeonMap.Tile.STAIRS_DOWN)
		CombatLog.post("The Abyss shifts... the exit has moved.", Color(0.6, 0.3, 0.9))
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
	var count: int = _monster_count_for_depth(eff_depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = _floor_seed(eff_depth) ^ 0xBBAACC11
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
		m.died.connect(_on_monster_died.bind(m))
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
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
	var spawn_pos: Vector2i = map.stairs_down_pos
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
	m.died.connect(_on_branch_boss_died.bind(m, branch_id))
	TurnManager.register_actor(m)
	_roll_monster_weapon(m)
	CombatLog.post("A powerful presence fills the chamber...", Color(1.0, 0.5, 0.2))

func _spawn_branch_resistance_hint(branch_id: String) -> void:
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	if FaithSystem.allows_essence(player):
		var essence_id: String = String(cfg.get("essence_reward", ""))
		if essence_id != "":
			_queue_essence_pickup(essence_id)
			CombatLog.post("The environment here is hostile — a protective essence manifests.", Color(0.9, 0.85, 0.4))
	else:
		var ring_id: String = String(cfg.get("resist_ring", ""))
		if ring_id != "":
			var ring_data: ItemData = ItemRegistry.get_by_id(ring_id) if ItemRegistry != null and ring_id != "" else null
			if ring_data != null:
				_spawn_floor_item(ring_data, map.spawn_pos + Vector2i(1, 0), 0)
				CombatLog.post("The environment here is hostile — a protective ring lies nearby.", Color(0.9, 0.85, 0.4))

func _on_branch_boss_died(monster: Monster, branch_id: String) -> void:
	_on_monster_died(monster)
	_on_branch_cleared(branch_id)
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	# Brand scroll reward
	var element: String = String(cfg.get("brand_element", ""))
	var scroll_id: String = "scroll_brand_%s" % element
	var scroll_data: ItemData = ItemRegistry.get_by_id(scroll_id) if ItemRegistry != null and scroll_id != "" else null
	if scroll_data != null:
		_spawn_floor_item(scroll_data, monster.grid_pos, 0)
	# Rune — always dropped near the boss
	var rune_id: String = String(cfg.get("rune_reward", ""))
	if rune_id != "":
		var rune_data: ItemData = ItemRegistry.get_by_id(rune_id) if ItemRegistry != null and rune_id != "" else null
		if rune_data != null:
			_spawn_floor_item(rune_data, monster.grid_pos + Vector2i(1, 0), 0)
			CombatLog.post("A rune materialises!", Color(1.0, 0.9, 0.3))
	# Essence or ring depending on faith
	if FaithSystem.allows_essence(player):
		var essence_id: String = String(cfg.get("essence_reward", ""))
		if essence_id != "":
			_queue_essence_pickup(essence_id)
	else:
		var ring_id: String = String(cfg.get("ring_reward", ""))
		if ring_id != "":
			var ring_data: ItemData = ItemRegistry.get_by_id(ring_id) if ItemRegistry != null and ring_id != "" else null
			if ring_data != null:
				_spawn_floor_item(ring_data, monster.grid_pos, 0)
				CombatLog.post("A unique ring appears!", Color(0.8, 0.7, 1.0))
	# Place stairs back to main
	map.set_tile(map.stairs_down_pos, DungeonMap.Tile.STAIRS_UP)

func _cache_branch_floor(branch_id: String, branch_floor: int) -> void:
	var cache_key: String = "%s_%d" % [branch_id, branch_floor]
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
			state.items.append({"id": n.data.id, "pos": n.grid_pos, "plus": n.plus})
	for n in get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.data != null and n.hp > 0:
			state.monsters.append({"id": n.data.id, "pos": n.grid_pos, "hp": n.hp,
				"status": n.status.duplicate()})
	GameManager.branch_floor_cache[cache_key] = state

func _apply_branch_env_damage() -> void:
	if player == null or player.hp <= 0:
		return
	var branch_id: String = GameManager.branch_zone
	if branch_id == "":
		return
	var resistance: String = ZoneManager.branch_resistance(branch_id)
	if resistance != "" and player.resists.has(resistance):
		return
	var dmg: int = ZoneManager.branch_env_damage(branch_id, GameManager.branch_floor)
	if dmg <= 0:
		return
	var element: String = ZoneManager.branch_env_element(branch_id)
	CombatLog.damage_taken("The %s environment damages you for %d." \
		% [ZoneManager.branch_config(branch_id).get("display_name", branch_id), dmg])
	player.take_damage(dmg, element)

func _on_dungeon_cleared() -> void:
	CombatLog.post("You have cleared the dungeon!", Color(1.0, 0.9, 0.2))
	GameManager.end_run("victory")
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
	_cache_current_floor()
	GameManager.descend()
	if GameManager.depth >= 16:
		_on_dungeon_cleared()
		return
	CombatLog.post("You descend to B%d." % GameManager.depth, Color(0.6, 1.0, 1.0))
	_clear_monsters()
	_clear_floor_items()
	_generate_floor(GameManager.depth, _floor_seed(GameManager.depth), true)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()
	SaveManager.save_run(player, GameManager)
	TurnManager.end_player_turn()

func _on_stairs_up() -> void:
	if GameManager.branch_zone != "":
		_on_branch_stairs_up()
		return
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
	if not GameManager.floor_cache.has(target_depth):
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
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null and item_id != "" else null
	if data == null:
		return
	_spawn_floor_item(data, at_pos, plus)
	CombatLog.post("You drop %s." % GameManager.display_name_of(item_id))

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
		SaveManager.save_run(player, GameManager)
		CombatLog.post("Game saved.", Color(0.6, 0.9, 0.6))
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
		SaveManager.save_run(player, GameManager)
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

func _on_bestiary_pressed() -> void:
	if player == null:
		return
	BestiaryDialog.open(self)

func begin_spell_targeting(spell: SpellData, p: Player) -> void:
	_cancel_targeting()
	_targeting_spell = spell
	var visible: Dictionary = p.compute_fov()
	var range_val: int = MagicSystem.effective_spell_range(spell)
	_targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - p.grid_pos.x), abs(tile.y - p.grid_pos.y))
		if d > 0 and d <= range_val:
			_targeting_tiles.append(tile)
	_targeting_node = SpellTargetOverlay.new()
	_effect_layer.add_child(_targeting_node)
	_targeting_node.init(spell, p, _targeting_tiles)
	CombatLog.post("Tap highlighted tile to cast %s — tap elsewhere to cancel." \
			% spell.display_name, Color(0.8, 0.75, 1.0))

## Two-step targeting for single/auto/nearest spells: auto-selects nearest monster,
## highlights it, requires a second tap on it to confirm the cast.
func begin_spell_targeting_auto(spell: SpellData, p: Player) -> void:
	_cancel_targeting()
	var range_val: int = MagicSystem.effective_spell_range(spell)
	var visible: Dictionary = p.compute_fov()
	_targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - p.grid_pos.x), abs(tile.y - p.grid_pos.y))
		if d > 0 and d <= range_val:
			_targeting_tiles.append(tile)
	# Find nearest non-ally visible monster in range
	var best: Monster = null
	var best_d: int = range_val + 1
	for n in get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - p.grid_pos.x), abs(n.grid_pos.y - p.grid_pos.y))
		if d <= range_val and d < best_d:
			best_d = d
			best = n
	if best == null:
		CombatLog.post("No targets in range.", Color(0.75, 0.75, 0.75))
		return
	_targeting_spell = spell
	_targeting_monster = best
	_targeting_node = SpellTargetOverlay.new()
	_effect_layer.add_child(_targeting_node)
	_targeting_node.init(spell, p, _targeting_tiles)
	_targeting_node.set_target(best.grid_pos)
	CombatLog.post("Tap the %s to cast %s — tap elsewhere to cancel." \
			% [best.data.display_name, spell.display_name], Color(0.8, 0.75, 1.0))

func _cancel_targeting() -> void:
	_targeting_spell = null
	_targeting_tiles = []
	_targeting_monster = null
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
		TurnManager.end_player_turn(1, true)
		ticks += 1
		if _monster_in_sight():
			CombatLog.post("You stop resting — enemy spotted.", Color(1.0, 0.7, 0.5))
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
				TurnManager.end_player_turn()
		return
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
			TurnManager.end_player_turn()
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
		if result.size() >= 6:
			break
	return result

func _refresh_quickslots() -> void:
	if player == null:
		return
	if top_hud != null:
		var item_ids: Array[String] = _top_item_bar_ids()
		for i in range(6):
			if i >= item_ids.size():
				top_hud.set_item_slot(i, null, "")
				continue
			var item_id: String = item_ids[i]
			var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null else null
			if data == null:
				top_hud.set_item_slot(i, null, "")
				continue
			var count: int = player.count_item(item_id)
			var count_text: String = ("x%d" % count) if count > 1 else ""
			if GameManager.use_tiles and data.tile_path != "":
				var top_tex: Texture2D = _make_item_icon(data)
				top_hud.set_item_slot(i, top_tex, count_text)
			else:
				top_hud.set_item_slot_display(i, data.glyph, data.glyph_color)
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
	PauseMenuDialog.open(self)

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
		if player.can_attack_tile(nearest.grid_pos):
			player.try_attack_tile(nearest.grid_pos)
			return
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
			_spawn_floor_item(wdata, monster.grid_pos, 0)
	# Leave a corpse (non-unique only)
	if monster != null and monster.data != null and not monster.data.is_unique:
		map.corpses.append({
			"pos": monster.grid_pos,
			"tile_path": String(monster.data.tile_path),
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
	# B15 final boss death → victory
	if monster != null and monster.data != null \
			and monster.data.id == "abyssal_sovereign":
		await get_tree().create_timer(1.2).timeout
		CombatLog.post("The Abyssal Sovereign collapses. The dungeon trembles...",
				Color(0.85, 0.6, 1.0))
		await get_tree().create_timer(1.5).timeout
		_show_result_screen(true)
		return
	_handle_first_shrine_boss_clear(monster)
	# Before shrine choice, suppress all essence drops
	if not FaithSystem.has_chosen_faith(player):
		return
	_handle_monster_essence_drop(monster)

func _handle_first_shrine_boss_clear(monster: Monster) -> void:
	if map == null or monster == null or monster.data == null:
		return
	if GameManager.depth != 3 or map.altar_active or not monster.data.is_unique:
		return
	map.activate_altars()
	CombatLog.post("Ancient power stirs. The altars glow.", Color(0.85, 0.75, 1.0))
	if player != null and not FaithSystem.has_chosen_faith(player):
		ShrineDialog.open_choice(player, self)

func _handle_monster_essence_drop(monster: Monster) -> void:
	if monster == null or monster.data == null:
		return
	if monster.data.is_unique:
		var drop_chance: float = monster.data.drop_chance_override if monster.data.drop_chance_override >= 0.0 else 0.8
		if randf() >= drop_chance:
			return
		var uid: String = String(monster.data.essence_id)
		if uid == "":
			uid = EssenceSystem.random_id()
		CombatLog.post("The %s leaves behind an essence! (%s)" % [
			monster.data.display_name, EssenceSystem.display_name(uid)],
			Color(1.0, 0.75, 0.3))
		_queue_essence_pickup(uid)
		return
	var chance: float = min(0.22 + GameManager.depth * 0.01, 0.40)
	if randf() >= chance:
		return
	var essence_id: String
	if String(monster.data.essence_id) != "":
		essence_id = String(monster.data.essence_id)
	else:
		essence_id = EssenceSystem.random_id()
	CombatLog.post("An essence materializes! (%s)" % EssenceSystem.display_name(essence_id),
		Color(0.8, 0.6, 1.0))
	_queue_essence_pickup(essence_id)

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
		CombatLog.post("The %s notices you!" % monster.data.display_name, Color(1.0, 0.72, 0.45))
		spawn_text_popup(world_pos, "!", Color(1.0, 0.72, 0.35), 32, 0.55)
	else:
		CombatLog.post("The %s loses track of you." % monster.data.display_name, Color(0.7, 0.82, 0.95))
		spawn_text_popup(world_pos, "?", Color(0.75, 0.88, 1.0), 26, 0.5)

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

func spawn_text_popup(world_pos: Vector2, text: String, color: Color,
		font_size: int = 28, duration: float = 0.6) -> void:
	if _effect_layer == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = world_pos + Vector2(-12, -24)
	lbl.z_index = 10
	_effect_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, duration)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, duration)
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
		element: String, on_arrive: Callable = Callable(),
		delay: float = 0.0) -> void:
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
		rect.visible = false
		_effect_layer.add_child(rect)
		var tw := rect.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_callback(func(): rect.visible = true)
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
	_cache_current_floor()
	_clear_monsters()
	_clear_floor_items()
	GameManager.travel_to(target_depth)
	CombatLog.post("[DEBUG] Warp to B%d." % target_depth, Color(1.0, 0.85, 0.3))
	_generate_floor(target_depth, _floor_seed(target_depth), true)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()

func _debug_warp_to_branch(branch_id: String, branch_floor: int) -> void:
	_debug_panel.visible = false
	_debug_panel_visible = false
	_cache_current_floor()
	_clear_monsters()
	_clear_floor_items()
	var cfg: Dictionary = ZoneManager.branch_config(branch_id)
	var entry_depth: int = int(cfg.get("entrance_range", [1, 1])[1])
	GameManager.branch_zone = branch_id
	GameManager.branch_floor = branch_floor
	GameManager.branch_entry_depth = entry_depth
	GameManager.branches_cleared.erase(branch_id)
	CombatLog.post("[DEBUG] Warp to %s F%d." % [branch_id, branch_floor], Color(1.0, 0.85, 0.3))
	_generate_branch_floor(branch_id, branch_floor, true)
	RacePassiveSystem.on_floor_changed(player)
	_center_camera_on_player(true)
	_update_hud()
