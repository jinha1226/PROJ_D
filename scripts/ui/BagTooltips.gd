class_name BagTooltips
extends RefCounted
## Bag item tooltips + thumbnail builder + info popup, extracted from
## GameBootstrap. Pure-ish — the per-kind tooltip functions only need
## a reference to the player node to compute diffs against currently
## equipped gear.
##
## Left behind in GameBootstrap: `_on_bag_pressed`, the equip / use /
## drop callbacks, and the `_bag_dlg` / `_suppress_bag_reopen` state.
## Extracting those requires moving live dialog state too; this pass
## just pulls the big read-only builders.

const _ICON_SIZE: Vector2 = Vector2(64, 64)


## Router from item dict → rich tooltip string. Dispatches on `kind`;
## unknown kinds fall through to a one-line "miscellaneous junk" tag.
static func build_item_tooltip(player, it: Dictionary) -> String:
	var kind: String = String(it.get("kind", ""))
	var id: String = String(it.get("id", ""))
	var raw_name: String = String(it.get("name",
			WeaponRegistry.display_name_for(id)))
	var name_s: String = GameManager.display_name_for_item(id, raw_name, kind)
	match kind:
		"weapon":   return _tooltip_weapon(player, id, name_s, it)
		"armor":    return _tooltip_armor(player, id, name_s, it)
		"ring":     return _tooltip_ring(player, id, name_s, it)
		"potion":   return _tooltip_consumable(id, name_s, "potion")
		"scroll":   return _tooltip_consumable(id, name_s, "scroll")
		"book":     return _tooltip_book(player, id, name_s, it)
		"wand":     return _tooltip_wand(player, id, name_s, it)
		"talisman": return _tooltip_talisman(player, id, name_s, it)
		"evocable": return _tooltip_evocable(id, name_s, it)
		"gold":     return "%d gold coins." % int(it.get("gold", 0))
		_:          return "%s\nMiscellaneous junk." % name_s


## Info popup that opens on top of the bag when the player taps a row.
## Returns the dialog so the caller can close/track it if needed.
static func open_info(host: Node, player, it: Dictionary) -> GameDialog:
	var dlg := GameDialog.create(String(it.get("name", "Item")),
			Vector2i(960, 1100))
	host.add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)
	var lab := Label.new()
	lab.text = build_item_tooltip(player, it)
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lab)
	return dlg


## Bag thumbnail. Potions / scrolls layer the base-colour tile with the
## effect icon on top once identified. Other items blit their
## TileRenderer texture directly. Null when there's no texture to show.
static func build_thumbnail(iid: String, kind: String) -> Control:
	var is_consumable: bool = (kind == "potion" or kind == "scroll")
	if is_consumable:
		var stack := Control.new()
		stack.custom_minimum_size = _ICON_SIZE
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var base_tex: Texture2D = TileRenderer.consumable_base(iid, kind)
		if base_tex != null:
			stack.add_child(_full_rect_texture(base_tex))
		if GameManager != null and GameManager.is_identified(iid):
			var overlay: Texture2D = TileRenderer.item(iid)
			if overlay != null:
				stack.add_child(_full_rect_texture(overlay))
		return stack
	var tex: Texture2D = TileRenderer.item(iid)
	if tex == null:
		return null
	var icon := TextureRect.new()
	icon.texture = tex
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.custom_minimum_size = _ICON_SIZE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


