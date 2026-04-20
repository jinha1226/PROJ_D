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
	"water":       "dngn/water/deep_water.png",
	"lava":        "dngn/floor/lava00.png",
	"tree":        "dngn/trees/tree1.png",
}

## Per-branch overrides. DungeonMap picks the right floor/wall/etc. by
## passing the current branch id; missing keys fall back to FEATURES.
const BRANCH_TILESETS: Dictionary = {
	"main": {
		"floor": "dngn/floor/grey_dirt0.png",
		"wall":  "dngn/wall/stone2_gray0.png",
	},
	"forest": {
		"floor": "dngn/floor/grass/grass0.png",
		"wall":  "dngn/trees/tree1.png",
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
		"wall":  "dngn/wall/hell01.png",
	},
	"swamp": {
		"floor": "dngn/floor/swamp0.png",
		"wall":  "dngn/wall/marble_wall1.png",
	},
	"crystal": {
		"floor": "dngn/floor/crystal_floor0.png",
		"wall":  "dngn/wall/crystal_wall_blue.png",
	},
	"sandstone": {
		"floor": "dngn/floor/sandstone_floor0.png",
		"wall":  "dngn/wall/sandstone_wall0.png",
	},
}

const MONSTERS: Dictionary = {
	"rat":              "mon/animals/rat.png",
	"bat":              "mon/animals/bat.png",
	"goblin":           "mon/humanoids/goblin.png",
	"hobgoblin":        "mon/humanoids/hobgoblin.png",
	"kobold":           "mon/humanoids/kobold.png",
	"orc":              "mon/humanoids/orcs/orc.png",
	"orc_warrior":      "mon/humanoids/orcs/orc_warrior.png",
	"orc_priest":       "mon/humanoids/orcs/orc_priest.png",
	"orc_wizard":       "mon/humanoids/orcs/orc_wizard.png",
	"adder":            "mon/animals/adder.png",
	"wolf":             "mon/animals/wolf.png",
	"jackal":           "mon/animals/jackal.png",
	"ball_python":      "mon/animals/ball_python.png",
	"gnoll":            "mon/humanoids/gnoll.png",
	"boggart":          "mon/humanoids/boggart.png",
	"ghoul":            "mon/undead/ghoul.png",
	"bog_body":         "mon/undead/bog_body.png",
	"alligator":        "mon/animals/alligator.png",
	"hell_hound":       "mon/animals/hell_hound.png",
	"lich":             "mon/undead/lich.png",
	"fire_giant":       "mon/humanoids/giants/fire_giant.png",
	"ogre":             "mon/humanoids/ogre.png",
	"orc_knight":       "mon/humanoids/orcs/orc_knight.png",
	"dryad":            "mon/humanoids/dryad.png",
	"swamp_dragon":     "mon/dragons/swamp_dragon.png",
	"fire_dragon":      "mon/dragons/fire_dragon.png",
	"skeleton":         "mon/undead/skeletal_warrior.png",
	"fire_sprite":      "mon/animals/fire_bat.png",
}

