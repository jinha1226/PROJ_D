class_name MetaProgression
extends Node
## Persistent meta progression: rune shards, upgrade unlocks, lifetime stats.
## M1 scope — shard bank + save/load + result-screen computations only.

signal shards_changed(new_total: int)
signal upgrade_unlocked(id: String)

const SAVE_VERSION := "1.0"
const DEFAULT_JOBS := ["barbarian", "explorer", "warrior", "rogue", "druid", "smith"]

var rune_shards: int = 0
var unlocked: Dictionary = {}
var stats_record: Dictionary = {}  # {best_depth:int, total_runs:int}


func load_from_disk() -> void:
	var data: Dictionary = SaveManager.load_json(SaveManager.META_FILE)
	if data.is_empty():
		rune_shards = 0
		unlocked = {}
		stats_record = {"best_depth": 0, "total_runs": 0}
		return
	rune_shards = int(data.get("rune_shards", 0))
	var u = data.get("unlocked", {})
	unlocked = u if typeof(u) == TYPE_DICTIONARY else {}
	var s = data.get("stats_record", {})
	stats_record = s if typeof(s) == TYPE_DICTIONARY else {}
	if not stats_record.has("best_depth"):
		stats_record["best_depth"] = 0
	if not stats_record.has("total_runs"):
		stats_record["total_runs"] = 0


func save_to_disk() -> void:
	var payload := {
		"version": SAVE_VERSION,
		"rune_shards": rune_shards,
		"unlocked": unlocked,
		"stats_record": stats_record,
	}
	SaveManager.save_json(SaveManager.META_FILE, payload)


func add_rune_shards(amount: int) -> void:
	if amount == 0:
		return
	rune_shards += amount
	save_to_disk()
	shards_changed.emit(rune_shards)


func unlock(id: String) -> void:
	if unlocked.get(id, false):
		return
	unlocked[id] = true
	save_to_disk()
	upgrade_unlocked.emit(id)


func get_start_hp_bonus() -> float:
	# M1: no upgrades exist yet; formula left in place for forward compat.
	var bonus := 1.0
	if unlocked.get("surv_1", false): bonus += 0.10
	if unlocked.get("surv_2", false): bonus += 0.20
	if unlocked.get("surv_3", false): bonus += 0.30
	return bonus


func get_essence_slot_count() -> int:
	if unlocked.get("ess_2", false): return 3
	if unlocked.get("ess_1", false): return 2
	return 1


func is_job_unlocked(job_id: String) -> bool:
	if job_id in DEFAULT_JOBS:
		return true
	return bool(unlocked.get("job_" + job_id, false))


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
	add_rune_shards(gain)  # saves + emits
	# add_rune_shards already saved but stats_record was mutated before; re-save to be safe.
	save_to_disk()
	return gain
