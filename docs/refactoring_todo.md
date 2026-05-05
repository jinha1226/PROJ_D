# PocketCrawl Refactoring TODO

> **2026-05-05 우선순위 갱신**: 전체 감사(`docs/audits/2026-05-05-codebase-audit.md`)에서 Critical 4 / High 9 / Medium 11 / Low 5 발견.
> 아래 Phase 1~6은 *밸런스/구조 리팩토링* 로드맵이며, 그 *이전에* 출시 차단 버그를 먼저 처리해야 함.
> 현재 활성 우선순위는 Phase 0 → Phase 1 (Critical) → Phase 2 (사용자 통증) → 기존 Phase 1~6.

## Phase 0 — 시체 시스템 정리 (완료 2026-05-05)

- [x] DCSS 정통 방식으로 변경: `tile::corpsify` 알고리즘 GDScript 포팅 (세로 2x 압축 + 곡선 컷 + 양쪽 어긋나기 + 상처색) + 핏자국 배경 합성
- [x] `assets/tiles/corpses/`에 `blood_puddle_red.png`, `blood_green.png` 추가 (DCSS rltiles)
- [x] `_CORPSE_TILE_BY_SHAPE` 매핑 + `_corpse_shape_for_monster` 거대 match 제거 → audit L1 동시 해결
- [x] `_build_corpse_texture` + `_corpse_tex_cache` 신설 (몬스터당 1회 합성, 세션 캐시)
- [x] `DungeonMap.gd:413` per-frame `load()` 제거, 시체 dict에 `tile: Texture2D` spawn 시 저장
- [ ] (선택) `scripts/systems/CorpseService.gd` 추출 — `_build_corpse_texture` + cache 이전

> 런타임 확인: Godot 에디터에서 `assets/tiles/corpses/`의 두 PNG import 후 F5 스모크 — 몬스터 처치 시 핏자국 위에 어둡게 누운 몬스터 그래픽 확인. 스파이더/스콜피온/곤충은 녹색 핏자국.

## Phase 1 — Critical 4건 (출시 절대 차단)

- [ ] **C1**: `SaveManager.save_run` 스키마 확장 — 가지 상태, floor_cache, 맵 동적 상태(altar/corpse/cloud/hazard/fog/explored/visible/monster/item) 직렬화. `save_version` 키 추가. 로드는 `_restore_floor_from_cache` 경로 재사용.
- [x] **C2** (2026-05-05): `set_equipped_armor`/`set_equipped_shield`에 weapon과 동일한 affix 제거/적용 패턴 추가. `equipped_shield_entry()` 헬퍼 신설. `drop_item` armor 분기를 `set_equipped_armor("")` 호출로 통일.
- [ ] **C3**: `Player._apply_resist_mod` 정수 누적 모델로 재작성. `resists`를 `{element: int}`로 마이그레이션 또는 `for _ in abs(value): append/erase` 정확 횟수.
- [x] **C4** (2026-05-05): `_restore_floor_from_cache` 진입부에 `_clear_monsters()` / `_clear_floor_items()` 추가 (idempotent, 모든 호출 경로 보호).

## 추가 수정 (2026-05-05)

- [x] **포션 이미지 매치**: `ItemDetailDialog`도 `GameManager.potion_color_tile()` 사용 (BagDialog와 동일). 미식별 포션이 인벤·상세창에서 같은 색.
- [x] **층 복귀 시 몬스터 즉시 채우기**: `_restore_floor_from_cache`가 `_top_up_monsters_to_target(depth)` 호출. 캐시된 몬스터(살아남은 적)는 유지하면서 부족분만 채움. 18턴×N 드립피드 대기 제거. 플레이어 6칸 이내엔 스폰 안 함.

## Phase 2 — 사용자 통증 직접 해소

- [ ] **H3**: `BagDialog._tab_filters` 데이터화 + shield/wand/throwing/essence 포함, "기타" 탭 추가
- [ ] **H4**: `Player.use_item_by_entry(entry)` entry-기반 API 추가, `ItemDetailDialog` 콜백을 entry 캡처로 전환
- [ ] **H5**: `MagicSystem._damage_auto_target` 로그를 scaled 값으로 정렬, immune 분기 정리. CombatSystem brand 로그도 검증

## Phase 3 — 기능 정상화

