class_name ArmorRegistry
extends RefCounted
## Static armour catalog. Two-layer lookup:
##   1. DATA const — hand-tuned entries with slot assignments (our ids).
##   2. DCSS JSON — 22 armours from item-prop.cc (loaded lazily).
## Custom entries win when ids overlap.

const _DCSS_JSON := "res://assets/dcss_items/armours.json"

# Slot mapping for DCSS armour ids.
const _SLOT_MAP: Dictionary = {
	"robe": "chest", "animal_skin": "chest",
	"leather_armour": "chest", "ring_mail": "chest", "scale_mail": "chest",
	"chain_mail": "chest", "plate_armour": "chest", "crystal_plate_armour": "chest",
	"troll_leather_armour": "chest",
	"cloak": "cloak", "scarf": "cloak",
	"gloves": "gloves",
	"helmet": "helm", "cap": "helm", "hat": "helm",
	"boots": "boots",
	"buckler": "shield", "kite_shield": "shield", "tower_shield": "shield",
	"centaur_barding": "boots", "barding": "boots",
	"orb": "offhand",
}

# Hand-tuned entries — DCSS itself supplies AC / EV values via
# `assets/dcss_items/armours.json` (see _ensure_loaded). Only a handful
# of magical-cloak variants and spelling-aliases live here; everything
# else falls through to DCSS's item-prop.cc data.
const DATA: Dictionary = {
	# Cloak ego variants (our mobile layer — no direct DCSS equivalent).
	"cloak_protection":  {"name": "Cloak of Protection","slot": "cloak", "ac": 2, "ev_penalty": 0, "ev_bonus": 1, "color": Color(0.55, 0.45, 0.85)},
	"cloak_stealth":     {"name": "Cloak of Stealth",   "slot": "cloak", "ac": 1, "ev_penalty": 0, "ev_bonus": 1, "stealth": 2, "color": Color(0.12, 0.14, 0.22)},
	"cloak_resistance":  {"name": "Cloak of Resistance","slot": "cloak", "ac": 1, "ev_penalty": 0, "ev_bonus": 1, "dmg_reduce": 1, "color": Color(0.7, 0.25, 0.25)},
	# Legacy spelling aliases that some save/LPC paths still use.
	"leather_armor": {"name": "Leather Armour", "slot": "chest", "ac": 3, "ev_penalty": -40, "color": Color(0.55, 0.35, 0.20)},
	"plate_armor":   {"name": "Plate Armour",   "slot": "chest", "ac": 10, "ev_penalty": -180, "color": Color(0.85, 0.85, 0.90)},
}

static var _dcss: Dictionary = {}
static var _merged: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_DCSS_JSON, FileAccess.READ)
	if f == null:
		_merged = DATA.duplicate()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Array):
		_merged = DATA.duplicate()
		return
	for entry in parsed:
		var aid: String = String(entry.get("id", ""))
		if aid == "":
			continue
		var ev_pen: int = int(entry.get("ev_penalty", 0))
		_dcss[aid] = {
			"name":       String(entry.get("name", "")),
			"ac":         int(entry.get("ac", 0)),
			"ev_penalty": ev_pen,
			"slot":       _SLOT_MAP.get(aid, "chest"),
		}
	_merged = _dcss.duplicate()
	for k in DATA:
		_merged[k] = DATA[k]


static func _lookup(id: String) -> Dictionary:
	_ensure_loaded()
	return _merged.get(id, {})


static func is_armor(id: String) -> bool:
	_ensure_loaded()
	return _merged.has(id)


static func get_info(id: String) -> Dictionary:
	var d: Dictionary = _lookup(id)
	if d.is_empty():
		return {}
	var out: Dictionary = d.duplicate()
	out["id"] = id
	return out


static func slot_for(id: String) -> String:
	return String(_lookup(id).get("slot", ""))


static func ac_for(id: String) -> int:
	return int(_lookup(id).get("ac", 0))


static func ev_penalty_for(id: String) -> int:
	return int(_lookup(id).get("ev_penalty", 0))


static func display_name_for(id: String) -> String:
	return String(_lookup(id).get("name", id.replace("_", " ").capitalize()))


