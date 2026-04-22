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
## DCSS XP table — cumulative XP required to REACH this XL, lifted
## verbatim from player.cc:exp_needed. XL 1 costs 0; XL 2 costs 10;
## XL 27 (cap) costs 1,059,325. Per-level cost is `table[N] - table[N-1]`.
const _DCSS_EXP_NEEDED: Array = [
	0, 10, 30, 70, 140, 270, 520, 1010, 1980, 3910,
	7760, 15450, 26895, 45585, 72745, 108375, 152475, 205045,
	266085, 335595, 413575, 500025, 594945, 698335, 810195, 930525, 1059325,
]
const _HP_PER_LEVEL: int = 5  # fallback if race_res missing
const _MP_PER_LEVEL: int = 3


## True when the next step `delta` brings the player closer to any
## hostile monster they can currently see. Used by the SPARM_RAMPAGING
## ego gate so rampage only fires when the player is closing on a foe.
func _move_is_toward_hostile(delta: Vector2i) -> bool:
	if generator == null or delta == Vector2i.ZERO:
		return false
	var target_cell: Vector2i = grid_pos + delta
	var closest: int = 999999
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
			continue
		var cur: int = maxi(abs(m.grid_pos.x - grid_pos.x),
				abs(m.grid_pos.y - grid_pos.y))
		var nxt: int = maxi(abs(m.grid_pos.x - target_cell.x),
				abs(m.grid_pos.y - target_cell.y))
		if nxt < cur:
			return true
		closest = mini(closest, cur)
	return false


## DCSS player_spell_levels(xl, spellcasting). Max total difficulty
## of memorised spells. Per player.cc: sl = min(xl, 27)/2 + spellcasting/3.
## Each spell's `difficulty` field (SpellRegistry) eats into this pool.
func max_spell_levels() -> int:
	var xl: int = level
	var sp: int = _skill_level("spellcasting")
	return min(xl, 27) / 2 + sp / 3


func used_spell_levels() -> int:
	var total: int = 0
	for sid in learned_spells:
		total += _spell_difficulty(String(sid))
	return total


func _spell_difficulty(spell_id: String) -> int:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	return int(info.get("difficulty", 1)) if not info.is_empty() else 1


## DCSS get_real_hp (player.cc:4160) — base HP from XL + fighting skill, then
## scaled by species hp_mod. Excludes transient bonuses (berserk, artifacts,
## mutations) which we don't model yet.
static func _dcss_max_hp(xl: int, fighting_skill: int, hp_mod: int) -> int:
	var hitp: int = xl * 11 / 2 + 8
	hitp += xl * fighting_skill * 5 / 70
	hitp += (fighting_skill * 3 + 1) / 2
	hitp = hitp * (10 + hp_mod) / 10
	return max(1, hitp)


## DCSS get_real_mp (player.cc:4217) — spellcasting/invocations scaled by XL
## with a soft cap. Species mp_mod is a flat bonus added after scaling.
## Mutations and items are not applied here; pass 0 for invocations until
## we model god abilities.
static func _dcss_max_mp(xl: int, spellcasting: int, invocations: int, mp_mod: int) -> int:
	var scale: int = 100
	var scaled_xl: int = xl * scale
	var enp: int = min(23 * scale, scaled_xl)
	var spell_extra: int = spellcasting * scale
	var invoc_extra: int = invocations * scale / 2
	var highest: int = max(spell_extra, invoc_extra)
	enp += highest + min(8 * scale, min(highest, scaled_xl)) / 2
	# DCSS multiplies by 100 (ROBUST/FRAIL baseline) then divides by 100*scale.
	# Net effect with no mutations: enp = enp / scale.
	enp = enp / scale
	enp += mp_mod
	return max(0, enp)

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
# Single amulet slot — dict from AmuletRegistry.get_info, or {} if empty.
var equipped_amulet: Dictionary = {}
# Enchant level on the currently-equipped weapon (DCSS "pluses"). Travels
# with the specific item dict in inventory; we mirror it here so combat
# doesn't have to crack open equipped_weapon each tick.
var equipped_weapon_plus: int = 0
## DCSS action energy: most actions cost 10 ticks, but heavy weapons
## charge `weapon.delay * 10` on an attack swing. Monsters read this
## via `Monster.take_turn` to accumulate the right amount of energy,
## so a greatsword (delay 1.7) gives each nearby monster 17 energy
## per swing instead of 10.
var last_action_ticks: int = 10
var skill_state: Dictionary = {}
## DCSS-style mutation slots. Keys are mutation ids (see
## assets/dcss_mutations/mutations.json); values are the current level
## (1..mutation.levels). Stat/HP/MP deltas from each mutation are
## applied at the moment `apply_mutation` bumps the level, and reversed
## on `remove_mutation`.
var mutations: Dictionary = {}

## DCSS worship state. `current_god` is "" when unaligned, else the
## GodRegistry id the player pledged to at an altar. `piety` is a
## simple 0..god.piety_cap counter that climbs on kills and drops on
## hostile conducts (spell-casting under Trog, etc.).
var current_god: String = ""
var piety: int = 0

## DCSS rune collection — each picked-up rune id is stored here.
## RuneRegistry.ZOT_GATE_REQUIREMENT (= 3) is the minimum to pass
## the Zot entrance. Also drives the "you won!" flow once the Orb
## of Zot is in inventory and the player climbs back to D:1.
var runes: Array[String] = []
## Orb of Zot flag — set when the Orb pickup fires. Triggers the
## "Orb run" end-game pace (monster spawn boost, victory on D:1↑).
var has_orb: bool = false

## Gold currency. Gained from monster drops, floor piles, and Gozag's
## potion_petition gambling. Spent at shops and on Gozag's bribes.
var gold: int = 0

## DCSS transmutation state. Empty "" when in human form; set via
## `apply_form(id)` from talismans, the transmutations spell school,
## or god-granted shifts. All effect deltas (stats, HP cap, AC,
## unarmed, resists) unwind when `clear_form` is called.
var current_form: String = ""
## Cached baseline so clear_form can restore every touched field.
var _form_baseline: Dictionary = {}
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
## Emitted when the player triggers a wand that needs a tile target.
## GameBootstrap catches this, enters targeting mode, and — on the
## player's confirm tap — calls back into _fire_wand_at to resolve
## damage / hex effects. Keeps all targeting-UI state in one place.
signal wand_target_requested(item_index: int)

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
		var fallback_id := "%s_%s" % [job_id if job_id != "" else "fighter", race_id if race_id != "" else "human"]
		preset = LPCPresetLoader.load_with_fallback(fallback_id, "fighter_human")
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
	# Reset action-cost to the racial default so this turn's action
	# starts from a clean slate. Move uses `10 + race.move_speed_mod`;
	# attack overrides with weapon delay before the swing.
	last_action_ticks = 10
	if race_res != null:
		last_action_ticks += int(race_res.move_speed_mod)
	# Acrobat: assume active until a melee/cast action clears the flag.
	if has_meta("_amulet_acrobat"):
		set_meta("_acrobat_active", true)
	# Reset the per-turn shield-block counter so the next round of
	# monster swings starts from a fresh SH — DCSS applies fatigue
	# WITHIN a turn (several attacks from one beast) but not ACROSS
	# turns.
	if has_meta("_shield_blocks_this_turn"):
		remove_meta("_shield_blocks_this_turn")
	_tick_duration_metas()


## Count down every turn-based duration the player tracks via metas, and
## undo their effects cleanly when they expire. Keeping this in one place
## means new potions just have to drop a meta in _apply_consumable_effect
## and the tick here takes care of the rest.
func _tick_duration_metas() -> void:
	# Slow / Petrifying / Exhausted share the _slow_skip alternating gate.
	# When none are active, purge any stale skip flag so the next slow
	# effect starts fresh on the "move" side of the alternation.
	if has_meta("_slow_skip") and not (has_meta("_slowed_turns") \
			or has_meta("_petrifying_turns") or has_meta("_exhausted_turns")):
		remove_meta("_slow_skip")
	_tick_simple_meta("_haste_turns")
	_tick_simple_meta("_enlightened_turns")
	_tick_simple_meta("_invisible_turns")
	_refresh_invisibility_visual()
	_tick_simple_meta("_silenced_turns")
	_refresh_silence_visual()
	_tick_simple_meta("_heroism_turns")
	_tick_simple_meta("_finesse_turns")
	## Scroll of Teleportation defers the actual teleport by N turns (DCSS parity).
	if has_meta("_pending_teleport_turns"):
		var tpt: int = int(get_meta("_pending_teleport_turns", 0)) - 1
		if tpt <= 0:
			remove_meta("_pending_teleport_turns")
			_teleport_random()
		else:
			set_meta("_pending_teleport_turns", tpt)
			CombatLog.add("You feel strangely unstable. (teleporting in %d turns)" % tpt)
	# Confusion duration: when _confusion_turns hits zero, also clear
	# the boolean `_confused` so movement / spellcasting unblock.
	if has_meta("_confusion_turns"):
		var ct: int = int(get_meta("_confusion_turns", 0)) - 1
		if ct <= 0:
			remove_meta("_confusion_turns")
			remove_meta("_confused")
			CombatLog.add("You feel less confused.")
		else:
			set_meta("_confusion_turns", ct)
	_tick_simple_meta("_exhausted_turns")
	_tick_simple_meta("_mesmerised_turns")
	# Frozen — 1-2 turn full action block after heavy cold damage.
	if has_meta("_frozen_turns"):
		var fz: int = int(get_meta("_frozen_turns", 0)) - 1
		if fz <= 0:
			remove_meta("_frozen_turns")
			CombatLog.add("You thaw out.")
		else:
			set_meta("_frozen_turns", fz)
	# Weakness — melee damage reduced 33% while active.
	if has_meta("_weak_turns"):
		var wk: int = int(get_meta("_weak_turns", 0)) - 1
		if wk <= 0:
			remove_meta("_weak_turns")
			CombatLog.add("You feel strong again.")
		else:
			set_meta("_weak_turns", wk)
	_tick_simple_meta("_sanctuary_turns")
	# Paralysis, slow, fear, charm — monster hex durations.
	if has_meta("_paralysis_turns"):
		var pv: int = int(get_meta("_paralysis_turns", 0)) - 1
		if pv <= 0:
			remove_meta("_paralysis_turns")
			CombatLog.add("You can move again.")
		else:
			set_meta("_paralysis_turns", pv)
	if has_meta("_slowed_turns"):
		var sv: int = int(get_meta("_slowed_turns", 0)) - 1
		if sv <= 0:
			remove_meta("_slowed_turns")
			if has_meta("_slow_skip"):
				remove_meta("_slow_skip")
			CombatLog.add("You feel yourself speed up.")
		else:
			set_meta("_slowed_turns", sv)
	if has_meta("_afraid_turns"):
		var av: int = int(get_meta("_afraid_turns", 0)) - 1
		if av <= 0:
			remove_meta("_afraid_turns")
			CombatLog.add("Your fear subsides.")
		else:
			set_meta("_afraid_turns", av)
	if has_meta("_charmed_turns"):
		var cv: int = int(get_meta("_charmed_turns", 0)) - 1
		if cv <= 0:
			remove_meta("_charmed_turns")
			CombatLog.add("The charm wears off.")
		else:
			set_meta("_charmed_turns", cv)
	if has_meta("_blind_turns"):
		var bv: int = int(get_meta("_blind_turns", 0)) - 1
		if bv <= 0:
			remove_meta("_blind_turns")
			_recompute_gear_stats()
			CombatLog.add("Your vision returns.")
		else:
			set_meta("_blind_turns", bv)
	if has_meta("_corona_turns"):
		var kov: int = int(get_meta("_corona_turns", 0)) - 1
		if kov <= 0:
			remove_meta("_corona_turns")
			CombatLog.add("Your corona fades.")
		else:
			set_meta("_corona_turns", kov)
	if has_meta("_dazed_turns"):
		var dv: int = int(get_meta("_dazed_turns", 0)) - 1
		if dv <= 0:
			remove_meta("_dazed_turns")
			_recompute_gear_stats()
			CombatLog.add("You feel less dazed.")
		else:
			set_meta("_dazed_turns", dv)
	_tick_simple_meta("_divine_shield_turns")
	_tick_simple_meta("_shadow_form_turns")
	_tick_simple_meta("_fiery_armour_turns")
	_tick_simple_meta("_heavenly_storm_turns")
	_tick_simple_meta("_slimify_turns")
	# Poison DoT: DCSS tracks a total poison pool that ticks down a tiny
	# amount per turn until cured. We simplify to {turns, dmg-per-turn}.
	if has_meta("_poison_turns"):
		var pt: int = int(get_meta("_poison_turns", 0))
		if pt > 0 and stats != null:
			var dmg: int = int(get_meta("_poison_dmg", 2))
			take_damage(dmg)
			if pt <= 1:
				remove_meta("_poison_turns")
				remove_meta("_poison_dmg")
				if has_meta("_poison_level"):
					remove_meta("_poison_level")
			else:
				set_meta("_poison_turns", pt - 1)
	# Petrifying → petrified. Petrifying counts down; when it expires,
	# the petrified meta engages and freezes the player for N turns.
	if has_meta("_petrifying_turns"):
		var pt2: int = int(get_meta("_petrifying_turns", 0)) - 1
		if pt2 <= 0:
			remove_meta("_petrifying_turns")
			set_meta("_petrified_turns", 5)
			CombatLog.add("You petrify!")
		else:
			set_meta("_petrifying_turns", pt2)
	_tick_simple_meta("_petrified_turns")
	# Corrosion: each stack shaves 4 AC until the counter expires.
	if has_meta("_corroded_turns"):
		var ct: int = int(get_meta("_corroded_turns", 0)) - 1
		if ct <= 0:
			var stacks: int = int(get_meta("_corrosion_stacks", 0))
			if stats != null:
				stats.AC += stacks * 4
				stats_changed.emit()
			remove_meta("_corroded_turns")
			remove_meta("_corrosion_stacks")
		else:
			set_meta("_corroded_turns", ct)
	# Death's Door: HP locked at 1, counter ticks down, lethal at 0.
	if has_meta("_deaths_door_turns"):
		var dt: int = int(get_meta("_deaths_door_turns", 0)) - 1
		if dt <= 0:
			remove_meta("_deaths_door_turns")
			CombatLog.add("Death's Door closes. Normal damage resumes.")
		else:
			set_meta("_deaths_door_turns", dt)
	# Ambrosia: confusion while the duration runs, HP/MP regen each tick.
	if has_meta("_ambrosia_turns"):
		var at: int = int(get_meta("_ambrosia_turns", 0))
		if at > 0 and stats != null:
			stats.HP = min(stats.hp_max, stats.HP + 3)
			stats.MP = min(stats.mp_max, stats.MP + 1)
			stats_changed.emit()
		at -= 1
		if at <= 0:
			remove_meta("_ambrosia_turns")
			remove_meta("_confused")
		else:
			set_meta("_ambrosia_turns", at)
	# Berserk: reverse the HP inflation on expiry, leave the player
	# exhausted for 8 turns (DCSS DUR_EXHAUSTED).
	if has_meta("_berserk_turns"):
		var bt: int = int(get_meta("_berserk_turns", 0)) - 1
		if bt <= 0:
			remove_meta("_berserk_turns")
			if stats != null and has_meta("_berserk_bonus_hp"):
				var bonus: int = int(get_meta("_berserk_bonus_hp", 0))
				stats.hp_max = max(1, stats.hp_max - bonus)
				stats.HP = min(stats.HP, stats.hp_max)
				remove_meta("_berserk_bonus_hp")
				stats_changed.emit()
			set_meta("_exhausted_turns", 8)
			CombatLog.add("Your rage subsides. You feel exhausted.")
		else:
			set_meta("_berserk_turns", bt)
	# Tree form: reverse AC and HP bonuses on expiry.
	if has_meta("_tree_turns"):
		var tt: int = int(get_meta("_tree_turns", 0)) - 1
		if tt <= 0:
			remove_meta("_tree_turns")
			if stats != null:
				var ac_b: int = int(get_meta("_tree_ac_bonus", 0))
				var hp_b: int = int(get_meta("_tree_hp_bonus", 0))
				stats.AC = max(0, stats.AC - ac_b)
				stats.hp_max = max(1, stats.hp_max - hp_b)
				stats.HP = min(stats.HP, stats.hp_max)
				remove_meta("_tree_ac_bonus")
				remove_meta("_tree_hp_bonus")
				stats_changed.emit()
			CombatLog.add("You return to your usual form.")
		else:
			set_meta("_tree_turns", tt)


