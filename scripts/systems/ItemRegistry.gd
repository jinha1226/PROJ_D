extends Node

const _SHORT_SWORD: Resource = preload("res://resources/items/short_sword.tres")
const _DAGGER: Resource = preload("res://resources/items/dagger.tres")
const _LONG_SWORD: Resource = preload("res://resources/items/long_sword.tres")
const _LEATHER_ARMOR: Resource = preload("res://resources/items/leather_armor.tres")
const _ROBE: Resource = preload("res://resources/items/robe.tres")
const _CHAIN_MAIL: Resource = preload("res://resources/items/chain_mail.tres")
const _RING_MAIL: Resource = preload("res://resources/items/ring_mail.tres")
const _SCALE_MAIL: Resource = preload("res://resources/items/scale_mail.tres")
const _PLATE_MAIL: Resource = preload("res://resources/items/plate_mail.tres")
const _TROLL_LEATHER: Resource = preload("res://resources/items/troll_leather.tres")
const _POTION_HEALING: Resource = preload("res://resources/items/potion_healing.tres")
const _POTION_MIGHT: Resource = preload("res://resources/items/potion_might.tres")
const _POTION_CURE_POISON: Resource = preload("res://resources/items/potion_cure_poison.tres")
const _POTION_MAGIC: Resource = preload("res://resources/items/potion_magic.tres")
const _SCROLL_BLINKING: Resource = preload("res://resources/items/scroll_blinking.tres")
const _SCROLL_MAGIC_MAPPING: Resource = preload("res://resources/items/scroll_magic_mapping.tres")
const _SCROLL_TELEPORT: Resource = preload("res://resources/items/scroll_teleport.tres")
const _SCROLL_ENCHANT_WEAPON: Resource = preload("res://resources/items/scroll_enchant_weapon.tres")
const _SCROLL_ENCHANT_ARMOR: Resource = preload("res://resources/items/scroll_enchant_armor.tres")
const _GOLD_PILE: Resource = preload("res://resources/items/gold_pile.tres")
const _BATTLE_AXE: Resource = preload("res://resources/items/battle_axe.tres")
const _FLAMING_SWORD: Resource = preload("res://resources/items/flaming_sword.tres")
const _FROST_DAGGER: Resource = preload("res://resources/items/frost_dagger.tres")
const _VENOM_DAGGER: Resource = preload("res://resources/items/venom_dagger.tres")
const _POTION_BERSERK: Resource = preload("res://resources/items/potion_berserk.tres")
const _SCROLL_IDENTIFY: Resource = preload("res://resources/items/scroll_identify.tres")
const _SCROLL_SHROUDING: Resource = preload("res://resources/items/scroll_shrouding.tres")
const _BOOK_FIRE: Resource = preload("res://resources/items/book_fire.tres")
const _BOOK_COLD: Resource = preload("res://resources/items/book_cold.tres")
const _BOOK_AIR: Resource = preload("res://resources/items/book_air.tres")
const _BOOK_EARTH: Resource = preload("res://resources/items/book_earth.tres")
const _BOOK_NECROMANCY: Resource = preload("res://resources/items/book_necromancy.tres")
const _BOOK_HEXES: Resource = preload("res://resources/items/book_hexes.tres")
const _BOOK_CONJURATION: Resource = preload("res://resources/items/book_conjuration.tres")
const _SPEAR: Resource = preload("res://resources/items/spear.tres")
const _RING_STR: Resource = preload("res://resources/items/ring_str.tres")
const _RING_INT: Resource = preload("res://resources/items/ring_int.tres")
const _RING_DEX: Resource = preload("res://resources/items/ring_dex.tres")
const _RING_PROTECTION: Resource = preload("res://resources/items/ring_protection.tres")
const _RING_SLAYING: Resource = preload("res://resources/items/ring_slaying.tres")
const _RING_WIZARDRY: Resource = preload("res://resources/items/ring_wizardry.tres")
const _AMULET_LIFE: Resource = preload("res://resources/items/amulet_life.tres")
const _AMULET_MAGIC: Resource = preload("res://resources/items/amulet_magic.tres")
const _AMULET_STR: Resource = preload("res://resources/items/amulet_str.tres")
const _STILETTO: Resource = preload("res://resources/items/stiletto.tres")
const _DIRK: Resource = preload("res://resources/items/dirk.tres")
const _ASSASSIN_BLADE: Resource = preload("res://resources/items/assassin_blade.tres")
const _QUICK_BLADE: Resource = preload("res://resources/items/quick_blade.tres")
const _ARMING_SWORD: Resource = preload("res://resources/items/arming_sword.tres")
const _BASTARD_SWORD: Resource = preload("res://resources/items/bastard_sword.tres")
const _GREAT_BLADE: Resource = preload("res://resources/items/great_blade.tres")
const _BUCKLER: Resource = preload("res://resources/items/buckler.tres")
const _ROUND_SHIELD: Resource = preload("res://resources/items/round_shield.tres")
const _KITE_SHIELD: Resource = preload("res://resources/items/kite_shield.tres")
const _TOWER_SHIELD: Resource = preload("res://resources/items/tower_shield.tres")
const _LEATHER_CAP: Resource = preload("res://resources/items/leather_cap.tres")
const _IRON_HELM: Resource = preload("res://resources/items/iron_helm.tres")
const _GREAT_HELM: Resource = preload("res://resources/items/great_helm.tres")
const _LEATHER_GLOVES: Resource = preload("res://resources/items/leather_gloves.tres")
const _IRON_GAUNTLETS: Resource = preload("res://resources/items/iron_gauntlets.tres")
const _LEATHER_BOOTS: Resource = preload("res://resources/items/leather_boots.tres")
const _IRON_GREAVES: Resource = preload("res://resources/items/iron_greaves.tres")
const _SHORTBOW: Resource = preload("res://resources/items/shortbow.tres")
const _LONGBOW: Resource = preload("res://resources/items/longbow.tres")
const _CROSSBOW: Resource = preload("res://resources/items/crossbow.tres")
const _BANDAGE: Resource = preload("res://resources/items/bandage.tres")
const _STAFF: Resource = preload("res://resources/items/staff.tres")
# Potions (new)
const _POTION_HASTE: Resource = preload("res://resources/items/potion_haste.tres")
const _POTION_INVISIBLE: Resource = preload("res://resources/items/potion_invisible.tres")
const _POTION_AGILITY: Resource = preload("res://resources/items/potion_agility.tres")
const _POTION_BRILLIANCE: Resource = preload("res://resources/items/potion_brilliance.tres")
const _POTION_EXPERIENCE: Resource = preload("res://resources/items/potion_experience.tres")
# Scrolls (new)
const _SCROLL_FEAR: Resource = preload("res://resources/items/scroll_fear.tres")
const _SCROLL_UPGRADE: Resource = preload("res://resources/items/scroll_upgrade.tres")
const _SCROLL_FOG: Resource = preload("res://resources/items/scroll_fog.tres")
const _SCROLL_BRAND: Resource = preload("res://resources/items/scroll_brand.tres")
const _SCROLL_SILENCE: Resource = preload("res://resources/items/scroll_silence.tres")
const _SCROLL_BRAND_VENOM: Resource = preload("res://resources/items/scroll_brand_venom.tres")
const _SCROLL_BRAND_FREEZING: Resource = preload("res://resources/items/scroll_brand_freezing.tres")
const _SCROLL_BRAND_FLAMING: Resource = preload("res://resources/items/scroll_brand_flaming.tres")
const _SCROLL_BRAND_DRAIN: Resource = preload("res://resources/items/scroll_brand_drain.tres")
# Wands
const _WAND_FIRE: Resource = preload("res://resources/items/wand_fire.tres")
const _WAND_FROST: Resource = preload("res://resources/items/wand_frost.tres")
const _WAND_LIGHTNING: Resource = preload("res://resources/items/wand_lightning.tres")
const _WAND_TELEPORT: Resource = preload("res://resources/items/wand_teleport.tres")
const _WAND_FEAR: Resource = preload("res://resources/items/wand_fear.tres")
const _WAND_HASTE: Resource = preload("res://resources/items/wand_haste.tres")
const _WAND_DIGGING: Resource = preload("res://resources/items/wand_digging.tres")
# Throwing
const _THROWING_KNIFE: Resource = preload("res://resources/items/throwing_knife.tres")
const _JAVELIN: Resource = preload("res://resources/items/javelin.tres")
const _BOMB: Resource = preload("res://resources/items/bomb.tres")
const _POISON_FLASK: Resource = preload("res://resources/items/poison_flask.tres")
const _SMOKE_BOMB: Resource = preload("res://resources/items/smoke_bomb.tres")
const _POTION_RESISTANCE: Resource = preload("res://resources/items/potion_resistance.tres")
const _POTION_CANCELLATION: Resource = preload("res://resources/items/potion_cancellation.tres")
const _SCROLL_IMMOLATION: Resource = preload("res://resources/items/scroll_immolation.tres")
const _SCROLL_NOISE: Resource = preload("res://resources/items/scroll_noise.tres")
# Negative potions
const _POTION_POISON: Resource = preload("res://resources/items/potion_poison.tres")
const _POTION_CONFUSION: Resource = preload("res://resources/items/potion_confusion.tres")
const _POTION_DEGENERATION: Resource = preload("res://resources/items/potion_degeneration.tres")
const _POTION_PARALYSIS: Resource = preload("res://resources/items/potion_paralysis.tres")
const _POTION_TOXIC_GAS: Resource = preload("res://resources/items/potion_toxic_gas.tres")
const _POTION_LIQUID_FLAME: Resource = preload("res://resources/items/potion_liquid_flame.tres")
# Negative scrolls
const _SCROLL_CURSE: Resource = preload("res://resources/items/scroll_curse.tres")
const _SCROLL_TORMENT: Resource = preload("res://resources/items/scroll_torment.tres")
const _SCROLL_VULNERABILITY: Resource = preload("res://resources/items/scroll_vulnerability.tres")
# Resistance rings
const _RING_POISON_RESIST: Resource = preload("res://resources/items/ring_poison_resist.tres")
const _RING_COLD_RESIST: Resource = preload("res://resources/items/ring_cold_resist.tres")
const _RING_FIRE_RESIST: Resource = preload("res://resources/items/ring_fire_resist.tres")
const _RING_NECRO_RESIST: Resource = preload("res://resources/items/ring_necro_resist.tres")
const _RING_LIGHTNING_RESIST: Resource = preload("res://resources/items/ring_lightning_resist.tres")
const _RING_WILL_RESIST: Resource = preload("res://resources/items/ring_will_resist.tres")
# Unique rings
const _RING_BOG: Resource = preload("res://resources/items/ring_bog.tres")
const _RING_GLACIER: Resource = preload("res://resources/items/ring_glacier.tres")
const _RING_EMBER: Resource = preload("res://resources/items/ring_ember.tres")
const _RING_UNDEATH: Resource = preload("res://resources/items/ring_undeath.tres")
const _ESSENCE_SHARD: Resource = preload("res://resources/items/essence_shard.tres")
# Runes
const _RUNE_SWAMP: Resource = preload("res://resources/items/rune_swamp.tres")
const _RUNE_ICE: Resource = preload("res://resources/items/rune_ice.tres")
const _RUNE_INFERNAL: Resource = preload("res://resources/items/rune_infernal.tres")
const _RUNE_CRYPT: Resource = preload("res://resources/items/rune_crypt.tres")
# Spellpages
const _SPELLPAGE_FIREBALL: Resource = preload("res://resources/items/spellpage_fireball.tres")
const _SPELLPAGE_FIRE_STORM: Resource = preload("res://resources/items/spellpage_fire_storm.tres")
# Spellpages (tier 1)
const _SPELLPAGE_FREEZE: Resource = preload("res://resources/items/spellpage_freeze.tres")
const _SPELLPAGE_PAIN: Resource = preload("res://resources/items/spellpage_pain.tres")
const _SPELLPAGE_SHOCK: Resource = preload("res://resources/items/spellpage_shock.tres")
const _SPELLPAGE_SLOW: Resource = preload("res://resources/items/spellpage_slow.tres")
const _SPELLPAGE_SANDBLAST: Resource = preload("res://resources/items/spellpage_sandblast.tres")
const _SPELLPAGE_FOXFIRE: Resource = preload("res://resources/items/spellpage_foxfire.tres")
# Spellpages (tier 2)
const _SPELLPAGE_ANIMATE_SKELETON: Resource = preload("res://resources/items/spellpage_animate_skeleton.tres")
const _SPELLPAGE_CALL_IMP: Resource = preload("res://resources/items/spellpage_call_imp.tres")
const _SPELLPAGE_CONJURE_FLAME: Resource = preload("res://resources/items/spellpage_conjure_flame.tres")
const _SPELLPAGE_PETRIFY: Resource = preload("res://resources/items/spellpage_petrify.tres")
const _SPELLPAGE_SCORCH: Resource = preload("res://resources/items/spellpage_scorch.tres")
const _SPELLPAGE_STATIC_DISCHARGE: Resource = preload("res://resources/items/spellpage_static_discharge.tres")
# Spellpages (tier 3)
const _SPELLPAGE_CONFUSE: Resource = preload("res://resources/items/spellpage_confuse.tres")
const _SPELLPAGE_HEX_FEAR: Resource = preload("res://resources/items/spellpage_hex_fear.tres")
const _SPELLPAGE_LEE_RAPID_DECONSTRUCTION: Resource = preload("res://resources/items/spellpage_lee_rapid_deconstruction.tres")
const _SPELLPAGE_LIGHTNING_BOLT: Resource = preload("res://resources/items/spellpage_lightning_bolt.tres")
const _SPELLPAGE_STONE_ARROW: Resource = preload("res://resources/items/spellpage_stone_arrow.tres")
const _SPELLPAGE_VAMPIRIC_DRAINING: Resource = preload("res://resources/items/spellpage_vampiric_draining.tres")
# Spellpages (tier 4)
const _SPELLPAGE_AIRSTRIKE: Resource = preload("res://resources/items/spellpage_airstrike.tres")
const _SPELLPAGE_ANIMATE_DEAD: Resource = preload("res://resources/items/spellpage_animate_dead.tres")
const _SPELLPAGE_HEX_SLEEP: Resource = preload("res://resources/items/spellpage_hex_sleep.tres")
const _SPELLPAGE_LEHUDIB_CRYSTAL_SPEAR: Resource = preload("res://resources/items/spellpage_lehudib_crystal_spear.tres")
const _SPELLPAGE_OZOCUBUS_REFRIGERATION: Resource = preload("res://resources/items/spellpage_ozocubus_refrigeration.tres")
# Spellpages (tier 5)
const _SPELLPAGE_DEATHS_DOOR: Resource = preload("res://resources/items/spellpage_deaths_door.tres")
const _SPELLPAGE_IGNITION: Resource = preload("res://resources/items/spellpage_ignition.tres")
const _SPELLPAGE_SHATTER: Resource = preload("res://resources/items/spellpage_shatter.tres")
const _SPELLPAGE_HAUNT: Resource = preload("res://resources/items/spellpage_haunt.tres")
const _SPELLPAGE_MASS_CONFUSION: Resource = preload("res://resources/items/spellpage_mass_confusion.tres")
const _SPELLPAGE_GLACIATE: Resource = preload("res://resources/items/spellpage_glaciate.tres")

