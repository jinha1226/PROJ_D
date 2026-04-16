extends Node
class_name TileRenderer
## Central lookup for which art asset renders a given in-game id.
## Modes:
##   LPC  — composed LPC sprites
##   DCSS — Dungeon Crawl Stone Soup individual tile PNGs (default)
##
## All DCSS tiles live under res://assets/dcss_tiles/individual/ — the full
## crawl rltiles tree (~6055 PNGs across dngn/, mon/, item/, player/) is
## bundled, so adding new monsters/items/branches is just a matter of
## extending the mapping dictionaries below.

enum Mode { LPC, DCSS }

const TILE: int = 32
const _BASE_DIR: String = "res://assets/dcss_tiles/individual/"

# Dungeon features keyed by canonical id. Branch overrides via BRANCH_TILESETS.
const FEATURES: Dictionary = {
	"floor":       "dngn/floor/grey_dirt0.png",
	"wall":        "dngn/wall/stone2_gray0.png",
	"stairs_up":   "dngn/gateways/stone_stairs_up.png",
	"stairs_down": "dngn/gateways/stone_stairs_down.png",
	"door_open":   "dngn/doors/open_door.png",
	"door_closed": "dngn/doors/closed_door.png",
	"water":       "dngn/floor/swamp0.png",
	"lava":        "dngn/floor/volcanic_floor0.png",
}

## Per-branch overrides. DungeonMap picks the right floor/wall/etc. by
## passing the current branch id; missing keys fall back to FEATURES.
const BRANCH_TILESETS: Dictionary = {
	"main": {
		"floor": "dngn/floor/grey_dirt0.png",
		"wall":  "dngn/wall/stone2_gray0.png",
	},
	"forest": {
		"floor": "dngn/floor/grass0.png",
		"wall":  "dngn/wall/tree1.png",
	},
	"mine": {
		"floor": "dngn/floor/cage0.png",
		"wall":  "dngn/wall/iron0-0.png",
	},
	"crypt": {
		"floor": "dngn/floor/crypt0.png",
		"wall":  "dngn/wall/tomb0.png",
	},
	"volcano": {
		"floor": "dngn/floor/volcanic_floor0.png",
		"wall":  "dngn/wall/cocytus0.png",
	},
	"swamp": {
		"floor": "dngn/floor/swamp0.png",
		"wall":  "dngn/wall/marble_wall0.png",
	},
	"crystal": {
		"floor": "dngn/floor/crystal_floor0.png",
		"wall":  "dngn/wall/crystal_wall_blue0.png",
	},
	"sandstone": {
		"floor": "dngn/floor/sandstone_floor0.png",
		"wall":  "dngn/wall/sandstone_wall0.png",
	},
}

const MONSTERS: Dictionary = {
	"rat":         "mon/animals/rat.png",
	"bat":         "mon/animals/bat.png",
	"goblin":      "mon/humanoids/goblin.png",
	"hobgoblin":   "mon/humanoids/hobgoblin.png",
	"kobold":      "mon/humanoids/kobold.png",
	"orc":         "mon/humanoids/orcs/orc.png",
	"orc_warrior": "mon/humanoids/orcs/orc_warrior.png",
	"orc_priest":  "mon/humanoids/orcs/orc_priest.png",
	"orc_wizard":  "mon/humanoids/orcs/orc_wizard.png",
	"adder":       "mon/animals/adder.png",
	"wolf":        "mon/animals/wolf.png",
	"jackal":      "mon/animals/jackal.png",
	"ball_python": "mon/animals/ball_python.png",
}

