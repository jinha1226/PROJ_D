class_name GodInvocations
extends RefCounted
## God invocation dispatcher, extracted from GameBootstrap.
##
## The per-god effect table lives here; GameBootstrap owns piety
## accounting and the picker UI entry-point only.
##
## Because the invocation effects pull heavily on scene-tree state
## (summon monsters, AOE over visible tiles, teleport the player,
## convert terrain tiles, push flee metas on mobs), every case needs
## access to the running GameBootstrap host. We take it as `host` and
## duck-type the calls rather than building a fat Callable context —
## behaviour-preservation is the goal of this extraction, not
## dependency tightening.


## Open the invocations picker. Each row shows the ability name +
## cost + locked/ready badge; piety gate and "can afford" gate disable
## unavailable rows. Confirm pops the cost and hands off to `dispatch`.
static func show_menu(host: Node, player, add_child_target: Node) -> void:
	if player == null or player.current_god == "":
		return
	var god: Dictionary = GodRegistry.get_info(player.current_god)
	var title: String = "%s — Piety %d/%d" % [String(god.get("title", "")),
			player.piety, int(god.get("piety_cap", 200))]
	var dlg := GameDialog.create(title, Vector2i(960, 1100))
	add_child_target.add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	for inv_id in god.get("invocations", []):
		var inv: Dictionary = GodRegistry.invocation(String(inv_id))
		var btn := Button.new()
		var locked: bool = player.piety < int(inv.get("min_piety", 999))
		btn.text = "%s  — %d piety  [%s]" % [String(inv.get("name", inv_id)),
				int(inv.get("cost", 0)), ("LOCKED" if locked else "READY")]
		btn.custom_minimum_size = Vector2(0, 80)
		btn.add_theme_font_size_override("font_size", 40)
		btn.disabled = locked or player.piety < int(inv.get("cost", 0))
		btn.pressed.connect(Callable(GodInvocations, "_invoke").bind(
				host, player, String(inv_id), dlg))
		vb.add_child(btn)


static func _invoke(host: Node, player, inv_id: String, dlg) -> void:
	var inv: Dictionary = GodRegistry.invocation(inv_id)
	if inv.is_empty() or player == null:
		return
	if player.piety < int(inv.get("cost", 0)):
		CombatLog.add("Not enough piety.")
		return
	player.piety -= int(inv.get("cost", 0))
	if dlg != null and dlg.has_method("close"):
		dlg.close()
	dispatch(host, String(inv.get("effect", "")))


