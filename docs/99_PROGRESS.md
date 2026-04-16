# 진행 현황 (Progress Log)

마지막 업데이트: 2026-04-16

## 범례
- ✅ **실제 플레이로 검증됨**
- 🔧 **구현됨 (플레이 검증 대기)**
- 🐛 **버그 확인됨**
- ❌ **미구현**

---

## ✅ 검증 완료

- ✅ 웹 빌드 + GitHub Pages 배포 (사용자가 브라우저로 접속함)
- ✅ 상단 HUD 렌더 (HP/MP 바 표시)
- ✅ 던전 맵 화면 렌더 (화면 중앙 영역 가득 참)
- ✅ ULPC 5,331 PNG 빌드 단계 임포트 통과
- ✅ CREDITS_LPC.md 포함 커밋

## 🐛 검증 중 발견된 버그

- 🐛 한글 폰트 박스 출력 → 수정 완료, 배포 대기
- 🐛 BottomHUD 미노출 → 수정 완료, 배포 대기
- 🐛 몬스터 조우 프리즈 → 수정 완료, 배포 대기

## 🔧 구현됨 (검증 대기)

아래 전부 코드만 완료 상태. 버그 수정 재배포 후 사용자 플레이로 확인 필요.

### 코어
- Godot 4.6 프로젝트 세팅, 자동로드 7개
- 턴 매니저, JSON 세이브

### 던전
- BSP 분할 + 복도 + 도달성 보정
- 계단 하강 → 다음 층 재생성
- 깊이 스케일 몬스터 스폰

### 엔티티 / 전투
- Player 8방향 이동, HP/MP/스탯
- Monster AI (greedy 8-dir 추격)
- CombatSystem (DCSS식 + 스킬 보정)
- 3 몬스터 종 (rat/goblin/orc)

### 정수 시스템
- 슬롯 1개, 장착/해제, 스탯 합산
- 정수 3종 리소스
- drop_chance 기반 드롭
- 교체 팝업 UI

### 메타 진행
- 룬 조각 획득/저장
- 사망·클리어 결과 화면
- 재도전 버튼

### UI
- TopHUD (HP/MP/층수/가방·미니맵·스킬)
- BottomHUD (퀵슬롯 4 + 정수 1 + 휴식)
- PopupManager
- ResultScreen

### LPC 스프라이트
- LPCSpriteLoader / LPCDefLoader 포트
- def 80개 (34 + 46 신규)
- 캐릭터 프리셋 16개 (rat 제외, 9개 stub 포함)
- CharacterSprite 런타임 합성
- walk/slash/hurt/idle 애니메이션

### DCSS 스킬 시스템
- 26 스킬 카탈로그
- WeaponRegistry + 장착 무기 XP
- XP 커브 (30 × 1.5^(L-1), Lv.27 최대)
- 훈련 on/off
- 전투 공식 스킬 반영
- SkillsScreen UI
- 무기 스킬 힌트 (TopHUD)
- 레벨업 토스트

### 인프라
- GitHub Actions: Godot 4.6.2 web export + Pages
- 자동 Pages enablement

### 폰트 (버그 수정 과정)
- 글로벌 테마 파일, Pretendard 폰트 참조

---

## 🔜 검증 대기 시나리오

재배포 후 다음 흐름 확인 필요:

1. 기본 이동 (인접 탭, 장거리 자동이동)
2. 근접 공격 → 몬스터 HP 감소 → 사망
3. 정수 드롭 → 교체 팝업 → 장착 → 스탯 반영
4. axe 스킬 XP 성장 → Lv.2 토스트
5. 계단 하강 → B2F 재생성
6. 사망 → ResultScreen → 재도전
7. 스킬 UI 열기/탭 전환/훈련 토글
8. 한글 정상 렌더 확인
9. BottomHUD 실제 노출

---

## ❌ 미구현 (M1 범위 내 미완)

- 아이템 시스템 (포션·스크롤·무기·갑옷 드롭·줍기·인벤토리)
- 레벨업 실제 발화 (현재 플레이어 항상 Lv.1)
- 인게임 Credits 화면
- 휴식 버튼 자동 회복 로직
- 원거리 공격 UI
- 허기/식량
- FOV/시야 제한

---

## 🎯 다음 우선순위

### 즉시
0. 버그 수정 재배포 → 사용자 재플레이 → 🔧 항목들 ✅로 전환

### 단기 (M1 잔여)
1. 검증 중 추가 발견되는 버그 수정
2. 아이템 시스템 최소 버전
3. 레벨업 실연동
4. Credits 화면
5. 난이도 튜닝

### 중기 (M2 진입)
6. 정수 슬롯 3개 + 2계열 시너지 + 보관함 UI
7. 메타 업그레이드 트리 UI
8. 직업 해금 2종 (마법사, 신관) + 주문 시스템
9. 브랜치 2개 (숲, 광산)
10. FOV/시야 시스템
11. 타일셋 실제 적용

---

## 알려진 기술 부채

- LPC def 9개 stub (club/katana/scimitar/boomerang/legion_chest/body_skeleton/body_zombie/horns_small/tail_snake/wings_dragon/beard_braided)
- `greatsword.json` = longsword 스키마 복사본 (PROJ_B 기존 버그)
- rat 비휴머노이드 프리셋 없음
- 플레이어 레벨 공식 없음 (항상 Lv.1)
- Image rendering 필터 off 확인 필요 (픽셀 아트)

---

## 레포 / 배포

- GitHub: https://github.com/jinha1226/PROJ_D
- Pages: https://jinha1226.github.io/PROJ_D/
- 빌드 시간: 5~10분
