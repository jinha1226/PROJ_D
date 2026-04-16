extends Node
class_name TileRenderer
## Central lookup for which art asset renders a given in-game id.
## Modes:
##   LPC  — composed LPC sprites
##   DCSS — Dungeon Crawl Stone Soup individual tile PNGs (default)
##
## Mode is a GameManager-level setting so it persists across scenes.
## Missing ids fall through to LPC so the game keeps running.

enum Mode { LPC, DCSS }

const TILE: int = 32
const _BASE_DIR: String = "res://assets/dcss_tiles/individual/"

# id → relative path under _BASE_DIR
const FEATURES: Dictionary = {
	"floor":       "dngn/floor.png",
	"wall":        "dngn/wall.png",
	"stairs_up":   "dngn/stairs_up.png",
	"stairs_down": "dngn/stairs_down.png",
}

const MONSTERS: Dictionary = {
	"rat":    "mon/rat.png",
	"bat":    "mon/bat.png",
	"goblin": "mon/goblin.png",
	"kobold": "mon/kobold.png",
	"orc":    "mon/orc.png",
}

const ITEMS: Dictionary = {
	# Potions
	"minor_potion":     "item/potion/minor_potion.png",
	"major_potion":     "item/potion/major_potion.png",
	"mana_potion":      "item/potion/mana_potion.png",
	# Scrolls
	"scroll_teleport":  "item/scroll/scroll_teleport.png",
	"scroll_blink":     "item/scroll/scroll_blink.png",
	"scroll_magic_map": "item/scroll/scroll_magic_map.png",
	"scroll_identify":  "item/scroll/scroll_identify.png",
	# Weapons
	"dagger":          "item/weapon/dagger.png",
	"short_sword":     "item/weapon/short_sword.png",
	"rapier":          "item/weapon/rapier.png",
	"saber":           "item/weapon/saber.png",
	"arming_sword":    "item/weapon/arming_sword.png",
	"longsword":       "item/weapon/longsword.png",
	"katana":          "item/weapon/katana.png",
	"greatsword":      "item/weapon/greatsword.png",
	"scimitar":        "item/weapon/scimitar.png",
	"axe":             "item/weapon/axe.png",
	"axe_medium":      "item/weapon/axe_medium.png",
	"waraxe":          "item/weapon/waraxe.png",
	"club":            "item/weapon/club.png",
	"mace":            "item/weapon/mace.png",
	"flail":           "item/weapon/flail.png",
	"spear":           "item/weapon/spear.png",
	"longspear":       "item/weapon/longspear.png",
	"halberd":         "item/weapon/halberd.png",
	"scythe":          "item/weapon/scythe.png",
	"trident":         "item/weapon/trident.png",
	"short_bow":       "item/weapon/short_bow.png",
	"long_bow":        "item/weapon/long_bow.png",
	"bow":             "item/weapon/bow.png",
	"crossbow":        "item/weapon/crossbow.png",
	"slingshot":       "item/weapon/slingshot.png",
	"boomerang":       "item/weapon/boomerang.png",
	"gnarled_staff":   "item/weapon/gnarled_staff.png",
	# Magic staves
	"fire_staff":      "item/staff/fire_staff.png",
	"ice_staff":       "item/staff/ice_staff.png",
	"lightning_staff": "item/staff/lightning_staff.png",
	"crystal_staff":   "item/staff/crystal_staff.png",
	# Armor
	"leather_chest":   "item/armour/leather_chest.png",
	"chain_chest":     "item/armour/chain_chest.png",
	"plate_chest":     "item/armour/plate_chest.png",
	"leather_legs":    "item/armour/leather_legs.png",
	"chain_legs":      "item/armour/chain_legs.png",
	"plate_legs":      "item/armour/plate_legs.png",
	"leather_boots":   "item/armour/leather_boots.png",
	"plate_boots":     "item/armour/plate_boots.png",
	"leather_helm":    "item/armour/leather_helm.png",
	"plate_helm":      "item/armour/plate_helm.png",
	"leather_gloves":  "item/armour/leather_gloves.png",
	"plate_gloves":    "item/armour/plate_gloves.png",
	# Aliases for armor (legacy ids in floor drops / save data)
	"leather_armor":   "item/armour/leather_chest.png",
	"chain_mail":      "item/armour/chain_chest.png",
	"plate_armor":     "item/armour/plate_chest.png",
}

const PLAYER_RACES: Dictionary = {
	"human":       "player/human.png",
	"hill_orc":    "player/hill_orc.png",
	"minotaur":    "player/minotaur.png",
	"deep_elf":    "player/deep_elf.png",
	"troll":       "player/troll.png",
	"spriggan":    "player/spriggan.png",
	"catfolk":     "player/catfolk.png",
	"draconian":   "player/draconian.png",
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
	var full: String = _BASE_DIR + path_rel
	if _cache.has(full):
		return _cache[full]
	if not ResourceLoader.exists(full):
		return null
	var tex: Texture2D = load(full) as Texture2D
	_cache[full] = tex
	return tex


## Texture for a dungeon feature id (floor / wall / stairs_*).
static func feature(id: String) -> Texture2D:
	return _load(String(FEATURES.get(id, "")))


## Texture for a monster id.
static func monster(id: String) -> Texture2D:
	return _load(String(MONSTERS.get(id, "")))


## Texture for an item id.
static func item(id: String) -> Texture2D:
	return _load(String(ITEMS.get(id, "")))


## Texture for a player race id.
static func player_race(id: String) -> Texture2D:
	return _load(String(PLAYER_RACES.get(id, "")))
