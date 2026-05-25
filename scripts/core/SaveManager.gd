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

## Save schema versions:
##   1 — legacy: Player state only. Branch + floor cache lost on app close.
##   2 — Player + GameManager.floor_cache + branch_floor_cache + branch state.
##   3 — Skills DCSS 30-split (blade→short_blades+long_blades, hafted→maces+axes+staves,
##       ranged→bows+crossbows+slings+throwing, elemental→fire+ice+air+earth+poison,
##       agility→dodging+stealth, tool→invocations+evocations, +new schools/elements).
##       Old skills dict invalid — saves at v<3 should be wiped or migrated externally.
##   4 — Equipment slots: helmet, gloves, boots (in addition to weapon, armor, ring, amulet, shield).
##   5 — Dual-tier skill model: `skills` is now PROJ_G 9-bucket only; `hidden_skills`
##       stores per-DCSS-sub-skill familiarity XP banks. Legacy v<5 saves migrate
##       inline in Game._apply_loaded_player_state (visible = max-of-old level + sum
##       XP; hidden = per-sub-skill data preserved verbatim).
const SAVE_VERSION: int = 5

func save_run(player, game_manager) -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"save_version": SAVE_VERSION,
		"depth": game_manager.depth,
		"seed": game_manager.seed,
		"gold": game_manager.gold,
		"selected_race_id": game_manager.selected_race_id,
		"selected_talent_id": game_manager.selected_talent_id,
		"identified": game_manager.identified,
		"pseudonyms": game_manager.pseudonyms,
		"potion_colors": game_manager.potion_colors,
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
			"helmet": player.equipped_helmet_id,
			"gloves": player.equipped_gloves_id,
			"boots": player.equipped_boots_id,
			"kills": player.kills,
			"last_killer": player.last_killer,
			"known_spells": player.known_spells,
			"statuses": player.statuses,
			"resists": player.resists,
			"skills": player.skills,
			"hidden_skills": player.hidden_skills,
			"active_skills": player.active_skills,
			"quickslots": player.quickslots,
			"essence_slots": player.essence_slots,
			"essence_inventory": player.essence_inventory,
			"faith_id": player.faith_id,
			"first_shrine_choice_done": player.first_shrine_choice_done,
			"body_wounds": player.body_wounds,
		},
		# Branch state (audit C1).
		"branch_zone": game_manager.branch_zone,
		"branch_floor": game_manager.branch_floor,
		"branch_entry_depth": game_manager.branch_entry_depth,
		"branches_cleared": game_manager.branches_cleared.duplicate(),
		# Per-depth and per-branch-floor cache so resume restores the exact
		# state of every visited floor (audit C1).
		"floor_cache": SaveCodec.encode_cache_dict(game_manager.floor_cache),
		"branch_floor_cache": SaveCodec.encode_cache_dict(game_manager.branch_floor_cache),
		"persistent_branch_explored": SaveCodec.encode_explored_map(game_manager.persistent_branch_explored),
		"party": PartyManager.save_state(),
	}
	return save(data)
