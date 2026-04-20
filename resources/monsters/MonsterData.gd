class_name MonsterData
extends Resource
## Runtime monster definition. Existing .tres assets use the hand-tuned fields
## (id, display_name, hp, str, dex, ac, ev, …); the DCSS-sourced entries built
## by `MonsterRegistry.get(id)` fill the same fields from crawl-ref/dat/mons
## data plus the extended glyph/speed/flags metadata the AI systems read.

# --- Identity (used by .tres assets and MonsterRegistry alike) --------------
@export var id: String
@export var display_name: String
@export var tier: int = 1
@export var sprite: Texture2D
@export var is_boss: bool = false
@export var essence_drop_id: String = ""
@export var xp_value: int = 10

# --- Combat stats ----------------------------------------------------------
@export var hp: int = 10
@export var str: int = 5
@export var dex: int = 5
@export var ac: int = 0
@export var ev: int = 0
@export var sight_range: int = 6

# --- DCSS extended fields (populated by MonsterRegistry from monsters.json) -
## DCSS Hit Dice — the base stat that drives combat rolls, XP, and
## resistance levels in DCSS. Our hp/ac/str derivations can read from this
## when a .tres override hasn't been provided.
@export var hd: int = 1
## DCSS stores HP as hp × 10 (for integer-only average rolls). We preserve
## the raw value so level-scaling / variance code can compute hp bands.
@export var hp_10x: int = 10
## Movement speed in DCSS units: 10 = normal, 20 = half-pace, 5 = fast.
@export var speed: int = 10
## Willpower (magic resistance). 0 = none, 200 = MR_NO_FLAGS → immune.
@export var will: int = 0
## XP award formula input — DCSS pre-multiplies before scaling.
@export var exp_mod: int = 1

# --- Flavour + AI hints ----------------------------------------------------
## Single-letter ASCII glyph (`o`, `K`, `D` …) for the ASCII renderer.
@export var glyph_char: String = "?"
## DCSS colour name — TileRenderer translates to Godot Color.
@export var glyph_color: String = "white"
## "animal", "human", "plant", "brainless", "stupid". Drives AI state machine.
@export var intelligence: String = "animal"
## "little", "small", "medium", "large", "giant". Affects hit chance etc.
@export var size: String = "medium"
## "humanoid", "quadruped", "snake", "bird", "insect", "misc" …
@export var shape: String = "humanoid"
## "land", "amphibious", "lava", "flying" — drives terrain movement.
@export var habitat: String = "land"
## Sound event string: "shout", "hiss", "roar", "silent" etc.
@export var shout: String = "silent"
## Behavioural flags from DCSS (e.g. `speaks`, `warm_blood`, `fast_regen`).
@export var flags: Array[String] = []
## Raw attack records: each is `{type, damage, flavour?}`. CombatSystem reads
## damage and flavour so elemental/poison attacks apply.
@export var attacks: Array = []
## Resistance records from DCSS (`fire`, `cold`, `poison` …).
@export var resists: Array[String] = []