## DCSS mutation: bump the level on `id`, up to its max. Applies the
## stat/HP/MP/resist effect delta immediately. Returns true on success,
## false if the mutation is already maxed or unknown.
func apply_mutation(id: String) -> bool:
	if not MutationRegistry.has(id):
		return false
	var cur: int = int(mutations.get(id, 0))
	var cap: int = MutationRegistry.levels_for(id)
	if cur >= cap:
		return false
	mutations[id] = cur + 1
	_apply_mutation_delta(id, +1)
	return true


## Remove one level of `id`. Reverses the stat delta. Returns true if a
## level was actually removed.
func remove_mutation(id: String) -> bool:
	var cur: int = int(mutations.get(id, 0))
	if cur <= 0:
		return false
	mutations[id] = cur - 1
	if mutations[id] == 0:
		mutations.erase(id)
	_apply_mutation_delta(id, -1)
	return true


## One step of mutation effect. `direction` is +1 on gain, -1 on loss.
## We only model a subset of DCSS's 200+ mutations — the ones that map
## to stats, HP/MP caps, AC, or resists. Non-modelled mutations still
## appear in the mutations dict so they show up in character dumps, but
## have no mechanical effect yet.
func _apply_mutation_delta(id: String, direction: int) -> void:
	if stats == null:
		return
	match id:
		"strong": stats.STR += 2 * direction
		"weak":   stats.STR -= 2 * direction
		"clever": stats.INT += 2 * direction
		"dopey":  stats.INT -= 2 * direction
		"agile":  stats.DEX += 2 * direction
		"clumsy": stats.DEX -= 2 * direction
		"robust":
			var bump: int = max(1, stats.hp_max / 10)
			stats.hp_max += bump * direction
			if direction > 0: stats.HP += bump
			else: stats.HP = min(stats.HP, stats.hp_max)
		"frail":
			var bump_f: int = max(1, stats.hp_max / 10)
			stats.hp_max = max(1, stats.hp_max - bump_f * direction)
			stats.HP = min(stats.HP, stats.hp_max)
		"high_magic":
			stats.mp_max += max(1, stats.mp_max / 10) * direction
			if direction > 0: stats.MP = min(stats.mp_max, stats.MP + max(1, stats.mp_max / 10))
			else: stats.MP = min(stats.MP, stats.mp_max)
		"low_magic":
			stats.mp_max = max(1, stats.mp_max - max(1, stats.mp_max / 10) * direction)
			stats.MP = min(stats.MP, stats.mp_max)
		"flat_hp":
			stats.hp_max += 4 * direction
			if direction > 0: stats.HP += 4
			else: stats.HP = min(stats.HP, stats.hp_max)
		"tough_skin", "rugged_brown_scales", "icy_blue_scales", \
				"iridescent_scales", "molten_scales", "shaggy_fur":
			stats.AC += 1 * direction
		# Resistance mutations: flags the combat system can query.
		"heat_resistance":
			set_meta("_mut_rF", int(get_meta("_mut_rF", 0)) + direction)
		"cold_resistance":
			set_meta("_mut_rC", int(get_meta("_mut_rC", 0)) + direction)
		"poison_resistance":
			set_meta("_mut_rPois", int(get_meta("_mut_rPois", 0)) + direction)
		"shock_resistance":
			set_meta("_mut_rElec", int(get_meta("_mut_rElec", 0)) + direction)
		"heat_vulnerability":
			set_meta("_mut_rF", int(get_meta("_mut_rF", 0)) - direction)
		"cold_vulnerability":
			set_meta("_mut_rC", int(get_meta("_mut_rC", 0)) - direction)
		"wild_magic":
			set_meta("_mut_wild_magic", int(get_meta("_mut_wild_magic", 0)) + direction)
		"subdued_magic":
			set_meta("_mut_subdued_magic", int(get_meta("_mut_subdued_magic", 0)) + direction)
		"anti_wizardry":
			set_meta("_mut_anti_wizardry", int(get_meta("_mut_anti_wizardry", 0)) + direction)
		# --- Additional mutation effect handlers (session 15 batch) ---
		"regeneration", "regen":
			# DCSS MUT_REGENERATION grants +20 HP regen per 3 levels
			# (additive to the DCSS base rate). We route the bonus
			# through player_regen_bonus() (read by the per-turn tick).
			set_meta("_mut_regen", int(get_meta("_mut_regen", 0)) + direction)
		"inhibited_regeneration":
			set_meta("_mut_regen", int(get_meta("_mut_regen", 0)) - direction)
		"fast_metabolism":
			# No hunger system yet; tracked for future Nemelex / worship.
			set_meta("_mut_fast_metab", int(get_meta("_mut_fast_metab", 0)) + direction)
		"slow_metabolism":
			set_meta("_mut_fast_metab", int(get_meta("_mut_fast_metab", 0)) - direction)
		"see_invisible":
			set_meta("_mut_see_invis", int(get_meta("_mut_see_invis", 0)) + direction)
		"telepathy":
			set_meta("_mut_telepathy", int(get_meta("_mut_telepathy", 0)) + direction)
		"stochastic_torment_resistance", "magic_resistance":
			# DCSS: each level adds +40 WL (one pip). _recompute_gear_stats
			# reads _mut_wl_bonus when recomputing stats.WL.
			set_meta("_mut_wl_bonus", int(get_meta("_mut_wl_bonus", 0)) + direction)
		"torment_resistance":
			# MUT_TORMENT_RESISTANCE — takes damage instead of being torment-hit.
			# Same flag pattern.
			set_meta("_mut_rN_torment", int(get_meta("_mut_rN_torment", 0)) + direction)
		"acute_vision":
			# MUT_ACUTE_VISION: +3 FOV radius.
			set_meta("_mut_fov_bonus", int(get_meta("_mut_fov_bonus", 0)) + 2 * direction)
		"blurry_vision":
			# -1 FOV radius per level.
			set_meta("_mut_fov_bonus", int(get_meta("_mut_fov_bonus", 0)) - direction)
		"deformed":
			# -30% of body-armour AC (rough approx of DCSS's handling).
			# Recompute picks it up next time.
			set_meta("_mut_deformed", int(get_meta("_mut_deformed", 0)) + direction)
		"fast":
			# MUT_FAST — +1 speed_mod (one extra move per 4 turns).
			set_meta("_mut_fast", int(get_meta("_mut_fast", 0)) + direction)
		"slow":
			set_meta("_mut_slow", int(get_meta("_mut_slow", 0)) + direction)
		"antennae":
			# MUT_ANTENNAE: see-through-walls radius small boost.
			set_meta("_mut_antennae", int(get_meta("_mut_antennae", 0)) + direction)
		"stingers", "horns", "claws", "hooves":
			# Aux-attack mutations — each level adds to _mut_aux_<kind>.
			# CombatSystem reads these when doing post-hit aux rolls.
			set_meta("_mut_aux_" + id, \
					int(get_meta("_mut_aux_" + id, 0)) + direction)
		"berserk":
			# MUT_BERSERK: chance to auto-berserk on taking damage.
			set_meta("_mut_berserkitis", int(get_meta("_mut_berserkitis", 0)) + direction)
		"deterioration":
			# -5 max HP per level.
			stats.hp_max = max(1, stats.hp_max - 5 * direction)
			stats.HP = min(stats.HP, stats.hp_max)
		"evolution":
			# Each turn tiny chance to gain/lose a mutation. Flag only.
			set_meta("_mut_evolution", int(get_meta("_mut_evolution", 0)) + direction)
		"thin_skeletal_structure":
			# +2 EV, -2 STR per level (summary — DCSS also reduces HP).
			stats.STR -= 2 * direction
		"powered_by_death":
			# +regen near corpses (flag for per-turn tick).
			set_meta("_mut_pbd", int(get_meta("_mut_pbd", 0)) + direction)
		"powered_by_pain":
			# On-damage power boost.
			set_meta("_mut_pbp", int(get_meta("_mut_pbp", 0)) + direction)
		"nightstalker":
			# +2 stealth per level, FOV -1 (night affinity).
			set_meta("_mut_night_stealth", \
					int(get_meta("_mut_night_stealth", 0)) + 2 * direction)
			set_meta("_mut_fov_bonus", \
					int(get_meta("_mut_fov_bonus", 0)) - direction)
		"herbivore":
			set_meta("_mut_herbivore", int(get_meta("_mut_herbivore", 0)) + direction)
		"carnivore":
			set_meta("_mut_carnivore", int(get_meta("_mut_carnivore", 0)) + direction)
		_:
			pass  # Non-modelled mutation — recorded but has no effect.
	stats_changed.emit()


## DCSS transmutation: adopt `form_id` (dragon / statue / blade / …).
## Captures the player's current STR/DEX/AC/HP cap/unarmed damage as a
## baseline, then applies the form's deltas. Reverse via `clear_form`.
## No-op if the form is unknown or already active.
func apply_form(form_id: String) -> bool:
	if not FormRegistry.has(form_id):
		return false
	if current_form == form_id:
		return false
	if current_form != "":
		clear_form()
	var info: Dictionary = FormRegistry.get_info(form_id)
	if stats == null:
		return false
	_form_baseline = {
		"STR": stats.STR, "DEX": stats.DEX,
		"AC": stats.AC,
		"hp_max": stats.hp_max, "HP": stats.HP,
	}
	stats.STR += int(info.get("str_delta", 0))
	stats.DEX += int(info.get("dex_delta", 0))
	stats.AC += int(info.get("ac_base", 0))
	var hp_mod: int = int(info.get("hp_mod", 100))
	if hp_mod != 100:
		var new_cap: int = max(1, int(stats.hp_max * hp_mod / 100))
		stats.hp_max = new_cap
		stats.HP = min(stats.HP * hp_mod / 100, new_cap)
	# Resist metas, for the combat system to query.
	for r in info.get("resists", {}).keys():
		set_meta("_form_r%s" % String(r), int(info["resists"][r]))
	# Feature flags.
	if bool(info.get("can_fly", false)):
		set_meta("_flying", true)
	if bool(info.get("can_swim", false)):
		set_meta("_swimming", true)
	# DCSS form-specific unarmed damage. CombatSystem.melee_attack reads
	# _form_unarmed_base when the player is weaponless so dragon fists
	# actually hit hard (base 8), tree fists are sturdy (base 9),
	# storm form is devastating (base 24), etc.
	# The DCSS formula is unarmed_base + unarmed_scaling × shapeshifting_skill / 10,
	# capped at reasonable values. We precompute and store so the combat
	# path only has to read a single meta.
	var ubase: int = int(info.get("unarmed_base", 0))
	var uscale: int = int(info.get("unarmed_scaling", 0))
	var shape_lv: int = _skill_level("shapeshifting")
	var utotal: int = ubase + (uscale * shape_lv) / 10
	if utotal > 0:
		set_meta("_form_unarmed_base", utotal)
	# DCSS form AC scaling — base + ac_scaling * shapeshifting / 10.
	# ac_base was already applied via stats.AC delta in apply_form's top
	# section; the scaling portion is folded in here now that we have
	# the skill level. Store in a form-specific meta so clear_form can
	# peel it off without rereading the registry.
	var ac_scale: int = int(info.get("ac_scaling", 0))
	if ac_scale > 0 and shape_lv > 0:
		var ac_bonus: int = (ac_scale * shape_lv) / 10
		if ac_bonus > 0:
			stats.AC += ac_bonus
			set_meta("_form_ac_bonus", ac_bonus)
	# Form movement bonus. DCSS speed 10 is baseline; 5 means the form
	# moves at 2× normal pace (bat/bat_swarm). Map to free-move bonus
	# so the player skips the turn-end when moving in fast forms.
	var mspeed: int = int(info.get("move_speed", 10))
	if mspeed < 10:
		set_meta("_form_move_bonus", 10 - mspeed)  # bat=5 → +5 free-move tokens
	# Equipment melding. DCSS locks certain slots when a form is active
	# (statue melds body/gloves/boots/barding; dragon melds "physical").
	# Record the slot list so the Status panel / item info tooltip can
	# flag equipped gear as suppressed. Mechanical effect (stat removal)
	# not yet wired — the Status display is the high-value piece.
	if info.get("melds"):
		set_meta("_form_melds", info["melds"])
	# Size override. DCSS `SIZE_MEDIUM` = 3; factor = 2*(3-size). So
	# a dragon form (giant=5) has factor -4 (much easier to hit), a
	# spider (little=1) has factor +4 (hard to hit). PlayerDefense
	# reads `_form_size_factor` before the racial fallback.
	var size_name: String = String(info.get("size", "medium"))
	var size_lookup: Dictionary = {
		"tiny": 6, "little": 4, "small": 2, "medium": 0,
		"large": -2, "big": -3, "giant": -4,
	}
	if size_lookup.has(size_name) and size_name != "medium":
		set_meta("_form_size_factor", int(size_lookup[size_name]))
	current_form = form_id
	stats_changed.emit()
	CombatLog.add("You transform into %s." % String(info.get("description",
			info.get("name", form_id))))
	return true