## The big switchboard. Each branch maps a DCSS-inspired invocation
## effect name to the matching scene-tree action. Simple status /
## consumable-flavour effects reuse `_apply_consumable_effect` on
## the player; combat / summon effects call back into host helpers
## (`_summon_ally`, `_aoe_damage_visible`, etc) since those need
## direct access to EntityLayer / Monster group / DungeonMap.
static func dispatch(host: Node, effect: String) -> void:
	var player = host.player
	match effect:
		# ---- Trog ----
		"berserk":
			player._apply_consumable_effect({"effect": "berserk",
					"dur_base": 15, "dur_rand": 10})
		"trog_hand":
			host._summon_ally("orc_warrior", 60, "Trog's Hand strikes your side!")
		"brothers_in_arms":
			for i in 3:
				host._summon_ally("deep_troll", 40, "")
			CombatLog.add("Trog sends his brothers in arms!")
		# ---- Okawaru ----
		"heroism":
			player.set_meta("_heroism_turns", 25)
			CombatLog.add("Your combat prowess surges!")
		"finesse":
			player.set_meta("_finesse_turns", 10)
			CombatLog.add("Your strikes blur into a flurry!")
		"duel":
			_okawaru_duel(host, player)
		# ---- Makhleb ----
		"minor_destruction":
			host._makhleb_random_zap(false)
		"major_destruction":
			host._makhleb_random_zap(true)
		"summon_demon":
			var demon_pool: Array = ["red_devil", "yellow_devil", "green_death",
					"blue_devil", "iron_devil"]
			host._summon_ally(String(demon_pool[randi() % demon_pool.size()]),
					50, "A demon rises to serve!")
		# ---- Uskayaw ----
		"stomp":
			var stomp_r: Array = host._inv_scale_range(10, 20)
			host._aoe_damage_visible(8, int(stomp_r[0]), int(stomp_r[1]),
					"Uskayaw's stomp rattles the floor!")
		"line_pass":
			var lp_r: Array = host._inv_scale_range(15, 30)
			host._aoe_damage_visible(12, int(lp_r[0]), int(lp_r[1]),
					"You dance through the enemy line!")
		# ---- Zin / TSO / Elyvilon ----
		"vitalisation":
			host._heal_player(host._inv_scale_int(40), host._inv_scale_int(20),
					"Zin's light fills you.")
		"imprison":
			var imp_t = host._find_nearest_visible_monster(8)
			if imp_t != null:
				imp_t.set_meta("_paralysis_turns", host._inv_scale_int(10))
				CombatLog.add("Stone walls seal the %s in place." % host._mon_name(imp_t))
		"sanctuary":
			player.set_meta("_sanctuary_turns", host._inv_scale_int(12))
			CombatLog.add("A peaceful silence falls around you.")
		"divine_shield":
			if player.stats != null:
				var ds_ac: int = host._inv_scale_int(6)
				player.stats.AC += ds_ac
				player.set_meta("_divine_shield_turns", host._inv_scale_int(15))
				player.set_meta("_divine_shield_ac", ds_ac)
				player.stats_changed.emit()
			CombatLog.add("A golden shield surrounds you.")
		"cleansing_flame":
			var cf_r: Array = host._inv_scale_range(20, 40)
			host._aoe_damage_visible(12, int(cf_r[0]), int(cf_r[1]),
					"Cleansing flame burns every foe!")
		"summon_angel":
			host._summon_ally("angel", host._inv_scale_int(80),
					"An angel descends to your aid!")
		"lesser_healing":
			host._heal_player(host._inv_scale_int(15), 0, "Elyvilon mends your wounds.")
		"greater_healing":
			host._heal_player(host._inv_scale_int(40), 0, "Elyvilon heals you deeply.")
		"pacify":
			var pac_t = host._find_nearest_visible_monster(8)
			if pac_t != null:
				pac_t.set_meta("_flee_turns", host._inv_scale_int(20))
				CombatLog.add("The %s calms and flees in peace." % host._mon_name(pac_t))
		# ---- Vehumet ----
		"gift_spell":
			_vehumet_gift_spell(player)
		# ---- Sif Muna ----
		"channel_mana":
			if player.stats != null:
				var mp_gain: int = host._inv_scale_int(15)
				player.stats.MP = min(player.stats.mp_max, player.stats.MP + mp_gain)
				player.stats_changed.emit()
			CombatLog.add("Sif Muna channels arcane energy into you.")
		"divine_exegesis":
			if player.stats != null:
				player.stats.MP = player.stats.mp_max
				player.stats_changed.emit()
			player.set_meta("_exegesis_turns", 3)
			CombatLog.add("Sif Muna's insight fills you — next 3 spells cannot fail.")
		"forget_spell":
			player._apply_consumable_effect({"effect": "amnesia"})
		# ---- Kikubaaqudgha ----
		"receive_corpses":
			for i in 3:
				host._summon_ally("zombie", 30, "")
			CombatLog.add("Corpses stir to your service.")
		"torment":
			player._apply_consumable_effect({"effect": "torment"})
		"unearthly_bond":
			player.set_meta("_unearthly_bond", true)
			CombatLog.add("Your summons are bound to you.")
		# ---- Nemelex ----
		"draw_card":
			host._nemelex_draw_card()
		"stack_five":
			for i in 3:
				host._nemelex_draw_card()
			CombatLog.add("You stack the deck and draw three.")
		# ---- Yredelemnul ----
		"animate_dead":
			for i in 2:
				host._summon_ally("zombie", 50, "")
			CombatLog.add("The dead answer your call.")
		"drain_life":
			var dl_r: Array = host._inv_scale_range(5, 15)
			var drained: int = host._aoe_damage_visible(10, int(dl_r[0]),
					int(dl_r[1]), "Life flows out of the living!")
			host._heal_player(drained / 2, 0, "")
		"enslave_soul":
			var es_t = host._find_nearest_visible_monster(8)
			if es_t != null:
				es_t.set_meta("_enslaved_on_death", true)
				CombatLog.add("The %s's soul is yours to claim." % host._mon_name(es_t))
		# ---- Beogh ----
		"recall_followers":
			CombatLog.add("Orc allies rally to your side.")
		"smite":
			var sm_t = host._find_nearest_visible_monster(10)
			if sm_t != null:
				var sm_r: Array = host._inv_scale_range(20, 40)
				sm_t.take_damage(randi_range(int(sm_r[0]), int(sm_r[1])))
				CombatLog.add("Divine wrath smites the %s!" % host._mon_name(sm_t))
		# ---- Jiyva ----
		"jelly_prayer":
			var jp_gain: int = 15 if player.has_meta("_amulet_piety_boost") else 10
			player.piety = min(200, player.piety + jp_gain)
			CombatLog.add("The slimes commune with their god.")
		"cure_bad_mutation":
			host._cure_one_bad_mutation()
		"slimify":
			player.set_meta("_slimify_turns", 10)
			CombatLog.add("Your weapon oozes acidic slime.")
		# ---- Fedhas ----
		"sunlight":
			_fedhas_sunlight(host)
		"plant_ring":
			for i in randi_range(2, 4):
				host._summon_ally("plant", 20, "")
			CombatLog.add("Verdant plants burst from the ground around you.")
		"rain":
			_fedhas_rain(host)
		# ---- Cheibriados ----
		"bend_time":
			for m in host.get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.slowed_turns = 6
			CombatLog.add("Time slows for every foe.")
		"temporal_distortion":
			for m in host.get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.slowed_turns = randi_range(3, 10)
			CombatLog.add("Time fractures unpredictably.")
		"slouch":
			var sl_r: Array = host._inv_scale_range(8, 20)
			for m in host.get_tree().get_nodes_in_group("monsters"):
				if is_instance_valid(m) and m.is_alive:
					m.take_damage(randi_range(int(sl_r[0]), int(sl_r[1])))
			CombatLog.add("Slouch hits the swift!")
		# ---- Lugonu ----
		"bend_space":
			var bs_t = host._find_nearest_visible_monster(8)
			if bs_t != null:
				var bsr: Array = host._inv_scale_range(5, 12)
				bs_t.take_damage(randi_range(int(bsr[0]), int(bsr[1])))
				CombatLog.add("Space warps around the %s." % host._mon_name(bs_t))
		"banishment":
			var bn_t = host._find_nearest_visible_monster(8)
			if bn_t != null:
				bn_t.take_damage(9999)
				CombatLog.add("The %s vanishes into the Abyss!" % host._mon_name(bn_t))
		"corrupt_level":
			_lugonu_corrupt(host)
		# ---- Ashenzari ----
		"scry":
			var dmap_y = host.get_node("DungeonLayer/DungeonMap")
			if dmap_y != null and dmap_y.has_method("reveal_all"):
				dmap_y.reveal_all()
			CombatLog.add("Ashenzari grants you sight.")
		"transfer_knowledge":
			_ashenzari_transfer(host, player)
		# ---- Dithmenos ----
		"shadow_step":
			var ss_t = host._find_nearest_visible_monster(10)
			if ss_t != null:
				var near: Vector2i = host._find_free_adjacent_tile(ss_t.grid_pos)
				if near != ss_t.grid_pos:
					player.grid_pos = near
					var ts: int = host.TILE_SIZE
					player.position = Vector2(near.x * ts + ts / 2.0,
							near.y * ts + ts / 2.0)
					player.moved.emit(near)
					CombatLog.add("You step through shadow!")
		"shadow_form":
			player.set_meta("_shadow_form_turns", 20)
			CombatLog.add("You become a living shadow.")
		"summon_shadow":
			host._summon_ally("shadow", 50, "A shadow detaches from you.")
		# ---- Gozag ----
		"potion_petition":
			_gozag_potions(player)
		"call_merchant":
			if player.gold < 100:
				CombatLog.add("Gozag requires 100 gold to call a merchant.")
			else:
				player.gold -= 100
				host._summon_shop_near_player()
		"bribe_branch":
			if player.gold < 250:
				CombatLog.add("Gozag requires 250 gold to bribe the branch.")
			else:
				player.gold -= 250
				for m in host.get_tree().get_nodes_in_group("monsters"):
					if is_instance_valid(m) and m.is_alive:
						m.set_meta("_flee_turns", 30)
				CombatLog.add("Gold changes hands; monsters retreat.")
		# ---- Qazlal ----
		"upheaval":
			host._damage_nearest_visible(25, 50, "Upheaval tears up the floor!")
		"elemental_force":
			for i in 3:
				host._summon_ally("fire_elemental", 30, "")
			CombatLog.add("Elementals swirl at your command.")
		"disaster_area":
			host._aoe_damage_visible(12, 30, 60, "Disaster area erupts!")
		# ---- Ru ----
		"sacrifice":
			host._ru_sacrifice_menu()
		"draw_out_power":
			if player.stats != null:
				player.stats.HP = player.stats.hp_max
				player.stats.MP = player.stats.mp_max
				player.stats_changed.emit()
			CombatLog.add("Ru surges power through you!")
		"power_leap":
			host._aoe_damage_visible(12, 20, 40, "You leap with awesome power!")
		"apocalypse":
			host._aoe_damage_visible(15, 40, 80, "Apocalypse!")
		# ---- Wu Jian ----
		"wall_jump":
			host._aoe_damage_visible(8, 12, 24, "You pivot off the wall!")
		"heavenly_storm":
			player.set_meta("_heavenly_storm_turns", 20)
			CombatLog.add("Heavenly storm girds your attacks.")
		# ---- Hepliaklqana ----
		"recall_ancestor":
			host._summon_ally("orc_knight", 999, "Your ancestor answers the call.")
		"idealise":
			_heplia_idealise(host)
		"transference":
			_heplia_transference(host, player)
		# ---- Ignis ----
		"fiery_armour":
			player.set_meta("_fiery_armour_turns", 30)
			CombatLog.add("Flames wreath your armour.")
		"foxfire_swarm":
			for i in 4:
				host._summon_ally("fire_elemental", 20, "")
			CombatLog.add("A swarm of foxfires flits out.")
		"rising_flame":
			host._damage_nearest_visible(30, 55, "A spire of flame engulfs %s!")
		_:
			CombatLog.add("The god is silent.")


