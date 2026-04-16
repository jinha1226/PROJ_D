extends Node
## Central turn scheduler. Player acts, then all monsters act.

signal turn_started(turn_number: int)
signal player_turn_started
signal monster_turn_started
signal turn_ended(turn_number: int)

var turn_number: int = 0
var is_player_turn: bool = true
var actors: Array = []  # monsters register here

# Reentrancy guard — defends against any synchronous re-entry from a signal
# listener (e.g. an auto-move handler that decides to act again before the
# previous turn settled). Without this, a freeze could occur from infinite
# recursion through end_player_turn → start_player_turn → emit → handler →
# end_player_turn.
var _ending_turn: bool = false


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
	if _ending_turn:
		push_warning("TurnManager.end_player_turn(): re-entrant call ignored")
		return
	if not is_player_turn:
		push_warning("TurnManager.end_player_turn(): called outside player turn; ignored")
		return
	_ending_turn = true
	is_player_turn = false
	monster_turn_started.emit()
	# Snapshot to make iteration safe against mutation (die() unregisters mid-loop).
	var snapshot: Array = actors.duplicate()
	for a in snapshot:
		if is_instance_valid(a) and a.has_method("take_turn"):
			a.take_turn()
	turn_ended.emit(turn_number)
	_ending_turn = false
	# Defer start_player_turn one frame so any synchronous chain
	# (input → end_player_turn → start_player_turn → handler → input) can
	# never grow the call stack.
	call_deferred("start_player_turn")