func clear_form() -> void:
	if current_form == "" or _form_baseline.is_empty():
		current_form = ""
		return
	var info: Dictionary = FormRegistry.get_info(current_form)
	if stats != null:
		stats.STR = int(_form_baseline.get("STR", stats.STR))
		stats.DEX = int(_form_baseline.get("DEX", stats.DEX))
		stats.AC = int(_form_baseline.get("AC", stats.AC))
		stats.hp_max = int(_form_baseline.get("hp_max", stats.hp_max))
		stats.HP = min(stats.HP, stats.hp_max)
	for r in info.get("resists", {}).keys():
		remove_meta("_form_r%s" % String(r))
	remove_meta("_flying")
	remove_meta("_swimming")
	remove_meta("_form_unarmed_base")
	remove_meta("_form_move_bonus")
	remove_meta("_form_melds")
	remove_meta("_form_size_factor")
	# _form_ac_bonus was added directly to stats.AC in apply_form; the
	# _form_baseline restore above already rolled AC back to pre-form,
	# so we just clean up the tracking meta.
	remove_meta("_form_ac_bonus")
	_form_baseline.clear()
	current_form = ""
	stats_changed.emit()
	CombatLog.add("You return to your usual form.")


## Sum the player's current resistance level for `element`, including
## mutations (`_mut_rF`…), active-form resists (`_form_rfire`…), and
## racial intrinsics (gargoyle neg-drain, vine stalker poison, …).
## Returns an int; positive = resist, negative = vulnerability.
func get_resist(element: String) -> int:
	var total: int = 0
	var rt: String = _racial_trait_id()
	match element:
		"fire":
			total += int(get_meta("_mut_rF", 0))
			total += int(get_meta("_form_rfire", 0))
			# Djinni fire-born, demonspawn — +1 rF. Mummy -1 rF.
			if rt in ["djinni_flight", "demonspawn_mutations"]:
				total += 1
			elif rt == "mummy_undead":
				total -= 1
		"cold":
			total += int(get_meta("_mut_rC", 0))
			total += int(get_meta("_form_rcold", 0))
			# Vampire / mummy / ghoul cold-immune intrinsic.
			if rt in ["vampire_bloodfeast", "mummy_undead", "ghoul_claws"]:
				total += 1
			# Djinni -1 rC (fire body, no cold protection).
			elif rt == "djinni_flight":
				total -= 1
		"elec":
			total += int(get_meta("_mut_rElec", 0))
			total += int(get_meta("_form_relec", 0))
			# Gargoyle / tengu intrinsic rElec.
			if rt in ["gargoyle_stone", "tengu_flight"]:
				total += 1
		"poison":
			total += int(get_meta("_mut_rPois", 0))
			total += int(get_meta("_form_rpoison", 0))
			# Vine stalker / mummy / kobold / naga / gargoyle / ghoul / troll.
			if rt in ["vine_stalker_poison", "mummy_undead", "kobold_sneak",
					"naga_poison_spit", "gargoyle_stone", "ghoul_claws", "trollregen"]:
				total += 1
			# Naga +2 rP total.
			if rt == "naga_poison_spit":
				total += 1
		"acid":
			total += int(get_meta("_form_racid", 0))
		"holy":
			pass  # DCSS has rHoly only via mutations; we don't model yet
		"drain", "neg":
			# Gargoyle / mummy / ghoul / deep dwarf / vine stalker drain resist.
			if rt in ["gargoyle_stone", "mummy_undead", "deep_dwarf_dr",
					"vine_stalker_mpregen"]:
				total += 1
			if rt == "ghoul_claws":
				total += 2
		"magic":
			# Willpower pips: WL / 40 rounded down (max displayed 3 for +++).
			if stats != null:
				total = mini(3, stats.WL / 40)
				return total  # skip armour ego loop — WL is self-contained
		"corr":
			total += int(get_meta("_mut_rCorr", 0))
		"mut":
			total += int(get_meta("_mut_rMut", 0))
	# DCSS SPARM_* ego resists — each equipped armour with a matching
	# ego adds 1 to the corresponding element. Resistance / willpower
	# ego grants both fire and cold by reading the ego table.
	for slot_key in equipped_armor.keys():
		var slot_dict: Dictionary = equipped_armor[slot_key]
		var ego_id: String = String(slot_dict.get("ego", ""))
		if ego_id == "":
			continue
		var res_map: Dictionary = ArmorRegistry.ego_info(ego_id).get("resists", {})
		if res_map.has(element):
			total += int(res_map[element])
	# Ring resists (ring of fire, ice, lightning, life protection, etc.).
	for ring in equipped_rings:
		if typeof(ring) != TYPE_DICTIONARY or ring.is_empty():
			continue
		var ring_res: Dictionary = ring.get("resists", {})
		if ring_res.has(element):
			total += int(ring_res[element])
	# Amulet resists.
	if not equipped_amulet.is_empty():
		var amu_res: Dictionary = equipped_amulet.get("resists", {})
		if amu_res.has(element):
			total += int(amu_res[element])
	return total


## DCSS resist_adjust_damage (fight.cc:853) — player branch.
##   resistible = amount   (100 % resistible for fire/cold/elec/pois/neg)
##   if res > 3:            return 0 (immune)
##   elif res in 1..3:      resistible /= (3*res + 1) / 2 + bonus_res
##                          bonus_res = 1 for "boolean" resists (pois, neg)
##   elif res == -1:        resistible *= 1.5
##   elif res <= -2:        resistible *= 2
## Resist levels: --- (-3) ×3, -- (-2) ×2, - (-1) ×1.5, 0 full,
## + (1) /2, ++ (2) /3, +++ (3) immune (0). Clamps at ±3.
func _apply_elem_resist(amount: int, element: String) -> int:
	var rl: int = get_resist(element)
	var final_amt: int = amount
	if rl >= 3:
		final_amt = 0  # immune at rF+++ and above
	elif rl < 0:
		# Vulnerability: -1 = ×1.5, -2 = ×2, -3 = ×3 (triple vulnerability)
		if rl == -1:
			final_amt = amount * 3 / 2
		elif rl == -2:
			final_amt = amount * 2
		else:
			final_amt = amount * 3  # rF--- and worse
	elif rl > 0:
		var bonus_res: int = 0
		if element == "poison" or element == "neg":
			bonus_res = 1  # boolean resists
		if element == "neg":
			# DCSS special: rN divides by res*2 instead of the polynomial.
			final_amt = maxi(1, amount / (rl * 2))
		else:
			var denom: int = (3 * rl + 1) / 2 + bonus_res
			final_amt = maxi(1, amount / maxi(1, denom))
	# DCSS Frozen rider: heavy cold damage that isn't fully resisted has a
	# small chance to freeze the player for a turn or two. No rC+ dodge
	# (rC already cut the damage) but rl≥3 immunity zeroed final_amt, so
	# the gate is "damage landed and was cold-flavoured".
	if element == "cold" and final_amt >= 6 and randi() % 100 < 15:
		apply_frozen(1 + randi() % 2, "the chill")
	return final_amt


## FOV radius to use when computing line-of-sight. Blind = 2 tiles.
## Acute vision mutation extends; blurry / nightstalker shrink.
func get_fov_radius() -> int:
	if has_meta("_blind_turns"):
		return 2
	var r: int = FieldOfView.LOS_DEFAULT_RANGE
	r += int(get_meta("_mut_fov_bonus", 0))
	return maxi(2, r)


## DCSS Frozen: brief full-action block after heavy cold damage.
## Duration stacks with whichever is longer rather than adding, matching
## DCSS's mon-tentacle / bolt_of_cold "prefer fresh freeze" behaviour.
func apply_frozen(turns: int = 2, source: String = "the cold") -> void:
	if turns <= 0:
		return
	var cur: int = int(get_meta("_frozen_turns", 0))
	if turns <= cur:
		return
	set_meta("_frozen_turns", turns)
	CombatLog.add("You are frozen by %s!" % source)


## DCSS Weakness: -33% melee damage for `turns` turns. Applied by a few
## monster spells and the Potion of Sickness aftermath. Longer duration
## wins on reapply (don't let old debuff block a fresh one).
func apply_weakness(turns: int = 10, source: String = "an effect") -> void:
	if turns <= 0:
		return
	var cur: int = int(get_meta("_weak_turns", 0))
	if turns <= cur:
		return
	set_meta("_weak_turns", turns)
	CombatLog.add("You feel weak (%s)." % source)


## Apply poison to the player. level 1/2/3 = increasing DoT.
## Stacks: re-poisoning at equal or higher level upgrades the DoT.
func apply_poison(level: int = 1, source: String = "something") -> void:
	if get_resist("poison") >= 1:
		CombatLog.add("You resist the poison.")
		return
	var cur_level: int = int(get_meta("_poison_level", 0))
	var new_level: int = clampi(maxi(cur_level, level), 1, 3)
	var dmg_per_turn: int = new_level * 2
	var turns: int = 5 + new_level * 2
	set_meta("_poison_level", new_level)
	set_meta("_poison_turns", turns)
	set_meta("_poison_dmg", dmg_per_turn)
	var labels: Array = ["", "lightly", "moderately", "severely"]
	CombatLog.add("You are %s poisoned by %s!" % [labels[new_level], source])


## DCSS willpower_check. Returns true if the player resists the hex.
## Formula: if randi(0..spell_hd*5) < stats.WL → resisted.
## Formicid (WL=270) is immune to all hexes.
func willpower_check(spell_hd: int) -> bool:
	if stats == null:
		return false
	if stats.WL >= 270:
		return true  # immune
	var roll: int = randi() % maxi(1, spell_hd * 5 + 30)
	return roll < stats.WL


## DCSS species MR (willpower) base values from species-data.h.
static func _race_base_wl(rid: String) -> int:
	match rid:
		"formicid":  return 270  # MR_IMMUNE
		"mummy":     return 80
		"vine_stalker": return 80
		"deep_elf":  return 80
		"vampire":   return 60
		"halfling":  return 60
		"merfolk":   return 60
		"elf":       return 60
		"octopode":  return 50
		"gargoyle":  return 40
		"ghoul":     return 40
		"naga":      return 40
		"centaur":   return 40
		"demonspawn":return 40
		"draconian": return 40
		"tengu":     return 40
		"djinni":    return 40
		"deep_dwarf":return 40
		"minotaur":  return 40
		"kobold":    return 40
		"human":     return 40
		"troll":     return 20
		"gnoll":     return 25
		_:           return 40


## Generic `_<name>_turns` meta countdown. Removes the meta at 0.
func _tick_simple_meta(key: String) -> void:
	if not has_meta(key):
		return
	var t: int = int(get_meta(key, 0)) - 1
	if t <= 0:
		remove_meta(key)
	else:
		set_meta(key, t)


## Sync the sprite alpha with `_invisible_turns`. Dim to 0.45 while active
## so the player gets the same visual cue DCSS gives with its glyph colour.
func _refresh_invisibility_visual() -> void:
	modulate.a = 0.45 if has_meta("_invisible_turns") else 1.0


## Persistent silence indicator — a faint pulsing ring beneath the player
## sprite while `_silenced_turns > 0`. Created on demand and freed when
## silence clears so there's no per-frame cost off-effect.
class _SilenceAura extends Node2D:
	var phase: float = 0.0
	func _process(delta: float) -> void:
		phase += delta
		queue_redraw()
	func _draw() -> void:
		var a: float = 0.30 + 0.18 * sin(phase * 3.0)
		var col := Color(0.55, 0.55, 0.70, a)
		draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 48, col, 2.0, true)
		var col_in := Color(0.55, 0.55, 0.70, a * 0.55)
		draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 32, col_in, 1.4, true)


var _silence_aura: _SilenceAura = null


