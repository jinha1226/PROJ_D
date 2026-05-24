class_name OptionsDialog extends RefCounted

## Settings modal — accessible from MainMenu and PauseMenu. Two sections:
##   Language: pick a locale (ko / en). Live switch via TranslationServer.
##   Font: pick a pixel font. Each row renders in its own font + name label
##         in default Galmuri11 so users can compare without committing.
## Each tap is final — no separate Apply button. The dialog auto-rebuilds
## visible labels (which are TranslationServer.translate()-driven) on locale change.

static func open(parent: Node, on_locale_changed: Callable = Callable()) -> void:
	var dlg: GameDialog = GameDialog.create_ratio(TranslationServer.translate("OPTIONS_TITLE"), 0.92, 0.92)
	parent.add_child(dlg)
	_populate(dlg, on_locale_changed)

static func _populate(dlg: GameDialog, on_locale_changed: Callable) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", GameTheme.PAD_XL)

	# ── Language section ─────────────────────────────────────────────────
	body.add_child(_section_header(TranslationServer.translate("OPTIONS_LANGUAGE")))
	var lang_row := HBoxContainer.new()
	lang_row.add_theme_constant_override("separation", GameTheme.PAD_M)
	body.add_child(lang_row)
	for locale in LocaleManager.SUPPORTED_LOCALES:
		var btn := _make_lang_button(String(locale))
		lang_row.add_child(btn)
		btn.pressed.connect(func() -> void:
			LocaleManager.set_locale(String(locale))
			# Rebuild this dialog body so all TranslationServer.translate() labels refresh.
			_populate(dlg, on_locale_changed)
			if on_locale_changed.is_valid():
				on_locale_changed.call())

	# ── Combat mode section ──────────────────────────────────────────────
	body.add_child(_section_header("전투 방식"))
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", GameTheme.PAD_M)
	body.add_child(mode_row)
	for mode_info in [["턴제", false], ["실시간", true]]:
		var mode_label: String = String(mode_info[0])
		var mode_val: bool = bool(mode_info[1])
		var mbtn := Button.new()
		mbtn.text = mode_label
		mbtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		mbtn.custom_minimum_size = Vector2(0, GameTheme.TAP_MIN_HEIGHT)
		mbtn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
		if GameManager.use_rt_mode == mode_val:
			mbtn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		mode_row.add_child(mbtn)
		mbtn.pressed.connect(func() -> void:
			if GameManager.use_rt_mode != mode_val:
				GameManager.toggle_rt_mode()
				# Apply immediately if a RealTimeController exists in the running scene.
				var scene: Node = Engine.get_main_loop().current_scene
				var rt_ctrl: Node = scene.get_node_or_null("RealTimeController") if scene != null else null
				if rt_ctrl != null and rt_ctrl.has_method("_toggle_rt_mode"):
					rt_ctrl._toggle_rt_mode()
			_populate(dlg, on_locale_changed))

	# ── Font section ─────────────────────────────────────────────────────
	body.add_child(_section_header(TranslationServer.translate("OPTIONS_FONT")))
	for font_def in FontManager.FONTS:
		body.add_child(_make_font_row(font_def, dlg, on_locale_changed))

static func _section_header(text: String) -> Control:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	lbl.add_theme_color_override("font_color", Color(0.94, 0.84, 0.42))
	return lbl

static func _make_lang_button(locale: String) -> Button:
	var btn := Button.new()
	btn.text = LocaleManager.display_name(locale)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, GameTheme.TAP_MIN_HEIGHT)
	btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	if LocaleManager.current_locale() == locale:
		btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	return btn

## Font row: name label rendered in target font + sample text in target font.
## Tap anywhere to apply.
static func _make_font_row(font_def: Dictionary, dlg: GameDialog,
		on_locale_changed: Callable) -> Control:
	var btn := Button.new()
	btn.flat = true
	btn.toggle_mode = false
	btn.text = ""
	btn.custom_minimum_size = Vector2(0, 96)

	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.add_theme_constant_override("separation", GameTheme.PAD_L)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(hb)

	# Selection check
	var check := Label.new()
	check.custom_minimum_size = Vector2(28, 0)
	check.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	check.text = "●" if FontManager.current_font_id() == String(font_def.id) else ""
	check.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	hb.add_child(check)

	# Name + sample column
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(col)

	var font_res = FontManager.font_resource(String(font_def.id))

	var name_lbl := Label.new()
	name_lbl.text = String(font_def.name)
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	if font_res != null:
		name_lbl.add_theme_font_override("font", font_res)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(name_lbl)

	var sample := Label.new()
	sample.text = TranslationServer.translate("OPTIONS_FONT_SAMPLE")
	sample.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	sample.add_theme_color_override("font_color", Color(0.78, 0.78, 0.82))
	if font_res != null:
		sample.add_theme_font_override("font", font_res)
	sample.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sample)

	btn.pressed.connect(func() -> void:
		FontManager.apply(String(font_def.id))
		# Re-populate so the selected dot moves to the picked row.
		_populate(dlg, on_locale_changed))

	return btn
