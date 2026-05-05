# PocketCrawl Codebase Audit — 2026-05-05

## 스코프
`scripts/main/Game.gd` (3112 줄), `scripts/systems/`, `scripts/dungeon/DungeonMap.gd`, 인벤토리 일체, `scripts/ui/`, save/load, 일부 `.tres`. 시체 시스템(별도 진단 완료, Phase 0)은 제외.

발견: **Critical 4 / High 9 / Medium 11 / Low 5**.

> 현 상태로 출시 시 플레이어 진행할수록 캐릭터 상태가 망가지는 것이 거의 확정. Phase 0 → Phase 1을 다른 작업보다 우선.

---

## Critical (출시 차단)

### C1. 저장 시 진행 상태 대량 누락 (데이터 손실)
- **위치**: `scripts/core/SaveManager.gd:34-80` (`save_run`)
- **누락 필드**:
  - `GameManager.branch_zone`, `branch_floor`, `branch_entry_depth`, `branch_floor_cache`, `branches_cleared`
  - `GameManager.floor_cache` (모든 이전 층 상태)
  - 현재 층의 `altar_active`, `altar_map`, `corpses`, `cloud_tiles`, `hazard_tiles`, `fog_tiles`, `explored`, `visible_tiles`, 살아있는 몬스터, 바닥 아이템
  - `GameManager.titles`
- **결과**: 가지 안에서 저장→메뉴→복귀 시 메인 던전 어딘가로 강제 복귀, 같은 층 재방문 시 빈 맵 재생성, 신단 활성화 풀림. **모바일 백그라운드→복귀 시나리오 직격.**
- **권장 수정**: `save_run`을 `Game._cache_current_floor()` dict와 동일 스키마로 직렬화. 로드 시 `_restore_floor_from_cache` 경로 재사용. `save_version` 키 추가.

### C2. 장착 방어구 버리기 시 어픽스 보너스 영구 잔존
- **위치**: `scripts/entities/Player.gd:547-565` (`drop_item`), `1132-1135` (`set_equipped_armor`)
- **증상**: armor 분기가 `set_equipped_armor("")` 미호출, `equipped_armor_id = ""`로 직접 대입 → randart 어픽스(+HP, +slay 등) 영구 적용. weapon/ring/amulet은 정상.
- **재현**: +10 HP, +2 slay mod의 randart armor 장착 → 버리기 → HP_max +10, slay_bonus +2 영구 누적.
- **권장 수정**: `set_equipped_armor`에 affix 제거 호출 추가, `drop_item` armor 분기를 다른 슬롯과 동일하게 통일. shield도 동일 검증.

### C3. 저항 mod 적용/해제 누적 손상
- **위치**: `scripts/entities/Player.gd:1274-1281` (`_apply_resist_mod`)
- **증상**:
  - +/- 분기 둘 다 동일 동작 (`resists.append(tag)`)
  - magnitude 무시 → rFire+++ randart도 +1만 작동
  - 해제 시 반대 부호 토큰 추가 → 반복 시 마이너스 저항 누적
- **권장 수정**: `resists`를 `{element: int}`로 바꾸거나, `for _ in abs(value): resists.append(tag)` + remove는 `erase` 정확히 횟수만큼.

### C4. 가지 1층에서 위로 이탈 시 몬스터 누수
- **위치**: `scripts/main/Game.gd:1741-1761` (`_on_branch_stairs_up`)
- **증상**: `branch_floor == 1`에서 위로 가는 분기가 `_clear_monsters()` / `_clear_floor_items()` 호출 안 함. 가지 몬스터들이 메인 던전 layer에 그대로 남음.
- **권장 수정**: `_restore_floor_from_cache` 진입부에 clear 추가 (중복 호출 안전), 또는 가지 종료 경로에 명시 호출.

---

## High (기능 오작동)

### H1. 다수 스크롤/완드 효과 없음
- **위치**: `scripts/entities/Player.gd:386-440, 458-466`
- **미구현 호출**: `apply_fear_aoe`, `apply_fog_aoe`, `apply_silence_aoe`, `alert_all_monsters`, `dig_toward`. Game.gd엔 `apply_immolation_aoe`만 존재. 폴백 코드(line 421-427, 434-439)가 참조하는 `_map.entities`도 DungeonMap에 없음.
- **결과**: scroll_fear/fog/silence/noise/immolation(폴백), wand_fear/digging — 메시지만 출력 + 자동 식별 + 효과 0.
- **권장 수정**: `scripts/systems/AoeEffects.gd` static helper에 모아 Player.gd에서 호출. Game.gd 의존 제거.

