extends Node
## Zone configuration for main path and branches.
## Autoloaded singleton — exposes zone/branch configs by depth.

# ── Main path zones ──────────────────────────────────────────────────────────
# wall/floor: zone-themed tiles (override depth-based selection)
# Note: depth 3 (B3 ruined temple) is overridden in DungeonMap._load_atmosphere
const MAIN_ZONES: Array = [
	# 15-floor PROJ_D layout compressed to 5 PROJ_G themed floors (2026-05-21).
	# Original ranges retained in comments for migration reference.
	{"id": "dungeon",     "from": 1, "to": 1, "env": "",      "map_style": "bsp",       # was depths 1-3 (Catacombs)
		"wall":  "res://assets/tiles/individual/dngn/wall/lpc_gray_stone.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lpc_stone_cobble.png"},
	{"id": "lair",        "from": 2, "to": 2, "env": "",      "map_style": "cave",      # was depths 4-6 (Lair)
		"wall":  "res://assets/tiles/individual/dngn/wall/lpc_dark_cobble.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lpc_dirt.png"},
	{"id": "orc_mines",   "from": 3, "to": 3, "env": "",      "map_style": "bsp",       # was depths 7-9 (Orc Mines)
		"wall":  "res://assets/tiles/individual/dngn/wall/lpc_red_brick.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lpc_dark_brick.png"},
	{"id": "elven_halls", "from": 4, "to": 4, "env": "",      "map_style": "bsp_large", # was depths 10-12 (Elven Halls)
		"wall":  "res://assets/tiles/individual/dngn/wall/lpc_beige_stone.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lpc_cream_tile.png"},
	{"id": "abyss",       "from": 5, "to": 5, "env": "abyss", "map_style": "cave",      # was depths 13-14 (Abyss + final boss)
		"wall":  "res://assets/tiles/individual/dngn/wall/lpc_dark_stone.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lpc_dark_hex.png"},
]

# ── Branch configs ───────────────────────────────────────────────────────────
const BRANCHES: Dictionary = {
	"swamp": {
		"display_name": "Swamp",
		"map_style": "cave",
		"env": "poison",
		"entrance_range": [2, 2],
		"floors": 3,
		"resistance": "poison+",
		"boss_id": "bog_serpent",
		"essence_reward": "essence_plague",
		"ring_reward": "ring_bog",
		"resist_ring": "ring_poison_resist",
		"rune_reward": "rune_swamp",
		"brand_element": "venom",
		"entrance_tile": "res://assets/tiles/individual/dngn/gateways/enter_swamp.png",
		"wall": "res://assets/tiles/individual/dngn/wall/wall_vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/swamp0.png",
	},
	"ice_caves": {
		"display_name": "Ice Caves",
		"map_style": "cave",
		"env": "cold",
		"entrance_range": [3, 3],
		"floors": 3,
		"resistance": "cold+",
		"boss_id": "glacial_sovereign",
		"essence_reward": "essence_glacial",
		"ring_reward": "ring_glacier",
		"resist_ring": "ring_cold_resist",
		"rune_reward": "rune_ice",
		"brand_element": "freezing",
		"entrance_tile": "res://assets/tiles/individual/dngn/gateways/ice_cave_portal.png",
		"wall": "res://assets/tiles/individual/dngn/wall/ice_wall0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/ice0.png",
	},
	"infernal": {
		"display_name": "Infernal",
		"map_style": "bsp_large",
		"env": "fire",
		"entrance_range": [4, 4],
		"floors": 3,
		"resistance": "fire+",
		"boss_id": "ember_tyrant",
		"essence_reward": "essence_infernal",
		"ring_reward": "ring_ember",
		"resist_ring": "ring_fire_resist",
		"rune_reward": "rune_infernal",
		"brand_element": "flaming",
		"entrance_tile": "res://assets/tiles/individual/dngn/gateways/enter_hell1.png",
		"wall": "res://assets/tiles/individual/dngn/wall/volcanic_wall0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lava00.png",
	},
	"crypt": {
		"display_name": "Crypt",
		"map_style": "crypt",
		"env": "necro",
		"entrance_range": [1, 1],
		"floors": 3,
		"resistance": "necro+",
		"boss_id": "ancient_lich",
		"essence_reward": "essence_undeath",
		"ring_reward": "ring_undeath",
		"resist_ring": "ring_necro_resist",
		"rune_reward": "rune_crypt",
		"brand_element": "drain",
		"entrance_tile": "res://assets/tiles/individual/dngn/gateways/necropolis_portal.png",
		"wall": "res://assets/tiles/individual/dngn/wall/wall_stone_necropolis_1.png",
		"floor": "res://assets/tiles/individual/dngn/floor/necro_squares00.png",
	},
}

