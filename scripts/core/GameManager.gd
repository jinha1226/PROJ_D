extends Node
## Global game state singleton. Holds current run context.

signal run_started
signal run_ended(victory: bool)

var current_depth: int = 1
var current_seed: int = -1
var player: Node = null
var dungeon: Node = null
# Character-creation selections. Set by RaceSelect / JobSelect screens.
# "" means: use GameBootstrap defaults.
var selected_race_id: String = ""
var selected_job_id: String = ""
var selected_trait_id: String = ""
# Art mode — 0 = LPC (composed), 1 = DCSS tiles. Read via TileRenderer.mode().
# DCSS is now the default since the tile mapping is complete.
var render_mode: int = 1
## DCSS-style branch id that `current_depth` indexes into. "dungeon" on the
## main trunk; "lair" / "orc" / "vaults" / … once the player takes a
## branch entrance. Used as a key prefix in GameBootstrap._floor_state so
## each branch floor saves/restores independently of the main trunk.
var current_branch: String = "dungeon"
## Stack of {branch, depth} entries for where to return when leaving the
## current branch. Pushed on branch entry; popped on stairs-up off the
## branch's floor 1.
var branch_return_stack: Array = []

## Portal-vault turn counter. Non-zero only while the player is inside
## a portal branch (Sewer / Ossuary / Bailey / Volcano / Icecave).
## Ticks down every player turn via GameBootstrap._on_player_turn_started;
## when it hits zero the portal collapses and force-returns the player
## to the parent branch.
var portal_turns_left: int = 0

## Rune / Orb placement guards. Keys are "branch:depth" strings; each
## entry records that the rune or Orb has already been dropped on
## that floor this run, so revisits don't double-place.
var runes_placed: Dictionary = {}
var orb_placed: bool = false

## Active cloud tiles on the current floor. Keyed by Vector2i → dict
## (see CloudSystem.place for shape). Cleared on floor regenerate;
## CloudSystem.tick decrements per player turn via GameBootstrap.
var clouds: Dictionary = {}

## Debug flag — set by MainMenu's "Fireball Test" button. GameBootstrap
## reads this after setup to bump the player to XL 27, max skills, learn
## every spell, and stock consumables for rapid spell iteration.
var test_character_mode: bool = false

# --- Item identification (per-run) ---
# identified[id] == true once the player has drunk/read/identified a consumable.
var identified: Dictionary = {}
# Randomised pseudonyms for unidentified potions/scrolls. Stable within a run.
var _pseudonyms: Dictionary = {}
# Per-id DCSS base image filename (without extension). Drives the visible
# colour/look of unidentified consumables in DCSS render mode.
var _consumable_bases: Dictionary = {}
var _pseudonyms_assigned: bool = false

const _POTION_DESCRIPTORS: Array = [
	"Red", "Blue", "Green", "Yellow", "Purple", "Amber",
	"Swirling", "Bubbling", "Milky", "Frothing", "Foul", "Sweet",
	"Cloudy", "Glittering", "Smoky",
]
const _SCROLL_LABELS: Array = [
	"ZUN TAB", "VAX ROL", "ELIK DUR", "TREM OMOM", "OMAR BAB",
	"BLINKY", "KRULL", "ZEMA", "VORAL", "XENO", "AFOR PLI", "JEBA QI",
	"NEMIS", "PRUX", "GOROM",
]
# Rings wear a metal/material descriptor ("silver ring of dexterity"
# presents as just "silver ring" until identified). Amulets use shape
# + material likewise ("brass amulet" → "amulet of faith").
const _RING_DESCRIPTORS: Array = [
	"Wooden", "Silver", "Golden", "Iron", "Steel", "Bronze", "Brass",
	"Copper", "Granite", "Ivory", "Ruby", "Marble", "Jade", "Glass",
	"Agate", "Diamond", "Emerald", "Onyx",
]
const _AMULET_DESCRIPTORS: Array = [
	"Amber", "Silver", "Golden", "Bronze", "Jeweled", "Fluorescent",
	"Platinum", "Zirconium", "Cameo", "Pearl", "Emerald", "Ruby",
]

