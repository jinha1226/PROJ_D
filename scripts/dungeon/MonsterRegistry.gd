class_name MonsterRegistry
extends Object
## Single source of truth for monster definitions.
##
## Lookup priority:
##   1. `res://resources/monsters/<id>.tres` — hand-tuned overrides (e.g.
##      boss sprites, custom essence drops) win when present.
##   2. `assets/dcss_mons/monsters.json` — 667 entries ported from
##      crawl-ref/dat/mons at build time by tools/convert_dcss_mons.py.
##
## Every call to `get(id)` returns a MonsterData. Cached so repeated calls
## during a floor don't re-parse JSON or reload Resources.

const _DCSS_JSON_PATH: String = "res://assets/dcss_mons/monsters.json"
const _TRES_DIR: String = "res://resources/monsters/%s.tres"

static var _dcss_raw: Dictionary = {}
static var _cache: Dictionary = {}
static var _loaded: bool = false


static func fetch(id: String) -> MonsterData:
	if id == "":
		return null
	if _cache.has(id):
		return _cache[id]
	_ensure_loaded()
	var dcss_entry: Dictionary = _dcss_raw.get(id, {})
	# If we have a hand-tuned .tres, use it for core balance numbers
	# (hp/str/dex/xp_value/sprite/etc.) but fold in DCSS extended fields
	# (glyph, flags, shape, habitat, attacks, resists) so the AI and
	# renderer get the richer metadata even for our existing monsters.
	var path: String = _TRES_DIR % id
	if ResourceLoader.exists(path):
		var res: MonsterData = load(path) as MonsterData
		if res != null:
			var merged: MonsterData = res.duplicate() as MonsterData
			if not dcss_entry.is_empty():
				_merge_dcss_extended(merged, dcss_entry)
			_cache[id] = merged
			return merged
	# No .tres — build purely from DCSS data.
	if dcss_entry.is_empty():
		return null
	var built: MonsterData = _build_from_dcss(id, dcss_entry)
	_cache[id] = built
	return built


## Fold DCSS extended fields onto a hand-tuned MonsterData loaded from .tres,
## without touching the balance numbers the .tres already set.
static func _merge_dcss_extended(target: MonsterData, entry: Dictionary) -> void:
	# Don't overwrite fields the .tres customised. `glyph_char == "?"` is the
	# MonsterData default, so treat that as "not set" and pull from DCSS.
	if target.glyph_char == "?" or target.glyph_char == "":
		var glyph: Dictionary = entry.get("glyph", {})
		target.glyph_char = String(glyph.get("char", "?"))
		target.glyph_color = String(glyph.get("colour", "white"))
	if target.hd <= 1:
		target.hd = int(entry.get("hd", target.hd))
	if target.hp_10x <= 10:
		target.hp_10x = int(entry.get("hp_10x", target.hp_10x))
	if target.speed <= 0 or target.speed == 10:
		# 10 is the default; always prefer DCSS value when present.
		target.speed = int(entry.get("speed", 10))
	if target.flags.is_empty():
		target.flags = _to_string_array(entry.get("flags", []))
	if target.spells_book == "":
		target.spells_book = String(entry.get("spells", ""))
	if target.attacks.is_empty():
		target.attacks = entry.get("attacks", []) if typeof(entry.get("attacks")) == TYPE_ARRAY else []
	if target.resists.is_empty():
		target.resists = _to_string_array(entry.get("resists", []))
	if target.intelligence == "animal":
		target.intelligence = String(entry.get("intelligence", "animal"))
	if target.size == "medium":
		target.size = String(entry.get("size", "medium"))
	if target.shape == "humanoid":
		target.shape = String(entry.get("shape", "humanoid"))
	if target.habitat == "land":
		target.habitat = String(entry.get("habitat", "land"))
	if target.shout == "silent":
		target.shout = String(entry.get("shout", "silent"))
	# Energy overrides only fold in when the .tres left them at default
	# (10 for the four land axes, 6 for swim). That way a hand-tuned
	# boss's custom energy stays intact but a plain naga.tres picks up
	# move_energy=14 from the DCSS table.
	if target.move_energy == 10 and target.attack_energy == 10 \
			and target.spell_energy == 10 and target.missile_energy == 10:
		_apply_energy_overrides(target, target.id)


## List every monster id we know about — union of `.tres` files and DCSS JSON
## entries. Used by MonsterSpawner's depth-based pool.
static func all_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Dictionary = {}
	for k in _dcss_raw.keys():
		ids[String(k)] = true
	# Scan the .tres folder too so purely hand-tuned monsters appear.
	var dir := DirAccess.open("res://resources/monsters/")
	if dir != null:
		dir.list_dir_begin()
		var f: String = dir.get_next()
		while f != "":
			if f.ends_with(".tres"):
				ids[f.trim_suffix(".tres")] = true
			f = dir.get_next()
		dir.list_dir_end()
	var out: Array[String] = []
	for k in ids.keys():
		out.append(String(k))
	out.sort()
	return out


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_DCSS_JSON_PATH, FileAccess.READ)
	if f == null:
		push_warning("MonsterRegistry: missing %s" % _DCSS_JSON_PATH)
		return
	var text: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MonsterRegistry: monsters.json is not a dict")
		return
	_dcss_raw = parsed
	print("MonsterRegistry: loaded ", _dcss_raw.size(), " DCSS monsters")


