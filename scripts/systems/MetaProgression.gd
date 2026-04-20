class_name MetaProgression
extends Node
## Persistent meta progression: rune shards, upgrade unlocks, lifetime stats.

signal shards_changed(new_total: int)
signal upgrade_unlocked(id: String)

const SAVE_VERSION := "1.0"

const UPGRADES: Dictionary = {
	"surv_1":      {"name": "Fortitude I",      "cost": 15,  "cat": "survival",  "requires": ""},
	"surv_2":      {"name": "Fortitude II",     "cost": 40,  "cat": "survival",  "requires": "surv_1"},
	"surv_3":      {"name": "Fortitude III",    "cost": 80,  "cat": "survival",  "requires": "surv_2"},
	"surv_pot":    {"name": "Emergency Potion", "cost": 25,  "cat": "survival",  "requires": ""},
	"combat_1":    {"name": "Battle Instinct I",  "cost": 20, "cat": "combat", "requires": ""},
	"combat_2":    {"name": "Battle Instinct II", "cost": 50, "cat": "combat", "requires": "combat_1"},
	"insight_1":   {"name": "Monster Sense",    "cost": 30,  "cat": "insight",   "requires": ""},
	"insight_2":   {"name": "Monster Analysis", "cost": 80,  "cat": "insight",   "requires": "insight_1"},
	"insight_boss":{"name": "Boss Insight",     "cost": 120, "cat": "insight",   "requires": "insight_2"},
	"ess_1":       {"name": "Essence Affinity I",  "cost": 35, "cat": "essence", "requires": ""},
	"ess_2":       {"name": "Essence Affinity II", "cost": 70, "cat": "essence", "requires": "ess_1"},
	"ess_drop":    {"name": "Essence Resonance",   "cost": 50, "cat": "essence", "requires": ""},
}

## Shards required to unlock non-starter DCSS backgrounds. Starter roster
## (DEFAULT_JOBS) is free; the rest cost shards to gate progression.
const JOB_UNLOCK_COST: Dictionary = {
	"conjurer": 20, "summoner": 25, "necromancer": 30, "enchanter": 25,
	"shapeshifter": 30, "warper": 35, "hedge_wizard": 20,
	"hexslinger": 30, "artificer": 25, "cinder_acolyte": 30,
	"chaos_knight": 40, "reaver": 35, "alchemist": 30, "forgewright": 35,
	"delver": 25, "wanderer": 20,
}

const DEFAULT_JOBS: Array = [
	"fighter", "gladiator", "monk", "berserker", "brigand", "hunter",
	"fire_elementalist", "ice_elementalist", "earth_elementalist", "air_elementalist",
]

var rune_shards: int = 0
var unlocked: Dictionary = {}
var stats_record: Dictionary = {}
var bestiary: Dictionary = {}
# Most recently started run — surfaced on the QuickStart screen so the
# player can re-roll the same build with one tap. Empty strings mean
# "no prior run recorded yet".
var last_race: String = ""
var last_job: String = ""


func load_from_disk() -> void:
	var data: Dictionary = SaveManager.load_json(SaveManager.META_FILE)
	if data.is_empty():
		rune_shards = 0
		unlocked = {}
		stats_record = {"best_depth": 0, "total_runs": 0}
		bestiary = {}
		return
	rune_shards = int(data.get("rune_shards", 0))
	var u = data.get("unlocked", {})
	unlocked = u if typeof(u) == TYPE_DICTIONARY else {}
	var st = data.get("stats_record", {})
	stats_record = st if typeof(st) == TYPE_DICTIONARY else {}
	if not stats_record.has("best_depth"):
		stats_record["best_depth"] = 0
	if not stats_record.has("total_runs"):
		stats_record["total_runs"] = 0
	var b = data.get("bestiary", {})
	bestiary = b if typeof(b) == TYPE_DICTIONARY else {}
	last_race = String(data.get("last_race", ""))
	last_job = String(data.get("last_job", ""))


