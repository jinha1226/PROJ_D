# Race Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** RacePassiveSystem을 구현하고, 기존 6종족에 패시브를 적용하며, 신규 5종족(halfling, dwarf, tiefling, spriggan, vampire)을 추가한다.

**Architecture:** `RacePassiveSystem.gd` 싱글턴이 패시브 ID → 콜백 매핑을 관리. `RaceData`에 `passive_id` 필드 추가. Game.gd에서 종족 선택 시 패시브 등록, 관련 훅(공격, 피격, 턴, 이동)에서 패시브 발동 로직 호출.

**패시브 목록:**
| id | 종족 | 구현 난이도 |
|---|---|---|
| adaptable | Human | 쉬움 (에센스 배율) |
| keen_eyes | Elf | 쉬움 (시야+, sleep 면역) |
| bloodthirst | Orc | 쉬움 (HP 비율 체크) |
| regeneration | Troll | 쉬움 (턴 틱) |
| trapfinder | Kobold | 보통 (함정 사전 감지) |
| headbutt | Minotaur | 쉬움 (공격 플랫 보너스) |
| lucky | Halfling | 보통 (피격 후킹) |
| stone_sense | Dwarf | 보통 (보물방 자동 발견) |
| hellish_legacy | Tiefling | 보통 (MP 0 주문) |
| fleet | Spriggan | 보통 (속도 보정) |
| blood_drain | Vampire | 보통 (치명타 흡수) |

**Spec:** `docs/superpowers/specs/2026-04-23-zone-monster-expansion-design.md`

---

## 파일 구조

| 파일 | 변경 |
|---|---|
| `scripts/systems/RacePassiveSystem.gd` | **신규** — 패시브 등록/훅 처리 |
| `scripts/entities/RaceData.gd` | **수정** — passive_id 필드 추가 |
| `scripts/main/Game.gd` | **수정** — 패시브 등록, 훅 호출 |
| `scripts/systems/CombatSystem.gd` | **수정** — headbutt, blood_drain, bloodthirst 훅 |
| `scripts/systems/Status.gd` | **수정** — regeneration 틱, sleep 면역 |
| `resources/races/*.tres` (6개) | **수정** — passive_id 추가 |
| `resources/races/*.tres` (5개 신규) | **신규** — halfling, dwarf, tiefling, spriggan, vampire |
| `project.godot` | **수정** — RacePassiveSystem autoload 등록 |

---

## Task 1: RaceData에 passive_id 필드 추가

**Files:**
- Modify: `scripts/entities/RaceData.gd`

- [ ] **Step 1: passive_id 필드 추가**

`RaceData.gd`에서 `resist_mods` 선언 아래에 추가:
```gdscript
## Passive ability id. Empty string = no passive.
@export var passive_id: String = ""
```

- [ ] **Step 2: 커밋**
```bash
git add scripts/entities/RaceData.gd
git commit -m "feat: RaceData — add passive_id field"
```

---

## Task 2: RacePassiveSystem 구현

**Files:**
- Create: `scripts/systems/RacePassiveSystem.gd`
- Modify: `project.godot`

- [ ] **Step 1: RacePassiveSystem.gd 생성**

