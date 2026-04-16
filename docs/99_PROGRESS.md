# 진행 현황 (Progress Log)

마지막 업데이트: 2026-04-16

## 범례
- ✅ **실제 플레이로 검증됨**
- 🔧 **구현됨 (플레이 검증 대기)**
- 🐛 **버그 확인됨**
- ❌ **미구현**

---

## 현재 브랜치 / 세션 핸드오프 노트

**HEAD**: 보라색 UI 재배치 작업 중 (TopHUD 가로 bars + 미니맵 / BottomHUD 2 rows).
**다음 커밋 대기 중인 변경사항**:
- `scenes/ui/TopHUD.tscn` 전면 재작성 — HBox[Minimap 200×200 | VBox[HP row, MP row, XP row]] 각 row 60px 얇은 bar + 260px 라벨
- `scripts/ui/TopHUD.gd` 전면 재작성 — `minimap_pressed` signal, `set_hp/set_mp/set_xp(cur,to_next,lv)/set_depth/set_minimap_texture(tex)` API; 구 button 시그널 제거, weapon_skill_label stub만 남김
- `scenes/ui/BottomHUD.tscn` — 2 rows: Row1 [QS×4 + Spacer + REST 160×112], Row2 [BAG / SKILLS / STATUS 각 expand 112]. 위치 y=2060, size (1080, 280). EssenceSlot 제거됨
- `scripts/ui/BottomHUD.gd` — `bag_pressed`/`skills_pressed`/`status_pressed` 추가, `set_essence` stub (역호환)
- `scripts/entities/Player.gd` — `xp_changed(cur,to_next,level)` signal 추가, `grant_xp`에서 emit
- `scripts/core/GameBootstrap.gd` — bag/skills/status를 bottom_hud에서 connect, 기존 top_hud essence_slot_tapped wiring 제거. `_refresh_minimap_preview(dmap, player_pos)` 도입 — 초기 spawn, `_on_player_moved`, `_regenerate_dungeon` 세 시점에서 `TopHUD.set_minimap_texture(tex)` 호출. Status 팝업에 essence 섹션 + Swap 버튼 + 명시적 Close 버튼 (AcceptDialog OK 외 추가)
- `scripts/ui/ZoomController.gd` — DEFAULT_ZOOM 2.0 → 2.6

**검증 필요 (이번 배치)**:
1. 상단 HP/MP/XP 3바 + 좌측 미니맵 프리뷰 (탭하면 확장)
2. 하단 quickslots + REST 한 줄, BAG/SKILLS/STATUS 한 줄
3. STATUS 팝업에 Essence 섹션 + Swap 버튼 + Close 버튼
4. 시작 장비 (Fighter 등) 플레이어 스프라이트에 첫 턴부터 표시
5. 핀치 줌인/줌아웃 양방향 반응
6. MAP 팝업 탭 → 자동이동
7. Identify 스크롤: 미식별 아이템 목록 팝업 → 하나만 선택 감정
8. 포션/스크롤 주우면 하단 quickslot에 자동 배치, 탭하면 사용
9. 벽이 타일 중앙 얇은 띠로 그려지는지

---

## ✅ 검증 완료

- ✅ 웹 빌드 + GitHub Pages 배포
- ✅ 상단 HUD 렌더 (HP/MP 바)
- ✅ 던전 맵 렌더
- ✅ ULPC PNG 임포트
- ✅ CREDITS_LPC.md 커밋

---

## 🔧 최근 세션 커밋 요약 (검증 대기)

### 종족/직업/선택 플로우
- `MainMenu` → `RaceSelect` → `JobSelect` → `Game.tscn` 플로우
- 8 종족 (Human/Hill Orc/Minotaur/Deep Elf/Troll/Spriggan/Catfolk/Draconian)
- 20 직업 (DCSS 백그라운드 기반)
- RaceData/JobData 리소스 필드 확장 (body_def/skin/hair/beard/horns/ears/base_ac/racial_trait, starting_equipment, starting_skills)
- Player._compose_preset 실시간 race+장비 조합 (160 combo JSON 없이)
- 카드에 SubViewport CharacterSprite 실시간 프리뷰

### 종족 특성 실장
- Troll Regeneration (턴당 +1 HP)
- Spriggan 2× 이동 속도 (move_speed_mod 카운터)
- Draconian +2 AC (race.base_ac, `_recompute_defense` 합산)
- Minotaur Headbutt (근접 25% 확률 +2~5 dmg)
- Catfolk Claws (맨손 +3 dmg)

