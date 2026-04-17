extends Node
class_name TileRenderer

enum Mode { LPC, DCSS }

const TILE: int = 64
const _BASE_DIR: String = "res://assets/tiles/"

const FEATURES: Dictionary = {
	"floor":       "dungeon/floor_stone1.png",
	"wall":        "dungeon/wall_brick_side.png",
	"stairs_up":   "dungeon/stairs_up.png",
	"stairs_down": "dungeon/stairs_down.png",
	"door_open":   "dungeon/door_open.png",
	"door_closed": "dungeon/door_closed.png",
	"water":       "dungeon/floor_blue_stone1.png",
	"lava":        "dungeon/floor_red_stone1.png",
}

const BRANCH_TILESETS: Dictionary = {
	"main": {
		"floor": "dungeon/floor_stone1.png",
		"wall":  "dungeon/wall_brick_side.png",
	},
	"forest": {
		"floor": "dungeon/floor_grass1.png",
		"wall":  "dungeon/wall_dirt_side.png",
	},
	"mine": {
		"floor": "dungeon/floor_stonebrick1.png",
		"wall":  "dungeon/wall_rough_side.png",
	},
	"crypt": {
		"floor": "dungeon/floor_bone1.png",
		"wall":  "dungeon/wall_catacombs_side.png",
	},
	"volcano": {
		"floor": "dungeon/floor_red_stone1.png",
		"wall":  "dungeon/wall_igneous_side.png",
	},
	"swamp": {
		"floor": "dungeon/floor_green_grass1.png",
		"wall":  "dungeon/wall_large_side.png",
	},
	"crystal": {
		"floor": "dungeon/floor_blue_stone1.png",
		"wall":  "dungeon/wall_large_side.png",
	},
	"sandstone": {
		"floor": "dungeon/floor_dirt1.png",
		"wall":  "dungeon/wall_dirt_side.png",
	},
}

const MONSTERS: Dictionary = {
	"rat":              "monsters/rat.png",
	"bat":              "monsters/bat.png",
	"goblin":           "monsters/goblin.png",
	"hobgoblin":        "monsters/hobgoblin.png",
	"kobold":           "monsters/kobold.png",
	"orc":              "monsters/orc.png",
	"orc_warrior":      "monsters/orc_warrior.png",
	"orc_priest":       "monsters/orc_wizard.png",
	"orc_wizard":       "monsters/orc_wizard.png",
	"adder":            "monsters/salamander.png",
	"wolf":             "monsters/wolf.png",
	"jackal":           "monsters/wolf.png",
	"ball_python":      "monsters/worm.png",
	"gnoll":            "monsters/kobold_big.png",
	"boggart":          "monsters/hag.png",
	"ghoul":            "monsters/ghoul.png",
	"bog_body":         "monsters/zombie.png",
	"alligator":        "monsters/salamander.png",
	"hell_hound":       "monsters/wolf.png",
	"lich":             "monsters/lich.png",
	"fire_giant":       "monsters/ogre.png",
	"ogre":             "monsters/ogre.png",
	"orc_knight":       "monsters/orc_knight.png",
	"dryad":            "monsters/dryad.png",
	"swamp_dragon":     "monsters/drake.png",
	"fire_dragon":      "monsters/dragon.png",
	"skeleton":         "monsters/skeleton.png",
	"fire_sprite":      "monsters/imp.png",
}