```gdscript
# scripts/systems/RacePassiveSystem.gd
extends Node

var _active_passive: String = ""
var _player: Node = null  # Player 레퍼런스 (Game.gd에서 주입)

func register(passive_id: String, player: Node) -> void:
	_active_passive = passive_id
	_player = player
	_on_passive_registered(passive_id, player)

func clear() -> void:
	_active_passive = ""
	_player = null

func has(passive_id: String) -> bool:
	return _active_passive == passive_id

# ── 등록 시 즉시 적용되는 패시브 ───────────────────────────────────────────
func _on_passive_registered(id: String, player: Node) -> void:
	match id:
		"keen_eyes":
			player.sight_range = player.sight_range + 1
		"fleet":
			player.speed = player.speed + 3

# ── 턴 종료 훅 ──────────────────────────────────────────────────────────────
## 매 플레이어 턴 종료 시 Game.gd에서 호출
func on_player_turn_end(turn: int) -> void:
	if _player == null:
		return
	match _active_passive:
		"regeneration":
			if turn % 3 == 0:
				_player.hp = min(_player.hp + 1, _player.max_hp)

# ── 공격 후킹 ───────────────────────────────────────────────────────────────
## CombatSystem에서 플레이어 근접 공격 결과 확정 후 호출
## 반환값: 추가 대미지 (기본 0)
func on_player_melee_hit(target: Node, is_crit: bool, base_dmg: int) -> int:
	if _player == null:
		return 0
	match _active_passive:
		"headbutt":
			return 3
		"bloodthirst":
			if _player.hp < int(_player.max_hp * 0.5):
				return 4
		"blood_drain":
			if is_crit:
				_player.hp = min(_player.hp + 3, _player.max_hp)
	return 0

# ── 피격 후킹 ───────────────────────────────────────────────────────────────
## CombatSystem에서 플레이어가 피해를 받기 직전 호출
## is_crit: 치명타 여부. 반환 true = 치명타를 일반 피격으로 전환
func on_player_hit(is_crit: bool) -> bool:
	if _player == null or _active_passive != "lucky":
		return false
	if is_crit and not _lucky_used_this_floor:
		_lucky_used_this_floor = true
		return true  # 치명타 취소
	return false

var _lucky_used_this_floor: bool = false

func on_floor_changed() -> void:
	_lucky_used_this_floor = false

# ── 주문 시전 후킹 ──────────────────────────────────────────────────────────
## MagicSystem에서 MP 체크 전 호출. 반환 true = MP 없어도 시전 허용
func on_spell_cast_mp_check() -> bool:
	if _active_passive != "hellish_legacy":
		return false
	if _player == null or _player.mp > 0:
		return false
	if _hellish_used_this_floor:
		return false
	_hellish_used_this_floor = true
	return true

var _hellish_used_this_floor: bool = false
# on_floor_changed()에서 _hellish_used_this_floor도 초기화

# ── 함정 감지 후킹 ──────────────────────────────────────────────────────────
## Game.gd에서 플레이어 이동 후 인접 타일 검사 시 호출
## 반환 true = 해당 위치의 함정을 미리 감지
func on_check_trap_reveal(player_pos: Vector2i, trap_pos: Vector2i) -> bool:
	if _active_passive != "trapfinder":
		return false
	return player_pos.distance_to(trap_pos) <= 1.5

# ── 보물방 감지 후킹 ────────────────────────────────────────────────────────
## Game.gd에서 플레이어 이동 후 인접 비밀방 검사 시 호출
## 반환 true = 해당 방을 자동 발견
func on_check_room_reveal(player_pos: Vector2i, room: Rect2i) -> bool:
	if _active_passive != "stone_sense":
		return false
	# 방 외곽 1칸 이내
	var expanded: Rect2i = room.grow(1)
	return expanded.has_point(player_pos)

# ── Sleep 면역 ──────────────────────────────────────────────────────────────
func is_sleep_immune() -> bool:
	return _active_passive == "keen_eyes"

# ── 에센스 지속 배율 ────────────────────────────────────────────────────────
## EssenceSystem에서 지속시간 계산 시 호출
func essence_duration_mult() -> float:
	return 1.5 if _active_passive == "adaptable" else 1.0
```

- [ ] **Step 2: on_floor_changed에서 _hellish_used_this_floor도 초기화**

`on_floor_changed()` 함수를:
```gdscript
func on_floor_changed() -> void:
	_lucky_used_this_floor = false
	_hellish_used_this_floor = false
```
로 교체.

- [ ] **Step 3: project.godot autoload 등록**

```
RacePassiveSystem="*res://scripts/systems/RacePassiveSystem.gd"
```

- [ ] **Step 4: 커밋**
```bash
git add scripts/systems/RacePassiveSystem.gd project.godot
git commit -m "feat: RacePassiveSystem — passive registry and hook handlers"
```

---

## Task 3: Game.gd — 패시브 등록 + 훅 연결

**Files:**
- Modify: `scripts/main/Game.gd`

- [ ] **Step 1: 종족 선택 시 패시브 등록**

`Game.gd`에서 종족이 적용되는 위치 (보통 `player.resists = race.resist_mods.duplicate()` 근처):
```gdscript
RacePassiveSystem.register(race.passive_id, player)
```

- [ ] **Step 2: 턴 종료 시 on_player_turn_end 호출**

플레이어 턴이 끝나는 지점에 추가 (턴 카운터 `_turn` 또는 `GameManager.turn` 활용):
```gdscript
RacePassiveSystem.on_player_turn_end(GameManager.turn)
```

- [ ] **Step 3: 층 이동 시 on_floor_changed 호출**

`_generate_floor()` 또는 층 이동 처리 시작 부분에:
```gdscript
RacePassiveSystem.on_floor_changed()
```

- [ ] **Step 4: 커밋**
```bash
git add scripts/main/Game.gd
git commit -m "feat: Game — register race passive on start, wire turn/floor hooks"
```

