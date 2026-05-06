extends Node
## Loads translations.csv at startup and registers with TranslationServer.
## Persists locale choice via UserDefault config so it survives runs.
## Default locale is "ko" (Korean) per project decision 2026-05-06.

const CSV_PATH: String = "res://i18n/translations.csv"
const CONFIG_PATH: String = "user://settings.cfg"
const SECTION: String = "i18n"
const KEY_LOCALE: String = "locale"
const DEFAULT_LOCALE: String = "ko"
const SUPPORTED_LOCALES: Array = ["ko", "en"]

signal locale_changed(locale: String)

var _config: ConfigFile

func _ready() -> void:
	_config = ConfigFile.new()
	_config.load(CONFIG_PATH)
	_load_translations()
	var saved: String = String(_config.get_value(SECTION, KEY_LOCALE, DEFAULT_LOCALE))
	if not SUPPORTED_LOCALES.has(saved):
		saved = DEFAULT_LOCALE
	TranslationServer.set_locale(saved)

func current_locale() -> String:
	return TranslationServer.get_locale()

func set_locale(locale: String) -> void:
	if not SUPPORTED_LOCALES.has(locale):
		return
	if locale == TranslationServer.get_locale():
		return
	TranslationServer.set_locale(locale)
	_config.set_value(SECTION, KEY_LOCALE, locale)
	_config.save(CONFIG_PATH)
	locale_changed.emit(locale)

func display_name(locale: String) -> String:
	match locale:
		"ko": return "한국어"
		"en": return "English"
	return locale

## Reads translations.csv (UTF-8, comma-separated) and builds one Translation
## resource per locale column. CSV header layout: `keys,en,ko` (any order
## after the first column, which must be `keys`).
func _load_translations() -> void:
	var f := FileAccess.open(CSV_PATH, FileAccess.READ)
	if f == null:
		push_warning("LocaleManager: translations.csv not found at %s" % CSV_PATH)
		return
	var header: PackedStringArray = f.get_csv_line()
	if header.size() < 2 or String(header[0]) != "keys":
		push_warning("LocaleManager: bad CSV header — expected 'keys' first column")
		f.close()
		return
	# One Translation resource per locale column.
	var translations: Array = []
	for i in range(1, header.size()):
		var t := Translation.new()
		t.locale = String(header[i])
		translations.append(t)
	while not f.eof_reached():
		var row: PackedStringArray = f.get_csv_line()
		if row.size() < 2:
			continue
		var key: String = String(row[0]).strip_edges()
		if key == "":
			continue
		for i in range(min(translations.size(), row.size() - 1)):
			var msg: String = String(row[i + 1])
			if msg != "":
				translations[i].add_message(key, msg)
	f.close()
	for t in translations:
		TranslationServer.add_translation(t)
