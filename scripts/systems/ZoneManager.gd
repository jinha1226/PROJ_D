extends Node
## Zone configuration for main path and branches.
## Autoloaded singleton — exposes zone/branch configs by depth.

# ── Main path zones ──────────────────────────────────────────────────────────
const MAIN_ZONES: Array = [
	{"id": "dungeon",     "from": 1,  "to": 3,  "env": ""},
	{"id": "lair",        "from": 4,  "to": 6,  "env": ""},
	{"id": "orc_mines",   "from": 7,  "to": 9,  "env": ""},
	{"id": "elven_halls", "from": 10, "to": 12, "env": ""},
	{"id": "depths",      "from": 13, "to": 15, "env": ""},
	{"id": "boss",        "from": 16, "to": 16, "env": ""},
]

# ── Branch configs ───────────────────────────────────────────────────────────
const BRANCHES: Dictionary = {
	"swamp": {
		"display_name": "Swamp",
		"env": "poison",
		"entrance_range": [4, 6],
		"floors": 4,
		"env_damage": 2,
		"resistance": "poison+",
		"boss_id": "bog_serpent",
		"essence_reward": "essence_plague",
		"brand_element": "venom",
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown-vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/dirt0.png",
	},
	"ice_caves": {
		"display_name": "Ice Caves",
		"env": "cold",
		"entrance_range": [7, 12],
		"floors": 4,
		"env_damage": 2,
		"resistance": "cold+",
		"boss_id": "glacial_sovereign",
		"essence_reward": "essence_glacial",
		"brand_element": "freezing",
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown-vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/limestone0.png",
	},
	"infernal": {
		"display_name": "Infernal",
		"env": "fire",
		"entrance_range": [10, 15],
		"floors": 4,
		"env_damage": 2,
		"resistance": "fire+",
		"boss_id": "ember_tyrant",
		"essence_reward": "essence_infernal",
		"brand_element": "flaming",
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown-vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/crystal0.png",
	},
	"slime_pits": {
		"display_name": "Slime Pits",
		"env": "acid",
		"entrance_range": [13, 15],
		"floors": 4,
		"env_damage": 2,
		"resistance": "corr+",
		"boss_id": "sovereign_jelly",
		"essence_reward": "essence_acid",
		"brand_element": "acid",
		"wall": "res://assets/tiles/individual/dngn/wall/slime0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/acidic_floor0.png",
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

func branch_env_damage(branch_id: String, branch_floor: int) -> int:
	var cfg: Dictionary = BRANCHES.get(branch_id, {})
	if cfg.is_empty():
		return 0
	var base: int = int(cfg.get("env_damage", 2))
	return base if branch_floor > 1 else max(1, base / 2)

func branch_env_element(branch_id: String) -> String:
	return String(BRANCHES.get(branch_id, {}).get("env", ""))

func branch_resistance(branch_id: String) -> String:
	return String(BRANCHES.get(branch_id, {}).get("resistance", ""))

# Effective depth for monster/item scaling inside a branch.
func branch_effective_depth(branch_id: String, branch_floor: int) -> int:
	var cfg: Dictionary = BRANCHES.get(branch_id, {})
	if cfg.is_empty():
		return 8
	var mid: int = (int(cfg["entrance_range"][0]) + int(cfg["entrance_range"][1])) / 2
	return mid + branch_floor

# Rune bonus for clearing a branch.
const BRANCH_CLEAR_RUNES: int = 35
const ALL_BRANCHES_BONUS_RUNES: int = 120
