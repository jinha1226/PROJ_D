class_name Player extends Node2D

var TurnManager = null
var CombatLog = null
var GameManager = null
var ItemRegistry = null

signal stats_changed
signal moved(new_pos: Vector2i)
signal died
signal item_dropped(item_id: String, at_pos: Vector2i, plus: int)
signal damaged(amount: int)

@export var grid_pos: Vector2i = Vector2i(1, 1)

const SIGHT_RADIUS: int = 6
const DEFAULT_BASE_TEX: Texture2D = preload(
	"res://assets/tiles/individual/player/base/human_m.png")

const XP_CURVE: Array = [0, 10, 30, 70, 140, 250, 420, 700, 1150, 1800,
	2800, 4200, 6000, 8400, 11500, 15500, 20500, 27000, 35500, 47000]

## Paper-doll layer lookup tables. When equipped item id matches a key,
## the corresponding sprite is drawn on top of the base race sprite.
const DOLL_BODY_MAP: Dictionary = {
	"leather_armor": "res://assets/tiles/individual/player/body/leather_armour.png",
	"chain_mail": "res://assets/tiles/individual/player/body/chainmail.png",
	"robe": "res://assets/tiles/individual/player/body/robe_blue.png",
}

const DOLL_HAND2_MAP: Dictionary = {
	"buckler": "res://assets/tiles/individual/player/hand2/buckler_round.png",
	"round_shield": "res://assets/tiles/individual/player/hand2/doll_only/kite_shield_round1.png",
	"tower_shield": "res://assets/tiles/individual/player/hand2/tower_shield_teal.png",
}

const DOLL_HAND1_MAP: Dictionary = {
	"short_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"mace": "res://assets/tiles/individual/player/hand1/mace.png",
	"long_sword": "res://assets/tiles/individual/player/hand1/long_sword_slant.png",
	"battle_axe": "res://assets/tiles/individual/player/hand1/battleaxe.png",
	"spear": "res://assets/tiles/individual/player/hand1/spear.png",
	"shortbow": "res://assets/tiles/individual/player/hand1/shortbow.png",
	"staff": "res://assets/tiles/individual/player/hand1/staff.png",
	"flaming_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"frost_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"venom_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"shock_mace": "res://assets/tiles/individual/player/hand1/mace.png",
}

var _base_tex: Texture2D = DEFAULT_BASE_TEX
var _body_doll_tex: Texture2D = null
var _hand1_doll_tex: Texture2D = null
var _hand2_doll_tex: Texture2D = null

var hp: int = 22
var hp_max: int = 22
var _dead: bool = false
var mp: int = 5
var mp_max: int = 6
var ac: int = 0
var ev: int = 5
var wl: int = 0
var fov_radius_bonus: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var xl: int = 1
var xp: int = 0
var gold: int = 0
var kills: int = 0
var items_collected: int = 0
var last_killer: String = ""
var items: Array = []  # [{id: String, plus: int}]
var known_spells: Array = []  # [String]
var statuses: Dictionary = {}  # id -> turns_remaining (Status.gd manages)
var resists: Array = []  # ["fire", "cold-2", "poison+"] scaled by Status.resist_scale
var skills: Dictionary = {}  # skill_id -> {"level": int, "xp": float}
var active_skills: Array = []  # active skill ids receiving kill XP
var quickslots: Array = ["", "", "", "", "", ""]  # item/spell ids, index = slot
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_ring_id: String = ""
var equipped_amulet_id: String = ""
var equipped_shield_id: String = ""
var essence_slots: Array = ["", "", ""]   # equipped essence ids (max 3)
var essence_inventory: Array = []         # collected but unequipped essence ids
var faith_id: String = ""                 # active faith: "war"/"arcana"/"trickery"/"death"/"essence"
var first_shrine_choice_done: bool = false

