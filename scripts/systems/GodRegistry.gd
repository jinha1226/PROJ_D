class_name GodRegistry
extends RefCounted
## DCSS god roster — full 22-god port. Each god entry:
##   name, title       — display strings
##   color             — altar/log tint
##   piety_cap         — 200 (DCSS "*******")
##   kill_piety        — base piety gain per monster kill
##   conducts          — strings the engine can check via `has_conduct`
##   invocations       — list of invocation ids
##
## Gods vary wildly in how DCSS handles them — some grant passives, some
## require specific victim types, some are evil/good-aligned. This port
## ships the *core interactions* (kill-piety, one-or-two invocations,
## a couple conducts) and leaves the long tail (recruit-priests-as-allies,
## banish-to-Abyss, etc.) for later passes.

const GODS: Dictionary = {
	# -------- Warrior / "murder = piety" axis --------
	"trog": {
		"name": "Trog", "title": "Trog the Wrathful",
		"color": Color(0.90, 0.25, 0.15), "piety_cap": 200, "kill_piety": 3,
		"conducts": ["spells"],
		"desc": "Hate casters, love murder. Berserker fist-god.",
		"invocations": ["berserk", "trog_hand", "brothers_in_arms"],
	},
	"okawaru": {
		"name": "Okawaru", "title": "Okawaru",
		"color": Color(0.85, 0.70, 0.25), "piety_cap": 200, "kill_piety": 2,
		"desc": "Champion of tactical warriors. Gifts weapons and armour.",
		"invocations": ["heroism", "finesse", "duel"],
	},
	"makhleb": {
		"name": "Makhleb", "title": "Makhleb the Destroyer",
		"color": Color(0.75, 0.15, 0.25), "piety_cap": 200, "kill_piety": 2,
		"desc": "Demon prince of destruction. Raw firepower for a price.",
		"invocations": ["minor_destruction", "major_destruction", "summon_demon"],
	},
	"uskayaw": {
		"name": "Uskayaw", "title": "the Reveller",
		"color": Color(0.95, 0.35, 0.85), "piety_cap": 200, "kill_piety": 3,
		"desc": "The dance floor is the battlefield. Kill in rhythm.",
		"invocations": ["stomp", "line_pass"],
	},

	# -------- Lawful / holy axis --------
	"zin": {
		"name": "Zin", "title": "Zin",
		"color": Color(1.00, 0.95, 0.80), "piety_cap": 200, "kill_piety": 1,
		"conducts": ["mutation", "chaos"],
		"desc": "Law and purity. Heals the faithful, abhors chaos.",
		"invocations": ["vitalisation", "imprison", "sanctuary"],
	},
	"the_shining_one": {
		"name": "The Shining One", "title": "the Shining One",
		"color": Color(1.00, 1.00, 0.65), "piety_cap": 200, "kill_piety": 2,
		"conducts": ["evil"],
		"desc": "Light of retribution. Smites evil without mercy.",
		"invocations": ["divine_shield", "cleansing_flame", "summon_angel"],
	},
	"elyvilon": {
		"name": "Elyvilon", "title": "Elyvilon the Healer",
		"color": Color(0.85, 1.00, 0.85), "piety_cap": 200, "kill_piety": 1,
		"conducts": ["kill_noncombatants"],
		"desc": "Mercy and healing. Pacifism over combat.",
		"invocations": ["lesser_healing", "greater_healing", "pacify"],
	},

	# -------- Mage / caster axis --------
	"vehumet": {
		"name": "Vehumet", "title": "Vehumet",
		"color": Color(0.55, 0.15, 0.85), "piety_cap": 200, "kill_piety": 2,
		"desc": "Patron of destructive conjurers. Enhances raw spellpower.",
		"invocations": ["gift_spell"],
	},
	"sif_muna": {
		"name": "Sif Muna", "title": "Sif Muna the Loreweaver",
		"color": Color(0.55, 0.70, 0.95), "piety_cap": 200, "kill_piety": 1,
		"desc": "Patron of arcane lore. Channels mana and grants books.",
		"invocations": ["channel_mana", "divine_exegesis", "forget_spell"],
	},
	"kikubaaqudgha": {
		"name": "Kikubaaqudgha", "title": "Kikubaaqudgha",
		"color": Color(0.45, 0.10, 0.55), "piety_cap": 200, "kill_piety": 2,
		"conducts": ["holy"],
		"desc": "Lord of necromancy. Raises the dead as fodder.",
		"invocations": ["receive_corpses", "torment", "unearthly_bond"],
	},
	"nemelex_xobeh": {
		"name": "Nemelex Xobeh", "title": "Nemelex the Gambler",
		"color": Color(0.95, 0.55, 0.95), "piety_cap": 200, "kill_piety": 2,
		"desc": "Chaos dealer. Every cast of a card is a fresh roll.",
		"invocations": ["draw_card", "stack_five"],
	},

	# -------- Extended / weird gods --------
	"xom": {
		"name": "Xom", "title": "Xom the Chaos God",
		"color": Color(0.85, 0.25, 0.95), "piety_cap": 200, "kill_piety": 0,
		"desc": "Chaos incarnate. Amuses himself by occasionally helping you.",
		"invocations": [],  # no invocations; random effects instead
	},
	"yredelemnul": {
		"name": "Yredelemnul", "title": "Yredelemnul the Dark",
		"color": Color(0.35, 0.10, 0.35), "piety_cap": 200, "kill_piety": 2,
		"conducts": ["holy"],
		"desc": "Dark god of death. Raises undead slaves.",
		"invocations": ["animate_dead", "drain_life", "enslave_soul"],
	},
	"beogh": {
		"name": "Beogh", "title": "Beogh",
		"color": Color(0.55, 0.35, 0.15), "piety_cap": 200, "kill_piety": 2,
		"desc": "Orc god. Hill-orcs only. Converts fellow orcs to followers.",
		"invocations": ["recall_followers", "smite"],
	},
	"jiyva": {
		"name": "Jiyva", "title": "Jiyva the Shapeless",
		"color": Color(0.55, 0.85, 0.35), "piety_cap": 200, "kill_piety": 2,
		"desc": "Slime god. Merges with jellies, mutates the faithful.",
		"invocations": ["jelly_prayer", "cure_bad_mutation", "slimify"],
	},
	"fedhas": {
		"name": "Fedhas Madash", "title": "Fedhas Madash",
		"color": Color(0.35, 0.80, 0.35), "piety_cap": 200, "kill_piety": 1,
		"desc": "The plant god. Grows obstacles and allies from soil.",
		"invocations": ["sunlight", "plant_ring", "rain"],
	},
	"cheibriados": {
		"name": "Cheibriados", "title": "Cheibriados",
		"color": Color(0.65, 0.55, 0.95), "piety_cap": 200, "kill_piety": 2,
		"conducts": ["haste"],
		"desc": "The slow god. Demands deliberation, rewards temporal mastery.",
		"invocations": ["bend_time", "temporal_distortion", "slouch"],
	},
	"lugonu": {
		"name": "Lugonu", "title": "Lugonu the Unformed",
		"color": Color(0.35, 0.15, 0.65), "piety_cap": 200, "kill_piety": 2,
		"conducts": ["holy"],
		"desc": "Goddess of the Abyss. Warp space, banish enemies.",
		"invocations": ["bend_space", "banishment", "corrupt_level"],
	},
	"ashenzari": {
		"name": "Ashenzari", "title": "Ashenzari the Shackled",
		"color": Color(0.75, 0.65, 0.25), "piety_cap": 200, "kill_piety": 1,
		"desc": "Bound god of divination. Boosts skills in exchange for curses.",
		"invocations": ["scry", "transfer_knowledge"],
	},
	"dithmenos": {
		"name": "Dithmenos", "title": "Dithmenos",
		"color": Color(0.15, 0.15, 0.25), "piety_cap": 200, "kill_piety": 2,
		"desc": "Shadow god. Stealth-forward, dimness and shadow allies.",
		"invocations": ["shadow_step", "shadow_form", "summon_shadow"],
	},
	"gozag": {
		"name": "Gozag", "title": "Gozag Ym Sagoz",
		"color": Color(1.00, 0.90, 0.25), "piety_cap": 200, "kill_piety": 0,
		"desc": "Gold god. No piety — spend gold to bribe the dungeon.",
		"invocations": ["potion_petition", "call_merchant", "bribe_branch"],
	},
	"qazlal": {
		"name": "Qazlal", "title": "Qazlal the Storm",
		"color": Color(0.85, 0.70, 0.30), "piety_cap": 200, "kill_piety": 2,
		"desc": "Elemental storm god. Clouds, strikes, upheaval.",
		"invocations": ["upheaval", "elemental_force", "disaster_area"],
	},
	"ru": {
		"name": "Ru", "title": "Ru the Awoken",
		"color": Color(0.65, 0.25, 0.35), "piety_cap": 200, "kill_piety": 0,
		"desc": "Meditative god. Demands sacrifice, answers with mighty bursts.",
		"invocations": ["sacrifice", "draw_out_power", "power_leap", "apocalypse"],
	},
	"wu_jian": {
		"name": "Wu Jian Council", "title": "the Wu Jian Council",
		"color": Color(1.00, 0.35, 0.15), "piety_cap": 200, "kill_piety": 2,
		"desc": "Martial arts masters. Rewards movement-based combat.",
		"invocations": ["wall_jump", "heavenly_storm"],
	},
	"hepliaklqana": {
		"name": "Hepliaklqana", "title": "Hepliaklqana",
		"color": Color(0.55, 0.85, 0.85), "piety_cap": 200, "kill_piety": 2,
		"desc": "Ancestral god. Summons a persistent ancestor companion.",
		"invocations": ["recall_ancestor", "idealise", "transference"],
	},
	"ignis": {
		"name": "Ignis", "title": "Ignis the Last",
		"color": Color(1.00, 0.55, 0.15), "piety_cap": 50, "kill_piety": 3,
		"desc": "Dying fire god. Three invocations, then gone forever.",
		"invocations": ["fiery_armour", "foxfire_swarm", "rising_flame"],
	},
}


