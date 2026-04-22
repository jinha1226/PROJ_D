class_name Player extends Node2D

signal stats_changed
signal moved(new_pos: Vector2i)
signal died
signal stepped_on_stairs_down
signal item_dropped(item_id: String, at_pos: Vector2i, plus: int)

@export var grid_pos: Vector2i = Vector2i(1, 1)

const SIGHT_RADIUS: int = 8
const TEX_PLAYER: Texture2D = preload(
	"res://assets/tiles/individual/player/base/human_m.png")

const XP_CURVE: Array = [0, 10, 30, 70, 140, 250, 420, 700, 1150, 1800,
	2800, 4200, 6000, 8400, 11500, 15500, 20500, 27000, 35500, 47000]

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
var statuses: Dictionary = {}  # id -> turns_remaining
var skills: Dictionary = {}  # skill_id -> {"level": int, "xp": float}
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""

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
	if _map.tile_at(grid_pos) == DungeonMap.Tile.STAIRS_DOWN:
		emit_signal("stepped_on_stairs_down")
		return
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
		CombatLog.pickup("You pick up %s." % data.display_name)
	emit_signal("stats_changed")
	floor_item.queue_free()

func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var entry: Dictionary = items[index]
	var data: ItemData = ItemRegistry.get_by_id(entry.get("id", ""))
	if data == null:
		return
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
		_:
			CombatLog.post("Nothing happens.", Color(0.7, 0.7, 0.7))
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
	return FieldOfView.compute(grid_pos, SIGHT_RADIUS, is_opaque)

func take_damage(amount: int, source: String = "") -> void:
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
	statuses[id] = max(int(statuses.get(id, 0)), turns)
	emit_signal("stats_changed")

func has_status(id: String) -> bool:
	return int(statuses.get(id, 0)) > 0

func tick_statuses() -> void:
	if statuses.is_empty():
		return
	var ids: Array = statuses.keys().duplicate()
	for id in ids:
		_apply_status_tick(id)
		var left: int = int(statuses.get(id, 0)) - 1
		if left <= 0:
			statuses.erase(id)
			CombatLog.post("Your %s effect wears off." % id,
				Color(0.75, 0.8, 0.9))
		else:
			statuses[id] = left
	emit_signal("stats_changed")

func _apply_status_tick(id: String) -> void:
	match id:
		"poison":
			if hp > 1:
				hp -= 1
				CombatLog.damage_taken("Poison burns you. (-1 HP)")

func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager.use_tiles:
		draw_texture_rect(TEX_PLAYER, rect, false)
	else:
		draw_string(ThemeDB.fallback_font,
			Vector2(6, DungeonMap.CELL_SIZE - 6),
			"@", HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			Color(1.0, 0.95, 0.5))