static func _full_rect_texture(tex: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---- Per-kind tooltips ----------------------------------------------------

static func _tooltip_weapon(player, id: String, name_s: String, it: Dictionary) -> String:
	var new_dmg: int = WeaponRegistry.weapon_damage_for(id)
	var new_delay: float = WeaponRegistry.weapon_delay_for(id)
	var new_skill: String = WeaponRegistry.weapon_skill_for(id)
	var plus: int = int(it.get("plus", 0))
	var total_dmg: int = new_dmg + plus
	var cur_id: String = player.equipped_weapon_id if player else ""
	var cur_dmg: int = WeaponRegistry.weapon_damage_for(cur_id) \
			+ (int(player.equipped_weapon_plus) if player and cur_id != "" else 0)
	var cur_delay: float = WeaponRegistry.weapon_delay_for(cur_id)
	var cur_name: String = WeaponRegistry.display_name_for(cur_id) \
			if cur_id != "" else "unarmed"
	var new_dps: float = float(total_dmg) / max(new_delay, 0.1)
	var cur_dps: float = float(cur_dmg) / max(cur_delay, 0.1)
	var diff_dmg: int = total_dmg - cur_dmg
	var diff_dps: float = new_dps - cur_dps
	var lines: Array = [name_s]
	if plus != 0:
		lines.append("Enchant: +%d" % plus)
	lines.append("Damage: %d  (%s%d vs %s)" % [
			total_dmg, ("+" if diff_dmg >= 0 else ""), diff_dmg, cur_name])
	lines.append("Delay: %.2f  (cur %.2f — lower is faster)" % [new_delay, cur_delay])
	lines.append("DPS: %.1f  (%s%.1f)" % [
			new_dps, ("+" if diff_dps >= 0 else ""), diff_dps])
	lines.append("Trains: %s" % new_skill.replace("_", " "))
	var staff_school: String = WeaponRegistry.staff_spell_school(id)
	if staff_school != "":
		lines.append("Magical staff: +%d spell power to %s school" % [
				WeaponRegistry.staff_spell_bonus(id), staff_school])
	if bool(it.get("cursed", false)):
		lines.append("[color=#c55]*** Cursed *** — you cannot unequip it.[/color]")
	return "\n".join(PackedStringArray(lines))


static func _tooltip_armor(player, id: String, name_s: String, it: Dictionary) -> String:
	var new_ac: int = int(it.get("ac", 0))
	var slot: String = String(it.get("slot", ArmorRegistry.slot_for(id)))
	var ev_penalty: int = ArmorRegistry.ev_penalty_for(id)
	var cur: Dictionary = {}
	if player != null and player.equipped_armor.has(slot):
		cur = player.equipped_armor[slot]
	var cur_ac: int = int(cur.get("ac", 0))
	var cur_name: String = String(cur.get("name", "(empty)"))
	var diff_ac: int = new_ac - cur_ac
	var lines: Array = [name_s, "Slot: %s" % slot]
	lines.append("AC: +%d  (%s%d vs %s)" % [
			new_ac, ("+" if diff_ac >= 0 else ""), diff_ac, cur_name])
	if ev_penalty < 0:
		lines.append("EV penalty: %d  (heavier armour → worse dodge + spells)" \
				% (ev_penalty / 10))
	if bool(it.get("cursed", false)):
		lines.append("[color=#c55]*** Cursed *** — you cannot remove it.[/color]")
	return "\n".join(PackedStringArray(lines))


static func _tooltip_ring(player, id: String, name_s: String, it: Dictionary) -> String:
	var lines: Array = [name_s, "Slot: ring"]
	if it.get("randart", false):
		lines.append(RandartGenerator.describe(it))
		if player != null:
			var worn: int = player.equipped_rings.size() if "equipped_rings" in player else 0
			var cap: int = 8 if player.race_res and player.race_res.racial_trait == "octopode_rings" else 2
			lines.append("Worn: %d / %d rings" % [worn, cap])
		return "\n".join(PackedStringArray(lines))
	var info: Dictionary = RingRegistry.get_info(id)
	if info.is_empty():
		return "%s\nA small band of unknown metal." % name_s
	var pairs: Array = [
		["str",         "STR +%d"],
		["dex",         "DEX +%d"],
		["int_",        "INT +%d"],
		["ac",          "AC +%d"],
		["ev",          "EV +%d"],
		["mp_max",      "Max MP +%d"],
		["dmg_bonus",   "Melee damage +%d"],
		["spell_power", "Spell power +%d"],
		["regen",       "HP regen +%d / turn"],
		["stealth",     "Stealth +%d"],
		["fire_apt",    "Fire aptitude +%d (spells + resist)"],
		["cold_apt",    "Cold aptitude +%d (spells + resist)"],
	]
	for p in pairs:
		var key: String = p[0]
		var fmt: String = p[1]
		if info.has(key) and int(info[key]) != 0:
			lines.append(fmt % int(info[key]))
	var ring_resists: Dictionary = info.get("resists", {})
	for elem in ring_resists.keys():
		var lv: int = int(ring_resists[elem])
		if lv != 0:
			lines.append("r%s %s" % [elem.capitalize(), "+" if lv > 0 else "-"])
	for flag in info.get("flags", []):
		match String(flag):
			"see_invis": lines.append("See invisible")
			"flying":    lines.append("Flight")
	if player != null:
		var worn: int = player.equipped_rings.size() if "equipped_rings" in player else 0
		var cap: int = 8 if player.race_res and player.race_res.racial_trait == "octopode_rings" else 2
		lines.append("Worn: %d / %d rings" % [worn, cap])
	return "\n".join(PackedStringArray(lines))


static func _tooltip_consumable(id: String, name_s: String, kind: String) -> String:
	var desc: String = ""
	if GameManager.is_identified(id):
		desc = ConsumableRegistry.description_for(id)
	if desc == "":
		desc = ("Drink to find out." if kind == "potion" else "Read aloud to find out.")
	return "%s\n%s" % [name_s, desc]


static func _tooltip_book(player, id: String, name_s: String, _it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var spells: Array = info.get("spells", [])
	var lines: Array = [name_s]
	if spells.is_empty():
		lines.append("Teaches nothing you can learn.")
	else:
		lines.append("Spells taught:")
		for sid in spells:
			var sid_s: String = String(sid)
			var spell_info: Dictionary = SpellRegistry.get_spell(sid_s)
			var sp_name: String = String(spell_info.get("name",
					sid_s.replace("_", " ").capitalize()))
			var lv: int = int(spell_info.get("difficulty", 1))
			var known: bool = player != null and player.learned_spells.has(sid_s)
			var marker: String = " (known)" if known else ""
			lines.append("  • %s  [Lv.%d]%s" % [sp_name, lv, marker])
	return "\n".join(PackedStringArray(lines))


static func _tooltip_wand(player, id: String, name_s: String, it: Dictionary) -> String:
	var info: Dictionary = WandRegistry.get_info(id)
	if info.is_empty():
		return "%s\nA thin rod of unknown craft." % name_s
	var charges: int = int(it.get("charges", 0))
	var spell_id: String = String(info.get("spell", ""))
	var sp_name: String = spell_id.replace("_", " ").capitalize()
	if spell_id != "":
		var sp_info: Dictionary = SpellRegistry.get_spell(spell_id)
		if not sp_info.is_empty():
			sp_name = String(sp_info.get("name", sp_name))
	var evo: int = 0
	if player != null and player.skill_state.has("evocations"):
		evo = int(player.skill_state["evocations"].get("level", 0))
	var eff_power: int = 15 + evo * 7
	var lines: Array = [name_s, "Charges: %d" % charges]
	lines.append("Effect: %s" % sp_name)
	lines.append("Evocation power: %d  (Evocations Lv.%d)" % [eff_power, evo])
	lines.append(String(info.get("desc", "")))
	return "\n".join(PackedStringArray(lines))


static func _tooltip_talisman(player, id: String, name_s: String, _it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var form_id: String = String(info.get("form", id.replace("talisman_", "")))
	var form: Dictionary = FormRegistry.get_info(form_id)
	var lines: Array = [name_s]
	lines.append(String(info.get("desc", "")))
	if form.is_empty():
		return "\n".join(PackedStringArray(lines))
	var hp_mod: int = int(form.get("hp_mod", 100))
	if hp_mod != 100:
		lines.append("HP: %d%% of normal" % hp_mod)
	if int(form.get("str_delta", 0)) != 0:
		lines.append("STR %+d" % int(form.get("str_delta", 0)))
	if int(form.get("dex_delta", 0)) != 0:
		lines.append("DEX %+d" % int(form.get("dex_delta", 0)))
	if int(form.get("ac_base", 0)) != 0:
		lines.append("AC +%d  (+%d per 10 skill)" % [
				int(form.get("ac_base", 0)), int(form.get("ac_scaling", 0))])
	if int(form.get("unarmed_base", 0)) > 0:
		lines.append("Unarmed attack: %d base  (+%d per 10 skill)" % [
				int(form.get("unarmed_base", 0)), int(form.get("unarmed_scaling", 0))])
	var resists: Dictionary = form.get("resists", {})
	if not resists.is_empty():
		var parts: Array = []
		for r in resists.keys():
			parts.append("r%s+%d" % [String(r), int(resists[r])])
		lines.append("Resists: %s" % ", ".join(parts))
	var flags: Array = []
	if bool(form.get("can_fly", false)):
		flags.append("fly")
	if bool(form.get("can_swim", false)):
		flags.append("swim")
	if not flags.is_empty():
		lines.append("Movement: %s" % ", ".join(flags))
	if player != null and player.current_form == form_id:
		lines.append("[color=#8dd]Currently active — evoke again to revert.[/color]")
	return "\n".join(PackedStringArray(lines))


static func _tooltip_evocable(id: String, name_s: String, it: Dictionary) -> String:
	var info: Dictionary = ConsumableRegistry.get_info(id)
	var charges: int = int(it.get("charges", 0))
	var lines: Array = [name_s, "Charges: %d" % charges]
	lines.append(String(info.get("desc", "Activate to release its power.")))
	return "\n".join(PackedStringArray(lines))
