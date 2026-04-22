extends Node
## CombatLog — autoload singleton.
## Central message bus for all combat/game events. UI subscribes to
## message_added to display a scrolling log panel.

signal message_added(text: String)

const MAX_MESSAGES: int = 60

var _messages: Array[String] = []


func add(text: String) -> void:
	if text == "":
		return
	_messages.append(text)
	if _messages.size() > MAX_MESSAGES:
		_messages.pop_front()
	message_added.emit(text)
	print(text)  # keep editor output for debugging


func get_recent(n: int) -> Array[String]:
	var count: int = min(n, _messages.size())
	var out: Array[String] = []
	for i in range(_messages.size() - count, _messages.size()):
		out.append(_messages[i])
	return out


## Full rolling history (up to MAX_MESSAGES entries). Used by the
## full-screen log dialog opened via tapping the combat log strip.
func get_all() -> Array[String]:
	return _messages.duplicate()


func clear() -> void:
	_messages.clear()
