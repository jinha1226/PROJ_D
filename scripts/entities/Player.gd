class_name Player
extends Node2D
## Player entity. Grid-based movement, melee combat, hooked into TurnManager.

signal moved(new_grid_pos: Vector2i)
signal died
signal attacked(target)
signal damaged(amount: int)
signal stats_changed
signal leveled_up(new_level: int)
signal xp_changed(cur: int, to_next: int, level: int)
## Emitted when Scroll of Identification is used. GameBootstrap shows a
## picker popup that lets the player choose which inventory item to reveal.
signal identify_one_requested
signal enchant_one_requested(kind: String)
## Emitted when an essence's "summon" ability fires. Carries the essence id
## so GameBootstrap knows which Companion template to spawn.
signal summon_companion_requested(essence_id: String)

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var stats: Stats
var base_stats: Stats
var job_id: String = ""
var race_id: String = ""
var job_res: JobData = null
var race_res: RaceData = null
var tile_size: int = 32
var is_alive: bool = true
var level: int = 1
var xp: int = 0
# XP required to reach (level+1) from current level. Linear ramp.
# With tier-1 monsters giving 4–25 XP, level 2 lands around the 5th kill.
const _XP_PER_LEVEL: int = 50
const _HP_PER_LEVEL: int = 5  # fallback if race_res missing
const _MP_PER_LEVEL: int = 3

# [skill-agent] equipped weapon + per-skill state (level/xp/training).
var equipped_weapon_id: String = ""
# True while the equipped weapon is cursed — cannot unequip or drop.
var equipped_weapon_cursed: bool = false
# Bonus damage from Scroll of Enchant Weapon etc. Applied on top of the
# base WeaponRegistry damage inside CombatSystem.melee_attack.
var weapon_bonus_dmg: int = 0
# Slot-keyed Dict: "chest"/"legs"/"boots"/"helm"/"gloves" → {id,name,ac,color,slot}
# Missing key = nothing in that slot.
var equipped_armor: Dictionary = {}
# Array of ring info dicts (from RingRegistry.get_info). Max size is race-
# dependent — octopodes wear eight, everyone else two.
var equipped_rings: Array = []
# Enchant level on the currently-equipped weapon (DCSS "pluses"). Travels
# with the specific item dict in inventory; we mirror it here so combat
# doesn't have to crack open equipped_weapon each tick.
var equipped_weapon_plus: int = 0
var skill_state: Dictionary = {}
# Memorised spell ids. Seeded from job.starting_spells at setup and
# extended by reading spellbooks. Drives the MAGIC menu and what the
# player is allowed to cast.
var learned_spells: Array[String] = []
signal spells_learned

# M1 dummy inventory — Array of Dictionary (FloorItem.as_dict()).
var items: Array = []
signal inventory_changed
# 4 quickslot ids — "" means empty. Filled automatically on pickup of
# the first unique consumable id, cleared when no matching inventory item
# remains. Drives BottomHUD's four quickslot buttons.
var quickslot_ids: Array[String] = ["", "", "", "", "", "", "", ""]
signal quickslots_changed

# Temporary resistance: reduces damage for N more player turns.
var resist_turns: int = 0
# Vulnerability stacks applied to visible monsters (turns remaining).
var _vuln_applied: bool = false

const _CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
const _MOVE_TWEEN_DUR: float = 0.12
# Faster tween used when auto-explore / auto-move is driving movement,
# so tapping to travel across the map reads twice as fast without
# making single-step manual walk feel jittery.
const _MOVE_TWEEN_DUR_AUTO: float = 0.06
# Flipped by TouchInput around the auto-move step call so try_move picks
# the right duration without having to plumb a parameter everywhere.
var is_auto_step: bool = false
const _ATTACK_LUNGE_DUR: float = 0.08
var _sprite: CharacterSprite = null
var _walk_idle_timer: SceneTreeTimer = null
var _move_tween: Tween = null
# Spriggan-style free-move counter: increments on each move, resets when
# the turn actually ends. With race.move_speed_mod=1, every other move
# is "free" (doesn't end the turn) — effectively double speed.
var _free_move_counter: int = 0


func _ready() -> void:
	# Player reacts to its turn but waits for input — does not auto-act.
	if TurnManager and not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)
	z_index = 10
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_to_group("player")
	_ensure_sprite()
	_load_sprite_preset()
	if not attacked.is_connected(_on_self_attacked):
		attacked.connect(_on_self_attacked)
	if not died.is_connected(_on_self_died):
		died.connect(_on_self_died)


func _ensure_sprite() -> void:
	# DCSS / ASCII modes render via Player._draw() (texture-blit or glyph),
	# so we don't need the LPC AnimatedSprite child at all.
	if TileRenderer.is_dcss() or TileRenderer.is_ascii():
		queue_redraw()
		return
	if _sprite != null:
		return
	_sprite = _CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	if _sprite:
		add_child(_sprite)


func _load_sprite_preset() -> void:
	if TileRenderer.is_dcss() or TileRenderer.is_ascii():
		queue_redraw()
		return
	if _sprite == null:
		return
	var preset: Dictionary = _compose_preset()
	if preset.is_empty():
		# Fallback to disk-based preset if composition failed.
		var fallback_id := "%s_%s" % [job_id if job_id != "" else "barbarian", race_id if race_id != "" else "human"]
		preset = LPCPresetLoader.load_with_fallback(fallback_id, "barbarian_human")
	if preset.is_empty():
		push_error("Player: no preset available, sprite will be blank")
		return
	_sprite.load_character(preset)
	_sprite.set_direction("down")
	_sprite.play_anim("idle", true)


