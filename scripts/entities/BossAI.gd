class_name BossAI
## Turn-based boss pattern AI. Each boss cycles through a repeating pattern
## of NORMAL → TELEGRAPH → EXECUTE phases. On TELEGRAPH turns the boss
## announces its next big attack and (optionally) marks danger tiles.
## On EXECUTE turns it deals heavy damage to everything on those tiles.
##
## Only the first boss (ogre) shows visible floor markers. Later bosses
## telegraph via log message only — players must learn the patterns.

enum Phase { NORMAL, TELEGRAPH, EXECUTE }

const PATTERNS: Dictionary = {
	"ogre": {
		"cycle": 3,
		"telegraph_msg": "Ogre winds up a massive slam!",
		"execute_msg": "Ogre SLAMS the ground!",
		"show_tiles": true,
		"shape": "adjacent",
		"damage_mult": 2.5,
	},
	"orc_knight": {
		"cycle": 3,
		"telegraph_msg": "Orc Knight raises his shield!",
		"execute_msg": "Orc Knight shield-bashes!",
		"show_tiles": false,
		"shape": "line_toward_player",
		"damage_mult": 2.0,
	},
	"dryad": {
		"cycle": 4,
		"telegraph_msg": "Dryad summons grasping vines!",
		"execute_msg": "Vines erupt from the ground!",
		"show_tiles": false,
		"shape": "cross",
		"damage_mult": 1.5,
	},
	"swamp_dragon": {
		"cycle": 3,
		"telegraph_msg": "Swamp Dragon inhales deeply!",
		"execute_msg": "Swamp Dragon unleashes a toxic breath!",
		"show_tiles": false,
		"shape": "breath_line",
		"damage_mult": 3.0,
	},
	"fire_dragon": {
		"cycle": 3,
		"telegraph_msg": "Fire Dragon's chest glows white-hot!",
		"execute_msg": "Fire Dragon erupts in flames!",
		"show_tiles": false,
		"shape": "burst_3x3",
		"damage_mult": 3.5,
	},
}

var boss_id: String = ""
var turn_counter: int = 0
var phase: int = Phase.NORMAL
var danger_tiles: Array[Vector2i] = []
var _pattern: Dictionary = {}


func setup(id: String) -> void:
	boss_id = id
	_pattern = PATTERNS.get(id, {})
	turn_counter = 0
	phase = Phase.NORMAL
	danger_tiles.clear()


func act(monster: Node, player: Node) -> void:
	if _pattern.is_empty() or player == null:
		_basic_melee(monster, player)
		return

	var cycle: int = int(_pattern.get("cycle", 3))
	turn_counter += 1
	var cycle_pos: int = turn_counter % cycle

	if cycle_pos == cycle - 1:
		phase = Phase.TELEGRAPH
		_step_toward_player(monster, player)
		_do_telegraph(monster, player)
	elif cycle_pos == 0:
		phase = Phase.EXECUTE
		_do_execute(monster, player)
		_step_toward_player(monster, player)
	else:
		phase = Phase.NORMAL
		danger_tiles.clear()
		_step_toward_player(monster, player)


func _do_telegraph(monster: Node, player: Node) -> void:
	danger_tiles.clear()
	var shape: String = String(_pattern.get("shape", "adjacent"))
	var boss_pos: Vector2i = monster.grid_pos
	var player_pos: Vector2i = player.grid_pos

	match shape:
		"adjacent":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					danger_tiles.append(boss_pos + Vector2i(dx, dy))
		"line_toward_player":
			var dir: Vector2i = Vector2i(sign(player_pos.x - boss_pos.x), sign(player_pos.y - boss_pos.y))
			for i in range(1, 5):
				danger_tiles.append(boss_pos + dir * i)
		"cross":
			for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
				for i in range(1, 4):
					danger_tiles.append(boss_pos + d * i)
		"breath_line":
			var dir2: Vector2i = Vector2i(sign(player_pos.x - boss_pos.x), sign(player_pos.y - boss_pos.y))
			for i in range(1, 7):
				var center: Vector2i = boss_pos + dir2 * i
				danger_tiles.append(center)
				var perp: Vector2i = Vector2i(-dir2.y, dir2.x)
				if perp != Vector2i.ZERO:
					danger_tiles.append(center + perp)
					danger_tiles.append(center - perp)
		"burst_3x3":
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					danger_tiles.append(boss_pos + Vector2i(dx, dy))

	var msg: String = String(_pattern.get("telegraph_msg", "The boss prepares an attack!"))
	print(msg)


func _do_execute(monster: Node, player: Node) -> void:
	var mult: float = float(_pattern.get("damage_mult", 2.0))
	var base_dmg: int = int(monster.data.str) / 2 + 3 if monster.data != null else 8
	var dmg: int = int(float(base_dmg) * mult)

	if danger_tiles.has(player.grid_pos):
		player.take_damage(dmg)
		var msg: String = String(_pattern.get("execute_msg", "BOOM!"))
		print("%s %d damage!" % [msg, dmg])
	else:
		print("You dodged the attack!")

	danger_tiles.clear()
	phase = Phase.NORMAL


func _step_toward_player(monster: Node, player: Node) -> void:
	var dx: int = sign(player.grid_pos.x - monster.grid_pos.x)
	var dy: int = sign(player.grid_pos.y - monster.grid_pos.y)
	var candidates: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		candidates.append(Vector2i(dx, dy))
	if dx != 0:
		candidates.append(Vector2i(dx, 0))
	if dy != 0:
		candidates.append(Vector2i(0, dy))
	for delta in candidates:
		var nxt: Vector2i = monster.grid_pos + delta
		if monster.generator != null and monster.generator.is_walkable(nxt):
			if _cheb(nxt, player.grid_pos) <= 1:
				_basic_melee(monster, player)
				return
			monster.move_to_grid(nxt)
			return
	if _cheb(monster.grid_pos, player.grid_pos) <= 1:
		_basic_melee(monster, player)


func _basic_melee(monster: Node, player: Node) -> void:
	if player == null or not ("grid_pos" in player):
		return
	if _cheb(monster.grid_pos, player.grid_pos) > 1:
		_step_toward_player(monster, player)
		return
	var base_atk: int = int(monster.data.str) / 2 + 3 if monster.data != null else 5
	var dmg: int = max(1, base_atk - player.ac + randi_range(-2, 2))
	player.take_damage(dmg)


func shows_danger_tiles() -> bool:
	return phase == Phase.TELEGRAPH and bool(_pattern.get("show_tiles", false))


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