const MAX_XL: int = 20
const MAX_SKILL_LEVEL: int = 9
const SKILL_IDS: Array = ["fighting", "unarmed", "blade", "hafted", "polearm", "ranged", "spellcasting", "elemental", "arcane", "hex", "necromancy", "summoning", "armor", "shield", "agility", "tool"]
const SKILL_XP_DELTA: Array = [12, 28, 55, 95, 150, 230, 340, 490, 700]
const FIGHTING_HP_PER_LEVEL: int = 5
const MAGIC_SCHOOLS: Array = [
	"elemental", "arcane", "hex", "necromancy", "summoning",
]

var _map: DungeonMap
var _regen_hp_ticker: int = 0
var _regen_mp_ticker: int = 0

func _ready() -> void:
	TurnManager = get_node_or_null("/root/TurnManager")
	CombatLog = get_node_or_null("/root/CombatLog")
	GameManager = get_node_or_null("/root/GameManager")
	ItemRegistry = get_node_or_null("/root/ItemRegistry")
	add_to_group("player")

func bind_map(map: DungeonMap, spawn: Vector2i) -> void:
	_map = map
	grid_pos = spawn
	position = _map.grid_to_world(grid_pos)
	queue_redraw()

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

func _try_move(dir: Vector2i) -> void:
	var target: Vector2i = grid_pos + dir
	if try_attack_tile(target):
		return
	if _map.tile_at(target) == DungeonMap.Tile.DOOR_CLOSED:
		_map.set_tile(target, DungeonMap.Tile.DOOR_OPEN)
		emit_signal("moved", grid_pos)  # refresh FOV from current pos
		TurnManager.end_player_turn()
		return
	if not _map.is_walkable(target):
		return
	grid_pos = target
	position = _map.grid_to_world(grid_pos)
	emit_signal("moved", grid_pos)
	emit_signal("stats_changed")
	_auto_pickup()
	TurnManager.end_player_turn()

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
		var amount: int = max(1, data.effect_value)
		gold += amount
		CombatLog.pickup("You pick up %d gold." % amount)
	else:
		var new_entry: Dictionary = {"id": data.id, "plus": floor_item.plus}
		if data.kind == "wand":
			new_entry["charges"] = data.effect_value
		items.append(new_entry)
		items_collected += 1
		CombatLog.pickup("You pick up %s." % GameManager.display_name_of(data.id))
		auto_bind_quickslot(data.id)
	emit_signal("stats_changed")
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
	CombatSystem.player_attack_monster(self, monster)
	TurnManager.end_player_turn(_weapon_action_cost())
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

