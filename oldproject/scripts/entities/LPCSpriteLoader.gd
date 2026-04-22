extends Node
class_name LPCSpriteLoader
## ElizaWy LPC 스프라이트 로더 — 개별 시트 로딩 + 레이어 합성 + SpriteFrames 생성
## 시트 포맷: 64x64 프레임, 4행(상/좌/하/우) × N열(프레임 수 가변)

const FRAME_W = 64
const FRAME_H = 64

# ULPC oversize slash: 192×192 frame, 6 frames per direction (LPCAnimationData 메타 참조)
const OVERSIZE_FRAME = 192
const OVERSIZE_SLASH_FRAMES = 6
# ULPC bow walk_128: 128×128 frame, 8 frames per direction
const WALK128_FRAME = 128
const WALK128_FRAMES = 8

# 행 → 방향 (ElizaWy 표준)
const DIR_UP = 0
const DIR_LEFT = 1
const DIR_DOWN = 2
const DIR_RIGHT = 3
const DIR_NAMES = {DIR_UP: "_up", DIR_LEFT: "_left", DIR_DOWN: "_down", DIR_RIGHT: "_right"}

const BASE_PATH = "res://assets/sprites/lpc/"

# ── 애니메이션별 시트 접미사 + 프레임 수 ──
# ULPC body 기준: walk 9프레임, slash 6프레임, idle 2프레임, shoot 13프레임, hurt 6프레임.
# 우리는 idle 은 1프레임 정지 사용.
const ANIM_CONFIG = {
	"idle":  {"suffix": "idle",  "frames": 1,  "speed": 1.0,  "loop": true},
	"walk":  {"suffix": "walk",  "frames": 9,  "speed": 36.0, "loop": true},
	"slash": {"suffix": "slash", "frames": 6,  "speed": 12.0, "loop": false},
	"shoot": {"suffix": "shoot", "frames": 9,  "speed": 14.0, "loop": false},
}

# shoot 시 body 는 ULPC shoot 시트 존재 → 별도 fallback 필요 없음. (legacy 변수 유지)
const SHOOT_BODY_FALLBACK_SUFFIX := "shoot"

# ULPC body 팔레트 틴트 — ULPC base 톤(pale)에 곱해서 skin_tone 재현.
# 근사치. 정확한 ULPC 팔레트 swap 은 별 작업.
const SKIN_TONE_TINT := {
	"porcelain": Color(1.02, 1.00, 0.98),
	"ivory":     Color(1.00, 0.98, 0.94),
	"peach":     Color(1.00, 0.92, 0.85),
	"honey":     Color(1.05, 0.88, 0.72),
	"tan":       Color(1.05, 0.82, 0.65),
	"tawny":     Color(1.05, 0.75, 0.55),
	"bronze":    Color(1.00, 0.72, 0.52),
	"brown":     Color(0.85, 0.62, 0.45),
	"coffee":    Color(0.70, 0.50, 0.35),
}

# ── 부위 영역 (64x64 프레임 내) — 부상 틴트용 ──
const BODY_PART_REGIONS = {
	"head":      Rect2i(20, 4, 24, 20),
	"torso":     Rect2i(18, 24, 28, 18),
	"left_arm":  Rect2i(12, 24, 10, 20),
	"right_arm": Rect2i(42, 24, 10, 20),
	"left_leg":  Rect2i(22, 42, 10, 20),
	"right_leg": Rect2i(32, 42, 10, 20),
}

const DAMAGE_TINT = {
	BodyParts.PartStatus.HEALTHY:  null,
	BodyParts.PartStatus.WOUNDED:  Color(1.0, 0.35, 0.25, 0.55),
	BodyParts.PartStatus.CRIPPLED: Color(0.75, 0.05, 0.02, 0.80),
	BodyParts.PartStatus.LOST:     Color(0.6, 0.05, 0.02, 0.85),
}

# ── 장비 아이템 ID → ElizaWy 에셋 매핑 ──
# 각 장비는 애니메이션별 시트 경로를 지정
# 경로가 없는 애니메이션은 해당 장비가 안 보임
## 장비 시트는 front(몸 앞)/behind(몸 뒤) 2겹으로 분리.
## behind는 body 레이어 전에 블렌드 → 몸 뒤로 숨김.
## walk_front/walk_behind 키 사용, 없으면 walk 단일 키로 fallback.
## def(assets/lpc_defs/index.json) 에 등록된 아이템은 LPCDefLoader 가 처리.
## 이 맵은 아직 def 가 없는 아이템(투구/부츠/장갑 등)을 위한 레거시 fallback.
const EQUIPMENT_MAP = {
	# 갑옷 — 하체
	"plate_legs":      {"slash": "props/plate_legs_slash.png", "walk": "props/plate_legs_walk.png"},
	# 투구
	"leather_helm":    {"slash": "props/leather_helm_slash.png", "walk": "props/leather_helm_walk.png"},
	"plate_helm":      {"slash": "props/plate_helm_slash.png", "walk": "props/plate_helm_walk.png"},
	# 부츠
	"leather_boots":   {"slash": "props/leather_boots_slash.png", "walk": "props/leather_boots_walk.png"},
	"plate_boots":     {"slash": "props/plate_boots_slash.png", "walk": "props/plate_boots_walk.png"},
	# 장갑
	"plate_gloves":    {"slash": "props/plate_gloves_slash.png", "walk": "props/plate_gloves_walk.png"},
}