## DCSS player rendering: race body + equipped doll layers stacked.
## Order matters: base → legs → chest → boots → gloves → helm → weapon.
## Base sprite is the race (so a deep_elf mage and a human mage look
## different); the job just decides starting gear, which shows up through
## the doll layers.
func _draw() -> void:
	if TileRenderer.is_ascii():
		TileRenderer.draw_ascii_glyph(self, Vector2.ZERO, tile_size,
				String(TileRenderer.PLAYER_GLYPH[0]),
				TileRenderer.PLAYER_GLYPH[1])
		return
	if not TileRenderer.is_dcss():
		return
	var base: Texture2D = _pick_base_sprite()
	if base == null:
		draw_circle(Vector2.ZERO, 10.0, Color(0.2, 0.6, 1.0))
		return
	var sz: Vector2 = base.get_size()
	var rect: Rect2 = Rect2(-sz * 0.5, sz)
	draw_texture_rect(base, rect, false)

	# Overlay doll layers in DCSS paperdoll order: legs → chest → boots →
	# cloak → gloves → helm → weapon.
	var legs_id: String = String(equipped_armor.get("legs", {}).get("id", ""))
	_draw_doll_layer("legs", legs_id, rect)
	var chest_id: String = String(equipped_armor.get("chest", {}).get("id", ""))
	_draw_doll_layer("chest", chest_id, rect)
	var boots_id: String = String(equipped_armor.get("boots", {}).get("id", ""))
	_draw_doll_layer("boots", boots_id, rect)
	var cloak_id: String = String(equipped_armor.get("cloak", {}).get("id", ""))
	_draw_doll_layer("cloak", cloak_id, rect)
	var gloves_id: String = String(equipped_armor.get("gloves", {}).get("id", ""))
	_draw_doll_layer("gloves", gloves_id, rect)
	var helm_id: String = String(equipped_armor.get("helm", {}).get("id", ""))
	_draw_doll_layer("helm", helm_id, rect)
	_draw_doll_layer("weapon", equipped_weapon_id, rect)


## Pick the base body texture: race first, fall back to job, then fighter.
func _pick_base_sprite() -> Texture2D:
	if race_id != "":
		var t: Texture2D = TileRenderer.player_race(race_id)
		if t != null:
			return t
	if job_id != "":
		var t2: Texture2D = TileRenderer.player_race(job_id)
		if t2 != null:
			return t2
	return TileRenderer.player_race("fighter")


func _draw_doll_layer(slot: String, item_id: String, rect: Rect2) -> void:
	if item_id == "":
		return
	var tex: Texture2D = TileRenderer.doll_layer(slot, item_id)
	if tex == null:
		return
	# Overlays are drawn at the same size as the base so they align 1:1.
	draw_texture_rect(tex, rect, false)


## Build a CharacterSprite preset dict reflecting the player's CURRENT
## state (race + currently equipped weapon/armor), not their starting
## loadout. Called both at setup and whenever equipment changes so the
## sprite always matches what's worn.
func _compose_preset() -> Dictionary:
	if race_res == null and race_id != "":
		race_res = load("res://resources/races/%s.tres" % race_id) as RaceData
	if job_res == null and job_id != "":
		job_res = load("res://resources/jobs/%s.tres" % job_id) as JobData
	if race_res == null:
		return {}
	var equipment: Array = []
	# Racial visual: hair / beard / horns / ears.
	if race_res.hair_def != "":
		equipment.append({"def": race_res.hair_def, "variant": race_res.hair_color})
	if race_res.beard_def != "":
		equipment.append({"def": race_res.beard_def, "variant": race_res.beard_color})
	if race_res.horns_def != "":
		equipment.append({"def": race_res.horns_def, "variant": race_res.horns_color})
	if race_res.ears_def != "":
		equipment.append({"def": race_res.ears_def, "variant": race_res.ears_color})
	# Currently equipped weapon (if any).
	if equipped_weapon_id != "":
		equipment.append(_item_id_to_preset_entry(equipped_weapon_id))
	# Currently equipped armor pieces, slot by slot.
	for slot_dict in equipped_armor.values():
		var aid: String = String(slot_dict.get("id", ""))
		if aid != "":
			equipment.append(_item_id_to_preset_entry(aid))
	return {
		"id": "%s_%s" % [job_id, race_id],
		"body_def": race_res.body_def,
		"body_variant": "",
		"skin_tint": race_res.skin_tint,
		"equipment": equipment,
	}


func _item_id_to_preset_entry(item_id: String) -> Dictionary:
	# Weapons: no material variant; the weapon def has no variants.
	if WeaponRegistry.is_weapon(item_id):
		return {"def": item_id, "variant": ""}
	# Armor / clothing: default to brown material for leather tones.
	# Specific job tres files can override by embedding a "{id}|{color}" form
	# (e.g., "leather_chest|steel") which we split here.
	if "|" in item_id:
		var parts: PackedStringArray = item_id.split("|")
		return {"def": parts[0], "variant": parts[1]}
	return {"def": item_id, "variant": "brown"}


func _on_self_attacked(_target) -> void:
	if _sprite:
		_sprite.play_anim("slash", false)


func _on_self_died() -> void:
	if _sprite:
		_sprite.play_anim("hurt", false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.3, 0.6)


func _on_player_turn_started() -> void:
	# Decrement temporary buffs.
	if resist_turns > 0:
		resist_turns -= 1


var trait_res: TraitData = null

