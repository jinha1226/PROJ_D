extends Control
class_name TopHUD

@onready var hp_bar: ProgressBar = $Margin/VBox/HBox/HPBar
@onready var mp_bar: ProgressBar = $Margin/VBox/HBox/MPBar
@onready var depth_label: Label = $Margin/VBox/HBox/DepthLabel
@onready var bag_button: Button = $Margin/VBox/HBox/BagButton
@onready var minimap_button: Button = $Margin/VBox/HBox/MinimapButton
@onready var skills_button: Button = $Margin/VBox/HBox/SkillsButton
@onready var weapon_skill_label: Label = $Margin/VBox/WeaponSkillLabel

signal bag_pressed
signal minimap_pressed
signal skills_button_pressed

var _pulse_t: float = 0.0
var _pulsing: bool = false

func _ready() -> void:
	bag_button.pressed.connect(func(): bag_pressed.emit())
	minimap_button.pressed.connect(func(): minimap_pressed.emit())
	skills_button.pressed.connect(func(): skills_button_pressed.emit())

func _process(delta: float) -> void:
	if _pulsing:
		_pulse_t += delta * 6.0
		var a: float = 0.6 + 0.4 * sin(_pulse_t)
		hp_bar.modulate = Color(1, a, a, 1)
	else:
		hp_bar.modulate = Color.WHITE

func set_hp(cur: int, max_: int) -> void:
	hp_bar.max_value = max(1, max_)
	hp_bar.value = cur
	var ratio: float = float(cur) / float(max(1, max_))
	_pulsing = ratio < 0.3

func set_mp(cur: int, max_: int) -> void:
	mp_bar.max_value = max(1, max_)
	mp_bar.value = cur

func set_depth(d: int) -> void:
	depth_label.text = "B%dF" % d

func set_weapon_skill_info(skill_display_name: String, level: int, xp_cur: float, xp_max: float) -> void:
	if weapon_skill_label == null:
		return
	if skill_display_name == "":
		weapon_skill_label.text = "장착: 맨손"
		return
	if level >= 27:
		weapon_skill_label.text = "장착: %s (MASTER)" % skill_display_name
	else:
		weapon_skill_label.text = "장착: %s (Lv.%d, %d/%d XP)" % [
			skill_display_name, level, int(xp_cur), int(xp_max),
		]
