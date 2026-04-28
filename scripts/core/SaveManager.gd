extends Node

const SAVE_PATH: String = "user://save.json"

func save(data: Dictionary) -> bool:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveManager: cannot open save file for write")
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true

func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

func save_run(player, game_manager) -> bool:
	var data: Dictionary = {
		"version": 1,
		"depth": game_manager.depth,
		"seed": game_manager.seed,
		"gold": game_manager.gold,
		"selected_class_id": game_manager.selected_class_id,
		"selected_race_id": game_manager.selected_race_id,
		"identified": game_manager.identified,
		"pseudonyms": game_manager.pseudonyms,
		"kill_counts": game_manager.kill_counts,
		"player": {
			"hp": player.hp,
			"hp_max": player.hp_max,
			"mp": player.mp,
			"mp_max": player.mp_max,
			"ac": player.ac,
			"ev": player.ev,
			"wl": player.wl,
			"str": player.strength,
			"dex": player.dexterity,
			"int": player.intelligence,
			"xl": player.xl,
			"xp": player.xp,
			"gold": player.gold,
			"items": player.items,
			"weapon": player.equipped_weapon_id,
			"armor": player.equipped_armor_id,
			"ring": player.equipped_ring_id,
			"amulet": player.equipped_amulet_id,
			"shield": player.equipped_shield_id,
			"kills": player.kills,
			"last_killer": player.last_killer,
			"known_spells": player.known_spells,
			"statuses": player.statuses,
			"resists": player.resists,
			"skills": player.skills,
			"active_skills": player.active_skills,
			"quickslots": player.quickslots,
			"essence_slots": player.essence_slots,
			"essence_inventory": player.essence_inventory,
			"faith_id": player.faith_id,
			"first_shrine_choice_done": player.first_shrine_choice_done,
		},
	}
	return save(data)
