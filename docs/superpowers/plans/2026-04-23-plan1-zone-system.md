# Zone System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 25층을 8개 존으로 분리하고, 존별 맵 생성 알고리즘·타일 테마·환경 피해를 구현한다.

**Architecture:** `ZoneManager` 싱글턴이 depth→zone 매핑과 존 설정을 담당. `MapGen`에 CA 알고리즘 추가. `DungeonMap`의 TERRAIN_BANDS를 ZoneManager 기반으로 교체. 환경 피해는 `hazard_tiles: Dictionary` (Vector2i→String)로 별도 추적하여 플레이어 이동 시 `Game.gd`에서 처리.

**Tech Stack:** GDScript 4.x, Godot 4.6, 기존 Status.gd resist_scale 시스템

**Spec:** `docs/superpowers/specs/2026-04-23-zone-monster-expansion-design.md`

---

## 파일 구조

| 파일 | 변경 |
|---|---|
| `scripts/core/ZoneManager.gd` | **신규** — depth→zone 매핑, 존별 설정 |
| `scripts/dungeon/MapGen.gd` | **수정** — CA, CA+Scatter 알고리즘 추가, style 파라미터 |
| `scripts/dungeon/DungeonMap.gd` | **수정** — TERRAIN_BANDS 교체, hazard_tiles 추가, 새 Tile enum 값 |
| `scripts/main/Game.gd` | **수정** — 존 스타일로 맵 생성, 환경 피해 처리 |
| `scripts/systems/Status.gd` | **수정** — poison, neg resist 원소 추가 |
| `project.godot` | **수정** — ZoneManager autoload 등록 |

---

## Task 1: ZoneManager 구현

**Files:**
- Create: `scripts/core/ZoneManager.gd`
- Modify: `project.godot`

- [ ] **Step 1: ZoneManager 파일 생성**

```gdscript
# scripts/core/ZoneManager.gd
extends Node

## Returns 0-based zone index for a given depth (1-25).
## Zone 0 = Dungeon (1-3), Zone 1 = Lair (4-6), ..., Zone 8 = Boss (25)
static func zone_for_depth(depth: int) -> int:
	if depth >= 25:
		return 8
	return clampi((depth - 1) / 3, 0, 7)

## Returns depth offset within a zone (0, 1, or 2).
static func depth_in_zone(depth: int) -> int:
	if depth >= 25:
		return 0
	return (depth - 1) % 3

static func zone_config(zone: int) -> Dictionary:
	return _ZONES[clampi(zone, 0, 8)]

static func config_for_depth(depth: int) -> Dictionary:
	return zone_config(zone_for_depth(depth))

const _ZONES: Array = [
	# Zone 0: Dungeon (1-3)
	{
		"name": "Dungeon",
		"map_style": "bsp",
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/pebble_brown0.png",
		"hazard": "",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 1: Lair (4-6)
	{
		"name": "Lair",
		"map_style": "ca",
		"wall": "res://assets/tiles/individual/dngn/wall/lair0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lair0.png",
		"hazard": "",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 2: Orc Mines (7-9)
	{
		"name": "Orc Mines",
		"map_style": "bsp_tight",
		"wall": "res://assets/tiles/individual/dngn/wall/wall_stone_orc0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/orc0.png",
		"hazard": "",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 3: Swamp (10-12)
	{
		"name": "Swamp",
		"map_style": "ca_water",
		"wall": "res://assets/tiles/individual/dngn/wall/wall_stone_lair0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/swamp0.png",
		"hazard": "poison_swamp",
		"hazard_element": "poison",
		"hazard_density": 0.18,
	},
	# Zone 4: Crypt (13-15)
	{
		"name": "Crypt",
		"map_style": "bsp_long",
		"wall": "res://assets/tiles/individual/dngn/wall/crypt0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/crypt0.png",
		"hazard": "neg_mist",
		"hazard_element": "neg",
		"hazard_density": 0.12,
	},
	# Zone 5: Ice Caves (16-18)
	{
		"name": "Ice Caves",
		"map_style": "ca_open",
		"wall": "res://assets/tiles/individual/dngn/wall/ice_wall0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/ice0.png",
		"hazard": "ice_floor",
		"hazard_element": "cold",
		"hazard_density": 0.15,
	},
	# Zone 6: Elven Halls (19-21)
	{
		"name": "Elven Halls",
		"map_style": "bsp_large",
		"wall": "res://assets/tiles/individual/dngn/wall/elf-stone0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/crystal_floor0.png",
		"hazard": "",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 7: Infernal (22-24)
	{
		"name": "Infernal",
		"map_style": "ca_lava",
		"wall": "res://assets/tiles/individual/dngn/wall/hell0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lava0.png",
		"hazard": "lava",
		"hazard_element": "fire",
		"hazard_density": 0.15,
	},
	# Zone 8: Boss (25)
	{
		"name": "Boss Chamber",
		"map_style": "boss",
		"wall": "res://assets/tiles/individual/dngn/wall/hell0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lava0.png",
		"hazard": "lava",
		"hazard_element": "fire",
		"hazard_density": 0.08,
	},
]
```