# All learnable spells with depth-based tiers (tier ≈ depth at which spell first appears).
# Tiers are derived from spell_level: 1-2→tier1, 3-4→tier2, 5-6→tier3, 7-8→tier4, 9→tier5.
const SPELL_POOL: Array = [
	# Tier 1 — available from depth 1
	{"spell_id": "freeze",          "tier": 1},
	{"spell_id": "pain",            "tier": 1},
	{"spell_id": "shock",           "tier": 1},

	{"spell_id": "slow",            "tier": 1},
	{"spell_id": "sandblast",       "tier": 1},
	{"spell_id": "foxfire",         "tier": 1},

	# Tier 2 — available from depth 2
	{"spell_id": "animate_skeleton","tier": 2},
	{"spell_id": "call_imp",        "tier": 2},
	{"spell_id": "conjure_flame",   "tier": 2},
	{"spell_id": "petrify",         "tier": 2},
	{"spell_id": "scorch",          "tier": 2},
	{"spell_id": "static_discharge","tier": 2},
	# Tier 3 — available from depth 3
	{"spell_id": "confuse",         "tier": 3},
	{"spell_id": "hex_fear",        "tier": 3},
	{"spell_id": "lee_rapid_deconstruction","tier": 3},
	{"spell_id": "lightning_bolt",  "tier": 3},
	{"spell_id": "stone_arrow",     "tier": 3},
	{"spell_id": "vampiric_draining","tier": 3},
	# Tier 4 — available from depth 4
	{"spell_id": "airstrike",       "tier": 4},
	{"spell_id": "animate_dead",    "tier": 4},
	{"spell_id": "hex_sleep",       "tier": 4},
	{"spell_id": "lehudib_crystal_spear","tier": 4},
	{"spell_id": "ozocubus_refrigeration","tier": 4},
	# Tier 5 — available from depth 5
	{"spell_id": "deaths_door",     "tier": 5},
	{"spell_id": "fireball",        "tier": 5},
	{"spell_id": "ignition",        "tier": 5},
	{"spell_id": "shatter",         "tier": 5},
	{"spell_id": "haunt",           "tier": 6},
	{"spell_id": "mass_confusion",  "tier": 6},
	# Tier 7 — high-end spells
	{"spell_id": "fire_storm",      "tier": 7},
	{"spell_id": "glaciate",        "tier": 7},
]

