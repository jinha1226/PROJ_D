extends Node

signal depth_changed(new_depth: int)
signal run_ended(result: String)
signal settings_changed

const SETTINGS_PATH: String = "user://settings.json"

const _POTION_COLORS: Array = [
	{"file": "brown",        "name": "갈색"},
	{"file": "ruby",         "name": "루비색"},
	{"file": "sky_blue",     "name": "하늘색"},
	{"file": "golden",       "name": "황금색"},
	{"file": "emerald",      "name": "에메랄드색"},
	{"file": "purple_red",   "name": "자주색"},
	{"file": "magenta",      "name": "자홍색"},
	{"file": "cyan",         "name": "청록색"},
	{"file": "pink",         "name": "분홍색"},
	{"file": "silver",       "name": "은색"},
	{"file": "white",        "name": "흰색"},
	{"file": "orange",       "name": "주황색"},
	{"file": "murky",        "name": "탁한"},
	{"file": "puce",         "name": "적갈색"},
	{"file": "fizzy",        "name": "탄산"},
	{"file": "bubbly",       "name": "보글보글"},
	{"file": "cloudy",       "name": "흐린"},
	{"file": "dark",         "name": "어두운"},
	{"file": "black",        "name": "검은"},
	{"file": "yellow",       "name": "노란"},
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
var selected_class_id: String = ""
var selected_race_id: String = "human"
var selected_starting_weapon_id: String = ""
var selected_starting_school_id: String = ""
var selected_starting_essence_id: String = ""
var selected_faith_id: String = ""

# Staging slot for loaded player stats. Game.gd consumes this on scene
# load and writes into the freshly-instantiated Player, then clears it.
var pending_player_state: Dictionary = {}

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

# Display / meta state (persisted).
var use_tiles: bool = true
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
		SaveManager.delete_save()
	emit_signal("run_ended", result)

func load_run() -> bool:
	var data: Dictionary = SaveManager.load_save()
	if data.is_empty() or not data.has("player"):
		return false
	depth = int(data.get("depth", 1))
	seed = int(data.get("seed", 0))
	gold = int(data.get("gold", 0))
	selected_class_id = String(data.get("selected_class_id", ""))
	selected_race_id = String(data.get("selected_race_id", "human"))
	identified = data.get("identified", {})
	pseudonyms = data.get("pseudonyms", {})
	potion_colors = data.get("potion_colors", {})
	if pseudonyms.is_empty() or potion_colors.is_empty():
		_generate_pseudonyms()
	var saved_kc = data.get("kill_counts", null)
	if saved_kc is Dictionary:
		kill_counts = saved_kc
	pending_player_state = data.get("player", {})
	run_in_progress = true
	return true

func is_identified(item_id: String) -> bool:
	return identified.get(item_id, false)

func identify(item_id: String) -> void:
	identified[item_id] = true

func _generate_pseudonyms() -> void:
	pseudonyms.clear()
	potion_colors.clear()
	var colors: Array = _POTION_COLORS.duplicate()
	var scrolls: Array = _SCROLL_WORDS.duplicate()
	var books: Array = _BOOK_ADJ.duplicate()
	colors.shuffle()
	scrolls.shuffle()
	books.shuffle()
	var ci: int = 0
	for item in ItemRegistry.all:
		match item.kind:
			"potion":
				var col: Dictionary = colors[ci % colors.size()]
				ci += 1
				potion_colors[item.id] = col.file
				pseudonyms[item.id] = "%s 포션" % col.name
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
		return data.display_name
	if is_identified(lookup_id):
		return data.display_name
	return pseudonyms.get(lookup_id, data.display_name)

func toggle_tiles() -> void:
	use_tiles = not use_tiles
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
	kill_counts[monster_id] = kill_counts.get(monster_id, 0) + 1
	_save_settings()
	# Race unlock by kill.
	for rid in RaceRegistry.by_id.keys():
		var r: RaceData = RaceRegistry.get_by_id(rid)
		if r == null:
			continue
		if String(r.unlock_kind) == "kill" \
				and String(r.unlock_trigger_id) == monster_id \
				and unlock(rid):
			CombatLog.post("New race unlocked: %s!" % r.display_name,
				Color(1.0, 0.9, 0.4))

func try_use_unlock(item_id: String) -> void:
	# Class unlock by item use.
	for cid in ClassRegistry.by_id.keys():
		var c: ClassData = ClassRegistry.get_by_id(cid)
		if c == null:
			continue
		if String(c.unlock_kind) == "use_item" \
				and String(c.unlock_trigger_id) == item_id \
				and unlock(cid):
			CombatLog.post("New class unlocked: %s!" % c.display_name,
				Color(1.0, 0.85, 0.35))

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
		"unlocks": unlocks,
		"kill_counts": kill_counts,
		"titles": titles,
	}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
