# 진행 현황 (Progress Log)

마지막 업데이트: 2026-04-16

## 범례
- ✅ **실제 플레이로 검증됨**
- 🔧 **구현됨 (플레이 검증 대기)**
- 🐛 **버그 확인됨**
- ❌ **미구현**

---

## ✅ 검증 완료

- ✅ 웹 빌드 + GitHub Pages 배포 (브라우저 접속)
- ✅ 상단 HUD 렌더 (HP/MP 바)
- ✅ 던전 맵 렌더
- ✅ ULPC PNG 임포트 통과
- ✅ CREDITS_LPC.md 커밋

---

## 🐛 사용자 플레이 후 보고된 이슈 (최근 세션에서 수정 — 재검증 대기)

모두 코드 수정 완료, 배포됨. 재플레이로 재확인 필요.

### 레이아웃 / UI
- 🐛→🔧 BottomHUD 미노출 (+ + + + 퀵슬롯/정수/REST)
  - 원인: UI CanvasLayer가 UILayer CanvasLayer 안에 중첩 → Control 자식의
    `anchor_top=1.0` resolve 실패 (parent size 0으로 계산) → 원점(0,0)에 size 0
  - 수정: BottomHUD.tscn을 `position=(0,2196) size=(1080,144)` 하드코딩
  - 같은 이슈로 ZoomControls도 앵커 대신 explicit position/size 적용
- 🐛→🔧 SkillsScreen 닫기/목록 표시
  - 원인 1: Dim(ColorRect) + Panel이 중첩 CanvasLayer 안에서 앵커 resolve 실패
    → Panel이 (-460,-1000)에 배치, X 버튼이 화면 밖
  - 원인 2: `queue_free()` 타이밍으로 재빌드 시 stale 자식 남음
  - 수정: Dim/Panel/Margin 모두 explicit position+size, `free()`로 즉시 삭제,
    `_on_bg_input`의 panel_rect 하드코딩
- 🐛→🔧 TopHUD 깊이 라벨이 계단 이동에도 B1F 고정
  - 원인: `TopHUD.set_depth()` 메서드는 있었으나 `GameBootstrap`에서 호출 없음
  - 수정: `_ready()` 및 `_regenerate_dungeon()`에서 호출

### 기능 / 입력
- 🐛→🔧 MAP 버튼 무반응 (시그널 바인딩 없음)
  - 수정: `GameBootstrap._on_minimap_pressed` 추가 → AcceptDialog placeholder
- 🐛→🔧 BAG 버튼 무반응
  - 수정: `_on_bag_pressed` → 인벤토리 리스트 + Use/Drop 버튼
- 🐛→🔧 STAIRS_UP 상호작용 불가 ("You can't go back up." print 스텁)
  - 수정: `stairs_up_tapped` 시그널 추가, `_on_stairs_up_tapped` 핸들러
    (`GameManager.current_depth -= 1` + 재생성)
- 🐛→🔧 계단 올라가면 "새로운" B1F 생성
  - 원인: `_regenerate_dungeon`이 매번 `randi()`로 새 시드 사용
  - 수정: `_base_seed` 런 시작 시 1회 확정 → depth당 고정 맵.
    `_regenerate_dungeon(going_up: bool)`: 올라갈 때 `stairs_down_pos`에 배치
    (원래 내려갔던 위치로 복귀)
- 🐛→🔧 자동이동 중 멀리 있는 적 때문에 취소됨
  - 원인: SIGHT_RANGE=6칸, 화면 대부분이 범위 안 (fog-of-war 없음)
  - 수정: SIGHT_RANGE=3칸

### 스프라이트
- 🐛→🔧 캐릭터 팔 없음
  - 원인: ULPC 미러 스크립트가 인간 body 스프라이트 누락 → body/bodies/ 에
    skeleton/zombie만 존재
  - 수정: PROJ_B에서 `body/bodies/{male,female}/*.png` 복사

---

## 🔧 신규 구현 (검증 대기)

### 자동이동 시각화
- `DungeonMap.show_path(path)` / `clear_path()`: 예정 경로를 청록 점으로 표시
- `TouchInput`: 경로 오버레이 갱신 + 150ms 스텝 간격 (`create_timer`)

### 더미 아이템 시스템 (M1 최소 버전)
- `FloorItem` 엔티티: 다이아몬드 픽업, `floor_items` 그룹
- `Player.items` 인벤토리 Array + `inventory_changed` 시그널
- 이동 시 자동 픽업 (`_pickup_items_here`)
- `use_item` (potion → HP +20, scroll → 로그), `drop_item` (현재 위치에 재배치)
- `GameBootstrap._spawn_dummy_items(5)`: potion/scroll/junk 5종 랜덤 배치
  (재생성 시 floor_items 그룹 전체 제거 후 재배치)
- BAG 팝업: 아이템별 Use/Drop 버튼, 선택 시 팝업 재오픈 (즉시 갱신)