func setup(gen: DungeonGenerator, start_pos: Vector2i, job: JobData, race: RaceData = null, p_trait: TraitData = null) -> void:
	generator = gen
	grid_pos = start_pos
	position = Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)
	job_id = job.id if job else ""
	race_id = race.id if race else ""
	job_res = job
	race_res = race
	trait_res = p_trait
	_ensure_sprite()

	var s := Stats.new()
	var trait_str: int = p_trait.str_bonus if p_trait else 0
	var trait_dex: int = p_trait.dex_bonus if p_trait else 0
	var trait_int: int = p_trait.int_bonus if p_trait else 0
	var base_str: int = 8 + (job.str_bonus if job else 0) + trait_str
	var base_dex: int = 8 + (job.dex_bonus if job else 0) + trait_dex
	var base_int: int = 8 + (job.int_bonus if job else 0) + trait_int
	s.STR = base_str
	s.DEX = base_dex
	s.INT = base_int
	var hp_pct: float = 1.0 + (p_trait.hp_bonus_pct if p_trait else 0.0)
	var mp_pct: float = 1.0 + (p_trait.mp_bonus_pct if p_trait else 0.0)
	var hp_total: int = int((5 * level + 30) * hp_pct)
	var mp_total: int = int((3 * level + 10) * mp_pct)
	s.hp_max = hp_total
	s.HP = hp_total
	s.mp_max = mp_total
	s.MP = mp_total
	s.AC = p_trait.ac_bonus if p_trait else 0
	# Race base_ac (gargoyle stone skin, deep_dwarf plating, coglin exo-suit)
	# stacks on top of trait AC; armour bonuses get added later via
	# _recompute_defense when equipment loads.
	if race != null:
		s.AC += race.base_ac
	s.EV = 0
	# Innate evasion bump for flying races — DCSS's tengu/djinni aren't
	# grounded so they slip more attacks.
	var race_trait: String = race.racial_trait if race != null else ""
	if race_trait == "djinni_flight" or race_trait == "tengu_flight":
		s.EV += 2
	stats = s
	base_stats = s.clone()

	# Seed memorised spells from job + trait.
	learned_spells.clear()
	if job != null:
		for spell_id in job.starting_spells:
			var sp: String = String(spell_id)
			if sp != "" and not learned_spells.has(sp):
				learned_spells.append(sp)
	if p_trait != null:
		for spell_id in p_trait.starting_spells:
			var sp: String = String(spell_id)
			if sp != "" and not learned_spells.has(sp):
				learned_spells.append(sp)
		var school_id: String = _trait_to_school(p_trait.id)
		if school_id != "":
			var school_spells: Array = SpellRegistry.SCHOOL_SPELLS.get(school_id, [])
			for entry in school_spells:
				var sid: String = String(entry.get("id", ""))
				if sid != "" and not learned_spells.has(sid):
					learned_spells.append(sid)

	# Pick first weapon from starting_equipment. Every armor piece slots
	# itself by ArmorRegistry.slot_for so a job can start with chest+legs+
	# boots (or more) and they all stack.
	equipped_weapon_id = ""
	equipped_armor = {}
	if job != null:
		for eq_id in job.starting_equipment:
			var sid: String = String(eq_id)
			if WeaponRegistry.is_weapon(sid) and equipped_weapon_id == "":
				equipped_weapon_id = sid
			elif ArmorRegistry.is_armor(sid):
				var info: Dictionary = ArmorRegistry.get_info(sid)
				var slot: String = String(info.get("slot", "chest"))
				if not equipped_armor.has(slot):
					equipped_armor[slot] = info
	# Trait-based weapon/armor/item override
	if p_trait != null:
		var trait_equip: Dictionary = _get_trait_equipment(p_trait.id)
		if trait_equip.has("weapon"):
			equipped_weapon_id = String(trait_equip["weapon"])
		if trait_equip.has("armor"):
			for aid in trait_equip["armor"]:
				var ainfo: Dictionary = ArmorRegistry.get_info(String(aid))
				var aslot: String = String(ainfo.get("slot", "chest"))
				equipped_armor[aslot] = ainfo
		if trait_equip.has("extra_items"):
			for eid in trait_equip["extra_items"]:
				var item_id: String = String(eid)
				items.append({
					"id": item_id,
					"name": WeaponRegistry.display_name_for(item_id),
					"kind": "weapon",
					"color": Color(0.75, 0.75, 0.85),
				})
	_recompute_defense()

	if job != null and (job.id == "mage" or job.id == "warlock"):
		GameManager.identify("mana_potion")
		GameManager.identify("scroll_identify")

	stats_changed.emit()
	queue_redraw()
	_load_sprite_preset()


# [skill-agent] Swap the current weapon. Skill id update happens implicitly via
# WeaponRegistry lookup on next attack; we just re-emit stats_changed so HUDs
# refresh. Returns the previously-equipped weapon id ("" if none). Also
# triggers a sprite-preset reload so the on-screen LPC layers update.
func _trait_to_school(trait_id: String) -> String:
	match trait_id:
		"fire": return "fire"
		"ice": return "cold"
		"earth": return "earth"
		"air": return "air"
		"necro": return "necromancy"
		"hexer": return "hexes"
		"arcane": return "conjurations"
		"warper": return "translocations"
	return ""


func _get_trait_equipment(trait_id: String) -> Dictionary:
	match trait_id:
		"sword": return {"weapon": "longsword"}
		"polearm_trait": return {"weapon": "halberd"}
		"shield_trait": return {"weapon": "short_sword"}
		"heavy_armor": return {"weapon": "arming_sword", "armor": ["plate_chest", "plate_helm"]}
		"axe_trait": return {"weapon": "waraxe"}
		"mace_trait": return {"weapon": "mace"}
		"brawler": return {}
		"throwing_trait": return {"weapon": "throwing_axe"}
		"bow_trait": return {"weapon": "long_bow"}
		"crossbow_trait": return {"weapon": "crossbow"}
		"throwing_ranger": return {"weapon": "slingshot"}
		"scout": return {"weapon": "short_bow"}
		"dagger_trait": return {"weapon": "dagger"}
		"acrobat": return {"weapon": "short_sword"}
		"shadow": return {"weapon": "dagger"}
		"evoker": return {"weapon": "wand_simple"}
	return {}


func equip_weapon(weapon_id: String, plus: int = 0) -> String:
	if equipped_weapon_cursed and equipped_weapon_id != "":
		CombatLog.add("The %s is cursed and won't come off!" % WeaponRegistry.display_name_for(equipped_weapon_id))
		return equipped_weapon_id
	var prev: String = equipped_weapon_id
	equipped_weapon_id = weapon_id
	equipped_weapon_plus = plus
	equipped_weapon_cursed = false
	_auto_train_weapon_skill(weapon_id)
	stats_changed.emit()
	_load_sprite_preset()
	return prev


