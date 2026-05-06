extends SceneTree

const SPELL_DIR := "res://resources/spells"
const MONSTER_DIR := "res://resources/monsters"
const CLASS_FILES := {
	"fighter": "res://resources/classes/fighter.tres",
	"rogue": "res://resources/classes/brigand.tres",
	"mage": "res://resources/classes/wizard.tres",
}

# Tuning knobs (mirror live constants — keep in sync)
const XP_PACE_MULTIPLIER: float = 2.2   # mirror CombatSystem.gd
const KILL_RATE: float = 0.7            # frac of spawned monsters players kill per floor
const AVG_MONSTERS_PER_FLOOR: int = 11  # Game.gd._monster_count_for_depth midpoint
const RUNE_XP_PER_DEPTH: int = 150      # Player._rune_xp_bonus multiplier

func _init() -> void:
	print("== PocketCrawl Balance Simulator ==")
	_print_spell_thresholds()
	_print_class_hp_curves()
	_print_loot_samples()
	_print_xl_reach()
	_print_mastery_reach()
	quit()

func _print_spell_thresholds() -> void:
	print("")
	print("-- INT thresholds by spell level --")
	var spells := _load_spells()
	spells.sort_custom(func(a, b):
		if a.spell_level != b.spell_level:
			return a.spell_level < b.spell_level
		if a.school != b.school:
			return a.school < b.school
		return a.display_name < b.display_name
	)
	for spell in spells:
		var int_req: int = 8 + maxi(0, int(spell.spell_level) - 1) * 2
		print("L%d INT%02d %s [%s] MP%d XL%d" % [
			spell.spell_level,
			int_req,
			spell.display_name,
			spell.school,
			spell.mp_cost,
			spell.xl_required,
		])

func _print_class_hp_curves() -> void:
	print("")
	print("-- Class HP curves (XL1-10) --")
	for key in CLASS_FILES.keys():
		var cls: Resource = load(CLASS_FILES[key])
		if cls == null:
			continue
		var hp: int = int(cls.starting_hp) + int(cls.starting_str) / 2
		var strength: int = int(cls.starting_str)
		var out: Array[String] = []
		out.append("XL1=%d" % hp)
		for xl in range(2, 11):
			var gain: int = _hp_gain_for_class(String(cls.class_group), strength)
			hp += gain
			out.append("XL%d=%d" % [xl, hp])
		print("%s -> %s" % [String(cls.display_name), ", ".join(out)])

func _print_loot_samples() -> void:
	print("")
	print("-- Loot samples --")
	var registry: Object = load("res://scripts/systems/ItemRegistry.gd").new()
	registry._ready()
	for depth in [1, 3, 5, 8]:
		var counts: Dictionary = {}
		for _i in range(200):
			var item = registry.pick_floor_loot(depth)
			if item == null:
				continue
			var kind: String = String(item.kind)
			counts[kind] = int(counts.get(kind, 0)) + 1
		print("Depth %d -> %s" % [depth, JSON.stringify(counts)])

func _load_spells() -> Array:
	var out: Array = []
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var name := dir.get_next()
		if name == "":
			break
		if dir.current_is_dir():
			continue
		if not name.ends_with(".tres"):
			continue
		var spell = load("%s/%s" % [SPELL_DIR, name])
		if spell != null:
			out.append(spell)
	dir.list_dir_end()
	return out

## Estimated total kill XP earned across a depth range, given:
##   spawn pool = monsters whose [min_depth, max_depth] covers the floor
##   per-floor kills = AVG_MONSTERS_PER_FLOOR × KILL_RATE
##   per-kill xp = monster.xp_value × XP_PACE_MULTIPLIER (rounded)
##   floor xp = avg(xp per kill across spawn pool) × kills
func _expected_kill_xp(floor_from: int, floor_to: int, monsters: Array,
		kill_rate: float = KILL_RATE) -> int:
	var total: float = 0.0
	for d in range(floor_from, floor_to + 1):
		var pool_xp: Array = []
		for m in monsters:
			var min_d: int = int(m.get("min_depth", 1))
			var max_d: int = int(m.get("max_depth", 99))
			if d >= min_d and d <= max_d:
				pool_xp.append(int(m.get("xp_value", 1)))
		if pool_xp.is_empty():
			continue
		var avg_xp: float = 0.0
		for v in pool_xp:
			avg_xp += float(v)
		avg_xp /= float(pool_xp.size())
		var kills_per_floor: float = float(AVG_MONSTERS_PER_FLOOR) * kill_rate
		total += avg_xp * kills_per_floor * XP_PACE_MULTIPLIER
	return int(round(total))

