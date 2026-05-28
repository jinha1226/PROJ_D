class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills stubbed at 0; full formula with
## weapon skill / brands lands with SkillSystem (Week 2).

const UNARMED_DAMAGE: int = 2
const BACKSTAB_BASE_BONUS: float = 0.5
const BACKSTAB_PER_AGILITY: float = 0.05
const BACKSTAB_ROGUE_BONUS: float = 0.25
const BACKSTAB_DAGGER_BONUS: float = 0.25
const BACKSTAB_MAX_BONUS: float = 1.0
const XP_PACE_MULTIPLIER: float = 2.2

# d100 balance adapter. Existing content still stores compact roguelike values
# (EV, AC, HD, skill 0-9), but contested rolls resolve as explicit percent
# chances so tuning can be reasoned about on a 1-100 scale.
const D100_MIN_HIT_CHANCE: int = 10
const D100_MAX_HIT_CHANCE: int = 92
const D100_MIN_BLOCK_CHANCE: int = 3
const D100_MAX_BLOCK_CHANCE: int = 75
const D100_PLAYER_BASE_ACCURACY: int = 90
const D100_MONSTER_BASE_ACCURACY: int = 65
const D100_STAT_POINT_PCT: int = 2
const D100_SKILL_LEVEL_PCT: int = 5
const D100_PLUS_PCT: int = 3
const D100_SLAY_PCT: int = 4
const D100_EV_POINT_PCT: int = 3
const D100_HD_POINT_PCT: int = 3
const D100_STATUS_HIT_PENALTY_PCT: int = 5

const _DAMAGE_DICE_BY_WEAPON_ID: Dictionary = {
	"dagger": [1, 4, 1],
	"frost_dagger": [1, 4, 1],
	"venom_dagger": [1, 4, 1],
	"stiletto": [1, 4, 1],
	"dirk": [1, 4, 2],
	"quick_blade": [1, 4, 2],
	"assassin_blade": [1, 6, 1],
	"short_sword": [1, 6, 0],
	"arming_sword": [1, 8, 0],
	"long_sword": [1, 8, 0],
	"flaming_sword": [1, 8, 0],
	"bastard_sword": [1, 10, 0],
	"great_blade": [2, 6, 0],
	"battle_axe": [1, 8, 1],
	"spear": [1, 6, 0],
	"javelin": [1, 6, 0],
	"shortbow": [1, 6, 0],
	"longbow": [1, 8, 0],
	"crossbow": [1, 8, 1],
	"staff": [1, 6, 0],
}

static func _clamp_pct(value: int, lo: int = 0, hi: int = 100) -> int:
	return clampi(value, lo, hi)

static func _roll_pct(chance: int) -> bool:
	return randi_range(1, 100) <= _clamp_pct(chance)

static func _d100_hit_chance(accuracy_pct: int, ev_score_pct: int) -> int:
	return _clamp_pct(
		accuracy_pct - ev_score_pct,
		D100_MIN_HIT_CHANCE,
		D100_MAX_HIT_CHANCE
	)

static func _player_accuracy_pct(player: Player, profile: Dictionary) -> int:
	var stat_source: int = int(profile.stat_source)
	var skill_level: int = int(profile.skill_level)
	var weapon_plus: int = int(profile.weapon_plus)
	var req_hit_pen: int = int(profile.req_hit_pen)
	var skill_id: String = String(profile.skill_id)
	var acc: int = D100_PLAYER_BASE_ACCURACY
	acc += (stat_source - 10) * D100_STAT_POINT_PCT
	acc += skill_level * D100_SKILL_LEVEL_PCT
	acc += weapon_plus * D100_PLUS_PCT
	acc += player.slay_bonus * D100_SLAY_PCT
	acc += req_hit_pen * D100_STATUS_HIT_PENALTY_PCT
	if String(Player.SKILL_REMAP.get(skill_id, "")) == "weapon_mastery":
		acc += player.get_skill_level("weapon_mastery") * 2
	acc -= Status.hit_penalty(player) * D100_STATUS_HIT_PENALTY_PCT
	return acc

static func _monster_accuracy_pct(monster: Monster) -> int:
	var acc: int = D100_MONSTER_BASE_ACCURACY
	acc += monster.data.hd * D100_HD_POINT_PCT
	acc -= Status.hit_penalty(monster) * D100_STATUS_HIT_PENALTY_PCT
	return acc