### 테스트 튜닝
- `MonsterData.xp_value` 기본값 10 → 100
- `xp_value == 0` fallback: `tier * 3` → `tier * 30`
  → 첫 킬로 Fighting/Weapon 스킬 Lv.1+ 진입 가능
- `MAX_DEPTH` 15 → 2 (계단 상/하 테스트 집중)

---

## 🔧 구현됨 (이전 세션, 여전히 검증 대기)

### 코어
- Godot 4.6 프로젝트, 자동로드 7개, 턴 매니저, JSON 세이브

### 던전
- BSP 분할 + 복도 + 도달성 보정
- 깊이 스케일 몬스터 스폰

### 전투
- Player 8방향 이동, HP/MP/스탯
- Monster AI (greedy 추격)
- CombatSystem (DCSS식 + 스킬 보정)
- 3 몬스터 종 (rat/goblin/orc)

### 정수 시스템
- 슬롯 1, 장착/해제, 스탯 합산, 드롭/교체 팝업

### 메타 진행
- 룬 조각, 사망·클리어 결과, 재도전

### LPC 스프라이트
- LPCSpriteLoader / LPCDefLoader 포트
- def 80개, 프리셋 16개
- walk/slash/hurt/idle 애니메이션

### DCSS 스킬 시스템
- 26 스킬 카탈로그 + XP 커브 (30 × 1.5^(L-1))
- WeaponRegistry, 장착 무기 XP
- 훈련 on/off, 레벨업 토스트
- SkillsScreen UI, TopHUD 힌트

### 인프라
- GitHub Actions: Godot 4.6.2 web export + Pages

---

## 🔜 검증 대기 시나리오 (재플레이 체크리스트)

1. 상단 HUD: MAP/HP/MP/B*F/BAG/SKILLS 한 줄에 정렬
2. 하단 HUD: 퀵슬롯 4 + 정수 + REST 노출
3. ZoomControls(+/−): 화면 우측 중단
4. MAP 버튼 → placeholder 팝업
5. BAG 버튼 → 아이템 리스트, Use 시 HP 회복/로그, Drop 시 바닥 배치
6. SKILLS 버튼 → 스킬 리스트 26개, X/바깥 탭으로 닫힘, ESC 닫힘
7. 장거리 탭 → 경로 점 표시 + 스텝별 이동
8. 주변(3칸) 몬스터 접근 시 자동이동 취소
9. 몬스터 킬 시 XP 획득 → 스킬 Lv 상승 토스트
10. 아이템 줍기 → 이동 시 자동 픽업, 픽업 로그 출력
11. B1F 계단 하강 → B2F
12. B2F 계단 상승 → **같은** B1F 맵, 원래 내려갔던 위치에 등장
13. B2F에서 계단 하강 → 클리어 결과 화면 (MAX_DEPTH=2)
14. 캐릭터 팔 / 몸 보임 확인 (barbarian)

---

## ❌ 미구현 (M1 범위 외 또는 보류)

- **몬스터/아이템 상태 persist**: 맵 지형만 유지, 몬스터·아이템은 재방문 시 재생성
- FOV / 시야 제한 (fog of war)
- 이동/공격 스프라이트 트윈 (현재 즉시 점프)
- 레벨업 실제 발화 (플레이어 항상 Lv.1)
- 인게임 Credits 화면
- 휴식 버튼 자동 회복 로직
- 원거리 공격 UI
- 허기/식량
- 실제 아이템 데이터베이스 (현재 5종 하드코딩 더미)

---

## 🎯 다음 우선순위

### 즉시
0. 배포 완료 후 재플레이 → 🔧 → ✅ 전환

### 단기
1. 재검증 중 추가 버그 수정
2. 몬스터/아이템 층 persist (현재 지형만 유지)
3. FOV / 시야 제한
4. 레벨업 실연동

### 중기 (M2 진입)
5. 정수 슬롯 3개 + 2계열 시너지 + 보관함 UI
6. 메타 업그레이드 트리 UI
7. 직업 해금 2종 (마법사/신관) + 주문
8. 브랜치 2개 (숲/광산)
9. 타일셋 실제 적용
10. 이동/공격 애니메이션 트윈

---

## 알려진 기술 부채

- LPC def 9개 stub (club/katana/scimitar/boomerang/legion_chest/body_skeleton/
  body_zombie/horns_small/tail_snake/wings_dragon/beard_braided)
- `greatsword.json` = longsword 복사본 (PROJ_B 기존)
- rat 비휴머노이드 프리셋 없음
- 플레이어 레벨 공식 없음 (항상 Lv.1)
- ULPC 중첩 CanvasLayer + Control 앵커 조합이 부분적으로 깨지는 이슈
  → 현재 문제 지점마다 explicit position/size로 우회 중. 리팩터 후보.
- `MAX_DEPTH=2`는 테스트용 임시값 — M1 릴리즈 전 15로 복귀

---

## 레포 / 배포

- GitHub: https://github.com/jinha1226/PROJ_D
- Pages: https://jinha1226.github.io/PROJ_D/
- 빌드 시간: 5~10분
