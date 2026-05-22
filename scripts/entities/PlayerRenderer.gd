class_name PlayerRenderer extends Node2D

## ULPC sprite rendering for the Player entity.
## Added as a child of Player in Player._ready().
## Local position stays Vector2.ZERO — inherits parent world position automatically.

const DEFAULT_BASE_TEX: Texture2D = preload(
	"res://assets/tiles/individual/player/base/human_m.png")

## Paper-doll layer lookup tables. When equipped item id matches a key,
## the corresponding sprite is drawn on top of the base race sprite.
const DOLL_BODY_MAP: Dictionary = {
	"leather_armor": "res://assets/tiles/individual/player/body/leather_armour.png",
	"chain_mail": "res://assets/tiles/individual/player/body/chainmail.png",
	"robe": "res://assets/tiles/individual/player/body/robe_blue.png",
}

const DOLL_HAND2_MAP: Dictionary = {
	"buckler": "res://assets/tiles/individual/player/hand2/buckler_round.png",
	"round_shield": "res://assets/tiles/individual/player/hand2/doll_only/kite_shield_round1.png",
	"tower_shield": "res://assets/tiles/individual/player/hand2/tower_shield_teal.png",
}

const DOLL_HAND1_MAP: Dictionary = {
	"short_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"mace": "res://assets/tiles/individual/player/hand1/mace.png",
	"long_sword": "res://assets/tiles/individual/player/hand1/long_sword_slant.png",
	"arming_sword": "res://assets/tiles/individual/player/hand1/long_sword_slant2.png",
	"bastard_sword": "res://assets/tiles/individual/player/hand1/heavy_sword.png",
	"great_blade": "res://assets/tiles/individual/player/hand1/great_sword_slant.png",
	"battle_axe": "res://assets/tiles/individual/player/hand1/battleaxe.png",
	"spear": "res://assets/tiles/individual/player/hand1/spear.png",
	"shortbow": "res://assets/tiles/individual/player/hand1/shortbow.png",
	"longbow": "res://assets/tiles/individual/player/hand1/great_bow.png",
	"crossbow": "res://assets/tiles/individual/player/hand1/arbalest.png",
	"staff": "res://assets/tiles/individual/player/hand1/staff.png",
	"flaming_sword": "res://assets/tiles/individual/player/hand1/short_sword.png",
	"frost_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"venom_dagger": "res://assets/tiles/individual/player/hand1/dagger.png",
	"shock_mace": "res://assets/tiles/individual/player/hand1/mace.png",
	"dirk": "res://assets/tiles/individual/player/hand1/athame.png",
	"stiletto": "res://assets/tiles/individual/player/hand1/dagger.png",
	"quick_blade": "res://assets/tiles/individual/player/hand1/sword_thief.png",
	"assassin_blade": "res://assets/tiles/individual/player/hand1/dagger.png",
}

const _WALK_FPS: float = 18.0             # 9 frames / 18 fps ≈ 0.5s per step
const _ATTACK_FPS: float = 14.0
const _ATTACK_FRAMES: Dictionary = {"slash": 6, "thrust": 8, "spellcast": 7}
## Weapon base_id → attack animation type. Unlisted weapons default to "slash".
const _WEAPON_ATTACK_ANIM: Dictionary = {
	"mace": "thrust", "shock_mace": "thrust",
	"spear": "thrust", "javelin": "thrust", "staff": "thrust",
}

# ULPC 64x64 frame: character occupies y=14(head)..61(feet) = 48px
const _ULPC_CHAR_TOP: float = 14.0
const _ULPC_CHAR_H: float = 48.0

const _ULPC_ROOT: String = "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/"

# Per-race body sheet (relative to _ULPC_ROOT).
const _RACE_BODY_MAP: Dictionary = {
	"human":    "body/bodies/male/walk.png",
	"elf":      "body/bodies/teen/walk.png",
	"dwarf":    "body/bodies/male/walk.png",
	"hill_orc": "body/bodies/muscular/walk.png",
	"troll":    "body/bodies/muscular/walk.png",
	"vampire":  "body/bodies/male/walk.png",
	"minotaur": "body/bodies/muscular/walk.png",
	"kobold":   "body/bodies/child/walk.png",
	"spriggan": "body/bodies/child/walk.png",
	"gargoyle": "body/bodies/male/walk.png",
}