func _xl_for_xp(total_xp: int) -> int:
	# Mirror Player.xp_to_next() walk: subtract delta per level.
	var xp_curve: Array = [0, 10, 25, 50, 90, 150, 230, 320, 420, 540,
		650, 800, 980, 1190, 1430, 1700, 2000, 2330, 2690, 3080]
	var max_xl: int = 20
	var consumed: int = 0
	var xl: int = 1
	while xl < max_xl:
		var need: int = int(xp_curve[xl])
		if total_xp - consumed >= need:
			consumed += need
			xl += 1
		else:
			break
	return xl

func _load_monsters() -> Array:
	var out: Array = []
	var dir := DirAccess.open(MONSTER_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	while true:
		var fname := dir.get_next()
		if fname == "":
			break
		if dir.current_is_dir() or not fname.ends_with(".tres"):
			continue
		var m: Resource = load("%s/%s" % [MONSTER_DIR, fname])
		if m == null:
			continue
		out.append({
			"id": String(m.get("id")),
			"hd": int(m.get("hd")),
			"xp_value": int(m.get("xp_value")),
			"min_depth": int(m.get("min_depth")),
			"max_depth": int(m.get("max_depth")),
			"weight": int(m.get("weight") if m.get("weight") != null else 10),
			"is_boss": bool(m.get("is_boss")),
			"tier": int(m.get("tier") if m.get("tier") != null else 0),
		})
	dir.list_dir_end()
	return out

## Branch boss XP map. Hardcoded mirror of ZoneManager.BRANCHES boss_id —
## simpler than loading the autoload. Verify against Game.gd if branch list
## changes.
const _BRANCH_BOSSES: Dictionary = {
	"swamp": "bog_serpent",
	"ice_caves": "glacial_sovereign",
	"infernal": "ember_tyrant",
	"crypt": "ancient_lich",
}

func _find_monster(monsters: Array, id: String) -> Dictionary:
	for m in monsters:
		if String(m.get("id")) == id:
			return m
	return {}

## Spawn pool for a given depth, weighted. Excludes bosses (they spawn only at
## branch end, handled separately).
func _weighted_pool(monsters: Array, depth: int) -> Array:
	var pool: Array = []
	for m in monsters:
		if bool(m.get("is_boss")):
			continue
		var min_d: int = int(m.get("min_depth"))
		var max_d: int = int(m.get("max_depth"))
		if depth < min_d or depth > max_d:
			continue
		var w: int = maxi(1, int(m.get("weight")))
		for _i in range(w):
			pool.append(m)
	return pool

## Single Monte Carlo run for one floor span. Returns kill XP earned.
func _simulate_floor_span(monsters: Array, floor_from: int, floor_to: int,
		kill_rate: float, monsters_per_floor: int) -> int:
	var xp: float = 0.0
	for d in range(floor_from, floor_to + 1):
		var pool: Array = _weighted_pool(monsters, d)
		if pool.is_empty():
			continue
		# Random spawn count within Game.gd._monster_count_for_depth jitter.
		# Approximated as monsters_per_floor ± 2.
		var spawn_count: int = monsters_per_floor + randi_range(-2, 2)
		var killed: int = int(round(float(spawn_count) * kill_rate))
		for _k in range(killed):
			var pick: Dictionary = pool[randi() % pool.size()]
			xp += float(pick.get("xp_value")) * XP_PACE_MULTIPLIER
	return int(round(xp))

## Monte Carlo XL reach. Per scenario × player profile, run 200 trials with
## random spawn counts (±2 jitter), random weighted picks, branch bosses as
## confirmed kills, rune pickups granted on branch clear. Reports mean XP
## and resulting XL plus min/max bracket.
func _print_xl_reach() -> void:
	print("")
	print("-- Expected XL by depth scenario (200-run Monte Carlo) --")
	print("(%.2fx pace, weighted spawn pool, branch bosses confirmed)" \
		% [XP_PACE_MULTIPLIER])
	var monsters: Array = _load_monsters()
	# Branches: floor span (effective depth) + boss + rune entry depth (top of
	# branch entrance range, Player._rune_xp_bonus uses range[1]).
	var branch_swamp: Dictionary = {"floors": [6, 9], "boss": "bog_serpent", "rune_d": 6}
	var branch_ice: Dictionary = {"floors": [9, 12], "boss": "glacial_sovereign", "rune_d": 9}
	var branch_infernal: Dictionary = {"floors": [12, 15], "boss": "ember_tyrant", "rune_d": 12}
	var branch_crypt: Dictionary = {"floors": [15, 18], "boss": "ancient_lich", "rune_d": 15}
	var scenarios: Array = [
		{"name": "no-branch (D1-14)",        "main": [1, 14], "branches": []},
		{"name": "1-branch swamp",           "main": [1, 14], "branches": [branch_swamp]},
		{"name": "full 4-branch",            "main": [1, 14],
			"branches": [branch_swamp, branch_ice, branch_infernal, branch_crypt]},
	]
	var rates: Array = [
		{"name": "casual",   "rate": 0.5},
		{"name": "normal",   "rate": 0.7},
		{"name": "thorough", "rate": 0.9},
	]
	var trials: int = 200
	seed(42)  # reproducible across reruns; remove for true randomness
	for rate_def in rates:
		print("  --- %s (kill rate %.0f%%) ---" \
			% [String(rate_def.name), float(rate_def.rate) * 100.0])
		for s in scenarios:
			var totals: Array = []
			for _t in range(trials):
				var run_xp: int = _simulate_floor_span(monsters,
					int(s.main[0]), int(s.main[1]),
					float(rate_def.rate), AVG_MONSTERS_PER_FLOOR)
				for br in s.branches:
					run_xp += _simulate_floor_span(monsters,
						int(br.floors[0]), int(br.floors[1]),
						float(rate_def.rate), AVG_MONSTERS_PER_FLOOR)
					var boss: Dictionary = _find_monster(monsters, String(br.boss))
					if not boss.is_empty():
						run_xp += int(round(float(boss.get("xp_value"))
							* XP_PACE_MULTIPLIER))
					run_xp += int(br.rune_d) * RUNE_XP_PER_DEPTH
				totals.append(run_xp)
			var mean_xp: float = 0.0
			for v in totals:
				mean_xp += float(v)
			mean_xp /= float(trials)
			totals.sort()
			var p10: int = int(totals[trials / 10])
			var p90: int = int(totals[trials * 9 / 10])
			var xl_mean: int = _xl_for_xp(int(round(mean_xp)))
			var xl_p10: int = _xl_for_xp(p10)
			var xl_p90: int = _xl_for_xp(p90)
			print("    %-22s mean=%5d xl=%2d  | p10=%2d p90=%2d" \
				% [s.name, int(round(mean_xp)), xl_mean, xl_p10, xl_p90])
	print("  Targets: no-branch 12-13 / 1-branch 14-15 / full 4 19-20")

## Mastery reach: how high a category-mastery level a player hits given the
## sub-skill XP they earned, under both routing modes.
##  - action-routed: 100%% XP to one sub-skill in the category
##  - split-3:        33%% XP to each of 3 sub-skills in the category
func _print_mastery_reach() -> void:
	print("")
	print("-- Mastery reach (per category, given allocated XP share) --")
	var skill_xp_delta: Array = [12, 28, 55, 95, 150, 230, 340, 490, 700]
	var mastery_xp_delta: Array = [60, 140, 275, 475, 750, 1150, 1700, 2450, 3500]
	# share scenarios — fraction of total XP that lands in the category.
	# Action-routed melee build = nearly 100%; split build with 3 actives in
	# different categories = 33% each.
	var total_xp_buckets: Array = [800, 2000, 4000, 8000, 15000]
	for total in total_xp_buckets:
		var ar_lv: int = _mastery_level_for_xp(total, mastery_xp_delta)
		# Split: only 1/3 of XP to this category (rest to others)
		var split_lv: int = _mastery_level_for_xp(total / 3, mastery_xp_delta)
		# Single-skill specialist sub-skill level — given action-routed XP
		# all into one sub-skill, what level does it hit?
		var ar_sub: int = _skill_level_for_xp(total, skill_xp_delta)
		# Split: 1/3 of XP to one sub-skill (3 actives in same category)
		var split_sub: int = _skill_level_for_xp(total / 3, skill_xp_delta)
		print("  %5d cat-xp → mastery=%d (split=%d) | sub-skill=%d (split=%d)" \
			% [total, ar_lv, split_lv, ar_sub, split_sub])

func _mastery_level_for_xp(xp: int, deltas: Array) -> int:
	var consumed: int = 0
	var lv: int = 0
	for d in deltas:
		if xp - consumed >= int(d):
			consumed += int(d)
			lv += 1
		else:
			break
	return mini(9, lv)

func _skill_level_for_xp(xp: int, deltas: Array) -> int:
	var consumed: int = 0
	var lv: int = 0
	for d in deltas:
		if xp - consumed >= int(d):
			consumed += int(d)
			lv += 1
		else:
			break
	return mini(9, lv)

func _hp_gain_for_class(class_group: String, strength: int) -> int:
	var base_gain: int = 4
	match class_group:
		"fighter":
			base_gain = 5
		"rogue":
			base_gain = 4
		"mage":
			base_gain = 3
	return max(2, base_gain + strength / 6)