# ── Main-path zone helpers ───────────────────────────────────────────────────
func zone_for_depth(depth: int) -> Dictionary:
	for z in MAIN_ZONES:
		if depth >= int(z["from"]) and depth <= int(z["to"]):
			return z
	return MAIN_ZONES[MAIN_ZONES.size() - 1]

func zone_id_for_depth(depth: int) -> String:
	return String(zone_for_depth(depth).get("id", "dungeon"))

# Returns which branch (if any) should have its entrance on this main-path depth.
# Entrance is placed on the LAST floor of a zone's range.
func branch_entrance_for_depth(depth: int) -> String:
	for branch_id in BRANCHES.keys():
		var cfg: Dictionary = BRANCHES[branch_id]
		var range_end: int = int(cfg["entrance_range"][1])
		if depth == range_end:
			return branch_id
	return ""

# ── Branch helpers ───────────────────────────────────────────────────────────
func branch_config(branch_id: String) -> Dictionary:
	return BRANCHES.get(branch_id, {})

func branch_resistance(branch_id: String) -> String:
	return String(BRANCHES.get(branch_id, {}).get("resistance", ""))

# Effective depth for monster/item scaling inside a branch.
func branch_effective_depth(branch_id: String, branch_floor: int) -> int:
	var cfg: Dictionary = BRANCHES.get(branch_id, {})
	if cfg.is_empty():
		return 8
	var mid: int = (int(cfg["entrance_range"][0]) + int(cfg["entrance_range"][1])) / 2
	return mid + branch_floor

# Turn budget per main floor depth (PROJ_G mobile_skill_balance_rules.md §Turn Budget).
const MAIN_TURN_BUDGETS: Dictionary = {
	1: 240,
	2: 260,
	3: 270,
	4: 290,
	5: 300,
}
const BRANCH_TURN_BUDGET: int = 180  # PROJ_G says 170-190; pick middle.

func turn_budget_for_depth(depth: int) -> int:
	return int(MAIN_TURN_BUDGETS.get(depth, 240))

func turn_budget_for_branch(_branch_id: String) -> int:
	return BRANCH_TURN_BUDGET

# ── Branch monster pools (DCSS-sourced) ─────────────────────────────────────
# Monsters are listed roughly weakest-to-strongest within each pool.
const BRANCH_MONSTER_POOLS: Dictionary = {
	"swamp": [
		# weak
		"adder", "vampire_bat", "giant_wolf_spider", "scorpion",
		# mid
		"zombie", "ghoul", "phantom",
		# strong
		"vampire", "swamp_dragon", "wyvern",
	],
	"ice_caves": [
		# weak
		"yak", "wight", "crypt_zombie", "gargoyle",
		# mid
		"wraith", "shadow_wraith", "stone_giant",
		# strong
		"frost_giant", "ice_devil", "ice_dragon", "titan",
	],
	"infernal": [
		# weak
		"crimson_imp", "fire_elemental",
		# mid
		"red_devil", "iron_golem",
		# strong
		"balrug", "fire_giant", "fire_dragon", "executioner",
	],
	"crypt": [
		# weak
		"zombie", "crypt_zombie", "skeletal_warrior", "mummy", "phantom",
		# mid
		"ghoul", "wight", "wraith", "shadow_wraith", "revenant",
		# strong
		"vampire", "vampire_knight", "lich", "deep_elf_death_mage", "bone_dragon",
	],
}

# Rune bonus for clearing a branch.
const BRANCH_CLEAR_RUNES: int = 35
const ALL_BRANCHES_BONUS_RUNES: int = 120