# ---- Larger per-god helpers (moved out of the match for readability) -----

static func _okawaru_duel(host: Node, player) -> void:
	var duel_t = host._find_nearest_visible_monster(10)
	if duel_t == null:
		return
	# Step the player onto a tile adjacent to the target.
	var dirs: Array = [Vector2i(1,0), Vector2i(-1,0),
			Vector2i(0,1), Vector2i(0,-1)]
	var ts: int = host.TILE_SIZE
	for d in dirs:
		var cand: Vector2i = duel_t.grid_pos + d
		if player.has_method("_player_can_walk_on") \
				and player._player_can_walk_on(cand):
			player.grid_pos = cand
			player.position = Vector2(cand.x * ts + ts / 2.0,
					cand.y * ts + ts / 2.0)
			break
	# Nearby other monsters flee to clear the arena.
	for m in host.get_tree().get_nodes_in_group("monsters"):
		if m == duel_t or not is_instance_valid(m):
			continue
		if maxi(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y)) <= 3:
			m.set_meta("_flee_turns", 8)
	var duel_rng: Array = host._inv_scale_range(25, 45)
	duel_t.take_damage(randi_range(int(duel_rng[0]), int(duel_rng[1])))
	CombatLog.add("Okawaru opens a private arena with the %s!" % \
			host._mon_name(duel_t))


