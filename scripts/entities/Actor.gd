class_name Actor extends Node2D

## Shared base class for all combatants (Player, and future Monster subclass).
## Contains state variables, constants, and pure methods that are not specific
## to the player's inventory/rendering/input systems.

var CombatLog = null
var GameManager = null
var ItemRegistry = null

signal stats_changed
signal moved(new_pos: Vector2i)
signal died
signal damaged(amount: int)
signal weapon_attacked(target: Vector2i, weapon_skill: String)

@export var grid_pos: Vector2i = Vector2i(1, 1)
var facing: Vector2i = Vector2i(1, 0)
var _map: DungeonMap

# Stats
var hp: int = 10
var hp_max: int = 10
var _dead: bool = false
var mp: int = 0
var mp_max: int = 0
var ac: int = 0
var ev: int = 5
var wl: int = 0
var slay_bonus: int = 0
var wizardry_bonus: int = 0
var fov_radius_bonus: int = 0
var strength: int = 10
var dexterity: int = 10
var intelligence: int = 10
var xl: int = 1
var xp: int = 0

var statuses: Dictionary = {}
var resists: Dictionary = {}
var body_wounds: Dictionary = {}
# Talent system fields
var job_id: String = ""
var talent_ids: Array = []
# Legacy skill fields — kept as empty dicts so any remaining code that
# reads player.skills / player.hidden_skills doesn't crash. Functionally inert.
var skills: Dictionary = {}
var hidden_skills: Dictionary = {}
var active_skills: Array = []

# Equipment slot IDs
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_ring_id: String = ""
var equipped_amulet_id: String = ""
var equipped_shield_id: String = ""
var equipped_helmet_id: String = ""
var equipped_gloves_id: String = ""
var equipped_boots_id: String = ""

var essence_slots: Array = ["", "", ""]
var essence_inventory: Array = []
var faith_id: String = ""
var first_shrine_choice_done: bool = false

# Regen tickers (used by tick_statuses)
var _regen_hp_ticker: int = 0
var _regen_mp_ticker: int = 0
var _regen_wound_ticker: int = 0

const SIGHT_RADIUS: int = 6

# 2026-05-06 compression: sum ~17,000 (91% reduction from prior ~183,000) so
# MAX_XL=20 is reachable in long runs. Tuning targets:
#   no-branch 14F → XL 12-13, 1-branch 18F → XL 14-15, full 4-branch 30F → XL 19-20.
# Rune pickups grant entry_depth × 100 bonus XP to keep deep branches rewarding.
const XP_CURVE: Array = [0, 10, 25, 50, 90, 150, 230, 320, 420, 540,
	650, 800, 980, 1190, 1430, 1700, 2000, 2330, 2690, 3080]

const MAX_XL: int = 20
# PROJ_G visible 9-skill set. These are the ONLY skills shown in UI,
# save files, tutorials, and the character sheet. Each represents 80%
# of player performance in its domain after the balance pass.
## Stub constants retained for backward-compat. Any code still referencing
## SKILL_IDS / SKILL_XP_DELTA / MAX_SKILL_LEVEL / HIDDEN_SUBSKILL_IDS / SKILL_REMAP
## will compile without error. The skill system is otherwise removed.
const SKILL_IDS: Array = []
const SKILL_XP_DELTA: Array = [12, 28, 55, 95, 150, 230, 340, 490, 700]
const MAX_SKILL_LEVEL: int = 9
const HIDDEN_SUBSKILL_IDS: Array = []
const SKILL_REMAP: Dictionary = {}

# Natural light-wound healing. Only progresses when no hostile monster is
# in FOV — being threatened resets the ticker. Severe (level-2) wounds
# are NOT auto-cleared; they still require potion_healing / bandage.
const WOUND_HEAL_INTERVAL_TURNS: int = 25

## Item ids that are two-handed despite their category being a 1H one (e.g.,
## "blade"). Add new explicit two-handers here so shield/cleave/combat checks
## stay in sync.
const _TWO_HANDED_IDS: Array = ["great_blade"]

# ──────────────────────────────────────────────────────────────────────────────
# Virtual hooks — override in subclasses
# ──────────────────────────────────────────────────────────────────────────────

## Override in subclasses for visual feedback on damage.
func _on_take_damage_visual() -> void:
	pass

## Override in subclasses to refresh visual paperdoll after equipment change.
func _on_equipment_changed() -> void:
	pass

# ──────────────────────────────────────────────────────────────────────────────
# Shared methods
# ──────────────────────────────────────────────────────────────────────────────

func compute_fov() -> Dictionary:
	if _map == null:
		return {}
	var is_opaque := func(p: Vector2i) -> bool: return not _map.in_bounds(p) or _map.is_opaque(p)
	var radius: int = SIGHT_RADIUS + fov_radius_bonus
	# Blind clamps FOV to a fixed radius (currently 0 → see only own tile).
	# We special-case clamp_r == 0 here because FieldOfView.compute() always
	# fills the 3×3 around the origin before shadowcasting, which would
	# leak vision for a "see-nothing" blind status.
	var clamp_r: int = Status.fov_clamp(self)
	if clamp_r >= 0:
		radius = min(radius, clamp_r)
		if radius <= 0:
			return {grid_pos: true}
	return FieldOfView.compute(grid_pos, radius, is_opaque)

func apply_status(id: String, turns: int) -> void:
	Status.apply(self, id, turns)
	emit_signal("stats_changed")

func has_status(id: String) -> bool:
	return Status.has(self, id)

func is_wet() -> bool:
	return has_status("wet")

func apply_wet(turns: int = 4) -> void:
	apply_status("wet", turns)
	if CombatLog != null:
		CombatLog.post(LocaleManager.t("LOG_WATER_SOAKS_YOU"), Color(0.55, 0.8, 1.0))

