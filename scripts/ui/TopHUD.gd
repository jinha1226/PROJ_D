extends Control
class_name TopHUD

signal minimap_pressed
signal zoom_in_pressed
signal zoom_out_pressed
signal item_slot_pressed(index: int)

@onready var hp_bar: ProgressBar = $MainMargin/MainVBox/TopRow/Bars/HPRow/HPBar
@onready var hp_label: Label = $MainMargin/MainVBox/TopRow/Bars/HPRow/HPLabel
@onready var mp_bar: ProgressBar = $MainMargin/MainVBox/TopRow/Bars/MPRow/MPBar
@onready var mp_label: Label = $MainMargin/MainVBox/TopRow/Bars/MPRow/MPLabel
@onready var xp_bar: ProgressBar = $MainMargin/MainVBox/TopRow/Bars/XPRow/XPBar
@onready var xp_label: Label = $MainMargin/MainVBox/TopRow/Bars/XPRow/XPLabel
@onready var minimap_button: Button = $MainMargin/MainVBox/TopRow/MinimapCol/MinimapButton
@onready var depth_label: Label = $MainMargin/MainVBox/TopRow/MinimapCol/DepthLabel
@onready var level_label: Label = $MainMargin/MainVBox/TopRow/Bars/StatsRow/LevelLabel
@onready var gold_label: Label = $MainMargin/MainVBox/TopRow/Bars/StatsRow/GoldLabel
@onready var turn_label: Label = $MainMargin/MainVBox/TopRow/Bars/StatsRow/TurnLabel
@onready var zoom_in_button: Button = $MainMargin/MainVBox/TopRow/Bars/StatsRow/ZoomInButton
@onready var zoom_out_button: Button = $MainMargin/MainVBox/TopRow/Bars/StatsRow/ZoomOutButton
@onready var rune_row: HBoxContainer = $MainMargin/MainVBox/RuneRow
@onready var item_slots: Array = [
    $MainMargin/MainVBox/ItemRow/ItemSlot0,
    $MainMargin/MainVBox/ItemRow/ItemSlot1,
    $MainMargin/MainVBox/ItemRow/ItemSlot2,
    $MainMargin/MainVBox/ItemRow/ItemSlot3,
    $MainMargin/MainVBox/ItemRow/ItemSlot4,
    $MainMargin/MainVBox/ItemRow/ItemSlot5,
    $MainMargin/MainVBox/ItemRow/ItemSlot6,
    $MainMargin/MainVBox/ItemRow/ItemSlot7,
]

var _pulse_t: float = 0.0
var _pulsing: bool = false
var _buff_row: HFlowContainer = null
var _hp_max_val: int = 1


func _ready() -> void:
    if minimap_button != null:
        minimap_button.pressed.connect(func(): minimap_pressed.emit())
    if zoom_in_button != null:
        zoom_in_button.pressed.connect(func(): zoom_in_pressed.emit())
    if zoom_out_button != null:
        zoom_out_button.pressed.connect(func(): zoom_out_pressed.emit())
    var bars: VBoxContainer = get_node_or_null("MainMargin/MainVBox/TopRow/Bars")
    if bars != null:
        _buff_row = HFlowContainer.new()
        _buff_row.add_theme_constant_override("h_separation", 6)
        _buff_row.add_theme_constant_override("v_separation", 2)
        bars.add_child(_buff_row)
    for i in item_slots.size():
        var qs = item_slots[i]
        qs.slot_index = i
        if qs.has_signal("pressed_slot"):
            qs.pressed_slot.connect(func(idx): item_slot_pressed.emit(idx))


func _process(delta: float) -> void:
    if _pulsing:
        _pulse_t += delta * 6.0
        var a: float = 0.6 + 0.4 * sin(_pulse_t)
        hp_bar.modulate = Color(1, a, a, 1)
    else:
        hp_bar.modulate = Color.WHITE


func set_hp(cur: int, max_: int) -> void:
    _hp_max_val = max(1, max_)
    hp_bar.max_value = _hp_max_val
    hp_bar.value = cur
    if hp_label:
        hp_label.text = "HP %d/%d" % [cur, max_]
    var ratio: float = float(cur) / float(_hp_max_val)
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


func set_runes(player_items: Array) -> void:
    if rune_row == null:
        return
    for c in rune_row.get_children():
        c.queue_free()
    var rune_entries: Array = []
    for entry in player_items:
        var d = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
        if d != null and d.kind == "rune":
            rune_entries.append(d)
    rune_row.visible = not rune_entries.is_empty()
    for d in rune_entries:
        var container := Control.new()
        container.custom_minimum_size = Vector2(32, 32)
        if d.tile_path != "" and ResourceLoader.exists(d.tile_path):
            var rect := TextureRect.new()
            rect.texture = load(d.tile_path) as Texture2D
            rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
            rect.anchor_right = 1.0
            rect.anchor_bottom = 1.0
            rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
            container.add_child(rect)
        var tooltip_lbl := Label.new()
        tooltip_lbl.text = d.display_name
        tooltip_lbl.tooltip_text = d.display_name
        tooltip_lbl.visible = false
        container.add_child(tooltip_lbl)
        rune_row.add_child(container)


func set_item_slot(i: int, icon: Texture2D, text: String) -> void:
    if i >= 0 and i < item_slots.size():
        item_slots[i].set_item(icon, text)


func set_item_slot_display(i: int, txt: String, color: Color) -> void:
    if i >= 0 and i < item_slots.size():
        item_slots[i].set_slot_display(txt, color)


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
    lbl.add_theme_font_size_override("font_size", 15)
    lbl.add_theme_color_override("font_color", col)
    panel.add_child(lbl)
    return panel


func set_weapon_skill_info(_a: String, _b: int, _c: float, _d: float) -> void:
    pass
