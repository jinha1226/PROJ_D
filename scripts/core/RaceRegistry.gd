class_name RaceRegistry
extends Object
## Applies DCSS-authentic species aptitudes on top of hand-tuned
## `resources/races/*.tres`. The .tres file supplies visual def + description
## + racial_trait; DCSS JSON fills in the aptitudes, base stats and levelup
## pattern so player characters spend their XP the way DCSS's species do.
##
## Lookup is lazy: `fetch(id)` returns a RaceData with both sources merged.

const _APTS_JSON: String = "res://assets/dcss_species/aptitudes.json"
const _TRES_DIR: String = "res://resources/races/%s.tres"

static var _dcss: Dictionary = {}
static var _loaded: bool = false
static var _cache: Dictionary = {}


static func fetch(id: String) -> RaceData:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	var path: String = _TRES_DIR % id
	var res: RaceData = null
	if ResourceLoader.exists(path):
		res = load(path) as RaceData
		if res != null:
			res = res.duplicate() as RaceData
	_ensure_loaded()
	var dcss: Dictionary = _dcss.get(id, {})
	if res == null and dcss.is_empty():
		return null
	if res == null:
		res = RaceData.new()
		res.id = id
		res.display_name = id.capitalize().replace("_", " ")
	if not dcss.is_empty():
		_apply_dcss(res, dcss)
	_cache[id] = res
	return res


## Apply DCSS-sourced aptitudes + base stats to a RaceData, overwriting any
## hand-tuned `skill_aptitudes` / `base_*` fields. The hand-tuned visual +
## racial_trait fields are preserved.
static func _apply_dcss(target: RaceData, entry: Dictionary) -> void:
	target.base_str = int(entry.get("base_str", target.base_str))
	target.base_int = int(entry.get("base_int", target.base_int))
	target.base_dex = int(entry.get("base_dex", target.base_dex))
	# hp_per_level / mp_per_level: DCSS uses aptitude deltas (`hp`, `mp_mod`).
	# Start from the race's current value and adjust by the DCSS delta.
	if entry.has("hp"):
		target.hp_per_level = max(2, target.hp_per_level + int(entry.get("hp", 0)))
	if entry.has("mp_mod"):
		target.mp_per_level = max(0, target.mp_per_level + int(entry.get("mp_mod", 0)))
	# Overwrite aptitudes wholesale — DCSS's set is the authoritative one.
	var apts: Dictionary = entry.get("aptitudes", {})
	if not apts.is_empty():
		var apt_dict: Dictionary = {}
		for k in apts.keys():
			apt_dict[String(k)] = int(apts[k])
		target.skill_aptitudes = apt_dict


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_APTS_JSON, FileAccess.READ)
	if f == null:
		push_warning("RaceRegistry: missing %s" % _APTS_JSON)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_dcss = parsed
		print("RaceRegistry: loaded %d DCSS species" % _dcss.size())