const ITEMS: Dictionary = {
	# --- Potions (effect-themed tiles for identified items) ---
	"minor_potion":          "item/potion/i-curing.png",
	"major_potion":          "item/potion/i-heal-wounds.png",
	"mana_potion":           "item/potion/i-magic.png",
	"potion_curing":         "item/potion/i-curing.png",
	"potion_resistance":     "item/potion/i-resistance.png",
	"potion_haste":          "item/potion/i-haste.png",
	"potion_degeneration":   "item/potion/i-degeneration.png",
	"potion_restore":        "item/potion/i-restore-abilities.png",
	"potion_magic":          "item/potion/i-magic.png",
	# --- Scrolls ---
	"scroll_teleport":       "item/scroll/i-teleportation.png",
	"scroll_blink":          "item/scroll/i-blinking.png",
	"scroll_magic_map":      "item/scroll/i-magic_mapping.png",
	"scroll_identify":       "item/scroll/i-identify.png",
	"scroll_remove_curse":   "item/scroll/i-remove_curse.png",
	"scroll_enchant_armor":  "item/scroll/i-enchant_armour.png",
	"scroll_enchant_weapon": "item/scroll/i-enchant-weapon.png",
	"scroll_fear":           "item/scroll/i-fear.png",
	"scroll_immolation":     "item/scroll/i-immolation.png",
	"scroll_holy_word":      "item/scroll/i-holy_word.png",
	"scroll_vulnerability":  "item/scroll/i-vulnerability.png",
	"scroll_fog":            "item/scroll/i-fog.png",
	"scroll_acquirement":    "item/scroll/i-acquirement.png",
	# --- Weapons: short blades ---
	"dagger":           "item/weapon/dagger.png",
	"short_sword":      "item/weapon/short_sword1.png",
	"rapier":           "item/weapon/short_sword2.png",
	"saber":            "item/weapon/short_sword3.png",
	# Long blades
	"arming_sword":     "item/weapon/long_sword1.png",
	"longsword":        "item/weapon/long_sword2.png",
	"katana":           "item/weapon/long_sword3.png",
	"greatsword":       "item/weapon/long_sword2.png",
	"scimitar":         "item/weapon/scimitar1.png",
	# Axes
	"axe":              "item/weapon/hand_axe1.png",
	"axe_medium":       "item/weapon/battle_axe1.png",
	"waraxe":           "item/weapon/war_axe1.png",
	"throwing_axe":     "item/weapon/hand_axe2.png",
	# Maces / clubs
	"club":             "item/weapon/club.png",
	"mace":             "item/weapon/mace1.png",
	"flail":            "item/weapon/flail1.png",
	# Polearms
	"spear":            "item/weapon/spear1.png",
	"longspear":        "item/weapon/spear1.png",
	"halberd":          "item/weapon/halberd1.png",
	"scythe":           "item/weapon/scythe1.png",
	"trident":          "item/weapon/trident1.png",
	# Ranged
	"short_bow":        "item/weapon/ranged/shortbow1.png",
	"long_bow":         "item/weapon/ranged/longbow1.png",
	"bow":              "item/weapon/ranged/longbow1.png",
	"crossbow":         "item/weapon/ranged/arbalest1.png",
	"slingshot":        "item/weapon/ranged/sling1.png",
	"boomerang":        "item/weapon/ranged/boomerang1.png",
	# Staves
	"gnarled_staff":    "item/weapon/quarterstaff.png",
	"fire_staff":       "item/staff/i-staff_fire.png",
	"ice_staff":        "item/staff/i-staff_cold.png",
	"lightning_staff":  "item/staff/i-staff_air.png",
	"crystal_staff":    "item/staff/i-staff_energy.png",
	# Armor — chest
	"robe":             "item/armour/robe1.png",
	"leather_chest":    "item/armour/leather_armour1.png",
	"chain_chest":      "item/armour/chain_mail1.png",
	"plate_chest":      "item/armour/plate1.png",
	# Legs (DCSS doesn't split — reuse second variants)
	"leather_legs":     "item/armour/leather_armour2.png",
	"chain_legs":       "item/armour/chain_mail2.png",
	"plate_legs":       "item/armour/plate2.png",
	# Boots
	"leather_boots":    "item/armour/boots1.png",
	"plate_boots":      "item/armour/boots2.png",
	# Helms (under headgear/)
	"leather_helm":     "item/armour/headgear/helmet1.png",
	"plate_helm":       "item/armour/headgear/helmet2.png",
	# Gloves
	"leather_gloves":   "item/armour/glove1.png",
	"plate_gloves":     "item/armour/glove2.png",
	# Aliases for legacy ids
	"leather_armor":    "item/armour/leather_armour1.png",
	"chain_mail":       "item/armour/chain_mail1.png",
	"plate_armor":      "item/armour/plate1.png",
	# Spellbooks — cover colour picked per school for flavour
	"book_conjurations":   "item/book/dark_blue.png",
	"book_flames":         "item/book/red.png",
	"book_frost":          "item/book/light_blue.png",
	"book_earth":          "item/book/dark_brown.png",
	"book_air":            "item/book/cyan.png",
	"book_necromancy":     "item/book/book_of_the_dead.png",
	"book_hexes":          "item/book/magenta.png",
	"book_translocations": "item/book/purple.png",
	"book_minor_magic":    "item/book/parchment.png",
}

