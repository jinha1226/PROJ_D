extends Node

signal player_turn_started
signal monster_turn_started
signal turn_ended

var turn_number: int = 0
var is_player_turn: bool = true
var actors: Array = []
var rt_mode: bool = false

var _ending_turn: bool = false
# Set by Game._on_player_died to break out of the in-flight monster loop.
# Without this, monsters keep taking turns against a corpse — extra
# damage logs, wasted ability charges, and noisy timing on the death screen.
var _abort_actor_loop: bool = false

## Called by Game on player death so the current end_player_turn() unwinds
## immediately instead of finishing the remaining monster turns.
func abort_actor_loop() -> void:
	_abort_actor_loop = true

func register_actor(actor) -> void:
	if actor and not actors.has(actor):
		actors.append(actor)

func unregister_actor(actor) -> void:
	actors.erase(actor)

# action_cost: weapon delay in "turns" (dagger=0.8, sword=1.0, crossbow=2.0)
# Each monster accumulates action_cost * (speed/10.0) energy and acts when >= 1.0
func end_player_turn(action_cost: float = 1.0, immediate: bool = false) -> void:
	if rt_mode:
		# Real-time: tick state only; monsters are driven by RealTimeController._process.
		# ExpeditionState is NOT ticked per-action here — real-time fires far too many
		# actions per second for per-action budget drain to be fair (Phase 6 rebalance).
		turn_number += 1
		return
	if _ending_turn or not is_player_turn:
		return
	# Tick expedition turn budget BEFORE the monster loop so a player turn
	# always counts as one unit regardless of monster activity that follows.
	if ExpeditionState != null:
		ExpeditionState.tick()
	_ending_turn = true
	is_player_turn = false
	emit_signal("monster_turn_started")
	for actor in actors.duplicate():
		if _abort_actor_loop:
			break
		if not is_instance_valid(actor):
			continue
		var spd: float = 10.0
		if actor.get("data") != null:
			spd = float(actor.data.speed)
		actor.pending_energy += action_cost * (spd / 10.0)
		while actor.pending_energy >= 1.0 and is_instance_valid(actor):
			actor.pending_energy -= 1.0
			if actor.has_method("take_turn"):
				actor.take_turn()
			if _abort_actor_loop:
				break
	emit_signal("turn_ended")
	_ending_turn = false
	_abort_actor_loop = false
	if immediate:
		_start_player_turn()
	else:
		call_deferred("_start_player_turn")

func _start_player_turn() -> void:
	turn_number += 1
	is_player_turn = true
	emit_signal("player_turn_started")
