extends Control

const CATALOG: Array = [
	{"id": "potion_healing",  "price":  30},
	{"id": "bandage",         "price":  15},
	{"id": "scroll_identify", "price":  25},
	{"id": "short_sword",     "price":  60},
	{"id": "leather_armor",   "price":  55},
	{"id": "buckler",         "price":  40},
]

signal closed

@onready var _title: Label = $Panel/VBox/Title
@onready var _gold_label: Label = $Panel/VBox/GoldLabel
@onready var _grid: VBoxContainer = $Panel/VBox/ScrollContainer/Grid
@onready var _close_btn: Button = $Panel/VBox/CloseButton

var _save_data: Dictionary = {}

func _ready() -> void:
	_title.text = "Town Shop"
	_close_btn.text = "Done"
	_close_btn.pressed.connect(_on_close)
	_load_save()
	_build_cards()

func _load_save() -> void:
	if SaveManager.has_save():
		_save_data = SaveManager.load_save()
	else:
		_save_data = {}

func _current_gold() -> int:
	if _save_data.is_empty():
		return 0
	var p: Dictionary = _save_data.get("player", {})
	return int(p.get("gold", 0))

func _set_current_gold(g: int) -> void:
	if not _save_data.has("player"):
		_save_data["player"] = {}
	_save_data["player"]["gold"] = max(0, g)

func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_gold_label.text = "Gold: %d" % _current_gold()
	for entry in CATALOG:
		_grid.add_child(_make_card(entry))

func _make_card(entry: Dictionary) -> Control:
	var id: String = String(entry["id"])
	var price: int = int(entry["price"])
	var data = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
	var name: String = data.display_name if data != null else id
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_lbl := Label.new()
	name_lbl.text = "%s" % name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(name_lbl)
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % price
	price_lbl.add_theme_font_size_override("font_size", 20)
	price_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	row.add_child(price_lbl)
	var btn := Button.new()
	btn.text = "Buy"
	btn.custom_minimum_size = Vector2(96, 56)
	btn.disabled = _current_gold() < price
	btn.pressed.connect(_on_buy.bind(id, price))
	row.add_child(btn)
	return row

func _on_buy(item_id: String, price: int) -> void:
	if _current_gold() < price:
		return
	_set_current_gold(_current_gold() - price)
	# Append new item to player inventory.
	var items: Array = _save_data["player"].get("items", [])
	if typeof(items) != TYPE_ARRAY:
		items = []
	items.append({"id": item_id})
	_save_data["player"]["items"] = items
	# Persist.
	SaveManager.save(_save_data)
	# Refresh UI.
	_build_cards()

func _on_close() -> void:
	emit_signal("closed")
	queue_free()