func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index]
	var entry_id: String = String(entry.get("id", ""))
	var data: ItemData = ItemRegistry.get_by_id(entry_id) if ItemRegistry != null and entry_id != "" else null
	if data == null:
		return
	var had_effect: bool = true
	match data.effect:
		"heal":
			var heal_amt: int = maxi(1, int(round(float(data.effect_value) * EssenceSystem.potion_heal_mult(self) * FaithSystem.potion_heal_mult(self))))
			heal_amt += EssenceSystem.potion_heal_bonus(self)
			heal(heal_amt)
			CombatLog.post("You feel better. (+%d HP)" % heal_amt,
				Color(0.6, 1.0, 0.6))
		"bandage":
			var heal_amt: int = 6
			heal(heal_amt)
			CombatLog.post("You bandage your wounds. (+%d HP)" % heal_amt, Color(0.85, 0.9, 0.65))
		"blink":
			_blink(data.effect_value)
		"might":
			strength += data.effect_value
			CombatLog.post("You feel mighty. (+%d STR)" % data.effect_value,
				Color(1.0, 0.7, 0.55))
		"map_reveal":
			_reveal_map()
		"cure":
			if statuses.has("poison"):
				statuses.erase("poison")
				CombatLog.post("The poison clears.", Color(0.6, 1.0, 0.7))
			else:
				CombatLog.post("You feel healthy.", Color(0.6, 1.0, 0.7))
		"restore_mp":
			var gain: int = max(1, data.effect_value)
			mp = min(mp_max, mp + gain)
			CombatLog.post("You feel recharged. (+%d MP)" % gain,
				Color(0.5, 0.85, 1.0))
		"teleport":
			_teleport_far()
		"shroud":
			apply_status("shrouded", max(4, data.effect_value))
			_break_enemy_awareness(max(2, data.effect_value / 2))
			CombatLog.post("Shadows gather around you.", Color(0.72, 0.86, 1.0))
		"enchant_weapon":
			_enchant_weapon(max(1, data.effect_value))
		"enchant_armor":
			_enchant_armor(max(1, data.effect_value))
		"berserk":
			apply_berserk(max(1, data.effect_value))
		# --- New potion effects ---
		"haste":
			apply_status("haste", data.effect_value)
			CombatLog.post("You feel a surge of speed.", Color(0.4, 1.0, 0.6))
		"invisible":
			apply_status("invisible", data.effect_value)
			CombatLog.post("You fade from sight.", Color(0.7, 0.7, 1.0))
		"stat_dex":
			dexterity += data.effect_value
			refresh_ac_from_equipment()
			CombatLog.post("You feel more agile. (+1 DEX)", Color(0.3, 0.8, 1.0))
		"stat_int":
			intelligence += data.effect_value
			CombatLog.post("You feel sharper. (+1 INT)", Color(0.9, 0.9, 0.4))
		"grant_xp":
			grant_xp(data.effect_value)
			CombatLog.post("You feel more experienced.", Color(0.9, 0.6, 1.0))
		# --- New scroll effects ---
		"scroll_fear":
			var game_node: Node = get_tree().current_scene if get_tree() != null else null
			if game_node != null and game_node.has_method("apply_fear_aoe"):
				game_node.apply_fear_aoe(grid_pos, 6, data.effect_value)
			CombatLog.post("The enemies flee in terror!", Color(0.9, 0.7, 1.0))
		"scroll_upgrade":
			if equipped_weapon_id != "":
				_enchant_weapon(1)
			elif equipped_armor_id != "":
				_enchant_armor(1)
			else:
				CombatLog.post("Nothing to upgrade.", Color(0.7, 0.7, 0.7))
				had_effect = false
		"scroll_fog":
			var game_fog: Node = get_tree().current_scene if get_tree() != null else null
			if game_fog != null and game_fog.has_method("apply_fog_aoe"):
				game_fog.apply_fog_aoe(grid_pos, 4, data.effect_value)
			CombatLog.post("Fog spreads around you.", Color(0.75, 0.85, 0.95))
		"scroll_brand":
			_enchant_weapon(1)
			CombatLog.post("Your weapon glows with new power.", Color(1.0, 0.85, 0.3))
		"branch_brand":
			_apply_branch_brand(String(data.brand))
		"scroll_silence":
			var game_sil: Node = get_tree().current_scene if get_tree() != null else null
			if game_sil != null and game_sil.has_method("apply_silence_aoe"):
				game_sil.apply_silence_aoe(grid_pos, 6, data.effect_value)
			CombatLog.post("Silence falls upon your foes.", Color(0.7, 0.85, 1.0))
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
			CombatLog.post("Nearby enemies burst into flame!", Color(1.0, 0.5, 0.1))
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
			CombatLog.post("A loud noise echoes through the dungeon!", Color(1.0, 0.8, 0.4))
		"resistance":
			apply_status("resist_fire", data.effect_value)
			apply_status("resist_cold", data.effect_value)
			apply_status("resist_poison", data.effect_value)
			CombatLog.post("You feel resistant to fire, cold and poison.", Color(0.4, 0.7, 1.0))
		"cancellation":
			var neg_statuses := ["poison", "slow", "fear", "blind", "silence", "burning", "frozen", "paralyzed"]
			for st in neg_statuses:
				if statuses.has(st):
					statuses.erase(st)
			stats_changed.emit()
			CombatLog.post("Your negative effects are cancelled.", Color(0.85, 0.85, 0.85))
		# --- Wand effects ---
		"wand_haste":
			apply_status("haste", 12)
			CombatLog.post("You feel a surge of speed.", Color(0.4, 1.0, 0.6))
		"wand_fear":
			var game_wf: Node = get_tree().current_scene if get_tree() != null else null
			if game_wf != null and game_wf.has_method("apply_fear_aoe"):
				game_wf.apply_fear_aoe(grid_pos, 5, 8)
			CombatLog.post("Your foes turn and flee!", Color(0.9, 0.7, 1.0))
		"wand_digging":
			var game_wd: Node = get_tree().current_scene if get_tree() != null else null
			if game_wd != null and game_wd.has_method("dig_toward"):
				game_wd.dig_toward(grid_pos)
			CombatLog.post("The wand pulses with digging energy.", Color(0.8, 0.7, 0.5))
		"wand_fire", "wand_frost", "wand_lightning", "wand_teleport":
			CombatLog.post("This wand requires a target. (not yet implemented)", Color(0.7, 0.7, 0.7))
			had_effect = false
		# --- Throwing effects ---
		"throw_pierce", "throw_heavy", "throw_fire_aoe", "throw_poison", "throw_smoke":
			CombatLog.post("You throw the %s." % data.display_name, Color(0.85, 0.85, 0.7))
		"study":
			var all_ids: Array = []
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
					CombatLog.post("The tome is beyond your current intellect.", Color(1.0, 0.72, 0.5))
					if data.kind == "book":
						return
				else:
					CombatLog.post("You already know all spells in this tome.", Color(0.7, 0.85, 1.0))
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
	# Side grants — run regardless of match.
	if String(data.grants_spell_id) != "" \
			and not known_spells.has(data.grants_spell_id):
		known_spells.append(data.grants_spell_id)
		var s: SpellData = SpellRegistry.get_by_id(data.grants_spell_id)
		var sname: String = s.display_name if s != null else data.grants_spell_id
		CombatLog.post("You learn %s." % sname, Color(0.7, 0.95, 1.0))
		had_effect = true
	for sid in data.grants_spell_ids:
		if not known_spells.has(sid):
			known_spells.append(sid)
			var s2: SpellData = SpellRegistry.get_by_id(sid)
			var sname2: String = s2.display_name if s2 != null else sid
			CombatLog.post("You learn %s." % sname2, Color(0.7, 0.95, 1.0))
			had_effect = true
	if String(data.unlocks_class_id) != "":
		GameManager.try_use_unlock(data.id)
		had_effect = true
	if not had_effect:
		CombatLog.post("Nothing happens.", Color(0.7, 0.7, 0.7))
	# Wand: consume a charge instead of removing the item entirely.
	if data.kind == "wand":
		var wand_entry: Dictionary = items[index]
		var charges: int = int(wand_entry.get("charges", data.effect_value))
		if randf() >= FaithSystem.wand_charge_save_chance(self):
			charges -= 1
		if charges <= 0:
			CombatLog.post("The %s is exhausted." % data.display_name, Color(0.6, 0.6, 0.6))
			items.remove_at(index)
		else:
			wand_entry["charges"] = charges
			items[index] = wand_entry
			CombatLog.post("(%d charges remaining)" % charges, Color(0.5, 0.8, 0.9))
		emit_signal("stats_changed")
		return
	# Auto-identify on first successful use (consumables only).
	if data.kind == "potion" or data.kind == "scroll" or data.kind == "book":
		GameManager.identify(data.id)
	items.remove_at(index)
	emit_signal("stats_changed")

