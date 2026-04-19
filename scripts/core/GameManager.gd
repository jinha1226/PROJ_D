extends Node
## Global game state singleton. Holds current run context.

signal run_started
signal run_ended(victory: bool)

var current_depth: int = 1
var current_seed: int = -1
var player: Node = null
var dungeon: Node = null
# Character-creation selections. Set by RaceSelect / JobSelect screens.
# "" means: use GameBootstrap defaults.
var selected_race_id: String = ""
var selected_job_id: String = ""
var selected_trait_id: String = ""
# Art mode — 0 = LPC (composed), 1 = DCSS tiles. Read via TileRenderer.mode().
# DCSS is now the default since the tile mapping is complete.
var render_mode: int = 1
# Current dungeon branch id (for tile theming). "main" / "forest" / "mine" /
# "crypt" / "volcano" / "swamp" / "crystal" / "sandstone". TileRenderer.feature
# picks the right floor/wall texture based on this.
var current_branch: String = "main"

# --- Item identification (per-run) ---
# identified[id] == true once the player has drunk/read/identified a consumable.
var identified: Dictionary = {}
# Randomised pseudonyms for unidentified potions/scrolls. Stable within a run.
var _pseudonyms: Dictionary = {}
# Per-id DCSS base image filename (without extension). Drives the visible
# colour/look of unidentified consumables in DCSS render mode.
var _consumable_bases: Dictionary = {}
var _pseudonyms_assigned: bool = false

const _POTION_DESCRIPTORS: Array = [
	"Red", "Blue", "Green", "Yellow", "Purple", "Amber",
	"Swirling", "Bubbling", "Milky", "Frothing", "Foul", "Sweet",
	"Cloudy", "Glittering", "Smoky",
]
const _SCROLL_LABELS: Array = [
	"ZUN TAB", "VAX ROL", "ELIK DUR", "TREM OMOM", "OMAR BAB",
	"BLINKY", "KRULL", "ZEMA", "VORAL", "XENO", "AFOR PLI", "JEBA QI",
	"NEMIS", "PRUX", "GOROM",
]

# DCSS base-tile filenames (stem only; consumable_base_path prepends the
# full item/potion/ or item/scroll/ path). Files live under
# res://assets/dcss_tiles/individual/item/{potion,scroll}/.
const _POTION_BASE_TILES: Array = [
	"brilliant_blue", "sky_blue", "ruby", "emerald", "yellow", "orange",
	"cyan", "white", "black", "pink", "silver", "golden",
	"magenta", "murky", "puce",
]
const _SCROLL_BASE_TILES: Array = [
	"blue", "red", "green", "purple", "cyan", "yellow", "brown", "grey",
]


func start_new_run(job_id: String = "fighter", race_id: String = "human", run_seed: int = -1) -> void:
	current_depth = 1
	current_seed = run_seed if run_seed != -1 else randi()
	selected_race_id = race_id
	selected_job_id = job_id
	identified.clear()
	_pseudonyms.clear()
	_consumable_bases.clear()
	_pseudonyms_assigned = false
	run_started.emit()


func identify(id: String) -> void:
	identified[id] = true


func is_identified(id: String) -> bool:
	return identified.has(id)


## Returns true name if identified, or a stable pseudonym otherwise. Falls
## through to `fallback` for non-consumable items.
func display_name_for_item(id: String, fallback: String, kind: String) -> String:
	if identified.has(id):
		return fallback
	if kind == "potion" or kind == "scroll":
		_ensure_pseudonyms()
		return String(_pseudonyms.get(id, fallback))
	return fallback


func _ensure_pseudonyms() -> void:
	if _pseudonyms_assigned:
		return
	_pseudonyms_assigned = true
	var potion_ids: Array = []
	var scroll_ids: Array = []
	for cid in ConsumableRegistry.all_ids():
		var info: Dictionary = ConsumableRegistry.get_info(cid)
		var k: String = String(info.get("kind", ""))
		if k == "potion":
			potion_ids.append(cid)
		elif k == "scroll":
			scroll_ids.append(cid)
	var pd: Array = _POTION_DESCRIPTORS.duplicate()
	pd.shuffle()
	var pb: Array = _POTION_BASE_TILES.duplicate()
	pb.shuffle()
	for i in potion_ids.size():
		_pseudonyms[potion_ids[i]] = "%s Potion" % pd[i % pd.size()]
		_consumable_bases[potion_ids[i]] = pb[i % pb.size()]
	var sl: Array = _SCROLL_LABELS.duplicate()
	sl.shuffle()
	var sb: Array = _SCROLL_BASE_TILES.duplicate()
	sb.shuffle()
	for i in scroll_ids.size():
		_pseudonyms[scroll_ids[i]] = "Scroll labeled %s" % sl[i % sl.size()]
		_consumable_bases[scroll_ids[i]] = sb[i % sb.size()]


## DCSS base tile filename (stem) for a consumable id, paired with the kind.
## Returns "" if not a known consumable.
func consumable_base_path(id: String, kind: String) -> String:
	_ensure_pseudonyms()
	var stem: String = String(_consumable_bases.get(id, ""))
	if stem == "":
		return ""
	if kind == "potion":
		return "item/potion/%s.png" % stem
	elif kind == "scroll":
		return "item/scroll/scroll-%s.png" % stem
	return ""

func end_run(victory: bool) -> void:
	run_ended.emit(victory)


## Maps depth → branch id. 5-floor segments rotate the dungeon theme so each
## stretch of run feels distinct (also drives boss-floor tile selection).
##   D:1-5   main      D:6-10  mine    D:11-15 forest
##   D:16-20 swamp     D:21-25 volcano
func branch_for_depth(d: int) -> String:
	if d <= 5:
		return "main"
	if d <= 10:
		return "mine"
	if d <= 15:
		return "forest"
	if d <= 20:
		return "swamp"
	return "volcano"
