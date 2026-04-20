class_name VaultRegistry
extends Object
## Minivault templates — small handcrafted chunks overlaid on the generated
## map to add flavour per branch. DCSS-style but much simpler: no Lua hooks,
## no kprop tags, just ASCII grids.
##
## Char legend:
##   '#'  wall
##   '.'  floor
##   'w'  water
##   'l'  lava
##   'T'  tree (impassable wall with tree sprite)
##   ' '  transparent — leave the underlying generated tile alone
##
## All rows in a single template must be the same length. Width / height
## are derived at placement time.

const MAIN_VAULTS: Array = [
	# Pillared hall
	[
		"##########",
		"#........#",
		"#.#....#.#",
		"#........#",
		"#.#....#.#",
		"#........#",
		"##########",
	],
	# Cross crossroads with a stony centerpiece
	[
		"   ###   ",
		"   #.#   ",
		"   #.#   ",
		"###...###",
		"#...#...#",
		"###...###",
		"   #.#   ",
		"   #.#   ",
		"   ###   ",
	],
	# Diamond chamber
	[
		"  ###  ",
		" #...# ",
		"#.....#",
		"#..#..#",
		"#.....#",
		" #...# ",
		"  ###  ",
	],
]

const MINE_VAULTS: Array = [
	# Big cavern with central pillar
	[
		"##........##",
		"#..........#",
		"..........##",
		"....####....",
		"....####....",
		"##..........",
		"#..........#",
		"##........##",
	],
	# Ore veins: wall clusters inside open floor
	[
		"...........",
		".##...##...",
		".#.....#...",
		"...........",
		"...##...##.",
		"....#....#.",
		"...........",
	],
	# Mineshaft
	[
		"##.....##",
		"#.......#",
		".........",
		".#######.",
		".........",
		"#.......#",
		"##.....##",
	],
]

const FOREST_VAULTS: Array = [
	# Grove: ring of trees with a clearing
	[
		"TTTTTTT",
		"T.....T",
		"T.....T",
		"T..T..T",
		"T.....T",
		"T.....T",
		"TTTTTTT",
	],
	# Forest path between trees
	[
		"TT.TT.TTTT",
		"T...T...T.",
		"..TT...TT.",
		"T...TT..T.",
		"TT.TT.TTTT",
	],
	# Lone tree clearing
	[
		"  TTT  ",
		" T...T ",
		"T..T..T",
		"T.....T",
		" T...T ",
		"  TTT  ",
	],
]

const SWAMP_VAULTS: Array = [
	# Pool ringed with trees
	[
		"TTTTTTT",
		"T.....T",
		"T.www.T",
		"T.www..",
		"T.www.T",
		"T.....T",
		"TTTTTTT",
	],
	# Meandering water
	[
		"..........",
		".wwww.....",
		"....www...",
		"......www.",
		"..www.....",
		"..........",
	],
	# Island in water
	[
		"wwwwwwww",
		"w......w",
		"w..TT..w",
		"w..TT..w",
		"w......w",
		"wwwwwwww",
	],
]

const VOLCANO_VAULTS: Array = [
	# Lava pool
	[
		"#######",
		"#.....#",
		"#.lll.#",
		"#.lll..",
		"#.lll.#",
		"#.....#",
		"#######",
	],
	# Magma cross
	[
		"..#...#..",
		".........",
		"#...l...#",
		"..lllll..",
		"#...l...#",
		".........",
		"..#...#..",
	],
	# Volcanic island surrounded by lava
	[
		"llllllll",
		"l......l",
		"l.####.l",
		"l.#..#.l",
		"l.####.l",
		"l......l",
		"llllllll",
	],
]


## DCSS-imported vaults, populated from res://assets/dcss_des/*.des on first
## access. Each entry is the raw DesParser dict: {name, tags, depth_specs,
## weight, map, source, ...}. Kept separate from the hand-coded MAIN_VAULTS
## etc. so they can be filtered by branch + depth at pick time.
static var _dcss_vaults: Array = []
static var _dcss_loaded: bool = false