func drop_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index]
	var id: String = String(entry.get("id", ""))
	var plus_val: int = int(entry.get("plus", 0))
	if id == equipped_weapon_id:
		equipped_weapon_id = ""
	if id == equipped_armor_id:
		equipped_armor_id = ""
		refresh_ac_from_equipment()
	if id == equipped_ring_id:
		set_equipped_ring("")
	if id == equipped_amulet_id:
		set_equipped_amulet("")
	if id == equipped_shield_id:
		set_equipped_shield("")
	items.remove_at(index)
	emit_signal("item_dropped", id, grid_pos, plus_val)
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
	if has_status("mage_armor"):
		ac = max(ac, 13 + dexterity / 2)
	ac += EssenceSystem.bonus_ac(self)
	ev += EssenceSystem.bonus_ev(self)
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
		CombatLog.post("You have no equipment to brand.", Color(1.0, 0.7, 0.5))
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
			CombatLog.post("Your %s is branded with %s!" % [name_, element],
				element_colors.get(element, Color.WHITE))
			emit_signal("stats_changed")
			return

func _enchant_weapon(amount: int) -> void:
	if equipped_weapon_id == "":
		CombatLog.post("Nothing to enchant.", Color(0.8, 0.8, 0.6))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == equipped_weapon_id:
			entry["plus"] = int(entry.get("plus", 0)) + amount
			items[i] = entry
			var data: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
			var name_: String = data.display_name if data != null else "weapon"
			CombatLog.post("Your %s glows. (+%d)" % [name_, amount],
				Color(1.0, 0.9, 0.5))
			return

