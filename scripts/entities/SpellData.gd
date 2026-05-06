class_name SpellData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var school: String = ""      # fire / cold / air / earth / necromancy / hexes / translocation / summoning
@export var spell_level: int = 1     # 1–9 (SRD spell slot level)
@export var xl_required: int = 1     # minimum player XL to cast
@export var mp_cost: int = 2
@export var difficulty: int = 1
@export var base_damage: int = 0
@export var max_range: int = 5
@export var targeting: String = "single"
@export var element: String = ""
@export var effect: String = "damage"
@export var description: String = ""
@export var icon_path: String = ""


## Localized display name. Falls back to the .tres display_name if the
## translation key isn't registered (graceful for new content not yet
## translated). Key convention: SPELL_NAME_<UPPER_ID>.
func loc_name() -> String:
	if id == "":
		return display_name
	var key: String = "SPELL_NAME_" + id.to_upper()
	var translated: String = TranslationServer.translate(key)
	return translated if translated != key else display_name

## Localized description. Same fallback contract as loc_name().
func loc_description() -> String:
	if id == '':
		return description
	var key: String = 'SPELL_DESC_' + id.to_upper()
	var translated: String = TranslationServer.translate(key)
	return translated if translated != key else description