static func _ev_score_pct(evasion: int) -> int:
	return max(0, evasion) * D100_EV_POINT_PCT

static func _roll_dice(count: int, sides: int, flat: int = 0) -> int:
	var total: int = flat
	for _i in range(max(0, count)):
		total += randi_range(1, max(1, sides))
	return total

static func _weapon_damage_dice(weapon: ItemData) -> Array:
	if weapon == null:
		return [1, 3, 0]
	if _DAMAGE_DICE_BY_WEAPON_ID.has(weapon.id):
		return _DAMAGE_DICE_BY_WEAPON_ID[weapon.id]
	var dmg: int = max(1, weapon.damage)
	if dmg <= 4:
		return [1, 4, 0]
	if dmg <= 6:
		return [1, 6, 0]
	if dmg <= 8:
		return [1, 6, 1]
	if dmg <= 10:
		return [1, 8, 0]
	if dmg <= 12:
		return [1, 10, 0]
	if dmg <= 15:
		return [2, 6, 1]
	return [2, 8, 0]

static func _player_size_score(player: Player) -> int:
	var game_manager = player.GameManager if player != null else null
	var race_registry = null
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		race_registry = tree.root.get_node_or_null("RaceRegistry")
	if game_manager == null or race_registry == null:
		return 10
	var race: RaceData = race_registry.get_by_id(game_manager.selected_race_id)
	return race.size_score if race != null else 10

static func _damage_modifier_from_score(score: int) -> int:
	if score <= 12:
		return -1
	if score <= 20:
		return 0
	if score <= 28:
		return 1
	if score <= 36:
		return 2
	return 3

static func _player_damage_modifier(player: Player, profile: Dictionary) -> int:
	var stat_source: int = int(profile.stat_source)
	var size_score: int = _player_size_score(player)
	return _damage_modifier_from_score(stat_source + size_score)

static func _skill_damage_step(skill_level: int) -> int:
	if skill_level >= 9:
		return 3
	if skill_level >= 6:
		return 2
	if skill_level >= 3:
		return 1
	return 0

static func _armor_soak_roll(ac_score: int) -> int:
	if ac_score <= 0:
		return 0
	if ac_score <= 1:
		return randi_range(0, 1)
	if ac_score <= 2:
		return randi_range(1, 2)
	if ac_score <= 4:
		return randi_range(1, 3)
	if ac_score <= 6:
		return randi_range(2, 4)
	if ac_score <= 8:
		return randi_range(3, 5)
	return randi_range(4, 7) + max(0, ac_score - 10) / 3

## Updates `actor.facing` to point at `target_pos`. No-op if the actor has
## no facing field, no grid_pos, or already overlaps the target. Used by
## the attack entry points so BodyPartSystem.DIRECTION_BIAS sees a
## meaningful flank classification even for in-place / ranged strikes.
static func _face_toward(actor, target_pos: Vector2i) -> void:
	if actor == null or not ("facing" in actor) or not ("grid_pos" in actor):
		return
	var dir: Vector2i = target_pos - actor.grid_pos
	if dir == Vector2i.ZERO:
		return
	if dir.x != 0:
		dir.x = sign(dir.x)
	if dir.y != 0:
		dir.y = sign(dir.y)
	actor.facing = dir

static func _player_attack_profile(player: Player) -> Dictionary:
	var profile: Dictionary = {
		"weapon_dmg": UNARMED_DAMAGE,
		"stat_source": player.strength,
		"stat_scale": 0.35,
		"skill_id": "weapon_mastery",
		"weapon": null,
		"weapon_plus": 0,
		"req_hit_pen": 0,
		"req_dmg_pct": 1.0,
		"skill_level": 0,
	}
	if player.equipped_weapon_id != "":
		var weapon: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
		if weapon != null:
			var entry: Dictionary = player.equipped_weapon_entry()
			profile.weapon = weapon
			profile.weapon_plus = int(entry.get("plus", 0))
			profile.weapon_dmg = max(UNARMED_DAMAGE, weapon.damage + int(profile.weapon_plus))
			# DCSS 30-split: weapon_skill_for_item returns the canonical sub-skill
			# (short_blades / bows / spellcasting / etc). Stat source/scale stay
			# weapon-class-specific because finesse weapons key off DEX while
			# heavy weapons key off STR.
			profile.skill_id = Player.weapon_skill_for_item(weapon)
			if weapon.category == "ranged":
				profile.stat_source = player.dexterity
				profile.stat_scale = 0.25
			elif weapon.category == "staff":
				profile.stat_source = player.intelligence
				profile.stat_scale = 0.25
			elif weapon.category == "dagger":
				profile.stat_source = player.dexterity
				profile.stat_scale = 0.25
			var pen: Dictionary = _weapon_req_penalty(player, weapon)
			profile.req_hit_pen = pen.hit
			profile.req_dmg_pct = pen.dmg_pct
	var skill_id: String = String(profile.skill_id)
	if skill_id != "":
		profile.skill_level = player.get_skill_level(skill_id)
	return profile