## Per-invocation defs. The catalog is large (~60 entries) so the effect
## dispatch in GameBootstrap._invoke match-statement branches on the
## `effect` key. `cost` is piety spent; `min_piety` is the threshold at
## which the god unlocks the ability.
const INVOCATIONS: Dictionary = {
	# Trog
	"berserk":         {"name": "Berserk",            "cost": 25, "min_piety": 30,  "effect": "berserk",        "desc": "Rage: +damage, +HP, +haste."},
	"trog_hand":       {"name": "Hand of Trog",       "cost": 40, "min_piety": 50,  "effect": "trog_hand",      "desc": "Summon a berserker ally."},
	"brothers_in_arms":{"name": "Brothers in Arms",   "cost": 75, "min_piety": 120, "effect": "brothers",       "desc": "Summon 3 deep trolls."},
	# Okawaru
	"heroism":         {"name": "Heroism",            "cost": 15, "min_piety": 20,  "effect": "heroism",        "desc": "Temporary +5 combat skills."},
	"finesse":         {"name": "Finesse",            "cost": 35, "min_piety": 60,  "effect": "finesse",        "desc": "Strike twice / turn for 10."},
	"duel":            {"name": "Duel",               "cost": 50, "min_piety": 100, "effect": "duel",           "desc": "Pull a foe into a private arena."},
	# Makhleb
	"minor_destruction":{"name": "Minor Destruction", "cost": 10, "min_piety": 15,  "effect": "minor_destruction", "desc": "Random low-level blast at a foe."},
	"major_destruction":{"name": "Major Destruction", "cost": 30, "min_piety": 75,  "effect": "major_destruction", "desc": "Bigger random blast."},
	"summon_demon":    {"name": "Summon Demon",       "cost": 50, "min_piety": 120, "effect": "summon_demon",   "desc": "Summon a hostile ally demon."},
	# Uskayaw
	"stomp":           {"name": "Stomp",              "cost": 20, "min_piety": 30,  "effect": "stomp",          "desc": "Stomp the floor; all nearby foes take impact dmg."},
	"line_pass":       {"name": "Line Pass",          "cost": 30, "min_piety": 60,  "effect": "line_pass",      "desc": "Dash through a line, hitting every foe."},
	# Zin
	"vitalisation":    {"name": "Vitalisation",       "cost": 20, "min_piety": 25,  "effect": "vitalisation",   "desc": "Heal 40 HP, restore 20 MP."},
	"imprison":        {"name": "Imprison",           "cost": 60, "min_piety": 80,  "effect": "imprison",       "desc": "Lock a visible foe for 10 turns."},
	"sanctuary":       {"name": "Sanctuary",          "cost": 75, "min_piety": 120, "effect": "sanctuary",      "desc": "Monsters cannot attack you for 12 turns."},
	# TSO
	"divine_shield":   {"name": "Divine Shield",      "cost": 20, "min_piety": 30,  "effect": "divine_shield",  "desc": "+6 AC for 15 turns."},
	"cleansing_flame": {"name": "Cleansing Flame",    "cost": 40, "min_piety": 80,  "effect": "cleansing_flame","desc": "Holy flame hits every visible foe."},
	"summon_angel":    {"name": "Summon Angel",       "cost": 75, "min_piety": 140, "effect": "summon_angel",   "desc": "Summon an angelic ally."},
	# Elyvilon
	"lesser_healing":  {"name": "Lesser Healing",     "cost": 10, "min_piety": 15,  "effect": "lesser_healing", "desc": "Heal 15 HP."},
	"greater_healing": {"name": "Greater Healing",    "cost": 25, "min_piety": 60,  "effect": "greater_healing","desc": "Heal 40 HP."},
	"pacify":          {"name": "Pacify",             "cost": 30, "min_piety": 80,  "effect": "pacify",         "desc": "Turn a foe peaceful (fear)."},
	# Vehumet
	"gift_spell":      {"name": "Gift Spell",         "cost": 0,  "min_piety": 40,  "effect": "gift_spell",     "desc": "Vehumet grants you a new spell (automatic)."},
	# Sif Muna
	"channel_mana":    {"name": "Channel Mana",       "cost": 0,  "min_piety": 25,  "effect": "channel_mana",   "desc": "Restore 15 MP."},
	"divine_exegesis": {"name": "Divine Exegesis",    "cost": 35, "min_piety": 80,  "effect": "divine_exegesis","desc": "Cast any known spell at +power."},
	"forget_spell":    {"name": "Forget Spell",       "cost": 0,  "min_piety": 10,  "effect": "amnesia",        "desc": "Forget one of your spells."},
	# Kikubaaqudgha
	"receive_corpses": {"name": "Receive Corpses",    "cost": 10, "min_piety": 20,  "effect": "receive_corpses","desc": "Summon 3 zombies from corpses."},
	"torment":         {"name": "Torment",            "cost": 30, "min_piety": 80,  "effect": "god_torment",    "desc": "Halves every non-undead's HP."},
	"unearthly_bond":  {"name": "Unearthly Bond",     "cost": 50, "min_piety": 120, "effect": "unearthly_bond", "desc": "All summoned allies persist until depth change."},
	# Nemelex
	"draw_card":       {"name": "Draw Card",          "cost": 0,  "min_piety": 10,  "effect": "draw_card",      "desc": "Draw and fire a random Nemelex card."},
	"stack_five":      {"name": "Stack Five",         "cost": 40, "min_piety": 80,  "effect": "stack_five",     "desc": "Draw five cards and choose one."},
	# Yredelemnul
	"animate_dead":    {"name": "Animate Dead",       "cost": 15, "min_piety": 30,  "effect": "yred_animate",   "desc": "Raise 2 zombies nearby."},
	"drain_life":      {"name": "Drain Life",         "cost": 30, "min_piety": 80,  "effect": "drain_life",     "desc": "Drain every visible living thing, heal you."},
	"enslave_soul":    {"name": "Enslave Soul",       "cost": 50, "min_piety": 120, "effect": "enslave_soul",   "desc": "When the target dies, they serve you."},
	# Beogh
	"recall_followers":{"name": "Recall Followers",   "cost": 20, "min_piety": 30,  "effect": "recall_followers","desc": "Pull all your orc allies to your side."},
	"smite":           {"name": "Smite",              "cost": 25, "min_piety": 60,  "effect": "smite",          "desc": "Smite a single visible foe."},
	# Jiyva
	"jelly_prayer":    {"name": "Jelly Prayer",       "cost": 10, "min_piety": 25,  "effect": "jelly_prayer",   "desc": "Jellies nearby dissolve items into piety."},
	"cure_bad_mutation":{"name": "Cure Bad Mutation", "cost": 15, "min_piety": 40,  "effect": "cure_bad_mutation","desc": "Remove one bad mutation."},
	"slimify":         {"name": "Slimify",            "cost": 50, "min_piety": 100, "effect": "slimify",        "desc": "Your weapon slimes every target it hits."},
	# Fedhas
	"sunlight":        {"name": "Sunlight",           "cost": 10, "min_piety": 20,  "effect": "sunlight",       "desc": "Bathe an area in sunlight (reveals + damages dark)."},
	"plant_ring":      {"name": "Plant Ring",         "cost": 20, "min_piety": 50,  "effect": "plant_ring",     "desc": "Grow plants around you as cover."},
	"rain":            {"name": "Rain",               "cost": 35, "min_piety": 100, "effect": "rain",           "desc": "Floods a large area."},
	# Cheibriados
	"bend_time":       {"name": "Bend Time",          "cost": 15, "min_piety": 25,  "effect": "bend_time",      "desc": "Slow every visible enemy."},
	"temporal_distortion":{"name": "Temporal Distortion","cost": 30,"min_piety": 75,"effect": "temporal_distortion","desc": "Randomly haste/slow everything."},
	"slouch":          {"name": "Slouch",             "cost": 45, "min_piety": 120, "effect": "slouch",         "desc": "Hits every foe faster than you harder."},
	# Lugonu
	"bend_space":      {"name": "Bend Space",         "cost": 15, "min_piety": 20,  "effect": "bend_space",     "desc": "Swap positions with or banish a foe one tile."},
	"banishment":      {"name": "Banishment",         "cost": 35, "min_piety": 80,  "effect": "banishment",     "desc": "Banish a visible foe from the floor."},
	"corrupt_level":   {"name": "Corrupt Level",      "cost": 70, "min_piety": 130, "effect": "corrupt_level",  "desc": "Twist the current level into an Abyss-like zone."},
	# Ashenzari
	"scry":            {"name": "Scry",               "cost": 0,  "min_piety": 20,  "effect": "scry",           "desc": "Reveal the whole floor."},
	"transfer_knowledge":{"name": "Transfer Knowledge","cost": 0, "min_piety": 40,  "effect": "transfer_knowledge","desc": "Shift skill XP between two of your skills."},
	# Dithmenos
	"shadow_step":     {"name": "Shadow Step",        "cost": 15, "min_piety": 30,  "effect": "shadow_step",    "desc": "Teleport next to a visible foe from shadow."},
	"shadow_form":     {"name": "Shadow Form",        "cost": 35, "min_piety": 80,  "effect": "shadow_form",    "desc": "Become a shadow for 20 turns (half damage taken)."},
	"summon_shadow":   {"name": "Summon Shadow",      "cost": 50, "min_piety": 110, "effect": "summon_shadow",  "desc": "Summon a shadow ally."},
	# Gozag
	"potion_petition": {"name": "Potion Petition",    "cost": 0,  "min_piety": 0,   "effect": "potion_petition","desc": "Pay 50 gold for 3 random potions."},
	"call_merchant":   {"name": "Call Merchant",      "cost": 0,  "min_piety": 0,   "effect": "call_merchant",  "desc": "Summon a shopkeeper on the floor (costs 100 gold)."},
	"bribe_branch":    {"name": "Bribe Branch",       "cost": 0,  "min_piety": 0,   "effect": "bribe_branch",   "desc": "Monsters in this branch become peaceful (costs 250 gold)."},
	# Qazlal
	"upheaval":        {"name": "Upheaval",           "cost": 20, "min_piety": 30,  "effect": "upheaval",       "desc": "Elemental burst at a single target."},
	"elemental_force": {"name": "Elemental Force",    "cost": 35, "min_piety": 80,  "effect": "elemental_force","desc": "Nearby clouds become ally elementals."},
	"disaster_area":   {"name": "Disaster Area",      "cost": 65, "min_piety": 140, "effect": "disaster_area",  "desc": "The whole floor shakes — huge damage everywhere."},
	# Ru
	"draw_out_power":  {"name": "Draw Out Power",     "cost": 0,  "min_piety": 30,  "effect": "draw_out_power", "desc": "Fully refreshed HP/MP — huge but once per day."},
	"power_leap":      {"name": "Power Leap",         "cost": 0,  "min_piety": 40,  "effect": "power_leap",     "desc": "Leap to a visible tile, shockwave on landing."},
	"apocalypse":      {"name": "Apocalypse",         "cost": 0,  "min_piety": 80,  "effect": "apocalypse",     "desc": "Apocalypse! Heavy damage to everything in LOS."},
	# Wu Jian
	"wall_jump":       {"name": "Wall Jump",          "cost": 0,  "min_piety": 0,   "effect": "wall_jump",      "desc": "Pivot off an adjacent wall, hit all nearby foes."},
	"heavenly_storm":  {"name": "Heavenly Storm",     "cost": 40, "min_piety": 90,  "effect": "heavenly_storm", "desc": "Attacks deal splash damage for 20 turns."},
	# Hepliaklqana
	"recall_ancestor": {"name": "Recall Ancestor",    "cost": 0,  "min_piety": 0,   "effect": "recall_ancestor","desc": "Summon your persistent ancestor companion."},
	"idealise":        {"name": "Idealise",           "cost": 15, "min_piety": 40,  "effect": "idealise",       "desc": "Empower your ancestor for 20 turns."},
	"transference":    {"name": "Transference",       "cost": 25, "min_piety": 80,  "effect": "transference",   "desc": "Swap places with your ancestor."},
	# Ignis
	"fiery_armour":    {"name": "Fiery Armour",       "cost": 15, "min_piety": 10,  "effect": "fiery_armour",   "desc": "A blazing aura — attackers take fire damage."},
	"foxfire_swarm":   {"name": "Foxfire Swarm",      "cost": 20, "min_piety": 20,  "effect": "foxfire_swarm",  "desc": "Summon a flock of foxfires to harass foes."},
	"rising_flame":    {"name": "Rising Flame",       "cost": 30, "min_piety": 40,  "effect": "rising_flame",   "desc": "A spire of flame hits a visible foe."},
}