func _enchant_armor(amount: int) -> void:
	if equipped_armor_id == "":
		CombatLog.post("Nothing to enchant.", Color(0.8, 0.8, 0.6))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == equipped_armor_id:
			entry["plus"] = int(entry.get("plus", 0)) + amount
			items[i] = entry
			var data: ItemData = ItemRegistry.get_by_id(equipped_armor_id) if ItemRegistry != null and equipped_armor_id != "" else null
			var name_: String = data.display_name if data != null else "armor"
			CombatLog.post("Your %s glows. (+%d)" % [name_, amount],
				Color(0.85, 1.0, 0.7))
			refresh_ac_from_equipment()
			return

func _teleport_far() -> void:
	if _map == null:
		return
	for _i in range(80):
		var p := Vector2i(
			randi_range(1, DungeonMap.GRID_W - 2),
			randi_range(1, DungeonMap.GRID_H - 2))
		if not _map.is_walkable(p):
			continue
		if _monster_at(p) != null:
			continue
		if p == grid_pos:
			continue
		grid_pos = p
		position = _map.grid_to_world(p)
		emit_signal("moved", grid_pos)
		CombatLog.post("You teleport.", Color(0.85, 0.7, 1.0))
		return
	CombatLog.post("Nothing happens.", Color(0.7, 0.7, 0.7))

func _reveal_map() -> void:
	if _map == null:
		return
	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var p := Vector2i(x, y)
			if _map.tile_at(p) != DungeonMap.Tile.WALL:
				_map.explored[p] = true
	_map.queue_redraw()
	CombatLog.post("The floor's layout becomes clear.",
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
		CombatLog.post("You blink.", Color(0.7, 0.85, 1.0))
		return
	CombatLog.post("Nothing happens.", Color(0.7, 0.7, 0.7))

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

func compute_fov() -> Dictionary:
	if _map == null:
		return {}
	var is_opaque := func(p: Vector2i) -> bool: return _map.is_opaque(p)
	return FieldOfView.compute(grid_pos, SIGHT_RADIUS + fov_radius_bonus, is_opaque)

func take_damage(amount: int, source: String = "") -> void:
	if has_status("invulnerable"):
		CombatLog.post("You are invulnerable!", Color(1.0, 0.95, 0.5))
		return
	hp = max(0, hp - amount)
	if source != "":
		last_killer = source
	emit_signal("damaged", amount)
	emit_signal("stats_changed")
	if hp <= 0 and not _dead:
		_dead = true
		emit_signal("died")


func register_kill() -> void:
	kills += 1

func strength_hp_bonus_for_value(value: int) -> int:
	return value / 2

func compute_starting_hp(base_hp: int, base_str: int) -> int:
	return max(1, base_hp + strength_hp_bonus_for_value(base_str))

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

func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)
	emit_signal("stats_changed")