## Vehumet's piety-tiered spell gift. Low piety → early conjurations,
## mid → bolts, high → top-tier. Respects the memorisation cap.
static func _vehumet_gift_spell(player) -> void:
	var low_pool: Array = ["throw_flame", "throw_frost", "magic_dart",
			"mephitic_cloud"]
	var mid_pool: Array = ["sticky_flame", "bolt_of_fire", "bolt_of_cold",
			"iron_shot", "stone_arrow"]
	var high_pool: Array = ["fireball", "bolt_of_magma", "bolt_of_draining",
			"lehudibs_crystal_spear"]
	var pick_pool: Array = low_pool if player.piety < 80 \
			else (mid_pool if player.piety < 140 else high_pool)
	if player.used_spell_levels() >= player.max_spell_levels():
		CombatLog.add("Vehumet's lips form a spell but you have no memory to hold it.")
		return
	for _i in 10:
		var sp: String = String(pick_pool[randi() % pick_pool.size()])
		if not player.learned_spells.has(sp):
			player.learned_spells.append(sp)
			CombatLog.add("Vehumet gifts you %s." % sp.replace("_", " "))
			player.spells_learned.emit()
			return


## Fedhas sunlight: dispel invisibility + reveal floor + damage
## undead / demonic monsters in sight.
static func _fedhas_sunlight(host: Node) -> void:
	var dmap_s = host.get_node("DungeonLayer/DungeonMap")
	if dmap_s != null and dmap_s.has_method("reveal_all"):
		dmap_s.reveal_all()
	for m in host.get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not m.is_alive:
			continue
		if not dmap_s.is_tile_visible(m.grid_pos):
			continue
		var hol_s: String = ""
		if m.data and m.data.shape == "undead":
			hol_s = "undead"
		elif m.data and m.data.flags != null:
			for f in m.data.flags:
				if String(f).to_lower() == "demonic":
					hol_s = "demonic"
					break
		if hol_s != "":
			m.take_damage(randi_range(12, 24), "holy")
	CombatLog.add("Sunlight sears the shadows.")


