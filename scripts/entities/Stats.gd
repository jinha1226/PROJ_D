class_name Stats
extends Resource

@export var STR: int = 10
@export var DEX: int = 10
@export var INT: int = 10
@export var HP: int = 20
@export var MP: int = 10
@export var AC: int = 0
@export var EV: int = 0
@export var hp_max: int = 20
@export var mp_max: int = 10
## DCSS Willpower (MR). Each 40 points = one pip (★). Formicid = 270 (immune).
## Hex spells check random(0, hd*5) < WL to resist.
@export var WL: int = 40


func get_attack() -> int:
	return STR / 2


func clone() -> Stats:
	var s := Stats.new()
	s.STR = STR
	s.DEX = DEX
	s.INT = INT
	s.HP = HP
	s.MP = MP
	s.AC = AC
	s.EV = EV
	s.hp_max = hp_max
	s.mp_max = mp_max
	s.WL = WL
	return s
