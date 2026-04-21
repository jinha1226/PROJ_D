class_name UnrandartRegistry
extends Object
## DCSS-inspired unique named artifacts (unrandarts). Unlike regular
## randarts, unrands have hand-crafted stats and flavor text — seeing
## "the Singing Sword" means the same sword every run.
##
## Implementation: each entry carries the base weapon/armor/ring data
## shape the existing registries expect, so WeaponRegistry /
## ArmorRegistry / RingRegistry / AmuletRegistry fall through to us
## when the id has an "unrand_" prefix. No new equip pathway needed.
##
## Effect coverage uses existing brand / ego mechanics — we're not
## porting special per-unrand routines (Singing Sword's warbling,
## Krishna's arrow storm). A unique is a fixed base + plus + brand/ego
## combo with distinctive flavor naming, not a new code path.

const _UNRANDS: Dictionary = {
	# ---------------- WEAPONS ----------------
	"unrand_singing_sword": {
		"kind": "weapon",
		"base": "longsword",
		"name": "the Singing Sword",
		"dmg": 10, "skill": "long_blade", "delay": 1.3,
		"plus": 7, "brand": "holy_wrath",
		"color": Color(1.00, 0.90, 0.45),
		"min_depth": 8,
		"desc": "A long sword that hums in combat, slicing through unholy foes.",
	},
	"unrand_bow_of_krishna": {
		"kind": "weapon",
		"base": "longbow",
		"name": "the Bow of Krishna",
		"dmg": 16, "skill": "bow", "delay": 1.6,
		"plus": 5, "brand": "flaming",
		"color": Color(1.00, 0.55, 0.25),
		"min_depth": 10,
		"desc": "Arrows loosed from this bow burst into divine flame.",
	},
	"unrand_plutonium_sword": {
		"kind": "weapon",
		"base": "great_sword",
		"name": "the Plutonium Sword",
		"dmg": 15, "skill": "long_blade", "delay": 1.7,
		"plus": 4, "brand": "chaos",
		"color": Color(0.75, 1.00, 0.45),
		"min_depth": 12,
		"desc": "Every swing unleashes a different radiant horror on the target.",
	},
	"unrand_mace_of_variability": {
		"kind": "weapon",
		"base": "mace",
		"name": "the Mace of Variability",
		"dmg": 11, "skill": "mace", "delay": 1.4,
		"plus": 5, "brand": "chaos",
		"color": Color(0.85, 0.55, 0.95),
		"min_depth": 8,
		"desc": "The mace shimmers and distorts, never striking the same way twice.",
	},
	"unrand_wucad_mu_staff": {
		"kind": "weapon",
		"base": "staff",
		"name": "Wucad Mu's Staff",
		"dmg": 8, "skill": "staff", "delay": 1.3,
		"plus": 5, "brand": "pain",
		"color": Color(0.55, 0.30, 0.70),
		"min_depth": 10,
		"desc": "A gnarled staff that drinks life force from every foe it touches.",
	},
	"unrand_skullcrusher": {
		"kind": "weapon",
		"base": "great_mace",
		"name": "Skullcrusher",
		"dmg": 17, "skill": "mace", "delay": 1.9,
		"plus": 6, "brand": "vorpal",
		"color": Color(0.90, 0.85, 0.75),
		"min_depth": 12,
		"desc": "A two-handed mace that caves in helms and skulls alike.",
	},
	"unrand_storm_bow": {
		"kind": "weapon",
		"base": "shortbow",
		"name": "the Storm Bow",
		"dmg": 10, "skill": "bow", "delay": 1.3,
		"plus": 4, "brand": "electrocution",
		"color": Color(0.70, 0.85, 1.00),
		"min_depth": 7,
		"desc": "Each arrow crackles with storm-lightning on release.",
	},

	# ---------------- BODY ARMOUR ----------------
	"unrand_robe_of_augmentation": {
		"kind": "armor",
		"base": "robe",
		"name": "the Robe of Augmentation",
		"slot": "chest",
		"ac": 2, "plus": 3, "ego": "resistance",
		"color": Color(1.00, 0.85, 0.55),
		"min_depth": 8,
		"desc": "A silken robe that subtly bolsters the wearer's elemental wards.",
	},

	# ---------------- CLOAK ----------------
	"unrand_cloak_of_the_thief": {
		"kind": "armor",
		"base": "cloak",
		"name": "the Cloak of the Thief",
		"slot": "cloak",
		"ac": 1, "plus": 3, "ego": "stealth",
		"color": Color(0.35, 0.35, 0.45),
		"min_depth": 6,
		"desc": "A dark cloak that seems to drink the torchlight around it.",
	},

	# ---------------- HELM ----------------
	"unrand_hat_of_the_alchemist": {
		"kind": "armor",
		"base": "hat",
		"name": "the Hat of the Alchemist",
		"slot": "helm",
		"ac": 1, "plus": 2, "ego": "poison_resistance",
		"color": Color(0.60, 0.95, 0.55),
		"min_depth": 6,
		"desc": "A pointed hat soaked in fumes that steel the wearer against venoms.",
	},

	# ---------------- RING ----------------
	"unrand_ring_of_shaolin": {
		"kind": "ring",
		"name": "the Ring of Shaolin",
		"color": Color(0.95, 0.75, 0.35),
		"min_depth": 7,
		"slot": "ring",
		"desc": "A lacquered wooden ring — worn by monks seeking inner balance.",
		# Ring props use the same shape as RandartGenerator output so the
		# equip path folds them in via _recompute_gear_stats.
		"props": {"ev": 5, "dex": 2, "stealth": 2},
	},

	# ---------------- AMULET ----------------
	"unrand_amulet_of_bloodlust": {
		"kind": "amulet",
		"name": "the Amulet of Bloodlust",
		"color": Color(0.85, 0.15, 0.15),
		"min_depth": 8,
		"slot": "amulet",
		"base": "amulet_acrobat",  # reuses the acrobat passive as a proxy
		"desc": "Worn on the neck, it whispers of endless battle.",
		"props": {"str": 2, "slaying": 3},
	},

	# ---------------- WAVE 2 (+10, session 15) ----------------
	# Weapons
	"unrand_finisher": {
		"kind": "weapon",
		"base": "scimitar",
		"name": "Finisher",
		"dmg": 12, "skill": "long_blade", "delay": 1.2,
		"plus": 5, "brand": "speed",
		"color": Color(0.95, 0.95, 0.30),
		"min_depth": 9,
		"desc": "A slender blade whose strikes arrive before the swing.",
	},
	"unrand_sword_of_cerebov": {
		"kind": "weapon",
		"base": "great_sword",
		"name": "the Sword of Cerebov",
		"dmg": 22, "skill": "long_blade", "delay": 1.8,
		"plus": 6, "brand": "flaming",
		"color": Color(1.00, 0.35, 0.10),
		"min_depth": 18,
		"desc": "Cerebov's twisted blade drips with infernal flame.",
	},
	"unrand_obsidian_axe": {
		"kind": "weapon",
		"base": "waraxe",
		"name": "the Obsidian Axe",
		"dmg": 15, "skill": "axe", "delay": 1.5,
		"plus": 6, "brand": "pain",
		"color": Color(0.10, 0.05, 0.20),
		"min_depth": 14,
		"desc": "A black glass axe that feeds on suffering.",
	},
	"unrand_spriggans_rapier": {
		"kind": "weapon",
		"base": "rapier",
		"name": "Spriggan's Rapier",
		"dmg": 7, "skill": "short_blade", "delay": 1.0,
		"plus": 4, "brand": "venom",
		"color": Color(0.70, 1.00, 0.45),
		"min_depth": 7,
		"desc": "A wee envenomed rapier — light enough to flick between heartbeats.",
	},
	"unrand_vampire_tooth": {
		"kind": "weapon",
		"base": "dagger",
		"name": "the Vampire's Tooth",
		"dmg": 5, "skill": "short_blade", "delay": 0.9,
		"plus": 5, "brand": "pain",
		"color": Color(0.85, 0.15, 0.40),
		"min_depth": 8,
		"desc": "A dagger carved from a vampire's fang — drinks vitality on every cut.",
	},

	# Armor
	"unrand_crystal_plate": {
		"kind": "armor",
		"base": "crystal_plate_armour",
		"name": "the Crystal Plate of the Starlit Seer",
		"slot": "chest",
		"ac": 14, "plus": 4, "ego": "archmagi",
		"color": Color(0.75, 0.85, 1.00),
		"min_depth": 16,
		"desc": "Heavy plate shot through with mana-conducting crystals.",
	},
	"unrand_troll_skin_of_the_north": {
		"kind": "armor",
		"base": "troll_leather_armour",
		"name": "the Troll Skin of the North",
		"slot": "chest",
		"ac": 4, "plus": 5, "ego": "cold_resistance",
		"color": Color(0.55, 0.70, 0.95),
		"min_depth": 10,
		"desc": "Bitterly cold troll hide that regenerates the wearer.",
	},

	# Boots / Gloves
	"unrand_boots_of_the_assassin": {
		"kind": "armor",
		"base": "boots",
		"name": "the Boots of the Assassin",
		"slot": "boots",
		"ac": 1, "plus": 3, "ego": "stealth",
		"color": Color(0.20, 0.20, 0.30),
		"min_depth": 7,
		"desc": "Silent as grave-dust. The wearer barely registers on prey.",
	},
	"unrand_gauntlets_of_war": {
		"kind": "armor",
		"base": "gloves",
		"name": "the Gauntlets of War",
		"slot": "gloves",
		"ac": 2, "plus": 3, "ego": "strength",
		"color": Color(0.85, 0.50, 0.20),
		"min_depth": 9,
		"desc": "Iron gauntlets that flood the wearer with raw strength.",
	},

	# Ring
	"unrand_ring_of_the_octopus_king": {
		"kind": "ring",
		"name": "the Ring of the Octopus King",
		"color": Color(0.55, 0.25, 0.85),
		"min_depth": 11,
		"slot": "ring",
		"desc": "One of the legendary rings of the Octopus King — a touch of all magics.",
		"props": {"str": 1, "dex": 1, "int": 1, "ac": 2, "ev": 2, "slaying": 2},
	},

	# ---------------- WAVE 3 (+13, session 15) ----------------
	# --- Weapons ---
	"unrand_giant_club_of_stomping": {
		"kind": "weapon",
		"base": "giant_club",
		"name": "the Giant Club of Stomping",
		"dmg": 25, "skill": "mace", "delay": 2.2,
		"plus": 3, "brand": "heavy",
		"color": Color(0.75, 0.55, 0.30),
		"min_depth": 14,
		"desc": "Ogrish thunder in wood form. Crushes through armour.",
	},
	"unrand_woodcutters_axe": {
		"kind": "weapon",
		"base": "axe_medium",
		"name": "the Woodcutter's Axe",
		"dmg": 13, "skill": "axe", "delay": 1.5,
		"plus": 4, "brand": "vorpal",
		"color": Color(0.55, 0.40, 0.25),
		"min_depth": 8,
		"desc": "A well-worn axe that cleaves wood and bone alike.",
	},
	"unrand_punk": {
		"kind": "weapon",
		"base": "dagger",
		"name": "Punk",
		"dmg": 5, "skill": "short_blade", "delay": 0.8,
		"plus": 3, "brand": "electrocution",
		"color": Color(0.95, 0.85, 0.35),
		"min_depth": 5,
		"desc": "A short, sparking shiv pulled from a street fight.",
	},
	"unrand_snake_sceptre": {
		"kind": "weapon",
		"base": "staff",
		"name": "the Snake Sceptre",
		"dmg": 9, "skill": "staff", "delay": 1.3,
		"plus": 4, "brand": "venom",
		"color": Color(0.40, 0.85, 0.30),
		"min_depth": 11,
		"desc": "A serpent-coiled staff that spits poison with every strike.",
	},
	"unrand_frostbite": {
		"kind": "weapon",
		"base": "flail",
		"name": "Frostbite",
		"dmg": 11, "skill": "mace", "delay": 1.4,
		"plus": 5, "brand": "freezing",
		"color": Color(0.65, 0.85, 1.00),
		"min_depth": 9,
		"desc": "Ice forms on the chain between swings.",
	},
	"unrand_spellbinder": {
		"kind": "weapon",
		"base": "staff",
		"name": "the Spellbinder",
		"dmg": 8, "skill": "staff", "delay": 1.2,
		"plus": 5, "brand": "antimagic",
		"color": Color(0.75, 0.50, 0.90),
		"min_depth": 10,
		"desc": "A staff that drains magic from any caster it touches.",
	},

	# --- Armor / Aux ---
	"unrand_armour_of_zhor": {
		"kind": "armor",
		"base": "ring_mail",
		"name": "the Armour of Zhor",
		"slot": "chest",
		"ac": 7, "plus": 4, "ego": "cold_resistance",
		"color": Color(0.50, 0.80, 1.00),
		"min_depth": 11,
		"desc": "Once worn by an archmage who laughed off blizzards.",
	},
	"unrand_deep_dwarf_crown": {
		"kind": "armor",
		"base": "helmet",
		"name": "the Deep Dwarf Crown",
		"slot": "helm",
		"ac": 2, "plus": 3, "ego": "see_invisible",
		"color": Color(0.85, 0.75, 0.35),
		"min_depth": 9,
		"desc": "A brass circlet that reveals hidden things.",
	},
	"unrand_black_knights_horse": {
		"kind": "armor",
		"base": "boots",
		"name": "the Black Knight's Barding",
		"slot": "boots",
		"ac": 4, "plus": 4, "ego": "rampaging",
		"color": Color(0.15, 0.10, 0.20),
		"min_depth": 12,
		"desc": "Charges at foes on its own momentum.",
	},

	# --- Ring ---
	"unrand_ring_of_flames": {
		"kind": "ring",
		"name": "the Ring of Flames",
		"color": Color(1.00, 0.45, 0.15),
		"min_depth": 9,
		"slot": "ring",
		"desc": "Wreathes the wearer in a mantle of fire — fire-immune, cold-weak.",
		"props": {"fire": 2, "cold": -1, "spellpower": 3, "ev": 2},
	},

	# --- Amulets ---
	"unrand_amulet_of_the_air": {
		"kind": "amulet",
		"name": "the Amulet of the Air",
		"color": Color(0.75, 0.95, 1.00),
		"min_depth": 10,
		"slot": "amulet",
		"base": "amulet_regeneration",
		"desc": "The wearer breathes easy and moves with the wind at their back.",
		"props": {"dex": 2, "ev": 3, "stealth": 2},
	},
	"unrand_amulet_of_the_firebrand": {
		"kind": "amulet",
		"name": "the Firebrand Amulet",
		"color": Color(1.00, 0.55, 0.20),
		"min_depth": 11,
		"slot": "amulet",
		"base": "amulet_magic_mastery",
		"desc": "Blazing power flows into the wearer's spells — at a cost to caution.",
		"props": {"fire": 1, "spellpower": 4, "slaying": 2},
	},
	"unrand_quadruple_strike": {
		"kind": "weapon",
		"base": "morningstar",
		"name": "the Four-Pronged Morningstar",
		"dmg": 14, "skill": "mace", "delay": 1.6,
		"plus": 5, "brand": "vorpal",
		"color": Color(0.85, 0.45, 0.20),
		"min_depth": 10,
		"desc": "Four spiked heads strike in perfect unison.",
	},
}