- [ ] **H1**: `scripts/systems/AoeEffects.gd` static helper 신설, `apply_fear_aoe` / `apply_fog_aoe` / `apply_silence_aoe` / `alert_all_monsters` / `dig_toward` 구현, `Player.use_item`이 helper 호출
- [ ] **H2**: Faith 데이터의 8개 dead 키 — 사용 site에 wire-up 또는 데이터에서 제거 + 플레이어 텍스트 정렬
- [ ] **H9**: monster awareness state(`is_aware`, `is_alerted`, `last_known_player_pos`, `pending_energy`, `_ability_charge`) cache 직렬화 추가
- [ ] **H7**: `compute_damage_pipeline`을 base / flat add / multiplicative chain / brand extra 4단계로 분리
- [ ] **H8**: TurnManager에 abort flag, `Game._on_player_died`에서 세팅
- [ ] **H6**: 19파일의 `static var X = ...get_node_or_null(/root/X)` 패턴 일괄 제거 (autoload 자동 글로벌)

## Phase 4 — 구조 부채 (출시 후 또는 병행)

- [ ] **M1**: Game.gd 분해 — `FloorLifecycle.gd`, `BranchManager.gd`, `SaveMigration.gd`, `EffectsLayer.gd`, `MonsterFactory.gd`
- [ ] **M2**: `_apply_loaded_player_state`의 인-라인 마이그레이션 → `SaveMigration.gd` 데이터 테이블
- [ ] **M3**: 클래스 starter/active skill을 `ClassData` 필드로 이전
- [ ] **M5**: `_armor_brand` 두 단계 fallback (weapon과 동일)
- [ ] **M7**: DungeonMap rendering — 시체 텍스처 캐시, TileMap/MultiMeshInstance2D 검토
- [ ] **M8**: BagDialog `_thumb_cache`, 변경된 entry만 갱신
- [ ] **M11**: UI → 시스템 역호출 정리 — `Player.equip(slot, item_id)`가 turn 비용 책임, `IdentifyPicker`는 시그널 패턴

## Phase 5 — Low

- [x] **L1**: ~~`MonsterData.corpse_shape` 필드 추가, Game.gd 거대 match 제거~~ — Phase 0 옵션 B(런타임 합성)로 shape 매핑 자체가 불필요해져 자연 해결
- [ ] **L2**: autoload redundant `@onready var = get_node` 라인 정리
- [ ] **L4**: archmage 디버그 클래스 출시 빌드 게이팅

---

## 기존 Phase 1~6 (밸런스/구조 로드맵 — 이름 충돌 주의: 위 Phase 1과 다름)

> 위 Critical 처리 후 진행. 이름 충돌 피하려면 향후 위 표기를 `Audit-P1` / `Audit-P2` 등으로 리네이밍 검토.

## Current Risk Summary

The project is currently functional, but a few systems have grown across too
many files at once:

- HP and progression rules are split across class setup, race growth, stats,
  skill leveling, and auto stat bumps.
- Faith and essence rules are spread across dialog code, player code, save
  logic, and multiple system helpers.
- Combat, magic, and monster AI each contain large monolithic functions that
  are hard to safely extend.
- Several player-facing UI panels still mix system logic, display formatting,
  and stale text handling.

These areas should be refactored before adding many more content-heavy systems.

## Refactoring Phases

## Progress Snapshot

Completed in current refactor pass:
- HP/MP gain helpers were centralized in `Player.gd`
- class/race setup now uses shared HP/MP helpers in `Game.gd`
- faith state authority was moved toward `FaithSystem`
- shrine dialog now applies faith through `FaithSystem.choose_faith()`
- load-time faith normalization was added
- first-boss shrine flow can now open a full faith-choice dialog directly
- first Essence reward now uses the real `Player.add_essence()` path
- first-boss shrine handling and monster essence-drop handling were split into
  dedicated helpers in `Game.gd`
- duplicated kill reward and shield-block logic in `CombatSystem.gd` was reduced
- `CombatSystem` now has player attack profile / hit / base-damage helpers, and
  `player_attack_monster()` has started moving onto those helpers
- `StatusDialog.gd` was rebuilt from scratch to remove corrupted text and
  mixed legacy formatting
- `MagicSystem.cast()` now delegates spell-effect dispatch to
  `_cast_effect(...)`
- `MagicSystem` spell dispatch is now grouped into damage / status / utility /
  buff families

Still pending:
- final HP growth model decision (`fighting`, strength scaling, race growth)
- removing the remaining fallback-style altar step dependency if direct choice
  becomes the only desired UX
- deeper `CombatSystem` decomposition
- deeper data-driven spell family split within `MagicSystem`