# Per-race always-on overlays: head, ears, hair (relative to _ULPC_ROOT).
const _RACE_HEAD_OVERLAYS: Dictionary = {
	"human": [
		"head/heads/human/male/walk.png",
		"hair/plain/adult/walk/ash.png",
	],
	"elf": [
		"head/heads/human/male/walk.png",
		"head/ears/elven/adult/walk.png",
		"hair/plain/adult/walk/ash.png",
	],
	"dwarf": [
		"head/heads/human/male/walk.png",
		"hair/plain/adult/walk/ash.png",
	],
	"hill_orc": [
		"head/heads/orc/male/walk.png",
	],
	"troll": [
		"head/heads/troll/adult/walk.png",
	],
	"vampire": [
		"head/heads/vampire/adult/walk.png",
		"hair/plain/adult/walk/ash.png",
	],
	"minotaur": [
		"head/heads/minotaur/male/walk.png",
	],
	"kobold": [
		"head/heads/goblin/adult/walk.png",
	],
	"spriggan": [
		"head/heads/human/child/walk.png",
		"hair/plain/adult/walk/ash.png",
	],
	"gargoyle": [
		"head/heads/lizard/male/walk.png",
		"body/wings/bat/lizard/adult/bg/walk.png",
	],
}

const _WEAPON_OVERLAY_MAP: Dictionary = {
	"dagger":         "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"dirk":           "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"stiletto":       "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"venom_dagger":   "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"frost_dagger":   "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"assassin_blade": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"throwing_knife": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"quick_blade":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/dagger/walk/dagger.png",
	"short_sword":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/longsword/walk/longsword.png",
	"arming_sword":   "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/arming/universal/fg/walk/brass.png",
	"long_sword":     "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/longsword/walk/longsword.png",
	"flaming_sword":  "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/longsword/walk/longsword.png",
	"bastard_sword":  "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/longsword/walk/longsword.png",
	"great_blade":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/sword/longsword/walk/longsword.png",
	"mace":           "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/blunt/mace/walk/mace.png",
	"shock_mace":     "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/blunt/mace/walk/mace.png",
	"battle_axe":     "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/blunt/waraxe/walk/waraxe.png",
	"staff":          "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/magic/simple/foreground/walk/simple.png",
	"spear":          "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/polearm/spear/foreground/walk/iron.png",
	"javelin":        "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/polearm/spear/foreground/walk/iron.png",
	"crossbow":       "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/weapon/ranged/crossbow/foreground/walk/crossbow.png",
}
const _ARMOR_OVERLAY_MAP: Dictionary = {
	"leather_armor": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/armour/leather/male/walk.png",
	"troll_leather": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/armour/leather/male/walk.png",
	"ring_mail":     "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/armour/leather/male/walk.png",
	"scale_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/armour/leather/male/walk.png",
	"chain_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/chainmail/male/walk.png",
	"plate_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/armour/plate/male/walk.png",
	"robe":          "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/torso/clothes/robe/female/walk/black.png",
}
const _LEGS_OVERLAY_MAP: Dictionary = {
	"leather_armor": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/hose/male/walk/black.png",
	"troll_leather": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/hose/male/walk/black.png",
	"ring_mail":     "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/hose/male/walk/black.png",
	"scale_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/hose/male/walk/black.png",
	"chain_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/hose/male/walk/black.png",
	"plate_mail":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/armour/plate/male/walk.png",
	"robe":          "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/legs/pantaloons/male/walk/black.png",
}
const _HELMET_OVERLAY_MAP: Dictionary = {
	"leather_cap":  "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/hat/cloth/leather_cap/adult/walk/base.png",
	"leather_helm": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/hat/cloth/leather_cap/adult/walk/base.png",
	"iron_helm":    "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/hat/helmet/bascinet/adult/walk/iron.png",
	"great_helm":   "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/hat/helmet/bascinet/adult/walk/iron.png",
}
const _GLOVES_OVERLAY_MAP: Dictionary = {
	"leather_gloves": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/arms/gloves/male/walk/leather.png",
	"iron_gauntlets": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/arms/gloves/male/walk/iron.png",
}
const _BOOTS_OVERLAY_MAP: Dictionary = {
	"leather_boots": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/feet/boots/basic/male/walk/iron.png",
	"iron_greaves":  "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/feet/boots/basic/male/walk/iron.png",
}
const _SHIELD_OVERLAY_MAP: Dictionary = {
	"buckler":      "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/shield/crusader/fg/male/walk/crusader.png",
	"round_shield": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/shield/crusader/fg/male/walk/crusader.png",
	"kite_shield":  "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/shield/crusader/fg/male/walk/crusader.png",
	"tower_shield": "res://Universal-LPC-Spritesheet-Character-Generator/spritesheets/shield/crusader/fg/male/walk/crusader.png",
}