const _ALL_ITEMS: Array = [
	_SHORT_SWORD, _DAGGER, _LONG_SWORD, _BATTLE_AXE, _SPEAR,
	_STILETTO, _DIRK, _ASSASSIN_BLADE, _QUICK_BLADE,
	_ARMING_SWORD, _BASTARD_SWORD, _GREAT_BLADE,
	_RING_STR, _RING_INT, _RING_DEX, _RING_PROTECTION, _RING_SLAYING, _RING_WIZARDRY,
	_AMULET_LIFE, _AMULET_MAGIC, _AMULET_STR,
	_BUCKLER, _ROUND_SHIELD, _KITE_SHIELD, _TOWER_SHIELD,
	_LEATHER_CAP, _IRON_HELM, _GREAT_HELM,
	_LEATHER_GLOVES, _IRON_GAUNTLETS,
	_LEATHER_BOOTS, _IRON_GREAVES,
	_SHORTBOW, _LONGBOW, _CROSSBOW,
	_FLAMING_SWORD, _FROST_DAGGER, _VENOM_DAGGER,
	_LEATHER_ARMOR, _ROBE, _CHAIN_MAIL, _RING_MAIL, _SCALE_MAIL, _PLATE_MAIL, _TROLL_LEATHER,
	_POTION_HEALING, _POTION_MIGHT, _POTION_CURE_POISON, _POTION_MAGIC,
	_POTION_BERSERK, _BANDAGE, _STAFF,
	_POTION_HASTE, _POTION_INVISIBLE,
	_SCROLL_BLINKING, _SCROLL_MAGIC_MAPPING, _SCROLL_TELEPORT,
	_SCROLL_ENCHANT_WEAPON, _SCROLL_ENCHANT_ARMOR, _SCROLL_IDENTIFY,
	_SCROLL_FEAR, _SCROLL_BRAND, _SCROLL_IMMOLATION,
	_BOOK_FIRE, _BOOK_COLD, _BOOK_AIR, _BOOK_EARTH,
	_BOOK_NECROMANCY, _BOOK_HEXES, _BOOK_CONJURATION,
	_GOLD_PILE,
	_WAND_FIRE, _WAND_FROST, _WAND_LIGHTNING, _WAND_TELEPORT,
	_WAND_FEAR, _WAND_HASTE, _WAND_DIGGING,
	_THROWING_KNIFE, _JAVELIN, _BOMB, _POISON_FLASK, _SMOKE_BOMB,
	_POTION_RESISTANCE,
	_SCROLL_NOISE,
	_POTION_POISON, _POTION_CONFUSION, _POTION_DEGENERATION,
	_POTION_PARALYSIS, _POTION_TOXIC_GAS, _POTION_LIQUID_FLAME,
	_SCROLL_CURSE, _SCROLL_TORMENT, _SCROLL_VULNERABILITY,
	_RING_POISON_RESIST, _RING_COLD_RESIST, _RING_FIRE_RESIST, _RING_NECRO_RESIST,
	_RING_LIGHTNING_RESIST, _RING_WILL_RESIST,
	_RING_BOG, _RING_GLACIER, _RING_EMBER, _RING_UNDEATH,
	_ESSENCE_SHARD,
	_RUNE_SWAMP, _RUNE_ICE, _RUNE_INFERNAL, _RUNE_CRYPT,
	_SPELLPAGE_FIREBALL, _SPELLPAGE_FIRE_STORM,
	# Tier 1 spellpages
	_SPELLPAGE_FREEZE, _SPELLPAGE_PAIN,
	_SPELLPAGE_SHOCK, _SPELLPAGE_SLOW,
	_SPELLPAGE_SANDBLAST, _SPELLPAGE_FOXFIRE,
	# Tier 2 spellpages
	_SPELLPAGE_ANIMATE_SKELETON, _SPELLPAGE_CALL_IMP,
	_SPELLPAGE_CONJURE_FLAME, _SPELLPAGE_PETRIFY, _SPELLPAGE_SCORCH,
	_SPELLPAGE_STATIC_DISCHARGE,
	# Tier 3 spellpages
	_SPELLPAGE_CONFUSE, _SPELLPAGE_HEX_FEAR, _SPELLPAGE_LEE_RAPID_DECONSTRUCTION,
	_SPELLPAGE_LIGHTNING_BOLT, _SPELLPAGE_STONE_ARROW,
	_SPELLPAGE_VAMPIRIC_DRAINING,
	# Tier 4 spellpages
	_SPELLPAGE_AIRSTRIKE, _SPELLPAGE_ANIMATE_DEAD, _SPELLPAGE_HEX_SLEEP,
	_SPELLPAGE_LEHUDIB_CRYSTAL_SPEAR,
	_SPELLPAGE_OZOCUBUS_REFRIGERATION,
	# Tier 5 spellpages
	_SPELLPAGE_DEATHS_DOOR, _SPELLPAGE_IGNITION,
	_SPELLPAGE_SHATTER, _SPELLPAGE_HAUNT, _SPELLPAGE_MASS_CONFUSION, _SPELLPAGE_GLACIATE,
]

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in _ALL_ITEMS:
		_register(res)
	if all.is_empty():
		push_warning("ItemRegistry: 0 items registered.")