## Show/hide the silence aura ring. Called from every path that flips
## `_silenced_turns` (scroll use, turn-tick decrement, monster-aura
## gate) so the visual tracks the meta without polling.
func _refresh_silence_visual() -> void:
	var silenced: bool = has_meta("_silenced_turns")
	if silenced and _silence_aura == null:
		_silence_aura = _SilenceAura.new()
		_silence_aura.z_index = -1
		add_child(_silence_aura)
	elif not silenced and _silence_aura != null:
		_silence_aura.queue_free()
		_silence_aura = null


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
	# DCSS stats = species.base_stat + job_bonus (+ our mobile-layer trait
	# bonus). Earlier we used a flat 8 which ignored racial stats entirely,
	# so Gargoyle EE was (8, 15, 13) instead of the DCSS-correct (11, 15, 10).
	var race_str: int = race.base_str if race != null else 8
	var race_dex: int = race.base_dex if race != null else 8
	var race_int: int = race.base_int if race != null else 8
	var base_str: int = race_str + (job.str_bonus if job else 0) + trait_str
	var base_dex: int = race_dex + (job.dex_bonus if job else 0) + trait_dex
	var base_int: int = race_int + (job.int_bonus if job else 0) + trait_int
	s.STR = base_str
	s.DEX = base_dex
	s.INT = base_int
	var hp_pct: float = 1.0 + (p_trait.hp_bonus_pct if p_trait else 0.0)
	var mp_pct: float = 1.0 + (p_trait.mp_bonus_pct if p_trait else 0.0)
	# DCSS formula (player.cc get_real_hp/get_real_mp). Starting skills are
	# read straight from the JobData because SkillSystem isn't installed on
	# this Player until GameBootstrap does so right after setup() returns.
	var fighting_sk: int = 0
	var spellcast_sk: int = 0
	if job != null:
		fighting_sk = int(job.starting_skills.get("fighting", 0))
		spellcast_sk = int(job.starting_skills.get("spellcasting", 0))
	var hp_mod: int = race.hp_mod if race != null else 0
	var mp_mod: int = race.mp_mod if race != null else 0
	var hp_total: int = int(_dcss_max_hp(level, fighting_sk, hp_mod) * hp_pct)
	var mp_total: int = int(_dcss_max_mp(level, spellcast_sk, 0, mp_mod) * mp_pct)
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
	# DCSS species MR (willpower) base. Formicid = immune (270), Mummy = high.
	s.WL = _race_base_wl(race_id)
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
	# boots (or more) and they all stack. Consumables / wands fall into
	# the inventory with their DCSS kind so the Bag + quickslots see them.
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
			elif WandRegistry.has(sid):
				var winfo: Dictionary = WandRegistry.get_info(sid)
				items.append({
					"id": sid,
					"name": String(winfo.get("name", sid)),
					"kind": "wand",
					"color": winfo.get("color", Color(0.75, 0.75, 0.85)),
					"charges": WandRegistry.roll_charges(sid),
				})
				_try_assign_quickslot(sid, "wand")
			elif ConsumableRegistry.has(sid):
				var cinfo: Dictionary = ConsumableRegistry.get_info(sid)
				var ckind: String = String(cinfo.get("kind", "potion"))
				items.append({
					"id": sid,
					"name": String(cinfo.get("name", sid)),
					"kind": ckind,
					"color": cinfo.get("color", Color(0.75, 0.75, 0.85)),
				})
				_try_assign_quickslot(sid, ckind)
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

	# Caster backgrounds — pre-identify the starting potion of magic and
	# basic scrolls so first-turn play isn't gated by unknown-item testing.
	if job != null and job.starting_equipment.has("potion_magic"):
		GameManager.identify("potion_magic")
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
		"heavy_armor": return {"weapon": "long_sword", "armor": ["plate_armour", "helmet"]}
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


func equip_weapon(weapon_id: String, plus: int = 0, brand: String = "") -> String:
	if equipped_weapon_cursed and equipped_weapon_id != "":
		CombatLog.add("The %s is cursed and won't come off!" % WeaponRegistry.display_name_for(equipped_weapon_id))
		return equipped_weapon_id
	var prev: String = equipped_weapon_id
	equipped_weapon_id = weapon_id
	equipped_weapon_plus = plus
	equipped_weapon_cursed = false
	# Unrandart / scroll-of-brand weapons carry a brand meta the combat
	# system reads on every swing. Setting it here so the brand follows
	# the weapon across unequip/re-equip cycles (the meta is keyed by
	# weapon id, not slot).
	if brand != "" and weapon_id != "":
		set_meta("_weapon_brand_" + weapon_id, brand)
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
	# DCSS SPARM_MAYHEM (cloak of mayhem). On a killing blow, nearby
	# hostiles panic — fear them for 3 turns via `_flee_turns` so the
	# existing MonsterAI fear path drives the retreat. Radius 3 matches
	# the DCSS aura.
	if has_meta("_ego_mayhem"):
		for m in get_tree().get_nodes_in_group("monsters"):
			if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
				continue
			var d: int = maxi(abs(m.grid_pos.x - grid_pos.x),
					abs(m.grid_pos.y - grid_pos.y))
			if d == 0 or d > 3:
				continue
			if not m.has_meta("_flee_turns"):
				m.set_meta("_flee_turns", 3)


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
	# DCSS auto-identify: wearing an ego armour reveals the ego class for
	# the rest of the run, so subsequent drops of the same ego read true.
	var ego: String = String(armor.get("ego", ""))
	if ego != "" and GameManager != null:
		GameManager.identify_armor_ego(ego)
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
	# DCSS item-use.cc: putting on a ring identifies its base type (the
	# stat-ring flavour reveals when equipped). Randarts are opaque until
	# scrolls of identify hit them (their rolled props stay hidden).
	var r_id: String = String(ring.get("id", ""))
	if r_id != "" and not r_id.begins_with("randart_") \
			and not r_id.begins_with("unrand_") and GameManager != null:
		GameManager.identify(r_id)
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


## Equip an amulet. Returns the displaced amulet dict (or empty if slot was
## vacant) so the caller can place it back in inventory.
func equip_amulet(amulet: Dictionary) -> Dictionary:
	var prev: Dictionary = equipped_amulet.duplicate()
	equipped_amulet = amulet
	var a_id: String = String(amulet.get("id", ""))
	if a_id != "" and not a_id.begins_with("randart_") \
			and not a_id.begins_with("unrand_") and GameManager != null:
		GameManager.identify(a_id)
	_recompute_gear_stats()
	return prev


## Remove the equipped amulet. Returns the removed dict (empty if none).
func unequip_amulet() -> Dictionary:
	var prev: Dictionary = equipped_amulet.duplicate()
	equipped_amulet = {}
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
	# Clear stale ego metas so swapping an ego off actually removes
	# its effect. Each ego re-sets its meta below if still equipped.
	for ego_flag in ["harm", "slow", "see_invis", "hate_light", "shed_light",
			"mp_for_damage", "foes_fail_spells", "rampage", "missile_dodge",
			"reflect", "spirit_shield", "flying", "jump", "mayhem", "command"]:
		if has_meta("_ego_" + ego_flag):
			remove_meta("_ego_" + ego_flag)
	for amulet_flag in ["piety_boost", "acrobat", "reflect", "stasis",
			"spirit_shield", "gourmand"]:
		if has_meta("_amulet_" + amulet_flag):
			remove_meta("_amulet_" + amulet_flag)
	for ring_flag in ["see_invis", "flying"]:
		if has_meta("_ring_" + ring_flag):
			remove_meta("_ring_" + ring_flag)
	var base_ev: int = base_stats.EV
	# AC starts at racial intrinsic (gargoyle stone, etc) + trait AC bonus.
	var ac: int = 0
	if race_res != null:
		ac += race_res.base_ac
	if trait_res != null:
		ac += trait_res.ac_bonus
	var ev: int = base_ev
	# Sum up body armour EV-penalty (negative PARM_EVASION). DCSS reduces
	# EV by evp/10 from body armour only (other slots don't apply).
	var body_evp_raw: int = 0
	# Apply armor bonuses (base AC + enchant "plus") and DCSS SPARM_*
	# egos. Each equipped armour may carry an "ego" string resolved
	# against ArmorRegistry.EGOS; its stat_bonus / resists / flag
	# contributions fold into the player here.
	# DCSS player.cc _armour_plus_to_ac: body armour's base AC gets
	# multiplied by armour_skill / 10, so heavy plate scales massively
	# with investment (skill 10 ≈ +100% base AC). We track it outside
	# the slot loop so aux slots (helmet/gloves) keep their flat AC.
	var armour_skill_lv: int = _skill_level("armour")
	# DCSS player::shield_class. Shield slot gives a block score SH:
	#   sh = shield_base_ac * 2 + plus * 2
	#      + (shields_skill * (shield_base_ac * 2 + 13)) / 10
	# Buckler/kite/tower base AC is 3/8/13 so tower+skill20 ≈ SH 104.
	# Reset each recompute; re-set below if a shield is equipped.
	stats.SH = 0
	var shields_skill_lv: int = _skill_level("shields")
	for slot_key in equipped_armor.keys():
		var slot_dict: Dictionary = equipped_armor[slot_key]
		ac += int(slot_dict.get("ac", 0))
		ac += int(slot_dict.get("plus", 0))
		ev += int(slot_dict.get("ev_bonus", 0))
		if slot_key == "chest":
			body_evp_raw = int(slot_dict.get("ev_penalty", 0))
			# Armour-skill AC bonus applies ONLY to body armour base AC
			# in DCSS (helmet/gloves/boots don't benefit from Armour).
			var body_base_ac: int = int(slot_dict.get("ac", 0))
			if body_base_ac > 0 and armour_skill_lv > 0:
				ac += body_base_ac * armour_skill_lv / 10
		elif slot_key == "shield":
			var shield_base: int = int(slot_dict.get("ac", 0))
			if shield_base > 0:
				var shield_plus: int = int(slot_dict.get("plus", 0))
				var sh: int = shield_base * 2 + shield_plus * 2
				sh += shields_skill_lv * (shield_base * 2 + 13) / 10
				stats.SH = sh
		var ego_id: String = String(slot_dict.get("ego", ""))
		if ego_id != "":
			var ego: Dictionary = ArmorRegistry.ego_info(ego_id)
			var sb: Dictionary = ego.get("stat_bonus", {})
			stats.STR += int(sb.get("str", 0))
			stats.DEX += int(sb.get("dex", 0))
			stats.INT += int(sb.get("int", 0))
			ac += int(sb.get("ac", 0))
			ev += int(sb.get("ev", 0))
			# Flags written as player metas so other systems (take_damage,
			# try_move, cast pipeline) can check them without pulling the
			# ArmorRegistry directly.
			var flag_s: String = String(ego.get("flag", ""))
			if flag_s != "":
				set_meta("_ego_" + flag_s, true)
				# SPARM_FLYING (boots of flying) plumbs into the same
				# `_flying` meta that forms / djinni use, so the terrain
				# + ranged paths only check one flag.
				if flag_s == "flying":
					set_meta("_flying", true)
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
		# Flags: set player meta so other systems can check without re-reading ring dict.
		for flag_s in ring.get("flags", []):
			set_meta("_ring_" + String(flag_s), true)
	# Apply amulet bonuses (single slot).
	if not equipped_amulet.is_empty():
		var sb: Dictionary = equipped_amulet.get("stat_bonus", {})
		stats.STR    += int(sb.get("str", 0))
		stats.DEX    += int(sb.get("dex", 0))
		stats.INT    += int(sb.get("int_", 0))
		ac           += int(sb.get("ac", 0))
		ev           += int(sb.get("ev", 0))
		stats.mp_max += int(sb.get("mp_max", 0))
		var flag_s: String = String(equipped_amulet.get("flag", ""))
		if flag_s != "":
			set_meta("_amulet_" + flag_s, true)
	# DCSS player_evasion (player.cc:2167). The old ad-hoc formula was
	# replaced with the faithful PlayerDefense port: it now accounts for
	# size factor, armour-STR reduction, shield penalty, aux slots, form
	# bonus, ring/mutation EV, and transient petrify/caught halving.
	stats.AC = ac
	var skill_sys: Node = null
	if is_inside_tree():
		skill_sys = get_tree().root.get_node_or_null("Game/SkillSystem")
	var dcss_ev_total: int = PlayerDefense.player_evasion(self, skill_sys)
	# `ev` at this point is the sum of legacy slot-bonus + ring-EV reads
	# above; PlayerDefense now owns both of those so drop the double-count.
	stats.EV = maxi(0, dcss_ev_total)
	# Blind: -5 EV (can't dodge what you can't see). Daze: -2 EV.
	if has_meta("_blind_turns"):
		stats.EV = maxi(0, stats.EV - 5)
	if has_meta("_dazed_turns"):
		stats.EV = maxi(0, stats.EV - 2)
	# Clamp MP if cap dropped below current reading.
	if stats.MP > stats.mp_max:
		stats.MP = stats.mp_max
	# Recompute WL: base from race + XL scaling (DCSS: ~XL*3 for humans).
	# Willpower ego on armour adds +40 per piece. Formicid stays immune.
	var wl_base: int = _race_base_wl(race_id)
	if wl_base < 270:
		stats.WL = wl_base + level * 3
		for slot_key in equipped_armor.keys():
			var slot_dict: Dictionary = equipped_armor[slot_key]
			var ego_id: String = String(slot_dict.get("ego", ""))
			if ego_id == "willpower":
				stats.WL += 40
	else:
		stats.WL = 270  # formicid immune
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
	# Unarmed swings train "unarmed_combat" — the DCSS SK_UNARMED_COMBAT
	# skill, which scales fist damage and drops mindelay like any other
	# weapon skill.
	if equipped_weapon_id == "":
		return "unarmed_combat"
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
	# Petrified or paralysed: no movement or attacks.
	if has_meta("_petrified_turns"):
		CombatLog.add("You cannot move — you are stone.")
		return false
	if has_meta("_paralysis_turns"):
		CombatLog.add("You cannot move — you are paralysed!")
		return false
	# Frozen: brief full-action block (cold-attack after-effect).
	if has_meta("_frozen_turns"):
		CombatLog.add("You are frozen stiff and can't move.")
		return false
	# Slow / Petrifying / Exhausted all reduce speed to 50% via the same
	# alternating-skip gate so they stack sensibly (two of them active =
	# still just half speed, not quarter; matches DCSS which caps slow).
	if has_meta("_slowed_turns") or has_meta("_petrifying_turns") \
			or has_meta("_exhausted_turns"):
		if has_meta("_slow_skip"):
			remove_meta("_slow_skip")
			var msg: String = "You slowly struggle to move..."
			if has_meta("_petrifying_turns"):
				msg = "You lurch — petrification creeps in..."
			elif has_meta("_exhausted_turns"):
				msg = "You stagger — exhaustion drags at you..."
			CombatLog.add(msg)
			TurnManager.end_player_turn()
			return false
		else:
			set_meta("_slow_skip", true)
	# DCSS confusion: each move has ~50% chance to stagger into a
	# random cardinal direction instead. Doesn't stop the action.
	if has_meta("_confused") and bool(get_meta("_confused", false)):
		if randf() < 0.5:
			var dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
					Vector2i(1,1), Vector2i(-1,-1), Vector2i(1,-1), Vector2i(-1,1)]
			delta = dirs[randi() % dirs.size()]
			CombatLog.add("You stagger confusedly!")
	# Daze: lighter confusion — 33% direction scatter.
	elif has_meta("_dazed_turns"):
		if randf() < 0.33:
			var dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
			delta = dirs[randi() % dirs.size()]
			CombatLog.add("You stumble dazedly!")
	# Mesmerised: can't walk away from the caster (simplification —
	# DCSS checks direction; we just block movement outright for
	# `_mesmerised_turns`).
	if has_meta("_mesmerised_turns") \
			and _monster_at(grid_pos + delta) == null:
		CombatLog.add("You are transfixed.")
		return false
	# Fear: cannot step toward any visible monster.
	if has_meta("_afraid_turns"):
		var target_cell: Vector2i = grid_pos + delta
		var too_close: bool = false
		for m in get_tree().get_nodes_in_group("monsters"):
			if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
				continue
			var md: int = maxi(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y))
			var new_md: int = maxi(abs(m.grid_pos.x - target_cell.x), abs(m.grid_pos.y - target_cell.y))
			if new_md < md:
				too_close = true
				break
		if too_close:
			CombatLog.add("You are too afraid to move closer!")
			return false
	# Tree form (potion of lignification) — root in place; you can still
	# swing at adjacent monsters, but you can't walk.
	if has_meta("_tree_turns"):
		var tile_here: int = generator.get_tile(grid_pos + delta)
		var monster_adj: bool = _monster_at(grid_pos + delta) != null
		if not monster_adj:
			CombatLog.add("You are rooted to the spot.")
			return false
	var target: Vector2i = grid_pos + delta
	# Check monster occupancy → attack instead.
	var monster: Node = _monster_at(target)
	if monster != null:
		try_attack_at(target)
		return false
	# Closed door: open it (costs a turn) but don't move onto it this step.
	if generator.get_tile(target) == DungeonGenerator.TileType.DOOR_CLOSED:
		generator.open_door(target)
		CombatLog.add("You open the door.")
		moved.emit(grid_pos)
		TurnManager.end_player_turn()
		return true
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
	# DCSS shout.cc idea: heavy body armour broadcasts footsteps. We
	# skip the cast-noise path and emit a small direct pulse whose
	# loudness is proportional to unadjusted body armour penalty
	# (plate = 5-ish, robe = 0). Stealth skill trims it as usual.
	var evp_raw: int = 0
	if equipped_armor.has("chest"):
		evp_raw = absi(int(equipped_armor["chest"].get("ev_penalty", 0))) / 10
	if evp_raw > 0:
		MonsterAI.broadcast_noise(get_tree(), grid_pos, evp_raw + 2,
				_skill_level("stealth"))
	var should_end_turn: bool = true
	var speed_mod: int = 0
	if trait_res != null and trait_res.special == "swift":
		speed_mod = 3
	elif race_res != null and race_res.move_speed_mod > 0:
		speed_mod = race_res.move_speed_mod
	# Forms override the race bonus when they're faster — a swift-trait
	# human in bat form still moves at bat pace, not swift pace.
	if has_meta("_form_move_bonus"):
		speed_mod = maxi(speed_mod, int(get_meta("_form_move_bonus", 0)))
	# DCSS SPARM_RAMPAGING: stepping toward a visible hostile covers two
	# tiles in one action, so we grant +1 speed_mod exactly on those
	# moves (stacks with swift / bat-form in the max() above). Requires
	# a visible foe in the move direction so random wander doesn't
	# rampage.
	if has_meta("_ego_rampage") and _move_is_toward_hostile(delta):
		speed_mod = maxi(speed_mod, 1)
	# MUT_FAST / MUT_SLOW: each level shifts one tick of speed.
	var mut_fast: int = int(get_meta("_mut_fast", 0))
	var mut_slow: int = int(get_meta("_mut_slow", 0))
	if mut_fast > 0:
		speed_mod = maxi(speed_mod, mut_fast)
	elif mut_slow > 0:
		# Slow mutation: occasional skip via the _slow_skip gate already
		# used by the slow/petrifying paths.
		if has_meta("_slow_skip"):
			remove_meta("_slow_skip")
			CombatLog.add("Your slow mutation drags at you...")
			TurnManager.end_player_turn()
			return false
		else:
			set_meta("_slow_skip", true)
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
			# Gold piles go straight into the currency counter instead
			# of the inventory. `extra.gold` carries the amount.
			if it.kind == "gold":
				var amount: int = int(it.extra.get("gold", 0))
				if amount > 0:
					gold += amount
					CombatLog.add("Picked up %d gold." % amount)
				it.queue_free()
				continue
			# Rune pickup: add to rune collection rather than inventory.
			# Dramatic log line matches DCSS's "You pick up the foo rune of Zot!"
			if it.kind == "rune":
				var rid: String = String(it.extra.get("rune_id", it.item_id))
				if rid != "" and not runes.has(rid):
					runes.append(rid)
				CombatLog.add("You pick up the %s!" % it.display_name)
				CombatLog.add("[%d rune%s collected]" % \
						[runes.size(), "s" if runes.size() != 1 else ""])
				it.queue_free()
				continue
			# Orb of Zot: sets the has_orb flag and triggers the Orb run.
			# Doesn't go into regular inventory; monster aggression and
			# the "reach D:1 up-stairs" victory condition read has_orb.
			if it.kind == "orb":
				has_orb = true
				CombatLog.add("You pick up the Orb of Zot!")
				CombatLog.add("The dungeon convulses — monsters rush you!")
				CombatLog.add("Flee to the surface with the Orb to win!")
				it.queue_free()
				continue
			items.append(it.as_dict())
			var pickup_ego: String = String(it.extra.get("ego", "")) if it.extra is Dictionary else ""
			var shown: String = GameManager.display_name_for_item(
					it.item_id, it.display_name, it.kind, pickup_ego) if GameManager != null else it.display_name
			CombatLog.add("Picked up: %s" % shown)
			it.queue_free()
	inventory_changed.emit()