const _EQUIP_SHEET_SLOTS: Array[Array] = [
	["equipped_armor_id",  "armor"],
	["equipped_helmet_id", "helmet"],
	["equipped_gloves_id", "gloves"],
	["equipped_boots_id",  "boots"],
	["equipped_weapon_id", "sword"],
	["equipped_shield_id", "shield"],
]

# ── Runtime state ──────────────────────────────────────────────────────────────

var _base_tex: Texture2D = DEFAULT_BASE_TEX
var _body_doll_tex: Texture2D = null
var _hand1_doll_tex: Texture2D = null
var _hand2_doll_tex: Texture2D = null
var _base_sheets: Array[Texture2D] = []   # always-on race overlays: head, hair
var _equip_sheets: Array[Texture2D] = []  # equipment-conditional overlays
var _walk_frame: int = 0                  # current column in ULPC walk cycle (0-8)
var _walk_anim_t: float = 0.0             # time accumulator for walk animation
var _walk_anim_active: bool = false

var _attack_frame: int = 0
var _attack_anim_t: float = 0.0
var _attack_anim_active: bool = false
var _attack_anim_type: String = "slash"   # "slash" | "thrust" | "spellcast"
var _atk_base: Dictionary = {}            # {anim: Texture2D}
var _atk_sheets: Dictionary = {}          # {anim: Array[Texture2D]} (head+hair+equip)

# ── Public API ─────────────────────────────────────────────────────────────────