### Phase 1: Progression Model Cleanup

Priority: highest

Goal:
- define one consistent source of truth for HP, MP, stat growth, and skill
  effects

Main files:
- [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- [SkillsDialog.gd](D:\PROJ_D\scripts\ui\SkillsDialog.gd)
- [RaceData.gd](D:\PROJ_D\scripts\entities\RaceData.gd)
- class resources in [resources/classes](D:\PROJ_D\resources\classes)

Problems to solve:
- starting HP comes from class setup logic
- per-level HP comes from race growth
- strength can still affect HP
- fighting skill adds HP directly
- auto stat bump may also change HP

Target cleanup:
- define a single progression spec for:
  - starting HP
  - HP gain on XL
  - HP gain from skills
  - HP gain from stats
  - MP gain on XL
  - MP gain from magic systems
- move all derived stat recalculation into named helper functions instead of
  incremental mutation from many call sites

Recommended changes:
- add a single `recalculate_progression_stats()` or equivalent helper on
  `Player`
- reduce direct `hp_max += X` changes outside progression/equipment/status
  helpers
- centralize skill-on-level effects in one place
- document the final HP/MP model in code comments near the implementation

Open design questions:
- is fighting permanent in the final split-skill model?
- does strength affect HP at all?
- is HP growth fully XL-based, or partly skill-based?

### Phase 2: Faith / Essence / Shrine Flow Cleanup

Priority: highest

Goal:
- make the first-boss shrine choice, faith state, and essence branch behave as
  one coherent system

Main files:
- [FaithSystem.gd](D:\PROJ_D\scripts\systems\FaithSystem.gd)
- [EssenceSystem.gd](D:\PROJ_D\scripts\systems\EssenceSystem.gd)
- [ShrineDialog.gd](D:\PROJ_D\scripts\ui\ShrineDialog.gd)
- [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)

Problems to solve:
- faith selection timing and shrine activation are not fully unified
- faith state is partially represented by strings and partially by side effects
- essence permission rules depend on both explicit faith and legacy empty-state
  handling
- shrine dialog currently owns some system mutations directly

Target cleanup:
- define a single faith state model:
  - no faith chosen yet
  - one of the four normal faiths
  - essence path
- define one authority for:
  - can use essence?
  - can choose shrine?
  - has first shrine choice happened?
  - what happens when switching or loading state?

Recommended changes:
- move faith-application side effects from dialog code into `FaithSystem`
- add explicit helpers such as:
  - `choose_faith(player, faith_id)`
  - `enter_essence_path(player)`
  - `can_use_essence(player)`
- let UI call systems, not mutate player state directly
- treat empty `faith_id` only as migration state, not ongoing gameplay state

Open design questions:
- is essence path a true fifth faith or a separate non-faith route?
- should first essence choice happen immediately on selecting Essence?
- should shrine choice happen on boss clear or on altar interaction?

### Phase 3: Combat Decomposition

Priority: high

Goal:
- break large combat functions into smaller rule-specific helpers

Main files:
- [CombatSystem.gd](D:\PROJ_D\scripts\systems\CombatSystem.gd)
- [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- [Monster.gd](D:\PROJ_D\scripts\entities\Monster.gd)

Problems to solve:
- one attack function currently handles too many responsibilities
- weapon category logic, faith multipliers, brands, backstab, and XP rewards
  are tightly coupled
- future work on tool skill, ranged rebalance, or faith bonuses will be risky

Recommended extraction points:
- weapon category and required skill mapping
- attack accuracy calculation
- raw damage calculation
- post-hit special effects
- on-kill rewards and XP distribution
- unaware/backstab logic

Suggested target structure:
- `compute_attack_profile(...)`
- `roll_hit(...)`
- `compute_damage(...)`
- `apply_hit_effects(...)`
- `apply_kill_rewards(...)`

### Phase 4: Magic System Decomposition

Priority: high

Goal:
- reduce the size of the central spell dispatch function and make spell effects
  easier to add safely

Main files:
- [MagicSystem.gd](D:\PROJ_D\scripts\systems\MagicSystem.gd)
- spell data resources
- [MagicDialog.gd](D:\PROJ_D\scripts\ui\MagicDialog.gd)

Problems to solve:
- spell behavior is mostly controlled through large string matches
- spell rules, target rules, damage rules, and UI assumptions are mixed
- balance changes require editing large switch-style logic

Recommended refactor direction:
- split spells by effect family:
  - bolt/projectile
  - blast/aoe
  - summon
  - status/debuff
  - blink/mobility
  - self-buff
- add helper methods for each family
- keep `cast()` as orchestration, not full behavior implementation

Open design questions:
- should schools remain flavor-only, or affect behavior tables later?
- should spell range/cost modifiers live entirely in `FaithSystem` and player
  stats helpers?

### Phase 5: Monster AI Data-Driven Cleanup

Priority: medium-high

Goal:
- make AI behavior more data-driven and reduce monster-id-specific branching

Main files:
- [MonsterAI.gd](D:\PROJ_D\scripts\systems\MonsterAI.gd)
- [MonsterData.gd](D:\PROJ_D\scripts\entities\MonsterData.gd)
- monster resources in [resources/monsters](D:\PROJ_D\resources\monsters)

Problems to solve:
- AI contains many hardcoded monster id checks
- boss logic, ranged logic, support logic, and status logic are intertwined
- adding a new monster often means adding more special-case code

Recommended refactor direction:
- move more intent flags into `MonsterData`
  - `is_boss`
  - `ai_style`
  - `preferred_range`
  - `special_ability`
  - `charge_attack_type`
- keep shared AI routines in code
- reduce ID comparisons where possible

### Phase 6: UI Text / Tooltip / Encoding Cleanup

Priority: medium-high

Goal:
- make the systems readable to players and remove stale or broken text output

Main files:
- [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)
- [SkillsDialog.gd](D:\PROJ_D\scripts\ui\SkillsDialog.gd)
- [BagDialog.gd](D:\PROJ_D\scripts\ui\BagDialog.gd)
- [BestiaryDialog.gd](D:\PROJ_D\scripts\ui\BestiaryDialog.gd)
- [ShrineDialog.gd](D:\PROJ_D\scripts\ui\ShrineDialog.gd)

Problems to solve:
- some text still contains mojibake or stale formatting artifacts
- important systems are implemented, but their explanations are inconsistent
- system text and logic formatting are mixed in the same methods

Recommended changes:
- remove corrupted strings first
- centralize short descriptions where practical
- make skill, faith, item, and monster explanations consistent with current
  systems

## Immediate File-Level TODOs

### [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- unify HP/MP recalculation flow
- isolate fighting effects from generic skill XP code
- reduce direct mutation of derived stats from many places
- consider extracting:
  - progression helpers
  - inventory item effect helpers
  - essence/stat recalculation helpers

### [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- reduce responsibility in class application and spawn initialization
- move faith/shrine progression logic into dedicated systems
- split save/load migration concerns from core runtime logic

### [FaithSystem.gd](D:\PROJ_D\scripts\systems\FaithSystem.gd)
- become the single authority for faith state and faith-derived modifiers
- stop relying on empty-string gameplay semantics after migrations

### [EssenceSystem.gd](D:\PROJ_D\scripts\systems\EssenceSystem.gd)
- separate:
  - effect application
  - passive queries
  - resonance logic
  - inventory capacity rules
- normalize interactions with faith restrictions

### [CombatSystem.gd](D:\PROJ_D\scripts\systems\CombatSystem.gd)
- split attack resolution into smaller helpers
- isolate balance constants near the relevant logic

### [MagicSystem.gd](D:\PROJ_D\scripts\systems\MagicSystem.gd)
- replace giant effect dispatch with grouped handlers
- make spell family behaviors easier to audit and tune

### [MonsterAI.gd](D:\PROJ_D\scripts\systems\MonsterAI.gd)
- move repeated boss/behavior checks into data tags where possible
- separate ranged, caster, support, and boss routines

### [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)
- remove broken strings and encoding damage
- split rendering helpers by section:
  - stats
  - equipment
  - faith
  - essence
  - resonance

## Suggested Execution Order

1. progression cleanup
2. faith / essence state cleanup
3. shrine first-boss event cleanup
4. combat decomposition
5. magic decomposition
6. monster AI cleanup
7. UI text and tooltip pass

## Do Not Refactor Yet

Avoid large rewrites of these areas until the progression and faith models are
stable:

- full item economy rewrite
- full resist-system rewrite
- wide monster roster rebalance
- final tooltip wording pass
- large new content additions

## Success Criteria

This refactor pass is successful if:

- HP and MP sources are explainable in one short paragraph
- first shrine / faith / essence behavior has one clear flow
- combat and magic can be changed without editing giant functions every time
- status and skill screens explain the current rules without corrupted text
- adding one new monster, one new spell, or one new faith perk no longer feels
  risky
