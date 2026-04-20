extends Node
class_name TileRenderer
## Central lookup for which art asset renders a given in-game id.
## Modes:
##   LPC   — composed LPC sprites
##   DCSS  — Dungeon Crawl Stone Soup individual tile PNGs (default)
##   ASCII — classic roguelike glyphs (DCSS console palette)
##
## All DCSS tiles live under res://assets/dcss_tiles/individual/ — the full
## crawl rltiles tree (~6055 PNGs across dngn/, mon/, item/, player/) is
## bundled, so adding new monsters/items/branches is just a matter of
## extending the mapping dictionaries below.

enum Mode { LPC, DCSS, ASCII }

const TILE: int = 32
const _ASCII_FONT_PATH: String = "res://assets/fonts/DejaVuSansMono.ttf"

# DCSS console palette (roughly ANSI 16).
const _C_BLACK       := Color(0.05, 0.05, 0.08)
const _C_DARKGREY    := Color(0.40, 0.40, 0.42)
const _C_LIGHTGREY   := Color(0.72, 0.72, 0.72)
const _C_WHITE       := Color(0.98, 0.98, 1.00)
const _C_RED         := Color(0.78, 0.10, 0.10)
const _C_LIGHTRED    := Color(1.00, 0.38, 0.38)
const _C_GREEN       := Color(0.10, 0.70, 0.20)
const _C_LIGHTGREEN  := Color(0.35, 1.00, 0.35)
const _C_BROWN       := Color(0.70, 0.55, 0.25)
const _C_YELLOW      := Color(1.00, 0.95, 0.30)
const _C_BLUE        := Color(0.15, 0.45, 1.00)
const _C_LIGHTBLUE   := Color(0.40, 0.75, 1.00)
const _C_MAGENTA     := Color(0.72, 0.10, 0.72)
const _C_LIGHTMAGENTA:= Color(1.00, 0.45, 1.00)
const _C_CYAN        := Color(0.15, 0.70, 0.75)
const _C_LIGHTCYAN   := Color(0.35, 0.95, 1.00)
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
	"potion_might":          "item/potion/i-might.png",
	"potion_agility":        "item/potion/i-gain-dexterity.png",
	"potion_brilliance":     "item/potion/i-brilliance.png",
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
	"morningstar":      "item/weapon/morningstar1.png",
	"eveningstar":      "item/weapon/eveningstar1.png",
	"dire_flail":       "item/weapon/dire_flail1.png",
	# Whips
	"whip":             "item/weapon/bullwhip.png",
	# Axes (DCSS ids)
	"hand_axe":         "item/weapon/hand_axe1.png",
	"war_axe":          "item/weapon/war_axe1.png",
	"broad_axe":        "item/weapon/broad_axe1.png",
	"battleaxe":        "item/weapon/battle_axe1.png",
	"executioners_axe": "item/weapon/executioner_axe1.png",
	# Long/great blades (DCSS ids)
	"long_sword":       "item/weapon/long_sword1.png",
	"falchion":         "item/weapon/falchion1.png",
	"great_sword":      "item/weapon/long_sword3.png",
	"double_sword":     "item/weapon/double_sword.png",
	"triple_sword":     "item/weapon/triple_sword.png",
	"quick_blade":      "item/weapon/dagger3.png",
	"demon_blade":      "item/weapon/demon_blade.png",
	"lajatang":         "item/weapon/lajatang1.png",
	# Polearms
	"spear":            "item/weapon/spear1.png",
	"longspear":        "item/weapon/spear1.png",
	"halberd":          "item/weapon/halberd1.png",
	"glaive":           "item/weapon/glaive1.png",
	"bardiche":         "item/weapon/bardiche1.png",
	"scythe":           "item/weapon/scythe1.png",
	"trident":          "item/weapon/trident1.png",
	# Ranged
	"short_bow":        "item/weapon/ranged/shortbow1.png",
	"long_bow":         "item/weapon/ranged/longbow1.png",
	"bow":              "item/weapon/ranged/longbow1.png",
	"shortbow":         "item/weapon/ranged/shortbow1.png",
	"longbow":          "item/weapon/ranged/longbow1.png",
	"orcbow":           "item/weapon/ranged/orcbow1.png",
	"arbalest":         "item/weapon/ranged/arbalest1.png",
	"crossbow":         "item/weapon/ranged/arbalest1.png",
	"slingshot":        "item/weapon/ranged/sling1.png",
	"boomerang":        "item/weapon/ranged/boomerang1.png",
	# Staves
	"gnarled_staff":    "item/weapon/quarterstaff.png",
	"quarterstaff":     "item/weapon/quarterstaff.png",
	"fire_staff":       "item/staff/i-staff_fire.png",
	"ice_staff":        "item/staff/i-staff_cold.png",
	"lightning_staff":  "item/staff/i-staff_air.png",
	"crystal_staff":    "item/staff/i-staff_energy.png",
	# Armour — DCSS canonical ids
	"robe":                   "item/armour/robe1.png",
	"leather_armour":         "item/armour/leather_armour1.png",
	"ring_mail":              "item/armour/ring_mail1.png",
	"scale_mail":             "item/armour/scale_mail1.png",
	"chain_mail":             "item/armour/chain_mail1.png",
	"plate_armour":           "item/armour/plate1.png",
	"crystal_plate_armour":   "item/armour/crystal_plate.png",
	"troll_leather_armour":   "item/armour/troll_leather_armour.png",
	# Legacy / game-specific slot-split ids
	"leather_chest":    "item/armour/leather_armour1.png",
	"chain_chest":      "item/armour/chain_mail1.png",
	"plate_chest":      "item/armour/plate1.png",
	"leather_legs":     "item/armour/leather_armour2.png",
	"chain_legs":       "item/armour/chain_mail2.png",
	"plate_legs":       "item/armour/plate2.png",
	"leather_boots":    "item/armour/boots1.png",
	"plate_boots":      "item/armour/boots2.png",
	"leather_helm":     "item/armour/headgear/helmet1.png",
	"plate_helm":       "item/armour/headgear/helmet2.png",
	"leather_gloves":   "item/armour/glove1.png",
	"plate_gloves":     "item/armour/glove2.png",
	# Aliases
	"leather_armor":    "item/armour/leather_armour1.png",
	"plate_armor":      "item/armour/plate1.png",
	# Cloaks
	"cloak":             "item/armour/cloak1_leather.png",
	"cloak_protection":  "item/armour/cloak2.png",
	"cloak_stealth":     "item/armour/cloak3.png",
	"cloak_resistance":  "item/armour/cloak4.png",
	# Shields
	"buckler":          "item/armour/shields/buckler1.png",
	"kite_shield":      "item/armour/shields/kite_shield1.png",
	"tower_shield":     "item/armour/shields/tower_shield1.png",
	# Headgear (DCSS ids)
	"helmet":           "item/armour/headgear/helmet1.png",
	"hat":              "item/armour/headgear/hat1.png",
	# Gloves / boots (DCSS ids)
	"gloves":           "item/armour/glove1.png",
	"boots":            "item/armour/boots1.png",
	# Rings — each one gets a distinctive gemstone tile
	"ring_str":           "item/ring/coral.png",
	"ring_dex":           "item/ring/emerald.png",
	"ring_int":           "item/ring/agate.png",
	"ring_protection":    "item/ring/diamond.png",
	"ring_evasion":       "item/ring/bronze.png",
	"ring_slaying":       "item/ring/copper.png",
	"ring_magical_power": "item/ring/gold.png",
	"ring_wizardry":      "item/ring/brass.png",
	"ring_regeneration":  "item/ring/clay.png",
	"ring_stealth":       "item/ring/glass.png",
	"ring_fire":          "item/ring/copper.png",
	"ring_ice":           "item/ring/diamond.png",
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
	# --- DCSS Warrior backgrounds ---
	"fighter":            "player/base/human_m.png",
	"gladiator":          "mon/humanoids/humans/imperial_myrmidon.png",
	"monk":               "player/base/human2_m.png",
	"hunter":             "player/base/elf_m.png",
	"brigand":            "player/base/halfling_m.png",
	# --- DCSS Adventurer backgrounds ---
	"artificer":          "mon/humanoids/humans/arcanist.png",
	"shapeshifter":       "player/base/deep_elf_m.png",
	"wanderer":           "player/base/human_m.png",
	"delver":             "player/base/halfling_m.png",
	# --- DCSS Zealot backgrounds ---
	"berserker":          "player/base/orc_m.png",
	"chaos_knight":       "mon/humanoids/humans/hell_knight.png",
	"cinder_acolyte":     "mon/humanoids/humans/death_knight.png",
	# --- DCSS Warrior-mage backgrounds ---
	"warper":             "player/base/deep_elf_m.png",
	"hexslinger":         "player/base/deep_elf_m.png",
	"enchanter":          "player/base/deep_elf_m.png",
	"reaver":             "player/base/human_m.png",
	# --- DCSS Mage backgrounds ---
	"hedge_wizard":       "mon/humanoids/humans/arcanist.png",
	"conjurer":           "player/base/deep_elf_m.png",
	"summoner":           "mon/humanoids/elves/deep_elf_demonologist.png",
	"necromancer":        "mon/humanoids/humans/necromancer.png",
	"fire_elementalist":  "mon/humanoids/elves/deep_elf_elementalist1.png",
	"ice_elementalist":   "mon/humanoids/elves/deep_elf_elementalist2.png",
	"earth_elementalist": "mon/humanoids/elves/deep_elf_elementalist3.png",
	"air_elementalist":   "mon/humanoids/elves/deep_elf_elementalist4.png",
	"alchemist":          "player/base/deep_elf_m.png",
	"forgewright":        "mon/humanoids/humans/arcanist.png",
	# --- Legacy sprite aliases (old removed jobs, in case save files refer) ---
	"knight":             "mon/humanoids/humans/hell_knight.png",
	# --- Race sprites ---
	"human":              "player/base/human_m.png",
	"minotaur":           "player/base/minotaur_m.png",
	"troll":              "player/base/troll_m.png",
	"spriggan":           "player/base/spriggan_m.png",
	"draconian":          "player/base/draconian.png",
	"deep_elf":           "player/base/deep_elf_m.png",
	# DCSS 0.34 race sprites
	"demigod":            "player/base/demigod_m.png",
	"demonspawn":         "player/base/demonspawn_red_m.png",
	"djinni":             "player/base/djinni_blue_m.png",
	"formicid":           "player/base/formicid.png",
	"gargoyle":           "player/base/gargoyle_m.png",
	"gnoll":              "player/base/gnoll_m.png",
	"kobold":             "player/base/kobold_m.png",
	"merfolk":            "player/base/merfolk_m.png",
	"mummy":              "player/base/mummy_m.png",
	"naga":               "player/base/naga_green_m.png",
	"octopode":           "player/base/octopode1.png",
	"oni":                "player/base/oni_red_m.png",
	"tengu":              "player/base/tengu_winged_m.png",
	"vine_stalker":       "player/base/vine_stalker_green_m.png",
	"barachi":            "player/base/frog_m.png",
	"coglin":             "player/base/coglin.png",
}

