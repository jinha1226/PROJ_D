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

func end_player_turn(immediate: bool = false) -> void:
	if _ending_turn or not is_player_turn:
		return
	_ending_turn = true
	is_player_turn = false
	emit_signal("monster_turn_started")
	for actor in actors.duplicate():
		if is_instance_valid(actor) and actor.has_method("take_turn"):
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
