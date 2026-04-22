class_name ConsumableRegistry
extends RefCounted
## Catalog of single-use items (potions and scrolls). Each entry carries
## display metadata and an effect id that Player._apply_consumable_effect
## dispatches on.

const DATA: Dictionary = {
	# --- Potions ---
	"minor_potion": {
		"name": "Potion of Curing",
		"kind": "potion",
		"color": Color(0.95, 0.45, 0.45),
		"effect": "curing",
		"hp_base": 5, "hp_rand": 7,
		"cures": ["poison", "confusion"],
		"desc": "Restores 5-11 HP and cures poison/confusion.",
	},
	"major_potion": {
		"name": "Potion of Heal Wounds",
		"kind": "potion",
		"color": Color(0.95, 0.20, 0.20),
		"effect": "heal",
		"hp_base": 10, "hp_rand": 18,
		"desc": "Restores 10-27 HP (avg 24).",
	},
	"mana_potion": {
		"name": "Mana Potion",
		"kind": "potion",
		"color": Color(0.30, 0.45, 0.95),
		"effect": "restore_mp",
		"amount": 15,
		"desc": "Restores 15 MP.",
	},
	# --- Scrolls ---
	"scroll_teleport": {
		"name": "Scroll of Teleportation",
		"kind": "scroll",
		"color": Color(0.60, 0.40, 0.95),
		"effect": "teleport_random",
		"desc": "Whisks you to a random tile on this floor.",
	},
	"scroll_magic_map": {
		"name": "Scroll of Magic Mapping",
		"kind": "scroll",
		"color": Color(0.40, 0.75, 0.95),
		"effect": "magic_mapping",
		"desc": "Reveals the entire floor's layout (does not show monsters).",
	},
	"scroll_blink": {
		"name": "Scroll of Blink",
		"kind": "scroll",
		"color": Color(0.85, 0.80, 0.30),
		"effect": "blink",
		"desc": "Short-range teleport — up to 4 tiles in any direction.",
	},
	"scroll_identify": {
		"name": "Scroll of Identification",
		"kind": "scroll",
		"color": Color(0.70, 0.90, 0.70),
		"effect": "identify_one",
		"desc": "Reveals the true name and effect of a single unknown potion or scroll of your choice.",
	},
	# --- Temporary stat-boost potions (DCSS: duration 35-74 turns) ---
	"potion_might": {
		"name": "Potion of Might",
		"kind": "potion",
		"color": Color(0.85, 0.30, 0.20),
		"effect": "buff_temp",
		"stat": "STR",
		"amount": 5,
		"dur_base": 35, "dur_rand": 40,
		"desc": "Grants +5 Strength for 35-74 turns.",
	},
	"potion_brilliance": {
		"name": "Potion of Brilliance",
		"kind": "potion",
		"color": Color(0.85, 0.60, 0.95),
		"effect": "buff_temp",
		"stat": "INT",
		"amount": 5,
		"dur_base": 35, "dur_rand": 40,
		"desc": "Grants +5 Intelligence for 35-74 turns.",
	},
	# --- Curse-related scrolls ---
	"scroll_remove_curse": {
		"name": "Scroll of Remove Curse",
		"kind": "scroll",
		"color": Color(0.90, 0.75, 0.40),
		"effect": "remove_curse",
		"desc": "Removes curses from all equipped items.",
	},
	"scroll_enchant_armor": {
		"name": "Scroll of Enchant Armour",
		"kind": "scroll",
		"color": Color(0.45, 0.85, 0.75),
		"effect": "enchant_armor",
		"amount": 1,
		"desc": "Permanently improves the AC of your equipped chest armour by 1.",
	},
	# --- Enchant weapon scroll ---
	"scroll_enchant_weapon": {
		"name": "Scroll of Enchant Weapon",
		"kind": "scroll",
		"color": Color(0.90, 0.85, 0.40),
		"effect": "enchant_weapon",
		"amount": 2,
		"desc": "Permanently adds +2 damage to the currently equipped weapon.",
	},
	# --- More potions ---
	"potion_curing": {
		"name": "Potion of Curing",
		"kind": "potion",
		"color": Color(0.60, 0.95, 0.60),
		"effect": "curing",
		"hp_base": 5, "hp_rand": 7,
		"cures": ["poison", "confusion"],
		"desc": "Restores 5-11 HP and cures poison/confusion.",
	},
	"potion_resistance": {
		"name": "Potion of Resistance",
		"kind": "potion",
		"color": Color(0.50, 0.70, 0.95),
		"effect": "resistance",
		"dur_base": 35, "dur_rand": 40,
		"desc": "Grants rF+rC+rElec for 35-74 turns.",
	},
	"potion_haste": {
		"name": "Potion of Haste",
		"kind": "potion",
		"color": Color(0.95, 0.80, 0.20),
		"effect": "haste",
		"dur_base": 26, "dur_rand": 15,
		"desc": "You move and act faster for 26-40 turns.",
	},
	"potion_magic": {
		"name": "Potion of Magic",
		"kind": "potion",
		"color": Color(0.45, 0.45, 0.95),
		"effect": "restore_mp",
		"amount": 25,
		"desc": "Restores 25 MP.",
	},
	# --- DCSS potions added for parity with potion-type.h ---
	"potion_attraction": {
		"name": "Potion of Attraction",
		"kind": "potion",
		"color": Color(0.95, 0.35, 0.75),
		"effect": "attraction",
		"dur_base": 8, "dur_rand": 4,
		"desc": "Pulls nearby monsters toward you and attracts their attention.",
	},
	"potion_enlightenment": {
		"name": "Potion of Enlightenment",
		"kind": "potion",
		"color": Color(0.95, 0.92, 0.70),
		"effect": "enlightenment",
		"dur_base": 35, "dur_rand": 35,
		"desc": "Grants clarity and see-invisible for a while.",
	},
	"potion_cancellation": {
		"name": "Potion of Cancellation",
		"kind": "potion",
		"color": Color(0.55, 0.50, 0.55),
		"effect": "cancellation",
		"desc": "Dispels your own timed buffs and removes enchantments.",
	},
	"potion_ambrosia": {
		"name": "Potion of Ambrosia",
		"kind": "potion",
		"color": Color(0.85, 0.80, 0.55),
		"effect": "ambrosia",
		"dur_base": 4, "dur_rand": 4,
		"desc": "Confused and slowed for a few turns, but regenerates HP and MP fast.",
	},
	"potion_invisibility": {
		"name": "Potion of Invisibility",
		"kind": "potion",
		"color": Color(0.65, 0.70, 0.85),
		"effect": "invisibility",
		"dur_base": 18, "dur_rand": 10,
		"desc": "Monsters can't see you for 18-27 turns (unless you attack).",
	},
	"potion_experience": {
		"name": "Potion of Experience",
		"kind": "potion",
		"color": Color(0.50, 0.80, 0.65),
		"effect": "experience",
		"desc": "Grants a full character level of experience — rare and precious.",
	},
	"potion_berserk_rage": {
		"name": "Potion of Berserk Rage",
		"kind": "potion",
		"color": Color(0.85, 0.20, 0.20),
		"effect": "berserk",
		"dur_base": 11, "dur_rand": 8,
		"desc": "Fly into a rage: +damage, +HP, +haste. Exhausted when it ends.",
	},
	"potion_mutation": {
		"name": "Potion of Mutation",
		"kind": "potion",
		"color": Color(0.80, 0.40, 0.95),
		"effect": "mutation",
		"desc": "Rewrites your form. Random good and bad mutations.",
	},
	"potion_lignify": {
		"name": "Potion of Lignification",
		"kind": "potion",
		"color": Color(0.45, 0.55, 0.25),
		"effect": "lignify",
		"dur_base": 35, "dur_rand": 15,
		"desc": "Transform into a tree — very tough, cannot move.",
	},
	# --- More scrolls ---
	"scroll_fear": {
		"name": "Scroll of Fear",
		"kind": "scroll",
		"color": Color(0.95, 0.50, 0.20),
		"effect": "fear_monsters",
		"desc": "Sends all visible monsters fleeing in terror for 4 turns.",
	},
	"scroll_immolation": {
		"name": "Scroll of Immolation",
		"kind": "scroll",
		"color": Color(1.0, 0.30, 0.10),
		"effect": "immolation",
		"desc": "Causes all monsters within sight to burst into flames.",
	},
	"scroll_holy_word": {
		"name": "Scroll of Holy Word",
		"kind": "scroll",
		"color": Color(1.0, 0.95, 0.60),
		"effect": "holy_word",
		"desc": "Holy light smites all undead within 10 tiles.",
	},
	"scroll_vulnerability": {
		"name": "Scroll of Vulnerability",
		"kind": "scroll",
		"color": Color(0.95, 0.30, 0.60),
		"effect": "vulnerability",
		"desc": "Strips AC from all visible monsters for 4 turns.",
	},
	"scroll_fog": {
		"name": "Scroll of Fog",
		"kind": "scroll",
		"color": Color(0.75, 0.85, 0.95),
		"effect": "fog",
		"desc": "Teleports all visible monsters to random positions.",
	},
	"scroll_acquirement": {
		"name": "Scroll of Acquirement",
		"kind": "scroll",
		"color": Color(0.95, 0.85, 0.20),
		"effect": "acquirement",
		"desc": "Spawns a useful weapon or armour at your feet.",
	},
	# --- DCSS scrolls added for parity with scroll-type.h ---
	"scroll_noise": {
		"name": "Scroll of Noise",
		"kind": "scroll",
		"color": Color(0.95, 0.55, 0.15),
		"effect": "noise",
		"desc": "Deafening racket — wakes every monster on the floor.",
	},
	"scroll_summoning": {
		"name": "Scroll of Summoning",
		"kind": "scroll",
		"color": Color(0.75, 0.55, 0.95),
		"effect": "summoning",
		"count": 3,
		"desc": "Summons a handful of temporary allies at your side.",
	},
	"scroll_torment": {
		"name": "Scroll of Torment",
		"kind": "scroll",
		"color": Color(0.65, 0.10, 0.20),
		"effect": "torment",
		"desc": "Agony halves every living creature's HP within sight.",
	},
	"scroll_brand_weapon": {
		"name": "Scroll of Brand Weapon",
		"kind": "scroll",
		"color": Color(1.00, 0.70, 0.10),
		"effect": "brand_weapon",
		"desc": "Permanently brands your weapon with a random elemental ego.",
	},
	"scroll_silence": {
		"name": "Scroll of Silence",
		"kind": "scroll",
		"color": Color(0.45, 0.50, 0.65),
		"effect": "silence",
		"dur_base": 12, "dur_rand": 8,
		"desc": "Muffles all casting in a bubble around you.",
	},
	"scroll_amnesia": {
		"name": "Scroll of Amnesia",
		"kind": "scroll",
		"color": Color(0.55, 0.45, 0.85),
		"effect": "amnesia",
		"desc": "Forget one memorised spell, freeing mental space.",
	},
	"scroll_poison": {
		"name": "Scroll of Poison",
		"kind": "scroll",
		"color": Color(0.45, 0.75, 0.30),
		"effect": "poison_scroll",
		"desc": "A toxic cloud settles on every visible enemy.",
	},
	"scroll_butterflies": {
		"name": "Scroll of Butterflies",
		"kind": "scroll",
		"color": Color(0.95, 0.80, 0.95),
		"effect": "butterflies",
		"count": 5,
		"desc": "A flutter of butterflies spawns around you — distractions, mostly.",
	},
	# Simple-mode growth currency — Pixel Dungeon style. Adds +1 to the
	# equipped weapon's enchantment (or armour if no weapon equipped).
	# Stat-light runs rely on stacking these to carry into deeper floors.
	"scroll_upgrade": {
		"name": "Scroll of Upgrade",
		"kind": "scroll",
		"color": Color(0.85, 0.95, 0.45),
		"effect": "upgrade",
		"desc": "Enchants your equipped weapon or armour (+1).",
	},
	# --- DCSS talismans (activate a transmutation form on use) ---
	"talisman_dragon": {
		"name": "Dragon Talisman", "kind": "talisman", "form": "dragon",
		"color": Color(0.30, 0.75, 0.30),
		"desc": "A scale-etched claw. Evoke to take dragon form (teeth, claws, +50% HP).",
	},
	"talisman_statue": {
		"name": "Statue Talisman", "kind": "talisman", "form": "statue",
		"color": Color(0.65, 0.65, 0.70),
		"desc": "A chiselled stone disc. Evoke to turn to stone (+AC, +HP, slow).",
	},
	"talisman_serpent": {
		"name": "Serpent Talisman", "kind": "talisman", "form": "serpent",
		"color": Color(0.30, 0.55, 0.25),
		"desc": "A coiled snake-scale. Evoke to take serpent form (poison res, swim).",
	},
	"talisman_blade": {
		"name": "Blade Talisman", "kind": "talisman", "form": "blade",
		"color": Color(0.85, 0.85, 0.90),
		"desc": "An obsidian shard. Evoke to grow blades in place of hands.",
	},
	"talisman_bat": {
		"name": "Bat Talisman", "kind": "talisman", "form": "bat",
		"color": Color(0.40, 0.25, 0.35),
		"desc": "A leathery wing-fragment. Evoke to become a bat (fast, fragile).",
	},
	"talisman_rime_yak": {
		"name": "Rime Yak Talisman", "kind": "talisman", "form": "rime_yak",
		"color": Color(0.70, 0.85, 1.00),
		"desc": "A frost-rimed horn. Evoke to charge as a rime-yak.",
	},
	"talisman_spider": {
		"name": "Spider Talisman", "kind": "talisman", "form": "spider",
		"color": Color(0.55, 0.25, 0.55),
		"desc": "An eight-legged sigil. Evoke to skitter as a giant spider.",
	},
	"talisman_tree": {
		"name": "Tree Talisman", "kind": "talisman", "form": "tree",
		"color": Color(0.45, 0.65, 0.25),
		"desc": "A seed pod. Evoke to take root — massive HP and AC, no movement.",
	},
	"talisman_quill": {
		"name": "Quill Talisman", "kind": "talisman", "form": "quill",
		"color": Color(0.75, 0.55, 0.30),
		"desc": "Hair-thin spines. Evoke to become barbed (damage returned on hit).",
	},
	"talisman_protean": {
		"name": "Protean Talisman", "kind": "talisman", "form": "jelly",
		"color": Color(0.55, 0.90, 0.55),
		"desc": "A gelatinous bead. Evoke to liquefy into a jelly.",
	},
	# --- DCSS miscellaneous evocables ---
	# Each has limited uses tracked via the "charges" field (set on spawn).
	# Activation logic lives in Player._evoke_misc — damage bursts, summons,
	# utility effects all go through SpellRegistry / the Companion spawner.
	"horn_of_geryon": {
		"name": "Horn of Geryon", "kind": "evocable",
		"effect": "evoke_horn_geryon", "charges_base": 3, "charges_rand": 3,
		"color": Color(0.45, 0.25, 0.55),
		"desc": "A cursed horn. Summons 2-3 hell-beasts on blow.",
	},
	"box_of_beasts": {
		"name": "Box of Beasts", "kind": "evocable",
		"effect": "evoke_box_beasts", "charges_base": 5, "charges_rand": 5,
		"color": Color(0.70, 0.60, 0.25),
		"desc": "A rattling box. Opens to release a random ally beast.",
	},
	"phial_of_floods": {
		"name": "Phial of Floods", "kind": "evocable",
		"effect": "evoke_phial_floods", "charges_base": 4, "charges_rand": 4,
		"color": Color(0.35, 0.55, 0.90),
		"desc": "Summons a torrent of water that drowns enemies in LOS.",
	},
	"sack_of_spiders": {
		"name": "Sack of Spiders", "kind": "evocable",
		"effect": "evoke_sack_spiders", "charges_base": 5, "charges_rand": 5,
		"color": Color(0.45, 0.20, 0.45),
		"desc": "Tumbles out three spider allies.",
	},
	"phantom_mirror": {
		"name": "Phantom Mirror", "kind": "evocable",
		"effect": "evoke_phantom_mirror", "charges_base": 4, "charges_rand": 4,
		"color": Color(0.75, 0.75, 0.85),
		"desc": "Reflects a visible foe's phantom — fights alongside you briefly.",
	},
	"condenser_vane": {
		"name": "Condenser Vane", "kind": "evocable",
		"effect": "evoke_condenser_vane", "charges_base": 3, "charges_rand": 3,
		"color": Color(0.70, 0.90, 1.00),
		"desc": "Wraps your foes in a freezing cloud.",
	},
	"tin_of_tremorstones": {
		"name": "Tin of Tremorstones", "kind": "evocable",
		"effect": "evoke_tremorstones", "charges_base": 4, "charges_rand": 4,
		"color": Color(0.60, 0.45, 0.30),
		"desc": "Scatter-bomb of small earthquakes on a targeted area.",
	},
	"lightning_rod": {
		"name": "Lightning Rod", "kind": "evocable",
		"effect": "evoke_lightning_rod", "charges_base": 3, "charges_rand": 3,
		"color": Color(1.00, 1.00, 0.50),
		"desc": "Fire a beam of lightning — power builds on rapid reuse.",
	},
	"gell_gravitambourine": {
		"name": "Gell's Gravitambourine", "kind": "evocable",
		"effect": "evoke_gravitambourine", "charges_base": 3, "charges_rand": 3,
		"color": Color(0.75, 0.25, 0.85),
		"desc": "A gravity-bending percussion instrument — pulls foes in.",
	},
	# --- Spellbooks (learn_spells effect) ---
	"book_conjurations": {
		"name": "Book of Conjurations",
		"kind": "book",
		"color": Color(0.75, 0.75, 1.0),
		"effect": "learn_spells",
		"spells": ["magic_dart"],
		"desc": "Teaches: Magic Dart.",
	},
	"book_flames": {
		"name": "Book of Flames",
		"kind": "book",
		"color": Color(1.0, 0.40, 0.15),
		"effect": "learn_spells",
		"spells": ["flame_tongue", "fireball"],
		"desc": "Teaches: Flame Tongue, Fireball.",
	},
	"book_frost": {
		"name": "Book of Frost",
		"kind": "book",
		"color": Color(0.45, 0.80, 1.00),
		"effect": "learn_spells",
		"spells": ["freeze"],
		"desc": "Teaches: Freeze.",
	},
	"book_earth": {
		"name": "Book of Geomancy",
		"kind": "book",
		"color": Color(0.60, 0.45, 0.25),
		"effect": "learn_spells",
		"spells": ["stone_arrow"],
		"desc": "Teaches: Stone Arrow.",
	},
	"book_air": {
		"name": "Book of Air",
		"kind": "book",
		"color": Color(0.70, 0.90, 1.00),
		"effect": "learn_spells",
		"spells": ["lightning_bolt"],
		"desc": "Teaches: Lightning Bolt.",
	},
	"book_necromancy": {
		"name": "Necronomicon",
		"kind": "book",
		"color": Color(0.35, 0.10, 0.50),
		"effect": "learn_spells",
		"spells": ["pain"],
		"desc": "Teaches: Pain.",
	},
	"book_hexes": {
		"name": "Book of Maledictions",
		"kind": "book",
		"color": Color(0.80, 0.40, 0.85),
		"effect": "learn_spells",
		"spells": ["slow"],
		"desc": "Teaches: Slow.",
	},
	"book_translocations": {
		"name": "Book of Translocations",
		"kind": "book",
		"color": Color(0.75, 0.55, 1.00),
		"effect": "learn_spells",
		"spells": ["blink"],
		"desc": "Teaches: Blink.",
	},
	"book_minor_magic": {
		"name": "Book of Minor Magic",
		"kind": "book",
		"color": Color(0.85, 0.80, 0.60),
		"effect": "learn_spells",
		"spells": ["magic_dart", "blink"],
		"desc": "Teaches: Magic Dart, Blink.",
	},
}