static func _player_attack_hits(player: Player, monster: Monster, profile: Dictionary) -> bool:
	var eff_ev: int = max(0, monster.data.ev - (2 if Status.has(monster, "drained") else 0) - Status.ev_penalty(monster))
	var accuracy_pct: int = _player_accuracy_pct(player, profile)
	var ev_score_pct: int = _ev_score_pct(eff_ev)
	var hit_chance: int = _d100_hit_chance(accuracy_pct, ev_score_pct)
	return _roll_pct(hit_chance)

static func _player_attack_base_damage(player: Player, monster: Monster, profile: Dictionary) -> int:
	var weapon: ItemData = profile.weapon
	var req_dmg_pct: float = float(profile.req_dmg_pct)
	var skill_level: int = int(profile.skill_level)
	var dice: Array = _weapon_damage_dice(weapon)
	var raw: int = _roll_dice(int(dice[0]), int(dice[1]), int(dice[2]))
	raw += _player_damage_modifier(player, profile)
	raw += _skill_damage_step(skill_level)
	raw += int(profile.weapon_plus)
	raw += player.slay_bonus
	if "body_wounds" in player:
		var arm_penalty: int = (int(player.body_wounds.get("left_arm", 0))
				+ int(player.body_wounds.get("right_arm", 0))) * 2
		raw = max(1, raw - arm_penalty)
	if req_dmg_pct < 1.0:
		raw = max(1, int(float(raw) * req_dmg_pct))
	if Status.has(player, "damage_boost"):
		raw += randi_range(1, 4)
	var eff_ac: int = max(0, monster.data.ac - (2 if Status.has(monster, "corroded") else 0))
	var soak: int = _armor_soak_roll(eff_ac)
	return max(1, raw - soak)

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	# Face attacker/defender toward each other before damage resolves so
	# BodyPartSystem DIRECTION_BIAS uses the correct flank classification
	# for in-place / reach / ranged strikes (player.try_attack_tile sets
	# player.facing too, but ranged/cleave callers may bypass it).
	_face_toward(player, monster.grid_pos)
	_face_toward(monster, player.grid_pos)
	var profile: Dictionary = _player_attack_profile(player)
	var weapon: ItemData = profile.weapon
	var weapon_plus: int = int(profile.weapon_plus)
	var skill_id: String = String(profile.skill_id)
	var skill_level: int = int(profile.skill_level)
	if not _player_attack_hits(player, monster, profile):
		monster.become_aware(player.grid_pos)
		CombatLog.miss(LocaleManager.t("LOG_YOU_MISS_THE") % monster.data.display_name)
		return
	var base_final: int = _player_attack_base_damage(player, monster, profile)
	var backstab_bonus: int = _backstab_bonus(player, monster, weapon, weapon_plus)
	# Pipeline order (audit H7): base → flat additions → multiplicative chain → brand.
	# All flats sum into one accumulator; all mults compose into one factor; brand
	# is applied last because it is already resist-scaled and not subject to player mults.
	var flat_bonus: int = 0
	flat_bonus += RacePassiveSystem.melee_damage_bonus(player)
	flat_bonus += backstab_bonus
	flat_bonus += EssenceSystem.melee_flat_bonus(player)
	var mult: float = 1.0
	# Faith/essence damage hooks routed by canonical bucket. Mastery mults
	# stubbed to 1.0 under the dual-tier model — left in chain so future
	# wiring of the 20% hidden-familiarity bonus can replace them in place.
	var canon_skill: String = String(Player.SKILL_REMAP.get(skill_id, ""))
	if canon_skill == "archery":
		mult *= EssenceSystem.ranged_damage_mult(player)
		mult *= FaithSystem.ranged_damage_mult(player)
		mult *= player.ranged_mastery_dmg_mult()
	elif canon_skill == "weapon_mastery" or skill_id == "":
		mult *= FaithSystem.melee_damage_mult(player)
		mult *= player.melee_mastery_dmg_mult()
	if not monster.is_aware:
		var uw_mult: float = EssenceSystem.unaware_damage_mult(player)
		if uw_mult > 1.0:
			mult *= uw_mult
	if player.essence_slots.has("essence_plague") and Status.has(monster, "poison"):
		mult *= 1.2
	var final: int = max(1, int(round(float(base_final + flat_bonus) * mult)))
	var brand: String = _weapon_brand(player)
	var brand_extra: int = 0
	if brand != "":
		var brand_element: String = brand_element_of(brand)
		var roll: int = _brand_damage_roll(brand)
		brand_extra = Status.resist_scale(roll, monster.data.resists, brand_element)
		brand_extra = Status.elemental_damage_scale(brand_extra, monster, brand_element)
		if brand_element == "necro":
			brand_extra = max(1, int(round(float(brand_extra) * FaithSystem.necrotic_damage_mult(player))))
		final += brand_extra
	CombatLog.hit(_hit_log(monster.data.display_name, brand, final, brand_extra, backstab_bonus))
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	BodyPartSystem.process_hit(monster, final, player.grid_pos)
	monster.become_aware(player.grid_pos)
	# Tactics XP on every successful hit — positioning and timing awareness.
	player.grant_skill_xp("tactics", 1.5)
	if brand != "" and brand_extra > 0 and monster.hp > 0:
		_apply_brand_status(monster, brand)
		if brand == "drain" and brand_extra > 0:
			var vamp_heal: int = max(1, brand_extra / 2)
			player.heal(vamp_heal)
	if monster.hp > 0 and EssenceSystem.has_venom_touch(player):
		Status.apply(monster, "poison", 3)
	if monster.hp > 0 and EssenceSystem.has_drain_touch(player):
		var drain_hp: int = 2
		monster.take_damage(drain_hp)
		player.heal(drain_hp)
	if monster.hp > 0:
		EssenceSystem.apply_melee_hit_effects(player, monster)
		RingSystem.apply_melee_hit_effects(player, monster)
	# Hydra double-strike: 30% chance to hit again with reduced damage
	if monster.hp > 0 and EssenceSystem.has_hydra_double(player) and randf() < 0.30:
		var hydra_dmg: int = max(1, base_final / 2)
		monster.take_damage(hydra_dmg)
		CombatLog.hit("Hydra strike! (%d)" % hydra_dmg)
	if weapon != null and weapon.category == "axe":
		_cleave_hit(player, monster, final)
	if monster.hp > 0:
		var w_check: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
		if w_check != null and w_check.category == "dagger":
			var swift_chance: float = player.get_skill_level("weapon_mastery") * 0.05
			if swift_chance > 0.0 and randf() < swift_chance:
				CombatLog.hit(LocaleManager.t("LOG_SWIFT_STRIKE"))
				_dagger_swift_strike(player, monster)
	if was_alive and monster.hp <= 0:
		CombatLog.hit(LocaleManager.t("LOG_YOU_KILL_THE") % monster.data.display_name)
		_apply_player_kill_rewards(player, monster, skill_id)
		# Tactics XP bonus on a backstab killing-blow. backstab_bonus > 0
		# iff the kill landed before the monster was aware of the player.
		if backstab_bonus > 0:
			player.grant_skill_xp("tactics", 5.0)

