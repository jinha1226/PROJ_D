# Three Systems Design — 2026-04-30

## A. 종족별 HP per level
RaceData에 `hp_per_level: int` 추가. Player._level_up_hp_gain()에서 참조.
값: Human 5, Elf 3, Dwarf 4, Hill Orc 5, Kobold 3, Troll 7, Minotaur 6, Spriggan 2, Gargoyle 3, Vampire 4

## B. Cloud 타일 시스템
DungeonMap.cloud_tiles: Dictionary { Vector2i → {type, turns} }
타입: fire(3dmg), poison(1dmg+poison), cold(2dmg), electricity(2dmg+wet보너스)
- 플레이어 턴 시작 시 cloud damage tick
- 몬스터 take_turn()에서 cloud damage tick
- fire/aoe_damage 마법 명중 시 fire cloud 생성 (3턴)
- scroll_immolation → 시야 내 전체 fire cloud
- Infernal 브랜치: MapGen에서 lava 타일 배치 (진입 시 8 데미지/턴)
- Swamp 브랜치: MapGen에서 shallow_water 타일 (진입 시 is_wet 자동)

## C. Abyssal Sovereign (B15 보스)
hp=300, hd=22, ac=12, ev=8, speed=12
페이즈1(HP>50%): telegraph_aoe r=2 + 30%확률 zombie 소환
페이즈2(HP≤50%): telegraph_aoe r=3 AND telegraph_line 동시, speed=15, 50%확률 2마리 소환
B15: 보스 킬 → 승리 화면
