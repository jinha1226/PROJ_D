class_name LogDialog extends RefCounted

static var CombatLog = Engine.get_main_loop().root.get_node_or_null("/root/CombatLog") if Engine.get_main_loop() is SceneTree else null

## Full-history combat log viewer. Shows every message currently in
## CombatLog.history (up to MAX_HISTORY), newest at bottom, inside a
## GameDialog-wrapped scroll container so the player can review
## earlier combat messages that have faded out of the on-screen
## strip.

static func open(parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Message Log")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.scroll_active = true
	rtl.fit_content = true
	rtl.custom_minimum_size = Vector2(0, 1200)
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.add_theme_font_size_override("normal_font_size", 22)
	var out: String = ""
	var entries: Array = CombatLog.history
	if entries.is_empty():
		out = "[color=#888888](no messages yet)[/color]"
	else:
		for i in range(entries.size()):
			var e: Dictionary = entries[i]
			var c: Color = e.get("color", Color.WHITE)
			out += "[color=#%s]%s[/color]" % [c.to_html(true),
				String(e.get("text", ""))]
			if i < entries.size() - 1:
				out += "\n"
	rtl.text = out
	body.add_child(rtl)
	# Scroll to bottom on open so the most recent entry is visible.
	rtl.scroll_to_line.call_deferred(rtl.get_line_count() - 1)