## Beginner-focused guides. Each entry tells the player: (a) how to
## please this god (what actions grant piety), and (b) what you get
## at each ★ / *** piety milestone. Read by the altar popup and the
## status panel so first-time players understand the deal before
## committing to a pledge.
const GUIDES: Dictionary = {
	"trog": "Please by: killing enemies (especially casters).\nHates: casting spells (any cast angers Trog).\nGifts: random weapons at high piety.\nKey powers: Berserk (rage), Hand of Trog (berserker ally), Brothers in Arms (3 deep trolls).",
	"okawaru": "Please by: winning solo fights (no allies).\nHates: summoning, taking allies.\nGifts: weapons and armour at milestone piety.\nKey powers: Heroism (+skill), Finesse (extra attack), Duel (pull a foe to a private arena).",
	"makhleb": "Please by: murdering anything, fast and often.\nGifts: chaos powers; no gear.\nKey powers: Minor/Major Destruction (random blasts), Summon Demon.\nEach kill auto-heals a little HP while pledged.",
	"uskayaw": "Please by: killing quickly (multiple kills per turn = bigger piety).\nHates: idling in combat.\nKey powers: Stomp (AoE), Line Pass (dash-attack row).\nPiety decays fast; keep the dance going.",
	"zin": "Please by: killing unclean/chaotic things.\nHates: mutating yourself, using hexes/chaos.\nGifts: heals, mutation-suppression, imprisonment of foes.\nKey powers: Vitalisation (big heal), Sanctuary (12-turn untouchable), Imprison.",
	"the_shining_one": "Please by: killing evil/undead/demonic beings.\nHates: stabbing, poisoning, using evil spells.\nGifts: halo aura, divine shield.\nKey powers: Divine Shield (+6 AC), Cleansing Flame (holy AoE), Summon Angel.",
	"elyvilon": "Please by: healing yourself/allies; pacifying (not killing) foes.\nHates: killing pacified/neutral creatures.\nGifts: healing magic scaling with piety.\nKey powers: Lesser/Greater Healing, Pacify (turn foes neutral).",
	"vehumet": "Please by: killing things with destructive spells.\nGifts: new offensive spells at milestones (automatic).\nKey passive: destructive spells cost less MP as piety rises.\nNo special hates — just keep casting.",
	"sif_muna": "Please by: casting any spell to train it.\nGifts: spellbooks at milestones.\nKey powers: Channel Mana (free MP restore), Divine Exegesis (cast any known spell), Forget Spell (amnesia).",
	"kikubaaqudgha": "Please by: killing with necromancy.\nHates: holy actions.\nGifts: necromancy books, gains a corpse whenever you kill.\nKey powers: Receive Corpses, Torment (halves all non-undead HP), Unearthly Bond.",
	"nemelex_xobeh": "Please by: killing (any).\nGifts: decks of random cards.\nKey powers: Draw Card (random effect), Stack Five (pick-one-of-five).\nChaos patron — expect surprises, good and bad.",
	"xom": "No piety. Xom is amused by your existence — sometimes helps, sometimes harms, always random.\nCan't pledge via altar unless you really want chaos.\nActs on random turns when bored.",
	"yredelemnul": "Please by: killing in general; killing living things with drain.\nHates: holy acts.\nGifts: undead allies, life drain.\nKey powers: Animate Dead, Drain Life (AoE drain + self-heal), Enslave Soul.",
	"beogh": "Orcs only. Please by: killing non-orc foes while orcs nearby watch.\nGifts: orc followers convert to your side.\nKey powers: Recall Followers (teleport allies), Smite.",
	"jiyva": "Please by: feeding items to jellies (walk up, drop item).\nGifts: mutations (usually good), jelly allies.\nKey powers: Jelly Prayer, Cure Bad Mutation, Slimify (weapon dissolves foes).",
	"fedhas": "Please by: killing living things in plant-filled areas.\nHates: burning plants.\nGifts: plant allies, growth magic.\nKey powers: Sunlight (reveal+damage), Plant Ring (cover), Rain (flood).",
	"cheibriados": "Please by: moving slowly and killing HASTED foes.\nHates: haste self-cast, rushing.\nGifts: huge HP/stat boosts for patience.\nKey powers: Bend Time (slow all foes), Slouch (damage fast enemies).",
	"lugonu": "Please by: killing in the Abyss; banishing foes.\nGifts: space-warping abilities.\nKey powers: Bend Space (1-tile teleport), Banishment (send foe to Abyss), Corrupt Level.",
	"ashenzari": "Please by: being cursed (many items) and identifying things.\nGifts: +skill levels proportional to curses worn.\nKey powers: Scry (see through walls), Transfer Knowledge (skill swap).",
	"dithmenos": "Please by: killing while unseen; staying in darkness.\nGifts: shadow allies, invisibility aid.\nKey powers: Shadow Step (teleport into shadow), Shadow Form, Summon Shadow.",
	"gozag": "No piety. Spend GOLD instead.\nGifts: potions, shops, bribed monsters.\nKey powers: Potion Petition, Call Merchant, Bribe Branch (turn whole floor friendly).\nBest for rich runs.",
	"qazlal": "Please by: killing with elemental force.\nGifts: cloud protection around you.\nKey powers: Upheaval (bolt/flame/ice), Elemental Force (clouds do more), Disaster Area (massive AoE).",
	"ru": "Please by: sacrificing body parts / skills at the altar.\nGifts: massive passives per sacrifice (must permanently give something up).\nKey powers: Draw Out Power (big burst after rest), Apocalypse.",
	"wu_jian": "Please by: landing wall-jumps, whirlwinds, movement-based attacks.\nGifts: martial-art passives.\nKey powers: Wall Jump (leap + cleave), Heavenly Storm (cloud of strikes).\nPositioning god.",
	"hepliaklqana": "Please by: killing enemies while your ancestor is alive.\nGifts: stronger ancestor.\nKey powers: Recall Ancestor (teleport ally), Idealise (buff ancestor), Transference (swap places).\nAncestor acts with you as a partner.",
	"ignis": "Dying god — only 3 invocations ever.\nPlease by: killing enemies.\nKey powers: Fiery Armour, Foxfire Swarm, Rising Flame.\nEach invoke consumes one of the 3 uses — choose wisely.",
}