const ITEMS: Dictionary = {
	# Potions (effect-themed source files)
	"minor_potion":     "item/potion/i-curing.png",
	"major_potion":     "item/potion/i-heal-wounds.png",
	"mana_potion":      "item/potion/i-magic.png",
	# Scrolls
	"scroll_teleport":  "item/scroll/i-teleportation.png",
	"scroll_blink":     "item/scroll/i-blinking.png",
	"scroll_magic_map": "item/scroll/i-magic_mapping.png",
	"scroll_identify":  "item/scroll/i-identify.png",
	# Weapons — short blades
	"dagger":          "item/weapon/dagger.png",
	"short_sword":     "item/weapon/short_sword1.png",
	"rapier":          "item/weapon/short_sword2.png",
	"saber":           "item/weapon/short_sword3.png",
	# Long blades
	"arming_sword":    "item/weapon/long_sword1.png",
	"longsword":       "item/weapon/long_sword2.png",
	"katana":          "item/weapon/long_sword3.png",
	"greatsword":      "item/weapon/long_sword2.png",
	"scimitar":        "item/weapon/scimitar1.png",
	# Axes
	"axe":             "item/weapon/hand_axe1.png",
	"axe_medium":      "item/weapon/battle_axe1.png",
	"waraxe":          "item/weapon/war_axe1.png",
	# Maces / clubs
	"club":            "item/weapon/club.png",
	"mace":            "item/weapon/mace1.png",
	"flail":           "item/weapon/flail1.png",
	# Polearms
	"spear":           "item/weapon/spear1.png",
	"longspear":       "item/weapon/spear1.png",
	"halberd":         "item/weapon/halberd1.png",
	"scythe":          "item/weapon/scythe1.png",
	"trident":         "item/weapon/trident1.png",
	# Ranged
	"short_bow":       "item/weapon/ranged/shortbow1.png",
	"long_bow":        "item/weapon/ranged/longbow1.png",
	"bow":             "item/weapon/ranged/longbow1.png",
	"crossbow":        "item/weapon/ranged/arbalest1.png",
	"slingshot":       "item/weapon/ranged/sling1.png",
	"boomerang":       "item/weapon/ranged/sling1.png",
	# Staves
	"gnarled_staff":   "item/weapon/quarterstaff.png",
	"fire_staff":      "item/staff/i-staff_fire.png",
	"ice_staff":       "item/staff/i-staff_cold.png",
	"lightning_staff": "item/staff/i-staff_air.png",
	"crystal_staff":   "item/staff/i-staff_power.png",
	# Armor — chest
	"leather_chest":   "item/armour/leather_armour1.png",
	"chain_chest":     "item/armour/chain_mail1.png",
	"plate_chest":     "item/armour/plate1.png",
	# Legs (DCSS doesn't split — reuse second variants)
	"leather_legs":    "item/armour/leather_armour2.png",
	"chain_legs":      "item/armour/chain_mail2.png",
	"plate_legs":      "item/armour/plate2.png",
	# Boots
	"leather_boots":   "item/armour/boots1.png",
	"plate_boots":     "item/armour/boots2.png",
	# Helms (under headgear/)
	"leather_helm":    "item/armour/headgear/helmet1.png",
	"plate_helm":      "item/armour/headgear/helmet2.png",
	# Gloves
	"leather_gloves":  "item/armour/glove1.png",
	"plate_gloves":    "item/armour/glove2.png",
	# Aliases for legacy ids
	"leather_armor":   "item/armour/leather_armour1.png",
	"chain_mail":      "item/armour/chain_mail1.png",
	"plate_armor":     "item/armour/plate1.png",
}

const PLAYER_RACES: Dictionary = {
	"human":      "player/base/human_m.png",
	"hill_orc":   "player/base/orc_m.png",
	"minotaur":   "player/base/minotaur_m.png",
	"deep_elf":   "player/base/deep_elf_m.png",
	"troll":      "player/base/troll_m.png",
	"spriggan":   "player/base/spriggan_m.png",
	"catfolk":    "player/felids/cat1.png",
	"draconian":  "player/base/draconian.png",
}

# In-process texture cache so repeated lookups don't re-load.
static var _cache: Dictionary = {}


## Current render mode as stored on GameManager.
static func mode() -> int:
	if Engine.get_main_loop() == null:
		return Mode.DCSS
	var gm: Object = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm == null:
		return Mode.DCSS
	var v = gm.get("render_mode")
	if v == null:
		return Mode.DCSS
	return int(v)


static func is_dcss() -> bool:
	return mode() == Mode.DCSS


static func _load(path_rel: String) -> Texture2D:
	if path_rel == "":
		return null
	var full: String = _BASE_DIR + path_rel
	if _cache.has(full):
		return _cache[full]
	if not ResourceLoader.exists(full):
		push_warning("TileRenderer: missing tile %s" % full)
		_cache[full] = null
		return null
	var tex: Texture2D = load(full) as Texture2D
	_cache[full] = tex
	return tex


## Texture for a feature id — uses the active branch override when present.
static func feature(id: String, branch: String = "") -> Texture2D:
	if branch == "" and Engine.get_main_loop() != null:
		var gm: Object = Engine.get_main_loop().root.get_node_or_null("GameManager")
		if gm != null:
			branch = String(gm.get("current_branch") or "")
	if branch != "" and BRANCH_TILESETS.has(branch):
		var override: String = String(BRANCH_TILESETS[branch].get(id, ""))
		if override != "":
			return _load(override)
	return _load(String(FEATURES.get(id, "")))


static func monster(id: String) -> Texture2D:
	return _load(String(MONSTERS.get(id, "")))


static func item(id: String) -> Texture2D:
	return _load(String(ITEMS.get(id, "")))


## Base potion / scroll tile (the colour the player sees before identifying).
## Path picked from a per-run shuffled pool by GameManager.
static func consumable_base(id: String, kind: String) -> Texture2D:
	if Engine.get_main_loop() == null:
		return null
	var gm: Object = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm == null:
		return null
	var path: String = String(gm.consumable_base_path(id, kind))
	return _load(path)


static func player_race(id: String) -> Texture2D:
	return _load(String(PLAYER_RACES.get(id, "")))


## All known branch ids; useful for menus / debug.
static func known_branches() -> Array:
	return BRANCH_TILESETS.keys()