## Enchant-level of the currently-equipped weapon. Grows when a Scroll
## of Enchant Weapon is used on it.
func equip_weapon_plus() -> int:
	return equipped_weapon_plus


## Current racial trait id — the trait_res takes precedence if the player
## picked a trait card that overrides the race's innate behaviour.
func _racial_trait_id() -> String:
	if trait_res != null and trait_res.special != "":
		return String(trait_res.special)
	if race_res != null:
		return String(race_res.racial_trait)
	return ""


## Called by GameBootstrap when a monster the player was involved with dies.
## Applies heal-on-kill / MP-on-kill racial traits.
func apply_kill_bonuses(_monster: Node) -> void:
	if not is_alive or stats == null:
		return
	match _racial_trait_id():
		"vampire_bloodfeast":
			var heal: int = randi_range(3, 5)
			stats.HP = min(stats.hp_max, stats.HP + heal)
			stats_changed.emit()
			CombatLog.add("Life essence feeds you (+%d HP)." % heal)
		"vine_stalker_mpregen":
			var mp: int = 2
			stats.MP = min(stats.mp_max, stats.MP + mp)
			stats_changed.emit()


## Auto-enable the skill that `weapon_id` trains so the next kill's XP flows
## into the right weapon pool. Does NOT disable the previously-trained
## skill — the player can still turn it off manually in the skill dialog.
func _auto_train_weapon_skill(weapon_id: String) -> void:
	if weapon_id == "":
		return
	var skill_id: String = WeaponRegistry.weapon_skill_for(weapon_id)
	if skill_id == "":
		return
	if not (skill_state is Dictionary) or not skill_state.has(skill_id):
		return
	skill_state[skill_id]["training"] = true


## Equip an armor dict that includes a "slot" key. Replaces the prior armor
## in that slot, returning the displaced dict (empty if the slot was empty).
## Caller is responsible for putting the previous item back into inventory.
func equip_armor(armor: Dictionary) -> Dictionary:
	var slot: String = String(armor.get("slot", "chest"))
	var prev: Dictionary = equipped_armor.get(slot, {})
	equipped_armor[slot] = armor
	_recompute_gear_stats()
	_load_sprite_preset()
	return prev


## Remove an armor slot's entry (e.g. for unequip). Returns the dict.
func unequip_armor_slot(slot: String) -> Dictionary:
	var prev: Dictionary = equipped_armor.get(slot, {})
	equipped_armor.erase(slot)
	_recompute_gear_stats()
	_load_sprite_preset()
	return prev


## Maximum number of rings this player may equip. DCSS octopodes wear
## eight; everyone else is capped at two.
func max_ring_slots() -> int:
	if race_res != null and race_res.racial_trait == "octopode_many_rings":
		return 8
	return 2


## Equip a ring into the next free slot, or replace the ring at
## `slot_index` if specified. Returns the displaced ring dict (empty when
## no ring was removed) so the caller can re-insert it in inventory.
func equip_ring(ring: Dictionary, slot_index: int = -1) -> Dictionary:
	var cap: int = max_ring_slots()
	if cap <= 0:
		return ring
	if slot_index < 0:
		# Find first empty slot; fall back to slot 0 if already full.
		while equipped_rings.size() < cap:
			equipped_rings.append({})
		slot_index = 0
		for i in range(equipped_rings.size()):
			if typeof(equipped_rings[i]) != TYPE_DICTIONARY or equipped_rings[i].is_empty():
				slot_index = i
				break
	# Pad array so slot_index is always valid.
	while equipped_rings.size() <= slot_index:
		equipped_rings.append({})
	var prev: Dictionary = equipped_rings[slot_index] if typeof(equipped_rings[slot_index]) == TYPE_DICTIONARY else {}
	equipped_rings[slot_index] = ring
	_recompute_gear_stats()
	return prev


## Empty a ring slot; returns the removed ring dict (empty if none).
func unequip_ring(slot_index: int) -> Dictionary:
	if slot_index < 0 or slot_index >= equipped_rings.size():
		return {}
	var prev: Dictionary = equipped_rings[slot_index]
	equipped_rings[slot_index] = {}
	_recompute_gear_stats()
	return prev


## Full stat recompute. Base stats are captured on character setup
## (`base_stats`) and never mutated; equipment effects are layered fresh
## on every equip/unequip so swapping rings is always reversible.
func _recompute_gear_stats() -> void:
	if stats == null:
		return
	if base_stats == null:
		base_stats = stats.clone()
	# Reset mutable fields to their base values.
	stats.STR = base_stats.STR
	stats.DEX = base_stats.DEX
	stats.INT = base_stats.INT
	stats.mp_max = base_stats.mp_max
	var base_ev: int = base_stats.EV
	# AC starts at racial intrinsic (gargoyle stone, etc) + trait AC bonus.
	var ac: int = 0
	if race_res != null:
		ac += race_res.base_ac
	if trait_res != null:
		ac += trait_res.ac_bonus
	var ev: int = base_ev
	# Apply armor bonuses (base AC + enchant "plus").
	for slot_dict in equipped_armor.values():
		ac += int(slot_dict.get("ac", 0))
		ac += int(slot_dict.get("plus", 0))
		ev += int(slot_dict.get("ev_bonus", 0))
	# Apply ring bonuses.
	for ring in equipped_rings:
		if typeof(ring) != TYPE_DICTIONARY or ring.is_empty():
			continue
		stats.STR += int(ring.get("str", 0))
		stats.DEX += int(ring.get("dex", 0))
		stats.INT += int(ring.get("int_", 0))
		ac += int(ring.get("ac", 0))
		ev += int(ring.get("ev", 0))
		stats.mp_max += int(ring.get("mp_max", 0))
	stats.AC = ac
	stats.EV = ev
	# Clamp MP if cap dropped below current reading.
	if stats.MP > stats.mp_max:
		stats.MP = stats.mp_max
	stats_changed.emit()