# DCSS base-tile filenames (stem only; consumable_base_path prepends the
# full item/potion/ or item/scroll/ path). Files live under
# res://assets/dcss_tiles/individual/item/{potion,scroll}/.
const _POTION_BASE_TILES: Array = [
	"brilliant_blue", "sky_blue", "ruby", "emerald", "yellow", "orange",
	"cyan", "white", "black", "pink", "silver", "golden",
	"magenta", "murky", "puce",
]
const _SCROLL_BASE_TILES: Array = [
	"blue", "red", "green", "purple", "cyan", "yellow", "brown", "grey",
]


func start_new_run(job_id: String = "fighter", race_id: String = "human", run_seed: int = -1) -> void:
	current_depth = 1
	current_branch = "dungeon"
	branch_return_stack.clear()
	current_seed = run_seed if run_seed != -1 else randi()
	selected_race_id = race_id
	selected_job_id = job_id
	identified.clear()
	_pseudonyms.clear()
	_consumable_bases.clear()
	_pseudonyms_assigned = false
	runes_placed.clear()
	orb_placed = false
	portal_turns_left = 0
	clouds.clear()
	# test_character_mode is NOT cleared here — MainMenu sets it right
	# before change_scene_to_file, and start_new_run runs after. The flag
	# is cleared by GameBootstrap once the boost has been applied.
	# Persist the combo so QuickStart can resurface it on the next boot.
	var meta: Node = get_tree().root.get_node_or_null("MetaProgression") if get_tree() != null else null
	if meta != null and meta.has_method("record_last_combo"):
		meta.record_last_combo(race_id, job_id)
	run_started.emit()


func identify(id: String) -> void:
	identified[id] = true


func is_identified(id: String) -> bool:
	return identified.has(id)


## Returns true name if identified, or a stable pseudonym otherwise. Falls
## through to `fallback` for non-consumable items.
func display_name_for_item(id: String, fallback: String, kind: String) -> String:
	if identified.has(id):
		return fallback
	# Randarts + unrandarts always render with their artefact name —
	# the pseudonym system is only for base-item identification.
	if id.begins_with("randart_") or id.begins_with("unrand_"):
		return fallback
	if kind == "potion" or kind == "scroll" or kind == "ring" or kind == "amulet":
		_ensure_pseudonyms()
		return String(_pseudonyms.get(id, fallback))
	return fallback


func _ensure_pseudonyms() -> void:
	if _pseudonyms_assigned:
		return
	_pseudonyms_assigned = true
	var potion_ids: Array = []
	var scroll_ids: Array = []
	for cid in ConsumableRegistry.all_ids():
		var info: Dictionary = ConsumableRegistry.get_info(cid)
		var k: String = String(info.get("kind", ""))
		if k == "potion":
			potion_ids.append(cid)
		elif k == "scroll":
			scroll_ids.append(cid)
	var pd: Array = _POTION_DESCRIPTORS.duplicate()
	pd.shuffle()
	var pb: Array = _POTION_BASE_TILES.duplicate()
	pb.shuffle()
	for i in potion_ids.size():
		_pseudonyms[potion_ids[i]] = "%s Potion" % pd[i % pd.size()]
		_consumable_bases[potion_ids[i]] = pb[i % pb.size()]
	var sl: Array = _SCROLL_LABELS.duplicate()
	sl.shuffle()
	var sb: Array = _SCROLL_BASE_TILES.duplicate()
	sb.shuffle()
	for i in scroll_ids.size():
		_pseudonyms[scroll_ids[i]] = "Scroll labeled %s" % sl[i % sl.size()]
		_consumable_bases[scroll_ids[i]] = sb[i % sb.size()]
	# Ring / amulet base-item pseudonyms. Randarts are excluded at the
	# display-name level so this just covers ring_fire, ring_strength,
	# amulet_faith, etc. — the "standard" DCSS jewellery catalogue.
	var ring_ids: Array = []
	for rid in RingRegistry.all_ids():
		if not String(rid).begins_with("randart_"):
			ring_ids.append(rid)
	var rd: Array = _RING_DESCRIPTORS.duplicate()
	rd.shuffle()
	for i in ring_ids.size():
		_pseudonyms[ring_ids[i]] = "%s Ring" % rd[i % rd.size()]
	var amu_ids: Array = []
	for aid in AmuletRegistry.all_ids():
		if not String(aid).begins_with("randart_"):
			amu_ids.append(aid)
	var ad: Array = _AMULET_DESCRIPTORS.duplicate()
	ad.shuffle()
	for i in amu_ids.size():
		_pseudonyms[amu_ids[i]] = "%s Amulet" % ad[i % ad.size()]