### H2. Faith 데이터 절반이 dead
- **위치**: `scripts/systems/FaithSystem.gd:5-67`
- **미참조 키**:
  - `defense_effectiveness_mult` (war)
  - `shield_block_bonus` (war/trickery — getter 있으나 `CombatSystem._try_player_shield_block` 호출 안 함)
  - `magic_xp_mult`, `defense_xp_mult` (war/arcana)
  - `agility_effectiveness_mult`, `tool_effectiveness_mult`, `detect_range_mod` (trickery)
  - `undead_damage_mult` (death)
  - `essence_penalty_reduction` (essence)
- **결과**: 광고와 실제 불일치 — war 신앙의 +20% 방어 / +8% 차단 등 작동 안 함.
- **권장 수정**: 사용 site에 wire-up 또는 데이터에서 제거 + 문서 정렬.

### H3. 인벤토리 탭 필터 누락
- **위치**: `scripts/ui/BagDialog.gd:69-71`
- **증상**: `tab_filters = [[], ["weapon"], ["armor"], ["ring", "amulet"], ["potion", "scroll", "book"]]`. **`shield`, `wand`, throwing, `essence`, `rune`** kind는 specific 탭 어디에도 안 잡힘. "방어구" 탭 누르면 방패 사라짐 → 사용자가 잃어버린 줄 인식.
- **권장 수정**: `tab_filters`를 데이터로 외화, kind 화이트리스트 단일 소스. `["armor", "shield"]`, "기타" 탭 추가.

### H4. ItemDetailDialog item_index stale
- **위치**: `scripts/ui/ItemDetailDialog.gd:291-407`
- **증상**: 모든 액션 콜백이 `item_index`를 closure로 캡처. 다이얼로그 열려있는 동안 `player.items` 인덱스 변동 가능 (auto-use, identify, drop). wand 사용 시 `_use_targeting_wand` ↔ `use_quickslot` ↔ `use_item` 경로 충돌.
- **위험**: 잘못된 아이템 사용 또는 크래시.
- **권장 수정**: `Player.use_item_by_entry(entry)` entry-기반 API. UI는 entry 캡처. 또는 액션 직전 `items.find()` 재탐색.

### H5. 데미지 로그 raw vs 적용 scaled 불일치
- **위치**: `scripts/systems/MagicSystem.gd:368-388` (`_damage_auto_target`)
- **증상**: line 376 `CombatLog.hit("You hit ... for %d." % dmg)` — `dmg`는 raw, 저항 스케일은 line 381에서 `scaled` 별도. "12 데미지!" 떠도 HP 6만 깎임.
- **권장 수정**: scaled 계산을 로그 전으로 이동, immune 분기 정리. CombatSystem brand 로그도 유사 검증.

### H6. `static var X = get_node_or_null(/root/X)` 패턴 19파일
- **대표**: `scripts/tools/SimulationBot.gd:5` `static var MagicSystem = ...get_node_or_null("/root/MagicSystem")` — `MagicSystem`은 autoload 아닌 `class_name` RefCounted → 항상 null → 글로벌 클래스 식별자 섀도잉 → `MagicSystem.cast(...)` null deref. SimulationBot 동작 불가.
- **다른 18파일**: autoload 이름과 일치하므로 우연히 작동, 그러나 redundant + lazy 평가 race 위험.
- **권장 수정**: 해당 라인 전부 삭제. autoload는 GDScript 4에서 자동 글로벌.

### H7. 데미지 파이프라인 곱셈/덧셈 혼재
- **위치**: `scripts/systems/CombatSystem.gd:111-123`
- **증상**: `final` 계산 순서 (1) 스킬 mult → (2) faith melee mult → (3) `+ skill_level/2 + randi(0..skill/3)` → (4) backstab. backstab `_backstab_bonus`가 base × 0.5~1.0을 return → final에 add → 사실상 평타에 base의 50~100% 가산. 곱셈 의도였는지 덧셈 의도였는지 불명.
- **권장 수정**: `compute_damage_pipeline`을 (1) base, (2) flat additions, (3) multiplicative chain, (4) brand extra의 명시 단계로 분리. `_player_attack_profile`의 죽은 가드 `skill_id == ""` 제거.

### H8. 플레이어 사망 후 actor 루프 계속
- **위치**: `scripts/core/TurnManager.gd:22-44` (`end_player_turn`)
- **증상**: `actors.duplicate()` 루프가 player 사망을 보지 않음. `Monster.take_turn()` 내부도 hp/data/_map만 체크. 결과 화면 직전까지 추가 행동 → "죽은 뒤 데미지 로그" 신고.
- **권장 수정**: `Game._on_player_died`에서 TurnManager에 abort flag 세팅, 루프에서 체크.

### H9. monster awareness state 휘발
- **위치**: `scripts/main/Game.gd:1078-1089, 1799-1820` (`_restore_floor_from_cache`)
- **증상**: cache에 `is_aware`, `is_alerted`, `last_known_player_pos`, `pending_energy`, `_ability_charge` 저장 안 됨. 복원 시 모두 기본값 → 도망쳤다 돌아오면 "?" 재표시 + backstab 가능.
- **권장 수정**: 위 필드들을 cache state에 직렬화 추가.