### 아이템 시스템
- `WeaponRegistry.display_name_for` — 깔끔한 이름 (Arming Sword 등)
- `ArmorRegistry` 5슬롯 × 12항목 (chest/legs/boots/helm/gloves, alias 포함)
- Player 멀티 슬롯 (equipped_armor: slot→info 딕셔너리)
- 장착 시 즉시 LPC 스프라이트 갱신
- FloorItem `extra` 필드 slot/ac 저장 (floor persist 포함)
- `ConsumableRegistry` — 7종 (healing/mana potion, teleport/magic_map/blink/identify scroll)
- Scroll of Identification = 한 장에 한 아이템만 (picker 팝업)

### 식별 시스템
- `GameManager.identified` dict + `_pseudonyms` (Red Potion / Scroll labeled ZUN TAB 식)
- 사용 시 자동 식별
- Retry/New Run 시 pseudonyms 재할당

### 전투 / 턴 시스템
- 이동/공격 tween (120ms 이동, 카메라 follow 140ms, 공격 lunge는 제거)
- FOV Bresenham LOS (시야/탐색/미탐색 3상태)
- Floor persistence (map seed + 몬스터/아이템 스냅샷)
- 계단 상승 시 원래 stairs_down_pos에 배치
- Player level up + stat choice popup
- REST 버튼 (HP/MP regen, 적 시야 진입 시 중단)
- QuickSlot 자동 배정 (포션/스크롤 픽업 시 첫 빈 슬롯)

### 던전
- BSP_MAX_DEPTH 5 → 3 (≤8 방), MAP 40×60
- 벽 얇게 (타일 중앙 40% 높이 띠)
- DungeonMap `is_tile_visible` (CanvasItem.is_visible 충돌 해결)
- 미니맵 탭 → A* 자동이동

### UI 크기/가독성
- 모든 메뉴 폰트 확대 (iPhone 15 Pro 기준)
- Race/Job 카드 540×520~540, 폰트 32~36
- Skills/Status/BAG 폰트 28~32
- STATUS 버튼 추가 (race+job/레벨/HP/MP/스탯/AC 분해/장비 슬롯/trait)
- Credits는 MainMenu 전용 (BuildVersionLabel은 버전만)

### 핀치 줌
- MIN_ZOOM 0.25 (확장), damping 제거
- Wheel 1.20/0.83
- DEFAULT_ZOOM 2.6 (대기 중인 변경분)

---

## ❌ 아직 미구현 / 보류

- FOV 원추형 / shadowcasting (현재 Bresenham 원형)
- 원거리 공격 UI (조준선 표시 + 탭 확정)
- 주문 시전 시스템 (MP 소모)
- 메타 업그레이드 트리 UI
- 정수 슬롯 3개 + 2계열 시너지
- 브랜치 2개 (Forest/Mine)
- 실제 타일셋 적용 (현재 단색 rect)
- 세이브/로드 실장
- MAX_DEPTH 2 → 15 복구
- ULPC body 변형 에셋 (muscular/teen/child)
- LPC def 9개 stub (club/katana/scimitar/boomerang 등)
- rat 비휴머노이드 프리셋

---

## 알려진 기술 부채

- 중첩 CanvasLayer anchor 워크어라운드 (Game.tscn의 UI 계층, Bottom/TopHUD explicit position 하드코딩)
- `MAX_DEPTH = 2` 테스트용 임시값
- `_XP_PER_LEVEL = 100` 레벨업 너무 빠름 (밸런스 튜닝 필요)
- `barbarian.tres` legacy 파일 남아있음
- LPC def 일부 stub

---

## 레포 / 배포

- GitHub: https://github.com/jinha1226/PROJ_D
- Pages: https://jinha1226.github.io/PROJ_D/
- 빌드 시간: 5~10분

---

## 다른 Claude 세션 이어가는 법

1. `git pull origin main` 후 최신 커밋 확인
2. `docs/99_PROGRESS.md` 상단 "핸드오프 노트" 섹션 참고
3. 사용자 요청에 따라 작업하되, 주요 루틴:
   - **TopHUD/BottomHUD 수정**: 두 HUD 모두 `anchor` 대신 explicit `position`/`size` 씀 (중첩 CanvasLayer 이슈 회피). 수정 시 유지
   - **아이템 추가**: WeaponRegistry / ArmorRegistry / ConsumableRegistry에 엔트리 추가 → Player가 자동 픽업/장착
   - **종족 추가**: `resources/races/{id}.tres` + `RaceSelect.gd`의 `RACE_IDS`에 id 추가
   - **트레잇 추가**: `racial_trait` 문자열 + GameBootstrap._apply_passive_racial_traits 또는 CombatSystem.melee_attack에 분기
4. 커밋은 **실제 테스트 후에만** ✅로 문서 업데이트 (사용자 강조사항). 구현만 됐으면 🔧
5. 푸시는 자동으로 — GitHub Actions가 빌드/배포 (5~10분)