## Back-compat shim: older callers invoke _recompute_defense().
func _recompute_defense() -> void:
	_recompute_gear_stats()


## Aggregate flat-damage bonus from equipped rings (ring of slaying +
## others). Added to every melee hit in CombatSystem.melee_attack.
func gear_damage_bonus() -> int:
	var bonus: int = 0
	for ring in equipped_rings:
		if typeof(ring) == TYPE_DICTIONARY:
			bonus += int(ring.get("dmg_bonus", 0))
	return bonus


## Aggregate flat spell-power bonus from equipped rings.
func gear_spell_power_bonus() -> int:
	var bonus: int = 0
	for ring in equipped_rings:
		if typeof(ring) == TYPE_DICTIONARY:
			bonus += int(ring.get("spell_power", 0))
	return bonus


## Aggregate per-turn HP regen from equipped rings + cloaks.
func gear_regen_per_turn() -> int:
	var r: int = 0
	for ring in equipped_rings:
		if typeof(ring) == TYPE_DICTIONARY:
			r += int(ring.get("regen", 0))
	return r


## Flat incoming-damage reduction from cloak of resistance etc.
func gear_damage_reduction() -> int:
	var red: int = 0
	for slot_dict in equipped_armor.values():
		red += int(slot_dict.get("dmg_reduce", 0))
	return red


func get_current_weapon_skill() -> String:
	if equipped_weapon_id == "":
		return ""
	return WeaponRegistry.weapon_skill_for(equipped_weapon_id)


## Dispatcher for essence active abilities — called from EssenceSystem.invoke
## after it has validated MP and cooldown. All numbers scale with the
## essence_channeling skill so investing in it matters late-game.
func _invoke_essence_ability(e: EssenceData) -> bool:
	var lv: int = _essence_channeling_level()
	match e.ability_id:
		"essence_heal":
			if stats == null:
				return false
			stats.HP = min(stats.hp_max, stats.HP + 20 + lv * 2)
			stats_changed.emit()
			return true
		"essence_blink":
			return _teleport_blink(4 + lv / 6)
		"essence_stomp":
			# Hit every monster within 1 tile (Chebyshev). Damage scales.
			var dmg: int = 6 + lv / 2
			var hit_count: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not m.is_alive:
					continue
				if "grid_pos" in m and max(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y)) <= 1:
					m.take_damage(dmg)
					hit_count += 1
			print("Stomp hit %d enemies (%d dmg each)." % [hit_count, dmg])
			return true
		"essence_breath":
			return _fire_breath_line(lv)
		"essence_regen":
			if stats == null:
				return false
			stats.HP = min(stats.hp_max, stats.HP + 12 + lv)
			stats_changed.emit()
			return true
		"essence_summon":
			# GameBootstrap listens and spawns the actual Companion node.
			summon_companion_requested.emit(e.id)
			return true
		_:
			print("Unknown essence ability: %s" % e.ability_id)
			return false


func _essence_channeling_level() -> int:
	var sk: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	if sk == null:
		return 0
	return sk.get_level(self, "essence_channeling")


## Breath line: every monster in the 4-tile southward line takes damage
## that scales with essence channeling.
func _fire_breath_line(lv: int) -> bool:
	var dmg: int = 10 + lv / 2
	var hit_count: int = 0
	for d in range(1, 5):
		for m in get_tree().get_nodes_in_group("monsters"):
			if not is_instance_valid(m) or not m.is_alive:
				continue
			if "grid_pos" in m and m.grid_pos == grid_pos + Vector2i(0, d):
				m.take_damage(dmg)
				hit_count += 1
	print("Breath line hit %d enemies (%d dmg each)." % [hit_count, dmg])
	return true


func apply_essence_bonuses(essences: Array, synergy: Dictionary = {}) -> void:
	# Snapshot pre-recompute HP/MP to preserve current/max deltas.
	if base_stats == null:
		base_stats = stats.clone() if stats != null else Stats.new()
	var prev_hp: int = stats.HP if stats != null else base_stats.HP
	var prev_mp: int = stats.MP if stats != null else base_stats.MP
	var prev_hp_max: int = stats.hp_max if stats != null else base_stats.hp_max
	var new_stats: Stats = base_stats.clone()
	for e in essences:
		if e == null:
			continue
		new_stats.STR += e.str_bonus
		new_stats.DEX += e.dex_bonus
		new_stats.INT += e.int_bonus
		new_stats.hp_max += e.hp_bonus
		new_stats.AC += e.armor_bonus
		new_stats.EV += e.evasion_bonus
	# Synergy (2+ same type in slots).
	new_stats.STR += int(synergy.get("str", 0))
	new_stats.DEX += int(synergy.get("dex", 0))
	new_stats.INT += int(synergy.get("int", 0))
	new_stats.hp_max += int(synergy.get("hp", 0))
	new_stats.AC += int(synergy.get("armor", 0))
	new_stats.EV += int(synergy.get("evasion", 0))
	# HP delta handling: grow current hp on hp_max increase; clamp on decrease.
	var hp_delta: int = new_stats.hp_max - prev_hp_max
	var new_hp: int = prev_hp + max(0, hp_delta)
	if new_hp > new_stats.hp_max:
		new_hp = new_stats.hp_max
	new_stats.HP = new_hp
	new_stats.MP = min(prev_mp, new_stats.mp_max)
	stats = new_stats
	stats_changed.emit()
	queue_redraw()


