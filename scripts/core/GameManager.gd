extends Node

signal depth_changed(new_depth: int)
signal run_ended(result: String)
signal settings_changed

const SETTINGS_PATH: String = "user://settings.json"

## Potion color file names. Display name resolves through translations.csv —
## color_file → POTION_COLOR_<UPPER> key. Stored as just the file id so
## live language switches translate on display without re-rolling the
## per-run color assignment.
const _POTION_COLOR_FILES: Array = [
	"brown", "ruby", "sky_blue", "golden", "emerald",
	"purple_red", "magenta", "cyan", "pink", "silver",
	"white", "orange", "murky", "puce", "fizzy",
	"bubbly", "cloudy", "dark", "black", "yellow",
]
const _SCROLL_WORDS: Array = ["GIB XON", "VEL AMR", "HYAR ZED",
	"MOR TEX", "ARN BEK", "DUO LIS", "KER NAR", "FAL MIR",
	"QUA ZEN", "ORA TUM", "BEL TOR", "NIX HAL"]
const _BOOK_ADJ: Array = ["obsidian", "crimson", "ancient", "gilded",
	"rotting", "starlit", "iron-bound", "vellum"]

var depth: int = 1
var seed: int = 0
var gold: int = 0
var identified: Dictionary = {}   # item_id -> true once identified
var pseudonyms: Dictionary = {}   # item_id -> "갈색 포션" for this run
var potion_colors: Dictionary = {} # item_id -> "brown" (file base name)
var run_in_progress: bool = false

# Character selection — set by menus before start_new_run().
var selected_race_id: String = "human"
var selected_talent_id: String = ""
var selected_starting_weapon_id: String = ""
var selected_starting_school_id: String = ""
var selected_starting_essence_id: String = ""
var selected_faith_id: String = ""

# Staging slot for loaded player stats. Game.gd consumes this on scene
# load and writes into the freshly-instantiated Player, then clears it.
var pending_player_state: Dictionary = {}

# Items the player picked at the Starter Shop. Game._ready consumes
# this on new-run setup, then clears it.
var pending_starter_items: Array = []

# Per-depth cached floor state — kept in-memory across ascend/descend
# so revisiting a floor restores its tiles, explored fog, remaining
# items, and survivor monsters. Not persisted to disk (save on stairs
# is canonical; multi-floor snapshots would bloat saves).
var floor_cache: Dictionary = {}

# Branch state (per-run, not persisted to disk save).
var branch_zone: String = ""       # "" = main path; "swamp" | "ice_caves" | "infernal"
var branch_floor: int = 0          # 1-4 inside a branch; 0 = not in branch
var branch_entry_depth: int = 0    # main-path depth where branch was entered
var branch_floor_cache: Dictionary = {}  # branch_zone+floor -> floor state
var branches_cleared: Array = []   # branch ids cleared this run

# Explored tiles that survive across expeditions — cleared only on death,
# not on start_new_run. Key: "branch_id_floor" (e.g. "swamp_1").
# Value: Dictionary[Vector2i, bool].
var persistent_branch_explored: Dictionary = {}

# Pre-game starter shop budget. Set on race selection, cleared on first Game._ready().
const STARTING_GOLD: int = 150
var starter_shop_gold: int = 0

# Display / meta state (persisted).
var use_tiles: bool = true
var use_rt_mode: bool = false
var titles: Array = []  # earned title strings

## Permanent unlock registry — race / class ids the player has earned
## across runs. Keyed by plain id (e.g. "kobold", "rogue"). Written
## to settings.json so deaths don't revoke progress.
var unlocks: Dictionary = {}

## Kill counts per monster id — persisted across runs in settings.json.
var kill_counts: Dictionary = {}  # monster_id → int

func _ready() -> void:
	_load_settings()

