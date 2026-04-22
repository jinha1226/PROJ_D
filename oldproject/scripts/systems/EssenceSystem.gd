class_name EssenceSystem
extends Node
## Essence system (replaces DCSS gods). Three slots — slotted essences grant
## passive stat bonuses AND a synergy bonus when 2+ share a type. Some
## essences also expose an active ability (Player._invoke_essence_ability).

signal slot_changed(index: int, essence: EssenceData)
signal essence_acquired(essence: EssenceData)
signal inventory_full(pending: EssenceData)
signal ability_used(slot: int)

const MAX_INVENTORY: int = 16
const SLOT_COUNT: int = 3

const ESSENCE_COLORS: Dictionary = {
	EssenceData.EssenceType.GIANT: Color(0.85, 0.2, 0.2),
	EssenceData.EssenceType.UNDEAD: Color(0.55, 0.25, 0.75),
	EssenceData.EssenceType.NATURE: Color(0.25, 0.75, 0.35),
	EssenceData.EssenceType.ELEMENTAL: Color(0.25, 0.5, 0.95),
	EssenceData.EssenceType.ABYSS: Color(0.15, 0.1, 0.2),
	EssenceData.EssenceType.DRAGON: Color(0.95, 0.75, 0.15),
}

# Synergy bonuses applied when 2 or 3 slotted essences share a type.
# Table: type_pair_count (2 or 3) → {str, dex, int, hp, armor, evasion}
const SYNERGY: Dictionary = {
	EssenceData.EssenceType.GIANT: {
		2: {"str": 2, "hp": 5},
		3: {"str": 4, "hp": 12, "armor": 1},
	},
	EssenceData.EssenceType.UNDEAD: {
		2: {"int": 2, "hp": 3},
		3: {"int": 3, "hp": 8, "armor": 1},
	},
	EssenceData.EssenceType.NATURE: {
		2: {"dex": 1, "hp": 4},
		3: {"dex": 2, "hp": 10, "evasion": 1},
	},
	EssenceData.EssenceType.ELEMENTAL: {
		2: {"int": 2},
		3: {"int": 4, "hp": 6},
	},
	EssenceData.EssenceType.ABYSS: {
		2: {"int": 1, "dex": 1},
		3: {"int": 3, "dex": 3, "evasion": 2},
	},
	EssenceData.EssenceType.DRAGON: {
		2: {"str": 1, "int": 1, "armor": 1},
		3: {"str": 2, "int": 2, "armor": 2, "hp": 8},
	},
}

@export var player: Player

var slots: Array = []
var inventory: Array[EssenceData] = []
# Per-slot cooldown counter (turns remaining before the ability can fire).
var cooldowns: Array[int] = []


func _ready() -> void:
	if slots.is_empty():
		# DCSS-style slots cap, but gated by MetaProgression's
		# Essence Affinity upgrade: start at 1 slot, 2 after ess_1,
		# 3 after ess_2. Matches how the UPGRADES catalog is worded.
		var slot_cap: int = SLOT_COUNT
		var mp_node: Node = get_tree().root.get_node_or_null("MetaProgression") \
				if get_tree() != null else null
		if mp_node != null and mp_node.has_method("get_essence_slot_count"):
			slot_cap = mini(SLOT_COUNT, maxi(1, int(mp_node.get_essence_slot_count())))
		slots.resize(slot_cap)
		for i in slot_cap:
			slots[i] = null
		cooldowns.resize(slot_cap)
		for i in slot_cap:
			cooldowns[i] = 0


func equip(index: int, essence: EssenceData) -> void:
	if index < 0 or index >= slots.size():
		return
	var prev: EssenceData = slots[index]
	if prev != null and inventory.size() < MAX_INVENTORY:
		inventory.append(prev)
	slots[index] = essence
	cooldowns[index] = 0
	if essence != null:
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
	cooldowns[index] = 0
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
	# MetaProgression Essence Resonance upgrade multiplies the per-
	# monster essence drop chance. Defaults to 1.0 without the unlock.
	var drop_mult: float = 1.0
	var mp_node: Node = get_tree().root.get_node_or_null("MetaProgression") \
			if get_tree() != null else null
	if mp_node != null and mp_node.has_method("get_essence_drop_mult"):
		drop_mult = float(mp_node.get_essence_drop_mult())
	if randf() > essence.drop_chance * drop_mult:
		return
	essence_acquired.emit(essence)
	add_to_inventory(essence)


## Sum of base stat bonuses across all slotted essences + synergy bonuses
## when 2+ share a type. Applied via Player.apply_essence_bonuses.
func recompute_player_stats() -> void:
	if player == null or not player.has_method("apply_essence_bonuses"):
		return
	# Pass the slotted array + synergy extras (as a virtual "bonus essence"
	# aggregated into the dict).
	player.apply_essence_bonuses(slots, _synergy_bonuses())


## Aggregate synergy bonuses for the current slot configuration.
## Returns a Dictionary with keys str/dex/int/hp/armor/evasion.
func _synergy_bonuses() -> Dictionary:
	var totals: Dictionary = {"str": 0, "dex": 0, "int": 0, "hp": 0, "armor": 0, "evasion": 0}
	var counts: Dictionary = {}
	for e in slots:
		if e == null:
			continue
		var t: int = e.essence_type
		counts[t] = int(counts.get(t, 0)) + 1
	for t in counts.keys():
		var c: int = int(counts[t])
		if c < 2:
			continue
		var tier: int = min(c, 3)
		var bonus: Dictionary = SYNERGY.get(t, {}).get(tier, {})
		for k in bonus.keys():
			totals[k] = int(totals.get(k, 0)) + int(bonus[k])
	return totals


func get_color_for(essence: EssenceData) -> Color:
	if essence == null:
		return Color(0.3, 0.3, 0.3)
	return ESSENCE_COLORS.get(essence.essence_type, Color.WHITE)


## Fire the active ability attached to the essence in `slot_index`.
## Returns true on success. Player handles the actual effect and MP cost.
func invoke(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= slots.size():
		return false
	var e: EssenceData = slots[slot_index]
	if e == null or e.ability_id == "":
		return false
	if cooldowns[slot_index] > 0:
		print("Essence ability still on cooldown (%d turns)." % cooldowns[slot_index])
		return false
	if player == null:
		return false
	if player.stats != null and player.stats.MP < e.ability_mp:
		print("Not enough MP.")
		return false
	if not player.has_method("_invoke_essence_ability"):
		return false
	var ok: bool = player._invoke_essence_ability(e)
	if ok:
		if player.stats != null and e.ability_mp > 0:
			player.stats.MP -= e.ability_mp
			player.stats_changed.emit()
		cooldowns[slot_index] = e.ability_cooldown
		ability_used.emit(slot_index)
	return ok


## Called once per player turn. Ticks cooldowns down.
func on_turn_tick() -> void:
	for i in cooldowns.size():
		if cooldowns[i] > 0:
			cooldowns[i] -= 1