- [ ] **Step 2: project.godot에 autoload 등록**

`project.godot` 파일에서 기존 autoload 섹션에 추가:
```
[autoload]
...기존 항목들...
ZoneManager="*res://scripts/core/ZoneManager.gd"
```

- [ ] **Step 3: 에디터에서 프로젝트 열어 ZoneManager.zone_for_depth(1) == 0, zone_for_depth(25) == 8 확인 (디버그 출력)**

- [ ] **Step 4: 커밋**
```bash
git add scripts/core/ZoneManager.gd project.godot
git commit -m "feat: ZoneManager — depth→zone mapping and per-zone config"
```

---

## Task 2: MapGen CA 알고리즘 추가

**Files:**
- Modify: `scripts/dungeon/MapGen.gd`

- [ ] **Step 1: generate() 시그니처에 style 파라미터 추가**

`MapGen.gd`의 `generate()` 함수 시그니처를:
```gdscript
static func generate(width: int, height: int, map_seed: int = -1) -> Dictionary:
```
다음으로 교체:
```gdscript
static func generate(width: int, height: int, map_seed: int = -1, style: String = "bsp") -> Dictionary:
	match style:
		"ca", "ca_open":
			return _generate_ca(width, height, map_seed, style)
		"ca_water", "ca_lava":
			return _generate_ca_scatter(width, height, map_seed, style)
		"bsp_tight":
			return _generate_bsp(width, height, map_seed, 5, 4, 6, 4)
		"bsp_long":
			return _generate_bsp(width, height, map_seed, 4, 3, 6, 4, 5)
		"bsp_large":
			return _generate_bsp(width, height, map_seed, 6, 5, 12, 10)
		"boss":
			return _generate_boss(width, height, map_seed)
		_:  # "bsp" default
			return _generate_bsp(width, height, map_seed)
```

- [ ] **Step 2: 기존 BSP 로직을 _generate_bsp()로 래핑**

기존 `generate()` 본문을 `_generate_bsp()`로 추출:
```gdscript
static func _generate_bsp(width: int, height: int, map_seed: int = -1,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H,
		max_split_depth: int = MAX_SPLIT_DEPTH) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if map_seed >= 0:
		rng.seed = map_seed
	else:
		rng.randomize()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.WALL
	var rooms: Array[Rect2i] = []
	_split(Rect2i(1, 1, width - 2, height - 2), 0, rng, tiles, width, rooms,
		min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
	if rooms.is_empty():
		var fallback := Rect2i(width / 2 - 4, height / 2 - 3, 8, 6)
		rooms.append(fallback)
		for y in range(fallback.position.y, fallback.position.y + fallback.size.y):
			for x in range(fallback.position.x, fallback.position.x + fallback.size.x):
				tiles[y * width + x] = DungeonMap.Tile.FLOOR
	for i in range(rooms.size() - 1):
		_carve_corridor(rooms[i].get_center(), rooms[i + 1].get_center(), tiles, width, rng)
	var spawn: Vector2i = rooms[0].get_center()
	var stairs_down: Vector2i = _farthest_floor(spawn, tiles, width, height)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down, "stairs_up": spawn, "rooms": rooms}
```