## Fill the first empty quickslot with this consumable id, unless it's
## already quickslotted. Weapons/armor/junk don't go into quickslots.
func _try_assign_quickslot(id: String, kind: String) -> void:
	if kind != "potion" and kind != "scroll" and kind != "book" and kind != "wand":
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
	# Wands evoke rather than consume: fire their spell at the nearest
	# visible hostile, spend one charge, destroy the wand when the last
	# charge is used. DCSS evoke.cc:zap_wand behaviour in miniature.
	if String(it.get("kind", "")) == "wand" or WandRegistry.has(item_id):
		var fired: bool = _evoke_wand(index)
		if fired:
			TurnManager.end_player_turn()
		return
	# Talismans: toggle a form. Item id is "talisman_<form>" (e.g.
	# "talisman_dragon"); a second use clears the form and frees the
	# player back to human shape. Talismans aren't consumed.
	if String(it.get("kind", "")) == "talisman":
		var form_id: String = String(it.get("form", item_id.replace("talisman_", "")))
		if current_form == form_id:
			clear_form()
		else:
			apply_form(form_id)
		TurnManager.end_player_turn()
		return
	# Misc evocable (horn / box / phial / phantom mirror …). Charges
	# attach to the item dict via `extra.charges` at floor-gen time;
	# _evoke_misc decrements and runs the effect.
	if String(it.get("kind", "")) == "evocable":
		if _evoke_misc(index):
			TurnManager.end_player_turn()
		return
	# Rings: equip into the next free slot (or swap slot 0 if full).
	# The displaced ring, if any, goes back into the inventory in place of
	# the one just worn.
	if String(it.get("kind", "")) == "ring" or RingRegistry.is_ring(item_id):
		var ring_info: Dictionary = it.duplicate()
		if not ring_info.has("slot"):
			ring_info = RingRegistry.get_info(item_id)
		var displaced: Dictionary = equip_ring(ring_info)
		items.remove_at(index)
		if not displaced.is_empty():
			items.insert(index, displaced)
		CombatLog.add("You put on the %s." % String(ring_info.get("name", item_id)))
		inventory_changed.emit()
		TurnManager.end_player_turn()
		return
	# Amulets: equip into the single amulet slot.
	if String(it.get("kind", "")) == "amulet" or AmuletRegistry.is_amulet(item_id):
		var amu_info: Dictionary = it.duplicate()
		if not amu_info.has("flag") and not amu_info.has("stat_bonus"):
			amu_info = AmuletRegistry.get_info(item_id)
		var displaced: Dictionary = equip_amulet(amu_info)
		items.remove_at(index)
		if not displaced.is_empty():
			items.insert(index, displaced)
		CombatLog.add("You put on the %s." % String(amu_info.get("name", item_id)))
		inventory_changed.emit()
		TurnManager.end_player_turn()
		return
	var info: Dictionary = ConsumableRegistry.get_info(item_id)
	# Log "You drink/read..." BEFORE the effect so the cause appears first.
	# Use the display name (pseudonym if unidentified, real name if identified).
	var item_kind: String = String(info.get("kind", it.get("kind", "")))
	var display_n: String = String(it.get("name", item_id))
	if GameManager != null:
		display_n = GameManager.display_name_for_item(item_id, display_n, item_kind)
	match item_kind:
		"potion":
			CombatLog.add("You drink the %s." % display_n)
		"scroll":
			CombatLog.add("You read the %s." % display_n)
	var consumed: bool = false
	if info.is_empty():
		# Unknown id — fall back to legacy kind heuristic.
		match item_kind:
			"potion":
				if stats != null:
					stats.HP = min(stats.hp_max, stats.HP + 20)
					stats_changed.emit()
				consumed = true
			"scroll":
				consumed = true
			_:
				consumed = true
	else:
		consumed = _apply_consumable_effect(info)
	if consumed:
		# Auto-identify on use; re-fetch the real name for the reveal message.
		if GameManager != null:
			var was_known: bool = GameManager.identified.has(item_id)
			GameManager.identify(item_id)
			if not was_known and (item_kind == "potion" or item_kind == "scroll"):
				var real_name: String = String(info.get("name", display_n))
				CombatLog.add("(%s was the %s)" % [display_n, real_name])
		items.remove_at(index)
		inventory_changed.emit()
		# Using an item costs a turn.
		TurnManager.end_player_turn()


## Evoke the wand at `items[index]` — fires its spell at the nearest
## visible hostile, spends one charge, destroys the wand at 0. Power
## comes from Evocations skill (DCSS: `evo_skill * 7.5 + 15` — we reuse
## SpellRegistry.roll_damage at an evocation-scaled power so direct zap
## wands hit as hard as they do in DCSS). Returns true on a successful
## evocation (a turn was spent), false if there was no target or the
## wand was empty.
func _evoke_wand(index: int) -> bool:
	var it: Dictionary = items[index]
	var wand_id: String = String(it.get("id", ""))
	var info: Dictionary = WandRegistry.get_info(wand_id)
	if info.is_empty():
		CombatLog.add("You don't know how to evoke this.")
		return false
	var charges: int = int(it.get("charges", 0))
	if charges <= 0:
		CombatLog.add("The %s is out of charges." % String(info.get("name", wand_id)))
		return false
	# Evocations skill → effective spell power. DCSS uses a flat
	# `skill*7.5 + 15` for wands; mirror that and apply the spell's cap.
	var evo: int = 0
	if skill_state.has("evocations") and skill_state["evocations"] is Dictionary:
		evo = int(skill_state["evocations"].get("level", 0))
	var power: int = int(15 + evo * 7)
	var spell_id: String = String(info.get("spell", ""))
	# Find a target — MVP uses the nearest visible hostile. Targeting UI
	# comes later; digging wands self-target (no effect for now).
	# All wands (including utility_dig) route through GameBootstrap's
	# 2-tap targeting flow. GameBootstrap will call fire_wand_at once
	# the player confirms a tile; charges and identification happen in
	# that callback so a cancelled target spends nothing. Dig wands
	# interpret the target as a direction hint rather than a creature.
	wand_target_requested.emit(index)
	return true


## Resolve a wand's effect at the chosen tile. Called back by
## GameBootstrap after the 2-tap target flow commits. Returns true on a
## successful fire so the caller can end the player's turn.
func fire_wand_at(index: int, target: Node) -> bool:
	if index < 0 or index >= items.size():
		return false
	var it: Dictionary = items[index]
	var wand_id: String = String(it.get("id", ""))
	var info: Dictionary = WandRegistry.get_info(wand_id)
	if info.is_empty():
		return false
	var charges: int = int(it.get("charges", 0))
	if charges <= 0:
		CombatLog.add("The %s is out of charges." % String(info.get("name", wand_id)))
		return false
	var evo: int = 0
	if skill_state.has("evocations") and skill_state["evocations"] is Dictionary:
		evo = int(skill_state["evocations"].get("level", 0))
	var power: int = int(15 + evo * 7)
	var spell_id: String = String(info.get("spell", ""))
	var kind: String = String(info.get("kind", "direct"))
	if target == null:
		CombatLog.add("No target.")
		return false
	if kind == "direct":
		var dmg: int = SpellRegistry.roll_damage(spell_id, power)
		if dmg < 0:
			dmg = randi_range(3, 8) + power / 4
		target.take_damage(dmg)
		CombatLog.add("%s hits the %s for %d!" % [String(info.get("name", wand_id)),
				target.data.display_name if target.data else "target", dmg])
	else:
		_apply_wand_hex(kind, target, power, info)
	_spend_wand_charge(index, wand_id)
	if GameManager != null:
		GameManager.identify(wand_id)
	return true


