extends Node
class_name RealTimeController

# Seconds per player movement step at action_cost == 1.0.
const BASE_TICK_SEC: float = 0.15
# Seconds per player attack at action_cost == 1.0. Slower than movement for readability.
const BASE_ATTACK_SEC: float = 0.65
# Monster action interval at speed == 10. Higher = slower monsters.
const MONSTER_BASE_SEC: float = 0.90
# Seconds a monster flashes red before executing an attack (telegraph window).
const MONSTER_WINDUP_SEC: float = 0.45

# Dodge: brief invulnerability dash.
const DODGE_WINDOW_SEC: float = 0.30
const DODGE_COOLDOWN_SEC: float = 3.0
# Parry: frontal block window.
const PARRY_WINDOW_SEC: float = 0.25
const PARRY_COOLDOWN_SEC: float = 4.0

var _game: Node
var touch_dir: Vector2i = Vector2i.ZERO  # set by RTControlOverlay D-pad
var _move_timer: float = 0.0
var _attack_timer: float = 0.0
var _dodge_window: float = 0.0
var _dodge_cooldown: float = 0.0
var _parry_window: float = 0.0
var _parry_cooldown: float = 0.0
# instance_id → remaining windup seconds before monster executes its turn
var _windup_timers: Dictionary = {}

func setup(game: Node) -> void:
	_game = game

func trigger_dodge() -> void:
	if _dodge_cooldown > 0.0:
		get_node("/root/CombatLog").post("회피 준비 중… (%.1f초)" % _dodge_cooldown, Color(0.5, 0.7, 1.0))
		return
	var player: Player = _game.player
	if player == null or player.hp <= 0:
		return
	_dodge_window = DODGE_WINDOW_SEC
	_dodge_cooldown = DODGE_COOLDOWN_SEC
	player.rt_dodge_active = true
	var dir: Vector2i = _held_direction()
	if dir != Vector2i.ZERO:
		player.try_step(dir)
		player.try_step(dir)  # double-step for a short dash feel
	get_node("/root/CombatLog").post("회피!", Color(0.3, 0.9, 1.0))

func trigger_parry() -> void:
	if _parry_cooldown > 0.0:
		get_node("/root/CombatLog").post("막기 준비 중… (%.1f초)" % _parry_cooldown, Color(0.8, 0.6, 0.3))
		return
	var player: Player = _game.player
	if player == null or player.hp <= 0:
		return
	_parry_window = PARRY_WINDOW_SEC
	_parry_cooldown = PARRY_COOLDOWN_SEC
	player.rt_parry_active = true
	get_node("/root/CombatLog").post("막기 준비!", Color(1.0, 0.85, 0.3))

func _input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_F2:
			_toggle_rt_mode()
			get_viewport().set_input_as_handled()
		KEY_SHIFT:
			if get_node("/root/TurnManager").rt_mode:
				trigger_dodge()
				get_viewport().set_input_as_handled()
		KEY_Z:
			if get_node("/root/TurnManager").rt_mode:
				trigger_parry()
				get_viewport().set_input_as_handled()

func _toggle_rt_mode() -> void:
	var tm: Node = get_node("/root/TurnManager")
	tm.rt_mode = not tm.rt_mode
	var gm: Node = get_node_or_null("/root/GameManager")
	if gm != null and gm.use_rt_mode != tm.rt_mode:
		gm.toggle_rt_mode()
	var label: String = "[실시간]" if tm.rt_mode else "[턴제]"
	get_node("/root/CombatLog").post(label + " 모드 (F2 전환)", Color(0.6, 1.0, 0.5))
	for actor in tm.actors:
		if is_instance_valid(actor):
			actor.pending_energy = 0.0
	if tm.rt_mode:
		_move_timer = 0.0
		_attack_timer = 0.0
		_dodge_window = 0.0
		_dodge_cooldown = 0.0
		_parry_window = 0.0
		_parry_cooldown = 0.0
		_windup_timers.clear()
		# Reset any lingering red tint on monsters
		for actor in get_node("/root/TurnManager").actors:
			if is_instance_valid(actor):
				actor.modulate = Color.WHITE
		tm.is_player_turn = true
		var player: Player = _game.player
		if player != null:
			player.rt_dodge_active = false
			player.rt_parry_active = false
	else:
		var player: Player = _game.player
		if player != null:
			player.rt_dodge_active = false
			player.rt_parry_active = false
	if _game.has_method("on_rt_mode_changed"):
		_game.on_rt_mode_changed(tm.rt_mode)