## Signed-magnitude resist mutator. delta > 0 raises resist tier, delta < 0 lowers it
## (or adds vulnerability tier). Erases the key when net is 0 to keep the dict tidy.
func add_resist(element: String, delta: int) -> void:
	if element == "" or delta == 0:
		return
	var net: int = clamp(int(resists.get(element, 0)) + delta, -3, 3)
	if net == 0:
		resists.erase(element)
	else:
		resists[element] = net

func has_two_handed_weapon() -> bool:
	if equipped_weapon_id == "":
		return false
	var w: ItemData = ItemRegistry.get_by_id(equipped_weapon_id) if ItemRegistry != null else null
	if w == null:
		return false
	if w.category == "axe" or w.category == "polearm":
		return true
	return _TWO_HANDED_IDS.has(w.id)

## Skill system removed. Returns 0 for all skill queries (stub for compat).
func get_skill_level(_id: String) -> int:
	return 0

## Talent system query — primary API.
func has_talent(id: String) -> bool:
	return talent_ids.has(id)

## No-op stub — init_skills callers no longer need to do anything.
func init_skills() -> void:
	pass

## Stub — returns "" for all ids (SKILL_REMAP is now empty).
func _canonical_skill(_id: String) -> String:
	return ""

## Stubs retained so any remaining callers (SkillsDialog legacy code) don't crash.
func is_skill_active(_id: String) -> bool:
	return false

func set_active_skills(_ids: Array) -> void:
	pass

func toggle_skill_active(_id: String) -> bool:
	return false

func hp_regen_period() -> int:
	var armor: ItemData = ItemRegistry.get_by_id(equipped_armor_id) if ItemRegistry != null and equipped_armor_id != "" else null
	var base: int = 3 if armor != null and armor.brand == "regen" else 5
	return base

func mp_regen_period() -> int:
	return 6

func apply_berserk(turns: int) -> void:
	Status.apply(self, "berserk", turns)
	CombatLog.post(LocaleManager.t("LOG_YOU_ENTER_A_BERSERK_RAGE"),
		Color(1.0, 0.55, 0.35))
	emit_signal("stats_changed")

func strength_hp_bonus_for_value(value: int) -> int:
	return value / 2

func compute_starting_hp(base_hp: int, base_str: int) -> int:
	return max(1, base_hp + strength_hp_bonus_for_value(base_str))

func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

func _no_hostile_in_sight() -> bool:
	var tree := get_tree()
	if tree == null:
		return true
	if _map == null:
		return true
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster) or n.hp <= 0:
			continue
		if n.is_ally:
			continue
		if _map.visible_tiles.has(n.grid_pos):
			return false
	return true

func wait_turn() -> void:
	if hp < hp_max:
		hp = min(hp_max, hp + 1)
	if mp < mp_max:
		mp = min(mp_max, mp + 1)
	emit_signal("stats_changed")

func tick_statuses() -> void:
	var expired: Array = Status.tick_actor(self)
	for id in expired:
		CombatLog.post(LocaleManager.t("LOG_YOUR_WEARS_OFF") % Status.display_name(id),
			Color(0.75, 0.8, 0.9))
	# Passive regen
	if hp < hp_max:
		_regen_hp_ticker += 1
		if _regen_hp_ticker >= hp_regen_period():
			_regen_hp_ticker = 0
			hp = min(hp_max, hp + 1)
	else:
		_regen_hp_ticker = 0
	if mp < mp_max:
		_regen_mp_ticker += 1
		if _regen_mp_ticker >= mp_regen_period():
			_regen_mp_ticker = 0
			mp = min(mp_max, mp + 1)
	else:
		_regen_mp_ticker = 0
	# Natural wound healing: only progresses when no hostile monster is in
	# the player's current FOV. Being threatened resets the ticker. On
	# threshold, one random level-1 wound is cleared. Level-2 wounds are
	# untouched here — consumables (potion_healing / bandage) remain the
	# only path to downgrade severe wounds.
	if not body_wounds.is_empty():
		if _no_hostile_in_sight():
			_regen_wound_ticker += 1
			if _regen_wound_ticker >= WOUND_HEAL_INTERVAL_TURNS:
				_regen_wound_ticker = 0
				_heal_one_light_wound()
		else:
			_regen_wound_ticker = 0
	else:
		_regen_wound_ticker = 0
	if not statuses.is_empty() or not expired.is_empty():
		emit_signal("stats_changed")
	if has_method("_actor_player_tick"):
		call("_actor_player_tick")

func _heal_one_light_wound() -> void:
	var light_parts: Array = []
	for part in body_wounds.keys():
		if int(body_wounds[part]) == 1:
			light_parts.append(part)
	if light_parts.is_empty():
		return
	var pick: String = String(light_parts[randi() % light_parts.size()])
	body_wounds.erase(pick)
	var label: String = BodyPartSystem.PART_LABELS.get(pick, pick)
	if CombatLog != null:
		CombatLog.post("%s 부위 통증이 가라앉습니다." % label, Color(0.6, 0.9, 0.7))
	emit_signal("stats_changed")

func heal(amount: int) -> void:
	hp = min(hp_max, hp + amount)
	emit_signal("stats_changed")

func take_damage(amount: int, source: String = "") -> void:
	if has_status("invulnerable"):
		CombatLog.post(LocaleManager.t("LOG_YOU_ARE_INVULNERABLE"), Color(1.0, 0.95, 0.5))
		return
	hp = max(0, hp - amount)
	emit_signal("damaged", amount)
	emit_signal("stats_changed")
	_on_take_damage_visual()
	if hp <= 0 and not _dead:
		_dead = true
		emit_signal("died")
