extends CanvasLayer
class_name PopupManager

# Minimal runtime popup manager. All popups are built from AcceptDialog / ConfirmationDialog
# created on demand; the Panel template in the .tscn exists as a reusable shell if needed.

func show_item_popup(item_name: String, desc: String, callbacks: Dictionary) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = item_name
	dlg.dialog_text = desc
	dlg.ok_button_text = "줍기"
	dlg.add_cancel_button("무시")
	var use_btn: Button = dlg.add_button("사용", true, "use")
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
	dlg.title = "슬롯 %d 교체" % slot_index
	var vb := VBoxContainer.new()
	var cur := Label.new()
	cur.text = "현재: %s" % (current_id if current_id != "" else "(비어있음)")
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
	clear_btn.text = "[비우기]"
	clear_btn.pressed.connect(func():
		if callback.is_valid(): callback.call("")
		dlg.queue_free())
	vb.add_child(clear_btn)
	dlg.add_child(vb)
	dlg.ok_button_text = "취소"
	add_child(dlg)
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())
	dlg.popup_centered(Vector2i(480, 600))

func show_levelup_popup(level: int, callback: Callable) -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "LEVEL UP! Lv.%d" % level
	dlg.dialog_hide_on_ok = false
	var vb := VBoxContainer.new()
	var lab := Label.new()
	lab.text = "스탯 +1 선택:"
	vb.add_child(lab)
	for stat in ["STR", "DEX", "INT"]:
		var b := Button.new()
		b.text = "%s +2" % stat
		b.pressed.connect(func():
			if callback.is_valid(): callback.call(stat)
			dlg.queue_free())
		vb.add_child(b)
	dlg.add_child(vb)
	dlg.get_ok_button().visible = false
	add_child(dlg)
	dlg.popup_centered(Vector2i(480, 400))