# ── 메인 API ──

## appearance 기반 캐릭터 프레임 생성
## appearance = {"body_type": "masculine", "skin_tone": "peach", "hair_style": "parted", "hair_color": "brown"}
func create_player_frames(appearance: Dictionary = {}, equipped_items: Array = [], damage_status: Dictionary = {}) -> SpriteFrames:
	var body_type = appearance.get("body_type", "masculine")
	var skin_tone = appearance.get("skin_tone", "peach")
	var hair_style = appearance.get("hair_style", "parted")
	var hair_color = appearance.get("hair_color", "brown")

	var frames = SpriteFrames.new()
	frames.remove_animation("default")

	for anim_id in ANIM_CONFIG:
		var config = ANIM_CONFIG[anim_id]
		var suffix = config["suffix"]
		# ULPC body 는 shoot 시트 보유 → suffix 를 그대로 씀.
		var body_suffix: String = suffix

		# 레이어 시트 경로 수집
		var layer_paths: Array = []

		# 1. Body — ULPC 공식 body 시트(9프레임) + 피부 톤 틴트.
		var gender_dir: String = "female" if body_type.begins_with("feminine") else "male"
		var body_rel: String = "res://assets/ulpc/body/bodies/%s/%s.png" % [gender_dir, body_suffix]
		var skin_tint: Color = SKIN_TONE_TINT.get(skin_tone, Color.WHITE)
		layer_paths.append({"path": body_rel, "tint": skin_tint})

		var def_gender: String = "female" if body_type.begins_with("feminine") else "male"

		# 2. Head — ULPC human head, body 와 동일 피부톤 tint.
		var head_def: String = "head_human_female" if def_gender == "female" else "head_human_male"
		_add_def_layers(layer_paths, head_def, body_suffix, def_gender, "", skin_tint)
		var has_chest_eq := _any_equipped_in_slot(equipped_items, "chest")
		var has_legs_eq  := _any_equipped_in_slot(equipped_items, "legs")
		var has_feet_eq  := _any_equipped_in_slot(equipped_items, "feet")

		# 2. Default clothing — 장비 없으면 기본 의상.
		if not has_chest_eq:
			_add_def_layers(layer_paths, "default_shirt", body_suffix, def_gender, "")
		if not has_legs_eq:
			_add_def_layers(layer_paths, "default_pants", body_suffix, def_gender, "brown")
		if not has_feet_eq:
			_add_def_layers(layer_paths, "leather_boots", body_suffix, def_gender, "brown")

		# 3. Hair — ULPC hair def. hair_style 별로 def id = "hair_{style}".
		# 게임 hair_color(brown/gray 등) → ULPC variant (dark brown 등) 매핑.
		var hair_def_id: String = "hair_%s" % hair_style
		var mapped_hair_color: String = _map_hair_color(hair_color)
		if LPCDefLoader.has_def(hair_def_id):
			_add_def_layers(layer_paths, hair_def_id, body_suffix, def_gender, mapped_hair_color)

		# 4. Equipment overlays — behind는 body 앞에 prepend
		# 활: walk → walk_128 (128×128 × 8); 장검: slash → oversize (192×192 × 6)
		# def 기반 아이템은 LPCDefLoader 가 frame_size/레이어를 결정.
		# 이번 anim 에 필요한 최대 frame_size 자동 감지 — 장비들 중 가장 큰 걸 캔버스로.
		var required_frame: int = FRAME_W  # 기본 64
		for item_id in equipped_items:
			if LPCDefLoader.has_def(item_id):
				var rr: Dictionary = LPCDefLoader.resolve(item_id, suffix, body_type, _material_of(item_id))
				required_frame = maxi(required_frame, int(rr.get("frame_size", 64)))
			elif item_id in EQUIPMENT_MAP:
				if suffix == "slash" and "slash_oversize_front" in EQUIPMENT_MAP[item_id]:
					required_frame = maxi(required_frame, OVERSIZE_FRAME)
				elif suffix == "walk" and "walk128_front" in EQUIPMENT_MAP[item_id]:
					required_frame = maxi(required_frame, WALK128_FRAME)
		# idle 에서도 walk_128 필요한 활/지팡이 대응.
		if suffix == "idle":
			for item_id in equipped_items:
				if LPCDefLoader.has_def(item_id):
					var rw2: Dictionary = LPCDefLoader.resolve(item_id, "walk", body_type, _material_of(item_id))
					required_frame = maxi(required_frame, int(rw2.get("frame_size", 64)))
		var oversize_active: bool = required_frame >= OVERSIZE_FRAME
		var walk128_active: bool = required_frame == WALK128_FRAME

		var eq_behind_paths: Array = []
		var eq_front_paths: Array = []
		for item_id in equipped_items:
			# def 기반 경로 (우선)
			if LPCDefLoader.has_def(item_id):
				var mat: String = _material_of(item_id)
				# walk128_idle 모드: idle 이어도 walk_128 레이어를 가져와 col 0 을
				# 정적으로 반복 (큰 128 캔버스). 활 idle 에 활 표시 복원.
				var game_anim_for_def: String = String(suffix)
				if suffix == "idle" and walk128_active:
					game_anim_for_def = "walk"
				var r2: Dictionary = LPCDefLoader.resolve(item_id, game_anim_for_def, body_type, mat)
				var layers: Array = r2.get("layers", [])
				# 재질 tint: def variants 에 매칭되는 sprite 가 없을 때만 적용.
				var apply_tint: bool = mat != "" and not LPCDefLoader.has_material_variant(item_id, mat)
				var tint: Color = Color.WHITE
				if apply_tint:
					tint = ItemDatabase.get_material_color(mat)
				for l in layers:
					var path: String = l.get("path", "")
					var zp: int = int(l.get("zPos", 0))
					var y_off: int = int(l.get("y_offset", 0))
					if path == "":
						continue
					var is_behind: bool = zp < LPCDefLoader.BODY_Z_POS
					var entry: Variant = path
					if apply_tint or y_off != 0:
						entry = {"path": path}
						if apply_tint:
							entry["tint"] = tint
						if y_off != 0:
							entry["y_offset"] = y_off
					# idle/walk/slash 공통 — zPos 기준으로 body 앞/뒤 분리.
					# (이전: idle 에서 모두 static 경로로 넣어 body 위에 덮어쓰는 버그
					# → 방패 bg(zPos=2)/숏소드 bg(zPos=9)가 UP 방향에서 몸을 뚫고 나옴)
					if is_behind:
						eq_behind_paths.append(entry)
					else:
						eq_front_paths.append(entry)
				continue
			if item_id in EQUIPMENT_MAP:
				var eq = EQUIPMENT_MAP[item_id]
				var front_key = suffix + "_front"
				var behind_key = suffix + "_behind"
				if oversize_active:
					front_key = "slash_oversize_front"
					behind_key = "slash_oversize_behind"
				elif walk128_active:
					front_key = "walk128_front"
					behind_key = "walk128_behind"
				var behind_path = ""
				var front_path = ""
				if front_key in eq:
					front_path = eq[front_key]
				elif suffix in eq:
					front_path = eq[suffix]
				elif suffix == "idle" and "walk_front" in eq:
					front_path = eq["walk_front"]
				elif suffix == "idle" and "walk" in eq:
					front_path = eq["walk"]
				if behind_key in eq:
					behind_path = eq[behind_key]
				elif suffix == "idle" and "walk_behind" in eq:
					behind_path = eq["walk_behind"]

				# 재질 변이 (front만 — behind는 재질별 분리 안 함)
				if front_path != "":
					var material_path = _get_material_variant(item_id, suffix)
					if material_path != "" and ResourceLoader.exists(BASE_PATH + material_path):
						front_path = material_path

				if behind_path != "":
					eq_behind_paths.append(behind_path)
				if front_path != "":
					eq_front_paths.append(front_path)

		# 레이어 순서: behind 장비 → body → head → ... → front 장비
		# behind는 레이어 배열 맨 앞에 insert
		for i in range(eq_behind_paths.size() - 1, -1, -1):
			layer_paths.insert(0, eq_behind_paths[i])
		for p in eq_front_paths:
			layer_paths.append(p)

		# 레이어 합성 — 모드별 캔버스/프레임 크기
		var sheet: Image
		var cfg_frames: int = int(config.get("frames", 8))
		if oversize_active:
			sheet = _compose_layers_sized(layer_paths, OVERSIZE_FRAME, OVERSIZE_SLASH_FRAMES)
		elif walk128_active:
			# walk 는 body 싱크용 8 cols, idle 은 3 cols + freeze.
			if suffix == "idle":
				sheet = _compose_layers_sized(layer_paths, WALK128_FRAME, cfg_frames, true)
			else:
				sheet = _compose_layers_sized(layer_paths, WALK128_FRAME, WALK128_FRAMES)
		else:
			# 캔버스 크기를 ANIM_CONFIG 기준으로 고정 — body 기준 프레임 수.
			# ULPC 9프레임 레이어가 먼저 prepend 되더라도 body 8프레임 캔버스에 맞춤.
			var canvas_w := FRAME_W * cfg_frames
			var canvas_h := FRAME_H * 4
			sheet = _compose_layers(layer_paths, canvas_w, canvas_h)
		if not sheet:
			continue

		# 부상 표현: 틴트 대신 에셋 기반으로 전환 예정 — 현재 비활성
		# TODO: bandage/wound 오버레이 에셋 적용

		# 프레임 추출 → 애니메이션 등록
		var fw = FRAME_W
		var fh = FRAME_H
		if oversize_active:
			fw = OVERSIZE_FRAME; fh = OVERSIZE_FRAME
		elif walk128_active:
			fw = WALK128_FRAME; fh = WALK128_FRAME
		var actual_cols = sheet.get_width() / fw
		# config.frames 상한 적용 (idle 1프레임 고정 등).
		var max_frames: int = int(config.get("frames", actual_cols))
		if max_frames > 0:
			actual_cols = mini(actual_cols, max_frames)
		for dir in [DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT]:
			var dir_suffix = DIR_NAMES[dir]
			var anim_name = ""

			if anim_id == "idle":
				anim_name = "idle" + dir_suffix
			elif anim_id == "walk":
				anim_name = "walk" + dir_suffix
			elif anim_id == "slash":
				anim_name = "attack" + dir_suffix
			elif anim_id == "shoot":
				anim_name = "shoot" + dir_suffix

			var tex_list: Array = []
			for col in range(actual_cols):
				tex_list.append(_extract_frame_sized(sheet, col, dir, fw, fh))

			_add_anim(frames, anim_name, tex_list, config["speed"], config["loop"])

		# 하위 호환 (방향 없는 이름 = DOWN)
		if anim_id == "idle":
			_add_anim(frames, "idle", [_extract_frame(sheet, 0, DIR_DOWN)], 1.0, true)
		elif anim_id == "walk":
			var wf: Array = []
			for col in range(actual_cols):
				wf.append(_extract_frame(sheet, col, DIR_DOWN))
			_add_anim(frames, "walk", wf, 10.0, true)
		elif anim_id == "slash":
			var af: Array = []
			for col in range(actual_cols):
				af.append(_extract_frame(sheet, col, DIR_DOWN))
			_add_anim(frames, "attack", af, 12.0, false)
		elif anim_id == "shoot":
			var sf: Array = []
			for col in range(actual_cols):
				sf.append(_extract_frame(sheet, col, DIR_DOWN))
			_add_anim(frames, "shoot", sf, 14.0, false)

	# hurt = idle 재사용 (ULPC body idle)
	var _gd: String = "female" if String(appearance.get("body_type", "masculine")).begins_with("feminine") else "male"
	var _tone: String = appearance.get("skin_tone", "peach")
	var _skin_tint: Color = SKIN_TONE_TINT.get(_tone, Color.WHITE)
	var idle_sheet = _compose_layers([{
		"path": "res://assets/ulpc/body/bodies/%s/idle.png" % _gd,
		"tint": _skin_tint,
	}])
	if idle_sheet:
		var hf: Array = []
		var cols = idle_sheet.get_width() / FRAME_W
		for i in range(cols):
			hf.append(_extract_frame(idle_sheet, i, DIR_DOWN))
		_add_anim(frames, "hurt", hf, 8.0, false)

	# death = idle 첫 프레임
	if idle_sheet:
		_add_anim(frames, "death", [_extract_frame(idle_sheet, 0, DIR_DOWN)], 1.0, false)

	return frames

