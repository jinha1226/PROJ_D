extends Node
class_name LPCDefLoader
## ULPC sheet_definitions 기반 아이템 레이어 리졸버
##
## assets/lpc_defs/*.json + index.json을 파싱하고, 게임 anim_id 와 아이템 id
## 조합에 대해 어느 ULPC PNG들이 어떤 z-order 로 블렌드되어야 하는지
## 계산해서 LPCSpriteLoader 가 쓸 수 있도록 돌려준다.
##
## 사용:
##   var resolved := LPCDefLoader.resolve("longsword", "slash", "male")
##   # resolved.frame_size = 192
##   # resolved.def_anim   = "slash_oversize"
##   # resolved.layers     = [{ path, zPos, frame_size }, ...]  (zPos 오름차순)
##
## 모든 path 는 "ulpc/weapon/.../longsword.png" 처럼 BASE_PATH 하위 상대경로.
## LPCSpriteLoader.BASE_PATH 를 prepend 해서 Image.load_from_file 에 넘기면 됨.
##
## zPos 가 BODY_Z_POS(10) 미만이면 body 뒤, 이상이면 body 앞.

const BODY_Z_POS := 10
const DEFS_DIR := "res://assets/lpc_defs/"
const ULPC_DIR := "res://assets/ulpc/"  # 절대경로 — LPCSpriteLoader 에서 그대로 load()

# 게임 anim_id → 우선순위 순 def anim 후보
const _ANIM_PREF := {
	"walk":  ["walk_128", "walk"],
	# arming sword 같은 무기는 slash_128 을 씀. slash_oversize 먼저 보고 없으면
	# slash_128 → slash 순으로 폴백.
	"slash": ["slash_oversize", "slash_128", "slash"],
	"thrust":["thrust_oversize", "thrust"],
	"shoot": ["shoot"],
	"hurt":  ["hurt"],
	"idle":  ["idle", "walk"],
}

const _OVERSIZE_ANIMS := {
	"slash_oversize": 192,
	"slash_reverse_oversize": 192,
	"slash_128": 128,
	"thrust_oversize": 192,
	"walk_128": 128,
}

static var _index: Dictionary = {}          # item_id -> def Dictionary
static var _loaded := false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var idx_path := DEFS_DIR + "index.json"
	var idx_txt := FileAccess.get_file_as_string(idx_path)
	if idx_txt.is_empty():
		push_warning("LPCDefLoader: index.json not found at %s" % idx_path)
		return
	var idx: Dictionary = JSON.parse_string(idx_txt)
	if idx == null:
		push_warning("LPCDefLoader: index.json parse failed")
		return
	for item_id in idx.keys():
		var fname: String = idx[item_id]
		var def_txt := FileAccess.get_file_as_string(DEFS_DIR + fname)
		if def_txt.is_empty():
			push_warning("LPCDefLoader: def missing %s" % fname)
			continue
		var data = JSON.parse_string(def_txt)
		if data == null or typeof(data) != TYPE_DICTIONARY:
			push_warning("LPCDefLoader: parse failed %s" % fname)
			continue
		_index[item_id] = data


## 이 item_id 가 def 시스템으로 관리되는지
static func has_def(item_id: String) -> bool:
	_ensure_loaded()
	return _index.has(item_id)


## def 에 선언된 animations 목록 (원본 그대로)
static func get_animations(item_id: String) -> Array:
	_ensure_loaded()
	var d: Dictionary = _index.get(item_id, {})
	return (d.get("animations", []) as Array).duplicate()

## def variants 에 이 material id 가 있는지
static func has_material_variant(item_id: String, mat: String) -> bool:
	_ensure_loaded()
	var d: Dictionary = _index.get(item_id, {})
	var variants: Array = d.get("variants", [])
	return mat in variants