---

## Medium (잠재적 버그·결합도)

### M1. Game.gd 3112줄 god-object
- 책임 영역 — 입력(132-281), 자동이동(283-468), 클래스/종족 적용(403-468 — Player 책임이어야), 세이브 마이그레이션(522-661 — 별도 모듈), 맵 생성/캐시(663-1090, 1780-1856, 1887-2000), 몬스터/아이템 스폰(1091-1334, 2046-2096), 시체 매핑(1332-1370 — MonsterData 책임), 가지 생명주기(1701-2123), HUD 호출(1502-1525, 2228-2587), 시각효과(2840-2986), Archmage debug(2988-3112).
- **분해 타겟**: `FloorLifecycle`, `BranchManager`, `SaveMigration`, `EffectsLayer`, `MonsterFactory`, `CorpseService`.

### M2. Save 마이그레이션 인-라인 if-사슬
- `scripts/main/Game.gd:571-630` (`_apply_loaded_player_state`)
- 6개 스킬 마이그레이션이 하드코딩 (`dodge → agility`, `melee → unarmed/blade/hafted/polearm`, `stealth → agility`, `magic → spellcasting+5`, `defense → armor/shield`).
- **권장**: `SaveMigration._migrate_skills_v1_to_v2(player)` + `save_version` 키.

### M3. 클래스 스타터/디폴트 액티브 스킬 거대 match 두 개로 중복
- `Game.gd:484-520` (`_class_starter_items`, `_class_default_active_skills`)
- 클래스 추가 시 2개 함수 + ClassData 동시 수정.
- **권장**: `ClassData`에 `default_active_skills`, `starter_items` 필드 → 데이터 우선, 미정의 시 fallback.

### M4. 첫 신단 보스 검출이 `is_unique`만 확인
- `Game.gd:2774-2780` (`_handle_first_shrine_boss_clear`)
- B3 신전에서 어떤 unique든 죽으면 신단 활성화. 컨텐츠 추가 시 의도 외 트리거 위험.
- **권장**: `MonsterData.is_first_shrine_boss: bool` 또는 ZoneManager 매핑.

### M5. armor brand 검출 비대칭
- `scripts/systems/CombatSystem.gd:228-259`
- weapon brand는 `entry.brand` 우선 + base brand fallback. armor brand는 `entry.brand`만. brand-stamped 아닌 base armor의 retaliation 미발동.
- **권장**: `_armor_brand` 두 단계 fallback 통일.

### M6. branch brand 코인플립
- `scripts/entities/Player.gd:617-642` (`_apply_branch_brand`)
- `target = "weapon" if randf() < 0.5 else "armor"`. 사용자 선택 무시. 첫 슬롯 비면 다른 슬롯 fallback.
- **권장**: 슬롯 선택 다이얼로그 (IdentifyPicker 패턴 재사용).

### M7. DungeonMap `_draw()` 매 프레임 광역
- 32×36 = 1152 셀 × 7 광역 + 시체 N개 × `load(ctile)`. boss floor에서 GC 압박.
- **권장**: 시체 Texture2D를 dict에 저장, `_draw`에서 path load 제거. TileMap/MultiMeshInstance2D 마이그레이션 검토.

### M8. BagDialog 매 호출 전체 재구축
- `scripts/ui/BagDialog.gd:14-89` (`_populate`)
- 50+ Control queue_free + 재생성, `_make_thumbnail`이 매번 `load(base_path)`.
- **권장**: `_thumb_cache: Dictionary[String, Texture2D]`, 변경된 entry만 갱신.

### M9. 인벤토리 stack key는 `id|plus`
- `BagDialog.gd:108`. randart는 `id` 자체가 unique → 의도된 분리. plus 다른 동일 base 무기도 분리.
- **권장**: 의도라면 그대로, 가독성 위해 plus 통합 표시 옵션.

### M10. delete_save가 user data 검증 안 함
- `scripts/core/SaveManager.gd:30-32`
- `DirAccess.remove_absolute(globalize_path("user://save.json"))`. Android 권한 이슈 가능. 죽음 시 자동 호출 → "튕김 = 죽음" 사용자 분노.
- **권장**: `FileAccess` 통일, 죽음 시 백업 옵션.

### M11. UI가 시스템 상태 직접 변형
- `scripts/ui/ItemDetailDialog.gd:306, 314, ...` 모든 액션 콜백이 `player.set_equipped_*` + `TurnManager.end_player_turn()` 직접.
- `Player.use_item` 안에서 `IdentifyPicker.open` 인스턴스화 — UI 의존성 역방향.
- **권장**: `Player.equip(slot, item_id)`가 turn 비용 책임. `IdentifyPicker`는 시그널 패턴 (`identify_requested`).

