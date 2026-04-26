extends SceneTree

const SPELL_DIR := "res://resources/spells"
const CLASS_FILES := {
	"fighter": "res://resources/classes/warrior.tres",
	"rogue": "res://resources/classes/rogue.tres",
	"mage": "res://resources/classes/mage.tres",
}

func _init() -> void:
	print("== PocketCrawl Balance Simulator ==")
	_print_spell_thresholds()
	_print_class_hp_curves()
	_print_loot_samples()
	quit()

func _print_spell_thresholds() -> void:
	print("")
	print("-- INT thresholds by spell level --")
	var spells := _load_spells()
	spells.sort_custom(func(a, b):
		if a.spell_level != b.spell_level:
			return a.spell_level < b.spell_level
		if a.school != b.school:
			return a.school < b.school
		return a.display_name < b.display_name
	)
	for spell in spells:
		var int_req := 8 + max(0, spell.spell_level - 1) * 2
		print("L%d INT%02d %s [%s] MP%d XL%d" % [
			spell.spell_level,
			int_req,
			spell.display_name,
			spell.school,
			spell.mp_cost,
			spell.xl_required,
		])

func _print_class_hp_curves() -> void:
	print("")
	print("-- Class HP curves (XL1-10) --")
	for key in CLASS_FILES.keys():
		var cls: Resource = load(CLASS_FILES[key])
		if cls == null:
			continue
		var hp: int = int(cls.starting_hp) + int(cls.starting_str) / 2
		var strength: int = int(cls.starting_str)
		var out: Array[String] = []
		out.append("XL1=%d" % hp)
		for xl in range(2, 11):
			var gain: int = _hp_gain_for_class(String(cls.class_group), strength)
			hp += gain
			out.append("XL%d=%d" % [xl, hp])
		print("%s -> %s" % [String(cls.display_name), ", ".join(out)])

func _print_loot_samples() -> void:
	print("")
	print("-- Loot samples --")
	var registry := load("res://scripts/systems/ItemRegistry.gd").new()
	registry._ready()
	for depth in [1, 3, 5, 8]:
		var counts: Dictionary = {}
		for _i in range(200):
			var item = registry.pick_floor_loot(depth)
			if item == null:
				continue
			var kind: String = String(item.kind)
			counts[kind] = int(counts.get(kind, 0)) + 1
		print("Depth %d -> %s" % [depth, JSON.stringify(counts)])

func _load_spells() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.ends_with(".tres"):
			continue
		var spell = load("%s/%s" % [SPELL_DIR, name])
		if spell != null:
			out.append(spell)
	dir.list_dir_end()
	return out

func _hp_gain_for_class(class_group: String, strength: int) -> int:
	var base_gain: int = 4
	match class_group:
		"fighter":
			base_gain = 5
		"rogue":
			base_gain = 4
		"mage":
			base_gain = 3
	return max(2, base_gain + strength / 6)