func try_move(delta: Vector2i) -> bool:
	if not is_alive:
		return false
	if generator == null:
		return false
	var target: Vector2i = grid_pos + delta
	# Check monster occupancy → attack instead.
	var monster: Node = _monster_at(target)
	if monster != null:
		try_attack_at(target)
		return false
	if not _player_can_walk_on(target):
		return false
	grid_pos = target
	var target_px: Vector2 = Vector2(grid_pos.x * tile_size + tile_size / 2.0, grid_pos.y * tile_size + tile_size / 2.0)
	var dur: float = _MOVE_TWEEN_DUR_AUTO if is_auto_step else _MOVE_TWEEN_DUR
	_tween_visual_to(target_px, dur)
	_pickup_items_here()
	if _sprite:
		_sprite.face_toward(delta)
		_sprite.play_anim("walk", true)
		_walk_idle_timer = get_tree().create_timer(0.2)
		_walk_idle_timer.timeout.connect(_return_to_idle)
	moved.emit(grid_pos)
	var should_end_turn: bool = true
	var speed_mod: int = 0
	if trait_res != null and trait_res.special == "swift":
		speed_mod = 3
	elif race_res != null and race_res.move_speed_mod > 0:
		speed_mod = race_res.move_speed_mod
	if speed_mod > 0:
		_free_move_counter += 1
		if _free_move_counter < speed_mod:
			should_end_turn = false
		else:
			_free_move_counter = 0
	if should_end_turn:
		TurnManager.end_player_turn()
	return true


func _tween_visual_to(target_px: Vector2, duration: float) -> void:
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_property(self, "position", target_px, duration)


func _pickup_items_here() -> void:
	for it in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(it):
			continue
		if it is FloorItem and it.grid_pos == grid_pos:
			items.append(it.as_dict())
			var shown: String = GameManager.display_name_for_item(
					it.item_id, it.display_name, it.kind) if GameManager != null else it.display_name
			CombatLog.add("Picked up: %s" % shown)
			it.queue_free()
	inventory_changed.emit()


## Fill the first empty quickslot with this consumable id, unless it's
## already quickslotted. Weapons/armor/junk don't go into quickslots.
func _try_assign_quickslot(id: String, kind: String) -> void:
	if kind != "potion" and kind != "scroll" and kind != "book":
		return
	if quickslot_ids.has(id):
		return
	for i in quickslot_ids.size():
		if quickslot_ids[i] == "":
			quickslot_ids[i] = id
			quickslots_changed.emit()
			return


## Use the quickslotted consumable in the given slot. Returns true if an
## item was found and consumed. Auto-clears the slot when the last matching
## item is used.
func use_quickslot(index: int) -> bool:
	if index < 0 or index >= quickslot_ids.size():
		return false
	var id: String = quickslot_ids[index]
	if id == "":
		return false
	for i in items.size():
		if String(items[i].get("id", "")) == id:
			use_item(i)
			if not _inventory_contains(id):
				quickslot_ids[index] = ""
				quickslots_changed.emit()
			return true
	# No item of this id left — clear the stale slot.
	quickslot_ids[index] = ""
	quickslots_changed.emit()
	return false


func _inventory_contains(id: String) -> bool:
	for it in items:
		if String(it.get("id", "")) == id:
			return true
	return false


func use_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	var item_id: String = String(it.get("id", ""))
	var info: Dictionary = ConsumableRegistry.get_info(item_id)
	var consumed: bool = false
	if info.is_empty():
		# Unknown id — fall back to legacy kind heuristic.
		match String(it.get("kind", "")):
			"potion":
				if stats != null:
					stats.HP = min(stats.hp_max, stats.HP + 20)
					stats_changed.emit()
				consumed = true
			"scroll":
				print("Read scroll: %s" % it.get("name", ""))
				consumed = true
			_:
				print("Used: %s" % it.get("name", ""))
				consumed = true
	else:
		consumed = _apply_consumable_effect(info)
	if consumed:
		# Auto-identify on use so the player learns what each unknown
		# potion/scroll was.
		if GameManager != null:
			GameManager.identify(item_id)
		items.remove_at(index)
		inventory_changed.emit()
		# Using an item costs a turn.
		TurnManager.end_player_turn()