static func _cleave_hit(player: Player, primary: Monster, base_dmg: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var cleave_dmg: int = max(1, base_dmg / 2)
	for node in tree.get_nodes_in_group("monsters"):
		if not (node is Monster):
			continue
		var m: Monster = node as Monster
		if m == primary or m.hp <= 0:
			continue
		var dist: int = max(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y))
		if dist <= 1:
			CombatLog.hit(LocaleManager.t("LOG_CLEAVE_HITS_THE_FOR") % [m.data.display_name, cleave_dmg])
			m.take_damage(cleave_dmg)

static func _dagger_swift_strike(player: Player, monster: Monster) -> void:
	if monster.hp <= 0 or monster.data == null:
		return
	var weapon_item: ItemData = null
	if player.equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
		if w != null:
			weapon_item = w
	var dice: Array = _weapon_damage_dice(weapon_item)
	var raw: int = _roll_dice(int(dice[0]), int(dice[1]), int(dice[2]))
	raw += _damage_modifier_from_score(player.dexterity + _player_size_score(player))
	raw += _skill_damage_step(player.get_skill_level("weapon_mastery"))
	raw += randi_range(0, 1)
	var eff_ac2: int = max(0, monster.data.ac - (2 if Status.has(monster, "corroded") else 0))
	var soak: int = _armor_soak_roll(eff_ac2)
	var final: int = max(1, raw - soak)
	CombatLog.hit(LocaleManager.t("LOG_YOU_HIT_THE_FOR") % [monster.data.display_name, final])
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	monster.become_aware(player.grid_pos)
	if was_alive and monster.hp <= 0:
		CombatLog.hit(LocaleManager.t("LOG_YOU_KILL_THE") % monster.data.display_name)
		_apply_player_kill_rewards(player, monster, Player.weapon_skill_for_item(weapon_item))

