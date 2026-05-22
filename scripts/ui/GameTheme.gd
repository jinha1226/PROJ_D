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
# Sizes are Galmuri11 multiples (11/22/33/44) for clean pixel-grid alignment.
# Off-multiple sizes produce slight aliasing on the pixel font — accept it for
# fine-print only. Hierarchy via color/weight/spacing where size collapses.
const TYPO_CAPTION: int = 22      # tips, hints, fine-print (was 18)
const TYPO_BODY: int = 22         # default running text, descriptions (2x)
const TYPO_BODY_LARGE: int = 22   # action button labels, prominent values
const TYPO_LABEL: int = 22        # row item names (bag entries, etc.)
const TYPO_SUBTITLE: int = 33     # row entity names with hierarchy (3x)
const TYPO_TITLE: int = 33        # dialog content headings, player name
const TYPO_HEADER: int = 33       # top-of-dialog headers
const TYPO_DISPLAY: int = 44      # large glyphs, hero counts (4x)

## Tap-target sizing — Android Material guideline is 48dp minimum.
## At 720×1280 viewport on phone, 1px ≈ 1dp.
const TAP_MIN_HEIGHT: int = 48
const ROW_MIN_HEIGHT: int = 56    # list rows (more comfortable than min tap)

## Layout spacing — keep dialog padding/separation consistent.
const PAD_S: int = 4
const PAD_M: int = 8
const PAD_L: int = 12
const PAD_XL: int = 16

## Static path to the master theme. Edit visuals there; this file holds only
## the layout/typography token constants and the loader entry point.
const THEME_PATH: String = "res://assets/theme.tres"
const UI_PIXEL_DIR: String = "res://assets/ui/pixel"

static func create() -> Theme:
	# Duplicate the base theme before adding generated StyleBoxTexture assets so
	# callers can still apply local overrides without mutating the master theme.
	var base := load(THEME_PATH) as Theme
	var themed := base.duplicate(true) as Theme
	_apply_pixel_skin(themed)
	return themed


static func apply_button_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_box("button_normal", 8, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("hover", _make_box("button_hover", 8, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("pressed", _make_box("button_pressed", 8, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("disabled", _make_box("button_disabled", 8, Vector4(12, 8, 12, 8)))
	button.add_theme_stylebox_override("focus", _make_box("button_hover", 8, Vector4(12, 8, 12, 8)))


static func apply_slot_style(button: Button) -> void:
	if button == null:
		return
	button.add_theme_stylebox_override("normal", _make_box("slot_normal", 8, Vector4(8, 8, 8, 8)))
	button.add_theme_stylebox_override("hover", _make_box("slot_hover", 8, Vector4(8, 8, 8, 8)))
	button.add_theme_stylebox_override("pressed", _make_box("slot_pressed", 8, Vector4(8, 8, 8, 8)))
	button.add_theme_stylebox_override("disabled", _make_box("slot_disabled", 8, Vector4(8, 8, 8, 8)))
	button.add_theme_stylebox_override("focus", _make_box("slot_hover", 8, Vector4(8, 8, 8, 8)))


static func apply_panel_style(panel: Control) -> void:
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _make_box("panel_window", 10, Vector4(16, 14, 16, 14)))


static func _apply_pixel_skin(theme: Theme) -> void:
	theme.set_color("font_color", "Button", Color(0.96, 0.96, 0.86, 1.0))
	theme.set_color("font_hover_color", "Button", Color(1.0, 0.96, 0.45, 1.0))
	theme.set_color("font_pressed_color", "Button", Color(0.82, 0.9, 0.72, 1.0))
	theme.set_color("font_disabled_color", "Button", Color(0.48, 0.50, 0.45, 1.0))
	theme.set_color("font_color", "Label", Color(0.92, 0.92, 0.84, 1.0))
	theme.set_stylebox("normal", "Button", _make_box("button_normal", 8, Vector4(12, 8, 12, 8)))
	theme.set_stylebox("hover", "Button", _make_box("button_hover", 8, Vector4(12, 8, 12, 8)))
	theme.set_stylebox("pressed", "Button", _make_box("button_pressed", 8, Vector4(12, 8, 12, 8)))
	theme.set_stylebox("disabled", "Button", _make_box("button_disabled", 8, Vector4(12, 8, 12, 8)))
	theme.set_stylebox("focus", "Button", _make_box("button_hover", 8, Vector4(12, 8, 12, 8)))
	theme.set_stylebox("panel", "Panel", _make_box("panel_window", 10, Vector4(16, 14, 16, 14)))
	theme.set_stylebox("panel", "PanelContainer", _make_box("panel_window", 10, Vector4(16, 14, 16, 14)))
	theme.set_stylebox("panel", "AcceptDialog", _make_box("panel_window", 10, Vector4(16, 14, 16, 14)))


static func _make_box(name: String, margin: int, content: Vector4) -> StyleBoxTexture:
	var box := StyleBoxTexture.new()
	box.texture = _load_pixel_texture("%s/%s.png" % [UI_PIXEL_DIR, name])
	box.texture_margin_left = margin
	box.texture_margin_top = margin
	box.texture_margin_right = margin
	box.texture_margin_bottom = margin
	box.content_margin_left = content.x
	box.content_margin_top = content.y
	box.content_margin_right = content.z
	box.content_margin_bottom = content.w
	return box


static func _load_pixel_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var image := Image.new()
	var err := image.load(ProjectSettings.globalize_path(path))
	if err != OK:
		push_warning("Pixel UI texture missing: %s" % path)
		return null
	return ImageTexture.create_from_image(image)
