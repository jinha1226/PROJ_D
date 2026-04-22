extends Node

signal depth_changed(new_depth: int)
signal run_ended(result: String)
signal settings_changed

const SETTINGS_PATH: String = "user://settings.json"

var depth: int = 1
var seed: int = 0
var gold: int = 0
var identified: Dictionary = {}
var run_in_progress: bool = false

# Character selection — set by menus before start_new_run().
var selected_class_id: String = ""
var selected_race_id: String = "human"

# Staging slot for loaded player stats. Game.gd consumes this on scene
# load and writes into the freshly-instantiated Player, then clears it.
var pending_player_state: Dictionary = {}

# Display / meta state (persisted).
var use_tiles: bool = true
var rune_shards: int = 0

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
	pending_player_state.clear()
	run_in_progress = true
	emit_signal("depth_changed", depth)

func descend() -> void:
	depth += 1
	emit_signal("depth_changed", depth)

func end_run(result: String) -> void:
	run_in_progress = false
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
	pending_player_state = data.get("player", {})
	run_in_progress = true
	return true

func is_identified(item_id: String) -> bool:
	return identified.get(item_id, false)

func identify(item_id: String) -> void:
	identified[item_id] = true

func toggle_tiles() -> void:
	use_tiles = not use_tiles
	_save_settings()
	emit_signal("settings_changed")

func add_rune_shards(amount: int) -> void:
	rune_shards = max(0, rune_shards + amount)
	_save_settings()

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
	rune_shards = int(parsed.get("rune_shards", rune_shards))

func _save_settings() -> void:
	var data := {"use_tiles": use_tiles, "rune_shards": rune_shards}
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data))
	f.close()
