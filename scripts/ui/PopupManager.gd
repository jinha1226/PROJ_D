extends CanvasLayer
class_name PopupManager

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
		b.text = str(essence_id)
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