---

## Task 4: CombatSystem + Status — 전투 훅 연결

**Files:**
- Modify: `scripts/systems/CombatSystem.gd`
- Modify: `scripts/systems/Status.gd`
- Modify: `scripts/systems/MagicSystem.gd`
- Modify: `scripts/systems/EssenceSystem.gd`

- [ ] **Step 1: CombatSystem — 플레이어 근접 공격에 headbutt/bloodthirst/blood_drain 훅**

`CombatSystem.gd`에서 플레이어가 몬스터를 공격하는 로직을 찾아 `dmg` 계산 직후에:
```gdscript
# 패시브 추가 대미지
var passive_bonus: int = RacePassiveSystem.on_player_melee_hit(target, is_crit, dmg)
dmg += passive_bonus
```

치명타 판정 이전에 `is_crit` 변수가 있어야 함. 없다면 공격 로직에서 추출.

- [ ] **Step 2: CombatSystem — 플레이어 피격에 lucky 훅**

플레이어가 피격 당할 때 치명타 여부 판정 직후:
```gdscript
if is_crit:
	if RacePassiveSystem.on_player_hit(true):
		is_crit = false  # lucky 발동으로 치명타 취소
```

- [ ] **Step 3: Status.gd — sleep 면역 체크**

`Status.apply(actor, "sleep", turns)` 에서 플레이어에게 sleep 적용 전:
```gdscript
if actor == player and RacePassiveSystem.is_sleep_immune():
	CombatLog.post("You are immune to sleep!", Color(0.8, 0.9, 1.0))
	return
```

(player 레퍼런스가 Status.gd에 없으면 `actor.has_method("get_race")` 또는 autoload 통해 체크)

- [ ] **Step 4: MagicSystem.gd — hellish_legacy MP 체크**

MP 부족으로 주문 취소하는 위치에:
```gdscript
if player.mp <= 0:
	if not RacePassiveSystem.on_spell_cast_mp_check():
		CombatLog.post("Not enough MP!", Color(0.8, 0.4, 0.4))
		return
	# hellish_legacy 발동 — MP 없이 시전
```

- [ ] **Step 5: EssenceSystem.gd — adaptable 배율 적용**

에센스 `duration` 계산 위치에:
```gdscript
var duration: int = int(round(base_duration * RacePassiveSystem.essence_duration_mult()))
```

- [ ] **Step 6: 커밋**
```bash
git add scripts/systems/CombatSystem.gd scripts/systems/Status.gd scripts/systems/MagicSystem.gd scripts/systems/EssenceSystem.gd
git commit -m "feat: wire race passive hooks in combat, status, magic, essence systems"
```

---

## Task 5: 기존 6종족 .tres에 passive_id 추가

**Files:**
- Modify: `resources/races/human.tres`
- Modify: `resources/races/elf.tres`
- Modify: `resources/races/orc.tres`
- Modify: `resources/races/troll.tres`
- Modify: `resources/races/kobold.tres`
- Modify: `resources/races/minotaur.tres`

- [ ] **Step 1: 각 파일에 passive_id 추가**

각 파일에 다음 한 줄 추가 (기존 필드 다음):

```
human.tres   → passive_id = "adaptable"
elf.tres     → passive_id = "keen_eyes"
orc.tres     → passive_id = "bloodthirst"
troll.tres   → passive_id = "regeneration"
kobold.tres  → passive_id = "trapfinder"
minotaur.tres → passive_id = "headbutt"
```

- [ ] **Step 2: 에디터 실행 — Troll 선택 후 3턴마다 HP +1 회복 확인, Elf 선택 후 시야 범위 +1 확인**

- [ ] **Step 3: 커밋**
```bash
git add resources/races/
git commit -m "feat: assign passives to existing 6 races"
```

---

## Task 6: 신규 5종족 .tres 생성

**Files:**
- Create: `resources/races/halfling.tres`
- Create: `resources/races/dwarf.tres`
- Create: `resources/races/tiefling.tres`
- Create: `resources/races/spriggan.tres`
- Create: `resources/races/vampire.tres`

