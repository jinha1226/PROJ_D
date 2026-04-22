extends Control
class_name TopHUD

@onready var hp_bar: ProgressBar = $Margin/HBox/Bars/HPRow/HPBar
@onready var hp_label: Label = $Margin/HBox/Bars/HPRow/HPLabel
@onready var mp_bar: ProgressBar = $Margin/HBox/Bars/MPRow/MPBar
@onready var mp_label: Label = $Margin/HBox/Bars/MPRow/MPLabel
@onready var xp_bar: ProgressBar = $Margin/HBox/Bars/XPRow/XPBar
@onready var xp_label: Label = $Margin/HBox/Bars/XPRow/XPLabel
@onready var minimap_button: Button = $Margin/HBox/MinimapButton

signal minimap_pressed

var _pulse_t: float = 0.0
var _pulsing: bool = false
var _depth: int = 1
var _level: int = 1
var _gold: int = 0
var _branch_label: String = "Dungeon"


func _ready() -> void:
	minimap_button.pressed.connect(func(): minimap_pressed.emit())


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
	if hp_label:
		hp_label.text = "HP %d / %d" % [cur, max_]
	var ratio: float = float(cur) / float(max(1, max_))
	_pulsing = ratio < 0.3


func set_mp(cur: int, max_: int) -> void:
	mp_bar.max_value = max(1, max_)
	mp_bar.value = cur
	if mp_label:
		mp_label.text = "MP %d / %d" % [cur, max_]


func set_xp(cur: int, to_next: int, level: int) -> void:
	_level = level
	xp_bar.max_value = max(1, to_next)
	xp_bar.value = cur
	_update_xp_label()


func set_depth(d: int) -> void:
	_depth = d
	_update_xp_label()


## Set the short branch label alongside depth so the header reads
## "Lv.N  Temple:1  X$" instead of a bare "BNF". Caller passes a short
## zone/branch id string for the current map.
func set_branch(label: String) -> void:
	if label == "":
		label = "Dungeon"
	_branch_label = label
	_update_xp_label()


func set_location(branch_label: String, d: int) -> void:
	_branch_label = branch_label if branch_label != "" else "Dungeon"
	_depth = d
	_update_xp_label()


func set_gold(g: int) -> void:
	_gold = g
	_update_xp_label()


func _update_xp_label() -> void:
	if xp_label:
		xp_label.text = "Lv.%d  %s:%d  %d$" % [_level, _branch_label, _depth, _gold]


## GameBootstrap feeds the rebuilt minimap ImageTexture in here whenever
## the player moves or reveals new tiles.
func set_minimap_texture(tex: Texture2D) -> void:
	if minimap_button:
		minimap_button.icon = tex


# Compatibility stub — WeaponSkillLabel used to live here; the Status
# popup owns that info now. Left so existing GameBootstrap callers don't crash.
func set_weapon_skill_info(_skill_display_name: String, _level: int, _xp_cur: float, _xp_max: float) -> void:
	pass