func _apply_consumable_effect(info: Dictionary) -> bool:
	match String(info.get("effect", "")):
		"heal":
			if stats == null:
				return false
			stats.HP = min(stats.hp_max, stats.HP + int(info.get("amount", 20)))
			stats_changed.emit()
			return true
		"restore_mp":
			if stats == null:
				return false
			stats.MP = min(stats.mp_max, stats.MP + int(info.get("amount", 20)))
			stats_changed.emit()
			return true
		"teleport_random":
			return _teleport_random()
		"blink":
			return _teleport_blink(4)
		"magic_mapping":
			var dmap: Node = get_tree().root.get_node_or_null("Game/DungeonLayer/DungeonMap")
			if dmap != null and dmap.has_method("reveal_all"):
				dmap.reveal_all()
				return true
			return false
		"identify_one":
			# Hand the choice off to the UI — GameBootstrap opens a picker.
			identify_one_requested.emit()
			return true
		"buff_stat":
			if stats == null:
				return false
			var amt: int = int(info.get("amount", 2))
			match String(info.get("stat", "")):
				"STR": stats.STR += amt
				"DEX": stats.DEX += amt
				"INT": stats.INT += amt
			stats_changed.emit()
			return true
		"harm":
			if stats == null:
				return false
			take_damage(int(info.get("amount", 5)))
			return true
		"enchant_weapon":
			# Hand control to the UI so the player picks WHICH weapon to
			# enchant. GameBootstrap listens, shows a picker, then calls
			# apply_enchant(kind, item_ref) to commit.
			enchant_one_requested.emit("weapon")
			return true
		"remove_curse":
			var removed: bool = false
			if equipped_weapon_cursed and equipped_weapon_id != "":
				equipped_weapon_cursed = false
				CombatLog.add("The curse lifts from your %s!" % WeaponRegistry.display_name_for(equipped_weapon_id))
				removed = true
			for slot_key in equipped_armor:
				if bool(equipped_armor[slot_key].get("cursed", false)):
					equipped_armor[slot_key]["cursed"] = false
					removed = true
			if not removed:
				CombatLog.add("You feel briefly cleansed (nothing was cursed).")
			return true
		"enchant_armor":
			enchant_one_requested.emit("armor")
			return true
		"learn_spells":
			var newly: Array[String] = []
			for sp in info.get("spells", []):
				var spell_id: String = String(sp)
				if spell_id != "" and not learned_spells.has(spell_id):
					learned_spells.append(spell_id)
					newly.append(spell_id)
			if newly.is_empty():
				CombatLog.add("You already know these spells.")
			else:
				CombatLog.add("Learned: %s" % ", ".join(newly))
			spells_learned.emit()
			return true
		"curing":
			if stats == null:
				return false
			var amt: int = int(info.get("amount", 15))
			stats.HP = min(stats.hp_max, stats.HP + amt)
			stats_changed.emit()
			CombatLog.add("You feel much better! (+%d HP)" % amt)
			return true
		"resistance":
			resist_turns = int(info.get("turns", 5))
			CombatLog.add("You feel resistant to damage! (%d turns)" % resist_turns)
			return true
		"haste":
			# Skip monster action this turn by ending and immediately starting a new player turn.
			TurnManager.end_player_turn()
			CombatLog.add("Time seems to slow around you!")
			return true
		"degenerate":
			if stats == null:
				return false
			var amt: int = int(info.get("amount", 8))
			stats.hp_max = max(1, stats.hp_max - amt)
			stats.HP = min(stats.HP, stats.hp_max)
			stats_changed.emit()
			CombatLog.add("You feel your life force drain away! (-%d max HP)" % amt)
			return true
		"restore_all":
			if stats == null:
				return false
			stats.HP = stats.hp_max
			stats.MP = stats.mp_max
			stats_changed.emit()
			CombatLog.add("You are fully restored!")
			return true
		"fear_monsters":
			var count: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				m.set_meta("_flee_turns", 4)
				count += 1
			CombatLog.add("Monsters flee in terror! (%d affected)" % count)
			return true
		"immolation":
			var count: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				if not ("grid_pos" in m):
					continue
				var dist: int = max(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y))
				if dist <= 10:
					var fire_dmg: int = randi_range(15, 30)
					m.take_damage(fire_dmg)
					count += 1
			CombatLog.add("Flames engulf the dungeon! (%d monsters scorched)" % count)
			return true
		"holy_word":
			const _UNDEAD_IDS: Array = ["skeleton", "ghoul", "lich", "bog_body", "zombie", "wraith"]
			var count: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				if not ("data" in m) or m.data == null:
					continue
				if not _UNDEAD_IDS.has(String(m.data.id)):
					continue
				var dist: int = max(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y))
				if dist <= 12:
					m.take_damage(randi_range(20, 40))
					count += 1
			CombatLog.add("Holy light smites the undead! (%d struck)" % count)
			return true
		"vulnerability":
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				m.set_meta("_vuln_turns", 4)
			CombatLog.add("Monsters' defences crumble!")
			return true
		"fog":
			var all_tiles: Array = []
			if generator != null:
				for x in DungeonGenerator.MAP_WIDTH:
					for y in DungeonGenerator.MAP_HEIGHT:
						var p: Vector2i = Vector2i(x, y)
						if generator.is_walkable(p):
							all_tiles.append(p)
			var count: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				if all_tiles.is_empty():
					break
				var idx: int = randi() % all_tiles.size()
				if m.has_method("move_to_grid"):
					m.move_to_grid(all_tiles[idx])
					count += 1
			CombatLog.add("A thick fog scatters your foes! (%d displaced)" % count)
			return true
		"acquirement":
			if generator == null:
				return false
			var _acq_weapons: Array = ["longsword", "arming_sword", "waraxe", "mace", "short_bow",
					"halberd", "rapier", "gnarled_staff", "crystal_staff"]
			var _acq_armor: Array = ["chain_chest", "plate_chest", "leather_chest",
					"plate_helm", "leather_helm", "plate_boots"]
			var pool: Array = _acq_weapons + _acq_armor
			var chosen: String = pool[randi() % pool.size()]
			# Emit a pickup-like event: drop item at player position for auto-pickup.
			var fi_script = load("res://scripts/entities/FloorItem.gd")
			if fi_script != null:
				var fi: Node2D = Node2D.new()
				fi.set_script(fi_script)
				get_tree().get_first_node_in_group("entity_layer").add_child(fi)
				fi.setup(generator, grid_pos, {"id": chosen, "cursed": false})
				CombatLog.add("An item appears: %s!" % chosen.replace("_", " ").capitalize())
			return true
		_:
			print("Unknown consumable effect: %s" % info.get("effect"))
			return false


func _teleport_random() -> bool:
	if generator == null:
		return false
	if _is_formicid_stasis():
		CombatLog.add("Your stasis prevents any teleportation.")
		return false
	var candidates: Array = []
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var p: Vector2i = Vector2i(x, y)
			if generator.is_walkable(p) and p != grid_pos:
				candidates.append(p)
	if candidates.is_empty():
		return false
	_teleport_to(candidates[randi() % candidates.size()])
	return true


func _teleport_blink(radius: int) -> bool:
	if generator == null:
		return false
	if _is_formicid_stasis():
		CombatLog.add("Your stasis prevents any teleportation.")
		return false
	var candidates: Array = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			if max(abs(dx), abs(dy)) > radius:
				continue
			var p: Vector2i = grid_pos + Vector2i(dx, dy)
			if generator.is_walkable(p):
				candidates.append(p)
	if candidates.is_empty():
		return false
	_teleport_to(candidates[randi() % candidates.size()])
	return true


## Formicids are permanent-stasis — every teleport/blink path checks this
## so scrolls, blink spells, and trait triggers all bounce off.
func _is_formicid_stasis() -> bool:
	return _racial_trait_id() == "formicid_stasis"