## DCSS base tile filename (stem) for a consumable id, paired with the kind.
## Returns "" if not a known consumable.
func consumable_base_path(id: String, kind: String) -> String:
	_ensure_pseudonyms()
	var stem: String = String(_consumable_bases.get(id, ""))
	if stem == "":
		return ""
	if kind == "potion":
		return "item/potion/%s.png" % stem
	elif kind == "scroll":
		return "item/scroll/scroll-%s.png" % stem
	return ""

func end_run(victory: bool) -> void:
	run_ended.emit(victory)


## Compound floor key used by GameBootstrap's save/restore cache. Each
## branch's depth-N floor is independent, so revisiting D:10 after
## clearing Lair:3 restores D:10 exactly as it was left.
func floor_key() -> String:
	return "%s:%d" % [current_branch, current_depth]


## Tile theming bucket for DCSS TileRenderer. When we're in a real
## branch we route the branch id through; the trunk's Dungeon still
## rotates through thematic segments so D:1-5 vs D:11-15 look different.
func tileset_branch() -> String:
	if current_branch != "dungeon":
		# Map branch id → tileset bucket. Most branches get their own
		# distinct tileset (snake / spider / slime / …); a handful
		# alias into a shared one when DCSS itself does the same.
		match current_branch:
			"lair": return "forest"
			"swamp": return "swamp"
			"shoals": return "shoals"
			"snake": return "snake"
			"spider": return "spider"
			"slime": return "slime"
			"orc": return "mine"
			"elf": return "elf"
			"vaults": return "vaults"
			"crypt": return "crypt"
			"tomb": return "crypt"
			"zot": return "crystal"
			"abyss": return "abyss"
			"pan": return "pan"
			"dis", "gehenna", "cocytus", "tartarus", "vestibule":
				return "hell"
			"depths": return "sandstone"
			# Portal vaults each reuse an existing floor-gen theme that
			# matches their flavour.
			"sewer": return "sewer"
			"ossuary": return "crypt"
			"bailey": return "mine"
			"volcano": return "volcano"
			"icecave": return "icecave"
			_: return current_branch
	# Main dungeon trunk keeps a single consistent tileset across D:1-15.
	# Earlier we rotated by depth (main/mine/forest/swamp/volcano) so the
	# look "changed with elevation", but that blurred the distinction
	# between D:6-10 and the actual Orcish Mines branch — the whole point
	# of branches is a visual break, so the trunk stays neutral grey.
	return "main"


## Legacy compat — kept so older callers (TileRenderer tile selection)
## keep working. Prefer `tileset_branch()` going forward.
func branch_for_depth(d: int) -> String:
	if current_branch != "dungeon":
		return tileset_branch()
	if d <= 5:
		return "main"
	if d <= 10:
		return "mine"
	if d <= 15:
		return "forest"
	if d <= 20:
		return "swamp"
	return "volcano"


## Push the current {branch, depth} and switch to the top of a new
## branch. GameBootstrap handles the floor regen afterward.
## For portal vaults, also starts the per-portal turn counter so the
## timed-branch expiry logic kicks in.
func enter_branch(branch_id: String) -> void:
	branch_return_stack.push_back({"branch": current_branch, "depth": current_depth})
	current_branch = branch_id
	current_depth = 1
	if BranchRegistry.is_portal(branch_id):
		portal_turns_left = BranchRegistry.portal_duration(branch_id)
	else:
		portal_turns_left = 0


## Pop the last parent floor off the stack (if any) and return to it.
## Returns true if we actually left a branch; false when we're already
## on the root. Caller still has to regenerate the floor.
func leave_branch() -> bool:
	if branch_return_stack.is_empty():
		return false
	var ret: Dictionary = branch_return_stack.pop_back()
	current_branch = String(ret.get("branch", "dungeon"))
	current_depth = int(ret.get("depth", 1))
	portal_turns_left = 0
	return true
