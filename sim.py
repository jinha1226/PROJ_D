"""
PocketCrawl Full-Run Simulation
- 레벨업 / 스킬업 / 아이템드롭 반영
- 새 힐링 시스템: injury=hp_max 감소, 자동회복 1HP/4턴, 포션=injury0+max_hp*20%(min10)
- 붕대: injury-10, HP+cleared/2
- 목표: 존1=90%, 존2=80%, ..., 존8=20%
"""
import random
import math
import statistics
from dataclasses import dataclass, field
from typing import List, Optional, Tuple

# ── XP 커브 (Player.gd 복사) ──────────────────────────────────────────────────
XP_CURVE = [0, 10, 30, 70, 140, 250, 420, 700, 1150, 1800,
            2800, 4200, 6000, 8400, 11500, 15500, 20500, 27000, 35500, 47000]
SKILL_XP_DELTA = [13, 20, 32, 52, 78, 110, 150, 195, 260,
                  325, 455, 650, 910, 1300, 1820, 2600, 3575, 4875, 6500, 8450]

def xp_to_next(xl: int) -> int:
    if xl < len(XP_CURVE):
        return XP_CURVE[xl]
    return int(XP_CURVE[-1] * (1.35 ** (xl - len(XP_CURVE) + 1)))

# ── 몬스터 ────────────────────────────────────────────────────────────────────
@dataclass
class Mon:
    name: str
    hp: int
    hd: int
    ac: int
    ev: int
    dmg: int
    xp: int

ZONE_MONSTERS = {
    1: [
        Mon("bat",          4,  1, 0, 12, 2,  2),
        Mon("rat",          6,  1, 0,  7, 3,  1),
        Mon("jackal",       5,  1, 1, 11, 2,  1),
        Mon("hound",        7,  2, 1, 10, 3,  2),
        Mon("kobold",       7,  2, 1,  6, 3,  2),
        Mon("giant_cockroach", 8, 1, 3, 8, 3, 2),
        Mon("wolf",        11,  2, 2, 12, 5,  3),
    ],
    2: [
        Mon("goblin",      12,  3, 2,  8, 4,  4),
        Mon("adder",       10,  3, 1, 10, 4,  4),
        Mon("scorpion",    12,  2, 3,  8, 5,  4),
        Mon("vampire_bat", 10,  2, 2, 14, 4,  4),
        Mon("hobgoblin",   18,  4, 3,  7, 5,  6),
        Mon("orc_warrior", 20,  4, 4,  7, 8,  6),
        Mon("zombie",      22,  3, 3,  3, 5,  5),
    ],
    3: [
        Mon("orc",         26,  5, 4,  7, 7, 10),
        Mon("gnoll",       22,  5, 3,  8, 6,  8),
        Mon("warg",        28,  5, 3,  9, 9,  8),
        Mon("ghoul",       22,  4, 3,  7, 7,  8),
        Mon("black_bear",  22,  4, 3,  8, 8,  7),
        Mon("orc_priest",  28,  5, 3,  7, 7,  9),
        Mon("yak",         30,  5, 4,  6,10,  8),
    ],
    4: [
        Mon("skeletal_warrior", 25, 4, 5, 6, 7,  8),
        Mon("phantom",     35,  6, 4, 12, 9, 13),
        Mon("gargoyle",    38,  5, 8,  5, 8, 11),
        Mon("basilisk",    40,  6, 5,  5, 9, 12),
        Mon("ogre",        52,  8, 5,  4,12, 25),
        Mon("cyclops",     65,  9, 5,  4,14, 18),
        Mon("two_headed_ogre", 55, 8, 4, 5,12, 15),
    ],
    5: [
        Mon("deep_troll",  55,  8, 5,  7,13, 16),
        Mon("ogre_mage",   55,  8, 3,  6,12, 18),
        Mon("wight",       42,  8, 3,  6, 9, 26),
        Mon("revenant",    50,  7, 5,  9,10, 15),
        Mon("red_devil",   52,  7, 6,  8,10, 16),
        Mon("wyvern",      60,  8, 6,  8,13, 18),
        Mon("troll",       65,  9, 3,  5,14, 30),
    ],
    6: [
        Mon("minotaur",    58, 10, 4,  7,12, 34),
        Mon("ice_devil",   65,  9, 7,  7,13, 21),
        Mon("swamp_dragon",65,  9, 6,  6,15, 19),
        Mon("iron_golem",  80, 10,14,  2,18, 24),
        Mon("mummy",       55,  9, 5,  3,11, 36),
        Mon("wraith",      45,  7, 4, 10,10, 16),
        Mon("vampire",     55,  8, 5,  8, 8, 17),
    ],
    7: [
        Mon("frost_giant", 80, 11, 6,  5,18, 24),
        Mon("fire_giant",  85, 11, 6,  5,19, 25),
        Mon("fire_dragon", 90, 11, 8,  5,20, 28),
        Mon("lich",        70, 10, 7,  8,12, 25),
        Mon("vampire_knight",75,10, 8,  8,15, 22),
        Mon("balrug",      80, 11, 7,  7,16, 25),
        Mon("stone_giant", 82, 11, 6,  4,18, 60),
    ],
    8: [
        Mon("ice_dragon",  100,12, 8,  5,20, 30),
        Mon("bone_dragon",  95,12, 9,  4,18, 28),
        Mon("ancient_lich",110,14,10,  8,18, 40),
        Mon("executioner", 100,13, 9,  9,20, 38),
        Mon("titan",       120,14, 9,  5,24, 45),
        Mon("golden_dragon",130,14,11,  6,25, 45),
    ],
}

