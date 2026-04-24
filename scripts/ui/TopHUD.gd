extends Control
class_name TopHUD

@onready var hp_bar: ProgressBar = $Margin/HBox/Bars/HPRow/HPBar
@onready var hp_label: Label = $Margin/HBox/Bars/HPRow/HPLabel
@onready var mp_bar: ProgressBar = $Margin/HBox/Bars/MPRow/MPBar
@onready var mp_label: Label = $Margin/HBox/Bars/MPRow/MPLabel
@onready var xp_bar: ProgressBar = $Margin/HBox/Bars/XPRow/XPBar
@onready var xp_label: Label = $Margin/HBox/Bars/XPRow/XPLabel
@onready var minimap_button: Button = $Margin/HBox/MinimapCol/MinimapButton
@onready var depth_label: Label = $Margin/HBox/MinimapCol/DepthLabel
@onready var level_label: Label = $Margin/HBox/Bars/StatsRow/LevelLabel
@onready var gold_label: Label = $Margin/HBox/Bars/StatsRow/GoldLabel
@onready var turn_label: Label = $Margin/HBox/Bars/StatsRow/TurnLabel
@onready var zoom_in_button: Button = $Margin/HBox/Bars/StatsRow/ZoomInButton
@onready var zoom_out_button: Button = $Margin/HBox/Bars/StatsRow/ZoomOutButton

signal minimap_pressed
signal zoom_in_pressed
signal zoom_out_pressed

var _pulse_t: float = 0.0
var _pulsing: bool = false
var _buff_row: HFlowContainer = null


func _ready() -> void:
	if minimap_button != null:
		minimap_button.pressed.connect(func(): minimap_pressed.emit())
	if zoom_in_button != null:
		zoom_in_button.pressed.connect(func(): zoom_in_pressed.emit())
	if zoom_out_button != null:
		zoom_out_button.pressed.connect(func(): zoom_out_pressed.emit())
	var bars: VBoxContainer = get_node_or_null("Margin/HBox/Bars")
	if bars != null:
		_buff_row = HFlowContainer.new()
		_buff_row.add_theme_constant_override("h_separation", 6)
		_buff_row.add_theme_constant_override("v_separation", 2)
		bars.add_child(_buff_row)


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
		hp_label.text = "HP %d/%d" % [cur, max_]
	var ratio: float = float(cur) / float(max(1, max_))
	_pulsing = ratio < 0.3


func set_mp(cur: int, max_: int) -> void:
	mp_bar.max_value = max(1, max_)
	mp_bar.value = cur
	if mp_label:
		mp_label.text = "MP %d/%d" % [cur, max_]


func set_xp(cur: int, to_next: int, level: int) -> void:
	xp_bar.max_value = max(1, to_next)
	xp_bar.value = cur
	if xp_label:
		xp_label.text = "XP %d/%d" % [cur, to_next]
	if level_label:
		level_label.text = "Lv.%d" % level


func set_gold(g: int) -> void:
	if gold_label:
		gold_label.text = "%dg" % g


func set_turn(t: int) -> void:
	if turn_label:
		turn_label.text = "T:%d" % t


func set_depth(d: int) -> void:
	_update_depth_label(d)


func set_branch(label: String) -> void:
	_update_depth_label(-1, label)


func set_location(branch_label: String, d: int) -> void:
	_update_depth_label(d, branch_label)


func _update_depth_label(d: int = -1, branch: String = "") -> void:
	if depth_label == null:
		return
	var b := branch if branch != "" else depth_label.text.split(":")[0]
	if b == "":
		b = "Dungeon"
	if d >= 0:
		depth_label.text = "%s:%d" % [b, d]
	else:
		depth_label.text = b


func set_minimap_texture(tex: Texture2D) -> void:
	if minimap_button:
		minimap_button.icon = tex


func set_buffs(statuses: Dictionary) -> void:
	if _buff_row == null:
		return
	for c in _buff_row.get_children():
		c.queue_free()
	for sid in statuses.keys():
		var turns: int = int(statuses[sid])
		if turns <= 0:
			continue
		var info: Dictionary = Status.INFO.get(sid, {})
		var col: Color = info.get("color", Color(0.7, 0.7, 0.8))
		var label_text: String = info.get("name", sid.capitalize())
		var badge := _make_buff_badge(label_text, turns, col)
		_buff_row.add_child(badge)


static func _make_buff_badge(label: String, turns: int, col: Color) -> Control:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(col.r, col.g, col.b, 0.25)
	style.border_color = col
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var lbl := Label.new()
	lbl.text = "%s %d" % [label, turns]
	lbl.add_theme_font_size_override("font_size", 17)
	lbl.add_theme_color_override("font_color", col)
	panel.add_child(lbl)
	return panel


# Compatibility stubs
func set_weapon_skill_info(_a: String, _b: int, _c: float, _d: float) -> void:
	pass