static func _apply_player_kill_rewards(player: Player, monster: Monster, skill_id: String) -> void:
	var base_xp: int = max(1, int(round(float(monster.data.xp_value) * XP_PACE_MULTIPLIER)))
	var xp_award: int = player.monster_xp_award(monster, base_xp)
	if xp_award > 0:
		player.grant_xp(xp_award)
		player.grant_kill_skill_xp(float(xp_award), skill_id)
		# Tracking XP: flat per-kill grant for hunting relevant creatures.
		player.grant_skill_xp("tracking", 0.5)
	player.register_kill()
	GameManager.try_kill_unlock(monster.data.id)
	RacePassiveSystem.on_player_killed_monster(player)
	EssenceSystem.apply_on_kill_effects(player)
	RingSystem.apply_on_kill_effects(player)

	# Humanoid gold drop: direct reward (no floor item needed)
	if monster.data.gold_drop_max > 0 and randf() < 0.30:
		var g: int = randi_range(monster.data.gold_drop_max / 2, monster.data.gold_drop_max)
		player.gold += g
		player.emit_signal("stats_changed")
		CombatLog.post(LocaleManager.t("LOG_YOU_LOOT_GOLD") % g, Color(1.0, 0.88, 0.3))

static func _weapon_brand(player: Player) -> String:
	if player.equipped_weapon_id == "":
		return ""
	# Runtime brand from item dict takes precedence
	for entry in player.items:
		if String(entry.get("id", "")) == player.equipped_weapon_id:
			var rb: String = String(entry.get("brand", ""))
			if rb != "":
				return rb
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
	if w == null:
		return ""
	return String(w.brand)

static func _armor_brand(player: Player) -> String:
	if player.equipped_armor_id == "":
		return ""
	for entry in player.items:
		if String(entry.get("id", "")) == player.equipped_armor_id:
			var rb: String = String(entry.get("brand", ""))
			if rb != "":
				return rb
	return ""

static func _apply_armor_brand_retaliation(player: Player, monster: Monster) -> void:
	var brand: String = _armor_brand(player)
	if brand == "" or monster.hp <= 0:
		return
	if randf() >= 0.20:
		return
	match brand:
		"venom":
			Status.apply(monster, "poison", 3)
			CombatLog.post(LocaleManager.t("LOG_YOUR_ARMOR_S_VENOM_LASHES"), Color(0.4, 1.0, 0.4))
		"freezing":
			Status.apply(monster, "frozen", 1)
			CombatLog.post(LocaleManager.t("LOG_YOUR_ARMOR_FREEZES_THE_ATTACKER"), Color(0.5, 0.85, 1.0))
		"flaming":
			Status.apply(monster, "burning", 2)
			CombatLog.post(LocaleManager.t("LOG_YOUR_ARMOR_BURNS_THE_ATTACKER"), Color(1.0, 0.55, 0.2))
		"acid":
			Status.apply(monster, "corroded", 3)
			CombatLog.post(LocaleManager.t("LOG_YOUR_ARMOR_CORRODES_THE_ATTACKER"), Color(0.6, 0.85, 0.3))
		"drain":
			Status.apply(monster, "drained", 3)
			CombatLog.post(LocaleManager.t("LOG_YOUR_ARMOR_DRAINS_THE_ATTACKER"), Color(0.55, 0.35, 0.8))

