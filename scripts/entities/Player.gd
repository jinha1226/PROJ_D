class_name Player extends Node2D

signal stats_changed
signal moved(new_pos: Vector2i)
signal died
signal item_dropped(item_id: String, at_pos: Vector2i, plus: int)

@export var grid_pos: Vector2i = Vector2i(1, 1)

const SIGHT_RADIUS: int = 8
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

const DOLL_HAND1_MAP: Dictionary = {
	"short_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"mace": "res://assets/tiles/individual/player/hand1/mace.png",
	"long_sword": "res://assets/tiles/individual/player/hand1/long_sword_slant.png",
	"battle_axe": "res://assets/tiles/individual/player/hand1/battle_axe1.png",
	"flaming_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"frost_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"venom_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"shock_mace": "res://assets/tiles/individual/player/hand1/mace.png",
}

var _base_tex: Texture2D = DEFAULT_BASE_TEX
var _body_doll_tex: Texture2D = null
var _hand1_doll_tex: Texture2D = null

var hp: int = 30
var hp_max: int = 30
var mp: int = 5
var mp_max: int = 5
var ac: int = 0
var ev: int = 5
var wl: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var xl: int = 1
var xp: int = 0
var gold: int = 0
var kills: int = 0
var last_killer: String = ""
var items: Array = []  # [{id: String, plus: int}]
var known_spells: Array = []  # [String]
var statuses: Dictionary = {}  # id -> turns_remaining (Status.gd manages)
var resists: Array = []  # ["fire", "cold-2", "poison+"] scaled by Status.resist_scale
var skills: Dictionary = {}  # skill_id -> {"level": int, "xp": float}
var quickslots: Array = ["", "", "", "", ""]  # item ids, index = slot
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var essence_slots: Array = ["", "", ""]   # equipped essence ids (max 3)
var essence_inventory: Array = []         # collected but unequipped essence ids
var fov_radius_bonus: int = 0             # set by RacePassiveSystem (keen_eyes)

const SKILL_IDS: Array = ["blade", "blunt", "dagger", "polearm", "ranged",
	"armor", "magic", "stealth"]
const SKILL_XP_DELTA: Array = [20, 30, 50, 80, 120, 170, 230, 300, 400,
	500, 700, 1000, 1400, 2000, 2800, 4000, 5500, 7500, 10000, 13000]

var _map: DungeonMap

func _ready() -> void:
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
	var monster: Monster = _monster_at(target)
	if monster != null:
		CombatSystem.player_attack_monster(self, monster)
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
		items.append({"id": data.id, "plus": floor_item.plus})
		CombatLog.pickup("You pick up %s." % GameManager.display_name_of(data.id))
		auto_bind_quickslot(data.id)
	emit_signal("stats_changed")
	floor_item.queue_free()

func auto_bind_quickslot(item_id: String) -> void:
	if item_id == "":
		return
	var data: ItemData = ItemRegistry.get_by_id(item_id)
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

func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index]
	var data: ItemData = ItemRegistry.get_by_id(entry.get("id", ""))
	if data == null:
		return
	var had_effect: bool = true
	match data.effect:
		"heal":
			heal(data.effect_value)
			CombatLog.post("You feel better. (+%d HP)" % data.effect_value,
				Color(0.6, 1.0, 0.6))
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
		"enchant_weapon":
			_enchant_weapon(max(1, data.effect_value))
		"enchant_armor":
			_enchant_armor(max(1, data.effect_value))
		"berserk":
			apply_berserk(max(1, data.effect_value))
		"study":
			CombatLog.post("You study the tome.", Color(0.7, 0.85, 1.0))
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
	ev = 5 + dexterity / 2
	var armor: ItemData = ItemRegistry.get_by_id(equipped_armor_id)
	if armor != null:
		var armor_plus: int = int(equipped_armor_entry().get("plus", 0))
		ac += armor.ac_bonus + armor_plus
		var armor_skill: int = get_skill_level("armor")
		var penalty_mult: float = max(0.0, 1.0 - float(armor_skill) * 0.1)
		ev -= int(round(float(armor.ev_penalty) * penalty_mult))
	if has_status("mage_armor"):
		ac = max(ac, 13 + dexterity / 2)
	ev = max(0, ev)
	emit_signal("stats_changed")