## 인간형 몬스터 프레임 생성 (ULPC body 에셋 기반)
## monster_body: "skeleton", "zombie", "muscular"
## tint: 색 변환 (예: 오크=녹색)
func create_monster_frames(monster_body: String, tint: Color = Color.WHITE) -> SpriteFrames:
	var frames = SpriteFrames.new()
	frames.remove_animation("default")

	# head 레이어가 있으면 body + head 합성
	var head_layers = {}
	for anim in ["walk", "slash", "hurt"]:
		var head_file = "monsters/%s_head_%s.png" % [monster_body, anim]
		if ResourceLoader.exists(BASE_PATH + head_file):
			head_layers[anim] = head_file

	var anim_map = {
		"walk": {"file": "monsters/%s_walk.png" % monster_body, "speed": 10.0, "prefix": "walk"},
		"slash": {"file": "monsters/%s_slash.png" % monster_body, "speed": 12.0, "prefix": "attack"},
		"hurt": {"file": "monsters/%s_hurt.png" % monster_body, "speed": 8.0, "prefix": "hurt"},
	}

	for anim_id in anim_map:
		var info = anim_map[anim_id]
		var layers = [info["file"]]
		if anim_id in head_layers:
			layers.append(head_layers[anim_id])
		var sheet = _compose_layers(layers)
		if not sheet:
			continue

		# 색 틴트 적용
		if tint != Color.WHITE:
			_apply_color_tint(sheet, tint)

		var actual_cols = sheet.get_width() / FRAME_W
		var actual_rows = sheet.get_height() / FRAME_H

		if actual_rows >= 4:
			for dir in [DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT]:
				var tex_list: Array = []
				for col in range(actual_cols):
					tex_list.append(_extract_frame(sheet, col, dir))
				var anim_name = info["prefix"] + DIR_NAMES[dir]
				_add_anim(frames, anim_name, tex_list, info["speed"], anim_id == "walk")
			# 하위 호환
			var compat: Array = []
			for col in range(actual_cols):
				compat.append(_extract_frame(sheet, col, DIR_DOWN))
			_add_anim(frames, info["prefix"], compat, info["speed"], anim_id == "walk")
		else:
			# hurt 등 1행짜리
			var tex_list: Array = []
			for col in range(actual_cols):
				tex_list.append(_extract_frame(sheet, col, 0))
			_add_anim(frames, info["prefix"], tex_list, info["speed"], false)

	# idle = walk 첫 프레임 — 머리 레이어 포함
	var walk_path = "monsters/%s_walk.png" % monster_body
	var walk_layers: Array = [walk_path]
	if "walk" in head_layers:
		walk_layers.append(head_layers["walk"])
	var walk_sheet = _compose_layers(walk_layers)
	if walk_sheet:
		if tint != Color.WHITE:
			_apply_color_tint(walk_sheet, tint)
		for dir in [DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT]:
			_add_anim(frames, "idle" + DIR_NAMES[dir], [_extract_frame(walk_sheet, 0, dir)], 1.0, true)
		_add_anim(frames, "idle", [_extract_frame(walk_sheet, 0, DIR_DOWN)], 1.0, true)
		_add_anim(frames, "death", [_extract_frame(walk_sheet, 0, DIR_DOWN)], 1.0, false)

	return frames