## Race-aware walkability. Extends DungeonGenerator.is_walkable with:
##   merfolk_swim → water tiles count as walkable (tengu_flight likewise
##     ignores water/lava when implemented on a per-tile basis).
## Other races fall back to the default.
func _player_can_walk_on(target: Vector2i) -> bool:
	if generator == null:
		return false
	if generator.is_walkable(target):
		return true
	var tile: int = generator.get_tile(target)
	var trait_id: String = _racial_trait_id()
	if trait_id == "merfolk_swim" and tile == DungeonGenerator.TileType.WATER:
		return true
	if trait_id == "tengu_flight":
		# Winged races cross water but never walk through lava.
		if tile == DungeonGenerator.TileType.WATER:
			return true
	if trait_id == "djinni_flight":
		# Flame-spirits glide over both hazards.
		if tile == DungeonGenerator.TileType.WATER \
				or tile == DungeonGenerator.TileType.LAVA:
			return true
	return false


func _teleport_to(target: Vector2i) -> void:
	grid_pos = target
	position = Vector2(target.x * tile_size + tile_size / 2.0, target.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	moved.emit(grid_pos)


func drop_item(index: int) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	var iid: String = String(it.get("id", ""))
	if equipped_weapon_cursed and iid == equipped_weapon_id:
		CombatLog.add("You can't drop a cursed weapon!")
		return
	items.remove_at(index)
	inventory_changed.emit()
	var parent: Node = get_parent()
	if parent == null:
		return
	var fi: FloorItem = FloorItem.new()
	parent.add_child(fi)
	var extra: Dictionary = {}
	for k in it.keys():
		if k in ["id", "name", "kind", "color"]:
			continue
		extra[k] = it[k]
	fi.setup(grid_pos, String(it.get("id", "")), String(it.get("name", "")),
			String(it.get("kind", "junk")), it.get("color", Color(0.9, 0.9, 0.4)),
			extra)


func get_items() -> Array:
	return items


## Called on monster kill. Grants raw XP to the player level pool and
## promotes as many levels as the running total allows. Each level-up
## emits leveled_up so UI can pop the stat-choice dialog.
func grant_xp(amount: int) -> void:
	if amount <= 0 or not is_alive:
		return
	xp += amount
	while xp >= xp_for_next_level():
		xp -= xp_for_next_level()
		level += 1
		_apply_level_up_growth()
		leveled_up.emit(level)
	xp_changed.emit(xp, xp_for_next_level(), level)


func xp_for_next_level() -> int:
	return _XP_PER_LEVEL * level


func _apply_level_up_growth() -> void:
	if stats == null:
		return
	# Scale HP/MP gains by the race's per-level aptitude so Trolls grow
	# beefy fast and Deep Elves stay fragile.
	var hp_gain: int = race_res.hp_per_level if race_res != null else _HP_PER_LEVEL
	var mp_gain: int = race_res.mp_per_level if race_res != null else _MP_PER_LEVEL
	stats.hp_max += hp_gain
	stats.HP = stats.hp_max  # full heal on level up
	stats.mp_max += mp_gain
	stats.MP = stats.mp_max
	stats_changed.emit()


## Called by the level-up popup with a chosen stat id ("STR"/"DEX"/"INT").
func apply_level_up_stat(stat: String) -> void:
	if stats == null:
		return
	# One stat point per choice — the popup only fires on every third
	# level (see GameBootstrap._on_player_leveled_up), so the overall
	# stat-per-level pace averages 1/3, matching DCSS roughly.
	match stat:
		"STR":
			stats.STR += 1
			stats.hp_max += 2
			stats.HP += 2
		"DEX":
			stats.DEX += 1
		"INT":
			stats.INT += 1
			stats.mp_max += 2
			stats.MP += 2
	stats_changed.emit()


func _return_to_idle() -> void:
	if _sprite:
		_sprite.play_anim("idle", true)


func try_attack_at(target_pos: Vector2i) -> Node:
	if not is_alive:
		return null
	var monster: Node = _monster_at(target_pos)
	if monster == null:
		return null
	# Chebyshev adjacency check.
	var dx: int = abs(target_pos.x - grid_pos.x)
	var dy: int = abs(target_pos.y - grid_pos.y)
	if max(dx, dy) > 1:
		return null
	var delta := Vector2i(sign(target_pos.x - grid_pos.x), sign(target_pos.y - grid_pos.y))
	if _sprite:
		_sprite.face_toward(delta)
	# Sprite slash animation carries the attack feel — no position lunge.
	# [skill-agent] route through CombatSystem so skill levels are factored in.
	var skill_sys: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	CombatSystem.melee_attack(self, monster, skill_sys)
	attacked.emit(monster)
	TurnManager.end_player_turn()
	return monster


func take_damage(amount: int) -> void:
	if not is_alive:
		return
	if resist_turns > 0:
		amount = max(1, amount / 2)
	# --- Racial trait mitigation ---
	var trait_id: String = _racial_trait_id()
	if trait_id == "halfling_lucky" and randf() < 0.15:
		CombatLog.add("Halfling luck — you dodge entirely!")
		return
	if trait_id == "deep_dwarf_dr":
		# Roughly DCSS: halve damage at 50% odds, subtract 1 otherwise.
		if amount >= 4 and randf() < 0.5:
			amount = max(1, amount / 2)
		else:
			amount = max(1, amount - 1)
	# Cloak / gear flat reduction applies after racial mitigation.
	var reduction: int = gear_damage_reduction()
	if reduction > 0:
		amount = max(1, amount - reduction)
	stats.HP -= amount
	damaged.emit(amount)
	if stats.HP <= 0:
		stats.HP = 0
		is_alive = false
		died.emit()
	elif _sprite:
		_sprite.play_anim("hurt", false)
	else:
		# DCSS / sprite-less mode: brief red flash so the hit is visible.
		modulate = Color(1.6, 0.5, 0.5, 1)
		var tw := create_tween()
		tw.tween_property(self, "modulate", Color.WHITE, 0.18)
	stats_changed.emit()


func _monster_at(p: Vector2i) -> Node:
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if "grid_pos" in m and m.grid_pos == p:
			return m
	return null