`.tres` 포맷 참조 (기존 orc.tres 구조 동일):
```
[gd_resource type="Resource" script_class="RaceData" format=3 uid="uid://[고유ID]"]
[ext_resource type="Script" path="res://scripts/entities/RaceData.gd" id="1_rdata"]
[resource]
script = ExtResource("1_rdata")
id = "[id]"
display_name = "[표시명]"
description = "[설명]"
base_sprite_path = "res://assets/tiles/individual/player/base/[스프라이트].png"
unlocked = false
unlock_kind = "kill"
unlock_trigger_id = "[언락 몬스터 id]"
str_mod = N  dex_mod = N  int_mod = N  hp_mod = N  mp_mod = N
resist_mods = [...]
passive_id = "[passive_id]"
```

- [ ] **Step 1: halfling.tres**
```
uid="uid://bhalfling1"
id = "halfling"  display_name = "Halfling"
description = "Small and nimble. +2 DEX, -1 STR, -1 HP. Lucky: once per floor, a critical hit against you becomes a normal hit."
base_sprite_path = "res://assets/tiles/individual/player/base/human.png"
unlock_trigger_id = "goblin"
str_mod = -1  dex_mod = 2  int_mod = 0  hp_mod = -1  mp_mod = 0
resist_mods = []
passive_id = "lucky"
```
(플레이어 halfling 스프라이트가 없으면 human.png 임시 사용)

- [ ] **Step 2: dwarf.tres**
```
uid="uid://bdwarf0001"
id = "dwarf"  display_name = "Dwarf"
description = "Sturdy and perceptive. +1 STR, -1 DEX, +4 HP. Poison resistance. Stone Sense: automatically reveal secret rooms when adjacent."
base_sprite_path = "res://assets/tiles/individual/player/base/human.png"
unlock_trigger_id = "deep_dwarf"
str_mod = 1  dex_mod = -1  int_mod = 0  hp_mod = 4  mp_mod = 0
resist_mods = ["poison+"]
passive_id = "stone_sense"
```

- [ ] **Step 3: tiefling.tres**
```
uid="uid://btieflin1"
id = "tiefling"  display_name = "Tiefling"
description = "Infernal heritage. +1 INT, -1 HP, +2 MP. Fire resistance. Hellish Legacy: cast one spell per floor even at 0 MP."
base_sprite_path = "res://assets/tiles/individual/player/base/human.png"
unlock_trigger_id = "balrug"
str_mod = 0  dex_mod = 0  int_mod = 1  hp_mod = -1  mp_mod = 2
resist_mods = ["fire+"]
passive_id = "hellish_legacy"
```

- [ ] **Step 4: spriggan.tres**
```
uid="uid://bspriggan1"
id = "spriggan"  display_name = "Spriggan"
description = "Blazing fast, paper thin. +3 DEX, +1 INT, -2 STR, -5 HP, +1 MP. Fleet: +3 speed, always acts before monsters of equal speed."
base_sprite_path = "res://assets/tiles/individual/player/base/human.png"
unlock_trigger_id = "deep_troll"
str_mod = -2  dex_mod = 3  int_mod = 1  hp_mod = -5  mp_mod = 1
resist_mods = []
passive_id = "fleet"
```

- [ ] **Step 5: vampire.tres**
```
uid="uid://bvampire01"
id = "vampire"  display_name = "Vampire"
description = "Undying predator. +1 STR, +1 DEX, -2 HP. Neg resistance. Blood Drain: critical hits restore 3 HP."
base_sprite_path = "res://assets/tiles/individual/player/base/human.png"
unlock_trigger_id = "vampire"
str_mod = 1  dex_mod = 1  int_mod = 0  hp_mod = -2  mp_mod = 0
resist_mods = ["neg+"]
passive_id = "blood_drain"
```

- [ ] **Step 6: 종족 선택 UI에서 신규 5종족 노출 확인 (unlock 조건 충족 후)**

- [ ] **Step 7: 커밋**
```bash
git add resources/races/halfling.tres resources/races/dwarf.tres resources/races/tiefling.tres resources/races/spriggan.tres resources/races/vampire.tres
git commit -m "feat: 5 new races — halfling, dwarf, tiefling, spriggan, vampire with passives"
```

---

## 완료 기준

- [ ] 11개 종족이 선택 화면에 표시 (unlock 조건 충족 시)
- [ ] Troll: 3턴마다 HP +1 회복
- [ ] Orc: HP < 50% 시 공격력 +4 표기/적용
- [ ] Elf: 시야 +1, sleep 면역
- [ ] Minotaur: 근접 공격마다 +3 대미지
- [ ] Halfling: 치명타 피격 1회/층 일반 피격 전환
- [ ] Troll/Spriggan 속도 차이 체감
- [ ] Tiefling: MP 0에서 주문 1회 추가 시전
- [ ] Vampire: 치명타 공격 시 HP +3 회복
