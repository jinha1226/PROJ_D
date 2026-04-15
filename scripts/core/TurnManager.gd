extends Node
## Central turn scheduler. Player acts, then all monsters act.

signal turn_started(turn_number: int)
signal player_turn_started
signal monster_turn_started
signal turn_ended(turn_number: int)

var turn_number: int = 0
var is_player_turn: bool = true
var actors: Array = []  # monsters register here

func register_actor(actor: Node) -> void:
	if actor not in actors:
		actors.append(actor)

func unregister_actor(actor: Node) -> void:
	actors.erase(actor)

func start_player_turn() -> void:
	turn_number += 1
	is_player_turn = true
	turn_started.emit(turn_number)
	player_turn_started.emit()

func end_player_turn() -> void:
	is_player_turn = false
	monster_turn_started.emit()
	for a in actors:
		if is_instance_valid(a) and a.has_method("take_turn"):
			a.take_turn()
	turn_ended.emit(turn_number)
	start_player_turn()
