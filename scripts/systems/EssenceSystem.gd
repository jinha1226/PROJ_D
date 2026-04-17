class_name EssenceSystem
extends Node
## M1 essence system: 1 slot, inventory (max 10), drop-on-kill, stat recompute.

signal slot_changed(index: int, essence: EssenceData)
signal essence_acquired(essence: EssenceData)
signal inventory_full(pending: EssenceData)

const MAX_INVENTORY: int = 10
const ESSENCE_COLORS: Dictionary = {
	EssenceData.EssenceType.GIANT: Color(0.85, 0.2, 0.2),
	EssenceData.EssenceType.UNDEAD: Color(0.55, 0.25, 0.75),
	EssenceData.EssenceType.NATURE: Color(0.25, 0.75, 0.35),
	EssenceData.EssenceType.ELEMENTAL: Color(0.25, 0.5, 0.95),
	EssenceData.EssenceType.ABYSS: Color(0.15, 0.1, 0.2),
	EssenceData.EssenceType.DRAGON: Color(0.95, 0.75, 0.15),
}

@export var player: Player

var slot_count: int = 1
var slots: Array = []
var inventory: Array[EssenceData] = []


func _ready() -> void:
	if slots.is_empty():
		slots.resize(slot_count)
		for i in slot_count:
			slots[i] = null


func equip(index: int, essence: EssenceData) -> void:
	if index < 0 or index >= slots.size():
		return
	var prev: EssenceData = slots[index]
	if prev != null:
		# Move previous back to inventory (best-effort — ignore overflow in M1).
		if inventory.size() < MAX_INVENTORY:
			inventory.append(prev)
	slots[index] = essence
	if essence != null:
		# Remove from inventory if present.
		var idx: int = inventory.find(essence)
		if idx >= 0:
			inventory.remove_at(idx)
	recompute_player_stats()
	slot_changed.emit(index, essence)


func unequip(index: int) -> void:
	if index < 0 or index >= slots.size():
		return
	var prev: EssenceData = slots[index]
	if prev != null and inventory.size() < MAX_INVENTORY:
		inventory.append(prev)
	slots[index] = null
	recompute_player_stats()
	slot_changed.emit(index, null)


func add_to_inventory(essence: EssenceData) -> bool:
	if essence == null:
		return false
	if inventory.size() >= MAX_INVENTORY:
		inventory_full.emit(essence)
		return false
	inventory.append(essence)
	return true


func find_essence_by_id(essence_id: String) -> EssenceData:
	if essence_id == "":
		return null
	for e in inventory:
		if e != null and e.id == essence_id:
			return e
	for e in slots:
		if e != null and e.id == essence_id:
			return e
	return null


func try_drop_from_monster(monster: Monster) -> void:
	if monster == null or monster.data == null:
		return
	var drop_id: String = monster.data.essence_drop_id
	if drop_id == "":
		return
	var path: String = "res://resources/essences/%s.tres" % drop_id
	if not ResourceLoader.exists(path):
		return
	var essence: EssenceData = load(path) as EssenceData
	if essence == null:
		return
	if randf() > essence.drop_chance:
		return
	essence_acquired.emit(essence)
	add_to_inventory(essence)


func recompute_player_stats() -> void:
	if player == null:
		return
	if not player.has_method("apply_essence_bonuses"):
		return
	player.apply_essence_bonuses(slots)


func get_color_for(essence: EssenceData) -> Color:
	if essence == null:
		return Color(0.3, 0.3, 0.3)
	return ESSENCE_COLORS.get(essence.essence_type, Color.WHITE)
