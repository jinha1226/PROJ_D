---
name: PocketCrawl pending backlog
description: Next-session task list — bugs, features, and major design work confirmed by user
type: project
originSessionId: cbad590a-8beb-4eb1-bd29-f361f6be2fd2
---
## 대규모 작업 완료 이력

### Zone & Monster Expansion ✅ DONE (main에 머지)
- 8존×3층+보스, 38몬스터, CA맵, 환경피해, EssenceSystem poison/neg

### 이번 세션 완료 ✅ (2026-04-24)
- **한글 폰트**: Pretendard-Regular.otf, korean_theme.tres
- **DCSS 서브스킬**: Fighting(HP+dmg), Magic(fizzle), 6개 마법 학파 스킬
- **Skills 다이얼로그**: 4탭 (LEARNED/COMBAT/DEFENSE/MAGIC), 학파별 주문 목록
- **종족 패시브**: 11종족 RacePassiveSystem autoload, CombatSystem/MagicSystem/Game.gd 훅 연결
- **직업 2-step 선택**: Fighter/Wizard/Rogue 아키타입 → 세부 직업
  - Fighter: Warrior, Berserker, Spearman(신규), Crusher(신규)
  - Rogue: Rogue, Ranger
  - Wizard: Mage, Evoker, Conjurer, Transmuter, Necromancer, Abjurer, Enchanter, Archmage
  - ice_mage 비활성화 (unlocked=false, class_group="")
- **Spear 아이템** 추가 (polearm 카테고리, d8)
- **에센스 12개**: Fury(킬 시 분노), Drain(킬 시 흡수), 기존 10개 + Active 효과 추가
- **Bestiary**: BestiaryDialog, 몬스터 킬카운트 추적, 세이브 연동
- **UI/UX 버그 7개**: 아이템 터치 release로 수정, 장착중 표시, 미확인 아이템 숨김, ItemDetailDialog 비교 카드, 자동탐색 아이템 우선, 미니맵 floor 위치, 아크메이지 전층 이동

---

## 미완료 / 다음 작업

### 즉시 처리 필요
- **Bestiary 버튼 연결**: BottomHUD .tscn 씬에서 _on_bestiary_pressed 버튼 wiring (에디터 작업)
- **Reach 시스템**: Spearman 직업 있지만 polearm 2칸 공격 로직 미구현 (CombatSystem, MonsterAI)
- **Ranger 무기**: 현재 mace 임시 — short_bow 아이템 없음 (원거리 아이템 시스템 미존재)

### 설계 논의 중
- **디아블로식 affix 아이템**: 노말/매직/레어 등급, 랜덤 접두·접미사 능력치 변동
- **마을 시스템**: 상점 + 동료 영입

### 기존 버그 (대기)
1. 몬스터 공격 속도 — MonsterAI.gd, TurnManager.gd
2. 아이스 마법책 읽기 불가 — Player.gd, ItemRegistry.gd
3. 계단 올라가기 불가 + 층간 상태 유지 — Game.gd, GameManager.gd
4. 미감정 포션/스크롤 시스템
5. 밝힌 맵 터치로 멀리 이동 (auto-walk)