func start_new_run(random_seed: int = -1) -> void:
	if random_seed < 0:
		seed = randi()
	else:
		seed = random_seed
	depth = 1
	gold = 0
	identified.clear()
	potion_colors.clear()
	floor_cache.clear()
	branch_zone = ""
	branch_floor = 0
	branch_entry_depth = 0
	branch_floor_cache.clear()
	branches_cleared.clear()
	_generate_pseudonyms()
	pending_player_state.clear()
	# Do NOT clear starter_shop_gold here — _apply_starter_kit() converts
	# the remaining budget to player.gold and clears it at run entry.
	run_in_progress = true
	emit_signal("depth_changed", depth)

func descend() -> void:
	depth += 1
	emit_signal("depth_changed", depth)

func ascend() -> void:
	depth = max(1, depth - 1)
	emit_signal("depth_changed", depth)

func travel_to(d: int) -> void:
	depth = d
	emit_signal("depth_changed", depth)

func end_run(result: String) -> void:
	run_in_progress = false
	floor_cache.clear()
	if result == "death":
		persistent_branch_explored.clear()
		SaveManager.delete_save()
	emit_signal("run_ended", result)

func load_run() -> bool:
	var data: Dictionary = SaveManager.load_save()
	if data.is_empty() or not data.has("player"):
		return false
	depth = int(data.get("depth", 1))
	seed = int(data.get("seed", 0))
	gold = int(data.get("gold", 0))
	selected_race_id = String(data.get("selected_race_id", "human"))
	selected_talent_id = String(data.get("selected_talent_id", ""))
	identified = data.get("identified", {})
	pseudonyms = data.get("pseudonyms", {})
	potion_colors = data.get("potion_colors", {})
	if pseudonyms.is_empty() or potion_colors.is_empty():
		_generate_pseudonyms()
	var saved_kc = data.get("kill_counts", null)
	if saved_kc is Dictionary:
		kill_counts = saved_kc
	pending_player_state = data.get("player", {})
	# Branch state (save_version >= 2).
	branch_zone = String(data.get("branch_zone", ""))
	branch_floor = int(data.get("branch_floor", 0))
	branch_entry_depth = int(data.get("branch_entry_depth", 0))
	var saved_bc = data.get("branches_cleared", null)
	branches_cleared = saved_bc.duplicate() if saved_bc is Array else []
	# Floor caches.
	var fc_raw = data.get("floor_cache", null)
	if fc_raw is Dictionary:
		floor_cache = SaveCodec.decode_cache_dict(fc_raw, true)
	else:
		floor_cache.clear()
	var bfc_raw = data.get("branch_floor_cache", null)
	if bfc_raw is Dictionary:
		branch_floor_cache = SaveCodec.decode_cache_dict(bfc_raw, false)
	else:
		branch_floor_cache.clear()
	var pbe_raw = data.get("persistent_branch_explored", null)
	if pbe_raw is Dictionary:
		persistent_branch_explored = SaveCodec.decode_explored_map(pbe_raw)
	else:
		pass  # keep existing in-memory value (cross-expedition persistence)
	# Party state.
	var party_raw = data.get("party", null)
	if party_raw is Dictionary:
		PartyManager.load_state(party_raw)
	run_in_progress = true
	return true

func is_identified(item_id: String) -> bool:
	return identified.get(item_id, false)

func identify(item_id: String) -> void:
	identified[item_id] = true

func _generate_pseudonyms() -> void:
	pseudonyms.clear()
	potion_colors.clear()
	var colors: Array = _POTION_COLOR_FILES.duplicate()
	var scrolls: Array = _SCROLL_WORDS.duplicate()
	var books: Array = _BOOK_ADJ.duplicate()
	colors.shuffle()
	scrolls.shuffle()
	books.shuffle()
	var ci: int = 0
	for item in ItemRegistry.all:
		match item.kind:
			"potion":
				var color_file: String = String(colors[ci % colors.size()])
				ci += 1
				potion_colors[item.id] = color_file
				# Marker prefix `__potion_color__:<file>` — display_name_of()
				# expands it via LocaleManager so language switches live.
				pseudonyms[item.id] = "__potion_color__:%s" % color_file
			"scroll":
				if not scrolls.is_empty():
					pseudonyms[item.id] = "scroll labeled %s" % scrolls.pop_back()
			"book":
				if not books.is_empty():
					pseudonyms[item.id] = "%s tome" % books.pop_back()


