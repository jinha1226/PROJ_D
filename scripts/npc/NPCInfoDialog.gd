class_name NPCInfoDialog extends RefCounted

## Opens a GameDialog showing an NPC's name, HP, and equipped items.
## Includes an Attack button that triggers player→NPC combat and makes
## the NPC hostile so it fights back on its next turn.

static func show_for(npc: NPCActor, player: Player, game_node: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio(npc.npc_name, 0.75, 0.62)
	game_node.add_child(dlg)
	var body: VBoxContainer = dlg.body()

	# HP bar
	var hp_label := Label.new()
	hp_label.text = "HP  %d / %d" % [npc.hp, npc.hp_max]
	hp_label.add_theme_font_size_override("font_size", 22)
	body.add_child(hp_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = npc.hp_max
	bar.value = npc.hp
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	body.add_child(bar)

	body.add_child(HSeparator.new())

	# Equipment rows
	var slots: Array = [
		["Weapon",  npc.equipped_weapon_id],
		["Armor",   npc.equipped_armor_id],
		["Shield",  npc.equipped_shield_id],
		["Helmet",  npc.equipped_helmet_id],
		["Gloves",  npc.equipped_gloves_id],
		["Boots",   npc.equipped_boots_id],
		["Ring",    npc.equipped_ring_id],
		["Amulet",  npc.equipped_amulet_id],
	]
	var any_equip := false
	for slot_info in slots:
		var item_id: String = slot_info[1]
		if item_id == "":
			continue
		any_equip = true
		var item_data = null
		if npc.ItemRegistry != null:
			item_data = npc.ItemRegistry.get_by_id(item_id)
		var row := Label.new()
		var item_name: String = item_data.display_name if item_data != null else item_id
		row.text = "%s:  %s" % [slot_info[0], item_name]
		row.add_theme_font_size_override("font_size", 20)
		body.add_child(row)

	if not any_equip:
		var empty := Label.new()
		empty.text = "No equipment"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty.add_theme_font_size_override("font_size", 20)
		body.add_child(empty)

	body.add_child(HSeparator.new())

	# Attack button — only shown when player is adjacent
	var dist: int = max(abs(npc.grid_pos.x - player.grid_pos.x),
						abs(npc.grid_pos.y - player.grid_pos.y))
	if dist <= 1:
		var atk_btn := Button.new()
		atk_btn.text = "Attack"
		atk_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.3))
		atk_btn.add_theme_font_size_override("font_size", 22)
		atk_btn.pressed.connect(func():
			dlg.close()
			_do_attack(npc, player, game_node)
		)
		body.add_child(atk_btn)

	dlg.set_close_text("Close")

## Resolve one player→NPC melee hit, make the NPC hostile, end player turn.
static func _do_attack(npc: NPCActor, player: Player, game_node: Node) -> void:
	if not is_instance_valid(npc) or npc.hp <= 0:
		return

	# Simple damage: player slay_bonus + 1d(4+skill) — not routed through
	# CombatSystem because that requires Monster type. Wire properly later.
	var wpn_skill: int = player.get_skill_level("weapon_mastery")
	var dmg: int = randi_range(1, 4 + wpn_skill) + player.slay_bonus
	dmg = max(1, dmg - npc.ac / 4)

	player.facing = (npc.grid_pos - player.grid_pos).sign()
	player.play_bump_anim(player.facing)

	npc.take_damage(dmg)
	CombatLog.post(
		"You strike %s for %d damage." % [npc.npc_name, dmg],
		Color(0.95, 0.75, 0.5))

	# NPC becomes hostile — will target player on its next turn
	if is_instance_valid(npc):
		npc.set_relation(player, -1.0, 0.8)
		npc._current_plan = []  # force replan toward new goal

	TurnManager.end_player_turn(Status.speed_mult(player))