# ── 아이템 드롭 풀 (존별) ─────────────────────────────────────────────────────
# (type, value) — weapon=(dmg,plus), armor=(ac), potion/bandage=(count)
ZONE_ITEM_POOL = {
    1: [("potion",0.25), ("bandage",0.15), ("weapon",4,0), ("weapon",6,0), ("armor",2), ("armor",3), ("junk",0)],
    2: [("potion",0.25), ("bandage",0.15), ("weapon",6,0), ("weapon",8,0), ("armor",3), ("armor",4), ("junk",0)],
    3: [("potion",0.20), ("bandage",0.15), ("weapon",8,0), ("weapon",10,0),("armor",4), ("armor",5), ("junk",0)],
    4: [("potion",0.20), ("bandage",0.15), ("weapon",8,1), ("weapon",10,1),("armor",5), ("armor",6), ("junk",0)],
    5: [("potion",0.20), ("bandage",0.15), ("weapon",10,1),("weapon",12,1),("armor",6), ("armor",8), ("junk",0)],
    6: [("potion",0.20), ("bandage",0.15), ("weapon",10,2),("weapon",12,2),("armor",8), ("armor",10),("junk",0)],
    7: [("potion",0.20), ("bandage",0.10), ("weapon",12,2),("weapon",14,2),("armor",10),("armor",12),("junk",0)],
    8: [("potion",0.20), ("bandage",0.10), ("weapon",12,3),("weapon",14,3),("armor",11),("armor",14),("junk",0)],
}

def roll_item_drops(zone: int, floor_count: int) -> dict:
    """층당 2~4개 드롭, 반환: {potions, bandages, best_weapon(dmg,plus), best_armor_ac}"""
    result = {"potions": 0, "bandages": 0, "weapon": None, "armor_ac": None}
    pool = ZONE_ITEM_POOL[zone]
    for _ in range(floor_count):
        n = random.randint(2, 4)
        for _ in range(n):
            item = random.choice(pool)
            t = item[0]
            if t == "potion":
                result["potions"] += 1
            elif t == "bandage":
                result["bandages"] += 1
            elif t == "weapon":
                dmg, plus = item[1], item[2]
                if result["weapon"] is None or (dmg + plus) > sum(result["weapon"]):
                    result["weapon"] = (dmg, plus)
            elif t == "armor":
                ac = item[1]
                if result["armor_ac"] is None or ac > result["armor_ac"]:
                    result["armor_ac"] = ac
    return result