static func has(id: String) -> bool:
	return _UNRANDS.has(id)


static func get_info(id: String) -> Dictionary:
	var info: Dictionary = _UNRANDS.get(id, {})
	return info.duplicate() if not info.is_empty() else {}


static func all_ids() -> Array:
	return _UNRANDS.keys()


## Rolled floor-drop id for the current depth, or "" if none eligible.
## Each unrand has a min_depth gate; the selection is uniform among
## eligible entries so higher-floor unrands don't starve when depth
## ticks up.
static func roll_for_depth(depth: int) -> String:
	var pool: Array = []
	for id in _UNRANDS.keys():
		if int(_UNRANDS[id].get("min_depth", 0)) <= depth:
			pool.append(id)
	if pool.is_empty():
		return ""
	return String(pool[randi() % pool.size()])


## Build the FloorItem-ready item dict for an unrand id. Shape matches
## what WeaponRegistry / ArmorRegistry / RingRegistry consumers expect
## so the existing pickup + equip + info-tooltip paths don't care that
## this is an artefact instead of a rolled base item.
static func make_item(id: String) -> Dictionary:
	var info: Dictionary = get_info(id)
	if info.is_empty():
		return {}
	var kind: String = String(info.get("kind", ""))
	var out: Dictionary = {
		"id": id,
		"name": String(info.get("name", id)),
		"kind": kind,
		"color": info.get("color", Color.WHITE),
		"unrand": true,
	}
	match kind:
		"weapon":
			out["plus"] = int(info.get("plus", 0))
			# The _weapon_brand_<id> meta the melee code reads is hung
			# on the player when the weapon equips; FloorItem carries
			# the intended brand in `brand` so Player.equip_weapon can
			# apply it.
			if info.has("brand"):
				out["brand"] = String(info["brand"])
		"armor":
			out["slot"] = String(info.get("slot", "chest"))
			out["ac"] = int(info.get("ac", 0))
			out["plus"] = int(info.get("plus", 0))
			if info.has("ego"):
				out["ego"] = String(info["ego"])
		"ring":
			out["slot"] = "ring"
			out["props"] = info.get("props", {})
			out["desc"] = String(info.get("desc", ""))
		"amulet":
			out["slot"] = "amulet"
			out["props"] = info.get("props", {})
			if info.has("base"):
				out["base"] = String(info["base"])
			out["desc"] = String(info.get("desc", ""))
	return out