`_split`, `_carve_room`도 파라미터를 받도록 시그니처 수정:
```gdscript
static func _split(rect: Rect2i, depth: int, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H,
		max_split_depth: int = MAX_SPLIT_DEPTH) -> void:
	var area: int = rect.size.x * rect.size.y
	if depth >= max_split_depth or area < MIN_LEAF_AREA \
			or rect.size.x < min_room_w + 2 or rect.size.y < min_room_h + 2:
		_carve_room(rect, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h)
		return
	# ... 기존 분기 로직 유지, 재귀 호출에 파라미터 전달 ...
	_split(left_rect, depth + 1, rng, tiles, width, rooms,
		min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
	_split(right_rect, depth + 1, rng, tiles, width, rooms,
		min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)

static func _carve_room(leaf: Rect2i, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H) -> void:
	var mw: int = min(max_room_w, leaf.size.x - 2)
	var mh: int = min(max_room_h, leaf.size.y - 2)
	if mw < min_room_w or mh < min_room_h:
		return
	# ... 기존 방 생성 로직 유지 ...
```

- [ ] **Step 3: CA 알고리즘 추가**

파일 끝에 추가:
```gdscript
static func _generate_ca(width: int, height: int, map_seed: int, style: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if map_seed >= 0:
		rng.seed = map_seed
	else:
		rng.randomize()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	# 초기 랜덤 채우기 (45% FLOOR)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.FLOOR if rng.randf() < 0.45 else DungeonMap.Tile.WALL
	# 테두리는 항상 WALL
	for x in range(width):
		tiles[x] = DungeonMap.Tile.WALL
		tiles[(height - 1) * width + x] = DungeonMap.Tile.WALL
	for y in range(height):
		tiles[y * width] = DungeonMap.Tile.WALL
		tiles[y * width + width - 1] = DungeonMap.Tile.WALL
	# CA 반복 (open이면 birth threshold 낮춤)
	var birth: int = 4 if style == "ca_open" else 5
	var death: int = 5 if style == "ca_open" else 4
	var iterations: int = 4
	for _iter in range(iterations):
		var next := tiles.duplicate()
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var neighbors: int = _count_wall_neighbors(tiles, x, y, width, height)
				if tiles[y * width + x] == DungeonMap.Tile.WALL:
					next[y * width + x] = DungeonMap.Tile.WALL if neighbors >= death else DungeonMap.Tile.FLOOR
				else:
					next[y * width + x] = DungeonMap.Tile.WALL if neighbors >= birth else DungeonMap.Tile.FLOOR
		tiles = next
	# 가장 큰 연결 영역만 유지
	tiles = _keep_largest_region(tiles, width, height)
	# spawn과 stairs 배치
	var spawn: Vector2i = _find_floor_tile(tiles, width, height, rng)
	var stairs_down: Vector2i = _farthest_floor(spawn, tiles, width, height)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down, "stairs_up": spawn, "rooms": []}

static func _count_wall_neighbors(tiles: PackedByteArray, x: int, y: int, width: int, height: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				count += 1
				continue
			if tiles[ny * width + nx] == DungeonMap.Tile.WALL:
				count += 1
	return count

static func _keep_largest_region(tiles: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var visited: Dictionary = {}
	var best_region: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if visited.has(p) or tiles[y * width + x] == DungeonMap.Tile.WALL:
				continue
			var region: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [p]
			while not frontier.is_empty():
				var cur: Vector2i = frontier.pop_back()
				if visited.has(cur):
					continue
				visited[cur] = true
				region.append(cur)
				for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var n: Vector2i = cur + step
					if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
						continue
					if not visited.has(n) and tiles[n.y * width + n.x] == DungeonMap.Tile.FLOOR:
						frontier.append(n)
			if region.size() > best_region.size():
				best_region = region
	# 최대 영역 이외는 모두 WALL로
	var best_set: Dictionary = {}
	for p in best_region:
		best_set[p] = true
	var result := tiles.duplicate()
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if tiles[y * width + x] == DungeonMap.Tile.FLOOR and not best_set.has(p):
				result[y * width + x] = DungeonMap.Tile.WALL
	return result

static func _find_floor_tile(tiles: PackedByteArray, width: int, height: int,
		rng: RandomNumberGenerator) -> Vector2i:
	var floor_tiles: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if tiles[y * width + x] == DungeonMap.Tile.FLOOR:
				floor_tiles.append(Vector2i(x, y))
	if floor_tiles.is_empty():
		return Vector2i(width / 2, height / 2)
	return floor_tiles[rng.randi_range(0, floor_tiles.size() - 1)]
```