func _register(res) -> void:
	if res == null:
		return
	if not ("id" in res):
		return
	if String(res.id) == "":
		return
	by_id[String(res.id)] = res
	all.append(res)
	# Lint: warn if declared tile assets do not exist on disk so future
	# bad name→image mappings surface at boot instead of as silent blank icons.
	if "tile_path" in res:
		var tp: String = String(res.tile_path)
		if tp != "" and not ResourceLoader.exists(tp):
			push_warning("ItemRegistry: %s tile_path missing: %s" % [String(res.id), tp])
	if "identified_tile_path" in res:
		var itp: String = String(res.identified_tile_path)
		if itp != "" and not ResourceLoader.exists(itp):
			push_warning("ItemRegistry: %s identified_tile_path missing: %s" % [String(res.id), itp])

func get_by_id(id: String) -> ItemData:
	if by_id.has(id):
		return by_id[id]
	var base_id: String = base_id_of(id)
	return by_id.get(base_id)

func base_id_of(id: String) -> String:
	var idx: int = id.find("#")
	return id.substr(0, idx) if idx >= 0 else id

func entry_display_name(entry: Dictionary) -> String:
	var id: String = String(entry.get("id", ""))
	if base_id_of(id) == "essence_shard":
		var essence_id: String = String(entry.get("essence_id", ""))
		if essence_id != "":
			return EssenceSystem.display_name(essence_id)
	# Partial books carry their display_name directly in the entry dict.
	if entry.get("is_partial_book", false) and entry.has("display_name"):
		return String(entry["display_name"])
	var data: ItemData = get_by_id(id)
	if data == null:
		return id
	var base_name: String = GameManager.display_name_of(base_id_of(id)) if GameManager != null else data.loc_name()
	var artifact_name: String = String(entry.get("artifact_name", ""))
	if artifact_name != "":
		return 'the %s "%s"' % [data.loc_name(), artifact_name]
	return base_name