func init_skills() -> void:
	for id in SKILL_IDS:
		if not skills.has(id):
			skills[id] = {"level": 0, "xp": 0.0}
	if active_skills.is_empty():
		active_skills = ["blade"]

func is_skill_active(id: String) -> bool:
	return active_skills.has(id)

func set_active_skills(ids: Array) -> void:
	active_skills.clear()
	for id in ids:
		var sid: String = String(id)
		if SKILL_IDS.has(sid) and not active_skills.has(sid):
			active_skills.append(sid)
	if active_skills.is_empty():
		active_skills = ["blade"]
	emit_signal("stats_changed")

func toggle_skill_active(id: String) -> bool:
	if not SKILL_IDS.has(id):
		return false
	if active_skills.has(id):
		if active_skills.size() <= 1:
			return false
		active_skills.erase(id)
	else:
		active_skills.append(id)
	emit_signal("stats_changed")
	return true

func grant_kill_skill_xp(amount: float, preferred_skill: String = "") -> void:
	var targets: Array = []
	for id in active_skills:
		var sid: String = String(id)
		if SKILL_IDS.has(sid) and get_skill_level(sid) < MAX_SKILL_LEVEL:
			targets.append(sid)
	if targets.is_empty():
		var fallback: String = preferred_skill if SKILL_IDS.has(preferred_skill) else "blade"
		targets = [fallback]
	var share: float = amount / float(targets.size())
	for sid in targets:
		grant_skill_xp(String(sid), share)

func get_skill_level(id: String) -> int:
	var s: Dictionary = skills.get(id, {})
	return int(s.get("level", 0))

static func progression_school_for(raw_school: String) -> String:
	match raw_school:
		"fire", "cold", "air", "earth", "alchemy":
			return "elemental"
		"conjuration", "conjurations", "translocation", "transmutation", "abjuration", "evocation", "forgecraft":
			return "arcane"
		"hexes", "enchantment":
			return "hex"
		"necromancy":
			return "necromancy"
		"summoning":
			return "summoning"
	return raw_school

static func weapon_skill_for_item(item: ItemData) -> String:
	if item == null:
		return "unarmed"
	match String(item.category):
		"dagger", "blade":
			return "blade"
		"axe", "blunt":
			return "hafted"
		"polearm":
			return "polearm"
		"ranged":
			return "ranged"
		"staff":
			return "spellcasting"
	return "unarmed"

func spell_skill_for(spell: SpellData) -> String:
	if spell == null:
		return "spellcasting"
	return progression_school_for(String(spell.school))

func _skill_apt_mult(id: String) -> float:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id) if GameManager != null and RaceRegistry != null else null
	if race == null:
		return 1.0
	var apt: int = int(race.skill_aptitudes.get(id, 0))
	return pow(1.2, apt)