func _process(delta: float) -> void:
	var tm: Node = get_node("/root/TurnManager")
	if not tm.rt_mode:
		return
	var player: Player = _game.player
	if player == null or player.hp <= 0:
		return
	if _game.is_blocking_popup_open():
		return

	_tick_timers(delta, player)
	_tick_monsters(delta, tm, player)

	_move_timer = max(0.0, _move_timer - delta)
	var dir: Vector2i = _held_direction()
	if dir != Vector2i.ZERO and _move_timer <= 0.0:
		player.try_step(dir)
		_move_timer = player.movement_action_cost() * BASE_TICK_SEC
	elif dir == Vector2i.ZERO:
		_attack_timer = max(0.0, _attack_timer - delta)
		if _attack_timer <= 0.0:
			if _try_auto_attack(player):
				_attack_timer = player.attack_action_cost() * BASE_ATTACK_SEC

func _tick_timers(delta: float, player: Player) -> void:
	if _dodge_window > 0.0:
		_dodge_window -= delta
		if _dodge_window <= 0.0:
			_dodge_window = 0.0
			player.rt_dodge_active = false
	_dodge_cooldown = max(0.0, _dodge_cooldown - delta)

	if _parry_window > 0.0:
		_parry_window -= delta
		if _parry_window <= 0.0:
			_parry_window = 0.0
			player.rt_parry_active = false
	_parry_cooldown = max(0.0, _parry_cooldown - delta)

func _held_direction() -> Vector2i:
	# Touch D-pad takes priority over keyboard.
	if touch_dir != Vector2i.ZERO:
		return touch_dir
	var dx: int = 0
	var dy: int = 0
	if Input.is_action_pressed("ui_right"):
		dx = 1
	elif Input.is_action_pressed("ui_left"):
		dx = -1
	if Input.is_action_pressed("ui_down"):
		dy = 1
	elif Input.is_action_pressed("ui_up"):
		dy = -1
	return Vector2i(dx, dy)

func _try_auto_attack(player: Player) -> bool:
	var weapon_id: String = player.equipped_weapon_id
	var weapon: ItemData = null
	var ir: Node = get_node_or_null("/root/ItemRegistry")
	if weapon_id != "" and ir != null:
		weapon = ir.get_by_id(weapon_id)
	var is_ranged: bool = weapon != null and weapon.category == "ranged"
	var range_val: int = 1
	if is_ranged:
		range_val = weapon.effect_value if weapon.effect_value > 0 else 6

	var map: DungeonMap = _game.map
	var best: Monster = null
	var best_dist: int = range_val + 1
	for n in get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or (n as Monster).is_ally:
			continue
		var m: Monster = n as Monster
		var d: int = max(abs(m.grid_pos.x - player.grid_pos.x), abs(m.grid_pos.y - player.grid_pos.y))
		if d >= best_dist:
			continue
		if is_ranged:
			if map == null or not map.visible_tiles.has(m.grid_pos):
				continue
		else:
			if d > 1:
				continue
		best = m
		best_dist = d

	if best == null:
		return false

	if is_ranged and best_dist > 1 and map != null:
		var cs: float = DungeonMap.CELL_SIZE
		var half := Vector2(cs * 0.5, cs * 0.5)
		var world_start: Vector2 = player.position + half
		var world_end: Vector2 = map.grid_to_world(best.grid_pos) + half
		var target_pos: Vector2i = best.grid_pos
		_game.spawn_spell_bolt(world_start, world_end, "arrow",
			func(): player.try_attack_tile(target_pos))
	else:
		player.try_attack_tile(best.grid_pos)
	return true

func _tick_monsters(delta: float, tm: Node, player: Player) -> void:
	tm._abort_actor_loop = false

	# Drain windup timers — execute attack when countdown expires.
	for mid in _windup_timers.keys().duplicate():
		_windup_timers[mid] -= delta
		if _windup_timers[mid] > 0.0:
			continue
		_windup_timers.erase(mid)
		if player.hp <= 0:
			continue
		for actor in tm.actors:
			if is_instance_valid(actor) and actor.get_instance_id() == mid:
				actor.modulate = Color.WHITE
				if actor.has_method("take_turn"):
					actor.take_turn()
				break

	# Accumulate energy; telegraph adjacent monsters instead of acting immediately.
	for actor in tm.actors.duplicate():
		if not is_instance_valid(actor):
			continue
		if _windup_timers.has(actor.get_instance_id()):
			continue  # already in windup
		if player.hp <= 0:
			break
		var spd: float = 10.0
		if actor.get("data") != null:
			spd = float(actor.data.speed)
		actor.pending_energy += delta * spd / 10.0 / MONSTER_BASE_SEC
		while actor.pending_energy >= 1.0 and is_instance_valid(actor):
			actor.pending_energy -= 1.0
			if player.hp <= 0:
				break
			var dist: int = max(abs(actor.grid_pos.x - player.grid_pos.x),
								abs(actor.grid_pos.y - player.grid_pos.y))
			if dist <= 1:
				# Adjacent — flash red and delay attack so player can react.
				_windup_timers[actor.get_instance_id()] = MONSTER_WINDUP_SEC
				actor.modulate = Color(1.8, 0.25, 0.25)
			else:
				if actor.has_method("take_turn"):
					actor.take_turn()

	tm._abort_actor_loop = false
