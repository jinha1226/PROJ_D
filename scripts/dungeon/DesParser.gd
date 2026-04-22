class_name DesParser
extends Object
## Parses DCSS .des vault definition files into in-memory dictionaries.
##
## DCSS .des format (simplified for our use):
##   NAME:   <unique_vault_name>
##   TAGS:   <space-separated tags>         (optional)
##   DEPTH:  <branch>[:<range>][, ...]      (optional, default-depth applies otherwise)
##   WEIGHT: <int>                          (optional, default 10)
##   ORIENT: <encompass|north|south|...>    (optional; blank = minivault)
##   SUBST:  <char> = <char|char:weight>... (0+ lines, we only keep simple single-char)
##   MAP
##   <rows...>
##   ENDMAP
##
## We skip vaults that rely on Lua placement (`{{ ... }}` inline blocks or `: ...`
## lines between NAME and ENDMAP), and also vaults with KMONS/KITEM/KFEAT that
## require monster/item systems we haven't wired up yet. Pure static MAPs go in.
##
## Output is an Array of Dictionary with:
##   name, tags (Array[String]), depth_specs (Array[Dictionary{branch,min,max}]),
##   weight, orient, map (Array[String]), source (file basename).


const _BRANCH_ALIASES := {
	"D": "main", "Dungeon": "main",
	"Lair": "forest",
	"Swamp": "swamp",
	"Orc": "mine", "Mines": "mine",
	"Snake": "forest",
	"Shoals": "swamp",
	"Spider": "forest",
	"Elf": "main",
	"Crypt": "main",
	"Tomb": "main",
	"Vaults": "main",
	"Depths": "main",
	"Zot": "volcano",
	"Slime": "swamp",
	"Geh": "volcano", "Gehenna": "volcano",
	"Coc": "swamp", "Cocytus": "swamp",
	"Dis": "mine",
	"Tar": "main", "Tartarus": "main",
	"Pan": "main",
	"Abyss": "main",
	"Temple": "main",
	"Sewer": "main",
	"Ossuary": "main",
	"Volcano": "volcano",
	"IceCv": "main",
	"Bailey": "main",
	"Bazaar": "main",
	"WizLab": "main",
	"Desolation": "main",
	"Trove": "main",
	"Gauntlet": "main",
	"Forest": "forest",
	"Ice": "main",
	"Hell": "volcano",
}


