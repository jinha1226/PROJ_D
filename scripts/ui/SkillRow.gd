extends HBoxContainer
class_name SkillRow

signal training_toggled(skill_id: String, enabled: bool)

const SKILL_NAMES: Dictionary = {
	"axe": "Axe",
	"short_blade": "Short Blades",
	"long_blade": "Long Blades",
	"mace": "Maces & Flails",
	"polearm": "Polearms",
	"staff": "Staves",
	"bow": "Bows",
	"crossbow": "Crossbows",
	"sling": "Slings",
	"throwing": "Throwing",
	"unarmed_combat": "Unarmed Combat",
	"fighting": "Fighting",
	"armour": "Armour",
	"dodging": "Dodging",
	"shields": "Shields",
	"spellcasting": "Spellcasting",
	"conjurations": "Conjurations",
	"fire": "Fire Magic",
	"cold": "Cold Magic",
	"earth": "Earth Magic",
	"air": "Air Magic",
	"necromancy": "Necromancy",
	"hexes": "Hexes",
	"translocations": "Translocations",
	"summonings": "Summonings",
	"stealth": "Stealth",
	"evocations": "Evocations",
	"essence_channeling": "Essence Channeling",
}

const CATEGORY_NAMES: Dictionary = {
	"weapon": "Weapon",
	"defense": "Defense",
	"magic": "Magic",
	"misc": "Misc",
}

const MAX_LEVEL: int = 27

var skill_id: String = ""
var _check: CheckBox
var _name_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_status_label: Label
var _cat_label: Label
var _is_magic: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(880, 96)
	add_theme_constant_override("separation", 12)

	_check = CheckBox.new()
	_check.custom_minimum_size = Vector2(48, 48)
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_check.toggled.connect(_on_check_toggled)
	add_child(_check)

	var center: VBoxContainer = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 4)
	add_child(center)

	var top_row: HBoxContainer = HBoxContainer.new()
	top_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(top_row)

	_name_label = Label.new()
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_font_size_override("font_size", 22)
	top_row.add_child(_name_label)

	_level_label = Label.new()
	_level_label.add_theme_font_size_override("font_size", 22)
	_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top_row.add_child(_level_label)

	var bar_row: HBoxContainer = HBoxContainer.new()
	bar_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_child(bar_row)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(0, 18)
	_xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_xp_bar.show_percentage = false
	bar_row.add_child(_xp_bar)

	_xp_status_label = Label.new()
	_xp_status_label.add_theme_font_size_override("font_size", 14)
	_xp_status_label.modulate = Color(0.8, 0.8, 0.8, 1.0)
	center.add_child(_xp_status_label)

	_cat_label = Label.new()
	_cat_label.add_theme_font_size_override("font_size", 14)
	_cat_label.modulate = Color(0.6, 0.6, 0.7, 1.0)
	_cat_label.custom_minimum_size = Vector2(80, 0)
	_cat_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_cat_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_cat_label)


func bind(p_skill_id: String, state: Dictionary, category: String) -> void:
	skill_id = p_skill_id
	_is_magic = (category == "magic")
	_name_label.text = SKILL_NAMES.get(skill_id, skill_id)
	_cat_label.text = CATEGORY_NAMES.get(category, category)

	var level: int = int(state.get("level", 0))
	var xp: float = float(state.get("xp", 0.0))
	var training: bool = bool(state.get("training", false))

	_check.set_pressed_no_signal(training)

	if level >= MAX_LEVEL:
		_level_label.text = "MASTER"
		_xp_bar.visible = false
		_xp_status_label.visible = true
		_xp_status_label.text = "Max level reached"
	elif level == 0 and not training:
		_level_label.text = "Lv.0"
		_xp_bar.visible = false
		_xp_status_label.visible = true
		_xp_status_label.text = "untrained"
	else:
		_level_label.text = "Lv.%d" % level
		var needed: float = SkillSystem.xp_for_level(level + 1)
		_xp_bar.visible = true
		_xp_bar.max_value = max(1.0, needed)
		_xp_bar.value = clamp(xp, 0.0, needed)
		_xp_status_label.visible = true
		_xp_status_label.text = "%d / %d XP" % [int(xp), int(needed)]

	if _is_magic:
		modulate = Color(0.55, 0.55, 0.7, 1.0)
		_check.disabled = true
	elif training:
		modulate = Color(1, 1, 1, 1)
		_check.disabled = false
	else:
		modulate = Color(0.6, 0.6, 0.6, 1.0)
		_check.disabled = false


func _on_check_toggled(pressed: bool) -> void:
	training_toggled.emit(skill_id, pressed)
