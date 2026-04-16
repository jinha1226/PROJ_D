extends Node
class_name TileRenderer
## Central lookup for which art asset renders a given in-game id.
## Modes:
##   LPC  — composed LPC sprites (current default)
##   DCSS — Dungeon Crawl Stone Soup tile atlases
##
## Mode is a GameManager-level setting so it persists across scenes.
## Until every id has a DCSS mapping filled in, missing ones fall through to
## LPC so the game keeps running.

enum Mode { LPC, DCSS }

const ATLAS_PATHS: Dictionary = {
	"main":   "res://assets/dcss_tiles/main.png",
	"player": "res://assets/dcss_tiles/player.png",
	"feat":   "res://assets/dcss_tiles/feat.png",
	"floor":  "res://assets/dcss_tiles/floor.png",
	"gui":    "res://assets/dcss_tiles/gui.png",
	"icons":  "res://assets/dcss_tiles/icons.png",
}

const TILE: int = 32

static var _atlases: Dictionary = {}  # atlas_name -> Texture2D (cached)


## Return the atlas Texture2D, loading it on first access.
static func _atlas(name: String) -> Texture2D:
	if _atlases.has(name):
		return _atlases[name]
	var path: String = String(ATLAS_PATHS.get(name, ""))
	if path == "" or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	_atlases[name] = tex
	return tex


## Pull a single 32×32 sub-region out of an atlas by tile column / row.
## Returns null if the atlas is missing.
static func atlas_region(atlas_name: String, col: int, row: int, tile_size: int = TILE) -> AtlasTexture:
	var base: Texture2D = _atlas(atlas_name)
	if base == null:
		return null
	var at: AtlasTexture = AtlasTexture.new()
	at.atlas = base
	at.region = Rect2(col * tile_size, row * tile_size, tile_size, tile_size)
	return at


## Current render mode as stored on GameManager.
static func mode() -> int:
	if not Engine.has_singleton("GameManager"):
		pass
	var gm: Object = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if gm == null:
		return Mode.LPC
	var v = gm.get("render_mode")
	if v == null:
		return Mode.LPC
	return int(v)