- [ ] **Step 4: CA+Scatter (Swamp/Infernal) 추가**

```gdscript
static func _generate_ca_scatter(width: int, height: int, map_seed: int, style: String) -> Dictionary:
	# 기본 CA 생성
	var result: Dictionary = _generate_ca(width, height, map_seed, "ca")
	var tiles: PackedByteArray = result["tiles"]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0xDEADBEEF
	# scatter_tile 값 결정
	var scatter_tile: int
	var density: float
	if style == "ca_water":
		scatter_tile = DungeonMap.Tile.WATER
		density = 0.15
	else:  # ca_lava
		scatter_tile = DungeonMap.Tile.LAVA
		density = 0.12
	# FLOOR 타일 중 일부를 scatter 타일로 교체 (계단 인근 제외)
	var spawn: Vector2i = result["spawn"]
	var stairs: Vector2i = result["stairs_down"]
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if tiles[y * width + x] != DungeonMap.Tile.FLOOR:
				continue
			if p.distance_to(spawn) < 3.0 or p.distance_to(stairs) < 3.0:
				continue
			if rng.randf() < density:
				tiles[y * width + x] = scatter_tile
	result["tiles"] = tiles
	return result
```

- [ ] **Step 5: Boss 방 생성 추가**

```gdscript
static func _generate_boss(width: int, height: int, map_seed: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.WALL
	# 중앙에 20×15 방
	var room_w: int = 20
	var room_h: int = 15
	var x0: int = (width - room_w) / 2
	var y0: int = (height - room_h) / 2
	for y in range(y0, y0 + room_h):
		for x in range(x0, x0 + room_w):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR
	# 진입 복도 (위쪽)
	var cx: int = width / 2
	for y in range(2, y0):
		tiles[y * width + cx] = DungeonMap.Tile.FLOOR
	var spawn := Vector2i(cx, y0 + room_h - 2)
	var stairs_up := Vector2i(cx, 3)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	# 계단 내려가기 없음 (보스 방)
	var boss_room := Rect2i(x0, y0, room_w, room_h)
	return {"tiles": tiles, "spawn": spawn, "stairs_down": spawn,
		"stairs_up": stairs_up, "rooms": [boss_room]}
```

- [ ] **Step 6: 에디터에서 테스트 — Game.gd의 _generate_floor에서 style="ca"로 임시 호출, 맵이 자연 동굴 형태로 생성되는지 확인**

- [ ] **Step 7: 커밋**
```bash
git add scripts/dungeon/MapGen.gd
git commit -m "feat: MapGen — CA, CA+Scatter, BSP variants, Boss room generation"
```

---

## Task 3: DungeonMap — 새 Tile enum 값 + hazard_tiles 추가

**Files:**
- Modify: `scripts/dungeon/DungeonMap.gd`

- [ ] **Step 1: Tile enum에 WATER, LAVA 추가**