static func brand_element_of(brand: String) -> String:
	match brand:
		"flaming":  return "fire"
		"freezing": return "cold"
		"venom":    return "poison"
		"electric": return "electric"
		"draining": return "necro"
		"drain":    return "necro"
		"acid":     return "acid"
	return ""

static func _brand_damage_roll(brand: String) -> int:
	match brand:
		"venom":   return randi_range(1, 3)
		"electric": return randi_range(1, 6)
		"acid":     return randi_range(1, 4)
		_:         return randi_range(1, 4)

static func _weapon_req_penalty(player: Player, w: ItemData) -> Dictionary:
	var req: int = w.required_skill
	if req == 0:
		return {"hit": 0, "dmg_pct": 1.0}
	var mapped_skill: String = Player.weapon_skill_for_item(w)
	var skill_lv: int = player.get_skill_level(mapped_skill)
	var missing: int = max(0, req - skill_lv)
	if missing == 0:
		return {"hit": 0, "dmg_pct": 1.0}
	return {
		"hit": missing * -2,
		"dmg_pct": max(0.3, 1.0 - float(missing) * 0.05),
	}

static func _apply_brand_status(target: Monster, brand: String) -> void:
	match brand:
		"flaming":  Status.apply(target, "burning", 2)
		"freezing": Status.apply(target, "frozen", 1)
		"venom":    Status.apply(target, "poison", 3)
		"acid":     Status.apply(target, "corroded", 3)
		"drain":    Status.apply(target, "drained", 3)

static func _hit_log(name: String, brand: String, total: int, extra: int,
		backstab_bonus: int = 0) -> String:
	var suffix: String = ""
	if backstab_bonus > 0:
		suffix = " Ambush! (+%d)" % backstab_bonus
	if brand == "" or extra <= 0:
		return "You hit the %s for %d.%s" % [name, total, suffix]
	match brand:
		"flaming":
			return "You torch the %s for %d (+%d fire).%s" % [name, total, extra, suffix]
		"freezing":
			return "You chill the %s for %d (+%d cold).%s" % [name, total, extra, suffix]
		"venom":
			return "You envenom the %s for %d (+%d poison).%s" % [name, total, extra, suffix]
		"electric":
			return "You shock the %s for %d (+%d electric).%s" % [name, total, extra, suffix]
		"draining":
			return "You drain the %s for %d (+%d).%s" % [name, total, extra, suffix]
		"acid":
			return "You corrode the %s for %d (+%d acid).%s" % [name, total, extra, suffix]
		"drain":
			return "You drain the %s for %d (+%d necro).%s" % [name, total, extra, suffix]
	return "You hit the %s for %d (+%d).%s" % [name, total, extra, suffix]

static func _backstab_bonus(player: Player, monster: Monster, weapon: ItemData,
		weapon_plus: int) -> int:
	if monster == null or monster.is_aware:
		return 0
	var bonus_mult: float = BACKSTAB_BASE_BONUS
	bonus_mult += float(player.get_skill_level("stealth")) * BACKSTAB_PER_AGILITY
	if weapon != null and weapon.category == "dagger":
		bonus_mult += BACKSTAB_DAGGER_BONUS
	bonus_mult = min(BACKSTAB_MAX_BONUS, bonus_mult)
	var base_damage: int = UNARMED_DAMAGE
	if weapon != null:
		base_damage = max(base_damage, weapon.damage + weapon_plus)
	var result: int = max(1, int(round(float(base_damage) * bonus_mult)))
	return int(round(float(result) * FaithSystem.first_strike_mult(player)))