func grant_skill_xp(id: String, amount: float) -> void:
	if not SKILL_IDS.has(id):
		return
	if not skills.has(id):
		skills[id] = {"level": 0, "xp": 0.0}
	var s: Dictionary = skills[id]
	s["xp"] = float(s.get("xp", 0.0)) + amount * _skill_apt_mult(id)
	while int(s.get("level", 0)) < MAX_SKILL_LEVEL \
			and float(s.get("xp", 0.0)) >= SKILL_XP_DELTA[int(s.get("level", 0))]:
		s["xp"] = float(s["xp"]) - SKILL_XP_DELTA[int(s["level"])]
		s["level"] = int(s["level"]) + 1
		CombatLog.post("%s skill reaches %d." \
				% [id.capitalize(), int(s["level"])],
			Color(0.7, 0.95, 0.5))
		if id == "agility":
			ev += 1
		elif id == "fighting":
			var hp_gain: int = _fighting_hp_gain()
			_apply_max_hp_gain(hp_gain, "+%d max HP from Fighting." % hp_gain)
	skills[id] = s

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
	CombatLog.post("Level up! You are now level %d." % xl,
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
	CombatLog.post("(+1 %s)" % lowest_name.to_upper(), Color(0.75, 0.85, 1))

func learn_spell(spell_id: String) -> bool:
	var sid: String = String(spell_id)
	if sid == "" or known_spells.has(sid):
		return false
	var spell: SpellData = SpellRegistry.get_by_id(sid)
	if spell == null:
		return false
	var int_req: int = int_required_for_spell(spell)
	if intelligence < int_req:
		CombatLog.post("%s requires INT %d." % [spell.display_name, int_req], Color(1.0, 0.72, 0.5))
		return false
	known_spells.append(sid)
	CombatLog.post("You memorize %s." % spell.display_name, Color(0.7, 0.95, 1.0))
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
	return max(7, 7 + spell.spell_level * 2 - EssenceSystem.spell_int_discount(self))

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func wait_turn() -> void:
	if hp < hp_max:
		hp = min(hp_max, hp + 1)
	if mp < mp_max:
		mp = min(mp_max, mp + 1)
	emit_signal("stats_changed")

func apply_status(id: String, turns: int) -> void:
	Status.apply(self, id, turns)
	emit_signal("stats_changed")

func has_status(id: String) -> bool:
	return Status.has(self, id)

func is_wet() -> bool:
	return has_status("wet")

func apply_wet(turns: int = 4) -> void:
	apply_status("wet", turns)
	if CombatLog != null:
		CombatLog.post("Water soaks you.", Color(0.55, 0.8, 1.0))

func tick_statuses() -> void:
	var expired: Array = Status.tick_actor(self)
	for id in expired:
		CombatLog.post("Your %s wears off." % Status.display_name(id),
			Color(0.75, 0.8, 0.9))
	# Passive regen
	if hp < hp_max:
		_regen_hp_ticker += 1
		if _regen_hp_ticker >= hp_regen_period():
			_regen_hp_ticker = 0
			hp = min(hp_max, hp + 1)
	else:
		_regen_hp_ticker = 0
	if mp < mp_max:
		_regen_mp_ticker += 1
		if _regen_mp_ticker >= mp_regen_period():
			_regen_mp_ticker = 0
			mp = min(mp_max, mp + 1)
	else:
		_regen_mp_ticker = 0
	if not statuses.is_empty() or not expired.is_empty():
		emit_signal("stats_changed")
	EssenceSystem.tick(self)

func hp_regen_period() -> int:
	var armor: ItemData = ItemRegistry.get_by_id(equipped_armor_id) if ItemRegistry != null and equipped_armor_id != "" else null
	if armor != null and armor.brand == "regen":
		return 3
	return 5

func mp_regen_period() -> int:
	return 6

func equip_essence(slot: int, essence_id: String) -> void:
	if slot < 0 or slot >= essence_slots.size():
		return
	if not EssenceSystem.slot_is_unlocked(self, slot):
		return
	var old: String = String(essence_slots[slot])
	if old == essence_id:
		return
	if old != "" and essence_id == "" and EssenceSystem.inventory_is_full(self):
		CombatLog.post("Your essence inventory is full.", Color(1.0, 0.72, 0.5))
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

func apply_berserk(turns: int) -> void:
	Status.apply(self, "berserk", turns)
	CombatLog.post("You enter a berserk rage. (+4 STR)",
		Color(1.0, 0.55, 0.35))
	emit_signal("stats_changed")

func set_race_from_id(race_id: String) -> void:
	var race: RaceData = RaceRegistry.get_by_id(race_id)
	if race != null and race.base_sprite_path != "" \
			and ResourceLoader.exists(race.base_sprite_path):
		_base_tex = load(race.base_sprite_path) as Texture2D
	else:
		_base_tex = DEFAULT_BASE_TEX
	queue_redraw()

func set_equipped_weapon(id: String) -> void:
	equipped_weapon_id = id
	_refresh_paperdoll()
	emit_signal("stats_changed")

func set_equipped_armor(id: String) -> void:
	equipped_armor_id = id
	_refresh_paperdoll()
	refresh_ac_from_equipment()  # emits stats_changed

func set_equipped_ring(id: String) -> void:
	if equipped_ring_id != "":
		_remove_accessory_stat(equipped_ring_id)
	equipped_ring_id = id
	if id != "":
		_apply_accessory_stat(id)
	emit_signal("stats_changed")

func set_equipped_amulet(id: String) -> void:
	if equipped_amulet_id != "":
		_remove_accessory_stat(equipped_amulet_id)
	equipped_amulet_id = id
	if id != "":
		_apply_accessory_stat(id)
	emit_signal("stats_changed")

func set_equipped_shield(id: String) -> void:
	equipped_shield_id = id
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func has_two_handed_weapon() -> bool:
	if equipped_weapon_id == "":
		return false
	var w: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
	return w != null and (w.category == "axe" or w.category == "polearm")

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
		"stat_dex": dexterity += d.effect_value; ev += 1
		"hp_bonus": _apply_max_hp_gain(d.effect_value)
		"ac_bonus": ac += d.effect_value
		"mp_bonus": _apply_max_mp_gain(d.effect_value)
		"resist_poison":
			if not resists.has("poison+"): resists.append("poison+")
			ac += d.effect_value
		"resist_cold":
			if not resists.has("cold+"): resists.append("cold+")
			ev += d.effect_value
		"resist_fire":
			if not resists.has("fire+"): resists.append("fire+")
		"resist_necro":
			if not resists.has("necro+"): resists.append("necro+")

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
		"stat_dex": dexterity = maxi(1, dexterity - d.effect_value); ev = maxi(0, ev - 1)
		"hp_bonus": _apply_max_hp_gain(-d.effect_value)
		"ac_bonus": ac = maxi(0, ac - d.effect_value)
		"mp_bonus": _apply_max_mp_gain(-d.effect_value)
		"resist_poison":
			resists.erase("poison+")
			ac = maxi(0, ac - d.effect_value)
		"resist_cold":
			resists.erase("cold+")
			ev = maxi(0, ev - d.effect_value)
		"resist_fire":
			resists.erase("fire+")
		"resist_necro":
			resists.erase("necro+")

func _refresh_paperdoll() -> void:
	_body_doll_tex = null
	_hand1_doll_tex = null
	_hand2_doll_tex = null
	if DOLL_BODY_MAP.has(equipped_armor_id):
		var body_path: String = String(DOLL_BODY_MAP[equipped_armor_id])
		if ResourceLoader.exists(body_path):
			_body_doll_tex = load(body_path) as Texture2D
	if DOLL_HAND1_MAP.has(equipped_weapon_id):
		var path: String = String(DOLL_HAND1_MAP[equipped_weapon_id])
		if ResourceLoader.exists(path):
			_hand1_doll_tex = load(path) as Texture2D
	if DOLL_HAND2_MAP.has(equipped_shield_id):
		var path: String = String(DOLL_HAND2_MAP[equipped_shield_id])
		if ResourceLoader.exists(path):
			_hand2_doll_tex = load(path) as Texture2D
	queue_redraw()

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager.use_tiles:
		if _base_tex != null:
			draw_texture_rect(_base_tex, rect, false)
		if _body_doll_tex != null:
			draw_texture_rect(_body_doll_tex, rect, false)
		if _hand1_doll_tex != null:
			draw_texture_rect(_hand1_doll_tex, rect, false)
		if _hand2_doll_tex != null:
			draw_texture_rect(_hand2_doll_tex, rect, false)
	else:
		draw_string(ThemeDB.fallback_font,
			Vector2(6, DungeonMap.CELL_SIZE - 6),
			"@", HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			Color(1.0, 0.95, 0.5))