## 스켈레톤 프레임 (호환 래퍼)
func create_skeleton_frames() -> SpriteFrames:
	var path = BASE_PATH + "monsters/skeleton_walk.png"
	if ResourceLoader.exists(path):
		return create_monster_frames("skeleton")
	return SpriteGenerator.create_skeleton_frames(Color(0.9, 0.9, 0.85))

## 색 틴트 (전체 시트에 곱하기 블렌드)
func _apply_color_tint(sheet: Image, tint: Color) -> void:
	for y in range(sheet.get_height()):
		for x in range(sheet.get_width()):
			var src = sheet.get_pixel(x, y)
			if src.a < 0.05:
				continue
			sheet.set_pixel(x, y, Color(src.r * tint.r, src.g * tint.g, src.b * tint.b, src.a))

# ── 레이어 합성 ──

## 장비 고정 블렌드 — 각 방향 row 0번 col 프레임을 해당 row의 모든 col에 반복
func _blend_static_equipment(sheet: Image, eq_paths: Array) -> void:
	var sheet_cols = sheet.get_width() / FRAME_W
	var sheet_rows = sheet.get_height() / FRAME_H
	for entry in eq_paths:
		var pt := _entry_path_tint(entry)
		var raw_path: String = pt[0]
		var tint: Color = pt[1]
		var y_off: int = pt[2]
		var skip_up: bool = pt[3]
		var path = raw_path if raw_path.begins_with("res://") else BASE_PATH + raw_path
		var layer_img := _load_layer_image(path, tint)
		if not layer_img:
			continue
		var layer_rows = layer_img.get_height() / FRAME_H
		for row in sheet_rows:
			if row >= layer_rows:
				continue
			if skip_up and row == DIR_UP:
				continue
			var src_rect = Rect2i(0, row * FRAME_H, FRAME_W, FRAME_H)
			if src_rect.position.x + src_rect.size.x > layer_img.get_width():
				continue
			for col in sheet_cols:
				sheet.blend_rect(layer_img, src_rect, Vector2i(col * FRAME_W, row * FRAME_H + y_off))