## Evoke a misc item — same charges-decrement + destroy-on-0 pattern as
## wands, but the effect is looked up on the ConsumableRegistry entry.
## Most effects delegate to GameBootstrap helpers so the summon/AoE
## plumbing stays in one place.
func _evoke_misc(index: int) -> bool:
	var it: Dictionary = items[index]
	var info: Dictionary = ConsumableRegistry.get_info(String(it.get("id", "")))
	if info.is_empty():
		return false
	var charges: int = int(it.get("charges", 0))
	if charges <= 0:
		CombatLog.add("The %s is depleted." % String(info.get("name", "item")))
		return false
	var effect: String = String(info.get("effect", ""))
	var gb: Node = get_tree().root.get_node_or_null("Game")
	if gb == null:
		return false
	match effect:
		"evoke_horn_geryon":
			for i in 3:
				gb._summon_ally("hell_hound", 25, "")
			CombatLog.add("The horn wails! Hell-hounds answer.")
		"evoke_box_beasts":
			var pool: Array = ["hound", "war_dog", "quokka", "polar_bear"]
			gb._summon_ally(String(pool[randi() % pool.size()]), 30, "A beast springs from the box!")
		"evoke_phial_floods":
			gb._aoe_damage_visible(10, 10, 22, "A torrent of water crashes down!")
		"evoke_sack_spiders":
			for i in 3:
				gb._summon_ally("spider", 25, "")
			CombatLog.add("Spiders scatter from the sack!")
		"evoke_phantom_mirror":
			var mirror_t: Node = _nearest_visible_hostile()
			if mirror_t != null and mirror_t.data != null:
				gb._summon_ally(String(mirror_t.data.id), 20,
						"A phantom %s steps forth!" % String(mirror_t.data.display_name))
		"evoke_condenser_vane":
			gb._aoe_damage_visible(8, 8, 18, "Freezing fog boils out of the vane!")
		"evoke_tremorstones":
			gb._aoe_damage_visible(6, 12, 25, "The ground quakes violently!")
		"evoke_lightning_rod":
			gb._damage_nearest_visible(18, 36, "Lightning arcs from the rod into %s!")
		"evoke_gravitambourine":
			# Pull every visible foe one tile toward the player + small dmg.
			gb._aoe_damage_visible(8, 3, 8, "The tambourine drags the world toward you!")
			if player_has_method("_pull_nearest"): pass  # future enhancement
		_:
			CombatLog.add("Nothing happens.")
			return false
	charges -= 1
	it["charges"] = charges
	items[index] = it
	if charges <= 0:
		CombatLog.add("The %s shatters, spent." % String(info.get("name", "item")))
		items.remove_at(index)
	inventory_changed.emit()
	if GameManager != null:
		GameManager.identify(String(info.get("id", "")))
	return true


func player_has_method(method: String) -> bool:
	return has_method(method)


func _spend_wand_charge(index: int, wand_id: String) -> void:
	if index < 0 or index >= items.size():
		return
	var it: Dictionary = items[index]
	var charges: int = int(it.get("charges", 0)) - 1
	it["charges"] = charges
	items[index] = it
	if charges <= 0:
		CombatLog.add("The wand crumbles to dust.")
		items.remove_at(index)
	inventory_changed.emit()


## Apply a DCSS-shaped hex effect from a wand (paralyse / charm / poly /
## roots). Duration/strength scales with power per DCSS norms.
func _apply_wand_hex(kind: String, target: Node, power: int, info: Dictionary) -> void:
	var tname: String = target.data.display_name if ("data" in target and target.data) else "target"
	match kind:
		"hex_paralyse":
			var turns: int = 2 + int(power / 30)
			if target.has_method("set_meta"):
				target.set_meta("_paralysis_turns", turns)
			CombatLog.add("%s is paralysed! (%d turns)" % [tname, turns])
		"hex_root":
			var turns2: int = 3 + int(power / 30)
			if target.has_method("set_meta"):
				target.set_meta("_rooted_turns", turns2)
			CombatLog.add("Roots entangle the %s! (%d turns)" % [tname, turns2])
		"hex_charm":
			# Simple fear proxy (we don't have friendly-monster support yet).
			if target.has_method("set_meta"):
				target.set_meta("_flee_turns", 5)
			CombatLog.add("The %s falters, confused." % tname)
		"hex_poly":
			# DCSS polymorph: replace the monster with a different one of
			# similar HD. Pool is every MonsterRegistry entry whose HD is
			# within ±2 of the current target; we keep the grid_pos but
			# swap data + rename. If no candidate fits, the target just
			# "writhes" — matches the DCSS fallback for no-valid-poly.
			_polymorph_monster(target)
		_:
			CombatLog.add("The %s writhes briefly." % tname)


## DCSS polymorph — swap the monster's data for a random MonsterRegistry
## entry whose HD sits within ±2 of the current target. The target's hp
## is re-rolled from the new template's max. Logs the transformation so
## the player sees the change. No-op when no eligible replacement.
func _polymorph_monster(target: Node) -> void:
	if target == null or not ("data" in target) or target.data == null:
		return
	var old_name: String = String(target.data.display_name)
	var old_id: String = String(target.data.id)
	var old_hd: int = int(target.data.hd)
	var eligible: Array[String] = []
	for mid in MonsterRegistry.all_ids():
		if mid == old_id:
			continue
		var cand: MonsterData = MonsterRegistry.fetch(mid)
		if cand == null:
			continue
		var diff: int = abs(int(cand.hd) - old_hd)
		if diff > 2:
			continue
		# Never polymorph into a boss / unique / non-hostile placeholder.
		if cand.flags != null:
			var skip: bool = false
			for f in cand.flags:
				var lf: String = String(f).to_lower()
				if lf == "unique" or lf == "no_poly" or lf == "friendly":
					skip = true
					break
			if skip:
				continue
		eligible.append(mid)
	if eligible.is_empty():
		CombatLog.add("The %s shimmers, resisting the change." % old_name)
		return
	var picked: String = eligible[randi() % eligible.size()]
	var new_data: MonsterData = MonsterRegistry.fetch(picked)
	if new_data == null:
		return
	target.data = new_data
	if "hp" in target and int(new_data.hp) > 0:
		target.hp = int(new_data.hp)
	if target.has_method("queue_redraw"):
		target.queue_redraw()
	CombatLog.add("The %s writhes and becomes %s!" % [
			old_name, String(new_data.display_name)])


## Return up to `count` walkable, unoccupied 8-neighbour tiles around the
## player. Used by scroll-of-summoning and scroll-of-butterflies to place
## friendly summons next to the caster.
func _adjacent_free_tiles(count: int) -> Array:
	var out: Array = []
	if generator == null:
		return out
	var candidates: Array = []
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			candidates.append(grid_pos + Vector2i(dx, dy))
	candidates.shuffle()
	for p in candidates:
		if out.size() >= count:
			break
		if not generator.is_walkable(p):
			continue
		if _tile_has_actor(p):
			continue
		out.append(p)
	return out


func _tile_has_actor(p: Vector2i) -> bool:
	if p == grid_pos:
		return true
	for m in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(m) and "grid_pos" in m and m.grid_pos == p:
			return true
	for c in get_tree().get_nodes_in_group("companions"):
		if is_instance_valid(c) and "grid_pos" in c and c.grid_pos == p:
			return true
	return false


## Spawn a short-lived friendly monster at `tile`. Used by
## scroll_summoning / scroll_butterflies / (later) summon spells. Uses
## the Companion scene so the tile-existing companion AI handles it; we
## pick a reasonable default id (`small_mammal`) when the caller didn't
## specify one.
func _spawn_temp_ally_at(tile: Vector2i, monster_id: String = "rat") -> Monster:
	var path: String = "res://resources/monsters/%s.tres" % monster_id
	var mdata: MonsterData = null
	if ResourceLoader.exists(path):
		mdata = load(path)
	if mdata == null:
		mdata = MonsterRegistry.fetch(monster_id)
	if mdata == null:
		return null
	var scene: PackedScene = load("res://scenes/entities/Companion.tscn")
	if scene == null:
		return null
	var ally: Node = scene.instantiate()
	var entity_layer: Node = get_tree().get_first_node_in_group("entity_layer")
	if entity_layer == null:
		entity_layer = get_parent()
	entity_layer.add_child(ally)
	if ally.has_method("setup"):
		ally.setup(generator, tile, mdata)
	if "lifetime" in ally:
		ally.lifetime = 30  # ~30 turns
	return ally


func _is_undead(m: Node) -> bool:
	if m == null or not ("data" in m) or m.data == null:
		return false
	var shape: String = String(m.data.shape if "shape" in m.data else "")
	if shape == "undead":
		return true
	var flags: Array = m.data.flags if "flags" in m.data else []
	for f in flags:
		if String(f).to_lower().begins_with("undead"):
			return true
	return false


## Pick the closest visible, alive, hostile monster. Used for wand
## evocation MVP targeting (no picker UI yet).
func _nearest_visible_hostile() -> Node:
	var dmap: Node = get_tree().get_first_node_in_group("dmap")
	var best: Node = null
	var best_d: int = 999999
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
			continue
		if not ("grid_pos" in m):
			continue
		if dmap != null and dmap.has_method("is_tile_visible") \
				and not dmap.is_tile_visible(m.grid_pos):
			continue
		var d: int = max(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y))
		if d < best_d:
			best_d = d
			best = m
	return best


