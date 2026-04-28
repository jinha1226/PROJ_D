class_name RingSystem extends RefCounted

## Unique ring passive effects — hooked from CombatSystem.

const UNIQUE_RING_IDS: Array = ["ring_bog", "ring_glacier", "ring_ember", "ring_undeath"]

static func is_unique(id: String) -> bool:
	return id in UNIQUE_RING_IDS

## Called after a successful player melee hit (same hook as EssenceSystem).
static func apply_melee_hit_effects(player: Player, monster: Monster) -> void:
	var ring: String = player.equipped_ring_id
	match ring:
		"ring_ember":
			var fire_dmg: int = Status.resist_scale(3, monster.data.resists, "fire")
			if fire_dmg > 0:
				monster.take_damage(fire_dmg)
				if randf() < 0.25 and monster.hp > 0:
					Status.apply(monster, "burning", 2)
		"ring_glacier":
			if randf() < 0.20 and monster.hp > 0:
				Status.apply(monster, "frozen", 1)

## Called when player kills a monster (same hook as EssenceSystem).
static func apply_on_kill_effects(player: Player) -> void:
	var ring: String = player.equipped_ring_id
	match ring:
		"ring_undeath":
			player.heal(3)
		"ring_bog":
			player.heal(1)