func save_to_disk() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"rune_shards": rune_shards,
		"unlocked": unlocked,
		"stats_record": stats_record,
		"bestiary": bestiary,
		"last_race": last_race,
		"last_job": last_job,
	}
	SaveManager.save_json(SaveManager.META_FILE, payload)


## Record the race/job the player just started a run with. Persisted so the
## QuickStart screen can surface it as a one-tap rerun option.
func record_last_combo(race_id: String, job_id: String) -> void:
	if race_id == "" or job_id == "":
		return
	if race_id == last_race and job_id == last_job:
		return
	last_race = race_id
	last_job = job_id
	save_to_disk()


func add_rune_shards(amount: int) -> void:
	if amount == 0:
		return
	rune_shards += amount
	save_to_disk()
	shards_changed.emit(rune_shards)


func can_afford(id: String) -> bool:
	var info: Dictionary = UPGRADES.get(id, {})
	if info.is_empty():
		var job_cost: int = int(JOB_UNLOCK_COST.get(id, 0))
		return job_cost > 0 and rune_shards >= job_cost
	return rune_shards >= int(info.get("cost", 9999))


func can_unlock(id: String) -> bool:
	if is_unlocked(id):
		return false
	if not can_afford(id):
		return false
	var info: Dictionary = UPGRADES.get(id, {})
	var req: String = String(info.get("requires", ""))
	if req != "" and not is_unlocked(req):
		return false
	return true


func purchase(id: String) -> bool:
	if not can_unlock(id):
		return false
	var info: Dictionary = UPGRADES.get(id, {})
	var cost: int = 0
	if not info.is_empty():
		cost = int(info.get("cost", 0))
	else:
		cost = int(JOB_UNLOCK_COST.get(id, 0))
	if cost <= 0:
		return false
	rune_shards -= cost
	unlocked[id] = true
	save_to_disk()
	shards_changed.emit(rune_shards)
	upgrade_unlocked.emit(id)
	return true


func is_unlocked(id: String) -> bool:
	return bool(unlocked.get(id, false))


func get_start_hp_bonus() -> float:
	var bonus := 1.0
	if is_unlocked("surv_1"): bonus += 0.10
	if is_unlocked("surv_2"): bonus += 0.20
	if is_unlocked("surv_3"): bonus += 0.30
	return bonus


func get_start_stat_bonus() -> int:
	if is_unlocked("combat_2"): return 2
	if is_unlocked("combat_1"): return 1
	return 0


func gives_starting_potion() -> bool:
	return is_unlocked("surv_pot")


func get_essence_slot_count() -> int:
	if is_unlocked("ess_2"): return 3
	if is_unlocked("ess_1"): return 2
	return 1


func get_essence_drop_mult() -> float:
	return 1.5 if is_unlocked("ess_drop") else 1.0


func shows_monster_hp() -> bool:
	return is_unlocked("insight_1")


func shows_monster_stats() -> bool:
	return is_unlocked("insight_2")


func shows_boss_hints() -> bool:
	return is_unlocked("insight_boss")


func is_job_unlocked(job_id: String) -> bool:
	if job_id in DEFAULT_JOBS:
		return true
	return is_unlocked("job_" + job_id)


func register_monster(monster_id: String) -> void:
	if not bestiary.has(monster_id):
		bestiary[monster_id] = {"kills": 0}
		save_to_disk()


func record_kill(monster_id: String) -> void:
	if not bestiary.has(monster_id):
		bestiary[monster_id] = {"kills": 0}
	bestiary[monster_id]["kills"] = int(bestiary[monster_id].get("kills", 0)) + 1
	save_to_disk()


func is_registered(monster_id: String) -> bool:
	return bestiary.has(monster_id)


func record_run_end(depth_reached: int, victory: bool) -> int:
	var gain: int = 0
	if victory:
		gain = 10 + depth_reached
	else:
		gain = int(max(1, depth_reached / 2))
	var best: int = int(stats_record.get("best_depth", 0))
	if depth_reached > best:
		stats_record["best_depth"] = depth_reached
	stats_record["total_runs"] = int(stats_record.get("total_runs", 0)) + 1
	add_rune_shards(gain)
	save_to_disk()
	return gain