static func monster_ranged_attack_player(monster: Monster, player: Player,
		ra: Dictionary) -> void:
	if player.hp <= 0:
		return
	if player.rt_dodge_active:
		CombatLog.post("회피!", Color(0.3, 0.9, 1.0))
		return
	# Ranged hits also drive BodyPartSystem; face both ends toward each
	# other so DIRECTION_BIAS reads the projectile's true approach side.
	_face_toward(monster, player.grid_pos)
	_face_toward(player, monster.grid_pos)
	var dmg_base: int = int(ra.get("damage", 2))
	var verb: String = String(ra.get("verb", "shoots"))
	var eff_player_ev: int = max(0, player.ev - Status.ev_penalty(player))
	var hit_chance: int = _d100_hit_chance(
		_monster_accuracy_pct(monster),
		_ev_score_pct(eff_player_ev)
	)
	if not _roll_pct(hit_chance):
		CombatLog.miss(LocaleManager.t("LOG_THE_AT_YOU_AND_MISSES") \
				% [monster.data.display_name, verb])
		_grant_defense_xp(player, "dodging", DEFENSE_XP_DODGE)
		return
	if _try_player_shield_block(player, monster):
		_grant_defense_xp(player, "shields", DEFENSE_XP_BLOCK)
		return
	if player.equipped_armor_id != "":
		_grant_defense_xp(player, "armor", DEFENSE_XP_HIT_TAKEN)
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		_grant_defense_xp(player, "shields", DEFENSE_XP_HIT_TAKEN)
	var raw: int = randi_range(1, max(1, dmg_base))
	var eff_ac: int = max(0, player.ac - (2 if Status.has(player, "cursed") else 0))
	var soak: int = _armor_soak_roll(eff_ac)
	var final: int = max(1, raw - soak)
	final = max(1, final - EssenceSystem.incoming_damage_reduction(player))
	# Defense mastery: small multiplicative DR after flat soak/reduction.
	final = max(1, int(round(float(final) * player.defense_mastery_incoming_mult())))
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken(LocaleManager.t("LOG_THE_YOU_FOR") \
			% [monster.data.display_name, verb, final])
	player.take_damage(final, monster.data.id)
	BodyPartSystem.process_hit(player, final, monster.grid_pos)
	if player.hp > 0:
		_apply_armor_brand_retaliation(player, monster)

static func monster_attack_player(monster: Monster, player: Player) -> void:
	if monster.data == null or player.hp <= 0:
		return
	# RT dodge: full invulnerability during dodge window.
	if player.rt_dodge_active:
		CombatLog.post("회피!", Color(0.3, 0.9, 1.0))
		return
	# RT parry: block frontal melee hit and consume the parry window.
	if player.rt_parry_active:
		var atk_vec: Vector2i = monster.grid_pos - player.grid_pos
		var dot: int = player.facing.x * sign(atk_vec.x) + player.facing.y * sign(atk_vec.y)
		if dot >= 1:
			CombatLog.post("막기 성공!", Color(1.0, 0.85, 0.3))
			player.rt_parry_active = false
			return
	# Update facing on both sides before damage resolves (see notes on
	# player_attack_monster). Without this, the player's `facing` reflects
	# their last movement direction, so a monster striking from behind a
	# turned player still gets classified as "front".
	_face_toward(monster, player.grid_pos)
	_face_toward(player, monster.grid_pos)
	var attack: Dictionary = {}
	if not monster.data.attacks.is_empty():
		attack = monster.data.attacks[0]
	var dmg_base: int = int(attack.get("damage", 1))
	# Weapon bonus: if monster carries a weapon, add its damage
	if monster.equipped_weapon_id != "":
		var witem: ItemData = ItemRegistry.get_by_id(monster.equipped_weapon_id) if ItemRegistry != null else null
		if witem != null:
			dmg_base += witem.damage / 2

	var eff_ev: int = max(0, player.ev + (3 if Status.has(player, "blur") else 0) - Status.ev_penalty(player))
	# Defensive skill XP. Constants live in DEFENSE_XP_PER_EVENT.
	# A successful dodge (miss) trains dodging. A hit landing trains armor (if
	# armor-equipped) and shields (if shield-equipped — practice gain even
	# without a block). A successful block grants extra shields XP below.
	var hit_chance: int = _d100_hit_chance(
		_monster_accuracy_pct(monster),
		_ev_score_pct(eff_ev)
	)
	if not _roll_pct(hit_chance):
		CombatLog.miss(LocaleManager.t("LOG_THE_MISSES_YOU") % monster.data.display_name)
		_grant_defense_xp(player, "dodging", DEFENSE_XP_DODGE)
		return
	if _try_player_shield_block(player, monster):
		_grant_defense_xp(player, "shields", DEFENSE_XP_BLOCK)
		return
	if player.equipped_armor_id != "":
		_grant_defense_xp(player, "armor", DEFENSE_XP_HIT_TAKEN)
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		_grant_defense_xp(player, "shields", DEFENSE_XP_HIT_TAKEN)
	# Parry: blade weapon skill gives chance to halve damage
	if player.equipped_weapon_id != "":
		var _wp: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
		if _wp != null and _wp.category == "blade":
			var parry_chance: float = player.get_skill_level("weapon_mastery") * 0.03
			if parry_chance > 0.0 and randf() < parry_chance:
				CombatLog.miss(LocaleManager.t("LOG_YOU_PARRY_THE_S_ATTACK") % monster.data.display_name)
				return
	var dmg_lo: int = max(1, dmg_base * 3 / 5)
	var dmg_hi: int = max(dmg_lo, dmg_base * 3 / 2)
	var raw: int = randi_range(dmg_lo, dmg_hi) + monster.data.hd / 2
	var soak: int = _armor_soak_roll(player.ac)
	var final: int = max(1, raw - soak)
	final = max(1, final - EssenceSystem.incoming_damage_reduction(player))
	# Defense mastery: small multiplicative DR after flat soak/reduction.
	final = max(1, int(round(float(final) * player.defense_mastery_incoming_mult())))
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken(LocaleManager.t("LOG_THE_HITS_YOU_FOR") % [monster.data.display_name, final])
	player.take_damage(final, monster.data.id)
	BodyPartSystem.process_hit(player, final, monster.grid_pos)
	if player.hp > 0:
		_apply_armor_brand_retaliation(player, monster)
	var poison_turns: int = int(attack.get("poison_turns", 0))
	if poison_turns > 0 and player.hp > 0:
		player.apply_status("poison", poison_turns)
		CombatLog.damage_taken(LocaleManager.t("LOG_YOU_ARE_POISONED"))

