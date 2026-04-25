extends Node

# Active passive id for the current run. Empty = no passive.
var _passive_id: String = ""

# Per-turn counter for regeneration (troll).
var _regen_counter: int = 0

# Floor-scoped single-use flags.
var _lucky_used: bool = false       # halfling: crit-negation used this floor
var _hellish_used: bool = false     # tiefling: free MP cast used this floor

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func register(player: Node) -> void:
	_passive_id = ""
	_regen_counter = 0
	_lucky_used = false
	_hellish_used = false
	if player != null:
		player.fov_radius_bonus = 0
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	if race == null:
		return
	_passive_id = race.passive_id
	match _passive_id:
		"keen_eyes":
			player.fov_radius_bonus = 1
		"fleet":
			player.ev = max(1, player.ev + 1)

func clear() -> void:
	_passive_id = ""
	_regen_counter = 0
	_lucky_used = false
	_hellish_used = false

func has_passive(pid: String) -> bool:
	return _passive_id == pid

# ── Per-turn hook ─────────────────────────────────────────────────────────────

func on_player_turn_end(player: Node) -> void:
	if _passive_id == "regeneration":
		_regen_counter += 1
		if _regen_counter >= 3:
			_regen_counter = 0
			if player.hp < player.hp_max:
				player.hp = min(player.hp + 1, player.hp_max)
				CombatLog.post("You regenerate.", Color(0.5, 1.0, 0.6))
				player.emit_signal("stats_changed")

# ── Melee damage bonus (called before final damage dealt by player) ────────────

func melee_damage_bonus(player: Node) -> int:
	match _passive_id:
		"bloodthirst":
			if player.hp * 2 < player.hp_max:
				return 4
		"headbutt":
			return 2
	return 0

# ── After player kills a monster ──────────────────────────────────────────────

func on_player_killed_monster(player: Node) -> void:
	if _passive_id == "blood_drain":
		var healed: int = min(3, player.hp_max - player.hp)
		if healed > 0:
			player.hp += healed
			CombatLog.post("You drain blood. (+%d HP)" % healed, Color(0.8, 0.3, 0.3))
			player.emit_signal("stats_changed")

# ── Incoming damage hook (called before player.take_damage) ──────────────────

func on_player_hit(player: Node, damage: int) -> int:
	if _passive_id == "lucky" and not _lucky_used:
		_lucky_used = true
		var halved: int = max(1, damage / 2)
		CombatLog.post("Lucky! The blow glances off. (%d→%d)" % [damage, halved],
			Color(1.0, 0.9, 0.4))
		return halved
	return damage

# ── Floor change ──────────────────────────────────────────────────────────────

func on_floor_changed(_player: Node) -> void:
	_lucky_used = false
	_hellish_used = false
	_regen_counter = 0

# ── Spell MP check — returns true if cast is allowed ─────────────────────────

func on_spell_cast_mp_check(player: Node, mp_cost: int) -> bool:
	if player.mp >= mp_cost:
		return true
	if _passive_id == "hellish_legacy" and not _hellish_used:
		_hellish_used = true
		CombatLog.post("Hellish Legacy — you cast through sheer will!",
			Color(0.9, 0.5, 0.9))
		return true
	return false

# ── Trap reveal hook — kobold trapfinder ─────────────────────────────────────

func on_check_trap_reveal() -> bool:
	return _passive_id == "trapfinder"

# ── Sleep immunity — elf keen_eyes ────────────────────────────────────────────

func is_sleep_immune() -> bool:
	return _passive_id == "keen_eyes"

# ── Essence duration multiplier — human adaptable ─────────────────────────────

func essence_duration_mult() -> float:
	if _passive_id == "adaptable":
		return 1.5
	return 1.0
