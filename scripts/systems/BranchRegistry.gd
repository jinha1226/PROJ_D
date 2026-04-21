class_name BranchRegistry
extends RefCounted
## DCSS branch tree — lazy-loads `assets/dcss_branches/branches.json`
## (produced by our earlier data import) and answers "what branches
## enter from here?" + "where do I return to when leaving branch X?".
##
## Data shape from JSON:
##   { "branches": [ {id, parent, min_depth, max_depth, floors, ...}, ... ] }
## We fold it into `_by_id` on load.

const _JSON: String = "res://assets/dcss_branches/branches.json"

static var _by_id: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_JSON, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	for entry in parsed.get("branches", []):
		var bid: String = String(entry.get("id", ""))
		if bid != "":
			_by_id[bid] = entry


static func get_info(id: String) -> Dictionary:
	_ensure_loaded()
	return _by_id.get(id, {}).duplicate() if _by_id.has(id) else {}


static func floors_in(id: String) -> int:
	_ensure_loaded()
	return int(_by_id.get(id, {}).get("floors", 1))


static func display_name(id: String) -> String:
	_ensure_loaded()
	return String(_by_id.get(id, {}).get("long_name", id.capitalize()))


static func short_name(id: String) -> String:
	_ensure_loaded()
	return String(_by_id.get(id, {}).get("short_name", id.capitalize()))


static func parent_of(id: String) -> String:
	_ensure_loaded()
	var p = _by_id.get(id, {}).get("parent")
	return "" if p == null else String(p)


## Portal-vault helpers. Portal vaults are timed one-floor branches
## (Sewer, Ossuary, Bailey, Volcano, Icecave, …) distinguished by
## `is_portal: true` in branches.json. GameManager ticks a per-portal
## turn counter on entry and force-exits when it hits zero.
static func is_portal(id: String) -> bool:
	_ensure_loaded()
	return bool(_by_id.get(id, {}).get("is_portal", false))


static func portal_duration(id: String) -> int:
	_ensure_loaded()
	return int(_by_id.get(id, {}).get("duration", 80))


static func monster_pool(id: String) -> Array:
	_ensure_loaded()
	var pool = _by_id.get(id, {}).get("monster_pool", [])
	return pool if typeof(pool) == TYPE_ARRAY else []


static func loot_bump(id: String) -> float:
	_ensure_loaded()
	return float(_by_id.get(id, {}).get("loot_bump", 1.0))


static func entry_message(id: String) -> String:
	_ensure_loaded()
	var msg = _by_id.get(id, {}).get("entry_msg")
	return String(msg) if msg != null else ""


## All portal-vault ids eligible for placement at a given main-dungeon
## depth. Used by DungeonGenerator._place_branch_entrances to decide
## which portal to spawn.
static func portals_at_depth(parent_branch: String, depth: int) -> Array:
	_ensure_loaded()
	var out: Array = []
	for bid in _by_id.keys():
		var info: Dictionary = _by_id[bid]
		if not bool(info.get("is_portal", false)):
			continue
		if String(info.get("parent", "")) != parent_branch:
			continue
		var lo: int = int(info.get("min_depth", 0))
		var hi: int = int(info.get("max_depth", 0))
		if lo <= depth and depth <= hi:
			out.append(bid)
	return out


## Branches that enter from `parent_branch:depth`. Used by
## DungeonGenerator to place entrance tiles on the right floors.
## Excludes self-referential / deprecated entries; keys the result by
## child branch id → placement depth range.
static func children_entering_at(parent_branch: String, depth: int) -> Array:
	_ensure_loaded()
	var out: Array = []
	for bid in _by_id.keys():
		var info: Dictionary = _by_id[bid]
		if String(info.get("parent", "")) != parent_branch:
			continue
		var lo: int = int(info.get("min_depth", 0))
		var hi: int = int(info.get("max_depth", 0))
		if lo <= depth and depth <= hi:
			out.append(bid)
	return out


## A stable per-run depth where `branch_id`'s entrance should land in
## its parent. Hashing run-seed + branch id gives reproducibility —
## save/restore will always pick the same floor for the entrance.
static func entry_depth_for(branch_id: String, seed_val: int) -> int:
	_ensure_loaded()
	var info: Dictionary = _by_id.get(branch_id, {})
	if info.is_empty():
		return 0
	var lo: int = int(info.get("min_depth", 1))
	var hi: int = int(info.get("max_depth", lo))
	if hi <= lo:
		return lo
	var h: int = abs(hash(branch_id)) ^ (seed_val & 0xFFFF)
	return lo + (h % (hi - lo + 1))
