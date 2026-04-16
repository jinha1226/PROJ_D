class_name ConsumableRegistry
extends RefCounted
## Catalog of single-use items (potions and scrolls). Each entry carries
## display metadata and an effect id that Player._apply_consumable_effect
## dispatches on.

const DATA: Dictionary = {
	# --- Potions ---
	"minor_potion": {
		"name": "Minor Healing Potion",
		"kind": "potion",
		"color": Color(0.95, 0.45, 0.45),
		"effect": "heal",
		"amount": 20,
		"desc": "Restores 20 HP.",
	},
	"major_potion": {
		"name": "Healing Potion",
		"kind": "potion",
		"color": Color(0.95, 0.20, 0.20),
		"effect": "heal",
		"amount": 50,
		"desc": "Restores 50 HP.",
	},
	"mana_potion": {
		"name": "Mana Potion",
		"kind": "potion",
		"color": Color(0.30, 0.45, 0.95),
		"effect": "restore_mp",
		"amount": 20,
		"desc": "Restores 20 MP.",
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
		"effect": "identify_all",
		"desc": "Reveals the true name and effect of every unknown potion and scroll in your inventory.",
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
