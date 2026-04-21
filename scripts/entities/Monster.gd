class_name Monster extends Node2D

signal died(monster: Monster)

const TILE_SIZE: int = 32
const _CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var data: MonsterData
var hp: int = 0
var ac: int = 0
var dex: int = 0
var sight_range: int = 6
var is_alive: bool = true
var tile_size: int = 32
# Hex effect: remaining turns where this monster skips its action.
var slowed_turns: int = 0
# DCSS BEH_SLEEP state. Sleeping monsters skip their turn until woken by
# LOS of a hostile, damage, or adjacent combat noise. Set true at spawn for
# almost every non-boss monster (dungeon.cc:4252); MonsterAI.act() is
# responsible for the wake check and state transition.
var is_sleeping: bool = false
## DCSS action-energy accumulator. Each player turn the monster adds
## its `data.speed` (10 = normal, 15 = fast, 5 = slow); while the
## accumulator is ≥ 10, the monster takes one action and spends 10
## energy. A speed-15 centaur therefore averages 1.5 swings per player
## turn; a speed-30 bat swings 3 times.
var _action_energy: int = 10

var _sprite: CharacterSprite = null
var _has_preset: bool = false
var _walk_timer: SceneTreeTimer = null
var _move_tween: Tween = null
var boss_ai: BossAI = null
const _MOVE_TWEEN_DUR: float = 0.12
const _ATTACK_LUNGE_DUR: float = 0.08


