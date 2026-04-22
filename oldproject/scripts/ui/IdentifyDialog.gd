class_name IdentifyDialog
extends RefCounted
## Identify-item picker, extracted from GameBootstrap.
##
## Builds the "Choose an item to reveal" GameDialog, populates it from
## the player's inventory (consumables + rings + amulets + ego armour),
## and handles the commit callback when the user taps a row.
##
## Usage:
##   IdentifyDialog.open(host_node, player)
##
## `host_node` is whatever scene-tree parent should own the dialog —
## GameBootstrap passes itself. We don't need GameBootstrap-specific
## methods, just a Node to `add_child` the dialog under.

## Open the picker. No-op when there's no player, but always builds
## the dialog (even when there are zero candidates) so the caller can
## close the bag safely before showing it.
static func open(host: Node, player: Node) -> void:
	if host == null or player == null:
		return
	var dlg := GameDialog.create("Identify Which?", Vector2i(960, 1200))
	host.add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 8)
	var unidentified: Array = _collect_unidentified(player)
	if unidentified.is_empty():
		var l := Label.new()
		l.text = "You have nothing left to identify."
		l.add_theme_font_size_override("font_size", 40)
		vb.add_child(l)
		return
	var prompt := Label.new()
	prompt.text = "Choose an item to reveal:"
	prompt.add_theme_font_size_override("font_size", 40)
	vb.add_child(prompt)
	for it in unidentified:
		var iid: String = String(it.get("id", ""))
		var kind: String = String(it.get("kind", ""))
		var disp: String = GameManager.display_name_for_item(
				iid, String(it.get("name", "?")), kind)
		var btn := Button.new()
		btn.text = "%s [%s]" % [disp, kind]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 40)
		btn.pressed.connect(Callable(IdentifyDialog, "_on_pick").bind(iid, dlg, player))
		vb.add_child(btn)


## Unique-id set of inventory rows that can still be identified. Potions
## / scrolls go through ConsumableRegistry's identify flag; rings +
## amulets use the per-id flag; ego armour uses the per-ego-class flag
## so identifying one "runed cloak of stealth" reveals the whole
## stealth ego class.
static func _collect_unidentified(player: Node) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for it in player.get_items():
		var iid: String = String(it.get("id", ""))
		if iid == "" or seen.has(iid):
			continue
		if iid.begins_with("randart_") or iid.begins_with("unrand_"):
			continue
		var kind_it: String = String(it.get("kind", ""))
		var is_candidate: bool = false
		if ConsumableRegistry.has(iid) and not GameManager.is_identified(iid):
			is_candidate = true
		elif (kind_it == "ring" or kind_it == "amulet") \
				and not GameManager.is_identified(iid):
			is_candidate = true
		elif kind_it == "armor":
			var ego_it: String = String(it.get("ego", ""))
			if ego_it != "" and not GameManager.is_identified(
					GameManager.armor_ego_key(ego_it)):
				is_candidate = true
		if is_candidate:
			seen[iid] = true
			out.append(it)
	return out


## Row click → reveal the id. Armour egos are identified by the ego
## key, not the item id, so we scan the inventory rows sharing this id
## to find the ego tag (if any) and flip its class.
static func _on_pick(id: String, dlg, player: Node) -> void:
	GameManager.identify(id)
	if player != null:
		for it in player.get_items():
			if String(it.get("id", "")) != id:
				continue
			var ego: String = String(it.get("ego", ""))
			if ego != "":
				GameManager.identify_armor_ego(ego)
			break
	if dlg != null and dlg.has_method("close"):
		dlg.close()