```gdscript
enum Tile {
	WALL = 0,
	FLOOR = 1,
	STAIRS_UP = 2,
	STAIRS_DOWN = 3,
	DOOR_CLOSED = 4,
	DOOR_OPEN = 5,
	WATER = 6,
	LAVA = 7,
}
```

- [ ] **Step 2: 텍스처 상수 추가**

기존 `TEX_STAIRS_UP`, `TEX_STAIRS_DOWN` 아래에 추가:
```gdscript
const TEX_WATER: Texture2D = preload(
	"res://assets/tiles/individual/dngn/water/shallow_water_top_features10.png")
const TEX_LAVA: Texture2D = preload(
	"res://assets/tiles/individual/dngn/floor/lava0.png")
```

- [ ] **Step 3: TERRAIN_BANDS 제거 → ZoneManager 기반으로 교체**

`_load_atmosphere()` 함수를 교체:
```gdscript
func _load_atmosphere(depth: int) -> void:
	var cfg: Dictionary = ZoneManager.config_for_depth(depth)
	_tex_wall = load(cfg["wall"]) as Texture2D
	_tex_floor = load(cfg["floor"]) as Texture2D
```

`TERRAIN_BANDS` const 삭제.

- [ ] **Step 4: `_texture_for()`, `_glyph_for()`, `is_walkable()` 에 WATER/LAVA 처리 추가**

```gdscript
func is_walkable(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t != Tile.WALL and t != Tile.DOOR_CLOSED
	# WATER, LAVA는 걸을 수 있음 (피해는 Game.gd에서 처리)

func _texture_for(t: int) -> Texture2D:
	match t:
		Tile.WALL: return _tex_wall
		Tile.FLOOR: return _tex_floor
		Tile.STAIRS_UP: return TEX_STAIRS_UP
		Tile.STAIRS_DOWN: return TEX_STAIRS_DOWN
		Tile.WATER: return TEX_WATER
		Tile.LAVA: return TEX_LAVA
	return null

func _glyph_for(t: int) -> String:
	match t:
		Tile.WALL: return "#"
		Tile.FLOOR: return "."
		Tile.STAIRS_UP: return "<"
		Tile.STAIRS_DOWN: return ">"
		Tile.DOOR_CLOSED: return "+"
		Tile.DOOR_OPEN: return "'"
		Tile.WATER: return "~"
		Tile.LAVA: return "~"
	return "?"

func _glyph_color_for(t: int) -> Color:
	match t:
		Tile.WALL: return Color(0.65, 0.55, 0.38)
		Tile.FLOOR: return Color(0.45, 0.42, 0.35)
		Tile.STAIRS_UP: return Color(1.0, 1.0, 0.6)
		Tile.STAIRS_DOWN: return Color(0.6, 1.0, 1.0)
		Tile.DOOR_CLOSED: return Color(0.75, 0.55, 0.3)
		Tile.DOOR_OPEN: return Color(0.55, 0.4, 0.25)
		Tile.WATER: return Color(0.3, 0.5, 0.9)
		Tile.LAVA: return Color(1.0, 0.4, 0.1)
	return Color.WHITE
```

- [ ] **Step 5: 에디터 실행 — 기존 플레이 정상 동작, 타일 테마가 존별로 바뀌는지 확인**

- [ ] **Step 6: 커밋**
```bash
git add scripts/dungeon/DungeonMap.gd
git commit -m "feat: DungeonMap — zone-based terrain, WATER/LAVA tile types"
```

---

## Task 4: Game.gd — 존 스타일로 맵 생성 + 환경 피해

**Files:**
- Modify: `scripts/main/Game.gd`

- [ ] **Step 1: `_generate_floor()`에서 ZoneManager 스타일로 맵 생성**

`_generate_floor()` 내 `map.generate(map_seed)` 호출을:
```gdscript
var zone_cfg: Dictionary = ZoneManager.config_for_depth(depth)
map.generate(map_seed, zone_cfg["map_style"])
```
로 교체. (DungeonMap.generate()도 style 파라미터 받도록 수정 필요 — 아래 참조)