## Fedhas rain: scatter WATER tiles across a radius around the player.
## Doesn't touch stairs / vault features — only FLOOR.
static func _fedhas_rain(host: Node) -> void:
	if host.generator == null:
		return
	var dmap_r = host.get_node("DungeonLayer/DungeonMap")
	var player = host.player
	for dx in range(-4, 5):
		for dy in range(-4, 5):
			var cc: Vector2i = player.grid_pos + Vector2i(dx, dy)
			if cc.x < 0 or cc.x >= DungeonGenerator.MAP_WIDTH:
				continue
			if cc.y < 0 or cc.y >= DungeonGenerator.MAP_HEIGHT:
				continue
			if host.generator.get_tile(cc) == DungeonGenerator.TileType.FLOOR \
					and abs(dx) + abs(dy) >= 2 \
					and abs(dx) + abs(dy) <= 5:
				if randf() < 0.35:
					host.generator.map[cc.x][cc.y] = DungeonGenerator.TileType.WATER
	if dmap_r != null:
		dmap_r.render(host.generator)
	CombatLog.add("Rain floods the area with fresh water.")


## Lugonu corrupt: banish the top 5 highest-HD visible mobs; confuse
## the rest for 15 turns. Full-floor abyss rewrite is out of scope.
static func _lugonu_corrupt(host: Node) -> void:
	var mons_list: Array = []
	for m in host.get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and m is Monster and m.is_alive:
			mons_list.append(m)
	mons_list.sort_custom(func(a, b):
		return int(a.data.hd) > int(b.data.hd))
	for i in min(5, mons_list.size()):
		var victim = mons_list[i]
		victim.take_damage(9999)
	for m in mons_list.slice(5):
		m.set_meta("_confusion_turns", 15)
	CombatLog.add("The dungeon writhes — Lugonu corrupts everything in sight!")


## Ashenzari knowledge transfer: grant 1500 XP across currently-
## trained skills. Matches the "skill swap" spirit without the
## two-skill picker UI DCSS uses.
static func _ashenzari_transfer(host: Node, player) -> void:
	if host.skill_system == null:
		return
	var trained: Array = []
	for sk in SkillSystem.SKILL_IDS:
		var st: Dictionary = player.skill_state.get(sk, {})
		if bool(st.get("training", false)):
			trained.append(sk)
	if trained.is_empty():
		CombatLog.add("Enable skills to train before calling the transfer.")
		return
	host.skill_system.grant_xp(player, 1500.0, trained)
	CombatLog.add("Ashenzari pours arcane knowledge into your training.")


## Gozag potion petition: 50 gold → 3 random utility potions.
static func _gozag_potions(player) -> void:
	if player.gold < 50:
		CombatLog.add("Gozag requires 50 gold for a petition.")
		return
	player.gold -= 50
	for i in 3:
		var pot_ids: Array = ["potion_curing", "potion_haste", "potion_might",
				"potion_brilliance", "potion_resistance", "potion_magic"]
		var pid: String = String(pot_ids[randi() % pot_ids.size()])
		player.items.append(ConsumableRegistry.get_info(pid))
	player.inventory_changed.emit()
	CombatLog.add("Gozag sells you three potions for 50 gold.")


## Heplia idealise: full-heal + haste every companion currently out.
static func _heplia_idealise(host: Node) -> void:
	var idealised: int = 0
	for c in host.get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c) and c.is_alive:
			if "hp" in c and "data" in c and c.data != null:
				c.hp = int(c.data.hp)
			if c.has_method("set_meta"):
				c.set_meta("_haste_turns", 20)
			idealised += 1
	if idealised > 0:
		CombatLog.add("Your %d allies blaze with ancestral power!" % idealised)
	else:
		CombatLog.add("No allies answer the call.")


## Heplia transference: swap places with the nearest companion so
## the player can duck out of melee range.
static func _heplia_transference(host: Node, player) -> void:
	var closest: Node = null
	var closest_d: int = 999999
	for c in host.get_tree().get_nodes_in_group("companions"):
		if not is_instance_valid(c) or not c.is_alive:
			continue
		var d: int = maxi(abs(c.grid_pos.x - player.grid_pos.x),
				abs(c.grid_pos.y - player.grid_pos.y))
		if d < closest_d:
			closest_d = d
			closest = c
	if closest == null:
		CombatLog.add("No ally to bind with.")
		return
	var ts: int = host.TILE_SIZE
	var old_p: Vector2i = player.grid_pos
	player.grid_pos = closest.grid_pos
	player.position = Vector2(
			player.grid_pos.x * ts + ts / 2.0,
			player.grid_pos.y * ts + ts / 2.0)
	closest.grid_pos = old_p
	closest.position = Vector2(
			old_p.x * ts + ts / 2.0,
			old_p.y * ts + ts / 2.0)
	CombatLog.add("You swap places with your ancestor.")
