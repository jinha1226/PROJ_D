extends Node

const _ALL: Array[Resource] = [
	# Fire
	preload("res://resources/spells/scorch.tres"),
	preload("res://resources/spells/conjure_flame.tres"),
	preload("res://resources/spells/fireball.tres"),
	preload("res://resources/spells/fire_storm.tres"),
	preload("res://resources/spells/ignition.tres"),
	# Cold
	preload("res://resources/spells/freeze.tres"),
	preload("res://resources/spells/ice_bolt.tres"),
	preload("res://resources/spells/hibernation.tres"),
	preload("res://resources/spells/ozocubus_refrigeration.tres"),
	preload("res://resources/spells/glaciate.tres"),
	# Air
	preload("res://resources/spells/shock.tres"),
	preload("res://resources/spells/static_discharge.tres"),
	preload("res://resources/spells/lightning_bolt.tres"),
	preload("res://resources/spells/airstrike.tres"),
	preload("res://resources/spells/tornado.tres"),
	# Earth
	preload("res://resources/spells/stone_arrow.tres"),
	preload("res://resources/spells/petrify.tres"),
	preload("res://resources/spells/lee_rapid_deconstruction.tres"),
	preload("res://resources/spells/lehudib_crystal_spear.tres"),
	preload("res://resources/spells/shatter.tres"),
	# Necromancy
	preload("res://resources/spells/pain.tres"),
	preload("res://resources/spells/vampiric_draining.tres"),
	preload("res://resources/spells/animate_dead.tres"),
	preload("res://resources/spells/haunt.tres"),
	preload("res://resources/spells/deaths_door.tres"),
	# Hexes
	preload("res://resources/spells/slow.tres"),
	preload("res://resources/spells/confuse.tres"),
	preload("res://resources/spells/hex_fear.tres"),
	preload("res://resources/spells/hex_sleep.tres"),
	preload("res://resources/spells/mass_confusion.tres"),
	# Translocation
	preload("res://resources/spells/blink.tres"),
	preload("res://resources/spells/shroud_of_golubria.tres"),
	preload("res://resources/spells/conjure_fog.tres"),
	preload("res://resources/spells/swiftness.tres"),
	preload("res://resources/spells/teleport.tres"),
	# Summoning
	preload("res://resources/spells/call_imp.tres"),
	preload("res://resources/spells/animate_skeleton.tres"),
	preload("res://resources/spells/summon_vermin.tres"),
	preload("res://resources/spells/monstrous_menagerie.tres"),
	preload("res://resources/spells/malign_gateway.tres"),
]

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in _ALL:
		if res is SpellData:
			_register(res)
	all.sort_custom(func(a, b):
		if a.school != b.school:
			return a.school < b.school
		return a.spell_level < b.spell_level)
	if all.is_empty():
		push_warning("SpellRegistry: 0 spells registered.")

func _register(res: SpellData) -> void:
	if res.id == "":
		return
	by_id[res.id] = res
	all.append(res)

func get_by_id(id: String) -> SpellData:
	return by_id.get(id)

func get_by_school(school: String) -> Array:
	return all.filter(func(s): return s.school == school)

func get_available_for_xl(xl: int) -> Array:
	return all.filter(func(s): return s.xl_required <= xl)