func entry_bonus_lines(entry: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for mod in entry.get("mods", []):
		var m: Dictionary = mod
		var mod_type: String = String(m.get("type", ""))
		var value: int = int(m.get("value", 0))
		match mod_type:
			"slay":
				lines.append("Slay %+d" % value)
			"wizardry":
				lines.append("Wizardry %+d" % value)
			"stat_str":
				lines.append("Str %+d" % value)
			"stat_dex":
				lines.append("Dex %+d" % value)
			"stat_int":
				lines.append("Int %+d" % value)
			"hp_bonus":
				lines.append("HP %+d" % value)
			"mp_bonus":
				lines.append("MP %+d" % value)
			"will_bonus":
				lines.append("Will %+d" % value)
			"resist_fire":
				lines.append("rFire%s" % ("+" if value >= 0 else "-"))
			"resist_cold":
				lines.append("rCold%s" % ("+" if value >= 0 else "-"))
			"resist_poison":
				lines.append("rPois%s" % ("+" if value >= 0 else "-"))
			"resist_necro":
				lines.append("rNcr%s" % ("+" if value >= 0 else "-"))
	return lines

func entry_bonus_summary(entry: Dictionary) -> String:
	var lines: PackedStringArray = entry_bonus_lines(entry)
	return " {" + ", ".join(lines) + "}" if not lines.is_empty() else ""

func make_entry(id: String, depth: int, plus_override: int = 0) -> Dictionary:
	var data: ItemData = get_by_id(id)
	var entry: Dictionary = {"id": id, "plus": plus_override}
	if data == null:
		return entry
	if data.kind == "wand":
		entry["charges"] = data.effect_value
	if data.kind not in ["weapon", "ring", "amulet"]:
		return entry
	var chance: float = 0.05 + float(depth) * 0.012
	if data.kind in ["ring", "amulet"]:
		chance += 0.08
	if randf() >= min(chance, 0.33):
		return entry
	var rolled: Array = _roll_randart_mods(data.kind)
	if rolled.is_empty():
		return entry
	entry["id"] = "%s#%06d" % [id, randi() % 1000000]
	entry["base_id"] = id
	entry["artifact_name"] = _randart_name()
	entry["mods"] = rolled
	return entry

func _roll_randart_mods(kind: String) -> Array:
	var positives: Array = [
		{"type":"slay","value":randi_range(2, 4)},
		{"type":"stat_str","value":randi_range(1, 3)},
		{"type":"stat_dex","value":randi_range(1, 3)},
		{"type":"stat_int","value":randi_range(1, 3)},
		{"type":"hp_bonus","value":randi_range(4, 12)},
		{"type":"mp_bonus","value":randi_range(3, 8)},
		{"type":"will_bonus","value":1},
		{"type":"resist_fire","value":randi_range(1, 3)},
		{"type":"resist_cold","value":randi_range(1, 3)},
		{"type":"resist_poison","value":randi_range(1, 3)},
		{"type":"resist_necro","value":randi_range(1, 3)},
	]
	var negatives: Array = [
		{"type":"stat_str","value":-randi_range(1, 3)},
		{"type":"stat_dex","value":-randi_range(1, 3)},
		{"type":"stat_int","value":-randi_range(1, 3)},
		{"type":"hp_bonus","value":-randi_range(3, 10)},
		{"type":"mp_bonus","value":-randi_range(2, 6)},
		{"type":"will_bonus","value":-1},
		{"type":"resist_fire","value":-1},
		{"type":"resist_cold","value":-1},
		{"type":"resist_poison","value":-1},
		{"type":"resist_necro","value":-1},
	]
	if kind == "weapon":
		positives = positives.filter(func(m): return String(m.get("type", "")) not in ["mp_bonus"])
		negatives = negatives.filter(func(m): return String(m.get("type", "")) not in ["mp_bonus"])
	var rolled: Array = []
	var by_type: Dictionary = {}
	var positive_rolls: int = 1
	var quality_roll: float = randf()
	if quality_roll >= 0.22:
		positive_rolls += 1
	if quality_roll >= 0.62:
		positive_rolls += 1
	if quality_roll >= 0.9:
		positive_rolls += 1
	var negative_rolls: int = 0
	var bad_roll: float = randf()
	if bad_roll < 0.18:
		negative_rolls = 1
		if randf() < 0.12:
			negative_rolls = 2
	for _i in range(positive_rolls):
		var picked_pos := _pick_randart_mod(positives, rolled, by_type, true)
		if picked_pos.is_empty():
			continue
		_apply_randart_mod_roll(rolled, by_type, picked_pos)
	for _i in range(negative_rolls):
		var picked_neg := _pick_randart_mod(negatives, rolled, by_type, false)
		if picked_neg.is_empty():
			continue
		_apply_randart_mod_roll(rolled, by_type, picked_neg)
	return rolled

func _pick_randart_mod(pool: Array, rolled: Array, by_type: Dictionary, positive: bool) -> Dictionary:
	for _attempt in range(32):
		var candidate: Dictionary = pool[randi() % pool.size()].duplicate(true)
		var mod_type: String = String(candidate.get("type", ""))
		if mod_type == "":
			continue
		if by_type.has(mod_type):
			var idx: int = int(by_type[mod_type])
			var existing: Dictionary = rolled_entry_at(rolled, idx)
			var existing_value: int = int(existing.get("value", 0))
			if (existing_value >= 0) != positive:
				continue
		return candidate
	return {}

func _apply_randart_mod_roll(rolled: Array, by_type: Dictionary, mod: Dictionary) -> void:
	var mod_type: String = String(mod.get("type", ""))
	if mod_type == "":
		return
	if by_type.has(mod_type):
		var idx: int = int(by_type[mod_type])
		var existing: Dictionary = rolled[idx]
		existing["value"] = int(existing.get("value", 0)) + int(mod.get("value", 0))
		rolled[idx] = existing
	else:
		by_type[mod_type] = rolled.size()
		rolled.append(mod.duplicate(true))

func rolled_entry_at(arr: Array, idx: int) -> Dictionary:
	if idx < 0 or idx >= arr.size():
		return {}
	return Dictionary(arr[idx])

func _randart_name() -> String:
	var left: Array[String] = ["Ash", "Winter", "Widow", "Hollow", "Saint", "Mire", "Cinder", "Glass", "Black", "Storm"]
	var right: Array[String] = ["Choir", "Answer", "Tithe", "Promise", "Wake", "Vigil", "Crown", "Ladder", "Engine", "Oath"]
	return "%s %s" % [left[randi() % left.size()], right[randi() % right.size()]]

# Returns a runtime Dictionary entry (not a .tres resource) representing a
# partial spellbook with 2–3 spells appropriate for the given depth.
# Caller must handle spawning via _spawn_floor_item with a book base ItemData.
func generate_partial_book(depth: int) -> Dictionary:
	var eligible: Array = SPELL_POOL.filter(func(s): return int(s.get("tier", 1)) <= depth)
	if eligible.is_empty():
		eligible = SPELL_POOL.duplicate()
	eligible.shuffle()
	var count: int = randi_range(2, min(3, eligible.size()))
	var chosen: Array = eligible.slice(0, count)
	var spell_ids: Array = chosen.map(func(s): return String(s.get("spell_id", "")))
	var tier_sum: int = 0
	for s in chosen:
		tier_sum += int(s.get("tier", 1))
	var avg_tier: int = ceili(float(tier_sum) / float(count))
	var book_names: Array[String] = [
		"Worn Spellbook", "Scribbled Notes", "Dog-eared Tome",
		"Tattered Grimoire", "Partial Codex",
	]
	var display_name: String = book_names[randi() % book_names.size()]
	var book_tiles: Array[String] = [
		"res://assets/tiles/individual/item/book/dark_blue.png",
		"res://assets/tiles/individual/item/book/purple.png",
		"res://assets/tiles/individual/item/book/cloth.png",
		"res://assets/tiles/individual/item/book/leather.png",
	]
	var tile_path: String = book_tiles[randi() % book_tiles.size()]
	return {
		"id": "book_partial",        # base ItemData id for FloorItem / Player.use_item
		"kind": "book",
		"effect": "study",
		"tier": avg_tier,
		"display_name": display_name,
		"tile_path": tile_path,
		"grants_spell_ids": spell_ids,
		"plus": 0,
		"is_partial_book": true,     # sentinel so callers can distinguish
	}

# Picks a random spellpage ItemData from the registered spellpages.
func pick_random_spellpage(depth: int) -> ItemData:
	return _pick_weighted(depth, ["spellpage"])

func pick_by_depth(depth: int, kind_filter: String = "") -> ItemData:
	var candidates: Array = []
	for it in all:
		if kind_filter != "" and it.kind != kind_filter:
			continue
		if depth >= it.tier:
			candidates.append(it)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func pick_floor_loot(depth: int) -> ItemData:
	# Note: partial books (generate_partial_book) are NOT returned here because
	# this function returns ItemData resources. Partial books are spawned via
	# _spawn_items_for_floor in Game.gd using generate_partial_book() directly.
	# Weights: potion 31%, scroll 27%, wand 18%, throwing 6%, spellpage 2%,
	#          full school book 1%, gold 5%, equipment 10%.
	var roll: float = randf()
	if roll < 0.31:
		return _pick_weighted(depth, ["potion"])
	if roll < 0.58:
		return _pick_weighted(depth, ["scroll"])
	if roll < 0.76:
		return _pick_weighted(depth, ["wand"])
	if roll < 0.82:
		return _pick_weighted(depth, ["throwing"])
	if roll < 0.84:
		return _pick_weighted(depth, ["spellpage"])
	if roll < 0.85:
		return _pick_weighted(depth, ["book"])
	if roll < 0.90:
		return _pick_weighted(depth, ["gold"])
	return _pick_weighted(depth, ["weapon", "armor", "ring", "amulet", "shield", "helmet", "gloves", "boots"])

func pick_kind(depth: int, kind: String) -> ItemData:
	return _pick_weighted(depth, [kind])

func pick_equipment(depth: int) -> ItemData:
	return _pick_weighted(depth, ["weapon", "armor", "ring", "amulet", "shield", "helmet", "gloves", "boots"])

func pick_equipment_weighted(depth: int) -> ItemData:
	var eq_kinds: Array[String] = ["weapon", "armor", "ring", "amulet", "shield", "helmet", "gloves", "boots"]
	var candidates: Array = []
	var weights: Array[int] = []
	for it in all:
		if not eq_kinds.has(String(it.kind)):
			continue
		var w: int = _tier_weight(it.tier, depth)
		if w <= 0:
			continue
		candidates.append(it)
		weights.append(w)
	if candidates.is_empty():
		return pick_by_depth(depth)
	var total: int = 0
	for w in weights:
		total += w
	var roll: int = randi() % total
	var acc: int = 0
	for i in range(candidates.size()):
		acc += weights[i]
		if roll < acc:
			return candidates[i]
	return candidates[candidates.size() - 1]

func _tier_weight(tier: int, depth: int) -> int:
	# Main floors 1-5, branch effective depths up to 7.
	# Depth 1: dungeon. 2: lair/crypt-1F. 3: orc/crypt-2F/swamp-1F.
	# 4: elf/swamp-2F/ice-1F. 5: abyss/swamp-3F/ice-2F/infernal-1F.
	# 6+: ice-3F, infernal-2F/3F.
	if depth <= 1:
		match tier:
			1: return 70
			2: return 25
			3: return 5
		return 0
	elif depth <= 2:
		match tier:
			1: return 30
			2: return 45
			3: return 20
			4: return 5
		return 0
	elif depth <= 3:
		match tier:
			1: return 10
			2: return 30
			3: return 40
			4: return 18
			5: return 2
		return 0
	elif depth <= 4:
		match tier:
			2: return 15
			3: return 35
			4: return 35
			5: return 15
		return 0
	elif depth <= 5:
		match tier:
			2: return 5
			3: return 25
			4: return 45
			5: return 25
		return 0
	else:
		match tier:
			3: return 10
			4: return 40
			5: return 50
		return 0

func _pick_weighted(depth: int, kinds: Array[String]) -> ItemData:
	var candidates: Array = []
	for it in all:
		if depth < it.tier:
			continue
		if not kinds.has(String(it.kind)):
			continue
		candidates.append(it)
	if candidates.is_empty():
		return pick_by_depth(depth)
	return candidates[randi() % candidates.size()]