# ── 플레이어 ──────────────────────────────────────────────────────────────────
@dataclass
class Player:
    # 기본 스탯
    hp_max: int = 22
    strength: int = 10
    dexterity: int = 8
    # 장비
    weapon_dmg: int = 6
    weapon_plus: int = 0
    weapon_cat: str = "blade"
    armor_ac: int = 2
    # 스킬
    skill_wpn: int = 0
    skill_fight: int = 0
    skill_wpn_xp: float = 0.0
    skill_fight_xp: float = 0.0
    # 레벨
    xl: int = 1
    xp: int = 0
    # 상태
    hp: int = 0
    injury: int = 0
    potions: int = 1
    bandages: int = 1
    regen_counter: int = 0
    # 로그
    log: List[str] = field(default_factory=list)

    def __post_init__(self):
        self.hp = self.hp_max

    @property
    def ac(self) -> int:
        return self.armor_ac

    @property
    def ev(self) -> int:
        return 1 + self.dexterity // 2

    @property
    def effective_max(self) -> int:
        return max(1, self.hp_max - self.injury)

    def tick_regen(self, turns: int = 1):
        """자동 회복: 4턴마다 HP +1 (종족 기본값)"""
        for _ in range(turns):
            self.regen_counter += 1
            if self.regen_counter >= 4:
                self.regen_counter = 0
                if self.hp < self.effective_max:
                    self.hp = min(self.effective_max, self.hp + 1)

    def use_potion(self):
        if self.potions <= 0:
            return False
        self.potions -= 1
        self.injury = 0
        gain = max(10, int(self.hp_max * 0.20))
        self.hp = min(self.hp_max, self.hp + gain)
        self.log.append(f"  💊 포션 사용 → injury=0, HP+{gain} ({self.hp}/{self.hp_max})")
        return True

    def use_bandage(self):
        if self.bandages <= 0 or self.injury == 0:
            return False
        self.bandages -= 1
        cleared = min(self.injury, 10)
        self.injury -= cleared
        gain = cleared // 2
        self.hp = min(self.effective_max, self.hp + gain)
        self.log.append(f"  🩹 붕대 사용 → injury-{cleared} ({self.injury}), HP+{gain} ({self.hp}/{self.effective_max})")
        return True

    def grant_xp(self, amount: int):
        self.xp += amount
        while self.xl < 27 and self.xp >= xp_to_next(self.xl):
            self.xp -= xp_to_next(self.xl)
            self.xl += 1
            gain = 3 + self.strength // 5
            self.hp_max += gain
            self.hp = min(self.hp_max, self.hp + gain)
            self.log.append(f"  ⭐ 레벨업 XL{self.xl}! HP_MAX+{gain} → {self.hp}/{self.hp_max}")

    def grant_skill_xp(self, cat: str, amount: float):
        if cat == "weapon":
            self.skill_wpn_xp += amount
            while self.skill_wpn < 20 and self.skill_wpn_xp >= SKILL_XP_DELTA[self.skill_wpn]:
                self.skill_wpn_xp -= SKILL_XP_DELTA[self.skill_wpn]
                self.skill_wpn += 1
                self.log.append(f"  📈 {self.weapon_cat} 스킬 → lv{self.skill_wpn}")
        elif cat == "fighting":
            self.skill_fight_xp += amount
            while self.skill_fight < 20 and self.skill_fight_xp >= SKILL_XP_DELTA[self.skill_fight]:
                self.skill_fight_xp -= SKILL_XP_DELTA[self.skill_fight]
                self.skill_fight += 1
                self.hp_max += 3
                self.hp = min(self.hp_max, self.hp + 3)
                self.log.append(f"  📈 fighting 스킬 → lv{self.skill_fight} (HP_MAX+3 → {self.hp_max})")

    def equip_item(self, drops: dict):
        if drops["weapon"]:
            dmg, plus = drops["weapon"]
            if dmg + plus > self.weapon_dmg + self.weapon_plus:
                old = f"d{self.weapon_dmg}+{self.weapon_plus}"
                self.weapon_dmg = dmg
                self.weapon_plus = plus
                self.log.append(f"  🗡 무기 업그레이드 {old} → d{dmg}+{plus}")
        if drops["armor_ac"] is not None:
            if drops["armor_ac"] > self.armor_ac:
                self.log.append(f"  🛡 방어구 업그레이드 AC{self.armor_ac} → AC{drops['armor_ac']}")
                self.armor_ac = drops["armor_ac"]
        self.potions += drops["potions"]
        self.bandages += drops["bandages"]
        if drops["potions"] > 0:
            self.log.append(f"  🧪 포션 +{drops['potions']} (총 {self.potions}개)")
        if drops["bandages"] > 0:
            self.log.append(f"  🩹 붕대 +{drops['bandages']} (총 {self.bandages}개)")