## Doll overlay layers stacked on top of the race body sprite. Keyed by
## slot → item_id. Missing entries render no overlay for that slot.
##
## Draw order (caller decides): legs → chest → boots → gloves → helm → weapon.
## This matches DCSS's paperdoll stacking for the simplified slot set.
const PLAYER_DOLL: Dictionary = {
	"weapon": {
		"dagger":          "player/hand1/dagger.png",
		"short_sword":     "player/hand1/short_sword.png",
		"rapier":          "player/hand1/rapier.png",
		"saber":           "player/hand1/scimitar.png",
		"arming_sword":    "player/hand1/long_sword_slant.png",
		"longsword":       "player/hand1/long_sword_slant2.png",
		"katana":          "player/hand1/katana_slant.png",
		"greatsword":      "player/hand1/great_sword_slant.png",
		"scimitar":        "player/hand1/scimitar.png",
		"axe":             "player/hand1/axe_short.png",
		"axe_medium":      "player/hand1/axe_blood.png",
		"waraxe":          "player/hand1/axe_double.png",
		"club":            "player/hand1/club.png",
		"mace":            "player/hand1/mace.png",
		"flail":           "player/hand1/flail_ball.png",
		"morningstar":     "player/hand1/morningstar.png",
		"eveningstar":     "player/hand1/eveningstar.png",
		"dire_flail":      "player/hand1/flail_ball2.png",
		"whip":            "player/hand1/whip.png",
		"hand_axe":        "player/hand1/hand_axe.png",
		"war_axe":         "player/hand1/war_axe.png",
		"broad_axe":       "player/hand1/broad_axe.png",
		"battleaxe":       "player/hand1/battleaxe.png",
		"executioners_axe":"player/hand1/axe_executioner.png",
		"long_sword":      "player/hand1/long_sword_slant.png",
		"falchion":        "player/hand1/falchion.png",
		"great_sword":     "player/hand1/great_sword_slant.png",
		"double_sword":    "player/hand1/double_sword.png",
		"triple_sword":    "player/hand1/triple_sword.png",
		"quick_blade":     "player/hand1/dagger2.png",
		"demon_blade":     "player/hand1/demonblade.png",
		"lajatang":        "player/hand1/lajatang1.png",
		"spear":           "player/hand1/spear.png",
		"longspear":       "player/hand1/spear.png",
		"halberd":         "player/hand1/halberd.png",
		"glaive":          "player/hand1/glaive.png",
		"bardiche":        "player/hand1/halberd.png",
		"scythe":          "player/hand1/scythe.png",
		"trident":         "player/hand1/trident.png",
		"short_bow":       "player/hand1/bow.png",
		"long_bow":        "player/hand1/great_bow.png",
		"bow":             "player/hand1/bow.png",
		"shortbow":        "player/hand1/shortbow.png",
		"longbow":         "player/hand1/great_bow.png",
		"orcbow":          "player/hand1/orcbow1.png",
		"arbalest":        "player/hand1/arbalest.png",
		"crossbow":        "player/hand1/arbalest.png",
		"slingshot":       "player/hand1/sling.png",
		"quarterstaff":    "player/hand1/quarterstaff.png",
		"gnarled_staff":   "player/hand1/quarterstaff.png",
		"fire_staff":      "player/hand1/great_staff.png",
		"ice_staff":       "player/hand1/quarterstaff2.png",
		"lightning_staff": "player/hand1/staff-artefact1.png",
		"crystal_staff":   "player/hand1/great_staff.png",
	},
	"chest": {
		"robe":                  "player/body/robe_blue.png",
		"leather_armour":        "player/body/leather_armour.png",
		"ring_mail":             "player/body/scalemail.png",
		"scale_mail":            "player/body/scalemail2.png",
		"chain_mail":            "player/body/chainmail.png",
		"plate_armour":          "player/body/plate.png",
		"crystal_plate_armour":  "player/body/crystal_plate.png",
		"troll_leather_armour":  "player/body/troll_leather.png",
		# Legacy slot-split ids
		"leather_chest": "player/body/leather_armour.png",
		"chain_chest":   "player/body/chainmail.png",
		"plate_chest":   "player/body/plate.png",
		"leather_armor": "player/body/leather_armour.png",
		"plate_armor":   "player/body/plate.png",
	},
	"legs": {
		"leather_legs": "player/legs/leg_armour00.png",
		"chain_legs":   "player/legs/leg_armour02.png",
		"plate_legs":   "player/legs/leg_armour04.png",
	},
	"helm": {
		"helmet":       "player/head/helm_plume.png",
		"hat":          "player/head/cap_black1.png",
		"leather_helm": "player/head/cap_black1.png",
		"plate_helm":   "player/head/helm_plume.png",
	},
	"cloak": {
		"cloak":            "player/cloak/brown.png",
		"cloak_protection": "player/cloak/blue.png",
		"cloak_stealth":    "player/cloak/black.png",
		"cloak_resistance": "player/cloak/cyan.png",
	},
	"gloves": {
		"gloves":         "player/gloves/glove_brown.png",
		"leather_gloves": "player/gloves/glove_brown.png",
		"plate_gloves":   "player/gloves/gauntlet_blue.png",
	},
	"boots": {
		"boots":         "player/boots/middle_brown.png",
		"leather_boots": "player/boots/middle_brown.png",
		"plate_boots":   "player/boots/middle_gray.png",
	},
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


## Doll overlay texture for a slot/item. Returns null if no mapping exists
## so callers can cleanly skip that layer.
static func doll_layer(slot: String, item_id: String) -> Texture2D:
	if item_id == "":
		return null
	var slot_map: Dictionary = PLAYER_DOLL.get(slot, {})
	return _load(String(slot_map.get(item_id, "")))


## Compose a single texture from a race/job base + optional doll overlays,
## ready to drop into a TextureRect (e.g. JobSelect preview cards). Slots
## are stacked in DCSS paper-doll order: legs → chest → boots → gloves →
## helm → weapon. `armor_by_slot` is a Dictionary of slot_id → item_id.
## Returns the base texture unchanged if no overlays apply; null if the
## base itself is missing.
static func compose_doll(base_id: String, weapon_id: String = "",
		armor_by_slot: Dictionary = {}) -> Texture2D:
	var base: Texture2D = player_race(base_id)
	if base == null:
		return null
	var base_img: Image = base.get_image()
	if base_img == null:
		return base
	# Work on a copy so we never mutate the cached base.
	var out_img: Image = Image.new()
	out_img.copy_from(base_img)
	if out_img.get_format() != Image.FORMAT_RGBA8:
		out_img.convert(Image.FORMAT_RGBA8)
	var w: int = out_img.get_width()
	var h: int = out_img.get_height()
	var rect: Rect2i = Rect2i(0, 0, w, h)

	var stack: Array = [
		["legs", String(armor_by_slot.get("legs", ""))],
		["chest", String(armor_by_slot.get("chest", ""))],
		["boots", String(armor_by_slot.get("boots", ""))],
		["cloak", String(armor_by_slot.get("cloak", ""))],
		["gloves", String(armor_by_slot.get("gloves", ""))],
		["helm", String(armor_by_slot.get("helm", ""))],
		["weapon", weapon_id],
	]
	for entry in stack:
		var slot: String = entry[0]
		var iid: String = entry[1]
		if iid == "":
			continue
		var layer: Texture2D = doll_layer(slot, iid)
		if layer == null:
			continue
		var limg: Image = layer.get_image()
		if limg == null:
			continue
		if limg.get_format() != Image.FORMAT_RGBA8:
			var tmp: Image = Image.new()
			tmp.copy_from(limg)
			tmp.convert(Image.FORMAT_RGBA8)
			limg = tmp
		# Crop/resize so overlay fits the base exactly.
		if limg.get_width() != w or limg.get_height() != h:
			limg = limg.get_region(Rect2i(0, 0,
					min(limg.get_width(), w),
					min(limg.get_height(), h)))
		out_img.blend_rect(limg, rect, Vector2i.ZERO)

	return ImageTexture.create_from_image(out_img)


## All known branch ids; useful for menus / debug.
static func known_branches() -> Array:
	return BRANCH_TILESETS.keys()


# ---- ASCII mode ----------------------------------------------------------

static func is_ascii() -> bool:
	return mode() == Mode.ASCII


static var _ascii_font_cache: Font = null


## Monospace font used for ASCII rendering. Cached after first load.
static func ascii_font() -> Font:
	if _ascii_font_cache != null:
		return _ascii_font_cache
	if ResourceLoader.exists(_ASCII_FONT_PATH):
		_ascii_font_cache = load(_ASCII_FONT_PATH) as Font
	if _ascii_font_cache == null:
		_ascii_font_cache = ThemeDB.fallback_font
	return _ascii_font_cache


## Glyph + colour for a map tile type enum value. Falls back to "?" white.
## DungeonGenerator.TileType is passed in; we keep the mapping keyed by the
## int value so this file has no direct dependency on DungeonGenerator.
const _FEATURE_GLYPHS: Dictionary = {
	# enum order: WALL=0, FLOOR=1, DOOR_OPEN=2, DOOR_CLOSED=3, STAIRS_DOWN=4,
	# STAIRS_UP=5, WATER=6, LAVA=7, TRAP=8, BRANCH_ENTRANCE=9, SHOP=10,
	# ALTAR=11, TREE=12
	0:  ["#", _C_LIGHTGREY],
	1:  [".", _C_DARKGREY],
	2:  ["'", _C_BROWN],
	3:  ["+", _C_BROWN],
	4:  [">", _C_YELLOW],
	5:  ["<", _C_YELLOW],
	6:  ["~", _C_LIGHTBLUE],
	7:  ["~", _C_RED],
	8:  ["^", _C_LIGHTMAGENTA],
	9:  [">", _C_LIGHTCYAN],
	10: ["$", _C_YELLOW],
	11: ["_", _C_WHITE],
	12: ["T", _C_GREEN],
}


static func ascii_feature(tile_enum: int) -> Array:
	return _FEATURE_GLYPHS.get(tile_enum, ["?", _C_WHITE])


const _MONSTER_GLYPHS: Dictionary = {
	"rat":            ["r", _C_LIGHTGREY],
	"bat":            ["b", _C_LIGHTGREY],
	"goblin":         ["g", _C_GREEN],
	"hobgoblin":      ["g", _C_BROWN],
	"kobold":         ["k", _C_BROWN],
	"gnoll":          ["g", _C_LIGHTRED],
	"orc":            ["o", _C_RED],
	"orc_warrior":    ["o", _C_LIGHTRED],
	"orc_priest":     ["o", _C_LIGHTGREY],
	"orc_wizard":     ["o", _C_LIGHTMAGENTA],
	"orc_knight":     ["o", _C_CYAN],
	"adder":          ["s", _C_GREEN],
	"ball_python":    ["s", _C_YELLOW],
	"wolf":           ["h", _C_BROWN],
	"jackal":         ["h", _C_YELLOW],
	"hell_hound":     ["h", _C_LIGHTRED],
	"alligator":      ["l", _C_GREEN],
	"boggart":        ["i", _C_LIGHTMAGENTA],
	"dryad":          ["n", _C_GREEN],
	"ghoul":          ["z", _C_LIGHTGREY],
	"bog_body":       ["z", _C_DARKGREY],
	"skeleton":       ["z", _C_WHITE],
	"lich":           ["L", _C_WHITE],
	"ogre":           ["O", _C_RED],
	"fire_giant":     ["G", _C_LIGHTRED],
	"swamp_dragon":   ["D", _C_GREEN],
	"fire_dragon":    ["D", _C_LIGHTRED],
	"fire_sprite":    ["i", _C_LIGHTRED],
}


static func ascii_monster(monster_id: String) -> Array:
	return _MONSTER_GLYPHS.get(monster_id, ["M", _C_LIGHTGREY])


## Item glyphs by kind first, fall back to specific id overrides.
const _ITEM_KIND_GLYPHS: Dictionary = {
	"potion": ["!", _C_LIGHTCYAN],
	"scroll": ["?", _C_WHITE],
	"weapon": ["(", _C_LIGHTCYAN],
	"armor":  ["[", _C_BROWN],
	"book":   ["+", _C_LIGHTMAGENTA],
	"staff":  ["\\", _C_BROWN],
	"ring":   ["=", _C_YELLOW],
	"amulet": ["\"", _C_YELLOW],
	"wand":   ["/", _C_LIGHTGREEN],
	"gold":   ["$", _C_YELLOW],
}

# Per-id colour overrides for specific items (mostly ranged weapons / staves).
const _ITEM_ID_GLYPHS: Dictionary = {
	"short_bow":       [")", _C_BROWN],
	"long_bow":        [")", _C_BROWN],
	"bow":             [")", _C_BROWN],
	"crossbow":        [")", _C_LIGHTGREY],
	"slingshot":       [")", _C_LIGHTGREY],
	"boomerang":       [")", _C_LIGHTGREEN],
	"throwing_axe":    [")", _C_LIGHTRED],
	"fire_staff":      ["\\", _C_LIGHTRED],
	"ice_staff":       ["\\", _C_LIGHTBLUE],
	"lightning_staff": ["\\", _C_YELLOW],
	"crystal_staff":   ["\\", _C_LIGHTMAGENTA],
	"gnarled_staff":   ["\\", _C_BROWN],
}


static func ascii_item(item_id: String, kind: String = "") -> Array:
	if _ITEM_ID_GLYPHS.has(item_id):
		return _ITEM_ID_GLYPHS[item_id]
	if kind != "" and _ITEM_KIND_GLYPHS.has(kind):
		return _ITEM_KIND_GLYPHS[kind]
	# Infer kind from id if caller didn't supply one.
	if WeaponRegistry != null and item_id != "" and WeaponRegistry.is_weapon(item_id):
		return _ITEM_KIND_GLYPHS["weapon"]
	if ArmorRegistry != null and item_id != "" and ArmorRegistry.is_armor(item_id):
		return _ITEM_KIND_GLYPHS["armor"]
	return ["*", _C_WHITE]


## Player and companion glyphs.
const PLAYER_GLYPH: Array = ["@", _C_WHITE]
const COMPANION_GLYPH: Array = ["@", _C_LIGHTCYAN]


## Draw a single ASCII glyph centred on `world_px` in `tile_px_size`. Pass
## `visible=true` for full colour, `false` for dimmed (explored but out of
## FOV). Safe to call in any _draw() path.
static func draw_ascii_glyph(ci: CanvasItem, world_px: Vector2,
		tile_px_size: int, glyph: String, color: Color,
		visible: bool = true) -> void:
	var f: Font = ascii_font()
	if f == null:
		return
	var eff: Color = color if visible else color.darkened(0.55)
	var font_size: int = int(tile_px_size * 0.85)
	var ascent: float = f.get_ascent(font_size)
	var gw: float = f.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size).x
	var px: float = world_px.x - gw * 0.5
	var py: float = world_px.y + ascent * 0.5 - tile_px_size * 0.08
	ci.draw_string(f, Vector2(px, py), glyph,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, eff)