func _enchant_weapon(amount: int) -> void:
	if equipped_weapon_id == "":
		CombatLog.post("Nothing to enchant.", Color(0.8, 0.8, 0.6))
		return
	for i in range(items.size()):
		var entry: Dictionary = items[i]
		if entry.get("id", "") == equipped_weapon_id:
			entry["plus"] = int(entry.get("plus", 0)) + amount
			items[i] = entry
			var data: ItemData = ItemRegistry.get_by_id(equipped_weapon_id)
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
			var data: ItemData = ItemRegistry.get_by_id(equipped_armor_id)
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
	emit_signal("stats_changed")
	if hp <= 0:
		emit_signal("died")

func register_kill() -> void:
	kills += 1

func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)
	emit_signal("stats_changed")

func init_skills() -> void:
	for id in SKILL_IDS:
		if not skills.has(id):
			skills[id] = {"level": 0, "xp": 0.0}

func get_skill_level(id: String) -> int:
	var s: Dictionary = skills.get(id, {})
	return int(s.get("level", 0))

func grant_skill_xp(id: String, amount: float) -> void:
	if not SKILL_IDS.has(id):
		return
	if not skills.has(id):
		skills[id] = {"level": 0, "xp": 0.0}
	var s: Dictionary = skills[id]
	s["xp"] = float(s.get("xp", 0.0)) + amount
	while int(s.get("level", 0)) < 20 \
			and float(s.get("xp", 0.0)) >= SKILL_XP_DELTA[int(s.get("level", 0))]:
		s["xp"] = float(s["xp"]) - SKILL_XP_DELTA[int(s["level"])]
		s["level"] = int(s["level"]) + 1
		CombatLog.post("%s skill reaches %d." \
				% [id.capitalize(), int(s["level"])],
			Color(0.7, 0.95, 0.5))
	skills[id] = s

func grant_xp(amount: int) -> void:
	xp += amount
	while xl < 27 and xp >= xp_to_next():
		_level_up()
	emit_signal("stats_changed")

func xp_to_next() -> int:
	if xl < XP_CURVE.size():
		return XP_CURVE[xl]
	var base: float = float(XP_CURVE[XP_CURVE.size() - 1])
	return int(base * pow(1.35, xl - XP_CURVE.size() + 1))

func _level_up() -> void:
	xl += 1
	var hp_gain: int = 5 + strength / 5
	hp_max += hp_gain
	hp = min(hp_max, hp + hp_gain)
	var mp_gain: int = 2 + intelligence / 4
	mp_max += mp_gain
	mp = min(mp_max, mp + mp_gain)
	CombatLog.post("Level up! You are now level %d." % xl,
		Color(1.0, 0.9, 0.3))
	if xl == 12 or xl == 15 or xl == 18:
		_auto_stat_bump()

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
		"strength": strength += 1
		"dexterity": dexterity += 1
		"intelligence": intelligence += 1
	CombatLog.post("(+1 %s)" % lowest_name.to_upper(), Color(0.75, 0.85, 1))

func wait_turn() -> void:
	# Light regen while waiting.
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

func tick_statuses() -> void:
	var expired: Array = Status.tick_actor(self)
	for id in expired:
		CombatLog.post("Your %s wears off." % Status.display_name(id),
			Color(0.75, 0.8, 0.9))
	if not statuses.is_empty() or not expired.is_empty():
		emit_signal("stats_changed")
	EssenceSystem.tick(self)

func equip_essence(slot: int, essence_id: String) -> void:
	if slot < 0 or slot >= essence_slots.size():
		return
	var old: String = String(essence_slots[slot])
	if old != "":
		EssenceSystem.remove(self, old)
		essence_inventory.append(old)
	if essence_id != "":
		essence_inventory.erase(essence_id)
		EssenceSystem.apply(self, essence_id)
	essence_slots[slot] = essence_id
	emit_signal("stats_changed")

func add_essence(essence_id: String) -> void:
	essence_inventory.append(essence_id)
	emit_signal("stats_changed")

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

func _refresh_paperdoll() -> void:
	_body_doll_tex = null
	_hand1_doll_tex = null
	if DOLL_BODY_MAP.has(equipped_armor_id):
		var path: String = String(DOLL_BODY_MAP[equipped_armor_id])
		if ResourceLoader.exists(path):
			_body_doll_tex = load(path) as Texture2D
	if DOLL_HAND1_MAP.has(equipped_weapon_id):
		var path: String = String(DOLL_HAND1_MAP[equipped_weapon_id])
		if ResourceLoader.exists(path):
			_hand1_doll_tex = load(path) as Texture2D
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
	else:
		draw_string(ThemeDB.fallback_font,
			Vector2(6, DungeonMap.CELL_SIZE - 6),
			"@", HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			Color(1.0, 0.95, 0.5))
