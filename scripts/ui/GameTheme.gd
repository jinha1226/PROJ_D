class_name GameTheme
extends Node

## Typography scale — single source of truth for dialog font sizes.
## Use these constants instead of hardcoded numbers in `add_theme_font_size_override`.
## Mobile target: body 20-24, title 28-32, caption 16-18 (4.5:1 contrast assumed
## via theme colors). Scale up by ≥2 between adjacent levels to keep hierarchy
## clear at small phone sizes.
##
## Usage:
##   lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
const TYPO_CAPTION: int = 18      # tips, hints, fine-print
const TYPO_BODY: int = 22         # default running text, descriptions
const TYPO_BODY_LARGE: int = 24   # action button labels, prominent values
const TYPO_LABEL: int = 26        # row item names (bag entries, etc.)
const TYPO_SUBTITLE: int = 28     # row entity names with hierarchy (skill name)
const TYPO_TITLE: int = 30        # dialog content headings, player name
const TYPO_HEADER: int = 32       # top-of-dialog headers (matches default theme size)
const TYPO_DISPLAY: int = 36      # large glyphs, hero counts

## Tap-target sizing — Android Material guideline is 48dp minimum.
## At 720×1280 viewport on phone, 1px ≈ 1dp.
const TAP_MIN_HEIGHT: int = 48
const ROW_MIN_HEIGHT: int = 56    # list rows (more comfortable than min tap)

## Layout spacing — keep dialog padding/separation consistent.
const PAD_S: int = 4
const PAD_M: int = 8
const PAD_L: int = 12
const PAD_XL: int = 16

static func create() -> Theme:
	var theme := Theme.new()

	# Colors
	var bg_dark := Color(0.08, 0.07, 0.12, 0.95)
	var bg_panel := Color(0.12, 0.11, 0.18, 0.95)
	var border_color := Color(0.45, 0.35, 0.2, 0.8)
	var gold := Color(0.85, 0.72, 0.3)
	var text_color := Color(0.92, 0.9, 0.82)
	var text_dim := Color(0.6, 0.58, 0.52)
	var accent := Color(0.4, 0.65, 0.9)

	# --- Button styles ---
	var btn_normal := StyleBoxFlat.new()
	btn_normal.bg_color = Color(0.15, 0.13, 0.22, 0.9)
	btn_normal.border_width_left = 2
	btn_normal.border_width_right = 2
	btn_normal.border_width_top = 2
	btn_normal.border_width_bottom = 2
	btn_normal.border_color = border_color
	btn_normal.corner_radius_top_left = 6
	btn_normal.corner_radius_top_right = 6
	btn_normal.corner_radius_bottom_left = 6
	btn_normal.corner_radius_bottom_right = 6
	btn_normal.content_margin_left = 12
	btn_normal.content_margin_right = 12
	btn_normal.content_margin_top = 8
	btn_normal.content_margin_bottom = 8
	theme.set_stylebox("normal", "Button", btn_normal)

	var btn_hover := btn_normal.duplicate()
	btn_hover.bg_color = Color(0.2, 0.18, 0.3, 0.95)
	btn_hover.border_color = gold
	theme.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn_normal.duplicate()
	btn_pressed.bg_color = Color(0.25, 0.2, 0.1, 0.95)
	btn_pressed.border_color = Color(1.0, 0.85, 0.4)
	theme.set_stylebox("pressed", "Button", btn_pressed)

	var btn_disabled := btn_normal.duplicate()
	btn_disabled.bg_color = Color(0.1, 0.1, 0.12, 0.7)
	btn_disabled.border_color = Color(0.3, 0.3, 0.3, 0.5)
	theme.set_stylebox("disabled", "Button", btn_disabled)

	var btn_focus := btn_normal.duplicate()
	btn_focus.border_color = accent
	theme.set_stylebox("focus", "Button", btn_focus)

	theme.set_color("font_color", "Button", text_color)
	theme.set_color("font_hover_color", "Button", gold)
	theme.set_color("font_pressed_color", "Button", Color(1.0, 0.9, 0.5))
	theme.set_color("font_disabled_color", "Button", text_dim)

	# --- CheckBox ---
	theme.set_color("font_color", "CheckBox", text_color)
	theme.set_color("font_hover_color", "CheckBox", gold)

	# --- Panel ---
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = bg_panel
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = border_color
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	theme.set_stylebox("panel", "Panel", panel_style)
	theme.set_stylebox("panel", "PanelContainer", panel_style)

	# --- AcceptDialog / Window ---
	var window_panel := StyleBoxFlat.new()
	window_panel.bg_color = Color(0.06, 0.05, 0.1, 0.97)
	window_panel.border_width_left = 3
	window_panel.border_width_right = 3
	window_panel.border_width_top = 3
	window_panel.border_width_bottom = 3
	window_panel.border_color = Color(0.5, 0.4, 0.25, 0.9)
	window_panel.corner_radius_top_left = 10
	window_panel.corner_radius_top_right = 10
	window_panel.corner_radius_bottom_left = 10
	window_panel.corner_radius_bottom_right = 10
	window_panel.content_margin_left = 16
	window_panel.content_margin_right = 16
	window_panel.content_margin_top = 12
	window_panel.content_margin_bottom = 12
	theme.set_stylebox("embedded_border", "Window", window_panel)
	theme.set_stylebox("panel", "AcceptDialog", window_panel)

	# --- Label ---
	theme.set_color("font_color", "Label", text_color)

	# --- HSeparator ---
	var sep_style := StyleBoxFlat.new()
	sep_style.bg_color = Color(0.4, 0.35, 0.25, 0.5)
	sep_style.content_margin_top = 4
	sep_style.content_margin_bottom = 4
	theme.set_stylebox("separator", "HSeparator", sep_style)

	# --- ScrollContainer scrollbar ---
	var scroll_bg := StyleBoxFlat.new()
	scroll_bg.bg_color = Color(0.1, 0.1, 0.15, 0.5)
	scroll_bg.content_margin_left = 4
	scroll_bg.content_margin_right = 4
	theme.set_stylebox("scroll", "VScrollBar", scroll_bg)

	var scroll_grabber := StyleBoxFlat.new()
	scroll_grabber.bg_color = Color(0.4, 0.35, 0.25, 0.8)
	scroll_grabber.corner_radius_top_left = 4
	scroll_grabber.corner_radius_top_right = 4
	scroll_grabber.corner_radius_bottom_left = 4
	scroll_grabber.corner_radius_bottom_right = 4
	theme.set_stylebox("grabber", "VScrollBar", scroll_grabber)

	var scroll_grabber_hl := scroll_grabber.duplicate()
	scroll_grabber_hl.bg_color = gold
	theme.set_stylebox("grabber_highlight", "VScrollBar", scroll_grabber_hl)

	# --- ProgressBar ---
	var prog_bg := StyleBoxFlat.new()
	prog_bg.bg_color = Color(0.1, 0.1, 0.15)
	prog_bg.corner_radius_top_left = 3
	prog_bg.corner_radius_top_right = 3
	prog_bg.corner_radius_bottom_left = 3
	prog_bg.corner_radius_bottom_right = 3
	theme.set_stylebox("background", "ProgressBar", prog_bg)

	var prog_fill := StyleBoxFlat.new()
	prog_fill.bg_color = accent
	prog_fill.corner_radius_top_left = 3
	prog_fill.corner_radius_top_right = 3
	prog_fill.corner_radius_bottom_left = 3
	prog_fill.corner_radius_bottom_right = 3
	theme.set_stylebox("fill", "ProgressBar", prog_fill)

	return theme