---

## Low (가독성/사소)

### L1. `_corpse_shape_for_monster` 거대 match
- `Game.gd:1332-1362`. MonsterData에 `corpse_shape` 필드 한 줄로 충분.

### L2. autoload redundant 캡처
- `Game.gd:111-112` 등 12줄. autoload 이름은 글로벌이라 `@onready var GameManager = get_node("/root/GameManager")` 불필요.

### L3. `FaithSystem.normalize_player_state` 의미 검증
- 동작 자체는 일관. line 158 `_clear_equipped_essences`가 normalized != ESSENCE_FAITH_ID 일 때 분기 — 신앙 미선택+first_shrine_choice_done false 신규 캐릭터에서도 호출되지만 영향 작음.

### L4. archmage 디버그 클래스
- `Game.gd:516-517`. 모든 스킬 활성. 출시 빌드에서 unlock 게이팅 또는 제거 권장.

### L5. wand quickslot 바인딩 경로 부재
- `QuickslotPicker._populate`은 potion/scroll만 노출. Game.gd에 wand_fire/frost/lightning 처리 코드 있으나(`_WAND_ELEMENTS`) 슬롯 진입 경로 없음. **dead code 또는 미완성**.

---

## 꼬임의 패턴 7가지

### P1. Game.gd가 시스템 상태 직접 변형 (8곳+)
시체 매핑, 클래스/종족 적용(Player private state), 스킬 마이그레이션, 가지 brand 보상이 ItemRegistry → 직접 player.items append. **시스템 모듈이 단일 권위가 아님**.

### P2. Slot equip/unequip 비대칭 (5 슬롯 중 2개 이상)
- weapon ✓ — affix 정상
- armor ✗ — 해제 시 affix 안 빠짐 (C2)
- ring ✓
- amulet ✓
- shield ✗ — affix 코드 없음 (현재 데이터에 affix 없어 잠복)
**원인**: 5개 `set_equipped_*` 복붙, armor/shield 마무리 누락. → 통합 `_equip_slot(slot_kind, id)` helper.

### P3. 데이터 정의 ↔ 미참조 키
Faith 8개, MonsterData ai_flags 일부, ItemData encumbrance(line 21 정의, MagicSystem._armor_spell_mult만 사용).
**원인**: 데이터 추가 시 wire-up 누락.

### P4. static var autoload 섀도잉 (19 파일)
**원인**: 한 명이 시작 → 복붙 확산. 대부분 redundant, SimulationBot은 실제 깨짐.

### P5. Save/Load 직렬화 누락
가지 상태(C1), floor cache(C1), monster awareness(H9), altar_active/altar_map(C1), corpse(가지에선 캐시되지만 메인은 아님).
**원인**: Save 스키마가 Player만 보고, in-memory cache가 GameManager/map에 흩어짐 — 단일 진입점 없음.

### P6. UI → Turn/시스템 역방향 호출
ItemDetailDialog/BagDialog/QuickSlot 모두 `TurnManager.end_player_turn()` 직접. UI가 turn 비용 알게 됨.

### P7. log/effect 출력 vs 실 적용 시점 불일치
H5 (스펠 데미지 로그 raw), brand 로그(`_hit_log` line 301)도 final 표시 누락.

---

## 우선 처리 권장

```
Phase 0: 시체 시스템 정리 (이미 진단 완료)
Phase 1 — Critical:
  1. C1 (save 스키마 확장)
  2. C2 / C3 (스탯 누수)
  3. C4 (브랜치 몬스터 누수)
Phase 2 — 사용자 통증:
  4. H1 (스크롤 dead)
  5. H3 (인벤토리 탭) ← 사용자 명시 호소
  6. H4 (item_index stale)
Phase 3 — 기능 정상화:
  7. H9 (awareness 휘발)
  8. H2 (Faith dead data)
  9. H5/H7 (로그/파이프라인)
Phase 4 — 구조 부채:
  Game.gd 분해 (M1) / SaveMigration (M2) / CorpseService (L1) / UI 정리 (M11) / static var 정리 (H6)
```

---

## 영향 받는 파일 목록
- `scripts/main/Game.gd`
- `scripts/entities/Player.gd`, `Monster.gd`, `FloorItem.gd`
- `scripts/core/SaveManager.gd`, `GameManager.gd`, `TurnManager.gd`
- `scripts/systems/CombatSystem.gd`, `MagicSystem.gd`, `MonsterAI.gd`, `FaithSystem.gd`, `ItemRegistry.gd`
- `scripts/dungeon/DungeonMap.gd`
- `scripts/ui/BagDialog.gd`, `ItemDetailDialog.gd`, `QuickslotPicker.gd`
- `scripts/tools/SimulationBot.gd`
