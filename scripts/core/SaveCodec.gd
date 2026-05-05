extends Node
class_name SaveCodecCls

## Serialization codec for floor/branch cache state. Converts
## Godot-native types (Vector2i, Rect2i, PackedByteArray) to JSON-safe
## primitives so SaveManager can round-trip the full run state.
##
## Encoding choices:
##   Vector2i             -> [x, y]
##   Rect2i               -> [x, y, w, h]
##   Array[Vector2i]      -> [[x, y], ...]
##   Dict[Vector2i, V]    -> [[x, y, V], ...]  (V encoded recursively if needed)
##   PackedByteArray      -> base64 string

static func enc_vec(v: Vector2i) -> Array:
	return [v.x, v.y]

static func dec_vec(a) -> Vector2i:
	if typeof(a) != TYPE_ARRAY or a.size() < 2:
		return Vector2i.ZERO
	return Vector2i(int(a[0]), int(a[1]))

static func enc_rect(r: Rect2i) -> Array:
	return [r.position.x, r.position.y, r.size.x, r.size.y]

static func dec_rect(a) -> Rect2i:
	if typeof(a) != TYPE_ARRAY or a.size() < 4:
		return Rect2i()
	return Rect2i(int(a[0]), int(a[1]), int(a[2]), int(a[3]))

