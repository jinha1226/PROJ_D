extends Node
## Minimal PlayerData autoload stub for LPCSpriteLoader.
## LPCSpriteLoader uses this only to look up equipped-item material ids.
## In PROJ_D material selection is encoded directly in preset equipment
## entries (def + variant), so is_initialized() returns false by default
## and the material-sniffing paths fall through harmlessly.

var inventory = null  # must expose .equipped: Dictionary if initialized

func is_initialized() -> bool:
	return inventory != null