## 큰 캔버스(frame×cols × frame×4)에 64×64 작은 레이어를 중앙 패딩 후 합성.
## frame: 128(walk_128) 또는 192(slash_oversize), cols: 8 또는 6.
## 큰 캔버스 합성. freeze_native_col0=true 면 네이티브 frame 크기 소스(활 walk_128
## 같은 것)를 col 0 만 뽑아 모든 dest col 에 반복 — idle 모드.
func _compose_layers_sized(layer_files: Array, frame: int, cols: int,
		freeze_native_col0: bool = false) -> Image:
	var canvas_w = frame * cols
	var canvas_h = frame * 4
	var pad = (frame - FRAME_W) / 2
	var result = Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
	result.fill(Color.TRANSPARENT)
	for entry in layer_files:
		var pt := _entry_path_tint(entry)
		var raw_path: String = pt[0]
		var tint: Color = pt[1]
		var y_off: int = pt[2]
		var skip_up: bool = pt[3]
		var path = raw_path if raw_path.begins_with("res://") else BASE_PATH + raw_path
		var img := _load_layer_image(path, tint)
		if not img:
			continue
		# 소스 frame 크기를 height 로 자동 감지 (4행이 표준):
		#   height == frame*4 → 네이티브 frame×frame (oversize/walk_128 PNG)
		#   height == FRAME_H*4 → 소형 64×64 (body/clothing 등) — 중앙 패딩
		var src_frame: int = FRAME_W
		var src_pad: int = pad
		var src_h: int = img.get_height()
		if src_h == frame * 4:
			src_frame = frame
			src_pad = 0
		elif src_h == FRAME_H * 4:
			src_frame = FRAME_W
			src_pad = pad
		else:
			# 비정형: 맞는 가정 없음 — 작은 cell 가정으로 폴백
			src_frame = FRAME_W
			src_pad = pad
		var src_cols = img.get_width() / src_frame
		var src_rows = img.get_height() / src_frame
		var rows_to_use = mini(src_rows, 4)
		# walk_128 프레임 매핑: ULPC 원본은 13프레임(0=stand, 1~12=확장 walk),
		# body 는 8프레임(0~7=순수 걸음). 캔버스 8 컬럼에 맞추려면 네이티브
		# 소스(128)는 col 1~8 을 취해 body 와 보폭 싱크를 맞춘다.
		# idle 모드(freeze_native_col0) 에선 col 0(standing) 을 모든 dest col 에 반복.
		var is_native: bool = (src_frame == frame)
		var freeze: bool = freeze_native_col0 and is_native
		var src_col_offset: int = 0
		if not freeze and frame == WALK128_FRAME and is_native and src_cols > cols:
			src_col_offset = 1
		var cols_to_use = cols if freeze else mini(src_cols - src_col_offset, cols)
		for row in rows_to_use:
			if skip_up and row == DIR_UP:
				continue
			for col in cols_to_use:
				var src_col: int = 0 if freeze else (col + src_col_offset)
				var src = Rect2i(src_col * src_frame, row * src_frame, src_frame, src_frame)
				var dst = Vector2i(col * frame + src_pad, row * frame + src_pad + y_off)
				result.blend_rect(img, src, dst)
	return result

