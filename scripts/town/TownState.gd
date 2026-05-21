extends Node
## Persistent town-hub state. Autoloaded singleton. Survives character death.
## MVP scope: tracks expedition count, active-character race, last death summary.

const TOWN_SAVE_PATH: String = "user://town.json"

var expedition_count: int = 0
var current_character_alive: bool = false
var current_character_race: String = ""
var last_character_summary: Dictionary = {}

func _ready() -> void:
	load_state()

func start_new_character(race_id: String) -> void:
	current_character_alive = true
	current_character_race = race_id
	save_state()

func record_death(summary: Dictionary) -> void:
	last_character_summary = summary.duplicate(true)
	last_character_summary["victory"] = false
	current_character_alive = false
	current_character_race = ""
	expedition_count += 1
	save_state()

func record_victory(summary: Dictionary) -> void:
	last_character_summary = summary.duplicate(true)
	last_character_summary["victory"] = true
	current_character_alive = false
	current_character_race = ""
	expedition_count += 1
	save_state()

func has_last_summary() -> bool:
	return not last_character_summary.is_empty()

# ── Persistence ──────────────────────────────────────────────────────────
func save_state() -> bool:
	var data: Dictionary = {
		"expedition_count": expedition_count,
		"current_character_alive": current_character_alive,
		"current_character_race": current_character_race,
		"last_character_summary": last_character_summary,
	}
	var f := FileAccess.open(TOWN_SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("TownState: cannot open town save for write")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func load_state() -> void:
	if not FileAccess.file_exists(TOWN_SAVE_PATH):
		return
	var f := FileAccess.open(TOWN_SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	expedition_count = int(parsed.get("expedition_count", 0))
	current_character_alive = bool(parsed.get("current_character_alive", false))
	current_character_race = String(parsed.get("current_character_race", ""))
	last_character_summary = parsed.get("last_character_summary", {})
	if typeof(last_character_summary) != TYPE_DICTIONARY:
		last_character_summary = {}