const PLAYER_RACES: Dictionary = {
	# --- Warrior jobs ---
	"fighter":            "player/base/human_m.png",
	"gladiator":          "mon/humanoids/humans/imperial_myrmidon.png",
	"berserker":          "player/base/orc_m.png",
	"barbarian":          "player/base/orc_m.png",
	"monk":               "player/base/human2_m.png",
	# --- Ranged jobs ---
	"ranger":             "player/base/elf_m.png",
	"hunter":             "player/base/elf_m.png",
	"arcane_marksman":    "player/base/deep_elf_m.png",
	# --- Rogue jobs ---
	"rogue":              "player/base/halfling_m.png",
	"assassin":           "player/base/halfling_m.png",
	"brigand":            "player/base/halfling_m.png",
	# --- Hybrid ---
	"skald":              "player/base/human_m.png",
	# --- Divine ---
	"cleric":             "mon/humanoids/humans/human.png",
	# --- Mage jobs ---
	"mage":               "player/base/deep_elf_m.png",
	"warlock":            "mon/humanoids/humans/death_knight.png",
	"wizard":             "mon/humanoids/humans/arcanist.png",
	"conjurer":           "player/base/deep_elf_m.png",
	"necromancer":        "mon/humanoids/humans/necromancer.png",
	"fire_elementalist":  "mon/humanoids/elves/deep_elf_elementalist1.png",
	"ice_elementalist":   "mon/humanoids/elves/deep_elf_elementalist2.png",
	"earth_elementalist": "mon/humanoids/elves/deep_elf_elementalist3.png",
	"air_elementalist":   "mon/humanoids/elves/deep_elf_elementalist4.png",
	"enchanter":          "player/base/deep_elf_m.png",
	"summoner":           "mon/humanoids/elves/deep_elf_demonologist.png",
	"transmuter":         "player/base/deep_elf_m.png",
	"warper":             "player/base/deep_elf_m.png",
	# --- Legacy ---
	"knight":             "mon/humanoids/humans/hell_knight.png",
	# --- Race sprites ---
	"human":              "player/base/human_m.png",
	"hill_orc":           "player/base/orc_m.png",
	"minotaur":           "player/base/minotaur_m.png",
	"troll":              "player/base/troll_m.png",
	"spriggan":           "player/base/spriggan_m.png",
	"catfolk":            "player/felids/cat1.png",
	"draconian":          "player/base/draconian.png",
	"deep_elf":           "player/base/deep_elf_m.png",
}

## Doll overlay layers (weapon / chest / legs / boots / helm / gloves).
## Currently unused by renderers — kept as an infra hook for future per-slot
## compositing on the DCSS player sprite.
const PLAYER_DOLL: Dictionary = {}

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


## Doll overlay texture for a slot/item — currently always null (PLAYER_DOLL
## is empty). Callers should handle null by skipping that layer.
static func doll_layer(slot: String, item_id: String) -> Texture2D:
	if item_id == "":
		return null
	var slot_map: Dictionary = PLAYER_DOLL.get(slot, {})
	return _load(String(slot_map.get(item_id, "")))


## All known branch ids; useful for menus / debug.
static func known_branches() -> Array:
	return BRANCH_TILESETS.keys()