## 가변 프레임 사이즈 추출
func _extract_frame_sized(sheet: Image, col: int, row: int, fw: int, fh: int) -> ImageTexture:
	var frame_img = Image.create(fw, fh, false, Image.FORMAT_RGBA8)
	frame_img.fill(Color.TRANSPARENT)
	var src_x = col * fw
	var src_y = row * fh
	if src_x + fw > sheet.get_width() or src_y + fh > sheet.get_height():
		return ImageTexture.create_from_image(frame_img)
	frame_img.blit_rect(sheet, Rect2i(src_x, src_y, fw, fh), Vector2i.ZERO)
	return ImageTexture.create_from_image(frame_img)

## 캔버스 크기를 명시하면 그 크기로 생성, 아니면 첫 레이어 크기로 생성.
## 레이어가 캔버스보다 1프레임 넓으면 col 0(ULPC stand) 스킵 — body 8프레임과 정렬.
func _compose_layers(layer_files: Array, canvas_w: int = 0, canvas_h: int = 0) -> Image:
	var result: Image = null
	if canvas_w > 0 and canvas_h > 0:
		result = Image.create(canvas_w, canvas_h, false, Image.FORMAT_RGBA8)
		result.fill(Color.TRANSPARENT)

	for entry in layer_files:
		var pt := _entry_path_tint(entry)
		var raw_path: String = pt[0]
		var tint: Color = pt[1]
		var y_off: int = pt[2]
		var skip_up: bool = pt[3]
		var path = raw_path if raw_path.begins_with("res://") else BASE_PATH + raw_path
		var layer_img := _load_layer_image(path, tint)
		if not layer_img:
			continue

		if result == null:
			result = Image.create(layer_img.get_width(), layer_img.get_height(), false, Image.FORMAT_RGBA8)
			result.fill(Color.TRANSPARENT)

		var blend_w = mini(layer_img.get_width(), result.get_width())
		var blend_h = mini(layer_img.get_height(), result.get_height())
		var src_x: int = 0
		if skip_up:
			# UP 행(row 0) 건너뛰기 — LEFT/DOWN/RIGHT 만.
			var row_h: int = FRAME_H
			for r in [DIR_LEFT, DIR_DOWN, DIR_RIGHT]:
				result.blend_rect(layer_img,
					Rect2i(src_x, r * row_h, blend_w, row_h),
					Vector2i(0, r * row_h + y_off))
		else:
			result.blend_rect(layer_img, Rect2i(src_x, 0, blend_w, blend_h), Vector2i(0, y_off))

	return result

