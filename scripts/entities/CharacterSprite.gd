class_name CharacterSprite
extends Node2D
## Wraps an AnimatedSprite2D child "Anim" and drives LPC-composited sheets.
##
## Preset schema (from tools/characters/*.json or assets/characters/*.json):
## {
##   "body_def":     "body_human_male" | "body_muscular" | "body_zombie" ...
##   "body_variant": "light" | "tanned" | ...
##   "skin_tint":    "peach"  (optional; maps to LPCSpriteLoader.SKIN_TONE_TINT)
##   "equipment": [
##     {"def": "longsword",  "variant": "steel"},
##     {"def": "hair_buzzcut", "variant": "dark brown"},
##     ...
##   ]
## }

@export var tile_size: int = 32

@onready var _anim: AnimatedSprite2D = $Anim

var _direction: String = "down"
var _current_anim: String = "idle"
var _loader: LPCSpriteLoader
var _preset: Dictionary = {}

const _HAIR_COLOR_TO_LPC := {
	"dark brown": "brown",
	"black":      "black",
	"blonde":     "blonde",
	"redhead":    "red",
	"red":        "red",
	"gray":       "gray",
	"white":      "white",
}


func _ready() -> void:
	_loader = LPCSpriteLoader.new()
	# Scale 64px frame → 32px tile; y offset lifts feet onto tile floor.
	# LPC frame feet sit near y=60 of a 64-tall frame; halved that's y=30.
	# Our sprite is centered; offset -8 pushes the feet to the tile's bottom edge.
	if _anim:
		_anim.scale = Vector2(0.5, 0.5)
		_anim.centered = true
		_anim.offset = Vector2(0, -8)
	if _anim and not _anim.animation_finished.is_connected(_on_anim_finished):
		_anim.animation_finished.connect(_on_anim_finished)


## Build SpriteFrames from preset dict and attach to AnimatedSprite2D.
func load_character(preset: Dictionary) -> void:
	_preset = preset
	if _loader == null:
		_loader = LPCSpriteLoader.new()

	var body_def: String = String(preset.get("body_def", "body_human_male"))
	var body_type: String = "feminine" if body_def.find("female") != -1 else "masculine"
	if body_def.find("muscular") != -1:
		body_type = "masculine"

	var appearance := {
		"body_type":  body_type,
		"skin_tone":  String(preset.get("skin_tint", preset.get("body_variant", "peach"))),
		"hair_style": "parted",
		"hair_color": "brown",
	}

	var equipped: Array = []
	var equipment: Array = preset.get("equipment", [])
	# Also populate PlayerData.inventory.equipped so LPCSpriteLoader can read
	# the material (variant) of each equipped item.
	var equipped_dict: Dictionary = {}

	for entry in equipment:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var def_id: String = String(entry.get("def", ""))
		var variant: String = String(entry.get("variant", ""))
		if def_id == "":
			continue
		if def_id.begins_with("hair_"):
			appearance["hair_style"] = def_id.substr(5)
			if variant != "":
				appearance["hair_color"] = _HAIR_COLOR_TO_LPC.get(variant, variant)
			continue
		equipped.append(def_id)
		equipped_dict[def_id] = {"id": def_id, "material": variant}

	# Expose equipped variants via PlayerData stub for _material_of() lookup.
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		var pd := tree.root.get_node_or_null("PlayerData")
		if pd != null:
			pd.inventory = _InventoryLike.new(equipped_dict)

	var frames: SpriteFrames = _loader.create_player_frames(appearance, equipped)
	if frames == null:
		push_error("CharacterSprite: create_player_frames returned null for preset %s" % preset)
		return
	if _anim == null:
		_anim = get_node_or_null("Anim")
	if _anim:
		_anim.sprite_frames = frames
		_play_current()


## Direction: "up", "down", "left", "right".
func set_direction(dir: String) -> void:
	if dir not in ["up", "down", "left", "right"]:
		return
	_direction = dir
	_play_current()


func face_toward(grid_delta: Vector2i) -> void:
	if grid_delta == Vector2i.ZERO:
		return
	if abs(grid_delta.x) >= abs(grid_delta.y):
		set_direction("right" if grid_delta.x > 0 else "left")
	else:
		set_direction("down" if grid_delta.y > 0 else "up")


## LPC anim ids used by the loader: idle / walk / attack (slash) / shoot / hurt / death.
## We accept game-level names and translate.
func play_anim(anim: String, loop: bool = true) -> void:
	_current_anim = _translate_anim(anim)
	_play_current(loop)


func _translate_anim(a: String) -> String:
	match a:
		"walk":      return "walk"
		"idle":      return "idle"
		"slash", "attack", "thrust": return "attack"
		"shoot":     return "shoot"
		"hurt":      return "hurt"
		"die", "death": return "death"
		"spellcast": return "attack"  # no spellcast sheet — fallback
	return a


func _play_current(_loop: bool = true) -> void:
	if _anim == null or _anim.sprite_frames == null:
		return
	var name := "%s_%s" % [_current_anim, _direction]
	if not _anim.sprite_frames.has_animation(name):
		name = _current_anim  # fallback to direction-less
	if not _anim.sprite_frames.has_animation(name):
		return
	_anim.play(name)


func _on_anim_finished() -> void:
	# Non-looping one-shots return to idle.
	if _current_anim in ["attack", "hurt", "shoot", "death"]:
		if _current_anim == "death":
			return  # stay on last frame
		_current_anim = "idle"
		_play_current()


# --- tiny helper to masquerade as PlayerData.inventory ---
class _InventoryLike:
	var equipped: Dictionary = {}
	func _init(eq: Dictionary) -> void:
		equipped = eq
