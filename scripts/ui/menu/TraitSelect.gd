extends Control

const GAME_PATH := "res://scenes/main/Game.tscn"
const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"

## Mobile/Pixel-Dungeon-style trait picks layered on top of DCSS backgrounds.
## Each DCSS job offers 4 thematic trait cards that nudge early build
## direction without replacing DCSS's skill system.
const JOB_TRAITS: Dictionary = {
	# Warrior
	"fighter":         ["sword", "polearm_trait", "shield_trait", "heavy_armor"],
	"gladiator":       ["sword", "throwing_trait", "shield_trait", "scout"],
	"monk":            ["brawler", "acrobat", "shield_trait", "scout"],
	"hunter":          ["bow_trait", "crossbow_trait", "throwing_ranger", "scout"],
	"brigand":         ["dagger_trait", "acrobat", "shadow", "throwing_trait"],
	# Adventurer
	"artificer":       ["evoker", "scout", "shield_trait", "heavy_armor"],
	"shapeshifter":    ["brawler", "acrobat", "scout", "shadow"],
	"wanderer":        ["sword", "brawler", "fire", "scout"],
	"delver":          ["dagger_trait", "acrobat", "shadow", "scout"],
	# Zealot
	"berserker":       ["axe_trait", "mace_trait", "brawler", "heavy_armor"],
	"chaos_knight":    ["axe_trait", "sword", "heavy_armor", "shield_trait"],
	"cinder_acolyte":  ["fire", "mace_trait", "brawler", "heavy_armor"],
	# Warrior-mage
	"warper":          ["warper", "dagger_trait", "throwing_trait", "scout"],
	"hexslinger":      ["hexer", "bow_trait", "dagger_trait", "fire"],
	"enchanter":       ["hexer", "dagger_trait", "shadow", "arcane"],
	"reaver":          ["arcane", "sword", "ice", "heavy_armor"],
	# Mage
	"hedge_wizard":    ["fire", "ice", "earth", "air"],
	"conjurer":        ["arcane", "fire", "ice", "air"],
	"summoner":        ["arcane", "necro", "hexer", "scout"],
	"necromancer":     ["necro", "hexer", "arcane", "shadow"],
	"fire_elementalist":  ["fire", "arcane", "hexer", "scout"],
	"ice_elementalist":   ["ice", "arcane", "hexer", "scout"],
	"air_elementalist":   ["air", "arcane", "warper", "scout"],
	"earth_elementalist": ["earth", "arcane", "mace_trait", "heavy_armor"],
	"alchemist":       ["necro", "fire", "hexer", "scout"],
	"forgewright":     ["earth", "mace_trait", "arcane", "heavy_armor"],
}

var _selected_id: String = ""
var _cards: Dictionary = {}


func _ready() -> void:
	theme = GameTheme.create()
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/StartButton.pressed.connect(_on_start)
	$Footer/StartButton.disabled = true
	var job_id: String = GameManager.selected_job_id
	$Title.text = "Choose a Trait — %s" % job_id.capitalize()
	_build_cards(job_id)


func _build_cards(job_id: String) -> void:
	var grid: GridContainer = $Scroll/Grid
	var trait_ids: Array = JOB_TRAITS.get(job_id, ["tough", "fierce", "swift", "armored"])
	for tid in trait_ids:
		var path: String = "res://resources/traits/%s.tres" % tid
		if not ResourceLoader.exists(path):
			continue
		var tdata: TraitData = load(path)
		if tdata == null:
			continue
		var card := _make_card(tdata)
		grid.add_child(card)
		_cards[tid] = card


func _make_card(t: TraitData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(480, 450)
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.pressed.connect(_on_card_pressed.bind(t.id))

	var parts: Array = []
	parts.append(t.display_name)
	parts.append("")

	var stat_parts: Array = []
	if t.str_bonus != 0: stat_parts.append("STR%+d" % t.str_bonus)
	if t.dex_bonus != 0: stat_parts.append("DEX%+d" % t.dex_bonus)
	if t.int_bonus != 0: stat_parts.append("INT%+d" % t.int_bonus)
	if t.hp_bonus_pct > 0: stat_parts.append("HP+%d%%" % int(t.hp_bonus_pct * 100))
	if t.mp_bonus_pct > 0: stat_parts.append("MP+%d%%" % int(t.mp_bonus_pct * 100))
	if t.ac_bonus > 0: stat_parts.append("AC+%d" % t.ac_bonus)
	if not stat_parts.is_empty():
		parts.append("  ".join(stat_parts))
	parts.append("")
	parts.append(t.description)

	if not t.starting_spells.is_empty():
		parts.append("")
		parts.append("Spells: %s" % ", ".join(PackedStringArray(t.starting_spells)))

	btn.text = "\n".join(PackedStringArray(parts))
	btn.add_theme_font_size_override("font_size", 40)
	return btn


func _on_card_pressed(trait_id: String) -> void:
	if _selected_id == trait_id:
		_selected_id = ""
		$Footer/StartButton.disabled = true
	else:
		_selected_id = trait_id
		$Footer/StartButton.disabled = false
	for tid in _cards.keys():
		var b: Button = _cards[tid]
		b.button_pressed = (tid == _selected_id)


func _on_back() -> void:
	get_tree().change_scene_to_file(JOB_SELECT_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_trait_id = _selected_id
	get_tree().change_scene_to_file(GAME_PATH)
