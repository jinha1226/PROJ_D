class_name RandartGenerator
extends RefCounted
## DCSS-style random artefact generator for rings and amulets.
## Each randart gets a unique "the <Adj> <Noun>" name and 1-4 randomly
## rolled properties chosen from a depth-weighted pool.
##
## Usage:
##   var r := RandartGenerator.generate_ring(depth)
##   var a := RandartGenerator.generate_amulet(depth)
## Both return a FloorItem-ready Dictionary (same shape as RingRegistry /
## AmuletRegistry entries) with id="randart_ring_<n>" and kind="ring"/"amulet".

# --- Name parts -------------------------------------------------------
const _ADJ: Array = [
	"Shimmering", "Ancient", "Twisted", "Blazing", "Silent", "Phantom",
	"Iron", "Golden", "Cursed", "Blessed", "Midnight", "Radiant",
	"Broken", "Whispering", "Crimson", "Azure", "Fading", "Forgotten",
	"Sunken", "Vile", "Sterling", "Hollow", "Gleaming", "Rusted",
]
const _RING_NOUN: Array = [
	"Band", "Loop", "Coil", "Sigil", "Seal", "Circle", "Arc", "Hoop",
]
const _AMULET_NOUN: Array = [
	"Talisman", "Pendant", "Token", "Charm", "Locket", "Eye", "Stone",
	"Teardrop", "Shard", "Mark",
]

# --- Property pool ----------------------------------------------------
# Each entry: { key, min, max, weight, label }
# key matches the field names Player._recompute_gear_stats reads from rings.
# "resists.X" → stored in the "resists" sub-dict.
# "flags.X"   → appended to the "flags" array.
const _PROPS: Array = [
	{"key": "str",          "min": 1, "max": 3, "weight": 8,  "label": "Str"},
	{"key": "dex",          "min": 1, "max": 3, "weight": 8,  "label": "Dex"},
	{"key": "int_",         "min": 1, "max": 3, "weight": 8,  "label": "Int"},
	{"key": "ac",           "min": 1, "max": 4, "weight": 7,  "label": "AC"},
	{"key": "ev",           "min": 1, "max": 4, "weight": 7,  "label": "EV"},
	{"key": "mp_max",       "min": 3, "max": 9, "weight": 6,  "label": "MP"},
	{"key": "dmg_bonus",    "min": 1, "max": 3, "weight": 6,  "label": "Slay"},
	{"key": "spell_power",  "min": 2, "max": 5, "weight": 5,  "label": "Pow"},
	{"key": "regen",        "min": 1, "max": 1, "weight": 4,  "label": "regen"},
	{"key": "stealth",      "min": 1, "max": 3, "weight": 5,  "label": "Stlth"},
	{"key": "resists.fire", "min": 1, "max": 1, "weight": 5,  "label": "rF+"},
	{"key": "resists.cold", "min": 1, "max": 1, "weight": 5,  "label": "rC+"},
	{"key": "resists.elec", "min": 1, "max": 1, "weight": 4,  "label": "rElec+"},
	{"key": "resists.poison","min": 1,"max": 1, "weight": 5,  "label": "rPois+"},
	{"key": "resists.neg",  "min": 1, "max": 1, "weight": 3,  "label": "rN+"},
	{"key": "flags.see_invis","min":1,"max": 1, "weight": 4,  "label": "sInv"},
	{"key": "flags.flying", "min": 1, "max": 1, "weight": 2,  "label": "Flight"},
]

# Negative properties (drawbacks) that can appear on randarts.
const _NEG_PROPS: Array = [
	{"key": "str",       "min": -2, "max": -1, "weight": 3, "label": "Str"},
	{"key": "dex",       "min": -2, "max": -1, "weight": 3, "label": "Dex"},
	{"key": "int_",      "min": -2, "max": -1, "weight": 3, "label": "Int"},
	{"key": "ac",        "min": -2, "max": -1, "weight": 3, "label": "AC"},
	{"key": "ev",        "min": -2, "max": -1, "weight": 3, "label": "EV"},
	{"key": "stealth",   "min": -2, "max": -1, "weight": 3, "label": "Stlth"},
]

# Unique counter so IDs never collide within a run.
static var _counter: int = 0


