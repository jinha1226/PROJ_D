extends Node
## Per-expedition runtime state. Tracks turn budget for the current
## floor and provides the safe-return roll when the budget exhausts.
## Reset on every floor enter; cleared when the expedition ends
## (death, victory, safe-return success).
##
## Not persisted to disk in MVP — if the player saves mid-expedition
## and reloads, budget restarts at the floor entry value. (Acceptable
## for MVP; full persistence is a balance-pass concern.)

signal exhausted

var current_area_id: String = ""
var current_depth: int = 0
var turn_budget: int = 0
var turns_spent: int = 0
# When true, ExpeditionState.tick() will not advance — used to freeze
# the budget during scene transitions, result screens, etc.
var paused: bool = false

# Warnings emitted at these remaining-turn thresholds (descending order).
const WARNING_THRESHOLDS: Array = [60, 30, 10]
var _warnings_fired: Dictionary = {}

func on_floor_enter(area_id: String, depth: int, budget: int) -> void:
	current_area_id = area_id
	current_depth = depth
	turn_budget = budget
	turns_spent = 0
	_warnings_fired = {}
	paused = false

func tick() -> void:
	if paused or turn_budget <= 0:
		return
	turns_spent += 1
	var remaining: int = turns_remaining()
	for thr in WARNING_THRESHOLDS:
		var t: int = int(thr)
		if remaining == t and not _warnings_fired.get(t, false):
			_warnings_fired[t] = true
			if CombatLog != null:
				CombatLog.post(LocaleManager.t("LOG_EXPEDITION_PRESSURE") % t, Color(0.95, 0.85, 0.4))
	if is_exhausted() and not paused:
		paused = true  # latch — prevents re-emit while handler resolves
		emit_signal("exhausted")

func is_exhausted() -> bool:
	return turn_budget > 0 and turns_spent >= turn_budget

func turns_remaining() -> int:
	return max(0, turn_budget - turns_spent)

# Safe-return chance per PROJ_G mobile_skill_balance_rules.md §Survival.
# survival = player.get_skill_level("survival")  (0..9, current code uses ints not 0..100)
# supplies_bonus = 0 in MVP (no supplies inventory yet)
# depth_danger ≈ depth * 4 in MVP (5 main floors map to 4/8/12/16/20 danger)
func safe_return_chance(player, depth: int) -> float:
	var survival: int = 0
	if player != null and player.has_method("get_skill_level"):
		survival = int(player.get_skill_level("survival"))
	# PROJ_G formula uses survival on 0..100 scale; our skills are 0..9.
	# Scale up: each visible skill level ~= 11 points (so lv9 ≈ 99).
	var survival_scaled: float = float(survival) * 11.0
	var supplies_bonus: float = 0.0
	var depth_danger: float = float(depth) * 4.0
	var chance: float = 80.0 + survival_scaled * 0.20 + supplies_bonus - depth_danger
	return clamp(chance, 25.0, 99.0) / 100.0