## Rebuild all paperdoll/ULPC textures from the player's current equipment and race.
## Called by Player._on_equipment_changed() and set_race_from_id().
func refresh_equipment(player: Player) -> void:
	_body_doll_tex = null
	_hand1_doll_tex = null
	_hand2_doll_tex = null
	var ItemRegistry = get_node_or_null("/root/ItemRegistry")
	var GameManager = get_node_or_null("/root/GameManager")
	# Load ULPC body base — race-specific
	var race_id: String = GameManager.selected_race_id if GameManager != null else "human"
	var body_rel: String = _RACE_BODY_MAP.get(race_id, "body/bodies/male/walk.png")
	_base_tex = load_ulpc_tex(_ULPC_ROOT + body_rel)
	var armor_base_id: String = ItemRegistry.base_id_of(player.equipped_armor_id) if ItemRegistry != null else player.equipped_armor_id
	if DOLL_BODY_MAP.has(armor_base_id):
		var body_path: String = String(DOLL_BODY_MAP[armor_base_id])
		if ResourceLoader.exists(body_path):
			_body_doll_tex = load(body_path) as Texture2D
	var weapon_base_id: String = ItemRegistry.base_id_of(player.equipped_weapon_id) if ItemRegistry != null else player.equipped_weapon_id
	if DOLL_HAND1_MAP.has(weapon_base_id):
		var path: String = String(DOLL_HAND1_MAP[weapon_base_id])
		if ResourceLoader.exists(path):
			_hand1_doll_tex = load(path) as Texture2D
	var shield_base_id: String = ItemRegistry.base_id_of(player.equipped_shield_id) if ItemRegistry != null else player.equipped_shield_id
	if DOLL_HAND2_MAP.has(shield_base_id):
		var path: String = String(DOLL_HAND2_MAP[shield_base_id])
		if ResourceLoader.exists(path):
			_hand2_doll_tex = load(path) as Texture2D
	# Load always-on base overlays (head, hair) — race-specific
	_base_sheets.clear()
	var head_overlays: Array = _RACE_HEAD_OVERLAYS.get(race_id, _RACE_HEAD_OVERLAYS["human"])
	for rel in head_overlays:
		var btex := load_ulpc_tex(_ULPC_ROOT + rel)
		if btex != null:
			_base_sheets.append(btex)
	# Load equipment overlays from ULPC generator
	_equip_sheets.clear()
	for pair in _EQUIP_SHEET_SLOTS:
		var slot_val: String = player.get(pair[0]) if pair[0] in player else ""
		if slot_val == "":
			continue
		var base_id: String = ItemRegistry.base_id_of(slot_val) if ItemRegistry != null else slot_val
		var item_data: ItemData = ItemRegistry.get_by_id(slot_val) if ItemRegistry != null else null
		var path: String = ""
		if item_data != null and item_data.equip_overlay_path != "":
			path = item_data.equip_overlay_path
		else:
			path = ulpc_overlay_path(pair[1] as String, base_id)
		if path != "":
			var tex := load_ulpc_tex(path)
			if tex != null:
				_equip_sheets.append(tex)
	# Armor slot also adds matching legs overlay
	if player.equipped_armor_id != "":
		var armor_base: String = ItemRegistry.base_id_of(player.equipped_armor_id) if ItemRegistry != null else player.equipped_armor_id
		var legs_path: String = _LEGS_OVERLAY_MAP.get(armor_base, "")
		if legs_path != "":
			var tex := load_ulpc_tex(legs_path)
			if tex != null:
				_equip_sheets.append(tex)
	# Preload attack animation sheets (slash / thrust / spellcast) for body + all overlays
	_atk_base.clear()
	_atk_sheets.clear()
	var body_walk_path := _ULPC_ROOT + body_rel
	for anim in ["slash", "thrust", "spellcast"]:
		var bp := ulpc_attack_path(body_walk_path, anim)
		_atk_base[anim] = load_ulpc_tex(bp) if bp != "" else null
		var sheets: Array[Texture2D] = []
		for rel2 in head_overlays:
			var ap := ulpc_attack_path(_ULPC_ROOT + rel2, anim)
			if ap != "":
				var t := load_ulpc_tex(ap)
				if t != null:
					sheets.append(t)
		for pair in _EQUIP_SHEET_SLOTS:
			var slot_val: String = player.get(pair[0]) if pair[0] in player else ""
			if slot_val == "":
				continue
			var bid: String = ItemRegistry.base_id_of(slot_val) if ItemRegistry != null else slot_val
			var wpath := ulpc_overlay_path(pair[1] as String, bid)
			if wpath == "":
				continue
			var ap := ulpc_attack_path(wpath, anim)
			if ap != "":
				var t := load_ulpc_tex(ap)
				if t != null:
					sheets.append(t)
		if player.equipped_armor_id != "":
			var armor_base2: String = ItemRegistry.base_id_of(player.equipped_armor_id) if ItemRegistry != null else player.equipped_armor_id
			var lw: String = _LEGS_OVERLAY_MAP.get(armor_base2, "")
			if lw != "":
				var ap := ulpc_attack_path(lw, anim)
				if ap != "":
					var t := load_ulpc_tex(ap)
					if t != null:
						sheets.append(t)
		_atk_sheets[anim] = sheets
	queue_redraw()