# ── 부상 틴트 ──

func _apply_damage_tint(sheet: Image, damage_status: Dictionary) -> void:
	for part_id in damage_status:
		var status: int = damage_status[part_id]
		if status == BodyParts.PartStatus.HEALTHY:
			continue
		var tint = DAMAGE_TINT.get(status)
		if tint == null:
			continue
		if part_id not in BODY_PART_REGIONS:
			continue
		var region: Rect2i = BODY_PART_REGIONS[part_id]
		_tint_region_in_all_frames(sheet, region, tint)

func _tint_region_in_all_frames(sheet: Image, region: Rect2i, tint: Color) -> void:
	var cols: int = sheet.get_width() / FRAME_W
	var rows: int = sheet.get_height() / FRAME_H
	for col in cols:
		for row in rows:
			var fx = col * FRAME_W
			var fy = row * FRAME_H
			for ry in region.size.y:
				for rx in region.size.x:
					var x = fx + region.position.x + rx
					var y = fy + region.position.y + ry
					if x >= sheet.get_width() or y >= sheet.get_height():
						continue
					var src = sheet.get_pixel(x, y)
					if src.a < 0.05:
						continue
					var a = tint.a
					var r = tint.r * a + src.r * (1.0 - a)
					var g = tint.g * a + src.g * (1.0 - a)
					var b = tint.b * a + src.b * (1.0 - a)
					sheet.set_pixel(x, y, Color(r, g, b, src.a))

# ── 유틸 ──

## UP(row 0) 한정으로 eq_behind 레이어를 body 위에 덧칠.
## 소스가 canvas_frame 과 같은 크기면 직접 blit, 64 소스면 중앙 패딩.
func _overlay_up_behind(sheet: Image, eq_behind: Array, canvas_frame: int) -> void:
	for entry in eq_behind:
		var pt := _entry_path_tint(entry)
		var raw_path: String = pt[0]
		var tint: Color = pt[1]
		var path = raw_path if raw_path.begins_with("res://") else BASE_PATH + raw_path
		var img := _load_layer_image(path, tint)
		if not img:
			continue
		var src_frame: int = img.get_height() / 4
		if src_frame <= 0:
			continue
		if src_frame == canvas_frame:
			# 네이티브 동일 — UP 행 그대로 블렌드
			var blend_w = mini(img.get_width(), sheet.get_width())
			sheet.blend_rect(img, Rect2i(0, 0, blend_w, src_frame), Vector2i.ZERO)
		else:
			# 64 소스가 canvas_frame 셀에 중앙 패딩
			var pad: int = (canvas_frame - src_frame) / 2
			var src_cols = img.get_width() / src_frame
			var dst_cols = sheet.get_width() / canvas_frame
			var cols = mini(src_cols, dst_cols)
			for col in cols:
				var src = Rect2i(col * src_frame, 0, src_frame, src_frame)
				var dst = Vector2i(col * canvas_frame + pad, pad)
				sheet.blend_rect(img, src, dst)

## layer 엔트리를 [path, tint, y_offset, skip_up_row] 로 분해.
func _entry_path_tint(entry) -> Array:
	if entry is Dictionary:
		return [
			String(entry.get("path", "")),
			entry.get("tint", Color.WHITE),
			int(entry.get("y_offset", 0)),
			bool(entry.get("skip_up_row", false)),
		]
	return [String(entry), Color.WHITE, 0, false]