static func enc_vec_array(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		if v is Vector2i:
			out.append([v.x, v.y])
		else:
			out.append(v)
	return out

static func dec_vec_array(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for v in arr:
		out.append(dec_vec(v))
	return out

static func enc_rect_array(arr: Array) -> Array:
	var out: Array = []
	for r in arr:
		if r is Rect2i:
			out.append(enc_rect(r))
	return out

static func dec_rect_array(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for r in arr:
		out.append(dec_rect(r))
	return out

## Dict[Vector2i, Variant] -> [[x, y, value], ...]
static func enc_vec_dict(d: Dictionary) -> Array:
	var out: Array = []
	for k in d.keys():
		if k is Vector2i:
			out.append([k.x, k.y, d[k]])
	return out

static func dec_vec_dict(arr) -> Dictionary:
	var out: Dictionary = {}
	if typeof(arr) != TYPE_ARRAY:
		return out
	for entry in arr:
		if typeof(entry) == TYPE_ARRAY and entry.size() >= 3:
			out[Vector2i(int(entry[0]), int(entry[1]))] = entry[2]
	return out

static func enc_bytes(b: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(b)

static func dec_bytes(s) -> PackedByteArray:
	if typeof(s) != TYPE_STRING:
		return PackedByteArray()
	return Marshalls.base64_to_raw(str(s))

## Encode a single floor state dict (as produced by Game._cache_current_floor
## or Game._cache_branch_floor) into a JSON-safe dict.
static func encode_floor_state(state: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if state.has("tiles"):
		out["tiles"] = enc_bytes(state["tiles"])
	if state.has("explored"):
		out["explored"] = enc_vec_dict(state["explored"])
	if state.has("spawn_pos"):
		out["spawn_pos"] = enc_vec(state["spawn_pos"])
	if state.has("stairs_down_pos"):
		out["stairs_down_pos"] = enc_vec(state["stairs_down_pos"])
	if state.has("extra_stairs_down_positions"):
		out["extra_stairs_down_positions"] = enc_vec_array(state["extra_stairs_down_positions"])
	if state.has("stairs_up_pos"):
		out["stairs_up_pos"] = enc_vec(state["stairs_up_pos"])
	if state.has("rooms"):
		out["rooms"] = enc_rect_array(state["rooms"])
	if state.has("altar_map"):
		# altar_map: Vector2i -> String
		var am: Dictionary = state["altar_map"]
		var am_out: Array = []
		for k in am.keys():
			if k is Vector2i:
				am_out.append([k.x, k.y, str(am[k])])
		out["altar_map"] = am_out
	if state.has("broken_altar_positions"):
		out["broken_altar_positions"] = enc_vec_array(state["broken_altar_positions"])
	if state.has("altar_active"):
		out["altar_active"] = bool(state["altar_active"])
	if state.has("items"):
		out["items"] = _encode_items(state["items"])
	if state.has("monsters"):
		out["monsters"] = _encode_monsters(state["monsters"])
	if state.has("corpses"):
		out["corpses"] = _encode_corpses(state["corpses"])
	if state.has("cloud_tiles"):
		out["cloud_tiles"] = enc_vec_dict(state["cloud_tiles"])
	if state.has("hazard_tiles"):
		out["hazard_tiles"] = enc_vec_dict(state["hazard_tiles"])
	if state.has("fog_tiles"):
		out["fog_tiles"] = enc_vec_dict(state["fog_tiles"])
	return out

static func decode_floor_state(data: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	if data.has("tiles"):
		out["tiles"] = dec_bytes(data["tiles"])
	if data.has("explored"):
		out["explored"] = dec_vec_dict(data["explored"])
	if data.has("spawn_pos"):
		out["spawn_pos"] = dec_vec(data["spawn_pos"])
	if data.has("stairs_down_pos"):
		out["stairs_down_pos"] = dec_vec(data["stairs_down_pos"])
	if data.has("extra_stairs_down_positions"):
		out["extra_stairs_down_positions"] = dec_vec_array(data["extra_stairs_down_positions"])
	if data.has("stairs_up_pos"):
		out["stairs_up_pos"] = dec_vec(data["stairs_up_pos"])
	if data.has("rooms"):
		out["rooms"] = dec_rect_array(data["rooms"])
	if data.has("altar_map"):
		var am_arr = data["altar_map"]
		var am_out: Dictionary = {}
		if typeof(am_arr) == TYPE_ARRAY:
			for entry in am_arr:
				if typeof(entry) == TYPE_ARRAY and entry.size() >= 3:
					am_out[Vector2i(int(entry[0]), int(entry[1]))] = str(entry[2])
		out["altar_map"] = am_out
	if data.has("broken_altar_positions"):
		out["broken_altar_positions"] = dec_vec_array(data["broken_altar_positions"])
	if data.has("altar_active"):
		out["altar_active"] = bool(data["altar_active"])
	if data.has("items"):
		out["items"] = _decode_items(data["items"])
	if data.has("monsters"):
		out["monsters"] = _decode_monsters(data["monsters"])
	if data.has("corpses"):
		out["corpses"] = _decode_corpses(data["corpses"])
	if data.has("cloud_tiles"):
		out["cloud_tiles"] = dec_vec_dict(data["cloud_tiles"])
	if data.has("hazard_tiles"):
		out["hazard_tiles"] = dec_vec_dict(data["hazard_tiles"])
	if data.has("fog_tiles"):
		out["fog_tiles"] = dec_vec_dict(data["fog_tiles"])
	return out

## Encode a {depth: state} or {key: state} dict.
static func encode_cache_dict(cache: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in cache.keys():
		out[str(k)] = encode_floor_state(cache[k])
	return out

static func decode_cache_dict(data, key_as_int: bool) -> Dictionary:
	var out: Dictionary = {}
	if typeof(data) != TYPE_DICTIONARY:
		return out
	for k in data.keys():
		var state: Dictionary = decode_floor_state(data[k])
		if key_as_int:
			out[int(k)] = state
		else:
			out[str(k)] = state
	return out

# ── Items / monsters / corpses ─────────────────────────────────────────

static func _encode_items(items: Array) -> Array:
	var out: Array = []
	for it in items:
		var d: Dictionary = (it as Dictionary).duplicate(true)
		if d.has("pos") and d["pos"] is Vector2i:
			d["pos"] = enc_vec(d["pos"])
		out.append(d)
	return out

static func _decode_items(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for it in arr:
		if typeof(it) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (it as Dictionary).duplicate(true)
		if d.has("pos"):
			d["pos"] = dec_vec(d["pos"])
		out.append(d)
	return out

static func _encode_monsters(monsters: Array) -> Array:
	var out: Array = []
	for m in monsters:
		var d: Dictionary = (m as Dictionary).duplicate(true)
		if d.has("pos") and d["pos"] is Vector2i:
			d["pos"] = enc_vec(d["pos"])
		if d.has("last_known_player_pos") and d["last_known_player_pos"] is Vector2i:
			d["last_known_player_pos"] = enc_vec(d["last_known_player_pos"])
		out.append(d)
	return out

static func _decode_monsters(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for m in arr:
		if typeof(m) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = (m as Dictionary).duplicate(true)
		if d.has("pos"):
			d["pos"] = dec_vec(d["pos"])
		if d.has("last_known_player_pos"):
			d["last_known_player_pos"] = dec_vec(d["last_known_player_pos"])
		out.append(d)
	return out

static func _encode_corpses(corpses: Array) -> Array:
	var out: Array = []
	for c in corpses:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = {}
		# Drop runtime-only fields like cached Texture2D.
		for k in c.keys():
			var v = c[k]
			if v is Vector2i:
				d[k] = enc_vec(v)
			elif typeof(v) in [TYPE_STRING, TYPE_INT, TYPE_FLOAT, TYPE_BOOL]:
				d[k] = v
			# Skip non-serializable (Texture2D, Color, etc.)
		out.append(d)
	return out

static func _decode_corpses(arr) -> Array:
	var out: Array = []
	if typeof(arr) != TYPE_ARRAY:
		return out
	for c in arr:
		if typeof(c) != TYPE_DICTIONARY:
			continue
		var d: Dictionary = {}
		for k in c.keys():
			var v = c[k]
			if k == "pos" or (typeof(v) == TYPE_ARRAY and v.size() == 2):
				d[k] = dec_vec(v)
			else:
				d[k] = v
		out.append(d)
	return out