const ITEMS: Dictionary = {
	"minor_potion":     "items/potion_red.png",
	"major_potion":     "items/potion_blue.png",
	"mana_potion":      "items/potion_purple.png",
	"scroll_teleport":  "items/scroll_blue.png",
	"scroll_blink":     "items/scroll_purple.png",
	"scroll_magic_map": "items/scroll_green.png",
	"scroll_identify":  "items/scroll_plain.png",
	"dagger":           "items/dagger.png",
	"short_sword":      "items/short_sword.png",
	"rapier":           "items/short_sword2.png",
	"saber":            "items/short_sword2.png",
	"arming_sword":     "items/longsword.png",
	"longsword":        "items/longsword.png",
	"katana":           "items/katana.png",
	"greatsword":       "items/greatsword.png",
	"scimitar":         "items/longsword.png",
	"axe":              "items/axe.png",
	"axe_medium":       "items/battleaxe.png",
	"waraxe":           "items/waraxe.png",
	"club":             "items/mace.png",
	"mace":             "items/mace.png",
	"flail":            "items/flail.png",
	"spear":            "items/spear.png",
	"longspear":        "items/spear.png",
	"halberd":          "items/halberd.png",
	"scythe":           "items/scythe.png",
	"trident":          "items/trident.png",
	"short_bow":        "items/short_bow.png",
	"long_bow":         "items/long_bow.png",
	"bow":              "items/long_bow.png",
	"crossbow":         "items/crossbow.png",
	"slingshot":        "items/sling.png",
	"boomerang":        "items/sling.png",
	"gnarled_staff":    "items/staff.png",
	"fire_staff":       "items/fire_staff.png",
	"ice_staff":        "items/ice_staff.png",
	"lightning_staff":  "items/lightning_staff.png",
	"crystal_staff":    "items/crystal_staff.png",
	"robe":             "items/robe.png",
	"leather_chest":    "items/leather_armor.png",
	"chain_chest":      "items/chain_mail.png",
	"plate_chest":      "items/plate_armor.png",
	"leather_legs":     "items/leather_armor.png",
	"chain_legs":       "items/chain_mail.png",
	"plate_legs":       "items/plate_armor.png",
	"leather_boots":    "items/leather_boots.png",
	"plate_boots":      "items/plate_boots.png",
	"leather_helm":     "items/leather_helm.png",
	"plate_helm":       "items/plate_helm.png",
	"leather_gloves":   "items/leather_gloves.png",
	"plate_gloves":     "items/plate_gloves.png",
	"leather_armor":    "items/leather_armor.png",
	"chain_mail":       "items/chain_mail.png",
	"plate_armor":      "items/plate_armor.png",
	"book_conjurations":"items/book_blue.png",
	"book_flames":      "items/book_red.png",
	"book_frost":       "items/book_blue.png",
	"book_earth":       "items/book_brown.png",
	"book_air":         "items/book_green.png",
	"book_necromancy":  "items/book_black.png",
	"book_hexes":       "items/book_purple.png",
	"book_translocations":"items/book_purple.png",
	"book_minor_magic": "items/book_brown.png",
}

const PLAYER_RACES: Dictionary = {
	"human":      "players/fighter.png",
	"hill_orc":   "players/barbarian.png",
	"minotaur":   "players/barbarian.png",
	"deep_elf":   "players/mage.png",
	"troll":      "players/barbarian.png",
	"spriggan":   "players/rogue.png",
	"catfolk":    "players/rogue.png",
	"draconian":  "players/knight.png",
}

const PLAYER_DOLL: Dictionary = {}

const _POTION_BASE_TILES: Dictionary = {
	"red": "items/potion_red.png",
	"blue": "items/potion_blue.png",
	"green": "items/potion_green.png",
	"yellow": "items/potion_yellow.png",
	"purple": "items/potion_purple.png",
	"orange": "items/potion_orange.png",
	"cyan": "items/potion_cyan.png",
	"white": "items/potion_white.png",
	"black": "items/potion_black.png",
	"pink": "items/potion_pink.png",
}

const _SCROLL_BASE_TILES: Dictionary = {
	"plain": "items/scroll_plain.png",
	"blue": "items/scroll_blue.png",
	"red": "items/scroll_red.png",
	"green": "items/scroll_green.png",
	"purple": "items/scroll_purple.png",
	"gold": "items/scroll_gold.png",
}

static var _cache: Dictionary = {}


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


static func doll_layer(slot: String, item_id: String) -> Texture2D:
	return null


static func known_branches() -> Array:
	return BRANCH_TILESETS.keys()