func potion_color_tile(item_id: String) -> String:
	var color_file: String = potion_colors.get(item_id, "brown")
	return "res://assets/tiles/individual/item/potion/%s.png" % color_file

func display_name_of(item_id: String) -> String:
	var lookup_id: String = ItemRegistry.base_id_of(item_id) if ItemRegistry != null else item_id
	var data = ItemRegistry.get_by_id(lookup_id) if ItemRegistry != null and lookup_id != "" else null
	if data == null:
		return item_id
	# Weapons / armor / gold are always recognisable.
	if data.kind != "potion" and data.kind != "scroll" and data.kind != "book":
		return data.loc_name()
	if is_identified(lookup_id):
		return data.loc_name()
	var raw: String = String(pseudonyms.get(lookup_id, data.loc_name()))
	# Expand the live-locale marker for unidentified potions.
	if raw.begins_with("__potion_color__:"):
		var color_file: String = raw.substr("__potion_color__:".length())
		var color_key: String = "POTION_COLOR_" + color_file.to_upper()
		return "%s %s" % [LocaleManager.t(color_key), LocaleManager.t("POTION_KIND")]
	return raw

func toggle_tiles() -> void:
	use_tiles = not use_tiles
	_save_settings()
	emit_signal("settings_changed")

func toggle_rt_mode() -> void:
	use_rt_mode = not use_rt_mode
	_save_settings()
	emit_signal("settings_changed")

func unlock(id: String) -> bool:
	if id == "":
		return false
	if bool(unlocks.get(id, false)):
		return false
	unlocks[id] = true
	_save_settings()
	return true

func is_unlocked(id: String) -> bool:
	return bool(unlocks.get(id, false))

func try_kill_unlock(monster_id: String) -> void:
	var prev_count: int = int(kill_counts.get(monster_id, 0))
	kill_counts[monster_id] = prev_count + 1
	if prev_count == 0:
		# First time killing this monster id → bestiary entry just unlocked.
		# Reward Tracking XP for the discovery.
		var tree := get_tree() if Engine.get_main_loop() is SceneTree else null
		if tree != null:
			var p = tree.get_first_node_in_group("player")
			if p != null and p.has_method("grant_skill_xp"):
				p.grant_skill_xp("tracking", 5.0)
	_save_settings()
	# Race unlock by kill.
	for rid in RaceRegistry.by_id.keys():
		var r: RaceData = RaceRegistry.get_by_id(rid)
		if r == null:
			continue
		if String(r.unlock_kind) == "kill" \
				and String(r.unlock_trigger_id) == monster_id \
				and unlock(rid):
			CombatLog.post(LocaleManager.t("LOG_NEW_RACE_UNLOCKED") % r.display_name,
				Color(1.0, 0.9, 0.4))

func try_use_unlock(_item_id: String) -> void:
	# Class system removed; item-use unlocks no longer applicable.
	pass

func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	use_tiles = bool(parsed.get("use_tiles", use_tiles))
	use_rt_mode = bool(parsed.get("use_rt_mode", use_rt_mode))
	var saved_titles = parsed.get("titles", null)
	if saved_titles is Array:
		titles = saved_titles
	var saved_unlocks = parsed.get("unlocks", null)
	if saved_unlocks is Dictionary:
		unlocks = saved_unlocks
	var saved_kill_counts = parsed.get("kill_counts", null)
	if saved_kill_counts is Dictionary:
		kill_counts = saved_kill_counts

func earn_title(title: String) -> void:
	if title != "" and not titles.has(title):
		titles.append(title)
		_save_settings()

func _save_settings() -> void:
	var data := {
		"use_tiles": use_tiles,
		"use_rt_mode": use_rt_mode,
		"unlocks": unlocks,
		"kill_counts": kill_counts,
		"titles": titles,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