## DCSS SPARM_* armour egos. Each entry records:
##   label       — prefix for display names ("of fire resistance" etc.)
##   slots       — which slots accept the ego ("chest", "cloak", "all"…)
##   stat_bonus  — Dict{str,dex,int,ac,ev,stealth,spellpower,mp_regen,mr}
##   resists     — Dict{fire, cold, poison, neg, elec} resist levels (+1/+2)
##   flag        — engine flag the player reads (see_invis, invisible, …)
## Most SPARM_* entries without unique per-turn logic live here. Egos
## that need special per-hit or per-turn handling (RAMPAGING, HARM,
## SPIRIT_SHIELD, REFLECTION) are tagged via `flag` and handled in the
## relevant system (take_damage / try_move / etc.).
const EGOS: Dictionary = {
	# --- Resistance egos ---
	"fire_resistance":    {"label": "of fire resistance",    "slots": ["chest","cloak","shield"], "resists": {"fire": 1}},
	"cold_resistance":    {"label": "of cold resistance",    "slots": ["chest","cloak","shield"], "resists": {"cold": 1}},
	"poison_resistance":  {"label": "of poison resistance",  "slots": ["chest","cloak","shield"], "resists": {"poison": 1}},
	"positive_energy":    {"label": "of positive energy",    "slots": ["chest","cloak","shield"], "resists": {"neg": 1}},
	"resistance":         {"label": "of resistance",         "slots": ["chest","cloak","shield"], "resists": {"fire": 1, "cold": 1}},
	"willpower":          {"label": "of willpower",          "slots": ["chest","cloak","shield","helm"], "stat_bonus": {"mr": 30}},
	# --- Stat egos ---
	"strength":           {"label": "of strength",           "slots": ["gloves","boots","chest"], "stat_bonus": {"str": 3}},
	"dexterity":          {"label": "of dexterity",          "slots": ["gloves","boots","chest"], "stat_bonus": {"dex": 3}},
	"intelligence":       {"label": "of intelligence",       "slots": ["helm","chest"], "stat_bonus": {"int": 3}},
	# --- AC / defence ---
	"protection":         {"label": "of protection",         "slots": ["chest","cloak","helm","gloves","boots","shield"], "stat_bonus": {"ac": 3}},
	"ponderousness":      {"label": "of ponderousness",      "slots": ["chest"], "stat_bonus": {"ac": 2}, "flag": "slow"},  # DCSS bad ego
	# --- Senses / utility ---
	"see_invisible":      {"label": "of see invisible",      "slots": ["helm","cloak"], "flag": "see_invis"},
	"stealth":            {"label": "of stealth",            "slots": ["boots","cloak","chest"], "stat_bonus": {"stealth": 2}},
	"shadows":            {"label": "of shadows",            "slots": ["cloak"], "stat_bonus": {"stealth": 3}, "flag": "hate_light"},
	"light":              {"label": "of light",              "slots": ["chest","cloak"], "flag": "shed_light"},
	# --- Magic ---
	"archmagi":           {"label": "of the archmagi",       "slots": ["chest"], "stat_bonus": {"spellpower": 3}},
	"energy":             {"label": "of energy",             "slots": ["chest","cloak"], "stat_bonus": {"mp_regen": 1}},
	"infusion":           {"label": "of infusion",           "slots": ["gloves"], "flag": "mp_for_damage"},
	"guile":              {"label": "of guile",              "slots": ["gloves"], "flag": "foes_fail_spells"},
	# --- Combat riders ---
	"harm":               {"label": "of harm",               "slots": ["cloak","chest"], "flag": "harm"},  # +30% dmg both ways
	"rampaging":          {"label": "of rampaging",          "slots": ["boots"], "flag": "rampage"},
	"repulsion":          {"label": "of repulsion",          "slots": ["cloak"], "flag": "missile_dodge"},
	"reflection":         {"label": "of reflection",         "slots": ["shield"], "flag": "reflect"},
	"spirit_shield":      {"label": "of the spirit shield",  "slots": ["helm"], "flag": "spirit_shield"},
	"archery":            {"label": "of archery",            "slots": ["gloves","cloak"], "stat_bonus": {"ranged_dmg": 4}},
	"hurling":            {"label": "of hurling",            "slots": ["cloak","gloves"], "stat_bonus": {"throw_dmg": 3}},
	# --- Misc ---
	"flying":             {"label": "of flying",             "slots": ["boots"], "flag": "flying"},
	"jumping":            {"label": "of jumping",            "slots": ["boots"], "flag": "jump"},
	"mayhem":             {"label": "of mayhem",             "slots": ["cloak"], "flag": "mayhem"},
	"resonance":          {"label": "of resonance",          "slots": ["chest"], "resists": {"acid": 1}, "stat_bonus": {"spellpower": 2}},
	"command":            {"label": "of command",            "slots": ["helm"], "flag": "command"},
}


## Roll a random ego compatible with the given slot. Returns "" if no
## ego should be applied. Call-site `p_chance` is the base drop rate
## (DCSS rolls ego ~15% on a fresh armour); we default to 0.12 so
## early-floor items aren't a constant festival of magic.
static func roll_ego(slot: String, p_chance: float = 0.12) -> String:
	if randf() > p_chance:
		return ""
	var pool: Array = []
	for eid in EGOS.keys():
		var slots: Array = EGOS[eid].get("slots", [])
		if slots.has(slot) or slots.has("all"):
			pool.append(eid)
	if pool.is_empty():
		return ""
	return String(pool[randi() % pool.size()])


static func ego_info(ego_id: String) -> Dictionary:
	if EGOS.has(ego_id):
		return EGOS[ego_id].duplicate()
	return {}


static func ego_label(ego_id: String) -> String:
	return String(EGOS.get(ego_id, {}).get("label", ""))
