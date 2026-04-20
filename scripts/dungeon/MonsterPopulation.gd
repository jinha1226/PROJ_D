class_name MonsterPopulation
extends Object
## DCSS depth-based spawn table.
##
## `assets/dcss_mons/population.json` is built at author-time by
## tools/convert_dcss_population.py from crawl-ref/source/mon-pick-data.h.
## Each entry has (min, max, weight, shape, id) where shape controls how the
## weight tapers across the depth range.
##
## We route branch names via `_BRANCH_MAP` so our game's 5-branch structure
## (main/mine/forest/swamp/volcano) consumes DCSS's 20+ branch entries.
##
## Shape curves (DCSS convention):
##   FLAT  — full weight across [min, max]
##   PEAK  — triangular peak in the middle of the range
##   SEMI  — trapezoidal, full weight in middle, ramps at ends
##   FALL  — starts at full weight, falls off toward max
##   RISE  — starts low, rises toward max
## We keep the same names and translate to multipliers in `_shape_weight`.

const _POPULATION_JSON: String = "res://assets/dcss_mons/population.json"

## Our game's 5-branch structure → DCSS branch names to pull from.
## Pulling from multiple DCSS branches lets one of our branches inherit a
## union of DCSS pools (e.g. our "mine" reuses DCSS Orcish Mines + Dungeon).
const _BRANCH_MAP: Dictionary = {
	"main":    ["Dungeon"],
	"mine":    ["Orcish Mines", "Dungeon", "Dwarven Hall"],
	"forest":  ["Lair", "Forest", "Snake Pit", "Spider Nest"],
	"swamp":   ["Swamp", "Shoals", "Lair"],
	"volcano": ["Volcano", "Gehenna", "Zot"],
}

static var _table: Dictionary = {}
static var _loaded: bool = false


## Pick a weighted-random monster id eligible at (branch, depth). Returns ""
## if no entry matches (shouldn't happen for configured branches).
static func pick(branch: String, depth: int, rng: RandomNumberGenerator = null) -> String:
	if rng == null:
		rng = RandomNumberGenerator.new()
	var candidates: Array = eligible(branch, depth)
	if candidates.is_empty():
		return ""
	var total: float = 0.0
	for c in candidates:
		total += c["effective_weight"]
	if total <= 0:
		return ""
	var roll: float = rng.randf() * total
	var acc: float = 0.0
	for c in candidates:
		acc += c["effective_weight"]
		if roll <= acc:
			return String(c["id"])
	return String(candidates[-1]["id"])


## Convert our game's global depth (1..25) into the relative depth inside the
## currently active branch (1..5). DCSS pop tables are branch-local — e.g.
## Lair only runs 1..6 — so our floor 12 (forest bucket) needs to resolve to
## Lair:2 to find the right monster weights.
static func branch_local_depth(global_depth: int) -> int:
	# Branches are 5 floors each starting at main d=1.
	var local: int = ((global_depth - 1) % 5) + 1
	return local


## Return every population entry eligible at (branch, depth) with its shape-
## adjusted weight. Used by `pick` and by diagnostics / UI lists.
static func eligible(branch: String, depth: int) -> Array:
	_ensure_loaded()
	var source_branches: Array = _BRANCH_MAP.get(branch, ["Dungeon"])
	var out: Array = []
	for sb in source_branches:
		var entries: Array = _table.get(sb, [])
		for e in entries:
			var mn: int = int(e.get("min", 1))
			var mx: int = int(e.get("max", 99))
			if depth < mn or depth > mx:
				continue
			var shape: String = String(e.get("shape", "FLAT"))
			var raw: float = float(e.get("weight", 0))
			var eff: float = raw * _shape_weight(depth, mn, mx, shape)
			if eff <= 0:
				continue
			out.append({
				"id": String(e.get("id", "")),
				"min": mn,
				"max": mx,
				"effective_weight": eff,
			})
	return out


## Curve multiplier for a DCSS rarity shape. Matches the qualitative intent
## of crawl-ref's pop_entry shapes without chasing the exact C++ numbers.
static func _shape_weight(depth: int, mn: int, mx: int, shape: String) -> float:
	if mx <= mn:
		return 1.0
	var t: float = float(depth - mn) / float(mx - mn)   # 0.0 .. 1.0
	match shape:
		"FLAT":
			return 1.0
		"PEAK":
			# Triangular: 0 at ends, 1 in middle.
			return 1.0 - abs(t - 0.5) * 2.0
		"SEMI":
			# Trapezoid: full in middle half, ramps on outer quarters.
			if t < 0.25: return t * 4.0
			if t > 0.75: return (1.0 - t) * 4.0
			return 1.0
		"FALL":
			return 1.0 - t
		"RISE":
			return t
	return 1.0


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_POPULATION_JSON, FileAccess.READ)
	if f == null:
		push_warning("MonsterPopulation: missing %s" % _POPULATION_JSON)
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("MonsterPopulation: population.json is not a dict")
		return
	_table = parsed
	var total: int = 0
	for k in _table.keys():
		total += (_table[k] as Array).size()
	print("MonsterPopulation: loaded %d branches, %d entries" % [_table.size(), total])