func _apply_consumable_effect(info: Dictionary) -> bool:
	match String(info.get("effect", "")):
		"heal":
			if stats == null:
				return false
			var hp_base: int = int(info.get("hp_base", int(info.get("amount", 20))))
			var hp_rand: int = int(info.get("hp_rand", 0))
			var healed: int = hp_base + (randi() % max(hp_rand, 1) if hp_rand > 0 else 0)
			stats.HP = min(stats.hp_max, stats.HP + healed)
			stats_changed.emit()
			CombatLog.add("You feel better! (+%d HP)" % healed)
			return true
		"restore_mp":
			if stats == null:
				return false
			var restored: int = min(stats.mp_max - stats.MP, int(info.get("amount", 20)))
			stats.MP += restored
			stats_changed.emit()
			CombatLog.add("Your magic surges! (+%d MP)" % restored)
			return true
		"teleport_random":
			if _is_formicid_stasis():
				CombatLog.add("Your stasis prevents any teleportation.")
				return true
			var tp_turns: int = 3 + randi() % 3
			set_meta("_pending_teleport_turns", tp_turns)
			CombatLog.add("You feel strangely unstable. (teleporting in %d turns)" % tp_turns)
			return true
		"blink":
			return _teleport_blink(4)
		"magic_mapping":
			var dmap: Node = get_tree().root.get_node_or_null("Game/DungeonLayer/DungeonMap")
			if dmap != null and dmap.has_method("reveal_all"):
				dmap.reveal_all()
				CombatLog.add("An image of the level floods your mind.")
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
			var stat_n: String = String(info.get("stat", ""))
			match stat_n:
				"STR": stats.STR += amt
				"DEX": stats.DEX += amt
				"INT": stats.INT += amt
			stats_changed.emit()
			CombatLog.add("You feel %s! (+%d %s)" % [
				{"STR": "stronger", "DEX": "nimbler", "INT": "smarter"}.get(stat_n, "different"),
				amt, stat_n])
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
			var rejected: Array[String] = []
			var cap: int = max_spell_levels()
			var used: int = used_spell_levels()
			for sp in info.get("spells", []):
				var spell_id: String = String(sp)
				if spell_id == "" or learned_spells.has(spell_id):
					continue
				# DCSS memorisation cap. Each spell costs its difficulty in
				# spell-levels; refusing past the budget mirrors the
				# "your head is too full" prompt in DCSS. Player has to
				# grind Spellcasting or level up to make room.
				var cost: int = _spell_difficulty(spell_id)
				if used + cost > cap:
					rejected.append(spell_id)
					continue
				learned_spells.append(spell_id)
				used += cost
				newly.append(spell_id)
			if not newly.is_empty():
				CombatLog.add("Learned: %s" % ", ".join(newly))
			if not rejected.is_empty():
				CombatLog.add("Your memory is full; couldn't learn: %s" \
						% ", ".join(rejected))
			if newly.is_empty() and rejected.is_empty():
				CombatLog.add("You already know these spells.")
			spells_learned.emit()
			# DCSS preserves spellbooks when no new spell was learned.
			# Returning false keeps the book in inventory so the player
			# can retry after gaining memory / level / spellcasting.
			return not newly.is_empty()
		"curing":
			if stats == null:
				return false
			var hp_base: int = int(info.get("hp_base", int(info.get("amount", 8))))
			var hp_rand: int = int(info.get("hp_rand", 0))
			var healed: int = hp_base + (randi() % max(hp_rand, 1) if hp_rand > 0 else 0)
			stats.HP = min(stats.hp_max, stats.HP + healed)
			stats_changed.emit()
			CombatLog.add("You feel much better! (+%d HP)" % healed)
			# Cure status effects
			for status in info.get("cures", []):
				if status == "poison":
					set_meta("_poisoned", false)
					CombatLog.add("You feel less poisoned.")
				elif status == "confusion":
					set_meta("_confused", false)
			return true
		"buff_temp":
			if stats == null:
				return false
			var amt: int = int(info.get("amount", 5))
			var dur_base: int = int(info.get("dur_base", 35))
			var dur_rand: int = int(info.get("dur_rand", 40))
			var turns: int = dur_base + (randi() % max(dur_rand, 1))
			var stat_key: String = String(info.get("stat", ""))
			match stat_key:
				"STR": stats.STR += amt
				"DEX": stats.DEX += amt
				"INT": stats.INT += amt
			if not has_meta("_temp_buffs"):
				set_meta("_temp_buffs", [])
			var buffs: Array = get_meta("_temp_buffs")
			buffs.append({"stat": stat_key, "amount": amt, "turns_left": turns})
			set_meta("_temp_buffs", buffs)
			stats_changed.emit()
			CombatLog.add("You feel a surge of power! (+%d %s for %d turns)" % [amt, stat_key, turns])
			return true
		"resistance":
			var dur_base: int = int(info.get("dur_base", 35))
			var dur_rand: int = int(info.get("dur_rand", 40))
			resist_turns = dur_base + (randi() % max(dur_rand, 1))
			CombatLog.add("You feel protected! (rF+rC+rElec for %d turns)" % resist_turns)
			return true
		"haste":
			var dur_base: int = int(info.get("dur_base", 26))
			var dur_rand: int = int(info.get("dur_rand", 15))
			var turns: int = dur_base + (randi() % max(dur_rand, 1))
			set_meta("_haste_turns", int(get_meta("_haste_turns", 0)) + turns)
			CombatLog.add("Time seems to slow! (%d turns of haste)" % turns)
			return true
		"attraction":
			# DCSS potion_effects.cc:potion_effect_attraction — pulls every
			# nearby monster a step closer. Duration in our model is how many
			# times the pull fires in the next few turns.
			var count_att: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not ("is_alive" in m) or not m.is_alive:
					continue
				if not ("grid_pos" in m):
					continue
				var d: int = max(abs(m.grid_pos.x - grid_pos.x), abs(m.grid_pos.y - grid_pos.y))
				if d <= 10 and d > 1:
					var toward: Vector2i = Vector2i(
							sign(grid_pos.x - m.grid_pos.x),
							sign(grid_pos.y - m.grid_pos.y))
					var step: Vector2i = m.grid_pos + toward
					if generator != null and generator.is_walkable(step):
						m.move_to_grid(step)
						count_att += 1
					# Also wake sleepers — attraction is anything but subtle.
					if "is_sleeping" in m and m.is_sleeping:
						MonsterAI.wake(m)
			CombatLog.add("Monsters lurch toward you. (%d pulled)" % count_att)
			return true
		"enlightenment":
			# See invisible + clarity (anti-confusion). Represented as a
			# combined "enlightened" meta the combat/hex checks can key off.
			var dur_e: int = int(info.get("dur_base", 35)) + (randi() % max(int(info.get("dur_rand", 35)), 1))
			set_meta("_enlightened_turns", int(get_meta("_enlightened_turns", 0)) + dur_e)
			CombatLog.add("Your senses sharpen. (%d turns of clarity)" % dur_e)
			return true
		"cancellation":
			# DCSS potion-effects.cc: dispels the drinker's own timed buffs.
			# We clear every temp-buff meta our game currently tracks.
			remove_meta("_haste_turns")
			remove_meta("_enlightened_turns")
			remove_meta("_invisible_turns")
			remove_meta("_berserk_turns")
			remove_meta("_tree_turns")
			resist_turns = 0
			set_meta("_temp_buffs", [])
			stats_changed.emit()
			_refresh_invisibility_visual()
			CombatLog.add("A rush of nothingness erases your enchantments.")
			return true
		"ambrosia":
			# Confused + HP/MP regen for a few turns. DCSS uses DUR_AMBROSIA.
			var dur_a: int = int(info.get("dur_base", 4)) + (randi() % max(int(info.get("dur_rand", 4)), 1))
			set_meta("_ambrosia_turns", int(get_meta("_ambrosia_turns", 0)) + dur_a)
			set_meta("_confused", true)
			CombatLog.add("Sweet honey fills your senses! (%d turns of ambrosia)" % dur_a)
			return true
		"invisibility":
			var dur_i: int = int(info.get("dur_base", 18)) + (randi() % max(int(info.get("dur_rand", 10)), 1))
			set_meta("_invisible_turns", int(get_meta("_invisible_turns", 0)) + dur_i)
			_refresh_invisibility_visual()
			CombatLog.add("You vanish from sight. (%d turns invisible)" % dur_i)
			return true
		"experience":
			# DCSS: one character-level's worth of XP. We grant xp_for_next
			# so the next kill or two levels the player up, matching feel.
			if has_method("grant_xp"):
				var amt_xp: int = max(50, xp_for_next_level())
				grant_xp(amt_xp)
				CombatLog.add("Your past learnings crystallise. (+%d XP)" % amt_xp)
			return true
		"berserk":
			# DCSS you_exhausted(): exhausted players can't re-berserk
			# until the fatigue wears off. Silently fails with a log line.
			if has_meta("_exhausted_turns"):
				CombatLog.add("You are too exhausted to berserk.")
				return true
			var dur_b: int = int(info.get("dur_base", 11)) + (randi() % max(int(info.get("dur_rand", 8)), 1))
			set_meta("_berserk_turns", int(get_meta("_berserk_turns", 0)) + dur_b)
			# DCSS berserk also hastes and grants bonus HP for the duration.
			set_meta("_haste_turns", int(get_meta("_haste_turns", 0)) + dur_b)
			if stats != null:
				var bonus: int = max(1, stats.hp_max / 3)
				stats.hp_max += bonus
				stats.HP += bonus
				set_meta("_berserk_bonus_hp", bonus)
				stats_changed.emit()
			CombatLog.add("You go berserk! (%d turns)" % dur_b)
			return true
		"mutation":
			# DCSS potion_mutation grants 2-4 random rolls, each a coin-flip
			# between adding a good mutation or adding a bad one. Net effect
			# is "you're probably a bit different now".
			var rolls: int = randi_range(2, 4)
			var applied: Array = []
			for i in rolls:
				var polarity: String = "good" if randf() < 0.45 else ("bad" if randf() < 0.55 else "")
				var mid: String = MutationRegistry.pick_random(polarity)
				if mid == "" or not apply_mutation(mid):
					continue
				applied.append(mid)
			if applied.is_empty():
				CombatLog.add("You shiver, but nothing changes.")
			else:
				CombatLog.add("Your body transforms! (" + ", ".join(applied) + ")")
			return true
		"lignify":
			var dur_l: int = int(info.get("dur_base", 35)) + (randi() % max(int(info.get("dur_rand", 15)), 1))
			set_meta("_tree_turns", int(get_meta("_tree_turns", 0)) + dur_l)
			# Hefty AC bump + big HP pool while rooted.
			if stats != null:
				stats.AC += 15
				var bonus_l: int = stats.hp_max  # double HP
				stats.hp_max += bonus_l
				stats.HP = stats.hp_max
				set_meta("_tree_ac_bonus", 15)
				set_meta("_tree_hp_bonus", bonus_l)
				stats_changed.emit()
			CombatLog.add("You take root! (tree form for %d turns)" % dur_l)
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
		"noise":
			# DCSS scroll_effect.cc:noise — wakes every sleeping monster on
			# the floor regardless of LOS. Equivalent of "you shouted!"
			var woke: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
					continue
				if m.is_sleeping:
					MonsterAI.wake(m)
					woke += 1
			CombatLog.add("The scroll shrieks! (%d monsters woken)" % woke)
			return true
		"summoning":
			# DCSS scroll-effects.cc cast_summon_small_mammals — spawns
			# 2-4 temporary allies from the small-mammal pool (rat /
			# quokka / bat) on walkable tiles around the player.
			var small_mammals: Array = ["rat", "quokka", "bat"]
			var want: int = int(info.get("count", 3))
			var summoned: int = 0
			for tile in _adjacent_free_tiles(want):
				var pick: String = String(small_mammals[randi() % small_mammals.size()])
				var ally: Monster = _spawn_temp_ally_at(tile, pick)
				if ally != null:
					summoned += 1
			CombatLog.add("The scroll summons allies. (%d appeared)" % summoned)
			return true
		"torment":
			# DCSS torment: halves every non-undead living creature's HP
			# within LOS (undead are immune). We approximate "non-undead" by
			# excluding monsters with the "undead" flag or `shape: undead`.
			var dmap: Node = get_tree().get_first_node_in_group("dmap")
			var affected: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
					continue
				if dmap != null and dmap.has_method("is_tile_visible") \
						and not dmap.is_tile_visible(m.grid_pos):
					continue
				if _is_undead(m):
					continue
				var half: int = max(1, m.hp / 2)
				m.take_damage(half)
				affected += 1
			CombatLog.add("A wave of agony washes over the living. (%d struck)" % affected)
			return true
		"brand_weapon":
			# Permanent weapon ego. We roll from a small set of elemental
			# brands that map to flags combat already handles.
			if equipped_weapon_id == "":
				CombatLog.add("You are wielding nothing to brand.")
				return false
			var brands: Array = ["flaming", "freezing", "electrocution", "venom", "holy_wrath"]
			# DCSS SPWPN_PENETRATION is bow-exclusive.
			if WeaponRegistry.weapon_skill_for(equipped_weapon_id) == "bow":
				brands.append("penetration")
			var picked: String = String(brands[randi() % brands.size()])
			set_meta("_weapon_brand_" + equipped_weapon_id, picked)
			CombatLog.add("Your %s glows with %s energy!" % [
					WeaponRegistry.display_name_for(equipped_weapon_id), picked.replace("_", " ")])
			return true
		"silence":
			var dur_s: int = int(info.get("dur_base", 12)) + (randi() % max(int(info.get("dur_rand", 8)), 1))
			set_meta("_silenced_turns", int(get_meta("_silenced_turns", 0)) + dur_s)
			_refresh_silence_visual()
			CombatLog.add("Dead silence falls. (%d turns of silence)" % dur_s)
			return true
		"amnesia":
			if learned_spells.is_empty():
				CombatLog.add("You have no spells to forget.")
				return false
			var idx_f: int = randi() % learned_spells.size()
			var forgotten: String = String(learned_spells[idx_f])
			learned_spells.remove_at(idx_f)
			spells_learned.emit()
			CombatLog.add("You forget how to cast %s." % forgotten.replace("_", " ").capitalize())
			return true
		"poison_scroll":
			var dmap_p: Node = get_tree().get_first_node_in_group("dmap")
			var pcount: int = 0
			for m in get_tree().get_nodes_in_group("monsters"):
				if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
					continue
				if dmap_p != null and dmap_p.has_method("is_tile_visible") \
						and not dmap_p.is_tile_visible(m.grid_pos):
					continue
				m.set_meta("_poison_turns", 5)
				m.set_meta("_poison_dmg", 3)
				pcount += 1
			CombatLog.add("A toxic cloud settles on every enemy you see. (%d poisoned)" % pcount)
			return true
		"butterflies":
			# DCSS butterflies: noisy, harmless friendly summons. We use
			# Monster.tscn with "butterfly" data, spawned as temp companions.
			var bf_want: int = int(info.get("count", 5))
			var bf_placed: int = 0
			for tile in _adjacent_free_tiles(bf_want):
				var bf: Monster = _spawn_temp_ally_at(tile, "butterfly")
				if bf != null:
					bf_placed += 1
			CombatLog.add("A cloud of butterflies erupts around you! (%d)" % bf_placed)
			return true
		"acquirement":
			if generator == null:
				return false
			# DCSS acquirement picks a kind, then drops an appropriately-
			# powered item at the player's feet. We roll a weapon or armour
			# and drop it via the same FloorItem pipeline as floor gen.
			var _acq_weapons: Array = ["long_sword", "war_axe", "mace", "shortbow",
					"halberd", "rapier", "quarterstaff", "crystal_staff"]
			var _acq_armor: Array = ["chain_mail", "plate_armour", "leather_armour",
					"helmet", "buckler", "boots"]
			var is_weapon: bool = randf() < 0.5
			var chosen: String = _acq_weapons[randi() % _acq_weapons.size()] if is_weapon \
					else _acq_armor[randi() % _acq_armor.size()]
			var entity_layer: Node = get_tree().get_first_node_in_group("entity_layer")
			if entity_layer == null:
				entity_layer = get_parent()
			var fi := FloorItem.new()
			entity_layer.add_child(fi)
			var item_name: String = ""
			var item_kind: String = ""
			var tint: Color = Color(0.75, 0.75, 0.85)
			var extra: Dictionary = {"cursed": false}
			if is_weapon:
				item_name = WeaponRegistry.display_name_for(chosen)
				item_kind = "weapon"
			else:
				var a_info: Dictionary = ArmorRegistry.get_info(chosen)
				item_name = String(a_info.get("name", chosen))
				item_kind = "armor"
				if a_info.has("slot"):
					extra["slot"] = String(a_info["slot"])
			fi.setup(grid_pos, chosen, item_name, item_kind, tint, extra)
			CombatLog.add("An item materialises at your feet: %s!" % item_name)
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


## Returns true when the player is under stasis — blocks all teleports,
## blinks, hasting, and slowing. Covers Formicid racial trait and the
## Amulet of Stasis.
func _is_formicid_stasis() -> bool:
	return _racial_trait_id() == "formicid_stasis" or has_meta("_amulet_stasis")


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
		# Winged races cross water but never walk through lava or acid.
		if tile == DungeonGenerator.TileType.WATER:
			return true
	if trait_id == "djinni_flight":
		# Flame-spirits glide over water + lava (fire-kin immune).
		# Acid still eats them unless they have rCorr, handled below.
		if tile == DungeonGenerator.TileType.WATER \
				or tile == DungeonGenerator.TileType.LAVA:
			return true
	# Acid pools: impassable unless the player has rCorr (corrosion
	# resistance). DCSS equivalent — gargoyle stone, Shining One
	# followers, SPARM_RESONANCE-ego armour.
	if tile == DungeonGenerator.TileType.ACID:
		if get_resist("corr") >= 1:
			return true
	return false


