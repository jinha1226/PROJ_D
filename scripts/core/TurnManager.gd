extends Node

signal player_turn_started
signal monster_turn_started
signal turn_ended

var turn_number: int = 0
var is_player_turn: bool = true
var actors: Array = []

var _ending_turn: bool = false

func register_actor(actor) -> void:
	if actor and not actors.has(actor):
		actors.append(actor)

func unregister_actor(actor) -> void:
	actors.erase(actor)

# action_cost: weapon delay in "turns" (dagger=0.8, sword=1.0, crossbow=2.0)
# Each monster accumulates action_cost * (speed/10.0) energy and acts when >= 1.0
func end_player_turn(action_cost: float = 1.0, immediate: bool = false) -> void:
	if _ending_turn or not is_player_turn:
		return
	_ending_turn = true
	is_player_turn = false
	emit_signal("monster_turn_started")
	for actor in actors.duplicate():
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
	emit_signal("turn_ended")
	_ending_turn = false
	if immediate:
		_start_player_turn()
	else:
		call_deferred("_start_player_turn")

func _start_player_turn() -> void:
	turn_number += 1
	is_player_turn = true
	emit_signal("player_turn_started")
