---
name: sprite-system-ulpc
description: "ULPC 4-dir 스프라이트 시스템 아키텍처 — human_lpc 폴더 구조, walk 애니메이션, 장비 오버레이 매핑. 2026-05-22 세션에서 human_8dir 대체."
metadata: 
  node_type: memory
  type: project
  originSessionId: c397ad05-cddb-4275-bf92-7e35406cbee5
---

## 배경

human_8dir(AI 생성 8방향 가로 스프라이트)를 Universal LPC Spritesheet(ULPC) 4방향 세로 시트로 교체. 최신 커밋: `e209b61f` (2026-05-22, main 브랜치).

**Why:** ULPC는 CC-BY-SA 3.0 라이선스, 상업 출시 시 크레딧 필수. `CREDITS.md`에 추가 예정.
크레딧 문구: "Character sprites from Universal LPC Spritesheet (https://github.com/sanderfrenken/Universal-LPC-Spritesheet-Character-Generator), CC-BY-SA 3.0"

## ULPC 시트 포맷

- 크기: 576×256px
- 레이아웃: 9열(walk 프레임) × 4행(방향)
- 행 순서: **N(0) / W(1) / S(2) / E(3)**
- 프레임 크기: 64×64px
- 감지 조건: `tw * 4 == th * 9 and th % 4 == 0` (e.g. 576×256 → 2304==2304 ✓)
- 전체 ULPC 시트(832×1344 등)에서 walk 구간 추출: `img.crop((0, 512, 576, 768))`

## human_lpc/ 폴더 구조

```
assets/tiles/individual/player/human_lpc/
  base.png          # 몸통 (머리 없음)
  head.png          # 머리 (항상 표시)
  hair.png          # 머리카락 (항상 표시)
  armor.png         # 갑옷 기본 오버레이 (fallback)
  helmet.png        # 투구 기본 오버레이
  boots.png         # 부츠 기본 오버레이
  gloves.png        # 장갑 기본 오버레이
  sword.png         # 무기 기본 오버레이 (fallback)
  shield.png        # 방패 기본 오버레이

  weapons/
    dagger.png      # 단검류 (dagger/dirk/stiletto/venom_dagger/frost_dagger/assassin_blade/throwing_knife)
    longsword.png   # 한손검 (arming_sword/long_sword/flaming_sword/mace)
    greatsword.png  # 양손검 (bastard_sword/great_blade) — 현재 longsword 복사본
    axe.png         # 도끼 (battle_axe)
    staff.png       # 스태프/활/창 (staff/javelin/longbow/crossbow)

  armor/
    robe.png        # 로브
    leather.png     # 가죽갑옷 (leather_armor/troll_leather)
    chainmail.png   # 경갑옷 (chain_mail)
    plate.png       # 플레이트 (plate_mail)
```

## Player.gd 핵심 변수/상수

```gdscript
# 항상 표시되는 레이어 (머리, 머리카락)
const _BASE_OVERLAY_FILES: Array[String] = ["head", "hair"]
var _base_sheets: Array[Texture2D] = []

# 장비 조건부 레이어
var _equip_sheets: Array[Texture2D] = []
const _EQUIP_SHEET_SLOTS: Array[Array] = [
    ["equipped_armor_id",  "armor"],
    ["equipped_helmet_id", "helmet"],
    ["equipped_gloves_id", "gloves"],
    ["equipped_boots_id",  "boots"],
    ["equipped_weapon_id", "sword"],
    ["equipped_shield_id", "shield"],
]

# 무기/갑옷 타입별 오버레이 매핑 (base_id → 상대 경로, .png 제외)
const _WEAPON_OVERLAY_MAP: Dictionary = { "dagger": "weapons/dagger", ... }
const _ARMOR_OVERLAY_MAP: Dictionary = { "leather_armor": "armor/leather", ... }

# ULPC 프레임 내 캐릭터 실제 범위
const _ULPC_CHAR_TOP: float = 14.0   # head top (y in 64px frame)
const _ULPC_CHAR_H: float = 48.0     # head(y=14)~feet(y=61) = 48px
```

## Walk 애니메이션

```gdscript
var _walk_frame: int = 0       # 0~8 현재 열 인덱스
var _walk_anim_t: float = 0.0
var _walk_anim_active: bool = false
const _WALK_FPS: float = 18.0  # 9프레임 / 18fps ≈ 0.5s per step
```

- **이동 시**: `_walk_anim_active = true` (이미 활성 중이면 `_walk_anim_t` 리셋 안 함 → 연속 이동 시 첫 프레임 튀기 방지)
- **`_process(delta)`**: 프레임 0→8 순환, 완료 시 `_walk_frame = 0`으로 복귀
- **방향 감지**: `_facing_to_row()` (NW/SW → W, NE/SE → E/S 근사)

## 셀 크기 맞춤 draw rect

```gdscript
func _ulpc_draw_rect() -> Rect2:
    var cs := float(DungeonMap.CELL_SIZE)
    var scale := cs / _ULPC_CHAR_H       # 32/48 ≈ 0.667
    var draw_sz := 64.0 * scale           # ~42.7px (셀보다 약간 큼)
    var x_off := (cs - draw_sz) * 0.5    # 수평 중앙 정렬
    var y_off := -_ULPC_CHAR_TOP * scale  # 머리를 y=0에 맞춤
    return Rect2(x_off, y_off, draw_sz, draw_sz)
```

## 렌더 순서 (Player._draw)

1. `_base_tex` (base.png — 몸통)
2. `_base_sheets` (head.png → hair.png — 항상 표시)
3. `_equip_sheets` (갑옷 → 투구 → 장갑 → 부츠 → 무기 → 방패)
4. Legacy fallback (_body_doll_tex 등 — _equip_sheets 비어 있을 때만)

## StatusDialog / RaceSelect 연동

- `StatusDialog._south_atlas()`: ULPC 시트에서 S방향(row 2, frame 0) 추출 → `Rect2(0, 128, 64, 64)`
- `StatusDialog._portrait_stack()`: `Player._BASE_OVERLAY_FILES` 참조해 head/hair 레이어 추가
- `RaceSelect._add_layer()`: 동일 S방향 AtlasTexture 크롭

## 8-dir 레거시 호환

`tw >= th * 4` 조건이면 8방향 가로 시트로 처리 (다른 종족에서 사용 가능).

## 이번 세션 버그픽스 (같이 처리됨)

- `BodyPartSystem.gd:68`: Monster에 `hp_max` 없음 → `defender.data.hp` fallback 추가
- `SkillsDialog.gd`: `weapon_mastery` hidden 목록에서 `"fighting"` 제거 (tactics로 이동됨)

## 다음 개선 필요 항목

- greatsword.png = longsword 복사본 → 실제 양손검 ULPC 스프라이트 찾기
- 속옷/맨몸 상태 = base+head+hair만 표시 (별도 오버레이 없음, 의도적)
- 다른 종족(elf, orc 등) ULPC 스프라이트 추가 시 동일 폴더 구조 복사하면 자동 적용
- ItemData.equip_overlay_path로 아이템별 커스텀 오버레이 지정 가능 (최우선 적용)
