# scripts/core/ZoneManager.gd
extends Node

static func zone_for_depth(depth: int) -> int:
	if depth >= 25:
		return 8
	return clampi((depth - 1) / 3, 0, 7)

static func depth_in_zone(depth: int) -> int:
	if depth >= 25:
		return 0
	return (depth - 1) % 3

static func zone_config(zone: int) -> Dictionary:
	return _ZONES[clampi(zone, 0, 8)]

static func config_for_depth(depth: int) -> Dictionary:
	return zone_config(zone_for_depth(depth))

const _ZONES: Array = [
	# Zone 0: Dungeon (1-3)
	{
		"name": "Dungeon",
		"map_style": "bsp",
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/pebble_brown0.png",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 1: Lair (4-6)
	{
		"name": "Lair",
		"map_style": "ca",
		"wall": "res://assets/tiles/individual/dngn/wall/lair0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/lair0.png",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 2: Orc Mines (7-9)
	{
		"name": "Orc Mines",
		"map_style": "bsp_tight",
		"wall": "res://assets/tiles/individual/dngn/wall/orc0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/orc0.png",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 3: Swamp (10-12)
	{
		"name": "Swamp",
		"map_style": "ca_water",
		"wall": "res://assets/tiles/individual/dngn/wall/stone_mossy0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/swamp0.png",
		"hazard_element": "poison",
		"hazard_density": 0.18,
	},
	# Zone 4: Crypt (13-15)
	{
		"name": "Crypt",
		"map_style": "bsp_long",
		"wall": "res://assets/tiles/individual/dngn/wall/crypt0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/crypt0.png",
		"hazard_element": "neg",
		"hazard_density": 0.12,
	},
	# Zone 5: Ice Caves (16-18)
	{
		"name": "Ice Caves",
		"map_style": "ca_open",
		"wall": "res://assets/tiles/individual/dngn/wall/ice_wall0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/frozen0.png",
		"hazard_element": "cold",
		"hazard_density": 0.15,
	},
	# Zone 6: Elven Halls (19-21)
	{
		"name": "Elven Halls",
		"map_style": "bsp_large",
		"wall": "res://assets/tiles/individual/dngn/wall/elf-stone0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/marble_floor1.png",
		"hazard_element": "",
		"hazard_density": 0.0,
	},
	# Zone 7: Infernal (22-24)
	{
		"name": "Infernal",
		"map_style": "ca_lava",
		"wall": "res://assets/tiles/individual/dngn/wall/stone_wall_scorched0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/infernal01.png",
		"hazard_element": "fire",
		"hazard_density": 0.15,
	},
	# Zone 8: Boss (25)
	{
		"name": "Boss Chamber",
		"map_style": "boss",
		"wall": "res://assets/tiles/individual/dngn/wall/stone_wall_scorched0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/infernal01.png",
		"hazard_element": "fire",
		"hazard_density": 0.08,
	},
]