static func has(id: String) -> bool:
	return GODS.has(id)


static func get_info(id: String) -> Dictionary:
	return GODS.get(id, {}).duplicate() if GODS.has(id) else {}


static func all_ids() -> Array:
	return GODS.keys()


## Beginner-friendly teaching text for this god — covers how to earn
## piety, what's forbidden, and the top invocations. Falls back to
## the short `desc` when the id isn't in the GUIDES dict.
static func get_guide(id: String) -> String:
	if GUIDES.has(id):
		return String(GUIDES[id])
	return String(get_info(id).get("desc", ""))


static func invocation(id: String) -> Dictionary:
	return INVOCATIONS.get(id, {}).duplicate() if INVOCATIONS.has(id) else {}


## Invocations unlocked at `piety` for `god_id`. Rendered as bright rows;
## locked rows stay dim so the player can see the road ahead.
static func available_invocations(god_id: String, piety: int) -> Array:
	var out: Array = []
	for inv_id in get_info(god_id).get("invocations", []):
		var inv: Dictionary = invocation(String(inv_id))
		if int(inv.get("min_piety", 0)) <= piety:
			out.append(String(inv_id))
	return out


## Conducts are the "sins" that cost piety with this god. Example:
##   has_conduct("trog", "spells") → true  (Trog hates casters)
static func has_conduct(god_id: String, conduct: String) -> bool:
	var conducts: Array = get_info(god_id).get("conducts", [])
	return conducts.has(conduct)
