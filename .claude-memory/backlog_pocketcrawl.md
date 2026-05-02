---
name: PocketCrawl pending backlog
description: Next-session task list — bugs, features, and balance work. Primary source: docs/balance/claude_code_balance_handoff.md + claude_code_drop_table_handoff.md + claude_code_essence_and_resistance_handoff.md (2026-04-27)
type: project
originSessionId: 545aa407-23ef-4b76-ad7b-298f33b869e6
---
## 현재 방향 (handoff 기준)

- 목표: mobile-readable, 빠른 층 페이싱, 압축된 전술 결정
- 클래스: Fighter(방어/근접), Mage(마법/민첩), Rogue(원거리/민첩)
- 스킬 5개 — 두 핵심 스킬이 8~9까지, 전문화가 중요
- Essence = 두 번째 빌드 축 (신 시스템 대체)
- 저항: fire / cold / poison / will 4종류로 단순화
- 맵: 32×36, Pixel Dungeon보다 약간 크고 구 DCSS보다 확연히 좁음

## 완료된 작업 (2026-04-27 세션)

### 맵 / 던전
- ✅ 문(Door) 시스템, 맵 압축(32×36), _COR 버그 수정

### 드롭 이코노미
- ✅ 층당 랜덤 포션/스크롤/장비, 책 40% 확률
- ✅ 섹터 확정드롭(3층=1섹터): 회복포션, 강화스크롤, 완드
- ✅ 에센스 섹터당 2개, 장비 티어 가중치, 완드 충전수 하향

### Essence & Resistance 시스템
- ✅ 저항: necromancy+ 제거 (wight, mummy에서)
- ✅ EssenceSystem: 8개 고유 몬스터 에센스 추가
  (gloam, cinder, serpent, bastion, dread, bloodwake, tempest, pale_star)
- ✅ MonsterData: is_unique, drop_chance_override 필드 추가
- ✅ 8개 고유 몬스터 .tres 파일 생성 (섹터 1~8 배치)
- ✅ MonsterRegistry: 고유 몬스터 등록, unique_for_depth(), is_unique 가드
- ✅ Game.gd: _spawn_unique_for_floor (섹터 3번째 층), _on_monster_died unique 분기
- ✅ CombatSystem: gloam 비인지 데미지 +35%, tempest 원거리 +15%
- ✅ Player.gd: bloodwake 포션 회복 -20%, bastion+vitality +3
- ✅ random_id()에서 고유 에센스 제외 (전용 드롭 채널만)

### 공명(Resonance) 추가
- ✅ Gloam+Swiftness, Cinder+Arcana, Serpent+Swiftness
- ✅ Bastion+Vitality, Dread+Warding, Bloodwake+Fury
- ✅ Tempest+Arcana, Pale Star+Arcana

### 기타
- ✅ 자동이동 중 HP/MP 재생 (passive regen)

---

## 미완료 / 다음 작업

### P3: Rogue 정체성 완성
- 현재 위험: 수치만 다른 약한 Fighter처럼 느껴질 수 있음
- 탐색: 초반 원거리 데미지 강화, agility 상호작용, 유틸리티 아이템 루프, 인지 조작 아이템
- 피할 것: 취약한 근접 은신 세금으로 회귀

### P4: Injury 공정성 패스
- 목표: 압박 유지, 좌절감 제거
- 점검: 피격당 injury 누적률, 방어 기반 injury 경감, 포션/붕대 회복 커브
- Fighter가 Mage 대비 불합리하게 불리하지 않아야 함

### P5: Essence 공명 패스
- 현재 공명 효과 체감 여부 확인
- 모든 주요 에센스에 명확한 장단점
- 공명 보너스가 노릴 만한 가치 있는지
- 인벤 상한이 의미있는 픽업 결정을 만드는지

## 피해야 할 것 (handoff 명시)
- 많은 약한 적으로 가득 찬 넓은 맵
- 모든 클래스를 잡식 하이브리드로 만들기
- 모든 문제를 스탯 인플레로 해결
- 저항 타입 재증가 (fire/cold/poison/will 4개 유지)
- 고유 에센스를 단순 스탯 잭팟으로 만들기
- 에센스 인벤 무제한 완화
