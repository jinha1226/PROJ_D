extends Node

signal message_added(text: String, color: Color)

const MAX_HISTORY: int = 60

var history: Array[Dictionary] = []

func post(text: String, color: Color = Color.WHITE) -> void:
	history.append({"text": text, "color": color})
	if history.size() > MAX_HISTORY:
		history.pop_front()
	emit_signal("message_added", text, color)

func hit(text: String) -> void:
	post(text, Color(1.0, 0.85, 0.35))

func miss(text: String) -> void:
	post(text, Color(0.65, 0.65, 0.65))

func damage_taken(text: String) -> void:
	post(text, Color(1.0, 0.45, 0.4))

func pickup(text: String) -> void:
	post(text, Color(0.6, 1.0, 0.6))

func clear() -> void:
	history.clear()