## Parse all .des files under `dir_path`. Returns flat Array of vault dicts.
static func parse_directory(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		push_warning("DesParser: cannot open %s" % dir_path)
		return out
	d.list_dir_begin()
	var fname: String = d.get_next()
	while fname != "":
		if not d.current_is_dir() and fname.ends_with(".des"):
			var path: String = dir_path.path_join(fname)
			var vaults: Array = parse_file(path)
			out.append_array(vaults)
		fname = d.get_next()
	d.list_dir_end()
	return out


## Parse a single .des file. Returns Array of vault dicts (possibly empty).
static func parse_file(path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_warning("DesParser: cannot read %s" % path)
		return out
	var text: String = f.get_as_text()
	f.close()
	var source: String = path.get_file()

	var default_depth: Array = []
	# Build a line array with Lua `{{ ... }}` blocks removed. DCSS convention
	# puts `{{` / `}}` on their own lines (sometimes preceded by `lua`), so a
	# line-level filter is exact and linear — a char-level pass over a 13k-line
	# file is O(n) in operations but O(n²) in string concat work.
	var raw_lines: PackedStringArray = text.split("\n")
	var lines: PackedStringArray = PackedStringArray()
	var in_lua_block: bool = false
	for rl in raw_lines:
		var trimmed: String = String(rl).strip_edges()
		if in_lua_block:
			if trimmed.begins_with("}}"):
				in_lua_block = false
			continue
		if trimmed.begins_with("{{") or trimmed.begins_with("lua {{") \
				or trimmed == "lua" \
				or trimmed.ends_with("{{"):
			in_lua_block = true
			continue
		lines.append(rl)
	var i: int = 0
	while i < lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()
		if stripped.begins_with("default-depth:"):
			default_depth = _parse_depth(stripped.substr("default-depth:".length()))
		elif stripped.begins_with("NAME:"):
			var result: Dictionary = _parse_vault_block(lines, i, default_depth, source)
			var consumed: int = int(result.get("consumed", 1))
			var vault: Dictionary = result.get("vault", {})
			if not vault.is_empty():
				out.append(vault)
			i += max(1, consumed)
			continue
		i += 1
	return out


## Parse one vault starting at `start_idx` (the NAME: line). Returns
## {vault, consumed}. `vault` is empty if the vault was rejected.
static func _parse_vault_block(lines: PackedStringArray, start_idx: int,
		default_depth: Array, source: String) -> Dictionary:
	var vault: Dictionary = {
		"name": "",
		"tags": [],
		"depth_specs": default_depth.duplicate(true),
		"weight": 10,
		"orient": "",
		"map": [],
		"source": source,
		# SUBST: glyph → [ {ch, weight} ] weighted replacement pool.
		# Applied at _finalize_vault so source glyphs never reach the
		# supported-glyph gate.
		"subst": {},
		# KMONS: glyph → monster id (DCSS supports a single id or a
		# weighted set; we take the first id as a safe simplification).
		# During placement the glyph is treated as floor and a spawn
		# request is queued against VaultRegistry.
		"kmons": {},
	}
	var i: int = start_idx
	var in_map: bool = false
	var has_lua: bool = false
	var has_unsupported_feature: bool = false
	var name_raw: String = lines[start_idx].strip_edges().substr("NAME:".length()).strip_edges()
	vault["name"] = name_raw
	i += 1
	while i < lines.size():
		var raw: String = lines[i]
		var stripped: String = raw.strip_edges()
		# Blank line inside a vault block ends the block only if we've hit
		# ENDMAP; otherwise skip.
		if in_map:
			if stripped == "ENDMAP":
				in_map = false
				i += 1
				return {"vault": _finalize_vault(vault, has_lua, has_unsupported_feature), "consumed": i - start_idx}
			# Preserve map row exactly (trim trailing \r only). DCSS maps use
			# leading spaces and trailing gaps to define footprint.
			vault["map"].append(raw.trim_suffix("\r"))
			i += 1
			continue
		# End of this vault when next NAME: appears.
		if stripped.begins_with("NAME:") and i != start_idx:
			return {"vault": _finalize_vault(vault, has_lua, has_unsupported_feature), "consumed": i - start_idx}
		# Lua line or block — mark and skip. Lines starting with `:` are
		# inline Lua; `lua {{` or bare `{{` opens a block.
		if stripped.begins_with(":") or stripped.begins_with("lua {{") or stripped.begins_with("{{"):
			has_lua = true
			i += 1
			continue
		if stripped.begins_with("TAGS:"):
			# TAGS: can appear multiple times per vault — accumulate.
			var raw_tags: PackedStringArray = stripped.substr("TAGS:".length()).split(" ", false)
			var cleaned: Array = vault["tags"]
			for t in raw_tags:
				var ts: String = String(t).strip_edges()
				if ts != "":
					cleaned.append(ts)
			vault["tags"] = cleaned
		elif stripped.begins_with("DEPTH:"):
			vault["depth_specs"] = _parse_depth(stripped.substr("DEPTH:".length()))
		elif stripped.begins_with("WEIGHT:"):
			vault["weight"] = _parse_int(stripped.substr("WEIGHT:".length()), 10)
		elif stripped.begins_with("ORIENT:"):
			vault["orient"] = stripped.substr("ORIENT:".length()).strip_edges()
		elif stripped.begins_with("SUBST:"):
			# SUBST: X = . / F    or    SUBST: X = .:5 x:3 w
			# Parsed into a weighted replacement pool so finalize can
			# roll once and emit a supported-glyph map.
			_parse_subst_into(vault, stripped.substr("SUBST:".length()))
		elif stripped.begins_with("KMONS:"):
			# KMONS: X = orc   (we take the first token; weighted /
			# alternate sets are simplified to the lead id).
			_parse_kmons_into(vault, stripped.substr("KMONS:".length()))
		elif stripped.begins_with("NSUBST:") \
				or stripped.begins_with("KITEM:") \
				or stripped.begins_with("KFEAT:") \
				or stripped.begins_with("MONS:") \
				or stripped.begins_with("ITEM:") \
				or stripped.begins_with("SHUFFLE:") \
				or stripped.begins_with("MARKER:") \
				or stripped.begins_with("COLOUR:") \
				or stripped.begins_with("FTILE:") \
				or stripped.begins_with("RTILE:") \
				or stripped.begins_with("TILE:") \
				or stripped.begins_with("LFLAGS:") \
				or stripped.begins_with("BFLAGS:") \
				or stripped.begins_with("FLOAT:") \
				or stripped.begins_with("CHANCE:") \
				or stripped.begins_with("PLACE:") \
				or stripped.begins_with("DESC:") \
				or stripped.begins_with("EPILOGUE:") \
				or stripped.begins_with("PROPERTIES:") \
				or stripped.begins_with("NSLOT:"):
			# Remaining directives need engine support we don't have.
			# Tolerate them (don't reject the vault).
			pass
		elif stripped == "MAP":
			in_map = true
		# Silently ignore unknown headers, comments, blank lines.
		i += 1
	return {"vault": _finalize_vault(vault, has_lua, has_unsupported_feature), "consumed": i - start_idx}


static func _finalize_vault(vault: Dictionary, has_lua: bool, has_unsupported: bool) -> Dictionary:
	if vault.get("name", "") == "":
		return {}
	if vault.get("map", []).is_empty():
		return {}
	if has_lua:
		return {}
	if has_unsupported:
		return {}
	# Apply SUBST substitutions before the supported-glyph check so
	# vaults using `X = . / F` etc. don't get rejected for a source
	# glyph they're going to replace anyway. One roll per source glyph
	# per vault keeps the parsed template stable across runs — enough
	# variety across the ~200 vault corpus without per-placement RNG.
	var subst: Dictionary = vault.get("subst", {})
	if not subst.is_empty():
		var rolled: Dictionary = {}
		for ch in subst.keys():
			rolled[String(ch)] = _pick_weighted_glyph(subst[ch])
		var out_rows: Array = []
		for row in vault["map"]:
			var s: String = String(row)
			var rebuilt: String = ""
			for c in s:
				rebuilt += rolled.get(c, c) if rolled.has(c) else c
			out_rows.append(rebuilt)
		vault["map"] = out_rows
	# Drop vaults containing map characters we can't render. Any glyph not in
	# the supported set kills the vault — safer than placing a broken map.
	for row in vault["map"]:
		for ch in String(row):
			if not _is_supported_glyph(ch):
				return {}
	# Normalise map width — pad shorter rows with spaces so every row has the
	# same length. Spaces are "transparent" (no overwrite).
	var max_w: int = 0
	for row in vault["map"]:
		max_w = max(max_w, String(row).length())
	var padded: Array = []
	for row in vault["map"]:
		var s: String = String(row)
		if s.length() < max_w:
			s = s + " ".repeat(max_w - s.length())
		padded.append(s)
	vault["map"] = padded
	return vault


## Parse a `SUBST:` tail into vault["subst"]. Accepts the DCSS forms:
##   SUBST: X = .       (single replacement)
##   SUBST: X = . / F   (uniform weights across /-separated glyphs)
##   SUBST: X = .:5 x:3 w   (explicit weights — default 1)
## One SUBST line may rebind multiple source glyphs via `;`-separated
## clauses: `SUBST: X = . ; Y = w`.
static func _parse_subst_into(vault: Dictionary, tail: String) -> void:
	var subst: Dictionary = vault.get("subst", {})
	for clause in tail.split(";", false):
		var s: String = String(clause).strip_edges()
		if s == "":
			continue
		var eq: int = s.find("=")
		if eq < 0:
			continue
		var src_part: String = s.substr(0, eq).strip_edges()
		if src_part.length() == 0:
			continue
		# DCSS allows `SUBST: X Y = ...` binding both to the same pool.
		var sources: PackedStringArray = PackedStringArray()
		for sc in src_part:
			if sc != " " and sc != "\t":
				sources.append(String(sc))
		var pool_text: String = s.substr(eq + 1).strip_edges()
		pool_text = pool_text.replace("/", " ")
		var pool: Array = []
		for tok in pool_text.split(" ", false):
			var t: String = String(tok).strip_edges()
			if t == "":
				continue
			var w: int = 1
			var gch: String = t
			var colon: int = t.find(":")
			if colon >= 0:
				gch = t.substr(0, colon)
				w = _parse_int(t.substr(colon + 1), 1)
			if gch.length() != 1:
				continue
			pool.append({"ch": gch, "w": maxi(1, w)})
		if pool.is_empty():
			continue
		for sg in sources:
			subst[String(sg)] = pool
	vault["subst"] = subst


## Parse a `KMONS:` tail into vault["kmons"]. Takes the first monster id
## when the right-hand side enumerates a weighted set — good enough for
## our placer which spawns a single creature per glyph slot.
static func _parse_kmons_into(vault: Dictionary, tail: String) -> void:
	var kmons: Dictionary = vault.get("kmons", {})
	var s: String = tail.strip_edges()
	var eq: int = s.find("=")
	if eq < 0:
		return
	var src: String = s.substr(0, eq).strip_edges()
	var rhs: String = s.substr(eq + 1).strip_edges()
	if src.length() != 1:
		return
	# DCSS KMONS RHS forms:
	#   orc
	#   orc w:8 / kobold
	#   orc / gnoll
	# Split on `/` then pick the first non-weight token.
	var first: String = ""
	for chunk in rhs.split("/", false):
		for tok in String(chunk).split(" ", false):
			var t: String = String(tok).strip_edges()
			if t == "" or t.contains(":"):
				continue
			first = t
			break
		if first != "":
			break
	if first != "":
		kmons[src] = first
	vault["kmons"] = kmons


## Roll a glyph from a weighted pool. Pool entries are {"ch", "w"}.
static func _pick_weighted_glyph(pool: Array) -> String:
	if pool.is_empty():
		return "."
	var total: int = 0
	for e in pool:
		total += int(e.get("w", 1))
	if total <= 0:
		return String(pool[0].get("ch", "."))
	var r: int = randi() % total
	var acc: int = 0
	for e in pool:
		acc += int(e.get("w", 1))
		if r < acc:
			return String(e.get("ch", "."))
	return String(pool[-1].get("ch", "."))


static func _is_supported_glyph(ch: String) -> bool:
	# Keep this restrictive — any exotic glyph likely depends on KMONS/KITEM/
	# KFEAT/TILE support. When those systems come online we can expand.
	return ch in [".", "x", "c", "b", "v", "m", "G", "+", "a",
			"W", "w", "l", "T", "@", " ", "#"]


## Parse a depth spec like "D:5-11, Depths, !Depths:$, Crypt" into an Array of
## Dictionary entries {branch (String), min (int), max (int), negate (bool)}.
## `!Depths:$` means "never in Depths:$".
static func _parse_depth(text: String) -> Array:
	var out: Array = []
	var parts: PackedStringArray = text.split(",")
	for p in parts:
		var entry: String = p.strip_edges()
		if entry == "":
			continue
		var negate: bool = false
		if entry.begins_with("!"):
			negate = true
			entry = entry.substr(1)
		var branch: String = entry
		var mn: int = 1
		var mx: int = 99
		var colon: int = entry.find(":")
		if colon != -1:
			branch = entry.substr(0, colon).strip_edges()
			var range_str: String = entry.substr(colon + 1).strip_edges()
			if range_str == "$":
				# End of branch — we don't model branch ends, so treat as
				# "deep" (min 90 to let it still appear as a late-game minivault).
				mn = 90
				mx = 99
			elif range_str.find("-") != -1:
				var rparts: PackedStringArray = range_str.split("-")
				if rparts.size() >= 1 and rparts[0].strip_edges() != "":
					mn = _parse_int(rparts[0], 1)
				if rparts.size() >= 2 and rparts[1].strip_edges() != "":
					mx = _parse_int(rparts[1], 99)
				else:
					mx = 99
			else:
				mn = _parse_int(range_str, 1)
				mx = mn
		out.append({
			"branch": branch,
			"min": mn,
			"max": mx,
			"negate": negate,
		})
	return out


## Translate a DCSS branch tag to our simplified branch family. Unknown
## branches return "main" so imported vaults still get *a* home.
static func map_branch(dcss_branch: String) -> String:
	return String(_BRANCH_ALIASES.get(dcss_branch, "main"))


## Given a parsed vault and the current (branch, depth) in our game, decide
## whether the vault is eligible. `branch` is one of our branch families
## ("main", "mine", "forest", "swamp", "volcano"). `depth` is 1-based.
static func vault_matches(vault: Dictionary, branch: String, depth: int) -> bool:
	var specs: Array = vault.get("depth_specs", [])
	if specs.is_empty():
		# No depth data: allow everywhere (matches DCSS "no DEPTH line" semantic
		# when no default-depth was active either).
		return true
	var allow: bool = false
	for spec in specs:
		var sb: String = String(spec.get("branch", ""))
		var mn: int = int(spec.get("min", 1))
		var mx: int = int(spec.get("max", 99))
		var negate: bool = bool(spec.get("negate", false))
		if map_branch(sb) != branch:
			continue
		if depth < mn or depth > mx:
			continue
		if negate:
			return false
		allow = true
	return allow


static func _parse_int(s: String, fallback: int) -> int:
	var t: String = s.strip_edges()
	if t.is_valid_int():
		return int(t)
	return fallback


## Convert a DCSS map glyph to our DungeonGenerator.TileType. Returns -1 for
## transparent (keep the underlying generated tile).
static func dcss_char_to_tile(ch: String) -> int:
	if ch == "." or ch == "@":
		return DungeonGenerator.TileType.FLOOR
	if ch == "x" or ch == "c" or ch == "b" or ch == "v" or ch == "m" or ch == "G" or ch == "#":
		return DungeonGenerator.TileType.WALL
	if ch == "+" or ch == "a":
		return DungeonGenerator.TileType.DOOR_CLOSED
	if ch == "W" or ch == "w":
		return DungeonGenerator.TileType.WATER
	if ch == "l":
		return DungeonGenerator.TileType.LAVA
	if ch == "T":
		return DungeonGenerator.TileType.TREE
	return -1