## 게임 anim_id 를 def anim 으로 해석.
## item 이 그 anim 을 지원하지 않으면 빈 문자열.
## def 에 animations 필드가 없으면 (방패 같이 상시 표시되는 레이어) 게임 anim
## 중 표준 이름(walk/slash/hurt/shoot)을 그대로 사용.
static func resolve_anim(item_id: String, game_anim: String) -> String:
	_ensure_loaded()
	var d: Dictionary = _index.get(item_id, {})
	var anims: Array = d.get("animations", [])
	var prefs: Array = _ANIM_PREF.get(game_anim, [game_anim])
	if anims.is_empty():
		# animations 미선언: idle 은 walk 로 치환, 나머지는 그대로
		for a in prefs:
			if a in ["walk", "slash", "hurt", "shoot", "thrust", "spellcast"]:
				return a
		return "walk"
	for a in prefs:
		if a in anims:
			return a
	return ""


## item_id + game_anim 조합을 실제 블렌드 플랜으로 해석.
## 반환: { "def_anim": String, "frame_size": int, "layers": Array }
##   layers: [{ "path": String, "zPos": int }]  (zPos 오름차순 정렬)
## 어떤 레이어도 찾지 못하면 layers 는 비어 있음.
static func resolve(item_id: String, game_anim: String,
		body_type: String = "male", variant: String = "") -> Dictionary:
	_ensure_loaded()
	var out := {"def_anim": "", "frame_size": 64, "layers": []}
	var d: Dictionary = _index.get(item_id, {})
	if d.is_empty():
		return out

	var def_anim := resolve_anim(item_id, game_anim)
	if def_anim == "":
		return out
	out["def_anim"] = def_anim
	out["frame_size"] = _OVERSIZE_ANIMS.get(def_anim, 64)

	var variants: Array = d.get("variants", [])
	var has_variants: bool = not variants.is_empty()
	var default_v: String = d.get("default_variant", "")
	var v := variant
	if has_variants:
		if v == "" or not (v in variants):
			# material id 가 def variants 에 없으면 default_variant → variants[0].
			if default_v != "" and default_v in variants:
				v = default_v
			else:
				v = variants[0]

	var layers: Array = []
	var def_y_offset: int = int(d.get("pixel_y_offset", 0))
	for key in d.keys():
		if not (key is String) or not key.begins_with("layer_"):
			continue
		var layer: Dictionary = d[key]
		var layer_custom: String = layer.get("custom_animation", "")
		# 이 레이어가 이번 anim 에 기여하는지
		if layer_custom != "":
			if layer_custom != def_anim:
				continue
		else:
			# 표준 레이어는 def_anim 이 custom anim 이면 기여 안 함 (oversize 등)
			# 단, 일부 oversize 무기의 표준 레이어도 walk/hurt 에서만 쓰이므로
			# def_anim 이 커스텀 oversize 계열이면 표준 레이어 제외
			if _OVERSIZE_ANIMS.has(def_anim):
				continue

		var rel_dir: String = layer.get(body_type, "")
		if rel_dir == "":
			# body_type 별 키가 없으면 male fallback
			rel_dir = layer.get("male", "")
		if rel_dir == "":
			continue
		if not rel_dir.ends_with("/"):
			rel_dir += "/"

		var png_rel: String
		# ULPC 생성기 규칙 — 파일명은 언더스코어, variants 리스트는 스페이스.
		# (hash.js:138 `name.replaceAll(" ", "_")`)
		var v_file: String = v.replace(" ", "_")
		if has_variants:
			if layer_custom != "":
				png_rel = "%s%s.png" % [rel_dir, v_file]
			else:
				png_rel = "%s%s/%s.png" % [rel_dir, def_anim, v_file]
		else:
			# Variant-less (armor): {dir}/{anim}.png directly.
			if layer_custom != "":
				var trimmed := rel_dir
				if trimmed.ends_with("/"):
					trimmed = trimmed.substr(0, trimmed.length() - 1)
				png_rel = "%s.png" % trimmed
			else:
				png_rel = "%s%s.png" % [rel_dir, def_anim]

		var full_rel := ULPC_DIR + png_rel  # LPCSpriteLoader.BASE_PATH 기준
		var z: int = int(layer.get("zPos", 0))
		var layer_entry := {"path": full_rel, "zPos": z}
		if def_y_offset != 0:
			layer_entry["y_offset"] = def_y_offset
		layers.append(layer_entry)

	layers.sort_custom(func(a, b): return a["zPos"] < b["zPos"])
	out["layers"] = layers
	return out