## Called by Player._try_move() when a step begins. Resets or resumes walk cycle.
func start_walk_anim() -> void:
	if not _walk_anim_active:
		_walk_anim_t = 0.0
	_walk_anim_active = true
	queue_redraw()


func play_attack_anim(weapon_id: String) -> void:
	var GameManager = get_node_or_null("/root/GameManager")
	if GameManager == null or not GameManager.use_tiles:
		return
	var ItemRegistry = get_node_or_null("/root/ItemRegistry")
	var base_id: String = ItemRegistry.base_id_of(weapon_id) if ItemRegistry != null and weapon_id != "" else weapon_id
	var anim: String = String(_WEAPON_ATTACK_ANIM.get(base_id, "slash"))
	if not (_atk_base.has(anim) and _atk_base[anim] != null):
		return
	_attack_anim_type = anim
	_attack_frame = 0
	_attack_anim_t = 0.0
	_attack_anim_active = true
	queue_redraw()


func play_spellcast_anim() -> void:
	var GameManager = get_node_or_null("/root/GameManager")
	if GameManager == null or not GameManager.use_tiles:
		return
	if not (_atk_base.has("spellcast") and _atk_base["spellcast"] != null):
		return
	_attack_anim_type = "spellcast"
	_attack_frame = 0
	_attack_anim_t = 0.0
	_attack_anim_active = true
	queue_redraw()


# ── Static helpers (called externally by Companion, StatusDialog, RaceSelect) ─

static func race_body_path(race_id: String) -> String:
	var rel: String = _RACE_BODY_MAP.get(race_id, "body/bodies/male/walk.png")
	return _ULPC_ROOT + rel

## Returns full res:// paths (with _ULPC_ROOT prepended) — callers never need _ULPC_ROOT.
static func race_head_overlays(race_id: String) -> Array:
	var rels: Array = _RACE_HEAD_OVERLAYS.get(race_id, _RACE_HEAD_OVERLAYS["human"])
	var result: Array = []
	for rel in rels:
		result.append(_ULPC_ROOT + rel)
	return result

## Build a full res:// path for a hair color variant (plain style, adult walk).
## Returns "" if the file does not exist.
static func hair_plain_path(color: String) -> String:
	var p := _ULPC_ROOT + "hair/plain/adult/walk/" + color + ".png"
	return p if ulpc_file_exists(p) else ""

## Skin/body tint for races that differ from the default human tone.
## hill_orc and troll use the muscular body sheet tinted green.
static func race_body_color(race_id: String) -> Color:
	match race_id:
		"hill_orc", "troll":
			return Color(0.55, 0.88, 0.45)
		_:
			return Color.WHITE

## Load a PNG from the ULPC generator folder without needing Godot .import metadata.
static func load_ulpc_tex(res_path: String) -> Texture2D:
	var abs_path := ProjectSettings.globalize_path(res_path)
	var img := Image.load_from_file(abs_path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)

static func ulpc_file_exists(res_path: String) -> bool:
	return FileAccess.file_exists(ProjectSettings.globalize_path(res_path))

## Derive the attack-animation sheet path from a walk sheet path.
## Handles two ULPC path patterns:
##   .../walk.png          → .../slash.png  (single-sheet animations, torso/head)
##   .../walk/{color}.png  → .../slash/{color}.png  (or .../slash.png fallback, hair/gloves)
static func ulpc_attack_path(walk_path: String, anim: String) -> String:
	if not walk_path.begins_with(_ULPC_ROOT):
		return ""
	var rel := walk_path.substr(_ULPC_ROOT.length())
	if rel.ends_with("/walk.png"):
		var candidate := _ULPC_ROOT + rel.trim_suffix("walk.png") + anim + ".png"
		if ulpc_file_exists(candidate):
			return candidate
	elif "/walk/" in rel:
		var parts := rel.split("/walk/", false, 1)
		if parts.size() == 2:
			# Try color-specific: .../slash/iron.png
			var candidate := _ULPC_ROOT + parts[0] + "/" + anim + "/" + parts[1]
			if ulpc_file_exists(candidate):
				return candidate
			# Fall back to merged sheet: .../slash.png  (hair, gloves)
			candidate = _ULPC_ROOT + parts[0] + "/" + anim + ".png"
			if ulpc_file_exists(candidate):
				return candidate
	return ""

