extends Node
## Manages the project default font (used by theme.tres). Persists choice in
## the same settings.cfg used by LocaleManager. Mutates the loaded theme
## resource at runtime so all UI updates immediately.

const CONFIG_PATH: String = "user://settings.cfg"
const SECTION: String = "ui"
const KEY_FONT: String = "font_id"
const DEFAULT_FONT_ID: String = "galmuri11"

const FONTS: Array = [
	{"id": "galmuri11", "name": "Galmuri11", "path": "res://assets/fonts/Galmuri11.ttf"},
	{"id": "galmuri9",  "name": "Galmuri9",  "path": "res://assets/fonts/Galmuri9.ttf"},
	{"id": "galmuri7",  "name": "Galmuri7",  "path": "res://assets/fonts/Galmuri7.ttf"},
	{"id": "neodgm",    "name": "Neodgm",    "path": "res://assets/fonts/Neodgm.ttf"},
]

const THEME_PATH: String = "res://assets/theme.tres"

signal font_changed(font_id: String)

var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	_config.load(CONFIG_PATH)
	var saved: String = String(_config.get_value(SECTION, KEY_FONT, DEFAULT_FONT_ID))
	apply(saved, false)

func current_font_id() -> String:
	return String(_config.get_value(SECTION, KEY_FONT, DEFAULT_FONT_ID))

func font_path(font_id: String) -> String:
	for f in FONTS:
		if String(f.id) == font_id:
			return String(f.path)
	return ""

func font_name(font_id: String) -> String:
	for f in FONTS:
		if String(f.id) == font_id:
			return String(f.name)
	return font_id

func font_resource(font_id: String):
	var path: String = font_path(font_id)
	if path == "":
		return null
	return load(path)

## Apply a font choice. `persist=true` saves to disk; pass false during boot
## or for preview-only flips.
func apply(font_id: String, persist: bool = true) -> void:
	var font_res = font_resource(font_id)
	if font_res == null:
		return
	var theme: Theme = load(THEME_PATH) as Theme
	if theme == null:
		return
	theme.default_font = font_res
	if persist:
		_config.set_value(SECTION, KEY_FONT, font_id)
		_config.save(CONFIG_PATH)
	font_changed.emit(font_id)