# ── 전투 공식 ─────────────────────────────────────────────────────────────────
def player_atk(p: Player, m: Mon) -> Tuple[int, bool]:
    """(데미지, 명중여부)"""
    to_hit_base = 15 + p.skill_wpn + p.weapon_plus
    if random.randint(0, to_hit_base) < m.ev:
        return 0, False
    raw = p.weapon_dmg + int(p.strength * 0.4) + random.randint(0, 3)
    dmg = int(raw * (1.0 + p.skill_wpn * 0.04))
    dmg += p.skill_fight // 2
    soak = random.randint(0, m.ac + 1)
    return max(0, dmg - soak), True

def monster_atk(m: Mon, p: Player) -> int:
    to_hit_base = 15 + m.hd
    if random.randint(0, to_hit_base) < p.ev:
        return 0
    dmg_lo = max(1, m.dmg * 3 // 5)
    dmg_hi = max(dmg_lo, m.dmg * 3 // 2)
    raw = random.randint(dmg_lo, dmg_hi) + m.hd // 2
    soak = random.randint(0, p.ac + 1)
    return max(0, raw - soak)

def fight(p: Player, m: Mon, verbose: bool = False) -> bool:
    m_hp = m.hp
    turn = 0
    if verbose:
        p.log.append(f"  ⚔ vs {m.name} (HP:{m.hp} AC:{m.ac} EV:{m.ev} dmg:{m.dmg})")
    for _ in range(200):
        turn += 1
        p.tick_regen(1)
        d, hit = player_atk(p, m)
        m_hp -= d
        p.grant_skill_xp("weapon", 1.0)
        p.grant_skill_xp("fighting", 0.5)
        if verbose and (d > 0 or not hit):
            p.log.append(f"    T{turn}: {'명중' if hit else '빗나감'} {d}dmg → {m.name} HP:{max(0,m_hp)}")
        if m_hp <= 0:
            p.grant_xp(m.xp)
            if verbose:
                p.log.append(f"    → {m.name} 처치! XP+{m.xp} (총 {p.xp}/{xp_to_next(p.xl)})")
            return True
        dmg = monster_atk(m, p)
        if dmg > 0:
            p.hp = max(0, p.hp - dmg)
            inj = (dmg + 1) // 2
            p.injury = min(p.hp_max - 1, p.injury + inj)
            if verbose:
                p.log.append(f"    T{turn}: {m.name}이 {dmg}dmg 반격 → HP:{p.hp}/{p.effective_max} inj:{p.injury}")
        if p.hp <= 0:
            if verbose:
                p.log.append(f"    💀 {m.name}에게 사망")
            return False
    return False

def decide_heal(p: Player):
    hp_ratio = p.hp / p.hp_max
    eff_ratio = p.hp / p.effective_max if p.effective_max > 0 else 1.0
    if hp_ratio < 0.30 and p.potions > 0:
        p.use_potion()
    elif p.injury >= 10 and eff_ratio < 0.70 and p.bandages > 0:
        p.use_bandage()
    elif p.injury >= 6 and p.bandages > 0 and p.potions == 0:
        p.use_bandage()

# ── 존 시뮬레이션 ─────────────────────────────────────────────────────────────
FLOORS_PER_ZONE = {z: (4 if z == 8 else 3) for z in range(1, 9)}
REGEN_TICKS_BETWEEN_FLOORS = 12  # 층 이동 시 자동회복

def sim_zone(p: Player, zone: int, verbose: bool = False) -> bool:
    """플레이어 상태 in-place 업데이트. True=클리어."""
    pool = ZONE_MONSTERS[zone]
    floors = FLOORS_PER_ZONE[zone]
    if verbose:
        p.log.append(f"\n{'='*52}")
        p.log.append(f"  존{zone} 진입 | XL{p.xl} HP:{p.hp}/{p.effective_max}(max{p.hp_max}) "
                     f"injury:{p.injury} | wpn:d{p.weapon_dmg}+{p.weapon_plus} "
                     f"AC:{p.ac} EV:{p.ev} | 포션:{p.potions} 붕대:{p.bandages}")

    for fl in range(1, floors + 1):
        if verbose:
            p.log.append(f"\n--- 존{zone} 층{fl} ---")
        enc = random.randint(3, 5)
        for _ in range(enc):
            m = random.choice(pool)
            if not fight(p, m, verbose=verbose):
                return False
            decide_heal(p)
        # 층 이동: 아이템 드롭 + 자동회복
        drops = roll_item_drops(zone, 1)
        p.equip_item(drops)
        p.tick_regen(REGEN_TICKS_BETWEEN_FLOORS)

    if verbose:
        p.log.append(f"\n  ✅ 존{zone} 클리어! | XL{p.xl} HP:{p.hp}/{p.effective_max}(max{p.hp_max}) "
                     f"inj:{p.injury} 포션:{p.potions} 붕대:{p.bandages}")
    return True

def make_fresh_player() -> Player:
    return Player(
        hp_max=22, strength=10, dexterity=8,
        weapon_dmg=6, weapon_plus=0, weapon_cat="blade",
        armor_ac=2,
        skill_wpn=0, skill_fight=0,
        xl=1, xp=0,
        potions=1, bandages=1,
    )

# ── 존별 클리어율 ─────────────────────────────────────────────────────────────
TARGET = {1: 90, 2: 80, 3: 70, 4: 60, 5: 50, 6: 40, 7: 30, 8: 20}
DEPTH_RANGE = {1:"d1-3", 2:"d4-6", 3:"d7-9", 4:"d10-12",
               5:"d13-15", 6:"d16-18", 7:"d19-22", 8:"d23-25"}

def run_zone_stats(n: int = 4000):
    """각 존을 독립적으로 N회 시뮬 — 존 진입 시점 평균 스탯 추정."""
    print(f"\n{'='*72}")
    print(f"  PocketCrawl 존별 클리어율  (N={n:,}/존, Fighter, 레벨업/스킬/아이템 반영)")
    print(f"{'='*72}")
    print(f"  {'존':<4} {'범위':<9} {'목표':>6} {'실제':>6} {'평균XL':>7} {'평균HPmax':>10}  판정")
    print(f"  {'-'*68}")

    actuals = []
    for z in range(1, 9):
        wins, xls, hpmaxs = 0, [], []
        for _ in range(n):
            # 이전 존들을 평균적으로 통과한 플레이어를 근사:
            # 존1은 fresh, 존2는 존1 통과 후 상태, etc.
            # 간단히: fresh 플레이어가 이전 존들을 연속 시뮬
            p = make_fresh_player()
            alive = True
            for prev_z in range(1, z):
                if not sim_zone(p, prev_z, verbose=False):
                    alive = False
                    break
            if not alive:
                continue  # 이전 존에서 죽은 경우 스킵 (생존 조건부)
            survived = sim_zone(p, z, verbose=False)
            if survived:
                wins += 1
            xls.append(p.xl)
            hpmaxs.append(p.hp_max)

        total = n  # 분모는 전체 시도 수
        wr = wins / max(1, len(xls) + (n - len(xls) - wins)) * 100  # 간략화
        # 실제로는 이전 존 생존자 중 현재 존 클리어율
        survivors = len(xls)
        wr = (wins / survivors * 100) if survivors > 0 else 0
        avg_xl = statistics.mean(xls) if xls else 0
        avg_hp = statistics.mean(hpmaxs) if hpmaxs else 0
        tgt = TARGET[z]
        diff = wr - tgt
        if abs(diff) <= 5:   verdict = "✅ OK"
        elif diff > 5:        verdict = f"⬆ +{diff:.0f}% (너무 쉬움)"
        else:                 verdict = f"⬇ {diff:.0f}% (너무 어려움)"
        actuals.append(wr)
        print(f"  존{z}  {DEPTH_RANGE[z]:<9} {tgt:>5}%  {wr:>5.1f}%  "
              f"XL{avg_xl:>4.1f}  HP{avg_hp:>6.1f}  {verdict}")

    overall = math.prod(a / 100 for a in actuals)
    print(f"\n  전체 런 클리어율(이론): {overall*100:.3f}%")
    print(f"  = {' × '.join(f'{a:.0f}%' for a in actuals)}\n")

# ── 플레이 로그: 풀런 1회 ─────────────────────────────────────────────────────
def run_play_log(seed: int = 99):
    random.seed(seed)
    p = make_fresh_player()
    print(f"\n{'='*60}")
    print(f"  PLAY LOG — seed={seed}  (Fighter, 모든 존 연속)")
    print(f"{'='*60}")
    for z in range(1, 9):
        survived = sim_zone(p, z, verbose=True)
        for line in p.log:
            print(line)
        p.log.clear()
        if not survived:
            print(f"\n  💀 존{z}에서 사망 — 런 종료")
            return
    print(f"\n  🏆 풀런 클리어!")

if __name__ == "__main__":
    random.seed(42)
    run_zone_stats(n=4000)
    run_play_log(seed=77)
