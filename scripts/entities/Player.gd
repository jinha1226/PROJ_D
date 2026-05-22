class_name Player extends Actor

var TurnManager = null
var _renderer: PlayerRenderer = null

signal item_dropped(entry: Dictionary, at_pos: Vector2i)


var gold: int = 0
var kills: int = 0
var items_collected: int = 0
var last_killer: String = ""
var items: Array = []  # [{id: String, plus: int}]
var known_spells: Array = []  # [String]
var quickslots: Array = ["", "", "", "", "", ""]  # item/spell ids, index = slot

# Name retained for DCSS "general combat fitness" semantics; the gate is now
# tactics (the fighting hidden subskill moved tactics→ in 2026-05-21).
const FIGHTING_HP_PER_LEVEL: int = 5

# Deprecated DCSS mastery system. Constants kept as empty/identity so UI
# files referencing them don't crash; mastery getters return 0/identity.
# The UI sweep will remove the mastery cards in a follow-up.
const MASTERY_XP_DELTA: Array = [60, 140, 275, 475, 750, 1150, 1700, 2450, 3500]
const MAX_MASTERY_LEVEL: int = 9

# Spell school list (data routing for spells — unrelated to skill ids).
const MAGIC_SCHOOLS: Array = [
	"conjurations", "hexes", "charms", "summonings", "necromancy",
	"translocations", "transmutation",
	"fire", "ice", "air", "earth", "poison",
]

# Surface category grouping for SkillsDialog (only the 9 visible skills).
const SKILL_CATEGORIES: Dictionary = {
	"weapon_mastery": "Combat", "archery": "Combat", "tactics": "Combat",
	"defense": "Defense",
	"magery": "Magic",
	"stealth": "Utility", "tracking": "Utility", "survival": "Utility",
}


func _ready() -> void:
	TurnManager = get_node_or_null("/root/TurnManager")
	CombatLog = get_node_or_null("/root/CombatLog")
	GameManager = get_node_or_null("/root/GameManager")
	ItemRegistry = get_node_or_null("/root/ItemRegistry")
	add_to_group("player")
	_renderer = PlayerRenderer.new()
	_renderer.name = "Renderer"
	add_child(_renderer)

func bind_map(map: DungeonMap, spawn: Vector2i) -> void:
	_map = map
	grid_pos = spawn
	position = _map.grid_to_world(grid_pos)
	if _renderer != null:
		_renderer.refresh_equipment(self)

func _unhandled_input(event: InputEvent) -> void:
	if _map == null or hp <= 0:
		return
	if not TurnManager.is_player_turn:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var dir: Vector2i = _dir_for_key(event.keycode)
		if dir != Vector2i.ZERO:
			_try_move(dir)
			get_viewport().set_input_as_handled()

func _dir_for_key(k: int) -> Vector2i:
	match k:
		KEY_UP, KEY_W, KEY_K:
			return Vector2i(0, -1)
		KEY_DOWN, KEY_S, KEY_J:
			return Vector2i(0, 1)
		KEY_LEFT, KEY_A, KEY_H:
			return Vector2i(-1, 0)
		KEY_RIGHT, KEY_D, KEY_L:
			return Vector2i(1, 0)
	return Vector2i.ZERO

func _race_speed_mod() -> float:
	if GameManager == null or RaceRegistry == null:
		return 1.0
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	return race.speed_mod if race != null else 1.0

func _try_move(dir: Vector2i) -> void:
	var target: Vector2i = grid_pos + dir
	if try_attack_tile(target):
		return
	if Status.has(self, "crippled"):
		CombatLog.post("심한 부상으로 이동할 수 없습니다!", Color(1.0, 0.55, 0.3))
		return
	if _map.tile_at(target) == DungeonMap.Tile.DOOR_CLOSED:
		_map.set_tile(target, DungeonMap.Tile.DOOR_OPEN)
		emit_signal("moved", grid_pos)  # refresh FOV from current pos
		TurnManager.end_player_turn(_race_speed_mod() * Status.speed_mult(self))
		return
	if not _map.is_walkable(target):
		return
	grid_pos = target
	facing = dir
	if _renderer != null:
		_renderer.start_walk_anim()
	position = _map.grid_to_world(grid_pos)
	emit_signal("moved", grid_pos)
	emit_signal("stats_changed")
	_auto_pickup()
	TurnManager.end_player_turn(_race_speed_mod() * Status.speed_mult(self))

func _monster_at(pos: Vector2i) -> Monster:
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return n
	return null

func _auto_pickup() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("floor_items"):
		if n is FloorItem and n.grid_pos == grid_pos:
			pickup(n)
			break

func pickup(floor_item: FloorItem) -> void:
	if floor_item.data == null:
		return
	var data: ItemData = floor_item.data
	if data.kind == "gold":
		# Entry "amount" overrides the static effect_value for floor-scattered piles.
		var amount: int = max(1, int(floor_item.entry.get("amount", data.effect_value)))
		gold += amount
		CombatLog.pickup(LocaleManager.t("LOG_YOU_PICK_UP_GOLD") % amount)
	elif data.kind == "essence":
		var game_node: Node = get_tree().current_scene if get_tree() != null else null
		if game_node != null and game_node.has_method("_pickup_essence_floor_item"):
			game_node._pickup_essence_floor_item(floor_item)
	else:
		var new_entry: Dictionary = floor_item.entry.duplicate(true) if not floor_item.entry.is_empty() else {"id": data.id, "plus": floor_item.plus}
		if data.kind == "wand" and not new_entry.has("charges"):
			new_entry["charges"] = data.effect_value
		items.append(new_entry)
		var pickup_name: String = ItemRegistry.entry_display_name(new_entry) if ItemRegistry != null else GameManager.display_name_of(data.id)
		items_collected += 1
		CombatLog.pickup(LocaleManager.t("LOG_YOU_PICK_UP") % pickup_name)
		if data.kind == "rune":
			var rune_xp: int = _rune_xp_bonus(data.id)
			if rune_xp > 0:
				grant_xp(rune_xp)
				CombatLog.post(LocaleManager.t("LOG_THE_PULSES_WITH_DEEP_POWER") % [pickup_name, rune_xp],
					Color(1.0, 0.85, 0.4))
		auto_bind_quickslot(data.id)
	emit_signal("stats_changed")
	if data.kind != "essence":
		floor_item.queue_free()

func auto_bind_quickslot(item_id: String) -> void:
	if item_id == "":
		return
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null and item_id != "" else null
	if data == null:
		return
	if data.kind != "potion" and data.kind != "scroll":
		return
	if quickslots.has(item_id):
		return
	for i in range(quickslots.size()):
		if String(quickslots[i]) == "":
			quickslots[i] = item_id
			return

func use_quickslot(index: int) -> bool:
	if index < 0 or index >= quickslots.size():
		return false
	var id: String = String(quickslots[index])
	if id == "":
		return false
	for i in range(items.size()):
		if String(items[i].get("id", "")) == id:
			use_item(i)
			# If no more copies of that id remain, unbind the slot.
			if count_item(id) <= 0:
				quickslots[index] = ""
			return true
	quickslots[index] = ""
	return false

func count_item(id: String) -> int:
	var n: int = 0
	for entry in items:
		if String(entry.get("id", "")) == id:
			n += 1
	return n

func try_step(dir: Vector2i) -> void:
	if _map == null or hp <= 0:
		return
	if not TurnManager.is_player_turn:
		return
	_try_move(dir)

func can_attack_tile(target: Vector2i) -> bool:
	return _attack_target_for_tile(target) != null