func _teleport_to(target: Vector2i) -> void:
	grid_pos = target
	position = Vector2(target.x * tile_size + tile_size / 2.0, target.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	moved.emit(grid_pos)
	# DCSS teleport-onto-hazard: landing on lava / acid without the
	# relevant resist hurts. Walls never trigger this path because
	# _teleport_random only picks walkable candidates.
	if generator != null:
		var t: int = generator.get_tile(grid_pos)
		if t == DungeonGenerator.TileType.LAVA and get_resist("fire") < 3:
			var burn: int = randi_range(15, 30)
			take_damage(burn, "fire")
			CombatLog.add("You land in lava! (%d dmg)" % burn)
		elif t == DungeonGenerator.TileType.ACID and get_resist("corr") < 1:
			var corr: int = randi_range(10, 20)
			take_damage(corr, "acid")
			CombatLog.add("You land in acid! (%d dmg)" % corr)


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
	# DCSS exp_needed(level, exp_apt):
	#   cost = table[level] - table[level-1]    (apt 1 baseline)
	#   cost *= apt_to_factor(exp_apt - 1)       (species scaling)
	# apt_to_factor(apt) = 1 / 2^(apt/4). Higher apt → lower XP cost.
	# Troll xp_mod -1 → factor 2^0.5 ≈ 1.414× slower. Demigod -2 → ~1.68×.
	# XL is capped at 27 (DCSS experience_level max). At or past the cap,
	# return a sentinel so grant_xp's while-loop exits immediately — the
	# earlier bug was returning max(1, 0) = 1 once level >= 27, which
	# turned a single kill into a runaway level-up cascade.
	if level >= 27:
		return 0x3FFFFFFF
	var here: int = _DCSS_EXP_NEEDED[clampi(level - 1, 0, _DCSS_EXP_NEEDED.size() - 1)]
	var next: int = _DCSS_EXP_NEEDED[clampi(level, 0, _DCSS_EXP_NEEDED.size() - 1)]
	var base: int = max(1, next - here)
	var apt: int = race_res.xp_mod if race_res != null else 0
	var factor: float = pow(2.0, -float(apt - 1) / 4.0)  # apt_to_factor(apt-1)
	return max(1, int(base * factor))


func _apply_level_up_growth() -> void:
	if stats == null:
		return
	# DCSS recomputes hp_max/mp_max from scratch on level-up using current
	# XL + skills + species mods. Follows player.cc calc_hp/calc_mp (scaled
	# carry-over: current HP stays at the same ratio of new max).
	var fighting_sk: int = _skill_level("fighting")
	var spellcast_sk: int = _skill_level("spellcasting")
	var hp_mod: int = race_res.hp_mod if race_res != null else 0
	var mp_mod: int = race_res.mp_mod if race_res != null else 0
	var trait_hp_pct: float = 1.0 + (trait_res.hp_bonus_pct if trait_res != null else 0.0)
	var trait_mp_pct: float = 1.0 + (trait_res.mp_bonus_pct if trait_res != null else 0.0)
	var new_hp_max: int = int(_dcss_max_hp(level, fighting_sk, hp_mod) * trait_hp_pct)
	var new_mp_max: int = int(_dcss_max_mp(level, spellcast_sk, 0, mp_mod) * trait_mp_pct)
	# Preserve HP/MP ratio across max changes (DCSS calc_hp scales the same way).
	var old_hp_max: int = max(1, stats.hp_max)
	var old_mp_max: int = max(1, stats.mp_max)
	stats.hp_max = new_hp_max
	stats.HP = clampi(stats.HP * new_hp_max / old_hp_max, 1, new_hp_max)
	stats.mp_max = new_mp_max
	stats.MP = clampi(stats.MP * new_mp_max / old_mp_max, 0, new_mp_max)
	stats_changed.emit()


## Helper: read current skill level. Reads `skill_state` if SkillSystem has
## already seeded it; otherwise falls back to `job_res.starting_skills` (used
## during initial setup, before SkillSystem is installed).
func _skill_level(skill_id: String) -> int:
	if skill_state.has(skill_id) and typeof(skill_state[skill_id]) == TYPE_DICTIONARY:
		return int(skill_state[skill_id].get("level", 0))
	if job_res != null and job_res.starting_skills.has(skill_id):
		return int(job_res.starting_skills[skill_id])
	return 0


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
	# Charm: cannot bring yourself to attack while under the effect.
	if has_meta("_charmed_turns"):
		CombatLog.add("You are charmed and cannot attack!")
		return null
	# Frozen / Petrified / Paralysed: no motor control to swing a weapon.
	if has_meta("_frozen_turns"):
		CombatLog.add("You are frozen and can't attack!")
		return null
	if has_meta("_petrified_turns") or has_meta("_paralysis_turns"):
		CombatLog.add("You cannot attack — you are immobilised!")
		return null
	# DCSS reach check (item-prop.cc:2323). Polearms hit at distance 2;
	# everything else is plain Chebyshev adjacent. The 2-tile reach
	# also needs a clear middle cell (no wall, no blocking monster)
	# to emulate the shaft's line-of-fire.
	var reach: int = WeaponRegistry.weapon_reach(equipped_weapon_id)
	var dx: int = abs(target_pos.x - grid_pos.x)
	var dy: int = abs(target_pos.y - grid_pos.y)
	var ccdist: int = maxi(dx, dy)
	if ccdist > reach:
		return null
	if ccdist == 2:
		# Middle tile must be walkable-ish (not a wall, not another
		# monster). Diagonal-2 reaches use the midpoint of the line.
		var mid: Vector2i = grid_pos + Vector2i(
				sign(target_pos.x - grid_pos.x),
				sign(target_pos.y - grid_pos.y))
		if generator != null and not generator.is_walkable(mid):
			return null
		if _monster_at(mid) != null:
			return null
	var delta := Vector2i(sign(target_pos.x - grid_pos.x), sign(target_pos.y - grid_pos.y))
	if _sprite:
		_sprite.face_toward(delta)
	# Sprite slash animation carries the attack feel — no position lunge.
	# [skill-agent] route through CombatSystem so skill levels are factored in.
	var skill_sys: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	# DCSS attack_delay port (player-act.cc:252 attack_delay_with):
	#   delay = weapon_speed
	#   delay -= min(skill*10, mindelay_skill*10) / 20        # skill up to
	#                                                           mindelay halves
	#   if brand == speed: delay = delay*2/3
	#   if brand == heavy: delay = delay*3/2
	#   delay = max(delay, 3)
	# Our last_action_ticks is stored in BASELINE_DELAY units (×10), so the
	# 10-point scale gets converted to ticks at the end.
	var weapon_delay_base: float = 1.0
	if equipped_weapon_id != "" and WeaponRegistry.is_weapon(equipped_weapon_id):
		weapon_delay_base = WeaponRegistry.weapon_delay_for(equipped_weapon_id)
	var delay_10: int = int(round(weapon_delay_base * 10))
	# Unarmed routes through the "unarmed_combat" skill for delay
	# reduction, matching DCSS where SK_UNARMED_COMBAT governs fist
	# attack delay too (player-act.cc: player_adjust_delay_with_skill).
	var wpn_skill_id: String = WeaponRegistry.weapon_skill_for(equipped_weapon_id)
	if equipped_weapon_id == "":
		wpn_skill_id = "unarmed_combat"
	var wpn_sklev: int = 0
	if skill_sys != null and wpn_skill_id != "":
		wpn_sklev = skill_sys.get_level(self, wpn_skill_id)
	# mindelay_skill is usually 10 in DCSS (half-delay point). Cap skill
	# contribution so specialisation past 10 doesn't keep cutting delay.
	var capped_sk: int = mini(wpn_sklev, 10)
	delay_10 = maxi(3, delay_10 - capped_sk * 10 / 20)
	# Brand multipliers: speed weapons fire at 2/3 delay, heavy at 3/2.
	if equipped_weapon_id != "":
		var brand_key: String = "_weapon_brand_" + equipped_weapon_id
		if has_meta(brand_key):
			match String(get_meta(brand_key)):
				"speed": delay_10 = maxi(3, delay_10 * 2 / 3)
				"heavy": delay_10 = delay_10 * 3 / 2
	last_action_ticks = delay_10
	# Acrobat bonus expires on any melee swing.
	if has_meta("_acrobat_active"):
		remove_meta("_acrobat_active")
	CombatSystem.melee_attack(self, monster, skill_sys)
	attacked.emit(monster)
	# DCSS fight.cc cleave_targets — axes hit the two tiles flanking
	# the primary target (perpendicular to the swing direction). Each
	# cleave swing rolls independently so skill/RNG still matters.
	if WeaponRegistry.weapon_cleaves(equipped_weapon_id):
		var facing := Vector2i(
				sign(target_pos.x - grid_pos.x),
				sign(target_pos.y - grid_pos.y))
		var flank_a: Vector2i
		var flank_b: Vector2i
		if facing.x == 0:
			flank_a = target_pos + Vector2i(1, 0)
			flank_b = target_pos + Vector2i(-1, 0)
		elif facing.y == 0:
			flank_a = target_pos + Vector2i(0, 1)
			flank_b = target_pos + Vector2i(0, -1)
		else:
			# Diagonal swing — the flanks are the two orthogonals sharing
			# a side with both the attacker and target tiles.
			flank_a = Vector2i(grid_pos.x + facing.x, grid_pos.y)
			flank_b = Vector2i(grid_pos.x, grid_pos.y + facing.y)
		for flank in [flank_a, flank_b]:
			var m2: Node = _monster_at(flank)
			if m2 != null and "is_alive" in m2 and m2.is_alive:
				CombatSystem.melee_attack(self, m2, skill_sys)
	# Combat is loud — DCSS broadcasts noise roughly proportional to the
	# attacker's weapon/size. We key off stealth skill so high-stealth
	# rogues can pick off isolated targets without waking the whole room.
	MonsterAI.broadcast_noise(get_tree(), grid_pos, 6, _skill_level("stealth"))
	TurnManager.end_player_turn()
	return monster


## Player ranged attack. Pre-checks equipped weapon, routes through
## CombatSystem.ranged_attack which rolls to-hit with range penalty,
## applies damage, and trains bow + fighting via the standard XP pipe.
## Returns true if the shot actually fired (spent the turn).
func try_ranged_attack(target_pos: Vector2i) -> bool:
	if not is_alive or generator == null:
		return false
	# Bow/sling/crossbow required — WeaponRegistry maps all three to
	# the "bow" skill.
	if WeaponRegistry.weapon_skill_for(equipped_weapon_id) != "bow":
		CombatLog.add("You need a bow, sling, or crossbow to fire.")
		return false
	# Find a target at the position. Shots without a victim just fly
	# off; DCSS actually allows empty-tile fire but our UX keeps it
	# target-locked to stop accidental turn-wastes.
	var target: Node = _monster_at(target_pos)
	if target == null:
		CombatLog.add("No target there.")
		return false
	var skill_sys: Node = get_tree().root.get_node_or_null("Game/SkillSystem")
	var dist: int = maxi(abs(target_pos.x - grid_pos.x),
			abs(target_pos.y - grid_pos.y))
	# Clamp to the weapon's conservative range band. DCSS longbow caps at
	# 7 without Portal Projectile; we use a flat 7 for all bows.
	if dist > 7:
		CombatLog.add("Too far.")
		return false
	# Facing animation for feedback.
	if _sprite:
		_sprite.face_toward(target_pos - grid_pos)
	var delay_10: int = int(round(WeaponRegistry.weapon_delay_for(equipped_weapon_id) * 10))
	# Bow skill reduces delay the same way as melee mindelay.
	var bow_lv: int = skill_sys.get_level(self, "bow") if skill_sys != null else 0
	delay_10 = maxi(3, delay_10 - mini(bow_lv, 10) * 10 / 20)
	last_action_ticks = delay_10
	# DCSS SPWPN_PENETRATION: the arrow pierces through and hits every
	# monster in the line up to weapon range, not just the first. Reuses
	# `Beam.trace(pierce=true)` to enumerate victims; we fire the same
	# ranged_attack against each so skill training and noise-per-shot
	# still make sense (one swing, multiple victims).
	var brand_key: String = "_weapon_brand_" + equipped_weapon_id
	var penetrates: bool = has_meta(brand_key) \
			and String(get_meta(brand_key)) == "penetration"
	if penetrates:
		var gen: DungeonGenerator = generator
		var opaque_cb: Callable = func(cell: Vector2i) -> int:
			var t: int = gen.get_tile(cell)
			if t == DungeonGenerator.TileType.WALL \
					or t == DungeonGenerator.TileType.CRYSTAL_WALL \
					or t == DungeonGenerator.TileType.DOOR_CLOSED:
				return 2  # FieldOfView.OPC_OPAQUE
			return 0
		var mon_cb: Callable = func(cell: Vector2i):
			return _monster_at(cell)
		var trace: Dictionary = Beam.trace(grid_pos, target_pos, 7, true,
				opaque_cb, mon_cb)
		var hits: Array = trace.get("hits", [])
		if hits.is_empty():
			CombatSystem.ranged_attack(self, target, target_pos, skill_sys)
		else:
			for h in hits:
				if h == null or not is_instance_valid(h):
					continue
				CombatSystem.ranged_attack(self, h, h.grid_pos, skill_sys)
	else:
		CombatSystem.ranged_attack(self, target, target_pos, skill_sys)
	attacked.emit(target)
	MonsterAI.broadcast_noise(get_tree(), grid_pos, 8, _skill_level("stealth"))
	TurnManager.end_player_turn()
	return true


func take_damage(amount: int, element: String = "") -> void:
	if not is_alive:
		return
	# DCSS resistance pipeline: an element-tagged hit (fire/cold/elec/
	# poison/acid/holy/drain) first gets scaled by the player's total
	# resist level for that element before any generic mitigation.
	if element != "":
		amount = _apply_elem_resist(amount, element)
	# MUT_BERSERK (berserkitis). DCSS: on taking damage, 1/8 chance per
	# mutation level to auto-berserk (rage sets in unbidden). Only fires
	# when not already raging / exhausted, and skips if the hit is fatal.
	var berserkitis: int = int(get_meta("_mut_berserkitis", 0))
	if berserkitis > 0 and not has_meta("_berserk_turns") \
			and not has_meta("_exhausted_turns") and is_alive:
		if randi() % 8 < berserkitis and stats != null and stats.HP > amount:
			CombatLog.add("A rage takes you!")
			_apply_consumable_effect({"effect": "berserk", "dur_base": 11, "dur_rand": 8})
	# DCSS SPARM_HARM ego — scarf/robe of harm increases dmg both ways
	# by 30%. Here we handle the "dmg taken" half; the "dmg dealt" half
	# is applied in CombatSystem.melee_attack via the same meta.
	if has_meta("_ego_harm"):
		amount = (amount * 130) / 100
	# Shadow form halves all incoming damage.
	if has_meta("_shadow_form_turns"):
		amount = max(1, amount / 2)
	# Divine shield and fiery armour shave a flat chunk.
	if has_meta("_divine_shield_turns"):
		amount = max(1, amount - 3)
	# Potion/scroll of Resistance still applies a generic halving on top of
	# the specific-element scaling so it pairs with rF+/rC+ gear.
	if resist_turns > 0:
		amount = max(1, amount / 2)
	# Sanctuary: Zin protects the faithful from almost all harm.
	if has_meta("_sanctuary_turns"):
		amount = max(1, amount / 4)
	# Death's Door: HP cannot drop below 1 while the duration runs.
	if has_meta("_deaths_door_turns") and stats != null:
		amount = min(amount, stats.HP - 1)
		if amount <= 0:
			return
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
	# DCSS SPARM_SPIRIT_SHIELD / Amulet of Guardian Spirit — split incoming
	# HP damage equally with MP. Only the HP half is taken if MP is depleted.
	if (has_meta("_ego_spirit_shield") or has_meta("_amulet_spirit_shield")) and stats != null:
		var mp_share: int = amount / 2
		var mp_drain: int = mini(mp_share, stats.MP)
		stats.MP -= mp_drain
		amount -= mp_drain
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
