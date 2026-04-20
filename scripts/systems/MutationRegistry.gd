class_name MutationRegistry
extends RefCounted
## DCSS mutation-data.h catalog (port). Lazy-loaded from
## `assets/dcss_mutations/mutations.json` — each entry carries weight,
## max levels, flags, and short desc. Effect application lives in
## `Player.apply_mutation` / `Player.remove_mutation`; this registry is
## just the data + helpers for random-mutation rolls.

const _JSON: String = "res://assets/dcss_mutations/mutations.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_JSON, FileAccess.READ)
	if f == null:
		push_warning("MutationRegistry: missing %s" % _JSON)
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_data = parsed


static func get_info(id: String) -> Dictionary:
	_ensure_loaded()
	return _data.get(id, {}).duplicate() if _data.has(id) else {}


static func levels_for(id: String) -> int:
	_ensure_loaded()
	return int(_data.get(id, {}).get("levels", 1))


static func desc_for(id: String) -> String:
	_ensure_loaded()
	return String(_data.get(id, {}).get("desc", id))


static func has(id: String) -> bool:
	_ensure_loaded()
	return _data.has(id)


static func all_ids() -> Array:
	_ensure_loaded()
	return _data.keys()


## Weighted pick across the table. `filter_flag` in ["good", "bad", ""]
## narrows to that polarity (a potion of mutation rolls from the full
## set, a Beneficial Mutation only from `good`). Returns the chosen
## mutation id, or "" if nothing is eligible.
static func pick_random(filter_flag: String = "") -> String:
	_ensure_loaded()
	var total: int = 0
	var entries: Array = []
	for mid in _data.keys():
		var e: Dictionary = _data[mid]
		var w: int = int(e.get("weight", 0))
		if w <= 0:
			continue
		var flags: Array = e.get("flags", [])
		if filter_flag != "" and not flags.has(filter_flag):
			continue
		total += w
		entries.append({"id": mid, "w": w})
	if total <= 0 or entries.is_empty():
		return ""
	var roll: int = randi() % total
	var acc: int = 0
	for e in entries:
		acc += int(e["w"])
		if roll < acc:
			return String(e["id"])
	return String(entries[-1]["id"])
