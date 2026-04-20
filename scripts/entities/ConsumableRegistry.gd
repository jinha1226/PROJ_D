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
	"potion_agility": {
		"name": "Potion of Agility",
		"kind": "potion",
		"color": Color(0.40, 0.80, 0.40),
		"effect": "buff_temp",
		"stat": "DEX",
		"amount": 5,
		"dur_base": 35, "dur_rand": 40,
		"desc": "Grants +5 Dexterity for 35-74 turns.",
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
	"potion_poison": {
		"name": "Potion of Poison",
		"kind": "potion",
		"color": Color(0.35, 0.50, 0.25),
		"effect": "harm",
		"amount": 10,
		"desc": "Bitter, foul — inflicts 10 damage when drunk.",
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
	"potion_degeneration": {
		"name": "Potion of Degeneration",
		"kind": "potion",
		"color": Color(0.30, 0.25, 0.20),
		"effect": "degenerate",
		"amount": 8,
		"desc": "Permanently reduces max HP by 8. Very bad.",
	},
	"potion_restore": {
		"name": "Potion of Restore Abilities",
		"kind": "potion",
		"color": Color(0.70, 0.50, 0.95),
		"effect": "restore_all",
		"desc": "Fully restores HP and MP.",
	},
	"potion_magic": {
		"name": "Potion of Magic",
		"kind": "potion",
		"color": Color(0.45, 0.45, 0.95),
		"effect": "restore_mp",
		"amount": 25,
		"desc": "Restores 25 MP.",
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


static func has(id: String) -> bool:
	return DATA.has(id)


static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate()
	d["id"] = id
	return d


static func all_ids() -> Array:
	return DATA.keys()


static func description_for(id: String) -> String:
	return String(DATA.get(id, {}).get("desc", ""))