func try_attack_tile(target: Vector2i) -> bool:
	var monster: Monster = _attack_target_for_tile(target)
	if monster == null:
		return false
	# Face the target before resolving the attack. Without this, in-place
	# strikes (e.g., the player just turned to attack a side adjacency)
	# would leave `facing` stale from the last _try_move, breaking
	# BodyPartSystem DIRECTION_BIAS for any retaliation directed at the
	# player and giving misleading flank semantics for the outgoing hit.
	var dir: Vector2i = target - grid_pos
	if dir.x != 0:
		dir.x = sign(dir.x)
	if dir.y != 0:
		dir.y = sign(dir.y)
	if dir != Vector2i.ZERO:
		facing = dir
		if _renderer != null:
			_renderer.queue_redraw()
	play_bump_anim(target - grid_pos)
	play_attack_anim(equipped_weapon_id)
	var w: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null and equipped_weapon_id != "" else null
	weapon_attacked.emit(target, weapon_skill_for_item(w))
	CombatSystem.player_attack_monster(self, monster)
	TurnManager.end_player_turn(_weapon_action_cost() * Status.speed_mult(self))
	return true

func _weapon_action_cost() -> float:
	var base_delay: float = 1.0
	var skill_id: String = "unarmed"
	if equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
		if w != null and float(w.delay) > 0.0:
			base_delay = float(w.delay)
		if w != null:
			skill_id = weapon_skill_for_item(w)
	var skill_lv: int = get_skill_level(skill_id)
	# Each skill level reduces delay by 2.5%, capped at 25% reduction (lv9 → ×0.775)
	var mult: float = max(0.75, 1.0 - float(skill_lv) * 0.025)
	return base_delay * mult

func _attack_target_for_tile(target: Vector2i) -> Monster:
	var direct: Monster = _monster_at(target)
	if direct != null and direct.is_ally:
		return null  # Never attack allies
	if direct != null and _chebyshev(target, grid_pos) <= 1:
		return direct
	if equipped_weapon_id == "":
		return null
	var weapon: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
	if weapon == null:
		return null
	# Ranged weapon: attack any visible monster within range
	if weapon.category == "ranged":
		if direct == null:
			return null
		var range_val: int = weapon.effect_value if weapon.effect_value > 0 else 6
		if _chebyshev(target, grid_pos) > range_val:
			return null
		if _map != null and not _map.visible_tiles.has(target):
			return null
		return direct
	# Polearm: reach 2 tiles in a straight line
	if weapon.category != "polearm":
		return null
	var delta: Vector2i = target - grid_pos
	var reach: int = _chebyshev(target, grid_pos)
	if reach != 2:
		return null
	var step := Vector2i(sign(delta.x), sign(delta.y))
	if step == Vector2i.ZERO:
		return null
	if grid_pos + step * 2 != target:
		return null
	var middle: Vector2i = grid_pos + step
	if _monster_at(middle) != null:
		return null
	if _map != null and not _map.in_bounds(middle):
		return null
	var reach_monster: Monster = _monster_at(target)
	if reach_monster != null and reach_monster.is_ally:
		return null
	return reach_monster

## Locate the current index of `entry` in items[]. UI callbacks captured an
## entry dict at dialog-open time but items[] mutates between then and the
## button press (auto-use, identification, drop, stack consumption). Searching
## by content equality (Dictionary `==`) keeps the action targeting the right
## slot — or returns -1 if the stack was already consumed.
## Audit H4 fix: replaces stale-index closures in ItemDetailDialog.
func _find_entry_index(entry: Dictionary) -> int:
	if entry == null or entry.is_empty():
		return -1
	for i in range(items.size()):
		if items[i] == entry:
			return i
	# Fallback: id+plus match (entry contents may have been mutated in place).
	var id: String = String(entry.get("id", ""))
	var plus: int = int(entry.get("plus", 0))
	for i in range(items.size()):
		var it: Dictionary = items[i]
		if String(it.get("id", "")) == id and int(it.get("plus", 0)) == plus:
			return i
	return -1

## Remove one item from a stack for throwing. Does not trigger use effects.
func remove_thrown_item(entry: Dictionary) -> void:
	var idx: int = _find_entry_index(entry)
	if idx < 0:
		return
	var count: int = int(items[idx].get("count", 1))
	if count > 1:
		items[idx]["count"] = count - 1
	else:
		items.remove_at(idx)
	stats_changed.emit()

func use_item_by_entry(entry: Dictionary) -> bool:
	var idx: int = _find_entry_index(entry)
	if idx < 0:
		return false
	use_item(idx)
	return true

func drop_item_by_entry(entry: Dictionary) -> bool:
	var idx: int = _find_entry_index(entry)
	if idx < 0:
		return false
	drop_item(idx)
	return true

