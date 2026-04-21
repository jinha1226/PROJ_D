class_name UICards
extends Object

const GOLD := Color(1.0, 0.85, 0.40)
const HINT := Color(0.78, 0.78, 0.85)
const ACCENT_GOLD := Color(0.85, 0.72, 0.30)


static func section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", GOLD)
	return lbl


static func card(tint: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.15, tint.g * 0.15, tint.b * 0.15, 0.8)
	sb.border_color = tint
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	return panel


static func accent_value(text: String, size: int = 42) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	return lbl


static func dim_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.modulate = HINT
	return lbl


static func pill(text: String, tint: Color) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.25, tint.g * 0.25, tint.b * 0.25, 0.9)
	sb.border_color = tint
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", tint)
	panel.add_child(lbl)
	return panel


const SCHOOL_COLOURS := {
	"conjurations": Color(0.95, 0.95, 1.00),
	"hexes":        Color(0.75, 0.50, 1.00),
	"charms":       Color(1.00, 0.65, 0.85),
	"necromancy":   Color(0.60, 0.30, 0.70),
	"summonings":   Color(0.50, 0.95, 0.55),
	"translocations": Color(0.55, 1.00, 0.85),
	"fire":         Color(1.00, 0.55, 0.25),
	"ice":          Color(0.55, 0.85, 1.00),
	"earth":        Color(0.75, 0.55, 0.30),
	"air":          Color(0.70, 0.85, 1.00),
	"poison":       Color(0.75, 0.95, 0.35),
}


static func school_colour(school: String) -> Color:
	return SCHOOL_COLOURS.get(school, Color(0.70, 0.70, 0.70))