## Translate one DCSS YAML entry (as parsed JSON) into a MonsterData.
##
## Stats derived from DCSS fields:
##   hp       ≈ round(hp_10x / 10). DCSS rolls HD-dice so avg hp ~= hp_10x/10.
##   str/dex  — DCSS doesn't expose these directly; approximate from HD/size.
##   xp_value ≈ DCSS `exp` × 10 (our XP scale is coarser).
##   sprite   left null — assets map is keyed by id separately.
static func _build_from_dcss(id: String, entry: Dictionary) -> MonsterData:
	var d: MonsterData = MonsterData.new()
	d.id = id
	d.display_name = String(entry.get("name", id))
	# Core DCSS fields.
	d.hd = int(entry.get("hd", 1))
	d.hp_10x = int(entry.get("hp_10x", d.hd * 40))
	d.hp = max(1, d.hp_10x / 10)
	d.ac = int(entry.get("ac", 0))
	d.ev = int(entry.get("ev", 0))
	d.speed = int(entry.get("speed", 10))
	d.will = int(entry.get("will", 0))
	d.exp_mod = int(entry.get("exp", 1))
	d.xp_value = max(1, d.exp_mod)  # DCSS exp field is the direct XP value
	# Str / Dex aren't in DCSS YAML; approximate from HD and size so existing
	# combat code reading attacker.str keeps working. Mediums & bigger get a
	# small dex penalty, little & small get a bonus.
	var size_str: String = String(entry.get("size", "medium"))
	d.size = size_str
	d.str = max(1, 2 + d.hd)
	d.dex = 5 + _size_dex_mod(size_str)
	# Glyph.
	var glyph: Dictionary = entry.get("glyph", {})
	d.glyph_char = String(glyph.get("char", "?"))
	d.glyph_color = String(glyph.get("colour", "white"))
	# Flavour / AI hints.
	d.intelligence = String(entry.get("intelligence", "animal"))
	d.shape = String(entry.get("shape", "humanoid"))
	d.habitat = String(entry.get("habitat", "land"))
	d.shout = String(entry.get("shout", "silent"))
	d.flags = _to_string_array(entry.get("flags", []))
	d.attacks = entry.get("attacks", []) if typeof(entry.get("attacks")) == TYPE_ARRAY else []
	d.resists = _to_string_array(entry.get("resists", []))
	d.spells_book = String(entry.get("spells", ""))
	_apply_energy_overrides(d, id)
	# Tier is a rough difficulty band we use for UI sorting. Map to DCSS HD.
	if d.hd >= 20:
		d.tier = 5
	elif d.hd >= 14:
		d.tier = 4
	elif d.hd >= 9:
		d.tier = 3
	elif d.hd >= 5:
		d.tier = 2
	else:
		d.tier = 1
	return d


static func _size_dex_mod(size: String) -> int:
	match size:
		"little": return 3
		"small":  return 2
		"medium": return 0
		"large":  return -1
		"giant":  return -2
	return 0


## DCSS mon-data.h mon_energy_usage overrides for species that deviate
## from DEFAULT_ENERGY{10,10,10,10,10,10,10,10}. Keyed by id prefix so
## e.g. "naga", "naga_warrior", "naga_sharpshooter" all get the slow
## coils. Only the nonstandard axes are written; the rest keep the
## MonsterData field defaults.
const _ENERGY_OVERRIDES: Dictionary = {
	# Slow coils — nagas + naja-shape snakes.
	"naga":        {"move": 14},
	"salamander":  {"move": 14},
	# Fast movers — bats, rats, centaurs, spriggans.
	"bat":         {"move": 5},
	"vampire_bat": {"move": 5},
	"centaur":     {"move": 6, "missile": 7},
	"yaktaur":     {"missile": 7},
	"spriggan":    {"move": 6},
	# Slow biters — dragons, giants, jelly.
	"jelly":       {"move": 14, "attack": 14},
	"azure_jelly": {"move": 14, "attack": 14},
	"acid_blob":   {"move": 14, "attack": 14},
	"fire_dragon": {"attack": 15},
	"ice_dragon":  {"attack": 15},
	"steam_dragon":{"attack": 15},
	"hill_giant":  {"attack": 12},
	"stone_giant": {"attack": 12},
	# Quick stinger — adders, scorpions.
	"adder":       {"attack": 8},
	"scorpion":    {"attack": 9},
	"wasp":        {"move": 9, "attack": 9},
}


static func _apply_energy_overrides(d: MonsterData, id: String) -> void:
	var o: Variant = _ENERGY_OVERRIDES.get(id, null)
	if o == null:
		# Try stem match — "orc_wizard" → "orc_", "troll_dragon" → "troll_", etc.
		# Only fires when the exact key isn't present so family traits
		# stay limited to the ported species names.
		for key in _ENERGY_OVERRIDES.keys():
			if id == key or id.begins_with(String(key) + "_"):
				o = _ENERGY_OVERRIDES[key]
				break
	if typeof(o) != TYPE_DICTIONARY:
		return
	if o.has("move"):
		d.move_energy = int(o["move"])
	if o.has("attack"):
		d.attack_energy = int(o["attack"])
	if o.has("spell"):
		d.spell_energy = int(o["spell"])
	if o.has("missile"):
		d.missile_energy = int(o["missile"])
	if o.has("swim"):
		d.swim_energy = int(o["swim"])


static func _to_string_array(v: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(v) != TYPE_ARRAY:
		return out
	for s in v:
		out.append(String(s))
	return out