## Generate a random ring. `depth` drives property count and value caps.
static func generate_ring(depth: int) -> Dictionary:
	_counter += 1
	var name_s: String = "the %s %s" % [
		_ADJ[randi() % _ADJ.size()],
		_RING_NOUN[randi() % _RING_NOUN.size()],
	]
	var props: Dictionary = _roll_properties(depth)
	props["id"]    = "randart_ring_%d" % _counter
	props["name"]  = name_s
	props["slot"]  = "ring"
	props["kind"]  = "ring"
	props["color"] = Color(randf_range(0.55, 1.0), randf_range(0.55, 1.0), randf_range(0.55, 1.0))
	props["randart"] = true
	return props


## Generate a random amulet.
static func generate_amulet(depth: int) -> Dictionary:
	_counter += 1
	var name_s: String = "the %s %s" % [
		_ADJ[randi() % _ADJ.size()],
		_AMULET_NOUN[randi() % _AMULET_NOUN.size()],
	]
	var props: Dictionary = _roll_properties(depth)
	props["id"]    = "randart_amulet_%d" % _counter
	props["name"]  = name_s
	props["slot"]  = "amulet"
	props["kind"]  = "amulet"
	props["color"] = Color(randf_range(0.55, 1.0), randf_range(0.55, 1.0), randf_range(0.55, 1.0))
	props["randart"] = true
	return props


## Returns a property dict with 1-4 positive props (+ optional 1 negative).
static func _roll_properties(depth: int) -> Dictionary:
	# Number of positive properties scales with depth.
	var num_pos: int = 1 + int(depth / 5)
	num_pos = clampi(num_pos, 1, 4)
	# Small chance of a drawback on deeper items.
	var has_neg: bool = depth >= 5 and randf() < 0.30

	var result: Dictionary = {"resists": {}, "flags": []}
	var used_keys: Array = []

	for _i in range(num_pos):
		var prop: Dictionary = _weighted_pick(_PROPS, used_keys)
		if prop.is_empty():
			break
		used_keys.append(prop["key"])
		var val: int = randi_range(int(prop["min"]), int(prop["max"]))
		# Value scales slightly with depth.
		if depth >= 7:
			val = clampi(val + 1, int(prop["min"]), int(prop["max"]) + 1)
		_apply_prop(result, prop["key"], val)

	if has_neg:
		var neg: Dictionary = _weighted_pick(_NEG_PROPS, [])
		if not neg.is_empty():
			var nval: int = randi_range(int(neg["min"]), int(neg["max"]))
			_apply_prop(result, neg["key"], nval)

	# Clean up empty sub-dicts so callers don't need to guard them.
	if result["resists"].is_empty():
		result.erase("resists")
	if result["flags"].is_empty():
		result.erase("flags")
	return result


static func _apply_prop(d: Dictionary, key: String, val: int) -> void:
	if key.begins_with("resists."):
		var elem: String = key.substr(8)
		if not d.has("resists"):
			d["resists"] = {}
		d["resists"][elem] = int(d["resists"].get(elem, 0)) + val
	elif key.begins_with("flags."):
		var flag: String = key.substr(6)
		if not d.has("flags"):
			d["flags"] = []
		if not d["flags"].has(flag):
			d["flags"].append(flag)
	else:
		d[key] = int(d.get(key, 0)) + val


## Weighted random pick from pool, skipping already-used keys.
static func _weighted_pick(pool: Array, exclude: Array) -> Dictionary:
	var total: int = 0
	for p in pool:
		if not exclude.has(p["key"]):
			total += int(p["weight"])
	if total == 0:
		return {}
	var roll: int = randi() % total
	var acc: int = 0
	for p in pool:
		if exclude.has(p["key"]):
			continue
		acc += int(p["weight"])
		if roll < acc:
			return p
	return {}


## Build a compact display string listing all properties (for tooltip).
static func describe(item: Dictionary) -> String:
	var parts: Array = []
	var stat_map: Dictionary = {
		"str": "Str", "dex": "Dex", "int_": "Int",
		"ac": "AC", "ev": "EV", "mp_max": "MP",
		"dmg_bonus": "Slay", "spell_power": "Pow",
		"regen": "regen", "stealth": "Stlth",
	}
	for k in stat_map.keys():
		var v: int = int(item.get(k, 0))
		if v != 0:
			parts.append("%s %+d" % [stat_map[k], v])
	var resists: Dictionary = item.get("resists", {})
	for elem in resists.keys():
		var lv: int = int(resists[elem])
		if lv != 0:
			parts.append("r%s%s" % [elem.capitalize().left(1).to_upper() + elem.substr(1).left(3), "+" if lv > 0 else ""])
	for flag in item.get("flags", []):
		parts.append(String(flag).replace("_", " ").capitalize())
	return ", ".join(PackedStringArray(parts)) if not parts.is_empty() else "(no properties)"