`DungeonMap.gd`의 `generate()` 시그니처 수정:
```gdscript
func generate(map_seed: int = -1, style: String = "bsp") -> void:
	var result: Dictionary = MapGen.generate(GRID_W, GRID_H, map_seed, style)
	# ... 나머지 동일
```

- [ ] **Step 2: 환경 피해 처리 함수 추가**

`Game.gd`에 추가:
```gdscript
func _apply_hazard_damage(pos: Vector2i) -> void:
	var t: int = map.tile_at(pos)
	var zone_cfg: Dictionary = ZoneManager.config_for_depth(GameManager.depth)
	var element: String = zone_cfg.get("hazard_element", "")
	if element == "":
		return
	var zone_idx: int = ZoneManager.zone_for_depth(GameManager.depth)
	var depth_in_zone: int = ZoneManager.depth_in_zone(GameManager.depth)
	# 첫 번째 층은 50% 강도
	var intensity: float = 0.5 if depth_in_zone == 0 else 1.0
	var hazard_tile: bool = (t == DungeonMap.Tile.LAVA or t == DungeonMap.Tile.WATER)
	var neg_mist: bool = (element == "neg" and t == DungeonMap.Tile.FLOOR)
	var ice_floor: bool = (element == "cold" and t == DungeonMap.Tile.FLOOR)
	if not hazard_tile and not neg_mist and not ice_floor:
		return
	# 저항 확인
	var resist_level: int = Status.resist_level(player.resists, element)
	if resist_level >= 1:
		return
	var base_dmg: int = 0
	match element:
		"fire": base_dmg = 8   # 용암
		"poison": base_dmg = 4  # 독 늪 (DoT)
		"cold": base_dmg = 3    # 빙판
		"neg": base_dmg = 2     # 음에너지 안개
	var dmg: int = int(round(base_dmg * intensity))
	dmg = Status.resist_scale(dmg, player.resists, element)
	if dmg <= 0:
		return
	player.hp -= dmg
	var msg: String = ""
	match element:
		"fire": msg = "The lava scorches you for %d damage!" % dmg
		"poison": msg = "Toxic vapors poison you for %d damage!" % dmg
		"cold": msg = "The frozen ground numbs you for %d damage!" % dmg
		"neg": msg = "Negative energy drains you for %d damage!" % dmg
	CombatLog.post(msg, Color(0.9, 0.4, 0.2))
	if player.hp <= 0:
		_on_player_death()
```

- [ ] **Step 3: 플레이어 이동 후 `_apply_hazard_damage()` 호출**

`Game.gd`에서 플레이어 이동이 완료되는 지점 (통상 `_move_player()` 또는 이동 처리 끝)에 추가:
```gdscript
_apply_hazard_damage(player.grid_pos)
```

- [ ] **Step 4: 에디터에서 테스트**

- Infernal 층 (depth 22)으로 치트 이동, 용암 타일 위에 서면 화염 피해 메시지 확인
- fire+ 저항 있으면 피해 없는지 확인

- [ ] **Step 5: 커밋**
```bash
git add scripts/main/Game.gd scripts/dungeon/DungeonMap.gd
git commit -m "feat: zone-based map gen style + environmental hazard damage"
```

---

## Task 5: Status.gd — poison, neg 저항 원소 추가

**Files:**
- Modify: `scripts/systems/Status.gd`

- [ ] **Step 1: resist_scale이 poison, neg 원소를 처리하는지 확인**

`Status.resist_scale()`은 element 문자열을 받아 `resists` 배열에서 레벨을 찾는다.
`resist_level()`이 임의 문자열을 파싱하므로 추가 코드 불필요.

`EssenceSystem.gd`에서 `resist_fire`, `resist_cold` 에센스가 정의된 것처럼,
`resist_poison`, `resist_neg` 에센스 2개 추가:

```gdscript
# EssenceSystem.gd의 에센스 목록에 추가
{
	"id": "resist_poison",
	"name": "Venom Ward",
	"desc": "Grants poison resistance.",
	"icon": "...",  # 기존 poison 관련 아이콘 경로 사용
	"effect": "resist_poison",
	"duration": 30,
},
{
	"id": "resist_neg",
	"name": "Death Ward",
	"desc": "Grants negative energy resistance.",
	"icon": "...",
	"effect": "resist_neg",
	"duration": 30,
},
```

- [ ] **Step 2: EssenceSystem.gd의 apply_effect / remove_effect에 처리 추가**

```gdscript
# apply_effect() match 블록에 추가:
"resist_poison":
	if not player.resists.has("poison+"):
		player.resists.append("poison+")
"resist_neg":
	if not player.resists.has("neg+"):
		player.resists.append("neg+")

# remove_effect() match 블록에 추가:
"resist_poison":
	player.resists.erase("poison+")
"resist_neg":
	player.resists.erase("neg+")
```

- [ ] **Step 3: 테스트 — 독 늪 환경 피해 발생 → resist_poison 에센스 사용 → 피해 없어지는지 확인**

- [ ] **Step 4: 커밋**
```bash
git add scripts/systems/EssenceSystem.gd
git commit -m "feat: poison and neg resist essences (Venom Ward, Death Ward)"
```

---

## Task 6: 존별 몬스터 풀 — ZoneManager 기반 spawn

**Files:**
- Modify: `scripts/main/Game.gd`
- Modify: `scripts/systems/MonsterRegistry.gd`

- [ ] **Step 1: MonsterData.gd에 zone_mask 필드 추가 (선택적)**

현재 `min_depth`/`max_depth`로 존별 분배를 처리한다. Plan 2에서 depth를 재배치하므로 이 task는 Plan 2 완료 후 자동으로 동작. 별도 코드 변경 불필요.

- [ ] **Step 2: Boss 층(25)에서 golden_dragon + titan × 2 고정 스폰**

`_spawn_monsters_for_floor()`에 조건 추가:
```gdscript
func _spawn_monsters_for_floor(depth: int) -> void:
	if depth == 25:
		_spawn_boss_floor()
		return
	# 기존 로직...

func _spawn_boss_floor() -> void:
	var boss_data: MonsterData = MonsterRegistry.get_by_id("golden_dragon")
	var titan_data: MonsterData = MonsterRegistry.get_by_id("titan")
	if boss_data == null or titan_data == null:
		return
	# 방 중앙에 보스, 좌우에 titan
	var cx: int = DungeonMap.GRID_W / 2
	var cy: int = DungeonMap.GRID_H / 2
	_spawn_monster_at(boss_data, Vector2i(cx, cy))
	_spawn_monster_at(titan_data, Vector2i(cx - 3, cy))
	_spawn_monster_at(titan_data, Vector2i(cx + 3, cy))
```

`_spawn_monster_at(data, pos)` 헬퍼가 없으면 기존 `_spawn_monsters_for_floor`의 스폰 로직에서 추출.

- [ ] **Step 3: 에디터에서 depth=25로 이동, 보스 방 확인**

- [ ] **Step 4: 커밋**
```bash
git add scripts/main/Game.gd
git commit -m "feat: boss floor 25 — golden_dragon + titan x2 fixed spawn"
```

---

## 완료 기준

- [ ] 층 1-3: BSP 맵, brick 타일
- [ ] 층 4-6: CA 맵, lair 타일
- [ ] 층 7-9: BSP tight 맵, orc 타일
- [ ] 층 10-12: CA 맵, swamp 타일, WATER 산재, 독 환경 피해
- [ ] 층 13-15: BSP long 맵, crypt 타일, neg 환경 피해
- [ ] 층 16-18: CA open 맵, ice 타일, cold 환경 피해
- [ ] 층 19-21: BSP large 맵, elf-stone 타일
- [ ] 층 22-24: CA 맵, lava 타일, LAVA 산재, fire 환경 피해
- [ ] 층 25: 보스 방, golden_dragon + titan
- [ ] poison/neg 저항 에센스 존재