func _ready() -> void:
	add_to_group("monsters")
	TurnManager.register_actor(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(gen: DungeonGenerator, pos: Vector2i, mdata: MonsterData) -> void:
	generator = gen
	data = mdata
	# DCSS rolls HP per spawn: avg = hp_10x / 10 ± 33% variance, sampled from
	# random2avg(2*variance, 8). Ports mon-util.cc:2251 hit_points().
	hp = _dcss_roll_hp(mdata.hp_10x) if mdata.hp_10x > 10 else mdata.hp
	ac = mdata.ac
	dex = mdata.dex
	# DCSS dungeon.cc:4252 — regular floor monsters start BEH_SLEEP; bosses
	# and a small chance-to-be-awake get AWAKE. Waking rules are handled by
	# MonsterAI on each turn.
	is_sleeping = not mdata.is_boss and randi() % 8 != 0
	sight_range = mdata.sight_range if mdata.sight_range > 0 else 6
	grid_pos = pos
	position = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	if mdata.is_boss and BossAI.PATTERNS.has(mdata.id):
		boss_ai = BossAI.new()
		boss_ai.setup(mdata.id)
	_load_sprite()
	if not _has_preset:
		queue_redraw()


## DCSS hit_points(avg_hp_10x, scale=10) — mon-util.cc:2251. Each spawn rolls
## HP as `avg ± 33% variance` via an 8-sample random2avg to give a tight
## bell curve. Returns at least 1. `hp_10x` of 10 or less means "no roll"
## in DCSS (summons, temp monsters) — caller falls back to mdata.hp.
## Read the monster's resist level for `element` from DCSS-sourced flags
## (`resists: [fire, cold]`) + holiness-derived intrinsics (undead →
## cold+poison+drain, demonic → fire, nonliving → poison+drain).
## `data.resists` entries can be either plain strings ("fire") or
## scaled ("fire2" meaning rF+2) — we count level per entry.
func _mon_resist_level(element: String) -> int:
	if data == null:
		return 0
	var total: int = 0
	for r in data.resists:
		var s: String = String(r).to_lower()
		if s.begins_with(element):
			# "fire" → 1, "fire2" → 2, "fire3" → 3, "fire-1" → -1.
			var tail: String = s.substr(element.length())
			if tail == "":
				total += 1
			elif tail.is_valid_int():
				total += int(tail)
			else:
				total += 1
	# Holiness-derived defaults (DCSS mons_class_res_*). Our MonsterData
	# doesn't have a dedicated `holiness` field yet; read the tag off the
	# `flags` array + `shape` instead. Resource.get() is one-arg in Godot 4,
	# so the earlier `data.get("holiness", "")` was a parse error.
	var holy: String = ""
	if data.shape == "undead":
		holy = "undead"
	elif data.flags != null:
		for f in data.flags:
			var lf: String = String(f).to_lower()
			if lf == "undead" or lf == "demonic" or lf == "nonliving" or lf == "holy":
				holy = lf
				break
	match element:
		"cold", "drain":
			if holy == "undead" or holy == "nonliving":
				total += 1
		"poison":
			if holy == "undead" or holy == "nonliving" or holy == "plant":
				total += 1
		"fire":
			if holy == "demonic":
				total += 1
	return total


## DCSS resist_adjust_damage (fight.cc:853) — monster branch.
##   resistible /= 1 + bonus_res + res*res     (stronger than player!)
## res=1 → /2, res=2 → /5, res=3 → /10 (or immune for poison/neg/holy).
## Negative resist → ×1.5 damage.
func _apply_mon_resist(amount: int, element: String) -> int:
	var rl: int = _mon_resist_level(element)
	if rl == 0:
		return amount
	if rl < 0:
		return amount * 15 / 10  # -1 level: +50%
	# Positive resist. DCSS treats monsters as immune at res>=3 for
	# "boolean" elements (poison, drain, holy). Fire/cold/elec still
	# just divide heavily.
	var boolean_immune: bool = element == "poison" \
			or element == "neg" \
			or element == "holy"
	if boolean_immune and rl >= 3:
		return 0
	var bonus_res: int = 1 if (element == "poison" or element == "neg") else 0
	var denom: int = 1 + bonus_res + rl * rl
	return maxi(1, amount / maxi(1, denom))


static func _dcss_roll_hp(hp_10x: int) -> int:
	if hp_10x <= 0:
		return 1
	var variance: int = int(round(float(hp_10x) * 33.0 / 100.0))
	var min_hp: int = hp_10x - variance
	# random2avg(max, rolls=8): sum of one random2(max) + 7 random2(max+1),
	# divided by 8. Gives mean ~= variance with a bell shape.
	var size: int = variance * 2
	if size <= 0:
		return max(1, hp_10x / 10)
	var sum: int = randi() % size  # random2(size) = 0..size-1
	var n_extra: int = 7
	for _i in n_extra:
		sum += randi() % (size + 1)  # random2(size+1) = 0..size
	var rolled: int = sum / 8
	var hp_total: int = min_hp + rolled
	return max(1, hp_total / 10)


func _load_sprite() -> void:
	if data == null:
		return
	# DCSS / ASCII modes: skip LPC entirely and let _draw() render the tile
	# or glyph.
	if TileRenderer.is_dcss() or TileRenderer.is_ascii():
		_has_preset = false
		queue_redraw()
		return
	var preset := LPCPresetLoader.load_preset(data.id)
	if preset.is_empty():
		# No preset yet for this monster — keep primitive _draw() fallback.
		_has_preset = false
		return
	_has_preset = true
	_sprite = _CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	add_child(_sprite)
	_sprite.load_character(preset)
	_sprite.set_direction("down")
	_sprite.play_anim("idle", true)


## DCSS-parity poison. Mirrors Player.apply_poison so venom weapons,
## naga spit, alchemist spells and scroll of poison all route through
## the same 3-level stack for player and monster alike.
## Level 1=light (2dmg/t, 7t), 2=moderate (4dmg/t, 9t), 3=severe (6dmg/t, 11t).
## Higher level replaces lower; equal extends duration; rPois scales
## the level down and gates out when fully resistant.
func apply_poison(level: int = 1, _source: String = "poison") -> void:
	if data == null or not is_alive:
		return
	var rpois: int = _mon_resist_level("poison")
	if rpois >= 3:
		return  # Fully poison-immune (undead/demons/jellies typically).
	if rpois >= 1:
		level = maxi(0, level - 1)  # rPois+ one-shots a level down.
	if level <= 0:
		return
	var cur_level: int = int(get_meta("_poison_level", 0))
	var new_level: int = clampi(maxi(cur_level, level), 1, 3)
	var dmg_per_turn: int = new_level * 2
	var turns: int = 5 + new_level * 2
	set_meta("_poison_level", new_level)
	set_meta("_poison_turns", turns)
	set_meta("_poison_dmg", dmg_per_turn)


func take_damage(amount: int, element: String = "") -> void:
	if not is_alive:
		return
	# Monster resistance scaling: data.resists is a dict of {element: level}.
	# DCSS rF+1 halves / +2 thirds / +3 fifths; negative amplifies.
	if element != "" and data != null:
		amount = _apply_mon_resist(amount, element)
	# DCSS: damage always wakes a sleeping monster (mon-behv.cc:1172). Route
	# through MonsterAI.wake so the ring of adjacent sleepers wakes too.
	if is_sleeping:
		MonsterAI.wake(self)
	hp -= amount
	if _sprite and hp > 0:
		_sprite.play_anim("hurt", false)
	if hp <= 0:
		die()


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(self)
	TurnManager.unregister_actor(self)
	if _sprite:
		_sprite.play_anim("hurt", false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func take_turn() -> void:
	if not is_alive:
		return
	# DCSS energy model: each player action costs `player_move_speed`
	# ticks (naga 14, human 10, spriggan 10 but with mutations/haste
	# modifiers), and every monster accumulates that many energy points
	# scaled by its speed / 10. Net effect: walking naga lets a bat
	# swing 4 times before it moves a tile, a haste-12 player slightly
	# outpaces a standard orc.
	var monster_speed: int = int(data.speed) if data else 10
	var player_ticks: int = 10
	var tree: SceneTree = get_tree()
	if tree != null:
		var p: Node = tree.get_first_node_in_group("player")
		if p != null:
			# Movement baseline: race move_speed_mod shifts the per-step tick
			# cost. Overridden by last_action_ticks when the player's previous
			# action was a heavy swing (greatsword delay 1.7 → 17 ticks).
			if "race_res" in p and p.race_res != null:
				player_ticks = 10 + int(p.race_res.move_speed_mod)
			if "last_action_ticks" in p:
				player_ticks = max(player_ticks, int(p.last_action_ticks))
	_action_energy += monster_speed * player_ticks / 10
	while is_alive and _action_energy >= 10:
		var prev_pos: Vector2i = grid_pos
		var action_cost: int = 10
		if boss_ai != null:
			var p: Node = get_tree().get_first_node_in_group("player")
			boss_ai.act(self, p)
		else:
			# MonsterAI.act now returns the DCSS mon_energy_usage cost for
			# the action it took (move=10 default, naga move=14, bat
			# move=5, spell=10, etc.) — slow monsters actually lag.
			action_cost = MonsterAI.act(self)
		if _sprite and grid_pos != prev_pos:
			_sprite.face_toward(grid_pos - prev_pos)
		_action_energy -= maxi(1, action_cost)
		# DCSS / ASCII render modes skip LPC sprite loading entirely
		# (Monster._load_sprite returns early when TileRenderer.is_dcss()
		# or .is_ascii()). Guard the anim call so a no-sprite monster
		# doesn't crash its own turn.
		if _sprite:
			_sprite.play_anim("walk", true)
		# Reuse a single SceneTreeTimer reference per monster — each turn
		# overwrites the previous one. Connecting only when not already
		# connected avoids piling up lambdas (was a per-turn allocation that
		# kept _sprite captured and could fire after queue_free).
		_walk_timer = get_tree().create_timer(0.2)
		_walk_timer.timeout.connect(_return_to_idle, CONNECT_ONE_SHOT)


func _return_to_idle() -> void:
	if is_alive and _sprite:
		_sprite.play_anim("idle", true)


func get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func attack_animation_toward(target_grid: Vector2i) -> void:
	if _sprite != null:
		_sprite.face_toward(target_grid - grid_pos)
		_sprite.play_anim("slash", false)


## Used by MonsterAI._move_to — updates grid_pos AND tweens the visual.
## Tween starts after a small interval so the monster's slide doesn't visually
## overlap with the player's still-finishing move tween.
func move_to_grid(pos: Vector2i) -> void:
	grid_pos = pos
	var target_px: Vector2 = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_interval(0.08)  # let player tween finish first
	_move_tween.tween_property(self, "position", target_px, _MOVE_TWEEN_DUR)


func _draw() -> void:
	if _has_preset:
		if is_sleeping:
			_draw_sleep_indicator(Vector2(32, 32))
		return
	# ASCII mode: draw the DCSS console glyph.
	if TileRenderer.is_ascii() and data != null:
		var entry: Array = TileRenderer.ascii_monster(String(data.id))
		TileRenderer.draw_ascii_glyph(self, Vector2.ZERO, 32,
				String(entry[0]), entry[1])
		_draw_hp_bar(Vector2(32, 32))
		if is_sleeping:
			_draw_sleep_indicator(Vector2(32, 32))
		return
	# DCSS mode: render the monster's tile texture centred on the entity.
	if TileRenderer.is_dcss() and data != null:
		var tex: Texture2D = TileRenderer.monster(String(data.id))
		if tex != null:
			var sz: Vector2 = tex.get_size()
			draw_texture(tex, -sz * 0.5)
			_draw_hp_bar(sz)
			if is_sleeping:
				_draw_sleep_indicator(sz)
			return
	# LPC fallback / generic colored disc.
	var color: Color
	var tier: int = data.tier if data != null else 1
	if tier <= 1:
		color = Color(0.7, 0.7, 0.7)
	elif tier == 2:
		color = Color(0.6, 0.4, 0.2)
	else:
		color = Color(0.85, 0.15, 0.15)
	draw_circle(Vector2.ZERO, 10.0, color)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color.BLACK, 1.0)


## Small "Z" over a sleeping monster's head so the player can tell at a
## glance which enemies haven't spotted them yet. Doesn't render a font —
## just a stylised Z traced with draw_line, which works in every render
## mode without extra assets.
func _draw_sleep_indicator(sprite_sz: Vector2) -> void:
	var top_y: float = -sprite_sz.y * 0.5 - 6.0
	var x0: float = sprite_sz.x * 0.2
	var x1: float = sprite_sz.x * 0.45
	var y_hi: float = top_y
	var y_lo: float = top_y + 6.0
	var color := Color(0.6, 0.85, 1.0, 0.9)
	var w: float = 1.5
	draw_line(Vector2(x0, y_hi), Vector2(x1, y_hi), color, w)
	draw_line(Vector2(x1, y_hi), Vector2(x0, y_lo), color, w)
	draw_line(Vector2(x0, y_lo), Vector2(x1, y_lo), color, w)


func _draw_hp_bar(sprite_sz: Vector2) -> void:
	if data == null or data.hp <= 0:
		return
	var meta_node: Node = get_tree().root.get_node_or_null("MetaProgression")
	if meta_node == null:
		meta_node = get_tree().root.get_node_or_null("Game/MetaProgression")
	if meta_node == null or not meta_node.has_method("shows_monster_hp"):
		return
	if not meta_node.shows_monster_hp():
		return
	if not meta_node.is_registered(String(data.id)):
		return
	var bar_w: float = sprite_sz.x * 0.8
	var bar_h: float = 3.0
	var bar_y: float = sprite_sz.y * 0.5 + 2.0
	var ratio: float = clampf(float(hp) / float(data.hp), 0.0, 1.0)
	var bg_rect := Rect2(-bar_w * 0.5, bar_y, bar_w, bar_h)
	draw_rect(bg_rect, Color(0.15, 0.15, 0.15, 0.8), true)
	var fill_rect := Rect2(-bar_w * 0.5, bar_y, bar_w * ratio, bar_h)
	var bar_color: Color = Color(0.2, 0.9, 0.2) if ratio > 0.5 else (Color(1.0, 0.8, 0.1) if ratio > 0.25 else Color(1.0, 0.15, 0.1))
	draw_rect(fill_rect, bar_color, true)