const _BOOKS_JSON: String = "res://assets/dcss_spells/books.json"
static var _dcss_books: Dictionary = {}
static var _books_loaded: bool = false


## Load DCSS book-data.h (via tools/convert_dcss_books.py) lazily so the
## 80+ hand-curated spellbooks become pickups the same way DCSS treats
## them. Each entry becomes a `learn_spells` consumable.
static func _ensure_books_loaded() -> void:
	if _books_loaded:
		return
	_books_loaded = true
	var f := FileAccess.open(_BOOKS_JSON, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	_dcss_books = parsed


static func has(id: String) -> bool:
	if DATA.has(id):
		return true
	_ensure_books_loaded()
	return _dcss_books.has(id)


static func get_info(id: String) -> Dictionary:
	if DATA.has(id):
		var d: Dictionary = DATA[id].duplicate()
		d["id"] = id
		return d
	_ensure_books_loaded()
	if _dcss_books.has(id):
		var book: Dictionary = _dcss_books[id]
		var colour: Array = book.get("colour", [0.85, 0.80, 0.60])
		return {
			"id": id,
			"name": String(book.get("name", id)),
			"kind": "book",
			"effect": "learn_spells",
			"spells": Array(book.get("spells", [])),
			"color": Color(colour[0], colour[1], colour[2]),
			"desc": "Teaches: %s" % ", ".join(
					Array(book.get("spells", [])).map(
							func(s): return String(s).replace("_", " ").capitalize())),
		}
	return {}


static func all_ids() -> Array:
	_ensure_books_loaded()
	var out: Array = DATA.keys()
	for k in _dcss_books.keys():
		if not out.has(k):
			out.append(k)
	return out


static func description_for(id: String) -> String:
	return String(get_info(id).get("desc", ""))
