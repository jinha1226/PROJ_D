extends CanvasLayer
class_name UIRoot
## Root UI container. Controls inside a CanvasLayer anchor against the viewport
## directly — TopHUD and BottomHUD use their own .tscn anchor presets
## (top: offset_bottom=148; bottom: anchor_top=1.0, offset_top=-144).
## UILayer in Game.tscn is another CanvasLayer; nested CanvasLayers coexist fine.

@onready var top_hud: Control = $TopHUD
@onready var bottom_hud: Control = $BottomHUD
@onready var popup_manager: CanvasLayer = $PopupManager

func set_hp(cur: int, max_: int) -> void:
	if top_hud and top_hud.has_method("set_hp"):
		top_hud.set_hp(cur, max_)

func set_mp(cur: int, max_: int) -> void:
	if top_hud and top_hud.has_method("set_mp"):
		top_hud.set_mp(cur, max_)

func set_depth(d: int) -> void:
	if top_hud and top_hud.has_method("set_depth"):
		top_hud.set_depth(d)

func set_quickslot(i: int, icon: Texture2D, text: String) -> void:
	if bottom_hud and bottom_hud.has_method("set_quickslot"):
		bottom_hud.set_quickslot(i, icon, text)

func set_essence(id: String, type_color: Color) -> void:
	if bottom_hud and bottom_hud.has_method("set_essence"):
		bottom_hud.set_essence(id, type_color)

func show_item_popup(item_name: String, desc: String, callbacks: Dictionary) -> void:
	popup_manager.show_item_popup(item_name, desc, callbacks)

func show_essence_swap_popup(slot_index: int, current_id: String, inventory: Array, callback: Callable) -> void:
	popup_manager.show_essence_swap_popup(slot_index, current_id, inventory, callback)

func show_levelup_popup(level: int, callback: Callable) -> void:
	popup_manager.show_levelup_popup(level, callback)