static func ally_attack_monster(ally: Monster, target: Monster) -> void:
	if ally.data == null or target.data == null:
		return
	var base_dmg: int = 2
	if not ally.data.attacks.is_empty():
		base_dmg = int(ally.data.attacks[0].get("damage", 2))
	var raw: int = randi_range(max(1, base_dmg * 3 / 5), max(1, base_dmg * 3 / 2)) + ally.data.hd / 2
	var soak: int = randi_range(0, target.data.hd / 2 + 1)
	var final: int = max(1, raw - soak)
	CombatLog.post(LocaleManager.t("LOG_YOUR_HITS_THE_FOR") % [
		ally.data.display_name, target.data.display_name, final],
		Color(0.5, 0.9, 0.55))
	target.hp -= final
	target.emit_signal("hit_taken", final)
	if target.hp <= 0:
		target.die()

## Defense skill XP per defensive event. Tuned smaller than kill XP since
## defensive events fire more frequently — every monster turn vs every kill.
const DEFENSE_XP_HIT_TAKEN: float = 1.5  # armor / shields when struck
const DEFENSE_XP_DODGE: float = 2.0      # dodging when EV beats to-hit
const DEFENSE_XP_BLOCK: float = 3.0      # shields bonus on successful block

static func _grant_defense_xp(player: Player, skill_id: String, amount: float) -> void:
	# Bypass active_skills routing — defensive events should always train
	# the relevant defensive sub-skill, not the player's chosen actives.
	if Player.SKILL_IDS.has(skill_id) or Player.HIDDEN_SUBSKILL_IDS.has(skill_id):
		player.grant_skill_xp(skill_id, amount)

static func _try_player_shield_block(player: Player, monster: Monster) -> bool:
	if player.equipped_shield_id == "" or player.has_two_handed_weapon():
		return false
	var shield: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id) if ItemRegistry != null and player.equipped_shield_id != "" else null
	if shield == null:
		return false
	var shield_skill: int = player.get_skill_level("defense")
	var missing: int = max(0, shield.required_skill - shield_skill)
	var block_pct: int = _clamp_pct(
		shield.effect_value + shield_skill * 3 - missing * 4,
		D100_MIN_BLOCK_CHANCE,
		D100_MAX_BLOCK_CHANCE
	)
	if not _roll_pct(block_pct):
		return false
	CombatLog.miss(LocaleManager.t("LOG_YOU_BLOCK_THE_S_ATTACK") % monster.data.display_name)
	return true
