extends Node

const _ALL: Array[Resource] = [
	preload("res://resources/spells/animate_objects.tres"),
	preload("res://resources/spells/astral_projection.tres"),
	preload("res://resources/spells/blight.tres"),
	preload("res://resources/spells/blur.tres"),
	preload("res://resources/spells/chain_lightning.tres"),
	preload("res://resources/spells/cloudkill.tres"),
	preload("res://resources/spells/cone_of_cold.tres"),
	preload("res://resources/spells/confusion.tres"),
	preload("res://resources/spells/conjure_fey.tres"),
	preload("res://resources/spells/contagion.tres"),
	preload("res://resources/spells/dimension_door.tres"),
	preload("res://resources/spells/disintegrate.tres"),
	preload("res://resources/spells/earthquake.tres"),
	preload("res://resources/spells/enlarge.tres"),
	preload("res://resources/spells/expeditious_retreat.tres"),
	preload("res://resources/spells/fear.tres"),
	preload("res://resources/spells/finger_of_death.tres"),
	preload("res://resources/spells/fire_storm.tres"),
	preload("res://resources/spells/fireball.tres"),
	preload("res://resources/spells/fog_cloud.tres"),
	preload("res://resources/spells/gate.tres"),
	preload("res://resources/spells/globe_of_invulnerability.tres"),
	preload("res://resources/spells/harm.tres"),
	preload("res://resources/spells/haste.tres"),
	preload("res://resources/spells/hold_monster.tres"),
	preload("res://resources/spells/hold_person.tres"),
	preload("res://resources/spells/horrid_wilting.tres"),
	preload("res://resources/spells/ice_storm.tres"),
	preload("res://resources/spells/inflict_wounds.tres"),
	preload("res://resources/spells/invulnerability.tres"),
	preload("res://resources/spells/mage_armor.tres"),
	preload("res://resources/spells/magic_missile.tres"),
	preload("res://resources/spells/mass_suggestion.tres"),
	preload("res://resources/spells/maze.tres"),
	preload("res://resources/spells/meteor_swarm.tres"),
	preload("res://resources/spells/mind_blank.tres"),
	preload("res://resources/spells/misty_step.tres"),
	preload("res://resources/spells/polymorph.tres"),
	preload("res://resources/spells/power_word_kill.tres"),
	preload("res://resources/spells/power_word_pain.tres"),
	preload("res://resources/spells/power_word_stun.tres"),
	preload("res://resources/spells/prismatic_spray.tres"),
	preload("res://resources/spells/protection_from_energy.tres"),
	preload("res://resources/spells/ray_of_enfeeblement.tres"),
	preload("res://resources/spells/reverse_gravity.tres"),
	preload("res://resources/spells/scorching_ray.tres"),
	preload("res://resources/spells/sleep.tres"),
	preload("res://resources/spells/stinking_cloud.tres"),
	preload("res://resources/spells/stoneskin.tres"),
	preload("res://resources/spells/sunburst.tres"),
	preload("res://resources/spells/teleport.tres"),
	preload("res://resources/spells/time_stop.tres"),
	preload("res://resources/spells/vampiric_touch.tres"),
	preload("res://resources/spells/wall_of_force.tres"),
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
