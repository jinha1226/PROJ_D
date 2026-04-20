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


## Return the vault list for `branch`, or an empty array if none defined.
static func for_branch(branch: String) -> Array:
	match branch:
		"main":    return MAIN_VAULTS
		"mine":    return MINE_VAULTS
		"forest":  return FOREST_VAULTS
		"swamp":   return SWAMP_VAULTS
		"volcano": return VOLCANO_VAULTS
		_:         return []


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
