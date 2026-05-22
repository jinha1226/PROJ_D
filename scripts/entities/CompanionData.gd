class_name CompanionData

## Persistent record for a companion. Serialised to/from Dictionary for save/load.
## In-dungeon runtime state lives on Companion nodes; this holds the between-run record.

const LONG_TERM_THRESHOLD: int = 3

var id: String = ""
var display_name: String = ""
var race_id: String = "human"
var job_id: String = "fighter"
var loyalty_runs: int = 0
var is_long_term: bool = false
var is_dead: bool = false  # permanent death flag

# Core stats
var hp_max: int = 12
var mp_max: int = 0
var strength: int = 10
var dexterity: int = 8
var intelligence: int = 8
var xl: int = 1
var xp: int = 0
var ac: int = 0
var ev: int = 5

# Equipment
var equipped_weapon_id: String = ""
var equipped_armor_id: String = ""
var equipped_shield_id: String = ""
var equipped_helmet_id: String = ""
var equipped_gloves_id: String = ""
var equipped_boots_id: String = ""
var equipped_ring_id: String = ""
var equipped_amulet_id: String = ""

# Inventory & skills (shallow for now — companions level later)
var items: Array = []
var skills: Dictionary = {}
var speed: int = 10  # same speed tier as player; used by TurnManager energy loop


func to_dict() -> Dictionary:
	return {
		"id": id,
		"display_name": display_name,
		"race_id": race_id,
		"job_id": job_id,
		"loyalty_runs": loyalty_runs,
		"is_long_term": is_long_term,
		"is_dead": is_dead,
		"hp_max": hp_max,
		"mp_max": mp_max,
		"strength": strength,
		"dexterity": dexterity,
		"intelligence": intelligence,
		"xl": xl,
		"xp": xp,
		"ac": ac,
		"ev": ev,
		"equipped_weapon_id": equipped_weapon_id,
		"equipped_armor_id": equipped_armor_id,
		"equipped_shield_id": equipped_shield_id,
		"equipped_helmet_id": equipped_helmet_id,
		"equipped_gloves_id": equipped_gloves_id,
		"equipped_boots_id": equipped_boots_id,
		"equipped_ring_id": equipped_ring_id,
		"equipped_amulet_id": equipped_amulet_id,
		"items": items.duplicate(true),
		"skills": skills.duplicate(true),
	}


static func from_dict(d: Dictionary) -> CompanionData:
	var c := CompanionData.new()
	c.id = str(d.get("id", ""))
	c.display_name = str(d.get("display_name", ""))
	c.race_id = str(d.get("race_id", "human"))
	c.job_id = str(d.get("job_id", "fighter"))
	c.loyalty_runs = int(d.get("loyalty_runs", 0))
	c.is_long_term = bool(d.get("is_long_term", false))
	c.is_dead = bool(d.get("is_dead", false))
	c.hp_max = int(d.get("hp_max", 12))
	c.mp_max = int(d.get("mp_max", 0))
	c.strength = int(d.get("strength", 10))
	c.dexterity = int(d.get("dexterity", 8))
	c.intelligence = int(d.get("intelligence", 8))
	c.xl = int(d.get("xl", 1))
	c.xp = int(d.get("xp", 0))
	c.ac = int(d.get("ac", 0))
	c.ev = int(d.get("ev", 5))
	c.equipped_weapon_id = str(d.get("equipped_weapon_id", ""))
	c.equipped_armor_id = str(d.get("equipped_armor_id", ""))
	c.equipped_shield_id = str(d.get("equipped_shield_id", ""))
	c.equipped_helmet_id = str(d.get("equipped_helmet_id", ""))
	c.equipped_gloves_id = str(d.get("equipped_gloves_id", ""))
	c.equipped_boots_id = str(d.get("equipped_boots_id", ""))
	c.equipped_ring_id = str(d.get("equipped_ring_id", ""))
	c.equipped_amulet_id = str(d.get("equipped_amulet_id", ""))
	c.items = (d.get("items", []) as Array).duplicate(true)
	c.skills = (d.get("skills", {}) as Dictionary).duplicate(true)
	return c


## Predefined companion pool used by town hiring and dungeon encounters.
static func generate(depth: int, rng: RandomNumberGenerator = null) -> CompanionData:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var c := CompanionData.new()
	c.id = "companion_" + str(rng.randi())
	var name_pool: Array = [
		"Kael", "Lyra", "Torvin", "Asha", "Durn",
		"Sylva", "Gram", "Nissa", "Brek", "Valis",
		"Orin", "Thea", "Skeld", "Mira", "Jorvald",
	]
	c.display_name = name_pool[rng.randi() % name_pool.size()]
	var race_pool: Array = ["human", "elf", "dwarf", "hill_orc"]
	c.race_id = race_pool[rng.randi() % race_pool.size()]
	var job_pool: Array = ["fighter", "ranger", "mage"]
	c.job_id = job_pool[rng.randi() % job_pool.size()]
	var scale: int = max(1, depth)
	c.hp_max = 10 + rng.randi_range(0, 4) + scale * 2
	c.strength = 8 + rng.randi_range(0, 4)
	c.dexterity = 8 + rng.randi_range(0, 4)
	c.intelligence = 8 + rng.randi_range(0, 4)
	c.xl = max(1, scale)
	match c.job_id:
		"fighter":
			c.strength += 2
			c.equipped_weapon_id = "long_sword" if depth >= 3 else "short_sword"
			c.equipped_armor_id = "leather_armour"
			c.ac = 3
		"ranger":
			c.dexterity += 2
			c.equipped_weapon_id = "short_bow"
			c.ev = 7
		"mage":
			c.intelligence += 2
			c.mp_max = 8 + rng.randi_range(0, 4)
	return c
