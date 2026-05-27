extends Node
class_name TalentSystem

const DEFAULT_TALENT_ID: String = "veteran"

const TALENTS: Dictionary = {
	"veteran": {
		"name": "Veteran",
		"short": "Battle-hardened frontliner.",
		"desc": "Starts with stronger melee instincts and a sturdier frame.",
		"color": Color(0.92, 0.78, 0.35, 1.0),
		"str": 1, "dex": 0, "int": 0, "hp": 6, "mp": 0,
		"skill_apts": {"weapon_mastery": 2, "tactics": 2},
	},
	"scout": {
		"name": "Scout",
		"short": "Quiet eyes and quick feet.",
		"desc": "Starts with sharper senses and better survival instincts.",
		"color": Color(0.48, 0.84, 0.64, 1.0),
		"str": 0, "dex": 1, "int": 0, "hp": 2, "mp": 0,
		"skill_apts": {"stealth": 2, "tracking": 2},
	},
	"adept": {
		"name": "Adept",
		"short": "A practical student of the arcane.",
		"desc": "Starts with stronger spellcraft and a clearer mind.",
		"color": Color(0.72, 0.56, 0.98, 1.0),
		"str": 0, "dex": 0, "int": 2, "hp": 0, "mp": 4,
		"skill_apts": {"magery": 3},
	},
}

static func ids_in_order() -> Array:
	return ["veteran", "scout", "adept"]

static func get_talent(talent_id: String) -> Dictionary:
	if TALENTS.has(talent_id):
		return TALENTS[talent_id]
	return TALENTS[DEFAULT_TALENT_ID]

static func display_name(talent_id: String) -> String:
	return String(get_talent(talent_id).get("name", DEFAULT_TALENT_ID.capitalize()))

static func short_text(talent_id: String) -> String:
	return String(get_talent(talent_id).get("short", ""))

static func description_text(talent_id: String) -> String:
	return String(get_talent(talent_id).get("desc", ""))

static func color(talent_id: String) -> Color:
	return get_talent(talent_id).get("color", Color.WHITE)

static func bonus_lines(talent_id: String) -> PackedStringArray:
	var data: Dictionary = get_talent(talent_id)
	var lines: PackedStringArray = []
	for stat_key in ["str", "dex", "int"]:
		var value: int = int(data.get(stat_key, 0))
		if value != 0:
			lines.append("%s %+d" % [stat_key.to_upper(), value])
	var hp: int = int(data.get("hp", 0))
	if hp != 0:
		lines.append("HP %+d" % hp)
	var mp: int = int(data.get("mp", 0))
	if mp != 0:
		lines.append("MP %+d" % mp)
	var apts: Dictionary = data.get("skill_apts", {})
	for sid in apts.keys():
		var apt: int = int(apts[sid])
		var pct: int = int((pow(1.2, apt) - 1.0) * 100.0)
		lines.append("%s +%d%% XP" % [String(sid).replace("_", " ").capitalize(), pct])
	return lines

static func apply(player, talent_id: String) -> void:
	if player == null:
		return
	var data: Dictionary = get_talent(talent_id)
	var str_bonus: int = int(data.get("str", 0))
	var dex_bonus: int = int(data.get("dex", 0))
	var int_bonus: int = int(data.get("int", 0))
	if str_bonus != 0:
		player.strength = max(1, player.strength + str_bonus)
	if dex_bonus != 0:
		player.dexterity = max(1, player.dexterity + dex_bonus)
	if int_bonus != 0:
		player.intelligence = max(1, player.intelligence + int_bonus)
	var hp_bonus: int = int(data.get("hp", 0))
	if hp_bonus != 0:
		player._apply_max_hp_gain(hp_bonus)
	var mp_bonus: int = int(data.get("mp", 0))
	if mp_bonus != 0:
		player._apply_max_mp_gain(mp_bonus)
	# skill_apts are applied at XP-grant time via _skill_apt_mult — no upfront grant needed.
	if player.has_method("refresh_ac_from_equipment"):
		player.refresh_ac_from_equipment()