## Returns the overlay sheet path for a given equipment slot and base item id.
## Public so StatusDialog can call it as PlayerRenderer.ulpc_overlay_path().
static func ulpc_overlay_path(slot: String, base_id: String) -> String:
	match slot:
		"sword":  return _WEAPON_OVERLAY_MAP.get(base_id, "")
		"armor":  return _ARMOR_OVERLAY_MAP.get(base_id, "")
		"legs":   return _LEGS_OVERLAY_MAP.get(base_id, "")
		"helmet": return _HELMET_OVERLAY_MAP.get(base_id, "")
		"gloves": return _GLOVES_OVERLAY_MAP.get(base_id, "")
		"boots":  return _BOOTS_OVERLAY_MAP.get(base_id, "")
		"shield": return _SHIELD_OVERLAY_MAP.get(base_id, "")
	return ""

# ── Internal helpers ──────────────────────────────────────────────────────────

## Destination Rect2 that scales a ULPC 64x64 frame so the character
## fills the tile cell from head-top to foot-bottom.
func _ulpc_draw_rect() -> Rect2:
	var cs: float = float(DungeonMap.CELL_SIZE)
	var scale: float = cs / _ULPC_CHAR_H       # 32/48 ≈ 0.667
	var draw_sz: float = 64.0 * scale           # ~42.7px
	var x_off: float = (cs - draw_sz) * 0.5    # center horizontally (~-5.3)
	var y_off: float = -_ULPC_CHAR_TOP * scale  # shift head to y=0 (~-9.3)
	return Rect2(x_off, y_off, draw_sz, draw_sz)


## Returns row index for ULPC 4-dir vertical sheet (N=0, W=1, S=2, E=3).
## Diagonals map to nearest cardinal.
func _facing_to_row(facing: Vector2i) -> int:
	match facing:
		Vector2i( 0, -1): return 0  # N
		Vector2i(-1, -1): return 1  # NW → W
		Vector2i(-1,  0): return 1  # W
		Vector2i(-1,  1): return 2  # SW → S
		Vector2i( 0,  1): return 2  # S
		Vector2i( 1,  1): return 2  # SE → S
		Vector2i( 1,  0): return 3  # E
		Vector2i( 1, -1): return 3  # NE → E
	return 2  # default S

## Returns column index for an 8-dir horizontal sheet (legacy).
## Actual sheet order (left→right): N, NE, W, SE, S, SW, E, NW
func _facing_to_frame(facing: Vector2i) -> int:
	match facing:
		Vector2i( 0, -1): return 0  # N
		Vector2i(-1, -1): return 7  # NW
		Vector2i(-1,  0): return 2  # W
		Vector2i(-1,  1): return 5  # SW
		Vector2i( 0,  1): return 4  # S
		Vector2i( 1,  1): return 3  # SE
		Vector2i( 1,  0): return 6  # E
		Vector2i( 1, -1): return 1  # NE
	return 4


func _draw_ulpc4(tex: Texture2D, urect: Rect2, col: int, total_cols: int, row: int) -> void:
	var fw := tex.get_width() / total_cols
	var fh := tex.get_height() / 4
	draw_texture_rect_region(tex, urect, Rect2(col * fw, row * fh, fw, fh))


# ── _process / _draw ──────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if _attack_anim_active:
		_attack_anim_t += delta
		var cols: int = int(_ATTACK_FRAMES.get(_attack_anim_type, 6))
		var new_frame := int(_attack_anim_t * _ATTACK_FPS)
		if new_frame >= cols:
			_attack_anim_active = false
			_attack_frame = 0
			queue_redraw()
		elif new_frame != _attack_frame:
			_attack_frame = new_frame
			queue_redraw()
	if not _walk_anim_active:
		return
	_walk_anim_t += delta
	var new_frame := int(_walk_anim_t * _WALK_FPS)
	if new_frame >= 9:
		_walk_anim_active = false
		_walk_frame = 0
		queue_redraw()
	elif new_frame != _walk_frame:
		_walk_frame = new_frame
		queue_redraw()