const _DCSS_DIRS: Array[String] = [
	"res://assets/dcss_des/variable",
	"res://assets/dcss_des/builder",
]


## Ensure the DCSS vault pool is loaded. Safe to call repeatedly — work only
## happens on the first invocation. Called lazily from `for_branch_at_depth`.
static func ensure_dcss_loaded() -> void:
	if _dcss_loaded:
		return
	_dcss_loaded = true
	for dir_path in _DCSS_DIRS:
		var parsed: Array = DesParser.parse_directory(dir_path)
		for v in parsed:
			_dcss_vaults.append(_convert_dcss_vault(v))
	# Drop any conversions that resulted in empty maps.
	var kept: Array = []
	for v in _dcss_vaults:
		if not v.get("map", []).is_empty():
			kept.append(v)
	_dcss_vaults = kept
	print("VaultRegistry: loaded ", _dcss_vaults.size(), " DCSS vaults")


## Map DCSS glyphs into our 5-glyph vault vocabulary (#/./w/l/T + space).
## Lossy on purpose — it lets DCSS vaults plug into the existing `_stamp_vault`
## path without teaching the placer about statues, glass, runed doors, etc.
static func _convert_dcss_vault(v: Dictionary) -> Dictionary:
	var converted_map: Array = []
	for row in v.get("map", []):
		var out: String = ""
		for ch in String(row):
			out += _dcss_glyph_to_ours(ch)
		converted_map.append(out)
	var r: Dictionary = v.duplicate(true)
	r["map"] = converted_map
	return r


static func _dcss_glyph_to_ours(ch: String) -> String:
	if ch == "." or ch == "@" or ch == "+" or ch == "a":
		return "."
	if ch == "x" or ch == "c" or ch == "b" or ch == "v" or ch == "m" or ch == "G" or ch == "#":
		return "#"
	if ch == "W" or ch == "w":
		return "w"
	if ch == "l":
		return "l"
	if ch == "T":
		return "T"
	return " "


## Return the vault list for `branch`, or an empty array if none defined.
## Used by pre-DCSS callers; prefer `for_branch_at_depth` for depth-aware picks.
static func for_branch(branch: String) -> Array:
	match branch:
		"main":    return MAIN_VAULTS
		"mine":    return MINE_VAULTS
		"forest":  return FOREST_VAULTS
		"swamp":   return SWAMP_VAULTS
		"volcano": return VOLCANO_VAULTS
		_:         return []


## Depth-aware vault pool: combines hand-coded branch vaults with DCSS .des
## imports that match the given (branch, depth). Returns Array of map grids
## (Array[String]) — compatible with `_stamp_vault`.
static func for_branch_at_depth(branch: String, depth: int) -> Array:
	ensure_dcss_loaded()
	var out: Array = []
	# Hand-coded vaults are always eligible for their branch.
	for tmpl in for_branch(branch):
		out.append(tmpl)
	# DCSS vaults filter by depth spec. We also skip vaults whose footprint
	# would swamp the map (>25x25 is effectively a full-level layout).
	for v in _dcss_vaults:
		if not DesParser.vault_matches(v, branch, depth):
			continue
		var m: Array = v.get("map", [])
		if m.is_empty():
			continue
		var h: int = m.size()
		var w: int = String(m[0]).length()
		if h > 25 or w > 25:
			continue
		out.append(m)
	return out


## Decode a single char into a DungeonGenerator.TileType value, or -1 to
## indicate "transparent — keep existing tile" for spaces.
static func char_to_tile(ch: String) -> int:
	match ch:
		"#": return DungeonGenerator.TileType.WALL
		".": return DungeonGenerator.TileType.FLOOR
		"w": return DungeonGenerator.TileType.WATER
		"l": return DungeonGenerator.TileType.LAVA
		"T": return DungeonGenerator.TileType.TREE
		" ": return -1
		_:   return DungeonGenerator.TileType.FLOOR
