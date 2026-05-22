extends Control

const BUY_CATALOG: Array = [
	# Consumables
	{"id": "potion_healing",   "price":  30},
	{"id": "potion_might",     "price":  35},
	{"id": "potion_magic",     "price":  35},
	{"id": "potion_haste",     "price":  45},
	{"id": "potion_resistance","price":  50},
	{"id": "bandage",          "price":  15},
	# Scrolls
	{"id": "scroll_identify",  "price":  25},
	{"id": "scroll_teleport",  "price":  40},
	{"id": "scroll_magic_mapping","price": 55},
	{"id": "scroll_fog",       "price":  30},
	# Basic gear
	{"id": "short_sword",      "price":  60},
	{"id": "leather_armor",    "price":  55},
	{"id": "buckler",          "price":  40},
	{"id": "leather_cap",      "price":  35},
	{"id": "leather_gloves",   "price":  30},
	{"id": "leather_boots",    "price":  30},
]

const SELL_PRICE_MULTIPLIER: float = 0.4
const SELL_FALLBACK_PRICE: int = 5

enum Tab { BUY, SELL }

signal closed

@onready var _title: Label = $Panel/VBox/Title
@onready var _gold_label: Label = $Panel/VBox/GoldLabel
@onready var _buy_tab_btn: Button = $Panel/VBox/TabBar/BuyTabButton
@onready var _sell_tab_btn: Button = $Panel/VBox/TabBar/SellTabButton
@onready var _grid: VBoxContainer = $Panel/VBox/ScrollContainer/Grid
@onready var _close_btn: Button = $Panel/VBox/CloseButton

var _save_data: Dictionary = {}
var _active_tab: int = Tab.BUY

static func sell_price_for(item_id: String) -> int:
	for entry in BUY_CATALOG:
		if String(entry["id"]) == item_id:
			return max(1, int(round(float(entry["price"]) * SELL_PRICE_MULTIPLIER)))
	return SELL_FALLBACK_PRICE

func _ready() -> void:
	theme = GameTheme.create()
	_title.text = LocaleManager.t("UI_SHOP_TITLE")
	_close_btn.text = LocaleManager.t("UI_SHOP_BTN_DONE")
	_close_btn.pressed.connect(_on_close)
	_buy_tab_btn.text = LocaleManager.t("UI_SHOP_TAB_BUY")
	_sell_tab_btn.text = LocaleManager.t("UI_SHOP_TAB_SELL")
	_buy_tab_btn.pressed.connect(_on_tab.bind(Tab.BUY))
	_sell_tab_btn.pressed.connect(_on_tab.bind(Tab.SELL))
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

func _on_tab(tab: int) -> void:
	_active_tab = tab
	_build_cards()

func _refresh_tab_styling() -> void:
	_buy_tab_btn.modulate = Color.WHITE if _active_tab == Tab.BUY else Color(0.55, 0.55, 0.55)
	_sell_tab_btn.modulate = Color.WHITE if _active_tab == Tab.SELL else Color(0.55, 0.55, 0.55)

func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	_gold_label.text = LocaleManager.t("UI_SHOP_GOLD") % _current_gold()
	_refresh_tab_styling()
	if _active_tab == Tab.BUY:
		_build_buy_cards()
	else:
		_build_sell_cards()

func _build_buy_cards() -> void:
	for entry in BUY_CATALOG:
		_grid.add_child(_make_buy_card(entry))

func _make_buy_card(entry: Dictionary) -> Control:
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
	btn.text = LocaleManager.t("UI_SHOP_BTN_BUY")
	btn.custom_minimum_size = Vector2(96, 56)
	btn.disabled = _current_gold() < price
	btn.pressed.connect(_on_buy.bind(id, price))
	row.add_child(btn)
	return row

func _build_sell_cards() -> void:
	var items: Array = _save_data.get("player", {}).get("items", [])
	if typeof(items) != TYPE_ARRAY or items.is_empty():
		var empty := Label.new()
		empty.text = LocaleManager.t("UI_SHOP_NO_ITEMS_TO_SELL")
		empty.add_theme_font_size_override("font_size", 20)
		_grid.add_child(empty)
		return
	var any_sellable: bool = false
	for i in range(items.size()):
		var entry = items[i]
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var item_id: String = String(entry.get("id", ""))
		if item_id == "":
			continue
		if _is_equipped(item_id):
			continue
		_grid.add_child(_make_sell_card(item_id, i))
		any_sellable = true
	if not any_sellable:
		var empty := Label.new()
		empty.text = LocaleManager.t("UI_SHOP_NO_ITEMS_TO_SELL")
		empty.add_theme_font_size_override("font_size", 20)
		_grid.add_child(empty)

func _make_sell_card(item_id: String, item_index: int) -> Control:
	var data = ItemRegistry.get_by_id(item_id) if ItemRegistry != null else null
	var name: String = data.display_name if data != null else item_id
	var price: int = sell_price_for(item_id)
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
	btn.text = LocaleManager.t("UI_SHOP_BTN_SELL")
	btn.custom_minimum_size = Vector2(96, 56)
	btn.pressed.connect(_on_sell.bind(item_index, item_id, price))
	row.add_child(btn)
	return row

func _is_equipped(item_id: String) -> bool:
	var p: Dictionary = _save_data.get("player", {})
	for slot in ["weapon", "armor", "shield", "helmet", "gloves", "boots", "ring", "amulet"]:
		if String(p.get(slot, "")) == item_id:
			return true
	return false

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

func _on_sell(item_index: int, item_id: String, price: int) -> void:
	if not _save_data.has("player"):
		return
	var items: Array = _save_data["player"].get("items", [])
	if typeof(items) != TYPE_ARRAY:
		return
	if item_index < 0 or item_index >= items.size():
		_build_cards()
		return
	var entry = items[item_index]
	if typeof(entry) != TYPE_DICTIONARY or String(entry.get("id", "")) != item_id:
		# Index drift — refresh and bail.
		_build_cards()
		return
	items.remove_at(item_index)
	_save_data["player"]["items"] = items
	_set_current_gold(_current_gold() + price)
	SaveManager.save(_save_data)
	_build_cards()

func _on_close() -> void:
	emit_signal("closed")
	queue_free()