func _draw() -> void:
	var player := get_parent() as Player
	if player == null:
		return
	var GameManager = get_node_or_null("/root/GameManager")
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager != null and GameManager.use_tiles:
		var row := _facing_to_row(player.facing)
		var frame := _facing_to_frame(player.facing)
		var ulpc_rect := _ulpc_draw_rect()
		# ── Attack animation ─────────────────────────────────────────────────
		if _attack_anim_active and _atk_base.has(_attack_anim_type):
			var cols: int = int(_ATTACK_FRAMES.get(_attack_anim_type, 6))
			var atk_tex: Texture2D = _atk_base.get(_attack_anim_type)
			if atk_tex != null:
				_draw_ulpc4(atk_tex, ulpc_rect, _attack_frame, cols, row)
			var atk_list: Array = _atk_sheets.get(_attack_anim_type, [])
			for atex in atk_list:
				if atex != null:
					_draw_ulpc4(atex, ulpc_rect, _attack_frame, cols, row)
			return
		# ── Walk / idle ──────────────────────────────────────────────────────
		if _base_tex != null:
			var tw := _base_tex.get_width()
			var th := _base_tex.get_height()
			if tw >= th * 4:
				# 8-dir horizontal sheet: N NE W SE S SW E NW
				var fw := tw / 8
				draw_texture_rect_region(_base_tex, rect, Rect2(frame * fw, 0, fw, th))
			elif tw * 4 == th * 9 and th % 4 == 0:
				# ULPC 4-dir walk (9 cols × 4 rows)
				var fw := tw / 9
				var fh := th / 4
				draw_texture_rect_region(_base_tex, ulpc_rect, Rect2(_walk_frame * fw, row * fh, fw, fh))
			else:
				draw_texture_rect(_base_tex, rect, false)
		# Always-on base overlays (head, hair) drawn over body
		for btex in _base_sheets:
			if btex == null:
				continue
			var btw := btex.get_width()
			var bth := btex.get_height()
			if btw >= bth * 4:
				var bfw := btw / 8
				draw_texture_rect_region(btex, rect, Rect2(frame * bfw, 0, bfw, bth))
			elif btw * 4 == bth * 9 and bth % 4 == 0:
				var bfw := btw / 9
				var bfh := bth / 4
				draw_texture_rect_region(btex, ulpc_rect, Rect2(_walk_frame * bfw, row * bfh, bfw, bfh))
			else:
				draw_texture_rect(btex, rect, false)
		# Equipment overlay sheets drawn on top
		for etex in _equip_sheets:
			if etex == null:
				continue
			var etw := etex.get_width()
			var eth := etex.get_height()
			if etw >= eth * 4:
				var efw := etw / 8
				draw_texture_rect_region(etex, rect, Rect2(frame * efw, 0, efw, eth))
			elif etw * 4 == eth * 9 and eth % 4 == 0:
				var efw := etw / 9
				var efh := eth / 4
				draw_texture_rect_region(etex, ulpc_rect, Rect2(_walk_frame * efw, row * efh, efw, efh))
			else:
				draw_texture_rect(etex, rect, false)
		# Legacy single-frame paperdoll fallback
		if _equip_sheets.is_empty():
			if _body_doll_tex != null:
				draw_texture_rect(_body_doll_tex, rect, false)
			if _hand1_doll_tex != null:
				draw_texture_rect(_hand1_doll_tex, rect, false)
			if _hand2_doll_tex != null:
				draw_texture_rect(_hand2_doll_tex, rect, false)
	else:
		draw_string(ThemeDB.fallback_font,
			Vector2(6, DungeonMap.CELL_SIZE - 6),
			"@", HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			Color(1.0, 0.95, 0.5))
