class_name MonsterData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var hp: int = 10
@export var hd: int = 1
@export var ac: int = 0
@export var ev: int = 5
@export var speed: int = 10
@export var sight_range: int = 8
@export var attacks: Array = []
@export var ranged_attack: Dictionary = {}  # {damage, range, verb, flavour}
@export var resists: Array = []
@export var min_depth: int = 1
@export var max_depth: int = 25
@export var weight: int = 10
@export var xp_value: int = 1
@export var is_boss: bool = false
@export var is_unique: bool = false
@export var drop_chance_override: float = -1.0
@export var tile_path: String = ""
@export var glyph: String = "r"
@export var glyph_color: Color = Color(0.8, 0.8, 0.8)
@export var description: String = ""
@export var essence_id: String = ""   # legacy single drop; prefer essence_ids
@export var essence_ids: Array = []   # pool of 2-3 essences; one is picked randomly on drop
@export var body_type: String = "humanoid"
@export var ai_flags: Array = []      # ["kite", "healer", "summoner"]
@export var summon_pool: Array = []   # summoner: monster ids to spawn
@export var gold_drop_max: int = 0   # humanoid gold carry; 0 = no drop


## Localized display name. Falls back to the .tres display_name if the
## translation key isn't registered (graceful for new content not yet
## translated). Key convention: MONSTER_NAME_<UPPER_ID>.
func loc_name() -> String:
	if id == "":
		return display_name
	var key: String = "MONSTER_NAME_" + id.to_upper()
	var translated: String = TranslationServer.translate(key)
	return translated if translated != key else display_name

## Localized description. Same fallback contract as loc_name().
func loc_description() -> String:
	if id == '':
		return description
	var key: String = 'MONSTER_DESC_' + id.to_upper()
	var translated: String = TranslationServer.translate(key)
	return translated if translated != key else description