func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index]
	var entry_id: String = String(entry.get("id", ""))
	var data: ItemData = ItemRegistry.get_by_id(entry_id) if ItemRegistry != null and entry_id != "" else null
	if data == null:
		return
	# Utility XP: wands and scrolls train evocations on use. Books and potions
	# don't (potions are consumables, books grant spells which already train
	# spellcasting via cast events).
	if data.kind == "wand" or data.kind == "scroll":
		grant_skill_xp("evocations", 4.0)
	var had_effect: bool = true
	match data.effect:
		"heal":
			var survival_mult: float = 1.0 + float(get_skill_level("survival")) * 0.03
			var heal_amt: int = maxi(1, int(round(float(data.effect_value) * EssenceSystem.potion_heal_mult(self) * FaithSystem.potion_heal_mult(self) * survival_mult)))
			heal_amt += EssenceSystem.potion_heal_bonus(self)
			heal(heal_amt)
			BodyPartSystem.reduce_wounds(self, 1)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_BETTER_HP") % heal_amt,
				Color(0.6, 1.0, 0.6))
		"bandage":
			var survival_mult: float = 1.0 + float(get_skill_level("survival")) * 0.03
			var heal_amt: int = maxi(1, int(round(6.0 * survival_mult)))
			heal(heal_amt)
			BodyPartSystem.reduce_wounds(self, 1)
			CombatLog.post(LocaleManager.t("LOG_YOU_BANDAGE_YOUR_WOUNDS_HP") % heal_amt, Color(0.85, 0.9, 0.65))
		"blink":
			_blink(data.effect_value)
		"might":
			strength += data.effect_value
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_MIGHTY_STR") % data.effect_value,
				Color(1.0, 0.7, 0.55))
		"map_reveal":
			_reveal_map()
		"cure":
			if statuses.has("poison"):
				statuses.erase("poison")
				CombatLog.post(LocaleManager.t("LOG_THE_POISON_CLEARS"), Color(0.6, 1.0, 0.7))
			else:
				CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_HEALTHY"), Color(0.6, 1.0, 0.7))
		"restore_mp":
			var gain: int = max(1, data.effect_value)
			mp = min(mp_max, mp + gain)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_RECHARGED_MP") % gain,
				Color(0.5, 0.85, 1.0))
		"teleport":
			_teleport_far()
		"shroud":
			apply_status("shrouded", max(4, data.effect_value))
			_break_enemy_awareness(max(2, data.effect_value / 2))
			CombatLog.post(LocaleManager.t("LOG_SHADOWS_GATHER_AROUND_YOU"), Color(0.72, 0.86, 1.0))
		"enchant_weapon":
			_enchant_weapon(max(1, data.effect_value))
		"enchant_armor":
			_enchant_armor(max(1, data.effect_value))
		"berserk":
			apply_berserk(max(1, data.effect_value))
		# --- New potion effects ---
		"haste":
			apply_status("haste", data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_A_SURGE_OF"), Color(0.4, 1.0, 0.6))
		"invisible":
			apply_status("invisible", data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_YOU_FADE_FROM_SIGHT"), Color(0.7, 0.7, 1.0))
		"stat_dex":
			dexterity += data.effect_value
			refresh_ac_from_equipment()
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_MORE_AGILE_1"), Color(0.3, 0.8, 1.0))
		"stat_int":
			intelligence += data.effect_value
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_SHARPER_1_INT"), Color(0.9, 0.9, 0.4))
		"grant_xp":
			grant_xp(data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_MORE_EXPERIENCED"), Color(0.9, 0.6, 1.0))
		# --- New scroll effects ---
		"scroll_fear":
			var game_node: Node = get_tree().current_scene if get_tree() != null else null
			if game_node != null and game_node.has_method("apply_fear_aoe"):
				game_node.apply_fear_aoe(grid_pos, 6, data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_THE_ENEMIES_FLEE_IN_TERROR"), Color(0.9, 0.7, 1.0))
		"scroll_upgrade":
			if equipped_weapon_id != "":
				_enchant_weapon(1)
			elif equipped_armor_id != "":
				_enchant_armor(1)
			else:
				CombatLog.post(LocaleManager.t("LOG_NOTHING_TO_UPGRADE"), Color(0.7, 0.7, 0.7))
				had_effect = false
		"scroll_fog":
			var game_fog: Node = get_tree().current_scene if get_tree() != null else null
			if game_fog != null and game_fog.has_method("apply_fog_aoe"):
				game_fog.apply_fog_aoe(grid_pos, 4, data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_FOG_SPREADS_AROUND_YOU"), Color(0.75, 0.85, 0.95))
		"scroll_brand":
			_enchant_weapon(1)
			CombatLog.post(LocaleManager.t("LOG_YOUR_WEAPON_GLOWS_WITH_NEW"), Color(1.0, 0.85, 0.3))
		"branch_brand":
			_apply_branch_brand(String(data.brand))
		"scroll_silence":
			var game_sil: Node = get_tree().current_scene if get_tree() != null else null
			if game_sil != null and game_sil.has_method("apply_silence_aoe"):
				game_sil.apply_silence_aoe(grid_pos, 6, data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_SILENCE_FALLS_UPON_YOUR_FOES"), Color(0.7, 0.85, 1.0))
		"scroll_immolation":
			var game_imm: Node = get_tree().current_scene if get_tree() != null else null
			if game_imm != null and game_imm.has_method("apply_immolation_aoe"):
				game_imm.apply_immolation_aoe(grid_pos, data.effect_value)
			else:
				var imm_map = _map
				if imm_map != null:
					for eid in imm_map.entities:
						var ent = imm_map.entities[eid]
						if ent == self:
							continue
						if not imm_map.visible_tiles.has(ent.grid_pos):
							continue
						ent.take_damage(data.effect_value, "fire")
			CombatLog.post(LocaleManager.t("LOG_NEARBY_ENEMIES_BURST_INTO_FLAME"), Color(1.0, 0.5, 0.1))
		"scroll_noise":
			var game_ns: Node = get_tree().current_scene if get_tree() != null else null
			if game_ns != null and game_ns.has_method("alert_all_monsters"):
				game_ns.alert_all_monsters()
			else:
				var ns_map = _map
				if ns_map != null:
					for eid in ns_map.entities:
						var ent = ns_map.entities[eid]
						if ent != self and ent.has_method("alert"):
							ent.alert(grid_pos)
			CombatLog.post(LocaleManager.t("LOG_A_LOUD_NOISE_ECHOES_THROUGH"), Color(1.0, 0.8, 0.4))
		# --- Negative potion effects (drinking) ---
		"drink_poison":
			apply_status("poison", data.effect_value)
			CombatLog.post("The liquid burns like acid — you've been poisoned!", Color(0.3, 1.0, 0.3))
		"drink_confusion":
			apply_status("confusion", data.effect_value)
			CombatLog.post("Your thoughts dissolve into chaos.", Color(0.8, 0.5, 1.0))
		"drink_degeneration":
			apply_status("weak", data.effect_value)
			CombatLog.post("You feel your strength drain away.", Color(0.6, 0.6, 0.4))
		"drink_paralysis":
			apply_status("paralyzed", data.effect_value)
			CombatLog.post("Your body locks up completely!", Color(0.85, 0.85, 0.9))
		"drink_toxic_gas":
			apply_status("poison", data.effect_value)
			if _map != null:
				ThrowSystem._splash_cloud(grid_pos, 1, "poison", 5, get_tree().current_scene)
			CombatLog.post("A noxious cloud erupts around you!", Color(0.3, 1.0, 0.3))
		"drink_liquid_flame":
			take_damage(randi_range(6, 12), "fire")
			apply_status("burning", 4)
			if _map != null:
				ThrowSystem._splash_cloud(grid_pos, 1, "fire", 4, get_tree().current_scene)
			CombatLog.post("Liquid fire scorches your throat and everything nearby!", Color(1.0, 0.4, 0.1))
		# --- New negative scroll effects ---
		"curse_equipment":
			var cursed_count: int = 0
			for slot_id in ["equipped_weapon_id", "equipped_armor_id", "equipped_shield_id",
					"equipped_helmet_id", "equipped_gloves_id", "equipped_boots_id"]:
				if get(slot_id) != "":
					apply_status("cursed_" + slot_id, 999)
					cursed_count += 1
			if cursed_count > 0:
				CombatLog.post("A dark energy binds your equipment to you!", Color(0.5, 0.3, 0.8))
			else:
				CombatLog.post("Nothing happens.", Color(0.7, 0.7, 0.7))
				had_effect = false
		"torment":
			var dmg: int = maxi(1, hp / 2)
			take_damage(dmg)
			CombatLog.post("Agony courses through every living thing on the floor!", Color(0.8, 0.2, 0.2))
			var game_t: Node = get_tree().current_scene if get_tree() != null else null
			if game_t != null:
				for n in game_t.get_tree().get_nodes_in_group("monsters"):
					if n is Monster:
						n.take_damage(maxi(1, n.hp / 2))
		"vulnerability":
			apply_status("vulnerable", data.effect_value)
			CombatLog.post("Your defences crumble!", Color(1.0, 0.5, 0.5))
			var game_v: Node = get_tree().current_scene if get_tree() != null else null
			if game_v != null:
				for n in game_v.get_tree().get_nodes_in_group("monsters"):
					if n is Monster:
						Status.apply(n, "vulnerable", data.effect_value)
		"resistance":
			apply_status("resist_fire", data.effect_value)
			apply_status("resist_cold", data.effect_value)
			apply_status("resist_poison", data.effect_value)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_RESISTANT_TO_FIRE"), Color(0.4, 0.7, 1.0))
		"cancellation":
			var neg_statuses := ["poison", "slow", "fear", "blind", "silence", "burning", "frozen", "paralyzed"]
			for st in neg_statuses:
				if statuses.has(st):
					statuses.erase(st)
			stats_changed.emit()
			CombatLog.post(LocaleManager.t("LOG_YOUR_NEGATIVE_EFFECTS_ARE_CANCELLED"), Color(0.85, 0.85, 0.85))
		# --- Wand effects ---
		"wand_haste":
			apply_status("haste", 12)
			CombatLog.post(LocaleManager.t("LOG_YOU_FEEL_A_SURGE_OF"), Color(0.4, 1.0, 0.6))
		"wand_fear":
			var game_wf: Node = get_tree().current_scene if get_tree() != null else null
			if game_wf != null and game_wf.has_method("apply_fear_aoe"):
				game_wf.apply_fear_aoe(grid_pos, 5, 8)
			CombatLog.post(LocaleManager.t("LOG_YOUR_FOES_TURN_AND_FLEE"), Color(0.9, 0.7, 1.0))
		"wand_digging":
			var game_wd: Node = get_tree().current_scene if get_tree() != null else null
			if game_wd != null and game_wd.has_method("dig_toward"):
				game_wd.dig_toward(grid_pos)
			CombatLog.post(LocaleManager.t("LOG_THE_WAND_PULSES_WITH_DIGGING"), Color(0.8, 0.7, 0.5))
		"wand_teleport":
			_teleport_far()
		"wand_fire", "wand_frost", "wand_lightning":
			pass  # effect and log handled by Game.gd before use_quickslot
		# --- Throwing effects ---
		"throw_pierce", "throw_heavy", "throw_fire_aoe", "throw_poison", "throw_smoke":
			CombatLog.post(LocaleManager.t("LOG_YOU_THROW_THE") % data.display_name, Color(0.85, 0.85, 0.7))
		"study":
			var all_ids: Array = []
			# Partial books store their spell list in the entry dict; check it first.
			if entry.has("grants_spell_ids") and not entry["grants_spell_ids"].is_empty():
				for sid in entry["grants_spell_ids"]:
					all_ids.append(String(sid))
			else:
				if data.grants_spell_id != "":
					all_ids.append(data.grants_spell_id)
				for sid in data.grants_spell_ids:
					all_ids.append(String(sid))
			var learned_count: int = 0
			var blocked_count: int = 0
			for sid in all_ids:
				var sid_s: String = String(sid)
				if learn_spell(sid_s):
					learned_count += 1
					had_effect = true
				elif not known_spells.has(sid_s):
					blocked_count += 1
			if learned_count == 0:
				if blocked_count > 0:
					CombatLog.post(LocaleManager.t("LOG_THE_TOME_IS_BEYOND_YOUR"), Color(1.0, 0.72, 0.5))
					if data.kind in ["book", "spellpage"]:
						return
				else:
					CombatLog.post(LocaleManager.t("LOG_YOU_ALREADY_KNOW_ALL_SPELLS"), Color(0.7, 0.85, 1.0))
					had_effect = false
		"identify":
			items.remove_at(index)
			emit_signal("stats_changed")
			var picker_parent: Node = get_tree().current_scene \
					if get_tree() != null else self
			IdentifyPicker.open(self, picker_parent)
			return
		_:
			had_effect = false
	# Side grants — run regardless of match, but skip for partial books since
	# the study match block already handled the entry-level grants_spell_ids.
	var _entry_overrides_spells: bool = entry.has("grants_spell_ids") and \
			not entry["grants_spell_ids"].is_empty()
	if not _entry_overrides_spells:
		if String(data.grants_spell_id) != "" \
				and not known_spells.has(data.grants_spell_id):
			known_spells.append(data.grants_spell_id)
			var s: SpellData = SpellRegistry.get_by_id(data.grants_spell_id)
			var sname: String = s.display_name if s != null else data.grants_spell_id
			CombatLog.post(LocaleManager.t("LOG_YOU_LEARN") % sname, Color(0.7, 0.95, 1.0))
			had_effect = true
		for sid in data.grants_spell_ids:
			if not known_spells.has(sid):
				known_spells.append(sid)
				var s2: SpellData = SpellRegistry.get_by_id(sid)
				var sname2: String = s2.display_name if s2 != null else sid
				CombatLog.post(LocaleManager.t("LOG_YOU_LEARN") % sname2, Color(0.7, 0.95, 1.0))
				had_effect = true
	if String(data.unlocks_class_id) != "":
		GameManager.try_use_unlock(data.id)
		had_effect = true
	if not had_effect:
		CombatLog.post(LocaleManager.t("LOG_NOTHING_HAPPENS"), Color(0.7, 0.7, 0.7))
	# Wand: consume a charge instead of removing the item entirely.
	if data.kind == "wand":
		var wand_entry: Dictionary = items[index]
		var charges: int = int(wand_entry.get("charges", data.effect_value))
		if randf() >= FaithSystem.wand_charge_save_chance(self):
			charges -= 1
		if charges <= 0:
			CombatLog.post(LocaleManager.t("LOG_THE_IS_EXHAUSTED") % data.display_name, Color(0.6, 0.6, 0.6))
			items.remove_at(index)
		else:
			wand_entry["charges"] = charges
			items[index] = wand_entry
			CombatLog.post(LocaleManager.t("LOG_CHARGES_REMAINING") % charges, Color(0.5, 0.8, 0.9))
		emit_signal("stats_changed")
		return
	# Auto-identify on first successful use (consumables only).
	if data.kind in ["potion", "scroll", "book", "spellpage"]:
		GameManager.identify(data.id)
	items.remove_at(index)
	emit_signal("stats_changed")

func drop_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index].duplicate(true)
	var id: String = String(entry.get("id", ""))
	if id == equipped_weapon_id:
		set_equipped_weapon("")
	if id == equipped_armor_id:
		set_equipped_armor("")
	if id == equipped_ring_id:
		set_equipped_ring("")
	if id == equipped_amulet_id:
		set_equipped_amulet("")
	if id == equipped_shield_id:
		set_equipped_shield("")
	if id == equipped_helmet_id:
		set_equipped_helmet("")
	if id == equipped_gloves_id:
		set_equipped_gloves("")
	if id == equipped_boots_id:
		set_equipped_boots("")
	items.remove_at(index)
	emit_signal("item_dropped", entry, grid_pos)
	emit_signal("stats_changed")

func equipped_weapon_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_weapon_id:
			return entry
	return {}

func equipped_armor_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_armor_id:
			return entry
	return {}

func equipped_shield_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_shield_id:
			return entry
	return {}

func equipped_helmet_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_helmet_id:
			return entry
	return {}

func equipped_gloves_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_gloves_id:
			return entry
	return {}

func equipped_boots_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_boots_id:
			return entry
	return {}


func equipped_ring_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_ring_id:
			return entry
	return {}

func equipped_amulet_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_amulet_id:
			return entry
	return {}

func refresh_ac_from_equipment() -> void:
	ac = 0
	ev = 1 + dexterity / 2 + get_skill_level("agility")
	var armor: ItemData = ItemRegistry.get_by_id(equipped_armor_id) if ItemRegistry != null and equipped_armor_id != "" else null
	if armor != null:
		var armor_plus: int = int(equipped_armor_entry().get("plus", 0))
		ac += armor.ac_bonus + armor_plus
		var armor_skill: int = get_skill_level("armor")
		var penalty_mult: float = max(0.0, 1.0 - float(armor_skill) * 0.1)
		ev -= int(round(float(armor.ev_penalty) * penalty_mult))
		var armor_missing: int = max(0, armor.required_skill - armor_skill)
		ev -= armor_missing
	var shield: ItemData = ItemRegistry.get_by_id(equipped_shield_id) if ItemRegistry != null and equipped_shield_id != "" else null
	if shield != null:
		ev -= shield.ev_penalty
		var shield_skill: int = get_skill_level("shield")
		var shield_missing: int = max(0, shield.required_skill - shield_skill)
		ev -= shield_missing

	var helmet: ItemData = ItemRegistry.get_by_id(equipped_helmet_id) if ItemRegistry != null and equipped_helmet_id != "" else null
	if helmet != null:
		var helmet_plus: int = int(equipped_helmet_entry().get("plus", 0))
		ac += helmet.ac_bonus + helmet_plus

	var gloves: ItemData = ItemRegistry.get_by_id(equipped_gloves_id) if ItemRegistry != null and equipped_gloves_id != "" else null
	if gloves != null:
		var gloves_plus: int = int(equipped_gloves_entry().get("plus", 0))
		ac += gloves.ac_bonus + gloves_plus

	var boots: ItemData = ItemRegistry.get_by_id(equipped_boots_id) if ItemRegistry != null and equipped_boots_id != "" else null
	if boots != null:
		var boots_plus: int = int(equipped_boots_entry().get("plus", 0))
		ac += boots.ac_bonus + boots_plus

	if has_status("mage_armor"):
		ac = max(ac, 13 + dexterity / 2)
	ac += EssenceSystem.bonus_ac(self)
	ev += EssenceSystem.bonus_ev(self)
	ev += agility_mastery_ev_bonus()
	ev = max(0, ev)
	emit_signal("stats_changed")

func _apply_branch_brand(element: String) -> void:
	var target: String = "weapon" if randf() < 0.5 else "armor"
	var target_id: String = equipped_weapon_id if target == "weapon" else equipped_armor_id
	if target_id == "":
		# Fallback to the other slot
		target = "armor" if target == "weapon" else "weapon"
		target_id = equipped_weapon_id if target == "weapon" else equipped_armor_id
	if target_id == "":
		CombatLog.post(LocaleManager.t("LOG_YOU_HAVE_NO_EQUIPMENT_TO"), Color(1.0, 0.7, 0.5))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == target_id:
			entry["brand"] = element
			items[i] = entry
			var idata: ItemData = ItemRegistry.get_by_id(target_id) if ItemRegistry != null and target_id != "" else null
			var name_: String = idata.display_name if idata != null else target_id
			var element_colors: Dictionary = {
				"venom": Color(0.4, 1.0, 0.4),
				"freezing": Color(0.5, 0.85, 1.0),
				"flaming": Color(1.0, 0.55, 0.2),
			}
			CombatLog.post(LocaleManager.t("LOG_YOUR_IS_BRANDED_WITH") % [name_, element],
				element_colors.get(element, Color.WHITE))
			emit_signal("stats_changed")
			return

func _enchant_weapon(amount: int) -> void:
	if equipped_weapon_id == "":
		CombatLog.post(LocaleManager.t("LOG_NOTHING_TO_ENCHANT"), Color(0.8, 0.8, 0.6))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == equipped_weapon_id:
			entry["plus"] = int(entry.get("plus", 0)) + amount
			items[i] = entry
			var data: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
			var name_: String = data.display_name if data != null else "weapon"
			CombatLog.post(LocaleManager.t("LOG_YOUR_GLOWS") % [name_, amount],
				Color(1.0, 0.9, 0.5))
			return

func _enchant_armor(amount: int) -> void:
	if equipped_armor_id == "":
		CombatLog.post(LocaleManager.t("LOG_NOTHING_TO_ENCHANT"), Color(0.8, 0.8, 0.6))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == equipped_armor_id:
			entry["plus"] = int(entry.get("plus", 0)) + amount
			items[i] = entry
			var data: ItemData = ItemRegistry.get_by_id(equipped_armor_id) if ItemRegistry != null and equipped_armor_id != "" else null
			var name_: String = data.display_name if data != null else "armor"
			CombatLog.post(LocaleManager.t("LOG_YOUR_GLOWS") % [name_, amount],
				Color(0.85, 1.0, 0.7))
			refresh_ac_from_equipment()
			return

func _teleport_far() -> void:
	if _map == null:
		return
	for _i in range(80):
		var p := Vector2i(
			randi_range(1, _map.GRID_W - 2),
			randi_range(1, _map.GRID_H - 2))
		if not _map.is_walkable(p):
			continue
		if _monster_at(p) != null:
			continue
		if p == grid_pos:
			continue
		grid_pos = p
		position = _map.grid_to_world(p)
		emit_signal("moved", grid_pos)
		CombatLog.post(LocaleManager.t("LOG_YOU_TELEPORT"), Color(0.85, 0.7, 1.0))
		return
	CombatLog.post(LocaleManager.t("LOG_NOTHING_HAPPENS"), Color(0.7, 0.7, 0.7))

func _reveal_map() -> void:
	if _map == null:
		return
	for y in range(_map.GRID_H):
		for x in range(_map.GRID_W):
			var p := Vector2i(x, y)
			if _map.tile_at(p) != DungeonMap.Tile.WALL:
				_map.explored[p] = true
	_map.queue_redraw()
	CombatLog.post(LocaleManager.t("LOG_THE_FLOOR_S_LAYOUT_BECOMES"),
		Color(0.85, 0.7, 1.0))

func _blink(max_dist: int) -> void:
	for _i in range(24):
		var dx: int = randi_range(-max_dist, max_dist)
		var dy: int = randi_range(-max_dist, max_dist)
		var target: Vector2i = grid_pos + Vector2i(dx, dy)
		if target == grid_pos:
			continue
		if not _map.in_bounds(target):
			continue
		if not _map.is_walkable(target):
			continue
		if _monster_at(target) != null:
			continue
		grid_pos = target
		position = _map.grid_to_world(target)
		emit_signal("moved", grid_pos)
		CombatLog.post(LocaleManager.t("LOG_YOU_BLINK"), Color(0.7, 0.85, 1.0))
		return
	CombatLog.post(LocaleManager.t("LOG_NOTHING_HAPPENS"), Color(0.7, 0.7, 0.7))

func _break_enemy_awareness(radius: int) -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if _chebyshev(n.grid_pos, grid_pos) <= radius:
			continue
		n.is_alerted = false
		n.last_known_player_pos = Vector2i(-1, -1)
		n.lose_awareness()

func take_damage(amount: int, source: String = "") -> void:
	if source != "":
		last_killer = source
	super.take_damage(amount, source)

func _on_take_damage_visual() -> void:
	play_hit_anim()

func _on_equipment_changed() -> void:
	if _renderer != null:
		_renderer.refresh_equipment(self)

func play_bump_anim(dir: Vector2i) -> void:
	var origin: Vector2 = position
	var bump_offset := Vector2(dir.x, dir.y) * 8.0
	var tw := create_tween()
	tw.tween_property(self, "position", origin + bump_offset, 0.07)
	tw.tween_property(self, "position", origin, 0.07)

func play_attack_anim(weapon_id: String) -> void:
	if _renderer != null:
		_renderer.play_attack_anim(weapon_id)

func play_spellcast_anim() -> void:
	if _renderer != null:
		_renderer.play_spellcast_anim()

func play_hit_anim() -> void:
	var origin: Vector2 = position
	var tw := create_tween()
	tw.tween_property(self, "position", origin + Vector2(4, 0), 0.04)
	tw.tween_property(self, "position", origin + Vector2(-4, 0), 0.04)
	tw.tween_property(self, "position", origin + Vector2(3, 0), 0.03)
	tw.tween_property(self, "position", origin, 0.03)


func register_kill() -> void:
	kills += 1

func _apply_max_hp_gain(amount: int, source: String = "") -> void:
	if amount == 0:
		return
	hp_max = max(1, hp_max + amount)
	if amount > 0:
		hp = min(hp_max, hp + amount)
	else:
		hp = min(hp, hp_max)
	if source != "" and CombatLog != null:
		CombatLog.post(source, Color(0.85, 0.6, 0.6))

func _apply_max_mp_gain(amount: int) -> void:
	if amount == 0:
		return
	mp_max = max(1, mp_max + amount)
	if amount > 0:
		mp = min(mp_max, mp + amount)
	else:
		mp = min(mp, mp_max)

func _fighting_hp_gain() -> int:
	return FIGHTING_HP_PER_LEVEL

func _level_up_mp_gain() -> int:
	return 1 + intelligence / 3

func grant_kill_skill_xp(amount: float, action_skill: String = "") -> void:
	# Route kill XP through grant_skill_xp so dual-write to hidden tier
	# happens correctly. Two-mode XP routing:
	#   active_skills empty  → action-routed: full XP to action_skill
	#   active_skills filled → manual: split across active visible skills
	# action_skill may be a legacy/sub-skill id; it is translated to canonical.
	if amount <= 0.0:
		return
	var canon_action: String = _canonical_skill(action_skill)
	var fallback: String = canon_action if canon_action != "" else "weapon_mastery"
	if active_skills.is_empty():
		# Preserve the caller's original id (could be a hidden sub-skill like
		# "polearms") so dual-write into hidden tier still fires for it.
		var grant_id: String = action_skill if HIDDEN_SUBSKILL_IDS.has(action_skill) or SKILL_IDS.has(action_skill) else fallback
		grant_skill_xp(grant_id, amount)
		return
	var targets: Array = []
	for id in active_skills:
		var sid: String = String(id)
		if SKILL_IDS.has(sid) and get_skill_level(sid) < MAX_SKILL_LEVEL:
			targets.append(sid)
	if targets.is_empty():
		targets = [fallback]
	var share: float = amount / float(targets.size())
	for sid in targets:
		grant_skill_xp(String(sid), share)

## DCSS mastery system — DEPRECATED under PROJ_G 9-skill model.
## Stubs return identity values so UI cards render empty/no-effect until the
## UI sweep removes them. Do not add new callers.
func melee_mastery_dmg_mult() -> float:
	return 1.0

func ranged_mastery_dmg_mult() -> float:
	return 1.0

func magic_mastery_power_mult() -> float:
	return 1.0

func defense_mastery_incoming_mult() -> float:
	return 1.0

func agility_mastery_ev_bonus() -> int:
	return 0

func utility_mastery_effect_mult() -> float:
	return 1.0

func get_category_total_xp(_category: String) -> float:
	return 0.0

func get_category_mastery_level(_category: String) -> int:
	return 0

func get_skill_xp(id: String) -> float:
	var canon: String = _canonical_skill(id)
	if canon == "":
		return 0.0
	var entry: Dictionary = skills.get(canon, {"xp": 0.0})
	return float(entry.get("xp", 0.0))

## Hidden-tier inspector — reserved for the future balance pass / debug tools.
## UI must not surface this. Returns the silent familiarity level for a
## DCSS-style sub-skill id (dagger / polearms / fire / etc.).
func get_hidden_familiarity_level(subskill_id: String) -> int:
	var entry: Dictionary = hidden_skills.get(subskill_id, {"level": 0})
	return int(entry.get("level", 0))

func get_hidden_familiarity_xp(subskill_id: String) -> float:
	var entry: Dictionary = hidden_skills.get(subskill_id, {"xp": 0.0})
	return float(entry.get("xp", 0.0))

static func progression_school_for(raw_school: String) -> String:
	match raw_school:
		"fire":
			return "fire"
		"cold", "ice":
			return "ice"
		"air":
			return "air"
		"earth":
			return "earth"
		"alchemy", "poison":
			return "poison"
		"conjuration", "conjurations":
			return "conjurations"
		"translocation", "translocations":
			return "translocations"
		"transmutation":
			return "transmutation"
		"charm", "charms":
			return "charms"
		"abjuration", "evocation", "forgecraft":
			return "conjurations"
		"hex", "hexes", "enchantment":
			return "hexes"
		"necromancy":
			return "necromancy"
		"summoning", "summonings":
			return "summonings"
	return raw_school

static func weapon_skill_for_item(item: ItemData) -> String:
	if item == null:
		return "unarmed"
	match String(item.category):
		"dagger":
			return "short_blades"
		"blade":
			return "long_blades"
		"axe":
			return "axes"
		"blunt":
			return "maces"
		"polearm":
			return "polearms"
		"ranged":
			# No sub-category field on ItemData yet — match on id substring.
			# Order matters: check "crossbow" before "bow".
			var lid: String = String(item.id).to_lower()
			if "crossbow" in lid or "arbalest" in lid:
				return "crossbows"
			if "sling" in lid:
				return "slings"
			if "javelin" in lid or "dart" in lid or "boomerang" in lid or "throw" in lid:
				return "throwing"
			return "bows"
		"staff":
			return "spellcasting"  # TODO: route to "staves" once items mark combat staff vs magical staff
	return "unarmed"

func spell_skill_for(spell: SpellData) -> String:
	if spell == null:
		return "spellcasting"
	return progression_school_for(String(spell.school))

## Aptitude lookup. Translates the requested id to the canonical visible
## bucket, then:
##   1) tries the canonical key directly on the race aptitude dict
##   2) falls back to averaging all old (sub-skill / legacy) keys that
##      remap to the same canonical bucket — keeps existing race .tres
##      files working without per-file migration.
## Return value is int to preserve the previous signature (callers expect int).
static func aptitude_for(race: RaceData, skill_id: String) -> int:
	if race == null:
		return 0
	var canon: String = String(Actor.SKILL_REMAP.get(skill_id, ""))
	if canon == "":
		return 0
	var apts: Dictionary = race.skill_aptitudes if race.skill_aptitudes != null else {}
	if apts.has(canon):
		return int(apts[canon])
	# Fallback: average all old keys that remap to the same canonical bucket.
	var total: float = 0.0
	var count: int = 0
	for old_id in apts.keys():
		if String(Actor.SKILL_REMAP.get(old_id, "")) == canon:
			total += float(apts[old_id])
			count += 1
	if count == 0:
		return 0
	return int(round(total / float(count)))

func _skill_apt_mult(id: String) -> float:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id) if GameManager != null and RaceRegistry != null else null
	if race == null:
		return 1.0
	return pow(1.2, aptitude_for(race, id))

## Visible-tier level-up side effects. Extracted so the hidden tier can
## share level-up math without firing UI logs / stat bumps. Caller must
## have already incremented `skills[canon]["level"]`.
func _on_visible_skill_level_up(canonical_id: String, new_level: int) -> void:
	var pretty: String = canonical_id.capitalize().replace("_", " ")
	CombatLog.post(LocaleManager.t("LOG_SKILL_REACHES") % [pretty, new_level],
		Color(0.7, 0.95, 0.5))
	match canonical_id:
		"stealth":
			ev += 1
		"tactics":
			var hp_gain: int = _fighting_hp_gain()
			_apply_max_hp_gain(hp_gain, "+%d max HP from Tactics." % hp_gain)

## Dual-write skill XP grant.
##   - Resolve canonical visible bucket via SKILL_REMAP.
##   - Add XP to visible bucket (with race aptitude mult on visible only),
##     run level-up loop, fire side effects.
##   - If `id` is also a hidden sub-skill, ALSO add raw XP to the matching
##     hidden bucket and run a silent level-up loop (no log, no stats).
##   - Unknown ids: silent no-op.
##   - `active_skills` filter applies to the visible tier only.
func grant_skill_xp(id: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var canon: String = _canonical_skill(id)
	if canon == "":
		return  # unknown id, silent no-op
	# ── Visible tier ─────────────────────────────────────────────────────
	if active_skills.size() > 0 and not active_skills.has(canon):
		# Visible bucket filtered out by manual-mode selection. Hidden tier
		# still gets to accumulate (it represents item-specific familiarity,
		# which is independent of which visible skill the player is grinding).
		pass
	else:
		if not skills.has(canon):
			skills[canon] = {"level": 0, "xp": 0.0}
		var v_entry: Dictionary = skills[canon]
		v_entry["xp"] = float(v_entry.get("xp", 0.0)) + amount * _skill_apt_mult(canon)
		while int(v_entry.get("level", 0)) < MAX_SKILL_LEVEL:
			var lv: int = int(v_entry["level"])
			var need: float = float(SKILL_XP_DELTA[lv]) if lv < SKILL_XP_DELTA.size() else 99999.0
			if float(v_entry["xp"]) < need:
				break
			v_entry["xp"] = float(v_entry["xp"]) - need
			v_entry["level"] = lv + 1
			_on_visible_skill_level_up(canon, int(v_entry["level"]))
		skills[canon] = v_entry
	# ── Hidden tier (only if caller passed a hidden-tier sub-skill id) ───
	if HIDDEN_SUBSKILL_IDS.has(id):
		if not hidden_skills.has(id):
			hidden_skills[id] = {"level": 0, "xp": 0.0}
		var h_entry: Dictionary = hidden_skills[id]
		h_entry["xp"] = float(h_entry.get("xp", 0.0)) + amount
		while int(h_entry.get("level", 0)) < MAX_SKILL_LEVEL:
			var lv2: int = int(h_entry["level"])
			var need2: float = float(SKILL_XP_DELTA[lv2]) if lv2 < SKILL_XP_DELTA.size() else 99999.0
			if float(h_entry["xp"]) < need2:
				break
			h_entry["xp"] = float(h_entry["xp"]) - need2
			h_entry["level"] = lv2 + 1
			# silent — no log, no stat side effect
		hidden_skills[id] = h_entry
	emit_signal("stats_changed")

## Rune pickup bonus: entry_depth × 150, where entry_depth = top of the branch
## entrance range. Encourages deeper branch attempts (swamp 900, ice 1350,
## infernal 1800, crypt 2250 — total 6300 for full-4). Returns 0 for unknown
## runes. Tuned 2026-05-06 from ×100 → ×150 to push thorough full-4 runs to
## the XL 19-20 target.
func _rune_xp_bonus(rune_id: String) -> int:
	var zm = get_node_or_null("/root/ZoneManager")
	if zm == null:
		return 0
	for cfg in zm.BRANCHES.values():
		if String(cfg.get("rune_reward", "")) != rune_id:
			continue
		var rng: Array = cfg.get("entrance_range", [])
		if rng.size() >= 2:
			return int(rng[1]) * 150
		break
	return 0

func grant_xp(amount: int) -> void:
	xp += amount
	while xl < MAX_XL and xp >= xp_to_next():
		_level_up()
	emit_signal("stats_changed")

func xp_to_next() -> int:
	if xl < XP_CURVE.size():
		return XP_CURVE[xl]
	var base: float = float(XP_CURVE[XP_CURVE.size() - 1])
	return int(base * pow(1.35, xl - XP_CURVE.size() + 1))

func _level_up() -> void:
	xl += 1
	var hp_gain: int = _level_up_hp_gain()
	_apply_max_hp_gain(hp_gain)
	var mp_gain: int = _level_up_mp_gain()
	_apply_max_mp_gain(mp_gain)
	CombatLog.post(LocaleManager.t("LOG_LEVEL_UP_YOU_ARE_NOW") % xl,
		Color(1.0, 0.9, 0.3))
	if xl == 12 or xl == 15 or xl == 18:
		_auto_stat_bump()

func _level_up_hp_gain() -> int:
	var base: int = 5
	if GameManager != null and RaceRegistry != null:
		var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
		if race != null:
			base = race.hp_per_level
	return max(1, base + strength / 8)

func _auto_stat_bump() -> void:
	# Pick the lowest stat and +1. Simplification of the classic
	# player-choice bump; tie-breaks favour STR > DEX > INT.
	var lowest_name: String = "strength"
	var lowest_val: int = strength
	if dexterity < lowest_val:
		lowest_name = "dexterity"
		lowest_val = dexterity
	if intelligence < lowest_val:
		lowest_name = "intelligence"
		lowest_val = intelligence
	match lowest_name:
		"strength":
			var old_bonus: int = strength_hp_bonus_for_value(strength)
			strength += 1
			var hp_delta: int = strength_hp_bonus_for_value(strength) - old_bonus
			if hp_delta > 0:
				_apply_max_hp_gain(hp_delta)
		"dexterity": dexterity += 1
		"intelligence": intelligence += 1
	CombatLog.post(LocaleManager.t("LOG_1") % lowest_name.to_upper(), Color(0.75, 0.85, 1))

func learn_spell(spell_id: String) -> bool:
	var sid: String = String(spell_id)
	if sid == "" or known_spells.has(sid):
		return false
	var spell: SpellData = SpellRegistry.get_by_id(sid)
	if spell == null:
		return false
	var int_req: int = int_required_for_spell(spell)
	if intelligence < int_req:
		CombatLog.post(LocaleManager.t("LOG_REQUIRES_INT") % [spell.display_name, int_req], Color(1.0, 0.72, 0.5))
		return false
	known_spells.append(sid)
	CombatLog.post(LocaleManager.t("LOG_YOU_MEMORIZE") % spell.display_name, Color(0.7, 0.95, 1.0))
	emit_signal("stats_changed")
	return true

func add_school_spells(school: String) -> void:
	for spell in SpellRegistry.get_by_progression_school(school):
		if spell == null:
			continue
		var sid: String = String(spell.id)
		if not known_spells.has(sid):
			known_spells.append(sid)

func int_required_for_spell(spell: SpellData) -> int:
	if spell == null:
		return 99
	return max(5, 7 + spell.spell_level * 2 - EssenceSystem.spell_int_discount(self) - wizardry_bonus)

func equip_essence(slot: int, essence_id: String) -> void:
	if slot < 0 or slot >= essence_slots.size():
		return
	if not EssenceSystem.slot_is_unlocked(self, slot):
		return
	if essence_id != "" and not FaithSystem.allows_essence(self):
		if CombatLog != null:
			if not FaithSystem.has_chosen_faith(self):
				CombatLog.post(LocaleManager.t("LOG_CHOOSE_A_FAITH_BEFORE_ATTUNING"), Color(1.0, 0.72, 0.5))
			else:
				CombatLog.post(LocaleManager.t("LOG_YOUR_CURRENT_FAITH_DOES_NOT"), Color(1.0, 0.72, 0.5))
		return
	var old: String = String(essence_slots[slot])
	if old == essence_id:
		return
	if old != "" and essence_id == "" and EssenceSystem.inventory_is_full(self):
		CombatLog.post(LocaleManager.t("LOG_YOUR_ESSENCE_INVENTORY_IS_FULL"), Color(1.0, 0.72, 0.5))
		return
	if old != "":
		EssenceSystem.remove(self, old)
		essence_inventory.append(old)
	if essence_id != "":
		essence_inventory.erase(essence_id)
		EssenceSystem.apply(self, essence_id)
	essence_slots[slot] = essence_id
	emit_signal("stats_changed")

func can_add_essence(essence_id: String) -> bool:
	if essence_id == "":
		return false
	if essence_inventory.has(essence_id):
		return false
	if essence_slots.has(essence_id):
		return false
	return essence_inventory.size() < EssenceSystem.inventory_capacity(self)

func add_essence(essence_id: String) -> bool:
	if not can_add_essence(essence_id):
		return false
	essence_inventory.append(essence_id)
	emit_signal("stats_changed")
	return true

func replace_inventory_essence(old_id: String, new_id: String) -> bool:
	if old_id == "" or new_id == "":
		return false
	if not essence_inventory.has(old_id):
		return false
	if essence_inventory.has(new_id) or essence_slots.has(new_id):
		return false
	var idx: int = essence_inventory.find(old_id)
	if idx < 0:
		return false
	essence_inventory[idx] = new_id
	emit_signal("stats_changed")
	return true

func set_race_from_id(_race_id: String) -> void:
	# Race visuals are handled by PlayerRenderer.
	# GameManager.selected_race_id is already updated before this is called.
	if _renderer != null:
		_renderer.refresh_equipment(self)

func set_equipped_weapon(id: String) -> void:
	if equipped_weapon_id != "":
		_remove_entry_affixes(equipped_weapon_entry())
	equipped_weapon_id = id
	if id != "":
		_apply_entry_affixes(equipped_weapon_entry())
	# A two-handed weapon and a shield can never coexist: equipping the 2H
	# auto-frees the shield slot.
	if has_two_handed_weapon() and equipped_shield_id != "":
		set_equipped_shield("")
	_refresh_paperdoll()
	emit_signal("stats_changed")

func set_equipped_armor(id: String) -> void:
	if equipped_armor_id != "":
		_remove_entry_affixes(equipped_armor_entry())
	equipped_armor_id = id
	if id != "":
		_apply_entry_affixes(equipped_armor_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()  # emits stats_changed

func set_equipped_ring(id: String) -> void:
	if equipped_ring_id != "":
		_remove_accessory_stat(equipped_ring_id)
		_remove_entry_affixes(equipped_ring_entry())
	equipped_ring_id = id
	if id != "":
		_apply_accessory_stat(id)
		_apply_entry_affixes(equipped_ring_entry())
	emit_signal("stats_changed")

func set_equipped_amulet(id: String) -> void:
	if equipped_amulet_id != "":
		_remove_accessory_stat(equipped_amulet_id)
		_remove_entry_affixes(equipped_amulet_entry())
	equipped_amulet_id = id
	if id != "":
		_apply_accessory_stat(id)
		_apply_entry_affixes(equipped_amulet_entry())
	emit_signal("stats_changed")

func set_equipped_shield(id: String) -> void:
	if equipped_shield_id != "":
		_remove_entry_affixes(equipped_shield_entry())
	equipped_shield_id = id
	if id != "":
		_apply_entry_affixes(equipped_shield_entry())
		# Equipping a shield while wielding a two-hander forces the weapon
		# off — the player explicitly chose the shield.
		if has_two_handed_weapon():
			set_equipped_weapon("")
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func set_equipped_helmet(id: String) -> void:
	if equipped_helmet_id != "":
		_remove_entry_affixes(equipped_helmet_entry())
	equipped_helmet_id = id
	if id != "":
		_apply_entry_affixes(equipped_helmet_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func set_equipped_gloves(id: String) -> void:
	if equipped_gloves_id != "":
		_remove_entry_affixes(equipped_gloves_entry())
	equipped_gloves_id = id
	if id != "":
		_apply_entry_affixes(equipped_gloves_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func set_equipped_boots(id: String) -> void:
	if equipped_boots_id != "":
		_remove_entry_affixes(equipped_boots_entry())
	equipped_boots_id = id
	if id != "":
		_apply_entry_affixes(equipped_boots_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func _apply_accessory_stat(id: String) -> void:
	var d: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
	if d == null:
		return
	match d.effect:
		"stat_str":
			var old_bonus: int = strength_hp_bonus_for_value(strength)
			strength += d.effect_value
			var new_bonus: int = strength_hp_bonus_for_value(strength)
			_apply_max_hp_gain(new_bonus - old_bonus)
		"stat_int": intelligence += d.effect_value
		"stat_dex": dexterity += d.effect_value; ev += d.effect_value
		"hp_bonus": _apply_max_hp_gain(d.effect_value)
		"ac_bonus": ac += d.effect_value
		"mp_bonus": _apply_max_mp_gain(d.effect_value)
		"resist_poison":
			add_resist("poison", 1)
			ac += d.effect_value
		"resist_cold":
			add_resist("cold", 1)
			ev += d.effect_value
		"resist_fire":
			add_resist("fire", 1)
		"resist_necro":
			add_resist("necro", 1)
		"slay_bonus":
			slay_bonus += d.effect_value
		"wizardry":
			wizardry_bonus += d.effect_value

func _remove_accessory_stat(id: String) -> void:
	var d: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
	if d == null:
		return
	match d.effect:
		"stat_str":
			var old_bonus: int = strength_hp_bonus_for_value(strength)
			strength = maxi(1, strength - d.effect_value)
			var new_bonus: int = strength_hp_bonus_for_value(strength)
			_apply_max_hp_gain(new_bonus - old_bonus)
		"stat_int": intelligence = maxi(1, intelligence - d.effect_value)
		"stat_dex": dexterity = maxi(1, dexterity - d.effect_value); ev = maxi(0, ev - d.effect_value)
		"hp_bonus": _apply_max_hp_gain(-d.effect_value)
		"ac_bonus": ac = maxi(0, ac - d.effect_value)
		"mp_bonus": _apply_max_mp_gain(-d.effect_value)
		"resist_poison":
			add_resist("poison", -1)
			ac = maxi(0, ac - d.effect_value)
		"resist_cold":
			add_resist("cold", -1)
			ev = maxi(0, ev - d.effect_value)
		"resist_fire":
			add_resist("fire", -1)
		"resist_necro":
			add_resist("necro", -1)
		"slay_bonus":
			slay_bonus -= d.effect_value
		"wizardry":
			wizardry_bonus -= d.effect_value


func _apply_entry_affixes(entry: Dictionary) -> void:
	for mod in entry.get("mods", []):
		var m: Dictionary = mod
		var mod_type: String = String(m.get("type", ""))
		var value: int = int(m.get("value", 0))
		_apply_affix_value(mod_type, value)

func _remove_entry_affixes(entry: Dictionary) -> void:
	for mod in entry.get("mods", []):
		var m: Dictionary = mod
		var mod_type: String = String(m.get("type", ""))
		var value: int = int(m.get("value", 0))
		_apply_affix_value(mod_type, -value)

func _apply_affix_value(mod_type: String, value: int) -> void:
	match mod_type:
		"slay":
			slay_bonus += value
		"wizardry":
			wizardry_bonus += value
		"stat_str":
			var old_bonus: int = strength_hp_bonus_for_value(strength)
			strength = maxi(1, strength + value)
			var new_bonus: int = strength_hp_bonus_for_value(strength)
			_apply_max_hp_gain(new_bonus - old_bonus)
		"stat_dex":
			dexterity = maxi(1, dexterity + value)
			ev = maxi(0, ev + value)
		"stat_int":
			intelligence = maxi(1, intelligence + value)
		"hp_bonus":
			_apply_max_hp_gain(value)
		"mp_bonus":
			_apply_max_mp_gain(value)
		"will_bonus":
			wl += value
		"resist_fire":
			_apply_resist_mod("fire", value)
		"resist_cold":
			_apply_resist_mod("cold", value)
		"resist_poison":
			_apply_resist_mod("poison", value)
		"resist_necro":
			_apply_resist_mod("necro", value)

func _apply_resist_mod(kind: String, value: int) -> void:
	add_resist(kind, value)

## Parse legacy tag-array resists ("poison+", "fire-", "cold-2") into the
## current Dict[element → int] form. Used at race init and when loading old saves.
static func resists_from_tags(tags: Array) -> Dictionary:
	var out: Dictionary = {}
	for entry in tags:
		var s: String = String(entry)
		if s.is_empty():
			continue
		# Find first +/- to split element prefix from suffix.
		var idx: int = s.length()
		for i in s.length():
			var ch: String = s[i]
			if ch == "+" or ch == "-":
				idx = i
				break
		var element: String = s.substr(0, idx)
		var suffix: String = s.substr(idx)
		if element == "":
			continue
		var delta: int = 0
		if suffix == "":
			delta = 1
		elif suffix.is_valid_int():
			delta = int(suffix)
		else:
			# "+", "-", "++", "--", etc.
			for ch in suffix:
				if ch == "+":
					delta += 1
				elif ch == "-":
					delta -= 1
		if delta != 0:
			out[element] = int(out.get(element, 0)) + delta
	# Drop zero-net entries.
	for k in out.keys():
		if int(out[k]) == 0:
			out.erase(k)
	return out

## Stub for backward-compatibility. Forwards to _renderer.refresh_equipment().
func _refresh_paperdoll() -> void:
	if _renderer != null:
		_renderer.refresh_equipment(self)