## 이미지 로드 + 선택적 RGB 멀티플라이 (alpha 보존).
func _load_layer_image(path: String, tint: Color) -> Image:
	if not ResourceLoader.exists(path):
		return null
	var tex := load(path) as Texture2D
	if not tex:
		return null
	var img := tex.get_image()
	if not img:
		return null
	if tint == Color.WHITE:
		return img
	# tint 적용은 원본 보존을 위해 복사본에서.
	var copy := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	copy.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	for y in range(copy.get_height()):
		for x in range(copy.get_width()):
			var c := copy.get_pixel(x, y)
			if c.a < 0.05:
				continue
			copy.set_pixel(x, y, Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a))
	return copy

## 게임 hair_color → ULPC variant 매핑.
func _map_hair_color(c: String) -> String:
	match c:
		"brown": return "dark brown"
		"black": return "black"
		"blonde": return "blonde"
		"red": return "redhead"
		"gray": return "gray"
		"white": return "white"
		"blue": return "blue"
		"green": return "green"
	return c

## def 기반 레이어를 layer_paths 에 추가 (zPos 오름차순 유지).
## def 의 각 layer 를 {path, tint?, y_offset?} 딕셔너리로 넣음.
## override_tint != WHITE 면 강제 tint (ex: 피부톤 머리 → body skin tint).
func _add_def_layers(layer_paths: Array, def_id: String, game_anim: String,
		body_type: String, variant: String,
		override_tint: Color = Color.WHITE) -> void:
	if not LPCDefLoader.has_def(def_id):
		return
	var r: Dictionary = LPCDefLoader.resolve(def_id, game_anim, body_type, variant)
	var layers: Array = r.get("layers", [])
	for l in layers:
		var entry: Dictionary = {"path": l.get("path", "")}
		var y_off: int = int(l.get("y_offset", 0))
		if y_off != 0:
			entry["y_offset"] = y_off
		if override_tint != Color.WHITE:
			entry["tint"] = override_tint
		layer_paths.append(entry)

## equipped_items(Array of item_id) 중 주어진 slot 인 아이템이 있는지.
func _any_equipped_in_slot(equipped_items: Array, slot: String) -> bool:
	for item_id in equipped_items:
		var data: Dictionary = ItemDatabase.get_item(item_id)
		if data.is_empty():
			continue
		if String(data.get("slot", "")) == slot:
			return true
	return false

## 장착된 아이템의 재질 id 반환 (없으면 "")
func _material_of(item_id: String) -> String:
	if not PlayerData.is_initialized() or not PlayerData.inventory:
		return ""
	for slot in PlayerData.inventory.equipped:
		var eq = PlayerData.inventory.equipped[slot]
		if eq.get("id", "") == item_id and eq.has("material"):
			return String(eq["material"])
	return ""

## 재질별 스프라이트 경로 (장착 중인 아이템의 재질 확인)
func _get_material_variant(item_id: String, suffix: String) -> String:
	if not PlayerData.is_initialized() or not PlayerData.inventory:
		return ""
	# 장착된 동일 ID 아이템 찾기
	for slot in PlayerData.inventory.equipped:
		var eq = PlayerData.inventory.equipped[slot]
		if eq.get("id", "") == item_id and eq.has("material"):
			var material_id = eq["material"]
			return "props/%s_%s_%s.png" % [item_id, material_id, suffix]
	return ""

func _alpha_blend_into(dst: Image, overlay: Image) -> void:
	for y in range(dst.get_height()):
		for x in range(dst.get_width()):
			var src = overlay.get_pixel(x, y)
			if src.a < 0.01:
				continue
			var bg = dst.get_pixel(x, y)
			var a = src.a
			var r = src.r * a + bg.r * (1.0 - a)
			var g = src.g * a + bg.g * (1.0 - a)
			var b = src.b * a + bg.b * (1.0 - a)
			var out_a = a + bg.a * (1.0 - a)
			dst.set_pixel(x, y, Color(r, g, b, out_a))

func _extract_frame(sheet: Image, col: int, row: int) -> ImageTexture:
	var frame_img = Image.create(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8)
	var src_x = col * FRAME_W
	var src_y = row * FRAME_H
	if src_x + FRAME_W > sheet.get_width() or src_y + FRAME_H > sheet.get_height():
		frame_img.fill(Color.TRANSPARENT)
		return ImageTexture.create_from_image(frame_img)
	frame_img.blit_rect(sheet, Rect2i(src_x, src_y, FRAME_W, FRAME_H), Vector2i.ZERO)
	return ImageTexture.create_from_image(frame_img)

func _add_anim(frames: SpriteFrames, anim_name: String, textures: Array, speed: float, loop: bool = true) -> void:
	if frames.has_animation(anim_name):
		return
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, loop)
	frames.set_animation_speed(anim_name, speed)
	for tex in textures:
		frames.add_frame(anim_name, tex)
