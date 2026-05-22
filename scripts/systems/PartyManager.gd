extends Node

## Autoload: manages the active companion roster across runs.
## Max 2 companions. Loyalty tracking: 3+ runs together → long-term party.
## Permadeath: companions killed in-dungeon are marked dead and removed at run end.

const MAX_COMPANIONS: int = 2

signal party_changed
signal companion_died(companion_id: String)
signal companion_became_long_term(companion_id: String)

## Active party roster (including freshly-dead until run_end clears them).
var companions: Array = []  # Array[CompanionData]

## Companions available to hire this run (refreshed at run start).
var hireable_pool: Array = []  # Array[CompanionData]


func _ready() -> void:
	pass


# ── Query ─────────────────────────────────────────────────────────────────────

func get_active_companions() -> Array:
	return companions.filter(func(c: CompanionData) -> bool: return not c.is_dead)


func can_recruit() -> bool:
	return get_active_companions().size() < MAX_COMPANIONS


func get_by_id(companion_id: String) -> CompanionData:
	for c in companions:
		if c.id == companion_id:
			return c
	return null


# ── Roster mutations ──────────────────────────────────────────────────────────

func recruit(data: CompanionData) -> bool:
	if not can_recruit():
		return false
	companions.append(data)
	hireable_pool.erase(data)
	party_changed.emit()
	return true


func dismiss(companion_id: String) -> void:
	var c: CompanionData = get_by_id(companion_id)
	if c != null:
		companions.erase(c)
	party_changed.emit()


## Called from Companion node when killed in-dungeon. Marks as dead immediately
## so the in-dungeon HUD can show the death, but doesn't purge from roster
## until on_run_end so the player sees the death result screen.
func on_companion_killed(companion_id: String) -> void:
	var c: CompanionData = get_by_id(companion_id)
	if c != null:
		c.is_dead = true
	companion_died.emit(companion_id)
	party_changed.emit()


## Sync surviving companions' in-dungeon stats back to their data records.
## Call this before saving and when changing floors.
func sync_from_node(companion_node) -> void:
	if companion_node == null or companion_node.data == null:
		return
	companion_node.sync_to_data()


# ── Run lifecycle ─────────────────────────────────────────────────────────────

## Call at the start of every new run. Refreshes the hireable pool and
## full-heals survivors. Dead companions from the previous run are purged here.
func on_run_start(depth: int) -> void:
	companions = companions.filter(func(c: CompanionData) -> bool: return not c.is_dead)
	for c in companions:
		c.hp_max = c.hp_max  # no reset; they carry their current state
	_refresh_hireable_pool(depth)


## Call when the player successfully completes a run (reaches town/surface).
## Increments loyalty for surviving companions and checks for long-term promotion.
func on_run_complete() -> void:
	for c in companions:
		if c.is_dead:
			continue
		c.loyalty_runs += 1
		if not c.is_long_term and c.loyalty_runs >= CompanionData.LONG_TERM_THRESHOLD:
			c.is_long_term = true
			companion_became_long_term.emit(c.id)
			if CombatLog != null:
				CombatLog.post(
					c.display_name + "이(가) 장기 동료가 되었습니다!",
					Color(1.0, 0.9, 0.5))
	# Purge dead companions after giving the run-end screen time to show them.
	companions = companions.filter(func(c: CompanionData) -> bool: return not c.is_dead)
	party_changed.emit()


## On player death: purge dead companions but don't grant loyalty (failed run).
func on_run_failed() -> void:
	companions = companions.filter(func(c: CompanionData) -> bool: return not c.is_dead)
	party_changed.emit()


# ── Hireable pool ─────────────────────────────────────────────────────────────

func _refresh_hireable_pool(depth: int) -> void:
	hireable_pool.clear()
	var pool_size: int = 3
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _i in range(pool_size):
		hireable_pool.append(CompanionData.generate(depth, rng))


# ── Save / Load ───────────────────────────────────────────────────────────────

func save_state() -> Dictionary:
	var arr: Array = []
	for c in companions:
		arr.append(c.to_dict())
	return {"companions": arr}


func load_state(data: Dictionary) -> void:
	companions.clear()
	for d in data.get("companions", []):
		companions.append(CompanionData.from_dict(d))
	party_changed.emit()
