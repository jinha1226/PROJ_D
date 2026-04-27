extends CanvasLayer
class_name PopupManager

var SpellRegistry = null

# Minimal runtime popup manager. All popups are built from AcceptDialog / ConfirmationDialog
# created on demand; the Panel template in the .tscn exists as a reusable shell if needed.

func show_item_popup(item_name: String, desc: String, callbacks: Dictionary) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = item_name
	dlg.dialog_text = desc
	dlg.ok_button_text = "Take"
	dlg.add_cancel_button("Ignore")
	var use_btn: Button = dlg.add_button("Use", true, "use")
	add_child(dlg)
	dlg.confirmed.connect(func():
		if callbacks.has("pickup"): callbacks["pickup"].call()
		dlg.queue_free())
	dlg.canceled.connect(func():
		if callbacks.has("ignore"): callbacks["ignore"].call()
		dlg.queue_free())
	dlg.custom_action.connect(func(action: StringName):
		if action == &"use" and callbacks.has("use"): callbacks["use"].call()
		dlg.queue_free())
	dlg.popup_centered()

func show_essence_swap_popup(slot_index: int, current_id: String, inventory: Array, callback: Callable) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Swap Slot %d" % slot_index
	var vb := VBoxContainer.new()
	var cur := Label.new()
	cur.text = "Current: %s" % (current_id if current_id != "" else "(empty)")
	vb.add_child(cur)
	vb.add_child(HSeparator.new())
	for essence_id in inventory:
		var b := Button.new()
		b.text = EssenceSystem.display_name(String(essence_id))
		b.icon = EssenceSystem.icon_texture_of(String(essence_id))
		b.pressed.connect(func():
			if callback.is_valid(): callback.call(essence_id)
			dlg.queue_free())
		vb.add_child(b)
	var clear_btn := Button.new()
	clear_btn.text = "[Empty slot]"
	clear_btn.pressed.connect(func():
		if callback.is_valid(): callback.call("")
		dlg.queue_free())
	vb.add_child(clear_btn)
	dlg.add_child(vb)
	dlg.ok_button_text = "Cancel"
	add_child(dlg)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered(Vector2i(480, 600))

func show_essence_pickup_popup(essence_id: String, inventory: Array, cap: int, callbacks: Dictionary) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = EssenceSystem.display_name(essence_id)
	dlg.dialog_hide_on_ok = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	var icon := TextureRect.new()
	icon.texture = EssenceSystem.icon_texture_of(essence_id)
	icon.custom_minimum_size = Vector2(48, 48)
	icon.custom_maximum_size = Vector2(48, 48)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(icon)
	var desc := Label.new()
	desc.text = EssenceSystem.description(essence_id)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 24)
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(desc)
	vb.add_child(header)
	var inv := Label.new()
	inv.text = "Carried essences: %d / %d" % [inventory.size(), cap]
	inv.add_theme_font_size_override("font_size", 18)
	inv.add_theme_color_override("font_color", Color(0.68, 0.72, 0.8))
	vb.add_child(inv)
	if inventory.size() < cap:
		var take_btn := Button.new()
		take_btn.text = "Take"
		take_btn.custom_minimum_size = Vector2(0, 60)
		take_btn.pressed.connect(func():
			if callbacks.has("take"):
				callbacks["take"].call()
			dlg.queue_free())
		vb.add_child(take_btn)
	else:
		var full := Label.new()
		full.text = "Inventory full. Replace one carried essence or leave it behind."
		full.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		full.add_theme_font_size_override("font_size", 20)
		full.add_theme_color_override("font_color", Color(1.0, 0.76, 0.48))
		vb.add_child(full)
		for existing_id in inventory:
			var swap_btn := Button.new()
			swap_btn.text = "Replace %s" % EssenceSystem.display_name(String(existing_id))
			swap_btn.icon = EssenceSystem.icon_texture_of(String(existing_id))
			swap_btn.custom_minimum_size = Vector2(0, 56)
			swap_btn.pressed.connect(func():
				if callbacks.has("replace"):
					callbacks["replace"].call(String(existing_id))
				dlg.queue_free())
			vb.add_child(swap_btn)
	var leave_btn := Button.new()
	leave_btn.text = "Leave"
	leave_btn.custom_minimum_size = Vector2(0, 56)
	leave_btn.pressed.connect(func():
		if callbacks.has("leave"):
			callbacks["leave"].call()
		dlg.queue_free())
	vb.add_child(leave_btn)
	dlg.add_child(vb)
	dlg.get_ok_button().visible = false
	add_child(dlg)
	dlg.popup_centered(Vector2i(760, 720))

func show_levelup_popup(level: int, callback: Callable) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "LEVEL UP! Lv.%d" % level
	dlg.dialog_hide_on_ok = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	var lab := Label.new()
	lab.text = "Choose a stat bonus:"
	lab.add_theme_font_size_override("font_size", 40)
	vb.add_child(lab)
	for stat in ["STR", "DEX", "INT"]:
		var b := Button.new()
		b.text = "%s +1" % stat
		b.custom_minimum_size = Vector2(0, 96)
		b.add_theme_font_size_override("font_size", 44)
		b.pressed.connect(func():
			if callback.is_valid(): callback.call(stat)
			dlg.queue_free())
		vb.add_child(b)
	dlg.add_child(vb)
	dlg.get_ok_button().visible = false
	add_child(dlg)
	dlg.popup_centered(Vector2i(640, 620))

func show_spell_learn_popup(spell_level: int, spell_ids: Array, callback: Callable) -> void:
	if SpellRegistry == null:
		SpellRegistry = get_node_or_null("/root/SpellRegistry")
	var dlg := AcceptDialog.new()
	dlg.title = "Learn Spell Lv.%d" % spell_level
	dlg.dialog_hide_on_ok = false
	dlg.set_meta("chosen", false)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = "Choose one spell to memorize."
	lab.add_theme_font_size_override("font_size", 32)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(lab)
	for spell_id in spell_ids:
		var sid: String = String(spell_id)
		var spell: SpellData = SpellRegistry.get_by_id(sid)
		if spell == null:
			continue
		var b := Button.new()
		b.text = "%s  [%s]" % [spell.display_name, spell.school.capitalize()]
		b.custom_minimum_size = Vector2(0, 78)
		b.add_theme_font_size_override("font_size", 28)
		b.pressed.connect(func():
			dlg.set_meta("chosen", true)
			if callback.is_valid():
				callback.call(sid)
			dlg.queue_free())
		vb.add_child(b)
		var desc := Label.new()
		desc.text = spell.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 18)
		desc.add_theme_color_override("font_color", Color(0.7, 0.72, 0.8))
		vb.add_child(desc)
	dlg.add_child(vb)
	dlg.get_ok_button().visible = false
	add_child(dlg)
	dlg.canceled.connect(func():
		if bool(dlg.get_meta("chosen", false)):
			return
		dlg.call_deferred("popup_centered", Vector2i(760, 860)))
	dlg.popup_centered(Vector2i(760, 860))
