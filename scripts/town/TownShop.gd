extends Control

const BUY_CATALOG: Array = [
	# Weapons
	{"id": "dagger",      "price":  40},
	{"id": "short_sword", "price":  60},
	{"id": "spear",       "price":  70},
	{"id": "staff",       "price":  70},
	{"id": "shortbow",    "price":  80},
	{"id": "long_sword",  "price":  90},
	# Armor
	{"id": "leather_armor",   "price":  55},
	{"id": "buckler",         "price":  40},
	{"id": "leather_cap",     "price":  35},
	{"id": "leather_gloves",  "price":  30},
	{"id": "leather_boots",   "price":  30},
	# Consumables
	{"id": "potion_healing",    "price":  30},
	{"id": "potion_might",      "price":  35},
	{"id": "potion_magic",      "price":  35},
	{"id": "potion_haste",      "price":  45},
	{"id": "potion_resistance", "price":  50},
	{"id": "bandage",           "price":  15},
	# Scrolls
	{"id": "scroll_identify",      "price":  25},
	{"id": "scroll_teleport",      "price":  40},
	{"id": "scroll_magic_mapping", "price":  55},
	{"id": "scroll_fog",           "price":  30},
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

# Pre-game mode: player is shopping before embarking; no save file yet.
func _is_pregame() -> bool:
	return GameManager.starter_shop_gold > 0 or not SaveManager.has_save()

func _current_gold() -> int:
	if _is_pregame():
		return GameManager.starter_shop_gold
	var p: Dictionary = _save_data.get("player", {})
	return int(p.get("gold", 0))

func _set_current_gold(g: int) -> void:
	if _is_pregame():
		GameManager.starter_shop_gold = max(0, g)
		return
	if not _save_data.has("player"):
		_save_data["player"] = {}
	_save_data["player"]["gold"] = max(0, g)

func _ready() -> void:
	theme = GameTheme.create()
	_title.text = LocaleManager.t("UI_SHOP_TITLE")
	_close_btn.text = LocaleManager.t("UI_SHOP_BTN_DONE")
	_close_btn.pressed.connect(_on_close)
	_buy_tab_btn.text = LocaleManager.t("UI_SHOP_TAB_BUY")
	_sell_tab_btn.text = LocaleManager.t("UI_SHOP_TAB_SELL")
	_buy_tab_btn.pressed.connect(_on_tab.bind(Tab.BUY))
	_sell_tab_btn.pressed.connect(_on_tab.bind(Tab.SELL))
	if not _is_pregame():
		_load_save()
	else:
		# Hide sell tab: nothing to sell before the run starts.
		_sell_tab_btn.visible = false
	_build_cards()

func _load_save() -> void:
	if SaveManager.has_save():
		_save_data = SaveManager.load_save()
	else:
		_save_data = {}

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
	if _is_pregame() and not GameManager.pending_starter_items.is_empty():
		_grid.add_child(_make_cart_section())
	for entry in BUY_CATALOG:
		_grid.add_child(_make_buy_card(entry))

func _make_cart_section() -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	var hdr := Label.new()
	hdr.text = "구매 목록 (%d)" % GameManager.pending_starter_items.size()
	hdr.add_theme_font_size_override("font_size", 16)
	hdr.add_theme_color_override("font_color", Color(0.65, 1.0, 0.7))
	vb.add_child(hdr)

	for id_v in GameManager.pending_starter_items:
		var id: String = String(id_v)
		var data = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
		var item_name: String = data.display_name if data != null else id
		var lbl := Label.new()
		lbl.text = "  · %s" % item_name
		lbl.add_theme_font_size_override("font_size", 15)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.9, 0.85))
		vb.add_child(lbl)

	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vb.add_child(sep)
	return vb

func _speed_label(delay: float) -> String:
	if delay <= 1.0:
		return "빠름"
	elif delay <= 1.2:
		return "보통"
	else:
		return "느림"

func _make_buy_card(entry: Dictionary) -> Control:
	var id: String = String(entry["id"])
	var price: int = int(entry["price"])
	var data = ItemRegistry.get_by_id(id) if ItemRegistry != null else null
	var item_name: String = data.display_name if data != null else id

	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)

	# Name + stats column
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var name_lbl := Label.new()
	name_lbl.text = item_name
	name_lbl.add_theme_font_size_override("font_size", 20)
	col.add_child(name_lbl)

	# Weapon stats row
	if data != null and String(data.kind) == "weapon":
		var stats_row := HBoxContainer.new()
		stats_row.add_theme_constant_override("separation", 16)
		col.add_child(stats_row)

		var atk_lbl := Label.new()
		atk_lbl.text = "공격력 %d" % int(data.damage)
		atk_lbl.add_theme_font_size_override("font_size", 15)
		atk_lbl.add_theme_color_override("font_color", Color(1.0, 0.75, 0.4))
		stats_row.add_child(atk_lbl)

		var spd_lbl := Label.new()
		spd_lbl.text = "속도 %s" % _speed_label(float(data.delay))
		spd_lbl.add_theme_font_size_override("font_size", 15)
		spd_lbl.add_theme_color_override("font_color", Color(0.5, 0.9, 0.7))
		stats_row.add_child(spd_lbl)

	# Price label
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % price
	price_lbl.add_theme_font_size_override("font_size", 20)
	price_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
		if item_id == "" or _is_equipped(item_id):
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
	name_lbl.text = name
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
	if _is_pregame():
		GameManager.pending_starter_items.append(item_id)
		_build_cards()
		return
	# In-run purchase: write to save.
	var items: Array = _save_data["player"].get("items", [])
	if typeof(items) != TYPE_ARRAY:
		items = []
	items.append({"id": item_id, "plus": 0})
	_save_data["player"]["items"] = items
	SaveManager.save(_save_data)
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
